--[[
    Lifeline - Dispel highlight (Indicators > Dispels)

    Colors (standard, colorblind-friendly, custom), the looks shared by both
    highlights (glow, border, debuff tint on the bar), and Lifeline's own
    highlight for sample frames, out of combat, and clients without aura
    containers. In combat the game draws the highlight itself
    (AuraContainers.lua, BuildDispelContainer); Lifeline's copy then stays
    hidden.
]]

local _, L = ...
local WHITE = L.WHITE
local Readable = L.Readable
local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local GetAuraDispelTypeColor = C_UnitAuras and C_UnitAuras.GetAuraDispelTypeColor
local pcall = pcall

local DISPEL_COLORS = {
    Magic   = { 0.20, 0.60, 1.00 },
    Curse   = { 0.64, 0.19, 0.79 },
    Disease = { 0.60, 0.40, 0.00 },
    Poison  = { 0.00, 0.60, 0.00 },
    Bleed   = { 0.80, 0.00, 0.00 },
    Enrage  = { 1.00, 0.40, 0.00 },
    none    = { 0.80, 0.00, 0.00 },
}
local DEFAULT_DISPEL = { 0.64, 0.19, 0.79 }
-- colorblind-friendly set (Okabe-Ito colors): blue, pink, orange, yellow, vermilion
local DISPEL_COLORS_CB = {
    Magic   = { 0.34, 0.71, 0.91 },
    Curse   = { 0.80, 0.47, 0.65 },
    Disease = { 0.90, 0.62, 0.00 },
    Poison  = { 0.94, 0.89, 0.26 },
    Bleed   = { 0.84, 0.37, 0.00 },
    Enrage  = { 0.84, 0.37, 0.00 },
    none    = { 0.84, 0.37, 0.00 },
}
-- your own colors (Indicators > Dispels > Custom): anything you haven't
-- picked uses the standard color. Cached until a color changes.
local customCache, customSrc
local function CustomColors()
    local src = L.db.dispelCustom or {}
    if customCache and customSrc == src then return customCache end
    local t = {}
    for k, v in pairs(DISPEL_COLORS) do
        local c = src[k]
        t[k] = (type(c) == "table" and c.r) and { c.r, c.g, c.b } or v
    end
    customCache, customSrc = t, src
    return t
end
function L:DispelColorsChanged() customCache = nil end
L.DISPEL_STANDARD = DISPEL_COLORS

local function DispelColors()
    local mode = L.db and L.db.dispelColors
    if mode == "COLORBLIND" then return DISPEL_COLORS_CB end
    if mode == "CUSTOM" then return CustomColors() end
    return DISPEL_COLORS
end
L.DispelColors = DispelColors

------------------------------------------------------------------------
-- Dispel highlight looks (Indicators > Dispels), shared by Lifeline's own
-- highlight and the game-drawn one (AuraContainers.lua)
------------------------------------------------------------------------
-- glow: a fade over the health bar. t1/t2 are textures on a frame covering
-- `host`; t2 is only used for "from both edges". Returns false if the game
-- refused the color.
function L:Dispel_ApplyTint(t1, t2, host, r, g, bl)
    local db = L.db
    local a = math.max(0, math.min(1, (db.dispelGlowAlpha or 30) / 100))
    local frac = math.max(0.1, math.min(1, (db.dispelGlowHeight or 100) / 100))
    local dir = db.dispelGlowDir or "BOTTOM"
    local H = host:GetHeight() or 0
    if H <= 0 then H = 40 end
    t1:ClearAllPoints() t2:ClearAllPoints() t2:Hide()
    local function fade(t, aLow, aHigh)
        t:SetColorTexture(1, 1, 1, 1)
        local ok = CreateColor and t.SetGradient and pcall(t.SetGradient, t, "VERTICAL",
            CreateColor(r, g, bl, aLow), CreateColor(r, g, bl, aHigh))
        if not ok then ok = pcall(t.SetColorTexture, t, r, g, bl, math.max(aLow, aHigh) * 0.4) end
        return ok
    end
    if dir == "FULL" then
        t1:SetAllPoints(host)
        return pcall(t1.SetColorTexture, t1, r, g, bl, a) and true or false
    elseif dir == "TOP" then
        t1:SetPoint("TOPLEFT", host) t1:SetPoint("TOPRIGHT", host)
        t1:SetHeight(math.max(2, H * frac))
        return fade(t1, 0, a)
    elseif dir == "EDGES" then
        local band = math.max(2, H * frac / 2)
        t1:SetPoint("BOTTOMLEFT", host) t1:SetPoint("BOTTOMRIGHT", host) t1:SetHeight(band)
        t2:SetPoint("TOPLEFT", host) t2:SetPoint("TOPRIGHT", host) t2:SetHeight(band)
        t2:Show()
        return fade(t1, a, 0) and fade(t2, 0, a)
    end
    t1:SetPoint("BOTTOMLEFT", host) t1:SetPoint("BOTTOMRIGHT", host)
    t1:SetHeight(math.max(2, H * frac))
    return fade(t1, a, 0)
