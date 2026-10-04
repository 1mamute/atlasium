# In-game testing

The specs do not cover XML layout, real frames or textures (see [testing.md](testing.md)). Check
these in a running 3.3.5a client. `tools/wow-dev.ps1` runs Lua in the client and prints the result,
reloads the UI, takes screenshots, and opens and closes the world map. You (or Claude Code) can check
a change without leaving the editor.

## Setup (once)

1. Link the add-on into the client, so the client reads the repo files:

   ```powershell
   New-Item -ItemType Junction -Path "<WoW>\Interface\AddOns\Atlasium" -Target "<repo>\Atlasium"
   ```

   If WoW is in `C:\Program Files`, run this command in an administrator PowerShell.

2. Tell the script where the client is. Copy `.env.example` to `.env` in the root of the repository
   and set the folder that contains `Wow.exe`:

   ```
   ATLASIUM_WOW_DIR=C:\Path\To\WoW
   ```

   Git ignores `.env`, so your paths stay on your computer. The script also accepts the folder as an
   `ATLASIUM_WOW_DIR` environment variable or as `-WowDir <path>`. `-WowDir` takes precedence over the
   environment variable, and the environment variable takes precedence over `.env`.

3. In the client, run WoW in windowed or windowed (fullscreen) mode and save screenshots as JPEG:
   `/console screenshotFormat jpeg`.
