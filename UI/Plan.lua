-- Scrollkeeper: UI/Plan.lua
-- The Farming Plan window. It shows what fits where you are:
--
--   Out in the world (the note button on the panel, or /sk plan)
--     your Comprehension, your next goal, about how many scrolls and how
--     long, and Where to farm: the zones with the most scroll drops
--     (click one to open it on the map)
--
--   At the auction house (the Plan button there, docked beside it)
--     your Comprehension, and the scrolls you'd still level from with their
--     buyout price, sortable (click one to search for it there)
--
-- Prices: Auctionator's or TSM's when one of them is installed, otherwise
-- Scrollkeeper's own "Scan scrolls".

local _, SK = ...
local L = SK.L

local WIDTH = 360
local INNER = 330
local ROWS = 10
local ROW_HEIGHT = 16

local window

------------------------------------------------------------------------
-- Sorting the auction house list (Price, Tier, Name; click again to flip)
------------------------------------------------------------------------

local SORT_LABELS = { price = "Price", tier = "Tier", name = "Name" }
local function NameOf(entry)
    local name = C_Item and C_Item.GetItemNameByID and SK.Try(C_Item.GetItemNameByID, entry.itemID)
    return name or ""
end
local SORTS = {
    price = function(a, b) return a.price < b.price end,
    tier  = function(a, b) if a.needs ~= b.needs then return a.needs < b.needs end return a.price < b.price end,
    name  = function(a, b) return NameOf(a) < NameOf(b) end,
}
local function SortScrolls(list, mode, reversed)
    local compare = SORTS[mode] or SORTS.price
    table.sort(list, reversed and function(a, b) return compare(b, a) end or compare)
end
local ARROW_UP = " |TInterface\\Buttons\\Arrow-Up-Up:12:12|t"
local ARROW_DOWN = " |TInterface\\Buttons\\Arrow-Down-Up:12:12|t"

local function AtAuctionHouse()
    return (_G.AuctionHouseFrame and _G.AuctionHouseFrame:IsShown()) or (_G.AuctionFrame and _G.AuctionFrame:IsShown())
end

-- Open the world map on a zone.
local function ShowZone(mapID)
    if not (mapID and WorldMapFrame) then return end
    if not WorldMapFrame:IsShown() and ToggleWorldMap then SK.Try(ToggleWorldMap) end
    if WorldMapFrame.SetMapID then SK.Try(WorldMapFrame.SetMapID, WorldMapFrame, mapID) end
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------

