-- Scrollkeeper: Data/News.lua
-- MADE BY tools/make-news.py FROM CHANGELOG.md: don't edit by hand, run it again.
-- The update's news, in chat once per account (see Data/Messages.lua).

local _, SK = ...

SK.MESSAGES = SK.MESSAGES or {}
table.insert(SK.MESSAGES, 1, {
    id = "news-update",
    alert = true,
    lines = {
        "|TInterface\\GossipFrame\\AvailableQuestIcon:16:16|t |cffffd100Hey, Natop here! Scrollkeeper got an update. Here's what's new:|r",
        "|cffffd100-|r New: the Scroll Bag. Every deciphered mage scroll you own in one list, counted across your bags, bank and mail, grouped like the panel with imbues split by weapon.",
        "|cffffd100-|r New: anonymous usage stats, so we can see which features people use the most and keep those in the best shape.",
        "|cffffd100-|r New theme: Modern. Flat slate panels, square buttons and boxes with thin borders that light up blue when you point at them, slate-blue section bars.",
        "|cffffd100-|r Scrollkeeper has its own settings window now: sections down the left, the settings on the right with what each one does.",
        "|cffffd100-|r New in /sk options: Modules. Turn off what you don't use and its button leaves the panel; the rest close up.",
        "|cffffd100-|r New: pins. Right-click the panel's Familiar or Imbue button for all your scrolls of that kind: click one to use it, click its star to pin it.",
        "|cffffd100-|r New weapon? Scrollkeeper says which imbues for it are waiting in your bank or mail.",
        "|cff9d9d9dThanks for using Scrollkeeper! Bugs or ideas: /sk options > About. - Natop (Archmage Naage)|r",
    },
})
