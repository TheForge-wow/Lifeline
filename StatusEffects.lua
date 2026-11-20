--[[
    Lifeline - Status effects: ICE BLOCK and CC'D banners, and the
    SOULSTONE tag

    A banner across the bottom of a player's frame (like DRINKING). In
    combat addons can't read debuffs, so the banner hangs on a hidden slot
    the game shows itself (AuraContainers.lua), the same trick as the dispel
    highlight.

    CC'D (1.2.5): WoW Forever doesn't match enemy debuffs by spell ID, so the
    old STUNNED / SILENCED lists never fired in a real fight. CC'D uses the
    game's own crowd-control filter instead: stuns, fears, sheep and the like,
    with no lists to keep up.

    Banner order when several are up: ICE BLOCK, CC'D (then DRINKING,
    Indicators.lua). SOULSTONE is a small tag at the top center.
]]

local _, L = ...

-- starter lists (all ranks). Unknown IDs are dropped at runtime.
local BUILTIN = {
    ICEBLOCK = {
        11958,                       -- Ice Block
        45438,                       -- Ice Block (later version)
    },
    SOULSTONE = {
        20707, 20762, 20763, 20764, 20765, 27239, 47883, -- Soulstone Resurrection
    },
}

local ENABLED = { CC = "statusCC", ICEBLOCK = "statusIceBlock", SOULSTONE = "statusSoulstone" }
L.STATUS_KINDS = { "CC", "ICEBLOCK", "SOULSTONE" }   -- banners later in the list draw on top
L.STATUS_FILTER = { CC = "HARMFUL|CROWD_CONTROL", ICEBLOCK = "HELPFUL", SOULSTONE = "HELPFUL" }
-- kinds the game picks out itself (no spell IDs)
L.STATUS_BYFILTER = { CC = true }
-- layers above the overlay: banners sit over every icon and the LOW MANA tag
L.STATUS_LEVEL = { CC = 14, ICEBLOCK = 15, SOULSTONE = 15 }
L.STATUS_LOOK = {
    ICEBLOCK = { text = "ICE BLOCK", bg = { 0.16, 0.24, 0.30, 0.88 }, line = { 0.85, 0.95, 1.00 }, fg = { 0.90, 0.97, 1.00 } },
    SOULSTONE = { text = "SOULSTONE", tag = true, fg = { 0.80, 0.50, 1.00 } },
    CC      = { text = "CC'D",     bg = { 0.22, 0.10, 0.00, 0.85 }, line = { 1.00, 0.55, 0.10 }, fg = { 1.00, 0.70, 0.30 } },
}

local known = {}
local function Known(id)
    if known[id] ~= nil then return known[id] end
    local ok, info = true, true
    if C_Spell and C_Spell.GetSpellInfo then ok, info = pcall(C_Spell.GetSpellInfo, id) end
    known[id] = (ok and info ~= nil) and true or false
    return known[id]
end

