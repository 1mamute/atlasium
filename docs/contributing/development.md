# Development

This page explains how to set up your environment, run the checks and add code.

## 1. Install the add-on in the game

Link the `Atlasium` folder into the WoW add-ons folder, so each edit shows in the game without a
copy. Use PowerShell as administrator, or turn on Developer Mode.

```powershell
New-Item -ItemType SymbolicLink `
  -Path "<WoW folder>\Interface\AddOns\Atlasium" `
  -Target "<path to this repo>\Atlasium"
```

Replace `<WoW folder>` with your 3.3.5a installation folder and `<path to this repo>` with the
folder where you cloned Atlasium.

After each change, type `/reload` in the game. Type `/atlasium version` to check that the add-on
loaded.

## 2. Install the tools

You need three tools:

- Lua 5.1, the version the game client uses.
- LuaRocks
- [busted](https://lunarmodules.github.io/busted/) for tests.
- [luacheck](https://github.com/lunarmodules/luacheck) for lint.

Install busted and luacheck with LuaRocks:

```
luarocks install busted
luarocks install luacheck
```

## 3. Run the checks

From the root of the repository:

```
luacheck Atlasium tests    # lint
busted                     # run all specs (settings are in .busted)
```

CI runs the same two commands on every push, so check that they pass on your computer first.

## Add a file

1. Create `Atlasium/Foo.lua` and start it with `local _, ns = ...`.
2. Add it to `Atlasium/Atlasium.toc`, after the files it depends on.
3. Add each new WoW API function it uses to `read_globals` in `.luacheckrc`. If the specs need the
   function, add a stub in `tests/helper.lua`.
4. Create `tests/foo_spec.lua`.

Before you use a WoW function, event or widget method, check that it exists in 3.3.5a. Many modern
APIs do not.

## Generate the minimap tile data

`Atlasium/Data/MinimapTileData.lua` comes from the game files. The game data does not change, so you
need this only if you change the generator. CI does not run it.

1. Install Python 3 and the MPQ reader `mpyq`:

   ```
   pip install mpyq
   ```

2. From the root of the repository, run the generator with your 3.3.5a folder:

   ```
   python tools/gen_minimap_tiles.py "<WoW folder>"
   ```

   Without the folder, the script reads `ATLASIUM_WOW_DIR` from `.env` in the repository root.

3. The script prints the MPQ that each file came from, and the counts of zones and tiles. It
   writes the data file again.
4. Run `busted tests/minimap_tile_data_spec.lua` to check the result.

Next: [Testing](testing.md) and [Conventions](conventions.md).
