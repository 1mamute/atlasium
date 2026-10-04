-- Map navigation: the mouse wheel zooms the world map around the cursor, a left drag pans it.
-- The map frames move into a clipping ScrollFrame (the viewport) and a scaled zoom frame, like the
-- WorldMapScrollFrame that Blizzard added in 6.0. Blizzard icons are counter-scaled to keep their size.
local _, ns = ...

local MapNavigation = {}
ns.MapNavigation = MapNavigation

local abs, max, min = math.abs, math.max, math.min

-- Zoom speed of the eased animation: about 0.25 s per wheel notch.
local EASE_SPEED = 12
-- A press that moves less than this, in screen pixels, is a click and not a drag.
local DRAG_THRESHOLD = 4
-- Detach the quest blob frame during combat (see PLAYER_REGEN_DISABLED below).
local DETACH_BLOB_IN_COMBAT = true

--- Return `v` limited to the range from `low` to `high`.
function MapNavigation.Clamp(v, low, high)
    return max(low, min(v, high))
end
local Clamp = MapNavigation.Clamp

--- Return the zoom target after `notches` wheel notches (positive zooms in), from 1 to `maxZoom`.
function MapNavigation.StepZoom(target, notches, step, maxZoom)
    return Clamp(target * step ^ notches, 1, maxZoom)
end

--- Return the zoom after one animation frame. Snaps to `target` when the gap is below 0.2 %.
function MapNavigation.Ease(current, target, elapsed, speed)
    local zoom = current + (target - current) * min(1, elapsed * speed)
    if abs(target - zoom) < target * 0.002 then
        return target
    end
    return zoom
end

--- Return the largest scroll offset for a viewport side of `viewSize` at `zoom`.
function MapNavigation.ScrollMax(viewSize, zoom)
    return viewSize * (zoom - 1)
end

--- Return the scroll offset that keeps the map point under `anchor` fixed when the zoom changes.
-- `anchor` and `scroll` are in viewport units, from the viewport top left.
function MapNavigation.ZoomScroll(anchor, scroll, oldZoom, newZoom)
    return newZoom / oldZoom * (anchor + scroll) - anchor
end

--- Return the cursor position in viewport units, from the viewport top left (y goes down).
-- `cx`, `cy` come from GetCursorPosition; `scale` is the viewport's effective scale.
function MapNavigation.CursorToView(cx, cy, scale, left, top)
    return cx / scale - left, top - cy / scale
end

--- Return the scroll offsets for a drag that started at the cursor `scx`, `scy` with the scroll
-- `sx`, `sy`, now that the cursor is at `cx`, `cy`. The result is not clamped.
function MapNavigation.PanScroll(sx, sy, scx, scy, cx, cy, scale)
    return sx + (scx - cx) / scale, sy + (cy - scy) / scale
end

--- Return true when a cursor move of `dx`, `dy` screen pixels is a drag.
function MapNavigation.IsDrag(dx, dy, threshold)
    return dx * dx + dy * dy >= threshold * threshold
end

--- Return the five values of any SetPoint call form. A nil `relativeTo` means the parent.
function MapNavigation.NormalizePoint(point, a, b, c, d)
    if type(a) == "number" then
        return point, nil, point, a, b or 0
    end
    if type(b) == "number" then
        return point, a, point, b, c or 0
    end
    return point, a, b or point, c or 0, d or 0
end

--- Return the raw (Blizzard) value of an icon offset or scale.
-- If `current` is still the value we `applied`, we placed the icon last, so `raw` is right.
-- Else Blizzard moved it, and `current` is the new raw value. The client stores these values as
-- 32-bit floats, so they can come back a little different from what we set.
function MapNavigation.ResolveRaw(current, applied, raw)
    if raw and applied and abs(current - applied) <= 1e-4 * max(1, abs(applied)) then
        return raw
    end
    return current
end

--- Return the scale and the offsets that keep an icon at its raw size and map position at `zoom`.
-- Anchor offsets are in the icon's own scale units, so with a scale of 1/zoom an offset of x*zoom
-- lands at x in the parent's units.
function MapNavigation.IconPlacement(rawX, rawY, rawScale, zoom)
    return rawScale / zoom, rawX * zoom, rawY * zoom
end

