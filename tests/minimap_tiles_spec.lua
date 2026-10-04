local helper = require("tests.helper")

describe("MinimapTiles", function()
    local ns, state, Tiles

    local TILE = 1600 / 3

    local function near(expected, actual, tolerance, message)
        assert.is_true(math.abs(expected - actual) <= (tolerance or 1e-6),
            (message or "") .. " expected " .. expected .. ", got " .. actual)
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
        Tiles = ns.MinimapTiles
    end)

    describe("diameters", function()
        it("uses the outdoor diameters of HereBeDragons at Blizzard zoom 0 to 5", function()
            near(466.6667, Tiles.GetDiameter(0), 1e-4)
            assert.equals(400, Tiles.GetDiameter(1))
            near(133.3333, Tiles.GetDiameter(5), 1e-4)
        end)
    end)

    describe("positions", function()
        local data = {
            zones = {
                Test = { "Azeroth", TILE, -TILE, TILE, -TILE }, -- tiles 31 to 33 on both axes
                Dalaran = { "Northrend" },
            },
            floors = { Dalaran = { [1] = { TILE, -TILE, 3 * TILE, TILE } } },
            tiles = {},
        }

        it("turns a map position into world yards", function()
            local wx, wy = Tiles.ZoneToWorld(100, -300, 50, -150, 0, 0)
            assert.same({ 50, 100 }, { wx, wy })
            wx, wy = Tiles.ZoneToWorld(100, -300, 50, -150, 1, 1)
            assert.same({ -150, -300 }, { wx, wy })
            wx, wy = Tiles.ZoneToWorld(100, -300, 50, -150, 0.25, 0.5)
            assert.same({ -50, 0 }, { wx, wy })
        end)

        it("turns world yards into tiles, column east and row south", function()
            assert.same({ 32, 32 }, { Tiles.WorldToTile(0, 0) })
            local col, row = Tiles.WorldToTile(-TILE, TILE)
            near(31, col)
            near(33, row)
        end)

        it("finds the player tile on a zone map", function()
            local folder, col, row = Tiles.GetPlayerTile(data, "Test", 0, 0.5, 0.25)
            assert.equals("Azeroth", folder)
            near(32, col)
            near(31.5, row)
        end)

        it("uses the floor bounds on a dungeon level", function()
            local folder, col, row = Tiles.GetPlayerTile(data, "Dalaran", 1, 0.5, 0.5)
            assert.equals("Northrend", folder)
            near(32, col)
            near(30, row)
        end)

        it("has no position at 0, 0, on an unknown map or a level without bounds", function()
            assert.is_nil(Tiles.GetPlayerTile(data, "Test", 0, 0, 0))
            assert.is_nil(Tiles.GetPlayerTile(data, "Nowhere", 0, 0.5, 0.5))
            assert.is_nil(Tiles.GetPlayerTile(data, nil, 0, 0.5, 0.5))
            assert.is_nil(Tiles.GetPlayerTile(data, "Dalaran", 0, 0.5, 0.5))
            assert.is_nil(Tiles.GetPlayerTile(data, "Dalaran", 2, 0.5, 0.5))
            assert.is_nil(Tiles.GetPlayerTile(data, "Test", 1, 0.5, 0.5))
        end)

        it("puts Goldshire on a known Elwynn tile of the real data", function()
            local folder, col, row = Tiles.GetPlayerTile(ns.MinimapTileData, "Elwynn", 0, 0.42, 0.65)
            assert.equals("Azeroth", folder)
            assert.same({ 31, 49 }, { math.floor(col), math.floor(row) })
            assert.is_string(ns.MinimapTileData.tiles.Azeroth["31_49"])
        end)
    end)

    describe("GetRowExtent", function()
        it("follows the circle for a round shape", function()
            assert.same({ -50, 50 }, { Tiles.GetRowExtent("ROUND", 0, 50) })
            local left, right = Tiles.GetRowExtent(nil, 30, 50)
            near(-40, left)
            near(40, right)
        end)

        it("goes to the full radius in square quarters", function()
            assert.same({ -50, 50 }, { Tiles.GetRowExtent("SQUARE", 45, 50) })
            local left, right = Tiles.GetRowExtent("CORNER-TOPLEFT", -30, 50)
            near(-40, left)
            assert.equals(50, right)
            assert.same({ -50, 50 }, { Tiles.GetRowExtent("CORNER-TOPLEFT", 30, 50) })
        end)
    end)

    describe("CanDraw", function()
        it("draws on an outdoor zone map", function()
            assert.is_true(Tiles.CanDraw("Durotar", nil, false))
            assert.is_true(Tiles.CanDraw("Stormwind", nil, false))
        end)

        it("leaves instances, indoors, WMO cities and unknown maps to Blizzard", function()
            assert.is_false(Tiles.CanDraw("Durotar", 1, false))
            assert.is_false(Tiles.CanDraw("Durotar", nil, true))
            assert.is_false(Tiles.CanDraw(nil, nil, false))
            for _, city in ipairs({ "Ogrimmar", "ThunderBluff", "Darnassis", "TheExodar", "Ironforge" }) do
                assert.is_false(Tiles.CanDraw(city, nil, false), city)
                assert.is_not_nil(ns.MinimapTileData.zones[city], city .. " in the data")
            end
        end)
    end)

    describe("IsIndoorZoom", function()
        it("compares the zoom with the CVars when they differ", function()
            assert.is_true(Tiles.IsIndoorZoom(0, 2, 2, false))
            assert.is_false(Tiles.IsIndoorZoom(0, 2, 0, true))
        end)

        it("asks IsIndoors when the CVars are equal", function()
            assert.is_true(Tiles.IsIndoorZoom(0, 0, 0, 1))
            assert.is_false(Tiles.IsIndoorZoom(0, 0, 0, nil))
        end)
    end)

    describe("BuildSegments", function()
        local function build(overrides)
            local params = { size = 140, shape = "ROUND", strip = 2, pad = 0.35, col = 32.6, row = 48.4,
                across = 2.5, angle = 0 }
            for key, value in pairs(overrides or {}) do
                params[key] = value
            end
            local pieces = {}
            local count = Tiles.BuildSegments(params, function(...)
                table.insert(pieces, { ... })
            end)
            assert.equals(count, #pieces)
            return pieces, params
        end

        -- The tile position the minimap point (x, y) shows through the piece, from its 4 corners.
        local function sample(piece, x, y)
            local fx, fy = (x - piece[3]) / piece[5], (y - piece[4]) / piece[6]
            local u = piece[7] + (piece[11] - piece[7]) * fx + (piece[9] - piece[7]) * fy
            local v = piece[8] + (piece[12] - piece[8]) * fx + (piece[10] - piece[8]) * fy
            return piece[1] + u, piece[2] + v
        end

        local function findPiece(pieces, x, y)
            for _, piece in ipairs(pieces) do
                if x >= piece[3] and x < piece[3] + piece[5] and y >= piece[4] and y < piece[4] + piece[6] then
                    return piece
                end
            end
        end

        it("covers each strip from edge to edge without gaps", function()
            for _, case in ipairs({ { shape = "ROUND", angle = 0.7 }, { shape = "SQUARE", angle = 0 },
                { shape = "CORNER-BOTTOMRIGHT", angle = 2 } }) do
                local pieces, params = build(case)
                local r = params.size / 2
                local rows = {}
                for _, piece in ipairs(pieces) do
                    rows[piece[4]] = rows[piece[4]] or {}
                    table.insert(rows[piece[4]], piece)
                end
                for top, list in pairs(rows) do
                    table.sort(list, function(a, b) return a[3] < b[3] end)
                    local left, right = Tiles.GetRowExtent(case.shape, top - r + 1, r)
                    near(r + left, list[1][3], 1e-6, case.shape .. " left")
                    for i = 2, #list do
                        near(list[i - 1][3] + list[i - 1][5], list[i][3], 1e-6, case.shape .. " gap")
                    end
                    near(r + right, list[#list][3] + list[#list][5], 1e-6, case.shape .. " right")
                end
            end
        end)

        it("shows the player position at the center", function()
            for _, angle in ipairs({ 0, 0.7, -2.5 }) do
                local pieces, params = build({ angle = angle })
                local col, row = sample(findPiece(pieces, 70, 70.5), 70, 70.5)
                near(params.col, col, 0.5 / (140 / 2.5) + 1e-9, "col")
                near(params.row, row, 0.5 / (140 / 2.5) + 1e-9, "row")
            end
        end)

        it("turns the map counterclockwise by the angle", function()
            local pieces, params = build({ angle = math.pi / 2 })
            local k = params.size / params.across
            -- A quarter turn counterclockwise puts south on the right.
            local col, row = sample(findPiece(pieces, 90, 70.5), 90, 70.5)
            near(params.col - 0.5 / k, col, 1e-6, "col")
            near(params.row + 20 / k, row, 1e-6, "row")
        end)

        it("splits each piece at the tile edges", function()
            -- A sliver thinner than 0.01 units joins its neighbor, so a piece can pass the edge by 0.01 / k.
            local pieces = build({ angle = 0 })
            for _, piece in ipairs(pieces) do
                assert.is_true(piece[7] >= -1e-3 and piece[11] <= 1 + 1e-3)
            end
        end)

        it("draws the spike view with about as many pieces as the spike", function()
            -- The in-game spike drew this view with 245 textures.
            assert.is_true(#build({ angle = math.rad(30) }) <= 250)
        end)
    end)


    describe("renderer and wheel", function()
        local CLEAR = "Interface\\WORLDMAP\\Silithus\\pixelfix1"

        local function login(saved)
            _G.AtlasiumDB = saved
            -- Tiles 31 to 33 on both axes; only 32_32 has a texture, the rest is sea.
            ns.MinimapTileData = {
                zones = {
                    Test = { "Azeroth", TILE, -TILE, TILE, -TILE },
                    Ogrimmar = { "Kalimdor", TILE, -TILE, TILE, -TILE },
                },
                floors = {},
                tiles = { Azeroth = { ["32_32"] = "abc" }, Kalimdor = {} },
            }
            state.map.name = "Test"
            state.player.x, state.player.y = 0.5, 0.5
            ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
            ns.Core.OnEvent(nil, "PLAYER_LOGIN")
        end

        local function layer()
            for _, frame in ipairs(state.frames) do
                if frame.parent == MinimapCluster then
                    return frame
                end
            end
        end

        -- Run the OnUpdate script of the frame that has one (the position checks).
        local function tick(elapsed)
            for _, frame in ipairs(state.frames) do
                if frame.ownScripts.OnUpdate then
                    helper.runScript(frame, "OnUpdate", elapsed or 0.1)
                    return
                end
            end
        end

        local function wheel(delta, times)
            for _ = 1, times or 1 do
                helper.runScript(Minimap, "OnMouseWheel", delta)
            end
        end

        local function lastPath(method)
            local args = helper.lastCall(Minimap, method)
            return args and args[1]
        end

        -- The tiles across the middle strip: the sum of its pieces' texture widths.
        local function across()
            local total = 0
            for _, texture in ipairs(layer().textures) do
                local point = helper.lastCall(texture, "SetPoint")
                if point and point[5] == -70 and texture.calls.Hide == nil then
                    local coords = helper.lastCall(texture, "SetTexCoord")
                    total = total + coords[5] - coords[1]
                end
            end
            return total
        end

        it("draws raw tiles under the minimap and hides the Blizzard ground", function()
            login()
            local frame = layer()
            assert.is_true(frame:IsShown())
            assert.equals(Minimap:GetFrameLevel() - 1, frame:GetFrameLevel())
            assert.same({ "LOW", n = 1 }, helper.lastCall(frame, "SetFrameStrata"))
            assert.is_false(frame:IsMouseEnabled())
            assert.equals(CLEAR, lastPath("SetMaskTexture"))
            assert.is_nil(lastPath("SetBlipTexture"))
            assert.is_true(#frame.textures > 70)
            local paths = {}
            for _, texture in ipairs(frame.textures) do
                local args = helper.lastCall(texture, "SetTexture")
                paths[args.n == 1 and args[1] or "sea"] = true
                assert.is_nil(texture.calls.SetVertexColor)
            end
            assert.same({ ["Textures\\Minimap\\abc"] = true, sea = true }, paths)
        end)

        it("draws each Blizzard zoom at its scale", function()
            login()
            near(466.6667 / TILE, across(), 1e-3)
            state.minimapZoom = 5
            tick()
            near(133.3333 / TILE, across(), 1e-3)
        end)

        it("raises a background minimap so the world cannot cover the tiles, and restores it", function()
            Minimap:SetFrameStrata("BACKGROUND")
            login()
            assert.equals("LOW", Minimap:GetFrameStrata())
            assert.equals("LOW", layer():GetFrameStrata())
            assert.equals(Minimap:GetFrameLevel() - 1, layer():GetFrameLevel())
            Tiles.SetEnabled(false)
            assert.equals("BACKGROUND", Minimap:GetFrameStrata())
        end)

        it("restores background strata during fallback and raises it on return", function()
            Minimap:SetFrameStrata("BACKGROUND")
            login()
            state.instance = 1
            tick()
            assert.equals("BACKGROUND", Minimap:GetFrameStrata())
            state.instance = nil
            tick()
            assert.equals("LOW", Minimap:GetFrameStrata())
            assert.equals("LOW", layer():GetFrameStrata())
        end)

        it("preserves another add-on's strata change while drawing", function()
            Minimap:SetFrameStrata("BACKGROUND")
            login()
            Minimap:SetFrameStrata("HIGH")
            tick()
            assert.equals("HIGH", layer():GetFrameStrata())
            Tiles.SetEnabled(false)
            assert.equals("HIGH", Minimap:GetFrameStrata())
        end)

        it("reapplies active transparent textures after entering the world", function()
            login()
            -- Simulate the engine resetting textures without calling the Lua methods or hooks.
            Minimap.calls.SetMaskTexture = nil
            Minimap.calls.SetBlipTexture = nil
            ns.Core.OnEvent(nil, "PLAYER_ENTERING_WORLD")
            assert.equals(CLEAR, lastPath("SetMaskTexture"))
            assert.is_nil(lastPath("SetBlipTexture"))
        end)

        it("reapplies only the mask at normal zoom and keeps texture ownership", function()
            login()
            Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
            Minimap:SetBlipTexture("OtherAddon\\Blips")
            local blipCalls = #Minimap.calls.SetBlipTexture
            Minimap.calls.SetMaskTexture = nil
            ns.Core.OnEvent(nil, "PLAYER_ENTERING_WORLD")
            assert.equals(CLEAR, lastPath("SetMaskTexture"))
            assert.equals(blipCalls, #Minimap.calls.SetBlipTexture)
            Tiles.SetEnabled(false)
            assert.equals("Interface\\Buttons\\WHITE8X8", lastPath("SetMaskTexture"))
            assert.equals("OtherAddon\\Blips", lastPath("SetBlipTexture"))
            assert.equals(blipCalls, #Minimap.calls.SetBlipTexture)
        end)

        it("does not change textures or strata on world entry when tiles are off", function()
            Minimap:SetFrameStrata("BACKGROUND")
            login({ minimapTiles = { enabled = false } })
            ns.Core.OnEvent(nil, "PLAYER_ENTERING_WORLD")
            assert.is_nil(lastPath("SetMaskTexture"))
            assert.is_nil(lastPath("SetBlipTexture"))
            assert.equals("BACKGROUND", Minimap:GetFrameStrata())
            assert.is_nil(layer())
        end)

        it("leaves the Blizzard zoom alone above zoom 0", function()
            login()
            state.minimapZoom = 2
            wheel(-1)
            assert.same({ -1 }, state.minimapZooms)
        end)

        it("shows the Blizzard minimap in an instance, indoors and in a WMO city", function()
            login()
            local function check(blizzard)
                tick()
                assert.equals(not blizzard, layer():IsShown())
                assert.equals(blizzard and "Textures\\MinimapMask" or CLEAR, lastPath("SetMaskTexture"))
            end
            state.instance = 1
            check(true)
            state.instance = nil
            check(false)
            state.indoors = 1
            check(true)
            state.indoors = nil
            state.map.name = "Ogrimmar"
            check(true)
            state.map.name = "Test"
            check(false)
        end)

        it("leaves the Blizzard minimap as it is when the tiles are off", function()
            login({ minimapTiles = { enabled = false } })
            assert.is_nil(layer())
            assert.is_nil(lastPath("SetMaskTexture"))
            Tiles.SetEnabled(true)
            assert.is_true(layer():IsShown())
            Tiles.SetEnabled(false)
            assert.is_false(layer():IsShown())
            assert.equals("Textures\\MinimapMask", lastPath("SetMaskTexture"))
            assert.is_nil(lastPath("SetBlipTexture"))
            local count = #Minimap.calls.SetMaskTexture
            tick()
            assert.equals(count, #Minimap.calls.SetMaskTexture)
        end)

        it("keeps the mask another add-on sets, and puts it back when done", function()
            login()
            Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
            assert.equals(CLEAR, lastPath("SetMaskTexture"))
            Tiles.SetEnabled(false)
            assert.equals("Interface\\Buttons\\WHITE8X8", lastPath("SetMaskTexture"))
        end)

        it("sets the map to the player's zone when the position is missing", function()
            login()
            state.map.name = "Nowhere"
            state.zone = { name = "Test", x = 0.5, y = 0.5 }
            tick(2)
            assert.equals(1, state.mapResets)
            assert.is_true(layer():IsShown())
        end)

        it("keeps the last position while the world map is open", function()
            login()
            WorldMapFrame:Show()
            state.map.name = "Nowhere"
            tick(2)
            assert.equals(0, state.mapResets)
            assert.is_true(layer():IsShown())
        end)

        it("sets the map to the new zone when the world map is closed", function()
            login()
            ns.Core.OnEvent(nil, "ZONE_CHANGED_NEW_AREA")
            assert.equals(1, state.mapResets)
            WorldMapFrame:Show()
            ns.Core.OnEvent(nil, "ZONE_CHANGED_NEW_AREA")
            assert.equals(1, state.mapResets)
        end)

        it("redraws when the player moves, at most 30 times a second", function()
            login()
            local tile = layer().textures[1]
            local before = #tile.calls.SetTexCoord
            state.player.x = 0.51
            tick(0.01)
            assert.equals(before, #tile.calls.SetTexCoord)
            tick(0.03)
            assert.equals(before + 1, #tile.calls.SetTexCoord)
        end)

        it("redraws the scale when the Blizzard zoom event fires", function()
            login()
            state.minimapZoom = 5
            ns.Core.OnEvent(nil, "MINIMAP_UPDATE_ZOOM")
            near(133.3333 / TILE, across(), 1e-3)
        end)

        it("checks fallback as soon as the player changes zone", function()
            login()
            state.zone = { name = "Ogrimmar", x = 0.5, y = 0.5 }
            ns.Core.OnEvent(nil, "ZONE_CHANGED_NEW_AREA")
            assert.is_false(layer():IsShown())
            assert.equals("Textures\\MinimapMask", lastPath("SetMaskTexture"))
            assert.is_nil(lastPath("SetBlipTexture"))
        end)

        it("keeps custom tiles when wheel zoom is turned off", function()
            login()
            ns.MinimapZoom.SetEnabled(false)
            assert.is_true(layer():IsShown())
        end)

        it("keeps native button handlers and routes wheel notches through Blizzard", function()
            local onClick = MinimapZoomIn:GetScript("OnClick")
            login()
            assert.equals(onClick, MinimapZoomIn:GetScript("OnClick"))
            wheel(-1, 6)
            wheel(1)
            assert.same({ -1, -1, -1, -1, -1, -1, 1 }, state.minimapZooms)
            near(466.6667 / TILE, across(), 1e-3)
            assert.is_nil(lastPath("SetBlipTexture"))
            helper.runScript(MinimapZoomIn, "OnClick")
            assert.equals(1, state.zoomInClicks)
        end)

        it("shows the alignment check at half alpha over the Blizzard ground", function()
            login()
            Tiles.SetAlign(true)
            local frame = layer()
            assert.equals(Minimap:GetFrameLevel() + 1, frame:GetFrameLevel())
            assert.same({ 0.5, n = 1 }, helper.lastCall(frame, "SetAlpha"))
            assert.equals("Textures\\MinimapMask", lastPath("SetMaskTexture"))
            Tiles.SetAlign(false)
            assert.equals(Minimap:GetFrameLevel() - 1, frame:GetFrameLevel())
            assert.same({ 1, n = 1 }, helper.lastCall(frame, "SetAlpha"))
            assert.equals(CLEAR, lastPath("SetMaskTexture"))
        end)
    end)
end)
