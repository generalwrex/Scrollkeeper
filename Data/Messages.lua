-- Scrollkeeper: Data/Messages.lua
-- One-time chat messages from Natop. Each one is printed once per account,
-- the first time you open the panel after it's added.
--
-- To add one, put a new entry at the bottom:
--   id       any name that's new (it's how Scrollkeeper remembers it was shown)
--   version  optional: only show it in versions that start with this, like "1.1.5"
--   lines    what to say, one chat line each (gets translated if Locales has it)
--   alert    optional: make it stand out: lines above and below, a sound,
--            and the first line in big letters mid-screen too
--
-- Each update's news is made from CHANGELOG.md by tools/make-news.py, into
-- Data/News.lua (the release workflow runs it, so it's automatic).

local _, SK = ...

-- The news line on the panel (under the title). Not used right now:
-- news goes in chat, once, as a message below. To bring the line back:
--   SK.NEWS = { id = "new name", headline = "...", short = "...", more = { "...", ... } }
SK.NEWS = nil

SK.MESSAGES = {
    {
        id = "thanks-1.1.5",
        version = "1.1.5",
        lines = {
            "|cffffd100Hey, thanks for using Scrollkeeper!|r All of you downloading it and sharing your scroll data is what fills in the odds, the drop spots and everything else. Couldn't do it without you. - Natop (Archmage Naage)",
            "|cff9d9d9dNew: you can back up all your Scrollkeeper data now, in Options > Scrollkeeper > Backup.|r",
        },
    },
}