--- Return the left, right, top and bottom hit rect insets of a map frame with the scale `scale` (in
-- the zoom frame) so that it takes the mouse only inside the viewport.
function MapNavigation.HitInsets(scrollX, scrollY, viewW, viewH, zoom, scale)
    local unit = zoom * scale
    return scrollX / unit, (viewW * zoom - viewW - scrollX) / unit,
        scrollY / unit, (viewH * zoom - viewH - scrollY) / unit
end

--- Return true when the point x, y (viewport units, from the top left) is inside the viewport.
function MapNavigation.InView(x, y, viewW, viewH)
    return x >= 0 and x <= viewW and y >= 0 and y <= viewH
end
local InView = MapNavigation.InView

local state = {
    built = false,
    zoom = 1,
    targetZoom = 1,
    anchorX = 0, -- cursor position in the viewport at the last wheel notch
    anchorY = 0,
    scrollX = 0,
    scrollY = 0,
    viewW = 0, -- viewport size, in WorldMapFrame units
    viewH = 0,
    panning = false,
    moved = false,
    startCursorX = 0,
    startCursorY = 0,
    startScrollX = 0,
    startScrollY = 0,
    mapContinent = nil,
    mapArea = nil,
    mapLevel = nil,
    blobDetached = false,
}
MapNavigation.state = state

local viewport, scrollChild, zoomFrame, overlay, blobRestorer
-- The last point Blizzard gave WorldMapDetailFrame, with offsets in detail frame units.
local detailAnchor = {}

-- Icon bookkeeping: raw Blizzard values and the values we applied last. Weak keys, filled once per frame.
local function WeakTable()
    return setmetatable({}, { __mode = "k" })
end
local rawX, rawY, rawScale = WeakTable(), WeakTable(), WeakTable()
local appliedX, appliedY, appliedScale = WeakTable(), WeakTable(), WeakTable()
local questPOIs = WeakTable()
local units = {}
local landmarks = {}

local function IsEnabled()
    return ns.db and ns.db.mapNav.enabled
end

--- Counter-scale one icon anchored by one point so it keeps its on-screen size at the current zoom.
function MapNavigation.Place(frame)
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then
        return
    end
    local resolve = MapNavigation.ResolveRaw
    local rx = resolve(x, appliedX[frame], rawX[frame])
    local ry = resolve(y, appliedY[frame], rawY[frame])
    local rs = resolve(frame:GetScale(), appliedScale[frame], rawScale[frame])
    rawX[frame], rawY[frame], rawScale[frame] = rx, ry, rs
    local scale, nx, ny = MapNavigation.IconPlacement(rx, ry, rs, state.zoom)
    appliedX[frame], appliedY[frame], appliedScale[frame] = nx, ny, scale
    frame:SetScale(scale)
    frame:SetPoint(point, relativeTo, relativePoint, nx, ny)
end
local Place = MapNavigation.Place

local function PlaceUnits(skipHidden)
    for i = 1, #units do
        local frame = units[i]
        if not skipHidden or frame:IsShown() then
            Place(frame)
        end
    end
    for _, frame in ipairs(MAP_VEHICLES) do
        if not skipHidden or frame:IsShown() then
            Place(frame)
        end
    end
end

local function PlaceLandmarks()
    for i = 1, NUM_WORLDMAP_POIS do
        local frame = landmarks[i] or _G["WorldMapFramePOI" .. i]
        landmarks[i] = frame
        if frame then
            Place(frame)
        end
    end
end

-- A selected completed quest shows Blizzard's swap button (the yellow circle) on top of its POI. It is
-- anchored to the POI with no offset, so it needs only the counter-scale.
local function PlaceSwapButton()
    local swap = QUEST_POI_SWAP_BUTTONS.WorldMapPOIFrame
    if swap then
        Place(swap)
    end
end

local function PlaceQuestPOIs()
    for frame in pairs(questPOIs) do
        Place(frame)
    end
    PlaceSwapButton()
end

local function PlaceIcons()
    PlaceUnits(false)
    PlaceLandmarks()
    PlaceQuestPOIs()
end

-- WorldMapBlobFrame_OnUpdate caches its hit math from the blob's position and scale. Clearing the
-- cache makes Blizzard calculate it again on the next mouse-over, as WorldMap_ToggleSizeUp does.
local function ResetBlobHits()
    if not state.blobDetached then
        WorldMapBlobFrame.xRatio = nil
    end
end

-- Return the quest frame whose blob Blizzard shows, or nil. A completed quest has no blob.
local function SelectedBlobQuest()
    local selected = WORLDMAP_SETTINGS.selectedQuest
    if selected and not selected.completed then
        return selected
    end
