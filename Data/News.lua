-- Scrollkeeper by generalwrex. Created 2026-11-24.
-- Read the LICENSE file before using any of this code.
-- Scrollkeeper: Data/News.lua
-- MADE BY tools/make-news.py FROM CHANGELOG.md: don't edit by hand, run it again.
-- The update's news, in chat once per account (see Data/Messages.lua).

local _, SK = ...

SK.MESSAGES = SK.MESSAGES or {}
table.insert(SK.MESSAGES, 1, {
    id = "news-1.4.3",
    alert = true,
    lines = {
        "|TInterface\\GossipFrame\\AvailableQuestIcon:16:16|t |cffffe14dHey, Natop here! Scrollkeeper 1.4.3 is out. Here's what's new:|r",
        "|cff40c8ff>|r |cffffffffNew: react to board posts and replies with a heart, laugh, fire or wow.|r",
        "|cff40c8ff>|r |cffffffffNew: /sk tutorial, a quick tour of how mage scrolls work (thanks Navacado!).|r",
        "|cff40c8ff>|r |cffffffffNew: get pinged when someone replies, reacts or @mentions you, and shift-click item links into posts.|r",
        "|cff40c8ff>|r |cffffffffNew: Doorways pops up a Teleport button once you're grouped with a door, and knows far more inns.|r",
        "|cff40c8ff>|r |cffffffffNew: you all use the Scroll Bag a lot, so it got a big update: scrolls you don't have yet, favorites on top, and banking the ones you can't use yet.|r",
        "|cff9fe0ffHave fun, and tell me what breaks: /sk options > About. - Natop (Archmage Naage)|r",
    },
})
