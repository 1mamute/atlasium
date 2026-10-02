# Testing

Specs are in `tests/*_spec.lua`. Run them with `busted` from the root of the repository. They run
outside the game, so they mock the WoW client.

## How the specs mock the client

`tests/helper.lua` has two functions:

- `loadAddonFile(path, ns)` loads a file the way the client does, passing `"Atlasium"` and `ns`.
- `installWowStubs()` installs fresh mocks of the WoW globals and resets the saved variables. It
  returns a `state` table that records what the code did, so a spec can check it.

These are the stubs:

| Stub | Behavior |
| --- | --- |
| `CreateFrame(type, name, parent)` | Returns a fake frame (see below). A named frame also becomes a global, as in the client. |
| `Minimap` | 140 × 140, center at (940, 680), effective scale 1. |
| `UIParent` | A 1024 × 768 screen. |
| `GameTooltip`, `WorldMapFrame` | Fake widgets that record all calls. |
| `GetCursorPosition()` | Returns `state.cursor.x` and `state.cursor.y`. |
| `ToggleFrame(frame)` | Adds the frame to `state.toggled`. |
| `GetMinimapShape` | `nil`, as in the 3.3.5 client. Set it in a spec to act as a shape add-on such as SexyMap. |
| `DEFAULT_CHAT_FRAME`, `GetAddOnMetadata`, `SlashCmdList` | Chat messages go to `state.messages`. The version is `0.1.0`. |

The `state` table also has `events` (registered events), `scripts` (scripts set on any frame) and
`frames` (all created frames).

A fake frame keeps real state for `Show`, `Hide`, `IsShown`, `GetParent`, `GetName`, `SetScript`
and `GetScript`. `CreateTexture` returns a fake texture. Any other method with a `PascalCase` name
is accepted and recorded in `fake.calls[method]`. Use `helper.lastCall(fake, method)` to get the
arguments of the last call. To change what a method returns, set it on the fake, for example
`frame.GetCenter = function() return 883, 623 end`. Use `helper.newFake()` to make other fake
widgets.

In `before_each`, call `installWowStubs()` and create a new namespace. This stops state from one
spec leaking into the next. `installWowStubs()` also removes the globals of named frames from the
previous spec.

## What to test, and how

| Code | How to test |
| --- | --- |
| Pure helpers (`Util`) | Call them directly. No stubs needed. |
| Event handlers | Call `ns.Core.OnEvent(nil, event, ...)` instead of firing real events. |
| Slash commands | Call `SlashCmdList.ATLASIUM("...")`, then check `ns.db` and the recorded chat messages. |
| Frame scripts (`OnClick`, `OnDragStart`) | Get the script with `frame:GetScript(name)` and call it with the arguments that the client sends. |
| XML layout, real frames, textures | Specs do not cover these. Check them in the game (see [In-game testing](in-game-testing.md)). |

## Add stubs

Stub only the functions that the code under test calls. When a spec needs a new API function, add
it to `installWowStubs()`, to `read_globals` in `.luacheckrc` and to the globals for `tests/` in
`.luacheckrc`.

Use `assert.near` to compare floating-point values, such as positions from `math.cos`.
