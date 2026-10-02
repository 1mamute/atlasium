# Configuration

## Settings

| Setting | Default | How to change |
| --- | --- | --- |
| Debug messages | Off | Type `/atlasium debug` to switch on or off. |
| Minimap button | Shown | Type `/atlasium minimap` to hide or show it. |
| Minimap button position | Bottom-left edge of the minimap | Drag the button around the minimap. |
| Fog clearing | On | Type `/atlasium fog` to switch it off or on. |
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
