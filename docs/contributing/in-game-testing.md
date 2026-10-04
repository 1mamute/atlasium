# In-game testing

The specs do not cover XML layout, real frames or textures (see [testing.md](testing.md)). Check
these in a running 3.3.5a client. `tools/wow-dev.ps1` reloads the UI, takes a screenshot, and opens
and closes the world map, so you (or Claude Code) can check a change without leaving the editor.

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
4. Type `/atlasium debug` in the client to turn on debug mode. The map modes and the screenshots of
   the script need it (see [Debug mode](#debug-mode-map-marker-and-keys)). The setting is saved, so
   you do it once.
5. Optional: install BugGrabber and BugSack (3.3.5 builds). Errors go to
   `WTF\Account\<ACCOUNT>\SavedVariables\!BugGrabber.lua`, which can be read after a reload.

## Atlasium log

Atlasium writes its error and debug messages to chat and to a saved log. Debug messages need debug
mode. To read the log after a session:

1. Type `/reload`, or log out. The client writes saved variables only on reload, logout or exit.
2. Open `WTF\Account\<ACCOUNT>\SavedVariables\Atlasium.lua`.
3. Find the `log` table. It holds the newest 200 entries, oldest first.

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
| `./tools/wow-dev.ps1 reload` | Checks that the map is closed, types `/reload`, waits `-LoadDelay` seconds (default 8), takes a screenshot and prints `SCREENSHOT: <path>`. |
| `./tools/wow-dev.ps1 screenshot` | Takes a screenshot with a key, without a reload. |
| `./tools/wow-dev.ps1 run -Lua '<code>'` | Checks that the map is closed, types `/run <code>`, takes a screenshot and prints `SCREENSHOT: <path>`. |
| `./tools/wow-dev.ps1 mapstate` | Takes a screenshot, reads the map marker and prints `MAP_OPEN`, `MAP_CLOSED` or `NO_MARKER` with the path. |
| `./tools/wow-dev.ps1 mapopen` | Opens the world map if it is closed. It checks the result with a second screenshot. |
| `./tools/wow-dev.ps1 mapclose` | Closes the world map if it is open. It checks the result with a second screenshot. |

The script types slash commands into the WoW chat box with window messages. It presses keys with
the same messages. The client stays in the background, so you can keep using the computer. The
client must show the game world with no menu or chat box open.

Exit codes: 0 ok, 2 client not running, 3 restart needed, 4 screenshot not found, 5 reload did not
happen, 6 no map marker, 7 the map did not open or close, 8 the map is open, so the script did not
type.

`reload` checks that the reload happened. The client writes `Atlasium.lua` in
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

The client refuses binding changes in combat. When you turn debug mode on or off in combat, the
add-on changes the keys when combat ends. The marker is not protected, so it changes at once.

The script reads the marker from the screenshot: it checks the centre of the square, and accepts the
state when at least 90% of those pixels are clearly green or clearly red. The check uses screenshot
pixels, so the window size does not matter.

Without debug mode there is no marker and no key. Then `mapstate`, `mapopen` and `mapclose` print
`NO_MARKER`, and `screenshot` finds no file. `screenshot -ChatFallback` types `/run Screenshot()`
instead. Use it only when you know that the map is closed.

`run` and `reload` read the marker before they type. If the map is open, they print `MAP_OPEN` and do
not type (exit code 8). Use `mapclose` first. If the marker is missing, they print `NO_MARKER` and
type as before, because they cannot know the state. `reload -SkipMapCheck` skips the check, and saves
the extra screenshot. Each map check adds one screenshot file to the `Screenshots` folder.

The script never sends Escape. With the map closed, Escape opens the game menu.

Status: the script, the marker, the keys and the specs are built. The specs cover the marker and
the key logic with stubs, and the script reads the marker correctly from test JPEG files. The
following points need a check in the game (they are not verified yet):

- the client accepts `NUMPADMULTIPLY` and `NUMPADMINUS` from posted messages;
- the key names that `OnKeyDown` receives match the names above;
- the marker is visible above the open world map.

## With Claude Code

The `ingame-check` project skill runs this loop. It runs the specs, then `status`, then `reload`. It
reads the screenshot and the BugGrabber errors. To check the world map, it uses `mapopen` and
`mapclose`, and it reads the state with `mapstate`. When the script reports `RESTART_NEEDED` or
`NOT_RUNNING`, Claude Code stops and asks you to restart the client. It waits until you reply that the
game is back.

## Known limits

- Chat messages printed during loading can scroll out of the chat box before the screenshot,
  because other add-ons print after Atlasium. To check a change in a screenshot, show it on the
  screen, not in chat.
- The script waits a fixed time after `/reload`. If the client loads slowly, increase `-LoadDelay`.
- Some states do not survive a reload, for example an open world map. Set them up again before the
  screenshot.
- If a chat box or menu is open in the client, the commands do not run. The script then reports
  `NO_RELOAD` or `NO_SCREENSHOT`. Close it and run the command again.
- With the map open, only the map keys work. Chat commands are lost, and `run` and `reload` refuse
  to type. Use `mapclose` first.
- The marker has no parent frame, so it stays visible when the fullscreen map or Alt-Z hides the UI.
- The client does not count these messages as activity, so the character can go Away while you
  test.
