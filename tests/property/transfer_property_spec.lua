local fake = require("tests.support.fake_native")
local reconcile = require("reconcile")

local SEED, SEQUENCES = 7092026, 1200
local PAL_IDS = { "pal-a", "pal-b", "pal-unknown" }
local OWNERS = { ["pal-a"] = "A", ["pal-b"] = "B", ["pal-unknown"] = false }
local ACTORS = { "A", "B" }

-- Expected effects of externally selected fault scenarios on an otherwise
-- eligible cross-owner request. The model tracks one physical location per
-- Pal and never uses adapter replies, journal rows or policy to choose it.
local effects = {
    { fault = "none", attempted = true, moved = true, status = "CONFIRMED", decision = "REDIRECT" },
    { fault = "fail_validation", decision = "DENY" },
    { fault = "disk", decision = "DENY" },
    { fault = "crash", status = "PREPARED" },
    { fault = "move_fails", attempted = true, status = "RECONCILIATION_REQUIRED", decision = "DENY" },
    { fault = "timeout", attempted = true, status = "RECONCILIATION_REQUIRED", decision = "DENY" },
    { fault = "success_without_move", attempted = true, status = "RECONCILIATION_REQUIRED", decision = "DENY" },
    { fault = "move_but_error", attempted = true, moved = true, status = "RECONCILIATION_REQUIRED", decision = "DENY" },
    { fault = "confirmation_read_fails", attempted = true, moved = true,
        status = "RECONCILIATION_REQUIRED", decision = "DENY" },
    { fault = "disconnect_owner", status = "ABORTED_SAFE", decision = "DENY" },
    { fault = "bad_build", decision = "OBSERVE_ONLY" },
}

local function random_generator(state)
    return function(limit)
        state = (1664525 * state + 1013904223) & 0xffffffff
        return (state >> 8) % limit + 1
    end
end

local function verify_world(world, model)
    -- Scan backing containers directly so a faulty read cannot validate itself.
    local references = {}
    for container, contents in pairs(world.containers) do
        for _, pal in ipairs(contents.pals) do
            assert_eq(references[pal], nil) -- INV-01: no second live reference
            assert_eq(container, model.position[pal])
            references[pal] = container
        end
    end
    for _, pal in ipairs(PAL_IDS) do
        assert_eq(references[pal], model.position[pal]) -- INV-01: no disappearance
    end
end

local function verify_history(s, model)
    local attempts, movements = {}, {}
    for _, attempt in ipairs(s.world.attempts) do
        assert_eq(attempts[attempt.op], nil) -- INV-04: even a failed native move is attempted once
        attempts[attempt.op] = attempt
    end
    for _, move in ipairs(s.world.moves) do
        assert_eq(movements[move.op], nil)
        local operation = assert(model.operations[move.op])
        local owner = OWNERS[operation.pal]
        assert(owner and owner ~= operation.actor) -- INV-03 / INV-05
        assert_eq(move.pal, operation.pal)
        assert_eq(move.dst, "box-" .. owner)
        movements[move.op] = move
    end
    for id, operation in pairs(model.operations) do
        local state, row = s.journal:status(id)
        assert_eq(state, operation.status)
        assert_eq(attempts[id] ~= nil, operation.attempted == true)
        assert_eq(movements[id] ~= nil, operation.moved == true)
        if state == "CONFIRMED" or state == "CONFIRMED_RECOVERED" then
            assert_eq(row.dst, "box-" .. OWNERS[operation.pal])
            if state ~= operation.last_seen then -- INV-07: at the moment of confirmation
                assert_eq(row.dst, model.position[operation.pal])
                assert_eq(s.world:locations(operation.pal)[1], row.dst)
            end
        end
        operation.last_seen = state
    end
end

local function configure(s, effect)
    local world = s.world
    world:reset_faults()
    for _, box in pairs(world.boxes) do
        world.containers[box].available = true
    end
    s.backend.fail_write = effect.fault == "disk"
    s.context.build_supported = effect.fault ~= "bad_build"
    s.coordinator.after_prepared = nil
    if effect.fault == "crash" then
        s.coordinator.after_prepared = function() error("simulated process stop") end
    elseif effect.fault ~= "none" and effect.fault ~= "disk" and effect.fault ~= "bad_build" then
        world.faults[effect.fault] = true
    end
end

