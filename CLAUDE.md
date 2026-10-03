# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

Atlasium is a map add-on for **World of Warcraft 3.3.5a (WotLK, interface 30300)**. The repo has a minimal scaffold: the add-on in `Atlasium/` (`Util.lua`, `Core.lua`, `MinimapButton.lua`, `Data/Overlays.lua`, `FogClear.lua`), busted specs in `tests/`, and developer docs in `docs/`. Available features: the minimap button and fog clearing on the world map.

## Commands

Requires Lua 5.1, busted and luacheck (see `docs/contributing/development.md`). From the repo root:

- `luacheck Atlasium tests` lints
- `busted` runs the specs (config in `.busted`)
- `busted tests/core_spec.lua` runs one spec file; `busted --filter="text"` runs matching tests

CI (`.github/workflows/ci.yml`) runs both.

## Architecture

- The client calls each `.toc` file with `(addonName, ns)` varargs; `ns` is the only shared state. `Core.lua` owns the event frame (`Core.RegisterEvent`), SavedVariables init (`ns.defaults` merged into `AtlasiumDB` via `ns.Util.CopyDefaults` on `ADDON_LOADED`) and the `/atlasium` slash handler.
- `FogClear.lua` hooks `WorldMapFrame_Update` with `hooksecurefunc` and draws the unexplored overlays on its own `BORDER` textures under `WorldMapDetailFrame`. Its data is `Data/Overlays.lua` (`ns.Overlays`), generated from the 3.3.5a DBC files: do not edit it by hand. The tile math (`GetTiles`) matches Blizzard's loop in `FrameXML/WorldMapFrame.lua`.
- `MinimapButton.lua` builds the button on `PLAYER_LOGIN` (registered with `Core.RegisterEvent`, which keeps one handler per event). Its position and tooltip math are pure functions (`GetOffset`, `AngleFromCursor`, `GetTooltipAnchor`).
- Specs load files with `helper.loadAddonFile(path, ns)`, which mimics the client's varargs, after `helper.installWowStubs()` mocks the WoW globals. The `CreateFrame` stub returns fake frames that record any method call (`helper.lastCall`). A new WoW API needs a stub in `installWowStubs()` as well as entries in `read_globals` and the `tests/` globals.
- Deeper docs: `docs/contributing/` (`architecture.md`, `conventions.md`, `testing.md`).

## Code layout rules

- Every file starts with `local ADDON_NAME, ns = ...` and attaches to `ns`; no new globals beyond `AtlasiumDB`, the slash command and frame names that start with `Atlasium` (only when the client or other add-ons need the name, for example `UISpecialFrames`).
- New files go in `Atlasium/Atlasium.toc` in dependency order, with a matching `tests/*_spec.lua`.
- Keep logic pure (like `Util.lua`) and WoW-API glue thin so it can be tested with the stubs in `tests/helper.lua`.
- Add any new WoW API function to `read_globals` in `.luacheckrc`.

## Documentation style

- Player-facing docs (`README.md`, `docs/*.md`) use normal, friendly English.
- Contributor docs (`docs/contributing/`) use about 80% ASD-STE100: short sentences (about 20 words), one idea or instruction per sentence, active voice, simple present tense, consistent terms, numbered steps for procedures. Relax the rules where strict STE would read badly for humans, for example with "so", "for example" or a natural phrasing. Humans are the main readers, so readability wins over strict compliance.
- Keep real status honest: mark features as Available or Planned, and do not describe planned work as built.

## Planned features (from README)

- Google Maps-style map navigation
- Map notes
- Integration with Questie and TomTom
- Party integration over add-on channels: shared waypoints, party leader sets the tracked TomTom waypoint for all members, ping system, shared notes

## Target environment

- Code is Lua/XML running in the 3.3.5a client (Lua 5.1, no modern Blizzard APIs). Verify that any function, event or widget method exists in 3.3.5a before using it.
- Carbonite, Mapster, Questie-335 and TomTom are the reference implementations the project draws on.
- Do not copy or check against the `minimapShapes` table in Questie-335's `Compat/Libs/LibDBIcon-1.0` (Rev 15): it swaps several shapes. Use the shape rule in `MinimapButton.lua`.
