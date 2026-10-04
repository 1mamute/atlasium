local helper = require("tests.helper")

describe("DevConsole", function()
    local ns, state, Console

    local function hex(text)
        return (text:gsub(".", function(c) return string.format("%02x", c:byte()) end))
    end

    local function load(debug)
        _G.AtlasiumDB = { debug = debug }
        ns.Core.OnEvent(nil, "ADDON_LOADED", "Atlasium")
        ns.Core.OnEvent(nil, "PLAYER_LOGIN")
    end

    -- The strip is the frame with an OnUpdate script.
    local function findStrip()
        for _, frame in ipairs(state.frames) do
            if frame.ownScripts.OnUpdate then
                return frame
            end
        end
    end

    local function findEditBox()
        for _, frame in ipairs(state.frames) do
            if frame.frameType == "EditBox" then
                return frame
            end
        end
    end

    -- Read the strip back the way tools/wow-dev.ps1 does: the colour of each shown cell as 3 bytes.
    local function readStrip()
        local bytes = {}
        for _, cell in ipairs(findStrip().textures) do
            local shown = helper.lastCall(cell, "Show")
            local hidden = helper.lastCall(cell, "Hide")
            if shown and (not hidden or #cell.calls.Show > #cell.calls.Hide) then
                local c = helper.lastCall(cell, "SetTexture")
                for i = 1, 3 do
                    bytes[#bytes + 1] = math.floor(c[i] * 255 + 0.5)
                end
            end
        end
        local function u24(i) return bytes[i] * 65536 + bytes[i + 1] * 256 + bytes[i + 2] end
        local length = u24(10)
        local chars = {}
        for i = 16, 15 + length do
            chars[#chars + 1] = string.char(bytes[i])
        end
        local text = table.concat(chars)
        assert.equals(Console.Checksum(text), u24(13))
        return {
            magic = string.char(bytes[1], bytes[2], bytes[3]),
            loadId = u24(4),
            seq = bytes[7] * 256 + bytes[8],
            flags = bytes[9],
            text = text,
        }
    end

    local function submit(text)
        Console.Focus()
        findEditBox():SetText(text)
        helper.runScript(findEditBox(), "OnEnterPressed")
    end

    local function tick(seconds)
        state.time = state.time + seconds
        helper.runScript(findStrip(), "OnUpdate", seconds)
    end

    before_each(function()
        state = helper.installWowStubs()
        ns = helper.newNamespace()
        helper.loadAddonFile("Atlasium/Util.lua", ns)
        helper.loadAddonFile("Atlasium/Core.lua", ns)
        helper.loadAddonFile("Atlasium/Localization.lua", ns)
        helper.loadAddonFile("Atlasium/Settings.lua", ns)
        helper.loadAddonFile("Atlasium/Log.lua", ns)
        helper.loadAddonFile("Atlasium/Dev.lua", ns)
        helper.loadAddonFile("Atlasium/DevConsole.lua", ns)
        Console = ns.DevConsole
    end)

    describe("HexDecode", function()
        it("decodes pairs of hex digits in either case", function()
            assert.equals("Hello", Console.HexDecode("48656c6C6F"))
            assert.equals("", Console.HexDecode(""))
            assert.equals("a|b\n", Console.HexDecode(hex("a|b\n")))
        end)

        it("refuses odd lengths, other characters and non-strings", function()
            assert.is_nil(Console.HexDecode("486"))
            assert.is_nil(Console.HexDecode("4g"))
            assert.is_nil(Console.HexDecode(nil))
        end)
    end)

    describe("Checksum", function()
        it("weights each byte by its position", function()
            assert.equals(0, Console.Checksum(""))
            assert.equals(65, Console.Checksum("A"))
            assert.equals(65 + 66 * 2, Console.Checksum("AB"))
        end)

        it("starts the weights again after 251 bytes", function()
            assert.equals(251 * 252 / 2 + 1, Console.Checksum(string.rep("\1", 252)))
        end)

        it("stays below 2^24", function()
            assert.is_true(Console.Checksum(string.rep("\255", 4096)) < 16777216)
        end)
    end)

    describe("EncodeCells", function()
        it("writes the header, then three bytes of text per cell padded with zeros", function()
            local cells = Console.EncodeCells(0x123456, 0x0102, 5, "abcd")
            assert.same({
                { 0x41, 0x74, 0x6C },
                { 0x12, 0x34, 0x56 },
                { 0x01, 0x02, 5 },
                { 0, 0, 4 },
                { 0, 0x03, 0xDE }, -- 97 + 98 * 2 + 99 * 3 + 100 * 4 = 990
                { 97, 98, 99 },
                { 100, 0, 0 },
            }, cells)
        end)

        it("has only the header for empty text", function()
            assert.equals(Console.HEADER_CELLS, #Console.EncodeCells(0, 0, 0, ""))
        end)
    end)

    describe("GetFocusFlags", function()
        it("tells the console focus from another focus", function()
            local box = {}
            assert.equals(0, Console.GetFocusFlags(nil, box))
            assert.equals(Console.FLAG_FOCUS, Console.GetFocusFlags(box, box))
            assert.equals(Console.FLAG_OTHER_FOCUS, Console.GetFocusFlags({}, box))
        end)
    end)

    describe("Serialize", function()
        it("quotes strings and shows other values with tostring", function()
            assert.equals('"a\\"b"', Console.Serialize('a"b'))
            assert.equals("12.5", Console.Serialize(12.5))
            assert.equals("nil", Console.Serialize(nil))
            assert.equals("true", Console.Serialize(true))
        end)

        it("shows tables in key order, numbers first", function()
            assert.equals('{ [1] = "x", [2] = "y", a = 1, b = { c = true } }',
                Console.Serialize({ "x", "y", b = { c = true }, a = 1 }))
            assert.equals("{}", Console.Serialize({}))
        end)

        it("brackets keys that are not names", function()
            assert.equals('{ ["a b"] = 1 }', Console.Serialize({ ["a b"] = 1 }))
        end)

        it("stops after two levels", function()
            local text = Console.Serialize({ a = { b = { c = 1 } } })
            assert.matches("^{ a = { b = table: ", text)
        end)

        it("shows at most MAX_ENTRIES entries per level", function()
            local list = {}
            for i = 1, Console.MAX_ENTRIES + 5 do
                list[i] = i
            end
            local text = Console.Serialize(list)
            assert.matches("%[30%] = 30, %.%.%. }$", text)
            assert.is_nil(text:find("[31]", 1, true))
        end)

        it("shows widgets by type and name", function()
            local widget = { [0] = newproxy and newproxy() or io.stdout }
            widget.GetObjectType = function() return "Frame" end
            widget.GetName = function() return "WorldMapFrame" end
            assert.equals("<Frame WorldMapFrame>", Console.Serialize(widget))
        end)
    end)

    describe("Preview", function()
        it("shows the first line and marks more lines", function()
            assert.equals("local a = 1 ...", Console.Preview("  local a = 1\nreturn a"))
            assert.equals("return 1", Console.Preview("return 1\n"))
        end)

        it("cuts long lines and escapes pipes", function()
            assert.equals(string.rep("x", Console.PREVIEW_LENGTH) .. "...",
                Console.Preview(string.rep("x", Console.PREVIEW_LENGTH + 1)))
            assert.equals("print('||cff')", Console.Preview("print('|cff')"))
        end)
    end)

    describe("Evaluate", function()
        it("returns the value of an expression", function()
            assert.same({ "=> 3", false }, { Console.Evaluate("1 + 2") })
            assert.same({ '=> 1, "a", nil', false }, { Console.Evaluate("1, 'a', nil") })
        end)

        it("runs statements and shows returned values", function()
            assert.same({ "", false }, { Console.Evaluate("local a = 1") })
            assert.same({ "=> 2", false }, { Console.Evaluate("local a = 1 return a + 1") })
        end)

        it("captures chat output without colour codes and still prints it", function()
            local text = Console.Evaluate("DEFAULT_CHAT_FRAME:AddMessage('|cffff0000hi|r') return 1")
            assert.equals("hi\n=> 1", text)
            assert.same({ "|cffff0000hi|r" }, state.messages)
        end)

        it("restores the chat frame after the call, also after an error", function()
            local method = DEFAULT_CHAT_FRAME.AddMessage
            Console.Evaluate("error('x')")
            assert.equals(method, DEFAULT_CHAT_FRAME.AddMessage)
        end)

        it("reports runtime and syntax errors", function()
            local text, failed = Console.Evaluate("error('boom')")
            assert.is_true(failed)
            assert.matches("boom", text)
            text, failed = Console.Evaluate("return +")
            assert.is_true(failed)
            assert.matches("^eval:1:", text)
        end)

        it("keeps the output printed before an error", function()
            local text = Console.Evaluate("DEFAULT_CHAT_FRAME:AddMessage('before') error('after', 0)")
            assert.equals("before\nafter", text)
        end)

        it("runs in the global environment and reaches the add-on through AtlasiumDev", function()
            load(true)
            assert.same({ "=> true", false }, { Console.Evaluate("AtlasiumDev.DevConsole ~= nil") })
            Console.Evaluate("AtlasiumConsoleSpecValue = 7")
            assert.equals(7, _G.AtlasiumConsoleSpecValue)
            _G.AtlasiumConsoleSpecValue = nil
        end)
    end)

    describe("with debug off", function()
        it("builds nothing and ignores the console key", function()
            load(false)
            assert.is_nil(findStrip())
            Console.Focus()
            assert.is_nil(state.focus)
        end)
    end)

    describe("with debug on", function()
        before_each(function()
            state.time = 12.3456
            load(true)
        end)

        it("shows the strip right of the marker, above everything, without a parent", function()
            local strip = findStrip()
            assert.equals("TOOLTIP", helper.lastCall(strip, "SetFrameStrata")[1])
            assert.same({ "TOPLEFT", nil, "TOPLEFT", 24, 0 }, { strip:GetPoint() })
            assert.is_nil(strip:GetParent())
            assert.is_true(strip:IsShown())
            assert.is_false(strip:IsMouseEnabled())
        end)

        it("paints the magic, a load ID from GetTime and no data", function()
            local read = readStrip()
            assert.equals("Atl", read.magic)
            assert.equals(12345, read.loadId)
            assert.equals(12345, Console.GetLoadId())
            assert.equals(0, read.seq)
            assert.equals("", read.text)
        end)

        it("binds the console key to a named button that focuses the console", function()
            assert.equals("CLICK AtlasiumDevConsoleButton:LeftButton", state.bindings.NUMPADPLUS)
            local button = _G.AtlasiumDevConsoleButton
            assert.is_not_nil(button)
            helper.runScript(button, "OnClick", "LeftButton")
            assert.equals(findEditBox(), state.focus)
        end)

        it("shows the focus flag while the console has the keyboard", function()
            Console.Focus()
            assert.is_true(findEditBox():IsShown())
            assert.equals(Console.FLAG_FOCUS, readStrip().flags)
        end)

        it("runs hex code on Enter, publishes the result and gives the keyboard back", function()
            submit(hex("return 6 * 7"))
            local read = readStrip()
            assert.equals("=> 42", read.text)
            assert.equals(1, read.seq)
            assert.equals(0, read.flags)
            assert.is_nil(state.focus)
            assert.is_false(findEditBox():IsShown())
        end)

        it("echoes the code in chat", function()
            submit(hex("return 1\nreturn 2"))
            assert.matches("dev>|r return 1 ...", state.messages[1], 1, true)
        end)

        it("ignores the + that the console key can type", function()
            submit("+" .. hex("1"))
            assert.equals("=> 1", readStrip().text)
        end)

        it("flags errors and input that is not hex", function()
            submit(hex("error('bad', 0)"))
            local read = readStrip()
            assert.equals("bad", read.text)
            assert.equals(Console.FLAG_ERROR, read.flags)
            submit("xyz")
            read = readStrip()
            assert.equals("dev console: the input is not hex", read.text)
            assert.equals(Console.FLAG_ERROR, read.flags)
            assert.equals(2, read.seq)
        end)

        it("cuts long output and flags it", function()
            submit(hex("string.rep('a', " .. (Console.MAX_BYTES + 10) .. ")"))
            local read = readStrip()
            assert.equals(Console.MAX_BYTES, #read.text)
            assert.equals(Console.FLAG_TRUNCATED, read.flags)
        end)

        it("hides cells that a shorter result no longer needs", function()
            submit(hex("string.rep('a', 300)"))
            submit(hex("1"))
            assert.equals("=> 1", readStrip().text)
        end)

        it("closes on Escape", function()
            Console.Focus()
            helper.runScript(findEditBox(), "OnEscapePressed")
            assert.is_nil(state.focus)
            assert.equals(0, readStrip().flags)
        end)

        it("gives the keyboard back after FOCUS_TIMEOUT seconds without input", function()
            Console.Focus()
            tick(Console.FOCUS_TIMEOUT - 1)
            helper.runScript(findEditBox(), "OnTextChanged", true)
            tick(Console.FOCUS_TIMEOUT - 1)
            assert.equals(findEditBox(), state.focus)
            tick(2)
            assert.is_nil(state.focus)
            assert.equals(0, readStrip().flags)
        end)

        it("shows when another edit box has the keyboard", function()
            state.focus = {}
            tick(0.1)
            assert.equals(Console.FLAG_OTHER_FOCUS, readStrip().flags)
            state.focus = nil
            tick(0.1)
            assert.equals(0, readStrip().flags)
        end)

        it("keeps the result flags when the focus changes", function()
            submit(hex("error('x')"))
            Console.Focus()
            assert.equals(Console.FLAG_ERROR + Console.FLAG_FOCUS, readStrip().flags)
        end)

        it("hides the strip and closes the console when debug turns off", function()
            Console.Focus()
            SlashCmdList.ATLASIUM("debug")
            assert.is_false(findStrip():IsShown())
            assert.is_nil(state.focus)
            Console.Focus()
            assert.is_nil(state.focus)
        end)

        it("shows the same strip again when debug turns on again", function()
            submit(hex("1"))
            SlashCmdList.ATLASIUM("debug")
            SlashCmdList.ATLASIUM("debug")
            assert.is_true(findStrip():IsShown())
            assert.equals("=> 1", readStrip().text)
        end)

        it("focuses the console from the world map key handler", function()
            helper.runScript(WorldMapFrame, "OnKeyDown", "NUMPADPLUS")
            assert.equals(findEditBox(), state.focus)
        end)
    end)
end)
