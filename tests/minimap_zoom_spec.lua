local helper = require("tests.helper")

describe("MinimapZoom", function()
    local ns, state, MinimapZoom

    local SKIPPED = "minimap wheel already used by another add-on; Atlasium minimap wheel zoom skipped"

    local function foreignHandler() end

    local function login(saved)
        _G.AtlasiumDB = saved
        ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
        ns.Core.OnEvent(nil, "PLAYER_LOGIN")
    end

    before_each(function()
        state = helper.installWowStubs()
        ns = helper.newNamespace()
        helper.loadAddonFile("Atlasium/Util.lua", ns)
        helper.loadAddonFile("Atlasium/Core.lua", ns)
        helper.loadAddonFile("Atlasium/Log.lua", ns)
        helper.loadAddonFile("Atlasium/Data/MinimapTileData.lua", ns)
        helper.loadAddonFile("Atlasium/MinimapTiles.lua", ns)
        helper.loadAddonFile("Atlasium/MinimapZoom.lua", ns)
        MinimapZoom = ns.MinimapZoom
    end)

    describe("GetDirection", function()
        it("zooms in for wheel up and out for wheel down", function()
            assert.equals(1, MinimapZoom.GetDirection(1))
            assert.equals(-1, MinimapZoom.GetDirection(-1))
            assert.equals(1, MinimapZoom.GetDirection(3))
            assert.equals(0, MinimapZoom.GetDirection(0))
        end)
    end)

    describe("on PLAYER_LOGIN", function()
        it("registers PLAYER_LOGIN when the file loads", function()
            assert.is_true(state.events.PLAYER_LOGIN)
        end)

        it("enables the wheel and sets the handler", function()
            login()
            assert.is_true(Minimap.wheelEnabled)
            assert.equals(MinimapZoom.OnMouseWheel, Minimap:GetScript("OnMouseWheel"))
        end)

        it("moves one zoom level per notch, through the Blizzard functions", function()
            login()
            helper.runScript(Minimap, "OnMouseWheel", 1)
            helper.runScript(Minimap, "OnMouseWheel", 1)
            helper.runScript(Minimap, "OnMouseWheel", -1)
            assert.same({ 1, 1, -1 }, state.minimapZooms)
        end)

        it("does nothing when the setting is off", function()
            login({ minimapZoom = { enabled = false } })
            assert.is_nil(Minimap:GetScript("OnMouseWheel"))
            assert.is_nil(Minimap.wheelEnabled)
        end)

        it("skips a foreign handler without a message when debug is off", function()
            Minimap:SetScript("OnMouseWheel", foreignHandler)
            login()
            assert.equals(foreignHandler, Minimap:GetScript("OnMouseWheel"))
            assert.is_nil(Minimap.wheelEnabled)
            assert.same({}, state.messages)
        end)

        it("skips a foreign handler with a message when debug is on", function()
            Minimap:SetScript("OnMouseWheel", foreignHandler)
            login({ debug = true })
            assert.equals(foreignHandler, Minimap:GetScript("OnMouseWheel"))
            assert.equals(1, #state.messages)
            assert.matches(SKIPPED, state.messages[1], 1, true)
            assert.same({ helper.DATE .. " [DEBUG] " .. SKIPPED }, ns.db.log)
        end)
    end)

    describe("SetEnabled", function()
        it("removes our handler and disables the wheel when turned off", function()
            login()
            MinimapZoom.SetEnabled(false)
            assert.is_false(ns.db.minimapZoom.enabled)
            assert.is_nil(Minimap:GetScript("OnMouseWheel"))
            assert.is_false(Minimap.wheelEnabled)
        end)

        it("sets the handler again when turned on", function()
            login({ minimapZoom = { enabled = false } })
            MinimapZoom.SetEnabled(true)
            assert.is_true(ns.db.minimapZoom.enabled)
            assert.is_true(Minimap.wheelEnabled)
            assert.equals(MinimapZoom.OnMouseWheel, Minimap:GetScript("OnMouseWheel"))
        end)

        it("leaves a foreign handler alone when turned off", function()
            login()
            Minimap:SetScript("OnMouseWheel", foreignHandler)
            Minimap.calls.EnableMouseWheel = nil
            MinimapZoom.SetEnabled(false)
            assert.equals(foreignHandler, Minimap:GetScript("OnMouseWheel"))
            assert.is_true(Minimap.wheelEnabled)
            assert.is_nil(Minimap.calls.EnableMouseWheel)
        end)

        it("skips a foreign handler when turned on", function()
            login({ minimapZoom = { enabled = false }, debug = true })
            Minimap:SetScript("OnMouseWheel", foreignHandler)
            MinimapZoom.SetEnabled(true)
            assert.is_true(ns.db.minimapZoom.enabled)
            assert.equals(foreignHandler, Minimap:GetScript("OnMouseWheel"))
            assert.matches(SKIPPED, state.messages[1], 1, true)
        end)
    end)
end)
