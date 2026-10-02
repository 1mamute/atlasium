# Architecture

This page shows how the Atlasium code is organized. Use it to find where new code belongs.

## Folder layout

```
Atlasium/          the add-on; put this folder in Interface/AddOns
  Atlasium.toc     manifest (Interface 30300, saved variable AtlasiumDB)
  Util.lua         pure helper functions; they do not call the WoW API
  Core.lua         event handling, saved-variable setup, the /atlasium command
tests/             busted specs and WoW stubs (not part of the add-on)
docs/              these pages
```

## Shared namespace

Each file starts with this line:

```lua
local ADDON_NAME, ns = ...
```

The game gives each file in the `.toc` two values: the add-on name and one shared table. Each
module attaches itself to this table (`ns.Util`, `ns.Core`). Do not create globals. The only
globals are the saved variable `AtlasiumDB` and the slash command.

## Load order

The game loads the files in the order of the `.toc`. A file can use only the modules that are
above it in the `.toc`. `Util.lua` is first because `Core.lua` uses it.

## Make code testable

Put code in one of two groups:

- **Pure logic.** A pure function receives plain values and returns plain values. It does not call
  the WoW API (see `Util.lua`). Tests call it directly.
- **Glue.** Glue code creates frames, registers events and prints to the chat (see `Core.lua`).
  Keep the glue small. Tests check it with the stubs in `tests/helper.lua`.

Small glue means less manual work in the game.

## Planned modules

These functions are planned: map navigation, notes, TomTom integration, Questie integration and
party sync (see the [project README](../../README.md)). Put each one in its own file in `Atlasium/`.
Add each file to the `.toc`. An integration with another add-on is optional. Before you call the
other add-on, make sure that it is loaded. Then Atlasium works without it.
