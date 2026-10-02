# Conventions

These are the rules for Atlasium code. Where luacheck can enforce a rule, it does.

## Structure

- **No globals.** Use the shared `ns` table. The allowed globals are `AtlasiumDB`,
  `SLASH_ATLASIUM1` and `SlashCmdList["ATLASIUM"]`.
- **Optional add-ons** (TomTom, Questie): check that the add-on's global or API exists before you
  call it. Keep each integration in its own file, so the core works without it.

## Game behavior

- **Saved variables:** merge the defaults on `ADDON_LOADED` with `Util.CopyDefaults`. Never
  overwrite user data, and do not read `AtlasiumDB` before this event.
- **Events:** register events with `Core.RegisterEvent`. Unregister events you no longer need.
- **Performance:** in code that runs often, cache API functions in locals
  (`local GetTime = GetTime`). Never create tables or closures in `OnUpdate`.
- **Add-on messages** (party sharing): use `SendAddonMessage` with a short, unique prefix (maximum
  16 bytes in 3.3.5a). Keep each payload under 255 bytes. Validate all data you receive from other
  players.

## Language and style

- **Lua 5.1 only.** Do not use `goto`, bitwise operators or `//`. Use the `bit` library instead.
- **Format:** 4 spaces for indent, 120 columns maximum.
- **Names:** `PascalCase` for module functions, `camelCase` for locals.
- **Comments:** add a short `---` doc comment to each public function.

## Releases

- Increase `## Version` in the `.toc` for each release.
