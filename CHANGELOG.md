# Scrollkeeper

## 1.1.2

- **First-time setup.** The first time you log in with Scrollkeeper a little setup window walks you through a few quick questions, one page at a time. On a mage: which panel view, minimap button and/or scroll icon, hide in combat, how much to share, and language. On other classes: tooltip lines, the mailbox helper, sharing and language. Run it again any time with `/sk setup`.
- **Minimap button** (finally lol). The usual round button on the minimap edge with your scroll count. Left-click opens the panel, right-click opens settings, drag it around the minimap. Don't want it? Turn it off in the settings.
- **Pick your language** in the settings (Auto, English, Deutsch, Español, Français). Needs a /reload to switch.
- The About page says where to find me in game (Archmage Naage, PvE) and thanks the people who helped. Thanks Curnil!
- New little scroll button on the panel's title bar (next to the book) that turns the scroll icon on and off. It's greyed out when the icon is off.
- The settings page isn't one giant list anymore. It's split into sections (Panel, Tooltips and chat, Sharing, Mailbox/guild bank/AH, Map), stuff that depends on something else greys out when it's off, and there's a "Move to middle" button if you lose the panel off screen.
- Fixed a bunch of German/Spanish/French text that was still showing in English on the panel.
- The About page says I'm Natop on CurseForge now too.
- Sharing your data is way easier now. Scrollkeeper keeps your latest export when you log out, so there's a little script (`tools/community/share-scrollkeeper-data.bat`, just double-click it) that opens the GitHub "Share your data" page with everything already filled in. You just hit Create.

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
