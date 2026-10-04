local helper = require("tests.helper")

describe("Util", function()
    local Util

    setup(function()
        local ns = helper.loadAddonFile("Atlasium/Util.lua", helper.newNamespace())
        Util = ns.Util
    end)

    describe("CopyDefaults", function()
        it("fills missing keys", function()
            assert.same({ a = 1, b = { c = 2 } }, Util.CopyDefaults({ a = 1, b = { c = 2 } }, nil))
        end)

        it("keeps existing values, including false", function()
            local result = Util.CopyDefaults({ a = true, b = { c = 2 } }, { a = false, b = { c = 9 } })
            assert.is_false(result.a)
            assert.equals(9, result.b.c)
        end)

        it("replaces a non-table value where defaults expect a table", function()
            assert.same({ b = { c = 2 } }, Util.CopyDefaults({ b = { c = 2 } }, { b = "bad" }))
        end)

        it("does not share nested tables with defaults", function()
            local defaults = { b = { c = 2 } }
            local result = Util.CopyDefaults(defaults, {})
            result.b.c = 5
            assert.equals(2, defaults.b.c)
        end)
    end)

    describe("FormatCoords", function()
        it("formats normalized coordinates as percentages", function()
            assert.equals("12.3, 45.6", Util.FormatCoords(0.123, 0.456))
            assert.equals("0.0, 100.0", Util.FormatCoords(0, 1))
        end)
    end)

    describe("SplitCommand", function()
        it("splits command and remainder", function()
            local cmd, rest = Util.SplitCommand("  Debug  on now ")
            assert.equals("debug", cmd)
            assert.equals("on now", rest)
        end)

        it("handles empty and nil input", function()
            assert.equals("", (Util.SplitCommand("")))
            assert.equals("", (Util.SplitCommand(nil)))
        end)
    end)

    describe("JoinArgs", function()
        it("joins the arguments with spaces through tostring", function()
            assert.equals("a 1 true", Util.JoinArgs("a", 1, true))
        end)

        it("keeps a nil in the middle and at the end", function()
            assert.equals("a nil b nil", Util.JoinArgs("a", nil, "b", nil))
        end)

        it("returns an empty string without arguments", function()
            assert.equals("", Util.JoinArgs())
        end)
    end)

    describe("AppendCapped", function()
        it("appends under the cap", function()
            local list = { "a" }
            Util.AppendCapped(list, "b", 3)
            assert.same({ "a", "b" }, list)
        end)

        it("fills up to the cap", function()
            local list = { "a", "b" }
            Util.AppendCapped(list, "c", 3)
            assert.same({ "a", "b", "c" }, list)
        end)

        it("drops the oldest entries over the cap", function()
            local list = { "a", "b", "c", "d" }
            Util.AppendCapped(list, "e", 3)
            assert.same({ "c", "d", "e" }, list)
        end)
    end)
end)
