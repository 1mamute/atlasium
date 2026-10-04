# Configuration

## Settings

| Setting | Default | How to change |
| --- | --- | --- |
| Debug mode | Off | Type `/atlasium debug` to switch on or off. It shows a small green or red square in the top-left corner and binds two Num Pad keys (developer aids). |
| Minimap button | Shown | Type `/atlasium minimap button off` or `/atlasium minimap button on`. |
| Minimap button position | Bottom-left edge of the minimap | Drag the button around the minimap. |
| Minimap wheel zoom | On | Type `/atlasium minimap zoom off` or `/atlasium minimap zoom on`. |
| Minimap tiles (experimental) | On | Type `/atlasium minimap tiles off` or `/atlasium minimap tiles on`. Off restores the Blizzard minimap. |
| Largest minimap far zoom | 4 (times the game's farthest zoom) | Type `/atlasium minimap farmax <number>`, from 1.5 to 16. |
| Minimap far zoom per wheel notch | 1.4 | Edit `minimapTiles.farStep` in the saved variables file while the game is closed. |
| Fog clearing | On | Type `/atlasium worldmap fog off` or `/atlasium worldmap fog on`. |
| Map zoom and drag | On | Type `/atlasium worldmap zoom off` or `/atlasium worldmap zoom on`. |
| Largest zoom | 4 | Edit `mapNav.maxZoom` in the saved variables file while the game is closed. |
| Zoom per wheel notch | 1.25 | Edit `mapNav.step` in the saved variables file while the game is closed. |
| Unexplored area tint | Gray (`r`, `g`, `b` 0.6, `a` 1) | Edit `fogClear.color` in the saved variables file while the game is closed. |

There is no settings window yet.

## Where your data is saved

Atlasium stores settings in the saved variable `AtlasiumDB`. The game writes it to
`WTF\Account\<account>\SavedVariables\Atlasium.lua` when you log out or reload the interface. It
is shared by all characters on the account.

New versions add default values for new settings and keep the ones you already have.

## Reset

Close the game, then delete `Atlasium.lua` from the `SavedVariables` folder above. Atlasium
starts with defaults next time.
