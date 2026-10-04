-- Minimap tiles: Atlasium draws the minimap ground (the terrain tiles) on a layer under the Blizzard
-- minimap, and hides the Blizzard ground with a transparent mask. The client still draws the player
-- arrow and the blips on top. Past Blizzard's zoom 0 the wheel goes to far levels on the same layer
-- (MinimapZoom.lua). Instances, indoors and the WMO cities show the Blizzard minimap.
local _, ns = ...

local Tiles = {}
ns.MinimapTiles = Tiles

local floor, sqrt, cos, sin, log = math.floor, math.sqrt, math.cos, math.sin, math.log
local min, max, sort = math.min, math.max, table.sort

-- World yards per minimap tile (mapX_Y): a continent is 64 x 64 tiles around world 0,0.
local TILE_YARDS = 1600 / 3

-- Outdoor minimap diameter in yards at Blizzard zoom 0 to 5 (Astrolabe and HereBeDragons values).
local DIAMETERS = { 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }

-- Cities where the client draws its own WMO minimap (md5translate.trs WMO folders), by map file name.
local WMO_CITIES = { Ogrimmar = true, ThunderBluff = true, Darnassis = true, TheExodar = true, Ironforge = true }

--- Return the minimap diameter in yards at Blizzard `zoom` and far `level` (level 0 is Blizzard's
-- zoom). Each far level multiplies the zoom 0 diameter by `step`.
function Tiles.GetDiameter(zoom, level, step)
    return (DIAMETERS[zoom + 1] or DIAMETERS[1]) * step ^ level
end

--- Return the number of far levels: each level multiplies the diameter by `step`, up to `maxFactor`.
function Tiles.GetLevelCount(maxFactor, step)
    if step <= 1 or maxFactor < step then
        return 0
    end
    return floor(log(maxFactor) / log(step) + 1e-9)
end

--- Return true when Atlasium draws the ground: not in an instance, not indoors, and not in a WMO city.
-- `mapName` is the map of the player position (GetMapInfo()).
function Tiles.CanDraw(mapName, instance, indoor)
    return not instance and not indoor and mapName ~= nil and not WMO_CITIES[mapName]
end

--- Return the world position (x grows north, y grows west) of a map position. The bounds come
-- from WorldMapArea.dbc: left and right are world y, top and bottom are world x.
function Tiles.ZoneToWorld(left, right, top, bottom, px, py)
    return top + (bottom - top) * py, left + (right - left) * px
end

--- Return the tile position (column grows east, row grows south) of a world position, with the
-- fraction inside the tile.
function Tiles.WorldToTile(wx, wy)
    return 32 - wy / TILE_YARDS, 32 - wx / TILE_YARDS
end

--- Return the tile folder and the bounds (left, right, top, bottom) of a map and dungeon level, or
-- nil when the data has no bounds for them.
function Tiles.GetBounds(data, mapName, level)
    local zone = mapName and data.zones[mapName]
    if not zone then
        return nil
    end
    if level and level > 0 then
        local floors = data.floors[mapName]
        local bounds = floors and floors[level]
        if bounds then
            return zone[1], bounds[1], bounds[2], bounds[3], bounds[4]
        end
        return nil
    end
    if zone[2] then
        return zone[1], zone[2], zone[3], zone[4], zone[5]
    end
end

--- Return the tile folder, column and row of a player position on a map, or nil. The client
-- returns 0, 0 when the player is not on the map.
function Tiles.GetPlayerTile(data, mapName, level, px, py)
    if not px or (px == 0 and py == 0) then
        return nil
    end
    local folder, left, right, top, bottom = Tiles.GetBounds(data, mapName, level)
    if not folder then
        return nil
    end
    local col, row = Tiles.WorldToTile(Tiles.ZoneToWorld(left, right, top, bottom, px, py))
    return folder, col, row
end