end

local blobZoomed = false

-- The blob frame fixes the blob on the screen when it draws it, so a zoom or a scroll leaves the blob
-- behind. Blizzard draws it again after a title bar drag for the same reason. Do the same after every
-- zoom or scroll change, and once more on the way back to 1x. A draw of a blob that is already drawn
-- does nothing, so clear it first, as the title bar drag does.
local function RedrawBlob()
    if state.blobDetached or (state.zoom == 1 and not blobZoomed) then
        return
    end
    blobZoomed = state.zoom ~= 1
    local selected = SelectedBlobQuest()
    if selected and selected:IsShown() then
        WorldMapBlobFrame:DrawQuestBlob(selected.questId, false)
        WorldMapBlobFrame:DrawQuestBlob(selected.questId, true)
    end
end

local function UpdateBlob()
    ResetBlobHits()
    RedrawBlob()
end

--- Show the map at `zoom` with the current scroll, clamped to the map edges.
function MapNavigation.ApplyZoom(zoom)
    state.zoom = zoom
    state.scrollX = Clamp(state.scrollX, 0, MapNavigation.ScrollMax(state.viewW, zoom))
    state.scrollY = Clamp(state.scrollY, 0, MapNavigation.ScrollMax(state.viewH, zoom))
    zoomFrame:SetScale(zoom)
    scrollChild:SetWidth(state.viewW * zoom)
    scrollChild:SetHeight(state.viewH * zoom)
    viewport:UpdateScrollChildRect()
    viewport:SetHorizontalScroll(state.scrollX)
    viewport:SetVerticalScroll(state.scrollY)
    WorldMapButton:SetHitRectInsets(MapNavigation.HitInsets(state.scrollX, state.scrollY,
        state.viewW, state.viewH, zoom, WorldMapButton:GetScale()))
    PlaceIcons()
    UpdateBlob()
end

local function SetScroll(x, y)
    state.scrollX = Clamp(x, 0, MapNavigation.ScrollMax(state.viewW, state.zoom))
    state.scrollY = Clamp(y, 0, MapNavigation.ScrollMax(state.viewH, state.zoom))
    viewport:SetHorizontalScroll(state.scrollX)
    viewport:SetVerticalScroll(state.scrollY)
    WorldMapButton:SetHitRectInsets(MapNavigation.HitInsets(state.scrollX, state.scrollY,
        state.viewW, state.viewH, state.zoom, WorldMapButton:GetScale()))
    UpdateBlob()
end

local function StopPan()
    if state.moved then
        WorldMapButton:EnableMouse(true)
    end
    state.panning = false
    state.moved = false
end

local function UpdatePan()
    if not IsMouseButtonDown("LeftButton") then
        StopPan()
        return
    end
    local cx, cy = GetCursorPosition()
    if not state.moved then
        if not MapNavigation.IsDrag(cx - state.startCursorX, cy - state.startCursorY, DRAG_THRESHOLD) then
            return
        end
        -- A disabled mouse stops the OnMouseUp, so the drag does not end in a click (a zone-in).
        state.moved = true
        WorldMapButton:EnableMouse(false)
    end
    SetScroll(MapNavigation.PanScroll(state.startScrollX, state.startScrollY,
        state.startCursorX, state.startCursorY, cx, cy, viewport:GetEffectiveScale()))
end

-- The driver runs only while the zoom animates or a drag is active.
local function OnDriverUpdate(self, elapsed)
    if state.zoom ~= state.targetZoom then
        local newZoom = MapNavigation.Ease(state.zoom, state.targetZoom, elapsed, EASE_SPEED)
        state.scrollX = MapNavigation.ZoomScroll(state.anchorX, state.scrollX, state.zoom, newZoom)
        state.scrollY = MapNavigation.ZoomScroll(state.anchorY, state.scrollY, state.zoom, newZoom)
        MapNavigation.ApplyZoom(newZoom)
    end
    if state.panning then
        UpdatePan()
    end
    if not state.panning and state.zoom == state.targetZoom then
        self:SetScript("OnUpdate", nil)
    end
end
MapNavigation.OnDriverUpdate = OnDriverUpdate

local function StartDriver()
    viewport:SetScript("OnUpdate", OnDriverUpdate)
end

