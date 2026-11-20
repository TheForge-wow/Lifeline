--[[
    Lifeline - Buff indicators
    User-placed spell icons at any of nine spots on the frame. Each indicator
    shows when the buff is active (cast by you or by anyone) or only when it's
    missing.

    Secret values: we look buffs up by name with C_UnitAuras.GetAuraDataBySpellName,
    which does the matching inside the game client, so it keeps working when aura
    names are hidden from addons. If the game won't tell us either way, "missing"
    indicators stay hidden rather than showing a false alarm.
]]

local _, L = ...
local Readable = L.Readable

L.IND_ANCHORS = {
    { value = "TOPLEFT",     text = "Top Left" },
    { value = "TOP",         text = "Top" },
    { value = "TOPRIGHT",    text = "Top Right" },
    { value = "LEFT",        text = "Left Center" },
    { value = "CENTER",      text = "Center" },
    { value = "RIGHT",       text = "Right Center" },
    { value = "BOTTOMLEFT",  text = "Bottom Left" },
    { value = "BOTTOM",      text = "Bottom Center" },
    { value = "BOTTOMRIGHT", text = "Bottom Right" },
}
L.IND_MODES = {
    { value = "MINE",         text = "Active - cast by me" },
    { value = "ANY",          text = "Active - cast by anyone" },
    { value = "MISSING",      text = "Missing - from everyone" },
    { value = "MISSING_MINE", text = "Missing - mine only" },
}
L.IND_SIZES = {}
for _, n in ipairs({ 10, 12, 14, 16, 18, 20, 22, 24, 28 }) do
    L.IND_SIZES[#L.IND_SIZES + 1] = { value = n, text = n .. " px" }
end
L.IND_MAX = 10

local QUESTION = 134400
local GetBySpellName = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex

------------------------------------------------------------------------
-- Spell helpers (spell info is static, never secret)
------------------------------------------------------------------------
function L:Ind_SpellName(spell)
    local id = tonumber(spell)
    if id then
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        return name or spell
    end
    return spell
end

function L:Ind_SpellIcon(spell)
    local key = tonumber(spell) or spell
    local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(key)
    return tex or QUESTION
end

------------------------------------------------------------------------
-- Buff families: single-target and group versions of the same buff count
-- as each other, so "Prayer of Fortitude missing" doesn't fire on someone
-- who has Power Word: Fortitude, and vice versa.
------------------------------------------------------------------------
local FAMILIES = {
    { "Power Word: Fortitude", "Prayer of Fortitude" },
    { "Divine Spirit", "Prayer of Spirit" },
    { "Shadow Protection", "Prayer of Shadow Protection" },
    { "Arcane Intellect", "Arcane Brilliance" },
    { "Mark of the Wild", "Gift of the Wild" },
    { "Blessing of Might", "Greater Blessing of Might" },
    { "Blessing of Wisdom", "Greater Blessing of Wisdom" },
    { "Blessing of Kings", "Greater Blessing of Kings" },
    { "Blessing of Salvation", "Greater Blessing of Salvation" },
    { "Blessing of Light", "Greater Blessing of Light" },
    { "Blessing of Sanctuary", "Greater Blessing of Sanctuary" },
}
local familyOf = {}
for _, fam in ipairs(FAMILIES) do
    for _, name in ipairs(fam) do familyOf[name:lower()] = fam end
end
local singleFamily = {}   -- cache so non-family spells don't build a table every aura update
function L:Ind_Family(name)
    name = name or ""
    local fam = familyOf[name:lower()]
    if fam then return fam end
    fam = singleFamily[name]
    if not fam then fam = { name } singleFamily[name] = fam end
    return fam
end

-- names + IDs of every spell placed as an indicator: the generic
-- "buffs you cast" row skips these so they only appear where you put them
-- cached; rebuilt when L:Refresh() runs or the indicator list itself changes
local excludeCache, cacheList, cacheLen = nil, nil, -1
function L:Ind_InvalidateCache() cacheList, cacheLen = nil, -1 end

function L:Ind_Exclude()
    local list = L.cdb and L.cdb.indicators
    local len = list and #list or 0
    if list == cacheList and len == cacheLen then return excludeCache end
    cacheList, cacheLen = list, len
    if len == 0 then excludeCache = nil return nil end
    local set = {}
    for _, ind in ipairs(list) do
        if ind.spell and ind.spell ~= "" then
            for _, n in ipairs(L:Ind_Family(L:Ind_SpellName(ind.spell))) do set[n] = true end
            local id = tonumber(ind.spell)
            if id then set[id] = true end
        end
    end
    excludeCache = set
    return set
end

-- returns aura (or nil), known (false if the game wouldn't tell us)
local function FindAura(unit, name, filter)
    if GetBySpellName then
        local ok, aura = pcall(GetBySpellName, unit, name, filter)
        if ok then return aura, true end
    end
    if not GetAuraDataByIndex then return nil, false end
    local known = true
    for i = 1, 40 do
        local ok, a = pcall(GetAuraDataByIndex, unit, i, filter)
        if not ok or not a then break end
        local n = Readable(a.name)
        if n == nil then known = false
        elseif n == name then return a, true end
    end
    return nil, known
end

------------------------------------------------------------------------
-- Per-button icons
------------------------------------------------------------------------
local function GetIcon(b, i)
    b.inds = b.inds or {}
    local ic = b.inds[i]
    if not ic then
        ic = L.NewAuraIcon(b.overlay, 14)
        ic:SetFrameLevel(b.overlay:GetFrameLevel() + 2)
        b.inds[i] = ic
    end
    return ic
end

local GROW = {   -- direction icons sharing a spot spread out in
    TOPLEFT = 1, LEFT = 1, BOTTOMLEFT = 1,
    TOPRIGHT = -1, RIGHT = -1, BOTTOMRIGHT = -1,
    TOP = 0, CENTER = 0, BOTTOM = 0,
}

-- Every indicator gets a fixed spot, worked out from the whole list: ones
-- sharing an anchor sit side by side in list order, whether they are drawn by
-- Lifeline or by the game's aura icons (AuraContainers.lua uses the same spots),
-- so they never land on top of each other. Also tells the buff / debuff rows
-- how much room the indicators take in their corner.
-- returns { [idx] = { point, anchor, x, y, size }, reserve = { [anchor] = width } }
function L:Ind_Positions()
    local list = (L.cdb and L.cdb.indicators) or {}
    local perSpot, out = {}, { reserve = {} }
    for i, ind in ipairs(list) do
        if ind.spell and ind.spell ~= "" then
            local a = ind.anchor or "TOPRIGHT"
            local size = ind.size or 14
            perSpot[a] = perSpot[a] or { total = 0 }
            local sp = perSpot[a]
            sp.total = sp.total + size + 1
            sp[#sp + 1] = { i = i, size = size }
        end
    end
    for anchor, sp in pairs(perSpot) do
        local dir = GROW[anchor] or 0
        local vy = anchor:find("TOP") and -1 or (anchor:find("BOTTOM") and 1 or 0)
        local x = (dir == 0) and (-(sp.total - 1) / 2) or 0
        for _, e in ipairs(sp) do
            if dir == 0 then
                local pt = (anchor == "TOP" and "TOPLEFT") or (anchor == "BOTTOM" and "BOTTOMLEFT") or "LEFT"
                out[e.i] = { pt, anchor, x, vy, e.size }
            else
                out[e.i] = { anchor, anchor, (x + 1) * dir, vy, e.size }
            end
            x = x + e.size + 1
        end
        out.reserve[anchor] = sp.total + 1
    end
    return out
end

-- spot for the n-th shown Lifeline icon at an anchor, `start` pixels in
local function FillPoint(anchor, start, size, centeredTotal)
    local dir = GROW[anchor] or 0
    local vy = anchor:find("TOP") and -1 or (anchor:find("BOTTOM") and 1 or 0)
    if dir == 0 then
        local pt = (anchor == "TOP" and "TOPLEFT") or (anchor == "BOTTOM" and "BOTTOMLEFT") or "LEFT"
        return pt, anchor, -(centeredTotal - 1) / 2 + start, vy
    end
    return anchor, anchor, (start + 1) * dir, vy
end

local function Layout(b, shown)
    if L.db.indicatorFill then
        -- reminders (drawn by Lifeline) line up from the corner, after the room
        -- the game's icons at the same spot take when their buffs are up
        local list = (L.cdb and L.cdb.indicators) or {}
        local gameRoom, spots = {}, {}
        for i, ind in ipairs(list) do
            if L:AC_HandlesIndicator(b, i) then
                local a = ind.anchor or "TOPRIGHT"
                gameRoom[a] = (gameRoom[a] or 0) + (ind.size or 14) + 1
            end
        end
        for _, e in ipairs(shown) do
            local ind = list[e.idx]
            local a = ind and ind.anchor or "TOPRIGHT"
            spots[a] = spots[a] or {}
            table.insert(spots[a], e)
        end
        for a, entries in pairs(spots) do
            local total = 0
            for _, e in ipairs(entries) do total = total + (list[e.idx].size or 14) + 1 end
            local x = gameRoom[a] or 0
            for _, e in ipairs(entries) do
                local size = list[e.idx].size or 14
                local p1, p2, px, py = FillPoint(a, x, size, total)
                e.icon:ClearAllPoints()
                e.icon:SetPoint(p1, b.health, p2, px, py)
                x = x + size + 1
            end
        end
        return
    end
    local pos = L:Ind_Positions()
    for _, e in ipairs(shown) do
        local p = pos[e.idx]
        e.icon:ClearAllPoints()
        if p then e.icon:SetPoint(p[1], b.health, p[2], p[3], p[4]) end
    end
end

local function ShowStatic(ic, spell)
    ic.tex:SetTexture(L:Ind_SpellIcon(spell))
    ic.tex:SetDesaturated(false)
    ic.cd:Hide()
    ic.count:SetText("")
    ic:Show()
end

function L:Button_UpdateIndicators(b)
    local list = L.cdb and L.cdb.indicators
    local used = 0
    local shown = {}

    if list and #list > 0 then
        local unit = b.unit
        local skipMissing = false
        if not b.fake then
            if not unit then return end
            -- don't nag about missing buffs on dead / offline players
            skipMissing = L.SafeBool(UnitIsDeadOrGhost, unit) or (L.SafeBool(UnitIsConnected, unit) == false)
                or L.IsPetUnit(unit)   -- no rebuff nagging for pets
        end

        for idx, ind in ipairs(list) do
            if ind.spell and ind.spell ~= "" then
                local ic = GetIcon(b, idx)
                ic:SetSize(ind.size or 14, ind.size or 14)
                local visible = false
                local missingMode = ind.mode == "MISSING" or ind.mode == "MISSING_MINE"

                if b.fake then
                    -- preview: missing on some frames, active on others
                    local i = b.fake.index or 1
                    if missingMode then visible = (i + idx) % 4 == 0 and not b.fake.isPet and not b.fake.dead
                    else visible = (i + idx) % 2 == 0 end
                    if visible then
                        ShowStatic(ic, ind.spell)
                        if missingMode then ic.tex:SetDesaturated(true) end
                    end
                elseif not missingMode and L:AC_HandlesIndicator(b, idx) then
                    -- drawn by the game's aura container (AuraContainers.lua), which
                    -- keeps working in combat; nothing to do here
                    visible = false
                else
                    local name = L:Ind_SpellName(ind.spell)
                    local filter = (ind.mode == "MINE" or ind.mode == "MISSING_MINE") and "HELPFUL|PLAYER" or "HELPFUL"
                    -- any member of the buff family counts
                    local aura, known = nil, true
                    for _, n in ipairs(L:Ind_Family(name)) do
                        local a, k = FindAura(unit, n, filter)
                        if a then aura, known = a, true break end
                        if not k then known = false end
                    end
                    if missingMode then
                        if not aura and known and not skipMissing and L.Ind_CanVerifyMissing(unit) then
                            visible = true
                            ShowStatic(ic, ind.spell)
                            ic.tex:SetDesaturated(true)   -- grayed = "you need to put this up"
                        end
                    elseif aura then
                        visible = true
                        ic.tex:SetDesaturated(false)
                        L.SetAuraIcon(ic, unit, aura)
                    end
                end

                if visible then
                    shown[#shown + 1] = { icon = ic, idx = idx }
                else
                    ic:Hide()
                end
                used = idx
            end
        end
        Layout(b, shown)
    end

    -- hide icons left over from removed indicators
    if b.inds then
        for i = used + 1, #b.inds do b.inds[i]:Hide() end
    end
end

------------------------------------------------------------------------
-- DRINKING banner
------------------------------------------------------------------------
local DRINK_BUFFS = { "Drink", "Food & Drink", "Refreshment", "Enriched Drink" }

-- Can we trust a "not found" right now? In combat (and in restricted
-- content) the game hides aura details from addons, and lookups come back
-- empty even when the buff is there - so a missing icon would be a lie.
local function CanVerifyMissing(unit)
    if InCombatLockdown() then return false end
    if not GetAuraDataByIndex then return false end
    local ok, a = pcall(GetAuraDataByIndex, unit, 1, "HELPFUL")
    if not ok then return false end
    if a and L.IsSecret(a.name) then return false end   -- aura names are hidden
    return true
end
L.Ind_CanVerifyMissing = CanVerifyMissing

local function IsDrinking(unit)
    for _, name in ipairs(DRINK_BUFFS) do
        local aura = FindAura(unit, name, "HELPFUL")
        if aura then return true end
    end
    return false
end

local function GetDrinkBanner(b)
    if b.drink then return b.drink end
    local f = CreateFrame("Frame", nil, b.overlay)
    f:SetFrameLevel(b.overlay:GetFrameLevel() + L.LAYER_DRINKING)
    f:SetPoint("BOTTOMLEFT", b.health, "BOTTOMLEFT", 0, 0)
    f:SetPoint("BOTTOMRIGHT", b.health, "BOTTOMRIGHT", 0, 0)
    f:SetHeight(12)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.02, 0.10, 0.22, 0.80)
    local line = f:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT") line:SetPoint("TOPRIGHT") line:SetHeight(1)
    line:SetColorTexture(0.35, 0.70, 1.00, 0.9)
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetFont(L.FONT, 9, "OUTLINE")
    f.text:SetPoint("CENTER", 0, 0)
    f.text:SetTextColor(0.55, 0.82, 1.00)
    f.text:SetText("DRINKING")
    f:Hide()
    b.drink = f
    return f
end

function L:Button_UpdateDrinking(b)
    local show = false
    if L.db.showDrinking then
        if b.fake then
            show = (b.fake.index == 4 or b.fake.index == 12)
        elseif b.unit and not L.SafeBool(UnitIsDeadOrGhost, b.unit) then
            show = IsDrinking(b.unit)
        end
    end
    -- name + health text sit a little higher while the banner is up
    local base = L:NameBaseY()
    local nx = L.ElementOffset("name")
    if show then
        local f = GetDrinkBanner(b)
        local h = math.max(10, math.min(14, math.floor((b.health:GetHeight() or 30) * 0.32)))
        f:SetHeight(h)
        f.text:SetFont(L.FONT, math.max(8, h - 3), "OUTLINE")
        f:Show()
        b.name:SetPoint("CENTER", b.health, "CENTER", nx, base + h / 2)
    else
        if b.drink then b.drink:Hide() end
        b.name:SetPoint("CENTER", b.health, "CENTER", nx, base)
    end
end

hooksecurefunc(L, "Button_UpdateAuras", function(_, b)
    if b.overlay then
        L:Button_UpdateIndicators(b)
        L:Button_UpdateDrinking(b)
    end
end)

-- combat starting / ending changes what we can verify, but fires no UNIT_AURA
local function RefreshAllIndicators()
    for _, b in ipairs(L.buttons) do
        if not b.fake and b.unit and b:IsVisible() then L:Button_UpdateIndicators(b) end
    end
end
L:On("PLAYER_REGEN_DISABLED", RefreshAllIndicators)
L:On("PLAYER_REGEN_ENABLED", RefreshAllIndicators)
