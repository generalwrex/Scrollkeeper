local SK = __NS
fire("ADDON_LOADED", "Scrollkeeper")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
print("class mage?", SK.isMage, "errors:", #ScrollkeeperDB.errors)
local sk = SK.GetComprehension(); print("skill", sk.rank, sk.max, sk.known)
print("untranslated:", #SK.bags.untranslated, "feathers", SK.bags.feathers, "bundles", SK.bags.bundles)
for _, s in ipairs(SK.bags.untranslated) do print("  ", s.bag, s.slot, s.name, s.needs) end
local nxt, ready, hard, ups = SK.NextDecipherable(); print("next", nxt and nxt.name, ready, hard, "skillups", ups)
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
  SK.db.collapsed = false; SK.RefreshPanel(); SETTING_CB(); SlashCmdList.SCROLLKEEPER("options")
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
SlashCmdList.SCROLLKEEPER("demo")
print("peers after demo off", #SK.PeerList())
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
  SK.db.errors = { { at = 0, where = "test", error = "boom" } }
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
