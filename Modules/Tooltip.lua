-- Scrollkeeper: Modules/Tooltip.lua
-- Adds a line to untranslated scroll tooltips, for every class.
--
--   Mage who can read it:   "you can decipher this, skill-up likely."
--   Mage who can't yet:     "Needs 15 Comprehension. You have 9."
--   Any other class:        "Mage scroll. Mail it to a mage or sell it."
--   Everyone:               which of your own mages can read it

local _, SK = ...

local TITLE = "|cff69ccf0Scrollkeeper|r"

local function AddScrollLines(tooltip, needs, itemID)
    if SK.isMage then
        local skill = SK.GetComprehension()
        if skill.effective >= needs then
            local chance = SK.SkillUpChance(needs, skill.rank)
            local skillUp = chance and (" " .. SK.ColoredChance(chance) .. ".") or ""
            tooltip:AddLine(TITLE .. ": |cff40ff40you can decipher this,|r" .. skillUp)
        else
            tooltip:AddLine((TITLE .. ": needs %d Comprehension. You have %d."):format(needs, skill.effective), 1, 0.4, 0.4)
        end
    else
        tooltip:AddLine(TITLE .. ": mage scroll. Mail it to a mage or sell it.", 1, 0.82, 0)
        tooltip:AddLine("Only mages can decipher it. It does not stack.", 0.7, 0.7, 0.7)
        -- With Auctionator: is the auction house worth it?
        local auction, vendor = itemID and SK.ScrollPrices and SK.ScrollPrices(itemID)
        if auction and vendor and GetMoneyString then
            if auction > vendor * 2 then
                tooltip:AddLine("Sells for about " .. GetMoneyString(auction) .. " on the auction house.", 0.25, 1, 0.25)
            else
                tooltip:AddLine("Not worth much on the auction house; a mage friend will thank you.", 0.7, 0.7, 0.7)
            end
        end
    end

    -- Your own mages on this account who can read it.
    local mine = SK.MyMagesFor and SK.MyMagesFor(needs) or {}
    if #mine > 0 then
        local names = {}
        for i = 1, math.min(#mine, 3) do
            local mage = mine[i]
            names[i] = mage.name .. (mage.chance and mage.chance.gives and (" " .. SK.ColoredChance(mage.chance)) or "")
        end
        tooltip:AddLine("Your mages: |cffffffff" .. table.concat(names, ", ") .. "|r", 0.41, 0.8, 0.94, true)
    end

    -- Other Scrollkeeper mages (group first, then guild) who'd get a
    -- skill-up from this scroll.
    local mages = SK.MagesWhoNeed and SK.MagesWhoNeed(needs) or {}
    if #mages > 0 then
        local names = {}
        for i = 1, math.min(#mages, 3) do
            local mage = mages[i]
            names[i] = mage.name .. (mage.group and " |cff40ff40(group)|r" or "")
        end
        if #mages > 3 then names[#names + 1] = ("+%d more"):format(#mages - 3) end
        local label = "Mail it to: "
        if SK.isMage then
            local mine = SK.SkillUpChance(needs, SK.GetComprehension().rank)
            label = (mine and mine.gives) and "Also a skill-up for: " or "Skill-up for: "
        end
        tooltip:AddLine(label .. "|cffffffff" .. table.concat(names, ", ") .. "|r", 1, 0.82, 0, true)
    end

    -- What it can become. With Shift: the community's real odds.
    local results = SK.TIER_RESULTS[needs]
    if IsShiftKeyDown and IsShiftKeyDown() then
        local odds, total, players = {}, 0, 0
        if SK.CommunityOdds then odds, total, players = SK.CommunityOdds(needs) end
        if total > 0 then
            tooltip:AddLine(("What it became, %d read by %d |4player:players;:"):format(total, players), 1, 0.82, 0)
            for i = 1, math.min(#odds, 8) do
                local row = odds[i]
                tooltip:AddDoubleLine("  " .. row.name, ("%.1f%%"):format(row.share * 100), 0.9, 0.9, 0.9, 1, 1, 1)
            end
        elseif results then
            tooltip:AddLine("Can become: " .. table.concat(results, ", "), 0.7, 0.7, 0.7, true)
        end
    elseif results then
        tooltip:AddLine("Hold Shift to see what it can become.", 0.5, 0.5, 0.5)
    end
end

local function OnItemTooltip(tooltip, data)
    if not (SK.db and SK.db.showTooltips) then return end
    if type(data) ~= "table" or not tooltip or not tooltip.AddLine then return end
    local needs = SK.RequirementFromLines(data.lines)
    if needs then AddScrollLines(tooltip, needs, data.id) end
end

SK.Listen("READY", function()
    if not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then return end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        -- pcall: a tooltip must never break because of us.
        pcall(OnItemTooltip, tooltip, data)
    end)
end)

-- Pressing or releasing Shift redraws an open item tooltip, so the odds
-- appear without moving the mouse.
SK.On("MODIFIER_STATE_CHANGED", function(key)
    if not (key == "LSHIFT" or key == "RSHIFT") then return end
    if GameTooltip:IsShown() and GameTooltip.RefreshData then GameTooltip:RefreshData() end
end)
