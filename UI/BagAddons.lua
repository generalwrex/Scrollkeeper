-- Scrollkeeper: UI/BagAddons.lua
-- Scroll Bag marks wherever you look at your bags: a small colored corner
-- on each mage scroll (green keep, red extra, orange part of the stack is
-- extra, blue set aside) and a star when it's pinned.
--
-- Works with the game's own bags, and with these bag addons when they're
-- installed (none are needed; each one is skipped if it isn't there):
--   AdiBags      a "Scrollkeeper" filter: Scrolls: Keep / Extra / Set aside
--                sections, plus the corner marks
--   Baganator    corner marks (its widget system), and extras as junk if
--                you turn that on
--   Bagnon       corner marks
--   BetterBags   Scrolls: Keep / Extra / Set aside categories
--   ArkInventory a rule: scrollkeeper("extra"), scrollkeeper("keep")...
-- Turn the marks off in /sk options (Scroll Bag).

local _, SK = ...
local L = SK.L

local COLORS = {
    keep = { 0.25, 0.85, 0.35 }, extra = { 0.9, 0.25, 0.25 }, partial = { 1, 0.6, 0.1 }, aside = { 0.35, 0.6, 1 },
}
local SECTION = { keep = "Scrolls: Keep", extra = "Scrolls: Extra", partial = "Scrolls: Extra", aside = "Scrolls: Set aside" }

local function Enabled() return SK.isMage and SK.db and SK.db.bagMarks ~= false and SK.ModuleOn("Bag") end

-- Status of a bag slot's item: "keep", "extra", "partial", "aside" or nil.
local function StatusAt(bag, slot, itemID)
    if not Enabled() or not itemID or not SK.StashSlotStatus then return nil end
    local ok, status, entry = pcall(SK.StashSlotStatus, bag, slot, itemID)
    if ok then return status, entry end
end

------------------------------------------------------------------------
-- The mark: a small square in the top-left corner, and a star if pinned
------------------------------------------------------------------------

local marks = setmetatable({}, { __mode = "k" })

local function Mark(button)
    local mark = marks[button]
    if mark then return mark end
    mark = CreateFrame("Frame", nil, button)
    mark:SetAllPoints()
    mark:SetFrameLevel((button:GetFrameLevel() or 1) + 5)
    mark.dot = mark:CreateTexture(nil, "OVERLAY")
    mark.dot:SetSize(8, 8)
    mark.dot:SetPoint("TOPLEFT", 3, -3)
    mark.dot:SetTexture("Interface\\Buttons\\WHITE8x8")
    mark.edge = mark:CreateTexture(nil, "ARTWORK")
    mark.edge:SetSize(10, 10)
    mark.edge:SetPoint("CENTER", mark.dot)
    mark.edge:SetColorTexture(0, 0, 0, 0.9)
    mark.star = mark:CreateTexture(nil, "OVERLAY")
    mark.star:SetSize(12, 12)
    mark.star:SetPoint("TOPRIGHT", -1, -1)
    mark.star:SetTexture("Interface\\COMMON\\FavoritesIcon")
    marks[button] = mark
    return mark
end

local function Apply(button, bag, slot, itemID)
    if not button then return end
    local status, entry = StatusAt(bag, slot, itemID)
    if not status then
        if marks[button] then marks[button]:Hide() end
        return
    end
    local mark = Mark(button)
    local c = COLORS[status]
    mark.dot:SetVertexColor(c[1], c[2], c[3], 1)
    mark.star:SetShown(entry and entry.pinned and true or false)
    mark:Show()
end
SK.ApplyBagMark = Apply

------------------------------------------------------------------------
-- The game's own bags
------------------------------------------------------------------------

local function ButtonSlot(button)
    local bag = button.GetBagID and SK.Try(button.GetBagID, button) or (button.GetParent and button:GetParent() and button:GetParent():GetID())
    local slot = button.GetID and button:GetID()
    return bag, slot
end

local function UpdateDefaultBags()
    local frames = {}
    if _G.ContainerFrameCombinedBags then frames[#frames + 1] = _G.ContainerFrameCombinedBags end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame then frames[#frames + 1] = frame end
    end
    for _, frame in ipairs(frames) do
        if frame:IsShown() then
            if frame.EnumerateValidItems then
                for _, button in frame:EnumerateValidItems() do
                    local bag, slot = ButtonSlot(button)
                    local info = bag and slot and SK.Try(C_Container.GetContainerItemInfo, bag, slot)
                    Apply(button, bag, slot, type(info) == "table" and info.itemID or nil)
                end
            else
                local name = frame:GetName()
                for i = 1, frame.size or 36 do
                    local button = name and _G[name .. "Item" .. i]
                    if button then
                        local bag, slot = frame:GetID(), button:GetID()
                        local info = SK.Try(C_Container.GetContainerItemInfo, bag, slot)
                        Apply(button, bag, slot, type(info) == "table" and info.itemID or nil)
                    end
                end
            end
        end
    end
end

local pending
local function UpdateSoon()
    if pending then return end
    pending = true
    C_Timer.After(0.1, function()
        pending = false
        SK.Quietly("bag marks", UpdateDefaultBags)
        if SK.RefreshBagAddons then SK.Quietly("bag addon marks", SK.RefreshBagAddons) end
    end)
end

SK.Listen("READY", function()
    if not SK.isMage then return end
    for _, name in ipairs({ "ToggleAllBags", "OpenAllBags", "ToggleBackpack", "ToggleBag", "OpenBag", "OpenBackpack" }) do
        if type(_G[name]) == "function" then hooksecurefunc(name, UpdateSoon) end
    end
    if _G.ContainerFrameCombinedBags then _G.ContainerFrameCombinedBags:HookScript("OnShow", UpdateSoon) end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame.HookScript then frame:HookScript("OnShow", UpdateSoon) end
    end
end)
SK.Listen("BAGS_CHANGED", UpdateSoon)
SK.Listen("STASH_CHANGED", UpdateSoon)
SK.Listen("PINS_CHANGED", UpdateSoon)

------------------------------------------------------------------------
-- Bag addons. Each part checks the addon is there and never errors if
-- its insides changed: a broken hook only loses the marks.
------------------------------------------------------------------------

local refreshers = {}
function SK.RefreshBagAddons()
    for _, refresh in ipairs(refreshers) do SK.Quietly("bag addon refresh", refresh) end
end

local function AceAddon(name)
    local LibStub = _G.LibStub
    local ace = LibStub and LibStub("AceAddon-3.0", true)
    if not ace then return nil end
    local ok, addon = pcall(ace.GetAddon, ace, name, true)
    return ok and addon or nil
end

-- AdiBags: a filter that puts scrolls in their own sections, and the marks
-- on its buttons (it tells modules about every button update).
local function SetUpAdiBags()
    local adi = AceAddon("AdiBags")
    if not (adi and adi.RegisterFilter) then return end
    local filter = adi:RegisterFilter("Scrollkeeper", 92, "ABEvent-1.0")
    filter.uiName = "Scrollkeeper"
    filter.uiDesc = L["Mage scrolls in their own sections: keep, extra and set aside (Scrollkeeper's Scroll Bag)."]
    function filter:OnEnable()
        self:RegisterMessage("AdiBags_UpdateButton", function(_, button)
            if button then Apply(button, button.bag, button.slot, button.itemId) end
        end)
        adi:UpdateFilters()
    end
    function filter:OnDisable() adi:UpdateFilters() end
    function filter:Filter(slotData)
        if SK.db.bagMarks == false then return nil end
        local status = StatusAt(slotData.bag, slotData.slot, slotData.itemId)
        if status then return L[SECTION[status]], L["Scrolls"] end
    end
    refreshers[#refreshers + 1] = function()
        if filter.SendMessage then filter:SendMessage("AdiBags_FiltersChanged") else adi:UpdateFilters() end
    end
end

-- Baganator: a corner widget, and (if you turn it on) a junk plugin.
local function SetUpBaganator()
    local api = _G.Baganator and _G.Baganator.API
    if not api then return end
    if api.RegisterCornerWidget then
        pcall(api.RegisterCornerWidget, "Scrollkeeper", "scrollkeeper",
            function(corner, details)
                local status, entry = StatusAt(details and details.bagID, details and details.slotID, details and details.itemID)
                if not status then return false end
                local c = COLORS[status]
                corner:SetVertexColor(c[1], c[2], c[3], 1)
                return true
            end,
            function(itemButton)
                local tex = itemButton:CreateTexture(nil, "OVERLAY")
                tex:SetSize(8, 8)
                tex:SetTexture("Interface\\Buttons\\WHITE8x8")
                return tex
            end,
            { corner = "top_left", priority = 1 })
    end
    if api.RegisterJunkPlugin then
        pcall(api.RegisterJunkPlugin, L["Scrollkeeper: extra scrolls"], "scrollkeeper", function(bagID, slotID, itemID)
            if not (SK.db and SK.db.bagJunk) then return false end
            local status = StatusAt(bagID, slotID, itemID)
            return status == "extra"
        end)
    end
    refreshers[#refreshers + 1] = function()
        if api.RequestItemButtonsRefresh then api.RequestItemButtonsRefresh() end
    end
end

-- Bagnon (and its BagBrother family): marks on its item buttons.
local function SetUpBagnon()
    local bagnon = _G.Bagnon
    local item = bagnon and (bagnon.Item or bagnon.ItemSlot)
    if not (item and item.Update) then return end
    hooksecurefunc(item, "Update", function(self)
        SK.Quietly("bagnon mark", function()
            local info = self.info or (self.GetInfo and self:GetInfo()) or {}
            local itemID = info.itemID or info.id
            local bag = (self.GetBag and self:GetBag()) or self.bag
            Apply(self, bag, self:GetID(), itemID)
        end)
    end)
    refreshers[#refreshers + 1] = function()
        if bagnon.Frames and bagnon.Frames.Update then pcall(bagnon.Frames.Update, bagnon.Frames) end
    end
end

-- BetterBags: categories for scrolls.
local function SetUpBetterBags()
    local better = AceAddon("BetterBags")
    if not better then return end
    local ok, categories = pcall(better.GetModule, better, "Categories")
    if not (ok and categories and categories.RegisterCategoryFunction) then return end
    categories:RegisterCategoryFunction("scrollkeeper", function(data)
        local info = data and data.itemInfo
        local status = info and StatusAt(data.bagid, data.slotid, info.itemID)
        return status and L[SECTION[status]] or nil
    end)
    refreshers[#refreshers + 1] = function()
        local okEvents, events = pcall(better.GetModule, better, "Events")
        if okEvents and events and events.SendMessage then pcall(events.SendMessage, events, "bags/FullRefreshAll") end
    end
end

-- ArkInventory: a rule you can use in its rules window:
--   scrollkeeper("extra"), scrollkeeper("keep"), scrollkeeper("aside")
local function SetUpArkInventory()
    local rules = _G.ArkInventoryRules
    if not (rules and rules.Register and rules.Object) then return end
    local module = {}
    function module.execute(...)
        local object = rules.Object
        local itemID = object and (object.test_id or (object.h and tonumber(object.h:match("item:(%d+)"))))
        local status = StatusAt(object and object.bag_id, object and object.slot_id, itemID)
        if not status then return false end
        local wanted = select("#", ...) == 0 and nil or tostring((...)):lower()
        if not wanted then return true end
        return wanted == status or (wanted == "extra" and status == "partial")
    end
    pcall(rules.Register, module, "SCROLLKEEPER", module.execute)
end

SK.Listen("READY", function()
    if not SK.isMage then return end
    -- AdiBags turns its filters on when you enter the world, so its filter
    -- is added right away (AdiBags loads before Scrollkeeper: A before S).
    SK.Quietly("AdiBags setup", SetUpAdiBags)
    -- The others, a moment after login (some load after Scrollkeeper).
    C_Timer.After(1, function()
        for _, setUp in ipairs({ SetUpBaganator, SetUpBagnon, SetUpBetterBags, SetUpArkInventory }) do
            SK.Quietly("bag addon setup", setUp)
        end
    end)
end)
