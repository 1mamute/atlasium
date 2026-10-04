-- Minimal WoW client stubs and an addon file loader for busted specs.
-- The client passes (addonName, namespace) as varargs to every file in the .toc;
-- loadAddonFile mimics that.

local helper = {}

-- The time that the `date` stub returns.
helper.DATE = "2026-10-04 12:34:56"

function helper.newNamespace()
    return {}
end

--- Load an addon file the way the client does.
function helper.loadAddonFile(path, ns)
    local chunk = assert(loadfile(path))
    chunk("Atlasium", ns)
    return ns
end

--- Create a fake widget. Any PascalCase method not defined in `fake` is accepted and recorded in
-- `fake.calls[method]` as a list of argument lists, so specs can check calls such as SetPoint.
-- `methods` is an optional table of real methods. Like the client's widget metatable, it is
-- looked up after the fields of `fake`, so `fake.Show = nil` brings the real method back.
function helper.newFake(fake, methods)
    fake = fake or {}
    fake.calls = {}
    return setmetatable(fake, {
        __index = function(self, key)
            if methods and methods[key] then
                return methods[key]
            end
            if type(key) ~= "string" or not key:match("^%u") then
                return nil
            end
            local recorder = function(_, ...)
                local list = self.calls[key] or {}
                self.calls[key] = list
                table.insert(list, { n = select("#", ...), ... })
            end
            rawset(self, key, recorder)
            return recorder
        end,
    })
end

