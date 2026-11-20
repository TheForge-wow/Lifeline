--[[
    Lifeline - Cast bars & incoming cast warnings (both off by default)

    Cast bar: a thin bar on each frame showing what that group member is
    casting, with the spell icon and name.

    Incoming casts: when an enemy starts casting at a group member, that
    member's frame shows the spell icon with a countdown swipe. Enemy casts
    are read from nameplates, so enemy nameplates have to be switched on.

    WoW Forever may hide cast details from addons (secret values), so we
    never compare them: progress comes from the game's cast duration objects,
    names and icons go straight to the widgets, and "is this enemy casting at
    this player?" can be answered by the frame's opacity when it's secret.
]]

local _, L = ...
local C = L.C

local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local UnitCastingDuration, UnitChannelDuration = _G.UnitCastingDuration, _G.UnitChannelDuration
local E = _G.Enum
local INTERP = E and E.StatusBarInterpolation and E.StatusBarInterpolation.Immediate
local DIR_ELAPSED = E and E.StatusBarTimerDirection and E.StatusBarTimerDirection.ElapsedTime
local DIR_REMAINING = E and E.StatusBarTimerDirection and E.StatusBarTimerDirection.RemainingTime

local CAST_COLOR    = { 1.00, 0.76, 0.20 }
local CHANNEL_COLOR = { 0.30, 0.85, 0.55 }
local FAIL_COLOR    = { 0.90, 0.25, 0.25 }

L.CASTBAR_POSITIONS = {
    { value = "BOTTOM", text = "Bottom of the frame" },
    { value = "TOP",    text = "Top of the frame" },
}
L.INCOMING_POSITIONS = {
    { value = "TOPLEFT",  text = "Top left" },
    { value = "TOP",      text = "Top center" },
    { value = "TOPRIGHT", text = "Top right" },
    { value = "LEFT",     text = "Left center" },
    { value = "CENTER",   text = "Center" },
    { value = "RIGHT",    text = "Right center" },
}

-- "is there a cast?" without comparing a possibly-secret name to nil
local function HasValue(v) return type(v) ~= "nil" end

------------------------------------------------------------------------
-- Widgets (added to every frame, real and sample)
------------------------------------------------------------------------
local function CreateWidgets(b)
    if b.cast then return end
    local cast = CreateFrame("StatusBar", nil, b.content)
    cast:SetFrameLevel(b.content:GetFrameLevel() + 4)
    cast:SetMinMaxValues(0, 1)
    local bg = cast:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.55)
    cast.icon = cast:CreateTexture(nil, "ARTWORK")
    cast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cast.text = cast:CreateFontString(nil, "OVERLAY")
    cast.text:SetFont(L:FrameFont(), 8, "OUTLINE")
    cast.text:SetPoint("LEFT", 2, 0)
    cast.text:SetPoint("RIGHT", -2, 0)
    cast.text:SetJustifyH("LEFT")
    cast.text:SetWordWrap(false)
    cast:Hide()
    b.cast = cast

    local inc = L.NewAuraIcon(b.overlay, 18)
    inc:SetFrameLevel(b.overlay:GetFrameLevel() + 2)
    inc.cd:SetReverse(false)
    L.AddBorder(inc, { 1, 0.25, 0.25, 1 }, 1)
    b.inc = inc
end

local function StyleWidgets(b)
    CreateWidgets(b)
    local db = L.db
    local cfg = db.castBar
    local cast = b.cast
    cast:SetStatusBarTexture(L:BarTexture())
    local h = cfg.height or 6
    local ox, oy = L.ElementOffset("castbar")
    cast:ClearAllPoints()
    local iconW = (cfg.showIcon and h >= 6) and h or 0
    if cfg.position == "TOP" then
        cast:SetPoint("TOPLEFT", b.health, "TOPLEFT", iconW + ox, oy)
        cast:SetPoint("TOPRIGHT", b.health, "TOPRIGHT", ox, oy)
    else
        cast:SetPoint("BOTTOMLEFT", b.health, "BOTTOMLEFT", iconW + ox, oy)
        cast:SetPoint("BOTTOMRIGHT", b.health, "BOTTOMRIGHT", ox, oy)
    end
    cast:SetHeight(h)
    cast.icon:ClearAllPoints()
    cast.icon:SetSize(h, h)
    cast.icon:SetPoint("RIGHT", cast, "LEFT", 0, 0)
    cast.icon:SetShown(iconW > 0)
    cast.text:SetFont(L:FrameFont(), math.max(7, math.min(11, h - 1)), "OUTLINE")
    cast.text:SetShown(cfg.showName and h >= 8)

    local ic = db.incoming
    local ix, iy = L.ElementOffset("incoming")
    b.inc:SetSize(ic.size or 18, ic.size or 18)
    b.inc:ClearAllPoints()
    local pos = ic.position or "TOPLEFT"
    local px = pos:find("LEFT") and 2 or (pos:find("RIGHT") and -2 or 0)
    local py = pos:find("TOP") and -2 or 0
    b.inc:SetPoint(pos, b.health, pos, px + ix, py + iy)
