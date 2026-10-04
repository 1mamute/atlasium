local helper = require("tests.helper")

describe("Core", function()
    local ns, state

    before_each(function()
        state = helper.installWowStubs()
        ns = helper.newNamespace()
        helper.loadAddonFile("Atlasium/Util.lua", ns)
        helper.loadAddonFile("Atlasium/Core.lua", ns)
        helper.loadAddonFile("Atlasium/Log.lua", ns)
        helper.loadAddonFile("Atlasium/Data/MinimapTileData.lua", ns)
        helper.loadAddonFile("Atlasium/MinimapFarZoom.lua", ns)
        helper.loadAddonFile("Atlasium/MinimapZoom.lua", ns)
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

        it("turns minimap zoom off and on, and prints the new state", function()
            SlashCmdList.ATLASIUM("minimap zoom off")
            assert.is_false(ns.db.minimapZoom.enabled)
            assert.matches("minimap zoom off %(/atlasium minimap zoom on | off%)", state.messages[1])
            SlashCmdList.ATLASIUM("minimap zoom on")
            assert.is_true(ns.db.minimapZoom.enabled)
            assert.equals(ns.MinimapZoom.OnMouseWheel, Minimap:GetScript("OnMouseWheel"))
            assert.matches("minimap zoom on", state.messages[2])
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
            assert.matches("minimap: button off, zoom on, far on, farmax 4$", state.messages[2])
        end)

        it("turns minimap far zoom off and on", function()
            SlashCmdList.ATLASIUM("minimap far off")
            assert.is_false(ns.db.minimapZoom.far)
            assert.matches("minimap far off %(/atlasium minimap far on | off%)", state.messages[1])
            SlashCmdList.ATLASIUM("minimap far on")
            assert.is_true(ns.db.minimapZoom.far)
        end)

        it("sets the largest far zoom factor within its range", function()
            SlashCmdList.ATLASIUM("minimap farmax 2.5")
            assert.equals(2.5, ns.db.minimapZoom.farMax)
            assert.matches("minimap farmax 2.5 %(/atlasium minimap farmax <1.5%-16>%)", state.messages[1])
            for _, value in ipairs({ "1", "17", "far", "" }) do
                SlashCmdList.ATLASIUM("minimap farmax " .. value)
            end
            assert.equals(2.5, ns.db.minimapZoom.farMax)
            for i = 2, 5 do
                assert.equals(state.messages[1], state.messages[i])
            end
        end)

        it("accepts the alignment check only in debug mode", function()
            SlashCmdList.ATLASIUM("minimap faralign on")
            assert.is_false(ns.MinimapFarZoom.align)
            assert.matches("commands:", state.messages[1])
            assert.is_nil(ns.Core.GetHelp():find("faralign", 1, true))
            ns.db.debug = true
            -- Without a player position the check turns itself off.
            state.map.name = "Elwynn"
            state.player.x, state.player.y = 0.42, 0.65
            SlashCmdList.ATLASIUM("minimap faralign on")
            assert.is_true(ns.MinimapFarZoom.align)
            assert.matches("minimap faralign on", state.messages[2])
            assert.is_not_nil(ns.Core.GetHelp():find("minimap faralign on/off", 1, true))
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
                "commands: /atlasium debug | version | minimap button on/off | minimap zoom on/off"
                    .. " | minimap far on/off | minimap farmax <1.5-16>"
                    .. " | worldmap zoom on/off | worldmap fog on/off",
                ns.Core.GetHelp()
            )
        end)
    end)
end)