--- Go back to 1x with no scroll, at once.
function MapNavigation.ResetZoom()
    if not state.built then
        return
    end
    StopPan()
    viewport:SetScript("OnUpdate", nil)
    state.targetZoom = 1
    state.scrollX, state.scrollY = 0, 0
    MapNavigation.ApplyZoom(1)
end
local ResetZoom = MapNavigation.ResetZoom

--- Mouse wheel on the map: change the zoom target around the cursor.
function MapNavigation.OnWheel(_, delta)
    if not state.built or not IsEnabled() or state.panning then
        return
    end
    local db = ns.db.mapNav
    local target = MapNavigation.StepZoom(state.targetZoom, delta, db.step, db.maxZoom)
    if target == state.targetZoom then
        return
    end
    local cx, cy = GetCursorPosition()
    state.anchorX, state.anchorY = MapNavigation.CursorToView(cx, cy, viewport:GetEffectiveScale(),
        viewport:GetLeft(), viewport:GetTop())
    state.anchorX = Clamp(state.anchorX, 0, state.viewW)
    state.anchorY = Clamp(state.anchorY, 0, state.viewH)
    state.targetZoom = target
    StartDriver()
end

--- Mouse down on WorldMapButton: start a possible drag. At 1x every click stays vanilla.
function MapNavigation.OnButtonDown(_, button)
    if button ~= "LeftButton" or state.zoom <= 1 or not IsEnabled() then
        return
    end
    -- Finish a running zoom animation first, so the drag starts from a fixed scroll.
    if state.zoom ~= state.targetZoom then
        state.scrollX = MapNavigation.ZoomScroll(state.anchorX, state.scrollX, state.zoom, state.targetZoom)
        state.scrollY = MapNavigation.ZoomScroll(state.anchorY, state.scrollY, state.zoom, state.targetZoom)
        MapNavigation.ApplyZoom(state.targetZoom)
    end
    state.startCursorX, state.startCursorY = GetCursorPosition()
    state.startScrollX, state.startScrollY = state.scrollX, state.scrollY
    state.panning = true
    state.moved = false
    StartDriver()
end

--- Runs after WorldMapButton_OnUpdate, which moves the unit icons and the player arrow every frame.
function MapNavigation.OnButtonUpdate()
    if state.zoom == 1 then
        return
    end
    PlaceUnits(true)

    -- The player arrow is a child of WorldMapFrame, outside the zoom frame. Blizzard's offsets
    -- leave out the zoom, so move it again, and hide it when it is outside the viewport.
    local px, py = GetPlayerMapPosition("player")
    if px ~= 0 or py ~= 0 then
        local scale = WorldMapDetailFrame:GetScale() * state.zoom
        local x = px * WorldMapDetailFrame:GetWidth() * scale
        local y = py * WorldMapDetailFrame:GetHeight() * scale
        -- The client takes only a frame name here: a frame object raises an error.
        PositionWorldMapArrowFrame("CENTER", "WorldMapDetailFrame", "TOPLEFT", x, -y)
        if not InView(x - state.scrollX, y - state.scrollY, state.viewW, state.viewH) then
            ShowWorldMapArrowFrame(nil)
        end
    end

    -- WorldMapButton_OnUpdate checks IsMouseOver, which is also true over the zoomed parts that the
    -- viewport hides.
    if not viewport:IsMouseOver() then
        WorldMapHighlight:Hide()
        if not WorldMapFrame.poiHighlight then
            WorldMapFrameAreaLabel:SetText(nil)
        end
    end
end

--- Runs after WorldMapFrame_Update: reset the zoom on a new map, and place the landmarks.
function MapNavigation.OnMapUpdate()
    if not state.built then
        return
    end
    local continent, area, level = GetCurrentMapContinent(), GetCurrentMapAreaID(), GetCurrentMapDungeonLevel()
    if continent ~= state.mapContinent or area ~= state.mapArea or level ~= state.mapLevel then
        state.mapContinent, state.mapArea, state.mapLevel = continent, area, level
        ResetZoom()
    end
    if state.zoom ~= 1 then
        PlaceLandmarks()
    end
end

--- Runs after WorldMapFrame_DisplayQuestPOI, which places one quest POI button.
-- Blizzard shows the POIs in its own OnShow, before our OnShow hook builds the frame tree. So remember
-- the button also when the tree is not built yet.
function MapNavigation.OnQuestPOI(questFrame)
    local poi = questFrame.poiIcon
    if not poi then
        return
    end
    questPOIs[poi] = true
    if state.built and state.zoom ~= 1 then
        Place(poi)
        PlaceSwapButton()
    end
