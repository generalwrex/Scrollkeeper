-- Minimal WoW mock for loading Scrollkeeper outside the game.

-- WoW's bit library (LuaBitOp: 32-bit, signed results), from Lua 5.3's operators.
do
  -- (fengari's integers are 32-bit: keep everything as signed 32-bit.)
  local function I(x)
    local v = math.floor(x) % 4294967296
    if v >= 2147483648 then v = v - 4294967296 end
    return math.tointeger(v)
  end
  local function S(x) return I(x) end
  bit = {
    band = function(a, ...) local r = I(a) for _, v in ipairs({ ... }) do r = r & I(v) end return S(r) end,
    bor = function(a, ...) local r = I(a) for _, v in ipairs({ ... }) do r = r | I(v) end return S(r) end,
    bxor = function(a, ...) local r = I(a) for _, v in ipairs({ ... }) do r = r ~ I(v) end return S(r) end,
    bnot = function(a) return S(~I(a)) end,
    lshift = function(a, n) return S(I(a) << n) end,
    rshift = function(a, n) return S(I(a) >> n) end,
    arshift = function(a, n) return I(math.floor(I(a) / 2 ^ n)) end,
  }
end
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
    if k == "SetChecked" then return function(self, v) self._checked = v and true or false end end
    if k == "GetChecked" then return function(self) return self._checked end end
    if k == "GetText" then return function(self) return self._text end end
    if k == "CreateFontString" or k == "CreateTexture" then return function() return newObj() end end
    if k == "IsShown" then return function(self) return self._shown end end
    if k == "SetShown" then return function(self, v) self._shown = v and true or false end end
    if k == "Show" then return function(self) self._shown = true end end
    if k == "Hide" then return function(self) self._shown = false end end
    if k == "GetStringHeight" then return function() return 12 end end
    if k == "SetScrollChild" then return function(self, c) self._child = c end end
    if k == "GetFrameLevel" then return function() return 1 end end
    if k == "GetVerticalScroll" or k == "GetVerticalScrollRange" then return function() return 0 end end
    if k == "GetScale" then return function() return 1 end end
    if k == "GetFont" then return function() return "font", 10 end end
    if k == "HookScript" then return function(self, n, f)
      local hooks = rawget(self, "_hooks") or {}; rawset(self, "_hooks", hooks)
      hooks[n] = hooks[n] or {}; table.insert(hooks[n], f)
    end end
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
BAGS[2][6] = { id = 213564, name = "Scroll of Minor Evocation", count = 3, tip = { "Scroll of Minor Evocation", "Classes: Mage" } }
BAGS[2][7] = { id = 277400, name = "Scroll of Cat Familiar", count = 1, tip = { "Scroll of Cat Familiar", "Classes: Mage", "Requires Level 25" } }
BAGS[2][8] = { id = 277401, name = "Scroll of Rat Familiar", count = 2, tip = { "Scroll of Rat Familiar", "Classes: Mage", "Requires Level 6" } }
BAGS[2][9] = { id = 277402, name = "Scroll of Imbue Lesser Flame", count = 1, tip = { "Scroll of Imbue Lesser Flame", "Use: Imbue a staff with magic for 1 hour.", "Classes: Mage", "Requires Level 6" } }
BAGS[2][10] = { id = 277403, name = "Scroll of Imbue Frost", count = 1, tip = { "Scroll of Imbue Frost", "Use: Imbue a sword with magic for 1 hour.", "Classes: Mage", "Requires Level 16" } }
BAGS[2][11] = { id = 277404, name = "Scroll of the Saber", count = 1, tip = { "Scroll of the Saber", "Classes: Mage" } }
BAGS[2][12] = { id = 277405, name = "Scroll of Comprehension", count = 1, tip = { "Scroll of Comprehension", "Classes: Mage", "Requires Level 6" } }
BAGS[2][4] = { id = 17056, name = "Light Feather", count = 3, tip = { "Light Feather" } }
BAGS[2][5] = { id = 6948, name = "Hearthstone", count = 1, tip = { "Hearthstone" } }
C_Container = {
  GetContainerNumSlots = function() return 16 end,
  GetContainerItemInfo = function(b, s) local i = BAGS[b] and BAGS[b][s]; if i then return { itemID = i.id, itemName = i.name, stackCount = i.count } end end,
}
C_Item = {
  GetItemNameByID = function(id) return "item" .. id end,
  GetItemInfoInstant = function(id) if id == 211786 or (id >= 213564 and id <= 277600) then return id, "Consumable", "Scrolls", "", 1, 0, 4 end return id, "Misc", "Junk", "", 1, 15, 0 end,
}
C_TooltipInfo = { GetBagItem = function(b, s) local i = BAGS[b] and BAGS[b][s]; if not i then return nil end local l = {}; for _, t in ipairs(i.tip) do l[#l+1] = { leftText = t } end return { lines = l } end }
TOOLTIP_CALLS = {}
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) TOOLTIP_CALLS[#TOOLTIP_CALLS+1] = fn end }
function GetBuildInfo() return "1.60.1", "70938", "Nov 12 2026", 16001 end

C_Item.GetItemIconByID = function(id) return 134939 end
Settings = {
  RegisterVerticalLayoutCategory = function(n) MOCK_HEADERS = 0; return { GetID = function() return 1 end }, { AddInitializer = function() MOCK_HEADERS = MOCK_HEADERS + 1 end } end,
  RegisterCanvasLayoutSubcategory = function(parent, frame, name) _G.SK_ABOUT_PAGE = name; return {} end,
  RegisterAddOnSetting = function() return { SetValueChangedCallback = function(self, f) SETTING_CB = f end } end,
  CreateCheckbox = function() end, CreateDropdown = function() end,
  CreateControlTextContainer = function() return { Add = function() end, GetData = function() return {} end } end, CreateSliderOptions = function() return {} end, CreateSlider = function() end,
  RegisterAddOnCategory = function() end, OpenToCategory = function(id) print("open settings", id) end,
}
math.ceil = math.ceil

TIMERS = {}
C_Timer = { After = function(sec, fn) TIMERS[#TIMERS+1] = fn end }
function runTimers() local t = TIMERS; TIMERS = {}; for _, f in ipairs(t) do f() end end

MOCK_SUB = "Tarren Mill"; MOCK_ZONE = "Hillsbrad Foothills"
function GetSubZoneText() return MOCK_SUB end
function GetRealZoneText() return MOCK_ZONE end

SENT = {}
C_ChatInfo = {
  RegisterAddonMessagePrefix = function() return true end,
  SendAddonMessage = function(prefix, text, chan, target) SENT[#SENT+1] = { prefix, text, chan } end,
}
function IsInGuild() return true end
function IsInGroup() return false end
function IsInRaid() return false end
function UnitFullName() return "Naage", "Realm" end
function UnitName() return "Naage" end
function UnitLevel() return 20 end
function Ambiguate(n) return (n:gsub("%-.*$", "")) end
function UnitInParty() return false end
C_Timer.NewTicker = function(sec, fn) TICKERS = TICKERS or {}; TICKERS[#TICKERS+1] = fn end
function tickAll() for _, f in ipairs(TICKERS or {}) do f() end end
function GetChannelName() return 0 end
LOOT_ITEM_SELF = "You receive loot: %s."
C_Map = { GetBestMapForUnit = function() return 1458 end,
  GetPlayerMapPosition = function() return { GetXY = function() return 0.73, 0.33 end } end }
C_TooltipInfo.GetHyperlink = function(link) if link:find("211786") then return { lines = { { leftText = "Requires Comprehension (1)" } } } end return { lines = {} } end
UISpecialFrames = {}
tinsert = table.insert

function UnitGUID() return "Player-1-ABC" end

function GetWeaponEnchantInfo() return MOCK_IMBUED or false end
C_UnitAuras = { GetAuraDataByIndex = function(u, i) return nil end }
function GetInventoryItemLink(u, slot) if slot == 16 then return "|cff|Hitem:1|h[Blade of Silverlaine]|h|r" end end
ITEM_MIN_LEVEL = "Requires Level %d"

function GetInventoryItemID(u, slot) if slot == 16 then return 99999 end end
local origInstant = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(id) if id == 99999 then return id, "Weapon", "Staves", "", 1, 2, 10 end return origInstant(id) end

function GetRealmName() return "Forever" end
function GetLocale() return MOCK_LOCALE or "enUS" end
date = date or os.date

function RegisterStateDriver() end

function CreateSettingsListSectionHeaderInitializer(t) return { text = t } end
function CreateSettingsButtonInitializer(...) return {} end
Minimap = CreateFrame("Frame", "Minimap")
function GetCursorPosition() return 100, 100 end

