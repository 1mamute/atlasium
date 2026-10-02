local helper = require("tests.helper")

describe("Overlays data", function()
    local overlays

    setup(function()
        overlays = helper.loadAddonFile("Atlasium/Data/Overlays.lua", helper.newNamespace()).Overlays
    end)

    local function isWholeNumber(value)
        return type(value) == "number" and value == math.floor(value)
    end

    it("has 61 zones and 886 overlays", function()
        local zones, total = 0, 0
        for _, zone in pairs(overlays) do
            zones = zones + 1
            for _ in pairs(zone) do
                total = total + 1
            end
        end
        assert.equals(61, zones)
        assert.equals(886, total)
    end)

    it("has 4 whole numbers in each entry, with a size above 0", function()
        for mapName, zone in pairs(overlays) do
            for name, entry in pairs(zone) do
                local where = mapName .. "." .. name
                assert.equals(4, #entry, where)
                for i = 1, 4 do
                    assert.is_true(isWholeNumber(entry[i]), where)
                end
                assert.is_true(entry[1] > 0 and entry[2] > 0, where)
                assert.is_true(entry[3] >= 0 and entry[4] >= 0, where)
            end
        end
    end)

    it("keeps each overlay inside the 1024 x 768 map", function()
        for mapName, zone in pairs(overlays) do
            for name, entry in pairs(zone) do
                local where = mapName .. "." .. name
                assert.is_true(entry[3] + entry[1] <= 1024, where)
                assert.is_true(entry[4] + entry[2] <= 768, where)
            end
        end
    end)

    it("has the known values for Chillwind Point", function()
        assert.same({ 350, 370, 626, 253 }, overlays.Alterac.CHILLWINDPOINT)
    end)
end)
