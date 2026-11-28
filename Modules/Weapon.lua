-- Scrollkeeper by generalwrex. Created 2026-11-15.
-- Read the LICENSE file before using any of this code.
-- Scrollkeeper: Modules/Weapon.lua
-- Things worth a reminder:
--   * no weapon imbue, while you carry imbue scrolls
--   * no familiar out, while you carry familiar scrolls
--   * a Scroll of Comprehension would let you read more scrolls right now
--   * weapon upgrades: which scroll and weapon you have, and what's missing
--
-- Aura and enchant checks only run out of combat; in combat the last
-- answer is kept.

local _, SK = ...
local L = SK.L

local state = { imbued = true, familiar = true }
-- When they run out, as GetTime() seconds (nil = unknown or never).
local endsAt = {}

------------------------------------------------------------------------
-- Weapon imbue and familiar
------------------------------------------------------------------------

local function HasMainHandImbue()
    if not GetWeaponEnchantInfo then return true end
    local ok, hasMainHand, expiresMs = pcall(GetWeaponEnchantInfo)
    if not ok then return state.imbued end
    hasMainHand, expiresMs = SK.Known(hasMainHand), SK.Known(expiresMs)
    endsAt.imbue = hasMainHand and type(expiresMs) == "number" and expiresMs > 0 and GetTime() + expiresMs / 1000 or nil
    return hasMainHand and true or false
end

-- The buffs a familiar gives, in any language: each familiar scroll's own
-- spell (its ID and its name in your language), plus every one seen before
-- (saved, so it works even after the scroll is used up).
local function FamiliarSpells()
    SK.db.familiarSpells = SK.db.familiarSpells or {}
    local ids, names = SK.db.familiarSpells, {}
    for _, scroll in ipairs(SK.bags and SK.bags.translated or {}) do
        if scroll.category == "familiars" and C_Item and C_Item.GetItemSpell then
            local spellName, spellID = SK.Try(C_Item.GetItemSpell, scroll.itemID)
            if spellID then ids[spellID] = spellName or true end
        end
    end
    for _, spellName in pairs(ids) do
        if type(spellName) == "string" then names[spellName] = true end
    end
    return ids, names
end

local function HasFamiliar()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return true end
    local ids, names = FamiliarSpells()
    local words = { "Familiar", SK.L["Familiar"] }
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok then return state.familiar end
        if type(aura) ~= "table" then break end
        local spellID, name = aura.spellId, aura.name
        if issecretvalue and (issecretvalue(spellID) or issecretvalue(name)) then return state.familiar end
        local found = (spellID and ids[spellID]) and true or false
        if not found and type(name) == "string" then
            if names[name] then found = true end
            for _, word in ipairs(words) do
                if word ~= "" and name:lower():find(word:lower(), 1, true) then found = true end
            end
        end
        if found then
            local expires = SK.Known(aura.expirationTime)
            endsAt.familiar = type(expires) == "number" and expires > 0 and expires or nil
            return true
        end
    end
    endsAt.familiar = nil
    return false
end

local function Check()
    if SK.InCombat() then return end
    local imbued, familiar = HasMainHandImbue(), HasFamiliar()
    if imbued ~= state.imbued or familiar ~= state.familiar then
        state.imbued, state.familiar = imbued, familiar
        SK.Send("REMINDERS_CHANGED")
    end
end

-- Seconds left on the imbue and the familiar: { imbue = n or nil, familiar = n or nil }.
function SK.BuffTimeLeft()
    local now, left = GetTime(), {}
    for kind, at in pairs(endsAt) do
        if at and at > now then left[kind] = at - now end
    end
    return left
end

-- Is a familiar out, and is the main hand imbued? (Last known answer.)
function SK.WeaponState()
    return { imbued = state.imbued, familiar = state.familiar }
end

-- Auras change often; check at most twice a second.
local pending
local function CheckSoon()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function() pending = false; SK.Safely("reminder check", Check) end)
end

