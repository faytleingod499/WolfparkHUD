# Wolfpark HUD

A client mod (for [GDWeave](https://thunderstore.io/c/webfishing/p/NotNet/GDWeave/)) that adds a small panel with
your wolf coin balance, a **Feed Wolves** button, a **Buy** menu (everything the server sells) and a bet box with a **Gamble** button.

*This mod was created with the assistance of AI.*

On such a server anything you type that starts with `!` is sent to the server only and does not show in chat, and the buttons do the same. The heading (default "Ether's Wolf Park", cyan) comes from `hudTitle` / `hudTitleColor` in `feed.txt`. Server messages (chat lines with no player name) are shown in sky blue; change or disable it with `hudChatColor` in `feed.txt`. A small clipboard icon next to the heading (tooltip "Leaderboard") runs `!wolves`. The chat window also starts expanded (you can still shrink it).

It only appears on servers that run the `Feed` server plugin (the plugin marks the server through
the Steam lobby data). On every other server the mod stays hidden and does nothing.

## Admin panel
Admins (listed in the server's `admins.cfg`) get a shield button left of the heading. It opens a list of all players
except the host and yourself, with **Kick** and **Ban** (Ban needs a second click). The buttons send the server's own
`!kick <SteamID>` / `!ban <SteamID>` commands, hidden from chat. The Feed plugin tells the mod who is an admin through
the lobby data key `wp_admins` (the Steam IDs of the admins online), so the Feed plugin must be updated too.

## Chalk menu
A **Chalk** button opens a menu for the server's `ChalkSaves` plugin: a canvas picker (follows the nearest canvas until
you click one), a name box with **Save**, and your saves with **Load**, **Share** (pick an online player) and **Delete**.
Load, Delete and saving over a save need a second click. A waiting share shows **Accept** / **Decline**. The buttons send
the plugin's own `!chalksave`, `!chalkload`, `!chalkshare`, `!chalkdelete`, `!chalkaccept` and `!chalkdecline`, hidden from chat.

Admins also get **All players**: every player with saves (online or not, the 120 most recently saved), each opening to
their drawings with **Load** and **Delete** (the commands with the player's Steam ID added). The mod asks for this list
with `!chalkowners` / `!chalkbrowse <SteamID>`, and the plugin only publishes it while an admin has it open.

The ChalkSaves plugin publishes into the lobby data: `wp_chalk` = `saveAll,loadAll,maxSaves,loadCooldown`,
`wp_cs<SteamID>` = that player's save names, `wp_co<SteamID>` = `from~name` for a waiting share, and for admins with
the list open `wp_ca<SteamID>` = `id~name~count;...` and `wp_cb<SteamID>` = `id~name,name`. The Chalk button only
shows when `wp_chalk` is set.

## Help button
A **?** button left of the heading (right of the admin shield for admins) opens the list of commands the player can use.
Opening it sends `!help` hidden; the server's answer ("Commands:" and one `command - description` line each, cut into
~480 character messages by the server) is taken out of the chat as it arrives, joined back up and shown as the list.
Server messages that are not part of the answer, and every player message, stay in chat. Clicking a command opens
the chat with `!command ` typed in. No server changes are needed.

## Install (players)
1. Install GDWeave if you do not have it yet.
2. Copy the `WolfparkHUD` folder from `package/` into `WEBFISHING/GDWeave/mods/`.
   It must contain `manifest.json` and `WolfparkHUD.pck`.
3. Start the game and join the server. The panel appears at the top left. Drag the `::` handle to move it, the
   position is remembered.

## Server
Replace the Feed plugin's DLL in `plugins/` with the new build and run `!reloadplugins feed` (or restart). Nothing to
configure; what the Buy menu lists comes from `shop.txt` (created next to `feed.txt`), the heading and gambling odds from `feed.txt`.

## How it works
The Feed plugin writes `wp_hud=1`, `wp_meteor_cost` and `wp_shop` (what the Buy menu lists), `wp_gamble` (bet limits) and one `wp_p<SteamID>` = `coins,feeds[,roll,multiplier,change]` entry per online player
into the lobby data. The mod reads its own entry once or twice a second. The buttons type `!feed` / `!meteor` for
you through the game's own chat, so the server needs no extra packet.

## Rebuilding the .pck
`source/mods/WolfparkHUD/main.gd` is the whole mod. To rebuild the pack, run `godot --no-window -s pack.gd`
with Godot 3.5 from this folder.

## Titles

The mod adds the titles **Lonely** and **Battery Charger** to the game's title list (Cosmetics, Misc tab) while you are on the server. It is taken off again when you leave the server or close the game.

If **LureRefreshed** is installed the title is registered through Lure (as `WolfparkHUD.lonely`), which is what Lure needs to draw it, and players without the mod just get a blank title from Lure. Without Lure it is added to the game directly, and players without this mod see the wearer as a default-looking character.

## Building

The mod is plain GDScript (plus models and sounds) packed into `package/WolfparkHUD/WolfparkHUD.pck` with the Godot 3.5 engine's own packer:

```
godot --no-window -s pack.gd
./build.sh
```

`pack.gd` packs `source/mods/WolfparkHUD/` into the pck. `build.sh` then makes `out/WolfparkHUD-mod.zip` (the folder for `GDWeave/mods`) and the Thunderstore upload zip from `thunderstore/`. Requires [GDWeave](https://thunderstore.io/c/webfishing/p/NotNet/GDWeave/).

## License

[MIT](LICENSE): you are free to copy, change and share your own versions of this mod, as long as you keep the copyright notice.