end

-- debuff tint on the bar: a colored layer over the health fill while the
-- debuff is up (the normal health color underneath is untouched), solid or
-- fading along the bar
function L:Dispel_ApplyBar(t, r, g, bl)
    local db = L.db
    local alpha = db.barAlpha or 1
    if db.dispelBarFill == "GRADIENT" and CreateColor and t.SetGradient then
        local k = 1 - math.max(0, math.min(0.9, (db.dispelBarGradient or 50) / 100))
        local fd = db.fillDirection or "LEFT_TO_RIGHT"
        local vertical = fd == "BOTTOM_TO_TOP" or fd == "TOP_TO_BOTTOM"
        local ok = pcall(function()
            local bright, dark = CreateColor(r, g, bl, alpha), CreateColor(r * k, g * k, bl * k, alpha)
            -- bright where the bar starts, darker toward where it ends
            local first = (fd == "LEFT_TO_RIGHT" or fd == "BOTTOM_TO_TOP")
            t:SetVertexColor(1, 1, 1, 1)
            t:SetGradient(vertical and "VERTICAL" or "HORIZONTAL", first and bright or dark, first and dark or bright)
        end)
        if ok then return true end
    end
    return pcall(t.SetVertexColor, t, r, g, bl, alpha) and true or false
end

-- resize a 4-edge border made by L.AddBorder (top, bottom, left, right)
function L:Dispel_BorderSize(f, size)
    local e = f.__border
    if not e then return end
    e[1]:SetHeight(size) e[2]:SetHeight(size) e[3]:SetWidth(size) e[4]:SetWidth(size)
end

-- Color curve for C_UnitAuras.GetAuraDispelTypeColor (works even while the
-- dispel type itself is secret). Built lazily and only if the API exists.
local dispelCurve, curvePalette
local function GetDispelCurve()
    if curvePalette ~= DispelColors() then dispelCurve, curvePalette = nil, DispelColors() end
    if dispelCurve ~= nil then return dispelCurve or nil end
    dispelCurve = false
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local ok, curve = pcall(function()
        local c = C_CurveUtil.CreateColorCurve()
        if Enum and Enum.LuaCurveType and c.SetType then c:SetType(Enum.LuaCurveType.Step) end
        local map = { [0] = "none", [1] = "Magic", [2] = "Curse", [3] = "Disease", [4] = "Poison", [9] = "Enrage", [11] = "Bleed" }
        for idx, key in pairs(map) do
            local col = curvePalette[key]
            c:AddPoint(idx, CreateColor(col[1], col[2], col[3], 1))
        end
        return c
    end)
    if ok and curve then dispelCurve = curve end
    return dispelCurve or nil
end

