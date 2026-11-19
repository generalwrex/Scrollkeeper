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

-- Grey out (or color in) an icon button's picture.
function SK.UI.Desaturate(button, grey)
    local texture = button.GetNormalTexture and button:GetNormalTexture()
    if type(texture) == "table" and texture.SetDesaturated then texture:SetDesaturated(grey and true or false) end
end

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
-- twoLine: taller rows with a smaller row.sub line under the label (and
-- visibleRows counts those taller rows).
function SK.UI.CreateScrollList(host, width, visibleRows, twoLine)
    local ROW_HEIGHT = twoLine and 30 or ROW_HEIGHT
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
    -- The template's own handler has to run first: it tells the scrollbar
    -- how far it can go, without which dragging it or the mouse wheel
    -- can't move the list.
    local bar = scroll.ScrollBar
    if type(bar) ~= "table" then bar = nil end
    local templateHandler = scroll:GetScript("OnScrollRangeChanged")
    scroll:SetScript("OnScrollRangeChanged", function(self, xrange, yrange)
        if type(templateHandler) == "function" then templateHandler(self, xrange, yrange) end
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
        if twoLine then
            -- Name on top across the whole row, details underneath.
            row.label:ClearAllPoints()
            row.label:SetPoint("TOPLEFT", 6, -3)
            row.label:SetWidth(listWidth - 12)
            row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.sub:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 8, -2)
            row.sub:SetWidth(listWidth - 20)
            row.sub:SetJustifyH("LEFT")
            row.sub:SetWordWrap(false)
            row.value:Hide()
        end

        -- Rows that show an item (row.itemID): its tooltip on hover, and
        -- Shift-click puts its link in chat, like any item link.
        row:EnableMouse(true)
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 0.82, 0, 0.12)
        row:SetScript("OnEnter", function(self)
            -- Rows can fill the tooltip themselves (row.tipFunc), or carry
            -- a simple one: row.tipTitle plus row.tipLines.
            if not self.itemID and self.tipFunc then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                self.tipFunc(GameTooltip)
                GameTooltip:Show()
                return
            end
            if not self.itemID and self.tipTitle then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(self.tipTitle)
                for _, line in ipairs(self.tipLines or {}) do
                    GameTooltip:AddDoubleLine(line[1], line[2], 1, 1, 1, 1, 1, 1)
                end
                GameTooltip:Show()
                return
            end
            if not self.itemID then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemID)
            if self.tipCount then GameTooltip:AddLine(self.tipCount, 1, 0.82, 0) end
            GameTooltip:AddLine(L["Shift-click to link it in chat."], 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnMouseUp", function(self)
            if not self.itemID and self.onClick then self.onClick() return end
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

-- Where a player was heard, for the tooltip.
local SOURCES = { GUILD = "Guild", PARTY = "Group", RAID = "Group", INSTANCE_CHAT = "Group",
                  CHANNEL = "Everyone online", WHISPER = "Whisper" }

-- How many untranslated scrolls in your bags a mage would level from.
local function YourScrollsFor(peer)
    local count = 0
    for _, scroll in ipairs(SK.bags and SK.bags.untranslated or {}) do
        if peer.tiers and peer.tiers[scroll.needs] then count = count + 1 end
    end
    return count
end

-- Sorting Fellow Mages. Each sort's normal order is the useful one
-- (highest skill first, A to Z, most of your scrolls first).
local MAGE_SORT_ORDER = { "skill", "name", "mine" }
local MAGE_SORTS = {
    skill = { label = "Skill", tip = "Highest Comprehension first.", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
              less = function(a, b) return (a.peer.skill or 0) > (b.peer.skill or 0) end },
    name  = { label = "Name", tip = "A to Z.", icon = "Interface\\Icons\\INV_Misc_Book_09",
              less = function(a, b) return a.name:lower() < b.name:lower() end },
    mine  = { label = "My scrolls", tip = "Who could use the most untranslated scrolls in your bags.",
              icon = "Interface\\Icons\\INV_Scroll_03",
              less = function(a, b)
                  if a.yours ~= b.yours then return a.yours > b.yours end
                  return (a.peer.skill or 0) > (b.peer.skill or 0)
              end },
}
-- The author's characters: their tooltip says so. Names are only unique
-- per server (PvE, PvP, RP, RP-PvP); realm = nil means every server
-- (the author has this name on all four).
local AUTHOR_CHARACTERS = {
    { names = { ["Archmage Naage"] = true, ["Naage"] = true } },
}
local function SameRealm(a, b)
    local function Plain(text) return (text or ""):gsub("[%s%-]", ""):lower() end
    return Plain(a) == Plain(b)
end
local function IsAuthor(sender)
    -- "Name-Server" for players on another server, just "Name" on yours.
    local short, realm = sender:match("^(.-)%-([^%-]+)$")
    if not short then short, realm = sender, GetRealmName and GetRealmName() end
    for _, author in ipairs(AUTHOR_CHARACTERS) do
        if author.names[short] and (not author.realm or SameRealm(realm, author.realm)) then return true end
    end
    return false
end

-- Community Odds tier icons, lowest tier first (a fancier scroll each tier).
local TIER_ICONS = {
    "Interface\\Icons\\INV_Scroll_01",
    "Interface\\Icons\\INV_Scroll_02",
    "Interface\\Icons\\INV_Scroll_05",
    "Interface\\Icons\\INV_Scroll_06",
}
SK.UI.TIER_ICONS = TIER_ICONS   -- the luck log uses the same ones
local ARROW_UP = "Interface\\Buttons\\Arrow-Up-Up"
local ARROW_DOWN = "Interface\\Buttons\\Arrow-Down-Up"

-- Hovering a Fellow Mages name: everything we know about them.
local function MageTooltip(tooltip, name, peer)
    tooltip:AddLine(CLASS_COLOR .. name .. "|r")
    if IsAuthor(name) then
        tooltip:AddLine("|TInterface\\Icons\\INV_Scroll_03:14:14:0:0|t " .. L["Made Scrollkeeper!"], 1, 0.82, 0)
    end
    if peer.level and peer.level > 0 then
        tooltip:AddLine(L["Level %d"]:format(peer.level), 1, 1, 1)
    end
    local skill = peer.skill or 0
    if peer.max and peer.max > 0 then
        tooltip:AddDoubleLine(L["Comprehension"], ("%d / %d"):format(skill, peer.max), 1, 0.82, 0, 1, 1, 1)
    else
        tooltip:AddDoubleLine(L["Comprehension"], tostring(skill), 1, 0.82, 0, 1, 1, 1)
    end

    local tiers, wanted = {}, {}
    for _, tier in ipairs(SK.TIERS) do
        if peer.tiers and peer.tiers[tier] then
            tiers[#tiers + 1] = tier
            wanted[tier] = true
        end
    end
    if #tiers > 0 then
        tooltip:AddDoubleLine(L["Levels from tiers"], table.concat(tiers, ", "), 1, 0.82, 0, 1, 1, 1)
    else
        tooltip:AddLine(L["Doesn't need any tier right now."], 0.6, 0.6, 0.6)
    end
    if peer.upgrades and #peer.upgrades > 0 then
        tooltip:AddDoubleLine(L["Weapon upgrades"], table.concat(peer.upgrades, ", "), 1, 0.82, 0, 0.64, 0.21, 0.93)
    end

    -- Untranslated scrolls in your bags they'd get a skill-up from.
    local yours = YourScrollsFor(peer)
    if yours > 0 then
        tooltip:AddLine(L["You have %d |4scroll:scrolls; they could use."]:format(yours), 0.25, 0.75, 0.25)
    end

    local source = peer.source and SOURCES[peer.source]
    if source then tooltip:AddDoubleLine(L["Heard through"], L[source], 0.6, 0.6, 0.6, 0.6, 0.6, 0.6) end
    if peer.version then tooltip:AddDoubleLine("Scrollkeeper", peer.version, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6) end
    tooltip:AddLine(L["Click: whisper  ·  Shift-click: put the name in the box you're typing in"], 0.6, 0.6, 0.6)
end

-- Builds the pane inside host, starting at (left, top). Returns the pane
-- and how tall it is.
function SK.UI.CreateNetworkPane(host, left, top, width, userRows, oddsRows)
    local pane = { selectedTier = 1, tierButtons = {}, regions = {} }
    local function Keep(region) table.insert(pane.regions, region) return region end
    local y = top

    local users = Keep(SK.UI.CreateHeader(host, L["Fellow Mages"], width))
    users:SetPoint("TOPLEFT", left, y)
    y = y - 26

    -- Small sort icons on the right of the header: click one to sort by
    -- it, again to flip it. The active one glows and shows an arrow.
    pane.sortButtons = {}
    for i, mode in ipairs(MAGE_SORT_ORDER) do
        local button = Keep(CreateFrame("Button", nil, host))
        button:SetSize(16, 16)
        button:SetFrameLevel(users:GetFrameLevel() + 2)
        button:SetPoint("RIGHT", users, "RIGHT", -6 - (#MAGE_SORT_ORDER - i) * 19, 0)
        button:SetNormalTexture(MAGE_SORTS[mode].icon)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button.glow = button:CreateTexture(nil, "OVERLAY")
        button.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        button.glow:SetBlendMode("ADD")
        button.glow:SetAllPoints()
        button.arrow = button:CreateTexture(nil, "OVERLAY", nil, 2)
        button.arrow:SetSize(10, 10)
        button.arrow:SetPoint("BOTTOMRIGHT", 4, -4)
        if mode == "mine" then
            -- Right-click: only show mages who could use your scrolls.
            button.check = button:CreateTexture(nil, "OVERLAY", nil, 3)
            button.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            button.check:SetSize(14, 14)
            button.check:SetPoint("TOPRIGHT", 6, 6)
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        end
        button:SetScript("OnClick", function(self, mouseButton)
            if mode == "mine" and mouseButton == "RightButton" then
                -- Turning the filter on also switches to this sort.
                SK.db.mageOnlyMine = not (SK.db.mageOnlyMine and SK.db.mageSort == "mine")
                if SK.db.mageOnlyMine and SK.db.mageSort ~= "mine" then
                    SK.db.mageSort, SK.db.mageSortReversed = "mine", false
                end
            elseif (SK.db.mageSort or "skill") == mode then
                SK.db.mageSortReversed = not SK.db.mageSortReversed
            else
                SK.db.mageSort, SK.db.mageSortReversed = mode, false
            end
            SK.RefreshNetwork()
            local onEnter = self:GetScript("OnEnter")
            if onEnter and GameTooltip:IsOwned(self) then onEnter(self) end
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L["Sort: "] .. L[MAGE_SORTS[mode].label])
            GameTooltip:AddLine(L[MAGE_SORTS[mode].tip], 1, 1, 1, true)
            GameTooltip:AddLine(L["Click again to flip the order."], 0.6, 0.6, 0.6)
            if mode == "mine" then
                GameTooltip:AddLine((SK.db.mageOnlyMine and SK.db.mageSort == "mine")
                    and L["Right-click: show everyone again."]
                    or L["Right-click: only mages who could use your scrolls."], 0.25, 0.75, 0.25)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        pane.sortButtons[mode] = button
    end

    -- Two-line rows (name, then skill and needs) in the same space.
    pane.users = SK.UI.CreateScrollList(host, width, math.max(1, math.floor(userRows * ROW_HEIGHT / 30)), true)
    pane.users:SetPoint("TOPLEFT", left, y)
    Keep(pane.users.scroll)
    y = y - userRows * ROW_HEIGHT - 10

    local odds =Keep(SK.UI.CreateHeader(host, L["Community Odds"], width))
    odds:SetPoint("TOPLEFT", left, y)
    y = y - 28
    -- One scroll icon per tier with its number on it, like a stack count.
    -- The picked one glows; the others are grayed out.
    local slot = width / #SK.TIERS
    for i, tier in ipairs(SK.TIERS) do
        local button = Keep(CreateFrame("Button", nil, host))
        button:SetSize(22, 22)
        button:SetPoint("TOPLEFT", left + (i - 1) * slot + (slot - 22) / 2, y)
        button:SetNormalTexture(TIER_ICONS[i] or TIER_ICONS[1])
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button.glow = button:CreateTexture(nil, "OVERLAY")
        button.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        button.glow:SetBlendMode("ADD")
        button.glow:SetAllPoints()
        button.number = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        button.number:SetPoint("BOTTOMRIGHT", 3, -2)
        button.number:SetText(tier)
        button:SetScript("OnClick", function()
            pane.selectedTier = tier
            pane.odds.scroll:SetVerticalScroll(0)   -- a new tier starts at the top
            pane:Refresh()
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L["Tier "] .. tier)
            GameTooltip:AddLine(L["What tier %d scrolls turned into, from everyone's deciphers."]:format(tier), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        pane.tierButtons[tier] = button
    end
    y = y - 28
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
        local sortMode = MAGE_SORTS[SK.db.mageSort or ""] and SK.db.mageSort or "skill"
        -- The My scrolls filter (right-click) only applies while sorting by
        -- My scrolls; it's remembered for the next time you pick that sort.
        local onlyMine = SK.db.mageOnlyMine and sortMode == "mine" or false
        local peers = {}
        for _, entry in ipairs(SK.PeerList()) do
            if entry.peer and entry.peer.class == "MAGE" then
                entry.yours = YourScrollsFor(entry.peer)
                if not onlyMine or entry.yours > 0 then peers[#peers + 1] = entry end
            end
        end
        local reversed = SK.db.mageSortReversed and true or false
        local less = MAGE_SORTS[sortMode].less
        table.sort(peers, reversed and function(a, b) return less(b, a) end or less)
        for mode, button in pairs(self.sortButtons) do
            local active = mode == sortMode
            button.glow:SetShown(active)
            button.arrow:SetShown(active)
            button.arrow:SetTexture(reversed and ARROW_DOWN or ARROW_UP)
            SK.UI.Desaturate(button, not active and not (button.check and onlyMine))
            if button.check then button.check:SetShown(onlyMine) end
        end
        -- Anonymous players aren't named, but show that they're there
        -- (not while filtering: we can't tell what they need).
        local anonymous = not onlyMine and SK.AnonymousCount and SK.AnonymousCount() or 0
        if anonymous > 0 then peers[#peers + 1] = { anonymous = anonymous } end

        self.users:SetRows(peers, function(row, entry)
            row.itemID = nil
            row.tipFunc, row.onClick = nil, nil
            local peer = entry.peer
            if not entry.anonymous then
                row.tipFunc = function(tooltip) MageTooltip(tooltip, entry.name, peer) end
                row.onClick = function()
                    local name = SK.Net and SK.Net.ShortName and SK.Net.ShortName(entry.name) or entry.name
                    -- Shift-click: the name goes into whatever box you're
                    -- typing in (chat, mail To:...). Click: a whisper.
                    if IsShiftKeyDown and IsShiftKeyDown() then
                        local box = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
                        if box and box.Insert then box:Insert(name)
                        elseif ChatEdit_InsertLink then ChatEdit_InsertLink(name) end
                    elseif ChatFrame_OpenChat then
                        ChatFrame_OpenChat("/w " .. name .. " ")
                    end
                end
            end
            if entry.anonymous then
                row.label:SetText("|cff808080" .. L["Anonymous"] .. "|r")
                row.sub:SetText("|cff808080" .. L["+%d |4player:players;"]:format(entry.anonymous) .. "|r")
            else
                local tiers = {}
                for _, tier in ipairs(SK.TIERS) do
                    if peer.tiers[tier] then tiers[#tiers + 1] = tier end
                end
                local needs = #tiers > 0 and (L["needs "] .. table.concat(tiers, ", ")) or ("|cff808080" .. L["needs none"] .. "|r")
                local upgrade = #peer.upgrades > 0 and ("  ·  |cffa335ee" .. table.concat(peer.upgrades, ", ") .. "|r") or ""
                row.label:SetText(CLASS_COLOR .. entry.name .. "|r")
                row.sub:SetText(L["|cffffd100%d|r skill"]:format(peer.skill or 0) .. "  ·  " .. needs .. upgrade)
            end
        end, onlyMine and L["Nobody here could use the scrolls in your bags. Right-click the scroll icon to show everyone."]
            or L["No one yet. Guild and group members running Scrollkeeper show up here within a minute of logging in."])

        for tier, button in pairs(self.tierButtons) do
            local active = tier == self.selectedTier
            button.glow:SetShown(active)
            SK.UI.Desaturate(button, not active)
            button.number:SetTextColor(active and 1 or 0.6, active and 0.82 or 0.6, active and 0 or 0.6)
        end
        local odds, total, players = SK.CommunityOdds(self.selectedTier)
        -- Standard scrolls (Scroll of Strength...) go in one row, and hovering
        -- it lists each one, unless the setting lists them one by one.
        -- Percentages stay the same either way.
        local kept, merged = {}, nil
        for _, entry in ipairs(odds) do
            if SK.db.oddsStandard or SK.IsMageScroll(entry.itemID, entry.name) then
                kept[#kept + 1] = entry
            else
                merged = merged or { standard = true, count = 0, share = 0, parts = {} }
                merged.count = merged.count + entry.count
                merged.share = merged.share + entry.share
                merged.parts[#merged.parts + 1] = entry
            end
        end
        if merged then
            kept[#kept + 1] = merged
            table.sort(kept, function(a, b) return a.count > b.count end)
        end
        odds = kept
        self.odds:SetRows(odds, function(row, entry)
            row.itemID = entry.itemID
            row.tipTitle, row.tipLines = nil, nil
            row.tipCount = L["Community: %d deciphered (%.1f%%)"]:format(entry.count, entry.share * 100)
            if entry.standard then
                row.label:SetText("|TInterface\\Icons\\INV_Scroll_03:14:14:0:0|t |cffffffff" .. L["Standard Scrolls"] .. "|r")
                row.tipTitle = L["Standard Scrolls"]
                row.tipLines = {}
                for _, part in ipairs(entry.parts) do
                    row.tipLines[#row.tipLines + 1] = { SK.UI.ItemLabel(part.itemID, part.name),
                        ("%d  %.1f%%"):format(part.count, part.share * 100) }
                end
            else
                row.label:SetText(SK.UI.ItemLabel(entry.itemID, (entry.name:gsub("^Scroll of ", ""))))
            end
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
SK.Listen("BAGS_CHANGED", function() SK.RefreshNetwork() end)   -- "My scrolls" counts

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
