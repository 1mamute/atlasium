-- Pure helpers with no WoW API dependency, so they can be unit tested outside the client.
local _, ns = ...

local Util = {}
ns.Util = Util

-- Round quarters for each minimap shape, from the shape name: CORNER-<corner> is round only at that
-- corner, SIDE-<side> on that half, TRICORNER-<corner> everywhere except the opposite corner.
-- Do not check this against Questie's 3.3.5 LibDBIcon (Rev 15): its table swaps several shapes.
local ROUND_QUARTERS = {
    ROUND = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true },
    SQUARE = {},
    ["CORNER-TOPLEFT"] = { TOPLEFT = true },
    ["CORNER-TOPRIGHT"] = { TOPRIGHT = true },
    ["CORNER-BOTTOMLEFT"] = { BOTTOMLEFT = true },
    ["CORNER-BOTTOMRIGHT"] = { BOTTOMRIGHT = true },
    ["SIDE-LEFT"] = { TOPLEFT = true, BOTTOMLEFT = true },
    ["SIDE-RIGHT"] = { TOPRIGHT = true, BOTTOMRIGHT = true },
    ["SIDE-TOP"] = { TOPLEFT = true, TOPRIGHT = true },
    ["SIDE-BOTTOM"] = { BOTTOMLEFT = true, BOTTOMRIGHT = true },
    ["TRICORNER-TOPLEFT"] = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true },
    ["TRICORNER-TOPRIGHT"] = { TOPLEFT = true, TOPRIGHT = true, BOTTOMRIGHT = true },
    ["TRICORNER-BOTTOMLEFT"] = { TOPLEFT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true },
    ["TRICORNER-BOTTOMRIGHT"] = { TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true },
}

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

--- Join the arguments with spaces, like `print`. Each argument goes through `tostring`, so nil and
-- numbers are safe, and a nil in the middle still counts.
function Util.JoinArgs(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    return table.concat(parts, " ")
end

--- Append `entry` to `list`, then drop the oldest entries until `list` holds at most `max`.
function Util.AppendCapped(list, entry, max)
    table.insert(list, entry)
    while #list > max do
        table.remove(list, 1)
    end
end

--- Return the set of round quarters (TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT) for a
-- GetMinimapShape() name. An unknown or nil `shape` counts as "ROUND".
function Util.GetRoundQuarters(shape)
    return ROUND_QUARTERS[shape] or ROUND_QUARTERS.ROUND
end
