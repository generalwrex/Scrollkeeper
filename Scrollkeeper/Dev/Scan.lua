-- Scrollkeeper: Dev/Scan.lua
-- Developer tool. Dumps what the game reports (skills, spells, bag
-- scrolls, zone, buffs) into the saved file so the addon can be built on
-- real data instead of guesses.
--
--   /sk scan       record a snapshot (only scroll-related bag items)
--   /sk scan all   same, but every bag item
--   /sk eventlog   start or stop recording game events
--   /sk show       open a window with the latest snapshot to copy
--   /sk clear      wipe the recorded data
--
-- Everything goes to ScrollkeeperScan in SavedVariables on /reload.

local ADDON, SK = ...
ScrollkeeperScan = ScrollkeeperScan or {}

local function say(msg)
    print("|cff69ccf0Scrollkeeper:|r " .. tostring(msg))
end

-- Call a function that may not exist on this client; never throw.
local function try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
    return nil
end

-- Make a value safe to store (no functions, userdata or cycles).
local function clean(v, depth)
    depth = depth or 0
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" then return v end
    if t ~= "table" or depth > 4 then return nil end
    local out = {}
    for k, val in pairs(v) do
        local kt = type(k)
        if kt == "string" or kt == "number" then
            out[k] = clean(val, depth + 1)
        end
    end
    return out
end

local WATCH_SPELLS = {
    "Comprehend Scroll", "Study", "Research", "Imbue Blade", "Scroll Comprehension",
}
local WATCH_SPELL_IDS = { 1296017 }
local WATCH_WORDS = {
    "scroll", "feather", "bundle", "comprehen", "imbue", "familiar", "cryoblast",
    "silverlaine", "hypnotic", "witchblade",
}

local function interesting(name, lines)
    local hay = (name or ""):lower()
    for _, l in ipairs(lines or {}) do hay = hay .. "\n" .. l:lower() end
    for _, w in ipairs(WATCH_WORDS) do
        if hay:find(w, 1, true) then return true end
    end
    return false
end

