# Conventions

These are the rules for Atlasium code. Where luacheck can enforce a rule, it does.

## Structure

- **Do not use globals.** Use the shared `ns` table. The allowed globals are `AtlasiumDB`,
  `SLASH_ATLASIUM1` and `SlashCmdList["ATLASIUM"]`.
- **Optional add-ons** (TomTom, Questie): before you call the add-on, make sure that its global or
  API exists. Put each integration in its own file. Then the core works without the add-on.

## Game behavior

- **Saved variables:** merge the defaults on `ADDON_LOADED` with `Util.CopyDefaults`. Do not
  overwrite user data. Do not read `AtlasiumDB` before this event.
- **Events:** register events with `Core.RegisterEvent`. Unregister the events that you do not need
  again.
- **Performance:** in code that runs often, cache API functions in locals (`local GetTime =
  GetTime`). Do not create tables or closures in `OnUpdate`.
- **Add-on messages** (party sharing): use `SendAddonMessage` with a short, unique prefix. The
  prefix is a maximum of 16 bytes in 3.3.5a. Keep each payload under 255 bytes. Validate all data
  that you receive from other players.

## Language and style

- **Use Lua 5.1 only.** Do not use `goto`, bitwise operators or `//`. Use the `bit` library.
- **Format:** use 4 spaces for indent. Use a maximum of 120 columns.
- **Names:** use `PascalCase` for module functions. Use `camelCase` for locals.
- **Comments:** add a short `---` doc comment to each public function.

## Releases

- For each release, increase `## Version` in the `.toc`.
