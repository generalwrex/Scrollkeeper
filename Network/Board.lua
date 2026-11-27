-- Scrollkeeper: Network/Board.lua
-- The Fellow Mages board: short posts and replies that last 7 days.
-- There's no server: every Scrollkeeper keeps its own copy of the posts
-- (saved in ScrollkeeperDB), new posts go out to everyone online, and
-- when you log in you ask for what you missed.
--
--   BP|id|parent|cat|at|ruleset|tier|guid|author|title|body|rev|faction
--        a post (parent "") or a reply (parent = the post's id); rev: how
--        many times its author edited it
--   BE|id|rev|title|body   the author's edit (only counts straight from them)
--   BD|id            the author takes their post (or reply) down
--   BQ|since         "what's new since then?" (1.4.0; still answered)
--   BR|since         the same, from 1.4.1 on. A new kind so 1.4.0 copies
--                    never hear it: they'd whisper answers across rulesets
--                    and get "No player named ..." over and over.
--   BA|name          "I'm answering name's BQ" (so only one player does);
--                    name@ruleset: answering for that ruleset, on the channel
--   BS|signature|action|a|b|c|at
--                    moderation, signed with the dev team's key (Ed25519,
--                    Core/Ed25519.lua). Everyone checks it with SK.BOARD_MOD_KEY below,
--                    which can check signatures but can't make them:
--                    remove|id, ban|guid|until|name, unban|guid,
--                    ok|id (this notice is really from the team),
--                    dev|guid|name (this character is on the dev team)
--
-- Rules everyone's copy keeps:
--   * a changed copy of a post is ignored, unless it's an edit straight
--     from its author (their character ID matches who sent it)
--   * a take-down only counts from the author's own character
--   * at most 3 posts and 30 replies a day per author
--   * trade, doorway and odds posts only reach mages on your ruleset
--   * posts are only text and numbers, never run as code
--   * players' text never crosses factions: a post or reply only shows to
--     its author's own faction (H or A, with the post; or the game's word
--     for their character), and when that's unknown it doesn't show

local _, SK = ...
local L = SK.L
local Net = SK.Net

local DAYS = 7
local KEEP_SECONDS = DAYS * 86400
local POSTS_PER_DAY, REPLIES_PER_DAY = 3, 30
local TITLE_MAX = 40          -- bytes
local MESSAGE_MAX = 250       -- what Comm.lua allows in one message
local CATCH_UP_MAX = 40       -- posts sent to one player who asks

-- Categories: { key, code, name, mine = only your ruleset, team = dev team only }
SK.BOARD_CATEGORIES = {
    { key = "notice", code = "n", name = "Notices", team = true },
    { key = "doors", code = "d", name = "Portals and doorways", mine = true },
    { key = "wanted", code = "w", name = "Scrolls wanted", mine = true },
    { key = "spare", code = "s", name = "Spare scrolls", mine = true },
    { key = "tips", code = "t", name = "Odds and tips", mine = true },
    { key = "general", code = "g", name = "General" },
}
local BY_CODE, BY_KEY = {}, {}
for _, c in ipairs(SK.BOARD_CATEGORIES) do BY_CODE[c.code] = c; BY_KEY[c.key] = c end
function SK.BoardCategory(key) return BY_KEY[key] end

-- The dev team's public key (base64). Only the team's secret key can
-- make signatures this accepts.
SK.BOARD_MOD_KEY = "FB2BfinUSRNv+psOjTdokFjgrIRf5VwcfiMN7RjD5lM"
local DEV_DAYS = 30   -- a dev mark lasts this long without being resent

-- Set by the team's own tools: signs a moderation message.
-- SK.BoardSigner = function(text) return signature (64 bytes) end
local function IAmTeam() return type(SK.BoardSigner) == "function" end
SK.BoardIAmTeam = IAmTeam

local function Now() return (GetServerTime and GetServerTime()) or time() end

-- Your faction as a letter (H/A), and a post author's, if it can be known.
local function MyFaction()
    local f = UnitFactionGroup and UnitFactionGroup("player")
    return f == "Horde" and "H" or f == "Alliance" and "A" or nil
end
local function FactionOf(p)
    if p.faction then return p.faction end
    local f = SK.FactionOfGUID and SK.FactionOfGUID(p.guid)
    return f == "Horde" and "H" or f == "Alliance" and "A" or nil
