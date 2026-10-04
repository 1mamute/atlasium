# Conventions

These are the rules for Atlasium code. Where luacheck can enforce a rule, it does.

## Structure

- **No globals.** Use the shared `ns` table. The allowed globals are `AtlasiumDB`,
  `SLASH_ATLASIUM1` and `SlashCmdList["ATLASIUM"]`.
- **Frame names** create globals too. Give a frame a name only when the client or other add-ons
  need it, and start the name with `Atlasium` (for example `AtlasiumMinimapButton`). For example,
  Escape closes a window only if the window name is in `UISpecialFrames`, minimap button
  collectors find buttons by name, and XML `$parent` needs a named parent. Keep the frame in a
  module field (`MinimapButton.frame`), and use that field in code, not the global.
- **Optional add-ons** (TomTom, Questie): check that the add-on's global or API exists before you
  call it. Keep each integration in its own file, so the core works without it.

## Game behavior

- **Saved variables:** merge the defaults on `ADDON_LOADED` with `Util.CopyDefaults`. Never
  overwrite user data, and do not read `AtlasiumDB` before this event.
- **Events:** register events with `Core.RegisterEvent`. Unregister events you no longer need.
  `Core.RegisterEvent` keeps a list of handlers for each event. The handlers run in the order of
  registration, which is the load order of the files (for example `PLAYER_LOGIN` in
  `MinimapButton.lua`, then in `Dev.lua`).
- **Messages:** use `Log.Error` when code finds a problem, and `Log.Debug` for details that help
  a contributor. Use `Core.Print` only for replies to the player, for example slash command
  output. Do not check `ns.db.debug` before `Log.Debug`: the function does it.
- **Performance:** in code that runs often, cache API functions in locals
  (`local GetTime = GetTime`). Never create tables or closures in `OnUpdate`.
- **Add-on messages** (party sharing): use `SendAddonMessage` with a short, unique prefix (maximum
  16 bytes in 3.3.5a). Keep each payload under 255 bytes. Validate all data you receive from other
  players.

## Reference add-ons

- Carbonite, Mapster, Questie-335 and TomTom show how things work in the 3.3.5a client. Read their
  code to learn the behavior, then write our own code. Do not copy it: most of it is not MIT
  licensed.
- **Do not trust the minimap shape table in Questie-335.** The LibDBIcon-1.0 copy in
  `Compat/Libs/LibDBIcon-1.0/` (Rev 15) has a wrong `minimapShapes` table. It swaps several
  `CORNER-*`, `SIDE-*` and `TRICORNER-*` shapes. Use the rule in `MinimapButton.lua` instead.

## Language and style

- **Lua 5.1 only.** Do not use `goto`, bitwise operators or `//`. Use the `bit` library instead.
- **Format:** 4 spaces for indent, 120 columns maximum.
- **Names:** `PascalCase` for module functions, `camelCase` for locals.
- **Comments:** add a short `---` doc comment to each public function.

## Releases

- Increase `## Version` in the `.toc` for each release.
