-- Scrollkeeper: UI/Mail.lua
-- At the mailbox: who could use the untranslated scrolls you're carrying.
--
-- On the Send Mail tab a small list appears beside the mail window:
--   your own mages (same realm and faction), then guildies, friends and
--   group members running Scrollkeeper. Skill-ups first, then people who
--   can at least read the scroll.
-- Click a name: it fills in the recipient and attaches their scrolls.
-- You still check it and click Send yourself.
--
-- On a mage, scrolls that are a skill-up for you stay off the list.

local _, SK = ...
local L = SK.L

local MAX_ROWS = 8
local ROW_HEIGHT = 34
local WIDTH = 250

local KIND_COLOR = { mine = "69ccf0", guild = "40ff40", friend = "82c5ff", group = "aad372", public = "9d9d9d", recent = "808080" }
local KIND_TEXT = { mine = "your mage", guild = "guild", friend = "friend", group = "group", public = "Scrollkeeper user",
    recent = "seen this week" }
local function KindLabel(kind)
    if not KIND_TEXT[kind] then return "" end
    return "|cff" .. KIND_COLOR[kind] .. L[KIND_TEXT[kind]] .. "|r"
end
local KIND_ORDER = { mine = 1, group = 2, guild = 3, friend = 4, public = 5, recent = 6 }

------------------------------------------------------------------------
-- Who could use what
------------------------------------------------------------------------

