-- Scrollkeeper: UI/Network.lua
-- The Network window (/sk net): other Scrollkeeper users you can hear,
-- the community's odds for each scroll tier, and who holds a weapon
-- upgrade scroll. /sk demo fills it with made-up players to try it out.

local _, SK = ...

local WIDTH, HEIGHT = 300, 500
local LEFT = 12
local INNER = WIDTH - LEFT * 2
local ROW_HEIGHT = 16
local MAX_ROWS = 8

local window
local mageRows, oddsRows = {}, {}
local tierButtons = {}
local selectedTier = 1

------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------

local function Header(text, y)
    local ok, header = pcall(CreateFrame, "Frame", nil, window, "CharacterStatFrameCategoryTemplate")
    if not (ok and header and type(header.Title) == "table") then
        header = CreateFrame("Frame", nil, window)
        local background = header:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.35, 0.22, 0.08, 0.85)
        header.Title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        header.Title:SetPoint("CENTER")
    end
    header.Title:SetText(text)
    header:SetSize(INNER, 22)
    header:SetPoint("TOPLEFT", LEFT, y)
    return header
end

local function Row(y, striped)
    local row = CreateFrame("Frame", nil, window)
    row:SetSize(INNER, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", LEFT, y)
    if striped then
        local stripe = row:CreateTexture(nil, "BACKGROUND")
        stripe:SetAllPoints()
        stripe:SetColorTexture(0.45, 0.32, 0.12, 0.18)
    end
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetPoint("LEFT", 6, 0)
    row.label:SetWidth(INNER * 0.5)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetPoint("RIGHT", -6, 0)
    row.value:SetJustifyH("RIGHT")
    return row
end

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
    window:SetTitle("Scrollkeeper Network")
    tinsert(UISpecialFrames, "ScrollkeeperNetworkFrame")   -- Escape closes it

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    background:SetColorTexture(0.05, 0.05, 0.06, 0.95)

    window.summary = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.summary:SetPoint("TOPLEFT", 62, -32)
    window.summary:SetPoint("RIGHT", window, "RIGHT", -12, 0)
    window.summary:SetJustifyH("CENTER")

    local y = -62
    Header("Scrollkeeper Users", y)
    y = y - 24
    for i = 1, MAX_ROWS do
        mageRows[i] = Row(y, i % 2 == 1)
        y = y - ROW_HEIGHT
    end
    window.more = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.more:SetPoint("TOPLEFT", LEFT + 6, y - 2)
    y = y - 20

    Header("Community Odds", y)
    y = y - 28
    for i, tier in ipairs(SK.TIERS) do
        local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        button:SetSize((INNER - 6) / #SK.TIERS, 20)
        button:SetPoint("TOPLEFT", LEFT + (i - 1) * ((INNER - 6) / #SK.TIERS + 2), y)
        button:SetText("Tier " .. tier)
        button:SetScript("OnClick", function()
            selectedTier = tier
            SK.RefreshNetwork()
        end)
        tierButtons[tier] = button
    end
    y = y - 26
    for i = 1, MAX_ROWS do
        oddsRows[i] = Row(y, i % 2 == 1)
        y = y - ROW_HEIGHT
    end
    window.oddsNote = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.oddsNote:SetPoint("TOPLEFT", LEFT + 6, y - 2)
    window.oddsNote:SetWidth(INNER - 12)
    window.oddsNote:SetJustifyH("LEFT")

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

local CLASS_COLOR = "|cff69ccf0"

function SK.RefreshNetwork()
    if not (window and window:IsShown()) then return end
    local peers = SK.PeerList()

    local demo = SK.demoCommunity and " |cffff8040(demo)|r" or ""
    window.summary:SetText(("|cffffffff%d|r heard from%s"):format(#peers, demo))

    -- Users
    for i, row in ipairs(mageRows) do
        local entry = peers[i]
        if entry then
            local peer = entry.peer
            if peer.class == "MAGE" then
                local tiers = {}
                for _, tier in ipairs(SK.TIERS) do
                    if peer.tiers[tier] then tiers[#tiers + 1] = tier end
                end
                local needs = #tiers > 0 and ("needs " .. table.concat(tiers, ", ")) or "|cff808080needs none|r"
                local upgrade = #peer.upgrades > 0 and (" |cffa335ee" .. table.concat(peer.upgrades, ", ") .. "|r") or ""
                row.label:SetText(CLASS_COLOR .. entry.name .. "|r  " .. peer.skill)
                row.value:SetText(needs .. upgrade)
            else
                row.label:SetText(entry.name)
                row.value:SetText("|cff808080not a mage|r")
            end
            row:Show()
        else
            row:Hide()
        end
    end
    if #peers == 0 then
        window.more:SetText("No one yet. Others in your guild or group with Scrollkeeper appear here.")
    elseif #peers > MAX_ROWS then
        window.more:SetText(("and %d more"):format(#peers - MAX_ROWS))
    else
        window.more:SetText("")
    end

    -- Odds
    for tier, button in pairs(tierButtons) do
        if tier == selectedTier then button:LockHighlight() else button:UnlockHighlight() end
    end
    local odds, total, players = SK.CommunityOdds(selectedTier)
    for i, row in ipairs(oddsRows) do
        local entry = odds[i]
        if entry then
            row.label:SetText(entry.name)
            row.value:SetText(("%d  |cffffffff%.1f%%|r"):format(entry.count, entry.share * 100))
            row:Show()
        else
            row:Hide()
        end
    end
    if total == 0 then
        window.oddsNote:SetText(("No tier %d scrolls deciphered yet."):format(selectedTier))
    else
        window.oddsNote:SetText(("%d deciphered by %d |4player:players;. More players, better odds."):format(total, players))
    end

    local sharing = SK.db.share and "|cff40ff40on|r" or "|cffff6666off|r"
    window.footer:SetText("Sharing " .. sharing .. "  ·  scroll data only  ·  /sk options")
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
        SK.Print("demo off.")
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
            [213564] = "Scroll of Minor Evocation", [277483] = "Scroll of Frog Familiar",
            [-1] = "Scroll of Comprehension", [-2] = "Scroll of Imbue Lesser Flame",
            [-3] = "Scroll of Rat Familiar", [-4] = "Scroll of Imbue Chillknife",
            [-5] = "Scroll of Cryoblast", [-6] = "Scroll of Polymorph: Odd Melon",
            [-7] = "Scroll of the Saber", [-8] = "Scroll of Imbue Frost",
            [-9] = "Scroll of Cat Familiar", [-10] = "Scroll of Khadgar's Unlocking",
            [-11] = "Scroll of the Blade",
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
        SK.Print("demo on: made-up players and odds (never sent or saved). /sk demo again to turn it off.")
    end
    SK.Send("PEERS_CHANGED")
    SK.Send("COMMUNITY_CHANGED")
    SK.Send("DROPS_CHANGED")
    SK.Send("BAGS_CHANGED", SK.bags, SK.bags)
end
