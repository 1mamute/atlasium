-- Developer console for in-game checks (see docs/contributing/in-game-testing.md). While debug mode is
-- on, the console key (Dev.CONSOLE_KEY) focuses a small edit box. tools/wow-dev.ps1 types Lua into it
-- as hex digits and presses Enter. The console runs the code and shows the result as a strip of
-- coloured cells right of the map marker, three bytes per cell. The script reads the strip from a
-- capture of the game window, so a round trip needs no chat box and no screenshot file.
local _, ns = ...

local Console = {}
ns.DevConsole = Console

-- Strip geometry in UI units of a frame without parent: 1 unit is screen height / 768 pixels. Keep the
-- values in sync with tools/wow-dev.ps1.
Console.CELL = 4
Console.COLUMNS = 64
Console.LEFT = 24 -- right of the map marker (Dev.MARKER_PIXELS at scale 1)
Console.MAX_BYTES = 4096 -- longer output is cut and flagged

-- Header cells, then the data cells:
-- 1 magic "Atl", 2 load ID, 3 sequence number (2 bytes) and flags, 4 data length, 5 data checksum.
Console.MAGIC = { 0x41, 0x74, 0x6C }
Console.HEADER_CELLS = 5

Console.FLAG_FOCUS = 1 -- the console has the keyboard
Console.FLAG_OTHER_FOCUS = 2 -- another edit box has the keyboard, for example the player types in chat
Console.FLAG_ERROR = 4 -- the last code did not compile or raised an error
Console.FLAG_TRUNCATED = 8 -- the last output was longer than MAX_BYTES

Console.FOCUS_TIMEOUT = 3 -- seconds the console keeps the keyboard without input
Console.MAX_ENTRIES = 30 -- table entries that Serialize shows per level
Console.PREVIEW_LENGTH = 80 -- characters of the code that the chat echo shows

local CHECK_INTERVAL = 0.05 -- seconds between keyboard focus checks

local strip, editBox
local cells = {} -- cell textures, in strip order
local painted = {} -- the colour of each cell as an "r,g,b" key, so unchanged cells are skipped
local loadId = 0
local seq = 0
local flags = 0
local data = ""
local lastInput -- GetTime() of the focus or the last typed character, nil without focus
local sinceCheck = 0

--- The bytes of `hex` (pairs of hex digits) as a string, or nil when `hex` is not valid.
function Console.HexDecode(hex)
    if type(hex) ~= "string" or #hex % 2 ~= 0 or hex:find("[^%x]") then
        return nil
    end
    return (hex:gsub("%x%x", function(pair) return string.char(tonumber(pair, 16)) end))
end

--- A 24-bit checksum of `text`: the sum of each byte times its position modulo 251, plus 1.
function Console.Checksum(text)
    local sum = 0
    for i = 1, #text do
        sum = (sum + text:byte(i) * ((i - 1) % 251 + 1)) % 16777216
    end
    return sum
end

local function Split24(n)
    return math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256
end

