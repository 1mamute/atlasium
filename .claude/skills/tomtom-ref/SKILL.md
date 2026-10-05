---
name: tomtom-ref
description: Look up how TomTom (WoW 3.3.5a waypoint/crazy-arrow addon) implements something — waypoints API, crazy arrow, minimap/world map waypoint icons, addon-message waypoint sharing, corpse arrow, POI integration — to learn from it for Atlasium's TomTom integration. Use when the user asks how TomTom does X or which TomTom API to call.
---

# TomTom reference (read-only)

Repo: `~/.cache/TomTom` (Windows: `C:\Users\mmt\.cache\TomTom`). Never edit it. Small (~3.7k lines): Grep then Read ranges; skip `libs/`, `Localization.*.lua`, `Images/`, `Media/`.

## Public API (what Atlasium integration should call) — all in `TomTom.lua` unless noted
- `TomTom:AddZWaypoint(c, z, x, y, desc, persistent, minimap, world, custom_callbacks, silent, crazy)` (~L741) — main entry; returns uid. `x,y` are 0–100.
- `TomTom:AddWaypoint(x, y, desc, ...)` (current zone), `TomTom:RemoveWaypoint(uid)`, `TomTom:WaypointExists(c,z,x,y,desc)`, `TomTom:SetCustomWaypoint(...)`
- `TomTom:GetClosestWaypoint()` / `SetClosestWaypoint()`, `TomTom:GetMapFile/GetCZ/GetXY/GetCoord`
- Crazy arrow (`TomTom_CrazyArrow.lua`): `SetCrazyArrow(uid, dist, title)`, `HijackCrazyArrow(onupdate)`, `ReleaseCrazyArrow()`, `CrazyArrowIsHijacked()`, `SetCrazyArrowDirection/Color/Title`
- Sharing: `SendWaypoint(uid, channel)` and `CHAT_MSG_ADDON` handler (~L593–700) — the party waypoint protocol.

## Where to look
| Topic | File |
|---|---|
| Waypoint add/remove, events, addon-message sharing, coord display | `TomTom.lua` |
| Minimap/world-map waypoint icon frames, tooltips, click menus | `TomTom_Waypoints.lua` |
| Arrow rendering/direction/distance | `TomTom_CrazyArrow.lua` |
| Options UI / defaults | `TomTom_Config.lua` |
| Corpse arrow | `TomTom_Corpse.lua` |
| Quest POI click integration | `TomTom_POIIntegration.lua` |
| Load order | `TomTom.toc` |

## Efficiency rules
- Use `Grep -n "function TomTom"` on a single file for an outline, then Read ~40–120 lines.
- Answers must cite `file:line`; note 3.3.5a compat (Astrolabe/Cartographer3-style `c,z` continent/zone indices, not modern map IDs).
- Detect at runtime in Atlasium with `if TomTom and TomTom.AddZWaypoint then`.