end
-- Same faction as you? Text from the other faction never shows. A post
-- that doesn't say (from 1.4.0) and whose author the game can't place
-- counts as yours: it could only have reached you over the channel or a
-- whisper, and the game keeps both to one faction.
local function SameFaction(p)
    if p.demo then return true end
    local mine, theirs = MyFaction(), FactionOf(p)
    if theirs == nil then return true end
    return mine == theirs
end
SK.BoardSameFaction = SameFaction

local function Board()
    local db = SK.db
    db.board = type(db.board) == "table" and db.board or {}
    local b = db.board
    b.posts = type(b.posts) == "table" and b.posts or {}
    b.muted = type(b.muted) == "table" and b.muted or {}
    b.hidden = type(b.hidden) == "table" and b.hidden or {}
    b.lastRead = tonumber(b.lastRead) or 0
    b.removed = type(b.removed) == "table" and b.removed or {}   -- id -> when the team took it down
    b.bans = type(b.bans) == "table" and b.bans or {}            -- guid -> { untilAt, name }
    b.modLog = type(b.modLog) == "table" and b.modLog or {}      -- key -> the signed message, to pass on
    b.devs = type(b.devs) == "table" and b.devs or {}            -- guid -> { name, at }
    return b
end
SK.BoardData = Board

function SK.BoardOn()
    if SK.RemoteOff and SK.RemoteOff("Board") then return false end
    return SK.db and SK.db.share and SK.db.boardOn ~= false and true or false
end

local function MyGUID() return UnitGUID and UnitGUID("player") or "" end

-- Your name on posts: your full Forever name, or "" when sharing is Anonymous.
local function MyAuthor()
    if SK.db.sharing == "anon" then return "" end
    return (SK.PlayerFullName and SK.PlayerFullName()) or UnitName("player") or ""
end

-- The highest scroll tier you can read: 1, 15, 50 or 175.
local function MyTier()
    local skill = SK.GetComprehension and SK.GetComprehension()
    if not (skill and skill.known) then return 0 end
    local best = 0
    for _, tier in ipairs(SK.TIERS or {}) do
        if (skill.effective or 0) >= tier then best = tier end
    end
    return best
end

------------------------------------------------------------------------
-- Checking a post
------------------------------------------------------------------------

local function Clean(text, max)
    text = tostring(text or ""):gsub("[%c]", " "):gsub("|", "/"):gsub("^%s+", ""):gsub("%s+$", "")
    if max and #text > max then
        text = text:sub(1, max)
        -- Don't leave half a multi-byte letter at the end.
        text = text:gsub("[\192-\255][\128-\191]*$", "")
    end
    return text
end

-- Posts from one author in the 24 hours around this one: top-level, replies.
local function AuthorCounts(guid, at, skipID)
    local posts, replies = 0, 0
    for id, p in pairs(Board().posts) do
        if id ~= skipID and p.guid == guid and math.abs((p.at or 0) - at) < 86400 then
            if p.parent == "" then posts = posts + 1 else replies = replies + 1 end
        end
    end
    return posts, replies
end

-- A post as we'd keep it, or nil and why not.
local function Valid(p)
    if type(p.id) ~= "string" or not p.id:match("^%x+$") or #p.id > 12 then return nil, "id" end
    local cat = BY_KEY[p.cat]
    if not cat then return nil, "category" end
    local now = Now()
    if not p.at or p.at < now - KEEP_SECONDS or p.at > now + 600 then return nil, "date" end
    if p.body == "" then return nil, "empty" end
    if p.parent == "" and p.title == "" then return nil, "title" end
    if #p.title > TITLE_MAX then return nil, "title" end
    if type(p.guid) ~= "string" or p.guid == "" then return nil, "author" end
    local b = Board()
    if b.removed[p.id] or (p.parent ~= "" and b.removed[p.parent]) then return nil, "removed" end
    local ban = b.bans[p.guid]
    if ban and (ban.untilAt or 0) > now then return nil, "banned" end
    -- The other faction (known): never kept.
    local theirs, myFaction = FactionOf(p), MyFaction()
    if theirs and myFaction and theirs ~= myFaction then return nil, "faction" end
    local mine = SK.ServerKind and SK.ServerKind()
    -- Trade, doorway and odds posts: only from your own ruleset (and one
    -- that doesn't say its ruleset doesn't count).
    if cat.mine and (p.ruleset == "" or (mine and p.ruleset ~= mine)) then return nil, "ruleset" end
    local posts, replies = AuthorCounts(p.guid, p.at, p.id)
    if p.parent == "" and posts >= POSTS_PER_DAY then return nil, "limit" end
    if p.parent ~= "" and replies >= REPLIES_PER_DAY then return nil, "limit" end
    return p