local function Build()
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperPlanFrame", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperPlanFrame", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if self.TitleText then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(WIDTH, 420)
    window:SetPoint("CENTER", 200, 0)
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetTitle(L["Scrollkeeper: Farming Plan"])
    if window.SetPortraitToAsset then window:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Note_01") end
    tinsert(UISpecialFrames, "ScrollkeeperPlanFrame")   -- Escape closes it

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    SK.UI.Background(background)

    -- Your Comprehension, at the top in both modes.
    window.skill = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.skill:SetPoint("TOPLEFT", 21, -64)
    window.skill:SetWidth(INNER - 12)
    window.skill:SetJustifyH("LEFT")

    -- Out in the world -------------------------------------------------------
    local world = CreateFrame("Frame", nil, window)
    world:SetAllPoints()
    window.world = world

    local goal = SK.UI.CreateHeader(world, L["Next goal"], INNER)
    goal:SetPoint("TOPLEFT", 15, -84)
    world.text = world:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    world.text:SetPoint("TOPLEFT", goal, "BOTTOMLEFT", 6, -6)
    world.text:SetWidth(INNER - 12)
    world.text:SetJustifyH("LEFT")
    world.text:SetSpacing(3)

    local where = SK.UI.CreateHeader(world, L["Where to farm"], INNER)
    where:SetPoint("TOPLEFT", world.text, "BOTTOMLEFT", -6, -12)
    world.zones = SK.UI.CreateScrollList(world, INNER, ROWS)

    -- A scroll icon per tier, like Community Odds. The tier you need is
    -- picked by itself and keeps a gold frame; click another to look at it.
    world.tierButtons = {}
    local slot = INNER / #SK.TIERS
    for i, tier in ipairs(SK.TIERS) do
        local button = CreateFrame("Button", nil, world)
        button:SetSize(22, 22)
        button:SetPoint("TOPLEFT", where, "BOTTOMLEFT", (i - 1) * slot + (slot - 22) / 2, -6)
        button:SetNormalTexture(SK.UI.TIER_ICONS and SK.UI.TIER_ICONS[i] or "Interface\\Icons\\INV_Scroll_03")
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button.frame = button:CreateTexture(nil, "BACKGROUND")
        button.frame:SetPoint("TOPLEFT", -2, 2)
        button.frame:SetPoint("BOTTOMRIGHT", 2, -2)
        button.frame:SetColorTexture(1, 0.82, 0, 1)
        button.glow = button:CreateTexture(nil, "OVERLAY")
        button.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        button.glow:SetBlendMode("ADD")
        button.glow:SetAllPoints()
        button.number = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        button.number:SetPoint("BOTTOMRIGHT", 3, -2)
        button.number:SetText(tier)
        button:SetScript("OnClick", function()
            SK.Track("plan.tier")
            world.picked = tier
            world.zones.scroll:SetVerticalScroll(0)
            SK.RefreshPlan()
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L["Tier "] .. tier)
            if self.needed then GameTooltip:AddLine(L["The tier you need right now."], 1, 0.82, 0) end
            GameTooltip:AddLine(L["Where people found tier %d scrolls."]:format(tier), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        world.tierButtons[tier] = button
    end

    -- Which tier the list is for ("You need Tier 50" / none logged yet).
    world.zonesFor = world:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    world.zonesFor:SetPoint("TOPLEFT", where, "BOTTOMLEFT", 6, -32)
    world.zonesFor:SetWidth(INNER - 12)
    world.zonesFor:SetJustifyH("LEFT")
    world.zonesFor:SetWordWrap(false)   -- one line, or it runs into the list
    world.zones:SetPoint("TOPLEFT", where, "BOTTOMLEFT", 0, -48)

    local worldNote = world:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    worldNote:SetPoint("BOTTOMLEFT", 16, 14)
    worldNote:SetPoint("RIGHT", window, "RIGHT", -16, 0)
    worldNote:SetJustifyH("LEFT")
    worldNote:SetText(L["Click a zone to open it on the map."] .. "\n"
        .. L["Drops by tier are only shared since 1.1.5, so this fills in as more people play."])

    -- At the auction house ---------------------------------------------------
    local ah = CreateFrame("Frame", nil, window)
    ah:SetAllPoints()
    window.ah = ah

    local onAH = SK.UI.CreateHeader(ah, L["On the auction house"], INNER)
    onAH:SetPoint("TOPLEFT", 15, -84)
    ah.source = ah:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ah.source:SetPoint("TOPLEFT", onAH, "BOTTOMLEFT", 6, -4)
    ah.source:SetWidth(INNER - 12)
    ah.source:SetJustifyH("LEFT")

    ah.sortButtons = {}
    local previous
    for _, mode in ipairs({ "price", "tier", "name" }) do
        local button = CreateFrame("Button", nil, ah, "UIPanelButtonTemplate")
        button:SetSize(70, 18)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
        else
            button:SetPoint("TOPLEFT", onAH, "BOTTOMLEFT", 2, -20)
        end
        button:SetText(L[SORT_LABELS[mode]])
        if button.GetFontString and button:GetFontString() then button:GetFontString():SetFontObject("GameFontNormalSmall") end
        button:SetScript("OnClick", function()
            SK.Track("plan.sort." .. mode)
            if (SK.db.planSort or "price") == mode then
                SK.db.planSortReversed = not SK.db.planSortReversed
            else
                SK.db.planSort, SK.db.planSortReversed = mode, false
            end
            SK.RefreshPlan()
        end)
        ah.sortButtons[mode] = button
        previous = button
    end
    ah.list = SK.UI.CreateScrollList(ah, INNER, ROWS)
    ah.list:SetPoint("TOPLEFT", onAH, "BOTTOMLEFT", 0, -42)

    local ahNote = ah:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ahNote:SetPoint("BOTTOMLEFT", 16, 14)
    ahNote:SetPoint("RIGHT", window, "RIGHT", -16, 0)
    ahNote:SetJustifyH("LEFT")
    ahNote:SetText(L["Click a scroll to search for it on the auction house."])

    window:SetScript("OnShow", function()
        window.world.picked = nil   -- opens on the tier you need
        SK.RefreshPlan()
        -- Scroll info the game hadn't loaded yet comes in a moment later.
        C_Timer.After(1, SK.RefreshPlan)
        -- At the auction house without Auctionator or TSM: ask before
        -- scanning (once per visit). No = nothing happens.
        local otherAddon = SK.HasAuctionAddon and SK.HasAuctionAddon()
        if AtAuctionHouse() and not otherAddon and not window.askedThisVisit and StaticPopup_Show then
            window.askedThisVisit = true
            StaticPopup_Show("SCROLLKEEPER_SCAN_AH")
        end
    end)
    window:Hide()   -- new frames start shown, so OnShow (and the scan question) wouldn't fire the first time
end

if StaticPopupDialogs then
    StaticPopupDialogs["SCROLLKEEPER_SCAN_AH"] = {
        text = L["Scrollkeeper: scan the auction house for scroll prices now?"],
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function() SK.Safely("plan scan", SK.ScanAuctionScrolls) end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

------------------------------------------------------------------------
-- Filling it in
------------------------------------------------------------------------

local function RefreshWorld()
    local world = window.world
    local lines, plan = SK.FarmPlanLines(true)
    world.text:SetText(table.concat(lines, "\n"))

    -- Zones for the tier the plan says to read, unless you clicked another
    -- tier. None logged yet for it: every tier.
    local needed = plan and plan.tier
    local tier = type(world.picked) == "number" and world.picked or needed
    for t, button in pairs(world.tierButtons) do
        local shown = t == tier
        button.needed = t == needed
        button.frame:SetShown(button.needed)
        button.glow:SetShown(shown)
        SK.UI.Desaturate(button, not shown and not button.needed)
        button.number:SetTextColor(shown and 1 or 0.6, shown and 0.82 or 0.6, shown and 0 or 0.6)
    end
    local zones = tier and SK.BestZones(25, tier) or {}
    local isNeeded = tier == needed
    if tier and #zones > 0 then
        world.zonesFor:SetText((isNeeded and L["You need |cffffffffTier %d|r. Where people found it:"]
            or L["|cffffffffTier %d|r. Where people found it:"]):format(tier))
    else
        zones = SK.BestZones(25)
        world.zonesFor:SetText(tier and (isNeeded and L["You need |cffffffffTier %d|r. None logged yet, so all tiers:"]
            or L["|cffffffffTier %d|r: none logged yet, so all tiers:"]):format(tier)
            or L["All tiers:"])
    end
    local arrows = SK.HasArrowAddon and SK.HasArrowAddon()
    world.zones:SetRows(zones, function(row, zone)
        row.itemID = nil
        row.label:SetText(zone.name)
        row.value:SetText(L["%d |4scroll:scrolls; found"]:format(zone.count))
        row:SetScript("OnMouseUp", function() SK.Track("plan.zone") ShowZone(zone.mapID) end)
        -- With Zygor or TomTom: an Arrow button to the zone's busiest drop spot.
        if arrows and type(row.skArrow) ~= "table" then
            row.skArrow = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.skArrow:SetSize(48, 16)
            row.skArrow:SetPoint("RIGHT", -4, 0)
            row.skArrow:SetText(L["Arrow"])
            if row.skArrow.GetFontString and row.skArrow:GetFontString() then row.skArrow:GetFontString():SetFontObject(GameFontHighlightSmall) end
            row.skArrow:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        if type(row.skArrow) == "table" then
            row.skArrow:SetShown(arrows and true or false)
            row.value:ClearAllPoints()
            row.value:SetPoint("RIGHT", arrows and -56 or -6, 0)
            row.skArrow:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L["Point an arrow at the spot in %s where the most scrolls dropped."]:format(zone.name), 1, 1, 1, true)
                GameTooltip:Show()
            end)
            row.skArrow:SetScript("OnClick", function()
                SK.Track("plan.arrow")
                local x, y = SK.BusiestDropSpot(zone.mapID)
                if x and SK.SetWaypoint(zone.mapID, x, y, L["Scroll drops: %s"]:format(zone.name)) then
                    SK.Print(L["waypoint set: "] .. zone.name)
                end
            end)
        end
    end, L["No drops logged yet. Loot some untranslated scrolls and the zones show up here."])

    local textHeight = world.text:GetStringHeight() or 60
    window:SetHeight(84 + 22 + 6 + textHeight + 12 + 22 + 48 + ROWS * ROW_HEIGHT + 58)
