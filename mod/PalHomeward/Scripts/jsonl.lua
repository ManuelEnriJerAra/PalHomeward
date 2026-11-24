-- JSON for journal records. Encode emits one line without its delimiter.
-- Plain empty tables are objects. Use array({}) for an empty array and null
-- for JSON null. Decode distinguishes incomplete input from invalid input.
local jsonl = { null = {} }
local array_type = {}
local max_depth = 64

function jsonl.array(values)
    return setmetatable(values, array_type)
end

local escaped = {
    ['"'] = '\\"', ['\\'] = '\\\\',
    ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function invalid_value()
    error("INVALID_VALUE", 0)
end

local function encode_string(value)
    if not utf8.len(value) then
        invalid_value()
    end
    return '"' .. value:gsub('[%z\1-\31"\\]', function(char)
        return escaped[char] or string.format("\\u%04x", char:byte())
    end) .. '"'
end

local function encode(value, depth)
    if depth > max_depth then
        invalid_value()
    end
    if value == jsonl.null then
        return "null"
    end
    local kind = type(value)
    if kind == "string" then
        return encode_string(value)
    end
    if kind == "boolean" or math.type(value) == "integer" then
        return tostring(value)
    end
    if kind ~= "table" then
        invalid_value()
    end

    local metatable = getmetatable(value)
    if metatable and metatable ~= array_type then
        invalid_value()
    end
    local parts, keys = {}, {}
    local count, last = 0, 0
    for key in pairs(value) do
        if math.type(key) == "integer" and key >= 1 then
            count = count + 1
            last = math.max(last, key)
        elseif type(key) == "string" then
            keys[#keys + 1] = key
        else
            invalid_value()
        end
    end
    if count > 0 or metatable == array_type then
        if count ~= last or #keys ~= 0 then
            invalid_value()
        end
        for index = 1, count do
            parts[index] = encode(value[index], depth + 1)
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end

    table.sort(keys)
    for index, key in ipairs(keys) do
        parts[index] = encode_string(key) .. ":" .. encode(value[key], depth + 1)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function checked(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
    return nil, result
end

function jsonl.encode(value)
    return checked(encode, value, 0)
end

local unescaped = {
    ['"'] = '"', ['\\'] = '\\', ['/'] = '/',
    b = '\b', f = '\f', n = '\n', r = '\r', t = '\t',
}

local function decode(input)
    local function invalid()
        error("INVALID_JSON", 0)
    end

    if type(input) ~= "string" then
        invalid()
    end
    local cursor = 1
    local function peek()
        return input:sub(cursor, cursor)
    end
    local function fail_at_cursor()
        if cursor > #input then
            error("TRUNCATED_JSON", 0)
        end
        invalid()
    end
    local function take(token)
        if peek() == token then
            cursor = cursor + 1
            return true
        end
        return false
    end
    local function expect(token)
        if not take(token) then
            fail_at_cursor()
        end
    end
    local function whitespace()
        cursor = input:match("^[ \r\n\t]*()", cursor)
    end

    local function read_hex()
        local start = cursor
        for _ = 1, 4 do
            if not peek():match("^[0-9a-fA-F]$") then
                fail_at_cursor()
            end
            cursor = cursor + 1
        end
        return tonumber(input:sub(start, cursor - 1), 16)
    end

    local function read_escape()
        local char = peek()
        if char == "u" then
            cursor = cursor + 1
            local code = read_hex()
            if code >= 0xd800 and code <= 0xdbff then
                expect("\\")
                expect("u")
                local low = read_hex()
                if low < 0xdc00 or low > 0xdfff then
                    invalid()
                end
                code = 0x10000 + (code - 0xd800) * 0x400 + (low - 0xdc00)
            elseif code >= 0xdc00 and code <= 0xdfff then
                invalid()
            end
            return utf8.char(code)
        end
        if not unescaped[char] then
            fail_at_cursor()
        end
        cursor = cursor + 1
        return unescaped[char]
    end

    local function read_string()
        expect('"')
        local parts = {}
        while not take('"') do
            if take("\\") then
                parts[#parts + 1] = read_escape()
            else
                local chunk, next_cursor = input:match('^([^%z\1-\31"\\]+)()', cursor)
                if not chunk then
                    fail_at_cursor()
                end
                parts[#parts + 1] = chunk
                cursor = next_cursor
            end
        end
        local value = table.concat(parts)
        if not utf8.len(value) then
            invalid()
        end
        return value
    end

    local function read_integer()
        local start = cursor
        take("-")
        if take("0") then
            if peek():match("[0-9]") then
                invalid()
            end
        else
            local next_cursor = input:match("^[1-9][0-9]*()", cursor)
            if not next_cursor then
                fail_at_cursor()
            end
            cursor = next_cursor
        end
        local number = tonumber(input:sub(start, cursor - 1))
        if math.type(number) ~= "integer" then
            invalid()
        end
        return number
    end

    local function read_literal(word, value)
        for index = 1, #word do
            expect(word:sub(index, index))
        end
        return value
    end

    local read_value
    local function read_collection(depth, object)
        local values, closing = {}, "}"
        if not object then
            values, closing = jsonl.array(values), "]"
        end
        whitespace()
        if take(closing) then
            return values
        end
        repeat
            whitespace()
            local key = #values + 1
            if object then
                key = read_string()
                if values[key] ~= nil then
                    invalid()
                end
                whitespace()
                expect(":")
            end
            values[key] = read_value(depth + 1)
            whitespace()
        until not take(",")
        expect(closing)
        return values
    end

    function read_value(depth)
        if depth > max_depth then
            invalid()
        end
        whitespace()
        local char = peek()
        if take("{") then
            return read_collection(depth, true)
        elseif take("[") then
            return read_collection(depth, false)
        elseif char == '"' then
            return read_string()
        elseif char == "-" or char:match("[0-9]") then
            return read_integer()
        elseif char == "t" then
            return read_literal("true", true)
        elseif char == "f" then
            return read_literal("false", false)
        elseif char == "n" then
            return read_literal("null", jsonl.null)
        end
        fail_at_cursor()
    end

    local value = read_value(0)
    whitespace()
    if cursor <= #input then
        invalid()
    end
    return value
end

function jsonl.decode(line)
    return checked(decode, line)
end

return jsonl
