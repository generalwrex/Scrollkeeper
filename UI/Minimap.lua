-- Scrollkeeper: UI/Minimap.lua
-- The round button on the edge of the minimap, like most addons have.
--
--   number         scrolls you can decipher right now (green: skill-ups)
--   left-click     open or close the panel
--   right-click    settings
--   drag           move it around the minimap
--
-- Turn it off in the settings (Minimap button). Mages only.

local _, SK = ...
local L = SK.L

local button

local function Place()
    if not (button and Minimap) then return end
    local angle = math.rad(SK.db.minimapAngle or 210)
    local radius = (Minimap:GetWidth() or 140) / 2 + 6
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function Build()
    button = CreateFrame("Button", "ScrollkeeperMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(18, 18)
    button.icon:SetPoint("TOPLEFT", 7, -6)
    button.icon:SetTexture("Interface\\Icons\\INV_Scroll_03")
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.count:SetPoint("BOTTOMRIGHT", -3, 3)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            SK.OpenOptions()
        elseif SK.InCombat() then
            SK.Print(L["the panel can be opened after combat."])
        else
            SK.TogglePanel()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            SK.db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
            Place()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", function(self)
        local _, readable, tooHard, skillUps = SK.NextDecipherable()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Scrollkeeper")
        GameTooltip:AddDoubleLine(L["Ready to decipher"], readable, 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(L["Skill-ups"], skillUps or 0, 1, 0.82, 0, 1, 1, 1)
        if (tooHard or 0) > 0 then GameTooltip:AddDoubleLine(L["Too hard"], tooHard, 1, 0.82, 0, 1, 1, 1) end
        if SK.KnowsStudy and SK.KnowsStudy() then
            GameTooltip:AddDoubleLine(L["Study"], SK.FormatStudyTime(SK.StudySecondsLeft()), 1, 0.82, 0, 1, 1, 1)
        end
        GameTooltip:AddLine(L["Click: panel   Right-click: settings   Drag: move"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Place()
end

function SK.RefreshMinimapButton()
    if not (SK.isMage and SK.db and SK.db.minimapButton and Minimap) then
        if button then button:Hide() end
        return
    end
    if not button then Build() end
    local _, readable, _, skillUps = SK.NextDecipherable()
    button.count:SetText((readable or 0) > 0 and readable or "")
    if (skillUps or 0) > 0 then
        button.count:SetTextColor(0.25, 1, 0.25)
    else
        button.count:SetTextColor(1, 1, 1)
    end
    button:Show()
end

SK.Listen("READY", SK.RefreshMinimapButton)
SK.Listen("BAGS_CHANGED", SK.RefreshMinimapButton)
SK.Listen("SKILL_CHANGED", SK.RefreshMinimapButton)