end

------------------------------------------------------------------------
-- Cast bar
------------------------------------------------------------------------
local function BarOnUpdate(cast)
    -- fallback when the game has no duration objects: readable start/end times
    local now = GetTime() * 1000
    if not cast.startMS or now >= cast.endMS then
        cast:SetScript("OnUpdate", nil)
        cast:Hide()
        return
    end
    local pct = (now - cast.startMS) / (cast.endMS - cast.startMS)
    cast:SetValue(cast.channel and (1 - pct) or pct)
end

function L:CastBar_Update(b)
    if not b.cast then return end
    local cfg = L.db.castBar
    local cast = b.cast
    cast:SetScript("OnUpdate", nil)
    if not cfg.enabled then cast:Hide() return end

    if b.fake then
        local f = b.fake.cast
        if not f then cast:Hide() return end
        local col = f.channel and CHANNEL_COLOR or CAST_COLOR
        cast:SetStatusBarColor(col[1], col[2], col[3])
        cast:SetMinMaxValues(0, 1)
        cast:SetValue(f.pct or 0.5)
        cast.icon:SetTexture(f.icon)
        cast.text:SetText(f.name)
        cast:Show()
        return
    end

    local unit = b.unit
    if not unit then cast:Hide() return end
    local channel = false
    local name, _, texture, startMS, endMS = UnitCastingInfo(unit)
    if not HasValue(name) then
        name, _, texture, startMS, endMS = UnitChannelInfo(unit)
        channel = true
    end
    if not HasValue(name) then cast:Hide() return end

    local col = channel and CHANNEL_COLOR or CAST_COLOR
    cast:SetStatusBarColor(col[1], col[2], col[3])
    pcall(cast.icon.SetTexture, cast.icon, texture)
    pcall(cast.text.SetText, cast.text, name)

    local dur
    if channel then dur = UnitChannelDuration and UnitChannelDuration(unit)
    else dur = UnitCastingDuration and UnitCastingDuration(unit) end
    if dur and cast.SetTimerDuration and INTERP then
        local ok = pcall(cast.SetTimerDuration, cast, dur, INTERP, channel and DIR_REMAINING or DIR_ELAPSED)
        if ok then cast:Show() return end
    end
    -- no duration object: use the times if the game lets us read them
    local s, e = L.Readable(startMS), L.Readable(endMS)
    if s and e and e > s then
        cast.startMS, cast.endMS, cast.channel = s, e, channel
        cast:SetMinMaxValues(0, 1)
        cast:SetScript("OnUpdate", BarOnUpdate)
        BarOnUpdate(cast)
        cast:Show()
    else
        -- can't show progress: a full bar still says "casting X"
        cast:SetMinMaxValues(0, 1)
        cast:SetValue(1)
        cast:Show()
    end
end

local function CastFailed(b)
    local cast = b.cast
    if not cast or not cast:IsShown() then return end
    cast:SetScript("OnUpdate", nil)
    cast:SetMinMaxValues(0, 1)
    cast:SetValue(1)
    cast:SetStatusBarColor(FAIL_COLOR[1], FAIL_COLOR[2], FAIL_COLOR[3])
    cast.text:SetText("Interrupted")
    local token = {}
    cast.failToken = token
    C_Timer.After(0.6, function()
        if cast.failToken == token then cast.failToken = nil L:CastBar_Update(b) end
    end)
end

------------------------------------------------------------------------
-- Incoming casts (enemy nameplates casting at a group member)
------------------------------------------------------------------------
local plates = {}        -- nameplate unit -> true while it exists
local castGen = {}       -- nameplate unit -> counter, so a late check for an old cast is dropped

local function HideIncomingFrom(plate)
    for _, b in ipairs(L.buttons) do
        if b.inc and b.incFrom == plate then
            b.incFrom = nil
            b.inc:Hide()
        end
    end
end

local function ShowOn(b, plate, texture, dur, isTarget)
    b.incFrom = plate
    pcall(b.inc.tex.SetTexture, b.inc.tex, texture)
    b.inc.cd:Hide()
    if dur and b.inc.cd.SetCooldownFromDurationObject then
        if pcall(b.inc.cd.SetCooldownFromDurationObject, b.inc.cd, dur) then b.inc.cd:Show() end
    end
    b.inc:Show()
    if L.IsSecret(isTarget) then
        -- the game won't say who the target is; let it decide what's visible
        if not (b.inc.SetAlphaFromBoolean and pcall(b.inc.SetAlphaFromBoolean, b.inc, isTarget, 1, 0)) then
            b.inc:Hide()
        end
    else
        b.inc:SetAlpha(1)
    end
end

