-- Scrollkeeper: UI/Swap.lua
-- The scroll swap board (/sk swap).
--
-- Every Scrollkeeper user (any class) tells the network how many spare
-- untranslated scrolls they carry, by tier: scrolls that aren't a
-- skill-up for them. The board shows:
--   Scrolls you could get   people with spares in tiers you'd level from
--   Who'd want yours        mages who'd level from your spare tiers
-- Click a name to open a whisper to them with a message ready to edit.
--
-- Network message:  S|1:2,15:3    (tier:count of spares)

local _, SK = ...
local L = SK.L
local Net = SK.Net

local ROWS = 8

------------------------------------------------------------------------
-- Spares: mine, and everyone's
------------------------------------------------------------------------

-- [tier] = count of untranslated scrolls I carry that aren't a skill-up for me.
function SK.MySpares()
    local spares = {}
    local skill = SK.isMage and SK.GetComprehension()
    for _, scroll in ipairs(SK.bags.untranslated or {}) do
        local keep = false
        if skill and skill.effective >= scroll.needs then
            local chance = SK.SkillUpChance(scroll.needs, skill.rank)
            keep = chance and chance.gives or false
        end
        if not keep then spares[scroll.needs] = (spares[scroll.needs] or 0) + 1 end
    end
    return spares
end