--- The cell colours for a strip as a list of { r, g, b } bytes: the header, then `text` three bytes per
-- cell, the last cell padded with zeros.
function Console.EncodeCells(id, sequence, flagBits, text)
    local list = {
        { Console.MAGIC[1], Console.MAGIC[2], Console.MAGIC[3] },
        { Split24(id) },
        { math.floor(sequence / 256) % 256, sequence % 256, flagBits },
        { Split24(#text) },
        { Split24(Console.Checksum(text)) },
    }
    for i = 1, #text, 3 do
        list[#list + 1] = { text:byte(i), text:byte(i + 1) or 0, text:byte(i + 2) or 0 }
    end
    return list
end

--- The flags for the keyboard focus: `focus` is the edit box that has the keyboard, or nil.
function Console.GetFocusFlags(focus, console)
    if not focus then
        return 0
    elseif focus == console then
        return Console.FLAG_FOCUS
    end
    return Console.FLAG_OTHER_FOCUS
end

-- Numbers first, then strings, then the rest, so the output does not depend on the order of pairs.
local TYPE_ORDER = { number = 1, string = 2 }

local function CompareKeys(a, b)
    local ta, tb = TYPE_ORDER[type(a)] or 3, TYPE_ORDER[type(b)] or 3
    if ta ~= tb then
        return ta < tb
    elseif ta == 3 then
        return tostring(a) < tostring(b)
    end
    return a < b
end

--- `value` as readable text. Strings are quoted, tables show `depth` levels (default 2) and at most
-- MAX_ENTRIES entries per level in key order, and widgets show their type and name.
function Console.Serialize(value, depth)
    depth = depth or 2
    local kind = type(value)
    if kind == "string" then
        return string.format("%q", value)
    elseif kind ~= "table" then
        return tostring(value)
    end
    if type(rawget(value, 0)) == "userdata" and type(value.GetObjectType) == "function" then
        return "<" .. value:GetObjectType() .. " " .. tostring(value:GetName()) .. ">"
    end
    if depth <= 0 then
        return tostring(value)
    end
    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end
    if #keys == 0 then
        return "{}"
    end
    table.sort(keys, CompareKeys)
    local parts = {}
    for i = 1, math.min(#keys, Console.MAX_ENTRIES) do
        local key = keys[i]
        local label = key
        if type(key) ~= "string" or not key:match("^[%a_][%w_]*$") then
            label = "[" .. Console.Serialize(key, 0) .. "]"
        end
        parts[#parts + 1] = label .. " = " .. Console.Serialize(value[key], depth - 1)
    end
    if #keys > Console.MAX_ENTRIES then
        parts[#parts + 1] = "..."
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

local function Pack(...)
    return { n = select("#", ...), ... }
end

local function StripCodes(msg)
    return (tostring(msg):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

--- Run `code` and return the output text and whether it failed. Like a REPL, the code is first tried
-- as an expression (`return <code>`). It runs in the global environment, like /run, and reaches the
-- add-on through AtlasiumDev. The text holds the chat lines that the code printed, then "=> " and the
-- serialized results, or the error message.
function Console.Evaluate(code)
    local fn = loadstring("return " .. code, "=eval")
    if not fn then
        local err
        fn, err = loadstring(code, "=eval")
        if not fn then
            return err, true
        end
    end

    -- Capture the chat output of the code, also from print, Core.Print and Log. The shadow is an
    -- instance field, so restoring the old instance field (usually nil) brings back the method.
    local lines = {}
    local chat = DEFAULT_CHAT_FRAME
    local shadowed = rawget(chat, "AddMessage")
    local addMessage = chat.AddMessage
    chat.AddMessage = function(self, msg, ...)
        lines[#lines + 1] = StripCodes(msg)
        return addMessage(self, msg, ...)
    end
    local results = Pack(pcall(fn))
    chat.AddMessage = shadowed

    if not results[1] then
        lines[#lines + 1] = tostring(results[2])
        return table.concat(lines, "\n"), true
    end
    if results.n > 1 then
        local parts = {}
        for i = 2, results.n do
            parts[#parts + 1] = Console.Serialize(results[i])
        end
        lines[#lines + 1] = "=> " .. table.concat(parts, ", ")
    end
    return table.concat(lines, "\n"), false
end

--- The first line of `code`, cut to PREVIEW_LENGTH characters, safe to show in chat.
function Console.Preview(code)
    local line = code:match("^%s*([^\n]*)") or ""
    if #line > Console.PREVIEW_LENGTH then
        line = line:sub(1, Console.PREVIEW_LENGTH) .. "..."
    elseif code:find("\n%s*%S") then
        line = line .. " ..."
    end
    return (line:gsub("|", "||"))
end

-- Draw the strip: one texture per cell, 64 cells per row. Only cells with a new colour are set.
local function Paint()
    if not strip then
        return
    end
    local list = Console.EncodeCells(loadId, seq, flags, data)
    for i, color in ipairs(list) do
        local cell = cells[i]
        if not cell then
            cell = strip:CreateTexture(nil, "OVERLAY")
            cell:SetWidth(Console.CELL)
            cell:SetHeight(Console.CELL)
            local col = (i - 1) % Console.COLUMNS
            local row = math.floor((i - 1) / Console.COLUMNS)
            cell:SetPoint("TOPLEFT", strip, "TOPLEFT", col * Console.CELL, -row * Console.CELL)
            cells[i] = cell
        end
        local key = color[1] .. "," .. color[2] .. "," .. color[3]
        if painted[i] ~= key then
            cell:SetTexture(color[1] / 255, color[2] / 255, color[3] / 255)
            painted[i] = key
        end
        cell:Show()
    end
    for i = #list + 1, #cells do
        cells[i]:Hide()
    end
    strip:SetHeight(math.ceil(#list / Console.COLUMNS) * Console.CELL)
end

--- Show `text` on the strip as the result of a new run.
function Console.Publish(text, failed)
    local resultFlags = failed and Console.FLAG_ERROR or 0
    if #text > Console.MAX_BYTES then
        text = text:sub(1, Console.MAX_BYTES)
        resultFlags = resultFlags + Console.FLAG_TRUNCATED
    end
    data = text
    seq = (seq + 1) % 65536
    flags = flags % Console.FLAG_ERROR + resultFlags -- keep the focus flags
    Paint()
end

local function SetFocusFlags(focusFlags)
    local newFlags = flags - flags % Console.FLAG_ERROR + focusFlags
    if newFlags ~= flags then
        flags = newFlags
        Paint()
    end
end

--- Give the console the keyboard. The console key runs this in debug mode.
function Console.Focus()
    if not editBox or not ns.Dev.IsActive() then
        return
    end
    editBox:SetText("")
    editBox:Show()
    editBox:SetFocus()
    lastInput = GetTime()
    SetFocusFlags(Console.FLAG_FOCUS)
end

--- Give the keyboard back and hide the console.
function Console.Close()
    if not editBox then
        return
    end
    lastInput = nil
    editBox:SetText("")
    editBox:ClearFocus()
    editBox:Hide()
    SetFocusFlags(Console.GetFocusFlags(GetCurrentKeyBoardFocus(), editBox))
end

--- Run the hex-encoded code in the console and publish the result.
function Console.Submit()
    -- The key press of the console key can type its own "+" into the box, so skip it and spaces.
    local hex = editBox:GetText():gsub("[%s+]", "")
    Console.Close()
    local code = Console.HexDecode(hex)
    if not code then
        Console.Publish("dev console: the input is not hex", true)
        return
    end
    ns.Core.Print("|cff999999dev>|r " .. Console.Preview(code))
    Console.Publish(Console.Evaluate(code))
end

local function OnTextChanged()
    if lastInput then
        lastInput = GetTime()
    end
end

-- Keep the focus flags current, and give the keyboard back when no input comes in time.
local function OnUpdate(_, elapsed)
    sinceCheck = sinceCheck + elapsed
    if sinceCheck < CHECK_INTERVAL then
        return
    end
    sinceCheck = 0
    if lastInput and GetTime() - lastInput > Console.FOCUS_TIMEOUT then
        Console.Close()
    end
    SetFocusFlags(Console.GetFocusFlags(GetCurrentKeyBoardFocus(), editBox))
end

local function Build()
    -- No parent: the fullscreen map hides UIParent, and so would hide the strip.
    strip = CreateFrame("Frame", nil, nil)
    strip:SetFrameStrata("TOOLTIP")
    strip:SetPoint("TOPLEFT", Console.LEFT, 0)
    strip:SetWidth(Console.COLUMNS * Console.CELL)
    strip:SetHeight(Console.CELL)
    strip:SetScript("OnUpdate", OnUpdate)

    editBox = CreateFrame("EditBox", nil, strip)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(0)
    editBox:SetWidth(160)
    editBox:SetHeight(14)
    editBox:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, -2)
    editBox:SetScript("OnEnterPressed", Console.Submit)
    editBox:SetScript("OnEscapePressed", Console.Close)
    editBox:SetScript("OnTextChanged", OnTextChanged)
    editBox:SetScript("OnEditFocusLost", function(self) self:Hide() end)
    editBox:Hide()

    -- The console key is a click binding, and a click binding needs a button with a global name.
    local button = CreateFrame("Button", ns.Dev.CONSOLE_BUTTON, nil)
    button:SetScript("OnClick", Console.Focus)

    -- A new ID on each load lets the script see that a /reload finished.
    loadId = math.floor(GetTime() * 1000) % 16777216
end

--- Show the strip in debug mode and hide it otherwise. Dev.Update calls this.
function Console.SetActive(active)
    if active then
        if not strip then
            Build()
        end
        strip:Show()
        Paint()
    elseif strip then
        Console.Close()
        strip:Hide()
    end
end

--- The load ID on the strip. tools/wow-dev.ps1 compares it before and after a /reload.
function Console.GetLoadId()
    return loadId
end
