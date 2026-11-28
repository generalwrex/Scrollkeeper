-- Scrollkeeper by generalwrex. Created 2026-11-27.
-- Read the LICENSE file before using any of this code.
-- Scrollkeeper: Modules/NotYet.lua
-- Scrolls you can't use yet go to the bank, and come back out when you can.
--
--   not yet   a deciphered mage scroll above your level, or an undeciphered
--             scroll above your Comprehension skill
--
-- Setting bagNotYet: "ask" (at the bank, ask first), "auto" (just do it),
-- "off". Only scrolls Scrollkeeper banked this way come back out by
-- themselves (SK.db.notYet remembers them), so nothing else you keep in
-- your bank moves. When a level or skill-up makes some usable, chat says so.

local _, SK = ...
local L = SK.L

local function Held()
    SK.db.notYet = type(SK.db.notYet) == "table" and SK.db.notYet or {}
    return SK.db.notYet   -- itemID -> { count, level, needs, name }
end

local function MyLevel() return (UnitLevel and SK.Known(UnitLevel("player"))) or 0 end
local function MySkill()
    local skill = SK.GetComprehension and SK.GetComprehension()
    return skill and skill.effective or 0
end

-- What a slot holds, if it's a scroll you can't use yet: { level } or { needs }.
local function NotYetInfo(bag, slot, itemID)
    if not (SK.IsScrollItem and SK.IsScrollItem(itemID)) or not SK.ReadScrollSlot then return nil end
    local needs, mageOnly, level = SK.ReadScrollSlot(bag, slot)
    if needs then
        if needs > MySkill() then return { needs = needs } end
    elseif mageOnly and (level or 0) > MyLevel() then
        return { level = level }
    end
    return nil
end

local function CanUseNow(h)
    if h.needs then return h.needs <= MySkill() end
    return (h.level or 0) <= MyLevel()
end

-- Still held for later (and not usable yet)? The Scroll Bag's bank sync
-- leaves these in the bank.
function SK.NotYetHeld(itemID)
    local h = type(SK.db.notYet) == "table" and SK.db.notYet[itemID]
    return h and not CanUseNow(h) or false
end

local function BagSlots(bags)
    local list = {}
    for _, bag in ipairs(bags) do
        for slot = 1, SK.Try(C_Container.GetContainerNumSlots, bag) or 0 do
            local info = SK.Try(C_Container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and info.itemID and not info.isLocked then
                list[#list + 1] = { bag = bag, slot = slot, itemID = info.itemID, count = info.stackCount or 1,
                    name = info.itemName }
            end
        end
    end
    return list
end

local function ToBank()
    local list = {}
    for _, it in ipairs(BagSlots({ 0, 1, 2, 3, 4, 5 })) do
        local why = NotYetInfo(it.bag, it.slot, it.itemID)
        if why then it.why = why; list[#list + 1] = it end
    end
    return list
end

local function FromBank()
    local list, held = {}, Held()
    for _, it in ipairs(BagSlots(SK.BankBags())) do
        local h = held[it.itemID]
        if h and CanUseNow(h) then list[#list + 1] = it end
    end
    return list
end

local function Count(list)
    local n = 0
    for _, it in ipairs(list) do n = n + it.count end
    return n
end

-- One move at a time (using an item with the bank open moves it across).
local function Move(list, after)
    local i = 0
    local function Step()
        i = i + 1
        local it = list[i]
        if not it or not SK.BankIsOpen() or SK.InCombat() then if after then after() end return end
        SK.Try(C_Container.UseContainerItem, it.bag, it.slot)
        C_Timer.After(0.3, Step)
    end
    Step()
end

local function Bank(list)
    local held = Held()
    for _, it in ipairs(list) do
        local h = held[it.itemID] or { count = 0 }
        h.count = (h.count or 0) + it.count
        h.level, h.needs = it.why.level, it.why.needs
        h.name = it.name or h.name
        held[it.itemID] = h
    end
    Move(list, function()
        SK.Print(L["Banked %d |4scroll:scrolls; you can't use yet. Scrollkeeper tells you when you can."]:format(Count(list)))
        SK.Send("STASH_CHANGED")
    end)
end

local function TakeOut(list)
    local held = Held()
    for _, it in ipairs(list) do held[it.itemID] = nil end
    Move(list, function()
        SK.Print(L["Took %d |4scroll:scrolls; you can use now out of your bank."]:format(Count(list)))
        SK.Send("STASH_CHANGED")
    end)
end

if StaticPopupDialogs then
    StaticPopupDialogs["SCROLLKEEPER_NOTYET_BANK"] = {
        text = "%s", button1 = YES or L["Yes"], button2 = NO or L["No"],
        timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function(_, data) if data then SK.Safely("not yet", data) end end,
    }
end

local function Ask(text, run)
    if SK.db.bagNotYet == "auto" then run() return end
    if StaticPopup_Show then StaticPopup_Show("SCROLLKEEPER_NOTYET_BANK", text, nil, run) end
end

SK.On("BANKFRAME_OPENED", function()
    if (SK.db.bagNotYet or "ask") == "off" or not SK.ModuleOn("Bag") then return end
    C_Timer.After(1.2, function()
        SK.Safely("not yet", function()
            if not SK.BankIsOpen() or SK.InCombat() then return end
            local out = FromBank()
            local into = ToBank()
            if #out > 0 then
                Ask(L["You can use %d |4scroll:scrolls; you banked for later now. Take them out of the bank?"]:format(Count(out)),
                    function() TakeOut(out) end)
            elseif #into > 0 then
                Ask(L["Bank your %d |4scroll:scrolls; you can't use yet? Scrollkeeper tells you when you can, and takes them back out at the bank."]:format(Count(into)),
                    function() Bank(into) end)
            end
        end)
    end)
end)

-- A level or a skill-up: say which held scrolls you can use now.
local told = {}
SK.Listen("SKILL_CHANGED", function()
    C_Timer.After(1, function()
        SK.Safely("not yet", function()
            if (SK.db.bagNotYet or "ask") == "off" then return end
            local n, names = 0, {}
            for itemID, h in pairs(Held()) do
                if CanUseNow(h) and not told[itemID] then
                    told[itemID] = true
                    n = n + (h.count or 0)
                    names[#names + 1] = (h.name or ("item " .. itemID)):gsub("^Scroll of ", "")
                end
            end
            if n > 0 then
                SK.Print(L["You can use %d |4scroll:scrolls; in your bank now (%s). %s"]:format(n, table.concat(names, ", "),
                    SK.db.bagNotYet == "auto" and L["They come out next time you open your bank."]
                        or L["Scrollkeeper asks next time you open your bank."]))
            end
        end)
    end)
end)
