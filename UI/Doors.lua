-- Scrollkeeper: UI/Doors.lua
-- Liminal Passage doors (/sk doors).
--
-- Scroll of Liminal Passage teleports a mage to a party member, as long
-- as both are resting (an inn or a city). So a mage who wants to get to
-- Ironforge needs someone resting in Ironforge to group with. Scrollkeeper
-- users can offer to be that someone: a "door". Off by default.
--
--   D|place|scrolls      my door: where I'm resting ("" = not a door right
--                        now) and how many Liminal Passage scrolls I carry
--   DA                   whisper: "can I come to you?"
--   DY / DN              whisper: "inviting you" / "not right now"
--
-- The window lists the doors on your server and faction. Click one to ask;
-- they get a pop-up to invite you. Once you're grouped, the Go button uses
-- the scroll on them.

local _, SK = ...
local L = SK.L
local Net = SK.Net

SK.LIMINAL_PASSAGE = 213548
local ROWS = 7
local WIDTH = 300

------------------------------------------------------------------------
-- My door
------------------------------------------------------------------------

function SK.LiminalCount()
    local count = SK.Try(C_Item and C_Item.GetItemCount, SK.LIMINAL_PASSAGE) or SK.Try(GetItemCount, SK.LIMINAL_PASSAGE)
    return tonumber(count) or 0
end

-- Where I'm resting, in words: "Goldshire, Elwynn Forest" or "Stormwind City".
local function RestingPlace()
    if not (IsResting and IsResting()) then return nil end
    local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
    local sub = GetSubZoneText and GetSubZoneText() or ""
    if zone == "" then return nil end
    if sub ~= "" and sub ~= zone then return sub .. ", " .. zone end
    return zone
end

-- My door's place, or nil when I'm not one right now.
function SK.MyDoorPlace()
    if not SK.db.liminalDoor or SK.InCombat() then return nil end
    return RestingPlace()
end

local lastSent
local function SendDoor(force)
    local text = (SK.MyDoorPlace() or "") .. "#" .. SK.LiminalCount()
    if text == lastSent and not force then return end
    lastSent = text
    Net.Send("D", SK.MyDoorPlace() or "", SK.LiminalCount())
end
SK.SendDoor = SendDoor

local doorQueued
local function DoorSoon()
    if doorQueued then return end
    doorQueued = true
    C_Timer.After(4, function() doorQueued = false SK.Safely("door", SendDoor) end)
end
SK.On("PLAYER_UPDATE_RESTING", DoorSoon)
SK.On("ZONE_CHANGED_NEW_AREA", DoorSoon)
SK.On("ZONE_CHANGED", DoorSoon)
SK.On("PLAYER_REGEN_ENABLED", DoorSoon)
SK.Listen("BAGS_CHANGED", DoorSoon)
SK.Listen("NET_READY", function()
    C_Timer.After(30, function() SK.Safely("door", SendDoor, true) end)
    C_Timer.NewTicker(5 * 60, function() SK.Safely("door", SendDoor, true) end)
end)
Net.Handle("Q", function() C_Timer.After(6 + math.random() * 20, function() SK.Safely("door", SendDoor, true) end) end)

------------------------------------------------------------------------
-- Everyone's doors
------------------------------------------------------------------------

-- SK.doors[sender] = { place = "Ironforge" or nil, scrolls = n, at = time() }
SK.doors = {}

Net.Handle("D", function(sender, f)
    local place = tostring(f[1] or ""):sub(1, 80)
    SK.doors[sender] = { place = place ~= "" and place or nil, scrolls = math.min(tonumber(f[2]) or 0, 99), at = time() }
    SK.Send("DOORS_CHANGED")
end)

local DEMO_DOORS = {
    { name = "Kaelith", place = "Ironforge" },
    { name = "Brannoc", place = "The Salty Sailor Tavern, Booty Bay" },
    { name = "Mirelle", place = "Stormwind City" },
}

