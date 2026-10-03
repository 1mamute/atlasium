local helper = require("tests.helper")

describe("FogClear", function()
    local ns, state, FogClear

    before_each(function()
        state = helper.installWowStubs()
        ns = helper.newNamespace()
        helper.loadAddonFile("Atlasium/Util.lua", ns)
        helper.loadAddonFile("Atlasium/Core.lua", ns)
        helper.loadAddonFile("Atlasium/MinimapButton.lua", ns)
        helper.loadAddonFile("Atlasium/Data/Overlays.lua", ns)
        helper.loadAddonFile("Atlasium/FogClear.lua", ns)
        FogClear = ns.FogClear
    end)

    describe("OverlayKey", function()
        it("returns the last part of a full path in capitals", function()
            assert.equals("GOLDSHIRE", FogClear.OverlayKey("Interface\\WorldMap\\Elwynn\\Goldshire"))
        end)

        it("ignores the case", function()
            assert.equals("THEGREATTREE", FogClear.OverlayKey("Interface\\WorldMap\\Ashenvale\\TheGreatTree"))
        end)

        it("accepts a name without a path", function()
            assert.equals("CHILLWINDPOINT", FogClear.OverlayKey("ChillwindPoint"))
        end)
    end)

    describe("GetUnexplored", function()
        local zone = {
            CHILLWINDPOINT = {},
            TheGreatTree = {},
            DALARAN = {},
        }

        it("returns all names when nothing is explored", function()
            assert.same({ "CHILLWINDPOINT", "DALARAN", "TheGreatTree" }, FogClear.GetUnexplored(zone, {}))
        end)

        it("leaves out the explored names, without case", function()
            local explored = { THEGREATTREE = true, DALARAN = true }
            assert.same({ "CHILLWINDPOINT" }, FogClear.GetUnexplored(zone, explored))
        end)

        it("returns nothing when all is explored", function()
            local explored = { CHILLWINDPOINT = true, THEGREATTREE = true, DALARAN = true }
            assert.same({}, FogClear.GetUnexplored(zone, explored))
        end)
    end)

    describe("GetTiles", function()
        local function assertTile(expected, tile)
            assert.equals(expected[1], tile.index)
            assert.equals(expected[2], tile.width)
            assert.equals(expected[3], tile.height)
            assert.near(expected[4], tile.right, 1e-9)
            assert.near(expected[5], tile.bottom, 1e-9)
            assert.equals(expected[6], tile.x)
            assert.equals(expected[7], tile.y)
        end

        it("splits Chillwind Point into 4 pieces", function()
            local tiles = FogClear.GetTiles(350, 370, 626, 253)
            assert.equals(4, #tiles)
            assertTile({ 1, 256, 256, 1, 1, 626, -253 }, tiles[1])
            assertTile({ 2, 94, 256, 0.734375, 1, 882, -253 }, tiles[2])
            assertTile({ 3, 256, 114, 1, 0.890625, 626, -509 }, tiles[3])
            assertTile({ 4, 94, 114, 0.734375, 0.890625, 882, -509 }, tiles[4])
        end)

        it("makes one full piece for 256 x 256", function()
            local tiles = FogClear.GetTiles(256, 256, 10, 20)
            assert.equals(1, #tiles)
            assertTile({ 1, 256, 256, 1, 1, 10, -20 }, tiles[1])
        end)

        it("gives the last column 256, not 0, for a width of 512", function()
            local tiles = FogClear.GetTiles(512, 100, 0, 0)
            assert.equals(2, #tiles)
            assertTile({ 2, 256, 100, 1, 100 / 128, 256, 0 }, tiles[2])
        end)

        it("uses 128 x 128 files for a 90 x 80 overlay", function()
            local tiles = FogClear.GetTiles(90, 80, 5, 6)
            assert.equals(1, #tiles)
            assertTile({ 1, 90, 80, 90 / 128, 80 / 128, 5, -6 }, tiles[1])
        end)

        it("caches the pieces", function()
            assert.equals(FogClear.GetTiles(350, 370, 626, 253), FogClear.GetTiles(350, 370, 626, 253))
        end)
    end)

    describe("drawing", function()
        local zone = {
            AREA_A = { 256, 256, 0, 0 },
            AREA_B = { 350, 370, 626, 253 },
            AREA_C = { 90, 80, 100, 100 },
        }

        local function shownTextures()
            local shown = {}
            for _, texture in ipairs(WorldMapDetailFrame.textures) do
                if texture:IsShown() then
                    table.insert(shown, texture)
                end
            end
            return shown
        end

        local function texturePath(texture)
            return helper.lastCall(texture, "SetTexture")[1]
        end

        before_each(function()
            ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
            ns.Overlays.TestZone = zone
            state.map.name = "TestZone"
            state.map.overlays = {
                "Interface\\WorldMap\\TestZone\\Area_A",
                "Interface\\WorldMap\\TestZone\\AREA_C",
            }
        end)

        it("hooks WorldMapFrame_Update when the file loads", function()
            assert.equals(FogClear.Update, state.hooks.WorldMapFrame_Update)
        end)

        it("shows textures only for the unexplored overlays", function()
            FogClear.Update()
            local shown = shownTextures()
            assert.equals(4, #shown)
            for i, texture in ipairs(shown) do
                assert.equals("Interface\\WorldMap\\TestZone\\AREA_B" .. i, texturePath(texture))
            end
        end)

        it("uses the BORDER layer, the tint and the piece position", function()
            FogClear.Update()
            local texture = shownTextures()[2]
            assert.equals("BORDER", texture.layer)
            assert.same({ n = 3, 0.6, 0.6, 0.6 }, helper.lastCall(texture, "SetVertexColor"))
            assert.same({ n = 1, 1 }, helper.lastCall(texture, "SetAlpha"))
            assert.same({ n = 5, "TOPLEFT", WorldMapDetailFrame, "TOPLEFT", 882, -253 },
                helper.lastCall(texture, "SetPoint"))
            local coords = helper.lastCall(texture, "SetTexCoord")
            assert.near(0.734375, coords[2], 1e-9)
            assert.near(1, coords[4], 1e-9)
        end)

        it("hides all textures on a map without overlays", function()
            FogClear.Update()
            state.map.name = "Kalimdor"
            FogClear.Update()
            assert.equals(0, #shownTextures())
        end)

        it("uses the same textures again on the next update", function()
            FogClear.Update()
            local created = #WorldMapDetailFrame.textures
            FogClear.Update()
            assert.equals(created, #WorldMapDetailFrame.textures)
        end)

        it("hides the textures that a smaller map does not use", function()
            state.map.overlays = {}
            FogClear.Update()
            assert.equals(6, #shownTextures())
            state.map.overlays = { "Interface\\WorldMap\\TestZone\\AREA_B" }
            FogClear.Update()
            assert.equals(2, #shownTextures())
            assert.equals(6, #WorldMapDetailFrame.textures)
        end)

        it("hides all textures when fog clearing is off", function()
            FogClear.Update()
            ns.db.fogClear.enabled = false
            FogClear.Update()
            assert.equals(0, #shownTextures())
        end)

        it("does nothing before the saved settings exist", function()
            ns.db = nil
            FogClear.Update()
            assert.equals(0, #WorldMapDetailFrame.textures)
        end)
    end)

    describe("/atlasium fog", function()
        before_each(function()
            ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
            state.map.name = "Alterac"
        end)

        it("turns fog clearing off and on, and prints the new state", function()
            SlashCmdList.ATLASIUM("fog off")
            assert.is_false(ns.db.fogClear.enabled)
            assert.matches("fog clearing off", state.messages[1])
            SlashCmdList.ATLASIUM("fog on")
            assert.is_true(ns.db.fogClear.enabled)
            assert.matches("fog clearing on", state.messages[2])
        end)

        it("does not switch when the state is already set", function()
            SlashCmdList.ATLASIUM("fog on")
            assert.is_true(ns.db.fogClear.enabled)
            SlashCmdList.ATLASIUM("fog off")
            SlashCmdList.ATLASIUM("fog off")
            assert.is_false(ns.db.fogClear.enabled)
        end)

        it("ignores the case of the argument", function()
            SlashCmdList.ATLASIUM("fog OFF")
            assert.is_false(ns.db.fogClear.enabled)
        end)

        it("prints the state and the usage without a valid argument", function()
            SlashCmdList.ATLASIUM("fog")
            SlashCmdList.ATLASIUM("fog maybe")
            assert.is_true(ns.db.fogClear.enabled)
            assert.matches("fog clearing on %(/atlasium fog on | off%)", state.messages[1])
            assert.equals(state.messages[1], state.messages[2])
        end)

        it("redraws at once when the map is shown", function()
            WorldMapFrame.IsShown = function() return true end
            SlashCmdList.ATLASIUM("fog off")
            assert.equals(0, #WorldMapDetailFrame.textures)
            SlashCmdList.ATLASIUM("fog on")
            assert.is_true(#WorldMapDetailFrame.textures > 0)
        end)

        it("does not draw while the map is hidden", function()
            SlashCmdList.ATLASIUM("fog off")
            SlashCmdList.ATLASIUM("fog on")
            assert.equals(0, #WorldMapDetailFrame.textures)
        end)
    end)
end)
