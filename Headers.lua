--[[
    Lifeline - Group headers, layout, mover and preview
]]

local _, L = ...
local C = L.C

local anchor, partyHeader, raidCombined
local raidGroups = {}
L.headers = {}
L.raidGroups = raidGroups

------------------------------------------------------------------------
-- Growth helpers
------------------------------------------------------------------------
-- returns: unit point, xOff, yOff, columnAnchorPoint, header corner, anchor corner
local function GrowthInfo(orientation, growth, spacing)
    local down  = growth:find("^DOWN") ~= nil
    local right = growth:find("RIGHT$") ~= nil
    local vCorner = down and "TOP" or "BOTTOM"
    local hCorner = right and "LEFT" or "RIGHT"
    local headerCorner = vCorner .. hCorner
    local anchorCorner = (down and "BOTTOM" or "TOP") .. hCorner
    if orientation == "VERTICAL" then
        return vCorner, 0, down and -spacing or spacing, hCorner, headerCorner, anchorCorner
    else
        return hCorner, right and spacing or -spacing, 0, vCorner, headerCorner, anchorCorner
    end
end
L.GrowthInfo = GrowthInfo

------------------------------------------------------------------------
-- Anchor / mover
------------------------------------------------------------------------
local function CreateAnchor()
    anchor = CreateFrame("Frame", "LifelineAnchor", UIParent)
    anchor:SetSize(180, 18)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    anchor:EnableMouse(false)
    anchor:RegisterForDrag("LeftButton")

    local handle = CreateFrame("Frame", nil, anchor)
    handle:SetAllPoints()
    L.Skin(handle, C.accentDim, C.accent)
    local t = L.Text(handle, 11, C.accent)
    t:SetPoint("CENTER")
    t:SetJustifyH("CENTER")
    t:SetText("Lifeline  -  drag to move")
    anchor.handle = handle

    anchor:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self:StartMoving()
    end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint(1)
        L.db.position.point, L.db.position.x, L.db.position.y = point, x, y
    end)
    anchor:SetScript("OnMouseUp", function(_, btn)
        if btn == "RightButton" and L.Options_Toggle then L:Options_Toggle() end
    end)
    L.anchor = anchor
end

function L:Anchor_Update()
    if not anchor then return end
    L:RunAfterCombat("anchor", function()
        local p = L.db.position
        anchor:ClearAllPoints()
        anchor:SetPoint(p.point or "TOPLEFT", UIParent, p.point or "TOPLEFT", p.x or 0, p.y or 0)
        anchor:SetScale(L.db.scale)
        local unlocked = not L.db.locked
        anchor.handle:SetShown(unlocked)
        anchor:EnableMouse(unlocked)
        if unlocked and L.Preview_AutoShow then L:Preview_AutoShow() end
        if not unlocked and L.Preview_AutoHide then L:Preview_AutoHide() end
    end)
end

------------------------------------------------------------------------
-- Secure headers
------------------------------------------------------------------------
local INIT_SNIPPET = [[
    local header = self:GetParent()
    self:SetWidth(%d)
    self:SetHeight(%d)
    if self.RegisterForClicks then self:RegisterForClicks("AnyUp") end
    %s
    header:CallMethod("initButton", self:GetName())
]]

local function InitButtonMethod(header, name)
    local b = _G[name]
    if not b then return end
    L:Button_Init(b)
end

local function NewHeader(name, isRaid)
    local h = CreateFrame("Frame", name, anchor, "SecureGroupHeaderTemplate")
    h.initButton = InitButtonMethod
    h.isRaid = isRaid
    h:SetAttribute("template", "LifelineUnitButtonTemplate")
    h.llWidth, h.llHeight = 80, 40
    h:SetAttribute("initialConfigFunction", L:Headers_InitSnippet(h))
    table.insert(L.headers, h)
    return h
end

-- sizes are baked into the snippet as plain numbers (restricted code can't
-- reliably read custom attributes back off the header)
function L:Headers_InitSnippet(h)
    local w = math.floor(((h and h.llWidth) or 80) + 0.5)
    local ht = math.floor(((h and h.llHeight) or 40) + 0.5)
    local extra = L.ClickCast_Snippet and L:ClickCast_Snippet() or ""
    return INIT_SNIPPET:format(w, ht, extra)
end