end

local placingDetail = false

-- Put the viewport where Blizzard put the detail frame, with the size of the scaled detail frame.
local function UpdateViewport()
    local scale = WorldMapDetailFrame:GetScale()
    state.viewW = WorldMapDetailFrame:GetWidth() * scale
    state.viewH = WorldMapDetailFrame:GetHeight() * scale
    local a = detailAnchor
    viewport:ClearAllPoints()
    viewport:SetPoint(a.point, a.relativeTo, a.relativePoint, a.x * scale, a.y * scale)
    viewport:SetWidth(state.viewW)
    viewport:SetHeight(state.viewH)
    zoomFrame:SetWidth(state.viewW)
    zoomFrame:SetHeight(state.viewH)
end

local function AnchorDetailFrame()
    placingDetail = true
    WorldMapDetailFrame:ClearAllPoints()
    WorldMapDetailFrame:SetPoint("TOPLEFT", zoomFrame, "TOPLEFT")
    placingDetail = false
end

-- Hook of WorldMapDetailFrame:SetPoint: Blizzard moved the map. Move the viewport there instead.
local function OnDetailSetPoint(_, ...)
    if placingDetail then
        return
    end
    local point, relativeTo, relativePoint, x, y = MapNavigation.NormalizePoint(...)
    if type(relativeTo) == "string" then
        relativeTo = _G[relativeTo]
    end
    detailAnchor.point, detailAnchor.relativeTo, detailAnchor.relativePoint = point, relativeTo or WorldMapFrame,
        relativePoint
    detailAnchor.x, detailAnchor.y = x, y
    UpdateViewport()
    AnchorDetailFrame()
end

-- Hook of WorldMapDetailFrame:SetScale: the layout changed.
local function OnDetailSetScale()
    UpdateViewport()
    ResetZoom()
end

local function OnButtonSetScale(_, scale)
    overlay:SetScale(scale)
end

local redirecting = false
local points = {}

-- Move the points of `region` that use WorldMapDetailFrame or WorldMapButton to the viewport.
-- At 1x the viewport has the same rect, so nothing moves on screen.
local function Redirect(region)
    if redirecting then
        return
    end
    local count = region:GetNumPoints()
    local found = false
    for i = 1, count do
        local point, relativeTo, relativePoint, x, y = region:GetPoint(i)
        if relativeTo == WorldMapDetailFrame or relativeTo == WorldMapButton then
            relativeTo = viewport
            found = true
        end
        local p = points[i] or {}
        points[i] = p
        p[1], p[2], p[3], p[4], p[5] = point, relativeTo, relativePoint, x, y
    end
    if not found then
        return
    end
    redirecting = true
    region:ClearAllPoints()
    for i = 1, count do
        local p = points[i]
        region:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
    redirecting = false
end

local skipRedirect

