--[[
    Lifeline - Low mana warning and the /ll showcase preview

    Low mana (Indicators > Status Effects > Tags, off by default): a small LOW MANA tag (bottom right) on players
    (healers only, by default) whose mana drops below a set percent. In combat
    the game may hide mana values; then the game's percent curve decides
    whether the tag shows, so no secret numbers are compared.

    /ll showcase: the preview with every indicator switched on, so you can see
    everything Lifeline can show at once. Your settings aren't changed.
]]

local _, L = ...

------------------------------------------------------------------------
-- Low mana
------------------------------------------------------------------------
local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local manaCurve, curvePct

local function Curve(pct)
    if curvePct == pct and manaCurve ~= nil then return manaCurve or nil end
    curvePct, manaCurve = pct, false
    if C_CurveUtil and C_CurveUtil.CreateCurve then
        local ok, c = pcall(function()
            local curve = C_CurveUtil.CreateCurve()
            if Enum and Enum.LuaCurveType and curve.SetType then curve:SetType(Enum.LuaCurveType.Step) end
            curve:AddPoint(0, 1)            -- below the threshold: fully visible
            curve:AddPoint(pct / 100, 0)    -- at / above it: hidden
            return curve
        end)
        if ok and c then manaCurve = c end
    end
    return manaCurve or nil
end

local function EnsureTag(b)
    if b.lowMana then return b.lowMana end
    -- its own layer: above every icon (incoming cast, res & ready check,
    -- big debuff), below the banners (which mean more than low mana)
    local f = CreateFrame("Frame", nil, b.overlay)
    f:SetAllPoints(b.overlay)
    f:SetFrameLevel(b.overlay:GetFrameLevel() + L.LAYER_LOWMANA)
    local t = f:CreateFontString(nil, "OVERLAY")
    t:SetFont(L:FrameFont(), 8, "OUTLINE")   -- a font must be set before any text
    t:SetTextColor(0.45, 0.72, 1)
    t:SetText("LOW MANA")
    t:Hide()
    b.lowMana = t
    return t
end

function L:LowMana_Style(b)
    local t = EnsureTag(b)
    t:SetFont(L:FrameFont(), 8, "OUTLINE")
    t:ClearAllPoints()
    local x, y = L.ElementOffset("lowMana")
    t:SetPoint("BOTTOMRIGHT", b.health, "BOTTOMRIGHT", -2 + x, 2 + y)
end

function L:LowMana_Update(b)
    local t = EnsureTag(b)
    local cfg = L.db.lowMana
    t:SetAlpha(1)
    if not cfg or not cfg.enabled then t:Hide() return end
    if b.fake then
        local f = b.fake
        local ok = f.power == "MANA" and not f.dead and (f.pp or 100) < cfg.percent
            and (not cfg.healersOnly or f.role == "HEALER")
        t:SetShown(ok and true or false)
        return
    end
    local unit = b.unit
    if not unit or L.SafeBool(UnitIsDeadOrGhost, unit) or L.SafeBool(UnitIsConnected, unit) == false then t:Hide() return end
    if cfg.healersOnly and L.Readable(UnitGroupRolesAssigned(unit)) ~= "HEALER" then t:Hide() return end
    local ptype = L.Readable((UnitPowerType(unit)))
    if ptype ~= nil and ptype ~= MANA then t:Hide() return end

    local cur, max = L.Readable(UnitPower(unit, MANA)), L.Readable(UnitPowerMax(unit, MANA))
    if cur and max then
        t:SetShown(max > 0 and cur / max * 100 < cfg.percent)
        return
    end
    -- secret mana: let the game turn the percent into an opacity
    local curve = Curve(cfg.percent)
    if curve and UnitPowerPercent then
        local ok = pcall(function()
            local a = UnitPowerPercent(unit, MANA, false, curve)
            t:Show()
            t:SetAlpha(a)
        end)
        if ok then return end
    end
    t:Hide()
end

hooksecurefunc(L, "Button_Init", function(_, b) L:LowMana_Style(b) L:LowMana_Update(b) end)
hooksecurefunc(L, "Button_ApplyStyle", function(_, b) if b.lowMana then L:LowMana_Style(b) end end)
hooksecurefunc(L, "Button_UpdatePower", function(_, b) L:LowMana_Update(b) end)
hooksecurefunc(L, "Button_UpdateAll", function(_, b) L:LowMana_Update(b) end)

------------------------------------------------------------------------
-- /ll showcase
------------------------------------------------------------------------
local showcase = false

local function ShowcaseDB(real)
    local function on(t, extra)
        local o = { enabled = true }
        for k, v in pairs(extra or {}) do o[k] = v end
        return setmetatable(o, { __index = t })
    end
    local over = {
        showRole = true, showLeader = true, showRaidIcon = true, showReadyCheck = true, showResurrect = true,
        showDrinking = true, showAggro = true, showTargetHL = true, showRaidRoles = true,
        showThreatIcon = true, threatIconLow = true, showAFK = true, statusTimer = true,
        showHealPred = true, showAbsorb = true, showDebuffs = true, showBuffs = true,
        dispelHighlight = true, bigBossDebuffs = true, rangeFade = true,
        overheal = (real.overheal == "OFF") and "INSIDE" or real.overheal,
        castBar = on(real.castBar), incoming = on(real.incoming),
        lowMana = on(real.lowMana, { healersOnly = false }),
    }
    return setmetatable({}, {
        __index = function(_, k)
            local v = over[k]
            if v ~= nil then return v end
            return real[k]
        end,
        __newindex = function(_, k, v) real[k] = v end,
    })
end

-- only the sample frames see the showcase settings, and only while drawing
local origRefresh = L.Preview_Refresh
function L:Preview_Refresh(...)
    if not showcase then return origRefresh(self, ...) end
    local real = L.db
    L.db = ShowcaseDB(real)
    local ok, err = pcall(origRefresh, self, ...)
    L.db = real
    if not ok and geterrorhandler then geterrorhandler()(err) end
end

hooksecurefunc(L, "Preview_Hide", function() showcase = false end)

function L:Showcase_Toggle()
    if showcase then
        L:Preview_Hide()
        L:Print("Showcase closed.")
        return
    end
    if InCombatLockdown() then L:Print("The showcase isn't available in combat.") return end
    showcase = true
    L:Preview_Show("raid25")
    if not L:Preview_IsShown() then showcase = false return end
    L:Print("Showcase: every indicator is switched on in this preview (your settings are unchanged). Type /ll showcase again to close it.")
end
