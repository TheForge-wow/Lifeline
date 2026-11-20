--[[
    Lifeline - Unit buttons
    Builds the visuals for each secure unit button and keeps them updated.
    Everything that may be a secret value is either handed straight to a
    widget (which is allowed) or checked with L.Readable() first.

    Other files add their pieces to every frame by hooking these methods
    (hooksecurefunc runs them right after the method here, in TOC order):
      Button_Init        AuraContainers (game aura icons), AuraExtras (big
                         debuff), CastBars (cast bar, incoming icon),
                         Extras (LOW MANA tag), ClickCast (bindings)
      Button_ApplyStyle  AuraExtras, CastBars, Extras: re-place their pieces
      Button_UpdateAll   CastBars, Extras
      Button_UpdateAuras Indicators (buff indicators, DRINKING), AuraExtras
                         (big debuff), StatusEffects (banners, SOULSTONE)
    The dispel highlight is in Dispels.lua (called from Button_UpdateAuras).
      Button_UpdatePower Extras (LOW MANA)
      Button_SetUnit     AuraContainers, CastBars
    Rule: a hook creates its widgets in Button_Init and never sets text on a
    FontString before giving it a font.
]]

local _, L = ...
local C, WHITE = L.C, L.WHITE
local Readable, IsSecret = L.Readable, L.IsSecret

local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax, UnitPowerType = UnitPower, UnitPowerMax, UnitPowerType
local UnitExists, UnitIsConnected, UnitIsDeadOrGhost, UnitIsGhost = UnitExists, UnitIsConnected, UnitIsDeadOrGhost, UnitIsGhost
local UnitIsAFK = UnitIsAFK or function() return false end
local UnitClass, UnitName, UnitIsUnit, UnitInRange = UnitClass, UnitName, UnitIsUnit, UnitInRange
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitGetIncomingHeals, UnitGetTotalAbsorbs = UnitGetIncomingHeals, UnitGetTotalAbsorbs
local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local GetAuraDuration = C_UnitAuras and C_UnitAuras.GetAuraDuration
local GetAuraDisplayCount = C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount
local UnitHealthPercent = _G.UnitHealthPercent
local pcall = pcall

local buttons   = {}   -- every initialized button
local byUnit    = {}   -- unit -> { [button] = true }
L.buttons = buttons

------------------------------------------------------------------------
-- Colors (dispel colors live in Dispels.lua)
------------------------------------------------------------------------
-- Blizzard's color for a class (or a !ClassColors-style override addon's)
function L:DefaultClassColor(class)
    local c = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
    if c then return c.r, c.g, c.b end
    return 0.5, 0.5, 0.5
end

-- The color Lifeline uses for a class: your override (Bars & Text > Class
-- colors) if you set one, then darkened by the "Darken class colors" slider.
function L:GetClassColor(class)
    local r, g, b
    local o = class and L.db.classColors and L.db.classColors[class]
    if o then r, g, b = o.r, o.g, o.b
    else r, g, b = L:DefaultClassColor(class) end
    local d = (L.db.classDarken or 0) / 100
    if d > 0 then
        local f = 1 - d
        r, g, b = r * f, g * f, b * f
    end
    return r, g, b
end

local function ClassColor(unit)
    if L.IsPetUnit and L.IsPetUnit(unit) then
        local c = L.PET_COLOR
        return c[1], c[2], c[3]
    end
    local _, class = UnitClass(unit)
    class = Readable(class)
    if not class then return 0.5, 0.5, 0.5 end
    return L:GetClassColor(class)
end

------------------------------------------------------------------------
-- Construction helpers
------------------------------------------------------------------------
local function Bar(parent, layer)
    local s = CreateFrame("StatusBar", nil, parent)
    s:SetStatusBarTexture(L.BarTexture and L.db and L:BarTexture() or WHITE)
    s:SetMinMaxValues(0, 1)
    s:SetValue(1)
    if layer then s:SetFrameLevel(parent:GetFrameLevel() + layer) end
    return s
end

local function Icon(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 1)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetPoint("TOPLEFT", 1, -1)
    f.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cd:SetAllPoints(f.tex)
    f.cd:SetReverse(true)
    f.cd:SetDrawEdge(false)
    if f.cd.SetHideCountdownNumbers then f.cd:SetHideCountdownNumbers(true) end
    f.count = f:CreateFontString(nil, "OVERLAY")
    f.count:SetFont(L.FONT, 9, "OUTLINE")
    f.count:SetPoint("BOTTOMRIGHT", 1, 0)
    f:Hide()
    return f
end

L.NewAuraIcon = Icon

