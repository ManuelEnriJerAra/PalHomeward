package.path = "mod/PalHomeward/Scripts/?.lua;" .. package.path

local function discover(filter)
    local command = [[find tests/unit -maxdepth 1 -type f -name '*_spec.lua']]
    local prefix = ""
    if package.config:sub(1, 1) == "\\" then
        command = [[dir /b /a-d "tests\unit\*_spec.lua"]]
        prefix = "tests/unit/"
    end

    local pipe = assert(io.popen(command))
    local specs = {}
    for name in pipe:lines() do
        local filename = name:match("[^/\\]+$")
        if filename and filename:find(filter, 1, true) then
            specs[#specs + 1] = prefix .. name
        end
    end
    assert(pipe:close(), "Could not list Lua specs in tests/unit")
    table.sort(specs)
    return specs
end

local function assert_eq(actual, expected)
    assert(actual == expected,
        "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function assert_true(value)
    assert_eq(value, true)
end

local function assert_match(value, pattern)
    assert(type(value) == "string" and value:match(pattern),
        tostring(value) .. " does not match " .. pattern)
end

local function assert_error(fn, pattern)
    local ok, message = pcall(fn)
    assert(not ok, "expected an error")
    if pattern then
        assert_match(tostring(message), pattern)
    end
end

local passed, failed = 0, 0

local function run_spec(path)
    local group = path
    local env = setmetatable({
        assert_eq = assert_eq,
        assert_true = assert_true,
        assert_error = assert_error,
        assert_match = assert_match,
    }, { __index = _G })
    env._G = env

    function env.describe(name, fn)
        local previous = group
        group = group .. " / " .. name
        fn()
        group = previous
    end

    function env.it(name, fn)
        local ok, message = xpcall(fn, debug.traceback)
        if ok then
            passed = passed + 1
            print("PASS " .. group .. " / " .. name)
        else
            failed = failed + 1
            print("FAIL " .. group .. " / " .. name .. "\n" .. message)
        end
    end

    local ok, message = xpcall(function()
        assert(loadfile(path, "t", env))()
    end, debug.traceback)
    if not ok then
        failed = failed + 1
        print("FAIL " .. group .. " / spec setup\n" .. message)
    end
end

local ok, specs = pcall(discover, arg[1] or "")
if not ok or #specs == 0 then
    print("FAIL " .. (ok and "No Lua specs matched" or specs))
    failed = failed + 1
else
    for _, path in ipairs(specs) do
        run_spec(path)
    end
    if passed + failed == 0 then
        print("FAIL No Lua tests ran")
        failed = failed + 1
    end
end

print(string.format("Lua suite: %d passed, %d failed", passed, failed))
os.exit(failed == 0)
