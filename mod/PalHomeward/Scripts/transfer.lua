-- Adapter contract (plain values, dot calls):
-- read_fresh_state(pal_id) returns { world_id, pal_id, locations = { location_id, ... },
-- has_active_operation, worker = { base_id, slot, location }? }. locations covers all
-- active occurrences, including duplicates. A worker location identifies the exact slot.
-- resolve_owner_storage(owner_uid) returns { id = location_id, owner_uid }.
-- can_safely_accept(dst, state) checks the current storage mapping and returns the
-- four policy destination flags. execute_move_once(state, dst) returns { success = true }
-- on success. Every adapter call may return nil, err. context is server-owned and
-- supplies server_authority, actor_may_manage and the policy preflight facts.
-- Use one coordinator per world, with a world-bound ownership registry. The
-- injected clock returns the operation start time as integer wall-clock seconds.
local policy = require("policy")
local reconcile = require("reconcile")

local transfer = {}
local Coordinator = {}
Coordinator.__index = Coordinator

local function result(request, decision, code)
    request = type(request) == "table" and request or {}
    return {
        operation_id = request.operation_id, world_id = request.world_id, pal_id = request.pal_id,
        decision = decision, code = code,
    }
end

local function deny(request, code)
    return result(request, "DENY", code)
end

function transfer.new(deps)
    return setmetatable({
        journal = deps.journal, registry = deps.registry, policy = deps.policy,
        native = deps.native, clock = deps.clock, locks = deps.locks or {},
        registry_world = deps.registry:snapshot().worldId,
        after_prepared = deps.after_prepared, -- Test hook for an interruption at this boundary.
        active_ops = {}, native_calls = {},
    }, Coordinator)
end

function Coordinator:call_native(method, ...)
    local thread = coroutine.running()
    self.native_calls[thread] = true
    local ok, response, err = pcall(self.native[method], ...)
    self.native_calls[thread] = nil
    if ok then
        return response, err
    end
    return nil, "ADAPTER_ERROR"
end

local function source_facts(state, request)
    local worker = state.worker
    local is_worker_in = type(worker) == "table" and worker.base_id == request.base_id
        and reconcile.only_at(state, request.world_id, request.pal_id, worker.location)
    return { is_worker_in = is_worker_in, slot_matches = is_worker_in and worker.slot == request.source_slot }
end

local abort_codes = {
    DENY_OWNER_STORAGE_UNAVAILABLE = true, DENY_DESTINATION_FULL = true,
    DENY_CONCURRENT_OPERATION = true, DENY_UNKNOWN_OWNER = true,
}

local function previous_result(request, status, op)
    if op.pal ~= request.pal_id or op.actor ~= request.actor_uid then
        return deny(request, "DENY_CONCURRENT_OPERATION")
    end
    if status == "CONFIRMED" or status == "CONFIRMED_RECOVERED" then
        return result(request, "REDIRECT", "OK_RETURNED_TO_OWNER")
    end
    if status == "ABORTED_SAFE" then
        return deny(request, abort_codes[op.reason] and op.reason or "DENY_SOURCE_CHANGED")
    end
    if status == "MANUAL_REVIEW_REQUIRED" then
        return deny(request, "ERROR_RECONCILIATION_REQUIRED")
    end
    return deny(request, "DENY_CONCURRENT_OPERATION")
end

function Coordinator:uncertain(request, reason, timestamp)
    self.journal:require_reconciliation(request.operation_id, reason, timestamp)
    return deny(request, "ERROR_RECONCILIATION_REQUIRED")
end

function Coordinator:abort(request, code, timestamp)
    if not self.journal:record_recovery(request.operation_id, "ABORTED_SAFE", code, timestamp) then
        return deny(request, "ERROR_PERSISTENCE_FAILED")
    end
    return deny(request, code)
end

