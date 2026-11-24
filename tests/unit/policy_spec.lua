local policy = require("policy")

local function fixture()
    return {
        operation_id = "op", world_id = "world", pal_id = "pal",
        actor_uid = "B", base_id = "base", source_slot = 0,
    }, {
        mode = "AUTO_RETURN", build_supported = true, current_world_id = "world",
        capabilities = { PRE_MUTATION_INTERCEPTION = "VERIFIED", CANCEL_OR_REDIRECT = "VERIFIED" },
        source_state = { is_worker_in = true, slot_matches = true },
        owner = { status = "VERIFIED", owner_uid = "A" },
        actor_may_manage = true,
        destination = { resolved = true, available = true, has_space = true, locked = false },
    }
end

local function check(request, facts, decision, code, reason, owner)
    local result = policy.decide(request, facts)
    assert_eq(result.decision, decision)
    assert_eq(result.code, code)
    assert_eq(result.reasons[1], reason)
    assert_eq(result.owner_uid, owner)
end

describe("worker removal policy", function()
    it("UT-001, UT-043 returns to verified owner and ignores request ownership", function()
        local request, facts = fixture()
        request.owner_uid = "B"
        for _ = 1, 2 do
            check(request, facts, "REDIRECT", "OK_RETURNED_TO_OWNER", "RETURN_TO_OWNER", "A")
        end
        assert_eq(request.owner_uid, "B")
        assert_eq(facts.owner.owner_uid, "A")
    end)

    it("UT-002 allows own-worker removal in both enabled modes", function()
        local request, facts = fixture()
        request.actor_uid = "A"
        for _, mode in ipairs({ "AUTO_RETURN", "PROTECT" }) do
            facts.mode = mode
            check(request, facts, "ALLOW", "OK_OWNER_SELF_REMOVAL", "OWNER_SELF_REMOVAL", "A")
        end
    end)

    it("UT-006 rejects a different world before examining an invalid source", function()
        local request, facts = fixture()
        request.world_id, facts.source_state = "other", nil
        check(request, facts, "DENY", "DENY_UNKNOWN_PAL", "WORLD_MISMATCH")
    end)

    it("UT-016, UT-017 rejects a stale slot or a Pal that is no longer working", function()
        local request, facts = fixture()
        facts.source_state.slot_matches, facts.owner = false, nil
        check(request, facts, "DENY", "DENY_SOURCE_CHANGED", "SLOT_CHANGED")
        facts.source_state.is_worker_in = false
        check(request, facts, "DENY", "DENY_SOURCE_CHANGED", "NOT_A_WORKER")
    end)

    it("UT-004, UT-005 hides unverified and conflicting owners", function()
        local request, facts = fixture()
        facts.owner.status = "UNRESOLVED"
        check(request, facts, "DENY", "DENY_UNKNOWN_OWNER", "NO_VERIFIED_OWNER")
        facts.owner.status = "CONFLICT"
        check(request, facts, "DENY", "DENY_UNKNOWN_OWNER", "OWNER_CONFLICT")
    end)

    it("UT-015 rejects missing permission before destination checks", function()
        local request, facts = fixture()
        facts.actor_may_manage, facts.destination = false, nil
        check(request, facts, "DENY", "DENY_UNAUTHORIZED_ACTOR", "ACTOR_NOT_AUTHORIZED", "A")
    end)

    it("UT-013 rejects unresolved or unavailable storage", function()
        local request, facts = fixture()
        facts.destination.resolved = false
        check(request, facts, "DENY", "DENY_OWNER_STORAGE_UNAVAILABLE", "DESTINATION_UNRESOLVED", "A")
        facts.destination.resolved, facts.destination.available = true, false
        check(request, facts, "DENY", "DENY_OWNER_STORAGE_UNAVAILABLE", "DESTINATION_UNAVAILABLE", "A")
    end)

    it("UT-014, UT-021 rejects full or locked storage in that order", function()
        local request, facts = fixture()
        facts.destination.has_space, facts.destination.locked = false, true
        check(request, facts, "DENY", "DENY_DESTINATION_FULL", "DESTINATION_FULL", "A")
        facts.destination.has_space = true
        check(request, facts, "DENY", "DENY_CONCURRENT_OPERATION", "DESTINATION_LOCKED", "A")
    end)

    it("denies cross-owner removal in protection mode", function()
        local request, facts = fixture()
        facts.mode = "PROTECT"
        check(request, facts, "DENY", "DENY_UNSUPPORTED_TRANSFER_PATH", "PROTECTION_ONLY", "A")
    end)

    it("UT-040 observes in OBSERVE mode or when either hook capability lacks verification", function()
        local request, facts = fixture()
        facts.mode, facts.build_supported = "OBSERVE", false
        check(request, facts, "OBSERVE_ONLY", "ERROR_HOOK_NOT_VERIFIED", "OBSERVE_MODE")
        facts.mode = "AUTO_RETURN"
        for name in pairs(facts.capabilities) do
            facts.capabilities[name] = "OBSERVED"
            check(request, facts, "OBSERVE_ONLY", "ERROR_HOOK_NOT_VERIFIED", "UNVERIFIED_CAPABILITY")
            facts.capabilities[name] = "VERIFIED"
        end
    end)

    it("UT-041 observes on a known unsupported build", function()
        local request, facts = fixture()
        facts.build_supported = false
        check(request, facts, "OBSERVE_ONLY", "ERROR_GAME_BUILD_UNSUPPORTED", "UNSUPPORTED_BUILD")
    end)

    it("fails closed on absent or invalid request and fact fields", function()
        local request, facts = fixture()
        check(request, nil, "DENY", "DENY_UNSUPPORTED_TRANSFER_PATH", "INVALID_MODE")
        local cases = {
            { facts, "mode", "INVALID_MODE", "DENY_UNSUPPORTED_TRANSFER_PATH" },
            { facts, "capabilities", "INVALID_CAPABILITIES", "ERROR_HOOK_NOT_VERIFIED" },
            { facts.capabilities, "PRE_MUTATION_INTERCEPTION", "INVALID_CAPABILITIES", "ERROR_HOOK_NOT_VERIFIED" },
            { facts.capabilities, "CANCEL_OR_REDIRECT", "INVALID_CAPABILITIES", "ERROR_HOOK_NOT_VERIFIED" },
            { facts, "build_supported", "INVALID_BUILD_STATUS", "ERROR_GAME_BUILD_UNSUPPORTED" },
            { facts, "current_world_id", "INVALID_WORLD", "DENY_UNKNOWN_PAL" },
            { facts, "source_state", "INVALID_SOURCE", "DENY_SOURCE_CHANGED" },
            { facts.source_state, "is_worker_in", "INVALID_SOURCE", "DENY_SOURCE_CHANGED" },
            { facts.source_state, "slot_matches", "INVALID_SOURCE", "DENY_SOURCE_CHANGED" },
            { facts, "owner", "INVALID_OWNER", "DENY_UNKNOWN_OWNER" },
            { facts.owner, "status", "INVALID_OWNER", "DENY_UNKNOWN_OWNER" },
            { facts.owner, "owner_uid", "INVALID_OWNER", "DENY_UNKNOWN_OWNER" },
            { facts, "actor_may_manage", "INVALID_PERMISSION", "DENY_UNAUTHORIZED_ACTOR", "A" },
            { facts, "destination", "INVALID_DESTINATION", "DENY_OWNER_STORAGE_UNAVAILABLE", "A" },
        }
        for _, field in ipairs({ "resolved", "available", "has_space", "locked" }) do
            cases[#cases + 1] = {
                facts.destination, field, "INVALID_DESTINATION", "DENY_OWNER_STORAGE_UNAVAILABLE", "A",
            }
        end
        for _, case in ipairs(cases) do
            local input, key, reason, code, owner = table.unpack(case)
            local saved = input[key]
            for _, value in ipairs({ {}, 42 }) do
                -- A malformed destination table also exercises its required boolean fields.
                input[key] = value
                check(request, facts, "DENY", code, reason, owner)
            end
            input[key] = nil
            check(request, facts, "DENY", code, reason, owner)
            input[key] = saved
        end
        check(nil, facts, "DENY", "DENY_UNKNOWN_PAL", "INVALID_PAL")
        for _, field in ipairs({ "pal_id", "operation_id", "world_id", "actor_uid", "base_id", "source_slot" }) do
            local saved = request[field]
            local code, reason = "DENY_UNSUPPORTED_TRANSFER_PATH", "INVALID_REQUEST"
            if field == "pal_id" then
                code, reason = "DENY_UNKNOWN_PAL", "INVALID_PAL"
            end
            for _, value in ipairs({ {}, "", -1, false }) do
                request[field] = value
                check(request, facts, "DENY", code, reason)
            end
            request[field] = saved
        end
        request.source_slot = "slot"
        check(request, facts, "REDIRECT", "OK_RETURNED_TO_OWNER", "RETURN_TO_OWNER", "A")
    end)
end)
