--[[
    Lifeline - Game-managed aura containers

    On WoW Forever the game hides aura details from addons during combat, so a
    Lua scan of a unit's buffs comes back empty and icons disappear. The client
    offers its own AuraContainer frames instead: we describe *what* to show
    (a filter string plus optional spell IDs) and *where*, and the game fills
    the icons itself - in or out of combat.

    Used for, on every real (non-sample) unit button:
      - "Your buffs" row      (Auras tab)          -> one flow-layout group
      - Debuff row            (Auras tab)          -> one flow-layout group
      - Active buff indicators (Buff Indicators tab) -> one fixed slot each
    Missing-buff reminders stay in Lua (they only show out of combat anyway).

    If the client doesn't offer AuraContainer, everything here switches off and
    the Lua code in UnitButton.lua / Indicators.lua handles auras as before.
]]

local _, L = ...

local TEMPLATE_CONTAINER = "LifelineAuraContainerTemplate"
local TEMPLATE_BUTTON = "LifelineAuraButtonTemplate"

------------------------------------------------------------------------
-- Is the AuraContainer frame type available on this client?
------------------------------------------------------------------------
local available
function L:AC_Available()
    if available ~= nil then return available end
    available = false
    local ok, f = pcall(CreateFrame, "AuraContainer", nil, UIParent, TEMPLATE_CONTAINER)
    if ok and f and f.AddAuraGroup and f.AddAuraSlot and f.SetUnit then
        available = true
        pcall(f.Hide, f)
    end
    return available
end

local function SortMethod() return AuraContainerSortMethod and AuraContainerSortMethod.Default end
local function SortDir() return AuraContainerSortDirection and AuraContainerSortDirection.Normal end
local FLOW = AnchorUtil and AnchorUtil.FlowDirection or {}
local AXIS = AnchorUtil and AnchorUtil.FlowLayoutAxis or {}

-- aura buttons can be "forbidden" to addon code in some contexts (e.g. combat)
local function Accessible(f)
    return f and (not f.CanBeAccessedInContext or f:CanBeAccessedInContext())
end

------------------------------------------------------------------------
-- Spell IDs for an indicator / exclusion (spell info is static, never secret)
------------------------------------------------------------------------
local function SpellID(spell)
    local id = tonumber(spell)
    if id then return id end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spell)
        if info and info.spellID then return info.spellID end
    end
    if C_Spell and C_Spell.GetSpellIDForSpellIdentifier then
        local ok, sid = pcall(C_Spell.GetSpellIDForSpellIdentifier, spell)
        if ok and sid then return sid end
    end
    return nil
end

-- every ID for a spell and its buff family (e.g. Fortitude + Prayer of Fortitude)
-- Every rank has its own spell ID, and a buff carries the ID of the rank
-- that was cast, so we collect every rank the game knows for each name in
-- the family (Inner Fire(Rank 1) ... (Rank 16)). Results are kept until your
-- spells change (training a new rank).
local idCache = {}
L:On("SPELLS_CHANGED", function() wipe(idCache) end)

local function AddRanks(ids, name)
    if not (C_Spell and C_Spell.GetSpellInfo) then return end
    for rank = 1, 16 do
        local info = C_Spell.GetSpellInfo(("%s(Rank %d)"):format(name, rank))
        local id = info and L.Readable(info.spellID)
        if id then ids[id] = true end
    end
end

function L:AC_SpellIDs(spell)
    local key = tostring(spell)
    local cached = idCache[key]
    if cached ~= nil then return cached or nil end
    local ids, any = {}, false
    local name = L:Ind_SpellName(spell)
    local direct = tonumber(spell)
    if direct then ids[direct] = true end
    for _, n in ipairs(L:Ind_Family(name)) do
        local id = SpellID(n)
        if id then ids[id] = true end
        AddRanks(ids, n)
    end
    for _ in pairs(ids) do any = true break end
    idCache[key] = any and ids or false
    return any and ids or nil
end

