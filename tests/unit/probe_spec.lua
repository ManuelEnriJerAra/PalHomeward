local logging = require("logging")
local targets = require("probe_targets")

local function setup(options)
    options = options or {}
    local probe = dofile("mod/PalHomeward/Scripts/probe.lua")
    local hooks, attempts, removed, lines = {}, {}, {}, {}
    local deps = {
        register_hook = function(path, pre, post)
            attempts[#attempts + 1] = path
            if path == options.missing then
                error("function not loaded")
            end
            local n = #attempts
            hooks[path] = { pre = pre, post = post, pre_id = n, post_id = n + 100 }
            return n, n + 100
        end,
        unregister_hook = function(path, pre_id, post_id)
            local registered = assert(hooks[path])
            assert_eq(pre_id, registered.pre_id)
            assert_eq(post_id, registered.post_id)
            removed[#removed + 1] = path
        end,
        logger = logging.new(function(line)
            lines[#lines + 1] = line
            if options.on_log then options.on_log(line) end
        end),
        targets = options.targets or targets,
        clock = function() return 12.5 end,
        session_id = "offline-test",
    }
    return probe, deps, hooks, attempts, removed, lines
end

local function matching(lines, fragment)
    local matches = {}
    for _, line in ipairs(lines) do
        if line:find(fragment, 1, true) then
            matches[#matches + 1] = line
        end
    end
    return matches
end

local function wrap(value, on_get)
    return setmetatable({
        get = function()
            if on_get then on_get() end
            return value
        end,
    }, {
        __index = function(_, key) error("unexpected param member " .. key) end,
        __newindex = function(_, key) error("unexpected param write " .. key) end,
    })
end

local function context(name)
    return wrap(setmetatable({
        IsValid = function() return true end,
        GetFullName = function() return name or "Object /Script/Pal.Context" end,
    }, {
        __index = function(_, key) error("unexpected object member " .. key) end,
        __newindex = function(_, key) error("unexpected object write " .. key) end,
    }))
end

describe("read-only observation probe", function()
    it("attempts all twelve paths once and tears down only successful registrations", function()
        local ordered = { table.unpack(targets) }
        ordered[#ordered + 1] = targets[1]
        ordered[#ordered + 1] = targets[2]
        local probe, deps, hooks, attempts, removed, lines = setup({
            missing = targets[2].path,
            targets = ordered,
        })
        probe.start(deps)
        probe.start(deps)
        assert_eq(#targets, 12)
        assert_eq(#attempts, 12)
        for i, target in ipairs(targets) do
            assert_eq(attempts[i], target.path)
        end
        assert_eq(#matching(lines, "probe.hook.registered"), 11)
        assert_match(matching(lines, "probe.hook.registered")[1], "id=H%-001.*post_id=101 pre_id=1")
        local unavailable = matching(lines, "probe.hook.unavailable")
        assert_eq(#unavailable, 1)
        assert_match(unavailable[1], "function not loaded.*id=H%-002")

        probe.stop()
        probe.stop()
        assert_eq(#removed, 11)
        assert_eq(#matching(removed, targets[2].path), 0)
        hooks[targets[10].path].pre(context())
        assert_eq(#matching(lines, "probe.event"), 0)
        probe.start(deps)
        assert_eq(#attempts, 12)
        probe.stop()
    end)

    it("reads only the allowed members, preserves parameter order and returns no values", function()
        local probe, deps, hooks, _, _, lines = setup()
        probe.start(deps)
        local guid = { A = 1, B = -1, C = 0, D = 2 }
        local slot = { ContainerId = { ID = guid }, SlotIndex = 7 }
        local reads = 0
        local function count_read() reads = reads + 1 end
        local pre = hooks[targets[1].path].pre
        assert_eq(select("#", pre(context(), wrap(guid, count_read), wrap(slot, count_read),
            wrap(4, count_read), wrap(guid, count_read))), 0)
        assert_eq(reads, 4)
        assert_eq(select("#", hooks[targets[10].path].post(context())), 0)
        local events = matching(lines, "probe.event")
        assert_eq(#events, 2)
        assert_match(events[1], "CurrentPage=4.*SlotId.ContainerId=00000001FFFFFFFF0000000000000002")
        assert_match(events[1], "SlotId.SlotIndex=7.*ctx=Object.*Context.*hook=H%-001 phase=PRE")
        assert_match(events[1], "seq=1 session=offline%-test t=12%.5")
        assert_match(events[2], "hook=H%-010 phase=POST seq=2")
        assert_eq(#matching(lines, "probe.error"), 0)
        probe.stop()
    end)

    it("logs a throwing read once per reason and at most five times per hook", function()
        local probe, deps, hooks, _, _, lines = setup()
        probe.start(deps)
        local cb = hooks[targets[8].path].pre
        local function fail(message)
            assert_eq(select("#", cb(context(), wrap(nil, function() error(message, 0) end))), 0)
        end
        for _ = 1, 8 do fail("bad read") end
        assert_eq(#matching(lines, "probe.error"), 1)
        for i = 1, 8 do fail("other bad read " .. i) end
        assert_eq(#matching(lines, "probe.error"), 5)
        assert_eq(#matching(lines, "SlotId=UNAVAILABLE"), 16)
        cb(context(), wrap({ ContainerId = { ID = { A = 0, B = 0, C = 0, D = 0 } }, SlotIndex = 3 }))
        assert_eq(#matching(lines, "SlotId.SlotIndex=3"), 1)
        probe.stop()
    end)

    it("redacts UID fields by key and bounds rendered diagnostics", function()
        local probe, deps, hooks, _, _, lines = setup()
        probe.start(deps)
        local a = { A = -1, B = -1, C = -1, D = -1 }
        local b = { A = 0, B = 0, C = 0, D = 1 }
        hooks[targets[7].path].pre(context(("long context "):rep(300)), wrap(b), wrap(b),
            wrap({ PlayerUId = a, InstanceId = b, DebugName = "private name" }))
        hooks[targets[8].path].pre(context(), wrap(nil, function() error(("\n"):rep(2000), 0) end))
        local event = matching(lines, "probe.event")[1]
        assert_match(event, "IndividualId.PlayerUId=FFFF%.%.%.")
        assert_eq(event:find("FFFFFFFF", 1, true), nil)
        assert_eq(event:find("private name", 1, true), nil)
        assert_match(event, "ctx=[^ ]+%.%.%.")
        for _, line in ipairs(lines) do
            assert_true(#line < 1500)
            assert_eq(line:find("\n", 1, true), nil)
        end
        probe.stop()
    end)

    it("skips re-entrancy and contains errors from the sink", function()
        local nested
        local probe, deps, hooks, _, _, lines = setup({
            on_log = function(line)
                if line:find("probe.reentrant", 1, true) then
                    nested()
                    error("re-entrant sink error")
                elseif line:find("probe.event", 1, true) then
                    error("event sink error")
                end
            end,
        })
        probe.start(deps)
        local cb = hooks[targets[10].path].pre
        local reads = 0
        nested = function() cb(wrap({}, function() reads = reads + 1 end)) end
        assert_eq(select("#", cb(wrap({
            IsValid = function() return true end,
            GetFullName = function() return "outer" end,
        }, nested))), 0)
        assert_eq(reads, 0)
        assert_eq(#matching(lines, "probe.reentrant"), 1)
        assert_eq(#matching(lines, "probe.event"), 1)
        assert_eq(#matching(lines, "event sink error"), 1)
        cb(context())
        assert_eq(#matching(lines, "probe.event"), 2)
        probe.stop()
    end)
end)
