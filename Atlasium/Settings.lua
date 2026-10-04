local ADDON_NAME, ns = ...

local Settings = { name = ADDON_NAME }
ns.Settings = Settings

-- The GUI and slash commands use these same feature setters. They are resolved after login.
local entries = {
    language = { path = { "language" }, set = function(v) ns.Localization.SetLanguage(v) end },
    button = { path = { "minimap", "hide" }, inverted = true,
        set = function(v) ns.MinimapButton.SetShown(v) end },
    angle = { path = { "minimap", "angle" }, min = 0, max = 359, step = 1,
        set = function(v) ns.MinimapButton.SetAngle(v) end },
    minimapZoom = { path = { "minimapZoom", "enabled" }, set = function(v) ns.MinimapZoom.SetEnabled(v) end },
    tiles = { path = { "minimapTiles", "enabled" }, set = function(v) ns.MinimapTiles.SetEnabled(v) end },
    fog = { path = { "fogClear", "enabled" }, set = function(v) ns.FogClear.SetEnabled(v) end },
    mapNav = { path = { "mapNav", "enabled" }, set = function(v) ns.MapNavigation.SetEnabled(v) end },
    maxZoom = { path = { "mapNav", "maxZoom" }, min = 1, max = 16, step = 0.25,
        set = function(v) ns.MapNavigation.SetMaxZoom(v) end },
    step = { path = { "mapNav", "step" }, min = 1.05, max = 2, step = 0.05,
        set = function(v) ns.MapNavigation.SetStep(v) end },
    color = { path = { "fogClear", "color" }, set = function(v) ns.FogClear.SetColor(v) end },
    debug = { path = { "debug" }, set = function(v) ns.Dev.SetEnabled(v) end },
}
Settings.entries = entries

local function Read(root, entry)
    local value = root
    for _, key in ipairs(entry.path) do value = value[key] end
    if entry.inverted then return not value end
    return value
end

local function InRange(value, low, high)
    return type(value) == "number" and value == value and value >= low and value <= high
end

--- Return the current value of a known setting.
function Settings.Get(id)
    local entry = entries[id]
    if not entry or not ns.db then return nil end
    return Read(ns.db, entry)
end

--- Validate and apply one setting. Invalid values leave saved and live state unchanged.
function Settings.Set(id, value)
    local entry = entries[id]
    local valid = entry and ns.db
    if valid then
        if id == "language" then
            valid = value == "enUS" or value == "ptBR"
        elseif id == "color" then
            valid = type(value) == "table"
            for _, component in ipairs({ "r", "g", "b", "a" }) do
                valid = valid and InRange(value[component], 0, 1)
            end
        elseif entry.min then
            valid = InRange(value, entry.min, entry.max)
        else
            valid = type(value) == "boolean"
        end
    end
    if not valid then return false, ns.Localization.Get("invalid") end
    entry.set(value)
    if id ~= "language" and ns.SettingsUI then ns.SettingsUI.Refresh() end
    return true
end

--- Restore user preferences through their setters; keep saved logs and unrelated saved data.
function Settings.ResetDefaults()
    for _, id in ipairs({ "language", "button", "angle", "minimapZoom", "tiles", "fog", "mapNav",
        "maxZoom", "step", "color", "debug" }) do
        Settings.Set(id, Read(ns.defaults, entries[id]))
    end
end
