# Configuration

## Settings

Click the minimap button or type `/atlasium` to open the movable settings window. You can also use
**Interface → AddOns → Atlasium**. Both views offer the same controls. Changes apply immediately;
closing the window or clicking Cancel in Interface Options keeps them.

Choose **English** or **Português (Brasil)** in General. English is the default. Your choice applies
to Atlasium settings, tooltips, slash help and replies without a reload. Blizzard's own menu and
color picker use the client language. Developer logs stay in English.

Drag the window's title bar to move it. Close it with Escape or its close button. The window
position lasts for the current session.

| Setting | Default | How to change |
| --- | --- | --- |
| Language | English | Choose English or Português (Brasil) in General. |
| Debug mode | Off | Type `/atlasium debug` to switch on or off. It shows a small green or red square in the top-left corner and binds two Num Pad keys (developer aids). |
| Minimap button | Shown | Type `/atlasium minimap button off` or `/atlasium minimap button on`. |
| Minimap button position | Bottom-left edge of the minimap (225°) | Drag the button or use the 0–359° slider. |
| Minimap wheel zoom | On | Type `/atlasium minimap zoom off` or `/atlasium minimap zoom on`. |
| Minimap tiles (experimental) | On | Type `/atlasium minimap tiles off` or `/atlasium minimap tiles on`. Off restores the Blizzard minimap. |
| Fog clearing | On | Type `/atlasium worldmap fog off` or `/atlasium worldmap fog on`. |
| Map zoom and drag | On | Type `/atlasium worldmap zoom off` or `/atlasium worldmap zoom on`. |
| Largest zoom | 4 | Use the World Map slider, from 1–16× in steps of 0.25. |
| Zoom per wheel notch | 1.25 | Use the World Map slider, from 1.05–2 in steps of 0.05. |
| Unexplored area tint | Gray (`r`, `g`, `b` 0.6, `a` 1) | Click the tint button to choose a color and opacity. Cancel restores the previous tint. |

The on/off settings above also have checkboxes in the settings window. Debug mode is under
Advanced. Custom minimap terrain stays marked as experimental.

## Where your data is saved

Atlasium stores settings in the saved variable `AtlasiumDB`. The game writes it to
`WTF\Account\<account>\SavedVariables\Atlasium.lua` when you log out or reload the interface. It
is shared by all characters on the account.

New versions add default values for new settings and keep the ones you already have.

## Reset

Click **Restore Defaults** in the Atlasium window, or use the Defaults button in Interface
Options for Atlasium. This resets configuration, including the language, and keeps your saved log.

For a full reset, close the game, then delete `Atlasium.lua` from the `SavedVariables` folder above. Atlasium
starts with defaults next time.