end

local function Fields(p)
    local cat = BY_KEY[p.cat]
    return p.id, p.parent, cat and cat.code or "g", p.at, p.ruleset, p.tier, p.guid, p.author, p.title, p.body, p.rev or 0,
        p.faction or ""
end

local function FromFields(f)
    local cat = BY_CODE[f[3] or ""]
    return {
        id = f[1] or "", parent = f[2] or "", cat = cat and cat.key or "", at = tonumber(f[4]),
        ruleset = Clean(f[5], 12), tier = tonumber(f[6]) or 0, guid = Clean(f[7], 40),
        author = Clean(f[8], 48), title = Clean(f[9], TITLE_MAX), body = Clean(f[10], MESSAGE_MAX),
        rev = math.max(0, math.min(99, tonumber(f[11]) or 0)),
        faction = (f[12] == "H" or f[12] == "A") and f[12] or nil,
    }
end

-- Keep a post: false if we have it already (the first version wins).
local function Keep(p)
    local posts = Board().posts
    if posts[p.id] then return false end
    posts[p.id] = p
    return true
end

-- Old posts go; so do replies whose post is gone.
local function Tidy()
    local posts, cutoff = Board().posts, Now() - KEEP_SECONDS
    for id, p in pairs(posts) do
        if type(p) ~= "table" or (p.at or 0) < cutoff then posts[id] = nil end
    end
    for id, p in pairs(posts) do
        if p.parent ~= "" and not posts[p.parent] then posts[id] = nil end
    end
    local b, now = Board(), Now()
    for id, at in pairs(b.removed) do if (tonumber(at) or 0) < cutoff then b.removed[id] = nil end end
    for guid, ban in pairs(b.bans) do
        if type(ban) ~= "table" or (ban.untilAt or 0) < now then b.bans[guid] = nil end
    end
    for guid, dev in pairs(b.devs) do
        if type(dev) ~= "table" or (dev.at or 0) < now - DEV_DAYS * 86400 then b.devs[guid] = nil end
    end
    for key, m in pairs(b.modLog) do
        local keep = type(m) == "table" and (m.at or 0) > now - DEV_DAYS * 86400
        if keep and m.action == "ban" then keep = (tonumber(m.b) or 0) > now end
        if keep and m.action == "ok" then keep = b.posts[m.a] ~= nil end
        if not keep then b.modLog[key] = nil end
    end
end

