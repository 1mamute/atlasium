-- Pure helpers with no WoW API dependency, so they can be unit tested outside the client.
local _, ns = ...

local Util = {}
ns.Util = Util

--- Recursively copy any key missing from `target` out of `defaults`.
-- Existing values in `target` are never overwritten. Returns `target`.
function Util.CopyDefaults(defaults, target)
    target = target or {}
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            Util.CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

--- Format normalized map coordinates (0..1) as "12.3, 45.6".
function Util.FormatCoords(x, y)
    return string.format("%.1f, %.1f", x * 100, y * 100)
end

--- Split a slash command message into a lowercase command and the remaining text.
function Util.SplitCommand(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    return cmd:lower(), rest
end
