# Downtime

<img src="assets/icon-512.png" alt="Downtime icon" width="128" align="right">

One menu on one key for everything you do between fights, on every character, for WoW Forever. Press the key and a menu opens at your mouse: your class's own spells for between fights, the camp items and hearths you carry, and your profession windows. Click one to use it.

Downtime was LockMenu, a warlock menu. The warlock menu is still here, unchanged, as the warlock's rows.

It reads your spellbook and your bags, so it only shows what that character knows and carries.

## What the menu shows

Your class's rows come first:

| Class | Rows |
|---|---|
| Warlock | Demons, Buffs, Utility, Stones, Curses and banes, Control, and the healthstone and soulstone you carry (LockMenu's menu) |
| Rogue | Main hand and Off hand: each poison you carry, one click puts it on that hand. The off hand row shows while you hold an off-hand weapon. |
| Paladin | Blessings, Greater blessings, Auras, Utility (redemption) |
| Mage | Conjure (water, food, mana gems), Buffs, Teleports, Portals |
| Priest | Buffs (fortitude, spirit, shadow protection, inner fire), Utility (resurrection, levitate, mind vision) |
| Druid | Buffs (mark of the wild, thorns), Utility (rebirth) |
| Shaman | Weapon enchants, Utility (shields, water walking and breathing, ancestral spirit, far sight) |
| Hunter | Pet (call, dismiss, revive, mend, feed, tame, train) |
| Warrior | No rows of its own |

Then the rows every character gets:

- **Camp:** the campfire kit you carry (the best one), the camp objects you carry (Fish Bowl, Enchanted Lute, Camp Tent and the rest) and the Cozy Sleeping Bag.
- **Hearths:** your Hearthstone, the engineering teleports, Astral Recall and Teleport: Moonglade.
- **Professions:** opens each profession's window, plus Disenchant and Fishing.
- **Extra:** spells you add by name in the options.

## Install

1. Download the zip from the [releases page](https://github.com/Jackafur/downtime/releases) and extract the `Downtime` folder into `World of Warcraft\_forever_\Interface\AddOns`.
2. Restart the game once. A new addon and its key binding need a full restart.
3. Esc, Options, Keybindings, AddOns, Downtime: bind "Downtime - Menu" to a key.

Press the key to open the menu. `/downtime` or `/dt` does the same.

**Coming from LockMenu:** the first time Downtime loads, your LockMenu settings are copied over, your LockMenu key opens Downtime from then on, and LockMenu is switched off. A character with its own key bindings gets its LockMenu key moved the first time it logs in. Delete the `LockMenu` folder from your AddOns.

## Options

Type `/downtime options`.

- **Hold to show:** the menu opens while you hold the key and closes when you let go, instead of toggling.
- **Cast on release:** with hold to show, letting go casts the spell the mouse is pointing at.
- **Close after casting**, and whether it **opens at the mouse** or near the middle of the screen.
- **Which rows show:** your class's rows, then the rows every character gets. The warlock's Curses and Control rows and the paladin's Auras start switched off.
- **Button size, background opacity and menu opacity.**
- **Extra spells:** exact spell names, separated by commas, that appear in an Extra row.

Settings are saved for the whole account.

## Commands

| Command | What it does |
|---|---|
| `/downtime` or `/dt` | Open or close the menu |
| `/downtime options` | Open the options window |
| `/downtime scan` | Print what the addon found in your spellbook and how many buttons the menu has (send this with a bug report) |
| `/downtime rebuild` | Redraw the menu |

## Change what is shown

Edit `Data.lua`. Each class has its rows. Spells are matched by name against your spellbook (or by a pattern like every "Curse of ...") and items by their item IDs, best first. The comment at the top of the file explains each field.

## Limits

- The menu is for between fights. It does not open in a fight, and an open menu closes when a fight starts, because the game does not let an addon show or hide a menu of spell buttons in a fight.
- It is early. It was built with AI assistance (Claude Code) and tested in game by the author on one setup, so expect rough edges. Bug reports are welcome under Issues.

## Credits

LockMenu was inspired by WarlockTools by afrugalpenguin, a popup spell menu for TBC Anniversary. Downtime is written from scratch for WoW Forever and shares no code with it. The item ID lists are game data, which any item database has.

## License

MIT, see LICENSE.
