# Wolfpark HUD

The player panel for **Ether's Wolf Park**.

*This mod was created with the assistance of AI.*

It adds a small panel at the top left with:

- your **wolf coin** balance (on Wolf Park every fish you catch earns coins by quality: Normal 1 up to Alpha 6),
- a **Feed Wolves** button,
- a **Buy** menu listing everything the server sells (including temporary buffs like the game's drinks),
- a bet box with a **Gamble** button,
- a **Leaderboard** button,
- a **Chalk** menu for your saved chalk drawings,
- a **?** button listing every command you can use, click one to send it (commands that need more open a small box).

Drag the `::` handle to move the panel; it remembers where you put it. **Click** the handle (without dragging)
to fold the panel into a small wolf-face button, drag that to move it, click it to open the panel again.
Commands you type starting with `!` go to the server only and don't show in chat. Server messages show in
their own colour (sky blue by default), and the chat window starts expanded. The round colour swatch next to
the **?** button opens a hue slider (with white at the left end and black at the right end) to pick another colour for server messages in your own chat; **Reset** goes
back to the server's colour.

While you're on the server you can also wear the titles **Lonely** and **Battery Charger** (Cosmetics, Misc tab).
They're taken off again when you leave.

## Chalk saves

The **Chalk** button opens a menu under the panel. Pick a canvas (it starts on the one nearest to you), type a
name and press **Save** to keep what's drawn there. Your saves are listed below with **Load** (puts it on the
picked canvas), **Share** (pick a player to offer a copy to) and **Delete**. Loading, deleting and saving over
an existing save ask for a second click ("Sure?"). Admins also get a **Clear** button next to the canvas
numbers that wipes the picked canvas for everyone (second click to confirm). When someone shares a save with you, **Accept** and
**Decline** appear in the menu. Click a save's name to put it in the name box.

## For admins

Server admins get a small shield button to the left of the title. It opens a list of everyone on the server
(except the host) under the panel, with **Kick** and **Ban** beside each name. Ban opens a box for the reason
(optional); the Ban button in the box (or Enter) sends it, so it can't happen by accident. The buttons use the server's own kick and ban commands, so the
server still checks that you're an admin.

The **Bans** button at the top of that list shows the server's ban list (bans.txt), newest first, with the reason
under each name. **Unban** (second click to confirm) removes a ban; **Reason** adds or changes the reason. This needs
the updated server; **Players** goes back to the player list.

In the Chalk menu, admins also get **All players**: everyone who has chalk saves, whether they're online or
not. Click a name to open their drawings and **Load** or **Delete** any of them.

## Other servers

The panel only appears on servers that support it, like Ether's Wolf Park. Everywhere else the mod stays hidden and does
nothing, so it's safe to leave installed.
