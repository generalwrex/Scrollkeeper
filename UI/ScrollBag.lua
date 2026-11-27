-- Scrollkeeper: UI/ScrollBag.lua
-- The Scroll Bag (/sk bag, or the bag button on the panel): every deciphered
-- mage scroll you own, in your bags, bank and mail, and what to do with it.
--
--   top      preset (pick one, or save your own), what's being counted,
--            and filters: All, Extra, Set aside, Bound
--   list     a header per group (imbues by weapon), a row per scroll:
--            icon (border = status), name, pin star, lock if bound,
--            a bar of where they are, keep - n +, status, total
--   bottom   totals, and Stack / Sell extras / Mail extras / Bank extras / Deposit
--            set aside / Delete extras
--
-- Every action is one click from you, and only does anything at the right
-- place (a vendor, the mailbox, the bank). Nothing runs in combat.
-- Right-click a row for its menu: keep amount (all, a number, the
-- preset's), protect (never sold, mailed or deleted), pin, don't set
-- aside, link in chat.

local _, SK = ...
local L = SK.L

local WIDTH, LIST_HEIGHT, ROW = 580, 370, 22
local INNER = WIDTH - 32
local COLORS = {
    keep = { 0.25, 0.85, 0.35 }, extra = { 0.9, 0.25, 0.25 }, aside = { 0.35, 0.6, 1 },
}
local WHERE_COLORS = { bags = { 0.95, 0.8, 0.35 }, bank = { 0.45, 0.68, 1 }, mail = { 0.8, 0.55, 1 } }
local WHERE = { "bags", "bank", "mail" }
-- Where each column starts in a row (the headings above the list line up).
local COLUMN_X = { bags = 262, bank = 296, mail = 330 }
local GROUP_ORDER = { "upgrades", "imbues:staff", "imbues:dagger", "imbues:sword", "imbues:other", "familiars", "combat", "utility" }
local GROUP_LABELS = { upgrades = "Upgrades", familiars = "Familiars", combat = "Combat", utility = "Utility",
    ["imbues:staff"] = "Imbues: staff", ["imbues:dagger"] = "Imbues: dagger", ["imbues:sword"] = "Imbues: sword",
    ["imbues:other"] = "Imbues" }

local window
local filter = "all"
local rows, headers = {}, {}

local function Protected(itemID) return SK.db.bagProtected and SK.db.bagProtected[itemID] or false end

------------------------------------------------------------------------
-- Doing things: one step at a time, a moment apart, so the game keeps up
------------------------------------------------------------------------

-- The same move tried again and again means the game isn't doing it:
-- stop instead of looping.
local lastTry, tries = nil, 0
local function Trying(key, itemID, where)
    if key == lastTry then tries = tries + 1 else lastTry, tries = key, 1 end
    if tries >= 3 then
        lastTry, tries = nil, 0
        local name = (itemID and C_Item and SK.Try(C_Item.GetItemNameByID, itemID)) or L["that scroll"]
        error(L["the game wouldn't move %s %s, so Scrollkeeper stopped."]:format(name, where), 0)
    end
end

-- After a split, wait until the part shows up in its new slot before the
-- next move: moving again too soon is what makes the game say "Couldn't
-- split those items" (the same as clicking items too fast yourself).
local landing
local function Landing()
    if not landing then return false end
    local info = SK.Try(C_Container.GetContainerItemInfo, landing.bag, landing.slot)
    if (type(info) == "table" and not info.isLocked) or GetTime() > landing.by then
        landing = nil
        return false
    end
    return true
end
local function Empty(bag, slot)
    return SK.Try(C_Container.GetContainerItemInfo, bag, slot) == nil
end
-- Really empty, and not the slot a split is still on its way to.
local function Open(bag, slot)
    if landing and landing.bag == bag and landing.slot == slot then return false end
    return Empty(bag, slot)
end
local function Land(bag, slot) landing = { bag = bag, slot = slot, by = GetTime() + 2 } end

-- The button shows it's working ("Syncing...") and then how it went for a
-- moment, so you can see on the panel when it finished.
local working = {}   -- button -> { run, showing }
local LABELS = {}    -- button key -> its label
local function Working(key, doing)
    local b = window and window.buttons and window.buttons[key]
    if not b then return function() end end
    local w = working[b]
    if not w then w = { run = 0 }; working[b] = w end
    b:Enable()
    b:SetText("|cffffff00" .. doing .. "|r")
    w.run, w.showing = w.run + 1, true
    local mine = w.run
    return function(text)
        b:SetText("|cff40ff40" .. (text or L["Done"]) .. "|r")
        C_Timer.After(2.5, function()
            if w.run == mine then
                w.showing = false
                b:SetText(LABELS[key] or "")
                SK.UpdateSyncButtons()
            end
        end)
    end
end

local busy
-- While Scrollkeeper moves scrolls, the game's red "Couldn't split those
-- items" / "That item is locked" messages (and their sound) are its own
-- business: hide them, then put them back. (A setting: bagHideErrors.)
local errorsHidden = false
local function HideErrors()
    if SK.db.bagHideErrors == false or errorsHidden then return end
    if UIErrorsFrame and UIErrorsFrame.IsEventRegistered and UIErrorsFrame:IsEventRegistered("UI_ERROR_MESSAGE") then
        UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
        errorsHidden = true
    end
end
local function ShowErrors()
    if not errorsHidden then return end
    errorsHidden = false
    -- A moment later, so a message for the last move is still hidden.
    C_Timer.After(0.5, function()
        if not errorsHidden and UIErrorsFrame then UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE") end
    end)
end

local function RunSteps(name, step, done, quiet)
    if busy then
        if quiet then return end
        SK.Print(L["one thing at a time: Scrollkeeper is still busy (%s)."]:format(busy))
        return
    end
    busy = name
    lastTry, tries, landing = nil, 0, nil
    HideErrors()
    local count, guard = 0, 0
    local function Finish()
        busy = nil
        ShowErrors()
        if done then done(count) end
    end
    local function Next()
        guard = guard + 1
        if guard > 200 or SK.InCombat() then Finish() return end
        local ok, did = pcall(step)
        if ok and did then
            -- "wait": the game is still moving something, try again shortly.
            if did ~= "wait" then count = count + 1 end
            C_Timer.After(0.35, Next)
        else
            if not ok then SK.Print("|cffff5555" .. tostring(did) .. "|r") end
            Finish()
        end
    end
    Next()
end

-- Only plain bags take scrolls: not the reagent bag or other special bags
-- (a split put there fails with "Couldn't split those items").
local function PlainBag(bag)
    local _, family = SK.Try(C_Container.GetContainerNumFreeSlots, bag)
    return family == nil or family == 0
end
SK.PlainBag = PlainBag
local function FreeSlot()
    for bag = 0, 5 do
        if PlainBag(bag) then
            local free = C_Container.GetContainerFreeSlots and SK.Try(C_Container.GetContainerFreeSlots, bag)
            if type(free) == "table" then
                for _, slot in ipairs(free) do
                    if Open(bag, slot) then return bag, slot end
                end
            end
        end
    end
    return nil
end

-- (SK.BankBags in Modules/Stash.lua: never the keyring.)
local BANK_BAGS = SK.BankBags()
local function Locked()
    if SK.BankIsOpen() then
        for _, bag in ipairs(BANK_BAGS) do
            for slot = 1, SK.Try(C_Container.GetContainerNumSlots, bag) or 0 do
                local info = SK.Try(C_Container.GetContainerItemInfo, bag, slot)
                if type(info) == "table" and info.isLocked then return true end
            end
        end
    end
    for bag = 0, 5 do
        for slot = 1, SK.Try(C_Container.GetContainerNumSlots, bag) or 0 do
            local info = SK.Try(C_Container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and info.isLocked then return true end
        end
    end
    return false
end

-- The next extra stack in your bags for an action: { bag, slot, count, take }
-- and its entry, or nil. skip(entry) leaves some kinds out.
local function NextExtra(skip)
    for _, e in ipairs((SK.StashList())) do
        if e.status == "extra" and e.bags > 0 and not Protected(e.itemID) and not (skip and skip(e)) then
            local stacks = SK.ExtraStacks(e.itemID, math.min(e.extra, e.bags))
            if stacks[1] then return stacks[1], e end
        end
    end
end

-- Merge part-stacks of the same scroll in your bags.
local function StackStep()
    if Locked() then return "wait" end
    local byID = {}
    for bag = 0, 5 do
        for slot = 1, SK.Try(C_Container.GetContainerNumSlots, bag) or 0 do
            local info = SK.Try(C_Container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and info.itemID and (SK.MAGE_SCROLL_IDS[info.itemID] or SK.SCROLL_FACTS[info.itemID]) then
                local max = (C_Item and SK.Try(C_Item.GetItemMaxStackSizeByID, info.itemID)) or 5
                if (info.stackCount or 1) < max then
                    byID[info.itemID] = byID[info.itemID] or {}
                    table.insert(byID[info.itemID], { bag = bag, slot = slot })
                end
            end
        end
    end
    for _, list in pairs(byID) do
        if #list >= 2 then
            local from, to = list[#list], list[1]
            ClearCursor()
            C_Container.PickupContainerItem(from.bag, from.slot)
            C_Container.PickupContainerItem(to.bag, to.slot)
            ClearCursor()
            return true
        end
    end
    return false
end

-- How many bag slots stacking would free.
local function StackSavings(entries)
    local saved = 0
    for _, e in ipairs(entries) do
        if e.bags > 0 then
            local max = (C_Item and SK.Try(C_Item.GetItemMaxStackSizeByID, e.itemID)) or 5
            local bagSlots = 0
            for bag = 0, 5 do
                for slot = 1, SK.Try(C_Container.GetContainerNumSlots, bag) or 0 do
                    local info = SK.Try(C_Container.GetContainerItemInfo, bag, slot)
                    if type(info) == "table" and info.itemID == e.itemID then bagSlots = bagSlots + 1 end
                end
            end
            saved = saved + math.max(0, bagSlots - math.ceil(e.bags / max))
        end
    end
    return saved
end

local function AtMerchant() return MerchantFrame and MerchantFrame:IsShown() end
local function AtMailbox() return SendMailFrame and SendMailFrame:IsShown() end

-- Sell: whole stacks are sold; a part-stack is split into an empty slot first.
local splitOff   -- the slot a part-stack was just split into: sold next
local function SellStep()
    if not AtMerchant() then splitOff = nil return false end
    if Locked() then return "wait" end
    if splitOff then
        local spot = splitOff
        splitOff = nil
        local info = SK.Try(C_Container.GetContainerItemInfo, spot.bag, spot.slot)
        if type(info) == "table" and info.itemID == spot.itemID then
            C_Container.UseContainerItem(spot.bag, spot.slot)
            return true
        end
    end
    local stack = NextExtra()
    if not stack then return false end
    if stack.take >= stack.count then
        C_Container.UseContainerItem(stack.bag, stack.slot)
        return true
    end
    local bag, slot = FreeSlot()
    if not bag then error(L["no empty bag slot to split a stack into. Make room for one."], 0) end
    ClearCursor()
    local info = SK.Try(C_Container.GetContainerItemInfo, stack.bag, stack.slot)
    C_Container.SplitContainerItem(stack.bag, stack.slot, stack.take)
    C_Container.PickupContainerItem(bag, slot)
    splitOff = { bag = bag, slot = slot, itemID = type(info) == "table" and info.itemID or nil }
    return true
end

-- Mail: bound scrolls can't be mailed. Splitting puts the part on your
-- cursor, which goes straight onto the mail.
local MAX_ATTACHMENTS = math.min(ATTACHMENTS_MAX_SEND or 7, 7)
local function FreeAttachment()
    for i = 1, MAX_ATTACHMENTS do
        local used = HasSendMailItem and HasSendMailItem(i)
        if not used then return i end
    end
end
local function MailStep()
    if not AtMailbox() then return false end
    if Locked() then return "wait" end
    local index = FreeAttachment()
    if not index then return false end
    local stack = NextExtra(function(e) return e.bound end)
    if not stack then return false end
    ClearCursor()
    if stack.take >= stack.count then
        C_Container.PickupContainerItem(stack.bag, stack.slot)
    else
        C_Container.SplitContainerItem(stack.bag, stack.slot, stack.take)
    end
    ClickSendMailItemButton(index)
    ClearCursor()
    return true
end

-- Deposit: set-aside imbues go into the bank (using an item with the bank
-- open moves it there).
local function DepositStep()
    if not SK.BankIsOpen() then return false end
    if Locked() then return "wait" end
    for bag = 0, 5 do
        for slot = 1, SK.Try(C_Container.GetContainerNumSlots, bag) or 0 do
            local info = SK.Try(C_Container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and info.itemID and not Protected(info.itemID) then
                local status = SK.StashSlotStatus(bag, slot, info.itemID)
                if status == "aside" then
                    C_Container.UseContainerItem(bag, slot)
                    return true
                end
            end
        end
    end
    return false
end

-- Bank: extras go into the bank. Whole stacks move with a click (using
-- an item with the bank open); for a part-stack, the part is split off
-- onto the cursor and put in an empty bank slot.
local function FreeBankSlot()
    for _, bag in ipairs(BANK_BAGS) do
        if PlainBag(bag) then
            local free = SK.Try(C_Container.GetContainerFreeSlots, bag)
            if type(free) == "table" then
                for _, slot in ipairs(free) do
                    if Open(bag, slot) then return bag, slot end
                end
            end
        end
    end
end
-- What to bank: what's in your bags over the keep amount. (Extra counts
-- your bank and mail too, so after banking a scroll would still be extra:
-- banking keeps the keep amount in your bags and banks the rest.)
local function BankAmount(e)
    if e.status ~= "extra" or e.bags <= 0 or Protected(e.itemID) then return 0 end
    local keep = SK.KeepAmount(e.itemID)
    if keep == nil then return 0 end
    return math.max(0, e.bags - keep)
end
local function NextToBank()
    for _, e in ipairs((SK.StashList())) do
        local n = BankAmount(e)
        if n > 0 then
            local stacks = SK.ExtraStacks(e.itemID, n)
            if stacks[1] then return stacks[1], e end
        end
    end
end
local function BankStep()
    if not SK.BankIsOpen() then return false end
    if Landing() or Locked() then return "wait" end
    local stack, e = NextToBank()
    if not stack then return false end
    Trying("in:" .. stack.bag .. ":" .. stack.slot .. ":" .. stack.count, e and e.itemID, L["into your bank"])
    local bag, slot = FreeBankSlot()
    if stack.take >= stack.count then
        C_Container.UseContainerItem(stack.bag, stack.slot)
        return true
    end
    if not bag then error(L["your bank is full."], 0) end
    ClearCursor()
    C_Container.SplitContainerItem(stack.bag, stack.slot, stack.take)
    C_Container.PickupContainerItem(bag, slot)
    ClearCursor()
    Land(bag, slot)
    return true
end

-- Taking out: the other way round. Raise a keep amount above what's in
-- your bags, and the difference comes out of your bank
-- (Sync bank extras) or your mail (Sync mail extras) into your bags.
-- "Keep all" means keep them wherever they are: nothing comes out for it.
local function Wanted(e)
    if e.status == "aside" then return 0 end
    local keep = SK.KeepAmount(e.itemID)
    if keep == nil then return 0 end
    return math.max(0, keep - e.bags)
end
local function AtInbox() return InboxFrame and InboxFrame:IsShown() end

-- The smallest unlocked stack of a scroll in your bank, or nil.
local function BankStackOf(itemID)
    local best
    for _, bag in ipairs(BANK_BAGS) do
        for slot = 1, SK.Try(C_Container.GetContainerNumSlots, bag) or 0 do
            local info = SK.Try(C_Container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and info.itemID == itemID and not info.isLocked then
                if not best or (info.stackCount or 1) < best.count then
                    best = { bag = bag, slot = slot, count = info.stackCount or 1 }
                end
            end
        end
    end
    return best
end

-- Is there anything for Sync bank extras to do right now?
local function BankNeedsSync()
    if not SK.BankIsOpen() then return true end   -- can't tell: let the click say "open your bank"
    if NextToBank() then return true end
    for _, e in ipairs((SK.StashList())) do
        if Wanted(e) > 0 and BankStackOf(e.itemID) then return true end
    end
    return false
end

-- And for Sync mail extras? (On the Send Mail tab: extras you can mail.)
local function MailNeedsSync()
    if SendMailFrame and SendMailFrame:IsShown() then
        return NextExtra(function(e) return e.bound end) ~= nil
    end
    if not AtInbox() then return true end
    if not (GetInboxNumItems and GetInboxItem) then return false end
    local byID = {}
    for _, e in ipairs((SK.StashList())) do byID[e.itemID] = e end
    for i = 1, GetInboxNumItems() or 0 do
        local cod = select(6, SK.Try(GetInboxHeaderInfo, i))
        if not (cod and cod > 0) then
            for a = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
                local _, itemID = SK.Try(GetInboxItem, i, a)
                local e = itemID and byID[itemID]
                if e and Wanted(e) > 0 then return true end
            end
        end
    end
    return false
end
local function TakeFromBankStep()
    if not SK.BankIsOpen() then return false end
    if Landing() or Locked() then return "wait" end
    local entries = SK.StashList()
    do
        for _, e in ipairs(entries) do
            local need = Wanted(e)
            if need > 0 and e.bank > 0 then
                local best = BankStackOf(e.itemID)
                if best then
                    Trying("out:" .. best.bag .. ":" .. best.slot .. ":" .. best.count, e.itemID, L["into your bags"])
                    local bag, slot = FreeSlot()
                    if best.count <= need then
                        if not bag then error(L["your bags are full."], 0) end
                        C_Container.UseContainerItem(best.bag, best.slot)
                    else
                        if not bag then error(L["your bags are full."], 0) end
                        ClearCursor()
                        C_Container.SplitContainerItem(best.bag, best.slot, need)
                        C_Container.PickupContainerItem(bag, slot)
                        ClearCursor()
                        Land(bag, slot)
                    end
                    return true
                end
            end
        end
    end
    return false
end

local function TakeFromMailStep()
    if not AtInbox() then return false end
    if Locked() then return "wait" end
    local entries = SK.StashList()
    if GetInboxNumItems and GetInboxItem and TakeInboxItem then
        local byID = {}
        for _, e in ipairs(entries) do byID[e.itemID] = e end
        local max = ATTACHMENTS_MAX_RECEIVE or 16
        for i = 1, GetInboxNumItems() do
            local cod = select(6, SK.Try(GetInboxHeaderInfo, i))
            if not (cod and cod > 0) then
                for a = 1, max do
                    local _, itemID = SK.Try(GetInboxItem, i, a)
                    local e = itemID and byID[itemID]
                    if e and Wanted(e) > 0 then
                        if not FreeSlot() then error(L["your bags are full."], 0) end
                        Trying("mail:" .. i .. ":" .. a, itemID, L["out of your mail"])
                        TakeInboxItem(i, a)
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Delete: only when you turned it on in the settings, and after asking.
local function DeleteStep()
    if Locked() then return "wait" end
    local stack = NextExtra()
    if not stack then return false end
    ClearCursor()
    if stack.take >= stack.count then
        C_Container.PickupContainerItem(stack.bag, stack.slot)
    else
        C_Container.SplitContainerItem(stack.bag, stack.slot, stack.take)
    end
    DeleteCursorItem()
    return true
end

-- What an action would do, as "3 Polymorph: Odd Melon, 6 Khadgar's Unlocking".
local function ExtrasText(skip)
    local parts, total = {}, 0
    for _, e in ipairs((SK.StashList())) do
        if e.status == "extra" and e.bags > 0 and not Protected(e.itemID) and not (skip and skip(e)) then
            local n = math.min(e.extra, e.bags)
            total = total + n
            parts[#parts + 1] = n .. " " .. e.name:gsub("^Scroll of ", "")
        end
    end
    return table.concat(parts, ", "), total
end

local function Finished(what)
    return function(count)
        if count > 0 then SK.Print(L["%s: done."]:format(what)) end
        SK.RefreshScrollBag()
    end
end

if StaticPopupDialogs then
    StaticPopupDialogs["SCROLLKEEPER_BAG_CONFIRM"] = {
        text = "%s", button1 = YES or "Yes", button2 = NO or "No",
        OnAccept = function(_, data) if data then data() end end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["SCROLLKEEPER_BAG_NAME"] = {
        text = "%s", button1 = OKAY or "Okay", button2 = CANCEL or "Cancel", hasEditBox = true,
        OnAccept = function(self, data) if data then data(self.editBox and self.editBox:GetText() or self.EditBox and self.EditBox:GetText()) end end,
        EditBoxOnEnterPressed = function(self) local parent = self:GetParent(); if parent.button1 then parent.button1:Click() end end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end

-- Start a new preset: ask for a name (a free one filled in), never over
-- an existing preset.
local function AskNewPreset()
    if not StaticPopup_Show then return end
    local dialog = StaticPopup_Show("SCROLLKEEPER_BAG_NAME", L["Name for the new preset:"], nil, function(name)
        local ok, why = SK.SaveBagPreset(name, true)
        if ok then SK.Print(L["saved the preset %s."]:format(name:gsub("^%s+", ""):gsub("%s+$", "")))
        elseif why then SK.Print(why) end
    end)
    local edit = dialog and (dialog.editBox or dialog.EditBox)
    if edit then
        edit:SetText(SK.NewBagPresetName())
        edit:HighlightText()
    end
end

local function Confirm(text, run)
    if SK.db.bagConfirm == false or not StaticPopup_Show then run() return end
    StaticPopup_Show("SCROLLKEEPER_BAG_CONFIRM", text, nil, run)
end

-- How many of each mage scroll are in your bags.
local function BagCounts()
    local counts = {}
    for bag = 0, 5 do
        for slot = 1, SK.Try(C_Container.GetContainerNumSlots, bag) or 0 do
            local info = SK.Try(C_Container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and info.itemID and (SK.MAGE_SCROLL_IDS[info.itemID] or SK.SCROLL_FACTS[info.itemID]) then
                counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    return counts
end
-- "2 Odd Melon into the bank, 3 Arcane Brilliance into your bags", and
-- whether anything changed at all.
local function ChangeText(before, after)
    local ids, seen = {}, {}
    for id in pairs(before) do if not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
    for id in pairs(after) do if not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
    table.sort(ids)
    local into, out = {}, {}
    for _, id in ipairs(ids) do
        local d = (after[id] or 0) - (before[id] or 0)
        if d ~= 0 then
            local name = ((C_Item and SK.Try(C_Item.GetItemNameByID, id)) or SK.MAGE_SCROLL_IDS[id] or ("item " .. id)):gsub("^Scroll of ", "")
            if d > 0 then out[#out + 1] = d .. " " .. name else into[#into + 1] = (-d) .. " " .. name end
        end
    end
    local parts = {}
    if into[1] then parts[#parts + 1] = L["into the bank: %s"]:format(table.concat(into, ", ")) end
    if out[1] then parts[#parts + 1] = L["into your bags: %s"]:format(table.concat(out, ", ")) end
    return table.concat(parts, "; "), parts[1] ~= nil
end

local ACTIONS = {
    stack = function()
        RunSteps(L["Stack"], StackStep, Finished(L["stacking"]))
    end,
    sell = function()
        if not AtMerchant() then SK.Print(L["talk to a vendor first, then click Sell extras."]) return end
        local text, n = ExtrasText()
        if n == 0 then SK.Print(L["no extras in your bags to sell."]) return end
        Confirm(L["Sell these extras to the vendor?\n\n%s"]:format(text), function() RunSteps(L["Sell extras"], SellStep, Finished(L["selling"])) end)
    end,
    mail = function()
        if not AtMailbox() then SK.Print(L["open the mailbox's Send Mail tab first, then click Mail extras."]) return end
        local text, n = ExtrasText(function(e) return e.bound end)
        if n == 0 then SK.Print(L["no extras you can mail (bound scrolls can't be mailed)."]) return end
        local to = SendMailNameEditBox and SendMailNameEditBox:GetText() or ""
        if to == "" and (SK.db.bagMailTo or "") ~= "" and SendMailNameEditBox then
            SendMailNameEditBox:SetText(SK.TidyMailName and SK.TidyMailName(SK.db.bagMailTo) or SK.db.bagMailTo)
        end
        if SendMailSubjectEditBox and (SendMailSubjectEditBox:GetText() or "") == "" then
            SendMailSubjectEditBox:SetText(L["Spare scrolls"])
        end
        RunSteps(L["Mail extras"], MailStep, function(count)
            if count > 0 then
                SK.Print(L["attached %d |4stack:stacks; of extras (%s). Check the name, then click Send."]:format(count, text))
            end
            SK.RefreshScrollBag()
        end)
    end,
    -- At the bank: extras in your bags go in, what your bags are missing
    -- (up to your keep amounts) comes out.
    -- auto: started by Auto-sync, so it only speaks up when it moved something.
    bank = function(auto)
        if SK.RemoteOff and SK.RemoteOff("Sync") then
            if not auto then SK.Print(L["Sync is switched off by the Scrollkeeper team for now, until it's fixed."]) end
            return
        end
        if not SK.BankIsOpen() then
            if not auto then SK.Print(L["open your bank first, then click Sync bank extras."]) end
            return
        end
        if busy then
            if not auto then SK.Print(L["one thing at a time: Scrollkeeper is still busy (%s)."]:format(busy)) end
            return
        end
        if not BankNeedsSync() then
            if not auto then SK.Print(L["bank already in sync with your keep amounts."]) end
            SK.UpdateSyncButtons()
            return
        end
        local finished = Working("bank", L["Syncing..."])
        local before = BagCounts()
        RunSteps(L["Sync bank extras"], function() return BankStep() or TakeFromBankStep() end, function()
            -- Say what really changed in your bags, once the game has caught up.
            C_Timer.After(0.6, function()
                local text, changed = ChangeText(before, BagCounts())
                if changed then
                    SK.Print((auto and L["auto-sync: %s."] or L["bank synced: %s."]):format(text))
                elseif not auto then
                    SK.Print(L["bank already in sync with your keep amounts."])
                end
                finished(changed and L["Synced"] or L["In sync"])
                SK.RefreshScrollBag()
            end)
        end, auto)
    end,
    -- At the mailbox (Inbox): what your bags are missing comes out of your mail.
    -- At the mailbox, both ways: on the Send Mail tab extras get attached
    -- (Mail extras), on the Inbox what your bags are missing comes out.
    mailsync = function(auto)
        if SK.RemoteOff and SK.RemoteOff("Sync") then
            if not auto then SK.Print(L["Sync is switched off by the Scrollkeeper team for now, until it's fixed."]) end
            return
        end
        if AtMailbox() and not auto then return SK.ScrollBagActions.mail() end
        if not AtInbox() then
            if not auto then SK.Print(L["open your mailbox first, then click Sync mail extras."]) end
            return
        end
        if busy then
            if not auto then SK.Print(L["one thing at a time: Scrollkeeper is still busy (%s)."]:format(busy)) end
            return
        end
        if not MailNeedsSync() then
            if not auto then SK.Print(L["nothing in your mail that your bags are missing."]) end
            SK.UpdateSyncButtons()
            return
        end
        local finished = Working("mailsync", L["Syncing..."])
        RunSteps(L["Sync mail extras"], TakeFromMailStep, function(count)
            finished(count > 0 and L["Synced"] or L["In sync"])
            if count > 0 then
                SK.Print((auto and L["auto-sync: took %d |4attachment:attachments; from your mail."]
                    or L["mail synced: took %d |4attachment:attachments;."]):format(count))
            elseif not auto then
                SK.Print(L["nothing in your mail that your bags are missing."])
            end
            SK.RefreshScrollBag()
        end, auto)
    end,
    deposit = function()
        if not SK.BankIsOpen() then SK.Print(L["open your bank first, then click Deposit set aside."]) return end
        RunSteps(L["Deposit set aside"], DepositStep, Finished(L["deposit"]))
    end,
    delete = function()
        local text, n = ExtrasText()
        if n == 0 then SK.Print(L["no extras in your bags."]) return end
        if StaticPopup_Show then
            StaticPopup_Show("SCROLLKEEPER_BAG_CONFIRM", L["Delete these extras for good? This can't be undone.\n\n%s"]:format(text), nil,
                function() RunSteps(L["Delete extras"], DeleteStep, Finished(L["deleting"])) end)
        end
    end,
}
SK.ScrollBagActions = ACTIONS   -- for the test harness

------------------------------------------------------------------------
-- Preset dropdown
------------------------------------------------------------------------

local function BuildPresetMenu(box)
    local list = CreateFrame("Frame", nil, box, "BackdropTemplate")
    list:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, 2)
    list:SetFrameStrata("DIALOG")
    list:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    list:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
    list:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
    SK.UI.SkinBox(list, "box")
    list:Hide()
    list.buttons = {}

    local function Option(i)
        local opt = list.buttons[i]
        if opt then return opt end
        opt = CreateFrame("Button", nil, list)
        opt:SetSize(270, 30)
        opt:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        opt.name = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        opt.name:SetPoint("TOPLEFT", 6, -2)
        opt.tip = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        opt.tip:SetPoint("TOPLEFT", opt.name, "BOTTOMLEFT", 0, -2)
        opt.tip:SetWidth(258)
        opt.tip:SetJustifyH("LEFT")
        opt.tip:SetWordWrap(false)
        list.buttons[i] = opt
        return opt
    end

    function list:Fill()
        local items = {}
        local current = SK.BagPreset()
        for _, preset in ipairs(SK.BAG_PRESETS) do
            items[#items + 1] = { name = L[preset.name], tip = L[preset.tip], key = preset.key }
        end
        for _, name in ipairs(SK.CustomPresetNames()) do
            items[#items + 1] = { name = name, tip = L["Your preset."], key = name }
        end
        items[#items + 1] = { action = true, name = "|cff40ff40" .. L["Save as new preset..."] .. "|r",
            tip = L["Keep amounts as they are now, under a name."], run = AskNewPreset }
        if SK.IsCustomPreset(current) then
            if SK.BagPresetChanged() then
                items[#items + 1] = { action = true, name = "|cff40ff40" .. L["Save changes to %s"]:format(current) .. "|r",
                    tip = L["Your changed numbers become this preset's."], run = function() SK.SaveBagPreset(current) end }
            end
            items[#items + 1] = { action = true, name = L["Rename %s..."]:format(current), tip = "", run = function()
                StaticPopup_Show("SCROLLKEEPER_BAG_NAME", L["New name for %s:"]:format(current), nil, function(name)
                    local ok, why = SK.RenameBagPreset(current, name)
                    if not ok and why then SK.Print(why) end
                end)
            end }
            items[#items + 1] = { action = true, name = "|cffff6666" .. L["Delete %s"]:format(current) .. "|r", tip = "", run = function()
                StaticPopup_Show("SCROLLKEEPER_BAG_CONFIRM", L["Delete the preset %s?"]:format(current), nil,
                    function() SK.DeleteBagPreset(current) end)
            end }
        end
        if SK.BagPresetChanged() then
            items[#items + 1] = { action = true, name = L["Undo my changes"], tip = L["Back to the preset's own numbers."],
                run = function() SK.UseBagPreset(current) end }
        end
        for i, item in ipairs(items) do
            local opt = Option(i)
            opt:SetPoint("TOPLEFT", 5, -5 - (i - 1) * 32)
            opt.name:SetText((item.key == current and "|TInterface\\Buttons\\UI-CheckBox-Check:14:14|t " or "") .. item.name)
            opt.tip:SetText(item.tip)
            opt:SetScript("OnClick", function()
                list:Hide()
                if item.run then item.run() else SK.UseBagPreset(item.key) end
            end)
            opt:Show()
        end
        for i = #items + 1, #list.buttons do list.buttons[i]:Hide() end
        list:SetSize(280, #items * 32 + 10)
    end
    return list
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------

local function Chip(parent, key)
    local chip = CreateFrame("Button", nil, parent, "BackdropTemplate")
    chip:SetHeight(18)
    chip:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    chip.text = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chip.text:SetPoint("CENTER")
    chip:SetScript("OnClick", function()
        SK.Track("bag.filter." .. tostring(key))
        filter = key
        window.list.scroll:SetVerticalScroll(0)
        SK.RefreshScrollBag()
    end)
    return chip
end

local function SmallButton(parent, text, width, onClick, tip)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    if b.GetFontString and b:GetFontString() then b:GetFontString():SetFontObject("GameFontNormalSmall") end
    b:SetScript("OnClick", onClick)
    if tip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(text)
            GameTooltip:AddLine(type(tip) == "function" and tip() or tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return b
end

local function Build()
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperBagFrame", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperBagFrame", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if self.TitleText then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(WIDTH, 624)
    window:SetPoint("CENTER", -100, 0)
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetTitle(L["Scrollkeeper: Scroll Bag"])
    if window.SetPortraitToAsset then window:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Bag_10") end
    tinsert(UISpecialFrames, "ScrollkeeperBagFrame")

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    SK.UI.Background(background)
    SK.UI.AddHelp(window, "bag")

    -- Preset
    local label = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 64, -34)
    label:SetText(L["Preset:"])
    local box = CreateFrame("Button", nil, window, "BackdropTemplate")
    box:SetSize(210, 22)
    box:SetPoint("LEFT", label, "RIGHT", 8, 0)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    box:SetBackdropColor(0, 0, 0, 0.8)
    box:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
    SK.UI.SkinBox(box, "box")
    box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.text:SetPoint("LEFT", 8, 0)
    box.text:SetPoint("RIGHT", -22, 0)
    box.text:SetJustifyH("LEFT")
    box.text:SetWordWrap(false)
    local arrow = box:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(16, 16)
    arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    box:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    box.menu = BuildPresetMenu(box)
    box:SetScript("OnClick", function() SK.Track("bag.presetmenu") box.menu:Fill(); box.menu:SetShown(not box.menu:IsShown()) end)
    window.preset = box

    -- Save as a new preset, right next to the dropdown.
    local save = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    save:SetSize(110, 22)
    save:SetPoint("LEFT", box, "RIGHT", 8, 0)
    save:SetText(L["New preset"])
    save:SetScript("OnClick", function()
        SK.Track("bag.presetsave")
        box.menu:Hide()
        AskNewPreset()
    end)
    save:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["New preset"])
        GameTooltip:AddLine(L["Saves the keep amounts as they are now as a new preset of your own. Never changes an existing one."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    save:SetScript("OnLeave", function() GameTooltip:Hide() end)
    window.savePreset = save


    -- Its settings, in the settings window.
    local gear = CreateFrame("Button", nil, window)
    gear:SetSize(18, 18)
    gear:SetPoint("TOPRIGHT", -12, -32)
    gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    gear:SetScript("OnClick", function() SK.OpenOptions("Scroll Bag") end)
    gear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Scroll Bag settings"])
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function() GameTooltip:Hide() end)

    window.counting = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.counting:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -10)

    -- Filters, and a key for the location bars
    window.chips = {}
    local previous
    for _, key in ipairs({ "all", "extra", "aside", "bound" }) do
        local chip = Chip(window, key)
        if previous then chip:SetPoint("LEFT", previous, "RIGHT", 8, 0) else chip:SetPoint("TOPLEFT", 16, -86) end
        window.chips[key] = chip
        previous = chip
    end
    -- Column headings over the list: Bags / Bank / Mail / Keep / Status / All.
    local headings = {
        { L["Bags"], 16 + COLUMN_X.bags, 32, WHERE_COLORS.bags },
        { L["Bank"], 16 + COLUMN_X.bank, 32, WHERE_COLORS.bank },
        { L["Mail"], 16 + COLUMN_X.mail, 32, WHERE_COLORS.mail },
        { L["Keep"], 16 + 372, 54 },
        { L["Status"], 16 + 436, 60 },
        { L["All"], 16 + 494, 26 },
    }
    for _, h in ipairs(headings) do
        local fs = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", h[2], -114)
        fs:SetWidth(h[3])
        fs:SetJustifyH(h[1] == L["Status"] and "LEFT" or "CENTER")
        if h[4] then fs:SetTextColor(h[4][1], h[4][2], h[4][3]) end
        fs:SetText(h[1])
    end
    window.key = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")

    -- The list
    local scroll = CreateFrame("ScrollFrame", "ScrollkeeperBagList", window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -128)
    scroll:SetSize(INNER - 22, LIST_HEIGHT)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(INNER - 22, LIST_HEIGHT)
    scroll:SetScrollChild(content)
    window.list = { scroll = scroll, content = content }

    -- Totals and buttons
    window.totals = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    window.totals:SetPoint("BOTTOMLEFT", 18, 62)
    window.totals:SetPoint("RIGHT", window, "RIGHT", -18, 0)
    window.totals:SetJustifyH("LEFT")

    local mailLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mailLabel:SetPoint("BOTTOMLEFT", 18, 42)
    mailLabel:SetText(L["Mail extras to:"])
    local mailTo = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    mailTo:SetSize(190, 18)
    mailTo:SetPoint("LEFT", mailLabel, "RIGHT", 10, 0)
    mailTo:SetAutoFocus(false)
    -- Forever names are a first name and a surname ("Test Sheep"): keep the
    -- one space between them, drop extra spaces around and between.
    local function TidyName(text)
        return ((text or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " "))
    end
    SK.TidyMailName = TidyName
    mailTo:SetScript("OnEditFocusLost", function(self)
        SK.db.bagMailTo = TidyName(self:GetText())
        self:SetText(SK.db.bagMailTo)
    end)
    mailTo:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    mailTo:SetScript("OnEscapePressed", function(self) self:SetText(SK.db.bagMailTo or ""); self:ClearFocus() end)
    mailTo:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Mail extras to"])
        GameTooltip:AddLine(L["Your bank alt, or anyone, by first name and surname (\"Test Sheep\"). Used when the mail's To box is empty, so you can still click a name in the mailbox's list instead."], 1, 1, 1, true)
        GameTooltip:AddLine(L["The arrow lists your mages you can mail."], 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    mailTo:SetScript("OnLeave", function() GameTooltip:Hide() end)
    window.mailTo = mailTo

    -- Your mages you can mail (same faction and server), by full name.
    local pick = CreateFrame("Button", nil, window)
    pick:SetSize(18, 18)
    pick:SetPoint("LEFT", mailTo, "RIGHT", 2, 0)
    pick:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    pick:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    pick:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local picks = CreateFrame("Frame", nil, pick, "BackdropTemplate")
    picks:SetPoint("BOTTOMLEFT", mailTo, "TOPLEFT", -6, 2)
    picks:SetFrameStrata("DIALOG")
    picks:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    picks:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
    picks:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
    SK.UI.SkinBox(picks, "box")
    picks:Hide()
    picks.rows = {}
    function picks:Fill()
        local names = {}
        for _, mage in ipairs(SK.MailableMages and SK.MailableMages() or {}) do
            names[#names + 1] = TidyName((mage.name or ""):gsub("%-.*$", ""))
        end
        if #names == 0 then names[1] = false end
        for i, name in ipairs(names) do
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Button", nil, self)
                row:SetSize(170, 18)
                row:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 18)
                row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", 4, 0)
                self.rows[i] = row
            end
            row.text:SetText(name or ("|cff999999" .. L["(no other mages you can mail yet)"] .. "|r"))
            row:SetScript("OnClick", function()
                if name then
                    SK.Track("bag.mailtopick")
                    SK.db.bagMailTo = name
                    mailTo:SetText(name)
                end
                picks:Hide()
            end)
            row:Show()
        end
        for i = #names + 1, #self.rows do self.rows[i]:Hide() end
        self:SetSize(182, 12 + #names * 18)
    end
    pick:SetScript("OnClick", function() picks:Fill(); picks:SetShown(not picks:IsShown()) end)
    window.mailPick = picks

    window.buttons = {}
    local specs = {
        { "stack", L["Stack"], 60, L["Merge part-stacks of the same scroll in your bags."] },
        { "sell", L["Sell extras"], 82, L["At a vendor: sells the extras in your bags. Protected scrolls (right-click a row) are never sold."] },
        { "bank", L["Sync bank extras"], 104, L["At the bank: your bags end up with your keep amount of each scroll. Extras go into the bank, and what's missing comes out of it. Protected scrolls stay."] },
        { "mailsync", L["Sync mail extras"], 104, L["At the mailbox. On the Send Mail tab: attaches the extras you can mail (not bound ones) to your Mail extras to name. On the Inbox: takes what your bags are missing (up to your keep amounts) out of your mail, skipping cash-on-delivery mail."] },
        { "deposit", L["Deposit set aside"], 112, L["At the bank: puts set-aside imbues (for weapons you don't have) in the bank."] },
    }
    -- Delete extras (only when turned on in the settings) sits up by the presets.
    local delete = SmallButton(window, L["Delete extras"], 90, function() ACTIONS.delete() end,
        L["Deletes the extras in your bags, after asking. Turn this button on in /sk options."])
    delete:SetPoint("LEFT", window.savePreset, "RIGHT", 8, 0)
    local last
    for _, spec in ipairs(specs) do
        local b = SmallButton(window, spec[2], spec[3], function() ACTIONS[spec[1]]() end, spec[4])
        if last then b:SetPoint("LEFT", last, "RIGHT", 8, 0) else b:SetPoint("BOTTOMLEFT", 16, 12) end
        window.buttons[spec[1]] = b
        LABELS[spec[1]] = spec[2]
        last = b
    end
    window.buttons.delete = delete

    -- Auto-sync at the bank, right here (also in /sk options).
    local auto = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    auto:SetSize(22, 22)
    auto:SetPoint("BOTTOMRIGHT", -150, 36)
    local autoText = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoText:SetPoint("LEFT", auto, "RIGHT", 1, 0)
    autoText:SetText(L["Auto-sync at the bank"])
    auto:SetScript("OnClick", function(self)
        SK.db.bagAutoSyncBank = self:GetChecked() and true or false
        if SK.db.bagAutoSyncBank and SK.BankIsOpen() then ACTIONS.bank(true) end
    end)
    auto:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Auto-sync at the bank"], 1, 1, 1)
        GameTooltip:AddLine(L["When you open your bank, Sync bank extras runs on its own, so your bags end up with your keep amounts."], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    auto:SetScript("OnLeave", function() GameTooltip:Hide() end)
    window.autoSync = auto

    window:SetScript("OnShow", function()
        mailTo:SetText(SK.db.bagMailTo or "")
        auto:SetChecked(SK.db.bagAutoSyncBank and true or false)
        SK.RefreshScrollBag()
    end)
    window:SetScript("OnHide", function() box.menu:Hide(); picks:Hide() end)
    window:Hide()
end

------------------------------------------------------------------------
-- Rows
------------------------------------------------------------------------

local function Header(i)
    local h = headers[i]
    if h then return h end
    local content = window.list.content
    h = CreateFrame("Frame", nil, content)
    h:SetSize(INNER - 22, ROW)
    local bg = h:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    SK.UI.HeaderBg(bg)
    h.label = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.label:SetPoint("LEFT", 8, 0)
    h.right = h:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    h.right:SetPoint("RIGHT", -8, 0)
    headers[i] = h
    return h
end

------------------------------------------------------------------------
-- A row's right-click menu
------------------------------------------------------------------------

local rowMenu
local function RowMenu()
    if rowMenu then return rowMenu end
    rowMenu = CreateFrame("Frame", "ScrollkeeperBagRowMenu", UIParent, "BackdropTemplate")
    rowMenu:SetFrameStrata("DIALOG")
    rowMenu:SetClampedToScreen(true)
    rowMenu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    rowMenu:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
    SK.UI.SkinBox(rowMenu, "box")
    rowMenu:EnableMouse(true)
    rowMenu.title = rowMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rowMenu.title:SetPoint("TOPLEFT", 10, -8)
    rowMenu.title:SetPoint("RIGHT", -10, 0)
    rowMenu.title:SetJustifyH("LEFT")
    rowMenu.title:SetWordWrap(false)
    rowMenu.options = {}
    rowMenu:Hide()
    tinsert(UISpecialFrames, "ScrollkeeperBagRowMenu")
    -- Closes when the Scroll Bag does, or when you click elsewhere.
    rowMenu:SetScript("OnUpdate", function(self)
        if not (window and window:IsShown()) then self:Hide() return end
        if IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
            and not self:IsMouseOver() and self.openedAt and GetTime() - self.openedAt > 0.2 then
            self:Hide()
        end
    end)
    return rowMenu
end

local function MenuOption(menu, i)
    local opt = menu.options[i]
    if opt then return opt end
    opt = CreateFrame("Button", nil, menu)
    opt:SetHeight(18)
    opt:SetPoint("LEFT", 6, 0)
    opt:SetPoint("RIGHT", -6, 0)
    opt:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    opt.check = opt:CreateTexture(nil, "OVERLAY")
    opt.check:SetSize(14, 14)
    opt.check:SetPoint("LEFT", 2, 0)
    opt.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    opt.text = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    opt.text:SetPoint("LEFT", 20, 0)
    opt.text:SetPoint("RIGHT", -4, 0)
    opt.text:SetJustifyH("LEFT")
    menu.options[i] = opt
    return opt
end

local function AskKeepNumber(e)
    if not StaticPopup_Show then return end
    local dialog = StaticPopup_Show("SCROLLKEEPER_BAG_NAME", L["How many %s to keep?"]:format(e.name or "?"), nil, function(text)
        local n = tonumber((text or ""):match("%d+"))
        if n then SK.SetKeepAmount(e.itemID, n) end
    end)
    local edit = dialog and (dialog.editBox or dialog.EditBox)
    if edit then
        local keep = SK.KeepAmount(e.itemID)
        edit:SetText(tostring(keep or e.total or 0))
        edit:HighlightText()
    end
end

function SK.ShowBagRowMenu(row)
    local e = row and row.entry
    if not e then return end
    local menu = RowMenu()
    local keep = SK.KeepAmount(e.itemID)
    local items = {
        { text = L["Keep all"], checked = keep == nil, run = function() SK.SetKeepAmount(e.itemID, nil) end },
        { text = keep and L["Keep %d (change...)"]:format(keep) or L["Keep a number..."], checked = keep ~= nil,
            run = function() AskKeepNumber(e) end },
    }
    if SK.KeepChanged and SK.KeepChanged(e.itemID) then
        items[#items + 1] = { text = L["Back to the preset's amount"], run = function() SK.ResetKeepAmount(e.itemID) end }
    end
    items[#items + 1] = { gap = true }
    items[#items + 1] = { text = L["Protect (never sold, mailed or deleted)"], checked = Protected(e.itemID), run = function()
        SK.Track("bag.protect")
        SK.db.bagProtected = SK.db.bagProtected or {}
        SK.db.bagProtected[e.itemID] = not SK.db.bagProtected[e.itemID] or nil
        SK.RefreshScrollBag()
    end }
    if row.pin and row.pin:IsShown() then
        items[#items + 1] = { text = L["Pin (the buttons and pop-up use it)"], checked = SK.IsPinned(e.itemID), run = function()
            SK.TogglePin(e.itemID)
        end }
    end
    if e.weapon then
        local noAside = SK.db.bagNoAside and SK.db.bagNoAside[e.itemID]
        items[#items + 1] = { text = L["Don't set aside (keep it even with no %s)"]:format(L[e.weapon] or e.weapon), checked = noAside and true or false,
            run = function()
                SK.Track("bag.noaside")
                SK.db.bagNoAside = SK.db.bagNoAside or {}
                SK.db.bagNoAside[e.itemID] = not SK.db.bagNoAside[e.itemID] or nil
                SK.Send("STASH_CHANGED")
            end }
    end
    items[#items + 1] = { gap = true }
    items[#items + 1] = { text = L["Link in chat"], run = function()
        local link = C_Item and select(2, SK.Try(C_Item.GetItemInfo, e.itemID))
        if link and ChatEdit_InsertLink then
            if ChatFrame_OpenChat and not (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()) then ChatFrame_OpenChat("") end
            ChatEdit_InsertLink(link)
        end
    end }

    menu.title:SetText(e.name or "")
    local y, n = -28, 0
    for _, item in ipairs(items) do
        if item.gap then
            y = y - 6
        else
            n = n + 1
            local opt = MenuOption(menu, n)
            opt:ClearAllPoints()
            opt:SetPoint("TOPLEFT", 6, y)
            opt:SetPoint("RIGHT", -6, 0)
            opt.text:SetText(item.text)
            opt.check:SetShown(item.checked and true or false)
            opt:SetScript("OnClick", function()
                menu:Hide()
                SK.Quietly("bag row menu", item.run)
            end)
            opt:Show()
            y = y - 18
        end
    end
    for i = n + 1, #menu.options do menu.options[i]:Hide() end
    menu:SetSize(270, -y + 8)
    local scale = UIParent:GetEffectiveScale() or 1
    local x, cy = GetCursorPosition()
    x, cy = tonumber(x) or 0, tonumber(cy) or 0
    if scale == 0 then scale = 1 end
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale - 6, cy / scale + 6)
    menu.openedAt = GetTime()
    menu:Show()
end

local function Row(i)
    local r = rows[i]
    if r then return r end
    local content = window.list.content
    r = CreateFrame("Button", nil, content)
    r:SetSize(INNER - 22, ROW)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.stripe = r:CreateTexture(nil, "BACKGROUND")
    r.stripe:SetAllPoints()
    r:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")

    r.border = r:CreateTexture(nil, "BORDER")
    r.border:SetSize(20, 20)
    r.border:SetPoint("LEFT", 3, 0)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16)
    r.icon:SetPoint("CENTER", r.border)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.name:SetPoint("LEFT", r.border, "RIGHT", 6, 0)
    r.name:SetWidth(196)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)

    -- Pin star (familiars and imbues).
    r.pin = CreateFrame("Button", nil, r)
    r.pin:SetSize(14, 14)
    r.pin:SetPoint("LEFT", r, "LEFT", 236, 0)
    r.pin.tex = r.pin:CreateTexture(nil, "OVERLAY")
    r.pin.tex:SetAllPoints()
    r.pin.tex:SetTexture("Interface\\COMMON\\FavoritesIcon")
    r.pin:SetScript("OnClick", function(self) if self.itemID then SK.TogglePin(self.itemID) end end)
    r.pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(SK.IsPinned(self.itemID) and L["Pinned"] or L["Pin it"])
        GameTooltip:AddLine(L["The Familiar and Imbue buttons, key bindings and pop-ups use your pinned scroll. Imbues get one pin per weapon kind."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    r.pin:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Where they are: how many in your bags, bank and mail, a column each
    -- (under the Bags / Bank / Mail headings).
    r.where = {}
    for i, where in ipairs(WHERE) do
        local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", r, "LEFT", COLUMN_X[where], 0)
        fs:SetWidth(32)
        fs:SetJustifyH("CENTER")
        r.where[where] = fs
    end

    -- Keep: - n +
    r.minus = CreateFrame("Button", nil, r)
    r.minus:SetSize(14, 14)
    r.minus:SetPoint("LEFT", r, "LEFT", 372, 0)
    r.minus:SetNormalFontObject("GameFontNormal")
    r.minus:SetText("-")
    r.keep = CreateFrame("Button", nil, r)
    r.keep:SetSize(26, 14)
    r.keep:SetPoint("LEFT", r.minus, "RIGHT", 0, 0)
    r.keep:SetNormalFontObject("GameFontHighlightSmall")
    r.plus = CreateFrame("Button", nil, r)
    r.plus:SetSize(14, 14)
    r.plus:SetPoint("LEFT", r.keep, "RIGHT", 0, 0)
    r.plus:SetNormalFontObject("GameFontNormal")
    r.plus:SetText("+")
    local function Step(delta)
        local id = r.itemID
        if not id then return end
        local keep = SK.KeepAmount(id)
        if keep == nil then keep = r.total or 0 end
        SK.SetKeepAmount(id, math.max(0, keep + delta))
    end
    r.minus:SetScript("OnClick", function() Step(IsShiftKeyDown() and -5 or -1) end)
    r.plus:SetScript("OnClick", function() Step(IsShiftKeyDown() and 5 or 1) end)
    r.keep:SetScript("OnClick", function()
        local id = r.itemID
        if not id then return end
        if SK.KeepAmount(id) == nil then SK.SetKeepAmount(id, r.total or 0) else SK.SetKeepAmount(id, nil) end
    end)
    for _, b in ipairs({ r.minus, r.keep, r.plus }) do
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["Keep amount"])
            GameTooltip:AddLine(L["How many to keep. More than this is extra.\n- and +: one less or more (Shift: 5).\nClick the number: keep all, or back to a number."], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    r.status = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.status:SetPoint("LEFT", r, "LEFT", 436, 0)
    r.status:SetWidth(60)
    r.status:SetJustifyH("LEFT")
    r.status:SetWordWrap(false)
    -- How many you have, in its own column on the right (never under the status).
    r.count = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.count:SetPoint("RIGHT", -6, 0)
    r.count:SetWidth(24)
    r.count:SetJustifyH("RIGHT")

    r:SetScript("OnEnter", function(self)
        local e = self.entry
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then GameTooltip:SetItemByID(e.itemID) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(L["Bags"], e.bags, 0.83, 0.65, 0.16, 1, 1, 1)
        if SK.db.bagCountBank ~= false then GameTooltip:AddDoubleLine(L["Bank"], e.bank, 0.35, 0.56, 0.83, 1, 1, 1) end
        if SK.db.bagCountMail ~= false then GameTooltip:AddDoubleLine(L["Mail"], e.mail, 0.69, 0.42, 0.83, 1, 1, 1) end
        GameTooltip:AddLine(SK.StashNote(e.itemID) or "", 1, 1, 1)
        if e.bound then GameTooltip:AddLine(L["Bound: can be sold to a vendor or deleted, not mailed or auctioned."], 0.7, 0.7, 0.7, true) end
        if Protected(e.itemID) then GameTooltip:AddLine(L["Protected: never sold, mailed or deleted."], 1, 0.82, 0, true) end
        GameTooltip:AddLine(L["Right-click: keep, protect, pin and more. Shift-click: link it."], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self, button)
        local e = self.entry
        if not e then return end
        if button == "RightButton" then
            SK.Track("bag.rowmenu")
            SK.ShowBagRowMenu(self)
        elseif IsModifiedClick and IsModifiedClick("CHATLINK") then
            local link = C_Item and select(2, SK.Try(C_Item.GetItemInfo, e.itemID))
            if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
        end
    end)
    rows[i] = r
    return r
end

local function FillRow(r, e, striped)
    r.entry, r.itemID, r.total = e, e.itemID, e.total
    SK.UI.Stripe(r.stripe, striped)
    local c = COLORS[e.status] or COLORS.keep
    r.border:SetColorTexture(c[1], c[2], c[3], 1)
    r.icon:SetTexture((C_Item and SK.Try(C_Item.GetItemIconByID, e.itemID)) or "Interface\\Icons\\INV_Scroll_03")
    local name = e.name:gsub("^Scroll of ", "")
    local marks = ""
    if e.bound then marks = marks .. " |TInterface\\PetBattles\\PetBattle-LockIcon:12:12|t" end
    if Protected(e.itemID) then marks = marks .. " |TInterface\\Common\\Indicator-Yellow:12:12|t" end
    r.name:SetText(name .. marks)
    local pinnable = e.category == "familiars" or (e.category == "imbues" and e.weapon)
    r.pin.itemID = e.itemID
    r.pin:SetShown(pinnable and true or false)
    r.pin.tex:SetDesaturated(not e.pinned)
    r.pin.tex:SetAlpha(e.pinned and 1 or 0.35)
    -- Bags / Bank / Mail counts ("-" for none)
    for _, where in ipairs(WHERE) do
        local n = e[where] or 0
        local c = WHERE_COLORS[where]
        r.where[where]:SetText(n > 0 and tostring(n) or "|cff505050-|r")
        r.where[where]:SetTextColor(c[1], c[2], c[3])
    end
    r.keep:SetText(e.keep == nil and L["all"] or tostring(e.keep))
    if e.status == "aside" then
        r.status:SetText("|cff66bbff" .. L["Set aside"] .. "|r")
    elseif e.status == "extra" then
        r.status:SetText("|cffff6666" .. L["%d extra"]:format(e.extra) .. "|r")
    else
        r.status:SetText("|cff40ff40" .. L["Keep"] .. "|r")
    end
    r.count:SetText(e.total)
end

------------------------------------------------------------------------
-- Filling it in
------------------------------------------------------------------------

local function GroupKey(e)
    if e.category == "imbues" then
        local kind = e.weapon
        if kind == "staff" or kind == "dagger" or kind == "sword" then return "imbues:" .. kind end
        return "imbues:other"
    end
    return e.category
end

function SK.RefreshScrollBag()
    if not (window and window:IsShown()) then return end
    local entries, owned = SK.StashList()
    local s = SK.StashState()
    SK.Quietly("sync buttons", SK.UpdateSyncButtons)

    -- Preset box
    local presetName = SK.BagPresetName()
    window.preset.text:SetText(presetName .. (SK.BagPresetChanged() and (" |cff808080" .. L["(changed)"] .. "|r") or ""))

    -- What's counted
    local function Ago(at) return at and SK.TimeAgo(at) or nil end
    local parts = { "|cff40ff40" .. L["Bags"] .. "|r" }
    if SK.db.bagCountBank ~= false then
        parts[#parts + 1] = s.bankAt and ("|cff40ff40" .. L["Bank"] .. "|r |cff808080(" .. Ago(s.bankAt) .. ")|r")
            or ("|cff808080" .. L["Bank (visit it once)"] .. "|r")
    end
    if SK.db.bagCountMail ~= false then
        parts[#parts + 1] = s.mailAt and ("|cff40ff40" .. L["Mail"] .. "|r |cff808080(" .. Ago(s.mailAt) .. ")|r")
            or ("|cff808080" .. L["Mail (open your mailbox once)"] .. "|r")
    end
    window.counting:SetText(L["Counting: "] .. table.concat(parts, " · "))

    -- Filter counts
    local counts = { all = #entries, extra = 0, aside = 0, bound = 0 }
    for _, e in ipairs(entries) do
        if e.status == "extra" then counts.extra = counts.extra + 1 end
        if e.status == "aside" then counts.aside = counts.aside + 1 end
        if e.bound then counts.bound = counts.bound + 1 end
    end
    local chipNames = { all = L["All"], extra = L["Extra"], aside = L["Set aside"], bound = L["Bound"] }
    for key, chip in pairs(window.chips) do
        chip.text:SetText(chipNames[key] .. " " .. counts[key])
        chip:SetWidth((chip.text:GetStringWidth() or 40) + 18)
        local on = key == filter
        chip:SetBackdropColor(on and 0.23 or 0, on and 0.16 or 0, on and 0.07 or 0, on and 1 or 0.4)
        chip:SetBackdropBorderColor(on and 0.66 or 0.42, on and 0.54 or 0.33, on and 0.23 or 0.15, 1)
        chip.text:SetTextColor(on and 1 or 0.79, on and 0.82 or 0.7, on and 0 or 0.48)
    end

    -- Groups
    local groups = {}
    for _, e in ipairs(entries) do
        local show = filter == "all" or (filter == "bound" and e.bound) or e.status == filter
        if show then
            local key = GroupKey(e)
            groups[key] = groups[key] or {}
            table.insert(groups[key], e)
        end
    end
    local y, nr, nh, striped = 0, 0, 0, false
    for _, key in ipairs(GROUP_ORDER) do
        local list = groups[key]
        if list then
            nh = nh + 1
            local h = Header(nh)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -y)
            local total = 0
            for _, e in ipairs(list) do total = total + e.total end
            local label = L[GROUP_LABELS[key]]
            local kind = key:match("^imbues:(%a+)$")
            local right = L["%d |4kind:kinds; · %d"]:format(#list, total)
            if kind and kind ~= "other" and not owned[kind] then right = "|cff66bbff" .. L["no %s owned"]:format(L[kind]) .. "|r" end
            h.label:SetText(label)
            h.right:SetText(right)
            h:Show()
            y = y + ROW + 2
            for _, e in ipairs(list) do
                nr = nr + 1
                striped = not striped
                local r = Row(nr)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -y)
                FillRow(r, e, striped)
                r:Show()
                y = y + ROW
            end
            y = y + 4
        end
    end
    for i = nh + 1, #headers do headers[i]:Hide() end
    for i = nr + 1, #rows do rows[i]:Hide() end
    local empty = rawget(window, "emptyText")
    if not empty then
        empty = window.list.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        empty:SetPoint("TOPLEFT", 6, -6)
        empty:SetWidth(INNER - 40)
        empty:SetJustifyH("LEFT")
        window.emptyText = empty
    end
    empty:SetText(nr == 0 and (filter == "all" and L["No deciphered scrolls yet. Decipher some, and they show up here."]
        or L["Nothing here right now."]) or "")
    window.list.content:SetHeight(math.max(LIST_HEIGHT, y))
    local bar = window.list.scroll.ScrollBar
    if type(bar) == "table" then bar:SetShown(y > LIST_HEIGHT) end
    if y <= LIST_HEIGHT then window.list.scroll:SetVerticalScroll(0) end

    -- Totals
    local slots, extra, aside = 0, 0, 0
    for _, e in ipairs(entries) do
        slots = slots + e.slots
        extra = extra + e.extra
        if e.status == "aside" then aside = aside + e.total end
    end
    local saved = StackSavings(entries)
    local text = L["%d slots"]:format(slots) .. "  ·  |cffff6666" .. L["%d extra"]:format(extra) .. "|r  ·  |cff66bbff"
        .. L["%d set aside"]:format(aside) .. "|r"
    if saved > 0 then text = text .. "  ·  " .. L["stacking frees %d |4slot:slots;"]:format(saved) end
    window.totals:SetText(text)

    window.buttons.delete:SetShown(SK.db.bagAllowDelete and true or false)
    window.buttons.deposit:SetShown(SK.db.bagSetAside ~= false)
end

function SK.ToggleScrollBag()
    if not SK.ModuleOn("Bag") then
        SK.Print(L["%s is turned off. Turn it on in /sk options (Modules)."]:format(L["Scroll Bag"]))
        return
    end
    if not window then Build() end
    window:SetShown(not window:IsShown())
end

-- Sync automatically (a setting): at the bank, and once the mail has come in.
local function AutoSync(action, key)
    if SK.db[key] and SK.ModuleOn("Bag") and SK.isMage and not SK.InCombat() then
        C_Timer.After(0.8, function() SK.Quietly("auto sync", ACTIONS[action], true) end)
    end
end
-- With the bank open, changing a keep amount (or the preset) syncs again,
-- a moment after your last click, so +/- clicks don't each start a sync.
local keepTimer = 0
SK.Listen("KEEP_CHANGED", function()
    if not (SK.db.bagAutoSyncBank and SK.BankIsOpen()) then return end
    keepTimer = keepTimer + 1
    local mine = keepTimer
    C_Timer.After(1, function()
        if mine == keepTimer and SK.BankIsOpen() then AutoSync("bank", "bagAutoSyncBank") end
    end)
end)
SK.On("BANKFRAME_OPENED", function() AutoSync("bank", "bagAutoSyncBank") end)
local mailOpened = false
SK.On("MAIL_SHOW", function() mailOpened = true end)
SK.On("MAIL_INBOX_UPDATE", function() if mailOpened then mailOpened = false; AutoSync("mailsync", "bagAutoSyncMail") end end)

-- Sync buttons: grayed out reading "In sync" when there's nothing to do.
function SK.UpdateSyncButtons()
    if not (window and window.buttons) then return end
    for key, needs in pairs({ bank = BankNeedsSync, mailsync = MailNeedsSync }) do
        local b = window.buttons[key]
        local w = b and working[b]
        if b and not (w and w.showing) then
            local ok, need = pcall(needs)
            if ok and not need then
                b:SetText("|cff808080" .. L["In sync"] .. "|r")
                b:Disable()
            else
                b:SetText(LABELS[key] or "")
                b:Enable()
            end
        end
    end
end
for _, event in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE" }) do
    SK.On(event, function() C_Timer.After(0.5, function() SK.Quietly("sync buttons", SK.UpdateSyncButtons) end) end)
end

local refreshSoon
local function Soon()
    if refreshSoon or not (window and window:IsShown()) then return end
    refreshSoon = true
    C_Timer.After(0.2, function() refreshSoon = false; SK.Safely("scroll bag", SK.RefreshScrollBag) end)
end
SK.Listen("BAGS_CHANGED", Soon)
SK.Listen("STASH_CHANGED", Soon)
SK.Listen("PINS_CHANGED", Soon)
SK.On("GET_ITEM_INFO_RECEIVED", Soon)
SK.On("PLAYER_EQUIPMENT_CHANGED", Soon)