--- Return the left and right edge (offsets from the center) of the minimap shape on the row at
-- offset `y` (down is positive). `r` is the radius. A round quarter follows the circle, a square
-- quarter goes to the full radius.
function Tiles.GetRowExtent(shape, y, r)
    local quarters = ns.Util.GetRoundQuarters(shape)
    local half = sqrt(max(r * r - y * y, 0))
    local top = y < 0
    local left = quarters[top and "TOPLEFT" or "BOTTOMLEFT"] and half or r
    local right = quarters[top and "TOPRIGHT" or "BOTTOMRIGHT"] and half or r
    return -left, right
end

--- Return true when the minimap uses the indoor zoom. The client keeps the outdoor and indoor zoom
-- in two CVars; when they differ, the current zoom tells which one is in use (HereBeDragons does the
-- same). When they are equal, `indoors` (IsIndoors()) decides.
function Tiles.IsIndoorZoom(outdoorZoom, insideZoom, zoom, indoors)
    if outdoorZoom ~= insideZoom then
        return zoom == insideZoom
    end
    return indoors and true or false
end

-- Split points of the strip being built, reused to avoid garbage on each frame.
local cuts = {}

-- Add a split point where the tile coordinate, which goes from p at offset a to q at offset b,
-- crosses a whole number.
local function AddCuts(p, q, a, b)
    if p == q then
        return
    end
    for n = floor(min(p, q)) + 1, max(p, q) do
        cuts[#cuts + 1] = a + (n - p) / (q - p) * (b - a)
    end
end

--- Cover the minimap shape with pieces of tiles and call `emit` for each piece with
-- (tx, ty, left, top, width, height, ulx, uly, llx, lly, urx, ury, lrx, lry): the tile, the
-- piece rectangle from the top-left corner of the minimap (down is positive) and the 8 SetTexCoord
-- values. Returns the number of pieces.
-- `params`: size (minimap width), shape (GetMinimapShape), strip (strip height), pad (extra height
-- so strips overlap), col and row (tile position of the center), across (tiles across the size),
-- angle (map rotation in radians, counterclockwise).
-- Each horizontal strip is split where its center line crosses a tile edge. Each piece shows its
-- slice of one tile, rotated through the 8 argument SetTexCoord.
function Tiles.BuildSegments(params, emit)
    local r = params.size / 2
    local k = params.size / params.across -- units per tile
    local c, s = cos(params.angle), sin(params.angle)
    local col, row = params.col, params.row
    local count = 0
    local y0 = -r
    while y0 < r do
        local y1 = min(y0 + params.strip, r)
        local ym = (y0 + y1) / 2
        local xa, xb = Tiles.GetRowExtent(params.shape, ym, r)
        if xb > xa then
            for i = #cuts, 1, -1 do
                cuts[i] = nil
            end
            cuts[1], cuts[2] = xa, xb
            AddCuts(col + (c * xa - s * ym) / k, col + (c * xb - s * ym) / k, xa, xb)
            AddCuts(row + (s * xa + c * ym) / k, row + (s * xb + c * ym) / k, xa, xb)
            sort(cuts)
            local y2 = min(y1 + params.pad, r)
            local a = cuts[1]
            for i = 2, #cuts do
                local b = cuts[i]
                -- A piece thinner than 0.01 joins the next one, so the strip has no gap.
                if b - a > 0.01 or (i == #cuts and b > a) then
                    local m = (a + b) / 2
                    local tx = floor(col + (c * m - s * ym) / k)
                    local ty = floor(row + (s * m + c * ym) / k)
                    local u, v = col - tx, row - ty
                    count = count + 1
                    emit(tx, ty, r + a, r + y0, b - a, y2 - y0,
                        u + (c * a - s * y0) / k, v + (s * a + c * y0) / k,
                        u + (c * a - s * y2) / k, v + (s * a + c * y2) / k,
                        u + (c * b - s * y0) / k, v + (s * b + c * y0) / k,
                        u + (c * b - s * y2) / k, v + (s * b + c * y2) / k)
                    a = b
                end
            end
        end
        y0 = y1
    end
    return count
end

-- Renderer: thin WoW glue around the pure functions above.

local STRIP, PAD = 2, 0.35 -- strip height and overlap in minimap units (no gaps in the spike)
local UPDATE_INTERVAL = 1 / 30 -- seconds between position checks
local RETRY_INTERVAL = 1 -- seconds between SetMapToCurrentZone calls while the position is missing
local WATER_R, WATER_G, WATER_B = 0.1, 0.2, 0.4 -- open sea (no tile)
local CLEAR = "Interface\\WORLDMAP\\Silithus\\pixelfix1" -- a fully transparent client texture

Tiles.level = 0
Tiles.align = false

-- Minimap textures that Atlasium replaces with CLEAR: the mask hides the Blizzard ground, and the blip
-- texture hides the blips at far levels (the client places them at the zoom 0 scale). `saved` is the
-- texture that Blizzard or another add-on set last, which comes back when Atlasium is done.
local swaps = {
    mask = { method = "SetMaskTexture", saved = "Textures\\MinimapMask", clear = false },
    blips = { method = "SetBlipTexture", saved = "Interface\\Minimap\\ObjectIcons", clear = false },
}
local swapping = false

local driver, layer
local pool, paths, used, shown = {}, {}, 0, 0
local pathCache = {}
local folder, col, row, mapName -- last good player position
local drawing = false
local last = {} -- view of the last draw
local params = { strip = STRIP, pad = PAD }
local sinceUpdate, sinceRetry = 0, RETRY_INTERVAL

local function CallSwap(swap, path)
    swapping = true
    Minimap[swap.method](Minimap, path)
    swapping = false
end

local function SetClear(swap, clear)
    if swap.clear ~= clear then
        swap.clear = clear
        CallSwap(swap, clear and CLEAR or swap.saved)
    end
end

-- Remember the texture another add-on sets. While Atlasium has CLEAR set, put CLEAR back.
for _, swap in pairs(swaps) do
    hooksecurefunc(Minimap, swap.method, function(_, path)
        if swapping then
            return
        end
        swap.saved = path
        if swap.clear then
            CallSwap(swap, CLEAR)
        end
    end)
end

local function GetTilePath(tx, ty)
    if tx < 0 or tx > 63 or ty < 0 or ty > 63 then
        return false
    end
    local cache = pathCache[folder]
    if not cache then
        cache = {}
        pathCache[folder] = cache
    end
    local index = tx * 64 + ty
    local path = cache[index]
    if path == nil then
        local md5 = ns.MinimapTileData.tiles[folder][tx .. "_" .. ty]
        path = md5 and "Textures\\Minimap\\" .. md5 or false
        cache[index] = path
    end
    return path
end

local function PlaceTile(tx, ty, left, top, width, height, ...)
    used = used + 1
    local texture = pool[used]
    if not texture then
        texture = layer:CreateTexture(nil, "ARTWORK")
        pool[used] = texture
    end
    local path = GetTilePath(tx, ty)
    if paths[used] ~= path then
        if path then
            texture:SetTexture(path)
        else
            texture:SetTexture(WATER_R, WATER_G, WATER_B)
        end
        paths[used] = path
    end
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", layer, "TOPLEFT", left, -top)
    texture:SetWidth(width)
    texture:SetHeight(height)
    texture:SetTexCoord(...)
    texture:Show()
end

local function Draw()
    used = 0
    Tiles.BuildSegments(params, PlaceTile)
    for i = used + 1, shown do
        pool[i]:Hide()
    end
    shown = used
end

-- Read the player tile position from the current world map. Returns true on success.
local function ReadPosition()
    local name = GetMapInfo()
    local px, py = GetPlayerMapPosition("player")
    local f, c, r = Tiles.GetPlayerTile(ns.MinimapTileData, name, GetCurrentMapDungeonLevel(), px, py)
    if f then
        folder, col, row, mapName = f, c, r, name
        return true
    end
    return false
end

-- Update the player position. When the current map has no position and the world map is closed,
-- set the map to the player's zone (at most once per RETRY_INTERVAL). While the world map is open,
-- keep the last good position. Returns false when there is no position.
local function UpdatePosition(elapsed)
    if ReadPosition() then
        return true
    end
    sinceRetry = sinceRetry + elapsed
    if sinceRetry >= RETRY_INTERVAL and not WorldMapFrame:IsShown() then
        sinceRetry = 0
        SetMapToCurrentZone()
        return ReadPosition()
    end
    return folder ~= nil
end

local function IsIndoor()
    return Tiles.IsIndoorZoom(tonumber(GetCVar("minimapZoom")), tonumber(GetCVar("minimapInsideZoom")),
        Minimap:GetZoom(), IsIndoors())
end

local function CreateLayer()
    -- Under the Blizzard minimap, so the client draws the arrow and the blips over the tiles. The
    -- mouse goes to the minimap.
    layer = CreateFrame("Frame", nil, MinimapCluster)
    layer:SetAllPoints(Minimap)
    layer:SetFrameStrata(Minimap:GetFrameStrata())
    layer:Hide()
end

-- Show the Blizzard minimap: restore the mask and the blips, hide the tiles and leave far zoom.
local function StopDrawing()
    drawing = false
    Tiles.level = 0
    SetClear(swaps.mask, false)
    SetClear(swaps.blips, false)
    if layer then
        layer:Hide()
    end
end

-- Show the tiles under a transparent mask. The alignment check shows them at half alpha over the
-- Blizzard minimap instead.
local function StartDrawing()
    if not layer then
        CreateLayer()
    end
    local level = Minimap:GetFrameLevel()
    layer:SetFrameLevel(Tiles.align and level + 1 or max(level - 1, 0))
    layer:SetAlpha(Tiles.align and 0.5 or 1)
    SetClear(swaps.mask, not Tiles.align)
    SetClear(swaps.blips, Tiles.level > 0)
    if not drawing then
        drawing = true
        wipe(last)
        layer:Show()
    end
end

-- Draw the tiles when the player is where Atlasium can draw, else show the Blizzard minimap.
-- Redraw only when the view changed.
local function Update(elapsed)
    -- Check the instance first: there the position is missing, and the retry would reset the map.
    local instance = IsInInstance()
    if instance or not UpdatePosition(elapsed) or not Tiles.CanDraw(mapName, instance, IsIndoor()) then
        StopDrawing()
        return
    end
    StartDrawing()
    local rotate = GetCVar("rotateMinimap") == "1"
    params.size = Minimap:GetWidth()
    params.shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    params.across = Tiles.GetDiameter(Minimap:GetZoom(), Tiles.level, ns.db.minimapTiles.farStep) / TILE_YARDS
    params.angle = rotate and -(GetPlayerFacing() or 0) or 0
    params.col, params.row = col, row
    if last.size ~= params.size or last.shape ~= params.shape or last.across ~= params.across
        or last.angle ~= params.angle or last.col ~= col or last.row ~= row or last.folder ~= folder then
        last.size, last.shape, last.across, last.angle = params.size, params.shape, params.across, params.angle
        last.col, last.row, last.folder = col, row, folder
        Draw()
    end
end

local function OnUpdate(_, elapsed)
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate >= UPDATE_INTERVAL then
        Update(sinceUpdate)
        sinceUpdate = 0
    end
end

-- Start or stop the position checks, and draw at once.
local function Refresh()
    if not driver then
        driver = CreateFrame("Frame")
    end
    if ns.db.minimapTiles.enabled then
        driver:SetScript("OnUpdate", OnUpdate)
        sinceRetry = RETRY_INTERVAL
        Update(0)
    else
        driver:SetScript("OnUpdate", nil)
        Tiles.align = false
        StopDrawing()
    end
end

--- Return the number of far levels the settings allow.
function Tiles.GetMaxLevel()
    local settings = ns.db.minimapTiles
    return Tiles.GetLevelCount(settings.farMax, settings.farStep)
end

--- Set the far level (0 is Blizzard's zoom). This ends the alignment check.
function Tiles.SetLevel(level)
    Tiles.align = false
    Tiles.level = max(0, min(level, Tiles.GetMaxLevel()))
    Refresh()
end

--- Leave far zoom and the alignment check.
function Tiles.Leave()
    Tiles.SetLevel(0)
end

--- Return true when the wheel can zoom out past the current level: the tiles are on and drawn, and
-- the Blizzard minimap is at zoom 0.
function Tiles.CanZoomOut()
    if not ns.db.minimapTiles.enabled or Minimap:GetZoom() ~= 0 or Tiles.level >= Tiles.GetMaxLevel() then
        return false
    end
    if not drawing then
        sinceRetry = RETRY_INTERVAL
        Update(0)
    end
    return drawing
end

--- Zoom out one far level.
function Tiles.ZoomOut()
    PlaySound("igMiniMapZoomOut")
    Tiles.SetLevel(Tiles.level + 1)
end

--- Zoom in one far level. At level 0 the Blizzard zoom takes over again.
function Tiles.ZoomIn()
    PlaySound("igMiniMapZoomIn")
    Tiles.SetLevel(Tiles.level - 1)
end

--- Save the `enabled` setting. Off shows the Blizzard minimap as it is without Atlasium.
function Tiles.SetEnabled(enabled)
    ns.db.minimapTiles.enabled = enabled
    Tiles.level = 0
    Tiles.align = false
    Refresh()
end

--- Save the largest zoom factor past zoom 0, and step back when the current level is now too far.
function Tiles.SetMaxFactor(factor)
    ns.db.minimapTiles.farMax = factor
    if Tiles.level > Tiles.GetMaxLevel() then
        Tiles.SetLevel(Tiles.GetMaxLevel())
    end
end

--- Turn the alignment check on or off: the tiles at half alpha over the Blizzard minimap, at the
-- current Blizzard zoom. Debug mode only.
function Tiles.SetAlign(enabled)
    Tiles.level = 0
    Tiles.align = enabled
    Refresh()
end

--- Return true when Atlasium draws the tiles now.
function Tiles.IsDrawing()
    return drawing
end

-- The Blizzard + button zooms the Blizzard minimap. While far zoom is active, it steps back one far
-- level instead.
local function WrapZoomInButton()
    if not MinimapZoomIn then
        return
    end
    local blizzardOnClick = MinimapZoomIn:GetScript("OnClick")
    MinimapZoomIn:SetScript("OnClick", function(...)
        if Tiles.level > 0 then
            Tiles.ZoomIn()
        elseif blizzardOnClick then
            blizzardOnClick(...)
        end
    end)
end

ns.Core.RegisterEvent("PLAYER_LOGIN", function()
    WrapZoomInButton()
    if ns.db.minimapTiles.enabled then
        Refresh()
    end
end)

-- Another add-on or the client changed the Blizzard zoom: far levels need zoom 0.
ns.Core.RegisterEvent("MINIMAP_UPDATE_ZOOM", function()
    if Tiles.level > 0 and Minimap:GetZoom() ~= 0 then
        Tiles.Leave()
    end
end)

-- The client keeps the current map when the player walks into another zone with the world map
-- closed. Set it to the new zone, so the WMO city check sees the city.
ns.Core.RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
    if ns.db.minimapTiles.enabled and not WorldMapFrame:IsShown() then
        SetMapToCurrentZone()
    end
end)
