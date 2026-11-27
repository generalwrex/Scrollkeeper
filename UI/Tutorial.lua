-- Scrollkeeper: UI/Tutorial.lua
-- The tutorial (/sk tutorial): the mage scroll system from the start, a
-- page at a time (Back / Next), with a "Show me" button that opens the
-- window for that part. Shown once to new players after setup; everyone
-- else gets a chat line about it once.
-- (Idea: Navacado. Facts checked by Natop.)

local _, SK = ...
local L = SK.L

local WIDTH, HEIGHT = 520, 380
local window, page = nil, 1

local function Icon(name) return "Interface\\Icons\\" .. name end

-- Each page: title, icon, text (a function, so numbers come from the
-- data), and what "Show me" opens.
local PAGES = {
    { "Welcome, mage!", Icon("INV_Misc_Book_09"), function()
        return L["Comprehension is a skill only mages have. You raise it by deciphering untranslated scrolls, and the scrolls you get (from deciphering, or from Studying at a library) are spells you can use: weapon imbues, familiars, and one-time spells.\n\nThis quick tour explains how it all works, and where Scrollkeeper helps. Back and Next to flip through, and Show me to open that part."]
    end },
    { "Untranslated scrolls", Icon("INV_Scroll_03"), function()
        local lines = {}
        for _, tier in ipairs(SK.TIERS or {}) do
            lines[#lines + 1] = L["  Tier %d: needs %d skill to decipher, and level %d to use what it becomes"]:format(tier, tier, (SK.TIER_USE_LEVEL or {})[tier] or 0)
        end
        return L["Untranslated scrolls drop all over the world, in tiers:"] .. "\n\n" .. table.concat(lines, "\n")
            .. "\n\n" .. L["The Farming Plan shows where each tier drops, from what every Scrollkeeper mage has found."]
    end, function() SK.TogglePlan() end },
    { "Deciphering", Icon("INV_Inscription_Scroll"), function()
        return L["Deciphering turns an untranslated scroll into a random spell scroll from its tier, and can raise your skill. Like professions, each tier has a color for you: orange always gives a point, yellow and green sometimes, gray never.\n\nThe Decipher button on the panel picks your best scroll first. And sometimes it backfires and turns you into a sheep. It happens to everyone (the Luck Log counts it)."]
    end, function() SK.ToggleLog() end },
    { "Imbues", Icon("Spell_Fire_FlameTounge"), function()
        return L["Imbue scrolls put a magic buff on your weapon, like flame or frost damage. Each one is for certain kinds of weapons, and they work together with weapon oils: a Wizard Oil or Mana Oil can go on too.\n\nScrollkeeper puts a gold outline on the imbue for the weapon you're holding, and clicking an imbue on the panel puts it straight on your weapon. It can also tell you when it wears off."]
    end, function() SK.TogglePanel() end },
    { "Familiars", Icon("Ability_Hunter_Pet_Cat"), function()
        return L["Familiar scrolls summon a little companion, like a Rat, a Frog or a Cat. While it's out, it gives you a buff: the Cat gives you 12 Intellect, for example.\n\nScrollkeeper shows your familiar on the panel and pops up when it's gone (or a few minutes before), if you have another scroll for it."]
    end, function() SK.TogglePanel() end },
    { "Spells for a pinch", Icon("Spell_Frost_FrostNova"), function()
        return L["The rest are one-time spells: combat ones like Cryoblast and Polymorph: Odd Melon, and handy ones like Scroll of Liminal Passage. Read one and it's used up.\n\nThe Codex lists every scroll with what it does (in your language), how many you have, and which tier it comes from."]
    end, function() SK.ToggleGuide() end },
    { "Study", Icon("INV_Feather_04"), function()
        return L["Study takes a Light Feather and has to be done in a library, once an hour: it gives you 2 or 3 deciphered scrolls from your level range, no untranslated scroll needed.\n\nThe Horde's library is the Magic Quarter in Undercity, the Alliance's is the Wizard's Sanctum in Stormwind. Both are pinned on your map, the panel shows when Study is ready, and clicking Study anywhere else opens the map to yours."]
    end, function() if WorldMapFrame and ToggleWorldMap then ToggleWorldMap() end end },
    { "Library books", Icon("INV_Misc_Book_11"), function()
        return L["40 books are hidden around the world. Hand them in to the librarians and they reward you as you go: titles at 10 and 20 books, and pendants, rings, a bow, a shield and more at 10, 20, 25 and 40.\n\nThe Codex's Books tab says where every book is (click one for a waypoint), which you've handed in, and how many until your next reward."]
    end, function() SK.ToggleGuide() end },
    { "Liminal Passage and Doorways", Icon("Spell_Arcane_PortalUndercity"), function()
        return L["Scroll of Liminal Passage takes you to someone in your party. You both have to be resting (in an inn or a city), and in a raid they have to be in your own subgroup. Only mages can read it.\n\nDoorways finds people for you: Scrollkeeper mages who offer to be a door (they invite you, and the invite is accepted for you), and anyone else resting there. Once you're grouped, a Teleport button pops up; if you aren't resting yet, it offers your city teleports and Hearthstone first.\n\nYou can be a door too: rest in an inn and turn on Be a door. Mages who whisper you (\"liminal pls\", \"inv\"...) get invited, and a mage's invite to you is accepted by itself."]
    end, function() SK.ToggleDoors() end },
    { "Fellow Mages", Icon("INV_Misc_GroupLooking"), function()
        return L["Everyone running Scrollkeeper helps each other. Fellow Mages lists the mages around you and which tiers they still need, the mailbox helper sends your spares to someone who can use them, the swap board matches up trades, and the Fellow Mages board is for posts, questions and doorways.\n\nIt all shares scroll info only, and you choose how much in the options."]
    end, function() SK.ToggleNetwork() end },
    { "That's it!", Icon("INV_Misc_Note_02"), function()
        return L["You're ready. A few last tips:\n\n  The ? button on every window explains that window.\n  /sk opens the panel, /sk options has (lots of) settings.\n  /sk tutorial brings this tour back.\n\nHave fun, and watch out for those sheep."]
    end, function() SK.ToggleOptions() end },
}

local function Show(n)
    page = math.max(1, math.min(#PAGES, n))
    local p = PAGES[page]
    window.icon:SetTexture(p[2])
    window.heading:SetText(L[p[1]])
    window.body:SetText(SK.FormatText and SK.FormatText(p[3]()) or p[3]())
    window.count:SetText(("%d / %d"):format(page, #PAGES))
    window.back:SetEnabled(page > 1)
    window.next:SetText(page < #PAGES and L["Next"] or L["Done"])
    window.show:SetShown(p[4] ~= nil)
    SK.Track("tutorial.page." .. page)
end

local function Build()
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperTutorial", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperTutorial", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if type(self.TitleText) == "table" then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetClampedToScreen(true)
    window:SetTitle(L["Scrollkeeper: Tutorial"])
    if window.SetPortraitToAsset then window:SetPortraitToAsset(Icon("INV_Misc_Book_09")) end
    tinsert(UISpecialFrames, "ScrollkeeperTutorial")
    local bg = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetPoint("TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", -2, 2)
    if SK.UI.Background then SK.UI.Background(bg) end

    window.icon = window:CreateTexture(nil, "ARTWORK")
    window.icon:SetSize(48, 48)
    window.icon:SetPoint("TOPLEFT", 24, -70)
    window.heading = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    window.heading:SetPoint("LEFT", window.icon, "RIGHT", 14, 0)
    window.heading:SetPoint("RIGHT", window, "RIGHT", -24, 0)
    window.heading:SetJustifyH("LEFT")
    window.body = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    window.body:SetPoint("TOPLEFT", window.icon, "BOTTOMLEFT", 0, -16)
    window.body:SetPoint("RIGHT", window, "RIGHT", -24, 0)
    window.body:SetJustifyH("LEFT")
    window.body:SetJustifyV("TOP")
    window.body:SetSpacing(3)

    local function Btn(text, width, onClick)
        local b = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        b:SetSize(width, 24)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        if SK.UI.SkinButton then SK.UI.SkinButton(b) end
        return b
    end
    window.back = Btn(L["Back"], 90, function() Show(page - 1) end)
    window.back:SetPoint("BOTTOMLEFT", 20, 16)
    window.next = Btn(L["Next"], 90, function()
        if page < #PAGES then Show(page + 1) else window:Hide() end
    end)
    window.next:SetPoint("BOTTOMRIGHT", -20, 16)
    window.show = Btn(L["Show me"], 110, function()
        local p = PAGES[page]
        if p[4] then SK.Safely("tutorial", p[4]) end
    end)
    window.show:SetPoint("BOTTOM", 0, 16)
    window.count = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.count:SetPoint("BOTTOM", window.show, "TOP", 0, 6)
    window:SetScript("OnHide", function() if SK.db then SK.db.tutorialSeen = true end end)
    window:Hide()
end

function SK.ToggleTutorial(from)
    if not window then Build() end
    if window:IsShown() then window:Hide() return end
    window:Show()
    Show(from or 1)
    SK.Track("tutorial.open")
end

-- New players get it right after setup (UI/Setup.lua). Everyone else: a
-- chat line once.
SK.Listen("READY", function()
    if not (SK.db and SK.isMage) or SK.db.tutorialSeen or SK.db.tutorialTold then return end
    C_Timer.After(12, function()
        if SK.db.tutorialSeen or SK.db.tutorialTold or (SK.InCombat and SK.InCombat()) then return end
        SK.db.tutorialTold = true
        do
            SK.Print(L["new: a quick tour of mage scrolls and how Scrollkeeper helps. Type /sk tutorial (thanks Navacado for the idea!)."])
        end
    end)
end)
