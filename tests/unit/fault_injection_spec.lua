local fake = require("tests.support.fake_native")
local reconcile = require("reconcile")

local function restart(s)
    s.world:reset_faults()
    s:restart()
    return reconcile.run(s.journal, s.world.native)
end

local function assert_location(world, location)
    local locations = world:locations("pal")
    assert_eq(#locations, 1)
    assert_eq(locations[1], location)
end

describe("plan 11.3 fault injection matrix", function()
    local cases = {
        {
            title = "before PREPARED: validation failure leaves the source unchanged",
            run = function(s, remove, src)
                s.world.faults.fail_validation = true
                assert_eq(remove().decision, "DENY")
                assert_eq(#s.backend.lines, 0)
                assert_eq(#s.world.attempts, 0)
                assert_location(s.world, src)
            end,
        },
        {
            title = "writing PREPARED: a disk fault forbids an unjournaled move",
            run = function(s, remove, src)
                s.backend.fail_write = true
                assert_eq(remove().code, "ERROR_PERSISTENCE_FAILED")
                assert_eq(s.journal:status("op"), nil)
                assert_eq(#s.backend.lines, 0)
                assert_eq(#s.world.attempts, 0)
                assert_location(s.world, src)
            end,
        },
        {
            title = "after PREPARED: restart reconciles without replaying a move",
            run = function(s, remove, src)
                s:restart(function()
                    assert_eq(s.journal:status("op"), "PREPARED")
                    assert_eq(#s.backend.lines, 1)
                    error("simulated process stop")
                end)
                assert_error(remove, "simulated process stop")
                assert_location(s.world, src)
                assert_eq(restart(s).ABORTED_SAFE, 1)
                assert_eq(remove().decision, "DENY")
                assert_eq(#s.world.attempts, 0)
                assert_location(s.world, src)
            end,
        },
        {
            title = "during native move: uncertainty stays visible and no compensating write occurs",
            run = function(s, remove, src)
                s.world.faults.move_fails = true
                assert_eq(remove().code, "ERROR_RECONCILIATION_REQUIRED")
                assert_eq(s.journal:status("op"), "RECONCILIATION_REQUIRED")
                assert_eq(#s.world.attempts, 1)
                assert_eq(#s.world.moves, 0)
                assert_location(s.world, src)
                s:restart()
                s.world.faults.read_fails = true
                assert_eq(reconcile.run(s.journal, s.world.native).MANUAL_REVIEW_REQUIRED, 1)
                assert_eq(#s.world.attempts, 1)
                assert_location(s.world, src)
            end,
        },
        {
            title = "after move before CONFIRMED: a read failure recovers the destination without a second move",
            run = function(s, remove)
                s.world.faults.confirmation_read_fails = true
                assert_eq(remove().code, "ERROR_RECONCILIATION_REQUIRED")
                assert_eq(s.journal:status("op"), "RECONCILIATION_REQUIRED")
                assert_location(s.world, "box-A")
                assert_eq(restart(s).CONFIRMED_RECOVERED, 1)
                assert_eq(remove().code, "OK_RETURNED_TO_OWNER")
                assert_eq(#s.world.attempts, 1)
                assert_eq(#s.world.moves, 1)
                assert_location(s.world, "box-A")
            end,
        },
        {
            title = "after CONFIRMED: a duplicate callback returns the prior result",
            run = function(s, remove)
                local first = remove()
                assert_eq(first.code, "OK_RETURNED_TO_OWNER")
                assert_eq(s.journal:status("op"), "CONFIRMED")
                local calls = #s.world.calls
                local duplicate = remove()
                assert_eq(duplicate.code, first.code)
                assert_eq(duplicate.decision, first.decision)
                assert_eq(#s.world.calls, calls)
                assert_eq(#s.world.attempts, 1)
                assert_eq(#s.backend.lines, 3)
                assert_location(s.world, "box-A")
            end,
        },
        {
            title = "owner disconnect: lost storage availability cannot reroute to the actor",
            run = function(s, remove, src)
                s.world.faults.disconnect_owner = true
                assert_eq(remove().code, "DENY_OWNER_STORAGE_UNAVAILABLE")
                assert_eq(s.journal:status("op"), "ABORTED_SAFE")
                assert_eq(#s.world.attempts, 0)
                assert_eq(#s.world.containers["box-B"].pals, 0)
                assert_location(s.world, src)
            end,
        },
        {
            title = "game update: an unvalidated build stays read-only",
            run = function(s, remove, src)
                s.context.build_supported = false
                local denied = remove()
                assert_eq(denied.decision, "OBSERVE_ONLY")
                assert_eq(denied.code, "ERROR_GAME_BUILD_UNSUPPORTED")
                assert_eq(#s.backend.lines, 0)
                assert_eq(#s.world.calls, 0)
                assert_location(s.world, src)
            end,
        },
    }

    for _, case in ipairs(cases) do
        it(case.title, function()
            local s = fake.scenario({ pal = "A", other = "B" })
            local req = s.world:request("op", "pal", "B")
            local function remove()
                return s.coordinator:handle_worker_removal(req, s.context)
            end
            case.run(s, remove, s.world.pals.pal.source)
        end)
    end
end)
