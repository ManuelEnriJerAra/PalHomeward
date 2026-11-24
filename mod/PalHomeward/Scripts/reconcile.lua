-- Reconcile before accepting requests after a restart. The native read must
-- enumerate every active location of the instance and report whether another
-- operation is active. Unknown or inconsistent state requires manual review.
local reconcile = {}

function reconcile.only_at(state, world_id, pal_id, location)
    if type(state) ~= "table" or state.world_id ~= world_id or state.pal_id ~= pal_id
        or state.has_active_operation ~= false or type(location) ~= "string" or location == "" then
        return false
    end
    local locations = state.locations
    return type(locations) == "table" and locations[1] == location
        and next(locations) == 1 and next(locations, 1) == nil
end

function reconcile.run(journal, native)
    local summary = { CONFIRMED_RECOVERED = 0, ABORTED_SAFE = 0, MANUAL_REVIEW_REQUIRED = 0, errors = {} }
    if journal.safe_mode then
        summary.error = journal.warning or "PERSISTENCE_FAILED"
        return summary
    end
    local pending = journal:pending()
    local other_active = {}
    for _, op in ipairs(pending) do
        other_active[op.op] = journal:blocks_pal(op.pal, op.op)
    end
    for _, op in ipairs(pending) do
        local status, reason = "MANUAL_REVIEW_REQUIRED", "AMBIGUOUS_LOCATION"
        local ok, state = pcall(native.read_fresh_state, op.pal)
        if other_active[op.op] then
            reason = "OTHER_PENDING_OPERATION"
        elseif not ok or type(state) ~= "table" then
            reason = "RECOVERY_READ_FAILED"
        elseif op.src == op.dst then
            reason = "INDISTINCT_LOCATIONS"
        elseif reconcile.only_at(state, op.world, op.pal, op.dst) then
            status, reason = "CONFIRMED_RECOVERED", "AT_DESTINATION"
        elseif reconcile.only_at(state, op.world, op.pal, op.src) then
            status, reason = "ABORTED_SAFE", "AT_SOURCE"
        end

        local recorded, err = journal:record_recovery(op.op, status, reason)
        if not recorded then
            summary.errors[#summary.errors + 1] = { operation_id = op.op, error = err }
            break
        end
        summary[recorded] = summary[recorded] + 1
    end
    return summary
end

return reconcile
