local SK = __NS
fire("ADDON_LOADED", "Scrollkeeper")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
print("class mage?", SK.isMage, "errors:", #ScrollkeeperDB.errors)
local sk = SK.GetComprehension(); print("skill", sk.rank, sk.max, sk.known)
print("untranslated:", #SK.bags.untranslated, "feathers", SK.bags.feathers, "bundles", SK.bags.bundles)
for _, s in ipairs(SK.bags.untranslated) do print("  ", s.bag, s.slot, s.name, s.needs) end
local nxt, ready, hard, ups = SK.NextDecipherable(); print("next", nxt and nxt.name, ready, hard, "skillups", ups)
do -- best chance first: at 74 a tier 50 (orange) beats a tier 15 (green)
  local bags, comprehension = SK.bags.untranslated, SK.GetComprehension
  SK.bags.untranslated = { { name = "T15", needs = 15 }, { name = "T50", needs = 50 } }
  SK.GetComprehension = function() return { rank = 74, effective = 74, max = 120 } end
  print("PICK at 74:", SK.NextDecipherable().name)
  SK.bags.untranslated, SK.GetComprehension = bags, comprehension
end
for _, t in ipairs({1, 15, 50, 175}) do for _, k in ipairs({0, 14, 15, 22, 23, 29, 30, 57}) do local c = SK.SkillUpChance(t, k); io.write(t, "@", k, "=", c.key, " ") end print() end
if SK.isMage then
  local b = ScrollkeeperDecipherButton
  print("button", b._text, b._attrs.type, b._attrs.spell, b._attrs["target-bag"], b._attrs["target-slot"])
  for _, n in ipairs({ "skill", "tier", "scrolls", "study", "warning", "log" }) do end
  -- decipher the first scroll: it becomes a Scroll of Frog Familiar
  -- real order seen in game
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1296017)
  fire("UNIT_SPELLCAST_START", "player", "guid", 1309973)
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1309973)
  fire("CHAT_MSG_LOOT", "You receive item: |cnIQ1:|Hitem:277483::::::::20:1482:::::::::|h[Scroll of Frog Familiar]|h|r")
  BAGS[0][7] = nil; MOCK_RANK = 58
  fire("BAG_UPDATE_DELAYED")
  BAGS[1][5].count = 2
  fire("BAG_UPDATE_DELAYED")
  runTimers()
  -- second decipher where the loot message never comes: logged as unknown after the wait
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1309973)
  BAGS[0][8] = nil
  fire("BAG_UPDATE_DELAYED")
  runTimers()
  -- third: the bag update comes too late, it's still logged (by the scroll the button aimed at)
  local before3, aimed = ScrollkeeperDB.deciphered, SK.NextDecipherable()
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1296017)
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1309973)
  fire("CHAT_MSG_LOOT", "You receive item: |cnIQ1:|Hitem:277401::::::::20:1482:::::::::|h[Scroll of Rat Familiar]|h|r")
  runTimers()
  print("LATEBAGS logged", ScrollkeeperDB.deciphered - before3, "aimed tier", aimed and aimed.needs)
  -- No spell events at all (Forever): the bags + the loot message are enough.
  local function Tier50(name) return { id = 211786, name = "Scroll: " .. name, count = 1, tip = { "Scroll: " .. name, "Classes: Mage", "Requires Comprehension (50)" } } end
  BAGS[2][1], BAGS[2][2], BAGS[2][3] = Tier50("AAA"), Tier50("BBB"), Tier50("CCC")
  fire("BAG_UPDATE_DELAYED"); runTimers()
  local n0 = ScrollkeeperDB.deciphered
  -- loot message first, then the bag update
  fire("CHAT_MSG_LOOT", "You receive loot: |cff1eff00|Hitem:275067::::::::20:1482:::::::::|h[Scroll of Owl Familiar]|h|r.")
  BAGS[2][1] = nil; fire("BAG_UPDATE_DELAYED"); runTimers()
  local n1 = ScrollkeeperDB.deciphered
  -- bag update first, then the loot message
  BAGS[2][2] = nil; fire("BAG_UPDATE_DELAYED")
  fire("CHAT_MSG_LOOT", "You receive item: |cff1eff00|Hitem:275069::::::::20:1482:::::::::|h[Scroll of Imbue Frost]|h|r.")
  runTimers()
  local n2 = ScrollkeeperDB.deciphered
  -- mailed away (no loot message): not a decipher
  BAGS[2][3] = nil; fire("BAG_UPDATE_DELAYED"); runTimers()
  local t50 = 0; for _, c in pairs(ScrollkeeperDB.results[50] or {}) do t50 = t50 + c end
  print("NOEVENTS loot-first", n1 - n0, "bags-first", n2 - n1, "mailed", ScrollkeeperDB.deciphered - n2, "tier50", t50)
  print("after decipher: total", ScrollkeeperDB.deciphered, "button", b._text, b._attrs["target-slot"])
  -- study
  print("in library (Tarren Mill)", SK.InLibrary())
  MOCK_ZONE = "Undercity"; MOCK_SUB = "The Magic Quarter"; fire("ZONE_CHANGED")
  print("in library (Magic Quarter)", SK.InLibrary())
  MOCK_SUB = "Odd Reading Nook"; fire("ZONE_CHANGED")
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1302508)
  print("in library (learned nook)", SK.InLibrary())
  print("study left", SK.StudySecondsLeft(), SK.FormatStudyTime(SK.StudySecondsLeft()))
  advance(3500); print("study left", SK.FormatStudyTime(SK.StudySecondsLeft()))
  BAGS[3][1] = { id = 999, name = "Bundle of Scrolls", count = 1, tip = { "Bundle of Scrolls" } }
  fire("BAG_UPDATE_DELAYED")
  ScrollkeeperPanel._scripts.OnUpdate(ScrollkeeperPanel, 1.5)
  print("translated:", #SK.bags.translated, SK.bags.translated[1] and SK.bags.translated[1].name, SK.bags.translated[1] and SK.bags.translated[1].count)
  local sb = ScrollkeeperScrollButton1; print("scroll button", sb._shown, sb._attrs.type, sb._attrs.item)
  SK.db.collapsed = true; SK.RefreshPanel(); print("collapsed button shown", sb._shown)
  SK.db.collapsed = false; SK.RefreshPanel(); SK.OptionChanged("viewMode"); SlashCmdList.SCROLLKEEPER("options")
  SlashCmdList.SCROLLKEEPER("log")
  SlashCmdList.SCROLLKEEPER("")
  SlashCmdList.SCROLLKEEPER("")
  SlashCmdList.SCROLLKEEPER("scan")
else
  SlashCmdList.SCROLLKEEPER("")
end
-- tooltip
local tip = { added = {} }
function tip:AddLine(t) self.added[#self.added + 1] = t end
for _, fn in ipairs(TOOLTIP_CALLS) do
  fn(tip, { lines = { { leftText = "Scroll: WUBBA WUBBA" }, { leftText = "Requires Comprehension (15)" } } })
  fn(tip, { lines = { { leftText = "Hearthstone" } } })
  fn(tip, { lines = { { leftText = "Scroll: DOST OREM" }, { leftText = "Requires Comprehension (175)" } } })
end
for _, t in ipairs(tip.added) do print("  tip:", t) end
SlashCmdList.SCROLLKEEPER("tooltips"); SlashCmdList.SCROLLKEEPER("bogus")
print("errors:", #ScrollkeeperDB.errors); for _, e in ipairs(ScrollkeeperDB.errors) do print("  ERR", e.where, e.error) end

-- NETWORK
runTimers()  -- NET_READY after 8s timer
print("sent after ready:", #SENT); for _, m in ipairs(SENT) do end
for i = 1, 8 do tickAll() end
for _, m in ipairs(SENT) do print("  sent", m[3], m[2]) end
-- someone answers
fire("CHAT_MSG_ADDON", "Scrollkeeper", "H|1|0.5.0|MAGE|24|41|120|15.50|Saber", "GUILD", "Kaelith-Realm")
fire("CHAT_MSG_ADDON", "Scrollkeeper", "T|15#1|277483:12,-5:9", "GUILD", "Kaelith-Realm")
fire("CHAT_MSG_ADDON", "Scrollkeeper", "T|15#1|277483:999999", "GUILD", "Evil-Realm")
fire("CHAT_MSG_ADDON", "Scrollkeeper", "P|1458#1|36.16:4,10.10:2", "GUILD", "Kaelith-Realm")
fire("CHAT_MSG_ADDON", "Scrollkeeper", "L|1458|0.731|0.335|The Magic Quarter", "GUILD", "Kaelith-Realm")
fire("CHAT_MSG_ADDON", "Scrollkeeper", "H|1|0.4.0|MAGE|20|57|100|15||Player-1-ABC", "GUILD", "Archmage Naage")
fire("CHAT_MSG_ADDON", "Scrollkeeper", "T|15#1|277483:50", "GUILD", "Archmage Naage")
local mages = SK.MagesWhoNeed(15); print("mages need 15:", #mages, mages[1] and mages[1].name)
local odds, total, players = SK.CommunityOdds(15); print("odds 15 total", total, "players", players)
for _, o in ipairs(odds) do print("  ", o.name, o.count) end
local cells = SK.DropCells(1458); local n = 0; for c, v in pairs(cells) do n = n + 1 end; print("drop cells", n)
print("library pins", #SK.LibraryPins(1458))
-- my loot
fire("CHAT_MSG_LOOT", "You receive loot: |cnIQ1:|Hitem:211786::::::::20:1482:::::::::|h[Scroll: CWAL]|h|r.")
print("my drops", SK.db.drops[1458] and SK.db.drops[1458]["36.16"])
-- tooltip with peers
ScrollkeeperDB.showTooltips = true
local tip = { added = {} }
function tip:AddLine(t) self.added[#self.added + 1] = t end
function tip:AddDoubleLine(a, b) self.added[#self.added + 1] = a .. " = " .. b end
for _, fn in ipairs(TOOLTIP_CALLS) do fn(tip, { lines = { { leftText = "Requires Comprehension (15)" } } }) end
for _, t in ipairs(tip.added) do print("  tip:", t) end
SlashCmdList.SCROLLKEEPER("demo")
print("peers with demo", #SK.PeerList())
local odds1, t1, p1 = SK.CommunityOdds(1); print("demo odds tier1", t1, p1, odds1[1].name)
SlashCmdList.SCROLLKEEPER("net")
-- Liminal Passage doors
fire("CHAT_MSG_ADDON", "Scrollkeeper", "G|Ironforge|2|1455|1", "GUILD", "Kaelith-Realm")
print("open doors (demo on)", #SK.OpenDoors())
SlashCmdList.SCROLLKEEPER("doors")
SK.RefreshDoors()
print("door places", #SK.DoorPlaces(), SK.DoorPlaces()[1].place.town, SK.DoorPlaces()[1].doors)
print("door hosts (all)", #SK.DoorHosts())
fire("PARTY_INVITE_REQUEST", "Nobody")
fire("WHO_LIST_UPDATE")
fire("CHAT_MSG_ADDON", "Scrollkeeper", "DA", "WHISPER", "Kaelith-Realm")
ScrollkeeperDB.liminalDoor = true
SK.SendDoor(true)
fire("CHAT_MSG_ADDON", "Scrollkeeper", "DA", "WHISPER", "Kaelith-Realm")
fire("CHAT_MSG_ADDON", "Scrollkeeper", "DY", "WHISPER", "Kaelith-Realm")
fire("CHAT_MSG_ADDON", "Scrollkeeper", "DN", "WHISPER", "Kaelith-Realm")
SlashCmdList.SCROLLKEEPER("doors")
SlashCmdList.SCROLLKEEPER("demo")
print("peers after demo off", #SK.PeerList())
print("open doors (demo off)", #SK.OpenDoors())
if SK.isMage then print("study button", ScrollkeeperStudyButton._attrs.spell, "bundle", ScrollkeeperBundleButton._attrs.item) end
print("errors:", #ScrollkeeperDB.errors); for _, e in ipairs(ScrollkeeperDB.errors) do print("  ERR", e.where, e.error) end

-- CATEGORIES
if SK.isMage then
  fire("BAG_UPDATE_DELAYED")
  for _, g in ipairs(SK.ScrollGroups()) do
    local names = {}
    for _, s in ipairs(g.scrolls) do names[#names+1] = s.name:gsub("Scroll of ", "") .. (s.best and "*" or "") .. (s.usable and "" or "(x)") end
    print("group", g.label, table.concat(names, ", "))
  end
  for _, u in ipairs(SK.UpgradeStatus()) do print("upgrade", u.upgrade.makes, u.hasScroll, u.hasWeapon, u.ready) end
  runTimers()
  for _, r in ipairs(SK.Reminders()) do print("reminder", r) end
  print("panel warning:", ScrollkeeperPanel and "ok")
  print("errors:", #ScrollkeeperDB.errors); for _, e in ipairs(ScrollkeeperDB.errors) do print("  ERR", e.where, e.error) end
end

-- MANY: 30 kinds of scrolls
if SK.isMage then
  for i = 1, 30 do BAGS[4][i] = { id = 277500 + i, name = "Scroll of Imbue Test " .. i, count = i, tip = { "Scroll of Imbue Test " .. i, "Use: Imbue a staff with magic.", "Classes: Mage", "Requires Level " .. i } } end
  fire("BAG_UPDATE_DELAYED")
  local shown = 0
  for i = 1, 40 do local b = _G["ScrollkeeperScrollButton" .. i]; if b and b._shown then shown = shown + 1 end end
  print("MANY: scroll buttons shown", shown)
  print("errors:", #ScrollkeeperDB.errors); for _, e in ipairs(ScrollkeeperDB.errors) do print("  ERR", e.where, e.error) end
end

-- VIEWS
if SK.isMage then
  print("view", SK.ViewMode())
  for _, m in ipairs({ "compact", "mini", "full" }) do
    SK.db.viewMode = m; SK.RefreshPanel()
    print("view", m, "decipher shown", ScrollkeeperDecipherButton._shown, "ready row", "ok")
  end
  SlashCmdList.SCROLLKEEPER("simple"); print("after /sk simple", SK.ViewMode())
  print("errors:", #ScrollkeeperDB.errors); for _, e in ipairs(ScrollkeeperDB.errors) do print("  ERR", e.where, e.error) end
end

-- LIBPINS
CreateVector2D = function(a, b) return { a = a, b = b } end
C_Map.GetMapPosFromWorldPos = function(inst, v, mapID)
  -- fake: Undercity map 1458 covers world 1600..1700 (first) / 100..200 (second)
  if mapID ~= 1458 then return mapID, nil end
  local px, py = (v.b - 100) / 100, (v.a - 1600) / 100
  return mapID, { GetXY = function() return px, py end }
end
SK.db.libraryPins = { old = { mapID = 1458, x = 0.5, y = 0.5, name = "Old" },
                      new = { inst = 0, x = 161.5, y = 1672.2, name = "Magic Quarter" } }
SK.db.sharedLibraries = { s = { inst = 0, x = 161.5, y = 1672.2, name = "Magic Quarter", from = { A = true, B = true } } }
for _, p in ipairs(SK.LibraryPins(1458)) do print("pin", p.name, ("%.3f %.3f"):format(p.x, p.y), p.mine, p.known, p.count) end
print("pins on other map", #SK.LibraryPins(84))
print("errors:", #ScrollkeeperDB.errors)

-- ALTS & BOOKS
if SK.isMage then
  print("my mage entry", SK.MyMage() and SK.MyMage().skill, SK.MyMage().studyReadyAt)
  fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:99001::::::::|h[Mystical Journal, Volume 4]|h|r.")
  local n = 0; for _, c in pairs(SK.db.bookDrops or {}) do for _, v in pairs(c) do n = n + v end end
  print("books logged", n)
  print("book cells", next(SK.DropCells(1458, "books")) ~= nil)
  SK.db.viewMode = "full"; SK.RefreshPanel()
else
  SK.db.mages = { ["Frostie-Forever"] = { name = "Frostie", skill = 59, max = 100, level = 20, knowsStudy = true, studyReadyAt = time() + 600 } }
  SK.bags.untranslated = { { needs = 15 }, { needs = 50 }, { needs = 175 } }
  SK.ToggleAltPanel()
  print("alt mages", #SK.MyOtherMages(), "readers of 50:", #SK.MyMagesFor(50), "of 175:", #SK.MyMagesFor(175))
end
print("errors:", #ScrollkeeperDB.errors); for _, e in ipairs(ScrollkeeperDB.errors) do print("  ERR", e.where, e.error) end

-- EXPORT
if SK.isMage then
  SK.db.resultsByID = { [1] = { [213564] = 3, [277483] = 1 } }
  SK.db.itemNames = { [213564] = "Scroll of Minor Evocation", [277483] = "Scroll of Frog Familiar" }
  SK.db.skillups = { ["1 orange"] = { ups = 2, tries = 3 } }
  local text, n = SK.ExportText(); print("EXPORT records", n); print(text)
  print(SK.BugReportText())
  SlashCmdList.SCROLLKEEPER("export"); SlashCmdList.SCROLLKEEPER("bug")
  print("errors after:", #ScrollkeeperDB.errors)
end

-- WHYNOT
print("WHY", SK.UI.WhyNotUsable({ usable = false, levelOK = true, fits = false, name = "Scroll of Imbue Spark", imbueFor = "sword" }))
print("WHY", SK.UI.WhyNotUsable({ usable = false, levelOK = false, level = 30, name = "Scroll of Cat Familiar" }))
print("WHY", SK.UI.WhyNotUsable({ usable = true }))

-- SWAPHINT
local realInfo = C_Container.GetContainerItemInfo
C_Container.GetContainerItemInfo = function(b, s) if b == 0 and s == 1 then return { itemID = 9001, hyperlink = "|cff|Hitem:9001|h[Blade of Testing]|h|r" } end return realInfo and realInfo(b, s) end
local realInstant = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(id) if id == 9001 then return 9001, "Weapon", "Swords", "", "", 2, 7 end return realInstant and realInstant(id) end
SK.bags.translated = { { category = "imbues", name = "Scroll of Imbue Spark", imbueFor = "sword", level = 1, itemID = 1 } }
local scroll, weapon = SK.ImbueSwapHint(); print("SWAP", scroll and scroll.name, weapon)
print("WHY", SK.UI.WhyNotUsable({ usable = false, levelOK = true, fits = false, name = "Scroll of Imbue Spark", imbueFor = "sword" }))
SK.RefreshPanel(); print("errors:", #ScrollkeeperDB.errors)

-- SECRET NAMES
issecretvalue = function(v) return v == "SECRET" end
local realUnitName = UnitName
UnitName = function(unit) if unit == "npc" then return "SECRET" end return realUnitName(unit) end
fire("QUEST_COMPLETE")
UnitName = realUnitName
print("secret npc ok, errors:", #ScrollkeeperDB.errors)

-- COMBAT HIDING
if SK.isMage then
  SK.db.hideInCombat = true; SK.UpdateCombatHiding(); fire("PLAYER_REGEN_ENABLED")
  print("combat hiding ok, errors:", #ScrollkeeperDB.errors)
end


-- TITLES
if SK.isMage then
  SlashCmdList.SCROLLKEEPER("export"); print("TITLE", ScrollkeeperExportFrame and ScrollkeeperExportFrame.title)
  SK.db.errors = { { at = 0, where = "map pins", error = "...Blizzard_MapCanvas.lua:309: assertion failed!" } }
  SlashCmdList.SCROLLKEEPER("bug"); print("TITLE", ScrollkeeperExportFrame and ScrollkeeperExportFrame.title)
  SK.db.errors = {}
end

-- SHIPPED DATA
if SK.isMage then
  SK.db.exportID = "someone-else"
  local list, total, players = SK.CommunityOdds(1)
  print("SHIPPED", total, players, list[1] and list[1].name)
  SK.db.exportID = "862ee863"
  local _, total2, players2 = SK.CommunityOdds(1)
  print("OWN SKIPPED", total2, players2)
end

-- ITEM LABELS
print("LABEL", SK.UI.ItemLabel(213564, "Minor Evocation"))
SK.ToggleNetwork(); SK.RefreshNetwork()
print("item labels ok, errors:", #ScrollkeeperDB.errors)

-- SCROLL LINKS
print("LINK id", SK.ScrollLink(213564))
print("LINK name", SK.ScrollLink(nil, "Scroll of Rat Familiar"))
print("LINK unknown", SK.ScrollLink(nil, "Scroll of Nothing"))
SK.PrintLog()
print("scroll links ok, errors:", #ScrollkeeperDB.errors)

-- ABOUT
SlashCmdList.SCROLLKEEPER("about")
print("about ok, errors:", #ScrollkeeperDB.errors)
print("ABOUT PAGE", SK_ABOUT_PAGE)

-- TITLE ONLY SKILL BAR
SK.db.viewMode = "mini"; SK.RefreshPanel()
local p = ScrollkeeperPanel
print("MINI", p and p:GetHeight())
SK.db.viewMode = nil; SK.RefreshPanel()
print("mini bar ok, errors:", #ScrollkeeperDB.errors)

-- MAIL / GUILD BANK / AUCTION
SK.db.mages = SK.db.mages or {}
SK.db.mages["Newbie-Forever"] = { name = "Newbie", skill = 0, max = 0, level = 1, realm = "Forever" }
SK.db.mages["Lowmage-Forever"] = { name = "Lowmage", skill = 20, max = 75, level = 20, realm = "Forever", faction = UnitFactionGroup and UnitFactionGroup("player") }
SK.db.mages["Farmage-Other"] = { name = "Farmage", skill = 60, max = 75, level = 30, realm = "Other" }
SK.bags.untranslated = {
  { bag = 0, slot = 1, itemID = 213601, name = "Scroll: ONE", needs = 1 },
  { bag = 0, slot = 2, itemID = 213602, name = "Scroll: FIFTEEN", needs = 15 },
  { bag = 0, slot = 3, itemID = 213603, name = "Scroll: FIFTY", needs = 50 },
}
for _, p in ipairs(SK.MailPlan()) do
  print("MAILPLAN", p.name, p.kind, "ups", p.ups, "reads", p.reads, "scrolls", #p.scrolls)
end
print("SKILLUPS 15", SK.SkillUpsFor(15))
-- fake mailbox
SendMailFrame = CreateFrame("Frame"); MailFrame = CreateFrame("Frame"); SendMailFrame:Show()
local attached = {}
SendMailNameEditBox = CreateFrame("EditBox"); SendMailSubjectEditBox = CreateFrame("EditBox")
function HasSendMailItem(i) return attached[i] ~= nil end
function ClickSendMailItemButton(i) attached[i] = true end
function ClearCursor() end
C_Container.PickupContainerItem = function() end
local origInfo = C_Container.GetContainerItemInfo
C_Container.GetContainerItemInfo = function(bag, slot)
  for _, s in ipairs(SK.bags.untranslated) do if s.bag == bag and s.slot == slot then return { itemID = s.itemID } end end
  return origInfo(bag, slot)
end
fire("MAIL_SHOW"); for _, f in ipairs(TIMERS) do pcall(f) end
local row1 = ScrollkeeperMailFrame and ScrollkeeperMailFrame:IsShown()
print("MAIL FRAME shown", row1)
local plan = SK.MailPlan()
if plan[1] then
  -- click the first row's handler through the plan
  local n = 0
  for _, child in ipairs({ ScrollkeeperMailFrame:GetChildren() }) do
    if child.person and n == 0 then n = 1; child:GetScript("OnClick")(child) end
  end
  print("MAIL to", SendMailNameEditBox:GetText(), "attached", #attached)
end
-- auction house, classic style
GetNumAuctionItems = function() return 2 end
GetAuctionItemInfo = function(_, i)
  if i == 1 then return "Scroll: ONE", 0, 1, 1, true, 1, "", 0, 0, 5000, 0, nil, nil, nil, nil, 0, 213601 end
  return "Linen Cloth", 0, 20, 1, true, 1, "", 0, 0, 2000, 0, nil, nil, nil, nil, 0, 2589
end
local nameByID = C_Item.GetItemNameByID
C_Item.GetItemNameByID = function(id) if id == 213601 then return "Scroll: ONE" elseif id == 2589 then return "Linen Cloth" end return nameByID and nameByID(id) end
local inst = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(id) if id == 213601 then return id, "Consumable", "Scrolls", "", 1, 0, 4 end return id, "Trade", "Cloth", "", 1, 7, 5 end
fire("AUCTION_ITEM_LIST_UPDATE")
C_Item.GetItemInfoInstant = inst
print("AH PRICE", SK.AuctionPrice(213601), SK.AuctionPrice(2589))
print("mail/bank/ah ok, errors:", #ScrollkeeperDB.errors)
for _, e in ipairs(ScrollkeeperDB.errors) do print("ERR", e.where, e.error) end
SlashCmdList.SCROLLKEEPER("mail")
fire("CHAT_MSG_GUILD", "who needs this? |cff1eff00|Hitem:213602::::::::|h[Scroll: FIFTEEN]|h|r", "Bob-Forever")
print("chat ok, errors:", #ScrollkeeperDB.errors)

-- HEARD DATA IN EXPORT
fire("CHAT_MSG_ADDON", "Scrollkeeper", "H|1|1.1.0|MAGE|30|60|120|50||guid|abcd1234", "GUILD", "Heardy-Realm")
fire("CHAT_MSG_ADDON", "Scrollkeeper", "T|50#1|277483:3,275067:2", "GUILD", "Heardy-Realm")
fire("CHAT_MSG_ADDON", "Scrollkeeper", "P|1458#1|12.30:2", "GUILD", "Heardy-Realm")
local text, _, heard = SK.ExportText()
print("HEARD", heard)
for line in text:gmatch("[^\n]+") do if line:find("heard") or line:find("export 1") then print("EXP", line) end end
print("export ok, errors:", #ScrollkeeperDB.errors)

-- BACKFIRE / PLAN / SWAP
if SK.isMage then
  -- a normal read counts a try
  SK.Send("DECIPHERED", 15)
  -- a backfire: cast finishes, then a polymorph aura
  C_UnitAuras = C_UnitAuras or {}
  local sheep = false
  C_UnitAuras.GetAuraDataByIndex = function(unit, i, filter) if sheep and i == 1 then return { icon = 136071, name = "Polymorph" } end end
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1309973)
  sheep = true
  fire("UNIT_AURA", "player")
  local mine = SK.BackfireStats()
  print("BACKFIRES", mine.b, mine.t)
  SK.db.farm = { seconds = 7200, looted = 20 }
  for _, line in ipairs(SK.FarmPlanLines()) do print("PLAN", line) end
end
fire("CHAT_MSG_ADDON", "Scrollkeeper", "S|1:3,15:2,50:1", "GUILD", "Kaelith-Realm")
print("COULD GET", #SK.ScrollsICouldGet(), "WANT MINE", #SK.WhoWantsMine())
SlashCmdList.SCROLLKEEPER("swap"); SlashCmdList.SCROLLKEEPER("plan")
local text = SK.ExportText()
for line in text:gmatch("[^\n]+") do if line:sub(1, 2) == "B|" then print("EXPB", line) end end
print("new features ok, errors:", #ScrollkeeperDB.errors)
for _, e in ipairs(ScrollkeeperDB.errors) do print("ERR", e.where, e.error) end

-- SURNAMES
if SK.isMage then
  local realName = UnitName
  SK.db.mages["Surnamey-Forever"] = { name = "Surnamey", skill = 5, studyReadyAt = 12345 }
  UnitName = function(unit) if unit == "player" then return "Surnamey", "Sheep" end return realName(unit) end
  local entry = SK.MyMage()
  print("SURNAME", SK.CharKey(), entry.name, entry.studyReadyAt, SK.db.mages["Surnamey-Forever"])
  UnitName = realName
end

-- SCROLL ICON
if SK.isMage then
  SK.db.scrollIcon = true; SK.RefreshIcon()
  print("ICON", ScrollkeeperIcon and ScrollkeeperIcon:IsShown(), ScrollkeeperIcon and ScrollkeeperIcon.count:GetText())
  -- A secure button since 1.1.5: its clicks may be hooks, not a script.
  local onClick = ScrollkeeperIcon:GetScript("OnClick")
  if type(onClick) == "function" then onClick(ScrollkeeperIcon, "LeftButton", false) end
  local onEnter = ScrollkeeperIcon:GetScript("OnEnter")
  if type(onEnter) == "function" then onEnter(ScrollkeeperIcon) end
  SK.db.scrollIcon = false; SK.RefreshIcon()
  print("ICON off", ScrollkeeperIcon:IsShown())
end
print("icon ok, errors:", #ScrollkeeperDB.errors)
fire("PLAYER_LOGOUT")
print("LASTEXPORT", SK.db.lastExportTitle, SK.db.lastExport and #SK.db.lastExport)

print("SETTINGS sections", MOCK_HEADERS)
if SK.isMage and ScrollkeeperPanel and ScrollkeeperPanel.iconToggle then
  ScrollkeeperPanel.iconToggle:GetScript("OnClick")(ScrollkeeperPanel.iconToggle)
  print("TOGGLE", SK.db.scrollIcon, ScrollkeeperIcon and ScrollkeeperIcon:IsShown())
  ScrollkeeperPanel.iconToggle:GetScript("OnClick")(ScrollkeeperPanel.iconToggle)
  print("TOGGLE", SK.db.scrollIcon, ScrollkeeperIcon and ScrollkeeperIcon:IsShown())
end
-- LANGUAGE PICK
print("LANG in use", SK.languageInUse, SK.L["Ready"])
SK.db.language = "deDE"; SK.ApplyLanguage(); print("LANG override", SK.languageInUse, SK.L["Ready"])
-- MINIMAP BUTTON
if SK.isMage then
  SK.RefreshMinimapButton()
  local b = ScrollkeeperMinimapButton
  print("MINIMAP", b and b:IsShown(), b and b.count:GetText())
  -- A secure button since 1.1.9: its clicks are the template's plus hooks.
  b:GetScript("OnEnter")(b); b:GetScript("OnDragStart")(b); b:GetScript("OnDragStop")(b)
  local onClick = b:GetScript("OnClick"); if type(onClick) == "function" then onClick(b, "LeftButton") end
  SK.db.minimapButton = false; SK.RefreshMinimapButton(); print("MINIMAP off", b:IsShown())
end
-- SETUP (one question per page)
do
  for _, t in ipairs(TIMERS) do pcall(t) end
  print("SETUP shown", ScrollkeeperSetupFrame and ScrollkeeperSetupFrame:IsShown())
  SlashCmdList.SCROLLKEEPER("setup")
  local f = ScrollkeeperSetupFrame
  local function pick(i) f.options[i]:GetScript("OnClick")(f.options[i]) end
  local function nextPage() f.next:GetScript("OnClick")(f.next) end
  if SK.isMage then
    pick(2) nextPage()      -- Advanced
    pick(2) nextPage()      -- turn on the scroll icon
    nextPage()              -- combat: keep
    nextPage()              -- reminders: keep
    nextPage()              -- keys: none
    pick(2) nextPage()      -- share: anonymous
  else
    pick(2) nextPage()      -- tooltips: no
    nextPage()              -- mailbox: keep
    pick(1) nextPage()      -- share: full
  end
  print("SETUP last page", f.next._text)
  nextPage()                -- language: keep, Done
  print("SETUP result", SK.db.viewMode, SK.db.scrollIcon, SK.db.showTooltips, SK.db.share, SK.db.shareChannel, SK.db.setupDone, SK.db.setupDoneOther, f:IsShown(), "sharing", SK.db.sharing, SK.db.anonymous, "panel", ScrollkeeperPanel and ScrollkeeperPanel:IsShown())
  -- Already set up: nothing new, so nothing opens.
  f:Hide()
  SK.ShowSetup(true)
  print("SETUP nothing new", f:IsShown())
  -- A changed question (sharing v3) comes back alone.
  local seenField = SK.isMage and "setupSeen" or "setupSeenOther"
  SK.db[seenField].sharing = 1
  SK.ShowSetup(true)
  print("SETUP only new", f:IsShown(), f.question:GetText(), f.next._text)
  f:Hide()
  -- Someone who did setup in 1.1.2/1.1.3 (no seen list) gets the sharing page only.
  SK.db[seenField] = nil
  TIMERS = {}
  SK.Send("READY")
  for _, t in ipairs(TIMERS) do pcall(t) end
  print("SETUP upgrade", f:IsShown(), f.question:GetText(), f.step:GetText())
  f:Hide()
  -- Skipping the full setup opens the panel.
  if ScrollkeeperPanel then ScrollkeeperPanel:Hide() end
  SK.db.showPanel = false
  SK.ShowSetup()
  f.skip:GetScript("OnClick")(f.skip)
  -- An anonymous peer: counted, not named.
  SK.peers["Hidden-Realm"] = { class = "MAGE", level = 30, skill = 50, max = 150, tiers = {}, upgrades = {}, seen = time(), anonymous = true }
  local named = 0
  for _, entry in ipairs(SK.PeerList()) do if entry.name == "Hidden" then named = named + 1 end end
  print("ANON", SK.AnonymousCount(), "named", named, "mail", #SK.FreshMages(), "counted", #SK.FreshMages(true))
  SK.peers["Hidden-Realm"] = nil
  print("SETUP skip", f:IsShown(), "panel", ScrollkeeperPanel and ScrollkeeperPanel:IsShown())
end

-- Links kept whole when text wraps
print("KEEPWHOLE", SK.KeepLinksWhole("for |cff|Hitem:1|h[Scroll of Frog Familiar]|h|r now") == "for |cff|Hitem:1|h[Scroll\194\160of\194\160Frog\194\160Familiar]|h|r now")

-- PLAN with auction house prices
if SK.isMage then
  local realTip = C_TooltipInfo.GetItemByID
  C_TooltipInfo.GetItemByID = function(id) if id == 990050 or id == 990051 then return { lines = { { leftText = "Requires Comprehension (50)" } } } end return realTip and realTip(id) end
  SK.db.ahPrices = {}
  SK.db.ahLastScan = time() - 7300
  SK.db.language = "enUS"
  SK.db.ahPrices[990050] = { price = 4500, count = 3, at = time() - 7200 }
  SK.db.ahPrices[990051] = { price = 12000, count = 4, total = 52000, at = time() - 7200 }
  for _, line in ipairs(SK.FarmPlanLines()) do print("PLANAH", line) end
  SK.TogglePlan(); print("PLANWIN", ScrollkeeperPlanFrame and ScrollkeeperPlanFrame:IsShown())
  print("errors:", #ScrollkeeperDB.errors)
end

-- PLAN after a reload: tooltips not loaded, requirement saved with the price
if SK.isMage then
  SK.db.ahPrices = { [990060] = { price = 3000, count = 5, total = 16000, at = time(), needs = 50 } }
  SK.db.ahLastScan = time() - 10
  local found = SK.CheapestScrolls(5)
  print("PLANRELOAD", #found, found[1] and found[1].itemID)
end


-- Drops remember their tier: the test loot is a tier 1 scroll
if SK.isMage then
  local t1, t50 = SK.BestZones(5, 1), SK.BestZones(5, 50)
  print("DROPTIERS tier1 zones", #t1, t1[1] and t1[1].count, "tier50 zones", #t50)
end

-- BACKUP: round trip, refuses junk and cut-off text, restore swaps the data in
do
  ScrollkeeperDB.backupTest = { a = 1, b = "x:y|z", c = { true, false, 2.5 }, ["weird key"] = "s5:fake" }
  local text = SK.BackupText()
  local data, why = SK.ReadBackup(text)
  local same = data and data.backupTest and data.backupTest.b == "x:y|z" and data.backupTest.c[3] == 2.5
    and data.backupTest["weird key"] == "s5:fake" and data.deciphered == ScrollkeeperDB.deciphered
  local junk = SK.ReadBackup("hello")
  local cut = SK.ReadBackup(text:sub(1, #text - 5))
  local reloaded = false; ReloadUI = function() reloaded = true end
  ScrollkeeperDB.deciphered = 999
  SK.RestoreBackupData(data)
  print("BACKUP roundtrip", same and true or false, "junk refused", junk == nil, "cut refused", cut == nil,
    "restored", ScrollkeeperDB.deciphered ~= 999, "reloads", reloaded, "size", #text)
  ScrollkeeperDB.backupTest = nil
  SK.ShowBackup(); SK.ShowRestore()
  print("errors:", #ScrollkeeperDB.errors)
end

-- MESSAGES: shown once when the panel opens, only in their version
do
  ScrollkeeperDB.messagesSeen = nil
  local realVersion = SK.version
  SK.MESSAGES = { { id = "test-now", version = realVersion, lines = { "hello one", "hello two" } },
                  { id = "test-other", version = "9.9", lines = { "never" } } }
  SK.ShowMessages(); SK.ShowMessages()
  print("MESSAGES seen now", ScrollkeeperDB.messagesSeen["test-now"], "other", ScrollkeeperDB.messagesSeen["test-other"])
end

-- 1.1.5 checks: categories by item ID (any language), drop tiers in the export, mailbox option
do
  print("CATEGORY german frog", SK.CategoryFor("Schriftrolle: Froschvertrauter", 277483), "unknown", SK.CategoryFor("Rolle: Etwas", 1))
  SK.db.dropTiers = { [1458] = { [50] = 3 } }
  local text = SK.ExportText()
  print("EXPORT has D line", text:find("\nD|1458|50:3", 1, true) ~= nil)
  local before = #SK.MailPlan()
  SK.db.mailIncludeMine = true
  local after = SK.MailPlan()
  local mine = 0; for _, p in ipairs(after) do mine = mine + (p.mineToo or 0) end
  SK.db.mailIncludeMine = false
  print("MAILMINE people", before, "->", #after, "you'd use too", mine)
end

-- Secret values (the client hides some unit info): SK.Known turns them into nil.
do
  local SECRET = {}
  issecretvalue = function(v) return v == SECRET end
  print("KNOWN secret ->", SK.Known(SECRET), " plain ->", SK.Known(true))
  issecretvalue = nil
end

-- Running-out reminder: an imbue with 3 minutes left (setting: 5) pops up once.
if SK.isMage then
  local realEnchant = GetWeaponEnchantInfo
  GetWeaponEnchantInfo = function() return true, 180000 end
  fire("UNIT_INVENTORY_CHANGED", "player"); runTimers()
  local left = SK.BuffTimeLeft()
  print("EXPIRING imbue left", left.imbue and math.floor(left.imbue))
  print("EXPIRING no scroll ->", SK.BestScroll("imbues") == nil and "held back" or "has one")
  local realBest = SK.BestScroll
  SK.BestScroll = function(category) return category == "imbues" and { itemID = 275069, name = "Scroll of Imbue Frost" } or nil end
  SK.CheckExpiring()
  print("EXPIRING toast", ScrollkeeperToast and ScrollkeeperToast:IsShown(), ScrollkeeperToast and ScrollkeeperToast.title:GetText())
  ScrollkeeperToast:Hide(); SK.CheckExpiring()
  print("EXPIRING again (should stay hidden)", ScrollkeeperToast:IsShown())
  GetWeaponEnchantInfo, SK.BestScroll = realEnchant, realBest
end

-- Khadgar's Unlocking: a hint on locked chests (a fake tooltip).
if SK.isMage then
  local realCount, lines, added = SK.UnlockingCount, { "Battered Chest", "Locked" }, {}
  SK.UnlockingCount = function() return 2 end
  _G.FakeTipTextLeft1 = { GetText = function() return lines[1] end }
  _G.FakeTipTextLeft2 = { GetText = function() return lines[2] end }
  local tip = { GetName = function() return "FakeTip" end, NumLines = function() return #lines end,
    GetItem = function() end, GetUnit = function() end, Show = function() end,
    AddLine = function(_, text) added[#added + 1] = text end }
  SK.UnlockHint(tip)
  print("UNLOCK hint:", added[1], "|", added[2])
  local plain = { GetName = function() return "FakeTip" end, NumLines = function() return 1 end,
    GetItem = function() end, GetUnit = function() end, Show = function() end, AddLine = function() error("no hint on unlocked things") end }
  SK.UnlockHint(plain)
  print("UNLOCK button:", ScrollkeeperUnlockButton and ScrollkeeperUnlockButton._attrs.type, ScrollkeeperUnlockButton and ScrollkeeperUnlockButton._attrs.item)
  SK.UnlockingCount = realCount
end

-- Our channel never keeps /1: moved after the game's own, others keep their order.
do
  local chans = { "ScrollkeeperNet", "General", "Trade", "LocalDefense" }
  local realList, realChat = GetChannelList, C_ChatInfo
  GetChannelList = function() local t = {}; for i, n in ipairs(chans) do t[#t+1] = i; t[#t+1] = n; t[#t+1] = false end; return (unpack or table.unpack)(t) end
  C_ChatInfo = setmetatable({ SwapChatChannelsByChannelIndex = function(a, b) chans[a], chans[b] = chans[b], chans[a]; return true end }, { __index = realChat })
  SK.Net.MoveChannelLast()
  print("CHANNELS after move:", table.concat(chans, ", "))
  GetChannelList, C_ChatInfo = realList, realChat
end

-- Library books: hand-ins counted from the quests the game says are done.
do
  local done = { [90001] = true, [90002] = true }
  local realLog = C_QuestLog
  C_QuestLog = setmetatable({ IsQuestFlaggedCompleted = function(id) return done[id] or false end }, { __index = realLog })
  SK.db.bookQuests = { [90001] = true, [90002] = true, [90003] = true }
  local handed, reward = SK.BookProgress()
  print("BOOKS handed", handed, "next at", reward and reward.books, reward and SK.BookRewardText(reward))
  C_QuestLog = realLog
  SK.db.bookQuests = nil
  print("MOVING label ok", pcall(SK.UpdateDecipherLabel))
end

-- Your own Doorways whisper: {place} filled in.
do
  print("WHISPER default:", SK.DoorWhisper("Tarren Mill"))
  SK.db.doorWhisper = "yo {name}, {me} here, {place} in {zone}, {scroll} {nope} 100% inv pls"
  print("WHISPER custom:", SK.DoorWhisper("Tarren Mill", { name = "Runey", zone = "Hillsbrad" }), "|", SK.DoorWhisper(nil))
  SK.db.doorWhisper = nil
end

-- Doorways: clicking someone /who found checks they're still there first.
do
  local realFL = C_FriendList
  local results, sent = {}, {}
  C_FriendList = setmetatable({
    SendWho = function(q) sent[#sent + 1] = q end,
    SetWhoToUi = function() end,
    GetNumWhoResults = function() return #results end,
    GetWhoInfo = function(i) return results[i] end,
  }, { __index = realFL })
  local place = SK.DOOR_PLACES[1]   -- Booty Bay
  local realMapInfo = C_Map.GetMapInfo
  C_Map.GetMapInfo = function() return { name = "Stranglethorn Vale" } end
  local got
  results = { { fullName = "Runey", area = place.town, level = 40, classStr = "Hunter" } }
  SK.DoorRecheck({ name = "Runey" }, place, function(person, checked) got = { person, checked } end)
  fire("WHO_LIST_UPDATE")
  print("RECHECK still there:", got[1] and got[1].area, got[1] and got[1].inTown, got[2], "| query:", sent[#sent])
  results, got = {}, nil
  SK.DoorRecheck({ name = "Runey" }, place, function(person, checked) got = { person, checked } end)
  fire("WHO_LIST_UPDATE")
  print("RECHECK moved away:", got[1], got[2])
  C_FriendList, C_Map.GetMapInfo = realFL, realMapInfo
end

-- Doorways: places you can teleport to yourself go to the bottom.
do
  local realKnown = IsPlayerSpell
  IsPlayerSpell = function(id) return id == 3567 end   -- Teleport: Orgrimmar
  local list = SK.DoorPlaces()
  print("PLACES last:", list[#list].place.town, list[#list].own, "| first:", list[1].place.town)
  IsPlayerSpell = realKnown
end

-- Mage history: remembered when heard, offline ones listed, at most 15.
do
  SK.db.mageHistory = {}
  local realRealm = GetRealmName
  GetRealmName = function() return "CAMWOW US1 Realm 1 PvE" end
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "H|1|1.1.9|MAGE|30|80|150|15.50||", "GUILD", "Histo-Realm")
  print("HISTORY saved:", SK.db.mageHistory["Histo"] and SK.db.mageHistory["Histo"].level)
  SK.peers["Histo-Realm"].seen = 0   -- gone stale
  local list = SK.MageHistory()
  print("HISTORY offline list:", #list, list[1] and list[1].name, list[1] and list[1].tiers[50])
  for i = 1, 20 do SK.db.mageHistory["M" .. i] = { name = "M" .. i, seen = time() - i, tiers = {} } end
  SK.db.mageHistory["Old"] = { name = "Old", seen = time() - 8 * 86400, tiers = {} }
  local n = 0; for _ in pairs(SK.db.mageHistory) do n = n + 1 end
  SK.MageHistory(); local m = 0; for _ in pairs(SK.db.mageHistory) do m = m + 1 end
  print("HISTORY capped:", n, "->", m, "old kept?", SK.db.mageHistory["Old"] ~= nil)
  GetRealmName = realRealm
  SK.db.mageHistory = nil
end

-- Connected realms: other PvE realms are reachable, other server kinds aren't.
do
  local realRealm, realNorm = GetRealmName, GetNormalizedRealmName
  GetRealmName = function() return "CAMWOW US1 Realm 1 PvE" end
  GetNormalizedRealmName = function() return "CAMWOWUS1Realm1PvE" end
  for _, sender in ipairs({ "Pve2-CAMWOWUS1Realm2PvE", "Same-CAMWOWUS1Realm1PvE", "Rppvp-CAMWOWUS1Realm9RPPvP", "Pvp-CAMWOWUS2Realm6PvP", "Rp-CAMWOWUS1Realm3RP", "Local" }) do
    SK.peers[sender] = { class = "MAGE", tiers = {}, upgrades = {}, seen = time(), level = 20, skill = 50 }
    print("REALM", sender, SK.IsUnreachable(sender) and "unreachable" or "reachable")
    SK.peers[sender] = nil
  end
  -- The game gives an empty realm name: the remembered one is used.
  print("RULESET known", SK.ServerKind())
  GetRealmName = function() return "" end
  GetNormalizedRealmName = function() return "" end
  print("RULESET empty realm", SK.ServerKind(), "realm", SK.RealmName())
  GetRealmName, GetNormalizedRealmName = realRealm, realNorm
  -- Waypoints go to Zygor's arrow when it's there.
  local got
  ZygorGuidesViewer = { Pointer = { SetWaypoint = function(self, m, x, y, data) got = { m, x, y, data.title } return {} end } }
  print("WAYPOINT zygor", SK.SetWaypoint(1454, 0.38, 0.78, "Library"), got and table.concat({ got[1], got[2], got[3], got[4] }, " "))
  ZygorGuidesViewer = nil
end

-- On a priest with a mage: listed and mailed as the mage.
do
  local realRealm = GetRealmName
  GetRealmName = function() return "Realm" end
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "H|1|1.2.0|PRIEST|30|0|0|||Player-1-ABCD|||Rotmage|120|50", "GUILD", "Rotting Reverend")
  local peer = SK.peers["Rotting Reverend"]
  print("ALT peer:", peer and peer.alt and peer.alt.name, peer and peer.alt and peer.alt.skill, peer and peer.alt and peer.alt.tiers[50])
  local found
  for _, mage in ipairs(SK.FreshMages()) do if mage.altOf == "Rotting Reverend" then found = mage end end
  print("ALT in mail list:", found and found.name, found and found.short, found and found.skill)
  print("ALT needs 50:", #SK.MagesWhoNeed(50) > 0)
  SK.peers["Rotting Reverend"] = nil
  GetRealmName = realRealm
end

-- "Fellow PvE Mages"
do
  local realRealm = GetRealmName
  for _, realm in ipairs({ "CAMWOW US1 Realm 1 PvE", "CAMWOW US1 Realm 9 RPPvP", "CAMWOW US2 Realm 6 PvP", "CAMWOW US1 Realm 4 Hardcore", "Cam Wow AU 1 Realm 2 PvP", "Forever" }) do
    GetRealmName = function() return realm end
    print("TITLE", realm, "->", SK.FellowMagesTitle())
  end
  GetRealmName = realRealm
end

-- History never repeats someone still in the live list (even marked offline).
do
  local realRealm = GetRealmName
  GetRealmName = function() return "Realm" end
  SK.db.mageHistory = {}
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "H|1|1.2.0|MAGE|20|64|100|15.50||", "GUILD", "Turbo-Realm")
  SK.peers["Turbo-Realm"].offline, SK.peers["Turbo-Realm"].offlineAt = true, time()
  print("DUP history while listed:", #SK.MageHistory())
  SK.peers["Turbo-Realm"] = nil
  print("DUP history once gone:", #SK.MageHistory())
  SK.db.mageHistory = nil
  GetRealmName = realRealm
end

-- Whisper/mail names: same server (any layer) by plain name, other servers keep the realm.
do
  local realRealm, realInfo = GetRealmName, GetPlayerInfoByGUID
  GetRealmName = function() return "CAMWOW US1 Realm 1 PvE" end
  local realms = { ["Player-1-AA"] = "CAMWOWUS1Realm3PvE", ["Player-1-BB"] = "CAMWOWUS1Realm9RPPvP" }
  GetPlayerInfoByGUID = function(guid) return "Mage", "MAGE", "Undead", "Scourge", 2, guid == "Player-1-AA" and "Count Turbo" or "Seifer", realms[guid] end
  SK.peers["T"] = { guid = "Player-1-AA", class = "MAGE", tiers = {}, upgrades = {}, seen = time() }
  SK.peers["S"] = { guid = "Player-1-BB", class = "MAGE", tiers = {}, upgrades = {}, seen = time() }
  print("CONTACT", SK.ContactName("T"), "|", SK.ContactName("S"))
  SK.peers["T"], SK.peers["S"] = nil, nil
  GetRealmName, GetPlayerInfoByGUID = realRealm, realInfo
end

-- History is per ruleset and faction (it's saved account-wide).
do
  local realRealm, realFaction = GetRealmName, UnitFactionGroup
  GetRealmName = function() return "CAMWOW US1 Realm 1 PvE" end
  UnitFactionGroup = function() return "Horde" end
  SK.db.mageHistory = { Turbo = { name = "Turbo", seen = time(), tiers = { 15 }, ruleset = "PvE", faction = "Horde", reached = true },
    Far = { name = "Far", seen = time(), tiers = { 15 }, ruleset = "PvE", faction = "Horde" } }   -- never reached: maybe another realm
  print("RULESET history on PvE Horde:", #SK.MageHistory())
  GetRealmName = function() return "CAMWOW US2 Realm 2 PvP" end
  UnitFactionGroup = function() return "Alliance" end
  print("RULESET history on PvP Alliance:", #SK.MageHistory())
  SK.db.mageHistory = nil
  GetRealmName, UnitFactionGroup = realRealm, realFaction
end

-- Ruleset in the hello: decides reachability; unknown-ruleset players aren't saved in the history.
do
  local realRealm, realInfo = GetRealmName, GetPlayerInfoByGUID
  GetRealmName = function() return "CAMWOW US1 Realm 3 RP" end
  GetPlayerInfoByGUID = function() return "Mage", "MAGE", "Undead", "Scourge", 2, "X", "" end   -- realm unknown
  SK.db.mageHistory = {}
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "H|1|1.2.0|MAGE|20|64|100|15.50||Player-1-AA||||||PvE", "CHANNEL", "Turbo")
  print("RULESET PvE seen from RP:", SK.IsUnreachable("Turbo") and "unreachable" or "reachable", "| saved:", SK.db.mageHistory["Turbo"] ~= nil)
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "H|1|1.1.9|MAGE|20|64|100|15.50||Player-1-AB", "CHANNEL", "Oldie")
  print("RULESET old client, realm unknown:", SK.IsUnreachable("Oldie") and "unreachable" or "reachable", "| saved:", SK.db.mageHistory["Oldie"] ~= nil)
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "H|1|1.2.0|MAGE|20|64|100|15.50||Player-1-AC||||||RP", "CHANNEL", "Rper")
  print("RULESET RP heard on the channel:", SK.IsUnreachable("Rper") and "unreachable" or "reachable", "| saved:", SK.db.mageHistory["X"] ~= nil)
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "H|1|1.2.0|MAGE|20|64|100|15.50||Player-1-AC||||||RP", "GUILD", "Rper")
  print("RULESET RP seen from RP (guild):", SK.IsUnreachable("Rper") and "unreachable" or "reachable", "| saved:", SK.db.mageHistory["X"] ~= nil)
  SK.peers["Turbo"], SK.peers["Oldie"], SK.peers["Rper"] = nil, nil, nil
  SK.db.mageHistory = nil
  GetRealmName, GetPlayerInfoByGUID = realRealm, realInfo
end

-- Your mages on another realm layer of the same ruleset count (mail, alt hello).
do
  local realRealm, realFaction, realMages = GetRealmName, UnitFactionGroup, SK.db.mages
  GetRealmName = function() return "CAMWOW US1 Realm 1 PvE" end
  UnitFactionGroup = function() return "Horde" end
  SK.db.mages = {
    ["Layermage-CAMWOW US1 Realm 3 PvE"] = { name = "Layermage", skill = 90, faction = "Horde" },
    ["Pvpmage-CAMWOW US2 Realm 6 PvP"] = { name = "Pvpmage", skill = 120, faction = "Horde" },
  }
  local names = {}
  for _, mage in ipairs(SK.MailableMages()) do names[#names + 1] = mage.name end
  print("LAYER mailable mages:", table.concat(names, ", "))
  GetRealmName, UnitFactionGroup, SK.db.mages = realRealm, realFaction, realMages
end

-- Network: who's-online messages jump ahead of bulk data in the send queue.
do
  local n0 = SK.Net.QueueLength()
  SK.Net.Send("T", "15#1", "1:2")
  SK.Net.Send("P", "1458#1", "3.4:1")
  SK.Net.Send("H", "1", "x")
  print("QUEUE grew by", SK.Net.QueueLength() - n0)
end

-- Dev network report builds without errors.
if SK.NetReport then
  local ok, text = pcall(SK.NetReportPlain)
  print("NETREPORT ok:", ok, ok and #text or text)
  if ok then print((text:gsub("\n.*", ""))) end
end

-- Dev inspector graphs: open, sample, draw.
if SK.commands.netdev and SK.NetDevSample then
  local dev = SK.devCopy; SK.devCopy = true
  SK.commands.netdev()
  for i = 1, 5 do SK.NetDevSample() end
  print("GRAPHS ok")
  SK.devCopy = dev
end

-- Map: drops close together become one circle with one pin.
do
  local acquired, provider = {}, nil
  CreateFromMixins = CreateFromMixins or function(...) local t = {} for _, m in ipairs({ ... }) do for k, v in pairs(m) do t[k] = v end end return t end
  MapCanvasDataProviderMixin = MapCanvasDataProviderMixin or {}
  local canvas = { GetWidth = function() return 1000 end, GetHeight = function() return 700 end }
  local map = {
    GetMapID = function() return 1429 end, GetCanvas = function() return canvas end,
    RemoveAllPinsByTemplate = function() end,
    AcquirePin = function(_, template, data) acquired[#acquired + 1] = { template, data } end,
  }
  WorldMapFrame = { AddDataProvider = function(_, p) provider = p end, IsShown = function() return false end }
  fire("ADDON_LOADED", "Blizzard_WorldMap")
  if provider then
    provider.GetMap = function() return map end
    SK.db.mapPins = true
    SK.db.drops = { [1429] = { ["10.10"] = 2, ["11.10"] = 3, ["12.11"] = 1, ["40.40"] = 1 } }
    SK.db.bookDrops = { [1429] = { ["20.20"] = 3, ["21.20"] = 1, ["21.21"] = 1, ["32.35"] = 2, ["10.40"] = 1, ["5.5"] = 3 } }
    -- A find named after a listed book but far from its spot: hidden.
    -- Named after it, found 3 times (more than the 2 at its spot): shown as moved.
    SK.db.bookNames = { ["1429:10.40"] = "Archmage Theocritus' Research Journal", ["1429:5.5"] = "Archmage Theocritus' Research Journal" }
    local ok, err = pcall(provider.DrawPins, provider)
    local areas, pins, books = 0, 0, 0
    for _, a in ipairs(acquired) do
      if a[1] == "ScrollkeeperMapAreaTemplate" then areas = areas + 1
      elseif a[2].kind == "drop" then pins = pins + 1
      elseif a[2].kind == "book" then books = books + 1 end
    end
    print("MAP CIRCLES", ok, err or "", "areas", areas, "drop pins", pins, "book pins", books)
    for _, a in ipairs(acquired) do
      if a[2].listed then print("MAP KNOWN BOOK", a[2].name, "found here", a[2].mine, a[2].outdated and "OUTDATED" or "") end
      if a[2].stale then print("MAP GREY BOOK", a[2].mine) end
      if a[2].movedHere then print("MAP MOVED HERE", a[2].name, a[2].mine) end
    end
    -- Tiers at a spot: recorded per spot, else the zone's mix.
    SK.db.cellTiers = { [1429] = { ["10.10"] = { [15] = 2 }, ["11.10"] = { [15] = 1, [50] = 2 } } }
    SK.db.dropTiers = { [1429] = { [15] = 9 } }
    local here = SK.TiersAt(1429, { "10.10", "11.10" })
    local zone = SK.TiersInZone(1429)
    print("MAP TIERS here", here and here[15], here and here[50], "zone 15:", zone and zone[15] or 0)
    -- Tier filter: only tier 50 spots, then back to all.
    SK.db.drops = { [1429] = { ["10.10"] = 2, ["11.10"] = 3, ["40.40"] = 1 } }
    SK.db.mapTiers = 50
    acquired = {}
    provider:DrawPins()
    local drops50 = 0
    for _, a in ipairs(acquired) do if a[2].kind == "drop" then drops50 = drops50 + 1 end end
    SK.db.mapTiers = "all"
    -- Open doors on the map.
    SK.doors = { ["Doory"] = { place = "Goldshire, Elwynn Forest", map = 1429, x = 44, y = 66, at = time(), scrolls = 1 } }
    SK.peers["Doory"] = { class = "MAGE", tiers = {}, upgrades = {}, seen = time(), level = 20, skill = 10 }
    acquired = {}
    provider:DrawPins()
    local doors = 0
    for _, a in ipairs(acquired) do if a[2].kind == "door" then doors = doors + 1 end end
    SK.peers["Doory"], SK.doors = nil, {}
    print("MAP FILTER tier 50 drop pins", drops50, "door pins", doors)
  else
    print("MAP CIRCLES no provider")
  end
end

-- Shipped community data: dump it in a fixed order (compare packed vs old).
do
  local function Dump(v)
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. Dump(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  local players = 0
  for _ in pairs(SK.COMMUNITY_DATA or {}) do players = players + 1 end
  local text = Dump(SK.COMMUNITY_DATA or {})
  print("COMMUNITY players", players, "size", #text)
end

-- Books: only real ones count (no more "any Journal or Tome").
print("ISBOOK listed", SK.IsBook(nil, "Goaz Scrolls"), "quest item", SK.IsBook(99999, "Torn Journal Page"), "old word", SK.IsBook(nil, "Tome of Something"))

-- Loot log: where a scroll came from (the mob), saved with the details.
do
  GetNumLootItems = function() return 1 end
  GetLootSlotLink = function() return "|cffffffff|Hitem:277600::::::::20:::::|h[Scroll: TEST]|h|r" end
  GetLootSourceInfo = function() return "Creature-0-1-2-3-2240-0000ABCD", 1 end
  fire("LOOT_OPENED")
  SK.LogLoot("scroll", 277600, 15, 1)
  local e = SK.db.lootLog[#SK.db.lootLog]
  print("LOOTLOG", e.kind, e.item, e.tier, e.src, e.srcID, e.lvl ~= nil, #SK.db.lootLog)
  local text = SK.ExportText()
  print("LOOTLOG export has Z", text:find("\nZ|", 1, true) ~= nil)
end

-- Libraries: a shared spot in Stormwind (the Royal Library) isn't shown to the Horde.
do
  local realFaction, realPlace = UnitFactionGroup, SK.WorldToMap
  SK.WorldToMap = function(inst, x, y) return (x % 1000) / 1000, (math.abs(y) % 1000) / 1000 end
  SK.db.sharedLibraries = { ["0_41_-836"] = { inst = 0, x = 410.4, y = -8356.9, name = "Royal Library", from = { X = true } } }
  SK.db.libraryPins = {}
  local function Names(f)
    UnitFactionGroup = function() return f end
    local names = {}
    for _, pin in ipairs(SK.LibraryPins(1415)) do names[#names + 1] = pin.name end
    table.sort(names)
    return table.concat(names, ", ")
  end
  print("LIBRARIES Horde:", Names("Horde"), "| Alliance:", Names("Alliance"))
  UnitFactionGroup, SK.WorldToMap = realFaction, realPlace
end

-- Setup: sharing and language answered on a mage aren't asked again elsewhere.
do
  SK.db.setupSeenAccount = nil
  SK.db.setupSeen = { sharing = 2, language = 1 }
  SK.db.setupSeenOther = {}
  local asked = {}
  local realShow = SK.RefreshSetupPage
  SK.ShowSetup(false, true)
  print("SETUP account seen", SK.db.setupSeenAccount and SK.db.setupSeenAccount.sharing, SK.db.setupSeenAccount and SK.db.setupSeenAccount.language)
end

-- Simple is gone: anyone on it becomes Anonymous.
do
  SK.SetSharing("simple")
  print("SIMPLE becomes", SK.db.sharing, "channel", SK.db.shareChannel, "anonymous", SK.db.anonymous)
  SK.SetSharing("full")
end

-- Sharing None still hears about a newer version.
do
  SK.SetSharing("none")
  local printed = ""
  local realPrint = SK.Print
  SK.Print = function(text) printed = printed .. tostring(text) end
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "H|1|9.9.9|MAGE|30|80|150|15||", "GUILD", "Newer-Realm")
  SK.Print = realPrint
  print("NONE update notice", printed:find("9.9.9", 1, true) ~= nil, "peer added", SK.peers["Newer-Realm"] ~= nil)
  SK.SetSharing("full")
end

-- Did setup before the reminders page: not asked about it.
do
  SK.db.setupDone = true
  SK.db.setupSeen = { viewMode = 1, open = 1, hideInCombat = 1 }
  SK.db.setupSeenAccount = { sharing = 2, language = 1 }
  SK.Send("READY")
  print("REMINDERS page skipped for old setups", SK.isMage and SK.db.setupSeen.reminders or "not a mage")
end

-- Reminder pop-ups in combat only when asked for.
print("REMINDER in combat default", SK.db.reminderInCombat)

-- Renew keys: pointed at the best imbue and familiar scrolls.
do
  if SK.PointRenewButtons then SK.PointRenewButtons() end
  print("RENEW imbue", ScrollkeeperImbueKey and ScrollkeeperImbueKey.itemID, "familiar", ScrollkeeperFamiliarKey and ScrollkeeperFamiliarKey.itemID)
end

-- Setup keys page: a key already used elsewhere is refused.
do
  local bound = { ["F"] = "JUMP" }
  GetBindingAction = function(key) return bound[key] or "" end
  GetBindingKey = function(command) for k, v in pairs(bound) do if v == command then return k end end end
  SetBinding = function(key, command) bound[key] = command end
  SaveBindings = function() end
  GetCurrentBindingSet = function() return 1 end
  print("KEYS F before", bound["F"], "| G free", bound["G"] == nil)
end

-- This character's own layout: its panel size is saved apart from the account's.
do
  SK.db.scale = 1
  SK.SetCharacterLayout(true)
  SK.db.scale = 1.3
  fire("PLAYER_LOGOUT")
  local accountAfterLogout, charSaved = SK.db.scale, SK.charDB.layout.scale
  SK.LoadCharacterLayout()
  print("CHARLAYOUT account", accountAfterLogout, "char saved", charSaved, "back in game", SK.db.scale)
  SK.SetCharacterLayout(false)
  print("CHARLAYOUT off ->", SK.db.scale)
end

-- Imbues follow the spec: Fire picks a flame imbue over a higher frost one.
do
  local realTabs, realInfo = GetNumTalentTabs, GetTalentTabInfo
  GetNumTalentTabs = function() return 3 end
  GetTalentTabInfo = function(tab) return "Tree" .. tab, "icon", tab == 2 and 20 or 0 end
  print("SPEC", SK.MageSpec(), "| school of Balefrost:", SK.ImbueSchool({ name = "Scroll of Imbue Balefrost" }),
    "| Greater Flame:", SK.ImbueSchool({ name = "Scroll of Imbue Greater Flame" }), "| Manablade:", SK.ImbueSchool({ name = "Scroll of Imbue Manablade" }))
  GetNumTalentTabs, GetTalentTabInfo = realTabs, realInfo
end

-- Favorites: the imbue you use most wins.
do
  SK.charDB.scrollUses = { [277485] = 3 }
  print("FAVORITE uses of 277485:", SK.ScrollUses(277485), "| unknown:", SK.ScrollUses(1))
end

-- Scroll Guide: both tabs open without errors.
do
  SlashCmdList.SCROLLKEEPER("guide")
  local f = ScrollkeeperGuideFrame
  print("GUIDE shown", f and f:IsShown(), "top", f and f.top and f.top._text)
  -- (The mock's GetID doesn't remember SetID.)
  if f then for i, t in ipairs(f.tabs) do t.GetID = function() return i end end end
  if f then f.booksTab:GetScript("OnClick")(f.booksTab) end
  print("GUIDE books top", f and f.top and f.top._text)
  if f then f.tabs[3]:GetScript("OnClick")(f.tabs[3]) end
  print("GUIDE rewards note", f and f.note and f.note._text)
  print("REWARD last", SK.NextRewardText(SK.BOOK_REWARDS[4]), SK.RewardBooks(SK.BOOK_REWARDS[4]))
  if f then f.scrollsTab:GetScript("OnClick")(f.scrollsTab) end
end

-- Codex books tab: a known book shows as a link.
do
  SK.db.bookIDs = { [207972] = "The Lessons of Ta'zo" }
  print("CODEX book id", SK.BookIDsByName()["the lessons of ta'zo"])
end

-- Mail only offers people a whisper reached (the channel spans other realms).
do
  local function InPlan(name)
    for _, p in ipairs(SK.MailPlan()) do if p.name == name then return true end end
    return false
  end
  local hello = "H|1|1.2.3|MAGE|20|20|100|1.15.50||Player-1-ZZ||||||"
  fire("CHAT_MSG_ADDON", "Scrollkeeper", hello, "CHANNEL", "Faraway")
  print("REACH channel only, in mail:", InPlan("Faraway"))
  SK.CheckOnline("Faraway")
  fire("CHAT_MSG_ADDON", "Scrollkeeper", hello, "WHISPER", "Faraway")
  print("REACH answered a whisper, in mail:", InPlan("Faraway"), "| reached:", SK.peers["Faraway"].reached ~= nil)
  SK.peers["Faraway"] = nil
end

-- Scroll icon as an action button: Study in a library, else a bundle, else decipher.
if SK.isMage then
  local realLib, realKnows, realLeft, realBags = SK.InLibrary, SK.KnowsStudy, SK.StudySecondsLeft, SK.bags
  SK.db.scrollIcon = true
  SK.bags = { untranslated = realBags.untranslated, translated = realBags.translated, counts = realBags.counts or {}, names = realBags.names or {},
    feathers = 2, bundles = 3, bundleBag = 1, bundleSlot = 4 }
  SK.InLibrary, SK.KnowsStudy, SK.StudySecondsLeft = function() return true end, function() return true end, function() return 0 end
  SK.RefreshIcon()
  print("ICONACTION library:", SK.IconAction(), ScrollkeeperIcon:GetAttribute("type1"), ScrollkeeperIcon:GetAttribute("spell1") == SK.SPELL_STUDY)
  SK.InLibrary = function() return false end
  SK.RefreshIcon()
  print("ICONACTION bundle:", SK.IconAction(), ScrollkeeperIcon:GetAttribute("type1"), ScrollkeeperIcon:GetAttribute("item1"))
  SK.bags.bundles, SK.bags.bundleBag = 0, nil
  SK.RefreshIcon()
  print("ICONACTION else:", SK.IconAction())
  SK.InLibrary, SK.KnowsStudy, SK.StudySecondsLeft, SK.bags = realLib, realKnows, realLeft, realBags
  SK.RefreshIcon()
end

-- Escape closes the panel (through its stand-in on UISpecialFrames).
do
  local panel = ScrollkeeperPanel
  if panel and ScrollkeeperPanelEscape then
    panel:Show()
    print("ESCAPE in combat?", SK.InCombat())
    ScrollkeeperPanelEscape:Hide()
    ScrollkeeperPanelEscape:GetScript("OnHide")(ScrollkeeperPanelEscape)   -- (the mock doesn't run scripts)
    print("ESCAPE closed panel:", not panel:IsShown(), "| showPanel:", SK.db.showPanel)
    panel:Show(); SK.db.showPanel = true
  else
    print("ESCAPE no panel", panel ~= nil, ScrollkeeperPanelEscape ~= nil)
  end
end

-- Spec beats the one you use most: a Frost mage gets the (lower) Frost imbue.
if SK.isMage then
  local realTabs, realInfo, realFits, realBags, realUses = GetNumTalentTabs, GetTalentTabInfo, SK.ImbueFits, SK.bags, SK.charDB.scrollUses
  GetNumTalentTabs = function() return 3 end
  GetTalentTabInfo = function(tab) return "Tree" .. tab, "icon", tab == 3 and 20 or 0 end   -- Frost
  SK.ImbueFits = function() return true end
  SK.bags = { translated = {
    { itemID = 277500, name = "Scroll of Imbue Greater Flame", category = "imbues", level = 20, count = 1 },
    { itemID = 277485, name = "Scroll of Imbue Frost", category = "imbues", level = 5, count = 1 },
  }, untranslated = {}, counts = {}, names = {} }
  SK.charDB.scrollUses = { [277500] = 9 }
  local pick
  for _, group in ipairs(SK.ScrollGroups()) do
    if group.key == "imbues" then for _, s in ipairs(group.scrolls) do if s.best then pick = s.name end end end
  end
  print("SPECFIRST frost mage picks:", pick, "| reason:", SK.ScrollReason({ itemID = 277485, category = "imbues", forSpec = true }))
  SK.db.imbueByUse = true
  pick = nil
  for _, group in ipairs(SK.ScrollGroups()) do
    if group.key == "imbues" then for _, s in ipairs(group.scrolls) do if s.best then pick = s.name end end end
  end
  print("SPECFIRST option on, picks:", pick)
  SK.db.imbueByUse = false
  table.remove(SK.bags.translated, 2)   -- no Frost imbue left: Flame isn't suggested
  print("SPECFIRST only Flame, frost mage best:", SK.BestScroll("imbues") and SK.BestScroll("imbues").name or "none", "| says why:", SK.NoImbueForSpec())
  SK.db.imbueByUse = false
  GetNumTalentTabs, GetTalentTabInfo, SK.ImbueFits, SK.bags, SK.charDB.scrollUses = realTabs, realInfo, realFits, realBags, realUses
end

-- Forever's talents (no talent tabs there): C_Traits columns, points per tree.
if SK.isMage then
  local realTraits, realClass, realTabs = C_Traits, C_ClassTalents, GetNumTalentTabs
  GetNumTalentTabs = nil
  -- 20 points in Frost talents (135310, 135309), 0 elsewhere; one Arcane node unspent.
  local nodes = { [1] = { def = 135310, rank = 15 }, [2] = { def = 135309, rank = 5 }, [3] = { def = 135345, rank = 0 } }
  C_ClassTalents = { GetActiveConfigID = function() return 4444013 end }
  C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 7 } } end,
    GetTreeNodes = function() return { 1, 2, 3 } end,
    GetNodeInfo = function(_, id) return { currentRank = nodes[id].rank, activeEntry = { entryID = id } } end,
    GetEntryInfo = function(_, id) return { definitionID = nodes[id].def } end,
  }
  fire("TRAIT_CONFIG_UPDATED")
  print("FOREVERSPEC frost:", SK.MageSpec(), "| name:", SK.SpecName())
  nodes[1].rank, nodes[2].rank = 0, 0
  fire("TRAIT_CONFIG_UPDATED")
  print("FOREVERSPEC no points:", SK.MageSpec())
  C_Traits, C_ClassTalents, GetNumTalentTabs = realTraits, realClass, realTabs
  fire("TRAIT_CONFIG_UPDATED")
end

-- SCROLL BAG: keep / extra / set aside, presets, pins, actions
if SK.isMage then
  local function S(id, name, count) return { id = id, name = name, count = count, tip = { name, "Classes: Mage" } } end
  for slot = 1, 16 do BAGS[3][slot] = nil end
  BAGS[3][1] = S(213550, "Scroll of Polymorph: Odd Melon", 3)
  BAGS[3][2] = S(213550, "Scroll of Polymorph: Odd Melon", 5)
  BAGS[3][3] = S(277489, "Scroll of Imbue Spark", 2)
  BAGS[3][4] = S(277493, "Scroll of Cat Familiar", 4)
  BAGS[3][5] = S(277492, "Scroll of Khadgar's Unlocking", 5)
  BAGS[3][6] = S(277492, "Scroll of Khadgar's Unlocking", 3)
  BAGS[3][7] = S(213548, "Scroll of Liminal Passage", 3)
  BAGS[-1] = { [1] = S(277492, "Scroll of Khadgar's Unlocking", 4), [2] = S(277489, "Scroll of Imbue Spark", 5) }
  C_Item.GetItemNameByID = function(id) return SK.MAGE_SCROLL_IDS[id] or ("item" .. id) end
  fire("BAG_UPDATE_DELAYED"); runTimers()
  fire("BANKFRAME_OPENED"); runTimers()
  local function Dump(label)
    local parts = {}
    for _, e in ipairs((SK.StashList())) do
      parts[#parts + 1] = ("%s=%d(%s%s)"):format(e.name:gsub("^Scroll of ", ""), e.total, e.status, e.extra > 0 and (" " .. e.extra) or "")
    end
    print(label, table.concat(parts, "  "))
  end
  Dump("BAG satchel:")
  print("BAG note melon:", SK.StashNote(213550), "| spark:", SK.StashNote(277489))
  local stacks = SK.ExtraStacks(213550, 7)
  print("BAG extra stacks melon:", #stacks, stacks[1].count, stacks[1].take, stacks[2] and stacks[2].take)
  print("BAG slot status 3:1", SK.StashSlotStatus(3, 1, 213550), "3:2", SK.StashSlotStatus(3, 2, 213550), "3:4", SK.StashSlotStatus(3, 4, 277493))
  SK.UseBagPreset("kit"); Dump("BAG kit:")
  SK.SetKeepAmount(277492, 20); print("BAG changed:", SK.BagPresetChanged(), SK.KeepAmount(277492))
  print("BAG save:", SK.SaveBagPreset("Mine"), SK.BagPreset(), SK.KeepAmount(277492), SK.BagPresetChanged())
  print("BAG builtin name refused:", SK.SaveBagPreset("Battlemage's Kit"))
  print("BAG rename:", SK.RenameBagPreset("Mine", "Raid night"), SK.BagPreset())
  SK.DeleteBagPreset("Raid night"); print("BAG deleted, back to:", SK.BagPreset())
  -- a sword in the bags: Spark isn't set aside any more
  BAGS[4][9] = { id = 5555, name = "Sword", count = 1, tip = { "Sword" } }
  local realInstant = C_Item.GetItemInfoInstant
  C_Item.GetItemInfoInstant = function(id) if id == 5555 then return id, "Weapon", "Swords", "", 1, 2, 7 end return realInstant(id) end
  fire("BAG_UPDATE_DELAYED"); runTimers()
  Dump("BAG with sword:")
  BAGS[4][9] = nil; C_Item.GetItemInfoInstant = realInstant
  fire("BAG_UPDATE_DELAYED"); runTimers()
  -- pins
  SK.TogglePin(277493); print("BAG pin cat:", SK.IsPinned(277493), SK.PinOf("familiars"))
  SK.TogglePin(277489); print("BAG pin spark:", SK.PinOf("imbues", "sword"))
  SK.TogglePin(277493); print("BAG unpin cat:", SK.IsPinned(277493))
  -- the window
  SK.UseBagPreset("satchel")
  SK.ToggleScrollBag(); SK.RefreshScrollBag(); runTimers()
  print("BAG window built:", ScrollkeeperBagFrame ~= nil, "errors:", #ScrollkeeperDB.errors)
  -- sell at a vendor: two Odd Melon stacks (3 and 5), keep 1 -> sell the 3, split 4 off the 5
  MerchantFrame = { IsShown = function() return true end }
  local sold, cursor = {}, nil
  C_Container.GetContainerFreeSlots = function(bag) if bag == 4 then return { 12 } end return {} end
  C_Container.UseContainerItem = function(b, s) local i = BAGS[b][s]; sold[#sold + 1] = i.count .. "x" .. i.id; BAGS[b][s] = nil end
  C_Container.SplitContainerItem = function(b, s, n) BAGS[b][s].count = BAGS[b][s].count - n; cursor = { id = BAGS[b][s].id, name = BAGS[b][s].name, count = n, tip = BAGS[b][s].tip } end
  C_Container.PickupContainerItem = function(b, s) if cursor then BAGS[b][s] = cursor; cursor = nil end end
  SK.db.bagConfirm = false
  SK.ScrollBagActions.sell()
  for _ = 1, 10 do runTimers() end
  print("BAG sold:", table.concat(sold, ", "), "| melons left in bags:", BAGS[3][2] and BAGS[3][2].count)
  -- chat note on a decipher result
  print("BAG tooltip line:", (function()
    local tip = { added = {} }
    function tip:AddLine(t) self.added[#self.added + 1] = t end
    function tip:AddDoubleLine(a, b) self.added[#self.added + 1] = a .. " | " .. b end
    for _, fn in ipairs(TOOLTIP_CALLS) do fn(tip, { id = 277492, lines = { { leftText = "Scroll of Khadgar's Unlocking" }, { leftText = "Classes: Mage" } } }) end
    return tip.added[#tip.added]
  end)())
  -- Liminal Passage running low
  SK.db.liminalLow = 2
  local realCount = C_Item.GetItemCount; C_Item.GetItemCount = function() return 3 end; fire("BAG_UPDATE_DELAYED"); C_Item.GetItemCount = function() return 1 end; fire("BAG_UPDATE_DELAYED"); runTimers(); C_Item.GetItemCount = realCount
  print("BAG liminal low:", SK.LiminalLowText())
  print("BAG errors:", #ScrollkeeperDB.errors)
  for _, e in ipairs(ScrollkeeperDB.errors) do print("  ", e.where, e.error) end
  MerchantFrame = nil
end

-- MODULES: turn features off
if SK.isMage then
  SK.db.moduleBag = false; SK.db.moduleCodex = false
  SK.ToggleScrollBag(); SK.ToggleGuide()
  print("MODULES bag on?", SK.ModuleOn("Bag"), "plan on?", SK.ModuleOn("Plan"))
  SK.RefreshPanel()
  print("MODULES errors:", #ScrollkeeperDB.errors)
  SK.db.moduleBag = true; SK.db.moduleCodex = true
end

-- OPTIONS WINDOW: every section builds, and a change sticks
if SK.isMage then
  SK.OpenOptions()
  for i, section in ipairs(SK.OPTION_SECTIONS) do
    SK.OpenOptions(section.name)
  end
  SK.OpenOptions("Scroll Bag")
  SK.db.scale = 1
  SK.OptionChanged("scale")
  print("OPTIONS sections:", #SK.OPTION_SECTIONS, "window:", ScrollkeeperOptionsFrame ~= nil, "errors:", #ScrollkeeperDB.errors)
  for _, e in ipairs(ScrollkeeperDB.errors) do print("  ", e.where, e.error) end
end

-- THEMES: switch and back, nothing breaks
if SK.isMage then
  if SK.OpenOptions then SK.OpenOptions("Panel") end
  if SK.ToggleScrollBag and not (ScrollkeeperBagFrame and ScrollkeeperBagFrame:IsShown()) then SK.ToggleScrollBag() end
  for _, name in ipairs({ "dark", "dusk", "modern", "classic" }) do
    SK.db.theme = name; SK.OptionChanged("theme")
    print("THEME", SK.UI.ThemeName(), "stripe alpha", SK.UI.Palette().stripe[4])
  end
  local parent = CreateFrame("Frame")
  local button = CreateFrame("Button", nil, parent)
  for _, k in ipairs({ "Left", "Middle", "Right" }) do rawset(button, k, button:CreateTexture()) end
  local label = button:CreateFontString()
  rawset(button, "GetObjectType", function() return "Button" end)
  rawset(button, "GetFontString", function() return label end)
  rawset(button, "GetRegions", function() return button.Left, button.Middle, button.Right end)
  rawset(parent, "GetChildren", function() return button end)
  SK.db.theme = "modern"; SK.UI.SkinControls(parent)
  print("THEME modern button squared:", rawget(button, "skSquare") ~= nil)
  SK.db.theme = "classic"; SK.UI.SkinControls(parent)
  print("THEME classic button back:", rawget(button, "skSquare").bg:IsShown() == false)
  print("THEME errors:", #ScrollkeeperDB.errors)
  for _, e in ipairs(ScrollkeeperDB.errors) do print("  ", e.where, e.error) end
end

-- USAGE STATS: counting, sharing, hearing (dev copy), the report, and the required setup page
do
  SK.db.usage = nil
  print("USAGE default off:", SK.UsageWanted() == false)
  SK.db.shareUsage = true
  if SK.isMage then SK.ToggleScrollBag(); SK.ToggleScrollBag(); SK.OpenOptions("Sharing") end
  SK.Track("bag.sell"); SK.Track("bad name!")
  local c = SK.db.usage.counts
  print("USAGE counts open.bag:", c["open.bag"], "open.options:", c["open.options"], "bag.sell:", c["bag.sell"], "badname:", c["badname"])
  local sent = {}
  local realSend = SK.Net.Send
  SK.Net.Send = function(kind, ...) sent[#sent + 1] = kind .. "|" .. table.concat({ ... }, "|") end
  SK.db.theme = "dark"
  SK.SendUsage(true)
  print("USAGE sent parts:", #sent, sent[1] and sent[1]:sub(1, 60))
  local leaked = false
  for _, line in ipairs(sent) do if line:find(UnitName("player") or "?", 1, true) then leaked = true end end
  print("USAGE name in message?", leaked, "theme setting sent?", (table.concat(sent, ",")):find("set.theme=dark", 1, true) ~= nil)
  SK.db.shareUsage = false; sent = {}; SK.SendUsage(true); print("USAGE off sends:", #sent)
  SK.db.theme = "classic"
  SK.Net.Send = realSend
  local wasDev = SK.devCopy; SK.devCopy = true
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "UZ|abc123#1|open.bag:5,bag.sell:2,set.theme=dark", "GUILD", "Someone-Realm")
  local heard = SK.db.usageHeard and SK.db.usageHeard.abc123
  print("USAGE heard open.bag:", heard and heard.counts["open.bag"], "theme:", heard and heard.settings.theme, "sender saved?", (heard and tostring(heard.sender)) or "nil")
  local report = SK.UsageReport()
  print("USAGE report installs line:", report:match("(%d+ installs)"))
  SlashCmdList.SCROLLKEEPER("usage")
  SK.devCopy = wasDev
  -- Setup: the required page shows for old setups, and Skip can't pass it
  SK.db.setupSeenAccount = SK.db.setupSeenAccount or {}
  SK.db.setupSeenAccount.shareUsage = nil
  SK.ShowSetup(true)
  local f = ScrollkeeperSetupFrame
  print("USAGE setup shown:", f and f:IsShown(), "question:", f and f.question:GetText())
  if f then f.skip:GetScript("OnClick")(f.skip); print("USAGE page:", f.question:GetText()); print("USAGE after skip shown:", f:IsShown(), "skip visible:", f.skip:IsShown(), "seen:", SK.db.setupSeenAccount.shareUsage) end
  SK.db.shareUsage = true
  local function RunHooks(frame, name, ...) local h = rawget(frame, "_hooks"); for _, fn in ipairs(h and h[name] or {}) do fn(frame, ...) end end
  if f then f:Hide(); RunHooks(f, "OnHide"); print("USAGE escape -> shareUsage:", SK.db.shareUsage, "seen:", SK.db.setupSeenAccount.shareUsage) end
  if ScrollkeeperDecipherButton then
    RunHooks(ScrollkeeperDecipherButton, "OnClick", "LeftButton", true)
    RunHooks(ScrollkeeperDecipherButton, "OnClick", "LeftButton", false)
  end
  if ScrollkeeperFamiliarButton then RunHooks(ScrollkeeperFamiliarButton, "OnClick", "RightButton", false) end
  local infoList = table.concat(SK.UsageInfo(), " ")
  print("USAGE info:", infoList)
  SK.Safely("test break", function() error("boom") end)
  print("USAGE error counted:", SK.db.usage.counts["error.testbreak"], "session:", SK.db.usage.counts["session"])
  table.remove(ScrollkeeperDB.errors)
  print("USAGE decipher button clicks:", SK.db.usage.counts["panel.decipher"], "familiar right:", SK.db.usage.counts["panel.familiar.right"])
  print("USAGE errors:", #ScrollkeeperDB.errors)
  for _, e in ipairs(ScrollkeeperDB.errors) do print("  ", e.where, e.error) end
end


-- BETTERBAGS: category function, and re-sorting only when a scroll's category changes
if SK.isMage then
  local fns, wiped, reprocessed = {}, {}, 0
  local cats = {
    RegisterCategoryFunction = function(self, id, fn) fns[id] = fn end,
    WipeCategory = function(self, ctx, name) wiped[#wiped + 1] = name end,
    ReprocessAllItems = function(self, ctx) reprocessed = reprocessed + 1 end,
  }
  local modules = { Categories = cats, Context = { New = function(self, e) return { event = e } end }, Events = {} }
  local better = { GetModule = function(self, name) return modules[name] end }
  local realLibStub = LibStub
  LibStub = function(name) return { GetAddon = function(self, n) if n == "BetterBags" then return better end end } end
  SK.SetUpBetterBags()
  LibStub = realLibStub
  local fn = fns.scrollkeeper
  local list = SK.StashList()
  local first = list[1]
  print("BETTERBAGS registered:", fn ~= nil, "first scroll ->", first and fn({ itemInfo = { itemID = first.itemID } }), "non-scroll ->", fn({ itemInfo = { itemID = 6948 } }))
  SK.RefreshBagAddons()
  print("BETTERBAGS no change -> reprocessed:", reprocessed)
  local keepBefore = SK.KeepAmount(first.itemID)
  SK.SetKeepAmount(first.itemID, 0)
  SK.RefreshBagAddons()
  print("BETTERBAGS after keep change -> reprocessed:", reprocessed, "wiped:", #wiped, "now ->", fn({ itemInfo = { itemID = first.itemID } }))
  SK.SetKeepAmount(first.itemID, keepBefore)
  print("BETTERBAGS errors:", #ScrollkeeperDB.errors); for _, e in ipairs(ScrollkeeperDB.errors) do print("  ", e.where, e.error) end
end

-- MAIL TO: first name and surname kept, spaces tidied; your mages listed
if SK.isMage and ScrollkeeperBagFrame then
  print("MAILTO tidy:", "[" .. SK.TidyMailName("  Test   Sheep ") .. "]")
  local picks = ScrollkeeperBagFrame.mailPick
  picks:Fill()
  local first = picks.rows[1] and picks.rows[1].text:GetText()
  print("MAILTO first pick:", first)
  print("MAILTO errors:", #ScrollkeeperDB.errors)
end

-- USAGE WINDOW: opens, fills both ways (when it's loaded)
if SK.ToggleUsageWindow then
  SK.ToggleUsageWindow()
  local f = ScrollkeeperUsageFrame
  if f then f:Refresh() end
  print("USAGEWIN shown:", f and f:IsShown())
  if f then f.mine:GetScript("OnClick")(f.mine); f.everyone:GetScript("OnClick")(f.everyone) end
  print("USAGEWIN errors:", #ScrollkeeperDB.errors)
  for _, e in ipairs(ScrollkeeperDB.errors) do print("  ", e.where, e.error) end
end

-- NEWS IN CHAT: once, standing out
do
  SK.db.messagesSeen = {}
  SK.ShowMessages()
  SK.ShowMessages()
  print("NEWS errors:", #ScrollkeeperDB.errors)
end

-- NEW PRESET: never over an existing one; a free name suggested
if SK.isMage then
  local name = SK.NewBagPresetName()
  print("NEWPRESET first:", name, SK.SaveBagPreset(name, true))
  print("NEWPRESET again:", SK.SaveBagPreset(name, true))
  print("NEWPRESET next name:", SK.NewBagPresetName())
  SK.DeleteBagPreset(name)
  print("NEWPRESET errors:", #ScrollkeeperDB.errors)
end

-- ROW MENU: opens on a row, every option runs
if SK.isMage and ScrollkeeperBagFrame then
  SK.RefreshScrollBag()
  local list = SK.StashList()
  local imbue
  for _, e in ipairs(list) do if e.weapon then imbue = e break end end
  local row = { entry = imbue or list[1], pin = { IsShown = function() return true end } }
  SK.ShowBagRowMenu(row)
  local menu = ScrollkeeperBagRowMenu
  local n = 0
  for _, opt in ipairs(menu and menu.options or {}) do
    if rawget(opt, "text") and opt.text:GetText() then
      n = n + 1
      local before = #ScrollkeeperDB.errors
      opt:GetScript("OnClick")(opt)
      if #ScrollkeeperDB.errors > before then print("ROWMENU option broke:", opt.text:GetText()) end
      SK.ShowBagRowMenu(row)
    end
  end
  print("ROWMENU options:", n, "noAside set:", SK.db.bagNoAside and imbue and SK.db.bagNoAside[imbue.itemID])
  print("ROWMENU errors:", #ScrollkeeperDB.errors)
  for _, e in ipairs(ScrollkeeperDB.errors) do print("  ", e.where, e.error) end
end

-- HELP: every window with a "?" has its help, and the card opens
do
  local count = 0
  for _, b in ipairs(SK.UI.helpButtons or {}) do
    count = count + 1
    b:GetScript("OnEnter")(b); b:GetScript("OnClick")(b)
  end
  SK.db.helpButtons = false; SK.OptionChanged("helpButtons"); SK.db.helpButtons = true; SK.OptionChanged("helpButtons")
  print("HELP buttons:", count, "errors:", #ScrollkeeperDB.errors)
  for _, e in ipairs(ScrollkeeperDB.errors) do print("  ", e.where, e.error) end
end

-- ABOUT: team and thanks
do
  SK.OpenOptions("About")
  print("ABOUT errors:", #ScrollkeeperDB.errors)
  for _, e in ipairs(ScrollkeeperDB.errors) do print("  ", e.where, e.error) end
end

-- BUG REPORT: one text for a CurseForge comment
do
  local text = SK.BugReportText()
  print("BUGREPORT lines:", select(2, text:gsub("\n", "")) + 1, "first:", text:match("^[^\n]*"))
  SK.ShowBugReport()
  print("BUGREPORT errors:", #ScrollkeeperDB.errors)
end

-- CLOSE ALL: every window, the panel too (out of combat)
do
  if SK.isMage then SK.ToggleScrollBag(); SK.OpenOptions("Panel") end
  SK.CloseAllWindows()
  print("CLOSEALL bag:", ScrollkeeperBagFrame and ScrollkeeperBagFrame:IsShown(), "panel:", ScrollkeeperPanel and ScrollkeeperPanel:IsShown(), "errors:", #ScrollkeeperDB.errors)
  SK.db.showPanel = true
end

-- DEMO MAIL: demo mages show in the mailbox list
if SK.isMage and SK.ToggleDemo then
  SK.ToggleDemo()
  local plan = SK.MailPlan()
  local demo = 0
  for _, p in ipairs(plan) do if p.kind ~= "mine" then demo = demo + 1 end end
  print("DEMOMAIL people:", #plan, "not mine:", demo)
  SK.ToggleDemo()
end

-- BANK EXTRAS: the button is there, and says to open the bank first
if SK.isMage and SK.ScrollBagActions and SK.ScrollBagActions.bank then
  SK.ScrollBagActions.bank()
  print("BANKEXTRAS button:", ScrollkeeperBagFrame and ScrollkeeperBagFrame.buttons.bank ~= nil, "errors:", #ScrollkeeperDB.errors)
end

-- SYNC: both buttons there, and say where to go
if SK.isMage and ScrollkeeperBagFrame then
  SK.ScrollBagActions.bank(); SK.ScrollBagActions.mailsync()
  local b = ScrollkeeperBagFrame.buttons
  print("SYNC buttons:", b.bank ~= nil, b.mailsync ~= nil, b.mail == nil, b.delete ~= nil, "errors:", #ScrollkeeperDB.errors)
end

-- AUTOSYNC: the bank check on the Scroll Bag
if SK.isMage and ScrollkeeperBagFrame then
  local a = ScrollkeeperBagFrame.autoSync
  a:SetChecked(true); a:GetScript("OnClick")(a)
  local on = SK.db.bagAutoSyncBank
  a:SetChecked(false); a:GetScript("OnClick")(a)
  print("AUTOSYNC check:", a ~= nil, on, SK.db.bagAutoSyncBank, "errors:", #ScrollkeeperDB.errors)
end

-- REFINE: sync shows on the button, auto-sync re-runs on keep changes, quiet when nothing to do
if SK.isMage and ScrollkeeperBagFrame then
  SK.db.bagAutoSyncBank = true
  SK.Send("KEEP_CHANGED")
  SK.ScrollBagActions.bank(true); SK.ScrollBagActions.mailsync(true)
  SK.db.bagAutoSyncBank = false
  print("REFINE bank label:", ScrollkeeperBagFrame.buttons.bank:GetText(), "errors:", #ScrollkeeperDB.errors)
end

-- HOLIDAY themes: only in season (two made up here; real ones come from the network)
do
  local m = SK.UI.Month()
  local c = { 0.1, 0.1, 0.1 }
  SK.UI.AddHoliday("testin", "Test In", "", { m }, c, c, c, c, 1)
  SK.UI.AddHoliday("testout", "Test Out", "", { m % 12 + 1 }, c, c, c, c, 2)
  local inKey, outKey
  for _, h in ipairs(SK.UI.HOLIDAYS) do
    if SK.UI.ThemeInSeason(h[1]) then inKey = inKey or h[1] else outKey = outKey or h[1] end
  end
  SK.db.theme = "modern"; SK.UI.ThemeName()
  SK.db.theme = outKey; SK.UI.ApplyTheme()
  local outName = SK.UI.ThemeName()
  SK.db.theme = inKey or "modern"; SK.UI.ApplyTheme()
  local inName = SK.UI.ThemeName()
  SK.db.theme = "modern"; SK.db.themeHoliday = true
  local auto = SK.UI.ThemeName()
  SK.db.themeHoliday = false; SK.UI.ApplyTheme()
  print("HOLIDAY month:", m, "out->", outKey, outName, "in->", inKey, inName, "auto:", auto, "errors:", #ScrollkeeperDB.errors)
end

-- BOARD: post, reply, receive, first version wins, take-down only by author, limits, window
do
  SK.db.share = true; SK.db.boardOn = true
  local now = (GetServerTime and GetServerTime()) or time()
  local p, why = SK.BoardPost("general", "Hello mages", "First post on the board!")
  local r = p and SK.BoardPost(nil, nil, "Replying to myself", p.id)
  -- someone else, with a hello so we know their character ID
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "H|1|1.3.2|MAGE|60|300|300|175||Player-9-0ABC", "GUILD", "Other-Realm")
  local msg = "BP|abc12345||w|" .. now .. "|" .. (SK.ServerKind() or "") .. "|175|Player-9-0ABC|Other Mage|LF Odd Melon|Will trade"
  fire("CHAT_MSG_ADDON", "Scrollkeeper", msg, "GUILD", "Other-Realm")
  fire("CHAT_MSG_ADDON", "Scrollkeeper", msg:gsub("Will trade", "CHANGED"), "GUILD", "Other-Realm")
  local kept = SK.BoardData().posts["abc12345"]
  -- forged delete from someone else, then a real one
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BD|abc12345", "GUILD", "Evil-Realm")
  local afterForged = SK.BoardData().posts["abc12345"] ~= nil
  -- bad stuff: code-ish text, wrong category code, old date
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BP|bad1||x|" .. now .. "|||Player-9-0ABC|X|T|B", "GUILD", "Other-Realm")
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BP|bad2||g|" .. (now - 30 * 86400) .. "|||Player-9-0ABC|X|T|B", "GUILD", "Other-Realm")
  -- notices only from the team
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BP|bad3||n|" .. now .. "|||Player-9-0ABC|Other Mage|Fake notice|B", "GUILD", "Other-Realm")
  -- daily limit: 3 posts
  local ok2 = SK.BoardPost("general", "Two", "b")
  local ok3 = SK.BoardPost("general", "Three", "c")
  local ok4, why4 = SK.BoardPost("general", "Four", "d")
  -- catch up request gets answered
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BQ|0", "GUILD", "Other-Realm")
  local posts, replies = SK.BoardPosts()
  SK.ToggleBoard(); SK.RefreshBoard()
  SK.ToggleDemo(); SK.RefreshBoard(); SK.ToggleDemo()
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BD|abc12345", "GUILD", "Other-Realm")
  local gone = SK.BoardData().posts["abc12345"] == nil
  print("BOARD post:", p ~= nil, why, "reply:", r ~= nil, "kept first:", kept and kept.body, "forged delete ignored:", afterForged,
    "bad dropped:", SK.BoardData().posts.bad1 == nil and SK.BoardData().posts.bad2 == nil and (SK.BoardData().posts.bad3 == nil or not SK.BoardData().posts.bad3.verified),
    "limit:", ok2 ~= nil, ok3 ~= nil, ok4 == nil, why4, "list:", #posts, "replies:", replies[p and p.id or ""] and #replies[p.id],
    "author delete:", gone, "window:", ScrollkeeperBoardFrame ~= nil, "errors:", #ScrollkeeperDB.errors)
end

-- BOARD MOD: only messages signed with the team's key count
do
  local function RunTimers()
    for _ = 1, 20 do
      local list = TIMERS; TIMERS = {}
      if #list == 0 then break end
      for _, t in ipairs(list) do pcall(t) end
    end
  end
  -- A test key (the real secret key isn't in this repo).
  local seed = string.rep("\7", 32)
  local realKey = SK.BOARD_MOD_KEY
  SK.BOARD_MOD_KEY = SK.Ed25519.ToBase64(SK.Ed25519.PublicKey(seed))
  local now = (GetServerTime and GetServerTime()) or time()
  local rs = SK.ServerKind() or ""
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BP|beef0001||g|" .. now .. "|" .. rs .. "|175|Player-9-0ABC|Other Mage|Spam|Buy gold", "GUILD", "Other-Realm")
  -- signed with the wrong key: ignored
  local wrong = SK.Ed25519.ToBase64(SK.Ed25519.Sign("SK1|remove|beef0001|||" .. now, string.rep("\9", 32)))
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BS|" .. wrong .. "|remove|beef0001|||" .. now, "GUILD", "Evil-Realm")
  RunTimers()
  local stillThere = SK.BoardData().posts.beef0001 ~= nil
  -- signed right, relayed by anyone: counts
  local good = SK.Ed25519.ToBase64(SK.Ed25519.Sign("SK1|remove|beef0001|||" .. now, seed))
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BS|" .. good .. "|remove|beef0001|||" .. now, "GUILD", "Someone-Realm")
  RunTimers()
  local removed = SK.BoardData().posts.beef0001 == nil
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BP|beef0001||g|" .. now .. "|" .. rs .. "|175|Player-9-0ABC|Other Mage|Spam|Buy gold", "GUILD", "Someone-Realm")
  local staysOut = SK.BoardData().posts.beef0001 == nil
  -- a signer, as the team has
  SK.BoardSigner = function(text) return SK.Ed25519.Sign(text, seed) end
  local okBan = SK.BoardMod("ban", "Player-9-0ABC", now + 86400, "Other Mage")
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BP|beef0002||g|" .. now .. "|" .. rs .. "|175|Player-9-0ABC|Other Mage|Again|Hi", "GUILD", "Other-Realm")
  local banned = SK.BoardData().posts.beef0002 == nil
  -- an old unban sent again can't undo the newer ban
  local oldUnban = SK.Ed25519.ToBase64(SK.Ed25519.Sign("SK1|unban|Player-9-0ABC|||" .. (now - 100), seed))
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BS|" .. oldUnban .. "|unban|Player-9-0ABC|||" .. (now - 100), "GUILD", "Someone-Realm")
  RunTimers()
  local stillBanned = SK.BoardData().bans["Player-9-0ABC"] ~= nil
  SK.BoardMod("unban", "Player-9-0ABC")
  -- a notice: hidden until the team's signed OK
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BP|beef0003||n|" .. now .. "|" .. rs .. "|175|Player-1-0DEF|Natop|News|Hello", "GUILD", "Someone-Realm")
  local function shown(id) for _, p in ipairs((SK.BoardPosts())) do if p.id == id then return true end end return false end
  local hiddenFirst = SK.BoardData().posts.beef0003 ~= nil and not shown("beef0003")
  SK.BoardMod("ok", "beef0003")
  local okNow = shown("beef0003")
  -- dev mark
  SK.BoardMod("dev", "Player-1-0DEF", nil, "Natop")
  local isDev = SK.BoardIsDev("Player-1-0DEF")
  local list = #SK.BoardModList()
  SK.BoardSigner = nil
  local ok, why = SK.BoardMod("remove", "beef0003")
  SK.BOARD_MOD_KEY = realKey
  print("BOARDMOD wrong key ignored:", stillThere, "removed:", removed, "stays out:", staysOut, "ban:", okBan, banned,
    "old unban ignored:", stillBanned, "notice hidden then ok:", hiddenFirst, okNow, "dev:", isDev,
    "no key refused:", ok == false, why, "list:", list, "errors:", #ScrollkeeperDB.errors)
end

-- BOARD EDIT: only the author's edits count, newer only
do
  SK.db.share = true; SK.db.boardOn = true
  local now = (GetServerTime and GetServerTime()) or time()
  local rs = SK.ServerKind() or ""
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "H|1|1.3.2|MAGE|60|300|300|175||Player-9-0EEE", "GUILD", "Editor-Realm")
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BP|edd00001||g|" .. now .. "|" .. rs .. "|175|Player-9-0EEE|Ed Itor|Old title|Old text|0", "GUILD", "Editor-Realm")
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BE|edd00001|1|Hacked|Bad", "GUILD", "Evil-Realm")
  local p = SK.BoardData().posts.edd00001
  local notHacked = p and p.body == "Old text"
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BE|edd00001|1|New title|New text", "GUILD", "Editor-Realm")
  local edited = p and p.body == "New text" and p.title == "New title" and p.rev == 1
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BE|edd00001|1|Again|Same rev", "GUILD", "Editor-Realm")
  local sameRevIgnored = p and p.body == "New text"
  -- a relayed copy with a higher rev from someone else: ignored
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BP|edd00001||g|" .. now .. "|" .. rs .. "|175|Player-9-0EEE|Ed Itor|Relayed|Fake|5", "GUILD", "Someone-Realm")
  local relayIgnored = p and p.body == "New text"
  -- my own edit
  SK.BoardData().posts = {}
  local mine = SK.BoardPost("general", "Mine", "first")
  local ok, why = SK.BoardEdit(mine and mine.id, "Mine v2", "second")
  local notMine = SK.BoardEdit("edd00001", "x", "y")
  SK.ToggleBoard(); SK.RefreshBoard(); SK.ToggleBoard()
  print("BOARDEDIT not hacked:", notHacked, "edited:", edited, "same rev ignored:", sameRevIgnored, "relay ignored:", relayIgnored,
    "mine:", ok ~= nil, mine and mine.body, mine and mine.rev, "others' refused:", notMine == nil, "errors:", #ScrollkeeperDB.errors)
end

-- BOARD FILTERS: menu, each filter, sorting
do
  SK.db.boardFilter = { show = { unanswered = true }, age = 1, sort = "replies" }
  SK.ToggleBoard(); SK.RefreshBoard()
  SK.db.boardFilter = { show = { dev = true, new = true }, age = 0, sort = "active" }
  SK.RefreshBoard()
  SK.db.boardFilter = nil
  SK.RefreshBoard(); SK.ToggleBoard()
  print("BOARDFILTER errors:", #ScrollkeeperDB.errors)
  for _, e in ipairs(ScrollkeeperDB.errors) do print("  ", e.where, e.error) end
end

-- TEAM NOTES: signed news and switches
do
  local function RunTimers() for _ = 1, 30 do local l = TIMERS; TIMERS = {}; if #l == 0 then break end for _, t in ipairs(l) do pcall(t) end end end
  local E = SK.Ed25519
  local seed = string.rep("\6", 32)
  local real, signer = SK.BOARD_MOD_KEY, SK.BoardSigner
  SK.BOARD_MOD_KEY = E.ToBase64(E.PublicKey(seed))
  SK.BoardSigner = function(t) return E.Sign(t, seed) end
  local okNews = SK.SendTeamNote("news", "n1", "Hello from the team")
  local okOff = SK.SendTeamNote("off", "Board", "1", "posts not syncing")
  local boardOff = not SK.BoardOn()
  local moduleOff = not SK.ModuleOn("Board")
  SK.SendTeamNote("off", "Board", "0", "")
  local boardBack = SK.BoardOn()
  -- a player receives a signed one, and a forged one
  SK.BoardSigner = nil
  local now = (GetServerTime and GetServerTime()) or time()
  local payload = table.concat({ "SK1N", "off", "Sync", "1", "testing", tostring(now) }, "|")
  local sig = E.ToBase64(E.Sign(payload, seed))
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BN|" .. sig .. "|off|Sync|1|testing|" .. now, "CHANNEL", "Someone")
  fire("CHAT_MSG_ADDON", "Scrollkeeper", "BN|" .. sig .. "|off|Bag|1|testing|" .. now, "CHANNEL", "Evil")
  RunTimers()
  local syncOff = SK.RemoteOff("Sync")
  local bagStill = not SK.RemoteOff("Bag")
  SK.ScrollBagActions.bank()
  SK.db.teamNotes = {}
  SK.BOARD_MOD_KEY, SK.BoardSigner = real, signer
  print("TEAMNOTES news:", okNews, "off:", okOff, boardOff, moduleOff, "back:", boardBack, "received:", syncOff, "forged ignored:", bagStill, "errors:", #ScrollkeeperDB.errors)
end

-- TEAM VERSION: an older copy is told once
do
  local E = SK.Ed25519
  local seed = string.rep("\8", 32)
  local real, signer = SK.BOARD_MOD_KEY, SK.BoardSigner
  SK.BOARD_MOD_KEY = E.ToBase64(E.PublicKey(seed))
  SK.BoardSigner = function(t) return E.Sign(t, seed) end
  local ok = SK.SendTeamNote("ver", "latest", "99.0.0", "")
  local bad = SK.SendTeamNote("ver", "latest", "soon", "")
  SK.BOARD_MOD_KEY, SK.BoardSigner = real, signer
  SK.db.teamNotes = {}
  print("TEAMVER announced:", ok, "bad refused:", bad == nil, "errors:", #ScrollkeeperDB.errors)
end

-- FORMAT: emojis and markdown, and both off
do
  local a = SK.FormatText("**big** *soft* `x` ~~no~~ :fire: :nope: :FIRE:")
  local b = SK.FormatText("- item")
  local q = SK.FormatText("> said")
  local many = select(2, SK.FormatText(string.rep(":x:", 20)):gsub("|T", ""))
  SK.db.textEmoji, SK.db.textMarkdown = false, false
  local off = SK.FormatText("**big** :fire:")
  SK.db.textEmoji, SK.db.textMarkdown = true, true
  local btn = SK.EmojiButton(UIParent, CreateFrame("EditBox"))
  print("FORMAT", a, "|", b, "|", q, "| capped:", many, "| off:", off, "| button:", btn ~= nil, "errors:", #ScrollkeeperDB.errors)
end

do
  local t = SK.FormatText("hi :) and <3 but not a:)b or (B)")
  print("FACES", t, "errors:", #ScrollkeeperDB.errors)
end
