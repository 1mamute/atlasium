# In-game testing

The specs do not cover XML layout, real frames or textures (see [testing.md](testing.md)). Check
these in a running 3.3.5a client. `tools/wow-dev.ps1` reloads the UI and takes a screenshot, so you
(or Claude Code) can check a change without leaving the editor.

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
4. Optional: install BugGrabber and BugSack (3.3.5 builds). Errors go to
   `WTF\Account\<ACCOUNT>\SavedVariables\!BugGrabber.lua`, which can be read after a reload.

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
| `./tools/wow-dev.ps1 reload` | Types `/reload`, waits `-LoadDelay` seconds (default 8), types `/run Screenshot()` and prints `SCREENSHOT: <path>`. |
| `./tools/wow-dev.ps1 screenshot` | Takes a screenshot without a reload. |

The script types the commands into the WoW chat box with window messages. The client stays in the
background, so you can keep using the computer. The client must show the game world with no menu
or chat box open.

`reload` checks that the reload happened. The client writes `Atlasium.lua` in
`WTF\Account\<ACCOUNT>\SavedVariables` on every reload. If the file is older than the `/reload`, the
script reports `NO_RELOAD`.

The script only sends text that starts with a slash command, because other text goes to public
chat. Run it from PowerShell, not Git Bash: Git Bash changes arguments that start with `/` into
file paths.

## With Claude Code

The `ingame-check` project skill runs this loop. It runs the specs, then `status`, then `reload`. It
reads the screenshot and the BugGrabber errors. When the script reports `RESTART_NEEDED` or
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
- The client does not count these messages as activity, so the character can go Away while you
  test.
