std = "lua51"
max_line_length = 120
exclude_files = { ".luarocks", "lua_modules" }

-- Globals the add-on owns (SavedVariables, slash command registration).
globals = {
    "AtlasiumDB",
    "SLASH_ATLASIUM1",
    "SlashCmdList",
}

-- WoW 3.3.5a API in use. Add entries as you use more of the API.
read_globals = {
    "CreateFrame",
    "DEFAULT_CHAT_FRAME",
    "GameTooltip",
    "GetAddOnMetadata",
    "GetCursorPosition",
    "GetMinimapShape",
    "Minimap",
    "ToggleFrame",
    "UIParent",
    "WorldMapFrame",
}

-- Specs install stubs for WoW globals, so they need write access.
files["tests/"] = {
    std = "+busted",
    globals = {
        "CreateFrame",
        "DEFAULT_CHAT_FRAME",
        "GameTooltip",
        "GetAddOnMetadata",
        "GetCursorPosition",
        "GetMinimapShape",
        "Minimap",
        "ToggleFrame",
        "UIParent",
        "WorldMapFrame",
    },
}
