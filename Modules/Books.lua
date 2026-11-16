-- Scrollkeeper: Modules/Books.lua
-- Books you hand in to the librarians (Owen Thadd in Undercity, Garion
-- Wendell in Stormwind), and where they're found.
--
-- The addon doesn't ship a list of books. It learns them:
--   * hand an item to a librarian, and that item is remembered as a book
--   * other Scrollkeeper users share the books they've learned
--   * until then, names like "Journal", "Volume" or "Tome" count too
-- Every time you loot a book, the spot is saved for the map:
-- bookDrops[mapID][cell] = count (same grid as scroll drops).

local _, SK = ...
local L = SK.L

-- The librarians who take books.
-- (Names go through translations too, for clients in other languages.)
local LIBRARIANS = {}
for _, name in ipairs({ "Owen Thadd", "Garion Wendell" }) do   -- Undercity, Stormwind
    LIBRARIANS[name] = true
    LIBRARIANS[L[name]] = true
end

-- Name words that usually mean a book, used until books are learned.
local BOOK_WORDS = {}
for _, word in ipairs({ "Journal", "Volume", "Tome", "Codex", "Diary", "Book of", "Treatise" }) do
    BOOK_WORDS[#BOOK_WORDS + 1] = word
    if L[word] ~= word then BOOK_WORDS[#BOOK_WORDS + 1] = L[word] end
end

-- Learned book item IDs: SK.db.bookIDs[itemID] = name.
function SK.IsBook(itemID, name)
    if itemID and SK.db.bookIDs and SK.db.bookIDs[itemID] then return true end
    for _, entry in pairs(SK.COMMUNITY_DATA or {}) do
        for _, id in ipairs(entry.bookIDs or {}) do
            if id == itemID then return true end
        end
    end
    if type(name) ~= "string" then return false end
    for _, word in ipairs(BOOK_WORDS) do
        if name:find(word, 1, true) then return true end
    end
    return false
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
            SK.Print(L["learned a book: "] .. (name or ("item " .. itemID)))
        end
    end
    before = now
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
    SK.Send("DROPS_CHANGED")
    SK.Send("MY_DATA_CHANGED")
end)
