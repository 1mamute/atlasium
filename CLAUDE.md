# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

Atlasium is a map add-on for **World of Warcraft 3.3.5a (WotLK, interface 30300)**. The repo has a minimal scaffold: the add-on in `Atlasium/` (`Util.lua`, `Core.lua`), busted specs in `tests/`, and developer docs in `docs/`.

## Commands

Requires Lua 5.1, busted and luacheck (see `docs/contributing/development.md`). From the repo root:

- `luacheck Atlasium tests` lints
- `busted` runs the specs (config in `.busted`)
- `busted tests/core_spec.lua` runs one spec file; `busted --filter="text"` runs matching tests

CI (`.github/workflows/ci.yml`) runs both.

## Architecture

- The client calls each `.toc` file with `(addonName, ns)` varargs; `ns` is the only shared state. `Core.lua` owns the event frame (`Core.RegisterEvent`), SavedVariables init (`ns.defaults` merged into `AtlasiumDB` via `ns.Util.CopyDefaults` on `ADDON_LOADED`) and the `/atlasium` slash handler.
- Specs load files with `helper.loadAddonFile(path, ns)`, which mimics the client's varargs, after `helper.installWowStubs()` mocks the WoW globals. A new WoW API needs a stub in `installWowStubs()` as well as an entry in `read_globals`.
- Deeper docs: `docs/contributing/` (`architecture.md`, `conventions.md`, `testing.md`).

## Code layout rules

- Every file starts with `local ADDON_NAME, ns = ...` and attaches to `ns`; no new globals beyond `AtlasiumDB` and the slash command.
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
