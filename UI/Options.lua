-- Scrollkeeper by generalwrex. Created 2026-11-15.
-- Read the LICENSE file before using any of this code.
-- Scrollkeeper: UI/Options.lua
-- Scrollkeeper's own settings window (/sk options, the gear on the panel,
-- right-click the minimap button). Sections down the left, their settings
-- on the right:
--
--   Panel, Pop-ups, Tooltips and chat, Sharing, Mailbox and auction house,
--   Scroll Bag, Modules, Map, Language, Backup, About
--
-- The game's Options > AddOns > Scrollkeeper page is a short note with a
-- button that opens this window.
--
-- Every setting is one entry in SECTIONS below: a checkbox, a choice, a
-- slider (- value +) or a button. Changing one runs Changed(key), which
-- tells the rest of the addon.

local _, SK = ...
local L = SK.L

SK.AUTHOR_CHARACTER = "Archmage Naage"

-- The dev team: { name, what they do }. Shown on the About page.
SK.TEAM = {
    { "Natop", "made Scrollkeeper (Archmage Naage)" },
    { "Curnil", "dev team: the scroll icon and Doorways were his ideas" },
}

-- People who helped: { name, what they did }. Shown on the About page.
SK.CREDITS = {
    { "Lofi Frostbeats", "Fellow Mage network user (RP-PvP Horde) who shared most of the community's tier 175 odds" },
    { "Magnus Magoo", "tested the board, Doorways and Fellow Mages with us" },
    { "Navacado", "the idea for a tutorial that explains the scrolls" },
    { "foundmonster", "reported Nethergarde Keep in Doorways (it has no inn)" },
    { "Count Turbo", "said \"DO IT!\" to the Fellow Mages board, so we did" },
    { "Everyone sharing scroll data", "every decipher you share makes the odds and drop spots better for all mages" },
}

SK.LINKS = {
    { "CurseForge", "https://www.curseforge.com/wow/addons/scrollkeeper" },
    { "Report a bug", "https://www.curseforge.com/wow/addons/scrollkeeper/comments" },
}

------------------------------------------------------------------------
-- What changing a setting does
------------------------------------------------------------------------

local function Changed(key)
    if SK.ApplyPanelSettings then SK.ApplyPanelSettings() end
    if key == "hideInCombat" and SK.UpdateCombatHiding then SK.UpdateCombatHiding() end
    if key == "sharing" then
        SK.SetSharing(SK.db.sharing)
        if SK.Net and SK.Net.UpdateChannel then SK.Net.UpdateChannel() end
        if SK.db.share and SK.SendHello then SK.SendHello() end
    end
    if key == "anonymous" and SK.SendHello then SK.SendHello() end
    if key == "scrollIcon" and SK.RefreshIcon then SK.RefreshIcon() end
    if key == "minimapButton" and SK.RefreshMinimapButton then SK.RefreshMinimapButton() end
    if (key == "liminalDoor" or key == "doorAutoInvite") and SK.SendDoor then SK.SendDoor(true) end
    if (key == "oddsStandard" or key == "offlineMinutes") and SK.RefreshNetwork then SK.RefreshNetwork() end
    if key == "language" then SK.Print(L["language changed. Type /reload to switch."]) end
    if key == "own" then SK.SetCharacterLayout(SK.charDB.own) end
    if (key == "theme" or key == "themeHoliday") and SK.UI.ApplyTheme then SK.UI.ApplyTheme() end
    if key == "helpButtons" and SK.UI.ApplyHelpButtons then SK.UI.ApplyHelpButtons() end
    if key:find("^board") then SK.Send("BOARD_CHANGED") end
    if key:find("^bag") or key:find("^liminal") or key:find("^module") then
        SK.Send("STASH_CHANGED")
        SK.Send("REMINDERS_CHANGED")
    end
    SK.Send("DROPS_CHANGED")
end
SK.OptionChanged = Changed

------------------------------------------------------------------------
-- The settings, section by section
--   { "check", key, label, tip, dependsOn = key }
--   { "choice", key, label, tip, choices = { { value, label, tip } } }
--   { "slider", key, label, tip, min, max, step, format }
--   { "button", label, buttonText, tip, run }
--   { "page", builder }   (Backup and About: their own layout)
-- `char = true` stores the setting for this character (SK.charDB).
------------------------------------------------------------------------

local function Percent(value) return ("%d%%"):format(math.floor(value * 100 + 0.5)) end
local function Minutes(value) return L["%d min"]:format(value) end

local MODULES = {
    { "Bag", "Scroll Bag", "Every deciphered scroll you own, keep or extra, and selling, mailing and banking the extras. Off: no window, bag marks, tooltip or chat notes." },
    { "Codex", "Codex", "Every scroll and what it does, and the 40 library books." },
    { "Plan", "Farming Plan", "Your next goal, where to farm, and auction house prices." },
    { "Log", "Luck Log", "What your deciphers turned into, next to everyone's odds." },
    { "Swap", "Scroll Swap", "Who has spare scrolls you'd level from, and who'd want yours." },
    { "Doors", "Doorways", "Getting around with Scroll of Liminal Passage, and the running-low warning." },
    { "Network", "Fellow Mages", "The Fellow Mages window (the Advanced view still shows them)." },
    { "Board", "Fellow Mages board", "The board button on the panel (/sk board still opens it). Its settings have their own page: Fellow Mages board." },
}

