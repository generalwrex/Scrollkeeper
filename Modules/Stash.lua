-- Scrollkeeper: Modules/Stash.lua
-- The Scroll Bag's numbers: every deciphered mage scroll you own, wherever
-- it is (bags, bank, mail), and what to do with it.
--
--   Keep       you want these (up to your keep amount, or all of them)
--   Extra      more than your keep amount: sell, mail, post or delete them
--   Set aside  an imbue for a weapon you don't own: bank it, and hear about
--              it when you get one
--
-- Keep amounts come from a preset (three built in, and any you save), and
-- any number you change on top of it. Pins pick which scroll the Familiar
-- and Imbue buttons use: one familiar pin, one imbue pin per weapon kind.
--
-- Saved:
--   SK.db.bagPresets[name] = { keep = { [itemID] = n, -1 = keep all } }   (account)
--   SK.charDB.stash = { preset, changes = {...}, bank = {...}, bankAt, mail = {...},
--                       mailAt, bankWeapons = {...}, pins = { familiar, imbue = { staff = id } } }

local _, SK = ...
local L = SK.L

local KEEP_ALL = -1

------------------------------------------------------------------------
-- What each mage scroll is: the weapon an imbue needs, and whether it's
-- bound (can't be mailed or sold on the auction house). From the item
-- tooltips (Wowhead and the game).
------------------------------------------------------------------------

SK.SCROLL_FACTS = {
    [274947] = { weapon = "staff" }, [277485] = { weapon = "staff" }, [277486] = { weapon = "staff" },
    [277487] = { weapon = "staff" }, [277497] = { weapon = "staff" }, [277494] = { weapon = "staff" },
    [277496] = { weapon = "staff" }, [277495] = { weapon = "staff" }, [277500] = { weapon = "staff" },
    [277501] = { weapon = "staff" }, [277502] = { weapon = "staff" }, [277503] = { weapon = "staff" },
    [275067] = { weapon = "dagger" }, [277488] = { weapon = "dagger" }, [277498] = { weapon = "dagger" },
    [277489] = { weapon = "sword" },
    [213550] = { bound = true }, [277484] = { bound = true }, [277491] = { bound = true },
    [277490] = { bound = true }, [217496] = { bound = true }, [277504] = { bound = true },
}

-- Weapon subclass IDs (item class 2) by the word imbue tooltips use.
local KIND_OF_SUBCLASS = { [10] = "staff", [15] = "dagger", [7] = "sword", [8] = "sword",
    [4] = "mace", [5] = "mace", [0] = "axe", [1] = "axe", [19] = "wand" }
SK.WEAPON_KIND_OF_SUBCLASS = KIND_OF_SUBCLASS

local LIMINAL = 213548
local ODD_MELON = 213550

function SK.IsBoundScroll(itemID)
    local facts = SK.SCROLL_FACTS[itemID]
    return facts and facts.bound or false
end

-- The weapon kind an imbue needs ("staff", "dagger"...), or nil.
function SK.ImbueWeapon(itemID, scroll)
    local facts = SK.SCROLL_FACTS[itemID]
    return (facts and facts.weapon) or (scroll and scroll.imbueFor) or nil
end

-- Which category a scroll goes in, by item ID (works for bank and mail too).
local function CategoryOf(itemID)
    for _, scroll in ipairs(SK.bags and SK.bags.translated or {}) do
        if scroll.itemID == itemID then return scroll.category end
    end
    return SK.CategoryFor(SK.EnglishScrollName(itemID) or "", itemID)
end
SK.StashCategory = CategoryOf

------------------------------------------------------------------------
-- Saved state
------------------------------------------------------------------------

local function State()
    if not SK.charDB then return { changes = {}, bank = {}, mail = {}, bankWeapons = {}, pins = { imbue = {} } } end
    local s = SK.charDB.stash
    if type(s) ~= "table" then s = {}; SK.charDB.stash = s end
    s.changes = s.changes or {}
    s.bank = s.bank or {}
    s.bankSlots = s.bankSlots or {}
    s.mail = s.mail or {}
    s.bankWeapons = s.bankWeapons or {}
    s.pins = s.pins or {}
    s.pins.imbue = s.pins.imbue or {}
    return s
end
SK.StashState = State

local function CustomPresets()
    SK.db.bagPresets = SK.db.bagPresets or {}
    return SK.db.bagPresets
end

------------------------------------------------------------------------
-- Presets
------------------------------------------------------------------------

-- Built-in presets: a rule for each scroll. nil = keep all.
SK.BAG_PRESETS = {
    { key = "satchel", name = "Apprentice's Satchel",
      tip = "Lean: imbues for your spec, all your familiars, a stack of utility scrolls. Combat scrolls are extra (one Odd Melon stays, for fun)." },
    { key = "kit", name = "Battlemage's Kit",
      tip = "Like the Satchel, plus a stack of each combat scroll for dungeons and raids." },
    { key = "hoard", name = "Archivist's Hoard",
      tip = "Keep everything. Just shows what you have and where." },
}

local function BuiltInKeep(preset, itemID)
    if preset == "hoard" then return KEEP_ALL end
    local category = CategoryOf(itemID)
    if category == "familiars" or category == "upgrades" then return KEEP_ALL end
    if category == "combat" then
        if itemID == ODD_MELON then return 1 end
        return preset == "kit" and 5 or 0
    end
    if category == "imbues" then
        -- Another school's imbue (Flame for a Frost mage) isn't one you use.
        local spec = SK.MageSpec and SK.MageSpec()
        local school = SK.ImbueSchool and SK.ImbueSchool({ itemID = itemID })
        if spec and school and school ~= spec and not (SK.db and SK.db.imbueByUse) then return 0 end
        return 5
    end
    return 5
end

-- The preset this character uses: its key (a built-in key, or a custom name).
function SK.BagPreset()
    local key = State().preset
    if key and (key == "satchel" or key == "kit" or key == "hoard" or CustomPresets()[key]) then return key end
    return "satchel"
end

function SK.BagPresetName(key)
    key = key or SK.BagPreset()
    for _, preset in ipairs(SK.BAG_PRESETS) do
        if preset.key == key then return L[preset.name] end
    end
    return key
end

function SK.IsCustomPreset(key) return CustomPresets()[key] ~= nil end

function SK.CustomPresetNames()
    local names = {}
    for name in pairs(CustomPresets()) do names[#names + 1] = name end
    table.sort(names)
    return names
end

-- The preset's own number for a scroll (before your changes).
local function PresetKeep(key, itemID)
    local custom = CustomPresets()[key]
    if custom then
        local n = custom.keep and custom.keep[itemID]
        if n ~= nil then return n end
        return BuiltInKeep(custom.base or "satchel", itemID)
    end
    return BuiltInKeep(key, itemID)
end

-- How many to keep: a number, or nil for "keep all".
function SK.KeepAmount(itemID)
    local n = State().changes[itemID]
    if n == nil then n = PresetKeep(SK.BagPreset(), itemID) end
    if n == KEEP_ALL then return nil end
    return n
end

-- Change a keep amount (nil = keep all). It's a change on top of the preset
-- until you save it.
function SK.SetKeepAmount(itemID, n)
    local value = n == nil and KEEP_ALL or math.max(0, math.floor(n))
    if value == PresetKeep(SK.BagPreset(), itemID) then value = nil end
    State().changes[itemID] = value
    SK.Send("STASH_CHANGED")
end

function SK.BagPresetChanged() return next(State().changes) ~= nil end

function SK.UseBagPreset(key)
    local s = State()
    s.preset = key
    s.changes = {}
    SK.Send("STASH_CHANGED")
end

-- Every scroll's keep amount right now (preset plus changes), for saving.
local function Snapshot()
    local keep = {}
    for itemID in pairs(SK.MAGE_SCROLL_IDS or {}) do
        local n = SK.KeepAmount(itemID)
        keep[itemID] = n == nil and KEEP_ALL or n
    end
    return keep
end

-- Save the current numbers as a new preset (or over a custom one).
function SK.SaveBagPreset(name)
    name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then return false, L["Give the preset a name."] end
    for _, preset in ipairs(SK.BAG_PRESETS) do
        if name:lower() == L[preset.name]:lower() or name:lower() == preset.name:lower() then
            return false, L["That's a built-in preset's name. Pick another."]
        end
    end
    CustomPresets()[name] = { keep = Snapshot(), at = time() }
    SK.UseBagPreset(name)
    return true
end

function SK.RenameBagPreset(old, new)
    local presets = CustomPresets()
    if not presets[old] then return false end
    new = type(new) == "string" and new:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if new == "" or presets[new] then return false, L["That name is taken or empty."] end
    presets[new], presets[old] = presets[old], nil
    if State().preset == old then State().preset = new end
    SK.Send("STASH_CHANGED")
    return true
end

function SK.DeleteBagPreset(name)
    CustomPresets()[name] = nil
    if State().preset == name then SK.UseBagPreset("satchel") else SK.Send("STASH_CHANGED") end
end

------------------------------------------------------------------------
-- Pins: the scroll the Familiar and Imbue buttons use, whatever else
-- Scrollkeeper would pick. Imbues have one pin per weapon kind.
------------------------------------------------------------------------

function SK.PinOf(categoryKey, weaponKind)
    local pins = State().pins
    if categoryKey == "familiars" then return pins.familiar end
    if categoryKey == "imbues" and weaponKind then return pins.imbue[weaponKind] end
    return nil
end

function SK.IsPinned(itemID)
    local pins = State().pins
    if pins.familiar == itemID then return true end
    for _, id in pairs(pins.imbue) do if id == itemID then return true end end
    return false
end

-- Pin (or unpin, if it's pinned) a familiar or imbue scroll.
function SK.TogglePin(itemID)
    local pins = State().pins
    local category = CategoryOf(itemID)
    if category == "familiars" then
        pins.familiar = pins.familiar ~= itemID and itemID or nil
    elseif category == "imbues" then
        local kind = SK.ImbueWeapon(itemID)
        if not kind then return end
        pins.imbue[kind] = pins.imbue[kind] ~= itemID and itemID or nil
    else
        return
    end
    SK.Send("PINS_CHANGED")
    SK.Send("REMINDERS_CHANGED")
end

-- The main-hand weapon's kind ("staff", "dagger"...), or nil.
function SK.MainHandKind()
    local subClassID = SK.MainHandWeapon and SK.MainHandWeapon()
    return subClassID and KIND_OF_SUBCLASS[subClassID] or nil
end

------------------------------------------------------------------------
-- Counting: bags (live), bank and mail (remembered from your last visit)
------------------------------------------------------------------------

local BANK_BAGS = { -1, -3, 6, 7, 8, 9, 10, 11, 12 }

local function IsMageScrollID(itemID)
    return itemID and (SK.MAGE_SCROLL_IDS[itemID] ~= nil or SK.SCROLL_FACTS[itemID] ~= nil)
end

local function WeaponKindOf(itemID)
    if not (itemID and C_Item and C_Item.GetItemInfoInstant) then return nil end
    local _, _, _, _, _, classID, subClassID = SK.Try(C_Item.GetItemInfoInstant, itemID)
    return classID == 2 and KIND_OF_SUBCLASS[subClassID] or nil
end

-- Scrolls and weapon kinds in a list of containers.
local function ScanContainers(list)
    local counts, slots, weapons = {}, {}, {}
    if not C_Container then return counts, slots, weapons end
    for _, bag in ipairs(list) do
        for slot = 1, SK.Try(C_Container.GetContainerNumSlots, bag) or 0 do
            local info = SK.Try(C_Container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and info.itemID then
                if IsMageScrollID(info.itemID) then
                    counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
                    slots[info.itemID] = (slots[info.itemID] or 0) + 1
                end
                local kind = WeaponKindOf(info.itemID)
                if kind then weapons[kind] = true end
            end
        end
    end
    return counts, slots, weapons
end

local bankOpen = false
local function ScanBank()
    local counts, slots, weapons = ScanContainers(BANK_BAGS)
    local s = State()
    s.bank, s.bankSlots, s.bankWeapons, s.bankAt = counts, slots, weapons, time()
    SK.Send("STASH_CHANGED")
end
SK.On("BANKFRAME_OPENED", function() bankOpen = true; C_Timer.After(0.3, function() SK.Safely("bank scan", ScanBank) end) end)
SK.On("BANKFRAME_CLOSED", function() bankOpen = false end)
SK.On("PLAYERBANKSLOTS_CHANGED", function() if bankOpen then SK.Safely("bank scan", ScanBank) end end)
SK.Listen("BAGS_CHANGED", function() if bankOpen then SK.Safely("bank scan", ScanBank) end end)
function SK.BankIsOpen() return bankOpen end

-- Mail: attachments in your inbox.
local function ScanMail()
    if not (GetInboxNumItems and GetInboxItem) then return end
    local counts = {}
    local max = ATTACHMENTS_MAX_RECEIVE or 16
    for i = 1, GetInboxNumItems() or 0 do
        for a = 1, max do
            local _, itemID, _, count = SK.Try(GetInboxItem, i, a)
            if IsMageScrollID(itemID) then counts[itemID] = (counts[itemID] or 0) + (count or 1) end
        end
    end
    local s = State()
    s.mail, s.mailAt = counts, time()
    SK.Send("STASH_CHANGED")
end
SK.On("MAIL_INBOX_UPDATE", function() SK.Safely("mail scan", ScanMail) end)

-- Weapon kinds you own: equipped, in your bags, and in your bank.
function SK.OwnedWeaponKinds()
    local kinds = {}
    for _, slot in ipairs({ 16, 17 }) do
        local kind = WeaponKindOf(GetInventoryItemID and GetInventoryItemID("player", slot))
        if kind then kinds[kind] = true end
    end
    local _, _, bagWeapons = ScanContainers({ 0, 1, 2, 3, 4, 5 })
    for kind in pairs(bagWeapons) do kinds[kind] = true end
    if SK.db.bagCountBank ~= false then
        for kind in pairs(State().bankWeapons) do kinds[kind] = true end
    end
    return kinds
end

------------------------------------------------------------------------
-- The list: one entry per kind of scroll, with where it is and its status
------------------------------------------------------------------------

-- Status for one kind of scroll. Returns status ("keep", "extra", "aside"),
-- how many are extra, and why, in words.
function SK.StashStatus(itemID, total, owned)
    local kind = SK.ImbueWeapon(itemID)
    owned = owned or SK.OwnedWeaponKinds()
    if kind and SK.db.bagSetAside ~= false and not owned[kind] then
        return "aside", 0, L["no %s"]:format(L[kind])
    end
    local keep = SK.KeepAmount(itemID)
    if keep == nil then return "keep", 0, L["keeping all"] end
    if total > keep then return "extra", total - keep, L["keeping %d"]:format(keep) end
    return "keep", 0, L["keeping %d"]:format(keep)
end

-- Every kind of deciphered mage scroll you have:
-- list of { itemID, name, category, weapon, bound, bags, bank, mail, total,
--           slots, keep, status, extra, why, pinned }
function SK.StashList()
    local s = State()
    local bags, bagSlots = ScanContainers({ 0, 1, 2, 3, 4, 5 })
    local entries, byID = {}, {}
    local function Entry(itemID)
        local e = byID[itemID]
        if not e then
            e = { itemID = itemID, bags = 0, bank = 0, mail = 0, slots = 0 }
            byID[itemID] = e
            entries[#entries + 1] = e
        end
        return e
    end
    for id, n in pairs(bags) do local e = Entry(id); e.bags = n; e.slots = e.slots + (bagSlots[id] or 0) end
    if SK.db.bagCountBank ~= false then
        for id, n in pairs(s.bank) do local e = Entry(id); e.bank = n; e.slots = e.slots + (s.bankSlots[id] or 0) end
    end
    if SK.db.bagCountMail ~= false then
        for id, n in pairs(s.mail) do Entry(id).mail = n end
    end
    local owned = SK.OwnedWeaponKinds()
    for _, e in ipairs(entries) do
        e.total = e.bags + e.bank + e.mail
        e.name = (C_Item and SK.Try(C_Item.GetItemNameByID, e.itemID)) or SK.MAGE_SCROLL_IDS[e.itemID] or ("item " .. e.itemID)
        e.category = CategoryOf(e.itemID)
        e.weapon = SK.ImbueWeapon(e.itemID)
        e.bound = SK.IsBoundScroll(e.itemID)
        e.keep = SK.KeepAmount(e.itemID)
        e.status, e.extra, e.why = SK.StashStatus(e.itemID, e.total, owned)
        e.pinned = SK.IsPinned(e.itemID)
    end
    table.sort(entries, function(a, b) return a.name < b.name end)
    return entries, owned
end

-- One kind's entry, or nil if you have none.
function SK.StashEntry(itemID)
    for _, e in ipairs((SK.StashList())) do
        if e.itemID == itemID then return e end
    end
end

-- A short note for chat and tooltips: "extra, keeping 1", "set aside, no sword".
function SK.StashNote(itemID)
    local e = SK.StashEntry(itemID)
    if not e then return nil end
    if e.status == "aside" then return "|cff66bbff" .. L["set aside, %s"]:format(e.why) .. "|r" end
    if e.status == "extra" then return "|cffff6666" .. L["%d extra, %s"]:format(e.extra, e.why) .. "|r" end
    if e.keep == nil then return "|cff40ff40" .. L["keep, %d of all"]:format(e.total) .. "|r" end
    return "|cff40ff40" .. L["keep, %d of %d"]:format(e.total, e.keep) .. "|r"
end

------------------------------------------------------------------------
-- Which stacks in your bags are the extras: the smallest stacks go first,
-- so the big ones stay. Returns a list of { bag, slot, count, take } where
-- take is how many of that stack are extra (a whole stack or part of one).
------------------------------------------------------------------------

function SK.ExtraStacks(itemID, extra, where)
    local stacks = {}
    for _, bag in ipairs(where or { 0, 1, 2, 3, 4, 5 }) do
        for slot = 1, SK.Try(C_Container.GetContainerNumSlots, bag) or 0 do
            local info = SK.Try(C_Container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and info.itemID == itemID then
                stacks[#stacks + 1] = { bag = bag, slot = slot, count = info.stackCount or 1 }
            end
        end
    end
    table.sort(stacks, function(a, b) return a.count < b.count end)
    local list, left = {}, extra
    for _, stack in ipairs(stacks) do
        if left <= 0 then break end
        stack.take = math.min(stack.count, left)
        left = left - stack.take
        list[#list + 1] = stack
    end
    return list
end

-- Is this bag slot (part of) an extra? For bag addon marks and junk.
-- Cached per bag update, since bag addons ask for every slot.
local slotCache
SK.Listen("BAGS_CHANGED", function() slotCache = nil end)
SK.Listen("STASH_CHANGED", function() slotCache = nil end)
SK.Listen("PINS_CHANGED", function() slotCache = nil end)

local function BuildSlotCache()
    slotCache = { slots = {}, status = {} }
    local entries = SK.StashList()
    for _, e in ipairs(entries) do
        slotCache.status[e.itemID] = e
        if e.status == "extra" then
            -- Extras in bags only: bank and mail ones aren't in a bag slot.
            local inBags = math.min(e.extra, e.bags)
            for _, stack in ipairs(SK.ExtraStacks(e.itemID, inBags)) do
                slotCache.slots[stack.bag .. ":" .. stack.slot] = stack.take >= stack.count and "extra" or "partial"
            end
        end
    end
end

-- Status of the scroll in a bag slot: "keep", "extra", "partial" (some of
-- the stack is extra), "aside", or nil (not a mage scroll). Also the entry.
function SK.StashSlotStatus(bag, slot, itemID)
    if not itemID or not IsMageScrollID(itemID) then return nil end
    if not slotCache then BuildSlotCache() end
    local e = slotCache.status[itemID]
    if not e then return nil end
    if e.status == "aside" then return "aside", e end
    if bag and slot then
        local mark = slotCache.slots[bag .. ":" .. slot]
        if mark then return mark, e end
        return "keep", e
    end
    return e.status, e
end

------------------------------------------------------------------------
-- A new weapon: tell me about imbues waiting in the bank or mail for it
------------------------------------------------------------------------

local knownKinds
local function CheckNewWeapons()
    if not (SK.isMage and SK.db) then return end
    local now = {}
    for _, slot in ipairs({ 16, 17 }) do
        local kind = WeaponKindOf(GetInventoryItemID and GetInventoryItemID("player", slot))
        if kind then now[kind] = true end
    end
    local _, _, bagWeapons = ScanContainers({ 0, 1, 2, 3, 4, 5 })
    for kind in pairs(bagWeapons) do now[kind] = true end
    if knownKinds and SK.db.bagWeaponAlert ~= false and SK.ModuleOn("Bag") then
        local s = State()
        for kind in pairs(now) do
            if not knownKinds[kind] then
                local waiting = {}
                for id, n in pairs(s.bank) do
                    if SK.ImbueWeapon(id) == kind then waiting[#waiting + 1] = L["%d %s in your bank"]:format(n, SK.ScrollLink(id)) end
                end
                for id, n in pairs(s.mail) do
                    if SK.ImbueWeapon(id) == kind then waiting[#waiting + 1] = L["%d %s in your mail"]:format(n, SK.ScrollLink(id)) end
                end
                if #waiting > 0 then
                    SK.Print(L["a %s! You have imbues for it: %s."]:format(L[kind], table.concat(waiting, ", ")))
                end
            end
        end
    end
    knownKinds = now
end
SK.On("PLAYER_EQUIPMENT_CHANGED", function() C_Timer.After(0.5, function() SK.Safely("weapon alert", CheckNewWeapons) end) end)
SK.Listen("BAGS_CHANGED", function() SK.Safely("weapon alert", CheckNewWeapons) end)

------------------------------------------------------------------------
-- Running low on Liminal Passage (Doorways uses it)
------------------------------------------------------------------------

-- (How many you carry: SK.LiminalCount, in UI/Doors.lua.)
-- A warning line, or nil: only once you've carried Liminal Passage at all.
function SK.LiminalLowText()
    local limit = tonumber(SK.db and SK.db.liminalLow) or 2
    if limit <= 0 or not (SK.db and SK.db.liminalSeen) or not SK.ModuleOn("Doors") then return nil end
    local n = SK.LiminalCount()
    if n > limit then return nil end
    local s = State()
    local elsewhere = (s.bank[LIMINAL] or 0) + (s.mail[LIMINAL] or 0)
    local text = n == 0 and L["Out of Scroll of Liminal Passage."] or L["Only %d Scroll of Liminal Passage left."]:format(n)
    if elsewhere > 0 then text = text .. " " .. L["%d more in your bank or mail."]:format(elsewhere) end
    return text
end

local lastLiminal
SK.Listen("BAGS_CHANGED", function()
    if not (SK.isMage and SK.db) then return end
    local n = SK.LiminalCount()
    if n > 0 then SK.db.liminalSeen = true end
    local limit = tonumber(SK.db.liminalLow) or 2
    -- Say it once, when it drops to the limit or below.
    if lastLiminal and n < lastLiminal and n <= limit and limit > 0 and SK.db.liminalLowChat ~= false and SK.ModuleOn("Doors") then
        SK.Print(SK.LiminalLowText() or "")
    end
    lastLiminal = n
end)
