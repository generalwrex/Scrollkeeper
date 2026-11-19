-- Scrollkeeper: UI/Network.lua
-- The network pane: other Scrollkeeper users you can hear, and the
-- community's odds for each scroll tier. It is built twice:
--   * inside the panel's right-hand column in the Advanced view
--   * as its own window (/sk net, or the book button)
-- /sk demo fills it with made-up players to try it out.

local _, SK = ...
local L = SK.L
SK.UI = SK.UI or {}

local ROW_HEIGHT = 16
local CLASS_COLOR = "|cff69ccf0"

local panes = {}      -- every pane built, so one refresh updates them all
local window

------------------------------------------------------------------------
-- Pieces
------------------------------------------------------------------------

-- A bronze plate like "General" on the character window.
function SK.UI.CreateHeader(host, text, width)
    local ok, header = pcall(CreateFrame, "Frame", nil, host, "CharacterStatFrameCategoryTemplate")
    if not (ok and header and type(header.Title) == "table") then
        header = CreateFrame("Frame", nil, host)
        local background = header:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.35, 0.22, 0.08, 0.85)
        header.Title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        header.Title:SetPoint("CENTER")
    end
    header.Title:SetText(text)
    header:SetSize(width, 22)
    return header
end

-- A scrolling list: a fixed-height box with a scrollbar, holding as many
-- label/value rows as needed. list:SetRows(items, fill, emptyText)
-- redraws it, where fill(row, item) sets row.label and row.value.
function SK.UI.CreateScrollList(host, width, visibleRows)
    local height = visibleRows * ROW_HEIGHT
    local listWidth = width - 22          -- room for the scrollbar on the right
    local scroll = CreateFrame("ScrollFrame", nil, host, "UIPanelScrollFrameTemplate")
    scroll:SetSize(listWidth, height)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(listWidth, height)
    scroll:SetScrollChild(content)

    local list = { scroll = scroll, content = content, rows = {}, height = height }

    -- The template shows its scrollbar whenever the content changes; only
    -- show it when there are more rows than fit.
    local bar = scroll.ScrollBar
    if type(bar) ~= "table" then bar = nil end
    scroll:SetScript("OnScrollRangeChanged", function(self)
        if bar then bar:SetShown(self.needsBar and true or false) end
    end)

    list.empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    list.empty:SetPoint("TOPLEFT", 6, -2)
    list.empty:SetWidth(listWidth - 12)
    list.empty:SetJustifyH("LEFT")

    local function MakeRow(i)
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(listWidth, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        if i % 2 == 1 then
            local stripe = row:CreateTexture(nil, "BACKGROUND")
            stripe:SetAllPoints()
            stripe:SetColorTexture(0.45, 0.32, 0.12, 0.18)
        end
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.label:SetPoint("LEFT", 6, 0)
        row.label:SetWidth(listWidth * 0.66)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.value:SetPoint("RIGHT", -6, 0)
        row.value:SetJustifyH("RIGHT")

        -- Rows that show an item (row.itemID): its tooltip on hover, and
        -- Shift-click puts its link in chat, like any item link.
        row:EnableMouse(true)
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 0.82, 0, 0.12)
        row:SetScript("OnEnter", function(self)
            if not self.itemID then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:AddLine(L["Shift-click to link it in chat."], 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnMouseUp", function(self)
            if not (self.itemID and IsModifiedClick and IsModifiedClick("CHATLINK")) then return end
            local link = C_Item and select(2, SK.Try(C_Item.GetItemInfo, self.itemID))
            if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
        end)
        return row
    end

    function list:SetPoint(...) scroll:SetPoint(...) end

    function list:SetRows(items, fill, emptyText)
        for i, item in ipairs(items) do
            self.rows[i] = self.rows[i] or MakeRow(i)
            fill(self.rows[i], item)
            self.rows[i]:Show()
        end
        for i = #items + 1, #self.rows do self.rows[i]:Hide() end
        self.empty:SetText(#items == 0 and (emptyText or "") or "")
        content:SetHeight(math.max(height, #items * ROW_HEIGHT))
        scroll.needsBar = #items > visibleRows
        if bar then bar:SetShown(scroll.needsBar) end
        if not scroll.needsBar then scroll:SetVerticalScroll(0) end
    end

    return list
end

-- "|T icon |t Minor Evocation" in the item's quality color. Falls back to
-- plain text until the game has the item's info, then the list refreshes.
local waitingForItems = {}
function SK.UI.ItemLabel(itemID, text)
    if not (itemID and C_Item) then return text end
    local icon = SK.Try(C_Item.GetItemIconByID, itemID)
    local quality = SK.Try(C_Item.GetItemQualityByID, itemID)
    if not quality then
        waitingForItems[itemID] = true
        if C_Item.RequestLoadItemDataByID then SK.Try(C_Item.RequestLoadItemDataByID, itemID) end
    end
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    local colored = color and color.hex and (color.hex .. text .. "|r") or text
    return icon and ("|T" .. icon .. ":14:14:0:0|t " .. colored) or colored
end

SK.On("GET_ITEM_INFO_RECEIVED", function(itemID)
    if itemID and waitingForItems[itemID] then
        waitingForItems[itemID] = nil
        if SK.RefreshNetwork then SK.RefreshNetwork() end
    end
end)

------------------------------------------------------------------------
-- The pane: Users, then Community Odds with a button per tier
------------------------------------------------------------------------

-- Builds the pane inside host, starting at (left, top). Returns the pane
-- and how tall it is.
function SK.UI.CreateNetworkPane(host, left, top, width, userRows, oddsRows)
    local pane = { selectedTier = 1, tierButtons = {}, regions = {} }
    local function Keep(region) table.insert(pane.regions, region) return region end
    local y = top

    local users = Keep(SK.UI.CreateHeader(host, L["Fellow Mages"], width))
    users:SetPoint("TOPLEFT", left, y)
    y = y - 26
    pane.users = SK.UI.CreateScrollList(host, width, userRows)
    pane.users:SetPoint("TOPLEFT", left, y)
    Keep(pane.users.scroll)
    y = y - userRows * ROW_HEIGHT - 10

    local odds = Keep(SK.UI.CreateHeader(host, L["Community Odds"], width))
    odds:SetPoint("TOPLEFT", left, y)
    y = y - 28
    local buttonWidth = (width - 6) / #SK.TIERS
    for i, tier in ipairs(SK.TIERS) do
        local button = Keep(CreateFrame("Button", nil, host, "UIPanelButtonTemplate"))
        button:SetSize(buttonWidth, 20)
        button:SetPoint("TOPLEFT", left + (i - 1) * (buttonWidth + 2), y)
        button:SetText(L["Tier "] .. tier)
        button:SetScript("OnClick", function()
            pane.selectedTier = tier
            pane:Refresh()
        end)
        pane.tierButtons[tier] = button
    end
    y = y - 26
    pane.odds = SK.UI.CreateScrollList(host, width, oddsRows)
    pane.odds:SetPoint("TOPLEFT", left, y)
    Keep(pane.odds.scroll)
    y = y - oddsRows * ROW_HEIGHT - 4

    pane.oddsNote = Keep(host:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"))
    pane.oddsNote:SetPoint("TOPLEFT", left + 6, y - 2)
    pane.oddsNote:SetWidth(width - 12)
    pane.oddsNote:SetJustifyH("LEFT")
    y = y - 30

    function pane:SetShown(shown)
        for _, region in ipairs(self.regions) do region:SetShown(shown) end
        if shown then self:Refresh() end
    end

    function pane:Refresh()
        if not self.regions[1]:IsVisible() then return end
        -- Only mages: the others have nothing to show here.
        local peers = {}
        for _, entry in ipairs(SK.PeerList()) do
            if entry.peer and entry.peer.class == "MAGE" then peers[#peers + 1] = entry end
        end
        -- Anonymous players aren't named, but show that they're there.
        local anonymous = SK.AnonymousCount and SK.AnonymousCount() or 0
        if anonymous > 0 then peers[#peers + 1] = { anonymous = anonymous } end

        self.users:SetRows(peers, function(row, entry)
            row.itemID = nil
            local peer = entry.peer
            if entry.anonymous then
                row.label:SetText("|cff808080" .. L["Anonymous"] .. "|r")
                row.value:SetText("|cff808080" .. L["+%d |4player:players;"]:format(entry.anonymous) .. "|r")
            else
                local tiers = {}
                for _, tier in ipairs(SK.TIERS) do
                    if peer.tiers[tier] then tiers[#tiers + 1] = tier end
                end
                local needs = #tiers > 0 and (L["needs "] .. table.concat(tiers, ", ")) or ("|cff808080" .. L["needs none"] .. "|r")
                local upgrade = #peer.upgrades > 0 and (" |cffa335ee" .. table.concat(peer.upgrades, ", ") .. "|r") or ""
                row.label:SetText(CLASS_COLOR .. entry.name .. "|r  " .. peer.skill)
                row.value:SetText(needs .. upgrade)
            end
        end, L["No one yet. Guild and group members running Scrollkeeper show up here within a minute of logging in."])

        for tier, button in pairs(self.tierButtons) do
            if tier == self.selectedTier then button:LockHighlight() else button:UnlockHighlight() end
        end
        local odds, total, players = SK.CommunityOdds(self.selectedTier)
        self.odds:SetRows(odds, function(row, entry)
            row.itemID = entry.itemID
            row.label:SetText(SK.UI.ItemLabel(entry.itemID, (entry.name:gsub("^Scroll of ", ""))))
            row.value:SetText(("%d  |cffffffff%.1f%%|r"):format(entry.count, entry.share * 100))
        end, "")
        if total == 0 then
            self.oddsNote:SetText(L["No tier %d scrolls deciphered yet."]:format(self.selectedTier))
        else
            self.oddsNote:SetText(L["%d deciphered by %d |4player:players;. More players, better odds."]:format(total, players))
        end
    end

    table.insert(panes, pane)
    return pane, top - y
end

------------------------------------------------------------------------
-- The separate window (/sk net)
------------------------------------------------------------------------

local WIDTH, HEIGHT = 300, 470
local LEFT = 12

local function Build()
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperNetworkFrame", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperNetworkFrame", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if self.TitleText then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER", -200, 0)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    if window.SetDontSavePosition then window:SetDontSavePosition(true) end
    if window.SetPortraitToAsset then window:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Book_09") end
    window:SetTitle(L["Scrollkeeper Network"])
    tinsert(UISpecialFrames, "ScrollkeeperNetworkFrame")   -- Escape closes it

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    background:SetColorTexture(0.05, 0.05, 0.06, 0.95)

    window.summary = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.summary:SetPoint("TOPLEFT", 62, -32)
    window.summary:SetPoint("RIGHT", window, "RIGHT", -12, 0)
    window.summary:SetJustifyH("CENTER")

    window.pane = SK.UI.CreateNetworkPane(window, LEFT, -62, WIDTH - LEFT * 2, 8, 8)

    window.footer = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.footer:SetPoint("BOTTOMLEFT", LEFT + 6, 12)
    window.footer:SetPoint("RIGHT", window, "RIGHT", -12, 0)
    window.footer:SetJustifyH("LEFT")

    window:SetScript("OnShow", function() SK.RefreshNetwork() end)
    window:Hide()
end

------------------------------------------------------------------------
-- Filling it in
------------------------------------------------------------------------

local SHARING_NAMES = { full = "Full", anon = "Anonymous", simple = "Simple" }

-- Colored name of the current sharing mode ("Full", "Anonymous", "Simple"), or "off".
function SK.SharingLabel()
    local name = SK.db.share and SHARING_NAMES[SK.db.sharing]
    if not name then
        return SK.db.share and L["|cff40ff40on|r"] or L["|cffff6666off|r"]
    end
    return "|cff40ff40" .. L[name] .. "|r"
end

function SK.NetworkFooter()
    local sharing = SK.SharingLabel()
    local demo = SK.demoCommunity and L["  |cffff8040demo|r"] or ""
    return L["Sharing "] .. sharing .. L["  ·  scroll data only"] .. demo
end

function SK.RefreshNetwork()
    for _, pane in ipairs(panes) do pane:Refresh() end
    if window and window:IsShown() then
        local demo = SK.demoCommunity and L[" |cffff8040(demo)|r"] or ""
        window.summary:SetText(L["|cffffffff%d|r heard from%s"]:format(#SK.PeerList(), demo))
        window.footer:SetText(SK.NetworkFooter() .. L["  ·  /sk options"])
    end
end

function SK.ToggleNetwork()
    if not window then Build() end
    window:SetShown(not window:IsShown())
end

SK.Listen("PEERS_CHANGED", function() SK.RefreshNetwork() end)
SK.Listen("COMMUNITY_CHANGED", function() SK.RefreshNetwork() end)
SK.Listen("LOG_CHANGED", function() SK.RefreshNetwork() end)

------------------------------------------------------------------------
-- Demo mode: made-up players, kept in memory only, never sent or saved
------------------------------------------------------------------------

function SK.ToggleDemo()
    if SK.demoCommunity then
        for name, peer in pairs(SK.peers) do
            if peer.demo then SK.peers[name] = nil end
        end
        SK.demoCommunity = nil
        SK.demoNames = nil
        SK.Print(L["demo off."])
    else
        local function Peer(class, level, skill, tiers, upgrades)
            local set = {}
            for _, tier in ipairs(tiers) do set[tier] = true end
            return { version = SK.version, class = class, level = level, skill = skill, max = level * 5,
                     tiers = set, upgrades = upgrades or {}, seen = time(), source = "GUILD", demo = true }
        end
        SK.peers["Kaelith-Demo"] = Peer("MAGE", 24, 41, { 15, 50 })
        SK.peers["Morwen-Demo"] = Peer("MAGE", 38, 162, { 50 }, { "Blade" })
        SK.peers["Thessaly-Demo"] = Peer("MAGE", 52, 205, { 175 }, { "Saber" })
        SK.peers["Brakka-Demo"] = Peer("WARRIOR", 30, 0, {})
        SK.peers["Pip-Demo"] = Peer("MAGE", 12, 18, { 1, 15 })

        -- Made-up results. Real item IDs where we know them.
        SK.demoNames = {
            [213564] = L["Scroll of Minor Evocation"], [277483] = L["Scroll of Frog Familiar"],
            [-1] = L["Scroll of Comprehension"], [-2] = L["Scroll of Imbue Lesser Flame"],
            [-3] = L["Scroll of Rat Familiar"], [-4] = L["Scroll of Imbue Chillknife"],
            [-5] = L["Scroll of Cryoblast"], [-6] = L["Scroll of Polymorph: Odd Melon"],
            [-7] = L["Scroll of the Saber"], [-8] = L["Scroll of Imbue Frost"],
            [-9] = L["Scroll of Cat Familiar"], [-10] = L["Scroll of Khadgar's Unlocking"],
            [-11] = L["Scroll of the Blade"],
        }
        local mapID, px, py = SK.PlayerMapPosition()
        local function Drops(n)
            if not mapID then return {} end
            local cells = {}
            for _ = 1, n do
                local x = math.min(0.98, math.max(0.02, px + (math.random() - 0.5) * 0.3))
                local y = math.min(0.98, math.max(0.02, py + (math.random() - 0.5) * 0.3))
                local cell = SK.CellFor(x, y)
                cells[cell] = (cells[cell] or 0) + math.random(1, 4)
            end
            return { [mapID] = cells }
        end
        SK.demoCommunity = {
            { results = { [1] = { [213564] = 41, [-1] = 22, [-2] = 37, [-3] = 30, [-4] = 15 },
                          [15] = { [277483] = 12, [-5] = 9, [-6] = 4, [-8] = 7, [-7] = 1 } }, drops = Drops(6) },
            { results = { [1] = { [213564] = 18, [-1] = 9, [-2] = 14, [-3] = 11, [-4] = 6 },
                          [15] = { [277483] = 6, [-5] = 5, [-6] = 2, [-8] = 3 },
                          [50] = { [-9] = 5, [-10] = 3, [-11] = 1 } }, drops = Drops(5) },
            { results = { [15] = { [277483] = 3, [-5] = 2, [-8] = 1 } }, drops = Drops(4) },
        }
        SK.Print(L["demo on: made-up players and odds (never sent or saved). /sk demo again to turn it off."])
    end
    SK.Send("PEERS_CHANGED")
    SK.Send("COMMUNITY_CHANGED")
    SK.Send("DROPS_CHANGED")
    SK.Send("BAGS_CHANGED", SK.bags, SK.bags)
end