local function tooltipLines(bag, slot)
    local lines = {}
    local data = C_TooltipInfo and try(C_TooltipInfo.GetBagItem, bag, slot)
    if type(data) == "table" and type(data.lines) == "table" then
        for _, line in ipairs(data.lines) do
            local l, r = line.leftText, line.rightText
            if type(l) == "string" and l ~= "" then
                if type(r) == "string" and r ~= "" then l = l .. " || " .. r end
                lines[#lines + 1] = l
            end
        end
    end
    return lines
end

local function scanBags(all)
    local items, apis = {}, {}
    apis.C_Container = C_Container ~= nil
    apis.C_TooltipInfo = C_TooltipInfo ~= nil
    if not C_Container then return items, apis end
    for bag = 0, 5 do
        local n = try(C_Container.GetContainerNumSlots, bag) or 0
        for slot = 1, n do
            local info = try(C_Container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and info.itemID then
                local name = info.itemName
                if not name and C_Item then name = try(C_Item.GetItemNameByID, info.itemID) end
                local lines = tooltipLines(bag, slot)
                if all or interesting(name, lines) then
                    local _, itemType, subType, equipLoc, _, classID, subClassID
                    if C_Item then
                        _, itemType, subType, equipLoc, _, classID, subClassID =
                            try(C_Item.GetItemInfoInstant, info.itemID)
                    end
                    local spellName, spellID
                    if C_Item then spellName, spellID = try(C_Item.GetItemSpell, info.itemID) end
                    items[#items + 1] = {
                        bag = bag, slot = slot,
                        id = info.itemID, name = name,
                        link = info.hyperlink and info.hyperlink:gsub("|", "||") or nil,
                        count = info.stackCount, quality = info.quality,
                        bound = info.isBound, locked = info.isLocked,
                        type = itemType, subType = subType, equipLoc = equipLoc,
                        classID = classID, subClassID = subClassID,
                        useSpell = spellName, useSpellID = spellID,
                        maxStack = C_Item and try(C_Item.GetItemMaxStackSizeByID, info.itemID) or nil,
                        tip = lines,
                    }
                end
            end
        end
    end
    return items, apis
end

local function scanSkills()
    local out = { classic = {}, professions = {}, apis = {} }
    out.apis.GetNumSkillLines = type(GetNumSkillLines) == "function"
    out.apis.GetSkillLineInfo = type(GetSkillLineInfo) == "function"
    out.apis.GetProfessions = type(GetProfessions) == "function"
    out.apis.C_TradeSkillUI = C_TradeSkillUI ~= nil
    out.apis.C_SkillInfo = C_SkillInfo ~= nil
    local n = try(GetNumSkillLines) or 0
    for i = 1, n do
        local name, header, _, rank, temp, modifier, maxRank = try(GetSkillLineInfo, i)
        if name then
            out.classic[#out.classic + 1] = {
                name = name, header = header and true or false,
                rank = rank, temp = temp, mod = modifier, max = maxRank,
            }
        end
    end
    if type(GetProfessions) == "function" then
        local idx = { try(GetProfessions) }
        for k = 1, 6 do
            local i = idx[k]
            if i then
                local name, _, rank, maxRank, _, _, skillLine, mod = try(GetProfessionInfo, i)
                out.professions[#out.professions + 1] = {
                    slot = k, name = name, rank = rank, max = maxRank, line = skillLine, mod = mod,
                }
            end
        end
    end
    if C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines then
        out.lines = {}
        local lines = try(C_TradeSkillUI.GetAllProfessionTradeSkillLines) or {}
        for _, id in ipairs(lines) do
            local info = try(C_TradeSkillUI.GetProfessionInfoBySkillLineID, id)
            if type(info) == "table" and info.professionName and (info.skillLevel or 0) > 0 then
                out.lines[#out.lines + 1] = {
                    id = id, name = info.professionName,
                    rank = info.skillLevel, max = info.maxSkillLevel, mod = info.skillModifier,
                }
            end
        end
    end
    -- Discovery: find Comprehension's skill line, which is not a profession slot.
    out.found = {}
    if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        for id = 1, 4000 do
            local info = try(C_TradeSkillUI.GetProfessionInfoBySkillLineID, id)
            if type(info) == "table" and type(info.professionName) == "string" and info.professionName ~= "" then
                local lvl = info.skillLevel or 0
                local nm = info.professionName:lower()
                if lvl > 0 or nm:find("compre", 1, true) or nm:find("research", 1, true) then
                    out.found[#out.found + 1] = {
                        id = id, name = info.professionName, rank = lvl,
                        max = info.maxSkillLevel, mod = info.skillModifier,
                        parent = info.parentProfessionID, prof = info.profession,
                    }
                end
            end
        end
    end
    out.skillInfo = {}
    if C_SkillInfo then
        local function pack(...) return { n = select("#", ...), ... } end
        local r = pack(pcall(C_SkillInfo.GetSkillLineInfoByID, 3012))
        out.skillInfo.byID = clean(r)
        local n = try(C_SkillInfo.GetNumSkillLines) or 0
        out.skillInfo.num = n
        out.skillInfo.list = {}
        for i = 1, math.min(n, 80) do
            out.skillInfo.list[i] = clean(pack(pcall(C_SkillInfo.GetSkillLineInfo, i)))
        end
    end
    out.fns = {}
    for _, ns in ipairs({ "C_SkillInfo", "C_TradeSkillUI", "C_SpellBook" }) do
        local t, names = _G[ns], {}
        if type(t) == "table" then
            for k, v in pairs(t) do
                if type(v) == "function" then names[#names + 1] = k end
            end
            table.sort(names)
        end
        out.fns[ns] = table.concat(names, " ")
    end
    out.globals = {}
    for _, g in ipairs({ "GetNumSkillLines", "GetSkillLineInfo", "GetProfessionInfo", "GetSpellRank",
        "ToggleProfessionsBook", "ToggleCharacter", "C_ClassicSkills", "SkillFrame", "ProfessionsBookFrame",
        "CharacterFrame", "C_PaperDollInfo", "C_Skills" }) do
        out.globals[g] = type(_G[g])
    end
    return out
end

local function spellEntry(key)
    local e = { key = key }
    local info = C_Spell and try(C_Spell.GetSpellInfo, key)
    if type(info) == "table" then
        e.id, e.name, e.castTime = info.spellID, info.name, info.castTime
        e.minRange, e.maxRange = info.minRange, info.maxRange
    end
    if e.id then
        e.known = (IsPlayerSpell and try(IsPlayerSpell, e.id)) or
            (IsSpellKnown and try(IsSpellKnown, e.id)) or false
        local cd = C_Spell and try(C_Spell.GetSpellCooldown, e.id)
        if type(cd) == "table" then
            e.cdStart, e.cdDuration = clean(cd.startTime), clean(cd.duration)
        end
        e.desc = C_Spell and try(C_Spell.GetSpellDescription, e.id) or nil
        e.usable = C_Spell and try(C_Spell.IsSpellUsable, e.id) or nil
    end
    return e
end

local function scanSpells()
    local out = { watched = {}, general = {} }
    for _, n in ipairs(WATCH_SPELLS) do out.watched[#out.watched + 1] = spellEntry(n) end
    for _, id in ipairs(WATCH_SPELL_IDS) do out.watched[#out.watched + 1] = spellEntry(id) end
    -- Every spell in the General tab (where Comprehend Scroll is said to live).
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        local tabs = try(C_SpellBook.GetNumSpellBookSkillLines) or 0
        for t = 1, tabs do
            local line = try(C_SpellBook.GetSpellBookSkillLineInfo, t)
            if type(line) == "table" and t == 1 then
                local first = (line.itemIndexOffset or 0) + 1
                local last = (line.itemIndexOffset or 0) + (line.numSpellBookItems or 0)
                for i = first, last do
                    local item = try(C_SpellBook.GetSpellBookItemInfo, i, bank)
                    if type(item) == "table" then
                        out.general[#out.general + 1] = {
                            name = item.name, id = item.spellID or item.actionID,
                            passive = item.isPassive,
                        }
                    end
                end
            end
        end
    end
    return out
end

local function scanPlace()
    local p = {
        zone = try(GetZoneText), sub = try(GetSubZoneText),
        mini = try(GetMinimapZoneText), real = try(GetRealZoneText),
        resting = try(IsResting) and true or false,
        indoors = try(IsIndoors) and true or false,
        pvp = try(GetZonePVPInfo),
    }
    if C_Map then
        p.mapID = try(C_Map.GetBestMapForUnit, "player")
        if p.mapID then
            local pos = try(C_Map.GetPlayerMapPosition, p.mapID, "player")
            if pos and pos.GetXY then
                local x, y = pos:GetXY()
                p.x, p.y = x and math.floor(x * 10000) / 100, y and math.floor(y * 10000) / 100
            end
            local info = try(C_Map.GetMapInfo, p.mapID)
            if type(info) == "table" then p.mapName = info.name end
        end
    end
    return p
end

local function scanBuffs()
    local out = {}
    if InCombatLockdown and InCombatLockdown() then return out end
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return out end
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        for i = 1, 40 do
            local a = try(C_UnitAuras.GetAuraDataByIndex, "player", i, filter)
            if type(a) ~= "table" then break end
            out[#out + 1] = {
                kind = filter, name = clean(a.name), id = clean(a.spellId),
                duration = clean(a.duration), stacks = clean(a.applications),
            }
        end
    end
    return out
end

local function doScan(all)
    local version, build, date, toc = try(GetBuildInfo)
    local _, class = try(UnitClass, "player")
    local items, apis = scanBags(all)
    local scan = {
        time = date and date or nil, at = time(),
        client = { version = version, build = build, toc = toc, locale = try(GetLocale) },
        player = {
            class = class, level = try(UnitLevel, "player"),
            faction = try(UnitFactionGroup, "player"),
        },
        apis = apis,
        skills = scanSkills(),
        spells = scanSpells(),
        place = scanPlace(),
        buffs = scanBuffs(),
        items = items,
        allItems = all and true or false,
    }
    ScrollkeeperScan.scans = ScrollkeeperScan.scans or {}
    table.insert(ScrollkeeperScan.scans, scan)
    while #ScrollkeeperScan.scans > 10 do table.remove(ScrollkeeperScan.scans, 1) end
    say(("scan %d saved: %d items, %d skill lines. Type /reload to write it to disk."):format(
        #ScrollkeeperScan.scans, #items, #scan.skills.classic + #(scan.skills.lines or {})))
    return scan
end

-- ---------------------------------------------------------------- event log
local LOG_EVENTS = {
    "CHAT_MSG_LOOT", "CHAT_MSG_SKILL", "CHAT_MSG_SYSTEM", "UI_ERROR_MESSAGE",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED",
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
    "PLAYER_UPDATE_RESTING", "SPELL_UPDATE_COOLDOWN",
}
local frame = CreateFrame("Frame")
local lastBag, lastCooldownLog = nil, 0

local function bagCounts()
    local counts = {}
    if not C_Container then return counts end
    for bag = 0, 5 do
        local n = try(C_Container.GetContainerNumSlots, bag) or 0
        for slot = 1, n do
            local info = try(C_Container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and info.itemID then
                counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    return counts
end

local function addLog(entry)
    ScrollkeeperScan.log = ScrollkeeperScan.log or {}
    local log = ScrollkeeperScan.log
    entry.t = time()
    log[#log + 1] = entry
    while #log > 600 do table.remove(log, 1) end
end

local function setLogging(on)
    ScrollkeeperScan.logging = on and true or false
    for _, ev in ipairs(LOG_EVENTS) do
        if on then pcall(frame.RegisterEvent, frame, ev) else pcall(frame.UnregisterEvent, frame, ev) end
    end
    if on then lastBag = bagCounts() end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        setLogging(ScrollkeeperScan.logging)
        return
    end
    if not ScrollkeeperScan.logging then return end
    if event:find("^UNIT_SPELLCAST") then
        local unit, _, spellID = ...
        if unit ~= "player" then return end
        local name = C_Spell and try(C_Spell.GetSpellName, spellID) or nil
        addLog({ e = event, id = clean(spellID), name = clean(name) })
    elseif event == "BAG_UPDATE_DELAYED" then
        local now, diff = bagCounts(), {}
        for id, c in pairs(now) do
            local d = c - ((lastBag and lastBag[id]) or 0)
            if d ~= 0 then diff[#diff + 1] = { id = id, d = d, name = C_Item and try(C_Item.GetItemNameByID, id) } end
        end
        for id, c in pairs(lastBag or {}) do
            if not now[id] then diff[#diff + 1] = { id = id, d = -c, name = C_Item and try(C_Item.GetItemNameByID, id) } end
        end
        lastBag = now
        if #diff > 0 then addLog({ e = event, diff = diff }) end
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        if GetTime() - lastCooldownLog < 2 then return end
        lastCooldownLog = GetTime()
        local cds = {}
        for _, n in ipairs(WATCH_SPELLS) do
            local e = spellEntry(n)
            if e.id and e.cdDuration and e.cdDuration > 2 then
                cds[#cds + 1] = { name = e.name, id = e.id, duration = e.cdDuration }
            end
        end
        if #cds > 0 then addLog({ e = event, cds = cds }) end
    elseif event:find("^ZONE_CHANGED") or event == "PLAYER_UPDATE_RESTING" then
        addLog({ e = event, place = scanPlace() })
    elseif event == "SKILL_LINES_CHANGED" then
        addLog({ e = event })
    else
        local a, b = ...
        local msg = type(a) == "string" and a or (type(b) == "string" and b or nil)
        if event == "CHAT_MSG_SYSTEM" and msg and not interesting(msg) and not msg:lower():find("skill") then
            return
        end
        addLog({ e = event, msg = clean(msg and msg:gsub("|", "||")), a = clean(type(a) == "number" and a or nil) })
    end
end)
frame:RegisterEvent("PLAYER_LOGIN")

-- ---------------------------------------------------------------- copy window
local function dump(v, indent, out)
    indent = indent or ""
    if type(v) ~= "table" then out[#out + 1] = tostring(v) return end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        local val = v[k]
        if type(val) == "table" then
            out[#out + 1] = indent .. tostring(k) .. ":"
            dump(val, indent .. "  ", out)
        else
            out[#out + 1] = indent .. tostring(k) .. " = " .. tostring(val)
        end
    end
end

local window
local function show()
    local scans = ScrollkeeperScan.scans
    if not scans or #scans == 0 then say("nothing scanned yet. Type /sk scan first.") return end
    if not window then
        window = CreateFrame("Frame", "ScrollkeeperScanWindow", UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(620, 460)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:SetMovable(true)
        window:EnableMouse(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        if window.TitleText then window.TitleText:SetText("Scrollkeeper scan (Ctrl+A, Ctrl+C)") end
        local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -32)
        scroll:SetPoint("BOTTOMRIGHT", -30, 12)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(560)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() window:Hide() end)
        scroll:SetScrollChild(edit)
        window.edit = edit
    end
    local out = {}
    dump(scans[#scans], "", out)
    window.edit:SetText(table.concat(out, "\n"))
    window:Show()
    window.edit:SetFocus()
    window.edit:HighlightText()
end

-- ---------------------------------------------------------------- commands
-- Added to the command table from Commands.lua.
SK.commands.scan = function(arg) doScan(arg == "all") end
SK.commands.show = show
SK.commands.eventlog = function()
    setLogging(not ScrollkeeperScan.logging)
    say("event recording " .. (ScrollkeeperScan.logging and "on" or "off"))
end
SK.commands.clear = function()
    ScrollkeeperScan = {}
    setLogging(false)
    say("recorded data cleared")
end
