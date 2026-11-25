-- Scrollkeeper: Data/Messages.lua
-- One-time chat messages from Natop. Each one is printed once per account,
-- the first time you open the panel after it's added.
--
-- To add one, put a new entry at the bottom:
--   id       any name that's new (it's how Scrollkeeper remembers it was shown)
--   version  optional: only show it in versions that start with this, like "1.1.5"
--   lines    what to say, one chat line each (gets translated if Locales has it)

local _, SK = ...

-- The news line on the panel, under the buttons at the top:
--   headline  the short line shown on the panel ("New: ...")
--   more      the details, shown when you hover it (and in chat on click)
-- Change the id for new news: everyone who clicked the old one away sees
-- the new one. SK.NEWS = nil: no line at all.
SK.NEWS = {
    id = "scroll-bag",
    headline = "New: the Scroll Bag, a settings window and themes",
    more = {
        "Scroll Bag (/sk bag): every deciphered scroll you have, in your bags, bank and mail. Pick how many to keep, then stack, sell, mail or bank the extras.",
        "Right-click the Imbue or Familiar button for a row of picks. Star one to pin it.",
        "Works with AdiBags, Baganator, Bagnon, BetterBags and ArkInventory.",
        "Scrollkeeper has its own settings window now: /sk options.",
        "Themes: Classic, Dark, Darker classic and Modern (Options > Panel).",
        "Don't use a part? Turn it off in Options > Modules.",
        "Opt-in, anonymous usage stats help decide what to improve next (Options > Sharing).",
    },
}

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
