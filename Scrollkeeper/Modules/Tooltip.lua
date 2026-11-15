-- Scrollkeeper: Modules/Tooltip.lua
-- Adds a line to untranslated scroll tooltips, for every class.
--
--   Mage who can read it:   "You can decipher this."
--   Mage who can't yet:     "Needs 15 Comprehension. You have 9."
--   Any other class:        "Mage scroll. Mail it to a mage or sell it."

local _, SK = ...

local TITLE = "|cff69ccf0Scrollkeeper|r"

local function AddScrollLines(tooltip, needs)
    if SK.isMage then
        local skill = SK.GetComprehension()
        if skill.effective >= needs then
            tooltip:AddLine(TITLE .. ": you can decipher this.", 0.25, 1, 0.25)
        else
            tooltip:AddLine((TITLE .. ": needs %d Comprehension. You have %d."):format(needs, skill.effective), 1, 0.4, 0.4)
        end
    else
        tooltip:AddLine(TITLE .. ": mage scroll. Mail it to a mage or sell it.", 1, 0.82, 0)
        tooltip:AddLine("Only mages can decipher it. It does not stack.", 0.7, 0.7, 0.7)
    end

    local results = SK.TIER_RESULTS[needs]
    if results and IsShiftKeyDown and IsShiftKeyDown() then
        tooltip:AddLine("Can become: " .. table.concat(results, ", "), 0.7, 0.7, 0.7, true)
    elseif results then
        tooltip:AddLine("Hold Shift to see what it can become.", 0.5, 0.5, 0.5)
    end
end

local function OnItemTooltip(tooltip, data)
    if not (SK.db and SK.db.showTooltips) then return end
    if type(data) ~= "table" or not tooltip or not tooltip.AddLine then return end
    local needs = SK.RequirementFromLines(data.lines)
    if needs then AddScrollLines(tooltip, needs) end
end

SK.Listen("READY", function()
    if not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then return end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        -- pcall: a tooltip must never break because of us.
        pcall(OnItemTooltip, tooltip, data)
    end)
end)