local function SparesText(spares)
    local parts = {}
    for _, tier in ipairs(SK.TIERS) do
        if (spares[tier] or 0) > 0 then parts[#parts + 1] = tier .. ":" .. spares[tier] end
    end
    return table.concat(parts, ",")
end

local lastSent
local function SendSpares()
    local text = SparesText(SK.MySpares())
    if text == lastSent then return end
    lastSent = text
    Net.Send("S", text ~= "" and text or "-")
end
SK.SendSpares = SendSpares

local sendQueued
SK.Listen("BAGS_CHANGED", function()
    if sendQueued then return end
    sendQueued = true
    C_Timer.After(15, function() sendQueued = false SendSpares() end)
end)
SK.Listen("NET_READY", function() C_Timer.After(25, function() lastSent = nil SendSpares() end) end)
-- Answer "who's there?" with our spares (on the public channel at most
-- every 10 minutes: everyone else hears them when they change anyway).
local lastAnswer = 0
Net.Handle("Q", function(_, _, source)
    local small = source == "GUILD" or source == "PARTY" or source == "RAID" or source == "INSTANCE_CHAT"
    if not small and time() - lastAnswer < 600 then return end
    lastAnswer = time()
    C_Timer.After(6 + math.random() * 20, function() lastSent = nil SendSpares() end)
end)

Net.Handle("S", function(sender, f)
    local spares = {}
    for tier, count in (f[1] or ""):gmatch("(%d+):(%d+)") do
        tier, count = tonumber(tier), tonumber(count)
        if SK.TIER_RESULTS[tier] and count > 0 and count <= 200 then spares[tier] = count end
    end
    SK.spares = SK.spares or {}
    SK.spares[sender] = { tiers = spares, at = time() }
    SK.Send("SPARES_CHANGED")
end)

local function KindLabel(kind)
    local text = ({ group = "group", guild = "guild", friend = "friend", public = "Scrollkeeper user" })[kind]
    return text and L[text] or ""
end

-- People with spares I'd level from: list of { name, short, tiers = {tier = n}, total, kind }.
function SK.ScrollsICouldGet()
    local list = {}
    if not SK.isMage then return list end
    local skill = SK.GetComprehension()
    local freshPeers = {}
    for _, entry in ipairs(SK.PeerList and SK.PeerList() or {}) do freshPeers[entry.name] = entry end
    for sender, spare in pairs(SK.spares or {}) do
        local short = Net.ShortName(sender)
        if freshPeers[short] and not Net.IsMe(sender) then
            local tiers, total = {}, 0
            for tier, count in pairs(spare.tiers) do
                local chance = skill.effective >= tier and SK.SkillUpChance(tier, skill.rank)
                if chance and chance.gives then tiers[tier], total = count, total + count end
            end
            if total > 0 then
                local peer = SK.peers[sender] or {}
                local kind = peer.source == "GUILD" and "guild" or peer.source == "WHISPER" and "friend"
                    or ((peer.source == "PARTY" or peer.source == "RAID") and "group") or "public"
                list[#list + 1] = { name = sender, short = short, tiers = tiers, total = total, kind = kind }
            end
        end
    end
    table.sort(list, function(a, b) return a.total > b.total end)
    return list
end

-- Mages who'd level from my spares: list of { name, short, tiers = {tier = n}, total, kind }.
function SK.WhoWantsMine()
    local list, spares = {}, SK.MySpares()
    for _, mage in ipairs(SK.FreshMages and SK.FreshMages() or {}) do
        local tiers, total = {}, 0
        for tier, count in pairs(spares) do
            if mage.tiers[tier] then tiers[tier], total = count, total + count end
        end
        if total > 0 then
            list[#list + 1] = { name = mage.name, short = mage.short, tiers = tiers, total = total, kind = mage.kind }
        end
    end
    table.sort(list, function(a, b) return a.total > b.total end)
    return list
end

local function TiersText(tiers)
    local parts = {}
    for _, tier in ipairs(SK.TIERS) do
        if tiers[tier] then parts[#parts + 1] = L["%d tier %d"]:format(tiers[tier], tier) end
    end
    return table.concat(parts, ", ")
end

------------------------------------------------------------------------
-- Whispering
------------------------------------------------------------------------

local function OpenWhisper(person, asking)
    local tiers = {}
    for _, tier in ipairs(SK.TIERS) do if person.tiers[tier] then tiers[#tiers + 1] = tier end end
    local text = asking
        and L["Hey! Scrollkeeper says you have spare tier %s scrolls. Could I have one? Happy to pay or trade :)"]:format(table.concat(tiers, "/"))
        or L["Hey! I've got spare tier %s scrolls you'd get skill-ups from, want them?"]:format(table.concat(tiers, "/"))
    if ChatFrame_OpenChat then
        -- person.name is the sender name, which can include a title on
        -- Forever; whisper their real name.
        local target = SK.ContactName and SK.ContactName(person.name) or person.name
        ChatFrame_OpenChat(("/w %s %s"):format(target, text))
    end
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------

local window

local function Build()
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperSwapFrame", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperSwapFrame", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if self.TitleText then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(330, 420)
    window:SetPoint("CENTER", 200, 0)
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetTitle(L["Scrollkeeper: Scroll Swap"])
    if window.SetPortraitToAsset then window:SetPortraitToAsset("Interface\\Icons\\INV_Scroll_03") end
    tinsert(UISpecialFrames, "ScrollkeeperSwapFrame")

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    SK.UI.Background(background)

    local width = 300
    local top = SK.UI.CreateHeader(window, L["Scrolls you could get"], width)
    top:SetPoint("TOPLEFT", 15, -64)
    window.get = SK.UI.CreateScrollList(window, width, ROWS)
    window.get:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -4)

    local bottom = SK.UI.CreateHeader(window, L["Who'd want yours"], width)
    bottom:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -(ROWS * 16 + 16))
    window.give = SK.UI.CreateScrollList(window, width, ROWS)
    window.give:SetPoint("TOPLEFT", bottom, "BOTTOMLEFT", 0, -4)

    local note = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 16, 14)
    note:SetPoint("RIGHT", window, "RIGHT", -16, 0)
    note:SetJustifyH("LEFT")
    note:SetText(L["Click a name to whisper them. Only Scrollkeeper users show up here."])

    window:SetScript("OnShow", function() SK.RefreshSwap() end)
    window:Hide()   -- new frames start shown; the first /sk swap would hide it instead
end

local function Clickable(row, person, asking)
    row.itemID = nil
    row.person = person
    row:SetScript("OnMouseUp", function(self) if self.person then SK.Track("swap.whisper") OpenWhisper(self.person, asking) end end)
end

function SK.RefreshSwap()
    if not (window and window:IsShown()) then return end
    window.get:SetRows(SK.ScrollsICouldGet(), function(row, person)
        Clickable(row, person, true)
        row.label:SetText(person.short .. "  |cff808080" .. KindLabel(person.kind) .. "|r")
        row.value:SetText(TiersText(person.tiers))
    end, SK.isMage and L["Nobody online has spare scrolls you'd level from yet."] or L["Only mages get scrolls from others."])
    window.give:SetRows(SK.WhoWantsMine(), function(row, person)
        Clickable(row, person, false)
        row.label:SetText(person.short .. "  |cff808080" .. KindLabel(person.kind) .. "|r")
        row.value:SetText(TiersText(person.tiers))
    end, L["No mage online would level from your spare scrolls right now."])
end

function SK.ToggleSwap()
    if not SK.ModuleOn("Swap") then
        SK.Print(L["%s is turned off. Turn it on in /sk options (Modules)."]:format(L["Scroll Swap"]))
        return
    end
    if not window then Build() end
    window:SetShown(not window:IsShown())
end

SK.Listen("SPARES_CHANGED", SK.RefreshSwap)
SK.Listen("PEERS_CHANGED", SK.RefreshSwap)
SK.Listen("BAGS_CHANGED", SK.RefreshSwap)
