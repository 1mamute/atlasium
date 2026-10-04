"""Generate Atlasium/Data/MinimapTileData.lua from the 3.3.5a client files.

Usage: python tools/gen_minimap_tiles.py [WoW folder]

Without an argument the script reads ATLASIUM_WOW_DIR from .env in the repo root.
Requires Python 3 and mpyq (pip install mpyq).
"""
import os
import re
import struct
import sys

import mpyq

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, "Atlasium", "Data", "MinimapTileData.lua")

# Tile folders of the four continents (Map.dbc Directory). Other maps fall back to Blizzard.
FOLDERS = ("Azeroth", "Kalimdor", "Expansion01", "Northrend")


def read_wow_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    env = os.path.join(ROOT, ".env")
    if os.path.exists(env):
        with open(env, encoding="utf-8") as f:
            for line in f:
                key, _, value = line.strip().partition("=")
                if key == "ATLASIUM_WOW_DIR" and value:
                    return value
    sys.exit("Give the WoW folder as an argument or set ATLASIUM_WOW_DIR in .env")


def patch_key(name):
    # patch-3.MPQ before patch-2.MPQ before patch.MPQ (newest first, as the client loads them).
    match = re.match(r"patch(?:-[a-zA-Z]{4})?-?(\w*)\.mpq$", name, re.IGNORECASE)
    suffix = match.group(1) if match else ""
    return (len(suffix) > 0, suffix.zfill(4))


def archive_order(data_dir):
    """MPQ paths, newest first. The first archive that has a file wins."""
    locales = [d for d in os.listdir(data_dir)
               if re.fullmatch(r"[a-z]{2}[A-Z]{2}", d) and os.path.isdir(os.path.join(data_dir, d))]
    if len(locales) != 1:
        sys.exit("Expected one locale folder in %s, found %s" % (data_dir, locales or "none"))
    loc = locales[0]
    loc_dir = os.path.join(data_dir, loc)

    def patches(folder):
        names = [n for n in os.listdir(folder) if n.lower().startswith("patch") and n.lower().endswith(".mpq")]
        return [os.path.join(folder, n) for n in sorted(names, key=patch_key, reverse=True)]

    order = patches(loc_dir) + patches(data_dir)
    for folder, name in [
        (loc_dir, "lichking-locale-%s.MPQ" % loc), (data_dir, "lichking.MPQ"),
        (loc_dir, "expansion-locale-%s.MPQ" % loc), (data_dir, "expansion.MPQ"),
        (loc_dir, "locale-%s.MPQ" % loc), (data_dir, "common-2.MPQ"), (data_dir, "common.MPQ"),
    ]:
        path = os.path.join(folder, name)
        if os.path.exists(path):
            order.append(path)
    return order


class Archives:
    def __init__(self, paths):
        self.archives = [(p, mpyq.MPQArchive(p, listfile=False)) for p in paths]

    def read(self, name):
        for path, archive in self.archives:
            data = archive.read_file(name)
            if data:
                print("%s from %s" % (name, os.path.basename(path)))
                return data
        sys.exit("%s not found in the client MPQs" % name)


def read_dbc(data):
    """Rows as tuples of ints, with a float reader and a string reader for the same row."""
    magic, count, fields, size, _ = struct.unpack_from("<4s4I", data)
    if magic != b"WDBC":
        sys.exit("Not a DBC file")
    strings = data[20 + count * size:]
    rows = []
    for i in range(count):
        record = data[20 + i * size:20 + (i + 1) * size]
        rows.append((struct.unpack_from("<%di" % fields, record), struct.unpack_from("<%df" % fields, record)))

    def text(offset):
        return strings[offset:strings.index(b"\0", offset)].decode("utf-8")
    return rows, text


def read_tiles(archives):
    tiles = {folder: {} for folder in FOLDERS}
    text = archives.read("Textures\\Minimap\\md5translate.trs").decode("utf-8")
    for line in text.splitlines():
        if line.startswith("dir:") or "\t" not in line:
            continue
        name, md5 = line.split("\t")
        folder, _, file = name.partition("\\")
        match = re.fullmatch(r"map(\d+)_(\d+)\.blp", file, re.IGNORECASE)
        if folder in tiles and match:
            tiles[folder]["%d_%d" % (int(match.group(1)), int(match.group(2)))] = md5[:-4] if md5.endswith(".blp") else md5
    return tiles


