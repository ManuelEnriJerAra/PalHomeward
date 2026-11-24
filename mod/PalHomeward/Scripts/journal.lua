-- Append-only decisions for one world and one writer. A backend appends one
-- logical line (without its delimiter) and reads a dense array of lines.
-- read_lines may also report whether the final line ended in LF. Optional
-- flush must succeed before a record enters the in-memory index.
-- NEW is implicit. status returns a state and a detached copy of the last row.
local jsonl = require("jsonl")

local journal = {}

local recovery_states = {
    CONFIRMED_RECOVERED = true, ABORTED_SAFE = true, MANUAL_REVIEW_REQUIRED = true,
}
local transitions = {
    NEW = { PREPARED = true },
    PREPARED = { EXECUTING = true, RECONCILIATION_REQUIRED = true },
    EXECUTING = { CONFIRMED = true, RECONCILIATION_REQUIRED = true },
    RECONCILIATION_REQUIRED = {},
}
for state in pairs(recovery_states) do
    for _, prior in ipairs({ "PREPARED", "EXECUTING", "RECONCILIATION_REQUIRED" }) do
        transitions[prior][state] = true
    end
end

local function is_pending(state)
    return state == "PREPARED" or state == "EXECUTING" or state == "RECONCILIATION_REQUIRED"
end

local function blocks_pal(state)
    return is_pending(state) or state == "MANUAL_REVIEW_REQUIRED"
end

local function has_id(value)
    return type(value) == "string" and value ~= ""
end

local function nonnegative_integer(value)
    return math.type(value) == "integer" and value >= 0
end

local immutable = { "op", "world", "pal", "owner", "actor", "src", "dst" }
local optional = { "owner", "actor", "src", "dst", "reason" }
local fields = { v = true, op = true, world = true, pal = true, state = true, t = true, seq = true }
for _, key in ipairs(optional) do
    fields[key] = true
end

local function valid_row(row)
    if type(row) ~= "table" or getmetatable(row) or row.v ~= 1 or math.type(row.v) ~= "integer"
        or not has_id(row.op) or not has_id(row.world) or not has_id(row.pal) or not has_id(row.state)
        or not nonnegative_integer(row.t) or not nonnegative_integer(row.seq) then
        return false
    end
    for _, key in ipairs(optional) do
        if row[key] ~= nil and not has_id(row[key]) then
            return false
        end
    end
    for key in pairs(row) do
        if not fields[key] then
            return false
        end
    end
    return true
end

local function valid_transition(previous, row)
    local choices = transitions[previous and previous.state or "NEW"]
    if not choices or not choices[row.state] then
        return false
    end
    if previous then
        for _, key in ipairs(immutable) do
            if previous[key] ~= row[key] then
                return false
            end
        end
    end
    return true
end

local function copy(row)
    local detached = {}
    for key, value in pairs(row) do
        detached[key] = value
    end
    return detached
end

