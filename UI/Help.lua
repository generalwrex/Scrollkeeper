-- Scrollkeeper: UI/Help.lua
-- A red "?" in the title bar of every Scrollkeeper window. Point at it
-- for what the window is and how to use it; click it to keep that open
-- beside the window while you try things (click again, or its X, to
-- close). Turn the "?" off in /sk options > Panel.

local _, SK = ...
local L = SK.L
SK.UI = SK.UI or {}

-- What each window says: a title and one line per point.
SK.HELP = {
    panel = { "The panel", {
        "Your Comprehension skill, and what you can decipher right now.",
        "Decipher: Ready is what you can decipher, Skill-ups what can raise your skill, Too hard what needs more skill. Decipher next scroll does the best one first.",
        "Your Scrolls: click one to use it. Right-click the Familiar or Imbue button for all of that kind, and star one to pin it.",
        "Study: needs a Light Feather and a library. The bar shows when it's ready again.",
        "The buttons along the top open the other windows. The size button switches between Simple, Advanced and Title only.",
        "The gear opens the settings.",
    } },
    bag = { "Scroll Bag", {
        "Every deciphered mage scroll you have, in your bags, bank and mail (bank and mail as of your last visit).",
        "Keep: how many to keep. More than that is Extra. Set aside: an imbue for a weapon you don't have.",
        "- and +: change the keep amount (Shift: 5). Click the number for keep all.",
        "Right-click a scroll: keep all or a number, protect it, pin it, don't set it aside, link it.",
        "Presets: pick one, or New preset to save your keep amounts under a name.",
        "Stack, Sell extras (at a vendor), Mail extras (at a mailbox), Deposit set aside (at the bank).",
    } },
    codex = { "Codex", {
        "Every mage scroll and library book in the game, and where they drop.",
        "The tabs on the right: Scrolls, Books, and Book rewards.",
        "Click a drop spot to put a waypoint on your map.",
    } },
    plan = { "Farming Plan", {
        "Out in the world: your next skill goal, about how many scrolls and how long, and the best zones to farm.",
        "Click a zone to open it on the map, or its arrow for a waypoint.",
        "At the auction house: the scrolls you'd still level from and their prices. Sort them, and click one to search for it.",
        "Prices come from Auctionator or TSM if you have one, otherwise from Scan scrolls.",
    } },
    log = { "Luck Log", {
        "What your deciphered scrolls turned into, one tier at a time.",
        "The top shows how many you've deciphered and how often it raised your skill.",
        "Click a tier icon to see that tier.",
    } },
    swap = { "Scroll Swap", {
        "Trade spare untranslated scrolls with other Scrollkeeper users.",
        "Scrolls you could get: people with spares in tiers you'd still level from.",
        "Who'd want yours: mages who'd level from your spares.",
        "Click a name for a whisper with a message ready to edit.",
    } },
    doors = { "Doorways", {
        "Get somewhere with Scroll of Liminal Passage: it teleports you to someone in your group, when you're both resting in an inn or a city.",
        "Left: pick a place. Right: people who can be your door there. Doors are Scrollkeeper users who offered; /who finds anyone else.",
        "The big button does the next step: Ask, Invite, Teleport, Leave group.",
        "Be a door: let others come to you while you rest.",
    } },
    fellowmages = { "Fellow Mages", {
        "Other mages running Scrollkeeper on your ruleset and faction, and what tiers they still level from.",
        "Click a mage to whisper them. Sort with the buttons at the top.",
        "Community Odds: what everyone's deciphers turned into. Account Stats: yours.",
    } },
    options = { "Settings", {
        "Everything Scrollkeeper can do differently, in sections down the left.",
        "Changes apply right away. Point at a setting for what it does.",
    } },
    alts = { "Your mages", {
        "Shown on your other characters: each of your mages, their skill, and when Study is ready.",
        "In your bags: scrolls this character carries that your mages can read. Mail them over.",
    } },
    backup = { "Backup", {
        "Copy all your Scrollkeeper data as text to keep somewhere safe, or paste a backup to restore it.",
    } },
    setup = { "Setup", {
        "A few questions to set Scrollkeeper up the way you like. Change any of them later in /sk options.",
    } },
}

local function Wanted() return not (SK.db and SK.db.helpButtons == false) end

local card
local function Card()
    if card then return card end
    card = CreateFrame("Frame", "ScrollkeeperHelpCard", UIParent, "BackdropTemplate")
    card:SetFrameStrata("DIALOG")
    card:SetClampedToScreen(true)
    card:SetWidth(280)
    card:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    card:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
    SK.UI.SkinBox(card, "accent")
    card:EnableMouse(true)
    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.title:SetPoint("TOPLEFT", 12, -10)
    card.title:SetPoint("RIGHT", -28, 0)
    card.title:SetJustifyH("LEFT")
    card.text = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.text:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -8)
    card.text:SetWidth(256)
    card.text:SetJustifyH("LEFT")
    card.text:SetSpacing(3)
    local close = CreateFrame("Button", nil, card, "UIPanelCloseButton")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -2, -2)
    card:Hide()
    tinsert(UISpecialFrames, "ScrollkeeperHelpCard")
    return card
end

local function Text(help)
    local lines = {}
    for _, line in ipairs(help[2]) do lines[#lines + 1] = "|cffff5050•|r " .. L[line] end
    return table.concat(lines, "\n\n")
end

-- Adds the "?" to a window (a key from SK.HELP).
function SK.UI.AddHelp(window, key)
    if not (window and SK.HELP[key]) or rawget(window, "skHelp") then return end
    local button = CreateFrame("Button", nil, window)
    button:SetSize(20, 20)
    button:SetPoint("TOPRIGHT", window, "TOPRIGHT", -26, -1)
    button:SetFrameLevel((window:GetFrameLevel() or 1) + 10)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    button.text:SetPoint("CENTER", 0, 0)
    button.text:SetText("?")
    button.text:SetTextColor(1, 0.25, 0.25)
    local font, size = button.text:GetFont()
    if font then button.text:SetFont(font, size or 16, "OUTLINE") end
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    button:SetScript("OnEnter", function(self)
        local help = SK.HELP[key]
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L[help[1]], 1, 0.82, 0)
        for _, line in ipairs(help[2]) do GameTooltip:AddLine("|cffff5050•|r " .. L[line], 1, 1, 1, true) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Click: keep this open beside the window."], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function()
        SK.Track("help." .. key)
        GameTooltip:Hide()
        local c = Card()
        if c:IsShown() and c.key == key then c:Hide() return end
        local help = SK.HELP[key]
        c.key = key
        c.title:SetText(L[help[1]])
        c.text:SetText(Text(help))
        c:SetHeight((c.text:GetStringHeight() or 100) + 46)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", window, "TOPRIGHT", 6, -10)
        c:Show()
    end)
    window:HookScript("OnHide", function() if card and card.key == key then card:Hide() end end)
    button:SetShown(Wanted())
    window.skHelp = button
    SK.UI.helpButtons = SK.UI.helpButtons or {}
    SK.UI.helpButtons[#SK.UI.helpButtons + 1] = button
end

-- The setting changed: show or hide every "?".
function SK.UI.ApplyHelpButtons()
    for _, button in ipairs(SK.UI.helpButtons or {}) do button:SetShown(Wanted()) end
    if card and not Wanted() then card:Hide() end
end
