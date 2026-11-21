# Scrollkeeper

**Latest (1.2.2):** the **Codex** (`/sk codex`): every mage scroll and what it does, plus all 40 library books with waypoints. A much smarter map: scroll tiers per spot, every book, open doors, a tier filter. Click the imbue/familiar reminder to use the scroll, or bind a key that works mid-fight. Now on Wago and WowUp too!

Mage scroll helper for WoW Forever.

## Features

### The panel (mages)

- **Comprehension bar** with tier marks, in three views: Advanced, Simple and Title only.
- A one-click **Decipher next scroll** button that reads the scrolls that still give skill-ups first.
- **Study** button with the cooldown and your Light Feathers, and an **Open bundle** button. No bags needed.
  Away from a library, Study opens the map to yours.
- Quick **familiar** and **imbue** buttons, pointed at your best scroll of each.
- **Your scrolls by category** (Imbues, Familiars, Combat, Utility, Upgrades), best ones starred, click one to use it.
  Clicking an imbue puts it straight on your main-hand weapon.
- **Weapon upgrades:** Coldflame Saber, Narpas Sword, Wit's Edge: what you have, what's missing, and where it drops.
- **Buttons along the top:** the Farming Plan, Luck Log, Scroll Swap, Doorways and Fellow Mages windows, the scroll icon and
  minimap button toggles, the view size and the settings. Right-click the scroll icon toggle if you lost the icon
  off screen.
- A **minimap button** and an optional **scroll icon** with how many scrolls you can decipher. Click the icon to
  decipher your best scroll without opening anything; right-click it for the panel.

### Skill-ups and odds

- Every scroll shows whether deciphering it will raise your Comprehension: skill-up, likely, unlikely, or none.
- **Luck Log** window (`/sk log`): what each tier of scroll turned into for you, your % next to everyone's, and how
  often each skill-up color really raised your skill.
- **Community Odds:** what scrolls turn into, from everyone's deciphers. Standard scrolls (Scroll of Strength and
  such) are grouped in one row; hover it for each one.

### Farming Plan

- Your skill, your next goal, and about how many scrolls it takes to get there.
- **Where to farm:** the zones where people found the tier of scroll you need (picked and framed in gold). Click
  another tier to look at it, or a zone to open the map.
- **At the auction house:** scroll prices you can sort by price, tier and name; click one to search for it. Uses
  Auctionator or TSM prices when you have them, or its own scan when you don't.

### Network (guild, group and everyone)

- **Fellow Mages:** other mages running Scrollkeeper on your ruleset, their skill and what they still need.
  Mages seen this week stay listed after they log off (mail still reaches them), and players on another class
  show their mage. Hover a name for more
  (like how many of your scrolls they could use), click to whisper, Shift-click to put the name in chat or mail.
  Sort by skill, name or "my scrolls"; right-click "my scrolls" to see only who could use yours.