------------------------------------------------------------------------
-- Every aura button the game creates has to be told which of its pieces
-- show the icon, the duration swipe and the stack count - otherwise the
-- game has nowhere to draw them and the button stays a plain black square.
------------------------------------------------------------------------
local NO_OPTIONS = {}
local function BindButton(btn)
    if btn.IconTexture and btn.SetIcon then pcall(btn.SetIcon, btn, btn.IconTexture) end
    if btn.DurationCooldown and btn.SetDurationCooldown then
        if btn.DurationCooldown.SetHideCountdownNumbers then btn.DurationCooldown:SetHideCountdownNumbers(true) end
        pcall(btn.SetDurationCooldown, btn, btn.DurationCooldown)
    end
    if btn.CountText and btn.SetApplicationCount then
        btn.CountText:SetFont(L.FONT, 9, "OUTLINE")
        pcall(btn.SetApplicationCount, btn, btn.CountText, NO_OPTIONS)
    end
    -- purely visual: clicks go through to the unit frame underneath
    if btn.SetMouseClickEnabled then pcall(btn.SetMouseClickEnabled, btn, false) end
    if btn.SetMouseMotionEnabled then pcall(btn.SetMouseMotionEnabled, btn, false) end
end

------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------
local function NewContainer(b)
    local c = CreateFrame("AuraContainer", nil, b.overlay, TEMPLATE_CONTAINER)
    c:SetFrameLevel(b.overlay:GetFrameLevel() + 1)
    if c.SetMouseClickEnabled then c:SetMouseClickEnabled(false) end
    c:EnableMouse(false)
    if c.SetMouseMotionEnabled then c:SetMouseMotionEnabled(false) end
    c:SetAllPoints(b.health)
    return c
end

-- a flowing row of icons (buffs or debuffs) starting from a corner
local function NewRow(b, key, filter, corner, hDir, vDir, sizeFn, maxFn)
    local c = NewContainer(b)
    c:SetFlowLayoutAnchorPoint(corner)
    c:SetFlowLayoutAxis(AXIS.Horizontal)
    c:SetFlowLayoutGrowthDirection(hDir, vDir)
    c:SetFlowLayoutPadding(1, 1, 1, 1)
    c:SetFlowLayoutMaximumLineSize(nil)
    c.llKey = key
    -- a filter the client doesn't understand falls back to plain HARMFUL/HELPFUL
    local base = filter:match("^[A-Z]+")
    local function add(f) return pcall(c.AddAuraGroup, c, key, f, {
        maxFrameCount = maxFn(),
        sortMethod = SortMethod(),
        sortDirection = SortDir(),
        templateNames = { TEMPLATE_BUTTON },
        initializeFrame = function(btn)
            local s = sizeFn()
            btn:SetSize(s, s)
            BindButton(btn)
        end,
    }) end
    c.llFilter = filter
    if not add(filter) then
        c.llFilter = base
        local ok, err = add(base)
        if not ok then error(err) end
    end
    c.llWanted = filter
    c:SetEnabled(false)
    c:Hide()
    return c
end

-- the debuff row leaves crowd control out while it shows big in the middle
local function DebuffRowFilter()
    local f = "HARMFUL"
    if L.db.debuffRaidOnly then f = f .. "|RAID" end            -- the game's own "debuffs that matter"
    if L.db.bigCC then f = f .. "|!CROWD_CONTROL" end          -- shown big in the middle instead
    return f
end
local function NewDebuffRow(b)
    return NewRow(b, "debuffs", DebuffRowFilter(), "BOTTOMLEFT", FLOW.Right, FLOW.Up,
        function() return L.db.debuffSize end, function() return L.db.maxDebuffs end)
end