function L:Headers_Create()
    if partyHeader then return end
    CreateAnchor()

    partyHeader = NewHeader("LifelinePartyHeader", false)
    partyHeader:SetAttribute("showParty", true)

    raidCombined = NewHeader("LifelineRaidHeader", true)
    raidCombined:SetAttribute("showRaid", true)
    raidCombined:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")

    for i = 1, 8 do
        local h = NewHeader("LifelineRaidGroup" .. i, true)
        h:SetAttribute("showRaid", true)
        h:SetAttribute("groupFilter", tostring(i))
        raidGroups[i] = h
    end
    L:Headers_StartVerify()

    L:Headers_ApplyLayout()
    L:Anchor_Update()
end

local function SetCommon(h, cfg, sortBy)
    -- (also used by Pets.lua through L.Headers_SetCommon)
    local point, xOff, yOff, colAnchor = GrowthInfo(cfg.orientation, cfg.growth or "DOWN_RIGHT", cfg.spacing)
    -- remember what this header should look like (Headers_Verify checks it).
    -- 1.1.8.1: "point" is never cleared any more - a header briefly left
    -- without it could keep a wrong layout. Every attribute change below
    -- makes the header re-anchor its frames anyway.
    h.llPoint, h.llCol = point, colAnchor
    h:SetAttribute("point", point)
    h.llWidth, h.llHeight = cfg.width, cfg.height
    h:SetAttribute("xOffset", xOff)
    h:SetAttribute("yOffset", yOff)
    h:SetAttribute("columnSpacing", cfg.groupSpacing or cfg.spacing)
    h:SetAttribute("columnAnchorPoint", colAnchor)

    if sortBy == "ROLE" then
        h:SetAttribute("groupBy", "ASSIGNEDROLE")
        h:SetAttribute("groupingOrder", "TANK,HEALER,DAMAGER,NONE")
        h:SetAttribute("sortMethod", "INDEX")
    elseif sortBy == "NAME" then
        h:SetAttribute("groupBy", nil)
        h:SetAttribute("groupingOrder", nil)
        h:SetAttribute("sortMethod", "NAME")
    else
        h:SetAttribute("groupBy", nil)
        h:SetAttribute("groupingOrder", nil)
        h:SetAttribute("sortMethod", "INDEX")
    end

    h:SetAttribute("initialConfigFunction", L:Headers_InitSnippet(h))

    -- resize already-spawned children before the header lays them out
    local i = 1
    local child = h:GetAttribute("child1")
    while child do
        child:SetSize(cfg.width, cfg.height)
        i = i + 1
        child = h:GetAttribute("child" .. i)
    end
    h:SetAttribute("point", point)
end

