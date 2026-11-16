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
- **Network (guild and group):** other Scrollkeeper users share what their
  scrolls became (community odds, Shift on a scroll tooltip), which mages
  still get skill-ups from which tiers (tooltips name them), libraries, and
  where scrolls drop. `/sk net` opens the Network window. Only scroll data
  is sent; turn it off in the settings.
- **World map pins:** libraries where Study worked, and spots where
  untranslated scrolls dropped (yours and shared).
- **Study and Open bundle buttons** on the panel, no bags needed.
- **Your scrolls by category** (Imbues, Familiars, Combat, Utility, Upgrades),
  with a star on the best imbue and familiar you can use.
- **Reminders:** no weapon imbue, no familiar out, when a Scroll of Comprehension
  would unlock more scrolls, and when a weapon upgrade is ready.
- **Weapon upgrades:** Coldflame Saber, Narpas Sword, Wit's Edge: what you have,
  what's missing, and where it drops.
- **Works with** Titan Panel and other info bars, the game's addon menu,
  Auctionator (sell-or-mail advice for non-mages) and TomTom (library waypoints).
- **Settings:** Options > AddOns > Scrollkeeper, or `/sk options`.

Nothing is automatic: every cast is one click from the player.

## Commands

| Command | What it does |
| --- | --- |
| `/sk` | show or hide the panel (on alts: your mages' window) |
| `/sk simple` / `/sk advanced` | switch the panel view |
| `/sk options` | open the settings page |
| `/sk net` | the Network window |
| `/sk demo` | try the network features with made-up players |
| `/sk log` | what your deciphers have produced |
| `/sk export` | copy your scroll data to share |
| `/sk bug` | copy a bug report |
| `/sk about` | version and links |
| `/sk reset` | move the panel to the middle and reset its size |
| `/sk scan` | developer: dump game data to the saved file |

## Help improve Scrollkeeper

- **Found a bug?** Type `/sk bug` in game, copy the report, and open a
  [bug report](https://github.com/generalwrex/scrollkeeper/issues/new?template=bug_report.yml).
- **Share your data.** Type `/sk export`, copy it, and paste it in a
  [data issue](https://github.com/generalwrex/scrollkeeper/issues/new?template=share_data.yml).
  It's scroll data only, with no character or account names. Everyone's exports are combined
  (`tools/community/merge.py`) into real odds, skill-up rates and drop spots
  that ship with future releases.
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
Core/                 shared helpers and game IDs
Data/                 scroll tiers, skill-up colors, weapon upgrades
Modules/              one feature per file, no drawing
Network/              talking to other players' Scrollkeeper (protocol notes in each file)
Map/                  world map pins
UI/                   everything you can see, plus optional links to other addons
Dev/                  /sk scan data collection tool
tools/community/      merges /sk export data from players (not loaded by the game)
tools/test/           runs the addon in a fake WoW (not loaded by the game)
                      cd tools/test, npm install, npm test
```

## Translations

Scrollkeeper is in English, Spanish, French and German. The Spanish, French and German were
translated with AI, so they need fixes from native speakers. The files are in `Locales/`
(one line per piece of text: `L["English"] = "your translation"`). Keep the `%d` / `%s`
codes, `|c...|r` colors and `|4one:many;` plurals as they are. Pull requests and issues
welcome!