-- Untranslated scrolls you're carrying that you don't need yourself.
-- With the "mailIncludeMine" setting, the ones you'd still level from
-- too, marked mineToo so the list can say so.
local function SpareScrolls()
    local spare = {}
    local skill = SK.isMage and SK.GetComprehension()
    for _, scroll in ipairs(SK.bags.untranslated or {}) do
        local keep = false
        if skill and skill.effective >= scroll.needs then
            local chance = SK.SkillUpChance(scroll.needs, skill.rank)
            keep = chance and chance.gives or false
        end
        if not keep then
            spare[#spare + 1] = scroll
        elseif SK.db and SK.db.mailIncludeMine then
            spare[#spare + 1] = setmetatable({ mineToo = true }, { __index = scroll })
        end
    end
    return spare
end

-- List of people: { mailName, name, kind, scrolls = {...}, ups, reads },
-- skill-ups first. Each person's scrolls are skill-ups first too.
function SK.MailPlan()
    local people, order = {}, {}
    local function Offer(mailName, name, kind, scroll, givesSkillUp)
        local person = people[mailName]
        if not person then
            person = { mailName = mailName, name = name, kind = kind, ups = {}, reads = {}, later = {}, mineToo = 0 }
            people[mailName] = person
            order[#order + 1] = person
        end
        local into = givesSkillUp == "later" and person.later or (givesSkillUp and person.ups) or person.reads
        table.insert(into, scroll)
        if scroll.mineToo then person.mineToo = person.mineToo + 1 end
    end

    local mages = SK.MailableMages and SK.MailableMages() or {}
    local others = SK.FreshMages and SK.FreshMages() or {}
    local recent = SK.MageHistory and SK.MageHistory() or {}
    for _, scroll in ipairs(SpareScrolls()) do
        for _, mage in ipairs(mages) do
            if mage.skill >= scroll.needs and mage.skill > 0 then
                local chance = SK.SkillUpChance(scroll.needs, mage.skill)
                Offer(mage.name, mage.name, "mine", scroll, chance and chance.gives)
            elseif scroll.needs <= 1 and (mage.skill or 0) < 1 then
                -- A new mage who hasn't trained Comprehend Scroll yet (level 6):
                -- tier 1 scrolls are skill-ups for them once they do.
                Offer(mage.name, mage.name, "mine", scroll, "later")
            end
        end
        for _, mage in ipairs(others) do
            local up = mage.tiers[scroll.needs] and true or false
            -- Strangers from the public channel only when it's a skill-up for them.
            if up or (mage.kind ~= "public" and mage.skill >= scroll.needs) then
                Offer(mage.name, mage.short, mage.kind, scroll, up)
            end
        end
        -- Mages seen this week who are offline: only skill-ups (it's mail
        -- they'll find later).
        for _, mage in ipairs(recent) do
            if mage.tiers[scroll.needs] then Offer(mage.name, mage.name, "recent", scroll, true) end
        end
    end

    for _, person in ipairs(order) do
        person.scrolls = {}
        for _, scroll in ipairs(person.ups) do person.scrolls[#person.scrolls + 1] = scroll end
        for _, scroll in ipairs(person.reads) do person.scrolls[#person.scrolls + 1] = scroll end
        for _, scroll in ipairs(person.later) do person.scrolls[#person.scrolls + 1] = scroll end
        person.ups, person.reads, person.later = #person.ups, #person.reads, #person.later
    end
    table.sort(order, function(a, b)
        if (a.ups > 0) ~= (b.ups > 0) then return a.ups > 0 end
        if KIND_ORDER[a.kind] ~= KIND_ORDER[b.kind] then return KIND_ORDER[a.kind] < KIND_ORDER[b.kind] end
        if a.ups ~= b.ups then return a.ups > b.ups end
        return #a.scrolls > #b.scrolls
    end)
    return order
end

------------------------------------------------------------------------
-- Filling in the mail
------------------------------------------------------------------------

-- WoW Forever's mail holds 7 attachments (never more than the game allows).
local MAX_ATTACHMENTS = math.min(ATTACHMENTS_MAX_SEND or 7, 7)

local function NextFreeAttachment()
    local max = MAX_ATTACHMENTS
    for i = 1, max do
        local used
        if HasSendMailItem then used = HasSendMailItem(i)
        elseif GetSendMailItem then used = GetSendMailItem(i) ~= nil end
        if not used then return i end
    end
    return nil
end

local function StillThere(scroll)
    local item = C_Container and SK.Try(C_Container.GetContainerItemInfo, scroll.bag, scroll.slot)
    return type(item) == "table" and item.itemID == scroll.itemID and not item.isLocked
end

-- Where this scroll is right now (it may have moved since the bag scan):
-- the saved spot if it's still there, otherwise any unlocked stack of it.
local used = {}
local function FindNow(scroll)
    if StillThere(scroll) and not used[scroll.bag .. ":" .. scroll.slot] then return scroll.bag, scroll.slot end
    for bag = 0, 5 do
        for slot = 1, (C_Container and SK.Try(C_Container.GetContainerNumSlots, bag)) or 0 do
            local item = SK.Try(C_Container.GetContainerItemInfo, bag, slot)
            if type(item) == "table" and item.itemID == scroll.itemID and not item.isLocked
                and not used[bag .. ":" .. slot] then
                return bag, slot
            end
        end
    end
    return nil
end

-- The note in the mail: what the scrolls are for, and to send back any
-- they don't need. Kept short; their first name only.
local lastSubject, lastBody
local function MailBody(person)
    local tiers, seen = {}, {}
    for _, scroll in ipairs(person.scrolls or {}) do
        if not seen[scroll.needs] then seen[scroll.needs] = true; tiers[#tiers + 1] = scroll.needs end
    end
    table.sort(tiers)
    local me = UnitName and UnitName("player") or ""
    local first = (person.name or ""):match("^(%S+)") or person.name or ""
    return L["Hi %s! Here are some tier %s scrolls that should give you Comprehension skill-ups. If you don't need them, feel free to send them back. Have fun!"]:format(first, table.concat(tiers, "/"))
        .. "\n\n- " .. me .. L[" (sent with Scrollkeeper)"]
end

local function FillMail(person)
    if SK.InCombat() then SK.Print(L["the mail can be filled in after combat."]) return end
    if not (SendMailFrame and SendMailNameEditBox and ClickSendMailItemButton) then return end
    if not SendMailFrame:IsShown() and MailFrameTab_OnClick then MailFrameTab_OnClick(nil, 2) end

    SendMailNameEditBox:SetText(person.mailName)
    -- Subject and a short note, unless you already wrote your own.
    local subject = L["Scrolls for you"]
    if SendMailSubjectEditBox then
        local now = SendMailSubjectEditBox:GetText() or ""
        if now == "" or now == lastSubject then SendMailSubjectEditBox:SetText(subject); lastSubject = subject end
    end
    local bodyBox = _G.SendMailBodyEditBox or (_G.MailEditBox and _G.MailEditBox.GetEditBox and _G.MailEditBox:GetEditBox())
    if bodyBox and bodyBox.SetText then
        local body = MailBody(person)
        local now = bodyBox:GetText() or ""
        if now == "" or now == lastBody then bodyBox:SetText(body); lastBody = body end
    end

    local added, left, full = 0, 0, false
    used = {}
    for _, scroll in ipairs(person.scrolls) do
        local bag, slot = FindNow(scroll)
        if bag then
            local index = not full and NextFreeAttachment()
            if index then
                ClearCursor()
                C_Container.PickupContainerItem(bag, slot)
                ClickSendMailItemButton(index)
                ClearCursor()
                used[bag .. ":" .. slot] = true
                added = added + 1
            else
                full = true
                left = left + 1
            end
        end
    end
    if added > 0 then
        SK.Print(L["attached %d |4scroll:scrolls; for %s. Check it, then click Send."]:format(added, person.name)
            .. (left > 0 and L[" %d more won't fit, click their name again after sending."]:format(left) or ""))
    else
        SK.Print(full and L["the mail is full. Send it, then click their name again."]
            or L["couldn't find those scrolls in your bags (already on the mail, or moved). Try /reload."])
    end
end

------------------------------------------------------------------------
-- The list beside the mail window
------------------------------------------------------------------------

local frame, rows = nil, {}

local function Build()
    frame = CreateFrame("Frame", "ScrollkeeperMailFrame", SendMailFrame or MailFrame, "BackdropTemplate")
    frame:SetWidth(WIDTH)
    frame:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 4, -24)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
    end

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 12, -12)
    icon:SetTexture("Interface\\Icons\\INV_Scroll_03")
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    title:SetText(L["Scrollkeeper: Who could use your scrolls"])
    frame.note = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.note:SetPoint("TOPLEFT", 14, -38)
    frame.note:SetWidth(WIDTH - 28)
    frame.note:SetJustifyH("LEFT")

    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(WIDTH - 24, ROW_HEIGHT - 2)
        row:SetPoint("TOPLEFT", 12, -38 - (i - 1) * ROW_HEIGHT)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("TOPLEFT", 4, -3)
        row.kind = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.kind:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
        row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        row:SetScript("OnClick", function(self) if self.person then FillMail(self.person) end end)
        row:SetScript("OnEnter", function(self)
            if not self.person then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.person.name)
            for n, scroll in ipairs(self.person.scrolls) do
                if n > 12 then break end
                GameTooltip:AddLine(SK.ScrollLink(scroll.itemID, scroll.name), 1, 1, 1)
            end
            GameTooltip:AddLine(L["Click to put their name and scrolls on the mail."], 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = row
    end
end

local function Refresh()
    if not (SendMailFrame and SendMailFrame:IsShown()) or not (SK.db and SK.db.mailHelper ~= false) then
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    local plan = SK.MailPlan()
    if #plan == 0 then
        frame:Hide()
        return
    end
    frame.note:SetText("")
    local shown = math.min(#plan, MAX_ROWS)
    for i, row in ipairs(rows) do
        local person = plan[i]
        row.person = person
        if person then
            row.name:SetText(person.name)
            row.kind:SetText(KindLabel(person.kind))
            local parts = {}
            if person.ups > 0 then parts[#parts + 1] = L["|cff40ff40%d skill-up|r"]:format(person.ups) end
            if person.reads > 0 then parts[#parts + 1] = L["%d they can read"]:format(person.reads) end
            if person.later > 0 then parts[#parts + 1] = L["%d for later (trains at level 6)"]:format(person.later) end
            if (person.mineToo or 0) > 0 then parts[#parts + 1] = L["|cffffd100%d you'd use too|r"]:format(person.mineToo) end
            row.detail:SetText(table.concat(parts, ", "))
            row:Show()
        else
            row:Hide()
        end
    end
    frame:SetHeight(48 + shown * ROW_HEIGHT)
    frame:Show()
end
SK.RefreshMailHelper = Refresh

SK.On("MAIL_SHOW", function()
    C_Timer.After(0.1, Refresh)
    if SK.PingFriends then SK.PingFriends() end
    if SendMailFrame and not SendMailFrame.scrollkeeperHooked then
        SendMailFrame.scrollkeeperHooked = true
        SendMailFrame:HookScript("OnShow", Refresh)
        SendMailFrame:HookScript("OnHide", Refresh)
    end
end)
SK.On("MAIL_CLOSED", function() if frame then frame:Hide() end end)
SK.On("MAIL_SEND_SUCCESS", function() C_Timer.After(0.5, Refresh) end)
SK.Listen("BAGS_CHANGED", function() if frame and frame:IsShown() then Refresh() end end)
SK.Listen("PEERS_CHANGED", function() if SendMailFrame and SendMailFrame:IsShown() then Refresh() end end)
