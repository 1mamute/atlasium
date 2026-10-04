local ADDON_NAME, ns = ...

ns.name = ADDON_NAME

ns.defaults = {
    language = "enUS", -- Atlasium text only; the client language stays unchanged
    debug = false,
    log = {}, -- error and debug messages, newest last (see Log.lua)
    minimap = {
        hide = false, -- true hides the button
        angle = 225, -- position on the minimap edge, in degrees (0 is right, 90 is top)
    },
    minimapZoom = {
        enabled = true, -- the mouse wheel over the minimap changes its zoom level
    },
    minimapTiles = {
        enabled = true, -- Atlasium draws the minimap ground at Blizzard zoom levels (MinimapTiles.lua)
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
    return ns.Localization.Get(enabled and "on" or "off")
end

-- The submenus of the slash command, in help order. Each subcommand has a `get` that returns its
-- state and a `set(value)` that changes it. The value is on or off. A `debugOnly` subcommand
-- works and shows in the help only in debug mode.
local SUBMENUS = {
    {
        name = "minimap",
        {
            name = "button",
            get = function() return not ns.db.minimap.hide end,
            set = function(enabled) ns.Settings.Set("button", enabled) end,
        },
        {
            name = "zoom",
            get = function() return ns.db.minimapZoom.enabled end,
            set = function(enabled) ns.Settings.Set("minimapZoom", enabled) end,
        },
        {
            name = "tiles",
            get = function() return ns.db.minimapTiles.enabled end,
            set = function(enabled) ns.Settings.Set("tiles", enabled) end,
        },
        {
            name = "align",
            debugOnly = true,
            get = function() return ns.MinimapTiles.align end,
            set = function(enabled) ns.MinimapTiles.SetAlign(enabled) end,
        },
    },
    {
        name = "worldmap",
        {
            name = "zoom",
            get = function() return ns.db.mapNav.enabled end,
            set = function(enabled) ns.Settings.Set("mapNav", enabled) end,
        },
        {
            name = "fog",
            get = function() return ns.db.fogClear.enabled end,
            set = function(enabled) ns.Settings.Set("fog", enabled) end,
        },
    },
}

-- A debugOnly subcommand counts only in debug mode.
local function IsAvailable(entry)
    return not entry.debugOnly or ns.db.debug
end

local function FindByName(list, name)
    for _, entry in ipairs(list) do
        if entry.name == name and IsAvailable(entry) then
            return entry
        end
    end
end

-- The state of a subcommand, "on" or "off".
local function FormatState(sub)
    return OnOff(sub.get())
end

-- The values a subcommand takes, "on/off" or "on | off".
local function FormatValues(separator)
    return "on" .. separator .. "off"
end

--- Return the help line, for example "commands: /atlasium debug | version | minimap button on/off".
function Core.GetHelp()
    local parts = { "settings", "help", "debug", "version" }
    for _, submenu in ipairs(SUBMENUS) do
        for _, sub in ipairs(submenu) do
            if IsAvailable(sub) then
                table.insert(parts, submenu.name .. " " .. sub.name .. " " .. FormatValues("/"))
            end
        end
    end
    return ns.Localization.Get("commands", table.concat(parts, " | "))
end

-- `/atlasium <submenu>` lists the subcommands and their state. `/atlasium <submenu> <sub> on | off`
-- changes one; without a value it shows the state.
local function HandleSubmenu(submenu, rest)
    local subName, arg = ns.Util.SplitCommand(rest)
    if subName == "" then
        local states = {}
        for _, sub in ipairs(submenu) do
            if IsAvailable(sub) then
                table.insert(states, sub.name .. " " .. FormatState(sub))
            end
        end
        Print(ns.Localization.Get("submenu", submenu.name, table.concat(states, ", ")))
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
    Print(ns.Localization.Get("state", command, FormatState(sub), command, FormatValues(" | ")))
end

function Core.HandleSlash(msg)
    local cmd, rest = ns.Util.SplitCommand(msg)
    local submenu = FindByName(SUBMENUS, cmd)
    if cmd == "" or cmd == "settings" then
        ns.SettingsUI.Show()
    elseif submenu then
        HandleSubmenu(submenu, rest)
    elseif cmd == "debug" then
        ns.Settings.Set("debug", not ns.db.debug)
        Print(ns.Localization.Get("debugState", OnOff(ns.db.debug)))
    elseif cmd == "version" then
        Print(ns.Localization.Get("version", GetAddOnMetadata(ADDON_NAME, "Version") or "?"))
    else
        Print(Core.GetHelp())
    end
end

SLASH_ATLASIUM1 = "/atlasium"
SlashCmdList["ATLASIUM"] = Core.HandleSlash
