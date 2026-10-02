-- The button on the minimap edge. It works like Questie's 3.3.5 button (LibDBIcon-1.0), without the library.
local ADDON_NAME, ns = ...

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local cos, sin, rad, deg, atan2 = math.cos, math.sin, math.rad, math.deg, math.atan2
local sqrt, max, min = math.sqrt, math.max, math.min

-- Round quarters for each minimap shape, from the shape name: CORNER-<corner> is round only at that
-- corner, SIDE-<side> on that half, TRICORNER-<corner> everywhere except the opposite corner.
-- Do not check this against Questie's 3.3.5 LibDBIcon (Rev 15): its table swaps several shapes.
local ROUND_QUARTERS = {
    ROUND = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true },
    SQUARE = {},
    ["CORNER-TOPLEFT"] = { TOPLEFT = true },
    ["CORNER-TOPRIGHT"] = { TOPRIGHT = true },
    ["CORNER-BOTTOMLEFT"] = { BOTTOMLEFT = true },
    ["CORNER-BOTTOMRIGHT"] = { BOTTOMRIGHT = true },
    ["SIDE-LEFT"] = { TOPLEFT = true, BOTTOMLEFT = true },
    ["SIDE-RIGHT"] = { TOPRIGHT = true, BOTTOMRIGHT = true },
    ["SIDE-TOP"] = { TOPLEFT = true, TOPRIGHT = true },
    ["SIDE-BOTTOM"] = { BOTTOMLEFT = true, BOTTOMRIGHT = true },
    ["TRICORNER-TOPLEFT"] = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true },
    ["TRICORNER-TOPRIGHT"] = { TOPLEFT = true, TOPRIGHT = true, BOTTOMRIGHT = true },
    ["TRICORNER-BOTTOMLEFT"] = { TOPLEFT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true },
    ["TRICORNER-BOTTOMRIGHT"] = { TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true },
}

-- Distance from the minimap edge to the button center, in pixels.
local EDGE_OFFSET = 10

local TOOLTIP_LINES = {
    "|cffa6a6a6Left-click|r: Open or close the world map",
    "|cffa6a6a6Drag|r: Move this button",
    "|cffa6a6a6/atlasium minimap|r: Hide this button",
}

--- Return the x, y offset of the button center from the minimap center.
-- `angle` is in degrees (0 is right, 90 is top). An unknown or nil `shape` counts as "ROUND".
function MinimapButton.GetOffset(angle, width, height, shape)
    local x, y = cos(rad(angle)), sin(rad(angle))
    local quarter
    if y > 0 then
        quarter = x < 0 and "TOPLEFT" or "TOPRIGHT"
    else
        quarter = x < 0 and "BOTTOMLEFT" or "BOTTOMRIGHT"
    end
    local radiusX, radiusY = width / 2 + EDGE_OFFSET, height / 2 + EDGE_OFFSET
    local round = ROUND_QUARTERS[shape] or ROUND_QUARTERS.ROUND
    if round[quarter] then
        return x * radiusX, y * radiusY
    end
    -- Square quarter: move out toward the corner (10 pixels short of it), then keep each axis on the edge.
    local diagonalX = sqrt(2 * radiusX * radiusX) - 10
    local diagonalY = sqrt(2 * radiusY * radiusY) - 10
    return max(-radiusX, min(x * diagonalX, radiusX)), max(-radiusY, min(y * diagonalY, radiusY))
end

--- Return the angle from the minimap center to the cursor, in degrees from 0 to 360.
function MinimapButton.AngleFromCursor(cursorX, cursorY, centerX, centerY)
    return deg(atan2(cursorY - centerY, cursorX - centerX)) % 360
end

--- Return the tooltip point and the button point that open the tooltip on the side of the button
-- that faces the center of the screen.
function MinimapButton.GetTooltipAnchor(x, y, screenWidth, screenHeight)
    local horizontal = ""
    if x > screenWidth * 2 / 3 then
        horizontal = "RIGHT"
    elseif x < screenWidth / 3 then
        horizontal = "LEFT"
    end
    if y > screenHeight / 2 then
        return "TOP" .. horizontal, "BOTTOM" .. horizontal
    end
    return "BOTTOM" .. horizontal, "TOP" .. horizontal
