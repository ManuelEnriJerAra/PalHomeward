-- Runs main.lua in an isolated environment and returns printed lines and engine calls.
local function run_main(with_ue4ss_globals, local_config)
    local lines, calls = {}, {}
    local delayed
    local env = setmetatable({
        print = function(line) lines[#lines + 1] = line end,
    }, { __index = _G })
    if with_ue4ss_globals then
        env.RegisterHook = function(path)
            calls[#calls + 1] = path
            return #calls, #calls + 100
        end
        env.ExecuteWithDelay = function(ms, fn)
            calls[#calls + 1] = ms
            delayed = fn
        end
        env.FindFirstOf = function() calls[#calls + 1] = "FindFirstOf" end
    end
    env._G = env

    local old_path, cached = package.path, {}
    local modules = { "config", "i18n", "logging", "local_config", "probe" }
    local old_override = package.preload.local_config
    package.path = ""
    for _, name in ipairs(modules) do
        cached[name], package.loaded[name] = package.loaded[name], nil
    end
    package.preload.local_config = function() return local_config end
    local ok, message = pcall(function()
        assert(loadfile("mod/PalHomeward/Scripts/main.lua", "t", env))()
        if delayed then
            assert_eq(#calls, 1)
            delayed()
        end
    end)
    package.path = old_path
    package.preload.local_config = old_override
    for _, name in ipairs(modules) do
        package.loaded[name] = cached[name]
    end
    assert(ok, message)
    return lines, calls
end

local function assert_single_marker(lines)
    local count = 0
    for _, line in ipairs(lines) do
        if line:find(" LOADED ", 1, true) then count = count + 1 end
    end
    assert_eq(count, 1)
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

    it("merges partial local sections and registers every path when enabled", function()
        local lines, calls = run_main(true, { Probe = { Enabled = true }, Logging = { Level = "DEBUG" } })
        local targets = require("probe_targets")
        assert_eq(#calls, #targets)
        for i, target in ipairs(targets) do
            assert_eq(calls[i], target.path)
        end
        assert_single_marker(lines)
        assert_match(table.concat(lines), "probe%.started")
    end)

    it("defers registration when configured and reports a skip outside UE4SS", function()
        local override = { Probe = { Enabled = true, StartDelayMs = 300 } }
        local lines, calls = run_main(true, override)
        assert_eq(calls[1], 300)
        assert_eq(#calls, #require("probe_targets") + 1)
        assert_single_marker(lines)

        lines, calls = run_main(false, override)
        assert_eq(#calls, 0)
        assert_match(lines[2], "probe%.skipped reason=no_ue4ss$")
        assert_single_marker(lines)
    end)
end)
