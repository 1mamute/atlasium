# Architecture

This page shows how the Atlasium code is organized.

## Folder layout

```
Atlasium/          the add-on; put this folder in Interface/AddOns
  Atlasium.toc     manifest (Interface 30300, saved variable AtlasiumDB)
  Util.lua         pure helper functions that do not call the WoW API
  Localization.lua  English and Brazilian Portuguese strings and live language selection
  Core.lua         event handling, saved-variable setup, the /atlasium command
  Log.lua          error and debug messages, in chat and in the saved log
  MinimapButton.lua  the minimap button and its position math
  Data/MinimapTileData.lua  minimap tile names and zone bounds (generated, do not edit)
  MinimapTiles.lua  terrain at every minimap zoom: tile math, texture swaps and the tile layer
  MinimapZoom.lua  mouse wheel zoom on the minimap
  Data/Overlays.lua  the world map overlays of all zones (generated, do not edit)
  FogClear.lua     fog clearing on the world map, and its tile math
  MapNavigation.lua  zoom and drag on the world map
  Dev.lua          debug-mode aids for in-game checks: the map marker, fixed keys, AtlasiumDev
  DevConsole.lua   debug-mode dev console: runs Lua from tools/wow-dev.ps1, shows the result
  Settings.lua     shared validation and feature setters for configuration edits
  SettingsUI.lua   shared controls in the native window and Interface Options panel
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
globals are the saved variable `AtlasiumDB`, the slash command, frame names that start with
`Atlasium` and, in debug mode only, `AtlasiumDev` (see [Conventions](conventions.md#structure)).

## Load order

The game loads files in `.toc` order. A file can use only the modules listed above it. `Util.lua`
is first because `Core.lua` uses it. `MinimapButton.lua` comes after `Core.lua`, because it
registers `PLAYER_LOGIN` with `Core.RegisterEvent` when it loads. `Log.lua` comes right after
`Core.lua`, so every feature file can write to the log. `Data/Overlays.lua` comes
before `FogClear.lua`, because `FogClear.lua` reads `ns.Overlays`. `Data/MinimapTileData.lua` and
`MinimapTiles.lua` come before `MinimapZoom.lua`, because the wheel handler calls
`ns.MinimapTiles`.

Code that needs saved settings or other add-ons waits for an event. For example, the minimap
button is built on `PLAYER_LOGIN`: at that time `AtlasiumDB` is ready, and add-ons that define
`GetMinimapShape` have loaded.

## Settings and localization

`Localization.lua` loads before `Core.lua`. It resolves text at use time from `ns.db.language`.
English is the default and fallback. Keep command keywords and developer logs in English.

`Settings.lua` loads after the feature modules. Its `Get`, `Set` and `ResetDefaults` functions
share configuration behavior between slash commands and UI controls. Invalid edits leave state
unchanged. New numeric limits apply to edits; loading existing preferences does not rewrite them.

`SettingsUI.lua` registers one Interface Options panel on `PLAYER_LOGIN`. It creates the standalone
dialog on first use. Both views use the same content builder. Refresh suppresses control callbacks,
so showing a view cannot apply changes. The views apply edits immediately and keep them on close.
Defaults use feature setters and preserve the saved log.

The minimap button resolves `ns.SettingsUI` when clicked, after all manifest files load. Its drag
handler refreshes the position sliders. Language edits refresh both views and visible tooltips.

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

## Minimap tiles

`MinimapTiles.lua` draws raw terrain under the Blizzard minimap at every zoom level.
A transparent mask hides the Blizzard ground. The client still draws the player arrow and blips.
Outdoor rendering is checked in the client.

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
3. `GetDiameter` uses the outdoor diameter for Blizzard zoom 0 through 5: 466.67, 400, 333.33,
   266.67, 200 and 133.33 yards.
4. `BuildSegments` covers the minimap shape with horizontal strips, 2 units high, that overlap by
   0.35 units. It splits each strip where it crosses a tile edge. Each piece shows its part of one
   tile through the 8 argument `SetTexCoord`, so the same code draws a rotated map.
   `GetRowExtent` gives the width of each strip, from the round quarters in `Util.GetRoundQuarters`
   (the same rule as the minimap button).

### Layer

The bottom half is the glue:

- The layer is a child of `MinimapCluster`, anchored to `Minimap`, at the minimap level minus 1.
  It uses the same frame strata. It has no mouse input and no separate player arrow.
- In 3.3.5a, the world render covers ordinary textures in `BACKGROUND` strata.
  The engine minimap still draws there. While tiles draw, Atlasium raises a background minimap
  and its underlay to `LOW`. Fallback and tiles off restore the original strata.
  A secure hook preserves later strata choices from other add-ons.
- `SetMaskTexture` uses `Interface\WORLDMAP\Silithus\pixelfix1` to hide the Blizzard ground.
- A secure hook remembers mask paths set by other add-ons. While the mask is transparent,
  Atlasium reapplies transparency. When it stops drawing, it restores the remembered path.
  The default is `Textures\MinimapMask`. Engine blip textures stay untouched.
  A mask set before the hooks load is a known compatibility limit.
- `PLAYER_ENTERING_WORLD` reapplies active transparent textures after world loading.
  The engine can reset them without calling the Lua setters, so a state-change check alone
  does not keep the ground hidden after login or reload.
- An `OnUpdate` script runs while tiles are enabled, including during fallback.
  At most 30 times a second it reads position, facing, shape, size and Blizzard zoom.
  It draws again only when the view changes. Tile colors have no shade or lighting tint.
- The position comes from the current world map. When the world map is closed and the map has
  no position, the layer calls `SetMapToCurrentZone()`, at most once a second. While the world map
  is open, the layer keeps the last position.
- The textures come from a pool. A texture calls `SetTexture` only when its tile changes.
- In an instance, indoors, in a WMO city, or without a position, the layer hides.
  WMO city map names are `Ogrimmar`, `ThunderBluff`, `Darnassis`, `TheExodar` and `Ironforge`.
  `IsIndoorZoom` compares the indoor and outdoor zoom CVars with the current zoom.
- Debug alignment shows the tiles above the minimap at half alpha and keeps the Blizzard mask.
  `/atlasium minimap align on|off` controls it at the current Blizzard zoom.

`MinimapZoom.lua` sends each wheel notch through Blizzard's zoom buttons, which enforce the
six native zoom levels. The tile renderer keeps the native button handlers unchanged.
`MINIMAP_UPDATE_ZOOM` redraws immediately.
Zone changes check fallback immediately after updating the current map.

Settings live in `minimapTiles`: `enabled`.
`/atlasium minimap tiles off` restores the Blizzard mask. Wheel zoom has its own setting;
turning it off keeps custom terrain enabled.

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

In debug mode the log also catches Lua errors. `Log.SetErrorCapture` puts a handler in front of the
current error handler (`seterrorhandler`):

- An error from a file in `AddOns\Atlasium\` goes to `Log.Error` as `Lua error: <message>`.
  `Log.errorCount` and `Log.lastError` count and keep it for the health report.
- Every error, also from other add-ons, then goes on to the previous handler, so the Blizzard error
  frame or BugGrabber still shows it.
- The capture starts on `ADDON_LOADED` when debug mode is saved as on, so errors in `PLAYER_LOGIN`
  handlers count too. `Dev.Update` turns it on and off with debug mode.
- When debug mode goes off, the previous handler comes back, but only if no other add-on set a
  handler after Atlasium. Else the Atlasium handler stays in the chain and only passes errors on.
- BugGrabber makes `seterrorhandler` do nothing. Then the capture registers for its
  `BugGrabber_BugGrabbed` and `BugGrabber_BugGrabbedAgain` callbacks instead. BugGrabber writes the
  path as `Atlasium-<version>\<file>`, so `Log.IsAddonError` accepts that form too. It reads only the
  first line, because the stack lines name other add-ons. BugGrabber gets its callbacks only when
  CallbackHandler-1.0 is loaded, often after Atlasium. So the capture tries again on `PLAYER_LOGIN`,
  and errors before that go only to BugGrabber.
- If another add-on blocks `seterrorhandler` and BugGrabber has no callbacks on `PLAYER_LOGIN`, the
  capture stays off, and a debug message says so once.
- `Log.GetErrorCapture()` returns `handler`, `BugGrabber` or `off`. The health report shows it, so
  `errors = 0` with the capture off does not read as a clean load.

Without debug mode, Lua errors go only to the Blizzard error handler.

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
