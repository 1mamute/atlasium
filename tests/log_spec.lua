local helper = require("tests.helper")

describe("Log", function()
    local ns, state, Log

    local function load(saved)
        _G.AtlasiumDB = saved
        ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
    end

    before_each(function()
        _G.BugGrabber = nil
        state = helper.installWowStubs()
        ns = helper.newNamespace()
        helper.loadAddonFile("Atlasium/Util.lua", ns)
        helper.loadAddonFile("Atlasium/Core.lua", ns)
        helper.loadAddonFile("Atlasium/Log.lua", ns)
        Log = ns.Log
    end)

    describe("Error", function()
        it("prints and saves with debug mode off", function()
            load()
            Log.Error("bad", 42)
            assert.equals(1, #state.messages)
            assert.matches("[ERROR]|r bad 42", state.messages[1], 1, true)
            assert.same({ helper.DATE .. " [ERROR] bad 42" }, ns.db.log)
        end)

        it("prints without saving before the saved variables load", function()
            Log.Error("early")
            assert.equals(1, #state.messages)
            assert.matches("early", state.messages[1], 1, true)
            assert.is_nil(ns.db)
        end)
    end)

    describe("Debug", function()
        it("does nothing with debug mode off", function()
            load()
            Log.Debug("hidden")
            assert.same({}, state.messages)
            assert.same({}, ns.db.log)
        end)

        it("prints and saves with debug mode on", function()
            load({ debug = true })
            Log.Debug("shown", nil)
            assert.equals(1, #state.messages)
            assert.matches("[DEBUG]|r shown nil", state.messages[1], 1, true)
            assert.same({ helper.DATE .. " [DEBUG] shown nil" }, ns.db.log)
        end)

        it("does nothing before the saved variables load", function()
            Log.Debug("early")
            assert.same({}, state.messages)
        end)
    end)

    it("keeps the newest MAX_ENTRIES entries", function()
        load()
        for i = 1, Log.MAX_ENTRIES + 5 do
            Log.Error(i)
        end
        assert.equals(Log.MAX_ENTRIES, #ns.db.log)
        assert.equals(helper.DATE .. " [ERROR] 6", ns.db.log[1])
        assert.equals(helper.DATE .. " [ERROR] " .. (Log.MAX_ENTRIES + 5), ns.db.log[Log.MAX_ENTRIES])
    end)

    it("keeps the saved log across a reload", function()
        load({ log = { "old entry" } })
        Log.Error("new")
        assert.same({ "old entry", helper.DATE .. " [ERROR] new" }, ns.db.log)
    end)

    describe("error capture", function()
        local ERR = [[Interface\AddOns\Atlasium\Core.lua:12: attempt to index a nil value]]
        local OTHER = [[Interface\AddOns\OtherAddon\Main.lua:3: boom]]

        it("starts on ADDON_LOADED with debug mode on", function()
            load({ debug = true })
            geterrorhandler()(ERR)
            assert.equals(1, Log.errorCount)
        end)

        it("does not start on ADDON_LOADED with debug mode off", function()
            load({ debug = false })
            geterrorhandler()(ERR)
            assert.equals(0, Log.errorCount)
            assert.same({ ERR }, state.errors)
        end)

        it("tells Atlasium errors from other errors", function()
            assert.is_true(Log.IsAddonError(ERR))
            assert.is_true(Log.IsAddonError("interface/addons/atlasium/Dev.lua:1: x"))
            assert.is_false(Log.IsAddonError(OTHER))
            assert.is_false(Log.IsAddonError([[Interface\AddOns\AtlasiumExtra\A.lua:1: x]]))
            assert.is_false(Log.IsAddonError(nil))
        end)

        it("tells Atlasium errors in the BugGrabber form", function()
            assert.is_true(Log.IsAddonError([[Atlasium-0.1.0\Core.lua:12: x]]))
            assert.is_true(Log.IsAddonError([[Atlasium\Core.lua:12: x]]))
            assert.is_false(Log.IsAddonError([[AtlasiumExtra\A.lua:1: x]]))
            -- Only the first line counts: a stack line from Atlasium does not make it an Atlasium error.
            assert.is_false(Log.IsAddonError(OTHER .. "\n" .. ERR))
        end)

        it("logs Atlasium errors and passes every error on to the previous handler", function()
            load({ debug = true })
            geterrorhandler()(ERR)
            geterrorhandler()(OTHER)
            assert.equals(1, Log.errorCount)
            assert.equals(ERR, Log.lastError)
            assert.same({ helper.DATE .. " [ERROR] Lua error: " .. ERR }, ns.db.log)
            assert.same({ ERR, OTHER }, state.errors)
        end)

        it("restores the previous handler when capture turns off", function()
            load({ debug = false })
            local previous = geterrorhandler()
            Log.SetErrorCapture(true)
            assert.is_not.equals(previous, geterrorhandler())
            Log.SetErrorCapture(false)
            assert.equals(previous, geterrorhandler())
        end)

        it("installs the handler once", function()
            load({ debug = true })
            local handler = geterrorhandler()
            Log.SetErrorCapture(true)
            assert.equals(handler, geterrorhandler())
            handler(ERR)
            assert.same({ ERR }, state.errors)
        end)

        it("stays in the chain, without logging, when another handler was set after it", function()
            load({ debug = true })
            local ours = geterrorhandler()
            state.errorHandler = function(msg) return ours(msg) end -- another add-on wraps it
            Log.SetErrorCapture(false)
            geterrorhandler()(ERR)
            assert.equals(0, Log.errorCount)
            assert.same({ ERR }, state.errors)
        end)

        it("says once that it is off when another add-on owns the handler", function()
            state.errorHandlerLocked = true
            load({ debug = true })
            Log.SetErrorCapture(true)
            geterrorhandler()(ERR)
            assert.equals(0, Log.errorCount)
            assert.equals(1, #ns.db.log)
            assert.matches("another add-on owns the error handler", ns.db.log[1], 1, true)
            assert.equals("off", Log.GetErrorCapture())
        end)

        it("reports how it captures errors", function()
            load({ debug = false })
            assert.equals("off", Log.GetErrorCapture())
            Log.SetErrorCapture(true)
            assert.equals("handler", Log.GetErrorCapture())
        end)

        describe("with BugGrabber", function()
            local callbacks

            -- BugGrabber 2.2 makes seterrorhandler do nothing and gets RegisterCallback from
            -- CallbackHandler-1.0, which calls a function handler with (event, ...).
            local function installBugGrabber(withCallbacks)
                callbacks = {}
                state.errorHandlerLocked = true
                _G.BugGrabber = {}
                if withCallbacks then
                    _G.BugGrabber.RegisterCallback = function(_, event, fn) callbacks[event] = fn end
                end
            end

            local function grab(message, event)
                event = event or "BugGrabber_BugGrabbed"
                callbacks[event](event, { message = message, session = 1, counter = 1 })
            end

            local BG_LINE = [[Atlasium-0.1.0\Core.lua:12: boom]]
            local BG_ERR = BG_LINE .. "\n" .. [[OtherAddon\Main.lua:3: in function]] .. "\n  ---"

            it("reads Atlasium errors from its callbacks", function()
                installBugGrabber(true)
                load({ debug = true })
                assert.equals("BugGrabber", Log.GetErrorCapture())
                grab(BG_ERR)
                grab(BG_ERR, "BugGrabber_BugGrabbedAgain")
                grab([[OtherAddon\Main.lua:3: boom]] .. "\n  ---")
                assert.equals(2, Log.errorCount)
                assert.equals(BG_LINE, Log.lastError)
                assert.matches("error capture reads BugGrabber", ns.db.log[1], 1, true)
            end)

            it("reads the first chunk of a long message", function()
                installBugGrabber(true)
                load({ debug = true })
                grab({ BG_ERR, "more" })
                assert.equals(BG_LINE, Log.lastError)
            end)

            it("hooks on PLAYER_LOGIN when the callbacks come after Atlasium loads", function()
                installBugGrabber(false)
                load({ debug = true })
                assert.equals("off", Log.GetErrorCapture())
                _G.BugGrabber.RegisterCallback = function(_, event, fn) callbacks[event] = fn end
                ns.Core.OnEvent(nil, "PLAYER_LOGIN")
                assert.equals("BugGrabber", Log.GetErrorCapture())
                grab(BG_ERR)
                assert.equals(1, Log.errorCount)
                -- No "capture is off" message before the PLAYER_LOGIN retry.
                assert.matches("error capture reads BugGrabber", ns.db.log[1], 1, true)
            end)

            it("says it is off on PLAYER_LOGIN when the callbacks never come", function()
                installBugGrabber(false)
                load({ debug = true })
                assert.same({}, ns.db.log)
                ns.Core.OnEvent(nil, "PLAYER_LOGIN")
                assert.equals("off", Log.GetErrorCapture())
                assert.equals(1, #ns.db.log)
                assert.matches("another add-on owns the error handler", ns.db.log[1], 1, true)
            end)

            it("stops counting when capture turns off", function()
                installBugGrabber(true)
                load({ debug = true })
                Log.SetErrorCapture(false)
                grab(BG_ERR)
                assert.equals(0, Log.errorCount)
                assert.equals("off", Log.GetErrorCapture())
                Log.SetErrorCapture(true)
                grab(BG_ERR)
                assert.equals(1, Log.errorCount)
            end)
        end)

        it("does not loop when logging the error raises an error", function()
            load({ debug = true })
            ns.Core.Print = function() geterrorhandler()(ERR) end
            geterrorhandler()(ERR)
            assert.equals(1, Log.errorCount)
        end)
    end)
end)