end

local icon
local isMoving = false

--- Move the button to the saved angle on the minimap edge.
function MinimapButton.UpdatePosition()
    local shape = GetMinimapShape and GetMinimapShape()
    local x, y = MinimapButton.GetOffset(ns.db.minimap.angle, Minimap:GetWidth(), Minimap:GetHeight(), shape)
    MinimapButton.frame:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function UpdateVisibility()
    if ns.db.minimap.hide then
        MinimapButton.frame:Hide()
    else
        MinimapButton.frame:Show()
    end
end

--- Switch the saved `hide` setting, then show or hide the button.
function MinimapButton.Toggle()
    ns.db.minimap.hide = not ns.db.minimap.hide
    UpdateVisibility()
end

--- Handle a click. Left-click opens or closes the world map, like the M key.
function MinimapButton.OnClick(_, mouseButton)
    if mouseButton == "LeftButton" then
        ToggleFrame(WorldMapFrame)
    end
end

-- Full icon while pressed; cut off the icon border otherwise.
local function PressIcon()
    icon:SetTexCoord(0, 1, 0, 1)
end

local function ReleaseIcon()
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
end

local function OnUpdate()
    local scale = Minimap:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    local centerX, centerY = Minimap:GetCenter()
    ns.db.minimap.angle = MinimapButton.AngleFromCursor(cursorX / scale, cursorY / scale, centerX, centerY)
    MinimapButton.UpdatePosition()
end

local function OnDragStart(self)
    self:LockHighlight()
    PressIcon()
    isMoving = true
    GameTooltip:Hide()
    self:SetScript("OnUpdate", OnUpdate)
end

local function OnDragStop(self)
    self:SetScript("OnUpdate", nil)
    ReleaseIcon()
    self:UnlockHighlight()
    isMoving = false
end

local function OnEnter(self)
    if isMoving then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    local x, y = self:GetCenter()
    local point, relativePoint = MinimapButton.GetTooltipAnchor(x, y, UIParent:GetWidth(), UIParent:GetHeight())
    GameTooltip:SetPoint(point, self, relativePoint)
    GameTooltip:AddLine(ADDON_NAME .. " " .. (GetAddOnMetadata(ADDON_NAME, "Version") or "?"), 1, 1, 1)
    for _, line in ipairs(TOOLTIP_LINES) do
        GameTooltip:AddLine(line)
    end
    GameTooltip:Show()
end

local function OnLeave()
    GameTooltip:Hide()
end

--- Build the button. Runs one time, on PLAYER_LOGIN.
function MinimapButton.Create()
    -- The name makes a global. Minimap button collectors such as MinimapButtonBag find buttons by
    -- their name (see "Structure" in docs/contributing/conventions.md).
    local button = CreateFrame("Button", "AtlasiumMinimapButton", Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetWidth(31)
    button:SetHeight(31)
    button:SetFrameLevel(8)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetWidth(53)
    border:SetHeight(53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    icon:SetPoint("TOPLEFT", 7, -5)
    ReleaseIcon()

    button:SetScript("OnClick", MinimapButton.OnClick)
    button:SetScript("OnMouseDown", PressIcon)
    button:SetScript("OnMouseUp", ReleaseIcon)
    button:SetScript("OnDragStart", OnDragStart)
    button:SetScript("OnDragStop", OnDragStop)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", OnLeave)

    MinimapButton.frame = button
end

-- Wait for PLAYER_LOGIN: the saved settings exist, and add-ons that define GetMinimapShape have loaded.
ns.Core.RegisterEvent("PLAYER_LOGIN", function()
    MinimapButton.Create()
    MinimapButton.UpdatePosition()
    UpdateVisibility()
end)
