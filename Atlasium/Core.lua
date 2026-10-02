local ADDON_NAME, ns = ...

ns.name = ADDON_NAME

ns.defaults = {
    debug = false,
}

local Core = {}
ns.Core = Core

local frame = CreateFrame("Frame")
local handlers = {}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffAtlasium|r: " .. msg)
end
Core.Print = Print

--- Register `fn(...)` to be called when `event` fires.
function Core.RegisterEvent(event, fn)
    handlers[event] = fn
    frame:RegisterEvent(event)
end

function Core.OnEvent(_, event, ...)
    local handler = handlers[event]
    if handler then
        handler(...)
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
    local cmd = ns.Util.SplitCommand(msg)
    if cmd == "debug" then
        ns.db.debug = not ns.db.debug
        Print("debug " .. (ns.db.debug and "on" or "off"))
    elseif cmd == "version" then
        Print("v" .. (GetAddOnMetadata(ADDON_NAME, "Version") or "?"))
    else
        Print("commands: /atlasium debug | version")
    end
end

SLASH_ATLASIUM1 = "/atlasium"
SlashCmdList["ATLASIUM"] = Core.HandleSlash
