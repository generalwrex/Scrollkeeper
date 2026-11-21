-- Scrollkeeper: Modules/Books.lua
-- Books you hand in to the librarians (Owen Thadd in Undercity, Garion
-- Wendell in Stormwind), and where they're found.
--
-- Which items are books:
--   * the 40 books by name (Data/BookSpots.lua, from Wowhead)
--   * hand an item to a librarian, and that item is remembered as a book
--   * other Scrollkeeper users share the books they've learned
-- Every time you loot a book, the spot is saved for the map:
-- bookDrops[mapID][cell] = count (same grid as scroll drops).

local _, SK = ...
local L = SK.L

-- The librarians who take books.
-- (Names go through translations too, for clients in other languages.
-- Built on first use, after your language is applied.)
local LIBRARIANS, BOOK_WORDS
local function Lists()
    if LIBRARIANS then return end
    LIBRARIANS, BOOK_WORDS = {}, {}
    for _, name in ipairs({ "Owen Thadd", "Garion Wendell" }) do   -- Undercity, Stormwind
        LIBRARIANS[name] = true
        LIBRARIANS[L[name]] = true
    end
    for _, word in ipairs({ "Journal", "Volume", "Tome", "Codex", "Diary", "Book of", "Treatise" }) do
        BOOK_WORDS[#BOOK_WORDS + 1] = word
        if L[word] ~= word then BOOK_WORDS[#BOOK_WORDS + 1] = L[word] end
    end
end

-- Is this item a book for the librarians? Yes if it was handed to a
-- librarian (yours or anyone's: SK.db.bookIDs[itemID] = name), or it's
-- named like one of the 40 books (Data/BookSpots.lua). Words like
-- "Journal" or "Tome" alone aren't enough: quest items use them too.
local bookNames
function SK.IsBook(itemID, name)
    if itemID and SK.db.bookIDs and SK.db.bookIDs[itemID] then return true end
    for _, entry in pairs(SK.COMMUNITY_DATA or {}) do
        for _, id in ipairs(entry.bookIDs or {}) do
            if id == itemID then return true end
        end
    end
    for _, entry in pairs(SK.db.community or {}) do
        for _, id in ipairs(entry.bookIDs or {}) do
            if id == itemID then return true end
        end
    end
    if type(name) ~= "string" then return false end
    if not bookNames then
        bookNames = {}
        for _, spot in ipairs(SK.BOOK_SPOTS or {}) do bookNames[spot.name:lower()] = true end
    end
    return bookNames[name:lower()] or false
end

-- Book spots saved by the old guess (any "Journal" or "Tome") that aren't
-- real books: forget them, once per load.
SK.Listen("READY", function()
    local names = SK.db.bookNames or {}
    local items = SK.db.bookItems or {}
    for mapID, cells in pairs(SK.db.bookDrops or {}) do
        for cell in pairs(cells) do
            local name = names[mapID .. ":" .. cell]
            local itemID = items[mapID] and items[mapID][cell]
            if (name or itemID) and not SK.IsBook(itemID, name) then
                cells[cell] = nil
                names[mapID .. ":" .. cell] = nil
                if items[mapID] then items[mapID][cell] = nil end
            end
        end
        if not next(cells) then SK.db.bookDrops[mapID] = nil end
    end
end)

-- Books this character has handed in, by name (lowercase), for the map:
-- SK.db.handedBooks[character][name] = true.
local function HandedSet()
    SK.db.handedBooks = SK.db.handedBooks or {}
    local key = SK.CharKey and SK.CharKey() or "?"
    SK.db.handedBooks[key] = SK.db.handedBooks[key] or {}
    return SK.db.handedBooks[key]
end

function SK.MarkBookHanded(name)
    if type(name) == "string" and name ~= "" then HandedSet()[name:lower()] = true end
end

function SK.BookHanded(name)
    return type(name) == "string" and HandedSet()[name:lower()] or false
end

-- Which of your characters handed this book in: their names (no realm).
function SK.BookHandedBy(name)
    local list = {}
    if type(name) ~= "string" then return list end
    for key, books in pairs(SK.db.handedBooks or {}) do
        if books[name:lower()] then list[#list + 1] = (key:gsub("%-.*$", "")) end
    end
    table.sort(list)
    return list
end

function SK.LearnBook(itemID, name)
    if not itemID then return end
    SK.db.bookIDs = SK.db.bookIDs or {}
    if SK.db.bookIDs[itemID] then return end
    SK.db.bookIDs[itemID] = name or true
    SK.Send("MY_DATA_CHANGED")
end

------------------------------------------------------------------------
-- Learning: what leaves your bags while you talk to a librarian
------------------------------------------------------------------------

local function BagCounts()
    local counts = {}
    if not (C_Container and C_Container.GetContainerNumSlots) then return counts end
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    return counts
end

local talking, before

-- Are you talking to a librarian? Sometimes the game hides NPC names from
-- addons (a "secret value" you can't compare or look up). Then fall back
-- to whether you're standing by a librarian, which Study already knows.
local function TalkingToLibrarian()
    local npc = UnitName("npc")
    local hidden = npc ~= nil and issecretvalue and issecretvalue(npc)
    Lists()
    if npc and not hidden then return LIBRARIANS[npc] == true end
    return SK.InLibrary and SK.InLibrary() and true or false
end

local function StartTalking()
    if not TalkingToLibrarian() then return end
    talking = true
    before = before or BagCounts()
end

local function StopTalking()
    -- Hand-ins can land a moment after the window closes.
    C_Timer.After(2, function()
        talking, before = false, nil
    end)
end

SK.On("GOSSIP_SHOW", StartTalking)
SK.On("QUEST_DETAIL", StartTalking)
SK.On("QUEST_PROGRESS", StartTalking)
SK.On("QUEST_COMPLETE", StartTalking)
SK.On("MERCHANT_SHOW", function() talking, before = false, nil end)   -- selling isn't handing in
SK.On("GOSSIP_CLOSED", StopTalking)
SK.On("QUEST_FINISHED", StopTalking)

SK.On("BAG_UPDATE_DELAYED", function()
    if not (talking and before) then return end
    local now = BagCounts()
    for itemID, count in pairs(before) do
        if (now[itemID] or 0) < count and itemID ~= SK.ITEM_LIGHT_FEATHER then
            local name = C_Item and SK.Try(C_Item.GetItemNameByID, itemID)
            SK.LearnBook(itemID, name)
            SK.MarkBookHanded(name)
            SK.Print(L["learned a book: "] .. (name or ("item " .. itemID)))
        end
    end
    before = now
end)

------------------------------------------------------------------------
-- Books handed in, and the librarians' rewards
-- Each book is handed in once, as a quest. Its quest ID is remembered the
-- first time, and from then on the game says whether you've done it, so
-- older hand-ins count too once their quest is known.
------------------------------------------------------------------------

SK.BOOKS_TOTAL = 40
-- Rewards at these counts (you pick one). 25 and 35 are from the wiki
-- only so far.
SK.BOOK_REWARDS = {
    { books = 10, title = "Friend of the Library", items = { "Scholarly Pendant", "Erudite's Amulet" } },
    { books = 20, title = "Greater Friend of the Library", items = { "Field Researcher's Loop", "Philanthropist's Ring" } },
    { books = 25, items = { "Truthseeker's Bow", "Crest of Elucidation", "Researcher's Night Light" } },
    { books = 35, items = { "Antique Bulwark", "Museum Keeper's Chain", "Artifact Seeker's Pendant" } },
}

local function QuestDone(questID)
    local check = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
    return check and SK.Try(check, questID) and true or false
end

-- Books this character has handed in, and the next reward (or nil).
function SK.BookProgress()
    local handed = 0
    for questID in pairs(SK.db.bookQuests or {}) do
        if QuestDone(questID) then handed = handed + 1 end
    end
    -- What this character was seen handing in (in case the game can't say).
    local mage = SK.MyMage and SK.MyMage()
    local seen = 0
    for _ in pairs(mage and mage.booksHanded or {}) do seen = seen + 1 end
    handed = math.min(math.max(handed, seen), SK.BOOKS_TOTAL)
    for _, reward in ipairs(SK.BOOK_REWARDS) do
        if handed < reward.books then return handed, reward end
    end
    return handed, nil
end

function SK.BookRewardText(reward)
    local names = {}
    for _, item in ipairs(reward.items) do names[#names + 1] = L[item] end
    return table.concat(names, L[" or "])
end

SK.On("QUEST_TURNED_IN", function(questID)
    questID = tonumber(questID)
    if not questID or not (talking or TalkingToLibrarian()) then return end
    SK.db.bookQuests = SK.db.bookQuests or {}
    SK.db.bookQuests[questID] = true
    -- Each book's quest is named after the book.
    local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and SK.Try(C_QuestLog.GetTitleForQuestID, questID)
    SK.MarkBookHanded(SK.Known(title))
    local mage = SK.MyMage and SK.MyMage()
    if mage then
        mage.booksHanded = mage.booksHanded or {}
        mage.booksHanded[questID] = true
    end
    local handed, reward = SK.BookProgress()
    if reward then
        SK.Print(L["book handed in: %d of %d. Next reward at %d books: %s."]:format(handed, SK.BOOKS_TOTAL, reward.books, SK.BookRewardText(reward)))
    else
        SK.Print(L["book handed in: %d of %d."]:format(handed, SK.BOOKS_TOTAL))
    end
    SK.Send("DROPS_CHANGED")
end)

------------------------------------------------------------------------
-- Where books are found
------------------------------------------------------------------------

SK.On("CHAT_MSG_LOOT", function(message)
    if type(message) ~= "string" then return end
    -- Only your own loot ("You receive loot: ...").
    local mine = LOOT_ITEM_SELF and message:find(LOOT_ITEM_SELF:match("^(.-)%%s"), 1, true)
    if LOOT_ITEM_SELF and not mine then return end
    local itemID = tonumber(message:match("item:(%d+)"))
    local name = message:match("|h%[(.-)%]|h")
    if not (itemID and SK.IsBook(itemID, name)) then return end

    local mapID, x, y = SK.PlayerMapPosition()
    if not mapID then return end
    SK.db.bookDrops = SK.db.bookDrops or {}
    SK.db.bookDrops[mapID] = SK.db.bookDrops[mapID] or {}
    local cell = SK.CellFor(x, y)
    SK.db.bookDrops[mapID][cell] = (SK.db.bookDrops[mapID][cell] or 0) + 1
    SK.db.bookNames = SK.db.bookNames or {}
    SK.db.bookNames[mapID .. ":" .. cell] = name
    -- Which book (by item ID, the same in every language), to share.
    SK.db.bookItems = SK.db.bookItems or {}
    SK.db.bookItems[mapID] = SK.db.bookItems[mapID] or {}
    SK.db.bookItems[mapID][cell] = itemID
    if SK.LogLoot then SK.Safely("loot log", SK.LogLoot, "book", itemID, nil, 1) end
    SK.Send("DROPS_CHANGED")
    SK.Send("MY_DATA_CHANGED")
end)

-- Books handed in before the map knew: look up each one's quest title.
SK.Listen("READY", function()
    if not (C_QuestLog and C_QuestLog.GetTitleForQuestID) then return end
    local mage = SK.MyMage and SK.MyMage()
    for questID in pairs(mage and mage.booksHanded or {}) do
        SK.MarkBookHanded(SK.Known(SK.Try(C_QuestLog.GetTitleForQuestID, questID)))
    end
end)
