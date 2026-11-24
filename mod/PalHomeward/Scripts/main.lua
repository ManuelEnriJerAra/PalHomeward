local source = debug.getinfo(1, "S").source
local directory = source:match("^@(.*[/\\])") or "./"
package.path = directory .. "?.lua;" .. package.path

local config = require("config")
local i18n = require("i18n")
local logging = require("logging")

local cfg = config.resolve(config)
-- OBSERVED (UE4SS v4.0.0, Palworld server v1.0.5.102999): UE4SS's print does not append a
-- newline, unlike stock Lua. Detect the UE4SS runtime by its global API (checked, never called).
local sink = print
if type(RegisterHook) == "function" then
    sink = function(line) print(line .. "\n") end
end
local log = logging.new(sink, { level = cfg.Logging.Level, redact = cfg.Logging.RedactSensitiveFields })
-- Keep the F1 startup marker stable for lab log checks.
log.sink(i18n.t("mod.loaded", { mode = "OBSERVE", version = "0.0.1" }, cfg.Language))
