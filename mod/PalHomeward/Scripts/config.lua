local function defaults()
    return {
        Enabled = true,
        Mode = "OBSERVE",
        Language = "en",
        FailClosed = true,
        AllowUnknownOwnerTransfer = false,
        AllowUnverifiedGameBuild = false,
        Logging = {
            Level = "INFO",
            Structured = true,
            RedactSensitiveFields = true,
        },
    }
end

local config = defaults()
local modes = { OBSERVE = true, PROTECT = true, AUTO_RETURN = true }
local languages = { en = true, es = true }
local levels = { DEBUG = true, INFO = true, WARN = true, ERROR = true }

function config.validate(cfg)
    if type(cfg) ~= "table" then
        return false, { "Configuration must be a table" }
    end

    local errors = {}
    local function check(condition, field, expected)
        if not condition then
            errors[#errors + 1] = field .. " must be " .. expected
        end
    end

    check(modes[cfg.Mode], "Mode", "OBSERVE, PROTECT or AUTO_RETURN")
    check(languages[cfg.Language], "Language", "en or es")
    for _, field in ipairs({ "Enabled", "FailClosed", "AllowUnknownOwnerTransfer", "AllowUnverifiedGameBuild" }) do
        check(type(cfg[field]) == "boolean", field, "a boolean")
    end

    local log = cfg.Logging
    check(type(log) == "table", "Logging", "a table")
    if type(log) == "table" then
        check(levels[log.Level], "Logging.Level", "DEBUG, INFO, WARN or ERROR")
        check(type(log.Structured) == "boolean", "Logging.Structured", "a boolean")
        check(type(log.RedactSensitiveFields) == "boolean", "Logging.RedactSensitiveFields", "a boolean")
    end
    return #errors == 0, errors
end

function config.resolve(cfg)
    local ok, errors = config.validate(cfg)
    if ok then
        return cfg, errors
    end
    return defaults(), errors
end

return config
