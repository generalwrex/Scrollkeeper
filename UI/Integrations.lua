-- Scrollkeeper by generalwrex. Created 2026-11-15.
-- Read the LICENSE file before using any of this code.
-- Scrollkeeper: UI/Integrations.lua
-- Optional extras that use other addons when they're installed. None of
-- them are required; each checks first and does nothing if it's missing.
--
--   Info bars (Titan Panel, ElvUI, Bazooka...)  via LibDataBroker
--   The game's addon menu (the minimap puzzle-piece button)
--   Auctionator  "worth more on the AH than at a vendor" on scroll tooltips

local _, SK = ...
local L = SK.L

------------------------------------------------------------------------
-- Info bar entry: "Scrolls 5 · Study 42m"
------------------------------------------------------------------------

local feed

local function FeedText()
    local _, readable, _, skillUps = SK.NextDecipherable()
    local text = L["Scrolls %d"]:format(readable)
    if skillUps and skillUps > 0 then text = text .. (" |cffff8040(+%d)|r"):format(skillUps) end
    if SK.isMage and SK.KnowsStudy() then
        text = text .. L["  Study "] .. SK.FormatStudyTime(SK.StudySecondsLeft())
    end
    return text
end

local function TooltipLines(tooltip)
    tooltip:AddLine(L["Scrollkeeper"])
    local skill = SK.GetComprehension()
    if skill.known then
        tooltip:AddDoubleLine(L["Comprehension"], ("%d / %d"):format(skill.rank, skill.max), 1, 0.82, 0, 1, 1, 1)
    end
    local _, readable, tooHard, skillUps = SK.NextDecipherable()
    tooltip:AddDoubleLine(L["Ready to decipher"], readable, 1, 0.82, 0, 1, 1, 1)
    tooltip:AddDoubleLine(L["Skill-ups"], skillUps or 0, 1, 0.82, 0, 1, 1, 1)
    if tooHard > 0 then tooltip:AddDoubleLine(L["Too hard"], tooHard, 1, 0.82, 0, 1, 1, 1) end
    tooltip:AddLine(" ")
    tooltip:AddLine(L["Click: panel   Right-click: Fellow Mages"], 0.6, 0.6, 0.6)
end

local function OnClick(_, button)
    if button == "RightButton" then SK.ToggleNetwork() else SK.TogglePanel() end
end

SK.Listen("READY", function()
    local LibStub = _G.LibStub
    local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
    if not ldb then return end
    feed = ldb:NewDataObject("Scrollkeeper", {
        type = "data source",
        label = L["Scrollkeeper"],
        icon = "Interface\\Icons\\INV_Scroll_03",
        text = "Scrollkeeper",
        OnClick = OnClick,
        OnTooltipShow = TooltipLines,
    })
    local function Update() if feed then feed.text = FeedText() end end
    SK.Listen("BAGS_CHANGED", Update)
    SK.Listen("SKILL_CHANGED", Update)
    SK.Listen("STUDY_CHANGED", Update)
    C_Timer.NewTicker(15, function() SK.Safely("info bar", Update) end)
    Update()
end)

------------------------------------------------------------------------
-- The game's addon menu (named in Scrollkeeper.toc)
------------------------------------------------------------------------

function Scrollkeeper_OnCompartmentClick(_, button)
    if button == "RightButton" then SK.ToggleNetwork() else SK.TogglePanel() end
end

function Scrollkeeper_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    TooltipLines(GameTooltip)
    GameTooltip:Show()
end

function Scrollkeeper_OnCompartmentLeave()
    GameTooltip:Hide()
end

------------------------------------------------------------------------
-- Auctionator: should a non-mage sell this scroll on the auction house?
------------------------------------------------------------------------

local CALLER = "Scrollkeeper"

-- Returns auction price and vendor price in copper (either may be nil).
function SK.ScrollPrices(itemID)
    local auction
    local api = _G.Auctionator and Auctionator.API and Auctionator.API.v1
    if api and api.GetAuctionPriceByItemID then
        auction = SK.Try(api.GetAuctionPriceByItemID, CALLER, itemID)
    end
    local vendor
    if C_Item and C_Item.GetItemInfo then
        vendor = select(11, SK.Try(C_Item.GetItemInfo, itemID))
    end
    return auction, vendor
end

-- Is Auctionator or TradeSkillMaster installed? Then their prices are used
-- and Scrollkeeper doesn't scan the auction house itself.
function SK.HasAuctionAddon()
    local api = _G.Auctionator and Auctionator.API and Auctionator.API.v1
    return (api and api.GetAuctionPriceByItemID and true) or (_G.TSM_API and TSM_API.GetCustomPriceValue and true) or false
end

-- An auction price from another addon, if one is installed and has it:
-- Auctionator first, then TradeSkillMaster. Copper each, or nil.
function SK.AddonAuctionPrice(itemID)
    local api = _G.Auctionator and Auctionator.API and Auctionator.API.v1
    if api and api.GetAuctionPriceByItemID then
        local price = SK.Try(api.GetAuctionPriceByItemID, CALLER, itemID)
        if type(price) == "number" and price > 0 then return price, "Auctionator" end
    end
    if _G.TSM_API and TSM_API.GetCustomPriceValue then
        local price = SK.Try(TSM_API.GetCustomPriceValue, "DBMinBuyout", "i:" .. itemID)
        if type(price) == "number" and price > 0 then return price, "TSM" end
    end
    return nil
end

-- The price to go by: another addon's if there is one, otherwise our own scan.
-- Returns copper each, and where it came from ("Auctionator", "TSM" or nil for ours).
function SK.MarketPrice(itemID)
    local price, source = SK.AddonAuctionPrice(itemID)
    if price then return price, source end
    return SK.AuctionPrice and SK.AuctionPrice(itemID), nil
end