end

local function RefreshAuctionHouse()
    local ah = window.ah
    local otherAddon = SK.HasAuctionAddon and SK.HasAuctionAddon()
    if otherAddon then
        ah.source:SetText(L["Prices from Auctionator or TSM."])
    elseif SK.db.ahLastScan then
        ah.source:SetText(L["Prices from your last scan (%s)."]:format(SK.TimeAgo(SK.db.ahLastScan)))
    else
        ah.source:SetText(L["No prices yet. Hit Scan scrolls."])
    end

    local scrolls = SK.CheapestScrolls(50)
    local sortMode, reversed = SK.db.planSort or "price", SK.db.planSortReversed and true or false
    if not SORT_LABELS[sortMode] then sortMode = "price" end
    SortScrolls(scrolls, sortMode, reversed)
    for mode, button in pairs(ah.sortButtons) do
        if mode == sortMode then
            button:LockHighlight()
            button:SetText(L[SORT_LABELS[mode]] .. (reversed and ARROW_DOWN or ARROW_UP))
        else
            button:UnlockHighlight()
            button:SetText(L[SORT_LABELS[mode]])
        end
    end

    ah.list:SetRows(scrolls, function(row, entry)
        row.itemID = entry.itemID
        -- Click: search for it. Shift-click: link it in chat.
        row:SetScript("OnMouseUp", function(self)
            SK.Track("plan.item")
            if IsModifiedClick and IsModifiedClick("CHATLINK") then
                local link = C_Item and select(2, SK.Try(C_Item.GetItemInfo, self.itemID))
                if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
                return
            end
            SK.ShowOnAuctionHouse(self.itemID)
        end)
        local name = C_Item and C_Item.GetItemNameByID and SK.Try(C_Item.GetItemNameByID, entry.itemID)
        row.label:SetText(SK.UI.ItemLabel(entry.itemID, name or ("item " .. entry.itemID))
            .. L[" |cff808080T%d|r"]:format(entry.needs))
        row.value:SetText(SK.Money(entry.price))
    end, L["None of the scrolls with a price give you skill-ups right now."])

    window:SetHeight(84 + 22 + 42 + ROWS * ROW_HEIGHT + 44)
