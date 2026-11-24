local fake = require("tests.support.fake_native")
local reconcile = require("reconcile")

local function fixture()
    local s = fake.scenario({ pal = "A" })
    local src = s.world.pals.pal.source
    assert(s.journal:prepare({ op = "op", world = "world", pal = "pal",
        owner = "A", actor = "B", src = src, dst = "box-A", t = 1 }))
    return s, src
end

describe("restart reconciliation", function()
    it("UT-036 leaves a previously confirmed operation untouched", function()
        local s = fixture()
        assert(s.journal:executing("op"))
        assert(s.journal:confirm("op"))
        s:restart()
        local summary = reconcile.run(s.journal, s.world.native)
        assert_eq(#s.world.calls, 0)
        assert_eq(#s.backend.lines, 3)
        assert_eq(#summary.errors, 0)
        assert_eq(s.journal:status("op"), "CONFIRMED")
    end)

    it("UT-037 aborts a prepared operation with one exact source and no active move", function()
        local s, src = fixture()
        s:restart()
        local summary = reconcile.run(s.journal, s.world.native)
        assert_eq(summary.ABORTED_SAFE, 1)
        assert_eq(s.journal:status("op"), "ABORTED_SAFE")
        assert_eq(s.world:locations("pal")[1], src)
        assert_eq(#s.world.attempts, 0)
        assert_eq(reconcile.run(s.journal, s.world.native).ABORTED_SAFE, 0)
    end)

    it("UT-038 recovers a Pal only at its recorded destination from each unfinished state", function()
        for _, advance in ipairs({ "prepared", "executing", "require_reconciliation" }) do
            local s, src = fixture()
            if advance ~= "prepared" then
                assert(s.journal[advance](s.journal, "op"))
            end
            s.world.containers[src].pals = {}
            s.world.containers["box-A"].pals = { "pal" }
            s:restart()
            local summary = reconcile.run(s.journal, s.world.native)
            assert_eq(summary.CONFIRMED_RECOVERED, 1)
            assert_eq(s.journal:status("op"), "CONFIRMED_RECOVERED")
            local req = s.world:request("op", "pal", "B")
            local result = s.coordinator:handle_worker_removal(req, s.context)
            assert_eq(result.code, "OK_RETURNED_TO_OWNER")
            assert_eq(#s.world.attempts, 0)
        end
    end)

    it("UT-039 flags missing, duplicated, unexpected, active and unreadable instances for review", function()
        for _, state in ipairs({ "missing", "duplicated", "unexpected", "active", "read-fails", "throws" }) do
            local s, src = fixture()
            if state == "missing" then
                s.world.containers[src].pals = {}
            elseif state == "duplicated" then
                s.world.containers["box-A"].pals = { "pal" }
            elseif state == "unexpected" then
                s.world.containers[src].pals = {}
                s.world.containers["other-box"] = { pals = { "pal" } }
            elseif state == "active" then
                s.world.pals.pal.active = true
            elseif state == "read-fails" then
                s.world.faults.read_fails = true
            else
                s.world.faults.read_throws = true
            end
            s:restart()
            local summary = reconcile.run(s.journal, s.world.native)
            assert_eq(summary.MANUAL_REVIEW_REQUIRED, 1)
            assert_eq(s.journal:status("op"), "MANUAL_REVIEW_REQUIRED")
            assert_true(s.journal:blocks_pal("pal"))
            assert_eq(#s.world.attempts, 0)
        end
    end)

    it("UT-039 quarantines competing pending ops and indistinct location records", function()
        local s, src = fixture()
        assert(s.journal:prepare({ op = "other", world = "world", pal = "pal", src = src, dst = "box-A" }))
        assert_eq(reconcile.run(s.journal, s.world.native).MANUAL_REVIEW_REQUIRED, 2)
        assert(s.journal:prepare({ op = "later", world = "world", pal = "pal", src = src, dst = "box-A" }))
        assert_eq(reconcile.run(s.journal, s.world.native).MANUAL_REVIEW_REQUIRED, 1)
        local _, row = s.journal:status("later")
        assert_eq(row.reason, "OTHER_PENDING_OPERATION")

        s = fake.scenario({ pal = "A" })
        assert(s.journal:prepare({ op = "same", world = "world", pal = "pal", src = "worker-1", dst = "worker-1" }))
        assert_eq(reconcile.run(s.journal, s.world.native).MANUAL_REVIEW_REQUIRED, 1)
    end)

    it("reports persistence errors and leaves unrecorded recovery pending", function()
        local s = fixture()
        s.backend.fail_write = true
        local summary = reconcile.run(s.journal, s.world.native)
        assert_eq(summary.ABORTED_SAFE, 0)
        assert_eq(summary.errors[1].operation_id, "op")
        assert_eq(summary.errors[1].error, "PERSISTENCE_FAILED")
        assert_eq(s.journal:status("op"), "PREPARED")
        assert_eq(reconcile.run(s.journal, s.world.native).error, "PERSISTENCE_FAILED")
        assert_eq(#s.world.calls, 1)
        assert_eq(#s.world.attempts, 0)
    end)
end)
