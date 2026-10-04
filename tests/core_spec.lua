local helper = require("tests.helper")

describe("Core", function()
    local ns, state

    before_each(function()
        state = helper.installWowStubs()
        ns = helper.newNamespace()
        helper.loadAddonFile("Atlasium/Util.lua", ns)
        helper.loadAddonFile("Atlasium/Core.lua", ns)
        helper.loadAddonFile("Atlasium/MapNavigation.lua", ns)
        helper.loadAddonFile("Atlasium/Dev.lua", ns)
    end)

    it("registers ADDON_LOADED and wires the event script", function()
        assert.is_true(state.events.ADDON_LOADED)
        assert.is_function(state.scripts.OnEvent)
    end)

    it("registers the slash command", function()
        assert.equals("/atlasium", SLASH_ATLASIUM1)
        assert.is_function(SlashCmdList.ATLASIUM)
    end)

    describe("RegisterEvent", function()
        it("runs every handler of an event in the order of registration", function()
            local calls = {}
            ns.Core.RegisterEvent("PLAYER_ENTERING_WORLD", function(...) table.insert(calls, { "first", ... }) end)
            ns.Core.RegisterEvent("PLAYER_ENTERING_WORLD", function(...) table.insert(calls, { "second", ... }) end)
            ns.Core.OnEvent(nil, "PLAYER_ENTERING_WORLD", "a", "b")
            assert.same({ { "first", "a", "b" }, { "second", "a", "b" } }, calls)
            assert.is_true(state.events.PLAYER_ENTERING_WORLD)
        end)

        it("ignores an event without handlers", function()
            assert.has_no.errors(function() ns.Core.OnEvent(nil, "UNKNOWN_EVENT") end)
        end)
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

        it("turns map zoom off and on, and prints the new state", function()
            local calls = {}
            local setEnabled = ns.MapNavigation.SetEnabled
            ns.MapNavigation.SetEnabled = function(enabled)
                table.insert(calls, enabled)
                setEnabled(enabled)
            end
            SlashCmdList.ATLASIUM("zoom off")
            assert.is_false(ns.db.mapNav.enabled)
            assert.matches("map zoom off", state.messages[1])
            SlashCmdList.ATLASIUM("zoom on")
            assert.is_true(ns.db.mapNav.enabled)
            assert.matches("map zoom on", state.messages[2])
            assert.same({ false, true }, calls)
        end)

        it("prints the map zoom state without a valid argument", function()
            local called = false
            ns.MapNavigation.SetEnabled = function() called = true end
            SlashCmdList.ATLASIUM("zoom")
            SlashCmdList.ATLASIUM("zoom maybe")
            assert.is_false(called)
            assert.matches("map zoom on %(/atlasium zoom on | off%)", state.messages[1])
            assert.equals(state.messages[1], state.messages[2])
        end)

        it("prints help for unknown input", function()
            SlashCmdList.ATLASIUM("nonsense")
            assert.matches("commands:", state.messages[1])
        end)
    end)
end)
