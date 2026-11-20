--[[
    Lifeline - Update notice and "What's new" window

    Update notice: Lifeline quietly tells other Lifeline users in your party,
    raid and guild which version it is (hidden addon messages, never in chat).
    If someone has a newer version you get one line in chat per session.
    Addons can't go online, so this is how word of an update gets around.

    What's new: the first time you log in on a new version, a small window
    lists what changed since the version you had before. /ll news shows it again.
]]

local ADDON, L = ...
local C = L.C

local PREFIX = "Lifeline"

------------------------------------------------------------------------
-- Versions
------------------------------------------------------------------------
local function Parse(v)
    local t = {}
    for n in tostring(v or ""):gmatch("%d+") do t[#t + 1] = tonumber(n) end
    return t
end

-- true when version a is newer than version b
function L.VersionNewer(a, b)
    local x, y = Parse(a), Parse(b)
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or 0, y[i] or 0
        if p ~= q then return p > q end
    end
    return false
end

------------------------------------------------------------------------
-- Update notice
------------------------------------------------------------------------
local announced          -- newest version we've told the player about this session
local lastSent = {}      -- channel -> time
local repliedTo = {}     -- player -> time (so old versions learn about ours)

local function CanSend()
    return C_ChatInfo and C_ChatInfo.SendAddonMessage and not InCombatLockdown()
end

local function Send(channel, target)
    if not CanSend() then return end
    local key = channel .. (target or "")
    if lastSent[key] and GetTime() - lastSent[key] < 60 then return end
    lastSent[key] = GetTime()
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, "V:" .. L.version, channel, target)
end

local function Broadcast()
    if not L.db or not L.db.updateNotice then return end
    if IsInGuild and IsInGuild() then Send("GUILD") end
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        Send("INSTANCE_CHAT")
    elseif IsInRaid() then
        Send("RAID")
    elseif IsInGroup() then
        Send("PARTY")
    end
end

local function OnVersion(ver, sender)
    if not L.db or not L.db.updateNotice then return end
    if L.VersionNewer(ver, L.version) then
        LifelineDB.newestSeen = (not LifelineDB.newestSeen or L.VersionNewer(ver, LifelineDB.newestSeen)) and ver or LifelineDB.newestSeen
        if not announced or L.VersionNewer(ver, announced) then
            announced = ver
            L:Print(("|cffffd100Lifeline %s is available|r (you have %s). Update through CurseForge."):format(ver, L.version))
        end
    elseif L.VersionNewer(L.version, ver) and sender then
        -- they're behind: tell them ours (at most every 10 minutes per player)
        if not repliedTo[sender] or GetTime() - repliedTo[sender] > 600 then
            repliedTo[sender] = GetTime()
            Send("WHISPER", sender)
        end
    end
end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
end

L:On("CHAT_MSG_ADDON", function(_, prefix, msg, channel, sender)
    prefix, msg, sender = L.Readable(prefix), L.Readable(msg), L.Readable(sender)
    if prefix ~= PREFIX or type(msg) ~= "string" then return end
    local ver = msg:match("^V:([%d%.]+)$")
    if not ver then return end
    -- ignore our own messages
    local me = UnitName("player")
    if sender and me and (sender == me or sender:match("^([^%-]+)") == me) then return end
    OnVersion(ver, sender)
end)

L:On("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(15, Broadcast)
    -- someone told us about a newer version last time and we still haven't updated
    C_Timer.After(20, function()
        local seen = LifelineDB and LifelineDB.newestSeen
        if seen and L.db and L.db.updateNotice and L.VersionNewer(seen, L.version) and not announced then
            announced = seen
            L:Print(("|cffffd100Lifeline %s is available|r (you have %s). Update through CurseForge."):format(seen, L.version))
        end
    end)
end)
L:On("GROUP_ROSTER_UPDATE", function() L:Debounce("versionBroadcast", 5, Broadcast) end)

------------------------------------------------------------------------
-- What's new window
------------------------------------------------------------------------
local win

local function Format(line)
    -- **bold** -> white
    return (line:gsub("%*%*(.-)%*%*", "|cffffffff%1|r"))
end

local function BuildText(since)
    local out = {}
    for _, e in ipairs(L.CHANGES or {}) do
        if not since or L.VersionNewer(e.version, since) then
            out[#out + 1] = ("|cff4cd98cv%s|r  |cffffffff%s|r"):format(e.version, e.title or "")
            for _, ln in ipairs(e.lines) do
                local kind, text = ln[1], Format(ln[2])
                if kind == "h" then out[#out + 1] = "\n|cffffd100" .. text .. "|r"
                elseif kind == "b" then out[#out + 1] = "  -  " .. text
                elseif kind == "s" then out[#out + 1] = "        -  " .. text
                else out[#out + 1] = text end
            end
            out[#out + 1] = " "
        end
    end
    return table.concat(out, "\n")
end

local function CreateNewsWindow()
    win = CreateFrame("Frame", "LifelineWhatsNew", UIParent)
    win:SetSize(520, 460)
    win:SetPoint("CENTER", 0, 40)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    L.Skin(win, C.bg, C.border)
    tinsert(UISpecialFrames, "LifelineWhatsNew")

    local bar = win:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", 1, -1) bar:SetPoint("TOPRIGHT", -1, -1) bar:SetHeight(2)
    L.SetC(bar, C.accent)
    local logo = win:CreateTexture(nil, "ARTWORK")
    logo:SetSize(24, 24)
    logo:SetPoint("TOPLEFT", 14, -12)
    logo:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Media\\icon")
    local title = L.Text(win, 15)
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    title:SetText("What's new in Lifeline")
    win.sub = L.Text(win, 11, C.muted)
    win.sub:SetPoint("LEFT", title, "RIGHT", 10, -1)

    local scroll = L.ScrollFrame(win)
    scroll:SetPoint("TOPLEFT", 16, -48)
    scroll:SetPoint("BOTTOMRIGHT", -28, 52)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(460, 10)
    scroll:SetScrollChild(content)
    win.text = L.Text(content, 12, C.text)
    win.text:SetPoint("TOPLEFT")
    win.text:SetWidth(460)
    win.text:SetWordWrap(true)
    win.text:SetSpacing(3)
    win.content, win.scroll = content, scroll

    local show = L.Check(win, "Show this after updates", function() return L.db.whatsNew end,
        function(v) L.db.whatsNew = v end)
    show:SetPoint("BOTTOMLEFT", 16, 16)
    show:SetWidth(220)
    win.check = show
    local close = L.Button(win, "Close", 100, 26, function() win:Hide() end, true)
    close:SetPoint("BOTTOMRIGHT", -16, 14)
end

function L:WhatsNew_Show(since)
    if not win then CreateNewsWindow() end
    win.sub:SetText(since and ("since v" .. since) or ("v" .. L.version))
    win.text:SetText(BuildText(since))
    win.content:SetHeight(math.max(10, win.text:GetStringHeight() + 10))
    win.scroll.ScrollToTop()
    if win.check.Refresh then win.check.Refresh() end
    win:Show()
end

L:On("PLAYER_LOGIN", function()
    local last = LifelineDB.lastSeenVersion
    LifelineDB.lastSeenVersion = L.version
    -- a fresh install has nothing to compare against: no window
    if last and L.VersionNewer(L.version, last) then
        if LifelineDB.newestSeen and not L.VersionNewer(LifelineDB.newestSeen, L.version) then
            LifelineDB.newestSeen = nil   -- we've caught up
        end
        if L.db and L.db.whatsNew then
            C_Timer.After(3, function() L:WhatsNew_Show(last) end)
        end
    end
end)