-- Is this character on the dev team (said with the team's key, lately)?
function SK.BoardIsDev(guid)
    local dev = guid and Board().devs[guid]
    return dev and (dev.at or 0) > Now() - DEV_DAYS * 86400 or false
end

------------------------------------------------------------------------
-- Who's who
------------------------------------------------------------------------

-- The player name to whisper about a post: who sent it to us, else a
-- Fellow Mage with the same character ID. Nil for anonymous posts.
function SK.BoardWhisperName(p)
    if not p or p.author == "" then return nil end
    if p.from then return p.from end
    for name, peer in pairs(SK.peers or {}) do
        if peer.guid == p.guid and not peer.demo then return name end
    end
    return p.author
end

function SK.BoardIsMine(p) return p and p.guid == MyGUID() end

-- Can you whisper them? Only on your own ruleset.
function SK.BoardCanWhisper(p)
    if not p or p.author == "" or SK.BoardIsMine(p) or p.demo then return false end
    local mine = SK.ServerKind and SK.ServerKind()
    return not (mine and p.ruleset ~= "" and p.ruleset ~= mine)
end

local function Ignored(p)
    if not (C_FriendList and C_FriendList.IsIgnored) then return false end
    local name = p.from or p.author
    return name ~= "" and SK.Try(C_FriendList.IsIgnored, name) and true or false
end

-- Is it shown to you? (Not hidden, not muted, not someone you ignore.)
function SK.BoardVisible(p)
    local b = Board()
    if b.hidden[p.id] or b.muted[p.guid] then return false end
    if not SameFaction(p) then return false end
    if p.cat == "notice" and p.parent == "" and not (p.verified or p.demo) then return false end
    local ban = b.bans[p.guid]
    if ban and (ban.untilAt or 0) > Now() then return false end
    if p.parent ~= "" and b.hidden[p.parent] then return false end
    if Ignored(p) then return false end
    local cat = BY_KEY[p.cat]
    if cat and not cat.mine and SK.db.boardRulesets == "mine" then
        local mine = SK.ServerKind and SK.ServerKind()
        if mine and p.ruleset ~= "" and p.ruleset ~= mine then return false end
    end
    return true
end

------------------------------------------------------------------------
-- Reading the board
------------------------------------------------------------------------

-- Made-up posts while /sk demo is on (never saved or sent).
local function DemoPosts()
    if not SK.demoCommunity then return {} end
    local now, mine = Now(), (SK.ServerKind and SK.ServerKind()) or "PvE"
    local function P(id, parent, cat, ago, author, tier, ruleset, title, body)
        return { id = id, parent = parent, cat = cat, at = now - ago, author = author, tier = tier, ruleset = ruleset,
                 guid = "demo-" .. author, title = title, body = body, demo = true,
                 team = (cat == "notice") or nil }
    end
    return {
        P("d1", "", "notice", 7200, "Archmage Naage", 175, mine, "Scrollkeeper has a board now!", "Post what you're after, offer spares, or say where you're opening a Liminal doorway. Posts last 7 days."),
        P("d2", "", "doors", 2400, "Kaelith Dawnmoor", 175, mine, "Liminal open in Dalaran at 8", "Opening a doorway by the fountain at 8 server time. Whisper me for an invite."),
        P("d3", "d2", "doors", 1200, "Morwen Ashby", 50, mine, "", "I'll be there!"),
        P("d4", "d2", "doors", 300, "Pip Underbough", 15, mine, "", "Saving a spot for my alt too."),
        P("d5", "", "wanted", 10800, "Thessaly Vane", 175, mine, "LF Odd Melon", "Will trade a Khadgar's Unlocking for one."),
        P("d6", "", "spare", 172800, "Morwen Ashby", 50, mine, "3 Scrolls of Frog Familiar, free", "Mail me and they're yours."),
        P("d7", "", "general", 86400, "Lofi Frostbeats", 175, "RP-PvP", "Tier 175 odds look better at night?", "Anyone else seeing this, or just luck?"),
    }
end

-- Every post and reply you can see: { list of posts, newest first }, and
-- replies by post id (oldest first). cat: a category key or nil for all.
function SK.BoardPosts(cat, search)
    Tidy()
    local all = {}
    for _, p in pairs(Board().posts) do all[#all + 1] = p end
    for _, p in ipairs(DemoPosts()) do all[#all + 1] = p end
    local posts, replies = {}, {}
    for _, p in ipairs(all) do
        if SK.BoardVisible(p) then
            if p.parent == "" then
                local inCat = not cat or p.cat == cat or (cat == "mine" and SK.BoardIsMine(p))
                if inCat and search then
                    local text = (p.title .. " " .. p.body .. " " .. p.author):lower()
                    inCat = text:find(search, 1, true) ~= nil
                end
                if inCat then posts[#posts + 1] = p end
            else
                replies[p.parent] = replies[p.parent] or {}
                table.insert(replies[p.parent], p)
            end
        end
    end
    -- Notices first, then newest first.
    table.sort(posts, function(a, b)
        local an, bn = a.cat == "notice", b.cat == "notice"
        if an ~= bn then return an end
        return a.at > b.at
    end)
    for _, list in pairs(replies) do table.sort(list, function(a, b) return a.at < b.at end) end
    return posts, replies
end

-- How many posts in each category (visible ones, not replies).
function SK.BoardCounts()
    local counts, total = {}, 0
    for _, p in ipairs((SK.BoardPosts())) do
        counts[p.cat] = (counts[p.cat] or 0) + 1
        total = total + 1
    end
    return counts, total
end

-- New since you last opened the board (not yours).
function SK.BoardUnread()
    local b, n = Board(), 0
    for _, p in pairs(b.posts) do
        if (p.at or 0) > b.lastRead and not SK.BoardIsMine(p) and SK.BoardVisible(p) then n = n + 1 end
    end
    return n
end

function SK.BoardMarkRead()
    Board().lastRead = Now()
    SK.Send("BOARD_CHANGED")
end

------------------------------------------------------------------------
-- Posting
------------------------------------------------------------------------

-- What's left for the text of a post or reply, in bytes.
function SK.BoardRoom(title)
    local p = { id = "ffffffff", parent = title and "" or "ffffffff", cat = "general", at = Now(),
        ruleset = (SK.ServerKind and SK.ServerKind()) or "", tier = MyTier(), guid = MyGUID(),
        author = MyAuthor(), title = title or "", body = "" }
    local text = "BP|" .. table.concat({ tostring(p.id), p.parent, "g", tostring(p.at), p.ruleset, tostring(p.tier),
        p.guid, p.author, p.title, "", "99", "H" }, "|")
    return MESSAGE_MAX - #text
end

-- What you can post in: every category but Notices (dev team only).
function SK.BoardCanPostIn(key)
    local cat = BY_KEY[key]
    if not cat then return false end
    if cat.team then return IAmTeam() and true or false end
    return true
end

-- Post (parent nil) or reply. Returns the post, or nil and a reason in words.
function SK.BoardPost(cat, title, body, parent)
    if not SK.BoardOn() then return nil, L["turn on Sharing and the board in /sk options first."] end
    local p = {
        id = ("%06x%02x"):format(Now() % 0x1000000, math.random(0, 255)),
        parent = parent or "", cat = cat, at = Now(),
        ruleset = (SK.ServerKind and SK.ServerKind()) or "", tier = MyTier(), guid = MyGUID(),
        author = MyAuthor(), title = parent and "" or Clean(title, TITLE_MAX), faction = MyFaction(),
    }
    local room
    if parent then room = SK.BoardRoom(nil) else room = SK.BoardRoom(p.title) end
    p.body = Clean(body, math.max(0, room))
    if parent then
        local top = Board().posts[parent]
        if not top then return nil, L["that post is gone."] end
        p.cat = top.cat
    end
    if not SK.BoardCanPostIn(p.cat) and not parent then return nil, L["only the dev team can post notices."] end
    local ok, why = Valid(p)
    if not ok then
        if why == "limit" then
            return nil, parent and L["that's 30 replies today: try again tomorrow."] or L["that's 3 posts today: try again tomorrow."]
        elseif why == "title" then
            return nil, L["give your post a title."]
        elseif why == "empty" then
            return nil, L["write something first."]
        end
        return nil, L["that post couldn't be made (%s)."]:format(why)
    end
    p.from = nil
    if IAmTeam() then p.verified = true end
    Keep(p)
    Net.Send("BP", Fields(p))
    if p.cat == "notice" and p.parent == "" and IAmTeam() then SK.BoardMod("ok", p.id) end
    if SK.Track then SK.Track(parent and "board.reply" or "board.post." .. p.cat) end
    SK.Send("BOARD_CHANGED")
    return p
end

-- Take down your own post or reply (and a post's replies, for you).
function SK.BoardDelete(id)
    local posts = Board().posts
    local p = posts[id]
    if not (p and SK.BoardIsMine(p)) then return false end
    posts[id] = nil
    Tidy()
    Net.Send("BD", id)
    SK.Send("BOARD_CHANGED")
    return true
end

-- Edit your own post (title and text) or reply (text). Returns true, or nil and why.
function SK.BoardEdit(id, title, body)
    local p = Board().posts[id]
    if not (p and SK.BoardIsMine(p)) then return nil, L["you can only edit your own posts."] end
    if (p.rev or 0) >= 99 then return nil, L["that post can't be edited any more."] end
    local newTitle = p.parent == "" and Clean(title, TITLE_MAX) or ""
    if p.parent == "" and newTitle == "" then return nil, L["give your post a title."] end
    local room = p.parent == "" and SK.BoardRoom(newTitle) or SK.BoardRoom(nil)
    local newBody = Clean(body, math.max(0, room))
    if newBody == "" then return nil, L["write something first."] end
    p.title, p.body, p.rev, p.edited = newTitle, newBody, (p.rev or 0) + 1, Now()
    Net.Send("BE", p.id, p.rev, p.title, p.body)
    SK.Send("BOARD_CHANGED")
    return p
end

Net.Handle("BE", function(sender, f)
    local p = Board().posts[f[1] or ""]
    local peer = SK.peers and SK.peers[sender]
    local rev = tonumber(f[2]) or 0
    -- Only straight from the author's own character, and only newer.
    if not (p and peer and peer.guid and peer.guid == p.guid and rev > (p.rev or 0) and rev <= 99) then return end
    local title = p.parent == "" and Clean(f[3], TITLE_MAX) or ""
    local body = Clean(f[4], MESSAGE_MAX)
    if body == "" or (p.parent == "" and title == "") then return end
    p.title, p.body, p.rev, p.edited = title, body, rev, Now()
    SK.Send("BOARD_CHANGED")
end)

function SK.BoardHide(id) Board().hidden[id] = true; SK.Send("BOARD_CHANGED") end
function SK.BoardMute(guid) if guid then Board().muted[guid] = true; SK.Send("BOARD_CHANGED") end end
function SK.BoardUnmuteAll() Board().muted = {}; Board().hidden = {}; SK.Send("BOARD_CHANGED") end
function SK.BoardMutedCount()
    local n = 0
    for _ in pairs(Board().muted) do n = n + 1 end
    return n
end

------------------------------------------------------------------------
-- Messages
------------------------------------------------------------------------

local told = false
Net.Handle("BP", function(sender, f)
    if not SK.BoardOn() then return end
    local p = Valid(FromFields(f))
    if not p then return end
    -- Straight from the author (their character ID matches who sent it):
    -- remember the name to whisper.
    local peer = SK.peers and SK.peers[sender]
    if peer and peer.guid == p.guid then p.from = sender end
    -- A newer edit, straight from its author: take it.
    local have = Board().posts[p.id]
    if have and p.from and have.guid == p.guid and (p.rev or 0) > (have.rev or 0) then
        have.title, have.body, have.rev, have.edited = p.title, p.body, p.rev, Now()
        SK.Send("BOARD_CHANGED")
        return
    end
    -- A notice the team already signed for (the OK came first).
    if p.cat == "notice" and Board().modLog["ok:" .. p.id] then p.verified = true end
    if Keep(p) then
        SK.Send("BOARD_CHANGED")
        -- Once a session, say there's something new (a setting).
        if not told and SK.db.boardNotify ~= false and p.parent == "" and SK.BoardVisible(p) then
            told = true
            C_Timer.After(10, function()
                local n = SK.BoardUnread()
                if n > 0 then SK.Print(L["Fellow Mages board: %d new |4post:posts;. /sk board"]:format(n)) end
            end)
        end
    end
end)

Net.Handle("BD", function(sender, f)
    local posts = Board().posts
    local p = posts[f[1] or ""]
    local peer = SK.peers and SK.peers[sender]
    -- Only from the author's own character.
    if p and peer and peer.guid and peer.guid == p.guid then
        posts[p.id] = nil
        Tidy()
        SK.Send("BOARD_CHANGED")
    end
end)

------------------------------------------------------------------------
-- Moderation (signed by the dev team; nothing else counts)
------------------------------------------------------------------------

-- What a signature covers: the action, its targets and when.
local function Payload(action, a, b, c, at)
    return table.concat({ "SK1", action or "", a or "", b or "", c or "", tostring(at or "") }, "|")
end

-- One key per thing a message is about, so an older message about the
-- same thing (an old "unban" sent again) can't undo a newer one.
local function ModKey(action, a)
    if action == "ban" or action == "unban" then return "user:" .. tostring(a) end
    return action .. ":" .. tostring(a)
end

local function ApplyMod(action, a, b, c)
    local board = Board()
    if action == "remove" and type(a) == "string" and a ~= "" then
        board.removed[a] = Now()
        board.posts[a] = nil
        Tidy()
    elseif action == "ban" and type(a) == "string" and a ~= "" then
        local untilAt = tonumber(b) or 0
        if untilAt <= Now() then return false end
        board.bans[a] = { untilAt = untilAt, name = Clean(c, 48) }
        for id, p in pairs(board.posts) do if p.guid == a then board.posts[id] = nil end end
        Tidy()
    elseif action == "unban" and type(a) == "string" then
        board.bans[a] = nil
    elseif action == "ok" and type(a) == "string" then
        local p = board.posts[a]
        if p and p.cat == "notice" then p.verified = true end
    elseif action == "dev" and type(a) == "string" and a:match("^Player%-") then
        board.devs[a] = { name = Clean(c, 48), at = Now() }
    else
        return false
    end
    SK.Send("BOARD_CHANGED")
    return true
end

-- Signed messages wait their turn: checking one takes a moment, so
-- they're checked one at a time, and each signature only once.
-- SK.VerifySigned(text, signatureBase64, ok): calls ok() if the team signed text.
local checked, waiting, checking = {}, {}, false
local function CheckNext()
    local item = table.remove(waiting, 1)
    if not item then checking = false return end
    -- (Remembered by signature AND text: a real signature on other text is no good.)
    local id = item.sig .. "\n" .. item.text
    if checked[id] == nil then
        local key = SK.Ed25519.FromBase64(SK.BOARD_MOD_KEY)
        local sig = SK.Ed25519.FromBase64(item.sig)
        checked[id] = (sig and key and SK.Ed25519.Verify(sig, item.text, key)) and true or false
    end
    if checked[id] then SK.Safely("signed", item.ok) end
    C_Timer.After(0.2, function() SK.Safely("board check", CheckNext) end)
end

function SK.VerifySigned(text, sig, ok)
    if type(sig) ~= "string" or sig == "" then return end
    local id = sig .. "\n" .. text
    if checked[id] ~= nil then
        if checked[id] then SK.Safely("signed", ok) end
        return
    end
    if #waiting >= 100 then return end
    waiting[#waiting + 1] = { text = text, sig = sig, ok = ok }
    if not checking then
        checking = true
        C_Timer.After(0, function() SK.Safely("board check", CheckNext) end)
    end
end

-- Sign with the team's key (only where SK.BoardSigner is set): base64, or nil.
function SK.SignForTeam(text)
    if not IAmTeam() then return nil end
    local signature = SK.BoardSigner(text)
    if type(signature) ~= "string" or #signature ~= 64 then return nil end
    local b64 = SK.Ed25519.ToBase64(signature)
    checked[b64 .. "\n" .. text] = true
    return b64
end

local function Accept(m)
    local key = ModKey(m.action, m.a)
    local have = Board().modLog[key]
    if have and (have.at or 0) >= m.at then return end   -- we know something newer
    if ApplyMod(m.action, m.a, m.b, m.c) or m.action == "ok" then
        Board().modLog[key] = m
    end
end

local function Heard(m)
    local now = Now()
    if not (m.at and m.at > now - DEV_DAYS * 86400 and m.at < now + 600) then return end
    SK.VerifySigned(Payload(m.action, m.a, m.b, m.c, m.at), m.sig, function() Accept(m) end)
end

Net.Handle("BS", function(_, f)
    local m = { sig = Clean(f[1], 100), action = Clean(f[2], 8), a = Clean(f[3], 48), b = Clean(f[4], 16),
                c = Clean(f[5], 48), at = tonumber(f[6]) }
    if m.action ~= "" and m.sig ~= "" then Heard(m) end
end)

-- Sign it (needs SK.BoardSigner), do it here, tell everyone.
function SK.BoardMod(action, a, b, c)
    if not IAmTeam() then return false, L["only the dev team can moderate the board."] end
    a, b, c = Clean(a, 48), Clean(b, 16), Clean(c, 48)
    local at = Now()
    local sig = SK.SignForTeam(Payload(action, a, b, c, at))
    if not sig then return false, L["that didn't work."] end
    local m = { action = action, a = a, b = b, c = c, at = at, sig = sig }
    if not ApplyMod(action, a, b, c) and action ~= "ok" then return false, L["that didn't work."] end
    Board().modLog[ModKey(action, a)] = m
    Net.Send("BS", m.sig, m.action, m.a, m.b, m.c, m.at)
    return true
end

-- Every signed message still in force, to pass on to mages who were
-- offline (anyone can pass them on: they can't be changed).
function SK.BoardModList()
    Tidy()
    local list = {}
    for _, m in pairs(Board().modLog) do list[#list + 1] = m end
    return list
end

function SK.BoardModResend(m)
    Net.Send("BS", m.sig, m.action, m.a, m.b, m.c, m.at)
end

------------------------------------------------------------------------
-- Catching up
------------------------------------------------------------------------

-- Catching up: someone asks what's new since a time. One player on their
-- ruleset answers (whoever says BA first), by whisper, through the queue.
local answering = {}   -- requester -> true while we wait to answer
Net.Handle("BA", function(sender, f)
    local who = f[1]
    if who then answering[who] = nil end
end)

-- Someone on another ruleset: whispers can't reach them, so one mage per
-- ruleset sends that ruleset's shared posts (General, notices: not trade,
-- doorways or odds) on the channel instead. At most once a minute.
local channelAnsweredAt = 0
local function AnswerOtherRuleset(sender, since, mine)
    if GetTime() - channelAnsweredAt < 60 and channelAnsweredAt > 0 then return end
    local list = {}
    for _, p in pairs(Board().posts) do
        local cat = SK.BoardCategory(p.cat)
        if (p.at or 0) > since and p.ruleset == mine and not (cat and cat.mine) and SameFaction(p)
            and not (p.cat == "notice" and p.parent == "" and not p.verified) then
            list[#list + 1] = p
        end
    end
    if #list == 0 then return end
    local key = sender .. "@" .. mine
    answering[key] = true
    C_Timer.After(3 + math.random() * 9, function()
        if not answering[key] then return end   -- someone else on our ruleset is answering
        answering[key] = nil
        if GetTime() - channelAnsweredAt < 60 and channelAnsweredAt > 0 then return end
        channelAnsweredAt = GetTime()
        Net.Send("BA", key)
        table.sort(list, function(a, b) return a.at > b.at end)
        local batch = {}
        for i = 1, math.min(#list, CATCH_UP_MAX) do batch[i] = list[i] end
        table.sort(batch, function(a, b)
            if (a.parent == "") ~= (b.parent == "") then return a.parent == "" end
            return a.at < b.at
        end)
        for _, p in ipairs(batch) do Net.Send("BP", Fields(p)) end
    end)
end

local function OnAsk(sender, f)
    if not SK.BoardOn() then return end
    -- Only whisper someone known to be on our own ruleset, and not just
    -- found unreachable. Anyone else gets the channel answer.
    local mine = SK.ServerKind and SK.ServerKind()
    local theirs = SK.RulesetOf and SK.RulesetOf(sender)
    if not mine then return end
    if theirs ~= mine then
        AnswerOtherRuleset(sender, tonumber(f[1]) or 0, mine)
        return
    end
    if Net.CantReach and Net.CantReach(sender) then return end
    local since = tonumber(f[1]) or 0
    local list = {}
    for _, p in pairs(Board().posts) do
        if (p.at or 0) > since and SameFaction(p) and not (p.cat == "notice" and p.parent == "" and not p.verified) then
            list[#list + 1] = p
        end
    end
    if #list == 0 and not next(Board().modLog) then return end
    table.sort(list, function(a, b) return a.at > b.at end)
    answering[sender] = true
    C_Timer.After(2 + math.random() * 6, function()
        if not answering[sender] then return end   -- someone else is answering
        answering[sender] = nil
        Net.Send("BA", sender)
        -- Posts before their replies.
        local batch = {}
        for i = 1, math.min(#list, CATCH_UP_MAX) do batch[i] = list[i] end
        table.sort(batch, function(a, b)
            if (a.parent == "") ~= (b.parent == "") then return a.parent == "" end
            return a.at < b.at
        end)
        -- Signed moderation first (take-downs, bans): anyone can pass those
        -- on, since nobody can change them.
        for _, m in pairs(Board().modLog) do Net.SendTo(sender, "BS", m.sig, m.action, m.a, m.b, m.c, m.at) end
        if SK.PassOnThemes then SK.PassOnThemes(sender) end
        if SK.PassOnNotes then SK.PassOnNotes(sender) end
        for _, p in ipairs(batch) do Net.SendTo(sender, "BP", Fields(p)) end
    end)
end

Net.Handle("BQ", OnAsk)
Net.Handle("BR", OnAsk)

-- Ask what's new: at login, and when you open the board (at most every 5 min).
-- now: the Refresh button (at most every 20 seconds).
local askedAt = 0
function SK.BoardCatchUp(now)
    if not SK.BoardOn() or GetTime() - askedAt < (now and 20 or 300) and askedAt > 0 then return end
    askedAt = GetTime()
    local newest = Now() - KEEP_SECONDS
    for _, p in pairs(Board().posts) do
        if (p.at or 0) > newest and not SK.BoardIsMine(p) then newest = p.at end
    end
    Net.Send("BR", newest)
end

-- Other addons can reach Scrollkeeper through this.
_G.ScrollkeeperNS = SK

SK.Listen("NET_READY", function()
    Tidy()
    C_Timer.After(20, function() SK.Safely("board", SK.BoardCatchUp) end)
end)
