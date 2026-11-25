-- Scrollkeeper: Data/News.lua
-- MADE BY tools/make-news.py FROM CHANGELOG.md: don't edit by hand, run it again.
-- The update's news, in chat once per account (see Data/Messages.lua).

local _, SK = ...

SK.MESSAGES = SK.MESSAGES or {}
table.insert(SK.MESSAGES, 1, {
    id = "news-update",
    alert = true,
    lines = {
        "|TInterface\\GossipFrame\\AvailableQuestIcon:16:16|t |cffffe14dHey, Natop here! Scrollkeeper got an update. Here's what's new:|r",
        "|cff40c8ff>|r |cffffffffNew: the Scroll Bag. Every deciphered mage scroll you own in one list, counted across your bags, bank and mail, grouped like the panel with imbues split by weapon.|r",
        "|cff40c8ff>|r |cffffffffNew: anonymous usage stats, so we can see which features people use the most and keep those in the best shape.|r",
        "|cff40c8ff>|r |cffffffffShift-click the X on any Scrollkeeper window to close all of them.|r",
        "|cff40c8ff>|r |cffffffffNew theme: Modern. Flat slate panels, square buttons and boxes with thin borders that light up blue when you point at them, slate-blue section bars.|r",
        "|cff40c8ff>|r |cffffffffScrollkeeper has its own settings window now: sections down the left, the settings on the right with what each one does.|r",
        "|cff40c8ff>|r |cffffffffNew in /sk options: Modules. Turn off what you don't use and its button leaves the panel; the rest close up.|r",
        "|cff40c8ff>|r |cffffffffNew: pins. Right-click the panel's Familiar or Imbue button for all your scrolls of that kind: click one to use it, click its star to pin it.|r",
        "|cff9fe0ffThanks for using Scrollkeeper! Bugs or ideas: /sk options > About. - Natop (Archmage Naage)|r",
    },
})