------------------------------------------------------------------------
-- Layout self-repair (1.1.8.1)
-- Some players saw their party frames turn into a staircase (each frame
-- below and to the right of the last) a minute after logging in. That only
-- happens when a header is told to stack from a corner. After group
-- changes, after combat and every 15 seconds out of combat, Lifeline checks
-- each visible header and puts the layout back if it changed. If anything
-- else changes a header's "point", where the change came from is kept for
-- /ll debug.
------------------------------------------------------------------------
local OPPOSITE = { TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT" }
L.layoutRepair = { count = 0 }

local function Str(v) return type(v) == "string" and v or nil end

-- is this child anchored the way the header's settings say?
local function ChildOK(h, child)
    local ok, p, rel, rp = pcall(child.GetPoint, child, 1)
    p, rp = ok and Str(p), ok and Str(rp)
    if not p or not rp or rel == h then return true end   -- unreadable, or the first one in the header
    if p == h.llPoint and rp == OPPOSITE[h.llPoint] then return true end
    if h.llCol and p == h.llCol and rp == OPPOSITE[h.llCol] then return true end   -- start of a new column
    return false, ("%s -> %s"):format(p, rp)
end

local function HeaderOK(h)
    if not h.llPoint or not h:IsVisible() then return true end
    local attr = h:GetAttribute("point")
    if attr ~= h.llPoint then return false, "point is " .. tostring(attr) .. ", should be " .. h.llPoint end
    for i = 2, 40 do
        local child = h:GetAttribute("child" .. i)
        if not child or not child:IsShown() then break end
        local good, how = ChildOK(h, child)
        if not good then return false, ("frame %d anchored %s"):format(i, how) end
    end
    return true
end

function L:Headers_Verify(reason)
    if not partyHeader or InCombatLockdown() then return end
    for _, h in ipairs(L.headers) do
        local good, why = HeaderOK(h)
        if not good then
            local r = L.layoutRepair
            r.count = r.count + 1
            r.last = ("%s %s: %s (found after %s)"):format(date("%H:%M:%S"), h:GetName() or "?", why, reason or "?")
            L:Headers_ApplyLayout()
            if L.Tanks_ApplyLayout then pcall(L.Tanks_ApplyLayout, L) end
            return
        end
    end
end

-- note who changes a header's "point" to something Lifeline didn't ask for
local function WatchHeader(h)
    h:HookScript("OnAttributeChanged", function(self, name, value)
        if name ~= "point" or value == nil or not self.llPoint or value == self.llPoint then return end
        local r = L.layoutRepair
        r.foreign = ("%s set to %s at %s"):format(self:GetName() or "?", tostring(value), date("%H:%M:%S"))
        r.stack = debugstack and debugstack(3, 4, 0) or nil
    end)
end

local verifyTicker
function L:Headers_StartVerify()
    for _, h in ipairs(L.headers) do WatchHeader(h) end
    L:On("GROUP_ROSTER_UPDATE", function()
        L:Debounce("headersVerify", 2, function() L:Headers_Verify("a group change") end)
    end)
    L:On("PLAYER_REGEN_ENABLED", function()
        C_Timer.After(1, function() L:Headers_Verify("combat") end)
    end)
    verifyTicker = verifyTicker or C_Timer.NewTicker(15, function() L:Headers_Verify("a routine check") end)
end

L.Headers_InitButtonMethod = InitButtonMethod
L.Headers_SetCommon = function(h, cfg, sortBy) SetCommon(h, cfg, sortBy) end

function L:Headers_ApplyLayout()
    if not partyHeader then return end
    if InCombatLockdown() then
        L:RunAfterCombat("layout", function() L:Headers_ApplyLayout() end)
        return
    end
    local db = L.db
    local party, raid = db.party, L:RaidCfg()
    local _, _, _, _, headerCorner, anchorCorner = GrowthInfo(party.orientation, party.growth or "DOWN_RIGHT", 0)

    -- party ---------------------------------------------------------
    SetCommon(partyHeader, party, db.sortBy)
    partyHeader:SetAttribute("showPlayer", db.showPlayerInParty)
    partyHeader:SetAttribute("showSolo", db.showSolo)
    partyHeader:SetAttribute("unitsPerColumn", 5)
    partyHeader:SetAttribute("maxColumns", 1)
    partyHeader:ClearAllPoints()
    partyHeader:SetPoint(headerCorner, anchor, anchorCorner, 0, 0)
    UnregisterAttributeDriver(partyHeader, "state-visibility")
    RegisterAttributeDriver(partyHeader, "state-visibility",
        db.showSolo and "[group:raid] hide; show" or "[group:raid] hide; [group:party] show; hide")

    -- raid ----------------------------------------------------------
    local byGroup = raid.groupBy == "GROUP"
    local _, _, _, _, rHeaderCorner, rAnchorCorner = GrowthInfo(raid.orientation, raid.growth or "DOWN_RIGHT", 0)
    local right = (raid.growth or "DOWN_RIGHT"):find("RIGHT$") ~= nil
    local down = (raid.growth or "DOWN_RIGHT"):find("^DOWN") ~= nil

    for i, h in ipairs(raidGroups) do
        UnregisterAttributeDriver(h, "state-visibility")
        if byGroup then
            SetCommon(h, raid, db.sortBy)
            h:SetAttribute("unitsPerColumn", 5)
            h:SetAttribute("maxColumns", 1)
            local step = i - 1
            local dx, dy = 0, 0
            if raid.orientation == "VERTICAL" then
                dx = step * (raid.width + raid.groupSpacing) * (right and 1 or -1)
            else
                dy = step * (raid.height + raid.groupSpacing) * (down and -1 or 1)
            end
            h:ClearAllPoints()
            h:SetPoint(rHeaderCorner, anchor, rAnchorCorner, dx, dy)
            RegisterAttributeDriver(h, "state-visibility", "[group:raid] show; hide")
        else
            h:Hide()
        end
    end

    UnregisterAttributeDriver(raidCombined, "state-visibility")
    if not byGroup then
        SetCommon(raidCombined, raid, raid.groupBy == "ROLE" and "ROLE" or (raid.groupBy == "CLASS" and "CLASS" or db.sortBy))
        if raid.groupBy == "CLASS" then
            raidCombined:SetAttribute("groupBy", "CLASS")
            raidCombined:SetAttribute("groupingOrder",
                "WARRIOR,PALADIN,DEATHKNIGHT,DRUID,PRIEST,SHAMAN,MONK,ROGUE,HUNTER,MAGE,WARLOCK,DEMONHUNTER,EVOKER")
        end
        raidCombined:SetAttribute("unitsPerColumn", raid.unitsPerColumn)
        raidCombined:SetAttribute("maxColumns", raid.maxColumns)
        raidCombined:ClearAllPoints()
        raidCombined:SetPoint(rHeaderCorner, anchor, rAnchorCorner, 0, 0)
        RegisterAttributeDriver(raidCombined, "state-visibility", "[group:raid] show; hide")
    else
        raidCombined:Hide()
    end

    anchor:SetScale(db.scale)
    if L.Pets_ApplyLayout then L:Pets_ApplyLayout() end
end

------------------------------------------------------------------------
-- Preview (non-secure fake frames, out of combat only)
------------------------------------------------------------------------
local preview, previewMode, previewAuto
local fakeButtons = {}

local FAKE_NAMES = { "Thrallgar", "Mireth", "Bolvar", "Selenna", "Grimbeard", "Kaelira", "Dornak", "Ysolde",
    "Varok", "Lunara", "Tessaly", "Brannoc", "Orrin", "Zhalia", "Fennick", "Morwen", "Rastak", "Elowen",
    "Jorvik", "Nyssa", "Hadrik", "Sariel", "Tobrin", "Velka", "Ulfar", "Ilyra", "Krogan", "Maelis",
    "Quillon", "Rheya", "Stoneh", "Taliah", "Ugrin", "Vashti", "Wexley", "Xandra", "Yorin", "Zephyra",
    "Aldric", "Brisa" }
local FAKE_CLASSES = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "PALADIN", "HUNTER", "WARLOCK", "SHAMAN" }
local DEBUFF_ICONS = { "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Interface\\Icons\\Spell_Fire_Immolation",
    "Interface\\Icons\\Spell_Shadow_CurseOfTounges", "Interface\\Icons\\Ability_Creature_Poison_02" }
