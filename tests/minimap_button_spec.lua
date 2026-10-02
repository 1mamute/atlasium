local helper = require("tests.helper")

describe("MinimapButton", function()
    local ns, state, MinimapButton

    before_each(function()
        state = helper.installWowStubs()
        ns = helper.newNamespace()
        helper.loadAddonFile("Atlasium/Util.lua", ns)
        helper.loadAddonFile("Atlasium/Core.lua", ns)
        helper.loadAddonFile("Atlasium/MinimapButton.lua", ns)
        MinimapButton = ns.MinimapButton
    end)

    local function assertOffset(expectedX, expectedY, x, y)
        assert.near(expectedX, x, 0.05)
        assert.near(expectedY, y, 0.05)
    end

    describe("GetOffset", function()
        it("puts the button on a circle on a round minimap", function()
            assertOffset(80, 0, MinimapButton.GetOffset(0, 140, 140, "ROUND"))
            assertOffset(0, 80, MinimapButton.GetOffset(90, 140, 140, "ROUND"))
            assertOffset(-80, 0, MinimapButton.GetOffset(180, 140, 140, "ROUND"))
            assertOffset(0, -80, MinimapButton.GetOffset(270, 140, 140, "ROUND"))
            assertOffset(-56.6, -56.6, MinimapButton.GetOffset(225, 140, 140, "ROUND"))
        end)

        it("pushes the button into the corner on a square minimap", function()
            assertOffset(72.9, 72.9, MinimapButton.GetOffset(45, 140, 140, "SQUARE"))
        end)

        it("limits each value to the radius on a square minimap", function()
            assertOffset(80, 51.6, MinimapButton.GetOffset(30, 140, 140, "SQUARE"))
        end)

        -- Questie's 3.3.5 LibDBIcon (Rev 15) makes the bottom-right quarter round for CORNER-TOPLEFT.
        it("is round only in the top-left quarter for CORNER-TOPLEFT", function()
            assertOffset(-56.6, 56.6, MinimapButton.GetOffset(135, 140, 140, "CORNER-TOPLEFT"))
            assertOffset(72.9, 72.9, MinimapButton.GetOffset(45, 140, 140, "CORNER-TOPLEFT"))
            assertOffset(-72.9, -72.9, MinimapButton.GetOffset(225, 140, 140, "CORNER-TOPLEFT"))
            assertOffset(72.9, -72.9, MinimapButton.GetOffset(315, 140, 140, "CORNER-TOPLEFT"))
        end)

        describe("follows the shape name rule", function()
            local QUARTER_ANGLES = { TOPRIGHT = 45, TOPLEFT = 135, BOTTOMLEFT = 225, BOTTOMRIGHT = 315 }

            local function roundQuarters(shape)
                local round = {}
                for quarter, angle in pairs(QUARTER_ANGLES) do
                    local x = MinimapButton.GetOffset(angle, 140, 140, shape)
                    -- A round quarter gives 56.6 at 45 degrees, a square one 72.9.
                    if math.abs(x) < 60 then
                        table.insert(round, quarter)
                    end
                end
                table.sort(round)
                return round
            end

            local expected = {
                ROUND = { "BOTTOMLEFT", "BOTTOMRIGHT", "TOPLEFT", "TOPRIGHT" },
                SQUARE = {},
                ["CORNER-TOPLEFT"] = { "TOPLEFT" },
                ["CORNER-TOPRIGHT"] = { "TOPRIGHT" },
                ["CORNER-BOTTOMLEFT"] = { "BOTTOMLEFT" },
                ["CORNER-BOTTOMRIGHT"] = { "BOTTOMRIGHT" },
                ["SIDE-LEFT"] = { "BOTTOMLEFT", "TOPLEFT" },
                ["SIDE-RIGHT"] = { "BOTTOMRIGHT", "TOPRIGHT" },
                ["SIDE-TOP"] = { "TOPLEFT", "TOPRIGHT" },
                ["SIDE-BOTTOM"] = { "BOTTOMLEFT", "BOTTOMRIGHT" },
                ["TRICORNER-TOPLEFT"] = { "BOTTOMLEFT", "TOPLEFT", "TOPRIGHT" },
                ["TRICORNER-TOPRIGHT"] = { "BOTTOMRIGHT", "TOPLEFT", "TOPRIGHT" },
                ["TRICORNER-BOTTOMLEFT"] = { "BOTTOMLEFT", "BOTTOMRIGHT", "TOPLEFT" },
                ["TRICORNER-BOTTOMRIGHT"] = { "BOTTOMLEFT", "BOTTOMRIGHT", "TOPRIGHT" },
            }

            for shape, quarters in pairs(expected) do
                it(shape, function()
                    assert.same(quarters, roundQuarters(shape))
                end)
            end
        end)

        it("works as ROUND for an unknown or missing shape", function()
            assertOffset(56.6, 56.6, MinimapButton.GetOffset(45, 140, 140, "HEXAGON"))
            assertOffset(-56.6, -56.6, MinimapButton.GetOffset(225, 140, 140, nil))
        end)

        it("uses the minimap size for the radius", function()
            assertOffset(110, 0, MinimapButton.GetOffset(0, 200, 160, "ROUND"))
            assertOffset(0, 90, MinimapButton.GetOffset(90, 200, 160, "ROUND"))
            assertOffset(102.9, 82.9, MinimapButton.GetOffset(45, 200, 160, "SQUARE"))
        end)
    end)

    describe("AngleFromCursor", function()
        it("uses 0 for right, 90 for top, 180 for left and 270 for bottom", function()
            assert.near(0, MinimapButton.AngleFromCursor(110, 100, 100, 100), 1e-9)
            assert.near(90, MinimapButton.AngleFromCursor(100, 110, 100, 100), 1e-9)
            assert.near(180, MinimapButton.AngleFromCursor(90, 100, 100, 100), 1e-9)
            assert.near(270, MinimapButton.AngleFromCursor(100, 90, 100, 100), 1e-9)
        end)

        it("stays between 0 and 360 for a cursor below or to the left of the center", function()
            assert.near(225, MinimapButton.AngleFromCursor(90, 90, 100, 100), 1e-9)
            assert.near(315, MinimapButton.AngleFromCursor(110, 90, 100, 100), 1e-9)
            for degrees = 0, 355, 5 do
                local angle = math.rad(degrees)
                local result = MinimapButton.AngleFromCursor(100 + math.cos(angle), 100 + math.sin(angle), 100, 100)
                assert.is_true(result >= 0 and result < 360)
            end
        end)
    end)

    describe("GetTooltipAnchor", function()
        local function anchor(x, y)
            return { MinimapButton.GetTooltipAnchor(x, y, 1024, 768) }
        end

        it("opens the tooltip below the button in the top half of the screen", function()
            assert.same({ "TOPRIGHT", "BOTTOMRIGHT" }, anchor(900, 700))
            assert.same({ "TOPLEFT", "BOTTOMLEFT" }, anchor(100, 700))
            assert.same({ "TOP", "BOTTOM" }, anchor(512, 700))
        end)

        it("opens the tooltip above the button in the bottom half of the screen", function()
            assert.same({ "BOTTOMRIGHT", "TOPRIGHT" }, anchor(900, 100))
            assert.same({ "BOTTOMLEFT", "TOPLEFT" }, anchor(100, 100))
            assert.same({ "BOTTOM", "TOP" }, anchor(512, 384))
        end)
    end)

    describe("in the game", function()
        local function login()
            ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
            ns.Core.OnEvent(nil, "PLAYER_LOGIN")
            return MinimapButton.frame
        end

        local function lastPoint(frame)
            local call = helper.lastCall(frame, "SetPoint")
            return call[1], call[2], call[3], call[4], call[5]
        end

        it("registers PLAYER_LOGIN when the file loads", function()
            assert.is_true(state.events.PLAYER_LOGIN)
        end)

        it("creates the named button on the minimap at login", function()
            local frame = login()
            assert.equals(frame, _G.AtlasiumMinimapButton)
            assert.equals("Button", frame.frameType)
            assert.equals(Minimap, frame:GetParent())
            assert.is_true(frame:IsShown())
        end)

        it("places the button at the saved angle", function()
            local frame = login()
            local point, relativeTo, relativePoint, x, y = lastPoint(frame)
            assert.equals("CENTER", point)
            assert.equals(Minimap, relativeTo)
            assert.equals("CENTER", relativePoint)
            assertOffset(-56.6, -56.6, x, y)
        end)

        it("uses the shape from GetMinimapShape when an add-on defines it", function()
            _G.GetMinimapShape = function() return "SQUARE" end
            _G.AtlasiumDB = { minimap = { angle = 45 } }
            local frame = login()
            local _, _, _, x, y = lastPoint(frame)
            assertOffset(72.9, 72.9, x, y)
        end)

        it("keeps the button hidden at login when hide is set", function()
            _G.AtlasiumDB = { minimap = { hide = true } }
            assert.is_false(login():IsShown())
        end)

        it("hides and shows the button with /atlasium minimap", function()
            local frame = login()
            SlashCmdList.ATLASIUM("minimap")
            assert.is_true(ns.db.minimap.hide)
            assert.is_false(frame:IsShown())
            assert.matches("minimap button hidden", state.messages[1])
            SlashCmdList.ATLASIUM("minimap")
            assert.is_false(ns.db.minimap.hide)
            assert.is_true(frame:IsShown())
            assert.matches("minimap button shown", state.messages[2])
        end)

        it("toggles the world map on a left-click only", function()
            local frame = login()
            local onClick = frame:GetScript("OnClick")
            onClick(frame, "RightButton")
            assert.same({}, state.toggled)
            onClick(frame, "LeftButton")
            assert.same({ WorldMapFrame }, state.toggled)
        end)

        it("saves the angle from the cursor while the player drags the button", function()
            local frame = login()
            Minimap.GetEffectiveScale = function() return 2 end
            -- Minimap center is (940, 680), so this cursor is straight above it after scaling.
            state.cursor = { x = 1880, y = 1560 }
            frame:GetScript("OnDragStart")(frame)
            local onUpdate = frame:GetScript("OnUpdate")
            assert.is_function(onUpdate)
            onUpdate(frame, 0.01)
            assert.near(90, ns.db.minimap.angle, 1e-9)
            local _, _, _, x, y = lastPoint(frame)
            assertOffset(0, 80, x, y)
            frame:GetScript("OnDragStop")(frame)
            assert.is_nil(frame:GetScript("OnUpdate"))
        end)

        it("shows the tooltip on the side that faces the screen center", function()
            local frame = login()
            frame.GetCenter = function() return 883, 623 end
            frame:GetScript("OnEnter")(frame)
            assert.same({ n = 2, frame, "ANCHOR_NONE" }, helper.lastCall(GameTooltip, "SetOwner"))
            assert.same({ n = 3, "TOPRIGHT", frame, "BOTTOMRIGHT" }, helper.lastCall(GameTooltip, "SetPoint"))
            assert.equals("Atlasium 0.1.0", GameTooltip.calls.AddLine[1][1])
            assert.is_table(helper.lastCall(GameTooltip, "Show"))
            frame:GetScript("OnLeave")(frame)
            assert.is_table(helper.lastCall(GameTooltip, "Hide"))
        end)

        it("shows no tooltip while the player drags the button", function()
            local frame = login()
            frame:GetScript("OnDragStart")(frame)
            frame:GetScript("OnEnter")(frame)
            assert.is_nil(GameTooltip.calls.SetOwner)
        end)
    end)
end)
