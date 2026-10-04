-- Fog clearing: draws the world map areas that the player has not explored yet, with a tint.
-- Blizzard still draws the explored areas. We add only the unexplored ones, on our own textures.
local _, ns = ...

local FogClear = {}
ns.FogClear = FogClear

local ceil, sort = math.ceil, table.sort

-- Overlays are stored as pieces of up to TILE_SIZE x TILE_SIZE pixels.
local TILE_SIZE = 256

--- Return the last part of an overlay texture path in capitals.
-- "Interface\WorldMap\Elwynn\Goldshire" gives "GOLDSHIRE".
function FogClear.OverlayKey(texturePath)
    return (texturePath:match("([^\\/]*)$")):upper()
end

--- Return the sorted names in `zoneOverlays` whose OverlayKey is not in the set `explored`.
function FogClear.GetUnexplored(zoneOverlays, explored)
    local names = {}
    for name in pairs(zoneOverlays) do
        if not explored[FogClear.OverlayKey(name)] then
            names[#names + 1] = name
        end
    end
    sort(names)
    return names
end

-- The size of the last piece in a row or column, and the power-of-two size of its image file.
local function LastPieceSize(size)
    local piece = size % TILE_SIZE
    if piece == 0 then
        piece = TILE_SIZE
    end
    local file = 16
    while file < piece do
        file = file * 2
    end
    return piece, file
end

local tileCache = {}

--- Return the pieces of one overlay, in the same order and size as Blizzard's WorldMapFrame_Update.
-- Each piece has `index` (the number after the texture path), `width`, `height`, `right` and
-- `bottom` (the texture coordinates) and `x`, `y` (the TOPLEFT offset from WorldMapDetailFrame).
-- The result is cached, so do not change it.
function FogClear.GetTiles(width, height, offsetX, offsetY)
    local cacheKey = width .. ":" .. height .. ":" .. offsetX .. ":" .. offsetY
    local tiles = tileCache[cacheKey]
    if tiles then
        return tiles
    end
    tiles = {}
    local columns, rows = ceil(width / TILE_SIZE), ceil(height / TILE_SIZE)
    local lastWidth, lastFileWidth = LastPieceSize(width)
    local lastHeight, lastFileHeight = LastPieceSize(height)
    for j = 1, rows do
        local pieceHeight, fileHeight = TILE_SIZE, TILE_SIZE
        if j == rows then
            pieceHeight, fileHeight = lastHeight, lastFileHeight
        end
        for k = 1, columns do
            local pieceWidth, fileWidth = TILE_SIZE, TILE_SIZE
            if k == columns then
                pieceWidth, fileWidth = lastWidth, lastFileWidth
            end
            tiles[#tiles + 1] = {
                index = (j - 1) * columns + k,
                width = pieceWidth,
                height = pieceHeight,
                right = pieceWidth / fileWidth,
                bottom = pieceHeight / fileHeight,
                x = offsetX + TILE_SIZE * (k - 1),
                y = -(offsetY + TILE_SIZE * (j - 1)),
            }
        end
    end
    tileCache[cacheKey] = tiles
    return tiles
end

-- Our textures on WorldMapDetailFrame. They have no names, so we do not add globals.
local pool = {}
local explored = {}

local function HideFrom(first)
    for i = first, #pool do
        pool[i]:Hide()
    end
end

--- Draw the unexplored overlays of the current map. Runs after WorldMapFrame_Update.
function FogClear.Update()
    if not ns.db or not ns.db.fogClear.enabled then
        HideFrom(1)
        return
    end
    local mapName = GetMapInfo()
    local zoneOverlays = mapName and ns.Overlays[mapName]
    if not zoneOverlays then
        HideFrom(1)
        return
    end

    wipe(explored)
    for i = 1, GetNumMapOverlays() do
        local texturePath = GetMapOverlayInfo(i)
        if texturePath and texturePath ~= "" then
            explored[FogClear.OverlayKey(texturePath)] = true
        end
    end

    local color = ns.db.fogClear.color
    local count = 0
    for _, name in ipairs(FogClear.GetUnexplored(zoneOverlays, explored)) do
        local path = "Interface\\WorldMap\\" .. mapName .. "\\" .. name
        local overlay = zoneOverlays[name]
        for _, tile in ipairs(FogClear.GetTiles(overlay[1], overlay[2], overlay[3], overlay[4])) do
            count = count + 1
            local texture = pool[count]
            if not texture then
                -- BORDER is above the base map (BACKGROUND) and below Blizzard's overlays (ARTWORK).
                texture = WorldMapDetailFrame:CreateTexture(nil, "BORDER")
                pool[count] = texture
            end
            texture:SetWidth(tile.width)
            texture:SetHeight(tile.height)
            texture:SetTexCoord(0, tile.right, 0, tile.bottom)
            texture:SetPoint("TOPLEFT", WorldMapDetailFrame, "TOPLEFT", tile.x, tile.y)
            texture:SetTexture(path .. tile.index)
            texture:SetVertexColor(color.r, color.g, color.b)
            texture:SetAlpha(color.a)
            texture:Show()
        end
    end
    HideFrom(count + 1)
end

--- Save the `enabled` setting. If the map is open, draw or hide the overlays at once.
function FogClear.SetEnabled(enabled)
    ns.db.fogClear.enabled = enabled
    if WorldMapFrame:IsShown() then
        FogClear.Update()
    end
end

--- Save an independent tint table and refresh unexplored areas on the open map.
function FogClear.SetColor(color)
    ns.db.fogClear.color = { r = color.r, g = color.g, b = color.b, a = color.a }
    if WorldMapFrame:IsShown() then FogClear.Update() end
end

-- WorldMapFrame_Update is in FrameXML, which loads before add-ons. hooksecurefunc runs our function
-- after Blizzard's and does not replace it, so it causes no taint.
hooksecurefunc("WorldMapFrame_Update", FogClear.Update)