local BUFF_ICONS = { "Interface\\Icons\\Spell_Nature_Rejuvenation", "Interface\\Icons\\Spell_Holy_Renew",
    "Interface\\Icons\\Spell_Holy_PowerWordShield" }

local function FakeData(i)
    local class = FAKE_CLASSES[(i * 7) % #FAKE_CLASSES + 1]
    local c = RAID_CLASS_COLORS[class]
    local hp = ({ 100, 82, 45, 100, 67, 23, 100, 91, 58, 100 })[(i - 1) % 10 + 1]
    local roles = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }
    local d = {
        index = i, class = class, name = FAKE_NAMES[i] or ("Player" .. i), r = c.r, g = c.g, b = c.b,
        hp = hp, heal = (hp < 90) and 12 or 0, absorb = (i % 5 == 3) and 15 or nil, role = roles[(i - 1) % 5 + 1],
        power = (class == "WARRIOR") and "RAGE" or ((class == "ROGUE") and "ENERGY" or "MANA"),
        pp = 40 + (i * 13) % 60,
        leader = (i == 1), target = (i == 3), aggro = (i == 1),
        dead = (i == 9), since = (i == 9) and 72 or nil, oor = (i == 7 or i == 14),
        mark = (i == 1) and 8 or ((i == 2) and 2 or nil),
    }
    if i % 4 == 3 then d.debuffs = { DEBUFF_ICONS[1], DEBUFF_ICONS[2] } end
    if i % 6 == 2 then d.dispel = (i % 12 == 2) and "Magic" or "Poison"; d.debuffs = { DEBUFF_ICONS[4] } end
    if i % 3 == 0 then d.buffs = { BUFF_ICONS[1], BUFF_ICONS[2] } end
    if i == 5 then d.buffs = { BUFF_ICONS[3] } end
    if i == 1 then d.raidRole = "MAINTANK" d.incoming = "Interface\\Icons\\Spell_Shadow_ShadowBolt" end
    if i == 2 or i == 12 then d.cast = { name = "Flash Heal", icon = "Interface\\Icons\\Spell_Holy_FlashHeal", pct = 0.6 } end
    if i == 11 then d.raidRole = "MAINASSIST" end
    if i == 6 then d.threat = 2 end
    if i == 4 or i == 17 then d.bigDebuff = "Interface\\Icons\\Spell_Shadow_UnholyStrength" end
    if i == 7 then d.pp = 12 end
    if i == 13 then d.afk = true d.since = 125 end
    return d
