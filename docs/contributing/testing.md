# Testing

Tests are in `tests/*_spec.lua`. To run them, do `busted` from the root of the repository. The
tests run outside the game. Therefore they use a replacement for the WoW client.

## How the tests replace the client

`tests/helper.lua` has two functions:

- `loadAddonFile(path, ns)` loads a file as the client does. It gives `"Atlasium"` and `ns` to
  the file.
- `installWowStubs()` installs new replacements for `CreateFrame`, `DEFAULT_CHAT_FRAME`,
  `GetAddOnMetadata` and `SlashCmdList`. It also resets the saved variables. It returns a table.
  This table records the registered events, the scripts and the chat messages. A test can check
  these records.

In `before_each`, call `installWowStubs()` and make a new namespace. Then the state of one test
does not change the next test.

## What to test, and how

| Code | How to test |
| --- | --- |
| Pure helpers (`Util`) | Call them directly. Do not use stubs. |
| Event handlers | Call `ns.Core.OnEvent(nil, event, ...)`. Do not fire real events. |
| Slash commands | Call `SlashCmdList.ATLASIUM("...")`. Then check `ns.db` and the recorded chat messages. |
| XML layout, real frames, textures | The tests do not cover these. Check them in the game. |

## Add stubs

Stub only the functions that the code under test calls. When a test needs a new API function, add
the function to `installWowStubs()`. Also add it to `read_globals` in `.luacheckrc`.