local SECTIONS = {
    { name = "Panel", icon = "Interface\\Icons\\INV_Scroll_03", items = {
        { "check", "showPanel", "Show the panel", "The window with your Comprehension, scrolls and Study timer. Mages only." },
        { "choice", "viewMode", "Panel view", "How much the panel shows. The size button on the panel switches between these too.", choices = {
            { "compact", "Simple", "Buttons, bars and your scrolls." },
            { "full", "Advanced", "Everything: all the numbers, sections and weapon upgrades." },
            { "mini", "Title only", "Just the title and your skill bar." } } },
        { "choice", "theme", "Theme", "How Scrollkeeper's windows look. Changes right away.", choices = {
            { "classic", "Classic", "The game's own windows: gold and stone frames, bronze section bars." },
            { "dark", "Dark", "Flat charcoal panels with thin gray borders and muted headers. No gold." },
            { "dusk", "Darker classic", "The game's window shapes, darkened: gray borders and charcoal section bars." },
            { "modern", "Modern", "Flat slate panels, square buttons and boxes with thin borders, a blue accent." } } },
        { "choice", "theme", "Holiday themes", "The Modern look in holiday colors, only during the holiday's months. When it's over, you're back on your everyday theme.", choices = {}, holidays = true },
        { "check", "themeHoliday", "Holiday themes automatically", "During a holiday, Scrollkeeper wears its holiday theme on its own, and goes back to your theme after. Off: only if you pick one above." },
        { "check", "helpButtons", "Help buttons", "A red ? in the corner of every Scrollkeeper window: point at it for what the window does, click it to keep that open beside the window." },
        { "slider", "scale", "Panel size", "How big the panel is.", 0.7, 1.5, 0.05, Percent },
        { "check", "own", "This character's own layout", "Panel position, size and view, the minimap button, the scroll icon and the pop-up's spot are saved for this character only. Everything else stays the same on all your characters.", char = true },
        { "check", "minimapButton", "Minimap button", "The round Scrollkeeper button on the edge of the minimap, with how many scrolls you can decipher. Left-click: panel. Right-click: settings. Drag to move it around." },
        { "check", "scrollIcon", "Scroll icon", "A small icon you can keep on screen. Click it for the most useful thing right now: Study when you're in a library, open a Bundle of Scrolls, or decipher your best scroll. Right-click it to open or close the panel in the view you picked above." },
        { "check", "hideInCombat", "Hide the panel in combat", "The panel hides when combat starts and comes back when it ends. (The X always closes it, even in combat.)" },
        { "check", "locked", "Lock position", "Stops the panel (and the scroll icon) from being dragged." },
        { "check", "showScrollBar", "Scroll buttons", "Adds a button to the panel for each kind of translated scroll in your bags. Click one to use it.", dependsOn = "showPanel" },
        { "button", "Panel position", "Move to middle", "Lost the panel off screen? This puts it back in the middle at normal size.",
            function() if SlashCmdList.SCROLLKEEPER then SlashCmdList.SCROLLKEEPER("reset") end end },
    } },
    { name = "Pop-ups", icon = "Interface\\Icons\\Spell_Fire_FlameTounge", items = {
        { "check", "reminderToast", "Imbue and familiar pop-up", "A small pop-up when your weapon imbue or familiar wears off and you have a scroll for it. Click it to use the scroll, right-click to pick another. Not in combat, and at most once every five minutes." },
        { "check", "expiringReminder", "Running-out pop-up", "A pop-up when your weapon imbue or familiar is about to run out and you have a scroll to renew it. Once each time, not in combat." },
        { "slider", "expiringMinutes", "Warn this long before", "How many minutes before your imbue or familiar runs out the running-out pop-up shows.", 1, 15, 1, Minutes, dependsOn = "expiringReminder" },
        { "check", "reminderInCombat", "Pop-ups in combat too", "Show the imbue and familiar pop-ups during a fight as well, in case one runs out mid-fight." },
        { "check", "imbueByUse", "Imbue pick: the one I use most", "Suggest the weapon imbue you use most, even if it's not for your spec. Off: an imbue for your spec always comes first (a Frost mage gets a Frost imbue). A pinned scroll always wins." },
        { "check", "familiarAnywhere", "Familiar pop-ups outside dungeons and raids", "Also remind you about your familiar out in the world. Flight paths make it vanish, so you may see this a lot." },
    } },
    { name = "Tooltips and chat", icon = "Interface\\Icons\\INV_Letter_15", items = {
        { "check", "showTooltips", "Tooltip lines", "Mages see whether they can decipher a scroll. Other classes see that it is a mage scroll." },
        { "check", "announce", "Decipher messages", "Prints a chat line such as \"deciphered: Scroll of Frog Familiar\"." },
        { "check", "chatHelper", "Chat notes", "When someone links a scroll in chat and asks who needs it, add a note only you see: is it a skill-up for you or your mages." },
    } },
    { name = "Sharing", icon = "Interface\\Icons\\INV_Misc_GroupLooking", items = {
        { "choice", "sharing", "Sharing", "What Scrollkeeper shares with other players: what scrolls became, where they drop, which libraries work and who needs which scrolls. Only scroll data is sent, never chat or gold.", choices = {
            { "full", "Full (recommended)", "Everything works. Other Scrollkeeper mages see your name and skill, so they can send you scrolls you need." },
            { "anon", "Anonymous", "Share with everyone, but your name isn't shown in their lists, so nobody can mail you scrolls from them." },
            { "none", "None (not recommended)", "Nothing is sent. No Fellow Mages or swap board, but each update's odds still show." } } },
        { "check", "shareUsage", "Share anonymous usage stats (recommended)", "Opt-in, off unless you turn it on. Counts which windows, buttons and settings get used, so we know which features people rely on most and can fix and improve those first. Totally anonymous: just counts under a random ID, plus your class, faction, game language, rough Comprehension skill and which bag and map addons you use, never your name, realm, guild, chat, gold, bags or where you are. Not sent when Sharing is None." },
        { "check", "themesShared", "Holiday themes from the network", "New holiday themes come from the Scrollkeeper team over the network, no update needed (they're only colors). Off: no new ones." },
        { "check", "showUnknownRuleset", "Fellow Mages: show old versions", "Mages on Scrollkeeper older than 1.2.0 don't say their ruleset, and the public channel reaches every ruleset, so they may not be on yours (whispers and mail won't reach them). Off: only listed when they're in your guild, group or friends." },
        { "choice", "rulesetPick", "Your ruleset", "Scrollkeeper reads it from your realm's name. Some realms don't say (or give no name): this is for characters there. Realms whose name says it always go by the name.", choices = {
            { "auto", "Automatic", "From your realm's name, or what mages on your realm say." },
            { "pve", "PvE", "" }, { "pvp", "PvP", "" }, { "rp", "RP", "" }, { "rppvp", "RP-PvP", "" } } },
        { "check", "liminalDoor", "Doorways: be a door", "While you rest in an inn or a city, mages on your server can ask to come to you with Scroll of Liminal Passage. You get a pop-up to invite them. /sk doors opens Doorways." },
        { "check", "doorGreet", "Doorways: say hi in party", "When someone joins your group to use you as a door, say a line in party (change it with Greeting... on Doorways).", dependsOn = "liminalDoor" },
        { "check", "doorGreetPlug", "Doorways: mention Scrollkeeper", "With the party hello, one more line: \"(Doorways is part of Scrollkeeper, a mage scroll addon on CurseForge.)\"", dependsOn = "doorGreet" },
        { "check", "doorTeleportPop", "Doorways: Teleport button pop-up", "When you're grouped with a door (someone you asked, a Scrollkeeper door, or someone you whispered in the last 10 minutes), a small Teleport button pops up so you don't have to find the scroll in your bags." },
        { "check", "doorWhisperInvite", "Doorways: answer whispers", "While you're a door, anyone who whispers you something like \"can I teleport to you?\" or \"liminal pls\" gets invited by themselves (no addon needed on their side). Add your own with Invite triggers... on Doorways.", dependsOn = "liminalDoor" },
        { "check", "doorAcceptMages", "Doorways: accept mages' invites", "While you're a door and resting, an invite from a mage is accepted by itself (they want to teleport to you). Invites from anyone else still show the usual box.", dependsOn = "liminalDoor" },
        { "check", "doorAutoInvite", "Doorways: skip the pop-up", "When a Scrollkeeper mage asks to come to you, invite them right away instead of asking you first with a pop-up (when you're not in a group, or lead one with room). At most 6 invites in 10 minutes.", dependsOn = "liminalDoor" },
        { "check", "oddsStandard", "Odds: list standard scrolls", "Community odds list standard scrolls (like Scroll of Strength) one by one. Off: they're merged into one Standard Scrolls row." },
        { "slider", "offlineMinutes", "Keep offline mages for", "When hovering a name in Fellow Mages finds that mage offline, their name turns gray and stays in the list this long.", 1, 15, 1, Minutes },
    } },
    { name = "Fellow Mages board", icon = "Interface\\Icons\\INV_Misc_Note_02", note = "The board itself is a module (Modules) and needs Sharing on.", items = {
        { "check", "boardOn", "Get and send posts", "Posts and replies from other Scrollkeeper mages, kept for 7 days (/sk board). Off: you don't get or send posts." },
        { "choice", "boardRulesets", "General posts from", "Trade, doorway and odds posts are always your ruleset only. This is for General posts and notices.", choices = {
            { "all", "All rulesets", "Mages on every ruleset, with their ruleset shown by their name." },
            { "mine", "Only my ruleset", "Just mages you could whisper or group with." } } },
        { "check", "textEmoji", "Show emojis", "Show :fire:, :sheep:, :skull: and the rest as icons in posts and replies. Off: you see them as typed.", dependsOn = "boardOn" },
        { "check", "textMarkdown", "Show formatting", "Show **bold**, *italic*, `code`, ~~strike~~, and - or > at the start as colors, a bullet or a quote. Off: you see the stars and marks as typed.", dependsOn = "boardOn" },
        { "check", "boardPingReplies", "Ping me about replies", "A line in chat when someone replies to your post, or to one you follow.", dependsOn = "boardOn" },
        { "check", "boardPingReacts", "Ping me about reactions", "A line in chat when someone reacts to your post or reply.", dependsOn = "boardOn" },
        { "check", "boardPingMentions", "Ping me about @mentions", "A line in chat when someone writes @ and your name in a post or reply.", dependsOn = "boardOn" },
        { "check", "boardPingSound", "Ping sound", "Play the whisper sound with board pings.", dependsOn = "boardOn" },
        { "check", "boardAutoFollow", "Follow posts I reply to", "Get reply pings for posts you've replied to, not just your own. You can follow or unfollow any post from its ••• menu.", dependsOn = "boardOn" },
        { "check", "boardShowOnline", "Show who's online", "A green dot by the name of mages who are online right now (heard from in the last 10 minutes), so you know who might answer.", dependsOn = "boardOn" },
        { "check", "boardClassColors", "Names in class colors", "Show each poster's name in their class color (alts of any class can post). Older Scrollkeepers don't send it, so some names stay plain.", dependsOn = "boardOn" },
        { "check", "boardStickyNotices", "Pin notices", "Team notices stay on top of every category.", dependsOn = "boardOn" },
        { "check", "boardHideDone", "Hide done posts", "Hide posts their author marked done (traded, found a door...).", dependsOn = "boardOn" },
        { "check", "boardWordFilter", "Word filter", "Show swear words as ****.", dependsOn = "boardOn" },
        { "choice", "boardFontSize", "Text size", "How big posts and replies are in the post pane.", dependsOn = "boardOn", choices = {
            { "small", "Small", "" }, { "normal", "Normal", "" }, { "large", "Large", "" } } },
        { "check", "boardNotify", "Tell me about new posts", "Say once a session in chat when the board has new posts.", dependsOn = "boardOn" },
    } },
    { name = "Mailbox and auction house", icon = "Interface\\Icons\\INV_Misc_Coin_01", items = {
        { "check", "mailHelper", "Mailbox helper", "At the mailbox, list your mages, guildies and friends who could use your spare scrolls. Click one to fill in the mail." },
        { "check", "mailIncludeMine", "Mailbox: offer scrolls I'd use too", "Also list mages who could use the scrolls you'd still level from yourself, marked so you know. Off: only scrolls you can't use.", dependsOn = "mailHelper" },
        { "check", "guildBankMarks", "Guild bank marks", "Put a colored dot on guild bank scrolls that you, your mages or a guildie would get a skill-up from." },
        { "check", "ahScanButton", "Auction house scan button", "Show a Scan scrolls button on the auction house. Prices you see are saved for tooltips either way." },
    } },
    { name = "Scroll Bag", icon = "Interface\\Icons\\INV_Misc_Bag_10", items = {
        { "check", "bagCountBank", "Count my bank", "The Scroll Bag counts what's in your bank too, as of your last visit." },
        { "check", "bagCountMail", "Count my mail", "The Scroll Bag counts scrolls in your mailbox too, as of the last time you opened it." },
        { "check", "bagFavoritesTop", "Favorites at the top", "Starred scrolls get their own Favorites group at the top of the Scroll Bag." },
        { "check", "bagShowMissing", "Show scrolls I have none of yet", "Scrolls you have none of show in their categories (orange), so you can set how many to keep before you get them. The chips on the Scroll Bag switch these too." },
        { "check", "bagShowTooHigh", "Show ones I can't use yet", "Scrolls your level is too low for, in red, with the level they need." },
        { "check", "bagShowOutleveled", "Show outleveled ones", "Scrolls from tiers you're past, in gray." },
        { "check", "bagSetAside", "Set aside imbues for weapons I don't have", "An imbue for a weapon you don't own (in your bags, bank or hands) is set aside instead of extra. Bank them with Deposit set aside." },
        { "check", "bagWeaponAlert", "Tell me about imbues for a new weapon", "When you equip or loot a kind of weapon you didn't have, say which imbues for it are waiting in your bank or mail." },
        { "check", "bagChatStatus", "Keep or extra in the decipher message", "The \"deciphered:\" chat line also says whether the new scroll is a keep, an extra or set aside." },
        { "check", "bagTooltip", "Keep or extra on scroll tooltips", "Deciphered scroll tooltips say how many you have, where, and whether they're extra." },
        { "check", "bagMarks", "Marks on scrolls in my bags", "A small colored corner on mage scrolls in your bags: green keep, red extra, orange part of the stack is extra, blue set aside. Works with the game's bags, AdiBags, Baganator, Bagnon, BetterBags and ArkInventory." },
        { "check", "bagJunk", "Extras count as junk in bag addons", "In bag addons with a junk list (Baganator), your extras count as junk, so its sell-junk button sells them too. Off by default: some people sell junk without looking." },
        { "check", "bagConfirm", "Ask before selling extras", "Sell extras shows what it'll sell and asks first." },
        { "check", "bagAllowDelete", "Delete extras button", "Adds a Delete extras button to the Scroll Bag. It always asks first." },
        { "choice", "bagNotYet", "Scrolls I can't use yet", "Deciphered scrolls above your level and undeciphered ones above your Comprehension can wait in the bank. When a level or skill-up makes them usable, chat tells you, and they come back out at the bank.", choices = {
            { "ask", "Ask at the bank", "When you open your bank, ask before banking them or taking them back out." },
            { "auto", "Do it by itself", "Bank them and take them back out on their own." },
            { "off", "Off", "Leave them where they are." },
        } },
        { "check", "bagAutoSyncBank", "Sync the bank automatically", "When you open your bank, Sync bank extras runs on its own, so your bags end up with your keep amounts. Also a check on the Scroll Bag." },
        { "check", "bagAutoSyncMail", "Sync mail automatically", "When you open your mailbox, Sync mail extras runs on its own once your mail comes in." },
        { "check", "bagHideErrors", "Hide the game's errors while moving scrolls", "While the Scroll Bag stacks, sells, syncs or deposits, the game's red messages like \"Couldn't split those items\" (and their sound) are hidden. Scrollkeeper still stops and tells you in chat if a move really won't go." },
        { "slider", "liminalLow", "Liminal Passage low at", "The panel and Doorways warn you (and it's said once in chat) when you carry this many Scroll of Liminal Passage or fewer. 0 turns it off.", 0, 10, 1,
            function(value) return value == 0 and L["off"] or tostring(value) end },
        { "check", "liminalLowChat", "Liminal Passage low: say it in chat", "Also say it once in chat when you drop to that many." },
    } },
    { name = "Modules", icon = "Interface\\Icons\\INV_Misc_Gear_01", note = "Turn off what you don't use: its panel button goes away, and so does everything it adds.", items = {} },
    { name = "Map", icon = "Interface\\Icons\\INV_Misc_Map_01", items = {
        { "check", "mapPins", "Map pins", "Show libraries and the spots where untranslated scrolls dropped on the world map." },
        { "check", "mapDoors", "Map: doors (Doorways)", "A pin for each Scrollkeeper mage who's a door right now. Also a button on the map.", dependsOn = "mapPins" },
        { "check", "mapInns", "Map: inns (Doorways)", "Our own innkeeper pin on the map, on top of the game's, with how many doors are open there; click it to open Doorways on that town.", dependsOn = "mapPins" },
        { "check", "mapQuestieInns", "Inns from Questie", "With Questie installed, Doorways knows every innkeeper Questie does: an inn pin right on each one, in every zone. Questie isn't needed for anything else.", dependsOn = "mapInns" },
        { "slider", "mapPinScale", "Map pin size", "How big the scroll and book spots are on the map (libraries keep their size).", 0.5, 2, 0.1, Percent, dependsOn = "mapPins" },
    } },
    { name = "Language", icon = "Interface\\Icons\\INV_Misc_Note_02", items = {
        { "choice", "language", "Language", "Scrollkeeper's language. Spanish, French, German and Chinese were translated with AI, so fixes are welcome on GitHub. Takes effect after /reload.", choices = {} },
    } },
    { name = "Backup", icon = "Interface\\Icons\\INV_Misc_Book_09", page = "backup" },
    { name = "About", icon = "Interface\\Icons\\INV_Misc_QuestionMark", page = "about" },
}
local modulesSection
for _, section in ipairs(SECTIONS) do if section.name == "Modules" then modulesSection = section end end
for _, module in ipairs(MODULES) do
    table.insert(modulesSection.items, { "check", "module" .. module[1], module[2], module[3] })
