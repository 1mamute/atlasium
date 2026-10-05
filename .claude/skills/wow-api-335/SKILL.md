---
name: wow-api-335
description: Look up the WoW 3.3.5a (WotLK, interface 30300) addon API — Lua API functions, widget methods, events, XML/FrameXML templates, and Blizzard UI code. Use whenever you need to verify a WoW function/event/frame exists in 3.3.5a, its signature/return values, or how Blizzard's own UI does something.
---

# WoW 3.3.5a API lookup

Target client is 3.3.5a (`## Interface: 30300`). Modern docs describe retail: many APIs there do NOT exist in 3.3.5a (`C_Map.*`, `C_Timer`, `C_ChatInfo.SendAddonMessage`, `Mixin`, `CreateFromMixins`, `BackdropTemplate`, `SetShown` variants etc.). Always confirm availability before using or recommending an API.

## Source order (cheapest and most authoritative first)

1. **Local Blizzard UI source for 3.3.5 (ground truth)** — `~/.cache/wow-ui-source-3.3.5` (Windows: `C:\Users\mmt\.cache\wow-ui-source-3.3.5`), a shallow clone of `Gethe/wow-ui-source` tag `3.3.5`.
   - `FrameXML/` (core UI Lua/XML, `FrameXML.toc` load order, `GlobalStrings.lua`, `Constants.lua`) and `AddOns/Blizzard_*` (load-on-demand UIs).
   - Grep for the function name: if it is *called* in Blizzard code with usage you can read, it exists, and the call site shows arg/return usage. Great for events (`RegisterEvent("X")`, `event == "X"`), templates (`<Frame name=... virtual="true">`), and widget methods.
   - Note: native C API functions are NOT defined here (only called). Absence of a definition is normal; absence of any call site means check source 2.
   - If missing: `git clone --depth 1 --branch 3.3.5 https://github.com/Gethe/wow-ui-source.git ~/.cache/wow-ui-source-3.3.5`.
2. **Warcraft Wiki (warcraft.wiki.gg)** — WebFetch `https://warcraft.wiki.gg/wiki/API_<FunctionName>` (e.g. `API_GetPlayerMapPosition`), widget methods `https://warcraft.wiki.gg/wiki/API_<Type>_<Method>` (e.g. `API_Frame_RegisterEvent`), events `https://warcraft.wiki.gg/wiki/<EVENT_NAME>`, indexes: `/wiki/World_of_Warcraft_API`, `/wiki/Widget_API`, `/wiki/Events`, `/wiki/XML_schema`, `/wiki/UI_best_practices`.
   - Covers retail but has a **Patch changes** section per page: usable in 3.3.5a only if "Added" is ≤ patch 3.3.5 (2010) and not later "Removed". Pages renamed to `C_Xxx.Name` are retail-only; use the original name if the history says "Added as `Name()`".
   - Ask WebFetch a narrow prompt ("signature, returns, patch changes since 3.x, notes") to keep output small.
3. **WoWWiki archive (3.x-era text)** — `https://vanilla-wow-archive.fandom.com/wiki/World_of_Warcraft_API` and per-function `.../wiki/API_<Name>`; closest to the wiki as it was in WotLK. Use when the Warcraft Wiki is ambiguous.
4. **Third-party** (WebSearch only if the above fail): wowprogramming.com (archived API docs, ~4.x), wowinterface.com forums, Wowpedia-style `HOWTO` pages. Treat as hints; verify against source 1.
5. **Real-world 3.3.5 addons** for usage patterns: `~/.cache/Questie-335`, `Carbonite`, `TomTom` (see the questie-ref / carbonite-ref / tomtom-ref skills); also bundled libs under their `Libs/` (LibStub, CallbackHandler, AceComm, AceEvent, HereBeDragons, Astrolabe).

## Efficiency rules
- Grep source 1 first (`Grep` with `-n`, `head_limit`, scoped `path`); only then fetch the web. Never read whole big files (`GlobalStrings.lua`, `FrameXML.toc` fine).
- One WebFetch per function, narrow prompt; batch multiple lookups in parallel in one turn.
- For "does X exist in 3.3.5a?": grep source 1 → wiki patch history → state the verdict with the evidence source. Say "unverified" if neither confirms.
- Common 3.3.5a pitfalls to check: world map via `GetPlayerMapPosition("player")`, `SetMapToCurrentZone`, `GetCurrentMapContinent/Zone/AreaID`, `GetMapInfo`; addon messages via global `SendAddonMessage(prefix, msg, channel[, target])` + `CHAT_MSG_ADDON` (prefix ≤16 chars, msg ≤255 bytes); timers via `OnUpdate` (no `C_Timer`); backdrops via `frame:SetBackdrop` directly; Lua 5.1 only (no `goto`, `//`, bit ops → use `bit.*`); `string.format`/`strsplit`/`strjoin`/`wipe`/`tinsert` globals exist; `UnitPosition` does NOT exist.
- Report: function, signature, returns, 3.3.5a availability + source, and a minimal usage snippet.
