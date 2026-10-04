# Usage

## Slash commands

Type these in the chat box. `/atlasium` with no command, or with an unknown one, lists the
available commands.

| Command | What it does |
| --- | --- |
| `/atlasium version` | Shows the installed version. |
| `/atlasium debug` | Turns debug mode on or off. Type it again to switch back. In debug mode a small green or red square shows in the top-left corner of the screen (green: world map open), and the Num Pad `*` and `-` keys open the map and take a screenshot. These are developer aids. |
| `/atlasium minimap` | Shows the minimap settings and whether each one is on or off. |
| `/atlasium minimap button on` | Shows the minimap button. |
| `/atlasium minimap button off` | Hides the minimap button. |
| `/atlasium minimap zoom on` | Turns minimap wheel zoom on. |
| `/atlasium minimap zoom off` | Turns minimap wheel zoom off. Custom tiles stay enabled. |
| `/atlasium minimap tiles on` | Enables custom minimap terrain (experimental). |
| `/atlasium minimap tiles off` | Restores the Blizzard terrain. |
| `/atlasium minimap align on` or `off` | Compares custom tiles with Blizzard terrain at half alpha. Requires debug mode. |
| `/atlasium worldmap` | Shows the world map settings and whether each one is on or off. |
| `/atlasium worldmap zoom on` | Turns map zoom and drag on. |
| `/atlasium worldmap zoom off` | Turns map zoom and drag off, so the map works as normal. |
| `/atlasium worldmap fog on` | Turns fog clearing on. |
| `/atlasium worldmap fog off` | Turns fog clearing off, so the map shows the normal fog again. |

Leave out `on` or `off` to see whether a setting is on, for example `/atlasium worldmap fog`.

## Minimap button

Atlasium puts a round button with a question mark on the edge of your minimap. The question mark
is a placeholder until Atlasium gets its own icon.

- **Left-click** opens or closes the world map, like the M key.
- **Drag** the button with the left mouse button to move it around the edge of the minimap. It
  remembers its spot after a reload or logout.
- **Point at it** to see a tooltip with the version and these actions.
- Type `/atlasium minimap button off` to hide it, and `/atlasium minimap button on` to bring it
  back.

If an add-on such as SexyMap gives your minimap a square shape, the button follows the square
edge.

## Minimap wheel zoom

- **Mouse wheel up** over the minimap zooms in one step, **wheel down** zooms out one step. It
  works just like the + and - buttons next to the minimap, and the buttons stay in sync.
- At the closest and farthest zoom, more turns of the wheel do nothing.
- A plain click on the minimap still pings it, as normal.
- The game keeps one zoom for indoors and one for outdoors, as it always does.
- If another add-on already uses the mouse wheel on the minimap, Atlasium leaves it alone.
- Type `/atlasium minimap zoom off` to turn it off, and `/atlasium minimap zoom on` to turn it
  back on.

## Minimap tiles

This feature is experimental. Outdoor rendering is checked in the client.
Indoor, city and instance fallback still need field checks.

- Atlasium draws raw terrain without lighting at all six game zoom levels. The client draws
  your arrow and dots over the terrain.
- The tiles follow the minimap shape and the rotating minimap option.
- Indoors, instances, Orgrimmar, Thunder Bluff, Darnassus, the Exodar and Ironforge use the
  Blizzard minimap.
- `/atlasium minimap tiles off` restores the Blizzard minimap. `/atlasium minimap zoom off`
  disables the wheel, while custom tiles stay enabled.
- Known compatibility limit: a square mask set before Atlasium loads its texture hooks cannot
  yet be restored automatically.

## Fog clearing

Normally the world map hides the parts of a zone you have not explored yet. With Atlasium, the
map shows the whole zone. Areas you have explored look the same as before, and areas you have not
explored yet are slightly darker.

- Fog clearing works on zone maps. Continent, city and dungeon maps do not change.
- Type `/atlasium worldmap fog off` to bring the fog back, and `/atlasium worldmap fog on` to
  clear it again. If the map is open, it changes at once. `/atlasium worldmap fog` on its own
  shows whether it is on or off.
- Atlasium remembers your choice after a reload or logout.

Use one map add-on at a time. If Mapster's fog clearing is also on, Atlasium darkens every area.

## Map zoom and drag

- **Mouse wheel** over the world map zooms in or out around the cursor, up to 4x.
- **Drag** with the left mouse button to move the zoomed map. It stops at the map edges.
- **Click** without dragging works as before, for example to open a zone. Right-click still goes
  one map level up.
- Your arrow, party members, quest markers and town icons keep their size while you zoom.
- The zoom goes back to normal when you close the map or change zone, floor or map size.
- In combat, zoom and drag still work. The blue quest areas are hidden until the fight ends.
- Type `/atlasium worldmap zoom off` to turn it off, and `/atlasium worldmap zoom on` to turn it
  back on. Atlasium remembers your choice.

Questie's map icons follow the zoom and the drag, but they grow with the zoom for now.

## Using the map

Notes and the integrations are planned. This page will describe them as they
are built. See [Features](features.md) for the current status.
