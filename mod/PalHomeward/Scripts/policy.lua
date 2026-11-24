-- Plan 6.3 order: hook/build safety, normalized request and world, current
-- worker and slot, verified owner, actor permission, then owner storage.
-- A fully validated request can use the normal self-removal path or redirect.
-- Ownership comes only from facts.owner. A redirect code describes intent.
local policy = {}

local function has_id(value)
    return type(value) == "string" and value ~= ""
end

local function decision(kind, code, reason, owner_uid)
    return { decision = kind, code = code, reasons = { reason }, owner_uid = owner_uid }
end

function policy.preflight(request, facts)
    local mode = type(facts) == "table" and facts.mode
    if mode == "OBSERVE" then
        return decision("OBSERVE_ONLY", "ERROR_HOOK_NOT_VERIFIED", "OBSERVE_MODE")
    end
    if mode ~= "AUTO_RETURN" and mode ~= "PROTECT" then
        return decision("DENY", "DENY_UNSUPPORTED_TRANSFER_PATH", "INVALID_MODE")
    end
    local capabilities = facts.capabilities
    if type(capabilities) ~= "table" or not has_id(capabilities.PRE_MUTATION_INTERCEPTION)
        or not has_id(capabilities.CANCEL_OR_REDIRECT) then
        return decision("DENY", "ERROR_HOOK_NOT_VERIFIED", "INVALID_CAPABILITIES")
    end
    if capabilities.PRE_MUTATION_INTERCEPTION ~= "VERIFIED" or capabilities.CANCEL_OR_REDIRECT ~= "VERIFIED" then
        return decision("OBSERVE_ONLY", "ERROR_HOOK_NOT_VERIFIED", "UNVERIFIED_CAPABILITY")
    end
    if type(facts.build_supported) ~= "boolean" then
        return decision("DENY", "ERROR_GAME_BUILD_UNSUPPORTED", "INVALID_BUILD_STATUS")
    end
    if not facts.build_supported then
        return decision("OBSERVE_ONLY", "ERROR_GAME_BUILD_UNSUPPORTED", "UNSUPPORTED_BUILD")
    end
    if type(request) ~= "table" or not has_id(request.pal_id) then
        return decision("DENY", "DENY_UNKNOWN_PAL", "INVALID_PAL")
    end
    local slot = request.source_slot
    local valid_slot = has_id(slot) or (math.type(slot) == "integer" and slot >= 0)
    if not (has_id(request.operation_id) and has_id(request.world_id) and has_id(request.actor_uid)
        and has_id(request.base_id) and valid_slot) then
        return decision("DENY", "DENY_UNSUPPORTED_TRANSFER_PATH", "INVALID_REQUEST")
    end
    if not has_id(facts.current_world_id) then
        return decision("DENY", "DENY_UNKNOWN_PAL", "INVALID_WORLD")
    end
    if request.world_id ~= facts.current_world_id then
        return decision("DENY", "DENY_UNKNOWN_PAL", "WORLD_MISMATCH")
    end
end

function policy.decide(request, facts)
    local early = policy.preflight(request, facts)
    if early then
        return early
    end
    local source = facts.source_state
    if type(source) ~= "table" or type(source.is_worker_in) ~= "boolean" or type(source.slot_matches) ~= "boolean" then
        return decision("DENY", "DENY_SOURCE_CHANGED", "INVALID_SOURCE")
    end
    if not source.is_worker_in then
        return decision("DENY", "DENY_SOURCE_CHANGED", "NOT_A_WORKER")
    end
    if not source.slot_matches then
        return decision("DENY", "DENY_SOURCE_CHANGED", "SLOT_CHANGED")
    end

    local owner = facts.owner
    if type(owner) ~= "table" then
        return decision("DENY", "DENY_UNKNOWN_OWNER", "INVALID_OWNER")
    end
    if owner.status == "UNRESOLVED" then
        return decision("DENY", "DENY_UNKNOWN_OWNER", "NO_VERIFIED_OWNER")
    end
    if owner.status == "CONFLICT" then
        return decision("DENY", "DENY_UNKNOWN_OWNER", "OWNER_CONFLICT")
    end
    if owner.status ~= "VERIFIED" or not has_id(owner.owner_uid) then
        return decision("DENY", "DENY_UNKNOWN_OWNER", "INVALID_OWNER")
    end
    local owner_uid = owner.owner_uid
    if type(facts.actor_may_manage) ~= "boolean" then
        return decision("DENY", "DENY_UNAUTHORIZED_ACTOR", "INVALID_PERMISSION", owner_uid)
    end
    if not facts.actor_may_manage then
        return decision("DENY", "DENY_UNAUTHORIZED_ACTOR", "ACTOR_NOT_AUTHORIZED", owner_uid)
    end

    local dst = facts.destination
    if type(dst) ~= "table" or type(dst.resolved) ~= "boolean" or type(dst.available) ~= "boolean"
        or type(dst.has_space) ~= "boolean" or type(dst.locked) ~= "boolean" then
        return decision("DENY", "DENY_OWNER_STORAGE_UNAVAILABLE", "INVALID_DESTINATION", owner_uid)
    end
    if not dst.resolved then
        return decision("DENY", "DENY_OWNER_STORAGE_UNAVAILABLE", "DESTINATION_UNRESOLVED", owner_uid)
    end
    if not dst.available then
        return decision("DENY", "DENY_OWNER_STORAGE_UNAVAILABLE", "DESTINATION_UNAVAILABLE", owner_uid)
    end
    if not dst.has_space then
        return decision("DENY", "DENY_DESTINATION_FULL", "DESTINATION_FULL", owner_uid)
    end
    if dst.locked then
        return decision("DENY", "DENY_CONCURRENT_OPERATION", "DESTINATION_LOCKED", owner_uid)
    end
    if owner_uid == request.actor_uid then
        return decision("ALLOW", "OK_OWNER_SELF_REMOVAL", "OWNER_SELF_REMOVAL", owner_uid)
    end
    if facts.mode == "PROTECT" then
        return decision("DENY", "DENY_UNSUPPORTED_TRANSFER_PATH", "PROTECTION_ONLY", owner_uid)
    end
    return decision("REDIRECT", "OK_RETURNED_TO_OWNER", "RETURN_TO_OWNER", owner_uid)
end

return policy
