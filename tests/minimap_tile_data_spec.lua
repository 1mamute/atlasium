local helper = require("tests.helper")

describe("MinimapTileData", function()
    local data

    setup(function()
        data = helper.loadAddonFile("Atlasium/Data/MinimapTileData.lua", helper.newNamespace()).MinimapTileData
    end)

    local function count(t)
        local n = 0
        for _ in pairs(t) do
            n = n + 1
        end
        return n
    end

    it("has the tiles of the four continents", function()
        assert.equals(4, count(data.tiles))
        assert.equals(687, count(data.tiles.Azeroth))
        assert.equals(1018, count(data.tiles.Kalimdor))
        assert.equals(800, count(data.tiles.Expansion01))
        assert.equals(1131, count(data.tiles.Northrend))
    end)

    it("keys each tile x_y inside the 64 x 64 grid, with an md5 name", function()
        for folder, tiles in pairs(data.tiles) do
            for key, md5 in pairs(tiles) do
                local x, y = key:match("^(%d+)_(%d+)$")
                assert.is_truthy(x, folder .. " " .. key)
                assert.is_true(tonumber(x) < 64 and tonumber(y) < 64, folder .. " " .. key)
                assert.matches("^%x+$", md5)
                assert.equals(32, #md5)
            end
        end
    end)

    it("has the known Azeroth tiles around Elwynn", function()
        assert.equals("b53fb722839e0c7a81bae678ea694f5c", data.tiles.Azeroth["32_48"])
        assert.equals("227be700afabf0d01103d054cc23f8cc", data.tiles.Azeroth["30_46"])
        assert.equals("82413a3dba665af0a1020360213e1559", data.tiles.Azeroth["35_51"])
        assert.equals("67b0e188191cab59eb9136c093997ba3", data.tiles.Azeroth["33_49"])
    end)

    it("gives each zone a tile folder and either 4 bounds or floors", function()
        for name, zone in pairs(data.zones) do
            assert.is_table(data.tiles[zone[1]], name)
            if #zone == 1 then
                assert.is_table(data.floors[name], name)
            else
                assert.equals(5, #zone, name)
                assert.is_true(zone[2] > zone[3] and zone[4] > zone[5], name)
            end
        end
    end)

    it("has the known bounds of Elwynn", function()
        assert.same({ "Azeroth", 1535.417, -1935.417, -7939.583, -10254.166 }, data.zones.Elwynn)
    end)

    it("has the two Dalaran floors", function()
        assert.same({ "Northrend" }, data.zones.Dalaran)
        assert.equals(2, count(data.floors.Dalaran))
        for level, floor in pairs(data.floors.Dalaran) do
            assert.equals(4, #floor, level)
            assert.is_true(floor[1] > floor[2] and floor[3] > floor[4], level)
        end
    end)
end)
