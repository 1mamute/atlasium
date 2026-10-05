# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

Atlasium is a map add-on for **World of Warcraft 3.3.5a (WotLK, interface 30300)**.
The first stable release is [v1.0.0](https://github.com/1mamute/atlasium/releases/tag/v1.0.0).
The add-on lives in `Atlasium/`, specs in `tests/`, and developer scripts in `tools/`.
Available features include the minimap button, minimap wheel zoom, fog clearing, world map drag and zoom,
and native settings with English and Brazilian Portuguese text.
Custom minimap tiles are experimental. Outdoor rendering is checked; field checks remain open in
`docs/en-US/contributing/in-game-testing.md`.

## Commands

Requires Lua 5.1, busted, luacheck and Python 3.10 or later
(see `docs/en-US/contributing/development.md`). From the repo root:

- `luacheck Atlasium tests` lints
- `busted` runs the specs (config in `.busted`)
- `busted tests/core_spec.lua` runs one spec file; `busted --filter="text"` runs matching tests
- `python -m unittest discover -s tests -p 'test_*.py'` checks release packaging and commit subjects
- `python tools/check_commit.py "docs: update contributor guidance"` checks a commit subject
- `python tools/package_release.py --tag v1.0.0` builds the player ZIP and checksum in `.build/release/`
- `python tools/build_docs.py` builds and validates the bilingual site; requires Doxygen 1.18.0 or later

CI (`.github/workflows/ci.yml`) runs Lua lint, Lua specs and Python tests.
It checks pull request titles on pull request events. Documentation and release workflows run separately.

## Project skills and Claude settings

`.claude/` is tracked. It contains the Lua LSP plugin setting, the permission for `tools/wow-dev.ps1`,
the `repo-worker` agent definition, and these project skills:

- `wow-api-335`: verify 3.3.5a APIs, events, widget methods and Blizzard UI code.
- `carbonite-ref`, `mapster-ref`, `questie-ref` and `tomtom-ref`: inspect reference add-ons before designing equivalents.
- `ingame-check`: verify changes in the running client with the dev console and screenshots.

Reference source caches live outside the repository under `~/.cache/`. They are read-only and may need setup.
Follow each skill's lookup instructions. Do not assume another contributor has those caches installed.
`CLAUDE.local.md` remains a private companion, excluded through `.git/info/exclude`.
Keep machine-specific preferences there and shared project guidance here.

## Commits, versions and releases

- Use `type: description` for new commit subjects and pull request titles. Do not add a scope or `!` to the subject.
- Types are `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore` and `revert`.
- Describe incompatible changes with a `BREAKING CHANGE:` footer and migration steps in `CHANGELOG.md`.
- Squash merges use the PR title as the commit subject. Existing history stays unchanged.
- Use SemVer: PATCH for compatible fixes, MINOR for compatible features, MAJOR for incompatible changes.
- The compatibility contract covers documented commands, settings, saved data and supported clients. Internal `ns` functions are not public API.
- `Atlasium/Atlasium.toc` is the version source. Git tags are annotated and use `vMAJOR.MINOR.PATCH`.
- Add a matching section in `CHANGELOG.md` before tagging. The tag must match the TOC version.
- `.github/workflows/release.yml` runs CI for `v*` tag pushes, then publishes the ZIP, SHA-256 checksum and changelog notes.
- Prerelease suffixes produce GitHub prereleases. Never move a published tag or replace a published archive.
- The ZIP includes the TOC and its listed files, README, changelog, license, and player Markdown docs in `docs/en-US/` and `docs/pt-BR/`.
- Exclude every `contributing` directory, tests, tooling, agent settings, website files, images and local configuration.
- Keep `Dev.lua` and `DevConsole.lua` in the ZIP: the TOC loads them, and they activate only in debug mode.
- `tools/package_release.py` redirects links to excluded docs and images to tagged files on GitHub.
- Players install the attached `Atlasium-v*.zip`, not GitHub's automatic source archives.

See `docs/en-US/contributing/releases.md` for the complete release procedure.

## Documentation layout and publishing

- English docs live in `docs/en-US/`; Brazilian Portuguese docs mirror them in `docs/pt-BR/`.
- Each language has a `home.md` and a `contributing/` directory. Keep the root README overview in sync with both home pages.
- Keep heading levels and order the same across translations. The site uses English section IDs in both languages.
- `docs/site/` is required source: it holds the HTML template, stylesheet and browser scripts. Keep it in the repo.
- `docs/assets/` holds shared documentation images. `.build/site/` is generated and ignored.
- `tools/build_docs.py` uses `Doxyfile` and Doxygen to render both languages and validate links, images and anchors.
- Published language paths are `/en-US/` and `/pt-BR/`; generated `/en/` redirects preserve older links.
- `.github/workflows/docs.yml` builds and deploys GitHub Pages at `https://1mamute.github.io/atlasium/`.
- Update installation and configuration docs when player behavior changes. Keep available, experimental and planned status honest.

## Architecture

- The client calls each `.toc` file with `(addonName, ns)` varargs; `ns` is the only shared state. `Core.lua` owns the event frame (`Core.RegisterEvent`), SavedVariables init (`ns.defaults` merged into `AtlasiumDB` via `ns.Util.CopyDefaults` on `ADDON_LOADED`) and the `/atlasium` slash handler.
- `FogClear.lua` hooks `WorldMapFrame_Update` with `hooksecurefunc` and draws the unexplored overlays on its own `BORDER` textures under `WorldMapDetailFrame`. Its data is `Data/Overlays.lua` (`ns.Overlays`), generated from the 3.3.5a DBC files: do not edit it by hand. The tile math (`GetTiles`) matches Blizzard's loop in `FrameXML/WorldMapFrame.lua`.
- `MapNavigation.lua` moves the Blizzard map frames into a clipping `ScrollFrame` (viewport) > scroll child > scaled zoom frame on the first map open. Icons are counter-scaled (`1/zoom`, offsets times `zoom`; `ResolveRaw` keeps raw Blizzard values). The selected quest blob is cleared and drawn again after each zoom or scroll. In combat the blob leaves the tree (it can be protected); on return `WorldMapButton` and `WorldMapPOIFrame` rejoin after it, because a ScrollFrame draws children in join order, not by frame level.
- `Log.lua` has `Log.Error(...)` (always) and `Log.Debug(...)` (only in debug mode). Both print to chat and append a timed string to `AtlasiumDB.log`, capped at 200 entries (`Util.AppendCapped`). In debug mode `Log.SetErrorCapture` wraps the Lua error handler: errors from Atlasium files go to `Log.Error` (and `Log.errorCount`), then on to the previous handler. BugGrabber makes `seterrorhandler` a no-op, so with it the capture uses BugGrabber's `BugGrabber_BugGrabbed` callbacks instead. Use `Core.Print` only for replies to the player.
- `MinimapButton.lua` builds the button on `PLAYER_LOGIN` (registered with `Core.RegisterEvent`, which keeps a list of handlers per event). Its position and tooltip math are pure functions (`GetOffset`, `AngleFromCursor`, `GetTooltipAnchor`).
- `MinimapZoom.lua` sets the minimap `OnMouseWheel` script on `PLAYER_LOGIN` and calls Blizzard's `Minimap_ZoomIn` and `Minimap_ZoomOut` (they click the + and - buttons). It skips a wheel handler of another add-on, and `zoom off` removes only its own handler.
- `MinimapTiles.lua` draws raw minimap terrain (`Textures\Minimap\<md5>`) at every zoom, on a child of `MinimapCluster` at `Minimap` level - 1. Horizontal strips are cropped and rotated with the 8-argument `SetTexCoord` (`BuildSegments`, pure). A transparent mask hides Blizzard ground; the engine draws the player arrow and normal blips. Secure texture hooks remember other add-ons' paths for restoration. Indoors, instances and WMO cities use Blizzard terrain. Its data is `Data/MinimapTileData.lua` (`ns.MinimapTileData`), generated by `tools/gen_minimap_tiles.py` (Python 3 + mpyq, not in CI): do not edit it by hand. Position comes from `GetPlayerMapPosition` on the current map (`SetMapToCurrentZone` when it is missing and the world map is closed). Settings use `minimapTiles`; commands are `minimap tiles on|off` and `align` (debug only). Masks set before the hooks load are not yet remembered.
- Minimap tiles raise a `BACKGROUND` minimap and its underlay to `LOW` while drawing: the world render otherwise covers ordinary textures. Fallback and tiles off restore its strata, unless another add-on changed it. `PLAYER_ENTERING_WORLD` reapplies active transparent textures because the engine can reset them during loading without running the Lua setters. Zoom and zone events refresh the view immediately.
- Specs load files with `helper.loadAddonFile(path, ns)`, which mimics the client's varargs, after `helper.installWowStubs()` mocks the WoW globals. The `CreateFrame` stub returns fake frames that record any method call (`helper.lastCall`). A new WoW API needs a stub in `installWowStubs()` as well as entries in `read_globals` and the `tests/` globals.
- `Dev.lua` (debug mode only, see `docs/en-US/contributing/in-game-testing.md`) shows a green or red marker square for the world map state in the top-left corner and sets override bindings (Num Pad * toggles the map, Num Pad - takes a screenshot) so `tools/wow-dev.ps1` can drive the client when the open map swallows chat input. In debug mode it also sets the global `AtlasiumDev = ns` for `/run` and the dev console; add-on code never reads it.
- `DevConsole.lua` (debug mode only): Num Pad + gives a hidden EditBox the keyboard. `wow-dev.ps1 eval` types Lua into it as hex digits; the console runs it in `_G` and shows the output as a strip of coloured cells (3 bytes per cell, header with load ID, sequence number, flags and checksum) right of the marker. The script reads the strip from a window capture. The encoding (`EncodeCells`, `Serialize`, `Evaluate`) is pure; keep the strip geometry in sync with `tools/wow-dev.ps1`.
- Deeper docs: `docs/en-US/contributing/` (`architecture.md`, `conventions.md`, `testing.md`).

## Code layout rules

- **UI design:** Make the UI as close to a vanilla window as possible, so the add-on feels like
  a built-in feature of the original client. Use the original 3.3.5a client's visual conventions.
  See `docs/en-US/contributing/conventions.md` (UI design).
- `Localization.lua` owns English and Brazilian Portuguese text. `Settings.lua` validates user
  edits and calls feature setters. `SettingsUI.lua` builds the shared controls in a standalone
  native dialog and an Interface Options panel. Changes apply immediately in both views.

- Every add-on Lua file starts with `local ADDON_NAME, ns = ...` (or `local _, ns = ...`) and attaches to `ns`; no new globals beyond `AtlasiumDB`, the slash command, frame names that start with `Atlasium` (only when the client or other add-ons need the name, for example `UISpecialFrames`) and the debug handle `AtlasiumDev` (debug mode only, set by `Dev.lua`).
- New files go in `Atlasium/Atlasium.toc` in dependency order, with a matching `tests/*_spec.lua`.
- Keep logic pure (like `Util.lua`) and WoW-API glue thin so it can be tested with the stubs in `tests/helper.lua`.
- Add any new WoW API function to `read_globals` in `.luacheckrc`.

## Documentation style

- Player-facing docs (`README.md`, `docs/en-US/*.md`) use normal, friendly English.
- Contributor docs (`docs/en-US/contributing/`) use about 80% ASD-STE100: short sentences (about 20 words), one idea or instruction per sentence, active voice, simple present tense, consistent terms, numbered steps for procedures. Relax the rules where strict STE would read badly for humans, for example with "so", "for example" or a natural phrasing. Humans are the main readers, so readability wins over strict compliance.
- Keep real status honest: mark features as Available or Planned, and do not describe planned work as built.

## Planned features (from README)

- Map notes
- Integration with Questie and TomTom
- Party integration over add-on channels: shared waypoints, party leader sets the tracked TomTom waypoint for all members, ping system, shared notes

## Target environment

- Code is Lua/XML running in the 3.3.5a client (Lua 5.1, no modern Blizzard APIs). Verify that any function, event or widget method exists in 3.3.5a before using it.
- Carbonite, Mapster, Questie-335 and TomTom are the reference implementations the project draws on.
- Do not copy or check against the `minimapShapes` table in Questie-335's `Compat/Libs/LibDBIcon-1.0` (Rev 15): it swaps several shapes. Use the shape rule in `MinimapButton.lua`.