-- spell IDs for one kind (built-in + yours), or nil when the kind is off
function L:Status_IDs(kind)
    local db = L.db
    if not db[ENABLED[kind]] then return nil end
    if L.STATUS_BYFILTER[kind] then return {} end   -- the game's filter does the matching
    if not BUILTIN[kind] then return nil end
    local set, any = {}, false
    for _, id in ipairs(BUILTIN[kind]) do
        if Known(id) then set[id] = true any = true end
    end
    if not any then
        -- the client wouldn't confirm any of them: keep the whole list
        -- (an ID the game doesn't have simply never matches)
        for _, id in ipairs(BUILTIN[kind]) do set[id] = true end
        any = true
    end
    return any and set or nil
end

-- where the SOULSTONE tag sits: top center (nudge it under Element positions)
function L:Status_TagPoint()
    local o = L.db.offsets and L.db.offsets.soulstone or {}
    return 0 + (o.x or 0), -2 + (o.y or 0)
end

-- the banner (or tag) itself; `parent` is the frame it lives on (a game slot or the button)
function L:Status_MakeBanner(parent, b, kind, level)
    local look = L.STATUS_LOOK[kind]
    if look.tag then
        local f = CreateFrame("Frame", nil, parent)
        f:SetFrameLevel(level)
        f:SetSize(1, 1)
        local t = f:CreateFontString(nil, "OVERLAY")
        t:SetFont(L.FONT, 9, "OUTLINE")
        local x, y = L:Status_TagPoint()
        t:SetPoint("TOP", b.health, "TOP", x, y)
        t:SetTextColor(look.fg[1], look.fg[2], look.fg[3])
        t:SetText(look.text)
        f:SetAllPoints(b.health)
        return f
    end
    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameLevel(level)
    f:SetPoint("BOTTOMLEFT", b.health, "BOTTOMLEFT", 0, 0)
    f:SetPoint("BOTTOMRIGHT", b.health, "BOTTOMRIGHT", 0, 0)
    local h = math.max(10, math.min(14, math.floor((b.health:GetHeight() or 30) * 0.32)))
    f:SetHeight(h)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(look.bg[1], look.bg[2], look.bg[3], look.bg[4])
    local line = f:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT") line:SetPoint("TOPRIGHT") line:SetHeight(1)
    line:SetColorTexture(look.line[1], look.line[2], look.line[3], 0.9)
    local t = f:CreateFontString(nil, "OVERLAY")
    t:SetFont(L.FONT, math.max(8, h - 3), "OUTLINE")
    t:SetPoint("CENTER", 0, 0)
    t:SetTextColor(look.fg[1], look.fg[2], look.fg[3])
    t:SetText(look.text)
    return f
end

------------------------------------------------------------------------
-- Lifeline's own banner: sample frames, and clients without aura
-- containers (out of combat only there)
------------------------------------------------------------------------
local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex

local function Has(unit, set, filter, any)
    if not set then return false end
    for i = 1, 40 do
        local ok, aura = pcall(GetAuraDataByIndex, unit, i, filter)
        if not ok or not aura then return false end
        if any then return true end
        local id = L.Readable(aura.spellId)
        if id and set[id] then return true end
    end
    return false
end

-- which banner (most important first) and whether to show the SOULSTONE tag
local function ScanUnit(unit)
    if not GetAuraDataByIndex or InCombatLockdown() then return nil, false end
    local banner
    for _, kind in ipairs({ "ICEBLOCK", "CC" }) do
        if Has(unit, L:Status_IDs(kind), L.STATUS_FILTER[kind], L.STATUS_BYFILTER[kind]) then banner = kind break end
    end
    return banner, Has(unit, L:Status_IDs("SOULSTONE"), "HELPFUL")
end

function L:Button_UpdateStatus(b)
    local kind, stone = nil, false
    local db = L.db
    if b.fake then
        local i = b.fake.index
        if i == 2 and db.statusCC then kind = "CC"
        elseif i == 3 and db.statusIceBlock then kind = "ICEBLOCK" end
        stone = (i == 1) and db.statusSoulstone and true or false
    elseif b.unit and not (L.AC_DrawsStatus and L:AC_DrawsStatus(b)) then
        kind, stone = ScanUnit(b.unit)
    end
    b.statusBanners = b.statusBanners or {}
    -- the tag position can change (Element positions): rebuild it then
    local tx, ty = L:Status_TagPoint()
    if b.statusBanners.SOULSTONE and (b.statusTagX ~= tx or b.statusTagY ~= ty) then
        b.statusBanners.SOULSTONE:Hide()
        b.statusBanners.SOULSTONE = nil
    end
    for _, k in ipairs(L.STATUS_KINDS) do
        local want = (k == "SOULSTONE") and stone or (k == kind)
        local f = b.statusBanners[k]
        if want and not f then
            f = L:Status_MakeBanner(b.overlay, b, k, b.overlay:GetFrameLevel() + L.STATUS_LEVEL[k])
            b.statusBanners[k] = f
            if k == "SOULSTONE" then b.statusTagX, b.statusTagY = tx, ty end
        end
        if f then f:SetShown(want and true or false) end
    end
end

hooksecurefunc(L, "Button_UpdateAuras", function(_, b)
    if b.overlay then L:Button_UpdateStatus(b) end
end)
