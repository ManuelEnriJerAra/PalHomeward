local i18n = require("i18n")

describe("localisation", function()
    it("substitutes names in both languages and preserves percent signs", function()
        local params = { pal = "Foxparks 100%", owner = "Alex" }
        assert_eq(i18n.t("ok.returned_to_owner", params, "en"), "Foxparks 100% was returned to Alex.")
        local spanish = i18n.t("ok.returned_to_owner", params, "es")
        assert_match(spanish, "Foxparks 100%%.*Alex")
        assert_eq(i18n.t("mode.observe.notice", nil, "es"), i18n.messages.es["mode.observe.notice"])
    end)

    it("uses English for a missing locale or a missing translation", function()
        assert_eq(i18n.t("deny.unknown_owner", nil, "fr"), i18n.messages.en["deny.unknown_owner"])
        local key = "test.english_only"
        i18n.messages.en[key] = "English only"
        local message = i18n.t(key, nil, "es")
        i18n.messages.en[key] = nil
        assert_eq(message, "English only")
    end)

    it("returns an unknown key and keeps missing placeholders visible", function()
        assert_eq(i18n.t("missing.key", nil, "es"), "missing.key")
        assert_match(i18n.t("ok.returned_to_owner", { owner = "Alex" }), "{pal}")
    end)

    it("keeps English and Spanish keys and placeholders in sync", function()
        for _, pair in ipairs({ { "en", "es" }, { "es", "en" } }) do
            for key, message in pairs(i18n.messages[pair[1]]) do
                local translation = i18n.messages[pair[2]][key]
                assert(translation, "missing translation for " .. key .. " in " .. pair[2])
                for placeholder in message:gmatch("{[%w_]+}") do
                    assert(translation:find(placeholder, 1, true), key .. " is missing " .. placeholder)
                end
            end
        end
    end)
end)