------------------------------------------------------------------------
-- Button initialization (called for header children *and* preview frames)
------------------------------------------------------------------------
-- every mouse button, on release. Done from Lua only out of combat (a button
-- spawned mid-fight gets it from the header's secure init, or right after combat)
local function RegisterClicks(b)
    if InCombatLockdown() then
        L:RunAfterCombat("registerclicks", function()
            for _, x in ipairs(L.buttons) do
                if not x.fake and not x.__llClicks then x:RegisterForClicks("AnyUp") x.__llClicks = true end
            end
        end)
        return
    end
    b:RegisterForClicks("AnyUp")
    b.__llClicks = true
end

function L:Button_Init(b)
    if b.__ll then return end
    b.__ll = true
    if not b.fake and b.RegisterForClicks then RegisterClicks(b) end

    local content = CreateFrame("Frame", nil, b)
    content:SetAllPoints()
    b.content = content

    -- background (missing-health color)
    b.bg = content:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()

    b.health = Bar(content, 1)
    b.healthBG = b.health:CreateTexture(nil, "BACKGROUND")
    b.healthBG:SetAllPoints()
    b.healthBG:SetColorTexture(0, 0, 0, 0)

    -- incoming heals / absorbs anchored to the end of the health fill.
    -- They're children of the health bar, which clips them, so overhealing
    -- stops at the frame edge instead of spilling past it.
    b.health:SetClipsChildren(true)
    b.healPred = Bar(b.health, 1)
    b.healPred:SetStatusBarColor(C.accent[1], C.accent[2], C.accent[3], 0.45)
    b.absorb = Bar(b.health, 1)
    b.absorb:SetStatusBarColor(1, 1, 1, 0.35)

    -- overheal: an invisible copy of the health bar carries a second heal bar.
    -- Only the part of that heal bar that sticks out past the copy's right
    -- edge is visible (through a narrow clipping strip), so it shows exactly
    -- how much of the incoming heal is wasted - without the addon ever having
    -- to compare health numbers, which the game may keep secret in combat.
    b.ohHost = Bar(content, 1)
    b.ohHost:SetStatusBarColor(0, 0, 0, 0)
    b.ohClip = CreateFrame("Frame", nil, content)
    b.ohClip:SetClipsChildren(true)
    b.ohClip:SetFrameLevel(content:GetFrameLevel() + 3)
    b.overheal = Bar(b.ohClip, 1)
    b.overheal:SetStatusBarColor(0.80, 1.00, 0.88, 0.90)

    b.power = Bar(content, 1)
    b.powerBG = b.power:CreateTexture(nil, "BACKGROUND")
    b.powerBG:SetAllPoints()
    b.powerBG:SetColorTexture(0, 0, 0, 0.8)

    -- overlay layer for text & icons
    local ov = CreateFrame("Frame", nil, content)
    ov:SetAllPoints()
    ov:SetFrameLevel(content:GetFrameLevel() + 5)
    b.overlay = ov

    b.name = ov:CreateFontString(nil, "OVERLAY")
    b.name:SetWordWrap(false)
    b.name:SetJustifyH("CENTER")
    b.name:SetShadowOffset(1, -1)

    b.status = ov:CreateFontString(nil, "OVERLAY")
    b.status:SetWordWrap(false)
    b.status:SetJustifyH("CENTER")
    b.status:SetShadowOffset(1, -1)

    b.role = ov:CreateTexture(nil, "OVERLAY")
    b.role:SetSize(11, 11)
    b.role:SetPoint("TOPLEFT", 2, -2)

    b.leader = ov:CreateTexture(nil, "OVERLAY")
    b.leader:SetSize(10, 10)
    b.leader:SetPoint("LEFT", b.role, "RIGHT", 1, 0)

    -- main tank / main assist (raid roles set by the raid leader)
    b.raidRole = ov:CreateTexture(nil, "OVERLAY")
    b.raidRole:SetSize(10, 10)
    b.raidRole:Hide()

    -- threat level square: yellow (high threat), orange (pulling), red (tanking)
    b.threatIcon = CreateFrame("Frame", nil, ov)
    b.threatIcon:SetSize(8, 8)
    local tb = b.threatIcon:CreateTexture(nil, "BACKGROUND")
    tb:SetAllPoints() tb:SetColorTexture(0, 0, 0, 1)
    b.threatIcon.tex = b.threatIcon:CreateTexture(nil, "ARTWORK")
    b.threatIcon.tex:SetPoint("TOPLEFT", 1, -1)
    b.threatIcon.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    b.threatIcon:Hide()

    b.raidIcon = ov:CreateTexture(nil, "OVERLAY")
    b.raidIcon:SetSize(13, 13)
    b.raidIcon:SetPoint("TOP", 0, -1)
    b.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")

    -- ready check / resurrection / summon icon: on its own frame above the
    -- text layer, so it's drawn in front of the name instead of behind it
    b.centerHolder = CreateFrame("Frame", nil, ov)
    b.centerHolder:SetAllPoints()
    b.centerHolder:SetFrameLevel(ov:GetFrameLevel() + 10)
    b.center = b.centerHolder:CreateTexture(nil, "OVERLAY", nil, 7)
    b.center:SetSize(18, 18)
    b.center:SetPoint("CENTER")

    -- borders: aggro, target, mouseover, dispel
    local function frameBorder(level, size)
        local f = CreateFrame("Frame", nil, content)
        f:SetAllPoints()
        f:SetFrameLevel(content:GetFrameLevel() + level)
        L.AddBorder(f, { 0, 0, 0, 1 }, size)
        return f
    end
    b.border = frameBorder(4, 1)          -- always-on 1px dark edge
    b.aggro = frameBorder(5, 2)           -- red border when the unit has aggro
    L.SetBorderColor(b.aggro, 1, 0.15, 0.15, 1)
    b.aggro:Hide()
    b.targetHL = frameBorder(6, 1)
    L.SetBorderColor(b.targetHL, 1, 1, 1, 1)
    b.targetHL:Hide()
    b.hoverHL = content:CreateTexture(nil, "OVERLAY")
    b.hoverHL:SetAllPoints(b.health)
    b.hoverHL:SetColorTexture(1, 1, 1, 0.08)
    b.hoverHL:Hide()

    b.dispel = frameBorder(6, 2)
    b.dispel:Hide()
    -- the tint lives on its own layer *below* the name/health text, so a
    -- dispellable debuff never hides who the player is
    b.dispelTintFrame = CreateFrame("Frame", nil, content)
    b.dispelTintFrame:SetAllPoints(b.health)
    b.dispelTintFrame:SetFrameLevel(content:GetFrameLevel() + 3)
    b.dispelTint = b.dispelTintFrame:CreateTexture(nil, "ARTWORK")
    b.dispelTint:SetAllPoints()
    b.dispelTint:SetTexture(WHITE)
    b.dispelTint2 = b.dispelTintFrame:CreateTexture(nil, "ARTWORK")
    b.dispelTint2:SetTexture(WHITE)
    b.dispelTint2:Hide()
    b.dispelTintFrame:Hide()
    -- "Debuff tint on the bar": a colored layer over the fill, below the text
    b.dispelBarFrame = CreateFrame("Frame", nil, content)
    b.dispelBarFrame:SetAllPoints(b.health)
    b.dispelBarFrame:SetFrameLevel(content:GetFrameLevel() + 2)
    b.dispelBarTex = b.dispelBarFrame:CreateTexture(nil, "ARTWORK")
    b.dispelBarTex:SetAllPoints(b.health:GetStatusBarTexture())
    b.dispelBarFrame:Hide()

    -- aura icons
    b.debuffs, b.buffs = {}, {}
    for i = 1, 5 do
        b.debuffs[i] = Icon(ov, 16)
        b.buffs[i] = Icon(ov, 14)
    end

    if not b.fake then
        b:HookScript("OnAttributeChanged", function(self, name)
            if name == "unit" then L:Button_SetUnit(self, self:GetAttribute("unit")) end
        end)
        b:HookScript("OnShow", function(self) L:Button_SetUnit(self, self:GetAttribute("unit")) end)
        b:HookScript("OnHide", function(self) L:Button_SetUnit(self, nil) end)
        b:HookScript("OnEnter", function(self)
            if L.db.showMouseoverHL then self.hoverHL:Show() end
            local mode = L.db.tooltipMode
            local allowed = mode == "ALWAYS" or (mode ~= "NEVER" and not InCombatLockdown())
            if self.unit and allowed then
                GameTooltip_SetDefaultAnchor(GameTooltip, self)
                GameTooltip:SetUnit(self.unit)
                local lines = L.db.tooltipBindings and L.CC_TooltipLines and L:CC_TooltipLines()
                if lines and #lines > 0 then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Click-casting", C.accent[1], C.accent[2], C.accent[3])
                    for _, ln in ipairs(lines) do
                        GameTooltip:AddDoubleLine(ln[1], ln[2], 0.75, 0.78, 0.82, 1, 1, 1)
                    end
                end
                GameTooltip:Show()
            end
        end)
        b:HookScript("OnLeave", function(self)
            self.hoverHL:Hide()
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        -- let Clique / other click-cast addons see us
        ClickCastFrames = ClickCastFrames or {}
        ClickCastFrames[b] = true
    end

    buttons[#buttons + 1] = b
    L:Button_ApplyStyle(b)
    if not b.fake then L:Button_SetUnit(b, b:GetAttribute("unit")) end
end

-- user nudge for an element (Indicators > Element positions)
local function Off(key)
    local o = L.db.offsets and L.db.offsets[key]
    if not o then return 0, 0 end
    return o.x or 0, o.y or 0
end
L.ElementOffset = Off

-- where the name's center sits vertically (before the drinking banner shift)
function L:NameBaseY()
    local db = L.db
    local _, oy = Off("name")
    return ((db.healthText == "NONE") and 0 or (db.healthTextSize * 0.55)) + oy
end

------------------------------------------------------------------------
-- Sample frames (preview, example panel, pet preview) share one builder
------------------------------------------------------------------------
-- fake: the sample's data table; tip: optional { title, text } tooltip
function L:CreateFakeButton(parent, fake, tip)
    local b = CreateFrame("Button", nil, parent)
    b.fake = fake
    L:Button_Init(b)
    b:EnableMouse(true)
    b:SetScript("OnEnter", function(s)
        if L.db.showMouseoverHL then s.hoverHL:Show() end
        if tip then
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine(tip[1], C.accent[1], C.accent[2], C.accent[3])
            GameTooltip:AddLine(tip[2], 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(s)
        s.hoverHL:Hide()
        if tip then GameTooltip:Hide() end
    end)
    return b
end

------------------------------------------------------------------------
-- Style (sizes/fonts/positions that depend on settings)
------------------------------------------------------------------------
-- fill directions: which edge the bar grows toward, its corners on that
-- edge, and a unit vector pointing that way
local FILL = {
    LEFT_TO_RIGHT = { orient = "HORIZONTAL", reverse = false, edge = "RIGHT",  ends = { "TOPRIGHT", "BOTTOMRIGHT" }, vec = { 1, 0 } },
    RIGHT_TO_LEFT = { orient = "HORIZONTAL", reverse = true,  edge = "LEFT",   ends = { "TOPLEFT", "BOTTOMLEFT" },   vec = { -1, 0 } },
    BOTTOM_TO_TOP = { orient = "VERTICAL",   reverse = false, edge = "TOP",    ends = { "TOPLEFT", "TOPRIGHT" },     vec = { 0, 1 } },
    TOP_TO_BOTTOM = { orient = "VERTICAL",   reverse = true,  edge = "BOTTOM", ends = { "BOTTOMLEFT", "BOTTOMRIGHT" }, vec = { 0, -1 } },
}
local OPPOSITE = { LEFT = "RIGHT", RIGHT = "LEFT", TOP = "BOTTOM", BOTTOM = "TOP" }
-- the same corner on the other side of the bar: TOPRIGHT -> TOPLEFT for edge RIGHT
local function FlipEnd(corner, edge)
    return (corner:gsub(edge, OPPOSITE[edge]))
end

function L:Button_ApplyStyle(b)
    local db = L.db
    local ph = db.showPower and db.powerHeight or 0

    b.health:ClearAllPoints()
    b.health:SetPoint("TOPLEFT", 1, -1)
    b.health:SetPoint("BOTTOMRIGHT", -1, 1 + (ph > 0 and (ph + 1) or 0))

    b.power:ClearAllPoints()
    b.power:SetPoint("BOTTOMLEFT", 1, 1)
    b.power:SetPoint("BOTTOMRIGHT", -1, 1)
    b.power:SetHeight(math.max(1, ph))
    b.power:SetShown(ph > 0)

    -- textures
    local tex = L:BarTexture()
    for _, bar in ipairs({ b.health, b.power, b.healPred, b.absorb, b.overheal }) do bar:SetStatusBarTexture(tex) end

    -- fill direction: health and every bar hanging off its end follow it
    local dir = FILL[db.fillDirection or "LEFT_TO_RIGHT"] or FILL.LEFT_TO_RIGHT
    local vertical = dir.orient == "VERTICAL"
    for _, bar in ipairs({ b.health, b.healPred, b.absorb, b.ohHost, b.overheal }) do
        bar:SetOrientation(dir.orient)
        bar:SetReverseFill(dir.reverse)
    end
    local c1, c2 = dir.ends[1], dir.ends[2]
    local function hang(child, parentFill)
        child:ClearAllPoints()
        child:SetPoint(FlipEnd(c1, dir.edge), parentFill, c1)
        child:SetPoint(FlipEnd(c2, dir.edge), parentFill, c2)
    end
    local function length() return vertical and b.health:GetHeight() or b.health:GetWidth() end
    local function setLen(bar, len)
        len = math.max(1, len or length())
        if vertical then bar:SetHeight(len) else bar:SetWidth(len) end
    end
    -- heals start where health ends; absorbs start where heals end
    hang(b.healPred, b.health:GetStatusBarTexture())
    hang(b.absorb, b.healPred:GetStatusBarTexture())
    setLen(b.healPred) setLen(b.absorb)

    -- overheal strip: past the end of the bar ("OUTSIDE") or over its last
    -- few pixels ("INSIDE", for frames that sit side by side)
    local ohMode, ohW = db.overheal or "OFF", db.overhealWidth or 8
    local shift = (ohMode == "INSIDE") and ohW or 0
    local vx, vy = dir.vec[1] * shift, dir.vec[2] * shift
    b.ohHost:ClearAllPoints()
    b.ohHost:SetPoint("TOPLEFT", b.health, "TOPLEFT", -vx, -vy)
    b.ohHost:SetPoint("BOTTOMRIGHT", b.health, "BOTTOMRIGHT", -vx, -vy)
    b.ohClip:ClearAllPoints()
    if ohMode == "INSIDE" then
        b.ohClip:SetPoint(c1, b.health, c1)
        b.ohClip:SetPoint(c2, b.health, c2)
    else
        b.ohClip:SetPoint(FlipEnd(c1, dir.edge), b.health, c1)
        b.ohClip:SetPoint(FlipEnd(c2, dir.edge), b.health, c2)
    end
    if vertical then b.ohClip:SetHeight(ohW) else b.ohClip:SetWidth(ohW) end
    b.ohClip:SetShown(ohMode ~= "OFF" and db.showHealPred)
    b.ohHost:SetShown(ohMode ~= "OFF" and db.showHealPred)
    hang(b.overheal, b.ohHost:GetStatusBarTexture())
    setLen(b.overheal)

    b.health:SetScript("OnSizeChanged", function(self, w, h)
        local len = vertical and h or w
        setLen(b.healPred, len) setLen(b.absorb, len) setLen(b.overheal, len)
    end)

    local font = L:FrameFont()
    local flags = L:TextOutlineFlags()
    L:SetNameFont(b.name, db.nameSize, flags)
    b.status:SetFont(font, db.healthTextSize, flags)
    L:TextOutlineShadow(b.name)
    L:TextOutlineShadow(b.status)
    b.name:ClearAllPoints()
    b.status:ClearAllPoints()
    local nx = Off("name")
    b.name:SetPoint("LEFT", b.health, "LEFT", 3 + nx, 0)
    b.name:SetPoint("RIGHT", b.health, "RIGHT", -3 + nx, 0)
    b.name:SetPoint("CENTER", b.health, "CENTER", nx, L:NameBaseY())
    -- health text sits under the name (and moves with it); its own nudge adds on top
    local sx, sy = Off("status")
    b.status:SetPoint("TOP", b.name, "BOTTOM", sx, -1 + sy)
    b.status:SetPoint("LEFT", b.health, "LEFT", 2 + sx, 0)
    b.status:SetPoint("RIGHT", b.health, "RIGHT", -2 + sx, 0)

    local x, y = Off("role")
    b.role:ClearAllPoints()
    b.role:SetPoint("TOPLEFT", 2 + x, -2 + y)
    x, y = Off("raidIcon")
    b.raidIcon:ClearAllPoints()
    b.raidIcon:SetPoint("TOP", x, -1 + y)
    x, y = Off("threat")
    b.threatIcon:ClearAllPoints()
    b.threatIcon:SetPoint("RIGHT", b.health, "RIGHT", -2 + x, y)
    x, y = Off("center")
    b.center:ClearAllPoints()
    b.center:SetPoint("CENTER", x, y)

    local reserve = L.Ind_Positions and L:Ind_Positions().reserve or {}
    for i, ic in ipairs(b.debuffs) do
        ic:SetSize(db.debuffSize, db.debuffSize)
        ic:ClearAllPoints()
        local dx, dy = Off("debuffs")
        dx = dx + (reserve.BOTTOMLEFT or 0)
        if i == 1 then ic:SetPoint("BOTTOMLEFT", b.health, "BOTTOMLEFT", 1 + dx, 1 + dy)
        else ic:SetPoint("LEFT", b.debuffs[i - 1], "RIGHT", 1, 0) end
    end
    for i, ic in ipairs(b.buffs) do
        ic:SetSize(db.buffSize, db.buffSize)
        ic:ClearAllPoints()
        local bx, by = Off("buffs")
        bx = bx - (reserve.TOPRIGHT or 0)
        if i == 1 then ic:SetPoint("TOPRIGHT", b.health, "TOPRIGHT", -1 + bx, -1 + by)
        else ic:SetPoint("RIGHT", b.buffs[i - 1], "LEFT", -1, 0) end
    end
end

------------------------------------------------------------------------
-- Unit mapping
------------------------------------------------------------------------
function L:Button_SetUnit(b, unit)
    if b.unit and byUnit[b.unit] then byUnit[b.unit][b] = nil end
    b.unit = unit
    if unit then
        byUnit[unit] = byUnit[unit] or {}
        byUnit[unit][b] = true
        L:Button_UpdateAll(b)
    end
end

local function ForUnit(unit, fn)
    local set = byUnit[unit]
    if not set then return end
    for b in pairs(set) do
        if b.unit == unit and b:IsVisible() then fn(b) end
    end
end
L.ForUnit = ForUnit

------------------------------------------------------------------------
-- Updates
------------------------------------------------------------------------
-- hand (possibly secret) values straight to the bar; pcall covers nil / odd values
local function SafeSet(bar, maxV, value)
    pcall(bar.SetMinMaxValues, bar, 0, maxV)
    pcall(bar.SetValue, bar, value)
end

local function IsDead(unit)
    return L.SafeBool(UnitIsDeadOrGhost, unit)
end
local function IsOffline(unit)
    local v = L.SafeBool(UnitIsConnected, unit)
    return v == false
end

------------------------------------------------------------------------
-- Status timers: remember when each player went dead / offline / AFK.
-- Keyed by GUID (or name) so it survives the roster shuffling unit tokens.
------------------------------------------------------------------------
local statusSince = {}
local function StatusKey(unit)
    return L.Readable(UnitGUID(unit)) or L.Readable((UnitName(unit))) or unit
end
-- dead and ghost share one timer: releasing doesn't restart the clock
local TIMER_GROUP = { DEAD = "DEAD", GHOST = "DEAD", OFFLINE = "OFFLINE", AFK = "AFK" }

-- returns seconds in this state (and starts the clock), or clears it with state = nil
function L:StatusSince(unit, state)
    local key = StatusKey(unit)
    if not key then return nil end
    if not state then statusSince[key] = nil return nil end
    local group = TIMER_GROUP[state] or state
    local e = statusSince[key]
    if not e or e.group ~= group then
        e = { group = group, t = GetTime() }
        statusSince[key] = e
    end
    return GetTime() - e.t
end

local function FormatTime(sec)
    sec = math.floor(sec or 0)
    local floor = math.floor
    if sec >= 3600 then return ("%dh %02dm"):format(floor(sec / 3600), floor((sec % 3600) / 60)) end
    return ("%d:%02d"):format(floor(sec / 60), sec % 60)
end
L.FormatStatusTime = FormatTime

function L:StatusText(state, seconds)
    if seconds then return state .. "  " .. FormatTime(seconds) end
    return state
end

-- forget players who left the group
L:On("GROUP_ROSTER_UPDATE", function()
    local keep = {}
    local function mark(u) if L.SafeBool(UnitExists, u) then local k = StatusKey(u) if k then keep[k] = true end end end
    mark("player")
    for i = 1, 4 do mark("party" .. i) end
    for i = 1, 40 do mark("raid" .. i) end
    for k in pairs(statusSince) do if not keep[k] then statusSince[k] = nil end end
end)

function L:Button_UpdateColors(b)
    local db, unit = L.db, b.unit
    local r, g, bl
    if b.fake and b.fake.class then r, g, bl = L:GetClassColor(b.fake.class)
    elseif b.fake then r, g, bl = b.fake.r, b.fake.g, b.fake.b
    else r, g, bl = ClassColor(unit) end

    local dead = b.fake and b.fake.dead or (unit and IsDead(unit))
    local off  = (not b.fake) and unit and (IsOffline(unit)) or (b.fake and b.fake.offline)
    local dark = db.bgDarkness
    local ba, bga = db.barAlpha or 1, db.bgAlpha or 1

    if dead or off then
        local d = db.deadColor or { r = 0.12, g = 0.12, b = 0.12 }
        b.health:SetStatusBarColor(0.25, 0.25, 0.25, ba)
        b.bg:SetColorTexture(d.r, d.g, d.b, bga)
    elseif db.healthColor == "DARK" then
        b.health:SetStatusBarColor(0.16, 0.17, 0.19, ba)
        b.bg:SetColorTexture(r * (1 - dark * 0.5), g * (1 - dark * 0.5), bl * (1 - dark * 0.5), bga)
    elseif db.healthColor == "CUSTOM" then
        local c = db.customHealth
        b.health:SetStatusBarColor(c.r, c.g, c.b, ba)
        b.bg:SetColorTexture(c.r * (1 - dark), c.g * (1 - dark), c.b * (1 - dark), bga)
    else
        b.health:SetStatusBarColor(r, g, bl, ba)
        b.bg:SetColorTexture(r * (1 - dark), g * (1 - dark), bl * (1 - dark), bga)
    end

    if db.nameClassColor then
        b.name:SetTextColor(r, g, bl)
    else
        b.name:SetTextColor(1, 1, 1)
    end
    b.status:SetTextColor(0.85, 0.87, 0.90)
end

function L:Button_UpdateName(b)
    if b.fake then b.name:SetText(b.fake.name) return end
    pcall(b.name.SetText, b.name, UnitName(b.unit))
end

function L:Button_UpdateHealth(b)
    local db, unit = L.db, b.unit
    if b.fake then
        b.health:SetMinMaxValues(0, 100)
        b.health:SetValue(b.fake.dead and 0 or b.fake.hp)
        local heal = b.fake.heal or 0
        if db.healPredMineOnly and (b.fake.index or 0) % 2 == 0 then heal = 0 end
        b.healPred:SetMinMaxValues(0, 100)
        b.healPred:SetValue(db.showHealPred and heal or 0)
        b.ohHost:SetMinMaxValues(0, 100)
        b.ohHost:SetValue(b.fake.dead and 0 or b.fake.hp)
        b.overheal:SetMinMaxValues(0, 100)
        b.overheal:SetValue(db.showHealPred and heal or 0)
        b.absorb:SetMinMaxValues(0, 100)
        b.absorb:SetValue((db.showAbsorb and b.fake.absorb) or 0)
        local fakeState = b.fake.dead and "DEAD" or (b.fake.offline and "OFFLINE") or (b.fake.afk and db.showAFK and "AFK")
        if fakeState then
            b.status:SetText(L:StatusText(fakeState, db.statusTimer and b.fake.since))
        elseif db.healthText == "PERCENT" then b.status:SetText(b.fake.hp .. "%")
        elseif db.healthText == "DEFICIT" then b.status:SetText(b.fake.hp < 100 and ("-" .. (100 - b.fake.hp) * 120) or "")
        else b.status:SetText("") end
        return
    end
    if not unit then return end

    local maxHP, curHP = UnitHealthMax(unit), UnitHealth(unit)
    SafeSet(b.health, maxHP, curHP)

    if db.showHealPred and UnitGetIncomingHeals then
        b.healPred:Show()
        local inc
        if db.healPredMineOnly then
            inc = UnitGetIncomingHeals(unit, "player")
        else
            inc = UnitGetIncomingHeals(unit)
        end
        SafeSet(b.healPred, maxHP, inc)
        if (db.overheal or "OFF") ~= "OFF" then
            SafeSet(b.ohHost, maxHP, curHP)
            SafeSet(b.overheal, maxHP, inc)
        end
    else
        b.healPred:Hide()
    end
    if db.showAbsorb and UnitGetTotalAbsorbs then
        b.absorb:Show()
        SafeSet(b.absorb, maxHP, UnitGetTotalAbsorbs(unit))
    else
        b.absorb:Hide()
    end

    -- status text (with how long they've been dead / offline / AFK)
    local state
    if IsOffline(unit) then state = "OFFLINE"
    elseif IsDead(unit) then state = L.SafeBool(UnitIsGhost, unit) and "GHOST" or "DEAD"
    elseif db.showAFK and L.SafeBool(UnitIsAFK, unit) then state = "AFK" end
    b.statusState = state
    if state then
        b.status:SetText(L:StatusText(state, db.statusTimer and L:StatusSince(unit, state)))
        return
    end
    L:StatusSince(unit, nil)

    local mode = db.healthText
    if mode == "NONE" then b.status:SetText("") return end

    local cur, max = Readable(curHP), Readable(maxHP)
    if cur and max and max > 0 then
        if mode == "PERCENT" then
            b.status:SetFormattedText("%d%%", math.floor(cur / max * 100 + 0.5))
        else
            local def = max - cur
            b.status:SetText(def > 0 and ("-" .. (AbbreviateNumbers and AbbreviateNumbers(def) or def)) or "")
        end
    elseif mode == "PERCENT" and UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        -- secret path: let the client format it for us
        local ok = pcall(function()
            b.status:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
        end)
        if not ok then b.status:SetText("") end
    else
        b.status:SetText("")   -- deficit can't be computed from secret values
    end
end

function L:Button_UpdatePower(b)
    local db, unit = L.db, b.unit
    if not db.showPower then return end
    if b.fake then
        local c = PowerBarColor and PowerBarColor[b.fake.power or "MANA"] or { r = 0, g = 0.5, b = 1 }
        b.power:SetStatusBarColor(c.r, c.g, c.b)
        b.power:SetMinMaxValues(0, 100)
        b.power:SetValue(b.fake.pp or 80)
        return
    end
    if not unit then return end
    if db.powerHealersOnly then
        local role = Readable(UnitGroupRolesAssigned(unit))
        if role ~= "HEALER" then b.power:SetValue(0) b.powerBG:SetAlpha(0.4) return end
    end
    b.powerBG:SetAlpha(1)
    local _, token = UnitPowerType(unit)
    token = Readable(token)
    local c = token and PowerBarColor and PowerBarColor[token] or { r = 0.0, g = 0.55, b = 1.0 }
    b.power:SetStatusBarColor(c.r, c.g, c.b)
    SafeSet(b.power, UnitPowerMax(unit), UnitPower(unit))
end

-- Ready check icons. The old READY_CHECK_*_TEXTURE globals aren't defined on
-- the Forever client, so point straight at the game's own icon files.
local READY_ICONS = {
    ready    = "Interface\\RaidFrame\\ReadyCheck-Ready",
    notready = "Interface\\RaidFrame\\ReadyCheck-NotReady",
    waiting  = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}
local function SetReadyIcon(tex, status)
    tex:SetTexture(READY_ICONS[status] or READY_ICONS.waiting)
    tex:SetTexCoord(0, 1, 0, 1)
end

local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }
function L:Button_UpdateIcons(b)
    local db, unit = L.db, b.unit

    -- role
    local role = b.fake and b.fake.role or (unit and Readable(UnitGroupRolesAssigned(unit)))
    if db.showRole and role and ROLE_ATLAS[role] then
        b.role:SetAtlas(ROLE_ATLAS[role])
        b.role:Show()
    else
        b.role:Hide()
    end

    -- leader / assist
    local lead = b.fake and b.fake.leader or (unit and L.SafeBool(UnitIsGroupLeader, unit))
    local assist = (not b.fake) and unit and L.SafeBool(UnitIsGroupAssistant, unit)
    if db.showLeader and lead then
        b.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon") b.leader:Show()
    elseif db.showLeader and assist then
        b.leader:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon") b.leader:Show()
    else
        b.leader:Hide()
    end
    b.leader:ClearAllPoints()
    local lx, ly = Off("leader")
    if b.role:IsShown() then b.leader:SetPoint("LEFT", b.role, "RIGHT", 1 + lx, ly)
    else b.leader:SetPoint("TOPLEFT", 2 + lx, -2 + ly) end

    -- main tank / main assist
    local rrole
    if db.showRaidRoles then
        if b.fake then rrole = b.fake.raidRole
        elseif unit and GetPartyAssignment then
            if L.SafeBool(GetPartyAssignment, "MAINTANK", unit) then rrole = "MAINTANK"
            elseif L.SafeBool(GetPartyAssignment, "MAINASSIST", unit) then rrole = "MAINASSIST" end
        end
    end
    b.raidRole:ClearAllPoints()
    if rrole then
        b.raidRole:SetTexture(rrole == "MAINTANK" and "Interface\\GroupFrame\\UI-Group-MainTankIcon"
            or "Interface\\GroupFrame\\UI-Group-MainAssistIcon")
        local prev = b.leader:IsShown() and b.leader or (b.role:IsShown() and b.role or nil)
        if prev then b.raidRole:SetPoint("LEFT", prev, "RIGHT", 1, 0)
        else b.raidRole:SetPoint("TOPLEFT", 2 + lx, -2 + ly) end
        b.raidRole:Show()
    else
        b.raidRole:Hide()
    end

    -- raid target
    local idx = b.fake and b.fake.mark or (unit and Readable(GetRaidTargetIndex(unit)))
    if db.showRaidIcon and idx then
        SetRaidTargetIconTexture(b.raidIcon, idx)
        b.raidIcon:Show()
    else
        b.raidIcon:Hide()
    end

    -- center status: ready check > resurrect > summon
    b.center:Hide()
    if b.fake then
        -- example / preview: simulated ready check and resurrection
        local rc = db.showReadyCheck and b.fake.ready
        if rc then
            SetReadyIcon(b.center, rc)
            b.center:Show()
        elseif db.showResurrect and b.fake.res then
            b.center:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
            b.center:SetTexCoord(0, 1, 0, 1)
            b.center:Show()
        end
        return
    end
    if not unit then return end
    local rc = db.showReadyCheck and Readable(GetReadyCheckStatus(unit))
    if rc or b.readyFade then
        rc = rc or b.readyFade
        SetReadyIcon(b.center, rc)
        b.center:Show()
        return
    end
    if db.showResurrect and L.SafeBool(UnitHasIncomingResurrection, unit) then
        b.center:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
        b.center:Show()
        return
    end
    if db.showResurrect and C_IncomingSummon and C_IncomingSummon.HasIncomingSummon
        and L.SafeBool(C_IncomingSummon.HasIncomingSummon, unit) then
        b.center:SetAtlas("Raid-Icon-SummonPending")
        b.center:Show()
    end
end

function L:Button_UpdateTarget(b)
    if b.fake then b.targetHL:SetShown(L.db.showTargetHL and b.fake.target) return end
    local is = b.unit and L.SafeBool(UnitIsUnit, b.unit, "target")
    b.targetHL:SetShown(L.db.showTargetHL and is and true or false)
end

local THREAT_COLORS = { [1] = { 1, 0.9, 0.2 }, [2] = { 1, 0.55, 0.1 }, [3] = { 1, 0.15, 0.15 } }
function L:Button_UpdateThreat(b)
    local db = L.db
    local s
    if b.fake then s = b.fake.aggro and 3 or b.fake.threat
    elseif b.unit and UnitThreatSituation then s = Readable(UnitThreatSituation(b.unit)) end
    b.aggro:SetShown(db.showAggro and s and s >= 2 and true or false)
    -- threat icon: level 1 (high threat, not tanking) is optional
    local minLevel = db.threatIconLow and 1 or 2
    local c = db.showThreatIcon and s and s >= minLevel and THREAT_COLORS[s]
    if c then
        b.threatIcon.tex:SetColorTexture(c[1], c[2], c[3], 1)
        b.threatIcon:Show()
    else
        b.threatIcon:Hide()
    end
end

------------------------------------------------------------------------
-- Auras
------------------------------------------------------------------------
local function SetAuraIcon(ic, unit, aura)
    pcall(ic.tex.SetTexture, ic.tex, aura.icon)

    -- stacks
    ic.count:SetText("")
    if GetAuraDisplayCount and aura.auraInstanceID then
        pcall(function() ic.count:SetText(GetAuraDisplayCount(unit, aura.auraInstanceID, 2, 99)) end)
    else
        local n = Readable(aura.applications)
        if n and n > 1 then ic.count:SetText(n) end
    end

    -- cooldown swipe
    local done = false
    if GetAuraDuration and ic.cd.SetCooldownFromDurationObject and aura.auraInstanceID then
        done = pcall(function()
            ic.cd:SetCooldownFromDurationObject(GetAuraDuration(unit, aura.auraInstanceID))
        end)
    end
    if not done then
        local dur, exp = Readable(aura.duration), Readable(aura.expirationTime)
        if dur and exp and dur > 0 then ic.cd:SetCooldown(exp - dur, dur) ic.cd:Show()
        else ic.cd:Hide() end
    end
    ic:Show()
end

L.SetAuraIcon = SetAuraIcon

-- exclude: optional set of spell names to leave out (e.g. ones you've placed
-- as buff indicators, so they don't also show up in the generic buff row)
local function ScanInto(unit, filter, icons, max, exclude)
    local shown = 0
    if GetAuraDataByIndex then
        for i = 1, 40 do
            if shown >= max then break end
            local ok, aura = pcall(GetAuraDataByIndex, unit, i, filter)
            if not ok or not aura then break end
            local name = exclude and Readable(aura.name)
            local id = exclude and Readable(aura.spellId)
            local boss = exclude and exclude.__boss and Readable(aura.isBossAura) == true
            if not boss and not (name and (exclude[name] or exclude[name:lower()])) and not (id and exclude[id]) then
                shown = shown + 1
                SetAuraIcon(icons[shown], unit, aura)
            end
        end
    end
    for i = shown + 1, #icons do icons[i]:Hide() end
end

function L:Button_UpdateAuras(b)
    local db, unit = L.db, b.unit
    if b.fake then
        for i, ic in ipairs(b.debuffs) do
            local tex = db.showDebuffs and i <= db.maxDebuffs and b.fake.debuffs and b.fake.debuffs[i]
            if tex then ic.tex:SetTexture(tex) ic.cd:Hide() ic.count:SetText("") ic:Show() else ic:Hide() end
        end
        for i, ic in ipairs(b.buffs) do
            local tex = db.showBuffs and i <= db.maxBuffs and b.fake.buffs and b.fake.buffs[i]
            if tex then ic.tex:SetTexture(tex) ic.cd:Hide() ic.count:SetText("") ic:Show() else ic:Hide() end
        end
        L:Dispel_UpdateFake(b)
        return
    end
    if not unit then return end

    if b.ac then
        -- the game's aura containers draw these rows (AuraContainers.lua)
        for _, ic in ipairs(b.debuffs) do ic:Hide() end
        for _, ic in ipairs(b.buffs) do ic:Hide() end
    else
        if db.showDebuffs then ScanInto(unit, db.debuffRaidOnly and "HARMFUL|RAID" or "HARMFUL", b.debuffs, db.maxDebuffs, L.DebuffRowExclude and L:DebuffRowExclude())
        else for _, ic in ipairs(b.debuffs) do ic:Hide() end end

        if db.showBuffs then ScanInto(unit, "HELPFUL|PLAYER", b.buffs, db.maxBuffs, L.Ind_Exclude and L:Ind_Exclude())
        else for _, ic in ipairs(b.buffs) do ic:Hide() end end
    end

    L:Dispel_Update(b)
end

------------------------------------------------------------------------
-- Range
------------------------------------------------------------------------
function L:Button_UpdateRange(b)
    local db = L.db
    local content = b.content
    if b.fake then content:SetAlpha((db.rangeFade and b.fake.oor) and db.oorAlpha or 1) return end
    local unit = b.unit
    if not db.rangeFade or not unit or L.SafeBool(UnitIsUnit, "player", unit) then content:SetAlpha(1) return end
    if IsOffline(unit) then content:SetAlpha(db.oorAlpha) return end

    -- range of a spell you picked (Indicators > Range), e.g. your main heal
    local spell = db.rangeSpell
    if spell and spell ~= "" and C_Spell and C_Spell.IsSpellInRange then
        local okS, r = pcall(C_Spell.IsSpellInRange, spell, unit)
        if okS and r ~= nil then
            if IsSecret(r) then
                if content.SetAlphaFromBoolean and pcall(content.SetAlphaFromBoolean, content, r, 1, db.oorAlpha) then return end
            else
                content:SetAlpha(r and 1 or db.oorAlpha)
                return
            end
        end
        -- nil: the spell can't be used on this player - fall back to the game's range
    end

    local ok, inRange, checked = pcall(UnitInRange, unit)
    if not ok then content:SetAlpha(1) return end
    if IsSecret(inRange) then
        if content.SetAlphaFromBoolean then
            pcall(content.SetAlphaFromBoolean, content, inRange, 1, db.oorAlpha)
        else
            content:SetAlpha(1)
        end
        return
    end
    checked = Readable(checked)
    if checked == false then content:SetAlpha(1) return end
    content:SetAlpha(inRange and 1 or db.oorAlpha)
end

------------------------------------------------------------------------
-- Full refresh
------------------------------------------------------------------------
function L:Button_UpdateAll(b)
    if not b.fake and (not b.unit or not UnitExists(b.unit)) then return end
    L:Button_UpdateColors(b)
    L:Button_UpdateName(b)
    L:Button_UpdateHealth(b)
    L:Button_UpdatePower(b)
    L:Button_UpdateIcons(b)
    L:Button_UpdateTarget(b)
    L:Button_UpdateThreat(b)
    L:Button_UpdateAuras(b)
    L:Button_UpdateRange(b)
end

function L:Buttons_RefreshAll()
    for _, b in ipairs(buttons) do
        L:Button_ApplyStyle(b)
        if b:IsVisible() then L:Button_UpdateAll(b) end
    end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local unitEvents = {
    UNIT_HEALTH                 = "Button_UpdateHealth",
    UNIT_MAXHEALTH              = "Button_UpdateHealth",
    UNIT_HEAL_PREDICTION        = "Button_UpdateHealth",
    UNIT_ABSORB_AMOUNT_CHANGED  = "Button_UpdateHealth",
    UNIT_POWER_UPDATE           = "Button_UpdatePower",
    UNIT_MAXPOWER               = "Button_UpdatePower",
    UNIT_DISPLAYPOWER           = "Button_UpdatePower",
    UNIT_AURA                   = "Button_UpdateAuras",
    UNIT_NAME_UPDATE            = "Button_UpdateAll",
    UNIT_CONNECTION             = "Button_UpdateAll",
    PLAYER_FLAGS_CHANGED        = "Button_UpdateHealth",
    UNIT_FLAGS                  = "Button_UpdateAll",
    UNIT_PHASE                  = "Button_UpdateRange",
    UNIT_THREAT_SITUATION_UPDATE= "Button_UpdateThreat",
    INCOMING_RESURRECT_CHANGED  = "Button_UpdateIcons",
    INCOMING_SUMMON_CHANGED     = "Button_UpdateIcons",
    READY_CHECK_CONFIRM         = "Button_UpdateIcons",
}

local f = CreateFrame("Frame")
for e in pairs(unitEvents) do pcall(f.RegisterEvent, f, e) end
for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PARTY_LEADER_CHANGED",
        "RAID_TARGET_UPDATE", "PLAYER_TARGET_CHANGED", "READY_CHECK", "READY_CHECK_FINISHED",
        "PLAYER_ENTERING_WORLD" }) do
    pcall(f.RegisterEvent, f, e)
end

local function ForAllVisible(method)
    for _, b in ipairs(buttons) do
        if not b.fake and b.unit and b:IsVisible() then L[method](L, b) end
    end
end

f:SetScript("OnEvent", function(_, event, unit, ...)
    if not L.db then return end
    local m = unitEvents[event]
    if m then
        if unit then ForUnit(unit, function(b) L[m](L, b) end) end
        return
    end
    if event == "PLAYER_TARGET_CHANGED" then
        ForAllVisible("Button_UpdateTarget")
    elseif event == "RAID_TARGET_UPDATE" or event == "PARTY_LEADER_CHANGED" or event == "PLAYER_ROLES_ASSIGNED"
        or event == "READY_CHECK" then
        for _, b in ipairs(buttons) do b.readyFade = nil end
        ForAllVisible("Button_UpdateIcons")
        if event == "PLAYER_ROLES_ASSIGNED" then ForAllVisible("Button_UpdatePower") end
    elseif event == "READY_CHECK_FINISHED" then
        for _, b in ipairs(buttons) do
            if b.unit then b.readyFade = Readable(GetReadyCheckStatus(b.unit)) or "notready" end
        end
        ForAllVisible("Button_UpdateIcons")
        C_Timer.After(6, function()
            for _, b in ipairs(buttons) do b.readyFade = nil end
            ForAllVisible("Button_UpdateIcons")
        end)
    else
        ForAllVisible("Button_UpdateAll")
    end
end)

-- status timers tick once a second, only on frames showing a status
C_Timer.NewTicker(1, function()
    if not L.db or not L.db.statusTimer then return end
    for _, b in ipairs(buttons) do
        if b.statusState and not b.fake and b.unit and b:IsVisible() then
            b.status:SetText(L:StatusText(b.statusState, L:StatusSince(b.unit, b.statusState)))
        end
    end
end)

-- range ticker
C_Timer.NewTicker(0.25, function()
    if not L.db then return end
    for _, b in ipairs(buttons) do
        if not b.fake and b.unit and b:IsVisible() then L:Button_UpdateRange(b) end
    end
end)

-- "Hide in combat": close a frame tooltip that was already open when combat starts
L:On("PLAYER_REGEN_DISABLED", function()
    if not L.db or L.db.tooltipMode ~= "NOCOMBAT" then return end
    local owner = GameTooltip:GetOwner()
    if owner and owner.__ll and not owner.fake then GameTooltip:Hide() end
end)
