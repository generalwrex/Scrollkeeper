-- Scrollkeeper: Modules/Chat.lua
-- "Who needs this? [Scroll: ZIMBO]" in chat.
--
-- When someone else links an untranslated scroll and asks who wants it,
-- Scrollkeeper adds a line only you see: whether it's a skill-up for you
-- or your mages, and which Scrollkeeper guildies would level from it.
-- On a mage that can use it there's a clickable [I'll take it] that
-- answers in the same chat. Nothing is ever sent unless you click.

local _, SK = ...
local L = SK.L

local CHANNELS = {
    CHAT_MSG_GUILD = "GUILD", CHAT_MSG_OFFICER = "OFFICER",
    CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT", CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    CHAT_MSG_WHISPER = "WHISPER", CHAT_MSG_SAY = "SAY", CHAT_MSG_YELL = "YELL",
    CHAT_MSG_CHANNEL = "CHANNEL",
}
-- Words that make it a question about who wants it (any of them).
local ASKING = { "need", "who", "want", "anyone", "anybody", "free", "?", "wts", "selling" }
local REPLY_TEXT = "I'd use that one if it's still free!"   -- translated when sent

local lastNote = {}

local function Asking(text)
    local lower = text:lower()
    for _, word in ipairs(ASKING) do
        if lower:find(word, 1, true) then return true end
    end
    return false
end

local function NeedsFromLink(link)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil end
    local data = SK.Try(C_TooltipInfo.GetHyperlink, link)
    return data and SK.RequirementFromLines(data.lines)
end

local function Note(event, text, sender, channelNumber)
    if not (SK.db and SK.db.chatHelper ~= false) then return end
    if type(text) ~= "string" or (issecretvalue and (issecretvalue(text) or issecretvalue(sender))) then return end
    if sender and SK.Net and SK.Net.IsMe and SK.Net.IsMe(sender) then return end
    local whisper = event == "CHAT_MSG_WHISPER"
    if not whisper and not Asking(text) then return end

    for link in text:gmatch("|c%x+|Hitem:[^|]+|h%[[^%]]+%]|h|r") do
        local needs = NeedsFromLink(link)
        if needs and (lastNote[link] or 0) < GetTime() - 30 then
            lastNote[link] = GetTime()
            local parts = {}
            local mine = false
            if SK.isMage then
                local skill = SK.GetComprehension()
                if skill.effective >= needs then
                    local chance = SK.SkillUpChance(needs, skill.rank)
                    mine = chance and chance.gives
                    parts[#parts + 1] = mine and (L["skill-up for you ("] .. SK.ColoredChance(chance) .. ")")
                        or L["you can read it, no skill-up"]
                else
                    parts[#parts + 1] = L["you need %d Comprehension"]:format(needs)
                end
            end
            local alts = {}
            for _, mage in ipairs(SK.MyMagesFor and SK.MyMagesFor(needs) or {}) do
                if mage.chance and mage.chance.gives then alts[#alts + 1] = mage.name end
            end
            if #alts > 0 then parts[#parts + 1] = L["your mages: "] .. table.concat(alts, ", ") end
            local others = {}
            for _, mage in ipairs(SK.MagesWhoNeed and SK.MagesWhoNeed(needs) or {}) do
                if #others < 3 then others[#others + 1] = mage.name end
            end
            if #others > 0 then parts[#parts + 1] = L["also levels: "] .. table.concat(others, ", ") end
            if #parts == 0 then return end

            local line = link .. " " .. table.concat(parts, "; ") .. "."
            local channel = CHANNELS[event]
            if (mine or #alts > 0) and channel and sender then
                local target = (channel == "WHISPER" and sender) or (channel == "CHANNEL" and channelNumber) or ""
                line = line .. L[" |cff40ff40|Haddon:scrollkeeper:reply:%s:%s|h[I'll take it]|h|r"]:format(channel, target)
            end
            SK.Print(line)
        end
    end
end

for event in pairs(CHANNELS) do
    SK.On(event, function(text, sender, _, _, _, _, _, channelNumber)
        Note(event, text, sender, channelNumber)
    end)
end

-- Clicking [I'll take it] answers in the same chat. Only on your click.
local function OnLink(link)
    if type(link) ~= "string" then return end
    local channel, target = link:match("^addon:scrollkeeper:reply:([^:]+):?(.*)$")
    if not channel then return end
    if channel == "WHISPER" then
        SendChatMessage(L[REPLY_TEXT], "WHISPER", nil, target)
    elseif channel == "CHANNEL" then
        SendChatMessage(L[REPLY_TEXT], "CHANNEL", nil, tonumber(target))
    else
        SendChatMessage(L[REPLY_TEXT], channel)
    end
end

if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("SetItemRef", function(_, link) OnLink(link) end, SK)
elseif hooksecurefunc then
    hooksecurefunc("SetItemRef", OnLink)
end