end

function SK.RefreshPlan()
    if not (window and window:IsShown()) then return end
    -- "Comprehension: 66 / 110", in the game's own name for the skill.
    local skill = SK.GetComprehension()
    local bonus = skill.bonus > 0 and L[" |cff40ff40(+%d for now)|r"]:format(skill.bonus) or ""
    window.skill:SetText(("%s: |cffffffff%d / %d|r"):format(skill.name, skill.rank, skill.max) .. bonus)

    local atAH = window.dock and AtAuctionHouse()
    window.world:SetShown(not atAH)
    window.ah:SetShown(atAH and true or false)
    if atAH then RefreshAuctionHouse() else RefreshWorld() end
end

-- dock = the auction house frame to sit beside (the AH mode), or nil for
-- the normal window (the world mode).
function SK.TogglePlan(dock)
    if not SK.ModuleOn("Plan") then
        SK.Print(L["%s is turned off. Turn it on in /sk options (Modules)."]:format(L["Farming Plan"]))
        return
    end
    if not window then Build() end
    if window:IsShown() and window.dock == dock then window:Hide() return end
    window:ClearAllPoints()
    if dock then
        window:SetPoint("TOPLEFT", dock, "TOPRIGHT", 4, 0)
    else
        window:SetPoint("CENTER", 200, 0)
    end
    window.dock = dock
    window:Show()
    SK.RefreshPlan()
end

-- Leaving the auction house: a docked window closes, and it asks again
-- about scanning next time.
SK.On("AUCTION_HOUSE_CLOSED", function()
    if not window then return end
    window.askedThisVisit = nil
    if StaticPopup_Hide then StaticPopup_Hide("SCROLLKEEPER_SCAN_AH") end
    if window.dock then window:Hide(); window.dock = nil end
end)

-- Item info the game loads later (names, tooltips): refresh, at most twice a second.
local refreshSoon
SK.On("GET_ITEM_INFO_RECEIVED", function()
    if refreshSoon or not (window and window:IsShown()) then return end
    refreshSoon = true
    C_Timer.After(0.5, function() refreshSoon = false; SK.Safely("plan refresh", SK.RefreshPlan) end)
end)

SK.Listen("PRICES_CHANGED", SK.RefreshPlan)
SK.Listen("BAGS_CHANGED", SK.RefreshPlan)
SK.Listen("SKILL_CHANGED", SK.RefreshPlan)
