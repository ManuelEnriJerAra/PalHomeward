local source = debug.getinfo(1, "S").source
local directory = source:match("^@(.*[/\\])") or "./"
package.path = directory .. "?.lua;" .. package.path

local config = require("config")
local i18n = require("i18n")
local logging = require("logging")

local cfg = config.resolve(config)
-- OBSERVED (UE4SS v4.0.0, Palworld server v1.0.5.102999): UE4SS's print does not append a
-- newline, unlike stock Lua. Detect the UE4SS runtime by its global API.
local has_ue4ss = type(RegisterHook) == "function"
local sink = print
if has_ue4ss then
    sink = function(line) print(line .. "\n") end
end
local log = logging.new(sink, { level = cfg.Logging.Level, redact = cfg.Logging.RedactSensitiveFields })
-- Keep the F1 startup marker stable for lab log checks.
log.sink(i18n.t("mod.loaded", { mode = "OBSERVE", version = "0.0.1" }, cfg.Language))

if cfg.Probe.Enabled then
    local function start_probe()
        local session_id = tostring(os.time())
        require("probe").start({
            register_hook = RegisterHook,
            unregister_hook = UnregisterHook,
            logger = log,
            targets = require("probe_targets"),
            clock = os.clock,
            session_id = session_id,
        })
        log:info("probe.started", { session = session_id })
    end

    if not has_ue4ss then
        log:warn("probe.skipped", { reason = "no_ue4ss" })
    elseif cfg.Probe.StartDelayMs == 0 then
        start_probe()
    elseif type(ExecuteWithDelay) == "function" then
        -- TO_VERIFY: registration from the delayed callback on UE4SS v4.0.0.
        local ok = pcall(ExecuteWithDelay, cfg.Probe.StartDelayMs, start_probe)
        if not ok then
            log:warn("probe.skipped", { reason = "delay_failed" })
        end
    else
        log:warn("probe.skipped", { reason = "no_execute_with_delay" })
    end
end