SK.On("UNIT_AURA", function(unit) if unit == "player" then CheckSoon() end end)
SK.On("UNIT_INVENTORY_CHANGED", function(unit) if unit == "player" then CheckSoon() end end)
SK.On("PLAYER_EQUIPMENT_CHANGED", function()
    CheckSoon()
    SK.Send("REMINDERS_CHANGED")   -- a new weapon changes which imbues fit
end)
SK.On("PLAYER_REGEN_ENABLED", CheckSoon)
SK.On("PLAYER_ENTERING_WORLD", CheckSoon)

------------------------------------------------------------------------
-- Weapon upgrades
------------------------------------------------------------------------

local function EquippedNames()
    local names = {}
    for _, slot in ipairs({ 16, 17 }) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        local name = link and link:match("%[(.-)%]")
        if name then names[name] = true end
    end
    return names
end

-- One entry per upgrade you have any part of:
-- { upgrade, hasScroll, hasWeapon, ready }
function SK.UpgradeStatus()
    local bagNames = {}
    -- By English name too, so it works in every language.
    for id, name in pairs(SK.bags.names or {}) do
        bagNames[name] = true
        local english = SK.EnglishScrollName and SK.EnglishScrollName(id)
        if english then bagNames[english] = true end
    end
    for name in pairs(EquippedNames()) do bagNames[name] = true end

    local list = {}
    for _, upgrade in ipairs(SK.WEAPON_UPGRADES) do
        local hasScroll = bagNames[upgrade.scroll] or false
        local hasWeapon = bagNames[upgrade.weapon] or false
        if hasScroll or hasWeapon then
            list[#list + 1] = { upgrade = upgrade, hasScroll = hasScroll, hasWeapon = hasWeapon,
                                ready = hasScroll and hasWeapon }
        end
    end
    return list
end

------------------------------------------------------------------------
-- The reminder lines for the panel, most important first.
------------------------------------------------------------------------

local function Has(categoryKey)
    return SK.BestScroll(categoryKey)
end

function SK.Reminders()
    local lines = {}
    if not SK.isMage then return lines end

    for _, entry in ipairs(SK.UpgradeStatus()) do
        if entry.ready then
            lines[#lines + 1] = L["|cff40ff40Ready: use %s on your %s.|r"]:format(entry.upgrade.scroll, entry.upgrade.weapon)
        end
    end

    local imbue = Has("imbues")
    if imbue and not state.imbued then
        -- The link goes on its own line so it doesn't get split when the text wraps.
        lines[#lines + 1] = L["|cffffd100No weapon imbue. Best you have:|r %s"]:format("\n" .. SK.ScrollLink(imbue.itemID, imbue.name))
    end

    local familiar = Has("familiars")
    if familiar and not state.familiar then
        lines[#lines + 1] = L["|cffffd100No familiar out. Best you have:|r %s"]:format("\n" .. SK.ScrollLink(familiar.itemID, familiar.name))
    end

    -- Running low on Scroll of Liminal Passage (Doorways)?
    local liminal = SK.LiminalLowText and SK.LiminalLowText()
    if liminal then lines[#lines + 1] = "|cffff9933" .. liminal .. "|r" end

    -- Would a Scroll of Comprehension (+15 for an hour) unlock more?
    local skill = SK.GetComprehension()
    local hasBoost = false
    for _, scroll in ipairs(SK.bags.translated) do
        if scroll.itemID == 215257 or scroll.name == "Scroll of Comprehension" then hasBoost = true end
    end
    if hasBoost and skill.bonus == 0 then
        local unlocked = 0
        for _, scroll in ipairs(SK.bags.untranslated) do
            if scroll.needs > skill.effective and scroll.needs <= skill.effective + 15 then
                unlocked = unlocked + 1
            end
        end
        if unlocked > 0 then
            lines[#lines + 1] = L["|cff69ccf0A Scroll of Comprehension would let you read %d more now.|r"]:format(unlocked)
        end
    end
    return lines
end