-- one fixed slot per active buff indicator
local function IndicatorSignature()
    local parts = { tostring(L.db and L.db.indicatorFill) }
    for i, ind in ipairs(L.cdb.indicators or {}) do
        parts[#parts + 1] = table.concat({ i, ind.spell or "", ind.anchor or "", ind.mode or "", ind.size or "" }, ":")
    end
    return table.concat(parts, "|")
end


-- "Fill from the corner": one flowing container per spot, holding every
-- active indicator there, so whichever buffs are up start at the corner and
-- line up without gaps. The game decides their order.
local FILL_DIR = { TOPLEFT = "Right", LEFT = "Right", BOTTOMLEFT = "Right", TOPRIGHT = "Left",
    RIGHT = "Left", BOTTOMRIGHT = "Left", TOP = "Right", CENTER = "Right", BOTTOM = "Right" }

local function BuildFillContainers(b, c)
    local perSpot = {}
    for i, ind in ipairs(L.cdb.indicators or {}) do
        local active = ind.mode == "MINE" or ind.mode == "ANY"
        local ids = active and ind.spell and ind.spell ~= "" and L:AC_SpellIDs(ind.spell)
        if ids then
            local a = ind.anchor or "TOPRIGHT"
            local filter = (ind.mode == "MINE") and "HELPFUL|PLAYER" or "HELPFUL"
            perSpot[a] = perSpot[a] or {}
            local sp = perSpot[a]
            sp[filter] = sp[filter] or { ids = {}, n = 0, size = 0, members = {} }
            local g = sp[filter]
            for id in pairs(ids) do g.ids[id] = true end
            g.n = g.n + 1
            g.size = math.max(g.size, ind.size or 14)
            g.members[#g.members + 1] = i
        end
    end
    c.subs = {}
    for anchor, groups in pairs(perSpot) do
        local sub = NewContainer(b)
        sub:SetFlowLayoutAnchorPoint(anchor)
        sub:SetFlowLayoutAxis(AXIS.Horizontal)
        local v = anchor:find("BOTTOM") and FLOW.Up or FLOW.Down
        sub:SetFlowLayoutGrowthDirection(FLOW[FILL_DIR[anchor] or "Right"], v)
        sub:SetFlowLayoutPadding(1, 1, 1, 1)
        local key = 0
        for filter, g in pairs(groups) do
            key = key + 1
            local size = g.size
            local ok = pcall(sub.AddAuraGroup, sub, "fill" .. anchor .. key, filter, {
                maxFrameCount = g.n,
                sortMethod = SortMethod(),
                sortDirection = SortDir(),
                templateNames = { TEMPLATE_BUTTON },
                candidateFilters = { includeSpellIDs = g.ids },
                initializeFrame = function(btn) btn:SetSize(size, size) BindButton(btn) end,
            })
            if ok then for _, i in ipairs(g.members) do c.handled[i] = true end end
        end
        sub:SetEnabled(false)
        sub:Hide()
        c.subs[#c.subs + 1] = sub
    end
end

local function BuildIndicatorContainer(b)
    local c = NewContainer(b)
    c.handled = {}
    if L.db.indicatorFill then
        BuildFillContainers(b, c)
        c:SetEnabled(false)
        c:Hide()
        c.signature = IndicatorSignature()
        return c
    end
    -- every indicator keeps its fixed spot (shared with Lifeline's own icons,
    -- see L:Ind_Positions); only buffs that are up get a game icon
    local positions = L:Ind_Positions()
    for i, ind in ipairs(L.cdb.indicators or {}) do
        local active = ind.mode == "MINE" or ind.mode == "ANY"
        local ids = active and ind.spell and ind.spell ~= "" and L:AC_SpellIDs(ind.spell)
        local p = positions[i]
        if ids and p then
            local filter = (ind.mode == "MINE") and "HELPFUL|PLAYER" or "HELPFUL"
            local ok = pcall(c.AddAuraSlot, c, "ind" .. i, filter, {
                templateNames = { TEMPLATE_BUTTON },
                candidateFilters = { includeSpellIDs = ids },
                initializeFrame = function(btn)
                    BindButton(btn)
                    btn:ClearAllPoints()
                    btn:SetSize(p[5], p[5])
                    btn:SetPoint(p[1], c, p[2], p[3], p[4])
                end,
            })
            if ok then c.handled[i] = true end
        end
    end
    c:SetEnabled(false)
    c:Hide()
    c.signature = IndicatorSignature()
    return c
end

-- one bigger icon in the middle: boss debuffs, then crowd control
local function BigSignature()
    return tostring(L.db.bigBossDebuffs) .. "|" .. tostring(L.db.bigCC) .. "|" .. tostring(L.db.bigDebuffSize)
end

local function BuildBigContainer(b)
    local c = NewContainer(b)
    local size = L.db.bigDebuffSize or 22
    c:ClearAllPoints()
    c:SetSize(size * 2 + 1, size)
    c:SetPoint("CENTER", b.health, "CENTER")
    c:SetFlowLayoutAnchorPoint("LEFT")
    c:SetFlowLayoutAxis(AXIS.Horizontal)
    c:SetFlowLayoutGrowthDirection(FLOW.Right, FLOW.Down)
    c:SetFlowLayoutPadding(1, 1, 1, 1)
    local function init(btn)
        btn:SetSize(size, size)
        BindButton(btn)
    end
    local any = false
    if L.db.bigBossDebuffs then
        any = pcall(c.AddAuraGroup, c, "boss", "HARMFUL", { maxFrameCount = 1, sortMethod = SortMethod(),
            sortDirection = SortDir(), templateNames = { TEMPLATE_BUTTON }, initializeFrame = init,
            candidateFilters = { isBossAura = true } }) or any
    end
    if L.db.bigCC then
        -- the game's own crowd-control check (same as the CC'D banner), no spell IDs
        any = pcall(c.AddAuraGroup, c, "cc", "HARMFUL|CROWD_CONTROL", { maxFrameCount = 1, sortMethod = SortMethod(),
            sortDirection = SortDir(), templateNames = { TEMPLATE_BUTTON }, initializeFrame = init }) or any
    end
    c.empty = not any
    c.signature = BigSignature()
    c:SetEnabled(false)
    c:Hide()
    return c
end

------------------------------------------------------------------------
-- Dispel highlight drawn by the game (works in combat)
-- One hidden slot per debuff type, each only accepting debuffs of that type
-- that you can remove. When the game shows a slot, the colored border/tint
-- or health bar layer attached to it shows with it, so Lifeline never has
-- to read the debuff itself.
------------------------------------------------------------------------
-- a game slot used only as a show/hide switch: its own icon stays invisible
-- and it ignores the mouse. Our visuals hang on it (dispel highlight,
-- status banners). Note: the game blocks scripts (OnShow etc.) on anything
-- hung on these slots, so they can't report when they appear.
local function HideSlot(btn)
    btn:SetSize(1, 1)
    if btn.Backdrop then btn.Backdrop:Hide() end
    if btn.CountText then btn.CountText:Hide() end
    if btn.DurationCooldown then btn.DurationCooldown:Hide() end
    if btn.IconTexture then
        btn.IconTexture:SetAlpha(0)
        if btn.SetIcon then pcall(btn.SetIcon, btn, btn.IconTexture) end
    end
    if btn.SetMouseClickEnabled then pcall(btn.SetMouseClickEnabled, btn, false) end
    if btn.SetMouseMotionEnabled then pcall(btn.SetMouseMotionEnabled, btn, false) end
end

local DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison" }
local DISPEL_FILTERS = { "HARMFUL|RAID_PLAYER_DISPELLABLE", "HARMFUL|RAID" }

local function DispelExclude() return nil end   -- the "don't highlight" list was removed in 1.2.5

local function DispelSignature(b)
    local db = L.db
    local cc = {}
    if db.dispelColors == "CUSTOM" then
        for _, k in ipairs({ "Magic", "Curse", "Disease", "Poison" }) do
            local c = (db.dispelCustom or {})[k]
            cc[#cc + 1] = c and ("%.3f,%.3f,%.3f"):format(c.r, c.g, c.b) or "-"
        end
    end
    local ids = {}
    for id in pairs(DispelExclude() or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    return table.concat(ids, ",") .. "|" .. table.concat({ tostring(db.dispelHighlight), db.dispelStyle or "BORDER", db.dispelColors or "DEFAULT",
        tostring(db.barTexture), tostring(db.barAlpha), table.concat(cc, ";"),
        tostring(db.dispelGlowAlpha), tostring(db.dispelGlowHeight), tostring(db.dispelGlowDir),
        tostring(db.dispelBorderSize), tostring(db.dispelBarFill), tostring(db.dispelBarGradient),
        tostring(db.fillDirection), tostring(b and math.floor((b.health:GetHeight() or 0) + 0.5)) }, "|")
end

-- the visuals hung on one game-shown slot
local function DecorateDispel(b, btn, col)
    if btn.__llDispel then return end
    btn.__llDispel = true
    HideSlot(btn)

    local style = L.db.dispelStyle or "BORDER"
    local base = b.content:GetFrameLevel()
    local r, g, bl = col[1], col[2], col[3]
    if style == "BAR" or style == "BOTH" then
        -- a colored copy of the health fill, under the name text
        local f = CreateFrame("Frame", nil, btn)
        f:SetAllPoints(b.health)
        f:SetFrameLevel(base + 2)
        local t = f:CreateTexture(nil, "ARTWORK")
        local fill = b.health:GetStatusBarTexture()
        t:SetAllPoints(fill)
        local file = fill and fill:GetTexture()
        if file then t:SetTexture(file) else t:SetTexture(L.WHITE) end
        L:Dispel_ApplyBar(t, r, g, bl)
    end
    if style ~= "BAR" then
        -- glow over the health bar, below the text
        local tf = CreateFrame("Frame", nil, btn)
        tf:SetAllPoints(b.health)
        tf:SetFrameLevel(base + 3)
        local t1 = tf:CreateTexture(nil, "ARTWORK")
        local t2 = tf:CreateTexture(nil, "ARTWORK")
        L:Dispel_ApplyTint(t1, t2, b.health, r, g, bl)
        -- border around the whole frame
        local bf = CreateFrame("Frame", nil, btn)
        bf:SetAllPoints(b.content)
        bf:SetFrameLevel(base + 6)
        L.AddBorder(bf, { r, g, bl, 1 }, L.db.dispelBorderSize or 2)
    end
end

local function BuildDispelContainer(b)
    local c = NewContainer(b)
    c:SetFlowLayoutAnchorPoint("CENTER")
    c:SetFlowLayoutAxis(AXIS.Horizontal)
    c:SetFlowLayoutGrowthDirection(FLOW.Right, FLOW.Down)
    local colors = L.DispelColors()
    local exclude = DispelExclude()
    local any = false
    if L.db.dispelHighlight then
        for _, filter in ipairs(DISPEL_FILTERS) do
            for _, kind in ipairs(DISPEL_TYPES) do
                local col = colors[kind]
                local ok = pcall(c.AddAuraGroup, c, "dispel" .. kind, filter, {
                    maxFrameCount = 1, sortMethod = SortMethod(), sortDirection = SortDir(),
                    templateNames = { TEMPLATE_BUTTON },
                    initializeFrame = function(btn) DecorateDispel(b, btn, col) end,
                    candidateFilters = { includeDispelTypes = { [kind] = true }, excludeSpellIDs = exclude },
                })
                any = ok or any
            end
            if any then break end
        end
    end
    c.empty = not any
    c.signature = DispelSignature(b)
    c:SetEnabled(false)
    c:Hide()
    return c
end

------------------------------------------------------------------------
-- Status effect banners drawn by the game (StatusEffects.lua): one hidden
-- slot per kind, accepting only the listed spell IDs; the banner hangs on it
------------------------------------------------------------------------
local function StatusSignature(b)
    local parts = {}
    for _, kind in ipairs(L.STATUS_KINDS or {}) do
        local ids = {}
        for id in pairs(L:Status_IDs(kind) or {}) do ids[#ids + 1] = id end
        table.sort(ids)
        parts[#parts + 1] = kind .. ":" .. (L:Status_IDs(kind) and "on" or "off") .. ":" .. table.concat(ids, ",")
    end
    parts[#parts + 1] = tostring(b and math.floor((b.health:GetHeight() or 0) + 0.5))
    parts[#parts + 1] = table.concat({ L:Status_TagPoint() }, ",")
    return table.concat(parts, "|")
end

local function DecorateStatus(b, btn, kind)
    if btn.__llStatus then return end
    btn.__llStatus = true
    HideSlot(btn)
    L:Status_MakeBanner(btn, b, kind, b.overlay:GetFrameLevel() + L.STATUS_LEVEL[kind])
end

local function BuildStatusContainer(b)
    local c = NewContainer(b)
    c:SetFlowLayoutAnchorPoint("CENTER")
    c:SetFlowLayoutAxis(AXIS.Horizontal)
    c:SetFlowLayoutGrowthDirection(FLOW.Right, FLOW.Down)
    local any = false
    for _, kind in ipairs(L.STATUS_KINDS or {}) do
        local ids = L:Status_IDs(kind)
        if ids then
            local ok = pcall(c.AddAuraGroup, c, "status" .. kind, L.STATUS_FILTER[kind], {
                maxFrameCount = 1, sortMethod = SortMethod(), sortDirection = SortDir(),
                templateNames = { TEMPLATE_BUTTON },
                initializeFrame = function(btn) DecorateStatus(b, btn, kind) end,
                -- CC'D: the game's crowd-control filter picks the debuffs itself
                candidateFilters = (not L.STATUS_BYFILTER[kind]) and { includeSpellIDs = ids } or nil,
            })
            any = ok or any
        end
    end
    c.empty = not any
    c.signature = StatusSignature(b)
    c:SetEnabled(false)
    c:Hide()
    return c
end

function L:AC_DrawsStatus(b)
    return (b.ac and b.ac.status and not b.ac.status.empty) and true or false
end

-- does the game draw this button's dispel highlight?
function L:AC_DrawsDispel(b)
    return (L.db.dispelHighlight and b.ac and b.ac.dispel and not b.ac.dispel.empty) and true or false
end

local function Retire(c)
    if not c then return end
    pcall(c.SetUnit, c, "none")
    pcall(c.SetEnabled, c, false)
    pcall(c.Hide, c)
    for _, sub in ipairs(c.subs or {}) do Retire(sub) end
end

-- set up the containers for one real unit button (out of combat)
function L:AC_Setup(b)
    if b.fake or b.ac or not L:AC_Available() then return end
    if InCombatLockdown() then
        L:RunAfterCombat("acsetup", function()
            for _, btn in ipairs(L.buttons) do L:AC_Setup(btn) end
            L:AC_RefreshAll()
        end)
        return
    end
    local ok, err = pcall(function()
        b.ac = {}
        b.ac.buffs = NewRow(b, "mybuffs", "HELPFUL|PLAYER", "TOPRIGHT", FLOW.Left, FLOW.Down,
            function() return L.db.buffSize end, function() return L.db.maxBuffs end)
        b.ac.debuffs = NewDebuffRow(b)
        b.ac.inds = BuildIndicatorContainer(b)
        b.ac.big = BuildBigContainer(b)
        b.ac.dispel = BuildDispelContainer(b)
        b.ac.status = BuildStatusContainer(b)
    end)
    if not ok then
        -- something about the container API differs: fall back to Lua scanning
        b.ac = nil
        available = false
        if geterrorhandler then geterrorhandler()(err) end
        return
    end
    L:AC_Apply(b)
end

------------------------------------------------------------------------
-- Settings -> containers (out of combat)
------------------------------------------------------------------------
function L:AC_Apply(b)
    local ac = b.ac
    if not ac or InCombatLockdown() then return end
    local db = L.db

    -- rebuild the indicator slots when the indicator list changed
    if not ac.inds or ac.inds.signature ~= IndicatorSignature() then
        Retire(ac.inds)
        local ok, c = pcall(BuildIndicatorContainer, b)
        ac.inds = ok and c or nil
    end

    -- the row's filter depends on "crowd control big in the middle"
    if ac.debuffs and ac.debuffs.llWanted ~= DebuffRowFilter() then
        Retire(ac.debuffs)
        local ok, c = pcall(NewDebuffRow, b)
        ac.debuffs = ok and c or nil
    end

    if not ac.big or ac.big.signature ~= BigSignature() then
        Retire(ac.big)
        local ok, c = pcall(BuildBigContainer, b)
        ac.big = ok and c or nil
    end
    if not ac.dispel or ac.dispel.signature ~= DispelSignature(b) then
        Retire(ac.dispel)
        local ok, c = pcall(BuildDispelContainer, b)
        ac.dispel = ok and c or nil
    end
    if ac.dispel then ac.dispel.wanted = not ac.dispel.empty end
    if not ac.status or ac.status.signature ~= StatusSignature(b) then
        Retire(ac.status)
        local ok, c = pcall(BuildStatusContainer, b)
        ac.status = ok and c or nil
    end
    if ac.status then ac.status.wanted = not ac.status.empty end

    if ac.big then
        local bx, by = L.ElementOffset("bigDebuff")
        ac.big:ClearAllPoints()
        ac.big:SetPoint("CENTER", b.health, "CENTER", bx, by)
        -- the middle icon has its own switches, so it shows even with the debuff row off
        ac.big.wanted = not ac.big.empty
    end

    -- rows: position (Element positions nudges), size, count, exclusions
    local reserve = L:Ind_Positions().reserve
    local function row(c, key, show, size, max, offKey, shiftX)
        if not c then return end
        local ox, oy = L.ElementOffset(offKey)
        ox = ox + (shiftX or 0)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", b.health, "TOPLEFT", ox, oy)
        c:SetPoint("BOTTOMRIGHT", b.health, "BOTTOMRIGHT", ox, oy)
        pcall(c.SetAuraGroupMaxFrameCount, c, key, max)
        local n = c.GetAuraGroupFrameCount and c:GetAuraGroupFrameCount(key) or 0
        for i = 1, n do
            local f = c:GetAuraGroupFrame(key, i)
            if Accessible(f) then f:SetSize(size, size) end
        end
        c.wanted = show
    end
    -- your buffs start left of any indicators in the top-right corner,
    -- debuffs right of any in the bottom-left corner
    row(ac.buffs, "mybuffs", db.showBuffs, db.buffSize, db.maxBuffs, "buffs", -(reserve.TOPRIGHT or 0))
    row(ac.debuffs, "debuffs", db.showDebuffs, db.debuffSize, db.maxDebuffs, "debuffs", reserve.BOTTOMLEFT or 0)

    -- spells placed as indicators stay out of the "your buffs" row
    local exclude
    for _, ind in ipairs(L.cdb.indicators or {}) do
        local ids = ind.spell and ind.spell ~= "" and L:AC_SpellIDs(ind.spell)
        if ids then
            exclude = exclude or {}
            for id in pairs(ids) do exclude[id] = true end
        end
    end
    pcall(ac.buffs.SetAuraGroupCandidateFilters, ac.buffs, "mybuffs", exclude and { excludeSpellIDs = exclude } or nil)

    -- debuff row: boss debuffs show big in the middle instead
    local dfilter = db.bigBossDebuffs and { isBossAura = false } or nil
    if ac.debuffs then pcall(ac.debuffs.SetAuraGroupCandidateFilters, ac.debuffs, "debuffs", dfilter) end

    L:AC_SetUnit(b)
end

-- point the containers at the button's current unit (safe in combat)
function L:AC_SetUnit(b)
    local ac = b.ac
    if not ac then return end
    local unit = b.unit
    for _, key in ipairs({ "buffs", "debuffs", "inds", "big", "dispel", "status" }) do
        local c = ac[key]
        if c then
            local show = unit ~= nil and (c.wanted ~= false)
            local all = { c }
            for _, sub in ipairs(c.subs or {}) do all[#all + 1] = sub end
            for _, x in ipairs(all) do
                pcall(x.SetUnit, x, show and unit or "none")
                pcall(x.SetEnabled, x, show)
                pcall(x.SetShown, x, show)
                if show and x.UpdateAllAuras then pcall(x.UpdateAllAuras, x) end
            end
        end
    end
end

function L:AC_RefreshAll()
    if InCombatLockdown() then
        L:RunAfterCombat("acrefresh", function() L:AC_RefreshAll() end)
        return
    end
    for _, b in ipairs(L.buttons) do
        if not b.fake then
            if not b.ac then L:AC_Setup(b) else L:AC_Apply(b) end
        end
    end
end

-- is this indicator drawn by a container on this button?
function L:AC_HandlesIndicator(b, idx)
    return b.ac and b.ac.inds and b.ac.inds.handled and b.ac.inds.handled[idx] or false
end

------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------
hooksecurefunc(L, "Button_Init", function(_, b) if not b.fake then L:AC_Setup(b) end end)
hooksecurefunc(L, "Button_SetUnit", function(_, b) if b.ac then L:AC_SetUnit(b) end end)
hooksecurefunc(L, "Buttons_RefreshAll", function() L:AC_RefreshAll() end)
