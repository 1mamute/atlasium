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

-- Lua error capture, in debug mode only. The handler writes errors from Atlasium files with Log.Error,
-- so they are text in AtlasiumDB.log, then passes every error on to the previous handler. BugGrabber
-- makes seterrorhandler do nothing; with it, the capture reads its BugGrabber_BugGrabbed callback.

Log.errorCount = 0 -- captured errors since this load
Log.lastError = nil -- the newest captured error message

local capturing = false
local installed = false -- OnError is in the handler chain
local bugGrabberHooked = false -- the BugGrabber callbacks are registered
local previousHandler
local inHandler = false -- guards against an error inside Record
local refusalLogged = false
local loggedIn = false -- PLAYER_LOGIN fired: the last chance for BugGrabber callbacks has passed

--- Whether a Lua error message comes from an Atlasium file. Only the first line counts, because a
-- stack trace names other add-ons too. It accepts the client form,
-- "Interface\AddOns\Atlasium\Core.lua:12: attempt to index a nil value", and the BugGrabber form,
-- "Atlasium-0.1.0\Core.lua:12: attempt to index a nil value".
function Log.IsAddonError(msg)
    if type(msg) ~= "string" then
        return false
    end
    local line = msg:match("^[^\n]*"):lower()
    return line:find("addons[\\/]atlasium[\\/]") ~= nil
        or line:find("^atlasium[\\/]") ~= nil
        or line:find("^atlasium%-[%w%.]+[\\/]") ~= nil
end

local function Record(msg)
    if capturing and not inHandler and Log.IsAddonError(msg) then
        inHandler = true
        Log.errorCount = Log.errorCount + 1
        Log.lastError = msg
        pcall(Log.Error, "Lua error:", msg)
        inHandler = false
    end
end

local function OnError(msg, ...)
    Record(msg)
    if previousHandler then
        return previousHandler(msg, ...)
    end
end

-- BugGrabber fires (event, errorObject). The message is the error line, the stack and "  ---"; a long
-- message is a table of chunks.
local function OnBugGrabbed(_, errorObject)
    local msg = type(errorObject) == "table" and errorObject.message
    if type(msg) == "table" then
        msg = msg[1]
    end
    if type(msg) == "string" then
        Record(msg:match("^[^\n]*"))
    end
end

-- BugGrabber gets RegisterCallback when CallbackHandler-1.0 is loaded, maybe only after Atlasium.
local function HookBugGrabber()
    if not bugGrabberHooked and type(BugGrabber) == "table" and type(BugGrabber.RegisterCallback) == "function" then
        BugGrabber.RegisterCallback(Log, "BugGrabber_BugGrabbed", OnBugGrabbed)
        BugGrabber.RegisterCallback(Log, "BugGrabber_BugGrabbedAgain", OnBugGrabbed)
        bugGrabberHooked = true
        Log.Debug("error capture reads BugGrabber, which owns the error handler")
    end
    return bugGrabberHooked
end

--- Capture Lua errors while `active` is true. Dev.Update calls this. When another add-on owns the
-- error handler, the capture uses BugGrabber if it can, else it stays off and a debug message says so
-- once.
function Log.SetErrorCapture(active)
    capturing = active and true or false
    if active and not installed and not bugGrabberHooked then
        previousHandler = geterrorhandler()
        seterrorhandler(OnError)
        installed = geterrorhandler() == OnError
        if not installed then
            previousHandler = nil
            if not HookBugGrabber() then
                capturing = false
                -- Before PLAYER_LOGIN, BugGrabber can still get its callbacks, so wait for the retry.
                if not refusalLogged and (loggedIn or type(BugGrabber) ~= "table") then
                    refusalLogged = true
                    Log.Debug("error capture is off: another add-on owns the error handler")
                end
            end
        end
    elseif not active and installed and geterrorhandler() == OnError then
        -- Restore only when OnError is still on top. Else it stays in the chain and passes errors on.
        seterrorhandler(previousHandler)
        installed = false
        previousHandler = nil
    end
end

--- How Lua errors are captured now: "handler" (own error handler), "BugGrabber" or "off".
function Log.GetErrorCapture()
    if not capturing then
        return "off"
    end
    return installed and "handler" or "BugGrabber"
end

-- Start the capture as soon as the saved variables say that debug mode is on, so errors in the login
-- handlers of other modules count too. Core.lua registered ADDON_LOADED first, so ns.db is set. Try
-- again on PLAYER_LOGIN, because BugGrabber can get its callbacks after Atlasium loads.
ns.Core.RegisterEvent("ADDON_LOADED", function(name)
    if name == ns.name and ns.db.debug then
        Log.SetErrorCapture(true)
    end
end)

ns.Core.RegisterEvent("PLAYER_LOGIN", function()
    loggedIn = true
    if ns.db.debug then
        Log.SetErrorCapture(true)
    end
end)