function journal.open(backend, world_id)
    if not has_id(world_id) then
        return nil, "INVALID_WORLD_ID"
    end
    if type(backend) ~= "table" or type(backend.append) ~= "function" or type(backend.read_lines) ~= "function"
        or (backend.flush ~= nil and type(backend.flush) ~= "function") then
        return nil, "INVALID_BACKEND"
    end
    local read_ok, lines, tail_terminated = pcall(backend.read_lines)
    if not read_ok or type(lines) ~= "table" then
        return nil, "PERSISTENCE_FAILED"
    end
    local count, last = 0, 0
    for index in pairs(lines) do
        if math.type(index) ~= "integer" or index < 1 then
            return nil, "PERSISTENCE_FAILED"
        end
        count = count + 1
        last = math.max(last, index)
    end
    if count ~= last then
        return nil, "PERSISTENCE_FAILED"
    end

    local j = { safe_mode = false, world_id = world_id }
    local rows, pending, blocked = {}, {}, {}
    local seq, writing = 0, false

    local function apply(row)
        local previous = rows[row.op]
        local blocked_count = blocked[row.pal] or 0
        if previous and blocks_pal(previous.state) then
            blocked_count = blocked_count - 1
        end
        if blocks_pal(row.state) then
            blocked_count = blocked_count + 1
        end
        blocked[row.pal] = blocked_count > 0 and blocked_count or nil
        pending[row.op] = is_pending(row.state) and row or nil
        rows[row.op], seq = row, row.seq
    end

    for index = 1, count do
        local row, parse_error = jsonl.decode(lines[index])
        if index == count and tail_terminated ~= true and lines[index] ~= "" and parse_error == "TRUNCATED_JSON" then
            j.safe_mode, j.warning = true, "TRUNCATED_TAIL"
            break
        end
        if type(row) == "table" and math.type(row.v) == "integer" and row.v > 1 then
            return nil, "UNSUPPORTED_SCHEMA"
        end
        if not valid_row(row) or row.seq ~= index or not valid_transition(rows[row.op], row) then
            return nil, "CORRUPT_JOURNAL"
        end
        if row.world ~= world_id then
            return nil, "WORLD_MISMATCH"
        end
        if index == count and tail_terminated == false then
            j.safe_mode, j.warning = true, "TRUNCATED_TAIL"
            break
        end
        apply(row)
    end

    local function write(row)
        if j.safe_mode or writing or seq == math.maxinteger then
            return nil, "PERSISTENCE_FAILED"
        end
        row.v, row.seq = 1, seq + 1
        if not valid_row(row) then
            return nil, "INVALID_OPERATION"
        end
        if row.world ~= world_id then
            return nil, "WORLD_MISMATCH"
        end
        local line = jsonl.encode(row)
        if not line then
            return nil, "INVALID_OPERATION"
        end

        writing = true
        local ok, persisted = pcall(function()
            if backend.append(line) then
                return not backend.flush or backend.flush()
            end
        end)
        writing = false
        if not ok or not persisted then
            -- The failed write may have left bytes on disk. Reopen and replay
            -- before appending anything else.
            j.safe_mode = true
            return nil, "PERSISTENCE_FAILED"
        end
        apply(row)
        return row.state
    end

    function j:status(op_id)
        local row = rows[op_id]
        if row then
            return row.state, copy(row)
        end
    end

    function j:pending()
        local result = {}
        for _, row in pairs(pending) do
            result[#result + 1] = copy(row)
        end
        table.sort(result, function(first, second) return first.seq < second.seq end)
        return result
    end

    function j:blocks_pal(pal_id, except_operation)
        local excluded = rows[except_operation]
        local count = blocked[pal_id] or 0
        if excluded and excluded.pal == pal_id and blocks_pal(excluded.state) then
            count = count - 1
        end
        return count > 0
    end

    function j:prepare(op)
        if type(op) ~= "table" or not has_id(op.op) then
            return nil, "INVALID_OPERATION"
        end
        local previous = rows[op.op]
        if previous then
            return previous.state
        end
        local row = { state = "PREPARED", t = op.t }
        if row.t == nil then
            row.t = os.time()
        end
        for _, key in ipairs(immutable) do
            row[key] = op[key]
        end
        return write(row)
    end

    local function advance(op_id, state, reason, timestamp)
        local previous = rows[op_id]
        local choices = previous and transitions[previous.state]
        if not choices or not choices[state] then
            return nil, "ILLEGAL_TRANSITION"
        end
        local row = copy(previous)
        row.state, row.reason, row.t = state, reason, timestamp
        if row.t == nil then
            row.t = os.time()
        end
        return write(row)
    end

    function j:executing(op_id, timestamp)
        return advance(op_id, "EXECUTING", nil, timestamp)
    end

    function j:confirm(op_id, timestamp)
        return advance(op_id, "CONFIRMED", nil, timestamp)
    end

    function j:require_reconciliation(op_id, reason, timestamp)
        return advance(op_id, "RECONCILIATION_REQUIRED", reason, timestamp)
    end

    function j:record_recovery(op_id, state, reason, timestamp)
        if not recovery_states[state] then
            return nil, "ILLEGAL_TRANSITION"
        end
        return advance(op_id, state, reason, timestamp)
    end

    return j, j.warning
end

function journal.file_backend(path)
    if not has_id(path) or path:find("\0", 1, true) then
        return nil, "INVALID_PATH"
    end
    return {
        append = function(line)
            local file, err = io.open(path, "ab")
            if not file then
                return nil, err
            end
            local wrote, write_error = file:write(line, "\n")
            local flushed, flush_error
            if wrote then
                flushed, flush_error = file:flush()
            end
            local closed, close_error = file:close()
            if not (wrote and flushed and closed) then
                return nil, write_error or flush_error or close_error
            end
            return true
        end,
        read_lines = function()
            local opened, err, errno = io.open(path, "rb")
            if not opened then
                if errno == 2 then -- ENOENT
                    return {}, true
                end
                return nil, err
            end
            local file <close> = opened
            local size = file:seek("end")
            if not size then
                return nil, "FILE_READ_FAILED"
            end

            local lines, bytes, terminated = {}, 0, true
            local function collect(raw)
                bytes = bytes + #raw
                terminated = raw:sub(-1) == "\n"
                lines[#lines + 1] = terminated and raw:sub(1, -2) or raw
            end
            for raw in io.lines(path, "L") do
                collect(raw)
            end
            if bytes == size then
                return lines, terminated
            end

            -- Windows text mode translates CRLF and treats Ctrl-Z as EOF.
            -- If it changed the byte count, replay from the binary stream.
            if not file:seek("set", 0) then
                return nil, "FILE_READ_FAILED"
            end
            lines, bytes, terminated = {}, 0, true
            for raw in file:lines("L") do
                collect(raw)
            end
            if bytes ~= size then
                return nil, "FILE_READ_FAILED"
            end
            return lines, terminated
        end,
    }
end

return journal
