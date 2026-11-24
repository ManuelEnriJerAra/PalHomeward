local config = require("config")

describe("configuration", function()
    it("defaults to valid OBSERVE settings (UT-042, INV-10)", function()
        local ok, errors = config.validate(config)
        assert_true(ok)
        assert_eq(#errors, 0)
        assert_eq(config.Mode, "OBSERVE")
        assert_eq(config.Language, "en")
        assert_true(config.Logging.RedactSensitiveFields)
        assert_eq(config.Probe.Enabled, false)
        assert_eq(config.Probe.StartDelayMs, 0)
    end)

    it("validates all supported mode names and locales", function()
        local cfg = config.resolve(nil)
        cfg.Language = "es"
        for _, mode in ipairs({ "OBSERVE", "PROTECT", "AUTO_RETURN" }) do
            cfg.Mode = mode
            assert_true(config.validate(cfg))
        end
    end)

    it("rejects unknown modes, locales, and non-boolean settings (UT-042)", function()
        local cfg = config.resolve(nil)
        cfg.Mode = "UNKNOWN"
        cfg.Language = "fr"
        cfg.Enabled = "true"
        cfg.FailClosed = 1
        cfg.AllowUnknownOwnerTransfer = "false"
        cfg.AllowUnverifiedGameBuild = 0
        cfg.Logging.Structured = 1
        cfg.Logging.RedactSensitiveFields = "false"
        cfg.Logging.Level = "TRACE"

        local ok, errors = config.validate(cfg)
        assert_eq(ok, false)
        assert_eq(#errors, 9)
        assert_eq(config.resolve(cfg).Mode, "OBSERVE")
    end)

    it("falls back to independent safe defaults for invalid mutating modes (UT-042)", function()
        for _, mode in ipairs({ "PROTECT", "AUTO_RETURN" }) do
            local cfg = config.resolve(nil)
            cfg.Mode = mode
            cfg.Logging = false
            local safe, errors = config.resolve(cfg)
            assert_eq(safe.Mode, "OBSERVE")
            assert_eq(safe.AllowUnknownOwnerTransfer, false)
            assert_true(safe.FailClosed)
            assert_eq(#errors, 1)
            safe.Logging.Level = "DEBUG"
            assert_eq(config.resolve(nil).Logging.Level, "INFO")
        end
    end)

    it("rejects invalid probe sections and delays and disables the probe on fallback", function()
        local cfg = config.resolve(nil)
        for _, delay in ipairs({ -1, 1.5, "300", math.huge, 0 / 0 }) do
            cfg.Probe = { Enabled = true, StartDelayMs = delay }
            local safe, errors = config.resolve(cfg)
            assert_eq(#errors, 1)
            assert_match(errors[1], "Probe%.StartDelayMs")
            assert_eq(safe.Probe.Enabled, false)
        end
        cfg.Probe = { Enabled = "yes", StartDelayMs = 0 }
        assert_eq(config.validate(cfg), false)
        cfg.Probe = false
        assert_eq(config.validate(cfg), false)
    end)
end)
