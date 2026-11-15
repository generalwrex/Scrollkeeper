-- Minimal WoW mock for loading Scrollkeeper outside the game.
local frames = {}
local function newObj()
  local o = { _scripts = {}, _events = {}, _attrs = {}, _shown = true, _text = nil }
  return setmetatable(o, { __index = function(t, k)
    if k == "SetScript" then return function(self, n, f) self._scripts[n] = f end end
    if k == "RegisterEvent" then return function(self, e) self._events[e] = true end end
    if k == "UnregisterEvent" then return function(self, e) self._events[e] = nil end end
    if k == "SetAttribute" then return function(self, a, v) self._attrs[a] = v end end
    if k == "GetAttribute" then return function(self, a) return self._attrs[a] end end
    if k == "SetText" then return function(self, v) self._text = v end end
    if k == "GetText" then return function(self) return self._text end end
    if k == "CreateFontString" or k == "CreateTexture" then return function() return newObj() end end
    if k == "IsShown" then return function(self) return self._shown end end
    if k == "SetShown" then return function(self, v) self._shown = v and true or false end end
    if k == "Show" then return function(self) self._shown = true end end
    if k == "Hide" then return function(self) self._shown = false end end
    if k == "GetStringHeight" then return function() return 12 end end
    if k == "GetScale" then return function() return 1 end end
    if k == "GetFont" then return function() return "font", 10 end end
    if k == "GetScript" then return function(self, n) return self._scripts[n] end end
    if k == "IsOwned" then return function() return false end end
    if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, 0 end end
    return function() end
  end })
end
function CreateFrame(kind, name, parent, template)
  if template == "CharacterStatFrameCategoryTemplate" then error("no template") end
  local f = newObj(); frames[#frames+1] = f; if name then _G[name] = f end; return f end
UIParent = newObj(); GameTooltip = newObj()
function fire(ev, ...) for _, f in ipairs(frames) do if f._events[ev] and f._scripts.OnEvent then f._scripts.OnEvent(f, ev, ...) end end end
local now = 1000
function time() return now end
function GetTime() return now end
function advance(s) now = now + s end
function UnitClass() return "Mage", MOCK_CLASS or "MAGE" end
function InCombatLockdown() return false end
function IsResting() return false end
function IsShiftKeyDown() return true end
function IsPlayerSpell() return true end
SlashCmdList = {}
ITEM_MIN_SKILL = "Requires %s (%d)"
Enum = { TooltipDataType = { Item = 0 } }
MOCK_RANK = 57
C_SkillInfo = { GetSkillLineInfoByID = function(id)
  if MOCK_CLASS == "WARRIOR" then return { name = "Comprehension", rank = 0, maxRank = 0, tempPoints = 0, modifier = 0 } end
  return { name = "Comprehension", rank = MOCK_RANK, maxRank = 100, tempPoints = 0, modifier = 0 } end }
C_SpellBook = { IsSpellKnown = function() return true end }
-- bags: [bag][slot] = { id, name, count, tip }
BAGS = { [0] = {}, {}, {}, {}, {}, {} }
local function U(name, needs) return { id = 211786, name = "Scroll: " .. name, count = 1, tip = { "Scroll: " .. name, "Classes: Mage", "Requires Comprehension (" .. needs .. ")" } } end
BAGS[0][7] = U("CHAP BALK WELLES", 1); BAGS[0][8] = U("CHAP BALK WELLES", 1); BAGS[0][9] = U("WUBBA WUBBA", 15); BAGS[1][1] = U("DOST OREM", 175)
BAGS[1][5] = { id = 277483, name = "Scroll of Frog Familiar", count = 1, tip = { "Scroll of Frog Familiar", "Classes: Mage", "Requires Level 16" } }
BAGS[2][4] = { id = 17056, name = "Light Feather", count = 3, tip = { "Light Feather" } }
BAGS[2][5] = { id = 6948, name = "Hearthstone", count = 1, tip = { "Hearthstone" } }
C_Container = {
  GetContainerNumSlots = function() return 16 end,
  GetContainerItemInfo = function(b, s) local i = BAGS[b] and BAGS[b][s]; if i then return { itemID = i.id, itemName = i.name, stackCount = i.count } end end,
}
C_Item = {
  GetItemNameByID = function(id) return "item" .. id end,
  GetItemInfoInstant = function(id) if id == 211786 or id == 277483 or id == 277400 then return id, "Consumable", "Scrolls", "", 1, 0, 4 end return id, "Misc", "Junk", "", 1, 15, 0 end,
}
C_TooltipInfo = { GetBagItem = function(b, s) local i = BAGS[b] and BAGS[b][s]; if not i then return nil end local l = {}; for _, t in ipairs(i.tip) do l[#l+1] = { leftText = t } end return { lines = l } end }
TOOLTIP_CALLS = {}
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) TOOLTIP_CALLS[#TOOLTIP_CALLS+1] = fn end }
function GetBuildInfo() return "1.60.1", "70938", "Nov 12 2026", 16001 end

C_Item.GetItemIconByID = function(id) return 134939 end
Settings = {
  RegisterVerticalLayoutCategory = function(n) return { GetID = function() return 1 end } end,
  RegisterAddOnSetting = function() return { SetValueChangedCallback = function(self, f) SETTING_CB = f end } end,
  CreateCheckbox = function() end, CreateSliderOptions = function() return {} end, CreateSlider = function() end,
  RegisterAddOnCategory = function() end, OpenToCategory = function(id) print("open settings", id) end,
}
math.ceil = math.ceil

TIMERS = {}
C_Timer = { After = function(sec, fn) TIMERS[#TIMERS+1] = fn end }
function runTimers() local t = TIMERS; TIMERS = {}; for _, f in ipairs(t) do f() end end

MOCK_SUB = "Tarren Mill"; MOCK_ZONE = "Hillsbrad Foothills"
function GetSubZoneText() return MOCK_SUB end
function GetRealZoneText() return MOCK_ZONE end
