local SK = __NS
fire("ADDON_LOADED", "Scrollkeeper")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
print("class mage?", SK.isMage, "errors:", #ScrollkeeperDB.errors)
local sk = SK.GetComprehension(); print("skill", sk.rank, sk.max, sk.known)
print("untranslated:", #SK.bags.untranslated, "feathers", SK.bags.feathers, "bundles", SK.bags.bundles)
for _, s in ipairs(SK.bags.untranslated) do print("  ", s.bag, s.slot, s.name, s.needs) end
local nxt, ready, hard = SK.NextDecipherable(); print("next", nxt and nxt.name, ready, hard)
if SK.isMage then
  local b = ScrollkeeperDecipherButton
  print("button", b._text, b._attrs.type, b._attrs.spell, b._attrs["target-bag"], b._attrs["target-slot"])
  for _, n in ipairs({ "skill", "tier", "scrolls", "study", "warning", "log" }) do end
  -- decipher the first scroll: it becomes a Scroll of Frog Familiar
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1296017)
  BAGS[0][7] = nil; BAGS[1][5].count = 2; MOCK_RANK = 58
  fire("BAG_UPDATE_DELAYED")
  print("after decipher: total", ScrollkeeperDB.deciphered, "button", b._text, b._attrs["target-slot"])
  -- study
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1302508)
  print("study left", SK.StudySecondsLeft(), SK.FormatStudyTime(SK.StudySecondsLeft()))
  advance(3500); print("study left", SK.FormatStudyTime(SK.StudySecondsLeft()))
  BAGS[3][1] = { id = 999, name = "Bundle of Scrolls", count = 1, tip = { "Bundle of Scrolls" } }
  fire("BAG_UPDATE_DELAYED")
  ScrollkeeperPanel._scripts.OnUpdate(ScrollkeeperPanel, 1.5)
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
