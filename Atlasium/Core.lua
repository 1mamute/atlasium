local ADDON_NAME, ns = ...

ns.name = ADDON_NAME

ns.defaults = {
    debug = false,
    minimap = {
        hide = false, -- true hides the button
        angle = 225, -- position on the minimap edge, in degrees (0 is right, 90 is top)
    },
    fogClear = {
        enabled = true,
        color = { r = 0.6, g = 0.6, b = 0.6, a = 1 }, -- tint of unexplored areas
    },
    mapNav = {
        enabled = true,
        maxZoom = 4, -- largest zoom factor
        step = 1.25, -- zoom factor per mouse wheel notch
    },
}

local Core = {}
ns.Core = Core

local frame = CreateFrame("Frame")
local handlers = {}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffAtlasium|r: " .. msg)
end
Core.Print = Print

--- Register `fn(...)` to be called when `event` fires. An event can have several handlers: they run
-- in the order of registration.
function Core.RegisterEvent(event, fn)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
    end
    table.insert(list, fn)
    frame:RegisterEvent(event)
end

function Core.OnEvent(_, event, ...)
    local list = handlers[event]
    if list then
        for _, handler in ipairs(list) do
            handler(...)
        end
    end
end
frame:SetScript("OnEvent", Core.OnEvent)

Core.RegisterEvent("ADDON_LOADED", function(name)
    if name ~= ADDON_NAME then
        return
    end
    AtlasiumDB = ns.Util.CopyDefaults(ns.defaults, AtlasiumDB)
    ns.db = AtlasiumDB
end)

function Core.HandleSlash(msg)
    local cmd, rest = ns.Util.SplitCommand(msg)
    if cmd == "debug" then
        ns.db.debug = not ns.db.debug
        ns.Dev.Update()
        Print("debug " .. (ns.db.debug and "on" or "off"))
    elseif cmd == "fog" then
        local arg = rest:lower()
        if arg == "on" or arg == "off" then
            ns.FogClear.SetEnabled(arg == "on")
        end
        Print("fog clearing " .. (ns.db.fogClear.enabled and "on" or "off") .. " (/atlasium fog on | off)")
    elseif cmd == "minimap" then
        ns.MinimapButton.Toggle()
        Print("minimap button " .. (ns.db.minimap.hide and "hidden" or "shown"))
    elseif cmd == "zoom" then
        local arg = rest:lower()
        if arg == "on" or arg == "off" then
            ns.MapNavigation.SetEnabled(arg == "on")
        end
        Print("map zoom " .. (ns.db.mapNav.enabled and "on" or "off") .. " (/atlasium zoom on | off)")
    elseif cmd == "version" then
        Print("v" .. (GetAddOnMetadata(ADDON_NAME, "Version") or "?"))
    else
        Print("commands: /atlasium debug | fog on | fog off | minimap | version | zoom on | zoom off")
    end
end

SLASH_ATLASIUM1 = "/atlasium"
SlashCmdList["ATLASIUM"] = Core.HandleSlash
