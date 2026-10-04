-- Mouse wheel zoom on the minimap. A wheel notch takes the same path as the Blizzard + and - buttons,
-- so the buttons disable at the limits and play their sound.
local _, ns = ...

local MinimapZoom = {}
ns.MinimapZoom = MinimapZoom

--- Return 1 to zoom in (wheel up), -1 to zoom out (wheel down), or 0 for a delta of 0.
function MinimapZoom.GetDirection(delta)
    if delta > 0 then
        return 1
    elseif delta < 0 then
        return -1
    end
    return 0
end

--- Handle one wheel notch. Minimap_ZoomIn and Minimap_ZoomOut click MinimapZoomIn and MinimapZoomOut:
-- a disabled button ignores the click, so a notch at a limit does nothing.
function MinimapZoom.OnMouseWheel(_, delta)
    local direction = MinimapZoom.GetDirection(delta)
    if direction > 0 then
        Minimap_ZoomIn()
    elseif direction < 0 then
        Minimap_ZoomOut()
    end
end

-- Set our wheel handler, unless another add-on already has one on the minimap.
local function Install()
    local current = Minimap:GetScript("OnMouseWheel")
    if current and current ~= MinimapZoom.OnMouseWheel then
        ns.Log.Debug("minimap wheel already used by another add-on; Atlasium minimap wheel zoom skipped")
        return
    end
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", MinimapZoom.OnMouseWheel)
end

-- Remove our wheel handler. A handler of another add-on stays.
local function Uninstall()
    if Minimap:GetScript("OnMouseWheel") == MinimapZoom.OnMouseWheel then
        Minimap:SetScript("OnMouseWheel", nil)
        Minimap:EnableMouseWheel(false)
    end
end

--- Save the `enabled` setting, then set or remove the wheel handler.
function MinimapZoom.SetEnabled(enabled)
    ns.db.minimapZoom.enabled = enabled
    if enabled then
        Install()
    else
        Uninstall()
    end
end

-- Wait for PLAYER_LOGIN: the saved settings exist, and add-ons that load before us have set their
-- minimap scripts.
ns.Core.RegisterEvent("PLAYER_LOGIN", function()
    if ns.db.minimapZoom.enabled then
        Install()
    end
end)
