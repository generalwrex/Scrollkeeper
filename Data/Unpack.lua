-- Scrollkeeper: Data/Unpack.lua
-- Reads the packed community data (Data/Community.lua) into
-- SK.COMMUNITY_DATA. It's plain data, only ever read as numbers and names.
--
-- Packed = base64 of the lines below, each byte shifted by a repeating key:
--   @exportid                          a new player
--   T|tier|itemID:count,...            what their deciphers became
--   U|tier|color:ups/tries,...         skill-ups by color
--   P|mapID|cell:count,...             scroll drop spots
--   K|mapID|cell:count,...             book drop spots
--   D|mapID|tier:count,...             drops by tier
--   B|tier:backfires/tries,...         sheep backfires
--   I|itemID,...                       book item IDs
--   J|mapID|cell:itemID,...            which book was at each book spot
--   N|itemID|name                      English item names

local _, SK = ...

local KEY = "Scrollkeeper"
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Decode(packed)
    local index = {}
    for i = 1, #ALPHABET do index[ALPHABET:byte(i)] = i - 1 end
    local out, n, value, bits = {}, 0, 0, 0
    local keyLength = #KEY
    for i = 1, #packed do
        local v = index[packed:byte(i)]
        if v then
            value, bits = value * 64 + v, bits + 6
            if bits >= 8 then
                bits = bits - 8
                local byte = math.floor(value / 2 ^ bits) % 256
                value = value % 2 ^ bits
                n = n + 1
                out[n] = string.char((byte - KEY:byte((n - 1) % keyLength + 1)) % 256)
            end
        end
    end
    return table.concat(out)
end

local function Parse(text)
    local data, player = {}, nil
    for line in text:gmatch("[^\n]+") do
        if line:sub(1, 1) == "@" then
            player = { results = {}, skillups = {}, drops = {}, books = {}, dropTiers = {}, backfires = {}, bookIDs = {}, names = {}, bookItems = {} }
            data[line:sub(2)] = player
        elseif player then
            local kind, a, b = line:match("^(%a)|([^|]*)|?(.*)$")
            if kind == "T" then
                local list = {}
                for id, count in b:gmatch("(%d+):(%d+)") do list[tonumber(id)] = tonumber(count) end
                player.results[tonumber(a)] = list
            elseif kind == "U" then
                for color, ups, tries in b:gmatch("(%a+):(%d+)/(%d+)") do
                    player.skillups[a .. " " .. color] = { ups = tonumber(ups), tries = tonumber(tries) }
                end
            elseif kind == "P" or kind == "K" then
                local cells = {}
                for cell, count in b:gmatch("([%d%.]+):(%d+)") do cells[cell] = tonumber(count) end
                player[kind == "P" and "drops" or "books"][tonumber(a)] = cells
            elseif kind == "J" then
                local cells = {}
                for cell, id in b:gmatch("([%d%.]+):(%d+)") do cells[cell] = tonumber(id) end
                player.bookItems[tonumber(a)] = cells
            elseif kind == "D" then
                local tiers = {}
                for tier, count in b:gmatch("(%d+):(%d+)") do tiers[tonumber(tier)] = tonumber(count) end
                player.dropTiers[tonumber(a)] = tiers
            elseif kind == "B" then
                for tier, backfires, tries in a:gmatch("(%d+):(%d+)/(%d+)") do
                    player.backfires[tonumber(tier)] = { b = tonumber(backfires), t = tonumber(tries) }
                end
            elseif kind == "I" then
                for id in a:gmatch("%d+") do player.bookIDs[#player.bookIDs + 1] = tonumber(id) end
            elseif kind == "N" and tonumber(a) then
                player.names[tonumber(a)] = b
            end
        end
    end
    return data
end

if type(SK.COMMUNITY_PACKED) == "string" then
    local ok, data = pcall(function() return Parse(Decode(SK.COMMUNITY_PACKED)) end)
    SK.COMMUNITY_DATA = ok and data or {}
    SK.COMMUNITY_PACKED = nil
end
SK.COMMUNITY_DATA = SK.COMMUNITY_DATA or {}
