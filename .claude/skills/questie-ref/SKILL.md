---
name: questie-ref
description: Look up how Questie-335 (WoW 3.3.5a quest addon) implements something — quest DB, map icons/pins, tracker, tooltips, party comms, journey/search — to learn from it for Atlasium. Use when the user asks how Questie does X or when designing Questie integration.
---

# Questie-335 reference (read-only)

Repo: `~/.cache/Questie-335` (Windows: `C:\Users\mmt\.cache\Questie-335`). Never edit it.

## Efficiency rules
- Grep first (Grep tool, `-n`, `head_limit`), then Read only the matching range (`offset`/`limit`). Never read whole files.
- NEVER open `Database/**` data files (`wotlkQuestDB.lua`, `*NpcDB.lua`, `*ObjectDB.lua`, `*ItemDB.lua`, `Zones/*`, `Corrections/*`) — huge generated tables. Read only `Database/QuestieDB.lua`, `Database/compiler.lua`, `Database/Constants.lua` (key/field index tables) for the schema.
- Skip `Libs/`, `Modules/Libs/`, `Localization/`, `Icons/`, `*.test.lua`, `cli/`, `ExternalScripts*`.
- For broad "where is X" questions across many files, delegate to an Explore subagent instead of reading yourself.
- Use the 3.3.5 TOC (`Questie-335.toc`) for load order; ignore the Classic/TBC/BCC TOCs.

## Where to look
| Topic | Path (under `Modules/` unless noted) |
|---|---|
| Init order / events | `QuestieInit.lua`, `QuestieEventHandler.lua`, `Questie.lua` (root) |
| Quest log state, accept/complete/objectives | `Quest/QuestieQuest.lua`, `Quest/QuestEventHandler.lua`, `Quest/QuestLogCache.lua` |
| Available quests (quest givers) | `Quest/AvailableQuests.lua`, `Quest/DailyQuests.lua` |
| Map pins on world map/minimap (icon creation, notes, clustering) | `Map/QuestieMap.lua`, `Map/QuestieMapUtils.lua`, `Map/HBDHooks.lua`, `WorldMapButton/` |
| Frame pooling | `FramePool/` |
| Quest tracker UI | `Tracker/QuestieTracker.lua` + sibling Tracker*.lua |
| Tooltips | `Tooltips/` |
| Party/addon-channel comms (sharing quest progress) | `Network/QuestieComms.lua`, `QuestieCommsData.lua` |
| Quest search / journey UI | `Journey/` |
| DB access API (GetQuest, GetNPC, spawns, zone ids) | `Database/QuestieDB.lua`, `Database/Zones/zoneDB.lua` (small helper parts only) |
| Compat shims for 3.3.5 | `QuestieCompat.lua`, `Compat/` |
| Slash commands / options | `QuestieSlash.lua`, `Options/` |
| Coordinates, TomTom hooks | `QuestieCoordinates.lua`; grep `TomTom` |

## Workflow
1. Map the question to a row above; Grep with a targeted identifier (e.g. `function QuestieMap`, `AddMapIcon`, `SendMessage`) scoped via `path`.
2. Read ~60–150 lines around hits.
3. Answer with `file:line` refs and a short note on how it applies to Atlasium (3.3.5a API only; Questie uses `QuestieLoader:ImportModule` modules and `Questie.db`, AceDB/AceComm libs).