end

L.FakeData = FakeData

local function GetFake(i)
    local b = fakeButtons[i]
    if not b then
        b = L:CreateFakeButton(preview, FakeData(i))
        fakeButtons[i] = b
    end
    return b
end

function L:Preview_Refresh()
    if not preview or not preview:IsShown() then return end
    local db = L.db
    local isRaid = previewMode ~= "party"
    local count = ({ party = 5, raid10 = 10, raid25 = 25, raid40 = 40 })[previewMode] or 5
    local cfg = isRaid and L:RaidCfg(count) or db.party

    local growth = cfg.growth or "DOWN_RIGHT"
    local down = growth:find("^DOWN") ~= nil
    local right = growth:find("RIGHT$") ~= nil
    local _, _, _, _, headerCorner, anchorCorner = GrowthInfo(cfg.orientation, growth, 0)
    local perCol = isRaid and (cfg.groupBy == "GROUP" and 5 or cfg.unitsPerColumn) or 5
    local colGap = isRaid and cfg.groupSpacing or cfg.spacing
    local sx = right and 1 or -1
    local sy = down and -1 or 1

    preview:ClearAllPoints()
    preview:SetPoint(headerCorner, anchor, anchorCorner, 0, 0)
    preview:SetSize(1, 1)

    for i = 1, 40 do
        local b = fakeButtons[i]
        if i <= count then
            b = GetFake(i)
            b:SetSize(cfg.width, cfg.height)
            L:Button_ApplyStyle(b)
            local idx = i - 1
            local col, row = math.floor(idx / perCol), idx % perCol
            local x, y
            if cfg.orientation == "VERTICAL" then
                x = col * (cfg.width + colGap)
                y = row * (cfg.height + cfg.spacing)
            else
                x = row * (cfg.width + cfg.spacing)
                y = col * (cfg.height + colGap)
            end
            b:ClearAllPoints()
            b:SetPoint(headerCorner, preview, headerCorner, x * sx, y * sy)
            b:Show()
            L:Button_UpdateAll(b)
        elseif b then
            b:Hide()
        end
    end
end

-- While the preview is up, fade the real frames so they don't show through
-- underneath it (e.g. your own frame when "Show frames when solo" is on).
-- Alpha isn't a protected change, so this is safe even if combat starts.
local function SetRealFramesHidden(hidden)
    for _, h in ipairs(L.headers) do h:SetAlpha(hidden and 0 or 1) end
end

function L:Preview_Show(mode)
    if InCombatLockdown() then L:Print("Preview isn't available in combat.") return end
    if not preview then
        preview = CreateFrame("Frame", "LifelinePreview", anchor)
        preview:SetFrameStrata("MEDIUM")
        L.previewFrame = preview
    end
    previewMode = mode or "party"
    preview:Show()
    SetRealFramesHidden(true)
    L:Preview_Refresh()
end

function L:Preview_Hide()
    previewAuto = nil
    if preview then preview:Hide() end
    previewMode = nil
    SetRealFramesHidden(false)
end

function L:Preview_Toggle(mode)
    if preview and preview:IsShown() and (not mode or mode == previewMode) then
        L:Preview_Hide()
    else
        L:Preview_Show(mode or (IsInRaid() and "raid25" or "party"))
    end
end

function L:Preview_IsShown() return preview and preview:IsShown() and previewMode end

function L:Preview_AutoShow()
    if not IsInGroup() and not (preview and preview:IsShown()) then
        previewAuto = true
        L:Preview_Show("party")
    end
end
function L:Preview_AutoHide()
    if previewAuto then L:Preview_Hide() end
end

L:On("PLAYER_REGEN_DISABLED", function()
    -- combat: drop the preview and bring the real frames straight back
    if preview and preview:IsShown() then preview:Hide() end
    SetRealFramesHidden(false)
end)