end
SK.OPTION_SECTIONS = SECTIONS   -- for the test harness

------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------

local WIDTH, HEIGHT, NAV = 660, 520, 168
local CONTENT = WIDTH - NAV - 52
local window
local current = 1
local widgets = {}   -- what the shown section built: refreshed on change
local shownContent   -- the shown section's content frame

local function Store(item) return item.char and SK.charDB or SK.db end
local function Value(item) return Store(item)[item[2]] end
local function Set(item, value)
    Store(item)[item[2]] = value
    if SK.Track then SK.Track("set." .. item[2]) end
    Changed(item[2])
    for _, w in ipairs(widgets) do if w.Refresh then w:Refresh() end end
end

local function Enabled(item)
    return not item.dependsOn or SK.db[item.dependsOn] and true or false
end

-- A box holding a web address, ready to copy (the game can't open links).
local function CopyBox(parent, url)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(360, 20)
    box:SetAutoFocus(false)
    box:SetText(url)
    box:SetCursorPosition(0)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box:SetScript("OnMouseUp", function(self) self:SetFocus() self:HighlightText() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(url) self:HighlightText() end
    end)
    return box
end

local function Tip(parent, text, anchor, x)
    local tip = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tip:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, -2)
    tip:SetWidth(CONTENT - 40)
    tip:SetJustifyH("LEFT")
    tip:SetTextColor(0.7, 0.7, 0.7)
    tip:SetText(text or "")
    return tip