local function request(s, model, id, effect, exercised)
    configure(s, effect)
    local op = model.operations[id]
    local expected = "DENY"
    if effect.fault == "bad_build" then
        exercised[effect.fault] = true
        expected = "OBSERVE_ONLY"
    elseif op.status == "CONFIRMED" or op.status == "CONFIRMED_RECOVERED" then
        expected = "REDIRECT"
    elseif not op.status and not model.safe_mode and not model.blocked[op.pal]
        and model.position[op.pal] == model.source[op.pal] and OWNERS[op.pal] then
        local owner = OWNERS[op.pal]
        if owner == op.actor then
            expected = effect.fault == "fail_validation" and "DENY" or "ALLOW"
        else
            exercised[effect.fault] = true
            op.status, op.attempted, op.moved = effect.status, effect.attempted, effect.moved
            expected = effect.decision
            if op.moved then
                model.position[op.pal] = "box-" .. owner
            end
            if op.status == "PREPARED" or op.status == "RECONCILIATION_REQUIRED" then
                model.blocked[op.pal] = true
            end
            if effect.fault == "disk" then
                model.safe_mode = true
            end
        end
    end

    local req = s.world:request(id, op.pal, op.actor)
    req.owner_uid = op.actor
    local ok, result = pcall(s.coordinator.handle_worker_removal, s.coordinator, req, s.context)
    if expected == nil then
        assert(not ok and tostring(result):find("simulated process stop", 1, true))
    else
        assert(ok, result)
        assert_eq(result.decision, expected)
        assert_eq(result.operation_id, id)
        if op.status == "RECONCILIATION_REQUIRED" and not op.last_seen then
            assert_eq(result.code, "ERROR_RECONCILIATION_REQUIRED") -- INV-08: uncertainty stops the move path
        end
    end
end

local function restart(s, model, unreadable)
    configure(s, effects[1])
    s.world.faults.read_fails = unreadable
    s:restart()
    local attempts = #s.world.attempts
    local expected = { CONFIRMED_RECOVERED = 0, ABORTED_SAFE = 0, MANUAL_REVIEW_REQUIRED = 0 }
    for _, op in pairs(model.operations) do
        if op.status == "PREPARED" or op.status == "RECONCILIATION_REQUIRED" then
            if unreadable then
                op.status = "MANUAL_REVIEW_REQUIRED" -- INV-08: unresolved evidence persists for review
            elseif model.position[op.pal] == model.source[op.pal] then
                op.status = "ABORTED_SAFE"
            else
                op.status = "CONFIRMED_RECOVERED"
            end
            expected[op.status] = expected[op.status] + 1
            model.blocked[op.pal] = unreadable
        end
    end
    model.safe_mode = false
    local result = reconcile.run(s.journal, s.world.native)
    assert_eq(#result.errors, 0)
    for status, count in pairs(expected) do
        assert_eq(result[status], count)
    end
    assert_eq(#s.world.attempts, attempts)
end

describe("transfer coordinator properties", function()
    it("preserves INV-01, INV-03, INV-04, INV-07 and INV-08 across random fault and restart sequences", function()
        print(string.format("Transfer property seed: %d, sequences: %d", SEED, SEQUENCES))
        local random = random_generator(SEED)
        local exercised, steps = {}, 0
        for sequence = 1, SEQUENCES do
            local s = fake.scenario(OWNERS)
            local model = { source = {}, position = {}, operations = {}, blocked = {}, safe_mode = false }
            for index, pal in ipairs(PAL_IDS) do
                model.source[pal] = "worker-" .. index
                model.position[pal] = model.source[pal]
            end
            local issued = {}
            for step = 1, random(20) + 12 do
                steps = steps + 1
                local pal, action = PAL_IDS[random(#PAL_IDS)], random(8)
                local effect = effects[random(#effects)]
                local ok, err = pcall(function()
                    if action <= 4 then
                        local id = "op-" .. (#issued + 1)
                        issued[#issued + 1] = id
                        model.operations[id] = { pal = pal, actor = ACTORS[random(#ACTORS)] }
                        request(s, model, id, effect, exercised)
                    elseif action <= 6 and #issued > 0 then
                        request(s, model, issued[random(#issued)], effect, exercised)
                    elseif action == 7 then
                        restart(s, model, random(5) == 1)
                    elseif not model.blocked[pal] then
                        s.world:assign(pal)
                        model.position[pal] = model.source[pal]
                    end
                    verify_world(s.world, model)
                    verify_history(s, model)
                end)
                assert(ok, string.format("seed %d, sequence %d, step %d, action %d, fault %s: %s",
                    SEED, sequence, step, action, effect.fault, tostring(err)))
            end
        end
        for _, effect in ipairs(effects) do
            assert(exercised[effect.fault], "fault was not exercised: " .. effect.fault)
        end
        print(string.format("Transfer property steps: %d", steps))
    end)
end)
