local helper = require("tests.helper")

describe("Localization", function()
    local ns
    before_each(function()
        helper.installWowStubs()
        ns = helper.loadAddon()
    end)

    it("uses English before saved variables load and defaults to English", function()
        assert.equals("Language", ns.Localization.Get("language"))
        ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
        assert.equals("enUS", ns.db.language)
    end)

    it("preserves the account language and other saved preferences", function()
        _G.AtlasiumDB = { language = "ptBR", mapNav = { maxZoom = 7 } }
        ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
        assert.equals("Idioma", ns.Localization.Get("language"))
        assert.equals(7, ns.db.mapNav.maxZoom)
    end)

    it("has matching translation keys and formatting placeholders", function()
        local translations = ns.Localization.translations
        for key, value in pairs(translations.enUS) do
            assert.is_string(translations.ptBR[key], key)
            local _, count = value:gsub("%%s", "")
            local _, translatedCount = translations.ptBR[key]:gsub("%%s", "")
            assert.equals(count, translatedCount, key)
        end
        for key in pairs(translations.ptBR) do assert.is_string(translations.enUS[key], key) end
    end)

    it("falls back for unknown saved locales, missing translations and missing keys", function()
        ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
        ns.db.language = "unsupported"
        assert.equals("Language", ns.Localization.Get("language"))
        ns.db.language = "ptBR"
        ns.Localization.translations.ptBR.language = nil
        assert.equals("Language", ns.Localization.Get("language"))
        assert.equals("unknown", ns.Localization.Get("unknown"))
    end)

    it("formats strings and rejects unsupported language edits", function()
        ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
        assert.is_true(ns.Localization.SetLanguage("ptBR"))
        assert.equals("Zoom máximo do mapa-múndi: 4×", ns.Localization.Get("maxZoom", "4"))
        local ok, errorText = ns.Localization.SetLanguage("xxXX")
        assert.is_false(ok)
        assert.equals(ns.Localization.Get("invalid"), errorText)
        assert.equals("ptBR", ns.db.language)
    end)
end)
