local helper = require("tests.helper")

describe("Settings", function()
    local ns, state
    before_each(function()
        state = helper.installWowStubs()
        ns = helper.loadAddon()
        ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
        ns.Core.OnEvent(nil, "PLAYER_LOGIN")
        WorldMapFrame:Show()
        ns.MapNavigation.Build()
        ns.MapNavigation.viewport.left = 100
        ns.MapNavigation.viewport.top = 600
        WorldMapFrame:Hide()
    end)

    it("uses feature setters for visibility, wheel zoom, terrain, fog and navigation", function()
        for _, id in ipairs({ "button", "minimapZoom", "tiles", "fog", "mapNav" }) do
            assert.is_true(ns.Settings.Set(id, false))
            assert.is_false(ns.Settings.Get(id))
        end
        assert.is_false(ns.MinimapButton.frame:IsShown())
        assert.is_nil(Minimap:GetScript("OnMouseWheel"))
        assert.is_false(ns.MinimapTiles.IsDrawing())
        assert.is_true(ns.Settings.Set("minimapZoom", true))
        assert.equals(ns.MinimapZoom.OnMouseWheel, Minimap:GetScript("OnMouseWheel"))
    end)

    it("rejects invalid values without changing saved or live state", function()
        local before = ns.Util.CopyDefaults(ns.db, {})
        for _, id in ipairs({ "angle", "maxZoom", "step" }) do
            local entry = ns.Settings.entries[id]
            for _, value in ipairs({ entry.min - 1, entry.max + 1, math.huge, -math.huge, 0 / 0, "2" }) do
                assert.is_false(ns.Settings.Set(id, value))
            end
        end
        assert.is_false(ns.Settings.Set("button", 1))
        assert.is_false(ns.Settings.Set("language", "deDE"))
        assert.is_false(ns.Settings.Set("missing", true))
        assert.is_false(ns.Settings.Set("color", { r = 1, g = 0, b = 0 }))
        assert.is_false(ns.Settings.Set("color", { r = 2, g = 0, b = 0, a = 1 }))
        assert.same(before, ns.db)
        assert.is_true(ns.MinimapButton.frame:IsShown())
    end)

    it("applies numeric boundaries and button position immediately", function()
        for _, id in ipairs({ "angle", "maxZoom", "step" }) do
            local entry = ns.Settings.entries[id]
            assert.is_true(ns.Settings.Set(id, entry.min))
            assert.equals(entry.min, ns.Settings.Get(id))
            assert.is_true(ns.Settings.Set(id, entry.max))
            assert.equals(entry.max, ns.Settings.Get(id))
        end
        assert.is_not_nil(helper.lastCall(ns.MinimapButton.frame, "SetPoint"))
    end)

    it("clamps both current and target map zoom during an animation", function()
        WorldMapFrame:Show()
        ns.MapNavigation.Build()
        ns.MapNavigation.OnWheel(nil, 6)
        ns.MapNavigation.OnDriverUpdate(ns.MapNavigation.viewport, 0.1)
        assert.is_true(ns.MapNavigation.state.zoom > 2)
        ns.Settings.Set("maxZoom", 2)
        assert.equals(2, ns.MapNavigation.state.zoom)
        assert.equals(2, ns.MapNavigation.state.targetZoom)
        ns.MapNavigation.OnDriverUpdate(ns.MapNavigation.viewport, 0.1)
        assert.equals(2, ns.MapNavigation.GetZoom())
        assert.is_true(ns.MapNavigation.state.scrollX >= 0)
    end)

    it("clamps an animation target even while the rendered zoom is still below the limit", function()
        WorldMapFrame:Show()
        ns.MapNavigation.Build()
        ns.MapNavigation.OnWheel(nil, 6)
        ns.Settings.Set("maxZoom", 2)
        assert.equals(1, ns.MapNavigation.GetZoom())
        assert.equals(2, ns.MapNavigation.state.targetZoom)
    end)

    it("applies wheel multiplier changes to the next notch", function()
        WorldMapFrame:Show()
        ns.MapNavigation.Build()
        ns.Settings.Set("step", 2)
        ns.MapNavigation.OnWheel(nil, 1)
        assert.equals(2, ns.MapNavigation.state.targetZoom)
    end)

    it("changes zoom limits in combat after detaching protected quest blobs", function()
        ns.MapNavigation.OnWheel(nil, 6)
        ns.MapNavigation.OnDriverUpdate(ns.MapNavigation.viewport, 0.1)
        ns.Core.OnEvent(nil, "PLAYER_REGEN_DISABLED")
        state.combat = true
        ns.Settings.Set("maxZoom", 2)
        assert.equals(2, ns.MapNavigation.GetZoom())
        assert.is_true(ns.MapNavigation.state.blobDetached)
        state.combat = false
        ns.Core.OnEvent(nil, "PLAYER_REGEN_ENABLED")
        assert.is_false(ns.MapNavigation.state.blobDetached)
    end)

    it("copies fog tint and refreshes the open map", function()
        local count = 0
        ns.FogClear.Update = function() count = count + 1 end
        WorldMapFrame:Show()
        local color = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }
        ns.Settings.Set("color", color)
        assert.same(color, ns.db.fogClear.color)
        color.r = 1
        assert.equals(0.1, ns.db.fogClear.color.r)
        assert.equals(1, count)
    end)

    it("restores configuration defaults and keeps saved logs and unknown data", function()
        local log = ns.db.log
        log[1] = "existing error"
        ns.db.other = "preserved"
        ns.Settings.Set("language", "ptBR")
        ns.Settings.Set("button", false)
        ns.Settings.Set("maxZoom", 8)
        ns.Settings.Set("color", { r = 1, g = 0, b = 0, a = 0.5 })
        ns.Settings.ResetDefaults()
        assert.equals("enUS", ns.db.language)
        assert.is_true(ns.MinimapButton.frame:IsShown())
        assert.equals(4, ns.db.mapNav.maxZoom)
        assert.same(ns.defaults.fogClear.color, ns.db.fogClear.color)
        assert.equals(log, ns.db.log)
        assert.equals("existing error", log[1])
        assert.equals("preserved", ns.db.other)
        ns.db.fogClear.color.r = 0
        assert.equals(0.6, ns.defaults.fogClear.color.r)
    end)

    it("defers debug bindings during combat and applies them afterward", function()
        state.combat = true
        ns.Settings.Set("debug", true)
        assert.is_true(ns.Dev.IsActive())
        assert.same({}, state.bindings)
        state.combat = false
        ns.Core.OnEvent(nil, "PLAYER_REGEN_ENABLED")
        assert.equals("TOGGLEWORLDMAP", state.bindings.NUMPADMULTIPLY)
    end)
end)