local function CheckPlate(plate)
    if not L.db or not L.db.incoming.enabled or not plates[plate] then return end
    if L.SafeBool(UnitCanAttack, "player", plate) ~= true then return end
    local channel = false
    local name, _, texture = UnitCastingInfo(plate)
    if not HasValue(name) then
        name, _, texture = UnitChannelInfo(plate)
        channel = true
    end
    HideIncomingFrom(plate)
    if not HasValue(name) then return end
    local dur
    if channel then dur = UnitChannelDuration and UnitChannelDuration(plate)
    else dur = UnitCastingDuration and UnitCastingDuration(plate) end

    local target = plate .. "target"
    for _, b in ipairs(L.buttons) do
        if b.inc and not b.fake and b.unit and b:IsVisible() then
            local ok, isTarget = pcall(UnitIsUnit, target, b.unit)
            if ok and (L.IsSecret(isTarget) or isTarget == true) then
                ShowOn(b, plate, texture, dur, isTarget)
            end
        end
    end
end

local function OnPlateCast(plate)
    castGen[plate] = (castGen[plate] or 0) + 1
    local gen = castGen[plate]
    -- the cast's target is settled a moment after the cast starts
    C_Timer.After(0.15, function()
        if castGen[plate] == gen then CheckPlate(plate) end
    end)
end

------------------------------------------------------------------------
-- Sample frames
------------------------------------------------------------------------
function L:Incoming_UpdateFake(b)
    if not b.inc then return end
    local f = b.fake and b.fake.incoming
    if L.db.incoming.enabled and f then
        b.inc.tex:SetTexture(f)
        b.inc.cd:Hide()
        b.inc:SetAlpha(1)
        b.inc:Show()
    else
        b.inc:Hide()
    end
end

------------------------------------------------------------------------
-- Hooks & events
------------------------------------------------------------------------
hooksecurefunc(L, "Button_Init", function(_, b)
    CreateWidgets(b)
    StyleWidgets(b)
    L:CastBar_Update(b)
    if b.fake then L:Incoming_UpdateFake(b) end
end)
hooksecurefunc(L, "Button_ApplyStyle", function(_, b) if b.cast then StyleWidgets(b) end end)
hooksecurefunc(L, "Button_UpdateAll", function(_, b)
    L:CastBar_Update(b)
    if b.fake then L:Incoming_UpdateFake(b)
    elseif b.inc and not L.db.incoming.enabled then b.inc:Hide() end
end)
hooksecurefunc(L, "Button_SetUnit", function(_, b, unit)
    if not unit and b.inc then b.incFrom = nil b.inc:Hide() end
end)

local START = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_DELAYED = true, UNIT_SPELLCAST_CHANNEL_UPDATE = true,
    UNIT_SPELLCAST_EMPOWER_START = true, UNIT_SPELLCAST_EMPOWER_UPDATE = true }
local STOP = { UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_CHANNEL_STOP = true,
    UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_FAILED_QUIET = true,
    UNIT_SPELLCAST_EMPOWER_STOP = true, UNIT_SPELLCAST_SUCCEEDED = false }
local FAIL = { UNIT_SPELLCAST_INTERRUPTED = true }

local f = CreateFrame("Frame")
for e in pairs(START) do pcall(f.RegisterEvent, f, e) end
for e, on in pairs(STOP) do if on then pcall(f.RegisterEvent, f, e) end end
for e in pairs(FAIL) do pcall(f.RegisterEvent, f, e) end
for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_REGEN_ENABLED" }) do
    pcall(f.RegisterEvent, f, e)
end

f:SetScript("OnEvent", function(_, event, unit)
    if not L.db then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        if type(unit) == "string" then
            plates[unit] = true
            if L.db.incoming.enabled then OnPlateCast(unit) end
        end
        return
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if type(unit) == "string" then
            plates[unit] = nil
            castGen[unit] = (castGen[unit] or 0) + 1
            HideIncomingFrom(unit)
        end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- out of combat nobody is casting at us any more
        for plate in pairs(plates) do HideIncomingFrom(plate) end
        return
    end
    if type(unit) ~= "string" then return end

    if plates[unit] then
        if not L.db.incoming.enabled then return end
        if START[event] then OnPlateCast(unit)
        else
            castGen[unit] = (castGen[unit] or 0) + 1
            HideIncomingFrom(unit)
        end
        return
    end

    if not L.db.castBar.enabled then return end
    local function update(b)
        if FAIL[event] then CastFailed(b)
        elseif b.cast and b.cast.failToken == nil then L:CastBar_Update(b) end
    end
    L.ForUnit(unit, update)
    -- in a raid your own frame is "raidN", but your casts arrive as "player"
    if unit == "player" then
        for _, b in ipairs(L.buttons) do
            if not b.fake and b.unit and b.unit ~= "player" and b:IsVisible()
                and L.SafeBool(UnitIsUnit, b.unit, "player") == true then
                update(b)
            end
        end
    end
end)
