# Installation

Download the player package from [GitHub Releases](https://github.com/1mamute/atlasium/releases/latest).

## Requirements

- World of Warcraft **3.3.5a** (WotLK, interface 30300). Other versions are not supported.

## Install

1. Download the attached `Atlasium-v1.0.0.zip` (or a newer `Atlasium-v*.zip`) and extract it.
   Use this ZIP instead of GitHub's automatic source archives.
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

You should see a chat message such as `Atlasium: v1.0.0`.

## Update

Replace the `Atlasium` folder in `Interface\AddOns` with the new version. Your settings are kept
(see [Configuration](configuration.md)).

## Uninstall

Delete the `Atlasium` folder from `Interface\AddOns`. To also remove saved settings, delete
`AtlasiumDB` from `WTF\Account\<account>\SavedVariables\Atlasium.lua` while the game is closed.