end

-- Each Make* puts one setting at y in the content frame and returns the
-- widget and how tall it is.

local function MakeCheck(content, item, y)
    local w = CreateFrame("Frame", nil, content)
    w:SetSize(CONTENT, 20)
    w:SetPoint("TOPLEFT", 0, y)
    local check = CreateFrame("CheckButton", nil, w, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", 0, 2)
    local label = w:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText(L[item[3]])
    local tip = Tip(w, L[item[4]], label, 0)
    check:SetScript("OnClick", function(self) Set(item, self:GetChecked() and true or false) end)
    function w:Refresh()
        check:SetChecked(Value(item) and true or false)
        local on = Enabled(item)
        if on then check:Enable() else check:Disable() end
        label:SetTextColor(on and 1 or 0.5, on and 0.82 or 0.5, on and 0 or 0.5)
    end
    w:Refresh()
    return w, 22 + (tip:GetStringHeight() or 12) + 10
end

local function MakeChoice(content, item, y)
    local w = CreateFrame("Frame", nil, content)
    w:SetSize(CONTENT, 20)
    w:SetPoint("TOPLEFT", 0, y)
    local label = w:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 4, 0)
    label:SetText(L[item[3]])
    local buttons, previous = {}, nil
    local row, rowX = 0, 0
    for i, choice in ipairs(item.choices) do
        local b = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
        b:SetText(L[choice[2]])
        local width = math.max(90, ((b:GetFontString() and b:GetFontString():GetStringWidth()) or 70) + 24)
        b:SetSize(width, 22)
        if rowX + width > CONTENT - 20 and i > 1 then row, rowX = row + 1, 0 end
        b:SetPoint("TOPLEFT", w, "TOPLEFT", 4 + rowX, -20 - row * 26)
        rowX = rowX + width + 4
        b:SetScript("OnClick", function()
            if choice.season and not SK.UI.ThemeInSeason(choice[1]) then return end
            Set(item, choice[1])
        end)
        b:SetScript("OnEnter", function(self)
            if not choice[3] then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L[choice[2]])
            GameTooltip:AddLine(L[choice[3]], 1, 1, 1, true)
            if choice.season then
                local now, months = SK.UI.ThemeInSeason(choice[1])
                if now then
                    GameTooltip:AddLine(L["In season now, until the end of %s."]:format(months), 0.25, 1, 0.25, true)
                else
                    GameTooltip:AddLine(L["Only in %s."]:format(months), 1, 0.4, 0.4, true)
                end
            end
            GameTooltip:Show()
        end)
        b.season = choice.season
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b.value = choice[1]
        buttons[#buttons + 1] = b
        previous = b
    end
    local spacer = CreateFrame("Frame", nil, w)
    spacer:SetSize(1, 1)
    spacer:SetPoint("TOPLEFT", w, "TOPLEFT", 4, -20 - row * 26 - 22)
    local tip = Tip(w, L[item[4]], spacer, 0)
    -- The picked one's own description, under the buttons.
    function w:Refresh()
        local value = Value(item)
        for _, b in ipairs(buttons) do
            if b.value == value then b:LockHighlight() else b:UnlockHighlight() end
        end
        local text = L[item[4]]
        for _, choice in ipairs(item.choices) do
            if choice[1] == value and choice[3] then text = "|cffffffff" .. L[choice[3]] .. "|r\n" .. text end
        end
        tip:SetText(text)
    end
    w:Refresh()
    return w, 20 + (row + 1) * 26 + (tip:GetStringHeight() or 24) + 12
end

local function MakeSlider(content, item, y)
    local w = CreateFrame("Frame", nil, content)
    w:SetSize(CONTENT, 20)
    w:SetPoint("TOPLEFT", 0, y)
    local label = w:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 4, 0)
    label:SetText(L[item[3]])
    local minus = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
    minus:SetSize(24, 20)
    minus:SetPoint("TOPLEFT", label, "TOPLEFT", 260, 3)
    minus:SetText("-")
    local value = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetPoint("LEFT", minus, "RIGHT", 6, 0)
    value:SetWidth(56)
    local plus = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
    plus:SetSize(24, 20)
    plus:SetPoint("LEFT", value, "RIGHT", 6, 0)
    plus:SetText("+")
    local low, high, step, format = item[5], item[6], item[7], item[8]
    local function Step(delta)
        local now = tonumber(Value(item)) or low
        local new = math.max(low, math.min(high, now + delta * step))
        new = math.floor(new / step + 0.5) * step   -- no 0.30000000004
        Set(item, new)
    end
    minus:SetScript("OnClick", function() Step(-1) end)
    plus:SetScript("OnClick", function() Step(1) end)
    local tip = Tip(w, L[item[4]], label, 0)
    function w:Refresh()
        local on = Enabled(item)
        value:SetText(format(tonumber(Value(item)) or low))
        if on then minus:Enable(); plus:Enable() else minus:Disable(); plus:Disable() end
        label:SetTextColor(on and 1 or 0.5, on and 0.82 or 0.5, on and 0 or 0.5)
    end
    w:Refresh()
    return w, 22 + (tip:GetStringHeight() or 12) + 12
