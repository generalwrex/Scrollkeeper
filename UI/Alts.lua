-- Scrollkeeper: UI/Alts.lua
-- A small window for your non-mage characters:
--
--   Your Mages     each of your mages: skill, and when Study is ready
--   In your bags   untranslated scrolls this character is carrying, and
--                  how many your mages can read (mail them over)
--
-- It shows once you've logged in on a mage with Scrollkeeper. Close it
-- with the X; /sk brings it back.

local _, SK = ...
local L = SK.L

local WIDTH = 240
local LEFT = 16
local INNER = WIDTH - LEFT - 18
local ROW_HEIGHT = 16
local MAX_ROWS = 6

local window
local rows = {}

local function Build()
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperAltFrame", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperAltFrame", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if self.TitleText then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(WIDTH, 200)
    window:SetFrameStrata("MEDIUM")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SK.db.altPoint = { self:GetLeft(), self:GetTop() }
    end)
    if window.SetDontSavePosition then window:SetDontSavePosition(true) end
    if window.SetPortraitToAsset then window:SetPortraitToAsset("Interface\\Icons\\INV_Scroll_03") end
    window:SetTitle(L["Scrollkeeper"])

    local point = SK.db.altPoint
    if point then
        window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", point[1], point[2])
    else
        window:SetPoint("CENTER", UIParent, "CENTER", 320, 0)
    end

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    background:SetColorTexture(0.05, 0.05, 0.06, 0.95)

    if type(window.CloseButton) == "table" then
        window.CloseButton:SetScript("OnClick", function()
            SK.db.showAltPanel = false
            window:Hide()
            SK.Print(L["hidden. Type /sk to show it again."])
        end)
    end

    window.summary = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.summary:SetPoint("TOPLEFT", 62, -32)
    window.summary:SetPoint("RIGHT", window, "RIGHT", -14, 0)
    window.summary:SetJustifyH("CENTER")

    window.header = SK.UI.CreateHeader(window, L["Your Mages"], INNER)
    window.header:SetPoint("TOPLEFT", LEFT, -62)

    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, window)
        row:SetSize(INNER, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", LEFT, -88 - (i - 1) * ROW_HEIGHT)
        if i % 2 == 1 then
            local stripe = row:CreateTexture(nil, "BACKGROUND")
            stripe:SetAllPoints()
            stripe:SetColorTexture(0.45, 0.32, 0.12, 0.18)
        end
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.label:SetPoint("LEFT", 6, 0)
        row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.value:SetPoint("RIGHT", -6, 0)
        rows[i] = row
    end

    window.bags = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.bags:SetWidth(INNER - 8)
    window.bags:SetJustifyH("LEFT")
end

local function Refresh()
    if not window then return end
    local mages = SK.MyOtherMages()
    window.summary:SetText(("|cffffffff%d|r |4mage:mages;"):format(#mages))

    for i, row in ipairs(rows) do
        local mage = mages[i]
        if mage then
            row.label:SetText(("|cff69ccf0%s|r  %d/%d"):format(mage.name, mage.skill, mage.max))
            if mage.knowsStudy then
                local left = mage.studyLeft
                row.value:SetText(left == 0 and ("|cff40ff40" .. L["Study ready"] .. "|r") or (L["Study"] .. " " .. SK.FormatStudyTime(left)))
            else
                row.value:SetText("")
            end
            row:Show()
        else
            row:Hide()
        end
    end

    -- Scrolls this character carries, and how many your mages can read.
    local carried, readable, skillUps = 0, 0, 0
    for _, scroll in ipairs(SK.bags.untranslated or {}) do
        carried = carried + 1
        local who = SK.MyMagesFor(scroll.needs)
        if #who > 0 then
            readable = readable + 1
            if who[1].chance and who[1].chance.gives then skillUps = skillUps + 1 end
        end
    end
    local y = -88 - math.max(1, math.min(#mages, MAX_ROWS)) * ROW_HEIGHT - 10
    window.bags:ClearAllPoints()
    window.bags:SetPoint("TOPLEFT", LEFT + 4, y)
    if carried == 0 then
        window.bags:SetText(L["|cff808080No untranslated scrolls on this character.|r"])
    else
        local text = L["In your bags: |cffffffff%d|r |4scroll:scrolls;"]:format(carried)
        if readable > 0 then
            text = text .. L["\n|cff40ff40%d|r your mages can read"]:format(readable)
            if skillUps > 0 then text = text .. (", |cffff8040%d|r |4skill-up:skill-ups;"):format(skillUps) end
            text = text .. L[". Mail them over."]
        end
        window.bags:SetText(text)
    end
    window:SetHeight(-y + window.bags:GetStringHeight() + 22)
end

function SK.ToggleAltPanel()
    if not window then Build() end
    SK.db.showAltPanel = not window:IsShown()
    window:SetShown(SK.db.showAltPanel)
    Refresh()
end

SK.Listen("READY", function()
    if SK.isMage then return end
    -- Only once you have a mage to help.
    if #SK.MyOtherMages() == 0 then return end
    if SK.db.showAltPanel == false then return end
    Build()
    window:Show()
    Refresh()
    SK.Listen("BAGS_CHANGED", Refresh)
    C_Timer.NewTicker(30, function() if window:IsShown() then Refresh() end end)
end)
