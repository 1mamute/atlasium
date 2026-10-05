# Contributing

This section is for developers. It explains how to build, test and change Atlasium. To learn what
Atlasium does for players, read the [project README](../home.md).

## Read in this order

1. [Development](development.md): install the tools, link the add-on into the game, run the checks.
2. [Architecture](architecture.md): how the code is organized, and why.
3. [Testing](testing.md): how the specs mock the WoW client, and what to test where.
4. [In-game testing](in-game-testing.md): check a change in the real client.
5. [Conventions](conventions.md): coding rules for 3.3.5a Lua.
6. [Releases](releases.md): version numbers, commit messages, tags and release archives.

## Before you submit a change

1. Run `luacheck Atlasium tests` and fix all warnings.
2. Run `busted` and check that all specs pass.
3. Give each new file a matching spec in `tests/`.
4. Check that every WoW function you use exists in 3.3.5a.
5. If you change what players see, update the player docs in `docs/`.

CI runs the same lint and test commands on every push.
