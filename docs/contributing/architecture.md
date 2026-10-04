# Architecture

This page shows how the Atlasium code is organized.

## Folder layout

```
Atlasium/          the add-on; put this folder in Interface/AddOns
  Atlasium.toc     manifest (Interface 30300, saved variable AtlasiumDB)
  Util.lua         pure helper functions that do not call the WoW API
  Core.lua         event handling, saved-variable setup, the /atlasium command
  MinimapButton.lua  the minimap button and its position math
  Data/Overlays.lua  the world map overlays of all zones (generated, do not edit)
  FogClear.lua     fog clearing on the world map, and its tile math
  MapNavigation.lua  zoom and drag on the world map
  Dev.lua          debug-mode aids for in-game checks: the map marker and fixed keys
tests/             busted specs and WoW stubs (not part of the add-on)
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
registers `PLAYER_LOGIN` with `Core.RegisterEvent` when it loads. `Data/Overlays.lua` comes
before `FogClear.lua`, because `FogClear.lua` reads `ns.Overlays`.

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
