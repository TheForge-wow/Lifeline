--[[
    Lifeline - Aura sounds
    Play a sound when a chosen buff or debuff is gained, fades or gains a
    stack on someone in your group (for example Weakened Soul fading, or a
    debuff landing on the tank).

    The game itself watches the auras and plays the sound (C_UnitAuras
    AddAuraSound), so it keeps working in combat where addons can't read
    auras. Sounds can only be registered out of combat and outside boss
    encounters, so we register them ahead of time and refresh after combat
    and when the group changes.
]]

local ADDON, L = ...

L.SOUND_TRIGGERS = {
    { value = "ADDED",   text = "Is gained" },
    { value = "REMOVED", text = "Fades" },
    { value = "STACKS",  text = "Gains a stack" },
}
L.SOUND_WHO = {
    { value = "ALL", text = "Whole group" },
    { value = "ME",  text = "Only me" },
}

local OWN = "Interface\\AddOns\\" .. ADDON .. "\\Sounds\\"
-- game sounds are file IDs, Lifeline's own are .ogg files in the Sounds folder
L.SOUNDS = {
    { value = "chime",   text = "Chime",    file = OWN .. "Chime.ogg" },
    { value = "ping",    text = "Ping",     file = OWN .. "Ping.ogg" },
    { value = "alert",   text = "Alert",    file = OWN .. "Alert.ogg" },
    { value = "bell",    text = "Bell",     file = OWN .. "Bell.ogg" },
    { value = "low",     text = "Low tone", file = OWN .. "Low.ogg" },
    { value = "pop",     text = "Pop",      file = OWN .. "Pop.ogg" },
    { value = "raidwarning", text = "Raid warning", id = 567397 },
    { value = "alarm",   text = "Alarm clock",  id = 567458 },
    { value = "ready",   text = "Ready check",  id = 567478 },
    { value = "mapping", text = "Map ping",     id = 567416 },
}
local SOUND_BY_KEY = {}
for _, s in ipairs(L.SOUNDS) do SOUND_BY_KEY[s.value] = s end

local TRIGGER_ENUM = { ADDED = "Added", REMOVED = "Removed", STACKS = "ApplicationsIncreased" }
L.SOUND_MAX = 10

local function API()
    local c = C_UnitAuras
    if c and type(c.AddAuraSound) == "function" and type(c.RemoveAuraSound) == "function" then
        return c.AddAuraSound, c.RemoveAuraSound
    end
end
function L:Sounds_Available() return API() ~= nil end

local function Config() return L.cdb and L.cdb.auraSounds end

------------------------------------------------------------------------
-- Test button: play the sound now
------------------------------------------------------------------------
function L:Sounds_Play(key)
    local s = SOUND_BY_KEY[key or ""]
    if not s then return end
    if s.id then
        if not pcall(PlaySoundFile, s.id, "Master") then L:Print("The game couldn't play that sound.") end
    else
        local ok, willPlay = pcall(PlaySoundFile, s.file, "Master")
        if not ok or willPlay == false then
            L:Print("Couldn't play " .. s.text .. " - restart the game once after installing a new Lifeline version so it finds the sound files.")
        end
    end
end

------------------------------------------------------------------------
-- Which spell IDs an entry means. Auras carry the ID of the rank that was
-- cast, so for a name we collect every rank the game will tell us about,
-- plus the buff family (Fortitude + Prayer of Fortitude etc.).
------------------------------------------------------------------------
local function AddID(set, id)
    id = L.Readable(id)
    if type(id) == "number" and id > 0 then set[id] = true end
end

local function IDsForName(set, name)
    if not C_Spell or not C_Spell.GetSpellInfo then return end
    local info = C_Spell.GetSpellInfo(name)
    if info then AddID(set, info.spellID) end
    for rank = 1, 16 do
        local r = C_Spell.GetSpellInfo(("%s(Rank %d)"):format(name, rank))
        if r then AddID(set, r.spellID) end
    end
end

function L:Sounds_SpellIDs(spell)
    local set = {}
    spell = tostring(spell or "")
    -- one or more IDs: "6788" or "6788, 11426"
    if spell:match("^[%d%s,]+$") then
        for id in spell:gmatch("%d+") do AddID(set, tonumber(id)) end
        return set
    end
    local name = L.CC_StripRank and L:CC_StripRank(spell) or spell
    for _, n in ipairs(L:Ind_Family(name)) do IDsForName(set, n) end
    if L.AC_SpellIDs then
        for id in pairs(L:AC_SpellIDs(name) or {}) do AddID(set, id) end
    end
    return set
end

------------------------------------------------------------------------
-- Registration
------------------------------------------------------------------------
local function Blocked()
    if InCombatLockdown() then return true end
    local types = Enum and Enum.AddOnRestrictionType
    if IsAddOnRestrictionActive and types and types.Encounter ~= nil then
        local ok, v = pcall(IsAddOnRestrictionActive, types.Encounter)
        if not ok or L.IsSecret(v) or v ~= false then return true end
    end
    return false
end

local function GroupUnits(who)
    local out = { "player" }
    if who == "ME" then return out end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local u = "raid" .. i
            if L.SafeBool(UnitIsUnit, u, "player") ~= true then out[#out + 1] = u end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do out[#out + 1] = "party" .. i end
    end
    return out
end

-- what should be registered right now: signature -> { trigger, info }
local function Wanted()
    local want = {}
    local cfg = Config()
    if not cfg or not cfg.enabled then return want end
    local enum = Enum and Enum.UnitAuraSoundTrigger
    for _, e in ipairs(cfg.list or {}) do
        local trig = enum and enum[TRIGGER_ENUM[e.trigger or "ADDED"] or ""]
        local s = SOUND_BY_KEY[e.sound or ""]
        if type(trig) == "number" and not L.IsSecret(trig) and s and e.spell and e.spell ~= "" then
            local units = GroupUnits(e.who)
            for id in pairs(L:Sounds_SpellIDs(e.spell)) do
                for _, unit in ipairs(units) do
                    local sig = table.concat({ unit, id, trig, e.sound }, "|")
                    if not want[sig] then
                        local info = { unitToken = unit, spellID = id, outputChannel = "Master" }
                        if s.id then info.soundFileID = s.id else info.soundFileName = s.file end
                        want[sig] = { trigger = trig, info = info }
                    end
                end
            end
        end
    end
    return want
end

local registered = {}   -- signature -> handle
local pending = false

function L:Sounds_Refresh()
    local add, remove = API()
    if not add or not L.cdb then return end
    if Blocked() then pending = true return end
    pending = false
    local want = Wanted()
    for sig, handle in pairs(registered) do
        if not want[sig] and pcall(remove, handle) then registered[sig] = nil end
    end
    for sig, w in pairs(want) do
        if not registered[sig] then
            local ok, handle = pcall(add, w.trigger, w.info)
            if ok and handle ~= nil and not L.IsSecret(handle) then registered[sig] = handle end
        end
    end
end

-- several events often arrive together; refresh once shortly after
function L:Sounds_Request()
    L:Debounce("auraSounds", 0.5, function() L:Sounds_Refresh() end)
end

for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "SPELLS_CHANGED" }) do
    L:On(e, function() L:Sounds_Request() end)
end
L:On("PLAYER_REGEN_ENABLED", function() if pending then L:Sounds_Request() end end)
pcall(L.On, L, "ADDON_RESTRICTION_STATE_CHANGED", function() L:Sounds_Request() end)
