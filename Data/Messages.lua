-- Scrollkeeper: Data/Messages.lua
-- One-time chat messages from Natop. Each one is printed once per account,
-- the first time you open the panel after it's added.
--
-- To add one, put a new entry at the bottom:
--   id       any name that's new (it's how Scrollkeeper remembers it was shown)
--   version  optional: only show it in versions that start with this, like "1.1.5"
--   lines    what to say, one chat line each (gets translated if Locales has it)

local _, SK = ...

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