--- Return the arguments of the last recorded call to `method` on `fake`, or nil.
function helper.lastCall(fake, method)
    local list = fake.calls[method]
    return list and list[#list]
end

-- Fake frames: the real, stateful methods of a widget. They also record every call in `calls`,
-- so helper.lastCall works on them as on any fake.

local frameMethods = {}

local function define(name, fn)
    frameMethods[name] = function(self, ...)
        local list = self.calls[name] or {}
        self.calls[name] = list
        table.insert(list, { n = select("#", ...), ... })
        return fn(self, ...)
    end
end

-- Same result as MapNavigation.NormalizePoint, for any SetPoint call form.
local function normalizePoint(point, a, b, c, d)
    if type(a) == "number" then
        return point, nil, point, a, b or 0
    end
    if type(b) == "number" then
        return point, a, point, b, c or 0
    end
    return point, a, b or point, c or 0, d or 0
end

local function resolve(frame)
    if type(frame) == "string" then
        return _G[frame]
    end
    return frame
end

local function detach(frame)
    local parent = frame.parent
    if parent and parent.children then
        for i, child in ipairs(parent.children) do
            if child == frame then
                table.remove(parent.children, i)
                break
            end
        end
    end
    frame.parent = nil
end

local function attach(frame, parent)
    detach(frame)
    if parent then
        frame.parent = parent
        parent.children = parent.children or {}
        table.insert(parent.children, frame)
    end
end

define("GetName", function(self) return self.name end)

define("SetPoint", function(self, ...)
    local point, relativeTo, relativePoint, x, y = normalizePoint(...)
    relativeTo = resolve(relativeTo) or self.parent
    for _, p in ipairs(self.points) do
        if p[1] == point then
            p[2], p[3], p[4], p[5] = relativeTo, relativePoint, x, y
            return
        end
    end
    table.insert(self.points, { point, relativeTo, relativePoint, x, y })
end)
define("GetPoint", function(self, index)
    local p = self.points[index or 1]
    if p then
        return unpack(p, 1, 5)
    end
end)
define("GetNumPoints", function(self) return #self.points end)
define("ClearAllPoints", function(self) self.points = {} end)
define("SetAllPoints", function(self, relativeTo)
    relativeTo = resolve(relativeTo) or self.parent
    self.points = { { "TOPLEFT", relativeTo, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", 0, 0 } }
end)

define("SetScale", function(self, scale) self.scale = scale end)
define("GetScale", function(self) return self.scale or 1 end)
define("GetEffectiveScale", function(self) return self.effectiveScale or 1 end)

define("SetParent", function(self, parent) attach(self, parent) end)
define("GetParent", function(self) return self.parent end)
define("GetChildren", function(self) return unpack(self.children or {}) end)
define("GetRegions", function(self) return unpack(self.regions or {}) end)

define("SetWidth", function(self, width) self.width = width end)
define("SetHeight", function(self, height) self.height = height end)
define("GetWidth", function(self) return self.width or 0 end)
define("GetHeight", function(self) return self.height or 0 end)
define("GetLeft", function(self) return self.left end)
define("GetTop", function(self) return self.top end)

-- Like the client, a new level moves all descendants by the same amount.
local function shiftLevels(frame, delta)
    for _, child in ipairs(frame.children or {}) do
        child.frameLevel = (child.frameLevel or 0) + delta
        shiftLevels(child, delta)
    end
end
define("SetFrameLevel", function(self, level)
    shiftLevels(self, level - (self.frameLevel or 0))
    self.frameLevel = level
end)
define("GetFrameLevel", function(self) return self.frameLevel or 0 end)

define("SetFrameStrata", function(self, strata) self.frameStrata = strata end)
define("GetFrameStrata", function(self)
    return self.frameStrata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM"
end)

define("EnableMouse", function(self, enabled) self.mouseEnabled = enabled and true or false end)
define("IsMouseEnabled", function(self) return self.mouseEnabled or false end)
define("EnableMouseWheel", function(self, enabled) self.wheelEnabled = enabled and true or false end)
define("SetHitRectInsets", function(self, left, right, top, bottom)
    self.hitInsets = { left, right, top, bottom }
end)
define("IsMouseOver", function(self) return self.mouseOver or false end)

define("Show", function(self) self.shown = true end)
define("Hide", function(self) self.shown = false end)
define("IsShown", function(self) return self.shown end)

define("SetScript", function(self, script, fn)
    self.ownScripts[script] = fn
    if self.scriptSink then
        self.scriptSink[script] = fn
    end
end)
define("GetScript", function(self, script) return self.ownScripts[script] end)
define("HookScript", function(self, script, fn)
    self.scriptHooks[script] = self.scriptHooks[script] or {}
    table.insert(self.scriptHooks[script], fn)
end)

-- ScrollFrame methods.
define("SetScrollChild", function(self, child) self.scrollChild = child end)
define("UpdateScrollChildRect", function() end)
define("SetHorizontalScroll", function(self, offset) self.horizontalScroll = offset end)
define("GetHorizontalScroll", function(self) return self.horizontalScroll or 0 end)
define("SetVerticalScroll", function(self, offset) self.verticalScroll = offset end)
define("GetVerticalScroll", function(self) return self.verticalScroll or 0 end)

--- Create a fake frame with the real methods above. `fields` may set the state: `name`, `parent`,
-- `shown` (default true), `scale`, `effectiveScale`, `width`, `height`, `left`, `top`,
-- `frameLevel`, `regions`, `mouseOver`, `mouseEnabled`, or any other field or method.
function helper.newFrame(fields)
    fields = fields or {}
    local parent = fields.parent
    fields.parent = nil
    if fields.shown == nil then
        fields.shown = true
    end
    fields.points = fields.points or {}
    fields.ownScripts = {}
    fields.scriptHooks = {}
    local frame = helper.newFake(fields, frameMethods)
    attach(frame, parent)
    return frame
end

--- Run the script `name` of `frame` with `...`, then its HookScript hooks, as the client does.
function helper.runScript(frame, name, ...)
    local fn = frame.ownScripts[name]
    if fn then
        fn(frame, ...)
    end
    for _, hook in ipairs(frame.scriptHooks[name] or {}) do
        hook(frame, ...)
    end
end

-- Names of global frames created by the stubs, cleared on the next installWowStubs().
local namedFrames = {}

-- Create a fake frame, and make it a global when it has a name, as the client does.
local function createNamed(name, fields)
    fields = fields or {}
    fields.name = name
    local frame = helper.newFrame(fields)
    if name then
        _G[name] = frame
        namedFrames[name] = true
    end
    return frame
end

-- Add the points of a frame without leaving calls in its record.
local function anchor(frame, ...)
    frame:SetPoint(...)
    frame.calls.SetPoint = nil
end

--- Install the Blizzard world map frames at the small map size: the map is 1002 x 668 units at a
-- scale of 0.691, so it is about 692 x 462 pixels. WorldMapFrame is hidden.
local function installMapFrames()
    local frame = createNamed
    local mapFrame = frame("WorldMapFrame", { parent = _G.UIParent, shown = false, frameLevel = 5,
        width = 1024, height = 768 })
    local guide = frame("WorldMapPositioningGuide", { parent = mapFrame, width = 1024, height = 768 })
    anchor(guide, "TOP", mapFrame, "TOP")

    local detailTextures = {}
    local detail = frame("WorldMapDetailFrame", {
        parent = mapFrame, width = 1002, height = 668, scale = 0.691, frameLevel = 6,
        textures = detailTextures,
        CreateTexture = function(_, textureName, layer)
            local texture = helper.newFake({ name = textureName, layer = layer, shown = true })
            texture.Show = function(self) self.shown = true end
            texture.Hide = function(self) self.shown = false end
            texture.IsShown = function(self) return self.shown end
            table.insert(detailTextures, texture)
            return texture
        end,
    })
    anchor(detail, "TOPLEFT", guide, "TOP", -726, -99)

    local button = frame("WorldMapButton", { parent = mapFrame, width = 1002, height = 668, scale = 0.691,
        frameLevel = 8, mouseEnabled = true })
    anchor(button, "TOPLEFT", detail, "TOPLEFT")
    local blob = frame("WorldMapBlobFrame", { parent = mapFrame, width = 1002, height = 668, scale = 0.691,
        frameLevel = 7 })
    anchor(blob, "TOPLEFT", detail, "TOPLEFT")
    local poiFrame = frame("WorldMapPOIFrame", { parent = mapFrame, width = 1002, height = 668, frameLevel = 9 })
    anchor(poiFrame, "TOPLEFT", detail, "TOPLEFT")

    local areaFrame = frame("WorldMapFrameAreaFrame", { parent = button, width = 300, height = 40 })
    anchor(areaFrame, "TOP", button, "TOP", 0, -10)
    frame("WorldMapFrameAreaLabel", { parent = areaFrame })
    frame("WorldMapHighlight", { parent = button })

    -- Icons on the map, all children of WorldMapButton. They have no point until a spec sets one.
    for _, name in ipairs({ "WorldMapPlayer", "WorldMapFlag1", "WorldMapFlag2", "WorldMapCorpse",
        "WorldMapDeathRelease", "WorldMapPing" }) do
        frame(name, { parent = button, width = 24, height = 24 })
    end
    for i = 1, 4 do
        frame("WorldMapParty" .. i, { parent = button, width = 24, height = 24 })
    end
    for i = 1, 40 do
        frame("WorldMapRaid" .. i, { parent = button, width = 24, height = 24 })
    end

    -- The client places the player arrow relative to the detail frame. It is a child of WorldMapFrame.
    local arrow = frame("PlayerArrowFrame", { parent = mapFrame, width = 32, height = 32 })
    anchor(arrow, "CENTER", detail, "TOPLEFT", 100, -100)
    frame("PlayerArrowEffectFrame", { parent = mapFrame, width = 32, height = 32 })

    -- Frames and a region of WorldMapFrame that are anchored to the map or to the positioning guide.
    local questScroll = frame("WorldMapQuestScrollFrame", { parent = mapFrame, width = 300, height = 400 })
    anchor(questScroll, "TOPLEFT", detail, "TOPRIGHT", 6, 0)
    frame("WorldMapQuestScrollChildFrame", { parent = questScroll })
    local trackQuest = frame("WorldMapTrackQuest", { parent = mapFrame, width = 20, height = 20 })
    anchor(trackQuest, "BOTTOMLEFT", guide, "TOP", -496, -700)
    local title = frame("WorldMapFrameTitle", { width = 200, height = 16 })
    anchor(title, "TOP", detail, "TOP", 0, 20)
    mapFrame.regions = { title }
end

-- The client function that sets the frame levels of the map frames.
local function resetFrameLevels()
    local level = _G.WorldMapFrame:GetFrameLevel()
    _G.WorldMapDetailFrame:SetFrameLevel(level + 1)
    _G.WorldMapBlobFrame:SetFrameLevel(level + 2)
    _G.WorldMapButton:SetFrameLevel(level + 3)
    _G.WorldMapPOIFrame:SetFrameLevel(level + 4)
end

--- Install the world map API. The functions read and write the tables of `state`.
local function installMapApi(state)
    _G.MAP_VEHICLES = {}
    _G.NUM_WORLDMAP_POIS = 0
    _G.QUEST_POI_SWAP_BUTTONS = {}
    _G.WORLDMAP_SETTINGS = { selectedQuestId = 0 }
    _G.WorldMapFrame_ResetFrameLevels = resetFrameLevels
    _G.WorldMapFrame_Update = function() end
    _G.WorldMapFrame_DisplayQuestPOI = function() end
    _G.GetMapInfo = function() return state.map.name end
    _G.GetNumMapOverlays = function() return #state.map.overlays end
    _G.GetMapOverlayInfo = function(i) return state.map.overlays[i] end
    _G.GetCurrentMapContinent = function() return state.map.continent end
    _G.GetCurrentMapAreaID = function() return state.map.area end
    _G.GetCurrentMapDungeonLevel = function() return state.map.level end
    _G.InCombatLockdown = function() return state.combat end
    _G.IsMouseButtonDown = function(button) return state.mouseDown[button] or false end
    _G.GetPlayerMapPosition = function() return state.player.x, state.player.y end
    -- Like the client, SetMapToCurrentZone shows the player's zone: `state.zone` when a spec sets it.
    _G.SetMapToCurrentZone = function()
        state.mapResets = state.mapResets + 1
        if state.zone then
            state.map.name, state.map.level = state.zone.name, state.zone.level or 0
            state.player.x, state.player.y = state.zone.x, state.zone.y
        end
    end
    _G.PositionWorldMapArrowFrame = function(...)
        -- Like the client, the relative frame must be a name: a frame object raises an error.
        assert(type((select(2, ...))) == "string", "relativeTo must be a frame name")
        table.insert(state.arrowPositions, { n = select("#", ...), ... })
    end
    _G.ShowWorldMapArrowFrame = function(...)
        table.insert(state.arrowShows, { n = select("#", ...), ... })
    end
end

--- Install hooksecurefunc. `hooksecurefunc(name, fn)` also wraps the global function `name`, so
-- calling it runs the original and then every hook, as in the client. `state.hooks[name]` is the
-- last hook, and `state.hookLists[name]` has all of them. `hooksecurefunc(tbl, method, fn)` wraps
-- `tbl[method]` in the same way, and passes the arguments of the call to `fn`.
local function installHooksecurefunc(state)
    local function wrap(original, hook)
        return function(...)
            local results = { original(...) }
            hook(...)
            return unpack(results)
        end
    end
    _G.hooksecurefunc = function(a, b, c)
        if type(a) == "table" then
            assert(type(a[b]) == "function", "hooksecurefunc: no method " .. tostring(b))
            a[b] = wrap(a[b], c)
            return
        end
        state.hooks[a] = b
        state.hookLists[a] = state.hookLists[a] or {}
        table.insert(state.hookLists[a], b)
        if type(_G[a]) == "function" then
            _G[a] = wrap(_G[a], b)
        end
    end
end

--- Install fresh WoW globals. Returns a table recording calls for assertions.
function helper.installWowStubs()
    local state = {
        messages = {},
        events = {},
        scripts = {},
        frames = {},
        toggled = {},
        cursor = { x = 0, y = 0 },
        hooks = {},
        hookLists = {},
        -- The current world map: its file name, the texture paths of the explored overlays, and
        -- the continent, area ID and dungeon level that MapNavigation compares.
        map = { name = nil, overlays = {}, continent = 1, area = 1, level = 0 },
        combat = false, -- InCombatLockdown()
        uiScale = 1, -- UIParent:GetEffectiveScale()
        bindings = {}, -- override bindings set with SetOverrideBinding: key -> command
        bindingOwner = nil, -- the owner passed to SetOverrideBinding or ClearOverrideBindings
        binds = {}, -- GetBindingFromClick(key) result for a key
        ran = {}, -- commands passed to RunBinding
        mouseDown = {}, -- IsMouseButtonDown(button), for example { LeftButton = true }
        player = { x = 0, y = 0 }, -- GetPlayerMapPosition("player")
        arrowPositions = {}, -- argument lists of PositionWorldMapArrowFrame
        arrowShows = {}, -- argument lists of ShowWorldMapArrowFrame
        minimapZooms = {}, -- 1 for each Minimap_ZoomIn call, -1 for each Minimap_ZoomOut call
        minimapZoom = 0, -- Minimap:GetZoom()
        zoomInClicks = 0, -- calls of the Blizzard OnClick script of MinimapZoomIn
        facing = 0, -- GetPlayerFacing()
        indoors = false, -- IsIndoors()
        instance = false, -- IsInInstance()
        cvars = { rotateMinimap = "0", minimapZoom = "0", minimapInsideZoom = "0" }, -- GetCVar(name)
        zone = nil, -- what SetMapToCurrentZone shows: { name, level, x, y }
        mapResets = 0, -- SetMapToCurrentZone calls
        time = 0, -- GetTime(), in seconds
        focus = nil, -- GetCurrentKeyBoardFocus(): the edit box that has the keyboard
        errors = {}, -- messages that reached the default error handler
        errorHandler = nil, -- geterrorhandler(), set below
        errorHandlerLocked = false, -- seterrorhandler does nothing, as with BugGrabber
    }
    state.errorHandler = function(msg) table.insert(state.errors, msg) end

    for name in pairs(namedFrames) do
        _G[name] = nil
        namedFrames[name] = nil
    end

    _G.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, msg) table.insert(state.messages, msg) end,
    }
    _G.CreateFrame = function(frameType, name, parent)
        local frame = createNamed(name, { frameType = frameType, parent = parent, textures = {},
            scriptSink = state.scripts })
        frame.RegisterEvent = function(_, event) state.events[event] = true end
        frame.CreateTexture = function(self, textureName, layer)
            local texture = helper.newFake({ name = textureName, layer = layer })
            table.insert(self.textures, texture)
            return texture
        end
        if frameType == "EditBox" then
            -- Text and keyboard focus. The client runs OnEditFocusLost when an edit box loses the focus.
            frame.text = ""
            frame.SetText = function(self, text) self.text = text end
            frame.GetText = function(self) return self.text end
            frame.SetFocus = function(self) state.focus = self end
            frame.HasFocus = function(self) return state.focus == self end
            frame.ClearFocus = function(self)
                if state.focus == self then
                    state.focus = nil
                    helper.runScript(self, "OnEditFocusLost")
                end
            end
        end
        table.insert(state.frames, frame)
        return frame
    end
    _G.GetAddOnMetadata = function() return "0.1.0" end
    -- The client exposes os.date as `date`. The stub returns a fixed time.
    _G.date = function() return helper.DATE end
    _G.SlashCmdList = {}
    _G.AtlasiumDB = nil
    _G.SLASH_ATLASIUM1 = nil

    -- Default minimap: a fake frame, 140 x 140 at the top-right of a 1024 x 768 screen, in
    -- MinimapCluster. SetMaskTexture and SetBlipTexture are recorded.
    local cluster = createNamed("MinimapCluster", { frameLevel = 1 })
    _G.Minimap = helper.newFrame({
        name = "Minimap",
        parent = cluster,
        frameLevel = 2,
        width = 140,
        height = 140,
        GetCenter = function() return 940, 680 end,
        GetZoom = function() return state.minimapZoom end,
        frameStrata = "LOW",
    })
    -- The Blizzard + button. Its OnClick script stands for Minimap_ZoomInClick.
    local zoomIn = createNamed("MinimapZoomIn")
    zoomIn:SetScript("OnClick", function() state.zoomInClicks = state.zoomInClicks + 1 end)
    zoomIn.calls.SetScript = nil
    _G.GetPlayerFacing = function() return state.facing end
    _G.IsIndoors = function() return state.indoors end
    _G.IsInInstance = function() return state.instance end
    _G.GetCVar = function(name) return state.cvars[name] end
    -- Blizzard's Minimap_ZoomIn and Minimap_ZoomOut click the + and - buttons. The stubs add
    -- 1 or -1 to `state.minimapZooms`.
    _G.Minimap_ZoomIn = function() table.insert(state.minimapZooms, 1) end
    _G.Minimap_ZoomOut = function() table.insert(state.minimapZooms, -1) end
    _G.UIParent = helper.newFake({
        GetWidth = function() return 1024 end,
        GetHeight = function() return 768 end,
        GetEffectiveScale = function() return state.uiScale end,
    })
    _G.GameTooltip = helper.newFake()
    _G.GetCursorPosition = function() return state.cursor.x, state.cursor.y end
    _G.ToggleFrame = function(frame) table.insert(state.toggled, frame) end
    _G.SetOverrideBinding = function(owner, _, key, command)
        state.bindingOwner = owner
        state.bindings[key] = command
    end
    _G.ClearOverrideBindings = function(owner)
        state.bindingOwner = owner
        for key in pairs(state.bindings) do
            state.bindings[key] = nil
        end
    end
    -- The client stores a click binding as "CLICK <button name>:<mouse button>".
    _G.SetOverrideBindingClick = function(owner, _, key, buttonName, mouseButton)
        state.bindingOwner = owner
        state.bindings[key] = "CLICK " .. buttonName .. ":" .. (mouseButton or "LeftButton")
    end
    _G.GetBindingFromClick = function(key) return state.binds[key] end
    _G.RunBinding = function(command) table.insert(state.ran, command) end
    _G.GetTime = function() return state.time end
    _G.GetCurrentKeyBoardFocus = function() return state.focus end
    _G.ChatFontNormal = helper.newFake({ name = "ChatFontNormal" })
    _G.geterrorhandler = function() return state.errorHandler end
    _G.seterrorhandler = function(fn)
        if not state.errorHandlerLocked then
            state.errorHandler = fn
        end
    end
    _G.AtlasiumDev = nil
    -- Blizzard does not define GetMinimapShape in 3.3.5. Specs set it to act as a shape add-on.
    _G.GetMinimapShape = nil

    _G.wipe = function(t)
        for key in pairs(t) do
            t[key] = nil
        end
        return t
    end
    installMapFrames()
    installMapApi(state)
    installHooksecurefunc(state)

    return state
end

return helper
