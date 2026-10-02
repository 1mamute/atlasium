# Testing

Specs are in `tests/*_spec.lua`. Run them with `busted` from the root of the repository. They run
outside the game, so they mock the WoW client.

## How the specs mock the client

`tests/helper.lua` has two functions:

- `loadAddonFile(path, ns)` loads a file the way the client does, passing `"Atlasium"` and `ns`.
- `installWowStubs()` installs fresh mocks of `CreateFrame`, `DEFAULT_CHAT_FRAME`,
  `GetAddOnMetadata` and `SlashCmdList`, and resets the saved variables. It returns a table that
  records registered events, scripts and chat messages, so a spec can check them.

In `before_each`, call `installWowStubs()` and create a new namespace. This stops state from one
spec leaking into the next.

## What to test, and how

| Code | How to test |
| --- | --- |
| Pure helpers (`Util`) | Call them directly. No stubs needed. |
| Event handlers | Call `ns.Core.OnEvent(nil, event, ...)` instead of firing real events. |
| Slash commands | Call `SlashCmdList.ATLASIUM("...")`, then check `ns.db` and the recorded chat messages. |
| XML layout, real frames, textures | Specs do not cover these. Check them in the game (see [In-game testing](in-game-testing.md)). |

## Add stubs

Stub only the functions that the code under test calls. When a spec needs a new API function, add
it to `installWowStubs()` and to `read_globals` in `.luacheckrc`.
