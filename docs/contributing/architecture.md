# Architecture

This page shows how the Atlasium code is organized.

## Folder layout

```
Atlasium/          the add-on; put this folder in Interface/AddOns
  Atlasium.toc     manifest (Interface 30300, saved variable AtlasiumDB)
  Util.lua         pure helper functions that do not call the WoW API
  Core.lua         event handling, saved-variable setup, the /atlasium command
  Log.lua          error and debug messages, in chat and in the saved log
  MinimapButton.lua  the minimap button and its position math
  Data/MinimapTileData.lua  minimap tile names and zone bounds (generated, do not edit)
  MinimapFarZoom.lua  minimap zoom past zoom 0: tile math and the tile layer
  MinimapZoom.lua  mouse wheel zoom on the minimap
  Data/Overlays.lua  the world map overlays of all zones (generated, do not edit)
  FogClear.lua     fog clearing on the world map, and its tile math
  MapNavigation.lua  zoom and drag on the world map
  Dev.lua          debug-mode aids for in-game checks: the map marker and fixed keys
tests/             busted specs and WoW stubs (not part of the add-on)
tools/             developer scripts, for example the generator of Data/MinimapTileData.lua
docs/              documentation
```

## Shared namespace

Each file starts with this line:

```lua
local ADDON_NAME, ns = ...
```