def read_areas(archives):
    rows, text = read_dbc(archives.read("DBFilesClient\\Map.dbc"))
    folders = {ints[0]: text(ints[1]) for ints, _ in rows}  # ID, Directory
    continent_maps = {map_id: folder for map_id, folder in folders.items() if folder in FOLDERS}

    # DungeonMap: ID, MapID, FloorIndex, MinY, MaxY, MinX, MaxX, ParentWorldMapID.
    dungeon_rows, _ = read_dbc(archives.read("DBFilesClient\\DungeonMap.dbc"))
    dungeon = {ints[0]: (ints, floats) for ints, floats in dungeon_rows}

    # WorldMapArea: ID, MapID, AreaID, AreaName, LocLeft, LocRight, LocTop, LocBottom, DisplayMapID,
    # DefaultDungeonFloor, ParentWorldMapID. Left/Right are world Y, Top/Bottom are world X.
    rows, text = read_dbc(archives.read("DBFilesClient\\WorldMapArea.dbc"))
    zones, floors = {}, {}
    for ints, floats in rows:
        folder = continent_maps.get(ints[1])
        # Skip the continent maps (AreaID 0): they show some zones of other maps (Eversong on the
        # Eastern Kingdoms map), so a position on them can belong to another tile folder.
        if not folder or ints[2] == 0:
            continue
        name = text(ints[3])
        if name in zones:
            sys.exit("Two continent zones named %s" % name)
        bounds = floats[4:8]
        if any(bounds):
            zones[name] = [folder] + list(bounds)
        elif ints[9] > 0:
            # A zone drawn only on dungeon floors (Dalaran): take the floors that share the map and
            # parent of its default floor.
            default = dungeon[ints[9]][0]
            zones[name] = [folder]
            floors[name] = {}
            for d_ints, d_floats in dungeon.values():
                if d_ints[1] == default[1] and d_ints[7] == default[7]:
                    min_y, max_y, min_x, max_x = d_floats[3:7]
                    floors[name][d_ints[2]] = [max_y, min_y, max_x, min_x]
    return zones, floors


def number(value):
    text = "%.3f" % value
    text = text.rstrip("0").rstrip(".")
    return "0" if text == "-0" else text


def write(zones, floors, tiles):
    out = [
        "-- Generated by tools/gen_minimap_tiles.py from the 3.3.5a (build 12340) md5translate.trs,",
        "-- Map.dbc, WorldMapArea.dbc and DungeonMap.dbc. Do not edit by hand.",
        "-- Game data (c) Blizzard Entertainment.",
        "local _, ns = ...",
        "",
        "-- zones[mapFileName] = { tileFolder, left, right, top, bottom }: bounds in world yards; left and",
        "-- right are world Y, top and bottom are world X. mapFileName matches GetMapInfo(). A zone drawn",
        "-- only on dungeon floors (Dalaran) has no bounds; floors[mapFileName][level] has them instead.",
        "-- tiles[tileFolder][\"x_y\"] = md5 name of Textures\\Minimap\\<md5>.blp (mapX_Y, X grows east and",
        "-- Y grows south). A missing key is open sea.",
        "ns.MinimapTileData = {",
        "    zones = {",
    ]
    for name in sorted(zones):
        zone = zones[name]
        values = ['"%s"' % zone[0]] + [number(v) for v in zone[1:]]
        out.append('        ["%s"] = { %s },' % (name, ", ".join(values)))
    out += ["    },", "    floors = {"]
    for name in sorted(floors):
        out.append('        ["%s"] = {' % name)
        for level in sorted(floors[name]):
            out.append("            [%d] = { %s }," % (level, ", ".join(number(v) for v in floors[name][level])))
        out.append("        },")
    out += ["    },", "    tiles = {"]
    for folder in FOLDERS:
        out.append("        %s = {" % folder)
        for key in sorted(tiles[folder], key=lambda k: tuple(int(n) for n in k.split("_"))):
            out.append('            ["%s"] = "%s",' % (key, tiles[folder][key]))
        out.append("        },")
    out += ["    },", "}", ""]
    with open(OUTPUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))


def main():
    data_dir = os.path.join(read_wow_dir(), "Data")
    archives = Archives(archive_order(data_dir))
    tiles = read_tiles(archives)
    zones, floors = read_areas(archives)
    write(zones, floors, tiles)
    counts = ", ".join("%s %d" % (folder, len(tiles[folder])) for folder in FOLDERS)
    print("Wrote %s: %d zones, %d floor zones, tiles %s" % (OUTPUT, len(zones), len(floors), counts))


if __name__ == "__main__":
    main()
