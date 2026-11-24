-- Runs main.lua in an isolated environment and returns printed lines and engine calls.
local function run_main(with_ue4ss_globals)
    local lines, calls = {}, {}
    local env = setmetatable({
        print = function(line) lines[#lines + 1] = line end,
    }, { __index = _G })
    if with_ue4ss_globals then
        env.RegisterHook = function() calls[#calls + 1] = "RegisterHook" end
        env.FindFirstOf = function() calls[#calls + 1] = "FindFirstOf" end
    end
    env._G = env

    local old_path, cached = package.path, {}
    local modules = { "config", "i18n", "logging" }
    package.path = ""
    for _, name in ipairs(modules) do
        cached[name], package.loaded[name] = package.loaded[name], nil
    end
    local ok, message = pcall(function()
        assert(loadfile("mod/PalHomeward/Scripts/main.lua", "t", env))()
    end)
    package.path = old_path
    for _, name in ipairs(modules) do
        package.loaded[name] = cached[name]
    end
    assert(ok, message)
    return lines, calls
end

describe("OBSERVE startup", function()
    it("loads sibling modules and writes one marker without engine calls (INV-10)", function()
        local lines, calls = run_main(true)
        assert_eq(#calls, 0)
        assert_eq(#lines, 1)
        -- UE4SS print does not append a newline, so main.lua adds one under UE4SS.
        assert_eq(lines[1], "[PalHomeward] LOADED mode=OBSERVE version=0.0.1\n")
    end)

    it("does not add an extra newline under stock Lua", function()
        local lines = run_main(false)
        assert_eq(#lines, 1)
        assert_eq(lines[1], "[PalHomeward] LOADED mode=OBSERVE version=0.0.1")
    end)
end)