------------------------------------------------------------------------
-- Lifeline's own highlight
------------------------------------------------------------------------
local DISPEL_FILTERS = { "HARMFUL|RAID_PLAYER_DISPELLABLE", "HARMFUL|RAID" }
local dispelFilter
local function FindDispellable(unit)
    if not GetAuraDataByIndex then return nil end
    if not dispelFilter then
        for _, f in ipairs(DISPEL_FILTERS) do
            if pcall(GetAuraDataByIndex, unit, 1, f) then dispelFilter = f break end
        end
        if not dispelFilter then return nil end
    end
    -- first one that isn't on the "Don't highlight these debuffs" list
    for i = 1, 40 do
        local ok, aura = pcall(GetAuraDataByIndex, unit, i, dispelFilter)
        if not ok or not aura then return nil end
        if not (L.DispelIgnored and L:DispelIgnored(aura)) then return aura end
    end
end

------------------------------------------------------------------------
-- Dispel highlight coloring
-- The tint is a soft fade (clear at the top, ~30% at the bottom). Calling
-- SetVertexColor on a gradient texture flattens it into a solid block, so the
-- color is always applied by rebuilding the gradient instead.
------------------------------------------------------------------------
local function TintDispel(b, r, g, bl)
    local ok = L:Dispel_ApplyTint(b.dispelTint, b.dispelTint2, b.health, r, g, bl)
    b.dispelTintFrame:SetShown(ok and true or false)
end

-- Dispel highlight style (Indicators > Dispels): border & glow, health bar
-- color, or both. The color may be a hidden (secret) value in combat; it is
-- only ever passed to widget setters (inside pcall), never compared.
local function DispelStyle()
    local s = L.db and L.db.dispelStyle
    return s == "BAR" or s == "BOTH", s ~= "BAR"
end

local function ShowDispel(b, r, g, bl)
    local bar, border = DispelStyle()
    if bar then
        -- the bar texture can change (Textures & Colors), so copy it each time
        local fill = b.health:GetStatusBarTexture()
        local file = fill and fill:GetTexture()
        b.dispelBarTex:SetTexture(file or WHITE)
        local ok = L:Dispel_ApplyBar(b.dispelBarTex, r, g, bl)
        b.dispelBarFrame:SetShown(ok and true or false)
        if not ok then border = true end
    else
        b.dispelBarFrame:Hide()
    end
    if border then
        L.SetBorderColor(b.dispel, 1, 1, 1, 1)
        L:Dispel_BorderSize(b.dispel, L.db.dispelBorderSize or 2)
        for _, tex in ipairs(b.dispel.__border) do pcall(tex.SetVertexColor, tex, r, g, bl, 1) end
        TintDispel(b, r, g, bl)
        b.dispel:Show()
    else
        b.dispel:Hide()
        b.dispelTintFrame:Hide()
    end
end

local function HideDispel(b)
    b.dispel:Hide()
    b.dispelTintFrame:Hide()
    b.dispelBarFrame:Hide()
end

function L:Dispel_Show(b, r, g, bl) ShowDispel(b, r, g, bl) end
function L:Dispel_Hide(b) HideDispel(b) end

-- sample frames (Example, preview, /ll showcase)
function L:Dispel_UpdateFake(b)
    local d = L.db.dispelHighlight and b.fake.dispel
    if d then
        local c = DispelColors()[d]
        ShowDispel(b, c[1], c[2], c[3])
    else
        HideDispel(b)
    end
end

-- real frames (called from Button_UpdateAuras)
function L:Dispel_Update(b)
    local unit = b.unit
    local gameDraws = L.AC_DrawsDispel and L:AC_DrawsDispel(b)
    local found = (L.db.dispelHighlight and not gameDraws) and FindDispellable(unit) or nil
    local aura = L.db.dispelHighlight and not gameDraws and found
    if aura then
        local painted = false
        local curve = GetDispelCurve()
        if curve and GetAuraDispelTypeColor and aura.auraInstanceID then
            painted = pcall(function()
                local col = GetAuraDispelTypeColor(unit, aura.auraInstanceID, curve)
                local r, g, bl = col:GetRGB()
                ShowDispel(b, r, g, bl)
            end)
        end
        if not painted then
            local key = Readable(aura.dispelName)
            local c = key and DispelColors()[key] or DEFAULT_DISPEL
            ShowDispel(b, c[1], c[2], c[3])
        end
    else
        HideDispel(b)
    end
end
