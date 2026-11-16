-- Scrollkeeper: UI/Icon.lua
-- The scroll icon: a small square you can keep on screen while you play.
--
--   the number    how many scrolls you can decipher right now
--                 (green when some of them still give skill-ups)
--   a gold glow   Study is ready
--   click         open or close the panel, in the view you picked
--   drag          move it (unless the panel position is locked)
--
-- Turn it on in Options > AddOns > Scrollkeeper > Scroll icon. Mages only.
-- (Idea from Curnil, thanks!)

local _, SK = ...
local L = SK.L

local SIZE = 40
local icon

local function Build()
    icon = CreateFrame("Button", "ScrollkeeperIcon", UIParent)
    icon:SetSize(SIZE, SIZE)
    icon:SetFrameStrata("MEDIUM")
    icon:SetClampedToScreen(true)
    icon:SetMovable(true)
    icon:EnableMouse(true)
    icon:RegisterForDrag("LeftButton")
    icon:RegisterForClicks("LeftButtonUp")

    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexture("Interface\\Icons\\INV_Scroll_03")
    icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    icon.border = icon:CreateTexture(nil, "OVERLAY")
    icon.border:SetPoint("TOPLEFT", -2, 2)
    icon.border:SetPoint("BOTTOMRIGHT", 2, -2)
    icon.border:SetColorTexture(0, 0, 0, 0)
    local edge = icon:CreateTexture(nil, "BACKGROUND")
    edge:SetPoint("TOPLEFT", -2, 2)
    edge:SetPoint("BOTTOMRIGHT", 2, -2)
    edge:SetColorTexture(0, 0, 0, 0.8)

    icon.glow = icon:CreateTexture(nil, "OVERLAY")
    icon.glow:SetPoint("TOPLEFT", -10, 10)
    icon.glow:SetPoint("BOTTOMRIGHT", 10, -10)
    icon.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    icon.glow:SetBlendMode("ADD")
    icon.glow:SetVertexColor(1, 0.82, 0)
    icon.glow:Hide()

    icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    icon.count:SetPoint("BOTTOMRIGHT", -2, 2)

    icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    icon:SetScript("OnDragStart", function(self)
        if SK.db.locked then return end
        self:StartMoving()
    end)
    icon:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        SK.db.iconPos = { point, relativePoint, x, y }
    end)
    icon:SetScript("OnClick", function()
        if SK.InCombat() then
            SK.Print(L["the panel can be opened after combat."])
            return
        end
        SK.TogglePanel()
    end)
    icon:SetScript("OnEnter", function(self)
        local _, readable, tooHard, skillUps = SK.NextDecipherable()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Scrollkeeper")
        GameTooltip:AddDoubleLine(L["Ready to decipher"], readable, 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(L["Skill-ups"], skillUps or 0, 1, 0.82, 0, 1, 1, 1)
        if (tooHard or 0) > 0 then GameTooltip:AddDoubleLine(L["Too hard"], tooHard, 1, 0.82, 0, 1, 1, 1) end
        if SK.StudySecondsLeft and SK.KnowsStudy and SK.KnowsStudy() then
            GameTooltip:AddDoubleLine(L["Study"], SK.FormatStudyTime(SK.StudySecondsLeft()), 1, 0.82, 0, 1, 1, 1)
        end
        GameTooltip:AddLine(L["Click to open or close the panel. Drag to move."], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local pos = SK.db.iconPos
    if pos then
        icon:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        icon:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    end
end

function SK.RefreshIcon()
    local wanted = SK.isMage and SK.db and SK.db.scrollIcon
    if not wanted then
        if icon then icon:Hide() end
        return
    end
    if not icon then Build() end
    local _, readable, _, skillUps = SK.NextDecipherable()
    icon.count:SetText(readable or 0)
    if (skillUps or 0) > 0 then
        icon.count:SetTextColor(0.25, 1, 0.25)
    elseif (readable or 0) > 0 then
        icon.count:SetTextColor(1, 1, 1)
    else
        icon.count:SetTextColor(0.6, 0.6, 0.6)
    end
    icon.texture:SetDesaturated((readable or 0) == 0)
    local studyReady = SK.KnowsStudy and SK.KnowsStudy() and SK.StudySecondsLeft and SK.StudySecondsLeft() <= 0
    icon.glow:SetShown(studyReady and true or false)
    icon:SetScale(SK.db.scale or 1)
    icon:Show()
end

SK.Listen("READY", SK.RefreshIcon)
SK.Listen("BAGS_CHANGED", SK.RefreshIcon)
SK.Listen("SKILL_CHANGED", SK.RefreshIcon)
SK.Listen("STUDY_CHANGED", SK.RefreshIcon)
