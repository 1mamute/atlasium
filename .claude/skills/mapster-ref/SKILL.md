---
name: mapster-ref
description: Look up how Mapster (WoW 3.3.5a Blizzard world map enhancer) implements something — resizable/movable world map, mini/large map toggle, scaling, cursor/player coordinates, fog-of-war clearing, group icons, battlefield minimap, instance maps in the zone dropdown, quest POI/blob handling — to learn from it for Atlasium. Use when the user asks how Mapster does X.
---

# Mapster reference (read-only)

Repo: `~/.cache/Mapster` (Windows: `C:\Users\mmt\.cache\Mapster`), v1.3.9 by Nevcairiel, interface 30300. Never edit it. License is "All rights reserved": learn from the approach, don't copy blocks.

Unlike Carbonite, Mapster is small (~3.7k lines), readable, and does not replace the world map: it **modifies Blizzard's `WorldMapFrame`** by hooking and re-anchoring. Good reference for how to coexist with / reskin the default map.

## Efficiency rules
- Built on Ace3 (`AceAddon`, `AceHook`, `AceDB`, `AceEvent`, `AceConfig`). Atlasium does not use Ace: translate `self:SecureHook(...)`/`self:RawHook(...)` into `hooksecurefunc` or manual function replacement, and `AceDB` into plain `AtlasiumDB`.
- Each feature is an Ace module (`Mapster:NewModule`) with `OnInitialize` / `OnEnable` / `OnDisable` / `Refresh` / `UpdateMapsize(mini)` / `BorderVisibilityChanged`. Read the module file whole except `FogClear.lua`.
- `FogClear.lua` is ~1050 lines of `errata` tables (per-zone overlay data, hex/number IDs). Skip lines 1–1050; the logic is at 1052+. Never read the `errata` data.
- Skip `Libs/`, `Locale/` (except `enUS.lua` for option strings) and `Artwork/`.
- Some functions are accidental globals (`OnUpdate`, `MouseXY`, `FixUnit`, `wmfOnShow`…). Don't replicate that in Atlasium (no new globals).

## Where to look (`Mapster/`)
| Topic | File |
|---|---|
| Core: map frame setup, mini/large toggle (`ToggleMapSize`, `SizeUp`, `SizeDown`), strata/alpha/scale/position, border, drag-move (`wmfStartMoving`), quest POI/blob handling, quest objectives dropdown | `Mapster.lua` |
| Options table / defaults | `Config.lua` |
| Cursor and player coordinates text, `GetCursorPosition` → map-relative x/y (`MouseXY`, `OnUpdate`) | `Coords.lua` |
| Drag-resize of the map by the corner (`GetScaleDistance`) | `Scaling.lua` |
| Party/raid icon replacement and sizing on map and battlefield minimap (`WorldMapUnit_Update`, `UpdateUnitIcon`) | `GroupIcons.lua` |
| Battlefield minimap (`BattlefieldMinimap`) tweaks | `BattleMap.lua` |
| Instance/dungeon maps added to continent/zone dropdowns (`WorldMapFrame_LoadContinents`, `SetMapZoom`) | `InstanceMaps.lua` |
| Fog-of-war removal: draws undiscovered overlay textures (`updateOverlayTextures`, `UpdateWorldMapOverlays`) | `FogClear.lua` (1052+) |

## Workflow
1. Pick the file from the table; Grep the feature keyword (e.g. `SetScale`, `GetCursorPosition`, `hooksecurefunc`, `SecureHook`, `WorldMapFrame`) in that file only.
2. Read 50–150 lines around hits. List a file's functions cheaply with Grep `^function\|^local function` `-n` on that file.
3. Check each 3.3.5a API it uses with the `wow-api-335` skill if unsure; Mapster targets 3.3.5 so APIs are valid, but verify before relying on them.
4. Report with `file:line` refs and how to adapt idiomatically for Atlasium (`local ADDON_NAME, ns = ...`, logic kept pure and testable, thin WoW glue, no Ace).
