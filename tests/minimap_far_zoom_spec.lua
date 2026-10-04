local helper = require("tests.helper")

describe("MinimapFarZoom", function()
    local ns, state, FarZoom

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
        helper.loadAddonFile("Atlasium/MinimapFarZoom.lua", ns)
        helper.loadAddonFile("Atlasium/MinimapZoom.lua", ns)
        FarZoom = ns.MinimapFarZoom
    end)

    describe("diameters and levels", function()
        it("uses the zoom 0 diameters of HereBeDragons", function()
            near(466.6667, FarZoom.GetBaseDiameter(false), 1e-4)
            assert.equals(300, FarZoom.GetBaseDiameter(true))
        end)

        it("multiplies the diameter by the step for each level", function()
            near(466.6667 * 1.96, FarZoom.GetDiameter(2, false, 1.4), 1e-3)
            assert.equals(300, FarZoom.GetDiameter(0, true, 1.4))
        end)

        it("counts the levels that stay within the largest factor", function()
            assert.equals(4, FarZoom.GetLevelCount(4, 1.4))
            assert.equals(4, FarZoom.GetLevelCount(16, 2))
            assert.equals(1, FarZoom.GetLevelCount(1.5, 1.4))
            assert.equals(0, FarZoom.GetLevelCount(1.2, 1.4))
            assert.equals(0, FarZoom.GetLevelCount(4, 1))
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
            local wx, wy = FarZoom.ZoneToWorld(100, -300, 50, -150, 0, 0)
            assert.same({ 50, 100 }, { wx, wy })
            wx, wy = FarZoom.ZoneToWorld(100, -300, 50, -150, 1, 1)
            assert.same({ -150, -300 }, { wx, wy })
            wx, wy = FarZoom.ZoneToWorld(100, -300, 50, -150, 0.25, 0.5)
            assert.same({ -50, 0 }, { wx, wy })
        end)

        it("turns world yards into tiles, column east and row south", function()
            assert.same({ 32, 32 }, { FarZoom.WorldToTile(0, 0) })
            local col, row = FarZoom.WorldToTile(-TILE, TILE)
            near(31, col)
            near(33, row)
        end)

        it("finds the player tile on a zone map", function()
            local folder, col, row = FarZoom.GetPlayerTile(data, "Test", 0, 0.5, 0.25)
            assert.equals("Azeroth", folder)
            near(32, col)
            near(31.5, row)
        end)

        it("uses the floor bounds on a dungeon level", function()
            local folder, col, row = FarZoom.GetPlayerTile(data, "Dalaran", 1, 0.5, 0.5)
            assert.equals("Northrend", folder)
            near(32, col)
            near(30, row)
        end)

        it("has no position at 0, 0, on an unknown map or a level without bounds", function()
            assert.is_nil(FarZoom.GetPlayerTile(data, "Test", 0, 0, 0))
            assert.is_nil(FarZoom.GetPlayerTile(data, "Nowhere", 0, 0.5, 0.5))
            assert.is_nil(FarZoom.GetPlayerTile(data, nil, 0, 0.5, 0.5))
            assert.is_nil(FarZoom.GetPlayerTile(data, "Dalaran", 0, 0.5, 0.5))
            assert.is_nil(FarZoom.GetPlayerTile(data, "Dalaran", 2, 0.5, 0.5))
            assert.is_nil(FarZoom.GetPlayerTile(data, "Test", 1, 0.5, 0.5))
        end)

        it("puts Goldshire on a known Elwynn tile of the real data", function()
            local folder, col, row = FarZoom.GetPlayerTile(ns.MinimapTileData, "Elwynn", 0, 0.42, 0.65)
            assert.equals("Azeroth", folder)
            assert.same({ 31, 49 }, { math.floor(col), math.floor(row) })
            assert.is_string(ns.MinimapTileData.tiles.Azeroth["31_49"])
        end)
    end)

    describe("GetRowExtent", function()
        it("follows the circle for a round shape", function()
            assert.same({ -50, 50 }, { FarZoom.GetRowExtent("ROUND", 0, 50) })
            local left, right = FarZoom.GetRowExtent(nil, 30, 50)
            near(-40, left)
            near(40, right)
        end)

        it("goes to the full radius in square quarters", function()
            assert.same({ -50, 50 }, { FarZoom.GetRowExtent("SQUARE", 45, 50) })
            local left, right = FarZoom.GetRowExtent("CORNER-TOPLEFT", -30, 50)
            near(-40, left)
            assert.equals(50, right)
            assert.same({ -50, 50 }, { FarZoom.GetRowExtent("CORNER-TOPLEFT", 30, 50) })
        end)
    end)

    describe("IsIndoorZoom", function()
        it("compares the zoom with the CVars when they differ", function()
            assert.is_true(FarZoom.IsIndoorZoom(0, 2, 2, false))
            assert.is_false(FarZoom.IsIndoorZoom(0, 2, 0, true))
        end)

        it("asks IsIndoors when the CVars are equal", function()
            assert.is_true(FarZoom.IsIndoorZoom(0, 0, 0, 1))
            assert.is_false(FarZoom.IsIndoorZoom(0, 0, 0, nil))
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
            local count = FarZoom.BuildSegments(params, function(...)
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
                    local left, right = FarZoom.GetRowExtent(case.shape, top - r + 1, r)
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

    describe("GetArrowTexCoords", function()
        it("keeps the texture upright at angle 0", function()
            assert.same({ 0, 0, 0, 1, 1, 0, 1, 1 }, { FarZoom.GetArrowTexCoords(0) })
        end)

        it("turns the texture a quarter counterclockwise", function()
            local coords = { FarZoom.GetArrowTexCoords(math.pi / 2) }
            local expected = { 1, 0, 0, 0, 1, 1, 0, 1 }
            for i = 1, 8 do
                near(expected[i], coords[i], 1e-9, "coord " .. i)
            end
        end)
    end)

    describe("renderer and wheel", function()
        local function login(saved)
            _G.AtlasiumDB = saved
            ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
            ns.Core.OnEvent(nil, "PLAYER_LOGIN")
            -- Tiles 31 to 33 on both axes; only 32_32 has a texture, the rest is sea.
            ns.MinimapTileData = {
                zones = { Test = { "Azeroth", TILE, -TILE, TILE, -TILE } },
                floors = {},
                tiles = { Azeroth = { ["32_32"] = "abc" } },
            }
            state.map.name = "Test"
            state.player.x, state.player.y = 0.5, 0.5
        end

        local function layer()
            for _, frame in ipairs(state.frames) do
                if frame.parent == Minimap then
                    return frame
                end
            end
        end

        local function wheel(delta, times)
            for _ = 1, times or 1 do
                helper.runScript(Minimap, "OnMouseWheel", delta)
            end
        end

        local function textures(frame)
            local list = {}
            for _, texture in ipairs(frame.textures) do
                if texture.layer == "ARTWORK" then
                    table.insert(list, texture)
                end
            end
            return list
        end

        it("zooms out past zoom 0 and covers the minimap with tiles", function()
            login()
            wheel(-1)
            assert.equals(1, FarZoom.level)
            assert.same({}, state.minimapZooms)
            assert.same({ "igMiniMapZoomOut" }, state.sounds)
            local frame = layer()
            assert.is_true(frame:IsShown())
            assert.equals(Minimap:GetFrameLevel() + 1, frame:GetFrameLevel())
            assert.equals(Minimap:GetFrameLevel() + 5, MinimapBackdrop:GetFrameLevel())
            assert.equals(Minimap:GetFrameLevel() + 6, GameTimeFrame:GetFrameLevel())
            local tiles = textures(frame)
            assert.is_true(#tiles > 70)
            local paths = {}
            for _, texture in ipairs(tiles) do
                local args = helper.lastCall(texture, "SetTexture")
                local key = args.n == 1 and args[1] or "sea"
                paths[key] = true
                -- Tiles are shaded like the Blizzard minimap; the sea color is not.
                assert.equals(key == "sea", helper.lastCall(texture, "SetVertexColor")[1] == 1)
            end
            assert.same({ ["Textures\\Minimap\\abc"] = true, sea = true }, paths)
        end)

        it("raises the clock when it loaded, and skips it when it did not", function()
            login()
            _G.TimeManagerClockButton = helper.newFrame({ frameLevel = 4 })
            wheel(-1)
            assert.equals(Minimap:GetFrameLevel() + 6, TimeManagerClockButton:GetFrameLevel())
            wheel(1)
            assert.equals(4, TimeManagerClockButton:GetFrameLevel())
            _G.TimeManagerClockButton = nil
            assert.has_no.errors(function() wheel(-1) end)
            assert.has_no.errors(function() wheel(1) end)
        end)

        it("stops at the largest level, then the notch goes to Blizzard", function()
            login()
            wheel(-1, 5)
            assert.equals(4, FarZoom.level)
            assert.same({ -1 }, state.minimapZooms)
        end)

        it("zooms back in and shows the Blizzard minimap at level 0", function()
            login()
            wheel(-1, 2)
            wheel(1, 2)
            assert.equals(0, FarZoom.level)
            assert.is_false(layer():IsShown())
            assert.equals(3, MinimapBackdrop:GetFrameLevel())
            assert.equals(4, GameTimeFrame:GetFrameLevel())
            assert.same({}, state.minimapZooms)
            wheel(1)
            assert.same({ 1 }, state.minimapZooms)
        end)

        it("forwards the wheel over the layer", function()
            login()
            wheel(-1)
            helper.runScript(layer(), "OnMouseWheel", -1)
            assert.equals(2, FarZoom.level)
        end)

        it("leaves the Blizzard zoom alone above zoom 0", function()
            login()
            state.minimapZoom = 2
            wheel(-1)
            assert.equals(0, FarZoom.level)
            assert.same({ -1 }, state.minimapZooms)
        end)

        it("does not zoom out past 0 when far zoom is off, in an instance or without data", function()
            login({ minimapZoom = { far = false } })
            wheel(-1)
            ns.db.minimapZoom.far = true
            state.instance = 1
            wheel(-1)
            state.instance = nil
            state.map.name = "Nowhere"
            wheel(-1)
            assert.equals(0, FarZoom.level)
            assert.same({ -1, -1, -1 }, state.minimapZooms)
        end)

        it("sets the map to the player's zone when the position is missing", function()
            login()
            state.map.name = "Nowhere"
            state.zone = { name = "Test", x = 0.5, y = 0.5 }
            wheel(-1)
            assert.equals(1, state.mapResets)
            assert.equals(1, FarZoom.level)
        end)

        it("keeps the last position while the world map is open", function()
            login()
            wheel(-1)
            WorldMapFrame:Show()
            state.map.name = "Nowhere"
            helper.runScript(layer(), "OnUpdate", 2)
            assert.equals(0, state.mapResets)
            assert.equals(1, FarZoom.level)
        end)

        it("leaves far zoom on entering an instance", function()
            login()
            wheel(-1)
            state.instance = 1
            helper.runScript(layer(), "OnUpdate", 0.1)
            assert.equals(0, FarZoom.level)
            assert.is_false(layer():IsShown())
        end)

        it("redraws when the player moves, at most 30 times a second", function()
            login()
            wheel(-1)
            local tile = textures(layer())[1]
            local before = #tile.calls.SetTexCoord
            state.player.x = 0.51
            helper.runScript(layer(), "OnUpdate", 0.01)
            assert.equals(before, #tile.calls.SetTexCoord)
            helper.runScript(layer(), "OnUpdate", 0.03)
            assert.equals(before + 1, #tile.calls.SetTexCoord)
        end)

        it("turns the arrow with the facing, or keeps it up when the minimap rotates", function()
            login()
            state.facing = math.pi / 2
            wheel(-1)
            local arrow = layer().textures[1]
            assert.equals("Interface\\Minimap\\MinimapArrow", arrow.calls.SetTexture[1][1])
            local coords = helper.lastCall(arrow, "SetTexCoord")
            near(1, coords[1], 1e-9)
            -- Like the Blizzard arrow: a bit right of and above the centre, whatever the facing.
            assert.same({ "CENTER", layer(), "CENTER", 1.8, 1.7, n = 5 }, helper.lastCall(arrow, "SetPoint"))
            state.cvars.rotateMinimap = "1"
            helper.runScript(layer(), "OnUpdate", 0.1)
            assert.same({ 0, 0, 0, 1, 1, 0, 1, 1, n = 8 }, helper.lastCall(arrow, "SetTexCoord"))
        end)

        it("steps back one level with the + button, and zooms the Blizzard map at level 0", function()
            login()
            wheel(-1, 2)
            helper.runScript(MinimapZoomIn, "OnClick")
            assert.equals(1, FarZoom.level)
            assert.equals(0, state.zoomInClicks)
            helper.runScript(MinimapZoomIn, "OnClick")
            helper.runScript(MinimapZoomIn, "OnClick")
            assert.equals(0, FarZoom.level)
            assert.equals(1, state.zoomInClicks)
        end)

        it("leaves far zoom when something else changes the Blizzard zoom", function()
            login()
            wheel(-1)
            ns.Core.OnEvent(nil, "MINIMAP_UPDATE_ZOOM")
            assert.equals(1, FarZoom.level)
            state.minimapZoom = 1
            ns.Core.OnEvent(nil, "MINIMAP_UPDATE_ZOOM")
            assert.equals(0, FarZoom.level)
        end)

        it("leaves far zoom when far or wheel zoom is turned off", function()
            login()
            wheel(-1)
            FarZoom.SetEnabled(false)
            assert.equals(0, FarZoom.level)
            FarZoom.SetEnabled(true)
            wheel(-1)
            ns.MinimapZoom.SetEnabled(false)
            assert.equals(0, FarZoom.level)
        end)

        it("steps back when the largest factor goes down", function()
            login()
            wheel(-1, 4)
            FarZoom.SetMaxFactor(2)
            assert.equals(2, ns.db.minimapZoom.farMax)
            assert.equals(2, FarZoom.level)
        end)

        it("shows the alignment check and the arrow at half alpha and lets the mouse through", function()
            login()
            FarZoom.SetAlign(true)
            local frame = layer()
            assert.is_true(frame:IsShown())
            assert.same({ 0.5, n = 1 }, helper.lastCall(frame, "SetAlpha"))
            assert.is_false(frame:IsMouseEnabled())
            assert.is_nil(frame.textures[1].calls.Hide)
            FarZoom.SetAlign(false)
            assert.is_false(frame:IsShown())
        end)

        it("ends the alignment check on a wheel notch or a Blizzard zoom change", function()
            login()
            FarZoom.SetAlign(true)
            wheel(-1)
            assert.is_false(FarZoom.align)
            assert.equals(1, FarZoom.level)
            assert.same({ 1, n = 1 }, helper.lastCall(layer(), "SetAlpha"))
            FarZoom.SetLevel(0)
            FarZoom.SetAlign(true)
            state.minimapZoom = 1
            ns.Core.OnEvent(nil, "MINIMAP_UPDATE_ZOOM")
            assert.is_false(FarZoom.align)
            assert.is_false(layer():IsShown())
        end)
    end)
end)
