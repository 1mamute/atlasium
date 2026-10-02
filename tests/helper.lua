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

--- Install fresh WoW globals. Returns a table recording calls for assertions.
function helper.installWowStubs()
    local state = { messages = {}, events = {}, scripts = {} }

    _G.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, msg) table.insert(state.messages, msg) end,
    }
    _G.CreateFrame = function()
        return {
            RegisterEvent = function(_, event) state.events[event] = true end,
            SetScript = function(_, name, fn) state.scripts[name] = fn end,
        }
    end
    _G.GetAddOnMetadata = function() return "0.1.0" end
    _G.SlashCmdList = {}
    _G.AtlasiumDB = nil
    _G.SLASH_ATLASIUM1 = nil

    return state
end

return helper
