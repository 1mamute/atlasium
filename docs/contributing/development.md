# Development

This page tells you how to prepare your environment, run the checks and add code.

## 1. Install the add-on in the game

Make a symbolic link from the `Atlasium` folder to the WoW add-ons folder. Then each edit shows in
the game without a copy. Use PowerShell as administrator, or turn on Developer Mode.

```powershell
New-Item -ItemType SymbolicLink `
  -Path "<WoW folder>\Interface\AddOns\Atlasium" `
  -Target "<path to this repo>\Atlasium"
```

1. Replace `<WoW folder>` with the folder of your 3.3.5a installation.
2. Replace `<path to this repo>` with the folder where you cloned Atlasium.

After each change, type `/reload` in the game. To make sure that the add-on loaded, type
`/atlasium version`.

## 2. Install the tools

You need three tools:

- Lua 5.1. This is the version that the game client uses.
- [busted](https://lunarmodules.github.io/busted/) for tests.
- [luacheck](https://github.com/lunarmodules/luacheck) for lint.

Install busted and luacheck with LuaRocks:

```
luarocks install busted
luarocks install luacheck
```

On Windows, use WSL. It is the easiest way to get LuaRocks with Lua 5.1.

## 3. Run the checks

Go to the root of the repository. Then do these commands:

```
luacheck Atlasium tests    # lint
busted                     # run all specs (settings are in .busted)
```

CI does the same two commands for each push. Make sure that they pass on your computer first.

## Add a file

1. Make the file `Atlasium/Foo.lua`. Start it with `local _, ns = ...`.
2. Add the file to `Atlasium/Atlasium.toc`, after the files that it needs.
3. Add each new WoW API function that the file uses to `read_globals` in `.luacheckrc`. If the
   tests need the function, add a stub in `tests/helper.lua`.
4. Make the file `tests/foo_spec.lua`.

Before you use a WoW function, event or widget method, make sure that it exists in 3.3.5a. Many
modern APIs do not exist in this version.

Next: [Testing](testing.md) and [Conventions](conventions.md).
