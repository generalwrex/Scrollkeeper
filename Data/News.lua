-- Scrollkeeper by generalwrex. Created 2026-11-24.
-- Read the LICENSE file before using any of this code.
-- Scrollkeeper: Data/News.lua
-- MADE BY tools/make-news.py FROM CHANGELOG.md: don't edit by hand, run it again.
-- The update's news, in chat once per account (see Data/Messages.lua).

local _, SK = ...

SK.MESSAGES = SK.MESSAGES or {}
table.insert(SK.MESSAGES, 1, {
    id = "news-1.3.0",
    alert = true,
    lines = {
        "|TInterface\\GossipFrame\\AvailableQuestIcon:16:16|t |cffffe14dHi from Natop! Scrollkeeper 1.3.0 just landed:|r",
        "|cff40c8ff>|r |cffffffffNew: the Scroll Bag. Every deciphered mage scroll you own in one list, counted across your bags, bank and mail, grouped like the panel with imbues split by weapon.|r",
        "|cff40c8ff>|r |cffffffffNew: pins. Right-click the panel's Familiar or Imbue button for all your scrolls of that kind: click one to use it, click its star to pin it.|r",
        "|cff40c8ff>|r |cffffffffNew weapon? Scrollkeeper says which imbues for it are waiting in your bank or mail.|r",
        "|cff40c8ff>|r |cffffffffNew in /sk options: Modules. Turn off what you don't use and its button leaves the panel; the rest close up.|r",
        "|cff40c8ff>|r |cffffffffNew theme: Modern. Flat slate panels, square buttons and boxes with thin borders that light up blue when you point at them, slate-blue section bars.|r",
        "|cff40c8ff>|r |cffffffffNew: Theme in /sk options > Panel. Classic, Dark and Darker classic.|r",
        "|cff40c8ff>|r |cffffffffNew: a red ? in the corner of every Scrollkeeper window.|r",
        "|cff9fe0ffThanks for playing with it! Ideas welcome (/sk options > About). - Natop (Archmage Naage)|r",
    },
})
