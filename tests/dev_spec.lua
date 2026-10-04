local helper = require("tests.helper")

describe("Dev", function()
    local ns, state

    -- The marker is the only frame that sets a strata.
    local function findMarker()
        for _, frame in ipairs(state.frames) do
            if frame.calls.SetFrameStrata then
                return frame
            end
        end
    end

    local function markerColor(marker)
        local call = helper.lastCall(marker.textures[1], "SetTexture")
        return call[1], call[2], call[3]
    end

    local function load(debug)
        _G.AtlasiumDB = { debug = debug }
        ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
        ns.Core.OnEvent(nil, "PLAYER_LOGIN")
    end

    before_each(function()
        state = helper.installWowStubs()
        ns = helper.newNamespace()
        helper.loadAddonFile("Atlasium/Util.lua", ns)
        helper.loadAddonFile("Atlasium/Core.lua", ns)
        helper.loadAddonFile("Atlasium/Localization.lua", ns)
        helper.loadAddonFile("Atlasium/Settings.lua", ns)
        helper.loadAddonFile("Atlasium/Dev.lua", ns)
    end)

    describe("pure helpers", function()
        it("colours the marker green for an open map and red for a closed map", function()
            assert.same({ 0, 1, 0 }, { ns.Dev.GetMarkerColor(true) })
            assert.same({ 1, 0, 0 }, { ns.Dev.GetMarkerColor(false) })
        end)

        it("sizes the marker in screen pixels", function()
            assert.equals(24, ns.Dev.GetMarkerSize(1))
            assert.equals(12, ns.Dev.GetMarkerSize(2))
            assert.equals(48, ns.Dev.GetMarkerSize(0.5))
        end)

        it("uses scale 1 for a missing or invalid scale", function()
            assert.equals(24, ns.Dev.GetMarkerSize(nil))
            assert.equals(24, ns.Dev.GetMarkerSize(0))
        end)

        it("finds the command of a key", function()
            assert.equals("TOGGLEWORLDMAP", ns.Dev.GetCommand("NUMPADMULTIPLY"))
            assert.equals("SCREENSHOT", ns.Dev.GetCommand("NUMPADMINUS"))
            assert.is_nil(ns.Dev.GetCommand("M"))
        end)

        it("does not use a key twice", function()
            local seen = { [ns.Dev.CONSOLE_KEY] = true }
            for _, binding in ipairs(ns.Dev.BINDINGS) do
                assert.is_nil(seen[binding.key])
                seen[binding.key] = true
            end
        end)
    end)

    describe("health report", function()
        it("lists debug mode, the modules, the load ID and the captured errors", function()
            load(true)
            ns.Log = {
                errorCount = 2,
                lastError = "Dev.lua:1: boom",
                GetErrorCapture = function() return "BugGrabber" end,
            }
            ns.DevConsole = { GetLoadId = function() return 1234 end }
            assert.same({
                debug = true,
                loadId = 1234,
                modules = "Core Dev DevConsole Localization Log Settings Util",
                errorCapture = "BugGrabber",
                errors = 2,
                lastError = "Dev.lua:1: boom",
            }, ns.Dev.GetHealth())
        end)

        it("works without the dev console and the log", function()
            load(false)
            local health = ns.Dev.GetHealth()
            assert.is_false(health.debug)
            assert.is_nil(health.loadId)
            assert.equals("off", health.errorCapture)
            assert.equals(0, health.errors)
            assert.equals("Core Dev Localization Settings Util", health.modules)
        end)
    end)

    describe("with debug off", function()
        before_each(function()
            load(false)
        end)

        it("creates no marker and sets no bindings", function()
            assert.is_nil(findMarker())
            assert.same({}, state.bindings)
        end)

        it("does not set the AtlasiumDev handle", function()
            assert.is_nil(_G.AtlasiumDev)
        end)

        it("ignores the map hooks", function()
            helper.runScript(WorldMapFrame, "OnShow")
            assert.is_nil(findMarker())
        end)

        it("ignores the map keys", function()
            ns.Dev.OnMapKeyDown(nil, "NUMPADMULTIPLY")
            assert.same({}, state.ran)
        end)
    end)

    describe("with debug on", function()
        before_each(function()
            load(true)
        end)

        it("shows a red marker in the top-left corner above everything", function()
            local marker = findMarker()
            assert.is_not_nil(marker)
            assert.equals("TOOLTIP", helper.lastCall(marker, "SetFrameStrata")[1])
            assert.same({ "TOPLEFT", nil, "TOPLEFT", 0, 0 }, { marker:GetPoint() })
            assert.is_nil(marker:GetParent())
            assert.is_nil(marker:GetName())
            assert.equals(24, marker:GetWidth())
            assert.equals(24, marker:GetHeight())
            assert.is_true(marker:IsShown())
            assert.same({ 1, 0, 0 }, { markerColor(marker) })
        end)

        it("does not catch the mouse", function()
            assert.is_false(findMarker():IsMouseEnabled())
        end)

        it("turns green when the map opens and red when it closes", function()
            local marker = findMarker()
            helper.runScript(WorldMapFrame, "OnShow")
            assert.same({ 0, 1, 0 }, { markerColor(marker) })
            helper.runScript(WorldMapFrame, "OnHide")
            assert.same({ 1, 0, 0 }, { markerColor(marker) })
        end)

        it("shows a green marker at login when the map is already open", function()
            WorldMapFrame:Show()
            ns.Core.OnEvent(nil, "PLAYER_LOGIN")
            assert.same({ 0, 1, 0 }, { markerColor(findMarker()) })
        end)

        it("keeps its size when the UI scale changes, because it has no parent", function()
            state.uiScale = 0.5
            ns.Dev.Update()
            assert.equals(24, findMarker():GetWidth())
            assert.equals(24, findMarker():GetHeight())
        end)

        it("sets the AtlasiumDev handle to the namespace", function()
            assert.equals(ns, _G.AtlasiumDev)
        end)

        it("sets the override bindings on a frame that is not the marker", function()
            assert.same({
                NUMPADMULTIPLY = "TOGGLEWORLDMAP",
                NUMPADMINUS = "SCREENSHOT",
                NUMPADPLUS = "CLICK AtlasiumDevConsoleButton:LeftButton",
            }, state.bindings)
            assert.is_not_nil(state.bindingOwner)
            assert.is_not.equals(findMarker(), state.bindingOwner)
        end)

        it("clears the bindings and hides the marker when debug turns off", function()
            ns.db.debug = false
            ns.Dev.Update()
            assert.is_false(findMarker():IsShown())
            assert.same({}, state.bindings)
        end)

        it("shows the marker and sets the bindings again when debug turns on again", function()
            ns.db.debug = false
            ns.Dev.Update()
            ns.db.debug = true
            ns.Dev.Update()
            assert.is_true(findMarker():IsShown())
            assert.equals("SCREENSHOT", state.bindings.NUMPADMINUS)
        end)
    end)

    describe("the debug command", function()
        before_each(function()
            load(false)
        end)

        it("sets and clears the AtlasiumDev handle", function()
            SlashCmdList.ATLASIUM("debug")
            assert.equals(ns, _G.AtlasiumDev)
            SlashCmdList.ATLASIUM("debug")
            assert.is_nil(_G.AtlasiumDev)
        end)

        it("switches the dev console and the error capture with debug mode", function()
            local console, capture = {}, {}
            ns.DevConsole = { SetActive = function(active) table.insert(console, active) end }
            ns.Log = { SetErrorCapture = function(active) table.insert(capture, active) end }
            SlashCmdList.ATLASIUM("debug")
            SlashCmdList.ATLASIUM("debug")
            assert.same({ true, false }, console)
            assert.same({ true, false }, capture)
        end)

        it("switches the marker and the bindings with /atlasium debug", function()
            SlashCmdList.ATLASIUM("debug")
            assert.is_true(findMarker():IsShown())
            assert.equals("TOGGLEWORLDMAP", state.bindings.NUMPADMULTIPLY)
            SlashCmdList.ATLASIUM("debug")
            assert.is_false(findMarker():IsShown())
            assert.same({}, state.bindings)
        end)
    end)

    describe("in combat", function()
        it("waits with the bindings until combat ends", function()
            load(false)
            state.combat = true
            SlashCmdList.ATLASIUM("debug")
            assert.is_true(findMarker():IsShown()) -- the marker is not protected
            assert.same({}, state.bindings)
            state.combat = false
            ns.Core.OnEvent(nil, "PLAYER_REGEN_ENABLED")
            assert.equals("TOGGLEWORLDMAP", state.bindings.NUMPADMULTIPLY)
        end)

        it("waits with clearing the bindings until combat ends", function()
            load(true)
            state.combat = true
            SlashCmdList.ATLASIUM("debug")
            assert.equals("SCREENSHOT", state.bindings.NUMPADMINUS)
            state.combat = false
            ns.Core.OnEvent(nil, "PLAYER_REGEN_ENABLED")
            assert.same({}, state.bindings)
        end)

        it("does nothing at the end of combat when no change waits", function()
            load(true)
            state.bindings.NUMPADMINUS = nil
            ns.Core.OnEvent(nil, "PLAYER_REGEN_ENABLED")
            assert.is_nil(state.bindings.NUMPADMINUS)
        end)
    end)

    describe("map keys", function()
        before_each(function()
            load(true)
        end)

        it("hooks OnKeyDown of the world map", function()
            assert.equals(ns.Dev.OnMapKeyDown, WorldMapFrame.scriptHooks.OnKeyDown[1])
        end)

        it("runs the command itself when the client does not count the override binding", function()
            helper.runScript(WorldMapFrame, "OnKeyDown", "NUMPADMULTIPLY")
            helper.runScript(WorldMapFrame, "OnKeyDown", "NUMPADMINUS")
            assert.same({ "TOGGLEWORLDMAP", "SCREENSHOT" }, state.ran)
        end)

        it("leaves the command to Blizzard when the client counts the override binding", function()
            state.binds.NUMPADMULTIPLY = "TOGGLEWORLDMAP"
            helper.runScript(WorldMapFrame, "OnKeyDown", "NUMPADMULTIPLY")
            assert.same({}, state.ran)
        end)

        it("focuses the dev console with the console key, which the map handler never runs", function()
            local focused = 0
            ns.DevConsole = { Focus = function() focused = focused + 1 end, SetActive = function() end }
            helper.runScript(WorldMapFrame, "OnKeyDown", "NUMPADPLUS")
            assert.equals(1, focused)
            assert.same({}, state.ran)
        end)

        it("ignores the console key without a dev console", function()
            helper.runScript(WorldMapFrame, "OnKeyDown", "NUMPADPLUS")
            assert.same({}, state.ran)
        end)

        it("ignores other keys", function()
            helper.runScript(WorldMapFrame, "OnKeyDown", "M")
            assert.same({}, state.ran)
        end)
    end)
end)
