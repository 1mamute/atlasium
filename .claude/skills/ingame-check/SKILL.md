---
name: ingame-check
description: Verify an Atlasium change in the running WoW 3.3.5a client — read add-on state as text with the dev console (wow-dev.ps1 eval), reload the UI after approval, take a WoW screenshot only for visual checks, and ask the user to restart the client when /reload is not enough. Use after changing add-on code or UI when the user wants it checked in game.
---

# In-game check

The add-on folder is linked into the client (`<WoW>\Interface\AddOns\Atlasium`), so edits are on disk
at once. `tools/wow-dev.ps1` drives the client; see `docs/en-US/contributing/in-game-testing.md`. Run it
with the PowerShell tool, never Git Bash (Bash turns `/reload` into a file path, which the character
would say in public chat).

## Debug mode

Most of the loop needs Atlasium debug mode. Ask the user to type `/atlasium debug` once (the setting
is saved). Debug mode gives:

- a square in the top-left corner (green: map open, red: map closed);
- the dev console strip right of it, which `eval`, `log` and `reload` read from a window capture;
- `AtlasiumDev` = the add-on `ns`, so code reaches any module (`AtlasiumDev.MapNavigation.state.zoom`);
- Lua errors from Atlasium files in the Atlasium log (own handler, or BugGrabber's callbacks when
  BugGrabber is loaded);
- keys: Num Pad * map toggle, Num Pad - screenshot, Num Pad + dev console focus.

Without debug mode, `eval` and `log` exit 6 (`NO_STRIP`), the map modes report `NO_MARKER`, and
`screenshot` needs `-ChatFallback`.

## Approval

- Free: `status`, `eval`, `log`, reading the window capture or screenshots. Lua sent through `eval`
  runs without asking. `mapstate` is free while the marker shows; without it, it presses the
  screenshot key.
- Ask first, showing the exact command, and batch them: `reload`, `run` (chat-box `/run`), `mapopen`,
  `mapclose`, `screenshot` and any other raw key.
- Never restart, kill or start the client yourself; restarts are always the user's.
- Never use DLL injection or memory writes on the client (Warden).

## Loop

1. Run `busted` and `luacheck Atlasium tests` first. Do not touch the client while they fail.
2. Run `./tools/wow-dev.ps1 status` and act on the first word of the output:
   - `RUNNING` → go to step 3.
   - `RESTART_NEEDED` → **stop**. Tell the user the listed reasons and ask them to restart the
     client, log in the test character and reply when the game is back. Do not send keys or run
     `reload` until they confirm. Then run `status` again.
   - `NOT_RUNNING` → **stop**. Ask the user to start the client and log in, and wait for them.
3. After approval, run `./tools/wow-dev.ps1 reload`. With the strip it waits for the new load ID and
   prints the health report (`return AtlasiumDev.Dev.GetHealth()`): `errors` above 0 is a failure,
   and `lastError` says where. With `errorCapture = "off"`, `errors = 0` proves nothing: check
   BugGrabber's saved variables (step 6). Without the strip it falls back to `-LoadDelay` and a screenshot.
4. Check state with `eval`, not screenshots:
   - `./tools/wow-dev.ps1 eval -Lua '<expression or chunk>'`; long probes go in a scratchpad file
     with `-File`. The output is the printed lines, then `=> ` and the returned values.
   - State that settles over frames (zoom animation, map update, tile load): use `-Until` with a
     condition instead of a sleep, for example `eval -Lua 'WorldMapFrame:IsShown()' -Until -Timeout 5`.
   - `./tools/wow-dev.ps1 log` (or `-Tail 50`) shows the Atlasium log, with captured Lua errors.
5. Take a screenshot only to check how something looks. Read the path after `SCREENSHOT:` with the
   Read tool. Say what you see, not what you expect.
6. Read `<WoW>\WTF\Account\<ACCOUNT>\SavedVariables\!BugGrabber.lua` if it exists and the health
   report or log do not explain a problem: any error newer than the reload is a failure.
7. Fix and repeat from step 1, or report done with the evidence (eval output, screenshot path).

## eval exit codes

- 9 `EVAL_ERROR`: the code failed; the output has the message. Fix the probe or the add-on.
- 10 `BUSY`: another edit box (chat) has the keyboard. Ask the user to close it.
- 11 `NO_FOCUS`: the console key did not work. After combat, debug bindings apply late. Report it,
  do not loop.
- 12 `NO_RESULT`, 13 `BAD_CHECKSUM`: report the output to the user. The strip colours are exact
  in the capture, so 13 usually means something covered the strip.
- 14 `UNTIL_TIMEOUT`: the condition never became true; the last output is printed.

## World map

- `./tools/wow-dev.ps1 mapstate` prints `MAP_OPEN`, `MAP_CLOSED` or `NO_MARKER` (window capture
  first, a screenshot only when the capture shows no marker).
- `eval` works with the map open; the add-on gives the console the keyboard itself.
- `mapopen` and `mapclose` press the toggle key only when needed and confirm the result. Exit code 7
  means the map did not change.
- `run` and `reload` read the marker first. With the map open they print `MAP_OPEN` and do not type
  (exit code 8): run `mapclose`, then retry. `NO_MARKER` means debug mode is off, so the state is
  unknown.
- Never send Escape to close the map: with the map closed it opens the game menu. Use `mapclose`.
- Do not type chat text while the map is open.

## Rules

- `NO_RELOAD` or `NO_SCREENSHOT` usually means a chat box or menu was open in the client: ask the
  user to close it, then retry once. Do not loop.
- If a check needs a game state (zone, party), ask the user to set it up. Do not script GM commands
  without asking.