-- Redirect the children and regions of WorldMapFrame now, and every time something moves them.
local function RedirectDependents(...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if not skipRedirect[region] then
            Redirect(region)
            hooksecurefunc(region, "SetPoint", Redirect)
        end
    end
end

-- Runs after WorldMapFrame_ResetFrameLevels. A new frame level moves all descendants by the same
-- amount, so setting our frames would move the Blizzard map frames too. Set them back after.
local function FixFrameLevels()
    if not state.built then
        return
    end
    local detail, blob = WorldMapDetailFrame:GetFrameLevel(), WorldMapBlobFrame:GetFrameLevel()
    local button, poi = WorldMapButton:GetFrameLevel(), WorldMapPOIFrame:GetFrameLevel()
    local level = WorldMapFrame:GetFrameLevel()
    viewport:SetFrameLevel(level)
    scrollChild:SetFrameLevel(level)
    zoomFrame:SetFrameLevel(level)
    WorldMapDetailFrame:SetFrameLevel(detail)
    WorldMapBlobFrame:SetFrameLevel(blob)
    WorldMapButton:SetFrameLevel(button)
    WorldMapPOIFrame:SetFrameLevel(poi)
    overlay:SetFrameLevel(button + 1)
end

--- Build the frame tree. Runs once, the first time the map opens with map navigation on.
function MapNavigation.Build()
    if state.built or InCombatLockdown() then
        return
    end

    viewport = CreateFrame("ScrollFrame", nil, WorldMapFrame)
    scrollChild = CreateFrame("Frame", nil, viewport)
    viewport:SetScrollChild(scrollChild)
    zoomFrame = CreateFrame("Frame", nil, scrollChild)
    zoomFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT")
    overlay = CreateFrame("Frame", nil, WorldMapFrame)
    overlay:SetAllPoints(viewport)
    overlay:SetScale(WorldMapButton:GetScale())
    MapNavigation.viewport, MapNavigation.scrollChild = viewport, scrollChild
    MapNavigation.zoomFrame, MapNavigation.overlay = zoomFrame, overlay

    OnDetailSetPoint(WorldMapDetailFrame, WorldMapDetailFrame:GetPoint(1))
    WorldMapDetailFrame:SetParent(zoomFrame)
    WorldMapBlobFrame:SetParent(zoomFrame)
    WorldMapButton:SetParent(zoomFrame)
    WorldMapPOIFrame:SetParent(zoomFrame)

    -- The zone name label stays at the top of the viewport and never zooms.
    local point, _, relativePoint, x, y = WorldMapFrameAreaFrame:GetPoint(1)
    WorldMapFrameAreaFrame:SetParent(overlay)
    WorldMapFrameAreaFrame:ClearAllPoints()
    WorldMapFrameAreaFrame:SetPoint(point, overlay, relativePoint, x, y)

    -- The player arrow is placed by the client, relative to the detail frame. OnButtonUpdate handles it.
    skipRedirect = { [viewport] = true, [overlay] = true }
    if PlayerArrowFrame then
        skipRedirect[PlayerArrowFrame] = true
    end
    if PlayerArrowEffectFrame then
        skipRedirect[PlayerArrowEffectFrame] = true
    end
    RedirectDependents(WorldMapFrame:GetChildren())
    RedirectDependents(WorldMapFrame:GetRegions())

    hooksecurefunc(WorldMapDetailFrame, "SetPoint", OnDetailSetPoint)
    hooksecurefunc(WorldMapDetailFrame, "SetScale", OnDetailSetScale)
    hooksecurefunc(WorldMapButton, "SetScale", OnButtonSetScale)

    viewport:EnableMouseWheel(true)
    viewport:SetScript("OnMouseWheel", MapNavigation.OnWheel)
    -- WorldMapButton is above the viewport, so it may get the wheel first. It has no wheel script.
    WorldMapButton:EnableMouseWheel(true)
    WorldMapButton:HookScript("OnMouseWheel", MapNavigation.OnWheel)
    WorldMapButton:HookScript("OnMouseDown", MapNavigation.OnButtonDown)
    WorldMapButton:HookScript("OnUpdate", MapNavigation.OnButtonUpdate)

    units = { WorldMapPlayer, WorldMapFlag1, WorldMapFlag2, WorldMapCorpse, WorldMapDeathRelease, WorldMapPing }
    for i = 1, 4 do
        units[#units + 1] = _G["WorldMapParty" .. i]
    end
    for i = 1, 40 do
        units[#units + 1] = _G["WorldMapRaid" .. i]
    end

    state.built = true
    WorldMapFrame_ResetFrameLevels()
    state.mapContinent, state.mapArea, state.mapLevel = nil, nil, nil
    ResetZoom()
end

local function OnMapShow()
    if IsEnabled() then
        MapNavigation.Build()
    end
end

--- Save the `enabled` setting. Off resets the zoom; the frame tree stays, and at 1x it looks vanilla.
function MapNavigation.SetEnabled(enabled)
    ns.db.mapNav.enabled = enabled
    if not enabled then
        ResetZoom()
    elseif WorldMapFrame:IsShown() then
        MapNavigation.Build()
    end
end

--- Save the maximum zoom and clamp both the rendered zoom and an animation in progress.
function MapNavigation.SetMaxZoom(maxZoom)
    ns.db.mapNav.maxZoom = maxZoom
    if not state.built then return end
    state.targetZoom = math.min(state.targetZoom, maxZoom)
    if state.zoom > maxZoom then
        state.scrollX = MapNavigation.ZoomScroll(state.anchorX, state.scrollX, state.zoom, maxZoom)
        state.scrollY = MapNavigation.ZoomScroll(state.anchorY, state.scrollY, state.zoom, maxZoom)
        MapNavigation.ApplyZoom(maxZoom)
    end
end

--- Save the world map wheel multiplier for the next notch.
function MapNavigation.SetStep(step)
    ns.db.mapNav.step = step
end

--- Return the current zoom level (1 is no zoom).
function MapNavigation.GetZoom()
    return state.zoom
end

-- Quest blobs in combat, like Mapster: WorldMapBlobFrame may be protected, and a protected frame
-- makes its parents protected in combat. Then every zoom or pan call on our frames would be blocked.
-- So take the blob out of our frames before combat starts, and put it back after.
local blobWasShown, blobPendingScale
local function BlobHide()
    blobWasShown = false
end
local function BlobShow()
    blobWasShown = true
end
local function BlobSetScale(_, scale)
    blobPendingScale = scale
end

function MapNavigation.OnCombatStart()
    if not DETACH_BLOB_IN_COMBAT or not state.built or state.blobDetached then
        return
    end
    blobWasShown = WorldMapBlobFrame:IsShown()
    blobPendingScale = nil
    WorldMapBlobFrame:SetParent(nil)
    WorldMapBlobFrame:ClearAllPoints()
    -- Off screen, so Blizzard's hit math still has a rect.
    WorldMapBlobFrame:SetPoint("TOP", UIParent, "BOTTOM")
    WorldMapBlobFrame:Hide()
    WorldMapBlobFrame.Hide = BlobHide
    WorldMapBlobFrame.Show = BlobShow
    WorldMapBlobFrame.SetScale = BlobSetScale
    state.blobDetached = true
end

-- The scroll frame draws the frames in it in the order they joined it, not by frame level. The blob
-- joins last when it comes back, so it would cover the POI icons. Take the frame out through
-- WorldMapFrame, which keeps it shown, and put it back with its level so it joins after the blob.
local function Rejoin(frame)
    local level = frame:GetFrameLevel()
    frame:SetParent(WorldMapFrame)
    frame:SetParent(zoomFrame)
    frame:SetFrameLevel(level)
end

-- One frame after the blob is back, draw the selected quest's blob with its highlight again.
local function OnBlobRestore(self)
    self:SetScript("OnUpdate", nil)
    local selected = SelectedBlobQuest()
    if selected then
        WorldMapBlobFrame:DrawQuestBlob(selected.questId, true)
    end
end

function MapNavigation.OnCombatEnd()
    if not state.blobDetached then
        return
    end
    WorldMapBlobFrame.Hide = nil
    WorldMapBlobFrame.Show = nil
    WorldMapBlobFrame.SetScale = nil
    state.blobDetached = false
    WorldMapBlobFrame:SetParent(zoomFrame)
    WorldMapBlobFrame:ClearAllPoints()
    WorldMapBlobFrame:SetPoint("TOPLEFT", WorldMapDetailFrame)
    WorldMapBlobFrame:SetFrameLevel(WorldMapDetailFrame:GetFrameLevel() + 1)
    Rejoin(WorldMapButton)
    Rejoin(WorldMapPOIFrame)
    if blobWasShown then
        WorldMapBlobFrame:Show()
        blobRestorer = blobRestorer or CreateFrame("Frame")
        blobRestorer:SetScript("OnUpdate", OnBlobRestore)
    end
    if blobPendingScale then
        WorldMapBlobFrame:SetScale(blobPendingScale)
        blobPendingScale = nil
    end
    ResetBlobHits()
    -- Blizzard keeps the selection in WORLDMAP_SETTINGS. Mapster's combat code reads
    -- WorldMapQuestScrollChildFrame.selected, which Blizzard never sets.
    local selected = WORLDMAP_SETTINGS.selectedQuest
    if selected then
        WorldMapBlobFrame:DrawQuestBlob(selected.questId, false)
    end
end

-- PLAYER_REGEN_DISABLED fires before the combat lockdown starts.
ns.Core.RegisterEvent("PLAYER_REGEN_DISABLED", MapNavigation.OnCombatStart)
ns.Core.RegisterEvent("PLAYER_REGEN_ENABLED", MapNavigation.OnCombatEnd)

-- FrameXML loads before add-ons. These hooks do nothing until the frame tree is built.
hooksecurefunc("WorldMapFrame_Update", MapNavigation.OnMapUpdate)
hooksecurefunc("WorldMapFrame_DisplayQuestPOI", MapNavigation.OnQuestPOI)
hooksecurefunc("WorldMapFrame_ResetFrameLevels", FixFrameLevels)
WorldMapFrame:HookScript("OnShow", OnMapShow)
WorldMapFrame:HookScript("OnHide", ResetZoom)
