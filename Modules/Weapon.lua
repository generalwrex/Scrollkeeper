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

local state = { imbued = true, familiar = true }

------------------------------------------------------------------------
-- Weapon imbue and familiar
------------------------------------------------------------------------

local function HasMainHandImbue()
    if not GetWeaponEnchantInfo then return true end
    local ok, hasMainHand = pcall(GetWeaponEnchantInfo)
    if not ok then return state.imbued end
    return hasMainHand and true or false
end

local function HasFamiliar()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return true end
    local familiarWord = "Familiar"
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok then return state.familiar end
        if type(aura) ~= "table" then break end
        local name = aura.name
        if type(name) == "string" and name:find(familiarWord, 1, true) then return true end
    end
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
    for _, name in pairs(SK.bags.names or {}) do bagNames[name] = true end
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
            lines[#lines + 1] = ("|cff40ff40Ready: use %s on your %s.|r"):format(entry.upgrade.scroll, entry.upgrade.weapon)
        end
    end

    local imbue = Has("imbues")
    if imbue and not state.imbued then
        lines[#lines + 1] = ("|cffffd100No weapon imbue. Best you have:|r %s"):format(SK.ScrollLink(imbue.itemID, imbue.name))
    end

    local familiar = Has("familiars")
    if familiar and not state.familiar then
        lines[#lines + 1] = ("|cffffd100No familiar out. Best you have:|r %s"):format(SK.ScrollLink(familiar.itemID, familiar.name))
    end

    -- Would a Scroll of Comprehension (+15 for an hour) unlock more?
    local skill = SK.GetComprehension()
    local hasBoost = false
    for _, scroll in ipairs(SK.bags.translated) do
        if scroll.name == "Scroll of Comprehension" then hasBoost = true end
    end
    if hasBoost and skill.bonus == 0 then
        local unlocked = 0
        for _, scroll in ipairs(SK.bags.untranslated) do
            if scroll.needs > skill.effective and scroll.needs <= skill.effective + 15 then
                unlocked = unlocked + 1
            end
        end
        if unlocked > 0 then
            lines[#lines + 1] = ("|cff69ccf0A Scroll of Comprehension would let you read %d more now.|r"):format(unlocked)
        end
    end
    return lines
end
