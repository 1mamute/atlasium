local ADDON_NAME, ns = ...

ns.name = ADDON_NAME

ns.defaults = {
    debug = false,
    log = {}, -- error and debug messages, newest last (see Log.lua)
    minimap = {
        hide = false, -- true hides the button
        angle = 225, -- position on the minimap edge, in degrees (0 is right, 90 is top)
    },
    minimapZoom = {
        enabled = true, -- the mouse wheel over the minimap changes its zoom level
    },
    fogClear = {
        enabled = true,
        color = { r = 0.6, g = 0.6, b = 0.6, a = 1 }, -- tint of unexplored areas
    },
    mapNav = {
        enabled = true,
        maxZoom = 4, -- largest zoom level
        step = 1.25, -- zoom level multiplier per mouse wheel notch
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

local function OnOff(enabled)
    return enabled and "on" or "off"
end

-- The submenus of the slash command, in help order. Each subcommand has a `get` that returns its
-- state and a `set(enabled)` that changes it.
local SUBMENUS = {
    {
        name = "minimap",
        {
            name = "button",
            get = function() return not ns.db.minimap.hide end,
            set = function(enabled) ns.MinimapButton.SetShown(enabled) end,
        },
        {
            name = "zoom",
            get = function() return ns.db.minimapZoom.enabled end,
            set = function(enabled) ns.MinimapZoom.SetEnabled(enabled) end,
        },
    },
    {
        name = "worldmap",
        {
            name = "zoom",
            get = function() return ns.db.mapNav.enabled end,
            set = function(enabled) ns.MapNavigation.SetEnabled(enabled) end,
        },
        {
            name = "fog",
            get = function() return ns.db.fogClear.enabled end,
            set = function(enabled) ns.FogClear.SetEnabled(enabled) end,
        },
    },
}

local function FindByName(list, name)
    for _, entry in ipairs(list) do
        if entry.name == name then
            return entry
        end
    end
end

--- Return the help line, for example "commands: /atlasium debug | version | minimap button on/off".
function Core.GetHelp()
    local parts = { "debug", "version" }
    for _, submenu in ipairs(SUBMENUS) do
        for _, sub in ipairs(submenu) do
            table.insert(parts, submenu.name .. " " .. sub.name .. " on/off")
        end
    end
    return "commands: /atlasium " .. table.concat(parts, " | ")
end

-- `/atlasium <submenu>` lists the subcommands and their state. `/atlasium <submenu> <sub> on | off`
-- changes one; without on or off it shows the state.
local function HandleSubmenu(submenu, rest)
    local subName, arg = ns.Util.SplitCommand(rest)
    if subName == "" then
        local states = {}
        for _, sub in ipairs(submenu) do
            table.insert(states, sub.name .. " " .. OnOff(sub.get()))
        end
        Print(submenu.name .. ": " .. table.concat(states, ", "))
        return
    end
    local sub = FindByName(submenu, subName)
    if not sub then
        Print(Core.GetHelp())
        return
    end
    arg = arg:lower()
    if arg == "on" or arg == "off" then
        sub.set(arg == "on")
    end
    local command = submenu.name .. " " .. sub.name
    Print(command .. " " .. OnOff(sub.get()) .. " (/atlasium " .. command .. " on | off)")
end

function Core.HandleSlash(msg)
    local cmd, rest = ns.Util.SplitCommand(msg)
    local submenu = FindByName(SUBMENUS, cmd)
    if submenu then
        HandleSubmenu(submenu, rest)
    elseif cmd == "debug" then
        ns.db.debug = not ns.db.debug
        ns.Dev.Update()
        Print("debug " .. OnOff(ns.db.debug))
    elseif cmd == "version" then
        Print("v" .. (GetAddOnMetadata(ADDON_NAME, "Version") or "?"))
    else
        Print(Core.GetHelp())
    end
end

SLASH_ATLASIUM1 = "/atlasium"
SlashCmdList["ATLASIUM"] = Core.HandleSlash
