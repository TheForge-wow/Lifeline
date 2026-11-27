--[[
    Lifeline - Big debuffs (Lua fallback), buff indicator lookup, /ll debug

    The Debuff Filters page now only uses the game's own checks (boss
    debuffs, crowd control, the raid filter), drawn by the aura containers.
    WoW Forever ignores spell IDs for debuffs, so the old name / spell ID
    lists were removed in 1.2.4. The list helpers below are kept only for
    clients without aura containers.
]]

local _, L = ...
local C = L.C

------------------------------------------------------------------------
-- Lists -> names / spell IDs
------------------------------------------------------------------------
local function Learned()
    LifelineDB.learnedDebuffs = LifelineDB.learnedDebuffs or {}
    return LifelineDB.learnedDebuffs
end

local function Trim(s) return (tostring(s or ""):match("^%s*(.-)%s*$")) end

-- IDs for one list entry: the number itself, IDs we've seen under that name,
-- or a spell the game can look up by name
local function EntryIDs(entry, set)
    entry = Trim(entry)
    local id = tonumber(entry)
    if id then set[id] = true return end
    for sid in pairs(Learned()[entry:lower()] or {}) do set[sid] = true end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(entry)
        local sid = info and L.Readable(info.spellID)
        if sid then set[sid] = true end
    end
end

function L:DebuffIDs(key)
    local set, any = {}, false
    for _, e in ipairs(L.db[key] or {}) do EntryIDs(e, set) end
    for _ in pairs(set) do any = true break end
    return any and set or nil
end