function Coordinator:handle_locked(request, facts)
    local pal, op = request.pal_id, request.operation_id
    local state = self:call_native("read_fresh_state", pal)
    if type(state) ~= "table" or state.pal_id ~= pal or state.world_id ~= request.world_id then
        return deny(request, "DENY_UNKNOWN_PAL")
    end

    local source = source_facts(state, request)
    facts.source_state = source
    local dst
    if source.slot_matches then
        facts.owner = self.registry:resolve(pal)
        local owner = facts.owner
        if type(owner) == "table" and owner.status == "VERIFIED" and type(owner.owner_uid) == "string"
            and owner.owner_uid ~= "" and facts.actor_may_manage == true then
            dst = self:call_native("resolve_owner_storage", owner.owner_uid)
            if type(dst) == "table" and dst.owner_uid == owner.owner_uid
                and type(dst.id) == "string" and dst.id ~= "" and dst.id ~= state.worker.location then
                facts.destination = self:call_native("can_safely_accept", dst, state)
            else
                facts.destination = { resolved = false, available = false, has_space = false, locked = false }
            end
        end
    end
    local chosen = self.policy.decide(request, facts)
    if chosen.decision ~= "REDIRECT" then
        return result(request, chosen.decision, chosen.code)
    end

    local src, destination_id = state.worker.location, dst.id
    local timestamp = self.clock()
    local prepared = self.journal:prepare({
        op = op, world = request.world_id, pal = pal, actor = request.actor_uid,
        owner = chosen.owner_uid, src = src, dst = destination_id, t = timestamp,
    })
    if prepared ~= "PREPARED" then
        return deny(request, "ERROR_PERSISTENCE_FAILED")
    end
    if self.after_prepared then
        self.after_prepared(op)
    end
    if not self.journal:executing(op, timestamp) then
        return deny(request, "ERROR_PERSISTENCE_FAILED")
    end

    local fresh = self:call_native("read_fresh_state", pal)
    if not reconcile.only_at(fresh, request.world_id, pal, src) then
        return self:uncertain(request, "SOURCE_UNCERTAIN", timestamp)
    end
    if not source_facts(fresh, request).slot_matches then
        return self:abort(request, "DENY_SOURCE_CHANGED", timestamp)
    end
    local owner = self.registry:resolve(pal)
    if type(owner) ~= "table" or owner.status ~= "VERIFIED" or owner.owner_uid ~= chosen.owner_uid then
        return self:abort(request, "DENY_UNKNOWN_OWNER", timestamp)
    end

    facts.destination = self:call_native("can_safely_accept", dst, fresh)
    local checked = self.policy.decide(request, facts)
    if checked.decision ~= "REDIRECT" then
        return self:abort(request, checked.code, timestamp)
    end
    if self.journal.safe_mode then
        return deny(request, "ERROR_PERSISTENCE_FAILED")
    end
    fresh.operation_id = op
    local outcome, move_error = self:call_native("execute_move_once", fresh, dst)
    local final = self:call_native("read_fresh_state", pal)
    if type(outcome) ~= "table" or outcome.success ~= true then
        local reason = move_error == "TIMEOUT" and "NATIVE_TIMEOUT" or "NATIVE_MOVE_FAILED"
        return self:uncertain(request, reason, timestamp)
    end
    if type(final) ~= "table" then
        return self:uncertain(request, "CONFIRMATION_READ_FAILED", timestamp)
    end
    if not reconcile.only_at(final, request.world_id, pal, destination_id) then
        return self:uncertain(request, "FINAL_LOCATION_UNCERTAIN", timestamp)
    end
    if not self.journal:confirm(op, timestamp) then
        return self:uncertain(request, "CONFIRMATION_WRITE_FAILED", timestamp)
    end
    return result(request, chosen.decision, chosen.code)
end

function Coordinator:handle_worker_removal(request, context)
    if self.native_calls[coroutine.running()] then
        return deny(request, "DENY_CONCURRENT_OPERATION")
    end
    if type(context) ~= "table" or context.server_authority ~= true then
        return deny(request, "DENY_UNAUTHORIZED_ACTOR")
    end
    local facts = {
        mode = context.mode, capabilities = context.capabilities,
        build_supported = context.build_supported, current_world_id = context.current_world_id,
        actor_may_manage = context.actor_may_manage,
    }
    local early = policy.preflight(request, facts)
    if early then
        return result(request, early.decision, early.code)
    end
    if request.world_id ~= self.journal.world_id or request.world_id ~= self.registry_world then
        return deny(request, "DENY_UNKNOWN_PAL")
    end

    local pal, op = request.pal_id, request.operation_id
    local status, previous = self.journal:status(op)
    if status then
        return previous_result(request, status, previous)
    end
    if self.journal.safe_mode then
        return deny(request, "ERROR_PERSISTENCE_FAILED")
    end
    if self.locks[pal] or self.active_ops[op] or self.journal:blocks_pal(pal) then
        return deny(request, "DENY_CONCURRENT_OPERATION")
    end
    self.locks[pal], self.active_ops[op] = true, true
    local ok, response = pcall(self.handle_locked, self, request, facts)
    self.locks[pal], self.active_ops[op] = nil, nil
    if not ok then
        error(response, 0)
    end
    return response
end

return transfer