end

local function MakeButton(content, item, y)
    local w = CreateFrame("Frame", nil, content)
    w:SetSize(CONTENT, 20)
    w:SetPoint("TOPLEFT", 0, y)
    local label = w:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 4, 0)
    label:SetText(L[item[2]])
    local b = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
    b:SetSize(140, 22)
    b:SetPoint("TOPLEFT", label, "TOPLEFT", 260, 4)
    b:SetText(L[item[3]])
    b:SetScript("OnClick", item[5])
    local tip = Tip(w, L[item[4]], label, 0)
    return w, 22 + (tip:GetStringHeight() or 12) + 12
end

local function TextBlock(content, y, text, font)
    local fs = content:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 4, y)
    fs:SetWidth(CONTENT - 20)
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(3)
    fs:SetText(text)
    return fs, (fs:GetStringHeight() or 14)
end

local function BackupPage(content)
    local y = 0
    local _, h = TextBlock(content, y, L["Everything Scrollkeeper has saved (settings, your luck log, drops, books, your mages, prices and what you heard from other players) lives in your WTF folder. If you ever have to wipe WTF, it's gone."]
        .. "\n\n" .. L["Make a backup, copy the text and keep it somewhere safe (a text file, a note, Discord). Restore pastes it back in and reloads."])
    y = y - h - 16
    local backup = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    backup:SetSize(170, 24)
    backup:SetPoint("TOPLEFT", 4, y)
    backup:SetText(L["Back up my data"])
    backup:SetScript("OnClick", function() SK.ShowBackup() end)
    local restore = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    restore:SetSize(170, 24)
    restore:SetPoint("LEFT", backup, "RIGHT", 10, 0)
    restore:SetText(L["Restore a backup"])
    restore:SetScript("OnClick", function() SK.ShowRestore() end)
    y = y - 34
    local _, h2 = TextBlock(content, y, L["Same as /sk backup and /sk restore."], "GameFontDisableSmall")
    return -(y - h2)
