# Usage

## Slash commands

Type these in the chat box. `/atlasium` with no command, or with an unknown one, lists the
available commands.

| Command | What it does |
| --- | --- |
| `/atlasium version` | Shows the installed version. |
| `/atlasium debug` | Turns debug messages on or off. Type it again to switch back. |
| `/atlasium minimap` | Hides the minimap button. Type it again to show the button. |
| `/atlasium fog on` | Turns fog clearing on. |
| `/atlasium fog off` | Turns fog clearing off, so the map shows the normal fog again. |

## Minimap button

Atlasium puts a round button with a question mark on the edge of your minimap. The question mark
is a placeholder until Atlasium gets its own icon.

- **Left-click** opens or closes the world map, like the M key.
- **Drag** the button with the left mouse button to move it around the edge of the minimap. It
  remembers its spot after a reload or logout.
- **Point at it** to see a tooltip with the version and these actions.

If an add-on such as SexyMap gives your minimap a square shape, the button follows the square
edge.

## Fog clearing

Normally the world map hides the parts of a zone you have not explored yet. With Atlasium, the
map shows the whole zone. Areas you have explored look the same as before, and areas you have not
explored yet are slightly darker.

- Fog clearing works on zone maps. Continent, city and dungeon maps do not change.
- Type `/atlasium fog off` to bring the fog back, and `/atlasium fog on` to clear it again. If
  the map is open, it changes at once. `/atlasium fog` on its own shows whether it is on or off.
- Atlasium remembers your choice after a reload or logout.

Use one map add-on at a time. If Mapster's fog clearing is also on, Atlasium darkens every area.

## Using the map

Map navigation, notes and the integrations are planned. This page will describe them as they
are built. See [Features](features.md) for the current status.
