local helper = require("tests.helper")

describe("Core", function()
    local ns, state

    before_each(function()
        state = helper.installWowStubs()
        ns = helper.newNamespace()
        helper.loadAddonFile("Atlasium/Util.lua", ns)
        helper.loadAddonFile("Atlasium/Core.lua", ns)
    end)

    it("registers ADDON_LOADED and wires the event script", function()
        assert.is_true(state.events.ADDON_LOADED)
        assert.is_function(state.scripts.OnEvent)
    end)

    it("registers the slash command", function()
        assert.equals("/atlasium", SLASH_ATLASIUM1)
        assert.is_function(SlashCmdList.ATLASIUM)
    end)

    describe("ADDON_LOADED", function()
        it("initializes saved variables with defaults", function()
            ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
            assert.is_false(AtlasiumDB.debug)
            assert.equals(AtlasiumDB, ns.db)
        end)

        it("preserves existing saved variables", function()
            _G.AtlasiumDB = { debug = true }
            ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
            assert.is_true(ns.db.debug)
        end)

        it("ignores other addons", function()
            ns.Core.OnEvent(nil, "ADDON_LOADED", "SomethingElse")
            assert.is_nil(ns.db)
        end)
    end)

    describe("slash command", function()
        before_each(function()
            ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
        end)

        it("toggles debug", function()
            SlashCmdList.ATLASIUM("debug")
            assert.is_true(ns.db.debug)
            SlashCmdList.ATLASIUM("debug")
            assert.is_false(ns.db.debug)
        end)

        it("prints the version", function()
            SlashCmdList.ATLASIUM("version")
            assert.matches("v0%.1%.0", state.messages[1])
        end)

        it("prints help for unknown input", function()
            SlashCmdList.ATLASIUM("nonsense")
            assert.matches("commands:", state.messages[1])
        end)
    end)
end)