The game passes two values to each file in the `.toc`: the add-on name and one shared table. Each
module attaches itself to this table (`ns.Util`, `ns.Core`), so you do not need globals. The only
globals are the saved variable `AtlasiumDB`, the slash command and frame names that start with
`Atlasium` (see [Conventions](conventions.md#structure)).

## Load order

The game loads files in `.toc` order. A file can use only the modules listed above it. `Util.lua`
is first because `Core.lua` uses it. `MinimapButton.lua` comes after `Core.lua`, because it
registers `PLAYER_LOGIN` with `Core.RegisterEvent` when it loads. `Log.lua` comes right after
`Core.lua`, so every feature file can write to the log. `Data/Overlays.lua` comes
before `FogClear.lua`, because `FogClear.lua` reads `ns.Overlays`. `Data/MinimapTileData.lua` and
`MinimapFarZoom.lua` come before `MinimapZoom.lua`, because the wheel handler calls
`ns.MinimapFarZoom`.

Code that needs saved settings or other add-ons waits for an event. For example, the minimap
button is built on `PLAYER_LOGIN`: at that time `AtlasiumDB` is ready, and add-ons that define
`GetMinimapShape` have loaded.

## Hooks on Blizzard code

To run code after a Blizzard function, use `hooksecurefunc`. Do not replace Blizzard functions or
API globals: a replaced function changes the result for all add-ons and can taint Blizzard code.
For example, `FogClear.lua` hooks `WorldMapFrame_Update` when it loads. FrameXML loads before
add-ons, so the function exists. The map opens only after login, but the hook still checks
`ns.db`.

## Fog clearing data

`Data/Overlays.lua` comes from the 3.3.5a (build 12340) files `WorldMapOverlay.dbc` and
`WorldMapArea.dbc`. The client has no API for unexplored overlays, so the add-on ships this table.
The keys are the map names from `GetMapInfo()`. Overlay names keep the case from the game data, so
compare them without case (`FogClear.OverlayKey`). The data does not change, so do not edit the
file by hand. `tests/overlays_spec.lua` checks its shape.

## Minimap far zoom

Blizzard's minimap stops at zoom 0. Past zoom 0, `MinimapFarZoom.lua` draws the minimap terrain
tiles itself, on a layer that covers the Blizzard minimap.

### Data

`Data/MinimapTileData.lua` comes from the 3.3.5a files `md5translate.trs`, `Map.dbc`,
`WorldMapArea.dbc` and `DungeonMap.dbc`. `tools/gen_minimap_tiles.py` writes it (see
[Development](development.md#generate-the-minimap-tile-data)). Do not edit it by hand.

- `tiles[folder]["x_y"]` is the file name of `Textures\Minimap\<md5>.blp`. Only the four continent
  folders are in the data. A missing key is open sea.
- `zones[mapName]` has the tile folder and the zone bounds in world yards. The keys are the map
  names from `GetMapInfo()`, as in `ns.Overlays`. Continent maps are not in the table: they show
  some zones of other continents, so a position on them can point at the wrong folder.
- `floors[mapName][level]` has the bounds of a dungeon floor, for a zone that the world map shows
  only as floors (Dalaran).

`tests/minimap_tile_data_spec.lua` checks its shape and some known values.

### Math

The top half of the file is pure functions:

1. `ZoneToWorld` turns the map position from `GetPlayerMapPosition` into world yards. Left and right
   are world Y, top and bottom are world X.
2. `WorldToTile` turns world yards into tile units. A tile is 533.33 yards. The column grows east
   and the row grows south.
3. `GetDiameter` gives the minimap diameter at a far level: the zoom 0 diameter (466.67 yards
   outdoors, 300 indoors, as in HereBeDragons) times `farStep` per level.
4. `BuildSegments` covers the minimap shape with horizontal strips, 2 units high, that overlap by
   0.35 units. It splits each strip where it crosses a tile edge. Each piece shows its part of one
   tile through the 8 argument `SetTexCoord`, so the same code draws a rotated map.
   `GetRowExtent` gives the width of each strip, from the round quarters in `Util.GetRoundQuarters`
   (the same rule as the minimap button).

### Layer

The bottom half is the glue:

- The layer is a child of `Minimap` at the minimap level + 1. Add-on pins at a higher level stay
  above it. The Blizzard player arrow and the engine blips draw inside the minimap, so the layer
  covers them. The layer has its own arrow, turned with `GetPlayerFacing()`. It copies the Blizzard
  arrow, measured at zoom 0: 29 units wide, 1.8 units right of and 1.7 units above the minimap
  centre. The engine turns its arrow around the texture centre, so the offset does not turn.
- While the layer shows, the Blizzard frames on the minimap edge go above it, and back after.
  `MinimapBackdrop` (the border) goes to the minimap level + 5. The mail, battlefield, calendar
  (`GameTimeFrame`) and clock (`TimeManagerClockButton`) buttons go to + 6, so they stay above the
  border. The clock loads on demand, so the layer skips it when it is missing. Do not hide
  `Minimap`: that also hides the border and the pins of other add-ons.
- An `OnUpdate` script runs only while the layer shows. At most 30 times a second it reads the
  position, the facing, the shape and the size. It draws again only when one of them changed.
- The position comes from the current world map. When the world map is closed and the map has
  no position, the layer calls `SetMapToCurrentZone()`, at most once a second. While the world map
  is open, the layer keeps the last position.
- The textures come from a pool. A texture calls `SetTexture` only when its tile changes.
- In an instance, or without a position, the layer goes back to zoom 0.

`MinimapZoom.lua` sends the wheel to far zoom: wheel down at zoom 0 goes to the next far level
(`CanZoomOut`), and wheel up above level 0 goes back one level. On `PLAYER_LOGIN`, far zoom wraps
the `OnClick` script of `MinimapZoomIn`, so the + button also goes back one level.
`MINIMAP_UPDATE_ZOOM` with a zoom other than 0 leaves far zoom.

Known limits: pins of other add-ons keep their zoom 0 positions, and the engine blips (party,
tracking, herbs) do not show past zoom 0.

## Map navigation

`MapNavigation.lua` builds its frames the first time the map opens. It moves the Blizzard map frames
(`WorldMapDetailFrame`, `WorldMapBlobFrame`, `WorldMapButton` and `WorldMapPOIFrame`) into this tree:

```
WorldMapFrame
   viewport     ScrollFrame where the map was; it clips the map
     scrollChild  scrolled by the drag
       zoomFrame  scaled by the zoom; holds the Blizzard map frames
   overlay      unscaled, over the viewport; holds the zone name label
```

The main parts:

1. **Layout hooks.** Hooks on `SetPoint` and `SetScale` of the Blizzard frames move the viewport when
   Blizzard changes the map size. Frames that were anchored to the detail frame get the viewport instead.
2. **Zoom and drag.** The wheel sets a zoom target, and an `OnUpdate` driver eases to it. The zoom
   keeps the map point under the cursor fixed. A left drag scrolls the scroll child. A drag does not
   count as a click, so it does not open a zone.
3. **Icon pass.** Icons get a scale of `1/zoom` and offsets times `zoom`, so they keep their size and
   their map position. This covers units, landmarks, quest POIs and the swap button of a completed
   quest. `ResolveRaw` tells a Blizzard value from our own value, so the change never compounds.
4. **Quest blob.** The blob frame fixes the blob on the screen when it draws it. After each zoom or
   scroll, the module clears and draws the selected blob again.
5. **Combat.** The blob frame can be protected, and a protected frame makes its parents protected in
   combat. So the blob leaves the tree before combat and comes back after. A ScrollFrame draws its
   frames in the order they joined it, so `WorldMapButton` and `WorldMapPOIFrame` join again after
   the blob. Else the blob covers the POI icons.

The zoom goes back to 1x when the map closes or the map, floor or layout changes. At 1x the map
looks the same as without Atlasium.

## Log

`Log.lua` writes error and debug messages. `Log.Error(...)` and `Log.Debug(...)` join their
arguments with spaces, like `print`. Each message goes to chat with an `[ERROR]` or `[DEBUG]` tag.
It also goes to `AtlasiumDB.log` as one string with the time, for example
`"2026-10-04 12:34:56 [ERROR] msg"`.

- Errors are always written.
- Debug messages are written only while debug mode is on (`/atlasium debug`).
- The log keeps the newest 200 entries (`Log.MAX_ENTRIES`). A new entry over the cap drops the
  oldest one.
- Before `ADDON_LOADED` the saved variables do not exist. Then an error goes only to chat, and a
  debug message is dropped.

The log does not catch Lua errors. Those still go to the Blizzard error handler.

## Keep code testable

Split code into two kinds:

- **Pure logic** takes plain values and returns plain values. It does not call the WoW API (see
  `Util.lua`). Tests call it directly.
- **Glue** creates frames, registers events and prints to the chat (see `Core.lua`). Keep it small.
  Tests check it with the stubs in `tests/helper.lua`.

The smaller the glue, the less you have to verify by hand in the game.

## Planned modules

Map notes, TomTom integration, Questie integration and party sync (see the
[project README](../../README.md)) each get their own file in `Atlasium/` and an entry in the
`.toc`. Integrations with other add-ons are optional: check that the other add-on is loaded before
you call it, so Atlasium still works without it.
