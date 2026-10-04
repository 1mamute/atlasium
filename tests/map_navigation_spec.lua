local helper = require("tests.helper")

describe("MapNavigation", function()
    local ns, state, MN

    before_each(function()
        state = helper.installWowStubs()
        ns = helper.newNamespace()
        helper.loadAddonFile("Atlasium/Util.lua", ns)
        helper.loadAddonFile("Atlasium/Core.lua", ns)
        helper.loadAddonFile("Atlasium/MapNavigation.lua", ns)
        MN = ns.MapNavigation
        ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
    end)

    describe("StepZoom", function()
        it("zooms in and out by the step", function()
            assert.near(1.25, MN.StepZoom(1, 1, 1.25, 4), 1e-9)
            assert.near(1.6, MN.StepZoom(2, -1, 1.25, 4), 1e-9)
            assert.near(1.5625, MN.StepZoom(1, 2, 1.25, 4), 1e-9)
        end)

        it("stops at the maximum zoom", function()
            assert.equals(4, MN.StepZoom(3.5, 1, 1.25, 4))
            assert.equals(4, MN.StepZoom(1, 10, 1.25, 4))
        end)

        it("stops at 1", function()
            assert.equals(1, MN.StepZoom(1, -1, 1.25, 4))
            assert.equals(1, MN.StepZoom(1.1, -3, 1.25, 4))
        end)
    end)

    describe("Ease", function()
        it("moves toward the target", function()
            assert.near(1.12, MN.Ease(1, 2, 0.01, 12), 1e-9)
            assert.near(1.88, MN.Ease(2, 1, 0.01, 12), 1e-9)
        end)

        it("snaps to the target when it is close", function()
            assert.equals(2, MN.Ease(1.999, 2, 0.01, 12))
            assert.equals(1, MN.Ease(1.001, 1, 0.01, 12))
        end)

        it("never goes past the target", function()
            assert.equals(2, MN.Ease(1, 2, 10, 12))
            assert.equals(1, MN.Ease(3, 1, 10, 12))
        end)
    end)

    describe("ZoomScroll", function()
        it("keeps the map point under the anchor fixed", function()
            local anchor, scroll, oldZoom, newZoom = 300, 120, 1.5, 3
            local result = MN.ZoomScroll(anchor, scroll, oldZoom, newZoom)
            assert.near((anchor + scroll) / oldZoom, (anchor + result) / newZoom, 1e-9)
        end)

        it("does not scroll from 1x with the anchor at the left edge", function()
            assert.equals(0, MN.ZoomScroll(0, 0, 1, 2))
        end)

        it("scrolls by the anchor when zooming from 1x to 2x", function()
            assert.equals(300, MN.ZoomScroll(300, 0, 1, 2))
        end)
    end)

    describe("ScrollMax", function()
        it("is zero at 1x and grows with the zoom", function()
            assert.equals(0, MN.ScrollMax(600, 1))
            assert.equals(600, MN.ScrollMax(600, 2))
            assert.equals(1800, MN.ScrollMax(600, 4))
        end)
    end)

    describe("Clamp", function()
        it("limits a value to a range", function()
            assert.equals(5, MN.Clamp(5, 0, 10))
            assert.equals(0, MN.Clamp(-3, 0, 10))
            assert.equals(10, MN.Clamp(13, 0, 10))
        end)
    end)

    describe("CursorToView", function()
        it("converts the cursor to viewport units from the top left", function()
            local x, y = MN.CursorToView(500, 400, 1, 100, 600)
            assert.equals(400, x)
            assert.equals(200, y)
        end)

        it("divides the cursor by the scale", function()
            local x, y = MN.CursorToView(500, 400, 2, 100, 600)
            assert.equals(150, x)
            assert.equals(400, y)
        end)
    end)

    describe("PanScroll", function()
        it("scrolls left when the cursor goes right", function()
            local sx, sy = MN.PanScroll(100, 0, 200, 200, 250, 200, 1)
            assert.equals(50, sx)
            assert.equals(0, sy)
        end)

        it("scrolls down when the cursor goes up", function()
            local sx, sy = MN.PanScroll(0, 0, 200, 200, 200, 230, 1)
            assert.equals(0, sx)
            assert.equals(30, sy)
        end)

        it("divides the cursor move by the scale", function()
            local sx, sy = MN.PanScroll(100, 100, 200, 200, 250, 230, 2)
            assert.equals(75, sx)
            assert.equals(115, sy)
        end)
    end)

    describe("IsDrag", function()
        it("is false below the threshold", function()
            assert.is_false(MN.IsDrag(3, 0, 4))
            assert.is_false(MN.IsDrag(2, 2, 4))
        end)

        it("is true at exactly the threshold", function()
            assert.is_true(MN.IsDrag(4, 0, 4))
            assert.is_true(MN.IsDrag(0, -4, 4))
        end)

        it("is true above the threshold, also on a diagonal", function()
            assert.is_true(MN.IsDrag(3, 3, 4))
            assert.is_true(MN.IsDrag(-10, 5, 4))
        end)
    end)

    describe("NormalizePoint", function()
        local frame = {}

        it("accepts a point only", function()
            assert.same({ "TOPLEFT", nil, "TOPLEFT", 0, 0 }, { MN.NormalizePoint("TOPLEFT") })
        end)

        it("accepts a point and offsets", function()
            assert.same({ "TOPLEFT", nil, "TOPLEFT", 5, 6 }, { MN.NormalizePoint("TOPLEFT", 5, 6) })
        end)

        it("accepts a point and a frame", function()
            assert.same({ "TOPLEFT", frame, "TOPLEFT", 0, 0 }, { MN.NormalizePoint("TOPLEFT", frame) })
        end)

        it("accepts a point, a frame and a relative point", function()
            assert.same({ "TOPLEFT", frame, "TOP", 0, 0 }, { MN.NormalizePoint("TOPLEFT", frame, "TOP") })
        end)

        it("accepts a point, a frame and offsets", function()
            assert.same({ "TOPLEFT", frame, "TOPLEFT", 3, 4 }, { MN.NormalizePoint("TOPLEFT", frame, 3, 4) })
        end)

        it("accepts all five values", function()
            assert.same({ "TOPLEFT", frame, "TOP", 5, 6 }, { MN.NormalizePoint("TOPLEFT", frame, "TOP", 5, 6) })
        end)
    end)

    describe("ResolveRaw", function()
        it("keeps the raw value when the current value is the one we applied", function()
            assert.equals(3, MN.ResolveRaw(5, 5, 3))
        end)

        it("accepts the rounding of a 32-bit float", function()
            assert.equals(7, MN.ResolveRaw(123.45600128, 123.456, 7))
        end)

        it("takes the current value when Blizzard moved the icon", function()
            assert.equals(9, MN.ResolveRaw(9, 5, 3))
        end)

        it("takes the current value when nothing is applied yet", function()
            assert.equals(5, MN.ResolveRaw(5, nil, nil))
            assert.equals(5, MN.ResolveRaw(5, 5, nil))
        end)
    end)

    describe("IconPlacement", function()
        it("changes nothing at 1x", function()
            local scale, x, y = MN.IconPlacement(100, -50, 1, 1)
            assert.same({ 1, 100, -50 }, { scale, x, y })
        end)

        it("halves the scale and doubles the offsets at 2x", function()
            local scale, x, y = MN.IconPlacement(100, -50, 1, 2)
            assert.same({ 0.5, 200, -100 }, { scale, x, y })
        end)

        it("keeps the raw scale of the icon", function()
            local scale = MN.IconPlacement(0, 0, 0.8, 2)
            assert.near(0.4, scale, 1e-9)
        end)
    end)

    describe("HitInsets", function()
        it("is zero at 1x without scroll", function()
            assert.same({ 0, 0, 0, 0 }, { MN.HitInsets(0, 0, 600, 400, 1, 0.5) })
        end)

        it("hides the scrolled away parts at 2x", function()
            -- Unit is 2 * 0.5 = 1, so the insets are in viewport units.
            local left, right, top, bottom = MN.HitInsets(150, 100, 600, 400, 2, 0.5)
            assert.same({ 150, 450, 100, 300 }, { left, right, top, bottom })
        end)

        it("divides by the zoom and the scale of the frame", function()
            local left, right = MN.HitInsets(200, 0, 600, 400, 2, 0.5)
            assert.equals(200, left)
            assert.equals(400, right)
            left = MN.HitInsets(200, 0, 600, 400, 4, 0.5)
            assert.equals(100, left)
        end)
    end)

    describe("InView", function()
        it("is true inside the viewport and on its edges", function()
            assert.is_true(MN.InView(10, 10, 600, 400))
            assert.is_true(MN.InView(0, 0, 600, 400))
            assert.is_true(MN.InView(600, 400, 600, 400))
        end)

        it("is false outside the viewport", function()
            assert.is_false(MN.InView(-1, 10, 600, 400))
            assert.is_false(MN.InView(10, -1, 600, 400))
            assert.is_false(MN.InView(601, 10, 600, 400))
            assert.is_false(MN.InView(10, 401, 600, 400))
        end)
    end)

    describe("with the world map frames", function()
        local VIEW_W, VIEW_H = 1002 * 0.691, 668 * 0.691
        local viewport, zoomFrame, overlay

        -- Show the map, so the OnShow hook builds the frame tree.
        local function build()
            helper.runScript(WorldMapFrame, "OnShow")
            viewport, zoomFrame, overlay = MN.viewport, MN.zoomFrame, MN.overlay
            if viewport then
                viewport.left, viewport.top = 100, 500
            end
        end

        -- The wheel zooms in to 2^notches at the cursor (400, 300), and the driver runs to the end.
        local function zoomIn(notches)
            ns.db.mapNav.step = 2
            state.cursor = { x = 400, y = 300 }
            helper.runScript(viewport, "OnMouseWheel", notches or 1)
            helper.runScript(viewport, "OnUpdate", 10)
        end

        local function anchorOf(frame, index)
            local point, relativeTo, relativePoint, x, y = frame:GetPoint(index or 1)
            return { point, relativeTo, relativePoint, x, y }
        end

        local function near(expected, actual)
            assert.near(expected, actual, 1e-6)
        end

        describe("Build", function()
            it("hooks the map when the file loads", function()
                assert.equals(1, #state.hookLists.WorldMapFrame_Update)
                assert.equals(1, #state.hookLists.WorldMapFrame_DisplayQuestPOI)
                assert.equals(1, #state.hookLists.WorldMapFrame_ResetFrameLevels)
                assert.is_nil(MN.viewport)
            end)

            it("remembers a quest POI that Blizzard shows before the build", function()
                local poi = helper.newFrame()
                poi:SetPoint("CENTER", WorldMapPOIFrame, "TOPLEFT", 30, -40)
                WorldMapFrame_DisplayQuestPOI({ poiIcon = poi })
                assert.equals(1, poi:GetScale())
                build()
                zoomIn()
                assert.equals(0.5, poi:GetScale())
                assert.equals(60, anchorOf(poi)[4])
            end)

            it("builds when the map is shown", function()
                build()
                assert.is_true(MN.state.built)
                assert.equals("ScrollFrame", viewport.frameType)
                assert.equals(WorldMapFrame, viewport:GetParent())
            end)

            it("moves the four map frames into the zoom frame", function()
                build()
                assert.equals(zoomFrame, WorldMapDetailFrame:GetParent())
                assert.equals(zoomFrame, WorldMapBlobFrame:GetParent())
                assert.equals(zoomFrame, WorldMapButton:GetParent())
                assert.equals(zoomFrame, WorldMapPOIFrame:GetParent())
            end)

            it("nests viewport, scroll child and zoom frame", function()
                build()
                assert.equals(viewport, MN.scrollChild:GetParent())
                assert.equals(MN.scrollChild, zoomFrame:GetParent())
                assert.equals(MN.scrollChild, viewport.scrollChild)
            end)

            it("moves the area frame to the overlay and anchors it there", function()
                build()
                assert.equals(overlay, WorldMapFrameAreaFrame:GetParent())
                assert.same({ "TOP", overlay, "TOP", 0, -10 }, anchorOf(WorldMapFrameAreaFrame))
                assert.equals(1, WorldMapFrameAreaFrame:GetNumPoints())
            end)

            it("puts the overlay over the viewport, with the scale of the map button", function()
                build()
                assert.same({ "TOPLEFT", viewport, "TOPLEFT", 0, 0 }, anchorOf(overlay, 1))
                assert.same({ "BOTTOMRIGHT", viewport, "BOTTOMRIGHT", 0, 0 }, anchorOf(overlay, 2))
                assert.equals(0.691, overlay:GetScale())
            end)

            it("gives the viewport the point and the size of the scaled detail frame", function()
                build()
                local p = anchorOf(viewport)
                assert.equals("TOPLEFT", p[1])
                assert.equals(WorldMapPositioningGuide, p[2])
                assert.equals("TOP", p[3])
                near(-726 * 0.691, p[4])
                near(-99 * 0.691, p[5])
                near(VIEW_W, viewport:GetWidth())
                near(VIEW_H, viewport:GetHeight())
                near(VIEW_W, zoomFrame:GetWidth())
                near(VIEW_H, zoomFrame:GetHeight())
            end)

            it("anchors the detail frame to the top left of the zoom frame", function()
                build()
                assert.same({ "TOPLEFT", zoomFrame, "TOPLEFT", 0, 0 }, anchorOf(WorldMapDetailFrame))
                assert.equals(1, WorldMapDetailFrame:GetNumPoints())
            end)

            it("sets the frame levels", function()
                build()
                assert.equals(WorldMapFrame:GetFrameLevel(), viewport:GetFrameLevel())
                assert.equals(WorldMapFrame:GetFrameLevel(), zoomFrame:GetFrameLevel())
                assert.equals(WorldMapButton:GetFrameLevel() + 1, overlay:GetFrameLevel())
            end)

            it("keeps the Blizzard frame levels when it moves the zoom frames", function()
                build()
                local level = WorldMapFrame:GetFrameLevel()
                assert.equals(level + 1, WorldMapDetailFrame:GetFrameLevel())
                assert.equals(level + 2, WorldMapBlobFrame:GetFrameLevel())
                assert.equals(level + 3, WorldMapButton:GetFrameLevel())
                assert.equals(level + 4, WorldMapPOIFrame:GetFrameLevel())
            end)

            it("builds only once", function()
                build()
                local frames = #state.frames
                helper.runScript(WorldMapFrame, "OnShow")
                assert.equals(frames, #state.frames)
            end)

            it("does nothing when map navigation is off", function()
                ns.db.mapNav.enabled = false
                build()
                assert.is_nil(MN.viewport)
                assert.equals(WorldMapFrame, WorldMapDetailFrame:GetParent())
            end)

            it("does nothing in combat", function()
                state.combat = true
                build()
                assert.is_nil(MN.viewport)
                assert.equals(WorldMapFrame, WorldMapButton:GetParent())
            end)

            it("builds when it is switched on while the map is shown", function()
                ns.db.mapNav.enabled = false
                WorldMapFrame:Show()
                build()
                assert.is_nil(MN.viewport)
                MN.SetEnabled(true)
                assert.is_true(MN.state.built)
            end)
        end)

        describe("WorldMapDetailFrame:SetPoint", function()
            before_each(build)

            it("moves the viewport with the offsets times the scale", function()
                WorldMapDetailFrame:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 10, -20)
                local p = anchorOf(viewport)
                assert.equals("TOPLEFT", p[1])
                assert.equals(WorldMapFrame, p[2])
                near(6.91, p[4])
                near(-13.82, p[5])
                assert.equals(1, viewport:GetNumPoints())
            end)

            it("puts the detail frame back in the zoom frame without recursion", function()
                local before = #WorldMapDetailFrame.calls.SetPoint
                WorldMapDetailFrame:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 10, -20)
                -- The call of Blizzard and one call of ours.
                assert.equals(before + 2, #WorldMapDetailFrame.calls.SetPoint)
                assert.same({ "TOPLEFT", zoomFrame, "TOPLEFT", 0, 0 }, anchorOf(WorldMapDetailFrame))
                assert.equals(1, WorldMapDetailFrame:GetNumPoints())
            end)

            it("uses WorldMapFrame when the relative frame is nil", function()
                WorldMapDetailFrame:SetPoint("TOPLEFT", 10, -20)
                local p = anchorOf(viewport)
                assert.equals(WorldMapFrame, p[2])
                assert.equals("TOPLEFT", p[3])
                near(6.91, p[4])
            end)

            it("resolves a frame name", function()
                WorldMapDetailFrame:SetPoint("TOPLEFT", "WorldMapPositioningGuide", "TOP", -700, -90)
                local p = anchorOf(viewport)
                assert.equals(WorldMapPositioningGuide, p[2])
                assert.equals("TOP", p[3])
                near(-700 * 0.691, p[4])
                near(-90 * 0.691, p[5])
            end)
        end)

        describe("WorldMapDetailFrame:SetScale", function()
            before_each(build)

            it("resizes the viewport", function()
                WorldMapDetailFrame:SetScale(0.5)
                near(501, viewport:GetWidth())
                near(334, viewport:GetHeight())
                near(501, zoomFrame:GetWidth())
                near(-726 * 0.5, anchorOf(viewport)[4])
            end)

            it("resets the zoom", function()
                zoomIn()
                assert.equals(2, MN.GetZoom())
                WorldMapDetailFrame:SetScale(0.5)
                assert.equals(1, MN.GetZoom())
                assert.equals(1, zoomFrame:GetScale())
                near(501, MN.scrollChild:GetWidth())
            end)

            it("gives the overlay the scale of the map button", function()
                WorldMapButton:SetScale(0.8)
                assert.equals(0.8, overlay:GetScale())
            end)
        end)

        describe("dependent frames and regions", function()
            before_each(build)

            it("moves points on the detail frame or the map button to the viewport", function()
                assert.same({ "TOPLEFT", viewport, "TOPRIGHT", 6, 0 }, anchorOf(WorldMapQuestScrollFrame))
                assert.equals(viewport, anchorOf(WorldMapFrameTitle)[2])
            end)

            it("leaves other points alone", function()
                assert.equals(WorldMapPositioningGuide, anchorOf(WorldMapTrackQuest)[2])
            end)

            it("moves a point that Blizzard sets later", function()
                WorldMapTrackQuest:SetPoint("BOTTOMLEFT", WorldMapDetailFrame, "BOTTOMLEFT", 2, -26)
                assert.same({ "BOTTOMLEFT", viewport, "BOTTOMLEFT", 2, -26 }, anchorOf(WorldMapTrackQuest))
                assert.equals(1, WorldMapTrackQuest:GetNumPoints())
            end)

            it("does not redirect the player arrow", function()
                assert.equals(WorldMapDetailFrame, anchorOf(PlayerArrowFrame)[2])
                PlayerArrowFrame:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", 5, -5)
                assert.equals(WorldMapDetailFrame, anchorOf(PlayerArrowFrame)[2])
            end)
        end)

        describe("mouse wheel", function()
            before_each(build)

            it("raises the target zoom and starts the driver", function()
                ns.db.mapNav.step = 2
                state.cursor = { x = 400, y = 300 }
                helper.runScript(viewport, "OnMouseWheel", 1)
                assert.equals(2, MN.state.targetZoom)
                assert.equals(1, MN.GetZoom())
                assert.is_function(viewport:GetScript("OnUpdate"))
                assert.equals(300, MN.state.anchorX)
                assert.equals(200, MN.state.anchorY)
            end)

            it("also works on the map button", function()
                ns.db.mapNav.step = 2
                state.cursor = { x = 400, y = 300 }
                helper.runScript(WorldMapButton, "OnMouseWheel", 1)
                assert.equals(2, MN.state.targetZoom)
            end)

            it("reaches the target and applies it when the driver runs", function()
                zoomIn()
                assert.equals(2, MN.GetZoom())
                assert.equals(2, zoomFrame:GetScale())
                near(VIEW_W * 2, MN.scrollChild:GetWidth())
                near(VIEW_H * 2, MN.scrollChild:GetHeight())
                -- The point under the cursor stays: 2 * 300 - 300 and 2 * 200 - 200.
                near(300, viewport:GetHorizontalScroll())
                near(200, viewport:GetVerticalScroll())
                assert.is_nil(viewport:GetScript("OnUpdate"))
            end)

            it("eases in small steps", function()
                ns.db.mapNav.step = 2
                helper.runScript(viewport, "OnMouseWheel", 1)
                helper.runScript(viewport, "OnUpdate", 0.01)
                assert.is_true(MN.GetZoom() > 1 and MN.GetZoom() < 2)
                assert.is_function(viewport:GetScript("OnUpdate"))
            end)

            it("limits the zoom to the maximum", function()
                zoomIn(5)
                assert.equals(ns.db.mapNav.maxZoom, MN.GetZoom())
            end)

            it("does nothing when zooming out at 1x", function()
                helper.runScript(viewport, "OnMouseWheel", -1)
                assert.equals(1, MN.state.targetZoom)
                assert.is_nil(viewport:GetScript("OnUpdate"))
            end)

            it("is ignored while map navigation is off", function()
                ns.db.mapNav.enabled = false
                helper.runScript(viewport, "OnMouseWheel", 1)
                assert.equals(1, MN.state.targetZoom)
                assert.is_nil(viewport:GetScript("OnUpdate"))
            end)

            it("limits the hit rect of the map button to the viewport", function()
                zoomIn()
                local expected = { MN.HitInsets(300, 200, VIEW_W, VIEW_H, 2, 0.691) }
                for i = 1, 4 do
                    near(expected[i], WorldMapButton.hitInsets[i])
                end
                near(300 / (2 * 0.691), WorldMapButton.hitInsets[1])
            end)
        end)

        describe("drag", function()
            before_each(build)

            it("starts on a left press when zoomed in", function()
                zoomIn()
                state.cursor = { x = 400, y = 300 }
                helper.runScript(WorldMapButton, "OnMouseDown", "LeftButton")
                assert.is_true(MN.state.panning)
                assert.is_false(MN.state.moved)
                assert.is_function(viewport:GetScript("OnUpdate"))
            end)

            it("does not start at 1x", function()
                helper.runScript(WorldMapButton, "OnMouseDown", "LeftButton")
                assert.is_false(MN.state.panning)
                assert.is_nil(viewport:GetScript("OnUpdate"))
            end)

            it("does not start with the right button", function()
                zoomIn()
                helper.runScript(WorldMapButton, "OnMouseDown", "RightButton")
                assert.is_false(MN.state.panning)
            end)

            it("pans once the cursor moves past the threshold", function()
                zoomIn()
                state.cursor = { x = 400, y = 300 }
                helper.runScript(WorldMapButton, "OnMouseDown", "LeftButton")
                state.mouseDown.LeftButton = true
                state.cursor = { x = 450, y = 300 }
                helper.runScript(viewport, "OnUpdate", 0.01)
                assert.is_true(MN.state.moved)
                assert.same({ n = 1, false }, helper.lastCall(WorldMapButton, "EnableMouse"))
                assert.is_false(WorldMapButton:IsMouseEnabled())
                -- The cursor went 50 pixels right, so the scroll goes 50 left.
                near(250, viewport:GetHorizontalScroll())
                near(200, viewport:GetVerticalScroll())
            end)

            it("keeps the scroll inside the map", function()
                zoomIn()
                state.cursor = { x = 400, y = 300 }
                helper.runScript(WorldMapButton, "OnMouseDown", "LeftButton")
                state.mouseDown.LeftButton = true
                state.cursor = { x = 5000, y = 5000 }
                helper.runScript(viewport, "OnUpdate", 0.01)
                assert.equals(0, viewport:GetHorizontalScroll())
                near(VIEW_H, viewport:GetVerticalScroll())
            end)

            it("is a click when the cursor moves less than the threshold", function()
                zoomIn()
                state.cursor = { x = 400, y = 300 }
                helper.runScript(WorldMapButton, "OnMouseDown", "LeftButton")
                state.mouseDown.LeftButton = true
                state.cursor = { x = 402, y = 301 }
                helper.runScript(viewport, "OnUpdate", 0.01)
                assert.is_false(MN.state.moved)
                assert.is_nil(helper.lastCall(WorldMapButton, "EnableMouse"))
                near(300, viewport:GetHorizontalScroll())
            end)

            it("ends and enables the mouse again when the button is released", function()
                zoomIn()
                state.cursor = { x = 400, y = 300 }
                helper.runScript(WorldMapButton, "OnMouseDown", "LeftButton")
                state.mouseDown.LeftButton = true
                state.cursor = { x = 450, y = 300 }
                helper.runScript(viewport, "OnUpdate", 0.01)
                state.mouseDown.LeftButton = false
                helper.runScript(viewport, "OnUpdate", 0.01)
                assert.same({ n = 1, true }, helper.lastCall(WorldMapButton, "EnableMouse"))
                assert.is_true(WorldMapButton:IsMouseEnabled())
                assert.is_false(MN.state.panning)
                assert.is_false(MN.state.moved)
                assert.is_nil(viewport:GetScript("OnUpdate"))
            end)

            it("ignores the wheel while panning", function()
                zoomIn()
                helper.runScript(WorldMapButton, "OnMouseDown", "LeftButton")
                helper.runScript(viewport, "OnMouseWheel", 1)
                assert.equals(2, MN.state.targetZoom)
            end)
        end)

        describe("icons", function()
            before_each(build)

            local function place(frame, x, y)
                frame:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", x, y)
            end

            it("counter-scales a unit icon at 2x", function()
                zoomIn()
                place(WorldMapPlayer, 100, -50)
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                assert.equals(0.5, WorldMapPlayer:GetScale())
                assert.same({ "CENTER", WorldMapDetailFrame, "TOPLEFT", 200, -100 }, anchorOf(WorldMapPlayer))
            end)

            it("does not move a hidden unit icon on update", function()
                zoomIn()
                place(WorldMapPlayer, 100, -50)
                WorldMapPlayer:Hide()
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                assert.equals(1, WorldMapPlayer:GetScale())
                assert.equals(100, anchorOf(WorldMapPlayer)[4])
            end)

            it("places the party and raid icons and the vehicles too", function()
                zoomIn()
                local vehicle = helper.newFrame()
                MAP_VEHICLES[1] = vehicle
                place(WorldMapParty2, 40, -10)
                place(WorldMapRaid40, 60, -20)
                place(vehicle, 80, -30)
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                assert.same({ 0.5, 80, -20 }, { WorldMapParty2:GetScale(), anchorOf(WorldMapParty2)[4],
                    anchorOf(WorldMapParty2)[5] })
                assert.equals(120, anchorOf(WorldMapRaid40)[4])
                assert.equals(160, anchorOf(vehicle)[4])
            end)

            it("does not compound when Blizzard sets the raw point again", function()
                zoomIn()
                place(WorldMapPlayer, 100, -50)
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                place(WorldMapPlayer, 100, -50)
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                assert.equals(0.5, WorldMapPlayer:GetScale())
                assert.same({ "CENTER", WorldMapDetailFrame, "TOPLEFT", 200, -100 }, anchorOf(WorldMapPlayer))
            end)

            it("does not compound without a new Blizzard point", function()
                zoomIn()
                place(WorldMapPlayer, 100, -50)
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                assert.equals(0.5, WorldMapPlayer:GetScale())
                assert.equals(200, anchorOf(WorldMapPlayer)[4])
            end)

            it("takes a new raw position from Blizzard", function()
                zoomIn()
                place(WorldMapPlayer, 100, -50)
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                place(WorldMapPlayer, 120, -60)
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                assert.same({ "CENTER", WorldMapDetailFrame, "TOPLEFT", 240, -120 }, anchorOf(WorldMapPlayer))
            end)

            it("restores the raw values when the zoom goes back to 1", function()
                zoomIn()
                place(WorldMapPlayer, 100, -50)
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                MN.ResetZoom()
                assert.equals(1, WorldMapPlayer:GetScale())
                assert.same({ "CENTER", WorldMapDetailFrame, "TOPLEFT", 100, -50 }, anchorOf(WorldMapPlayer))
            end)

            it("does nothing on update at 1x", function()
                place(WorldMapPlayer, 100, -50)
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                assert.equals(1, WorldMapPlayer:GetScale())
                assert.equals(100, anchorOf(WorldMapPlayer)[4])
            end)

            it("skips an icon without a point", function()
                zoomIn()
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                assert.equals(1, WorldMapPlayer:GetScale())
                assert.equals(0, WorldMapPlayer:GetNumPoints())
            end)

            it("places a quest POI at zoom above 1", function()
                zoomIn()
                local poi = helper.newFrame()
                place(poi, 30, -40)
                WorldMapFrame_DisplayQuestPOI({ poiIcon = poi })
                assert.equals(0.5, poi:GetScale())
                assert.equals(60, anchorOf(poi)[4])
                assert.equals(-80, anchorOf(poi)[5])
            end)

            it("remembers a quest POI from 1x and places it on zoom", function()
                local poi = helper.newFrame()
                place(poi, 30, -40)
                WorldMapFrame_DisplayQuestPOI({ poiIcon = poi })
                assert.equals(1, poi:GetScale())
                zoomIn()
                assert.equals(0.5, poi:GetScale())
                assert.equals(60, anchorOf(poi)[4])
            end)

            it("counter-scales the swap button of a selected completed quest on zoom", function()
                local poi, swap = helper.newFrame(), helper.newFrame()
                place(poi, 30, -40)
                swap:SetPoint("CENTER", poi)
                QUEST_POI_SWAP_BUTTONS.WorldMapPOIFrame = swap
                WorldMapFrame_DisplayQuestPOI({ poiIcon = poi })
                zoomIn()
                assert.equals(0.5, swap:GetScale())
                assert.same({ "CENTER", poi, "CENTER", 0, 0 }, anchorOf(swap))
                MN.ResetZoom()
                assert.equals(1, swap:GetScale())
            end)

            it("counter-scales the swap button when Blizzard makes it at zoom above 1", function()
                zoomIn()
                local poi, swap = helper.newFrame(), helper.newFrame()
                place(poi, 30, -40)
                swap:SetPoint("CENTER", poi)
                QUEST_POI_SWAP_BUTTONS.WorldMapPOIFrame = swap
                WorldMapFrame_DisplayQuestPOI({ poiIcon = poi })
                assert.equals(0.5, swap:GetScale())
            end)

            it("ignores a quest frame without a POI icon", function()
                WorldMapFrame_DisplayQuestPOI({})
                assert.is_true(MN.state.built)
            end)

            it("places the landmarks on a map update at zoom above 1", function()
                _G.NUM_WORLDMAP_POIS = 1
                local landmark = helper.newFrame()
                _G.WorldMapFramePOI1 = landmark
                place(landmark, 10, -10)
                WorldMapFrame_Update()
                zoomIn()
                assert.equals(0.5, landmark:GetScale())
                landmark:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", 50, -50)
                WorldMapFrame_Update()
                assert.equals(100, anchorOf(landmark)[4])
                _G.WorldMapFramePOI1 = nil
            end)

            it("hides the highlight and the label when the cursor is outside the viewport", function()
                zoomIn()
                viewport.mouseOver = false
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                assert.is_false(WorldMapHighlight:IsShown())
                assert.same({ n = 1, nil }, helper.lastCall(WorldMapFrameAreaLabel, "SetText"))
            end)

            it("keeps the highlight when the cursor is over the viewport", function()
                zoomIn()
                viewport.mouseOver = true
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                assert.is_true(WorldMapHighlight:IsShown())
                assert.is_nil(helper.lastCall(WorldMapFrameAreaLabel, "SetText"))
            end)
        end)

        describe("player arrow", function()
            before_each(build)

            it("is moved with the zoomed offsets at 2x", function()
                zoomIn()
                state.player = { x = 0.5, y = 0.5 }
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                assert.equals(1, #state.arrowPositions)
                local args = state.arrowPositions[1]
                assert.equals("CENTER", args[1])
                assert.equals("WorldMapDetailFrame", args[2])
                assert.equals("TOPLEFT", args[3])
                near(0.5 * 1002 * 0.691 * 2, args[4])
                near(-0.5 * 668 * 0.691 * 2, args[5])
                assert.equals(0, #state.arrowShows)
            end)

            it("is hidden when it is outside the viewport", function()
                zoomIn()
                state.player = { x = 0.1, y = 0.1 }
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                assert.equals(1, #state.arrowPositions)
                assert.same({ n = 1, nil }, state.arrowShows[1])
            end)

            it("is left alone at 1x", function()
                state.player = { x = 0.5, y = 0.5 }
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                assert.equals(0, #state.arrowPositions)
            end)

            it("is left alone when the position is unknown", function()
                zoomIn()
                state.player = { x = 0, y = 0 }
                helper.runScript(WorldMapButton, "OnUpdate", 0.01)
                assert.equals(0, #state.arrowPositions)
                assert.equals(0, #state.arrowShows)
            end)
        end)

        describe("resets", function()
            before_each(build)

            local function assertReset()
                assert.equals(1, MN.GetZoom())
                assert.equals(1, MN.state.targetZoom)
                assert.equals(0, MN.state.scrollX)
                assert.equals(0, MN.state.scrollY)
                assert.equals(1, zoomFrame:GetScale())
                assert.equals(0, viewport:GetHorizontalScroll())
                assert.equals(0, viewport:GetVerticalScroll())
                assert.is_nil(viewport:GetScript("OnUpdate"))
            end

            it("happens when the map hides", function()
                zoomIn()
                helper.runScript(WorldMapFrame, "OnHide")
                assertReset()
            end)

            it("happens when the map changes", function()
                WorldMapFrame_Update()
                zoomIn()
                WorldMapFrame_Update()
                assert.equals(2, MN.GetZoom())
                state.map.area = 2
                WorldMapFrame_Update()
                assertReset()
            end)

            it("happens when the continent or the dungeon level changes", function()
                WorldMapFrame_Update()
                zoomIn()
                state.map.continent = 2
                WorldMapFrame_Update()
                assertReset()
                zoomIn()
                state.map.level = 1
                WorldMapFrame_Update()
                assertReset()
            end)

            it("happens when map navigation is switched off", function()
                zoomIn()
                MN.SetEnabled(false)
                assert.is_false(ns.db.mapNav.enabled)
                assertReset()
            end)

            it("stops a drag", function()
                zoomIn()
                helper.runScript(WorldMapButton, "OnMouseDown", "LeftButton")
                state.mouseDown.LeftButton = true
                state.cursor = { x = 500, y = 300 }
                helper.runScript(viewport, "OnUpdate", 0.01)
                assert.is_true(MN.state.moved)
                MN.ResetZoom()
                assert.is_false(MN.state.panning)
                assert.is_true(WorldMapButton:IsMouseEnabled())
            end)

            it("does nothing before the frames are built", function()
                local ns2 = helper.newNamespace()
                helper.loadAddonFile("Atlasium/Util.lua", ns2)
                helper.loadAddonFile("Atlasium/Core.lua", ns2)
                helper.loadAddonFile("Atlasium/MapNavigation.lua", ns2)
                ns2.MapNavigation.ResetZoom()
                assert.equals(1, ns2.MapNavigation.GetZoom())
            end)
        end)

        describe("quest blob", function()
            local selected

            local function blobDraws()
                return WorldMapBlobFrame.calls.DrawQuestBlob or {}
            end

            before_each(function()
                build()
                selected = { questId = 7, completed = false, shown = true }
                function selected:IsShown() return self.shown end
                WORLDMAP_SETTINGS.selectedQuest = selected
            end)

            it("does not draw at 1x", function()
                MN.ResetZoom()
                assert.equals(0, #blobDraws())
            end)

            it("clears and draws the selected blob again after a zoom", function()
                zoomIn()
                local draws = blobDraws()
                assert.same({ n = 2, 7, false }, draws[#draws - 1])
                assert.same({ n = 2, 7, true }, draws[#draws])
            end)

            it("draws the selected blob again after a pan", function()
                zoomIn()
                WorldMapBlobFrame.calls.DrawQuestBlob = nil
                state.cursor = { x = 400, y = 300 }
                helper.runScript(WorldMapButton, "OnMouseDown", "LeftButton")
                state.mouseDown.LeftButton = true
                state.cursor = { x = 450, y = 300 }
                helper.runScript(viewport, "OnUpdate", 0.01)
                assert.equals(2, #blobDraws())
            end)

            it("draws once more on the way back to 1x, then stops", function()
                zoomIn()
                WorldMapBlobFrame.calls.DrawQuestBlob = nil
                MN.ResetZoom()
                MN.ResetZoom()
                assert.equals(2, #blobDraws())
            end)

            it("skips a completed quest and a hidden quest frame", function()
                selected.completed = true
                zoomIn()
                selected.completed, selected.shown = false, false
                zoomIn()
                assert.equals(0, #blobDraws())
            end)
        end)

        describe("combat", function()
            local selected

            before_each(function()
                build()
                selected = { questId = 42, completed = false }
                WORLDMAP_SETTINGS.selectedQuest = selected
            end)

            local function startCombat()
                ns.Core.OnEvent(nil, "PLAYER_REGEN_DISABLED")
            end

            local function endCombat()
                ns.Core.OnEvent(nil, "PLAYER_REGEN_ENABLED")
            end

            it("registers both events", function()
                assert.is_true(state.events.PLAYER_REGEN_DISABLED)
                assert.is_true(state.events.PLAYER_REGEN_ENABLED)
            end)

            it("detaches the blob frame and shadows its methods", function()
                startCombat()
                assert.is_true(MN.state.blobDetached)
                assert.is_nil(WorldMapBlobFrame:GetParent())
                assert.is_false(WorldMapBlobFrame:IsShown())
                assert.is_function(rawget(WorldMapBlobFrame, "Hide"))
                assert.is_function(rawget(WorldMapBlobFrame, "Show"))
                assert.is_function(rawget(WorldMapBlobFrame, "SetScale"))
                assert.same({ "TOP", UIParent, "BOTTOM", 0, 0 }, anchorOf(WorldMapBlobFrame))
            end)

            it("ignores Show and SetScale while it is detached", function()
                startCombat()
                WorldMapBlobFrame:Show()
                WorldMapBlobFrame:SetScale(0.8)
                assert.is_false(WorldMapBlobFrame:IsShown())
                assert.equals(0.691, WorldMapBlobFrame:GetScale())
            end)

            it("keeps the blob out of the zoom changes during combat", function()
                WorldMapBlobFrame.xRatio = 5
                startCombat()
                zoomIn()
                assert.equals(5, WorldMapBlobFrame.xRatio)
                assert.is_nil(WorldMapBlobFrame:GetParent())
                assert.is_nil(WorldMapBlobFrame.calls.DrawQuestBlob)
            end)

            it("puts the blob frame back after combat", function()
                startCombat()
                endCombat()
                assert.is_false(MN.state.blobDetached)
                assert.equals(zoomFrame, WorldMapBlobFrame:GetParent())
                assert.same({ "TOPLEFT", WorldMapDetailFrame, "TOPLEFT", 0, 0 }, anchorOf(WorldMapBlobFrame))
                assert.equals(WorldMapDetailFrame:GetFrameLevel() + 1, WorldMapBlobFrame:GetFrameLevel())
                assert.is_nil(rawget(WorldMapBlobFrame, "Hide"))
                assert.is_nil(rawget(WorldMapBlobFrame, "Show"))
                assert.is_nil(rawget(WorldMapBlobFrame, "SetScale"))
                assert.is_true(WorldMapBlobFrame:IsShown())
            end)

            it("puts the frames above the blob back after it, with their levels", function()
                local button, poi = WorldMapButton:GetFrameLevel(), WorldMapPOIFrame:GetFrameLevel()
                startCombat()
                endCombat()
                assert.same({ WorldMapDetailFrame, WorldMapBlobFrame, WorldMapButton, WorldMapPOIFrame },
                    { zoomFrame:GetChildren() })
                assert.equals(button, WorldMapButton:GetFrameLevel())
                assert.equals(poi, WorldMapPOIFrame:GetFrameLevel())
            end)

            it("keeps a blob that was hidden before combat hidden", function()
                WorldMapBlobFrame:Hide()
                startCombat()
                endCombat()
                assert.is_false(WorldMapBlobFrame:IsShown())
            end)

            it("applies a scale that was set during combat", function()
                startCombat()
                WorldMapBlobFrame:SetScale(0.8)
                endCombat()
                assert.equals(0.8, WorldMapBlobFrame:GetScale())
            end)

            it("clears the cached hit math", function()
                startCombat()
                WorldMapBlobFrame.xRatio = 5
                endCombat()
                assert.is_nil(WorldMapBlobFrame.xRatio)
            end)

            it("draws the selected quest again, with the highlight one frame later", function()
                startCombat()
                endCombat()
                assert.same({ n = 2, 42, false }, helper.lastCall(WorldMapBlobFrame, "DrawQuestBlob"))
                local restorer = state.frames[#state.frames]
                helper.runScript(restorer, "OnUpdate", 0.01)
                assert.same({ n = 2, 42, true }, helper.lastCall(WorldMapBlobFrame, "DrawQuestBlob"))
                assert.equals(2, #WorldMapBlobFrame.calls.DrawQuestBlob)
                assert.is_nil(restorer:GetScript("OnUpdate"))
            end)

            it("does not draw the highlight of a completed quest", function()
                selected.completed = true
                startCombat()
                endCombat()
                helper.runScript(state.frames[#state.frames], "OnUpdate", 0.01)
                assert.equals(1, #WorldMapBlobFrame.calls.DrawQuestBlob)
            end)

            it("does nothing when it ends without a start", function()
                endCombat()
                assert.equals(zoomFrame, WorldMapBlobFrame:GetParent())
                assert.is_nil(WorldMapBlobFrame.calls.DrawQuestBlob)
            end)

            it("does nothing before the frames are built", function()
                local ns2 = helper.newNamespace()
                helper.loadAddonFile("Atlasium/Util.lua", ns2)
                helper.loadAddonFile("Atlasium/Core.lua", ns2)
                helper.loadAddonFile("Atlasium/MapNavigation.lua", ns2)
                ns2.MapNavigation.OnCombatStart()
                assert.is_false(ns2.MapNavigation.state.blobDetached)
            end)
        end)
    end)
end)
