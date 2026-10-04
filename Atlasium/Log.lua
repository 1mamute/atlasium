-- Error and debug messages. Each message goes to chat and to AtlasiumDB.log, which keeps the newest
-- entries. Errors are always written; debug messages only while debug mode is on (/atlasium debug).
-- Use Core.Print for normal replies to the player.
local _, ns = ...

local Log = {}
ns.Log = Log

-- Largest number of entries in AtlasiumDB.log. A new entry over the cap drops the oldest.
Log.MAX_ENTRIES = 200

local TAGS = {
    ERROR = "|cffff0000[ERROR]|r",
    DEBUG = "|cff7c83ff[DEBUG]|r",
}

local function Write(level, ...)
    local msg = ns.Util.JoinArgs(...)
    ns.Core.Print(TAGS[level] .. " " .. msg)
    -- Before ADDON_LOADED the saved variables do not exist, so the message goes only to chat.
    if ns.db then
        local entry = date("%Y-%m-%d %H:%M:%S") .. " [" .. level .. "] " .. msg
        ns.Util.AppendCapped(ns.db.log, entry, Log.MAX_ENTRIES)
    end
end

--- Write an error message. It shows also when debug mode is off.
function Log.Error(...)
    Write("ERROR", ...)
end

--- Write a debug message. It does nothing when debug mode is off.
function Log.Debug(...)
    if ns.db and ns.db.debug then
        Write("DEBUG", ...)
    end
end