- **Scroll Swap:** who has spare scrolls you'd level from, and who'd want yours.
- **Doorways** (`/sk doors`): get around with Scroll of Liminal Passage, which takes you to a group member resting in
  an inn or a city. Pick a town and see who you can go to: Scrollkeeper users who offer to be a **door** (click, they
  invite you, the invite is accepted for you) and anyone else there (a ready-made whisper asking for an
  invite). Guildies and friends first. One button does the next step: ask, Teleport, Leave group. Being a door is
  off unless you turn it on. (Curnil's idea!)
- Shared odds, skill-up rates, libraries, drop spots and sheep backfires make everyone's numbers better.
- **Sharing** is Full, Anonymous, Simple (guild, group and friends only) or None. Only scroll data is sent, never
  chat or gold.
- Tells you in chat when someone has a newer Scrollkeeper (you can turn that off).

### Everywhere else

- **Tooltips (every class):** mages see whether they can decipher a scroll; other classes see that it's a mage scroll
  to mail or sell. Hold Shift to see what it can become.
- **Mailbox helper:** your mages, guildies and friends who could use your spare scrolls. Click one to fill in the mail.
- **Guild bank** dots on scrolls someone would level from, and **chat notes** when someone links a scroll asking who
  needs it.
- **Locked chests:** a key binding for Scroll of Khadgar's Unlocking (press it, then click the chest), and a
  tooltip hint on locked chests.
- **Reminders:** a small pop-up when your imbue or familiar wears off, or a few minutes before it does, and you
  have a scroll for it.
- **Library books:** how many of the 40 you've handed in, and the next librarian reward.
- **World map pins:** libraries where Study worked, and spots where untranslated scrolls dropped.
- **Backup and restore** all your Scrollkeeper data (Options > Scrollkeeper > Backup), in case you ever wipe WTF.
- **Works with** Titan Panel and other info bars, the game's addon menu, Auctionator, TSM, and Zygor or TomTom for waypoint arrows.
- **Settings:** Options > AddOns > Scrollkeeper, or `/sk options`. Lots of them.

Nothing is automatic: every cast is one click from the player.

## Commands

| Command | What it does |
| --- | --- |
| `/sk` | show or hide the panel (on alts: your mages' window) |
| `/sk simple` / `/sk advanced` | switch the panel view |
| `/sk options` | open the settings page |
| `/sk plan` | the Farming Plan |
| `/sk log` | the Luck Log window |
| `/sk logchat` | the luck log, printed in chat |
| `/sk net` | the Fellow Mages and Community Odds window |
| `/sk swap` | the Scroll Swap window |
| `/sk doors` | Doorways: get somewhere with Scroll of Liminal Passage |
| `/sk mail` | who could use your spare scrolls |
| `/sk backup` / `/sk restore` | save or bring back all your Scrollkeeper data |
| `/sk bug` | copy a bug report |
| `/sk about` | version and links |
| `/sk setup` | the first-time setup window |
| `/sk demo` | try the network features with made-up players |
| `/sk reset` | move the panel (and scroll icon) to the middle and reset its size |
| `/sk scan` | scan the auction house for scroll prices |

## Help improve Scrollkeeper

- **Found a bug?** Type `/sk bug` in game, copy the report, and open a
  [bug report](https://github.com/generalwrex/scrollkeeper/issues/new?template=bug_report.yml).
- **Like it?** You can [buy me a coffee](https://donorbox.org/generalwrex). Totally optional.
- **Have an idea?** Open a
  [feature idea](https://github.com/generalwrex/scrollkeeper/issues/new?template=feature_request.yml).

## Releasing

Tag a version and push it; GitHub Actions packages it and uploads it to
CurseForge. Tags with `alpha` or `beta` in them upload as Alpha or Beta files.

```
git tag v0.6.0-beta1
git push --tags
```

Needs the CurseForge project ID in `Scrollkeeper.toc` (`## X-Curse-Project-ID`)
and a `CF_API_KEY` secret in the GitHub repo settings.

## License

MIT, see `LICENSE`.

## Layout

This repo is the addon folder itself: clone it straight into
`Interface\AddOns\Scrollkeeper`.

```
Scrollkeeper.toc      load order
Commands.lua          slash commands
Core/                 shared helpers, game IDs and language setup
Locales/              translations, one file per language
Data/                 scroll tiers, skill-up colors, weapon upgrades, shipped community data
Modules/              one feature per file, no drawing
Network/              talking to other players' Scrollkeeper (protocol notes in each file)
Map/                  world map pins
UI/                   everything you can see, plus optional links to other addons
Dev/                  /sk scan data collection tool (not in the released addon)
tools/community/      builds the shipped community data (not loaded by the game)
tools/test/           runs the addon in a fake WoW (not loaded by the game)
                      cd tools/test, npm install, npm test
```

## Translations

Scrollkeeper is in English, German, Spanish, French, and Simplified and Traditional Chinese.
Everything but English was translated with AI, so fixes from native speakers are very welcome.
(Chinese only shows up on Chinese game clients, since other clients' fonts have no Chinese characters.)
The files are in `Locales/` (one line per piece of text: `L["English"] = "your translation"`).
Keep the `%d` / `%s` codes, `|c...|r` colors and `|4one:many;` plurals as they are.
Pull requests and issues welcome!
