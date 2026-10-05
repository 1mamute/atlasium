---
name: carbonite-ref
description: Look up how Carbonite (WoW 3.3.5a map/quest/social addon suite) implements something — world map, map notes/icons, quest watch, party/guild comms, HUD, options — to learn from it for Atlasium. Use when the user asks how Carbonite does X.
---

# Carbonite reference (read-only)

Repo: `~/.cache/Carbonite` (Windows: `C:\Users\mmt\.cache\Carbonite`). Never edit it. It has its own `CLAUDE.md` — read only if you need architecture details beyond this file.

## Efficiency rules
- Code is dense/minified with abbreviated names (`Nx:LoI`, `Nx.Map:CCM`). Grep by `Nx.<Module>` or function name, then Read a narrow range (`offset`/`limit`). Files are huge (CarboniteMap.lua ~7.8k lines): never read whole.
- NEVER read `Carbonite/CarboniteData.lua` or `CarboniteItems/CarboniteItems.lua` — packed binary (latin1) data; it wastes context and corrupts output. Also skip `CarboniteNodes/`, `Gfx/`, `Snd/`, `Localization.lua`.
- Everything hangs off global `Nx`; sub-tables: `Nx.Map` (world map), `Nx.Que` (quests), `Nx.War` (warehouse), `Nx.Soc`/`Nx.Inf` (social), `Nx.HUD`, `Nx.Com` (comms/combat), `Nx.Fav`, `Nx.Opt`, UI toolkit `Nx.Win/But/Lis/Men/Sli/TaB/EdB`.
- To list a file's functions cheaply: Grep `^function Nx` with `-n` and `output_mode: content` on that single file, then pick ranges.
- Broad multi-file questions: delegate to an Explore subagent.

## Where to look (`Carbonite/Carbonite/`)
| Topic | File |
|---|---|
| Init, timers, profiles, event dispatch | `CarboniteCore.lua` |
| World map, zoom/pan, icons, notes, minimap, goto/arrows | `CarboniteMap.lua` (`Nx.Map*`) |
| Quest log/watch, quest data decode | `CarboniteQuests.lua` (`Nx.Que*`) |
| Warehouse/tracker/auctions | `CarboniteTrackers.lua` |
| Friends/guild/social, HUD, minimap button | `CarboniteSocial.lua` |
| Addon-channel comms, favorites, combat | `CarboniteComms.lua` |
| Options panels | `CarboniteOptions.lua` |
| Widget toolkit (windows, lists, menus) | `CarboniteUI.lua` |
| Frame templates / bindings | `Carbonite.xml`, `Bindings.xml` |

## Workflow
1. Pick the file from the table; Grep the feature keyword (e.g. `Note`, `Goto`, `SendAddonMessage`) in that file only.
2. Read 50–150 lines around hits.
3. Report with `file:line` refs and how to adapt the idea idiomatically (readable Lua, not Carbonite's minified style; 3.3.5a API only; mind its license — learn from the approach, don't copy blocks).
