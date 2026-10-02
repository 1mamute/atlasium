# Contributing

This section is for developers. It tells you how to build, test and change Atlasium. To learn
what Atlasium does for players, read the [project README](../../README.md).

## Read in this order

1. [Development](development.md): install the tools, link the add-on into the game, run the tests.
2. [Architecture](architecture.md): how the code is organized, and why.
3. [Testing](testing.md): how the tests replace the WoW client, and what to test.
4. [Conventions](conventions.md): coding rules for 3.3.5a Lua.

## Before you submit a change

1. Run `luacheck Atlasium tests`. Fix all warnings.
2. Run `busted`. Make sure that all specs pass.
3. Make sure that each new file has a matching spec in `tests/`.
4. Make sure that each WoW function that you use exists in 3.3.5a.
5. If you change player-visible behavior, update the player docs in `docs/`.

CI runs the same lint and test commands for each push.

## References

Atlasium takes ideas from Carbonite, Mapster, Questie-335 and TomTom. Read how these add-ons solve
a problem before you design a new function.
