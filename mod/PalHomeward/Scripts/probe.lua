local values = require("ue_values")

local probe = {}
local attempted = {}
local session
local max_errors_per_hook = 5

local function shorten(text, limit)
    if #text > limit then
        return text:sub(1, limit - 3) .. "..."
    end
    return text
end

local function token(value)
    if type(value) == "string" then
        return (shorten(value, 160):gsub("%s", "_"))
    end
    return value
end

local function error_text(err)
    if type(err) == "string" then
        return shorten(err, 512)
    end
    return "error of type " .. type(err)
end

local function emit(state, level, event, fields)
    fields.session = state.id
    state.logger[level](state.logger, event, fields)
end

local function log_callback_error(state, hook, phase, err)
    local errors = state.errors[hook]
    if not errors then
        errors = { count = 0, seen = {} }
        state.errors[hook] = errors
    end
    if errors.count >= max_errors_per_hook then
        return
    end
    local reason = error_text(err)
    if not errors.seen[reason] then
        errors.seen[reason] = true
        errors.count = errors.count + 1
        emit(state, "error", "probe.error", { hook = hook, phase = phase, error = reason })
    end
end

local function observe(state, target, phase, context, ...)
    state.seq = state.seq + 1
    local obj, context_error = values.read_param(context)
    local name
    if obj ~= nil then
        name, context_error = values.safe_full_name(obj)
    end
    local fields = {
        hook = target.id, phase = phase, seq = state.seq, t = state.clock(),
        ctx = token(name) or "UNAVAILABLE",
    }
    local failure = context_error and ("ctx: " .. context_error)
    for i, param in ipairs(target.params) do
        local value, err = values.read_param((select(i, ...)))
        if err == nil then
            value, err = values.describe(value, param.type)
        end
        if err then
            fields[param.name] = "UNAVAILABLE"
            failure = failure or (param.name .. ": " .. err)
        elseif type(value) == "table" then
            -- Keep field names visible to the logger's UID redaction.
            for key, field in pairs(value) do
                fields[param.name .. "." .. key] = token(field)
            end
        else
            fields[param.name] = token(value)
        end
    end
    emit(state, "info", "probe.event", fields)
    return failure
end

local function callback(state, target, phase)
    local function dispatch(context, ...)
        if not state.active or not state.registered[target.path] then
            return
        end
        if state.busy then
            if not state.reporting_reentry then
                state.reporting_reentry = true
                pcall(emit, state, "warn", "probe.reentrant", { hook = target.id, phase = phase })
                state.reporting_reentry = false
            end
            return
        end
        state.busy = true
        -- TO_VERIFY: native delivery thread and phase per target. Read synchronously
        -- in this callback and discard all wrappers before returning to UE4SS.
        local ok, failure = pcall(observe, state, target, phase, context, ...)
        if not ok or failure then
            pcall(log_callback_error, state, target.id, phase, failure)
        end
        state.busy = false
    end
    return function(...)
        pcall(dispatch, ...)
    end
end

function probe.start(deps)
    if session then
        return
    end

    local state = {
        active = true, seq = 0, registered = {}, errors = {},
        logger = deps.logger, clock = deps.clock, id = token(deps.session_id),
        unregister = deps.unregister_hook,
    }
    session = state

    for _, target in ipairs(deps.targets) do
        if not attempted[target.path] then
            -- RegisterHook resolves the loaded function. Keep the attempt even if it throws.
            attempted[target.path] = true
            local ok, pre_id, post_id = pcall(deps.register_hook, target.path,
                callback(state, target, "PRE"), callback(state, target, "POST"))
            if ok then
                state.registered[target.path] = { pre_id = pre_id, post_id = post_id }
                pcall(emit, state, "info", "probe.hook.registered", {
                    id = target.id, path = target.path, pre_id = pre_id, post_id = post_id,
                })
            else
                pcall(emit, state, "warn", "probe.hook.unavailable", {
                    id = target.id, path = target.path, error = error_text(pre_id),
                })
            end
        end
    end
end

function probe.stop()
    local state = session
    if not state then
        return
    end
    state.active = false
    if type(state.unregister) == "function" then
        for path, pair in pairs(state.registered) do
            local ok, err = pcall(state.unregister, path, pair.pre_id, pair.post_id)
            if ok then
                state.registered[path] = nil
            else
                pcall(emit, state, "warn", "probe.hook.unregister_failed", {
                    path = path, error = error_text(err),
                })
            end
        end
        if next(state.registered) then
            return
        end
    end
    session = nil
end

return probe