-- Doors open right now that you can reach: list of { sender, short, place, scrolls, demo }.
function SK.OpenDoors()
    local list, fresh = {}, {}
    for _, entry in ipairs(SK.PeerList and SK.PeerList() or {}) do fresh[entry.sender] = true end
    for sender, door in pairs(SK.doors) do
        if door.place and fresh[sender] and not Net.IsMe(sender) and time() - door.at < 15 * 60 then
            list[#list + 1] = { sender = sender, short = Net.ShortName(sender), place = door.place, scrolls = door.scrolls }
        end
    end
    if SK.demoCommunity then
        for _, demo in ipairs(DEMO_DOORS) do
            list[#list + 1] = { sender = demo.name, short = demo.name, place = demo.place, scrolls = 0, demo = true }
        end
    end
    table.sort(list, function(a, b) return a.place < b.place end)
    return list
end

------------------------------------------------------------------------
-- Asking and answering
------------------------------------------------------------------------

local chosen          -- the door you asked last: { short, target }
local askedAt = {}    -- sender -> time() we last showed their pop-up

local function Invite(name)
    if C_PartyInfo and C_PartyInfo.InviteUnit then SK.Try(C_PartyInfo.InviteUnit, name)
    elseif InviteUnit then SK.Try(InviteUnit, name) end
end

local function Ask(door)
    if door.demo then
        SK.Print(L["%s is a demo door: real ones get a pop-up to invite you."]:format(door.short))
        return
    end
    local target = SK.ContactName(door.sender)
    chosen = { short = Net.ShortName(target), target = target }
    Net.Whisper(target, "DA")
    SK.Print(L["asked %s for a door. Once they invite you, click Go in the Liminal Passage window."]:format(chosen.short))
    SK.Send("DOORS_CHANGED")
end

Net.Handle("DA", function(sender, _, source)
    if source ~= "WHISPER" then return end
    if not SK.MyDoorPlace() then Net.Whisper(sender, "DN") return end
    if askedAt[sender] and time() - askedAt[sender] < 30 then return end
    askedAt[sender] = time()
    if PlaySound and SOUNDKIT and SOUNDKIT.READY_CHECK then SK.Try(PlaySound, SOUNDKIT.READY_CHECK) end
    if StaticPopup_Show then
        local popup = StaticPopup_Show("SCROLLKEEPER_DOOR", Net.ShortName(sender), nil, sender)
        if type(popup) == "table" then popup.data = sender end
    else
        SK.Print(L["%s wants to come to you with Liminal Passage."]:format(Net.ShortName(sender)))
    end
end)

Net.Handle("DY", function(sender, _, source)
    if source ~= "WHISPER" then return end
    SK.Print(L["%s is inviting you. Accept, then click Go in the Liminal Passage window."]:format(Net.ShortName(sender)))
end)

Net.Handle("DN", function(sender, _, source)
    if source ~= "WHISPER" then return end
    SK.Print(L["%s isn't a door right now (not resting, or turned it off)."]:format(Net.ShortName(sender)))
end)

if StaticPopupDialogs then
    StaticPopupDialogs["SCROLLKEEPER_DOOR"] = {
        text = L["Scrollkeeper: %s wants to come to you with Liminal Passage. Invite them to your group?"],
        button1 = L["Invite"],
        button2 = L["Not now"],
        OnAccept = function(self, data)
            data = data or self.data
            if not data then return end
            Invite(data)
            Net.Whisper(data, "DY")
        end,
        OnCancel = function(self, data, reason)
            data = data or self.data
            if data and reason == "clicked" then Net.Whisper(data, "DN") end
        end,
        timeout = 60,
        whileDead = false,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------

local window

-- The Go button: target the door and use the scroll. Secure, so it can
-- only change out of combat.
local function UpdateGo()
    if not window then return end
    local go = window.go
    local count = SK.LiminalCount()
    local inGroup = chosen and UnitInParty and UnitInParty(chosen.short)
    if not SK.InCombat() then
        if chosen then
            go:SetAttribute("type", "macro")
            go:SetAttribute("macrotext", "/target " .. chosen.short .. "\n/use item:" .. SK.LIMINAL_PASSAGE)
        else
            go:SetAttribute("type", nil)
        end
    end
    go:SetText(chosen and L["Go to %s"]:format(chosen.short) or L["Go"])
    go:SetEnabled(chosen ~= nil and count > 0)
    if count == 0 then
        window.goNote:SetText(L["You have no Scroll of Liminal Passage. You can still be a door for others."])
    elseif not chosen then
        window.goNote:SetText(L["Click a door above to ask them for an invite."])
    elseif not inGroup then
        window.goNote:SetText(L["Waiting for %s to invite you. You both have to be resting."]:format(chosen.short))
    else
        window.goNote:SetText(L["You're grouped with %s: click Go."]:format(chosen.short))
    end
end

local function UpdateStatus()
    if not window then return end
    window.doorCheck:SetChecked(SK.db.liminalDoor and true or false)
    local place = SK.MyDoorPlace()
    if not SK.db.liminalDoor then
        window.status:SetText(L["Tick this so mages with Liminal Passage can ask to come to you."])
    elseif place then
        window.status:SetText(L["You're a door in |cffffffff%s|r."]:format(place))
    else
        window.status:SetText(L["You're a door whenever you rest in an inn or a city."])
    end
end

local function Build()
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperDoorsFrame", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperDoorsFrame", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if self.TitleText then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(330, 420)
    window:SetPoint("CENTER", 220, 0)
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetTitle(L["Scrollkeeper: Liminal Passage"])
    local icon = (C_Item and SK.Try(C_Item.GetItemIconByID, SK.LIMINAL_PASSAGE)) or "Interface\\Icons\\INV_Scroll_05"
    if window.SetPortraitToAsset then window:SetPortraitToAsset(icon) end
    tinsert(UISpecialFrames, "ScrollkeeperDoorsFrame")

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    background:SetColorTexture(0.05, 0.05, 0.06, 0.95)

    local intro = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", 16, -62)
    intro:SetWidth(WIDTH)
    intro:SetJustifyH("LEFT")
    intro:SetText(L["Liminal Passage takes you to a group member who's resting in an inn or a city. Doors are Scrollkeeper users who offer to be that group member."])

    local header = SK.UI.CreateHeader(window, L["Open doors"], WIDTH)
    header:SetPoint("TOPLEFT", 15, -100)
    window.list = SK.UI.CreateScrollList(window, WIDTH, ROWS, true)
    window.list:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)

    local mine = SK.UI.CreateHeader(window, L["Your door"], WIDTH)
    mine:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -(ROWS * 30 + 10))

    local check = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", mine, "BOTTOMLEFT", 0, -2)
    check:SetScript("OnClick", function(self)
        SK.db.liminalDoor = self:GetChecked() and true or false
        SK.Safely("door", SendDoor, true)
        UpdateStatus()
    end)
    window.doorCheck = check
    local checkLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkLabel:SetPoint("LEFT", check, "RIGHT", 2, 0)
    checkLabel:SetText(L["Be a door"])
    window.status = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.status:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 4, 0)
    window.status:SetWidth(WIDTH - 8)
    window.status:SetJustifyH("LEFT")

    local go = CreateFrame("Button", "ScrollkeeperDoorsGo", window, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    go:SetSize(150, 22)
    go:SetPoint("BOTTOMLEFT", 16, 30)
    go:RegisterForClicks("AnyUp", "AnyDown")
    window.go = go
    window.goNote = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.goNote:SetPoint("BOTTOMLEFT", 16, 12)
    window.goNote:SetWidth(WIDTH)
    window.goNote:SetJustifyH("LEFT")

    window:SetScript("OnShow", function() SK.RefreshDoors() end)
    window:Hide()
end

function SK.RefreshDoors()
    if not (window and window:IsShown()) then return end
    window.list:SetRows(SK.OpenDoors(), function(row, door)
        row.itemID = nil
        row.label:SetText(door.short .. (door.demo and L["  |cffff8040demo|r"] or ""))
        local extra = door.scrolls > 0 and ("  |cff808080" .. L["has Liminal Passage"] .. "|r") or ""
        row.sub:SetText("|cffffffff" .. door.place .. "|r" .. extra)
        row.tipFunc = function(tip)
            tip:AddLine(door.short)
            tip:AddLine(L["Resting in %s"]:format(door.place), 1, 1, 1)
            tip:AddLine(L["Click: ask them to invite you, so you can use Liminal Passage on them."], 0.6, 0.6, 0.6, true)
        end
        row.onClick = function() Ask(door) end
    end, L["No open doors on your server right now. Doors show up while their owners rest in an inn or a city."])
    UpdateStatus()
    UpdateGo()
end

function SK.ToggleDoors()
    if not window then Build() end
    window:SetShown(not window:IsShown())
end

SK.Listen("DOORS_CHANGED", SK.RefreshDoors)
SK.Listen("PEERS_CHANGED", SK.RefreshDoors)
SK.Listen("BAGS_CHANGED", SK.RefreshDoors)
SK.On("GROUP_ROSTER_UPDATE", function() SK.RefreshDoors() end)
SK.On("PLAYER_UPDATE_RESTING", function() C_Timer.After(0.5, SK.RefreshDoors) end)
SK.On("PLAYER_REGEN_ENABLED", function() SK.RefreshDoors() end)
