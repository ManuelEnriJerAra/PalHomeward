local fake = {}

function fake.backend(lines)
    local backend = { lines = lines or {} }
    function backend.append(line)
        if backend.throw_write then
            error("simulated write exception")
        end
        if backend.fail_write or backend.fail_at == #backend.lines + 1 then
            return nil, "DISK_FAILURE"
        end
        backend.lines[#backend.lines + 1] = line
        return true
    end
    function backend.flush()
        if backend.fail_flush then
            return nil, "FLUSH_FAILURE"
        end
        return true
    end
    function backend.read_lines()
        if backend.fail_read then
            return nil, "READ_FAILURE"
        end
        return backend.lines, backend.terminated
    end
    return backend
end

-- The physical world and the adapter's reported state can disagree. Capacity,
-- storage ownership, and worker slots are read from mutable world tables.
function fake.world(owners)
    local world = {
        id = "world", owners = owners, pals = {}, containers = {}, boxes = {},
        faults = {}, calls = {}, attempts = {}, moves = {}, acceptance_checks = {},
    }
    local slots = {}
    for pal, owner in pairs(owners) do
        slots[#slots + 1] = pal
        if owner then
            local box = "box-" .. owner
            world.boxes[owner] = box
            world.containers[box] = { pals = {}, capacity = 100, available = true, locked = false }
        end
    end
    table.sort(slots)
    for slot, pal in ipairs(slots) do
        local id = "worker-" .. slot
        world.pals[pal] = { source = id, slot = slot, base = "base" }
        world.containers[id] = { pals = { pal }, capacity = 1, available = true, locked = false }
    end

    local function log(name, id)
        world.calls[#world.calls + 1] = { name, id }
    end

    function world:locations(pal)
        local locations = {}
        for id, container in pairs(self.containers) do
            for _, held in ipairs(container.pals) do
                if held == pal then
                    locations[#locations + 1] = id
                end
            end
        end
        table.sort(locations)
        return locations
    end

    function world:request(op, pal, actor)
        return {
            operation_id = op, pal_id = pal, actor_uid = actor, world_id = self.id,
            base_id = self.pals[pal].base, source_slot = self.pals[pal].slot,
        }
    end

    function world:assign(pal)
        for _, container in pairs(self.containers) do
            for index = #container.pals, 1, -1 do
                if container.pals[index] == pal then
                    table.remove(container.pals, index)
                end
            end
        end
        local source = self.containers[self.pals[pal].source]
        source.pals[#source.pals + 1] = pal
    end

    local native = {}
    world.native = native
    local attempted = {}
    function world:reset_faults()
        self.faults, self.acceptance_checks = {}, {}
        attempted = {}
    end

    function native.read_fresh_state(pal)
        log("read", pal)
        local faults = world.faults
        if faults.on_read then
            faults.on_read(pal)
        end
        if faults.read_throws then
            error("simulated read exception")
        end
        if faults.read_fails or (faults.confirmation_read_fails and attempted[pal]) then
            return nil, "READ_FAILURE"
        end
        local info = world.pals[pal]
        if not info then
            return nil, "MISSING_PAL"
        end
        local locations = world:locations(pal)
        local worker
        for _, location in ipairs(locations) do
            if location == info.source then
                worker = { base_id = info.base, slot = info.slot, location = location }
            end
        end
        if attempted[pal] and faults.report_locations then
            locations = faults.report_locations
        end
        return { pal_id = pal, world_id = world.id, has_active_operation = info.active == true,
            locations = locations, worker = worker }
    end

    function native.resolve_owner_storage(owner)
        log("resolve", owner)
        local id = world.boxes[owner]
        if not id then
            return nil, "MISSING_STORAGE"
        end
        return { id = id, owner_uid = owner }
    end

    function native.can_safely_accept(dst, state)
        local pal = state.pal_id
        log("validate", pal)
        local count = (world.acceptance_checks[pal] or 0) + 1
        world.acceptance_checks[pal] = count
        local faults = world.faults
        if faults.on_validate then
            faults.on_validate(count, dst, state)
        end
        if faults.disconnect_owner and count == 2 then
            world.containers[dst.id].available = false
        end
        if faults.fail_validation then
            return nil, "VALIDATION_FAILED"
        end
        local box = world.containers[dst.id]
        local resolved = box ~= nil and world.boxes[dst.owner_uid] == dst.id
        return {
            resolved = resolved, available = resolved and box.available,
            has_space = resolved and #box.pals < box.capacity, locked = resolved and box.locked,
        }
    end

    function native.execute_move_once(state, dst)
        local pal, op = state.pal_id, state.operation_id
        log("move", pal)
        world.attempts[#world.attempts + 1] = { op = op, pal = pal, dst = dst.id }
        attempted[pal] = true
        local faults = world.faults
        if faults.on_move then
            faults.on_move(op, pal)
        end
        if faults.move_throws then
            error("simulated native exception")
        end
        if faults.move_fails then
            return nil, "NATIVE_FAILURE"
        end
        if faults.timeout then
            return nil, "TIMEOUT"
        end
        if not faults.success_without_move then
            local from = world.containers[state.worker.location].pals
            local to = world.containers[dst.id].pals
            local found
            for index, held in ipairs(from) do
                if held == pal then
                    found = index
                    break
                end
            end
            if not found then
                return nil, "SOURCE_CHANGED"
            end
            local moving = table.remove(from, found)
            to[#to + 1] = moving
            world.moves[#world.moves + 1] = { op = op, pal = moving, dst = dst.id }
        end
        if faults.move_but_error then
            return nil, "NATIVE_FAILURE"
        end
        return { success = true }
    end
    return world
end

function fake.context()
    return {
        mode = "AUTO_RETURN", build_supported = true, current_world_id = "world",
        capabilities = { PRE_MUTATION_INTERCEPTION = "VERIFIED", CANCEL_OR_REDIRECT = "VERIFIED" },
        server_authority = true, actor_may_manage = true,
    }
end

function fake.scenario(owners, options)
    local ownership = require("ownership")
    local journal = require("journal")
    local policy = require("policy")
    local transfer = require("transfer")
    options = options or {}
    local s = {
        world = fake.world(owners), backend = options.backend or fake.backend(), context = fake.context(),
        registry = assert(ownership.new_registry(options.registry_world or "world")),
    }
    for pal, owner in pairs(owners) do
        if owner then
            assert(s.registry:record_verified_owner(pal, owner, { source = "synthetic", revision = 1 }))
        end
    end

    function s:restart(after_prepared)
        self.journal = assert(journal.open(self.backend, self.world.id))
        self.coordinator = transfer.new({
            journal = self.journal, registry = self.registry, policy = policy, native = self.world.native,
            clock = function() return 100 end, after_prepared = after_prepared, locks = options.locks,
        })
    end

    s:restart(options.after_prepared)
    return s
end

return fake
