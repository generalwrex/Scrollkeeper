# Scrollkeeper

Mage scroll helper for WoW Forever.

- **Panel (mages):** Comprehension bar with tier marks, scrolls ready or too hard,
  a one-click **Decipher next scroll** button, buttons for your usable scrolls,
  and the Study cooldown with your Light Feathers.
- **Skill-ups:** every scroll shows whether deciphering it will raise your
  Comprehension (skill-up, likely, unlikely, none), and the decipher button
  reads the ones that still give points first.
- **Tooltips (every class):** mages see whether they can decipher a scroll;
  other classes see that it's a mage scroll to mail or sell. Hold Shift to see
  what it can become.
- **Luck log:** records what each decipher produced. `/sk log`.
- **Settings:** Options > AddOns > Scrollkeeper, or `/sk options`.

Nothing is automatic: every cast is one click from the player.

## Commands

| Command | What it does |
| --- | --- |
| `/sk` | show or hide the panel |
| `/sk options` | open the settings page |
| `/sk log` | what your deciphers have produced |
| `/sk reset` | move the panel to the middle and reset its size |
| `/sk scan` | developer: dump game data to the saved file |

## Layout

This repo is the addon folder itself: clone it straight into
`Interface\AddOns\Scrollkeeper`.

```
Scrollkeeper.toc      load order
Commands.lua          slash commands
Core/                 shared helpers and game IDs
Data/                 scroll tiers, skill-up colours, weapon upgrades
Modules/              one feature per file, no drawing
UI/                   everything you can see
Dev/                  /sk scan data collection tool
tools/test/           runs the addon in a fake WoW (not loaded by the game)
                      cd tools/test, npm install, npm test
```
