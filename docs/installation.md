# Installation

> Atlasium has no release yet. For now, install it from the source code. Expect missing features.

## Requirements

- World of Warcraft **3.3.5a** (WotLK, interface 30300). Other versions are not supported.

## Install

1. Download or clone the Atlasium repository.
2. Copy the `Atlasium` folder (the one that contains `Atlasium.toc`) into
   `<WoW folder>\Interface\AddOns\`.
3. Start the game. At the character screen, click **AddOns** and make sure Atlasium is enabled.

The result should be `<WoW folder>\Interface\AddOns\Atlasium\Atlasium.toc`. If the path has an
extra folder level (for example `Atlasium\Atlasium\Atlasium.toc`), the game will not see the
add-on.

## Check that it works

Log in and type:

```
/atlasium version
```

You should see a chat message such as `Atlasium: v0.1.0`.

## Update

Replace the `Atlasium` folder in `Interface\AddOns` with the new version. Your settings are kept
(see [Configuration](configuration.md)).

## Uninstall

Delete the `Atlasium` folder from `Interface\AddOns`. To also remove saved settings, delete
`AtlasiumDB` from `WTF\Account\<account>\SavedVariables\Atlasium.lua` while the game is closed.
