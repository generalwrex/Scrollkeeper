-- Scrollkeeper by generalwrex. Created 2026-11-16.
-- Read the LICENSE file before using any of this code.
-- Scrollkeeper: Modules/GuildBank.lua
-- Marks untranslated scrolls in the guild bank that someone would level
-- from: you, your own mages, or guildies running Scrollkeeper.
--
-- A small colored dot in the corner (orange, yellow or green, like
-- skill-up colors) with how many people get a skill-up. Hover the scroll
-- for the names (the normal Scrollkeeper tooltip lines).

local _, SK = ...

local SLOTS_PER_COLUMN = 14
local MAX_SLOTS = MAX_GUILDBANK_SLOTS_PER_TAB or 98
local RANK = { orange = 3, yellow = 2, green = 1 }

local marks = {}

local function SlotButton(slot)
    local column = math.ceil(slot / SLOTS_PER_COLUMN)
    local index = ((slot - 1) % SLOTS_PER_COLUMN) + 1
    local bank = _G.GuildBankFrame
    if bank and bank.Columns and bank.Columns[column] and bank.Columns[column].Buttons then
        return bank.Columns[column].Buttons[index]
    end
    return _G["GuildBankColumn" .. column .. "Button" .. index]
end

local function Mark(button)
    local mark = marks[button]
    if mark then return mark end
    mark = CreateFrame("Frame", nil, button)
    mark:SetAllPoints()
    mark:SetFrameLevel(button:GetFrameLevel() + 5)
    mark.dot = mark:CreateTexture(nil, "OVERLAY")
    mark.dot:SetSize(10, 10)
    mark.dot:SetPoint("TOPLEFT", 2, -2)
    mark.dot:SetTexture("Interface\\COMMON\\Indicator-Gray")
    mark.count = mark:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    mark.count:SetPoint("LEFT", mark.dot, "RIGHT", 1, 0)
    marks[button] = mark
    return mark
end

local function HexToRGB(hex)
    hex = tostring(hex or "ffffff")
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-- Who gets a skill-up from a scroll of this tier: count and best chance.
function SK.SkillUpsFor(needs)
    local count, best = 0, nil
    local function Consider(chance)
        if chance and chance.gives then
            count = count + 1
            if not best or (RANK[chance.key] or 0) > (RANK[best.key] or 0) then best = chance end
        end
    end
    if SK.isMage then
        local skill = SK.GetComprehension()
        if skill.effective >= needs then Consider(SK.SkillUpChance(needs, skill.rank)) end
    end
    for _, mage in ipairs(SK.MyOtherMages and SK.MyOtherMages() or {}) do
        if mage.skill >= needs then Consider(SK.SkillUpChance(needs, mage.skill)) end
    end
    for _, mage in ipairs(SK.FreshMages and SK.FreshMages(true) or {}) do
        if mage.kind == "guild" and mage.tiers[needs] then Consider(SK.SkillUpChance(needs, mage.skill)) end
    end
    return count, best
end

local function Update()
    for _, mark in pairs(marks) do mark:Hide() end
    if not (SK.db and SK.db.guildBankMarks ~= false) then return end
    local bank = _G.GuildBankFrame
    if not (bank and bank:IsShown() and GetCurrentGuildBankTab and GetGuildBankItemLink) then return end
    if bank.mode and bank.mode ~= "bank" then return end
    local tab = GetCurrentGuildBankTab()
    for slot = 1, MAX_SLOTS do
        local link = GetGuildBankItemLink(tab, slot)
        if link then
            local data = C_TooltipInfo and C_TooltipInfo.GetGuildBankItem and SK.Try(C_TooltipInfo.GetGuildBankItem, tab, slot)
            local needs = data and SK.RequirementFromLines(data.lines)
            if needs then
                local count, best = SK.SkillUpsFor(needs)
                local button = SlotButton(slot)
                if button and count > 0 then
                    local mark = Mark(button)
                    mark.dot:SetVertexColor(HexToRGB(best.color))
                    mark.count:SetText(count > 1 and count or "")
                    mark:Show()
                end
            end
        end
    end
end
SK.UpdateGuildBankMarks = Update

local function Soon() C_Timer.After(0.1, function() SK.Safely("guild bank marks", Update) end) end
SK.On("GUILDBANKFRAME_OPENED", Soon)
SK.On("GUILDBANKBAGSLOTS_CHANGED", Soon)
SK.Listen("PEERS_CHANGED", function()
    if _G.GuildBankFrame and _G.GuildBankFrame:IsShown() then Soon() end
end)
