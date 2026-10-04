-- Developer aid for in-game checks (see docs/contributing/in-game-testing.md). While debug mode is on
-- (/atlasium debug), a solid square in the top-left corner of the screen shows the state of the world
-- map: green when it is open, red when it is closed. Fixed override keys open and close the map and take
-- a screenshot, even when a player rebinds M or Print Screen. tools/wow-dev.ps1 reads the square from a
-- screenshot and presses the keys, so it can drive the client without the chat box.
local _, ns = ...

local Dev = {}
ns.Dev = Dev

-- Edge of the marker in screen pixels. It must stay in sync with MarkerPixels in tools/wow-dev.ps1.
Dev.MARKER_PIXELS = 24

Dev.COLOR_OPEN = { 0, 1, 0 }
Dev.COLOR_CLOSED = { 1, 0, 0 }

-- Numpad keys have no default binding in 3.3.5a, and the client has no F13 to F15 on Windows (the
-- names exist only as Mac aliases). They are operator keys, so they do not depend on NumLock.
-- Keep the key names in sync with tools/wow-dev.ps1.
Dev.BINDINGS = {
    { key = "NUMPADMULTIPLY", command = "TOGGLEWORLDMAP" },
    { key = "NUMPADMINUS", command = "SCREENSHOT" },
}

local owner = CreateFrame("Frame") -- owns the override bindings, so it is never hidden
local marker
local bindingsOn = false -- whether the override bindings are set
local bindingsPending = false -- a binding change waits for the end of combat

--- The marker colour as r, g, b for an open or closed map.
function Dev.GetMarkerColor(mapOpen)
    local c = mapOpen and Dev.COLOR_OPEN or Dev.COLOR_CLOSED
    return c[1], c[2], c[3]
end

--- The marker edge in UI units at `effectiveScale`. A UI unit at scale 1 is screen height / 768 pixels,
-- so the square covers at least MARKER_PIXELS pixels on screens 768 pixels high or more.
function Dev.GetMarkerSize(effectiveScale)
    if not effectiveScale or effectiveScale <= 0 then
        effectiveScale = 1
    end
    return Dev.MARKER_PIXELS / effectiveScale
end

--- The binding command that `key` runs, or nil.
function Dev.GetCommand(key)
    for _, binding in ipairs(Dev.BINDINGS) do
        if binding.key == key then
            return binding.command
        end
    end
end

function Dev.IsActive()
    return ns.db ~= nil and ns.db.debug == true
end

local function GetMarker()
    if not marker then
        -- No parent: the fullscreen map hides UIParent, and so would hide the marker.
        marker = CreateFrame("Frame", nil, nil)
        marker:SetFrameStrata("TOOLTIP")
        marker:SetPoint("TOPLEFT", 0, 0)
        marker.texture = marker:CreateTexture(nil, "OVERLAY")
        marker.texture:SetAllPoints(marker)
    end
    return marker
end

-- Sets the override bindings while debug mode is on, and clears them when it is off. The client
-- refuses binding changes in combat, so a change waits for PLAYER_REGEN_ENABLED.
local function SyncBindings(active)
    if bindingsOn == active then
        bindingsPending = false
        return
    end
    if InCombatLockdown() then
        bindingsPending = true
        return
    end
    ClearOverrideBindings(owner)
    if active then
        for _, binding in ipairs(Dev.BINDINGS) do
            SetOverrideBinding(owner, false, binding.key, binding.command)
        end
    end
    bindingsOn = active
    bindingsPending = false
end

--- Bring the marker and the bindings in line with debug mode. `mapOpen` is optional: the map hooks
-- pass it, and without it the function asks WorldMapFrame.
function Dev.Update(mapOpen)
    local active = Dev.IsActive()
    if active then
        if mapOpen == nil then
            mapOpen = WorldMapFrame:IsShown() and true or false
        end
        local m = GetMarker()
        local size = Dev.GetMarkerSize(m:GetEffectiveScale())
        m:SetWidth(size)
        m:SetHeight(size)
        m.texture:SetTexture(Dev.GetMarkerColor(mapOpen))
        m:Show()
    elseif marker then
        marker:Hide()
    end
    SyncBindings(active)
end

--- OnKeyDown of the world map. The map frame has the keyboard while it is open, so it swallows the
-- override keys and runs only the bindings that GetBindingFromClick returns. If the client does not
-- count the override binding there, run the command here. Runs after the Blizzard handler.
function Dev.OnMapKeyDown(_, key)
    if not Dev.IsActive() then
        return
    end
    local command = Dev.GetCommand(key)
    if command and GetBindingFromClick(key) ~= command then
        RunBinding(command)
    end
end

function Dev.OnCombatEnd()
    if bindingsPending then
        SyncBindings(Dev.IsActive())
    end
end

-- Saved variables are ready on PLAYER_LOGIN.
ns.Core.RegisterEvent("PLAYER_LOGIN", function() Dev.Update() end)
ns.Core.RegisterEvent("PLAYER_REGEN_ENABLED", Dev.OnCombatEnd)

-- FrameXML loads before add-ons, so WorldMapFrame exists now.
WorldMapFrame:HookScript("OnShow", function() Dev.Update(true) end)
WorldMapFrame:HookScript("OnHide", function() Dev.Update(false) end)
WorldMapFrame:HookScript("OnKeyDown", Dev.OnMapKeyDown)