end

local function AboutPage(content)
    local icon = content:CreateTexture(nil, "ARTWORK")
    icon:SetSize(44, 44)
    icon:SetPoint("TOPLEFT", 4, 0)
    icon:SetTexture("Interface\\Icons\\INV_Scroll_03")
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    title:SetText(L["Scrollkeeper"])
    local version = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    version:SetText(L["Version %s  ·  by Natop (generalwrex)"]:format(SK.version))
    local y = -56
    local _, h = TextBlock(content, y, L["In game: %s (PvE). Say hi!"]:format(SK.AUTHOR_CHARACTER), "GameFontDisable")
    y = y - h - 10
    _, h = TextBlock(content, y, L["Everything for the mage's Comprehension skill in one place: decipher, "]
        .. L["study, imbue and summon from one panel, see what each scroll tier turns into, "]
        .. L["find libraries and scroll drops on the map, and share what you learn with "]
        .. L["other Scrollkeeper players. Made for WoW Forever."])
    y = y - h - 16
    _, h = TextBlock(content, y, L["Links"] .. "  |cff808080" .. L["Click one, press Ctrl+C, and paste it in your browser."] .. "|r", "GameFontNormal")
    y = y - h - 8
    for _, link in ipairs(SK.LINKS) do
        local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 12, y - 3)
        label:SetText(L[link[1]])
        local box = CopyBox(content, link[2])
        box:SetPoint("TOPLEFT", 110, y)
        y = y - 26
    end
    y = y - 8
    _, h = TextBlock(content, y, L["|cffffd100/sk bug|r  copy a bug report if something goes wrong.\n"]
        .. L["Paste it in the CurseForge comments (Report a bug, above)."])
    y = y - h - 16
    local team = { "|cffffd100" .. L["Dev team"] .. "|r" }
    for _, member in ipairs(SK.TEAM or {}) do
        team[#team + 1] = ("|cffffd100%s|r  %s"):format(member[1], L[member[2]])
    end
    _, h = TextBlock(content, y, table.concat(team, "\n"))
    y = y - h - 16
    local lines = { "|cffffd100" .. L["Thanks"] .. "|r" }
    for _, credit in ipairs(SK.CREDITS) do
        lines[#lines + 1] = ("|cffffd100%s|r  %s"):format(credit[1], L[credit[2]])
    end
    lines[#lines + 1] = L["Everyone who shares their scroll data or reports a bug."]
    _, h = TextBlock(content, y, table.concat(lines, "\n"))
    return -(y - h)
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------

local function ShowSection(index)
    current = index
    local section = SECTIONS[index]
    if section and SK.Track then SK.Track("options.section." .. section.name:lower()) end
    for i, button in ipairs(window.nav) do
        if i == index then button:LockHighlight() else button:UnlockHighlight() end
        button.text:SetTextColor(i == index and 1 or 0.85, i == index and 1 or 0.75, i == index and 1 or 0.5)
    end
    window.heading:SetText(L[section.name])
    -- A fresh content frame each time: sections are small, and this keeps
    -- old widgets out of the way.
    if shownContent then shownContent:Hide() end
    local content = CreateFrame("Frame", nil, window.scroll)
    content:SetSize(CONTENT, 10)
    window.scroll:SetScrollChild(content)
    shownContent = content
    widgets = {}
    local height
    if section.page == "backup" then
        height = BackupPage(content)
    elseif section.page == "about" then
        height = AboutPage(content)
    else
        local y = 0
        if section.note then
            local _, h = TextBlock(content, y, L[section.note], "GameFontHighlightSmall")
            y = y - h - 12
        end
        for _, item in ipairs(section.items) do
            -- Holiday themes: the ones in season now (they can come in
            -- from the network at any time, so this is worked out here).
            if item.holidays then
                item.choices = {}
                for _, h in ipairs(SK.UI.HOLIDAYS or {}) do
                    if SK.UI.ThemeInSeason(h[1]) then item.choices[#item.choices + 1] = { h[1], h[2], h[3], season = true } end
                end
            end
            local make = ({ check = MakeCheck, choice = MakeChoice, slider = MakeSlider, button = MakeButton })[item[1]]
            if make and not (item.char and not SK.charDB) and not (item.holidays and #item.choices == 0) then
                local w, h = make(content, item, y)
                widgets[#widgets + 1] = w
                y = y - h
            end
        end
        height = -y
    end
    content:SetHeight(math.max(10, height))
    window.scroll:SetVerticalScroll(0)
    -- Square the new buttons now (Modern), before they're ever drawn gold.
    if SK.UI.SkinControls then SK.UI.SkinControls(window) end
end

local function Build()
    -- The language choices depend on your game client.
    for _, section in ipairs(SECTIONS) do
        for _, item in ipairs(section.items or {}) do
            -- Holiday themes: only the ones in season now are shown.
            if item.holidays then
                item.choices = {}
                for _, h in ipairs(SK.UI.HOLIDAYS or {}) do
                    if SK.UI.ThemeInSeason(h[1]) then item.choices[#item.choices + 1] = { h[1], h[2], h[3], season = true } end
                end
            end
            if item[2] == "language" then
                item.choices = {}
                for _, language in ipairs(SK.LANGUAGES or {}) do
                    item.choices[#item.choices + 1] = { language[1], language[1] == "auto" and "Auto (game language)" or language[2] }
                end
            end
        end
    end
    if SK.charDB and SK.charDB.own == nil then SK.charDB.own = false end

    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperOptionsFrame", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if self.TitleText then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetTitle(L["Scrollkeeper: Settings"])
    if window.SetPortraitToAsset then window:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Gear_01") end
    tinsert(UISpecialFrames, "ScrollkeeperOptionsFrame")   -- Escape closes it

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    SK.UI.Background(background)
    SK.UI.AddHelp(window, "options")

    -- Sections down the left.
    local navBg = window:CreateTexture(nil, "BACKGROUND", nil, -6)
    navBg:SetPoint("TOPLEFT", 8, -62)
    navBg:SetPoint("BOTTOMLEFT", 8, 10)
    navBg:SetWidth(NAV - 8)
    SK.UI.NavBg(navBg)
    window.nav = {}
    for i, section in ipairs(SECTIONS) do
        local b = CreateFrame("Button", nil, window)
        b:SetSize(NAV - 16, 28)
        b:SetPoint("TOPLEFT", 12, -66 - (i - 1) * 32)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", 4, 0)
        icon:SetTexture(section.icon)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        b.text:SetPoint("RIGHT", -4, 0)
        b.text:SetJustifyH("LEFT")
        b.text:SetText(L[section.name])
        b:SetScript("OnClick", function() ShowSection(i) end)
        window.nav[i] = b
    end

    -- The section's settings on the right, scrolling if they don't fit.
    window.heading = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    window.heading:SetPoint("TOPLEFT", NAV + 16, -40)
    local divider = window:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.6, 0.45, 0.2, 0.5)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", NAV + 14, -60)
    divider:SetPoint("TOPRIGHT", -30, -60)
    window.scroll = CreateFrame("ScrollFrame", "ScrollkeeperOptionsScroll", window, "UIPanelScrollFrameTemplate")
    window.scroll:SetPoint("TOPLEFT", NAV + 16, -70)
    window.scroll:SetPoint("BOTTOMRIGHT", -32, 12)

    window:SetScript("OnShow", function() ShowSection(current) end)
    window:Hide()
end

-- Open the window, on a section by name ("Scroll Bag") if you like.
function SK.OpenOptions(sectionName)
    if SK.InCombat() then
        SK.Print(L["settings can't be opened in combat."])
        return
    end
    if not window then Build() end
    if type(sectionName) == "string" then
        for i, section in ipairs(SECTIONS) do
            if section.name:lower() == sectionName:lower() then current = i end
        end
    end
    window:Show()
    ShowSection(current)
end

-- A holiday theme came in: show it if the options are open.
SK.Listen("THEMES_CHANGED", function()
    if window and window:IsShown() then SK.Safely("options", ShowSection, current) end
end)

function SK.ToggleOptions()
    if window and window:IsShown() then window:Hide() else SK.OpenOptions() end
end

------------------------------------------------------------------------
-- The game's Options > AddOns > Scrollkeeper: a note and a button
------------------------------------------------------------------------

SK.Listen("READY", function()
    if not Settings then return end
    SK.Safely("settings page", function()
        local page = CreateFrame("Frame")
        local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText(L["Scrollkeeper"])
        local text = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
        text:SetWidth(560)
        text:SetJustifyH("LEFT")
        text:SetText(L["Scrollkeeper has its own settings window now. Open it here, with /sk options, or with the gear on the panel."])
        local open = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        open:SetSize(220, 26)
        open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -16)
        open:SetText(L["Open Scrollkeeper settings"])
        open:SetScript("OnClick", function()
            if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
            SK.OpenOptions()
        end)
        local category
        if Settings.RegisterCanvasLayoutCategory then
            category = Settings.RegisterCanvasLayoutCategory(page, "Scrollkeeper")
        elseif Settings.RegisterVerticalLayoutCategory then
            category = Settings.RegisterVerticalLayoutCategory("Scrollkeeper")
        end
        if category and Settings.RegisterAddOnCategory then Settings.RegisterAddOnCategory(category) end
    end)
end)
