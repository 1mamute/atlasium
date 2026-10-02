# Configuration

## Settings

Atlasium currently has one setting.

| Setting | Default | How to change |
| --- | --- | --- |
| Debug messages | Off | Type `/atlasium debug` to switch on or off. |

There is no settings window yet.

## Where your data is saved

Atlasium stores settings in the saved variable `AtlasiumDB`. The game writes it to
`WTF\Account\<account>\SavedVariables\Atlasium.lua` when you log out or reload the interface. It
is shared by all characters on the account.

New versions add default values for new settings and keep the ones you already have.

## Reset

Close the game, then delete `Atlasium.lua` from the `SavedVariables` folder above. Atlasium
starts with defaults next time.
