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

        it("turns world map zoom off and on, and prints the new state", function()
            local calls = {}
            local setEnabled = ns.MapNavigation.SetEnabled
            ns.MapNavigation.SetEnabled = function(enabled)
                table.insert(calls, enabled)
                setEnabled(enabled)
            end
            SlashCmdList.ATLASIUM("worldmap zoom off")
            assert.is_false(ns.db.mapNav.enabled)
            assert.matches("worldmap zoom off", state.messages[1])
            SlashCmdList.ATLASIUM("WorldMap Zoom On")
            assert.is_true(ns.db.mapNav.enabled)
            assert.matches("worldmap zoom on", state.messages[2])
            assert.same({ false, true }, calls)
        end)

        it("prints the zoom state without on or off", function()
            local called = false
            ns.MapNavigation.SetEnabled = function() called = true end
            SlashCmdList.ATLASIUM("worldmap zoom")
            SlashCmdList.ATLASIUM("worldmap zoom maybe")
            assert.is_false(called)
            assert.matches("worldmap zoom on %(/atlasium worldmap zoom on | off%)", state.messages[1])
            assert.equals(state.messages[1], state.messages[2])
        end)

        it("lists the subcommands and their state for a bare submenu", function()
            ns.db.fogClear.enabled = false
            SlashCmdList.ATLASIUM("worldmap")
            ns.db.minimap.hide = true
            SlashCmdList.ATLASIUM("minimap")
            assert.matches("worldmap: zoom on, fog off$", state.messages[1])
            assert.matches("minimap: button off$", state.messages[2])
        end)

        it("prints help for an unknown subcommand", function()
            SlashCmdList.ATLASIUM("worldmap nonsense on")
            SlashCmdList.ATLASIUM("minimap fog off")
            assert.matches("commands:", state.messages[1])
            assert.equals(state.messages[1], state.messages[2])
            assert.is_true(ns.db.fogClear.enabled)
        end)

        it("prints help for unknown input and for the old commands", function()
            SlashCmdList.ATLASIUM("nonsense")
            SlashCmdList.ATLASIUM("zoom off")
            SlashCmdList.ATLASIUM("fog off")
            SlashCmdList.ATLASIUM("")
            assert.matches("commands:", state.messages[1])
            for i = 2, 4 do
                assert.equals(state.messages[1], state.messages[i])
            end
            assert.is_true(ns.db.mapNav.enabled)
            assert.is_true(ns.db.fogClear.enabled)
        end)

        it("lists every subcommand in the help line", function()
            assert.equals(
                "commands: /atlasium debug | version | minimap button on/off | worldmap zoom on/off"
                    .. " | worldmap fog on/off",
                ns.Core.GetHelp()
            )
        end)
    end)
end)
