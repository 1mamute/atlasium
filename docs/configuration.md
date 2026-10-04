# Configuration

## Settings

| Setting | Default | How to change |
| --- | --- | --- |
| Debug mode | Off | Type `/atlasium debug` to switch on or off. It shows a small green or red square in the top-left corner and binds two Num Pad keys (developer aids). |
| Minimap button | Shown | Type `/atlasium minimap` to hide or show it. |
| Minimap button position | Bottom-left edge of the minimap | Drag the button around the minimap. |
| Fog clearing | On | Type `/atlasium fog off` or `/atlasium fog on`. |
| Map zoom and drag | On | Type `/atlasium zoom off` or `/atlasium zoom on`. |
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
