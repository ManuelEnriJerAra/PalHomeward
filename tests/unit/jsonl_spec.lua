local jsonl = require("jsonl")

describe("journal JSON codec", function()
    it("encodes deterministic objects, dense arrays, empty collections and nulls", function()
        local value = { z = { {}, jsonl.array({}), -7, jsonl.null, false, true }, a = "text" }
        local encoded = assert(jsonl.encode(value))
        assert_eq(encoded, '{"a":"text","z":[{},[],-7,null,false,true]}')
        assert_eq(jsonl.encode(assert(jsonl.decode(encoded))), encoded)
        assert_eq(jsonl.decode("null"), jsonl.null)
        assert_eq(jsonl.decode("false"), false)
        assert_eq(jsonl.decode(tostring(math.mininteger)), math.mininteger)
        assert_eq(jsonl.decode(tostring(math.maxinteger)), math.maxinteger)
    end)

    it("handles UTF-8, Unicode pairs, solidus escapes and every control byte", function()
        local decoded = assert(jsonl.decode([=[ "\u0041\u00f1\uD83D\uDE80\/\\\""]=]))
        assert_eq(decoded, "A" .. utf8.char(0xf1, 0x1f680) .. '/\\"')
        local controls = {}
        for byte = 0, 31 do
            controls[#controls + 1] = string.char(byte)
        end
        local original = table.concat(controls) .. utf8.char(0x1f680)
        local encoded = assert(jsonl.encode(original))
        assert_eq(encoded:find("[\0-\31]"), nil)
        assert_eq(jsonl.decode(encoded), original)
        assert_eq(jsonl.decode(" \t\r\n[ -0, \"\\b\\f\\n\\r\\t\" ]\r")[2], "\b\f\n\r\t")
    end)

    it("rejects malformed, unsupported and duplicate JSON data", function()
        for _, input in ipairs({
            '+1', '01', '1.0', '1e0', '-x', '9223372036854775808', '[-01]', 'false x', '{} []',
            '{"a": 1, "a": null}', '{"a" 1}', '{7: true}', '{"a":1,}', '[1,]', '[1 2]',
            [["\q"]], [["\u101x"]], [["\uD800\u0041"]], [["\uDC00"]], [["\uD800x"]],
            '"' .. string.char(0xff) .. '"', '"' .. string.char(1) .. '"',
            '"' .. string.char(0xed, 0xa0, 0x80) .. '"',
            string.rep("[", 66) .. string.rep("]", 66),
        }) do
            local value, err = jsonl.decode(input)
            assert(value == nil and err == "INVALID_JSON", string.format("unexpected decode for %q: %s", input, err))
        end
        local value, err = jsonl.decode(false)
        assert_eq(value, nil)
        assert_eq(err, "INVALID_JSON")
    end)

    it("distinguishes incomplete records from malformed JSON", function()
        for _, input in ipairs({
            "", "{", '{"x"', '{"x":', '{"x":1', '{"x":1,', "[", "[1,", "-", "fal", '"abc', '"\\',
            '"\\u00', '"\\uD800\\u',
        }) do
            local value, err = jsonl.decode(input)
            assert(value == nil and err == "TRUNCATED_JSON", string.format("unexpected decode for %q: %s", input, err))
        end
    end)

    it("rejects invalid Lua tables, values, strings and recursive input", function()
        local cyclic = {}
        cyclic.self = cyclic
        for _, value in ipairs({
            { [2] = "hole" }, { "mixed", key = true }, { [false] = 1 }, 7.5, 7.0, math.huge,
            string.char(0xff), function() end, cyclic, setmetatable({}, {}), jsonl.array({ foo = true }),
        }) do
            local encoded, err = jsonl.encode(value)
            assert_eq(encoded, nil)
            assert_eq(err, "INVALID_VALUE")
        end
        local encoded, err = jsonl.encode(nil)
        assert_eq(encoded, nil)
        assert_eq(err, "INVALID_VALUE")
    end)
end)
