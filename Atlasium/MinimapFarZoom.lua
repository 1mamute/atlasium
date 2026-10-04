-- Minimap far zoom: past Blizzard's zoom 0, Atlasium draws the minimap terrain tiles itself, on a
-- layer that covers the Blizzard minimap. MinimapZoom.lua sends the wheel here past zoom 0.
local _, ns = ...

local FarZoom = {}
ns.MinimapFarZoom = FarZoom

local floor, sqrt, cos, sin, log = math.floor, math.sqrt, math.cos, math.sin, math.log
local min, max, sort = math.min, math.max, table.sort

-- World yards per minimap tile (mapX_Y): a continent is 64 x 64 tiles around world 0,0.
local TILE_YARDS = 1600 / 3

--- Return the minimap diameter at zoom 0, in yards (Astrolabe and HereBeDragons values).
function FarZoom.GetBaseDiameter(indoor)
    return indoor and 300 or 466 + 2 / 3
end

--- Return the number of far levels: each level multiplies the diameter by `step`, up to `maxFactor`.
function FarZoom.GetLevelCount(maxFactor, step)
    if step <= 1 or maxFactor < step then
        return 0
    end
    return floor(log(maxFactor) / log(step) + 1e-9)
end

--- Return the minimap diameter in yards at far `level` (0 is Blizzard's zoom 0).
function FarZoom.GetDiameter(level, indoor, step)
    return FarZoom.GetBaseDiameter(indoor) * step ^ level
end

--- Return the world position (x grows north, y grows west) of a map position. The bounds come
-- from WorldMapArea.dbc: left and right are world y, top and bottom are world x.
function FarZoom.ZoneToWorld(left, right, top, bottom, px, py)
    return top + (bottom - top) * py, left + (right - left) * px
end

--- Return the tile position (column grows east, row grows south) of a world position, with the
-- fraction inside the tile.
function FarZoom.WorldToTile(wx, wy)
    return 32 - wy / TILE_YARDS, 32 - wx / TILE_YARDS
end

--- Return the tile folder and the bounds (left, right, top, bottom) of a map and dungeon level, or
-- nil when the data has no bounds for them.
function FarZoom.GetBounds(data, mapName, level)
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
function FarZoom.GetPlayerTile(data, mapName, level, px, py)
    if not px or (px == 0 and py == 0) then
        return nil
    end
    local folder, left, right, top, bottom = FarZoom.GetBounds(data, mapName, level)
    if not folder then
        return nil
    end
    local col, row = FarZoom.WorldToTile(FarZoom.ZoneToWorld(left, right, top, bottom, px, py))
    return folder, col, row
end

--- Return the left and right edge (offsets from the center) of the minimap shape on the row at
-- offset `y` (down is positive). `r` is the radius. A round quarter follows the circle, a square
-- quarter goes to the full radius.
function FarZoom.GetRowExtent(shape, y, r)
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
function FarZoom.IsIndoorZoom(outdoorZoom, insideZoom, zoom, indoors)
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
function FarZoom.BuildSegments(params, emit)
    local r = params.size / 2
    local k = params.size / params.across -- units per tile
    local c, s = cos(params.angle), sin(params.angle)
    local col, row = params.col, params.row
    local count = 0
    local y0 = -r
    while y0 < r do
        local y1 = min(y0 + params.strip, r)
        local ym = (y0 + y1) / 2
        local xa, xb = FarZoom.GetRowExtent(params.shape, ym, r)
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

--- Return the 8 SetTexCoord values that turn a square texture `angle` radians counterclockwise.
function FarZoom.GetArrowTexCoords(angle)
    local c, s = cos(angle), sin(angle)
    local h = 0.5
    return h + c * -h - s * -h, h + s * -h + c * -h, -- upper left
        h + c * -h - s * h, h + s * -h + c * h, -- lower left
        h + c * h - s * -h, h + s * h + c * -h, -- upper right
        h + c * h - s * h, h + s * h + c * h -- lower right
end

-- Renderer: thin WoW glue around the pure functions above.

local STRIP, PAD = 2, 0.35 -- strip height and overlap in minimap units (no gaps in the spike)
local UPDATE_INTERVAL = 1 / 30 -- seconds between position checks
local RETRY_INTERVAL = 1 -- seconds between SetMapToCurrentZone calls while the position is missing
local WATER_R, WATER_G, WATER_B = 0.1, 0.2, 0.4 -- open sea (no tile)
-- The client draws the minimap tiles darker than the texture files (measured in Durotar at zoom 0).
local SHADE_R, SHADE_G, SHADE_B = 0.6, 0.62, 0.7
-- The Blizzard arrow, measured at zoom 0: its size, and the offset of its centre from the minimap
-- centre (x right, y up). The offset stays the same when the arrow turns.
local ARROW_SIZE, ARROW_X, ARROW_Y = 29, 1.8, 1.7

FarZoom.level = 0
FarZoom.align = false

-- Blizzard frames on the minimap edge that must stay above the layer, with their level over the minimap.
-- The border goes above the layer, and the buttons that sit on the border go above the border.
local RAISED = {
    { "MinimapBackdrop", 5 },
    { "MiniMapMailFrame", 6 },
    { "MiniMapBattlefieldFrame", 6 },
    { "GameTimeFrame", 6 },
    { "TimeManagerClockButton", 6 }, -- load-on-demand, so it can be missing
}

local frame, arrow
local savedLevels = {}
local pool, paths, used, shown = {}, {}, 0, 0
local pathCache = {}
local folder, col, row -- last good player position
local last = {} -- view of the last draw
local params = { strip = STRIP, pad = PAD }
local sinceUpdate, sinceRetry = 0, RETRY_INTERVAL

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
        texture = frame:CreateTexture(nil, "ARTWORK")
        pool[used] = texture
    end
    local path = GetTilePath(tx, ty)
    if paths[used] ~= path then
        if path then
            texture:SetTexture(path)
            texture:SetVertexColor(SHADE_R, SHADE_G, SHADE_B)
        else
            texture:SetTexture(WATER_R, WATER_G, WATER_B)
            texture:SetVertexColor(1, 1, 1)
        end
        paths[used] = path
    end
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
    texture:SetWidth(width)
    texture:SetHeight(height)
    texture:SetTexCoord(...)
    texture:Show()
end

local function Draw()
    used = 0
    FarZoom.BuildSegments(params, PlaceTile)
    for i = used + 1, shown do
        pool[i]:Hide()
    end
    shown = used
end

-- Read the player tile position from the current world map. Returns true on success.
local function ReadPosition()
    local px, py = GetPlayerMapPosition("player")
    local f, c, r = FarZoom.GetPlayerTile(ns.MinimapTileData, GetMapInfo(), GetCurrentMapDungeonLevel(), px, py)
    if f then
        folder, col, row = f, c, r
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
    return FarZoom.IsIndoorZoom(tonumber(GetCVar("minimapZoom")), tonumber(GetCVar("minimapInsideZoom")),
        Minimap:GetZoom(), IsIndoors())
end

-- Redraw when the view changed. Leave far zoom in an instance or without a position.
local function Update(elapsed)
    if IsInInstance() or not UpdatePosition(elapsed) then
        FarZoom.Leave()
        return
    end
    local indoor = IsIndoor()
    local diameter
    if FarZoom.level > 0 then
        diameter = FarZoom.GetDiameter(FarZoom.level, indoor, ns.db.minimapZoom.farStep)
    else
        diameter = FarZoom.GetBaseDiameter(indoor) -- alignment check at zoom 0
    end
    local facing = GetPlayerFacing() or 0
    local rotate = GetCVar("rotateMinimap") == "1"
    params.size = Minimap:GetWidth()
    params.shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    params.across = diameter / TILE_YARDS
    params.angle = rotate and -facing or 0
    params.col, params.row = col, row
    if last.size ~= params.size or last.shape ~= params.shape or last.across ~= params.across
        or last.angle ~= params.angle or last.col ~= col or last.row ~= row or last.folder ~= folder then
        last.size, last.shape, last.across, last.angle = params.size, params.shape, params.across, params.angle
        last.col, last.row, last.folder = col, row, folder
        Draw()
    end
    local arrowAngle = rotate and 0 or facing
    if last.arrowAngle ~= arrowAngle then
        last.arrowAngle = arrowAngle
        arrow:SetTexCoord(FarZoom.GetArrowTexCoords(arrowAngle))
    end
end

local function OnUpdate(_, elapsed)
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate >= UPDATE_INTERVAL then
        Update(sinceUpdate)
        sinceUpdate = 0
    end
end

local function OnMouseWheel(_, delta)
    ns.MinimapZoom.OnMouseWheel(Minimap, delta)
end

local function CreateLayer()
    frame = CreateFrame("Frame", nil, Minimap)
    frame:SetAllPoints(Minimap)
    frame:SetScript("OnMouseWheel", OnMouseWheel)
    frame:Hide()
    arrow = frame:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    arrow:SetWidth(ARROW_SIZE)
    arrow:SetHeight(ARROW_SIZE)
    arrow:SetPoint("CENTER", frame, "CENTER", ARROW_X, ARROW_Y)
end

local function IsActive()
    return frame ~= nil and frame:IsShown()
end

-- Show the layer over the Blizzard minimap. The Blizzard map stays shown (hiding it hides the
-- border and the pins of other add-ons); the frames in RAISED go above the layer.
local function Activate()
    if not frame then
        CreateLayer()
    end
    if not IsActive() then
        wipe(savedLevels)
        for _, entry in ipairs(RAISED) do
            local raised = _G[entry[1]]
            if raised then
                savedLevels[raised] = raised:GetFrameLevel()
                raised:SetFrameLevel(Minimap:GetFrameLevel() + entry[2])
            end
        end
        folder = nil
        sinceRetry = RETRY_INTERVAL
    end
    frame:SetFrameLevel(Minimap:GetFrameLevel() + 1)
    -- The alignment check shows the tiles and the arrow at half alpha over the Blizzard map and lets
    -- the mouse through.
    frame:SetAlpha(FarZoom.align and 0.5 or 1)
    frame:EnableMouse(not FarZoom.align)
    frame:EnableMouseWheel(not FarZoom.align)
    wipe(last)
    frame:Show()
    frame:SetScript("OnUpdate", OnUpdate)
    Update(0)
end

local function Deactivate()
    if not IsActive() then
        return
    end
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
    for raised, level in pairs(savedLevels) do
        raised:SetFrameLevel(level)
    end
    wipe(savedLevels)
end

local function Refresh()
    if FarZoom.level > 0 or FarZoom.align then
        Activate()
    else
        Deactivate()
    end
end

--- Return the number of far levels the settings allow.
function FarZoom.GetMaxLevel()
    local settings = ns.db.minimapZoom
    return FarZoom.GetLevelCount(settings.farMax, settings.farStep)
end

--- Set the far level (0 shows the Blizzard minimap). This ends the alignment check.
function FarZoom.SetLevel(level)
    FarZoom.align = false
    FarZoom.level = max(0, min(level, FarZoom.GetMaxLevel()))
    Refresh()
end

--- Leave far zoom and the alignment check, and show the Blizzard minimap.
function FarZoom.Leave()
    FarZoom.level = 0
    FarZoom.align = false
    Refresh()
end

--- Return true when the wheel can zoom out past the current level: far zoom is on, the Blizzard
-- minimap is at zoom 0, the player is not in an instance, and the data has the player's position.
function FarZoom.CanZoomOut()
    if not ns.db.minimapZoom.far or Minimap:GetZoom() ~= 0 or FarZoom.level >= FarZoom.GetMaxLevel()
        or IsInInstance() then
        return false
    end
    if FarZoom.level > 0 then
        return true
    end
    sinceRetry = RETRY_INTERVAL
    folder = nil
    return UpdatePosition(0)
end

--- Zoom out one far level.
function FarZoom.ZoomOut()
    PlaySound("igMiniMapZoomOut")
    FarZoom.SetLevel(FarZoom.level + 1)
end

--- Zoom in one far level. At level 0 the Blizzard minimap shows again.
function FarZoom.ZoomIn()
    PlaySound("igMiniMapZoomIn")
    FarZoom.SetLevel(FarZoom.level - 1)
end

--- Save the `far` setting. Turning it off leaves far zoom.
function FarZoom.SetEnabled(enabled)
    ns.db.minimapZoom.far = enabled
    if not enabled then
        FarZoom.Leave()
    end
end

--- Save the largest zoom factor past zoom 0, and step back when the current level is now too far.
function FarZoom.SetMaxFactor(factor)
    ns.db.minimapZoom.farMax = factor
    if FarZoom.level > FarZoom.GetMaxLevel() then
        FarZoom.SetLevel(FarZoom.GetMaxLevel())
    end
end

--- Turn the alignment check on or off: the tiles at the zoom 0 diameter, at half alpha over the
-- Blizzard minimap. Debug mode only.
function FarZoom.SetAlign(enabled)
    FarZoom.level = 0
    FarZoom.align = enabled
    Refresh()
end

-- The Blizzard + button zooms the covered minimap. While far zoom is active, it steps back one far
-- level instead.
local function WrapZoomInButton()
    if not MinimapZoomIn then
        return
    end
    local blizzardOnClick = MinimapZoomIn:GetScript("OnClick")
    MinimapZoomIn:SetScript("OnClick", function(...)
        if FarZoom.level > 0 then
            FarZoom.ZoomIn()
        elseif blizzardOnClick then
            blizzardOnClick(...)
        end
    end)
end

ns.Core.RegisterEvent("PLAYER_LOGIN", WrapZoomInButton)

-- Another add-on or the client changed the Blizzard zoom: leave far zoom and the alignment check,
-- which need zoom 0.
ns.Core.RegisterEvent("MINIMAP_UPDATE_ZOOM", function()
    if (FarZoom.level > 0 or FarZoom.align) and Minimap:GetZoom() ~= 0 then
        FarZoom.Leave()
    end
end)
