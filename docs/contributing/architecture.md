# Architecture

This page shows how the Atlasium code is organized.

## Folder layout

```
Atlasium/          the add-on; put this folder in Interface/AddOns
  Atlasium.toc     manifest (Interface 30300, saved variable AtlasiumDB)
  Util.lua         pure helper functions that do not call the WoW API
  Core.lua         event handling, saved-variable setup, the /atlasium command
  MinimapButton.lua  the minimap button and its position math
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
registers `PLAYER_LOGIN` with `Core.RegisterEvent` when it loads.

Code that needs saved settings or other add-ons waits for an event. For example, the minimap
button is built on `PLAYER_LOGIN`: at that time `AtlasiumDB` is ready, and add-ons that define
`GetMinimapShape` have loaded.

## Keep code testable

Split code into two kinds:

- **Pure logic** takes plain values and returns plain values. It does not call the WoW API (see
  `Util.lua`). Tests call it directly.
- **Glue** creates frames, registers events and prints to the chat (see `Core.lua`). Keep it small.
  Tests check it with the stubs in `tests/helper.lua`.

The smaller the glue, the less you have to verify by hand in the game.

## Planned modules

Map navigation, notes, TomTom integration, Questie integration and party sync (see the
[project README](../../README.md)) each get their own file in `Atlasium/` and an entry in the
`.toc`. Integrations with other add-ons are optional: check that the other add-on is loaded before
you call it, so Atlasium still works without it.
