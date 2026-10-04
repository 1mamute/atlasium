local helper = require("tests.helper")

describe("Log", function()
    local ns, state, Log

    local function load(saved)
        _G.AtlasiumDB = saved
        ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
    end

    before_each(function()
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
end)
