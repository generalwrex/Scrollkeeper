# Scrollkeeper

## 1.2.4

- Fixed: the mail list's title ran off the side of its box.
- Escape closes the panel, like the game's own windows (out of combat; in a fight the X still closes it).
- The scroll icon is now an action button: in a library with Study ready it casts Study, with a Bundle of Scrolls in your bags it opens it, and otherwise it deciphers your best scroll like before. Its picture and number show which.
- Fixed: the mail list ("Who could use your scrolls") could offer mages on other realms, whom mail can't reach. It now only offers mages a whisper gets through to (or your guild and group): opening the mailbox checks everyone, and whoever answers shows up within a few seconds. The same goes for the offline "seen this week" mages.

## 1.2.3

- New in the Codex: a **Book rewards** tab with every librarian reward as an item link (hover to see it), which ones you've reached, and how many books until the next. The last set takes all 40 books and needs level 50.
- Fellow Mages is up to date as soon as you open the panel: it checks who's still online right away, instead of only when you hover a name.
- Fixed: pressing Shift while a player or another addon's map pin (like Questie's) had its tooltip open could cause a Lua error. Shift now only redraws Scrollkeeper's own scroll tooltips.
- Familiar pop-ups now only show in dungeons and raids (flight paths make your familiar vanish). Want them everywhere? Turn on "Familiar pop-ups outside dungeons and raids" in /sk options.
- Fixed: Fellow Mages could show grayed-out mages from other rulesets (players on older versions who don't say their ruleset). Someone the online check can't reach and whose ruleset is unknown now leaves the list right away, and the offline history only shows mages from your own ruleset.

## 1.2.2

- Thanks to Fellow Mage network user **Lofi Frostbeats** (RP-PvP Horde), who shared most of the community's tier 175 odds. Every mage reading tier 175 scrolls benefits from those deciphers!
- Fixed: hovering a Fellow Mage to check they're online kept whispering them over and over while the tooltip was up.
- Fixed: the game sometimes gives no realm name for a whole session, so Fellow Mages lost its ruleset ("Fellow PvE Mages"), others weren't told yours, and your mage was saved a second time without a realm. Scrollkeeper now remembers each character's realm.
- Fellow Mages: someone playing another class shows in that class's color ("on Warrior" in warrior brown).
- Community odds: scroll icons and colors are loaded after you log in, so the list no longer shows plain names first.
- Waypoints (library pins, the Study button) use Zygor's arrow if you have Zygor, then TomTom, then the game's own pin.
- The map only pins your own faction's library, including spots players shared in the other faction's city (like Stormwind's Royal Library for the Horde).
- Farming plan: with Zygor or TomTom, each zone in Where to farm gets an Arrow button that points you at the spot where the most scrolls dropped.
- Map: scroll (and book) spots close together are grouped into one shaded circle with the total in the middle, instead of a pile of little pins.
- Map: a book for the librarians shows as one book (it sits in one place), not a count of how often it was found. Spots right next to each other are that same book.
- Map: scroll and book spots are smaller, scrolls use the untranslated scroll's own icon, and there's a Map pin size setting (Options > Map).
- Map: when pins sit on top of each other (a library, a book, scrolls), one tooltip shows them all, and clicking still sets the library's waypoint.
- Map: book spots say which book it is, for anyone's finds (shared by item ID, so it's in your language).
- Map: all 40 books for the librarians are on the map (from Wowhead's list). Click one for a waypoint. Book spots players found away from the list are grey: that book may have moved. A find named after a listed book but far from its spot is left off as wrong, unless players find it there more often than at the listed spot (then it probably moved).
- Fixed: any loot with "Journal", "Tome" or "Codex" in its name was saved as a library book spot (two fake books in Hillsbrad). Now only real books count, and the wrong spots are cleaned up.
- Map: a Scrolls button on the map picks which scroll spots show: all, the tiers you still level from, or one tier.
- Map: busier scroll circles are stronger in color, so the hotspots stand out.
- Map: books you've handed in fade out, and a book's tooltip lists which of your characters (any class) handed it in.
- Map: open doors (Doorways) show where they're resting. Click one to open Doorways on them.
- Map: on a continent map, each zone gets one small faint marker with its scroll total.
- Map: scroll spots say which tiers dropped there (from now on, shared with everyone); older spots show the zone's tier mix.
- Fixed: on Forever, a few places used only your first name: Doorways could list you as someone to whisper, the mail note was signed with your first name, and {me} in a custom whisper was short.
- Fixed (non-English clients): the "a Scroll of Comprehension would let you read more" hint and weapon-upgrade scrolls (Saber, Blade, Wit) weren't recognized.
- Less network traffic: when a guildie or group member logs in, your data goes only to your guild or group, not to the whole public channel too. Friends are pinged at most every 2 minutes.
- Your level shows up for others right after you level, not up to 5 minutes later.
- So much community data has come in that it's now stored packed: the shipped data is less than half the size.
- Fixed: the panel's Skill, Ready, Cooldown and "none" labels stayed in English in other languages.
- Doorways says it can be opened after combat, instead of the game blocking it.
- Setup and settings say plainly what sharing sends (only scroll info, never chat, gold, bags or where you are), and Full is marked recommended (None: not recommended). The Simple choice (guild and friends only) is gone: if you had it, you're now on Anonymous, which keeps your name private and still helps everyone.
- With sharing set to None, Scrollkeeper still tells your guild and group which version you run (nothing else) and hears about newer versions, and the update message mentions Wago and WowUp too.
- The imbue and familiar pop-up does it for you: click it to summon your familiar or imbue your weapon. New key bindings (Key Bindings > Scrollkeeper) do the same, even mid-fight.
- New: the Codex (/sk codex, or the book button on the panel). Every mage scroll tier by tier with what it does, how many you have and why it's your pick, plus all 40 library books: where they are (click for a waypoint), which you've handed in, and your next reward.
- Imbues follow your spec: a Fire mage's best imbue is a flame one, Frost a frost one, Arcane an arcane one (by your talent tree with the most points). The panel, the pop-up and the imbue key all use it. Once you've used an imbue or familiar a couple of times, the one you use most becomes your best one (each character learns its own).
- New setting: This character's own layout (Options > Panel). Panel position, size and view, the minimap button, the scroll icon and the pop-up's spot can be different on each character.
- The imbue and familiar pop-up can be moved: Alt-drag it where you like (it remembers).
- Setup helps you set keys for summoning a familiar, imbuing your weapon and Khadgar's Unlocking. It never takes a key you already use. (Mages who did setup before see this page once, if none of those keys are set.)
- Setup asks new mages about the imbue and familiar reminders (wore off, running out, and also in combat). The in-combat choice is in the settings too, off by default.
- Setup: sharing and language are set once for your whole account, so a new character (mage or not) doesn't ask again.
- /sk export is gone: Fellow Mages already share everything over the network, so there's nothing to paste anymore. Thanks to everyone who sent theirs!

## 1.2.1

- **Big network fix.** Every login made every Scrollkeeper user online answer with all their data at once, so the game throttled everyone and most messages (including "I'm online") were silently dropped: with 150+ users in the channel you'd hear 2 or 3. Now who's-online messages go first, data goes out on login and when it changes (not to every login), and sending stays under the game's limit, retrying anything it refuses.
- Fixed: your mages on another realm of the same ruleset (Realm 3 PvE when you're on Realm 1 PvE) were skipped: not offered at the mailbox, and not shown to others when you play another class.

## 1.2.0

- Setup: Advanced comes first, marked recommended.
- Fixed: the setup's language page only showed 5 of the 7 choices (Chinese was cut off).
- Don't have Study yet? The panel says how to get it (hand a library book to your librarian), and the Study button shows them on the map.
- Mages who haven't learned Comprehend Scroll yet show as "not learned yet · needs 1", so others can send them tier 1 scrolls for when they do.
- "Your Stats" is now "Account Stats": it always counted all your characters together.
- New mages: the panel says Comprehend Scroll comes from a mage trainer at level 6, instead of an empty "Nothing to decipher".
- Fixed: whispers, mail and the online check used "Name-Realm 3 PvE" for mages on another realm of your ruleset, which the game doesn't accept, so they looked offline and mail bounced. Same ruleset now means the plain name.
- Fellow Mages says which ruleset it's showing: "Fellow PvE Mages", "Fellow RP-PvP Mages"...
- **Playing another class but have a mage?** Fellow Mages lists you as "on Priest" with your mage's name, skill and the tiers it needs, and the mailbox mails scrolls straight to your mage. (Both players need 1.2.0.)
- **Big fix: Fellow Mages was hiding most of your ruleset.** Mages on the other realms of your ruleset (like Realm 2 PvE when you're on Realm 1 PvE) were treated as unreachable, but connected realms can whisper, mail and group. They all show up now; only the other rulesets (PvP, RP, RP-PvP) and the other faction stay out.
- The mailbox list says it plainly: COD is not endorsed by Scrollkeeper, scroll sharing should be free!
- **Fellow Mages remembers** the last 15 mages you could reach (for a week): offline ones show grayed out with when you saw them, their level and what they need, and the mailbox still offers them your spare skill-up scrolls.
- Mailing scrolls fills in the subject and a short note (what they're for, and to send back any they don't need). Your own subject or note is never replaced.

## 1.1.9

- Fixed: an empty band at the bottom of the Advanced panel.
- **Study away from a library** opens the map on your faction's library (Undercity's Magic Quarter or Stormwind's Wizard's Sanctum) with a waypoint, TomTom if you have it.
- Doorways: places you can already teleport to with your own spell are greyed out at the bottom of the list.
- Doorways: clicking someone the search found checks they're still there first (a quick /who of just them). Moved on? You're told and they leave the list.
- Doorways: the whisper asks if you can group up, they invite you or say ok, and the button turns into **Invite** for when they do. Nobody gets an invite out of the blue.
- **Doorways: write your own whisper** (Whisper text... in the window). Use {place}, {zone}, {name}, {me} and {scroll} (a link to the scroll); Default brings ours back.
- Doorways tags cities (whole city is resting), and people found in one say "resting".
- **Library books:** how many you've handed in (of 40) and the next reward, in chat after each hand-in and on the panel's stats (hover for the rewards).
- The Decipher button says "Stand still to decipher" while you're moving.
- Fixed: Scrollkeeper's hidden channel could take chat channel /1 and push General to /2. It now joins after the game's channels and moves itself to the end if it ever lands before them.
- **Khadgar's Unlocking on locked chests:** set a key in Key Bindings > AddOns > Scrollkeeper ("Use Khadgar's Unlocking"), press it, then click the chest. Mouse over a locked chest and the tooltip reminds you how many scrolls you have and which key to press.
- **Open the panel in combat:** click the minimap button or right-click the scroll icon. (`/sk` still waits for combat to end: the game doesn't let typed commands show it in a fight.)
- **Running-out pop-up:** when your weapon imbue or familiar has 5 minutes left (and you carry a scroll to renew it), a pop-up tells you. Change the minutes or turn it off in Options > Panel, or Shift-right-click the pop-up.

## 1.1.8

Bug fix.

- Fixed: an error about a "secret boolean" (Modules/Farm.lua). The game now hides some player info from addons in places; Scrollkeeper skips it instead of erroring.
- Fixed: Decipher (the button and the scroll icon) now reads the scroll with the best skill-up chance first. It was taking the lowest tier, so a green tier 15 went before an orange tier 50.

## 1.1.7

- **Doorways (/sk doors, or the new button on the panel): getting around with Scroll of Liminal Passage (thanks Curnil for the idea!).** The scroll takes you to a group member resting in an inn or a city. Pick a town (neutral ones first; capitals you can already teleport to are greyed out) and Doorways shows who you can go to:
  - Scrollkeeper users who offer to be a **door**: click one, they invite you, and the invite is accepted for you.
  - Anyone else in that zone: people standing in the town come first. Click one for a ready-made whisper asking for an invite (you press Enter to send it), and their invite is accepted for you. They don't need any addon.
  - Guildies and friends are tagged and listed first.
  - Your Liminal Passage count and its auction house price at the top (hover for the scroll, Shift-click to link it).
  - One button does the next step: ask, **Teleport**, then **Leave group**.
- Be a door yourself: tick "Be a door" (off unless you turn it on). Mages who ask get a pop-up, or tick "Invite by myself" to skip it.
- The scroll icon's frame shows the skill-up color of the scroll a click would read (orange, yellow, green, or gray when it won't give a point), and its tooltip says it too.
- Fixed: /sk demo showed no made-up mages since 1.1.6.

## 1.1.6

Bug fix: Fellow Mages was listing mages you couldn't actually reach.

- **Fellow Mages knows who's really online.** Hover a name and Scrollkeeper quietly checks: if they've logged off, the name turns gray and drops off the list after a few minutes (Options > Sharing > "Keep offline mages for", 5 by default). Mail still reaches them, whispers won't.
- Players from other servers (the shared channel reaches all four) and the other faction don't show up in Fellow Mages, the swap board or the mailbox list any more, since you can't whisper, mail or trade with them. Their shared odds and drop spots still count.

## 1.1.5

- **Thank you!** Seriously, everyone downloading this and sharing your scroll data is what makes the odds and drop spots actually useful. There's a little thank-you in chat the first time you open the panel.
- **Backups.** Options > Scrollkeeper > Backup (or `/sk backup`) gives you all your Scrollkeeper data as text, so if you ever have to wipe WTF you don't lose your luck log, drops, settings and all that. `/sk restore` (or the Restore button) puts it back.
- **Chinese!** Simplified and Traditional Chinese (AI translated, fixes welcome). Shows up by itself on Chinese game clients.
- Familiars and the scroll categories (Imbues, Familiars...) now work in every language, not just English. They go by the item and spell, not the English name.
- Where to farm uses everyone's shared drops now, not just yours, and has tier icons: the one you need is picked and framed in gold, click another to look at it (drop tiers are shared from this version on, so it fills in as people play).
- New mailbox setting: also offer scrolls you'd still use yourself, marked "you'd use too".
- The imbue/familiar pop-up's hint is one short line now.
- **Luck Log window.** `/sk log` (or the dice button) shows what your deciphers turned into, tier by tier, with your % next to everyone's, and how often each skill-up color really raised your skill. `/sk logchat` still prints it in chat.
- **Window buttons at the top of the panel** for the Farming Plan, Luck Log, Scroll Swap and Fellow Mages, in every view. They took the spot of the "0 ready" line, since the Decipher button already says that.
- A minimap button on/off toggle on the panel, next to the scroll icon one.
- The "newer version is out" chat line says to update on CurseForge, and there's a setting to turn it off.
- **The scroll icon deciphers now.** Click it to decipher your best scroll (skill-ups first) without opening anything. Right-click opens the panel, Shift-drag moves it.
- A yellow **!** at the top of the panel (with a news line next to it in Advanced view) tells you about changes to how things work. Hover it for more, click to print it in chat, right-click to hide it.
- Lost the scroll icon off screen? Right-click its toggle on the panel (or `/sk reset`) to put it back in the middle.
- Clicking an imbue scroll on the panel puts it right on your main-hand weapon, no clicking the weapon after.
- Advanced view: Fellow Mages gets more room. Your Stats is shorter, since the Luck Log, Plan and Swap have their own windows now.
- The network list is now "Fellow Mages": only mages, with the full name on top and their skill, what they need and weapon upgrades underneath. Hover a name for more (and how many of your scrolls they could use), click to whisper, Shift-click to put the name in chat or mail. Little icons in its header sort it by skill, name, or who could use the most of your scrolls. Right-click the scroll icon to only show mages who could use yours.
- Community odds tiers are scroll icons now. Community odds put standard scrolls (Scroll of Strength and such) in one row. Hover it to see each one with its count, or turn on the setting to list them one by one. Hovering any scroll there shows its count too.
- Scroll of Liminal Passage is now known as a tier 50 result (your deciphers turned it up, it isn't in any guide).
- Community odds no longer count loot that showed up while deciphering (like a recipe or water) as a scroll result. The luck log ignores it too.
- Scrollbars in the lists (odds, Fellow Mages, plan, swap) and on Your Scrolls actually scroll now when you drag them or use the mouse wheel.

## 1.1.4

- **Sharing is one dropdown now** (in setup and in the settings): Full, Anonymous, Simple or None.
  - Full: everyone online, with your name. Same as before.
  - Anonymous: your scroll data still counts for everyone's odds and drop spots, but you won't show up in anyone's network list, swap board or mailbox list (so nobody can mail you scrolls from them either).
  - Simple: just your guild, group and friends.
  - None: turns off the whole network.
- The Network list shows how many anonymous players are around ("Anonymous +3 players"), so they still count even without names.
- The panel and the Network window show which sharing mode you're on now, instead of just "on".
- New little pop-up when your weapon imbue or familiar falls off and you've got a scroll for it. Click it to open the panel. Never in combat, and it won't nag more than once every 5 min. You can turn it off in the settings (Panel > Imbue and familiar pop-up), or just shift-right-click the pop-up.
- **Plan window.** The note button on the panel (where the network button was, the network list is on the Advanced panel anyway) or `/sk plan`. Your Comprehension at the top, then your next goal, about how many scrolls and how long, and **Where to farm**: the zones where you've found the tier you should be reading (tier 50 scrolls if that's your tier). Starts counting tiers from this version, so until you've looted some it shows all tiers. Click a zone to open it on the map. Works out the scroll count one skill point at a time, since low tiers go gray as you level.
- At the AH there's a **Plan** button on the Buy tab (with Scan scrolls). It opens the plan docked next to the AH, showing just AH stuff: the scrolls you'd still level from and their buyout price. Sort by price, tier or name (click again to flip it), and click a scroll to search for it. It never buys anything.
- If you have **Auctionator or TSM**, Scrollkeeper just uses their prices and doesn't scan the AH itself. If you don't, hit Scan scrolls (the plan asks if you want to when you open it at the AH, say no and it leaves you alone).
- AH prices: bid-only auctions don't count anymore (they made some scrolls look like they cost 5 copper). Old saved prices get cleared once so you start fresh.
- The Scrollkeeper title lines up with the "ready" line under it now.
- Your Scrolls on the panel: the last icon in a row isn't hidden behind the scrollbar anymore.
- **Fixed deciphers not getting logged** (they never showed up in your odds or counts, a lot of the time with higher tier scrolls). It now goes by the scroll leaving your bags plus the "You receive item" message, so it doesn't miss them. Sorry about that!
- `/sk swap` opens on the first try now (it used to need two).
- Scroll links don't get chopped in half across two lines anymore (the "best you have" reminders on the panel, and the tooltips).
- Community data is back. 1.1.3 went out with it empty by accident, sorry!

## 1.1.3

- The share data script has a .bat now, so you can just double-click it (`tools/community/share-scrollkeeper-data.bat`). It also finds your WoW folder on its own, so it works no matter where the game is installed.
- When you share your data on GitHub, the issue gets closed automatically once your data is in a release, so you know it made it in.

## 1.1.2

- **First-time setup.** The first time you log in with Scrollkeeper a little setup window walks you through a few quick questions, one page at a time. On a mage: which panel view, minimap button and/or scroll icon, hide in combat, how much to share, and language. On other classes: tooltip lines, the mailbox helper, sharing and language. Run it again any time with `/sk setup`.
- **Minimap button** (finally lol). The usual round button on the minimap edge with your scroll count. Left-click opens the panel, right-click opens settings, drag it around the minimap. Don't want it? Turn it off in the settings.
- **Pick your language** in the settings (Auto, English, Deutsch, Español, Français). Needs a /reload to switch.
- The About page says where to find me in game (Archmage Naage, PvE) and thanks the people who helped. Thanks Curnil!
- New little scroll button on the panel's title bar (next to the book) that turns the scroll icon on and off. It's greyed out when the icon is off.
- The settings page isn't one giant list anymore. It's split into sections (Panel, Tooltips and chat, Sharing, Mailbox/guild bank/AH, Map), stuff that depends on something else greys out when it's off, and there's a "Move to middle" button if you lose the panel off screen.
- Fixed a bunch of German/Spanish/French text that was still showing in English on the panel.
- The About page says I'm Natop on CurseForge now too.
- Sharing your data is way easier now. Scrollkeeper keeps your latest export when you log out, so there's a little script (`tools/community/share-scrollkeeper-data.ps1`) that opens the GitHub "Share your data" page with everything already filled in. You just hit Create.

## 1.1.1

- **Scroll icon** (thanks Curnil for the idea!). Turn it on in the settings and you get a little icon you can put anywhere, with the number of scrolls you can decipher right now (green when some still give skill-ups, and it glows when Study is ready). Click it to open or close the panel in whatever view you picked, so you can keep Advanced but only see it when you want.

## 1.1.0

Big one for alts and guilds!

- **Mailbox helper.** At the mailbox there's a new list next to the mail window that shows who could use the scrolls you're carrying. Your own mages first, then guildies, friends and group members who run Scrollkeeper. Skill-ups are on top, then people who can at least read it. Click a name and it fills in the mail and attaches their scrolls (up to 7, click again after sending for the rest). It never sends anything, you still hit Send yourself. `/sk mail` shows the same list in chat.
- **Scroll swap board** (`/sk swap`, or click Scroll swap in Your Stats). Everyone running Scrollkeeper tells the network how many spare scrolls they have, any class. The board shows who has spares you'd level from, and which mages would level from yours. Click a name and it opens a whisper with a message ready to go.
- **Farming plan** (`/sk plan`, or hover Next goal in Your Stats). Tells you how many skill-ups to your next tier, about how many scrolls that is at your colors, how many scrolls you find an hour, so how long it'll take, and where the most scrolls drop.
- **Auction house prices.** Scrollkeeper saves mage scroll prices on its own now (not the regular ones like Scroll of Agility). Anything you look at gets saved, or hit the new Scan scrolls button (or `/sk scan`) to grab all of them at once. Prices show on scroll tooltips with how old they are.
- **Guild bank dots.** Scrolls in the guild bank get a little colored dot if you, one of your mages, or a guildie would get a skill-up from it. The number is how many people.
- **Chat notes.** When someone links a scroll in chat and asks who needs it, you get a little note (only you see it) saying if it's a skill-up for you or your mages, with an [I'll take it] button to answer.
- **Sheep backfires get logged now** lol. Every time Comprehend Scroll turns you into a sheep it gets counted, and it's shared so we can finally see how often it really happens.
- **Spanish, French and German!** Heads up though, these were translated with AI so there's gonna be mistakes. If you speak one of them and something reads weird, please send a fix on GitHub (the files are in the Locales folder), I'd really appreciate it.
- Sharing with everyone is on by default now. Odds, drop spots and libraries come from every Scrollkeeper user online, not just your guild and group. It's a hidden channel so it won't clutter your chat.
- Friends who aren't in your guild show up now too, as long as they run Scrollkeeper.
- `/sk export` now also carries the data you've heard from other Scrollkeeper users, so when you post a [Data] issue you're helping everyone you've run into get counted. No names, just their random export code so nobody gets counted twice.
- Your alts are saved with their full name now (first name and surname), so mail goes to the right character.
- Works better on non-English clients in general (Bundle of Scrolls and librarians get picked up in any language now).
- Fixed: the Imbue tooltip didn't say which weapon in your bags to swap to, and the "worth selling on the AH?" line for non-mages never showed up.
- You can turn all of the new stuff off in the settings if you don't want it.

## 1.0.0 – first real version

This is the first version I'd call done. It does pretty much everything I wanted for Comprehension:

- One window with Decipher, Study, Open bundle, Familiar and Imbue. All one click.
- Every scroll shows its skill-up color like professions do, and the Decipher button grabs the best one first.
- Your scrolls are sorted into Imbues, Familiars, Combat, Utility and Upgrades. The right imbue for the weapon you're holding gets a gold outline. If you click one you can't use yet it tells you why instead of wasting it.
- If you've got a weapon in your bags that fits one of your imbues, the Imbue button tells you to swap.
- Study timer for each of your mages, and it knows when you're standing by a librarian. Both libraries are on the map.
- Hand in a book to the librarian and Scrollkeeper learns it, and where books drop goes on the map.
- If other people in your guild or group run it, you all share what each scroll tier turns into, where scrolls drop, and who needs what. There's also data from other players built in so it's not empty on day one.
- Your alts know about your mages. Scroll tooltips on any character tell you which mage can use it.
- Scroll names are real item links everywhere, hover them or Shift-click to link them in chat.
- Hides in combat and comes back after (you can turn that off), and the X always closes it.
- Three sizes: Advanced, Simple, and Title only which is just the title and your skill bar.
- Works with Titan Panel / ElvUI data bars, the addon menu, Auctionator and TomTom.
- `/sk about` for links, `/sk bug` if something breaks, `/sk export` to share your data.

Everything before this (0.1 to 0.5.3) was testing.
