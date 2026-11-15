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
