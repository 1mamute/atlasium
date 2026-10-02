-- Minimal WoW client stubs and an addon file loader for busted specs.
-- The client passes (addonName, namespace) as varargs to every file in the .toc;
-- loadAddonFile mimics that.

local helper = {}

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
function helper.newFake(fake)
    fake = fake or {}
    fake.calls = {}
    return setmetatable(fake, {
        __index = function(self, key)
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

-- Names of frames created through the CreateFrame stub, cleared on the next installWowStubs().
local namedFrames = {}

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
        -- The current world map: its file name and the texture paths of the explored overlays.
        map = { name = nil, overlays = {} },
    }

    for name in pairs(namedFrames) do
        _G[name] = nil
        namedFrames[name] = nil
    end

    _G.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, msg) table.insert(state.messages, msg) end,
    }
    _G.CreateFrame = function(frameType, name, parent)
        local frame = helper.newFake({ frameType = frameType, name = name, parent = parent, shown = true,
            ownScripts = {}, textures = {} })
        frame.RegisterEvent = function(_, event) state.events[event] = true end
        frame.SetScript = function(self, script, fn)
            self.ownScripts[script] = fn
            state.scripts[script] = fn
        end
        frame.GetScript = function(self, script) return self.ownScripts[script] end
        frame.GetName = function(self) return self.name end
        frame.GetParent = function(self) return self.parent end
        frame.Show = function(self) self.shown = true end
        frame.Hide = function(self) self.shown = false end
        frame.IsShown = function(self) return self.shown end
        frame.CreateTexture = function(self, textureName, layer)
            local texture = helper.newFake({ name = textureName, layer = layer })
            table.insert(self.textures, texture)
            return texture
        end
        table.insert(state.frames, frame)
        if name then
            _G[name] = frame
            namedFrames[name] = true
        end
        return frame
    end
    _G.GetAddOnMetadata = function() return "0.1.0" end
    _G.SlashCmdList = {}
    _G.AtlasiumDB = nil
    _G.SLASH_ATLASIUM1 = nil

    -- Default minimap: 140 x 140 at the top-right of a 1024 x 768 screen.
    _G.Minimap = helper.newFake({
        GetWidth = function() return 140 end,
        GetHeight = function() return 140 end,
        GetCenter = function() return 940, 680 end,
        GetEffectiveScale = function() return 1 end,
    })
    _G.UIParent = helper.newFake({
        GetWidth = function() return 1024 end,
        GetHeight = function() return 768 end,
    })
    _G.GameTooltip = helper.newFake()
    _G.WorldMapFrame = helper.newFake()
    _G.GetCursorPosition = function() return state.cursor.x, state.cursor.y end
    _G.ToggleFrame = function(frame) table.insert(state.toggled, frame) end
    -- Blizzard does not define GetMinimapShape in 3.3.5. Specs set it to act as a shape add-on.
    _G.GetMinimapShape = nil

    _G.hooksecurefunc = function(name, fn) state.hooks[name] = fn end
    _G.wipe = function(t)
        for key in pairs(t) do
            t[key] = nil
        end
        return t
    end
    _G.GetMapInfo = function() return state.map.name end
    _G.GetNumMapOverlays = function() return #state.map.overlays end
    _G.GetMapOverlayInfo = function(i) return state.map.overlays[i] end
    local detailTextures = {}
    _G.WorldMapDetailFrame = helper.newFake({
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

    return state
end

return helper