-- names (lowercase) and IDs, for the Lua fallback and the learner. Cached
-- per list until the list changes (L:Refresh after an edit, or an import).
local matchCache = {}
local function MatchSet(key)
    local list = L.db[key] or {}
    local c = matchCache[key]
    if c and c.list == list and c.n == #list then return c.set, c.typed end
    local set, typed = {}, {}
    for _, e in ipairs(L.db[key] or {}) do
        e = Trim(e)
        local id = tonumber(e)
        if id then
            set[id] = true
            local n = C_Spell and C_Spell.GetSpellName and L.Readable(C_Spell.GetSpellName(id))
            if n then set[n:lower()] = true end
        elseif e ~= "" then
            set[e:lower()] = true
            typed[e:lower()] = true   -- typed as a name: its spell ID still has to be learned
        end
    end
    matchCache[key] = { list = list, n = #list, set = set, typed = typed }
    return set, typed
end

local function Matches(set, aura)
    local name, id = L.Readable(aura.name), L.Readable(aura.spellId)
    return (id and set[id]) or (name and set[name:lower()]) or false
end

-- debuffs that shouldn't trigger the dispel highlight (Lua path)
function L:DispelIgnored(aura)
    if #(L.db.dispelIgnore or {}) == 0 then return false end
    return Matches((MatchSet("dispelIgnore")), aura)
end

-- debuffs the regular row skips (hidden + important, which show big instead)
function L:DebuffRowExclude()
    local out = {}
    for k in pairs(MatchSet("debuffHide")) do out[k] = true end
    for k in pairs(MatchSet("debuffImportant")) do out[k] = true end
    out.__boss = L.db.bigBossDebuffs and true or nil   -- boss debuffs show big instead
    return out
end

-- names in the lists we haven't matched to a spell ID yet (nil when none)
local function PendingNames()
    local learned, pending = Learned(), nil
    for _, key in ipairs(L.DEBUFF_LISTS) do
        local _, typed = MatchSet(key)
        for k in pairs(typed) do
            if not learned[k] then
                pending = pending or {}
                pending[k] = true
            end
        end
    end
    return pending
end

-- learn the spell IDs behind debuff names (out of combat, readable data only)
local learnQueued
local function LearnFrom(unit)
    local db = L.db
    if not db or InCombatLockdown() then return end
    local anyList = false
    for _, key in ipairs(L.DEBUFF_LISTS) do
        if #(db[key] or {}) > 0 then anyList = true break end
    end
    if not anyList then return end
    local GetByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not GetByIndex then return end
    -- nothing left to learn: skip the scan entirely
    local want = PendingNames()
    if not want then return end
    local learned, changed = Learned(), false
    for i = 1, 40 do
        local ok, aura = pcall(GetByIndex, unit, i, "HARMFUL")
        if not ok or not aura then break end
        local name, id = L.Readable(aura.name), L.Readable(aura.spellId)
        if name and id and want[name:lower()] then
            local t = learned[name:lower()] or {}
            if not t[id] then t[id] = true changed = true end
            learned[name:lower()] = t
        end
    end
    if changed and not learnQueued then
        learnQueued = true
        C_Timer.After(1, function()
            learnQueued = false
            if L.AC_RefreshAll then L:AC_RefreshAll() end
        end)
    end
end
L:On("UNIT_AURA", function(_, unit)
    if type(unit) == "string" and (unit == "player" or unit:find("^party") or unit:find("^raid")) then
        LearnFrom(unit)
    end
end)

------------------------------------------------------------------------
-- Big debuff (Lua path: sample frames, or clients without aura containers)
------------------------------------------------------------------------
local function EnsureBig(b)
    if b.bigDebuff then return b.bigDebuff end
    local ic = L.NewAuraIcon(b.overlay, 22)
    ic:SetFrameLevel(b.overlay:GetFrameLevel() + 3)
    L.AddBorder(ic, { 0.9, 0.2, 0.2, 1 }, 1)
    b.bigDebuff = ic
    return ic
end

function L:BigDebuff_Style(b)
    local ic = EnsureBig(b)
    local s = L.db.bigDebuffSize or 22
    ic:SetSize(s, s)
    ic:ClearAllPoints()
    local x, y = L.ElementOffset("bigDebuff")
    ic:SetPoint("CENTER", b.health, "CENTER", x, y)
end

function L:BigDebuff_Update(b)
    local ic = EnsureBig(b)
    local db = L.db
    if b.fake then
        if db.bigBossDebuffs and b.fake.bigDebuff then
            ic.tex:SetTexture(b.fake.bigDebuff) ic.cd:Hide() ic.count:SetText("") ic:Show()
        else ic:Hide() end
        return
    end
    if b.ac or not b.unit then ic:Hide() return end   -- containers draw it
    local GetByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not GetByIndex then ic:Hide() return end
    local imp = MatchSet("debuffImportant")
    for i = 1, 40 do
        local ok, aura = pcall(GetByIndex, b.unit, i, "HARMFUL")
        if not ok or not aura then break end
        if Matches(imp, aura) or (db.bigBossDebuffs and L.Readable(aura.isBossAura) == true) then
            L.SetAuraIcon(ic, b.unit, aura)
            return
        end
    end
    if db.bigCC then
        local ok, aura = pcall(GetByIndex, b.unit, 1, "HARMFUL|CROWD_CONTROL")
        if ok and aura then L.SetAuraIcon(ic, b.unit, aura) return end
    end
    ic:Hide()
end

------------------------------------------------------------------------
-- Buff indicator lookup (used by /ll debug)
------------------------------------------------------------------------
local GetBySpellName = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName

local function FindIndicatorAura(unit, ind)
    if not GetBySpellName then return nil end
    local name = L:Ind_SpellName(ind.spell)
    local filter = (ind.mode == "MINE" or ind.mode == "MISSING_MINE") and "HELPFUL|PLAYER" or "HELPFUL"
    for _, n in ipairs(L:Ind_Family(name)) do
        local ok, aura = pcall(GetBySpellName, unit, n, filter)
        if ok and aura then return aura end
    end
end

------------------------------------------------------------------------
-- /ll debug: what Lifeline can see about your buff indicators
------------------------------------------------------------------------
-- The report goes into a copy window (DebugWindow.lua) instead of chat, so
-- newer players can copy it with Ctrl+C. Each P() call is one line.
local function Plain(v)
    local ok, s = pcall(tostring, v)
    s = ok and s or "?"
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

function L:Debug_Report()
    local lines = {}
    local P = function(...)
        local t = {}
        for i = 1, select("#", ...) do t[i] = Plain((select(i, ...))) end
        lines[#lines + 1] = table.concat(t, " ")
    end
    P("Lifeline debug report")
    L:Debug_Collect(P)
    if L.DebugWindow_Show then
        L:DebugWindow_Show(table.concat(lines, "\n"))
        L:Print("Debug report opened - press Ctrl+C to copy it, then paste it in Discord with Ctrl+V.")
    else
        for _, line in ipairs(lines) do L:Print(line) end
    end
end

function L:Debug_Collect(P)
    P("version", L.version, "| in combat:", tostring(InCombatLockdown() and true or false),
        "| aura containers:", tostring(L.AC_Available and L:AC_Available()))
    -- frame layout (1.1.8.1)
    local ph = _G.LifelinePartyHeader
    if ph then
        P("party layout:", tostring(ph:GetAttribute("point")), "(should be " .. tostring(ph.llPoint) .. ")",
            "| repairs:", L.layoutRepair and L.layoutRepair.count or 0)
    end
    local r = L.layoutRepair or {}
    if r.last then P("last repair:", r.last) end
    if r.foreign then
        P("layout changed from outside:", r.foreign)
        if r.stack then for line in r.stack:gmatch("[^\n]+") do P("  ", line) end end
    end
    if L.Pad_DebugLines then for _, line in ipairs(L:Pad_DebugLines()) do P(line) end end
    local b
    for _, x in ipairs(L.buttons) do
        if not x.fake and x.unit and x:IsVisible() and L.SafeBool(UnitIsUnit, x.unit, "player") then b = x break end
    end
    if not b then P("Your own frame isn't showing (join a group or turn on 'Show frames when solo').") return end
    local list = L.cdb.indicators or {}
    P("dispel highlight:", L:AC_DrawsDispel(b) and "drawn by the game (works in combat)" or "drawn by Lifeline (out of combat only)")
    P("status banners:", (L.AC_DrawsStatus and L:AC_DrawsStatus(b)) and "drawn by the game (works in combat)"
        or ((L.db.statusCC or L.db.statusIceBlock) and "drawn by Lifeline (out of combat only)" or "off"))
    P("CC'D banner:", L.db.statusCC and "on (the game's crowd-control check)" or "off")
    -- debuffs on you right now, and recent ones (IDs only when the game shows them)
    P("debuffs on you now:", L:Debug_DebuffsNow())
    local seen = L.Debug_SeenDebuffs and L:Debug_SeenDebuffs() or {}
    if #seen > 0 then
        P("debuffs seen on you lately (newest first):")
        for _, line in ipairs(seen) do P("  ", line) end
    end
    local wh = L.wheelHover
    if wh then
        P("wheel bindings when you last hovered a frame (" .. wh.when .. ", " .. wh.unit .. ", wheel on frame: " .. wh.wheel .. "):")
        for _, line in ipairs(wh.lines) do P("  ", line) end
    end
    local clicks = L.ClickLog_Lines and L:ClickLog_Lines() or {}
    if #clicks > 0 then
        P("last clicks on frames (newest first):")
        for _, line in ipairs(clicks) do P("  ", line) end
    end
    P("your frame:", b.unit, "| buff indicators:", #list)
    for i, ind in ipairs(list) do
        local handled = L:AC_HandlesIndicator(b, i) and "game icon" or "Lifeline icon"
        local name = L:Ind_SpellName(ind.spell)
        local label = (tostring(name) ~= tostring(ind.spell)) and ("%s (%s)"):format(name, ind.spell) or tostring(ind.spell)
        local aura = FindIndicatorAura(b.unit, ind)
        local info
        if ind.mode and ind.mode:find("^MISSING") then
            if aura then info = "buff is up (reminder hidden)"
            elseif InCombatLockdown() then info = "can't tell in combat (reminders hide in combat)"
            else info = "buff is missing (reminder shown)" end
        elseif aura then
            local exp = L.Readable(aura.expirationTime)
            local left = exp and math.floor((exp - GetTime()) * 10) / 10
            info = ("found, time left: %s"):format(left and (left .. "s") or "hidden")
        else
            info = InCombatLockdown() and "not found (the game may hide it in combat)" or "not on you"
        end
        P(("  %d. %s [%s, %s] -> %s"):format(i, label, ind.mode or "?", handled, info))
    end
end

------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------
hooksecurefunc(L, "Button_Init", function(_, b) L:BigDebuff_Style(b) end)
hooksecurefunc(L, "Button_ApplyStyle", function(_, b) if b.bigDebuff then L:BigDebuff_Style(b) end end)
hooksecurefunc(L, "Button_UpdateAuras", function(_, b) L:BigDebuff_Update(b) end)

------------------------------------------------------------------------
-- Debuff IDs on you (for /ll debug): helps find the right ID for the
-- right IDs when debugging. The game hides aura details in
-- combat, so those show as "hidden"; out of combat you get name + ID.
------------------------------------------------------------------------
local GetAura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex

local function DescribeAura(a)
    local name = a and L.Readable(a.name)
    local id = a and L.Readable(a.spellId)
    if not name and not id then return nil end
    return ("%s (%s)"):format(name or "?", id and tostring(id) or "?")
end

function L:Debug_DebuffsNow()
    if not GetAura then return "unknown" end
    local out, hidden = {}, 0
    for i = 1, 40 do
        local ok, a = pcall(GetAura, "player", i, "HARMFUL")
        if not ok or not a then break end
        local d = DescribeAura(a)
        if d then out[#out + 1] = d else hidden = hidden + 1 end
    end
    if hidden > 0 then out[#out + 1] = hidden .. " hidden by the game" end
    return #out > 0 and table.concat(out, ", ") or "none"
end

local seenLog, seenAt = {}, {}
local function RecordSeen()
    if not GetAura then return end
    for i = 1, 40 do
        local ok, a = pcall(GetAura, "player", i, "HARMFUL")
        if not ok or not a then break end
        local d = DescribeAura(a)
        local key = d or "hidden"
        local now = GetTime and GetTime() or 0
        if not seenAt[key] or now - seenAt[key] > 3 then
            seenAt[key] = now
            local stamp = date and date("%H:%M:%S") or ""
            local combat = InCombatLockdown() and " (in combat)" or ""
            table.insert(seenLog, 1, stamp .. " " .. (d or "a debuff the game hid") .. combat)
            if #seenLog > 8 then seenLog[#seenLog] = nil end
        end
    end
end

function L:Debug_SeenDebuffs() return seenLog end

do
    local f = CreateFrame("Frame")
    if f.RegisterUnitEvent then f:RegisterUnitEvent("UNIT_AURA", "player") end
    f:SetScript("OnEvent", function() pcall(RecordSeen) end)
end