4. Type `/atlasium debug` in the client to turn on debug mode. Most modes of the script need it (see
   [Debug mode](#debug-mode-map-marker-and-keys) and [Dev console](#dev-console)). The setting is
   saved, so you do it once.
5. Optional: install BugGrabber and BugSack (3.3.5 builds). Errors go to
   `WTF\Account\<ACCOUNT>\SavedVariables\!BugGrabber.lua`, which can be read after a reload.

## Atlasium log

Atlasium writes its error and debug messages to chat and to a saved log. Debug messages need debug
mode. In debug mode the log also gets the Lua errors from Atlasium files, as `Lua error: <message>`
entries. These errors still go on to the Blizzard error frame or BugGrabber. With BugGrabber
installed, Atlasium reads the errors from BugGrabber's callbacks, because BugGrabber owns the error
handler.

To read the log while the client runs, use `./tools/wow-dev.ps1 log` (the newest 20 entries) or
`log -Tail 50`. To read it after a session:

1. Type `/reload`, or log out. The client writes saved variables only on reload, logout or exit.
2. Open `WTF\Account\<ACCOUNT>\SavedVariables\Atlasium.lua`.
3. Find the `log` table. It holds the newest 200 entries, oldest first.

## Inspect state

In debug mode the global `AtlasiumDev` is the add-on namespace (`ns`). Use it to read the state of
any module from `/run`, a macro or the dev console. For example:

```
/run print(AtlasiumDev.Dev.IsActive(), #AtlasiumDev.db.log)
/run local h = AtlasiumDev.Dev.GetHealth() print(h.modules, h.errors, h.lastError)
```

`AtlasiumDev` is only for checks. Add-on code never reads it (see
[Conventions](conventions.md#structure)).

The chat box takes at most 255 characters, so `wow-dev.ps1 run` is good only for short code, and the
result comes back on a screenshot. `wow-dev.ps1 eval` has no length limit and prints the result as
text. Use `eval` when debug mode is on.

## Settings UI checks

The settings feature adds manifest entries. Restart the client before this first check.

Checked in the 3.3.5a client on 2026-10-04: both settings views, English and Brazilian Portuguese
text, scroll bounds, feature callbacks, view synchronization, color preview and cancellation,
defaults, Interface Options cancellation, zoom limits during animation, wheel increments and
preferences after reload. The native special-window close path also passes. The session reports
zero captured Lua errors. Original preferences are restored after the checks.

Physical title-bar dragging, the Escape key, different UI scales and changes during real combat
still need field checks. The callback checks do not replace these checks.

1. Click the minimap button. Confirm that Atlasium settings opens and the world map stays closed.
2. Drag the title bar. Confirm that the window stays on screen. Close it with Escape.
3. Open Interface → AddOns → Atlasium. Confirm that both views show the same controls.
4. Switch to Português (Brasil). Check accents, text wrapping, tooltips and scrolling at small UI scales.
5. Toggle each feature. Confirm that changes apply immediately. Hide the minimap button, then open
   settings with `/atlasium`. Confirm that cancelling Interface Options keeps applied changes.
6. Drag the minimap button. Confirm that both position sliders update.
7. Zoom the world map. Lower its maximum zoom during animation. Confirm that zoom and scroll stay
   within the new limits. Change the wheel multiplier and check the next notch.
8. Change unexplored-area color and opacity with the map open. Cancel the picker and check the
   previous tint. Repeat and accept the new tint.
9. Open settings in combat. Change map settings and debug mode. Check for blocked actions and Lua
   errors. Confirm that debug bindings update after combat.
10. Reload after setting Portuguese and changing a feature. Confirm that both preferences persist.
11. Restore defaults from each view. Confirm that English and feature defaults return. Keep the
    saved log. Mark these checks complete only after observing them in the client.

## What needs a restart

The client reads `.toc` files only at startup. `/reload` reads the Lua and XML files again.

| Change | Needs |
| --- | --- |
| Edit an existing `.lua` or `.xml` file | `/reload` |
| Change `Atlasium.toc` | Restart |
| Add a new file | Restart |
| Change a texture | Restart (the client may cache it) |

`wow-dev.ps1` reports `RESTART_NEEDED` when one of these changes happened after the client started.
It compares the `.toc` and texture times with the start time of the client. To find new files, it
saves the add-on file list the first time it sees a client process (in
`%TEMP%\atlasium-wow-dev.json`). If you add a file before the first `status` or `reload`, the script
does not know about it.

## Commands

| Command | Does |
| --- | --- |
| `./tools/wow-dev.ps1 status` | Reports `RUNNING`, `RESTART_NEEDED` or `NOT_RUNNING`. |
| `./tools/wow-dev.ps1 eval -Lua '<code>'` | Runs the code in the dev console and prints the result as text (see [Dev console](#dev-console)). `-File <path>` reads the code from a file. |
| `./tools/wow-dev.ps1 eval -Lua '<code>' -Until` | Runs the code again until its first returned value is not `nil` or `false`, or until `-Timeout` (default 10 s) ends. |
| `./tools/wow-dev.ps1 log` | Prints the newest entries of the Atlasium log (`-Tail`, default 20). |
| `./tools/wow-dev.ps1 reload` | Checks that the map is closed and types `/reload`. With the dev console, it waits for the new load and prints a health report. Without it, it waits `-LoadDelay` seconds (default 8), takes a screenshot and prints `SCREENSHOT: <path>`. |
| `./tools/wow-dev.ps1 screenshot` | Takes a screenshot with a key, without a reload. |
| `./tools/wow-dev.ps1 run -Lua '<code>'` | Checks that the map is closed, types `/run <code>`, takes a screenshot and prints `SCREENSHOT: <path>`. |
| `./tools/wow-dev.ps1 mapstate` | Reads the map marker and prints `MAP_OPEN`, `MAP_CLOSED` or `NO_MARKER`. |
| `./tools/wow-dev.ps1 mapopen` | Opens the world map if it is closed, then checks the marker again. |
| `./tools/wow-dev.ps1 mapclose` | Closes the world map if it is open, then checks the marker again. |

The script types slash commands into the WoW chat box with window messages. It presses keys with
the same messages. The client stays in the background, so you can keep using the computer. For the
chat commands, the client must show the game world with no menu or chat box open.

The script reads the marker and the dev console strip from a capture of the client window
(`PrintWindow`). A capture takes 20 to 60 ms and writes no file. It works when other windows cover
the client, but not when the client is minimized. When the capture shows no marker, the map modes
take a WoW screenshot and read the marker from it. Then they print the screenshot path.

Exit codes:

| Code | Meaning |
| --- | --- |
| 0 | ok |
| 2 | client not running |
| 3 | restart needed |
| 4 | screenshot not found |
| 5 | reload did not happen |
| 6 | no map marker or no dev console strip (debug mode off, add-on not loaded, UI hidden or client minimized) |
| 7 | the map did not open or close |
| 8 | the map is open, so `run` or `reload` did not type |
| 9 | the Lua code of `eval` failed (the output shows the error) |
| 10 | another edit box has the keyboard (for example the chat box), so `eval` did not type |
| 11 | the dev console did not take the keyboard |
| 12 | no `eval` result in time |
| 13 | the strip did not pass the checksum |
| 14 | `eval -Until` timed out |

`reload` checks that the reload happened. With the dev console, a new load ID on the strip shows it.
Without the dev console, the script checks the saved variables: the client writes `Atlasium.lua` in
`WTF\Account\<ACCOUNT>\SavedVariables` on every reload. If the file is older than the `/reload`, the
script reports `NO_RELOAD`.

The script only sends text that starts with a slash command, because other text goes to public
chat. Run it from PowerShell, not Git Bash: Git Bash changes arguments that start with `/` into
file paths.

## Debug mode: map marker and keys

An open world map has the keyboard. It ignores typed text, so the chat box does not work while the
map is open. Debug mode gives the script a way around this. While `/atlasium debug` is on,
`Atlasium/Dev.lua` does two things:

- It shows a solid square of at least 24 by 24 screen pixels in the top-left corner of the screen,
  above the map. The square is green when the world map is open and red when it is closed.
- It binds two keys with `SetOverrideBinding`. Override bindings are not saved, and the add-on
  clears them when you turn debug mode off. A player who rebinds M or Print Screen does not break
  the script.

| Key | WoW name | Runs |
| --- | --- | --- |
| Num Pad * | `NUMPADMULTIPLY` | `TOGGLEWORLDMAP` |
| Num Pad - | `NUMPADMINUS` | `SCREENSHOT` |
| Num Pad + | `NUMPADPLUS` | Click on `AtlasiumDevConsoleButton`: gives the dev console the keyboard |

The script posts these keys to the client as `WM_KEYDOWN` and `WM_KEYUP` messages. It chose
numpad operator keys for these reasons:

- 3.3.5a has no default binding on them.
- They send the same virtual key whatever the NumLock state is.
- They are not extended keys, so the scan code is simple.
- WoW has no F13 to F15 on Windows: the names `F13` to `F15` exist only as Mac names for Print
  Screen, Scroll Lock and Pause.

The script cannot send a modifier key (Ctrl, Shift, Alt) with `PostMessage`, because the client reads
modifiers from the real keyboard. For this reason the bound keys have no modifier.

The map has the keyboard while it is open. Its `OnKeyDown` handler runs the binding that
`GetBindingFromClick` returns, so an override binding may or may not work there. `Dev.lua` hooks
the handler. If the client does not count the override binding, the hook runs the command itself.
A click binding never runs while the map is open, so the hook also gives the dev console the
keyboard on Num Pad +.

The client refuses binding changes in combat. When you turn debug mode on or off in combat, the
add-on changes the keys when combat ends. The marker is not protected, so it changes at once.

The script reads the marker from the window capture, or from a screenshot: it checks the centre of
the square, and accepts the state when at least 90% of those pixels are clearly green or clearly
red. The check uses client pixels, so the window size does not matter.

Without debug mode there is no marker and no key. Then `mapstate`, `mapopen` and `mapclose` print
`NO_MARKER`, and `screenshot` finds no file. `screenshot -ChatFallback` types `/run Screenshot()`
instead. Use it only when you know that the map is closed.

`run` and `reload` read the marker before they type. If the map is open, they print `MAP_OPEN` and do
not type (exit code 8). Use `mapclose` first. If the marker is missing, they print `NO_MARKER` and
type as before, because they cannot know the state. `reload -SkipMapCheck` skips the check. A map
check adds a screenshot file to the `Screenshots` folder only when the capture shows no marker.

The script never sends Escape. With the map closed, Escape opens the game menu.

Status: the script, the marker, the keys and the specs are built. The specs cover the marker and
the key logic with stubs. In the game, the marker shows above the open world map, `mapstate` reads
it from the window capture, and the map's `OnKeyDown` gets `NUMPADPLUS` from a posted key. Not
checked in the game yet: `NUMPADMULTIPLY` and `NUMPADMINUS` from posted messages (`mapopen`,
`mapclose`, `screenshot`).

## Dev console

In debug mode, `Atlasium/DevConsole.lua` adds a console that `wow-dev.ps1 eval` uses. It needs no
chat box and no screenshot, and it works while the world map is open. One round trip takes about a
second.

How `eval` works:

1. The script captures the window and reads the strip header. With no strip, it stops (exit 6). If
   another edit box has the keyboard, for example the chat box, it stops and types nothing (exit 10).
2. It presses Num Pad +. A hidden edit box gets the keyboard. The script waits until the strip shows
   the focus flag (2 s), else it stops (exit 11).
3. It types the code as hex digits and presses Enter. Hex digits pass the edit box unchanged, also
   for `|` and text that is not ASCII.
4. The console prints a grey `dev> <first line>` in chat and runs the code in `_G`, like `/run`. It
   first tries the code as an expression (`return <code>`), so `eval -Lua 'GetCVar("scriptErrors")'`
   prints the value.
5. The console shows the output on the strip. The script waits for a new sequence number, checks the
   checksum and prints the text.

The output has the chat lines that the code printed (colour codes removed), then `=> ` and the
returned values. Strings are quoted, tables show 2 levels and 30 entries per level, and frames show
as `<Type Name>`. An error prints `EVAL_ERROR:` and the message (exit 9). Output longer than 4096
bytes is cut, and the script adds `(truncated at 4096 bytes)`.

The console never keeps the keyboard: Escape or 3 seconds without input closes it.

Examples:

```powershell
./tools/wow-dev.ps1 eval -Lua 'AtlasiumDev.Dev.GetHealth()'
./tools/wow-dev.ps1 eval -Lua 'WorldMapFrame:IsShown(), GetCurrentMapAreaID()'
./tools/wow-dev.ps1 eval -Lua 'WorldMapFrame:IsShown()' -Until -Timeout 5
./tools/wow-dev.ps1 eval -File probe.lua
```

Use `-Until` for state that changes over some frames, for example a zoom animation or a map update.
It replaces a fixed wait. An error counts as "not yet", because the state may not exist yet.

The strip is a row of small coloured cells right of the map marker. Each cell holds 3 bytes, one per
colour channel. The first 5 cells are the header:

| Cell | Holds |
| --- | --- |
| 1 | magic bytes `Atl` |
| 2 | load ID: new on each load, so the script sees that a `/reload` finished |
| 3 | sequence number (2 bytes) and flags: 1 console focus, 2 other edit box focus, 4 error, 8 truncated |
| 4 | data length |
| 5 | data checksum |

The cells are 4 UI units wide, 64 per row. The script reads the centre of each cell, because the
edges are blended. Keep the geometry in `DevConsole.lua` and `tools/wow-dev.ps1` the same.

`reload` with the dev console waits for a new load ID instead of a fixed time. Then it runs
`AtlasiumDev.Dev.GetHealth()` and prints the report: debug mode, the load ID, the modules in `ns`, how
Lua errors are captured (`errorCapture`: `handler`, `BugGrabber` or `off`), and the number of Lua
errors from Atlasium files since the load, with the last one. With `errorCapture = "off"`, `errors = 0`
proves nothing.

Status: the console, the script and the specs are built and checked in the game. The strip colours
reach the capture exactly: 3 KB of all byte values and UTF-8 text pass the checksum. Typing and
Enter work with the map open and closed, and the click binding on Num Pad + works. A round trip
takes 0.5 to 0.9 seconds. `reload` waits for the new load ID and prints the health report. With
BugGrabber installed, an error in an Atlasium file shows in the report and the log.

## Minimap tiles alignment check

Debug mode adds `/atlasium minimap align on` and `off`. It draws the tiles at the current Blizzard
zoom, at half alpha, over the Blizzard ground. The Blizzard mask stays in place during this check.
If the scale and position are correct, the two maps match. The layer lets the mouse through.
Use the check outdoors. Indoor areas, instances and WMO cities use the Blizzard minimap.
`/atlasium minimap align off` ends the check.

Use the Blizzard + and - buttons to choose zoom levels during alignment checks.
The current zoom and indoor/outdoor CVars must agree for the fallback check.

Run these checks when changing the renderer:

1. Compare alignment at Blizzard zoom levels 0 through 5.
2. Track Flight Masters and check an engine dot over the custom terrain.
3. Enter a cave, Orgrimmar and an instance. Check that the Blizzard minimap returns.
4. Test a square minimap and the rotating minimap option.
5. Check frame rate while running and turning.
6. Check Dalaran floors, open sea and zone changes.
7. Open the world map, then reload the interface. Check the terrain and texture restoration.
8. Turn tiles off. Check that another add-on's mask returns and its blip texture stays unchanged.

Checks on 2026-10-04 at Razormane Grounds:

- Automated checks: 319 specs pass; luacheck reports no warnings or errors.
- Alignment overlays at zoom 0 through 5 look consistent.
- Tiles off restores Blizzard terrain and the original `BACKGROUND` strata.
- Opening and closing the world map leaves the custom minimap working.
- Rotation and a simulated square shape render at normal zoom.
  This checks the renderer, not integration with a square minimap add-on.

The failure had two causes. The world render covered the underlay in `BACKGROUND` strata.
The transparent mask also needed reapplication after loading. The renderer now raises a
background minimap to `LOW` while drawing and reapplies active swaps on `PLAYER_ENTERING_WORLD`.

Remaining field checks: an engine-only tracking blip, cave/city/instance fallback, performance
while running and turning, Dalaran floors, open sea, zone transitions and a real square minimap add-on.
Flight Master tracking produced no visible blip at this location, so that check is incomplete.

The final BugGrabber session has two errors from diagnostic commands: an unavailable
`GetNumErrors` method and an incorrect slash-handler name. Neither error comes from Atlasium.
The installed BugGrabber supports `GetDB()` and `GetSessionId()` for reading current-session errors.

Run `wow-dev.ps1` with desktop access when the sandbox reports `NOT_RUNNING` for a present process.
A zero window handle inside the sandbox does not prove that the client is stopped.

## With Claude Code

The `ingame-check` project skill runs this loop. It runs the specs, then `status`, then `reload`. It
checks state with `eval` and reads the Atlasium log with `log`. It uses screenshots only to check how
things look. To check the world map, it uses `mapopen` and `mapclose`, and it reads the state with
`mapstate`. When the script reports `RESTART_NEEDED` or
`NOT_RUNNING`, Claude Code stops and asks you to restart the client. It waits until you reply that the
game is back.

## Known limits

- Chat messages printed during loading can scroll out of the chat box before the screenshot,
  because other add-ons print after Atlasium. To check a change in a screenshot, show it on the
  screen, not in chat.
- Without the dev console, the script waits a fixed time after `/reload`. If the client loads
  slowly, increase `-LoadDelay`.
- Some states do not survive a reload, for example an open world map. Set them up again before the
  screenshot.
- If a chat box or menu is open in the client, the commands do not run. The script then reports
  `NO_RELOAD` or `NO_SCREENSHOT`. Close it and run the command again.
- With the map open, only the map keys work. Chat commands are lost, and `run` and `reload` refuse
  to type. Use `mapclose` first.
- The marker and the strip have no parent frame, so they stay visible when the fullscreen map or
  Alt-Z hides the UI.
- Each `eval` adds a `dev>` line to the chat. `-Until` adds one per try.
- An add-on cannot read files at run time, so a changed Lua file still needs `/reload`.
- The client does not count these messages as activity, so the character can go Away while you
  test.
