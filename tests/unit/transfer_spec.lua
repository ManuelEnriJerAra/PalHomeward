local fake = require("tests.support.fake_native")

local function setup(options)
    local scenario = fake.scenario({ pal = "A", other = "A" }, options)
    return scenario, scenario.world:request("op", "pal", "B")
end

local function removal(scenario, request)
    return scenario.coordinator:handle_worker_removal(request, scenario.context)
end

local function check(result, request, decision, code)
    assert_eq(result.operation_id, request.operation_id)
    assert_eq(result.pal_id, request.pal_id)
    assert_eq(result.world_id, request.world_id)
    assert_eq(result.decision, decision)
    assert_eq(result.code, code)
end

local function assert_in(world, pal, expected)
    local locations = world:locations(pal)
    assert_eq(#locations, 1)
    assert_eq(locations[1], expected)
end

describe("transfer coordinator", function()
    it("UT-001, UT-025, UT-043 journals before one move, validates again and confirms observed destination", function()
        local s, req = setup()
        req.owner_uid = "B"
        s.world.faults.on_move = function(op)
            assert_eq(s.journal:status(op), "EXECUTING")
            assert_eq(#s.backend.lines, 2)
            assert_eq(s.world.calls[#s.world.calls - 1][1], "validate")
        end
        check(removal(s, req), req, "REDIRECT", "OK_RETURNED_TO_OWNER")
        assert_eq(#s.world.attempts, 1)
        assert_in(s.world, "pal", "box-A")
        local status, row = s.journal:status("op")
        assert_eq(status, "CONFIRMED")
        assert_eq(row.owner, "A")
        assert_eq(row.actor, "B")
        assert_eq(row.t, 100)
        assert_eq(s.world.calls[#s.world.calls][1], "read")
    end)

    it("UT-002 preserves normal self-removal without a coordinator move", function()
        local s, req = setup()
        req.actor_uid = "A"
        check(removal(s, req), req, "ALLOW", "OK_OWNER_SELF_REMOVAL")
        s.context.mode = "PROTECT"
        check(removal(s, req), req, "ALLOW", "OK_OWNER_SELF_REMOVAL")
        assert_eq(#s.world.attempts, 0)
        assert_eq(#s.backend.lines, 0)
    end)

    it("UT-003, UT-006, UT-040, UT-041 rejects missing authority and foreign worlds and observes unsafe capabilities", function()
        local s, req = setup()
        check(s.coordinator:handle_worker_removal(req, nil), req, "DENY", "DENY_UNAUTHORIZED_ACTOR")
        s.context.server_authority = false
        check(removal(s, req), req, "DENY", "DENY_UNAUTHORIZED_ACTOR")
        s.context.server_authority = true
        s.context.mode = "OBSERVE"
        check(removal(s, req), req, "OBSERVE_ONLY", "ERROR_HOOK_NOT_VERIFIED")
        s.context.mode = "AUTO_RETURN"
        s.context.capabilities.CANCEL_OR_REDIRECT = "UNVERIFIED"
        check(removal(s, req), req, "OBSERVE_ONLY", "ERROR_HOOK_NOT_VERIFIED")
        s.context.capabilities.CANCEL_OR_REDIRECT = "VERIFIED"
        s.context.build_supported = false
        check(removal(s, req), req, "OBSERVE_ONLY", "ERROR_GAME_BUILD_UNSUPPORTED")
        s.context.build_supported = true
        req.world_id = "other"
        check(removal(s, req), req, "DENY", "DENY_UNKNOWN_PAL")
        s.context.current_world_id = "other"
        check(removal(s, req), req, "DENY", "DENY_UNKNOWN_PAL")
        local foreign = fake.scenario({ pal = "A" }, { registry_world = "other" })
        check(removal(foreign, foreign.world:request("op", "pal", "A")),
            foreign.world:request("op", "pal", "A"), "DENY", "DENY_UNKNOWN_PAL")
        assert_eq(#s.world.calls, 0)
        assert_eq(#foreign.world.calls, 0)
        s.context.current_world_id, req.world_id = "world", "world"
        s.world.id = "other"
        check(removal(s, req), req, "DENY", "DENY_UNKNOWN_PAL")
        s.world.id, req.pal_id = "world", "missing"
        check(removal(s, req), req, "DENY", "DENY_UNKNOWN_PAL")
        assert_eq(#s.backend.lines, 0)
    end)

    it("UT-004, UT-005, UT-015, UT-016, UT-017 stops before resolving a destination on bad source or authority", function()
        local s, req = setup()
        req.source_slot = 0
        check(removal(s, req), req, "DENY", "DENY_SOURCE_CHANGED")
        req.source_slot = s.world.pals.pal.slot
        req.base_id = "wrong-base"
        check(removal(s, req), req, "DENY", "DENY_SOURCE_CHANGED")
        req.base_id = "base"
        s.context.actor_may_manage = false
        check(removal(s, req), req, "DENY", "DENY_UNAUTHORIZED_ACTOR")
        s.context.actor_may_manage = true
        local original = s.registry.resolve
        s.registry.resolve = function() return { status = "UNRESOLVED", owner_uid = "B" } end
        check(removal(s, req), req, "DENY", "DENY_UNKNOWN_OWNER")
        s.registry.resolve = original
        assert(s.registry:mark_conflict("pal", "OWNER_CONFLICT"))
        check(removal(s, req), req, "DENY", "DENY_UNKNOWN_OWNER")
        assert_eq(#s.backend.lines, 0)
        assert_eq(#s.world.calls, 5)
        for _, call in ipairs(s.world.calls) do
            assert_eq(call[1], "read")
        end
    end)

    it("UT-013, UT-014 denies unusable destinations and protection-only cross-owner requests", function()
        local s, req = setup()
        local box = s.world.containers["box-A"]
        box.capacity = 0
        check(removal(s, req), req, "DENY", "DENY_DESTINATION_FULL")
        box.capacity, box.locked = 10, true
        check(removal(s, req), req, "DENY", "DENY_CONCURRENT_OPERATION")
        box.locked, s.context.mode = false, "PROTECT"
        check(removal(s, req), req, "DENY", "DENY_UNSUPPORTED_TRANSFER_PATH")
        s.context.mode = "AUTO_RETURN"
        s.world.boxes.A = s.world.pals.pal.source
        check(removal(s, req), req, "DENY", "DENY_OWNER_STORAGE_UNAVAILABLE")
        s.world.native.resolve_owner_storage = function() return { id = "box-B", owner_uid = "B" } end
        check(removal(s, req), req, "DENY", "DENY_OWNER_STORAGE_UNAVAILABLE")
        assert_eq(#s.world.attempts, 0)
        assert_eq(#s.backend.lines, 0)
    end)

    it("UT-018 denies a newly full destination immediately before execution and replays the denial", function()
        local s, req = setup()
        s.world.faults.on_validate = function(count, dst)
            if count == 2 then
                s.world.containers[dst.id].capacity = 0
            end
        end
        check(removal(s, req), req, "DENY", "DENY_DESTINATION_FULL")
        assert_eq(s.world.acceptance_checks.pal, 2)
        assert_eq(s.journal:status("op"), "ABORTED_SAFE")
        assert_eq(#s.world.attempts, 0)
        assert_in(s.world, "pal", s.world.pals.pal.source)
        local calls = #s.world.calls
        s:restart()
        check(removal(s, req), req, "DENY", "DENY_DESTINATION_FULL")
        assert_eq(#s.world.calls, calls)
    end)

    it("UT-018 records changed ownership or worker slot before the move", function()
        for key, expected in pairs({ slot = "DENY_SOURCE_CHANGED", owner = "DENY_UNKNOWN_OWNER" }) do
            local s, req = setup()
            s.coordinator.after_prepared = function()
                if key == "slot" then
                    s.world.pals.pal.slot = 42
                else
                    assert(s.registry:mark_conflict("pal", "OWNER_CHANGED"))
                end
            end
            check(removal(s, req), req, "DENY", expected)
            assert_eq(s.journal:status("op"), "ABORTED_SAFE")
            assert_eq(#s.world.attempts, 0)
        end
    end)

    it("UT-019 returns the original result after restart and rejects operation ID collisions", function()
        local s, req = setup()
        local first = removal(s, req)
        assert_eq(first.code, "OK_RETURNED_TO_OWNER")
        local calls = #s.world.calls
        s:restart()
        check(removal(s, req), req, first.decision, first.code)
        local collision = s.world:request("op", "other", "B")
        check(removal(s, collision), collision, "DENY", "DENY_CONCURRENT_OPERATION")
        req.actor_uid = "A"
        check(removal(s, req), req, "DENY", "DENY_CONCURRENT_OPERATION")
        assert_eq(#s.world.calls, calls)
        assert_eq(#s.world.attempts, 1)
    end)

    it("UT-020 denies pending IDs and quarantines the same Pal under a different ID", function()
        local s, req = setup()
        assert(s.journal:prepare({ op = "op", world = "world", pal = "pal", actor = "B" }))
        check(removal(s, req), req, "DENY", "DENY_CONCURRENT_OPERATION")
        req.operation_id = "other-op"
        check(removal(s, req), req, "DENY", "DENY_CONCURRENT_OPERATION")
        assert_eq(#s.world.calls, 0)
        assert(s.journal:record_recovery("op", "MANUAL_REVIEW_REQUIRED"))
        check(removal(s, req), req, "DENY", "DENY_CONCURRENT_OPERATION")
        req.operation_id = "op"
        check(removal(s, req), req, "DENY", "ERROR_RECONCILIATION_REQUIRED")
        assert_eq(#s.world.calls, 0)
    end)

    it("UT-021, UT-022 isolates concurrent requests by Pal and reserves operation IDs in flight", function()
        local s, req = setup()
        s.world.faults.on_read = function(pal)
            if pal == "pal" then
                coroutine.yield("in-flight")
            end
        end
        local thread = coroutine.create(function() return removal(s, req) end)
        local ok, point = coroutine.resume(thread)
        assert(ok, point)
        assert_eq(point, "in-flight")
        local same = s.world:request("second", "pal", "B")
        check(removal(s, same), same, "DENY", "DENY_CONCURRENT_OPERATION")
        local collision = s.world:request("op", "other", "B")
        check(removal(s, collision), collision, "DENY", "DENY_CONCURRENT_OPERATION")
        assert_eq(#s.world.calls, 1)
        local other = s.world:request("third", "other", "B")
        check(removal(s, other), other, "REDIRECT", "OK_RETURNED_TO_OWNER")
        s.world.faults.on_read = nil
        local resumed, first = coroutine.resume(thread)
        assert(resumed, first)
        check(first, req, "REDIRECT", "OK_RETURNED_TO_OWNER")
        assert_eq(#s.world.attempts, 2)
    end)

    it("UT-021 respects injected locks", function()
        local external = { pal = true }
        local s, req = setup({ locks = external })
        check(removal(s, req), req, "DENY", "DENY_CONCURRENT_OPERATION")
        assert_true(external.pal)
        assert_eq(#s.world.calls, 0)
    end)

    it("UT-023 suppresses synchronous callbacks during native calls even for other Pals", function()
        local s, req = setup()
        local nested = s.world:request("nested", "other", "B")
        s.world.faults.on_move = function()
            local calls = #s.world.calls
            check(removal(s, nested), nested, "DENY", "DENY_CONCURRENT_OPERATION")
            assert_eq(#s.world.calls, calls)
        end
        check(removal(s, req), req, "REDIRECT", "OK_RETURNED_TO_OWNER")
        assert_eq(#s.world.attempts, 1)
    end)

    it("UT-024 never confirms a success response if the Pal never moved", function()
        local s, req = setup()
        s.world.faults.success_without_move = true
        check(removal(s, req), req, "DENY", "ERROR_RECONCILIATION_REQUIRED")
        assert_eq(s.journal:status("op"), "RECONCILIATION_REQUIRED")
        assert_in(s.world, "pal", s.world.pals.pal.source)
        assert_eq(#s.world.attempts, 1)
    end)

    it("UT-026, UT-027 leaves ambiguous, empty or malformed final locations for reconciliation", function()
        for _, locations in ipairs({
            { "worker-2", "box-A" }, {}, { "box-A", "box-A" }, { "box-A", [3] = "box-B" },
        }) do
            local s, req = setup()
            s.world.faults.report_locations = locations
            check(removal(s, req), req, "DENY", "ERROR_RECONCILIATION_REQUIRED")
            assert_eq(s.journal:status("op"), "RECONCILIATION_REQUIRED")
            assert_eq(#s.world.attempts, 1)
        end
    end)

    it("UT-028 blocks native work when an incomplete journal tail needs review", function()
        local s, req = setup({ backend = fake.backend({ '{"op":"interrupted' }) })
        assert_true(s.journal.safe_mode)
        check(removal(s, req), req, "DENY", "ERROR_PERSISTENCE_FAILED")
        assert_eq(#s.world.calls, 0)
    end)

    it("UT-033 stops before any native move if either required journal append fails", function()
        for fail_at = 1, 2 do
            local s, req = setup()
            s.backend.fail_at = fail_at
            check(removal(s, req), req, "DENY", "ERROR_PERSISTENCE_FAILED")
            assert_eq(#s.world.attempts, 0)
            assert_eq(#s.backend.lines, fail_at - 1)
        end
    end)

    it("UT-034, UT-035 records exceptions, timeouts and move-with-error without retrying", function()
        local cases = {
            move_throws = "NATIVE_MOVE_FAILED", timeout = "NATIVE_TIMEOUT",
            move_but_error = "NATIVE_MOVE_FAILED", confirmation_read_fails = "CONFIRMATION_READ_FAILED",
        }
        for fault, expected_reason in pairs(cases) do
            local s, req = setup()
            s.world.faults[fault] = true
            check(removal(s, req), req, "DENY", "ERROR_RECONCILIATION_REQUIRED")
            local status, row = s.journal:status("op")
            assert_eq(status, "RECONCILIATION_REQUIRED")
            assert_eq(row.reason, expected_reason)
            local calls = #s.world.calls
            check(removal(s, req), req, "DENY", "DENY_CONCURRENT_OPERATION")
            assert_eq(#s.world.calls, calls)
            assert_eq(#s.world.attempts, 1)
        end
    end)

    it("keeps uncertainty when the source becomes unreadable or journal confirmation fails", function()
        local s, req = setup()
        s.coordinator.after_prepared = function() s.world.faults.read_fails = true end
        check(removal(s, req), req, "DENY", "ERROR_RECONCILIATION_REQUIRED")
        assert_eq(s.journal:status("op"), "RECONCILIATION_REQUIRED")
        assert_eq(#s.world.attempts, 0)

        s, req = setup()
        s.backend.fail_at = 3
        check(removal(s, req), req, "DENY", "ERROR_RECONCILIATION_REQUIRED")
        assert_eq(s.journal:status("op"), "EXECUTING")
        assert_true(s.journal.safe_mode)
        assert_eq(#s.backend.lines, 2)
        assert_in(s.world, "pal", "box-A")
    end)

    it("blocks a move if revalidation cannot record safe abort or the journal becomes unsafe", function()
        local s, req = setup()
        s.world.faults.disconnect_owner = true
        s.backend.fail_at = 3
        check(removal(s, req), req, "DENY", "ERROR_PERSISTENCE_FAILED")
        assert_eq(s.journal:status("op"), "EXECUTING")
        assert_eq(#s.world.attempts, 0)

        s, req = setup()
        s.world.faults.on_validate = function(count)
            if count == 2 then
                s.backend.fail_at = 3
                local other = s.world:request("other-op", "other", "B")
                local thread = coroutine.create(function() return removal(s, other) end)
                local ok, result = coroutine.resume(thread)
                assert(ok, result)
                check(result, other, "DENY", "ERROR_PERSISTENCE_FAILED")
                assert_true(s.journal.safe_mode)
            end
        end
        check(removal(s, req), req, "DENY", "ERROR_PERSISTENCE_FAILED")
        assert_eq(#s.world.attempts, 0)
    end)

end)
