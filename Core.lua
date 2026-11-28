--[[
    Lifeline - party & raid frames for WoW Forever
    Core: namespace, saved variables, secret-value helpers, events, slash commands.
]]

local ADDON, L = ...
_G.Lifeline = L

L.name    = "Lifeline"
L.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "1.2.6"
L.discord = "https://discord.gg/yskDeZjQj7"

------------------------------------------------------------------------
-- Defaults
------------------------------------------------------------------------
L.defaults = {
    locked        = true,
    hideBlizzard  = true,
    hideBlizzardManager = false,
    showSolo      = false,
    showExample   = true,             -- example frames beside the settings window
    showPlayerInParty = true,
    position      = { point = "TOPLEFT", x = 220, y = -260 },
    minimap       = { hide = false, angle = 205 },
    scale         = 1.0,

    -- layout
    party = { width = 110, height = 46, spacing = 3, orientation = "VERTICAL", growth = "DOWN_RIGHT" },
    raid  = { width = 84,  height = 40, spacing = 2, orientation = "VERTICAL", growth = "DOWN_RIGHT",
              groupBy = "GROUP", unitsPerColumn = 5, maxColumns = 8, groupSpacing = 6 },
    -- optional separate raid layouts by size: "raid" is used for up to 10
    -- players (or every raid when raidBySize is off), raid20 for 11-20, raid40 for 21-40
    raidBySize    = false,
    raid20 = { width = 84, height = 40, spacing = 2, orientation = "VERTICAL", growth = "DOWN_RIGHT",
               groupBy = "GROUP", unitsPerColumn = 5, maxColumns = 8, groupSpacing = 6 },
    raid40 = { width = 72, height = 34, spacing = 2, orientation = "VERTICAL", growth = "DOWN_RIGHT",
               groupBy = "GROUP", unitsPerColumn = 5, maxColumns = 8, groupSpacing = 4 },
    sortBy        = "INDEX",          -- INDEX, NAME, ROLE
    pets          = { enabled = false, width = 70, height = 26 },
    -- per-element nudges (pixels): x = right, y = up
    offsets = {
        name = { x = 0, y = 0 }, status = { x = 0, y = 0 }, role = { x = 0, y = 0 },
        leader = { x = 0, y = 0 }, raidIcon = { x = 0, y = 0 }, center = { x = 0, y = 0 },
        debuffs = { x = 0, y = 0 }, buffs = { x = 0, y = 0 }, threat = { x = 0, y = 0 },
        castbar = { x = 0, y = 0 }, incoming = { x = 0, y = 0 }, bigDebuff = { x = 0, y = 0 }, lowMana = { x = 0, y = 0 }, soulstone = { x = 0, y = 0 },
    },

    -- bars
    healthColor   = "CLASS",          -- CLASS, DARK, CUSTOM
    classColors   = {},               -- per-class overrides { PRIEST = { r=, g=, b= } }
    classDarken   = 0,                -- 0-60: % to darken every class color
    customHealth  = { r = 0.20, g = 0.80, b = 0.45 },
    bgDarkness    = 0.75,
    fillDirection = "LEFT_TO_RIGHT",  -- LEFT_TO_RIGHT, RIGHT_TO_LEFT, BOTTOM_TO_TOP, TOP_TO_BOTTOM
    barTexture    = "Lifeline Flat",  -- LibSharedMedia statusbar name
    frameFont     = "Game default",   -- LibSharedMedia font name
    barAlpha      = 1,                -- filled part of the health bar
    bgAlpha       = 1,                -- empty part / frame background
    deadColor     = { r = 0.12, g = 0.12, b = 0.12 },  -- background of dead & offline frames
    showPower     = true,
    powerHeight   = 4,
    powerHealersOnly = false,
    showHealPred  = true,
    healPredMineOnly = false,         -- only count heals you are casting
    showAbsorb    = true,
    overheal      = "INSIDE",         -- OFF, INSIDE (strip at the bar's edge), OUTSIDE (past the frame)
    overhealWidth = 8,

    -- text
    nameClassColor = false,
    nameSize      = 11,
    healthText    = "PERCENT",        -- NONE, PERCENT, DEFICIT
    healthTextSize = 10,
    textOutline   = "THIN",           -- SHADOW, THIN, THICK, NONE (names & health/status text)

    -- indicators
    showRole      = true,
    showLeader    = true,
    showRaidIcon  = true,
    showReadyCheck = true,
    showResurrect = true,
    showDrinking  = true,
    statusCC       = true,            -- CC'D banner (StatusEffects.lua), the game's crowd-control filter
    statusIceBlock = true,            -- ICE BLOCK banner
    statusSoulstone = false,          -- SOULSTONE tag (top center)
    showAFK       = true,
    statusTimer   = true,             -- DEAD 1:12, OFFLINE 4:05, AFK 2:30
    showAggro     = true,
    showRaidRoles = false,            -- main tank / main assist icons
    showThreatIcon = false,           -- colored threat square
    threatIconLow = false,            -- also show the first (yellow) threat level
    dispelColors  = "DEFAULT",        -- DEFAULT, COLORBLIND
    dispelStyle   = "BORDER",         -- BORDER, BAR, BOTH (how a dispellable debuff shows)
    dispelCustom  = {},               -- Custom dispel colors: [type] = { r, g, b }
    dispelGlowAlpha  = 30,            -- glow strength (%)
    dispelGlowHeight = 100,           -- how far up the frame the glow reaches (%)
    dispelGlowDir    = "BOTTOM",      -- BOTTOM, TOP, EDGES, FULL
    dispelBorderSize = 2,             -- dispel border thickness (px)
    dispelBarFill    = "SOLID",       -- SOLID, GRADIENT (Debuff tint style)
    dispelBarGradient = 50,           -- how much darker the far end of the bar gets (%)

    -- cast bars on the frames (what each group member is casting)
    castBar = { enabled = false, position = "BOTTOM", height = 6, showIcon = true, showName = true },
    -- warnings when an enemy (from its nameplate) casts at a group member
    incoming = { enabled = false, size = 18, position = "TOPLEFT" },
    showTargetHL  = true,
    showMouseoverHL = true,
    tooltipMode   = "NOCOMBAT",       -- ALWAYS, NOCOMBAT, NEVER
    tooltipBindings = true,           -- list your click-cast bindings in the frame tooltip
    updateNotice  = true,             -- tell me when a group / guild member has a newer Lifeline
    whatsNew      = true,             -- show the "What's new" window after an update
    groupLabels   = false,            -- "Group 1" ... above raid groups
    lowMana       = { enabled = false, percent = 20, healersOnly = true },
    -- tank frames: a separate small group of tanks (or players you name)
    tanks = { enabled = false, mode = "TANKS", names = "", width = 100, height = 36, spacing = 2,
              orientation = "VERTICAL", growth = "DOWN_RIGHT", position = { point = "TOPLEFT", x = 60, y = -260 } },

    -- auras
    showDebuffs   = true,
    maxDebuffs    = 3,
    debuffSize    = 16,
    indicatorFill = true,             -- indicators at one spot fill from the corner (false: fixed spots)
    showBuffs     = false,            -- every buff you cast (off: only your buff indicators show)
    maxBuffs      = 3,
    buffSize      = 14,
    dispelHighlight = true,
    -- debuff filters: hidden debuffs, "important" debuffs shown big in the
    -- center, and boss debuffs shown big too
    debuffRaidOnly = false,           -- "Hide minor debuffs": the game's raid filter (also hides Weakened Soul)
    bigBossDebuffs = true,
    bigCC         = true,             -- crowd control (game's filter) big in the middle
    bigDebuffSize = 22,

    -- range
    rangeFade     = true,
    rangeSpell    = "",               -- "" = the game's standard range, else a friendly spell's range
    oorAlpha      = 0.40,
}

L.charDefaults = {
    clickCast = {
        enabled = true,
        bindings = {
            -- [key] = { type = "target"|"menu"|"spell"|"macro"|"none", value = "Spell Name",
            --           fixedRank = true to keep a typed rank instead of auto-upgrading,
            --           autoTarget = true to also target the player when casting }
            ["BUTTON1"]       = { type = "target" },
            ["BUTTON2"]       = { type = "menu" },
        },
        extraButtons = {},   -- extra mouse buttons (4-16) the user has added
        extraKeys = {},      -- keyboard keys bound while hovering a frame ("NUMPAD1"...; MMO mice)
        shiftNumpadFix = false, -- also bind the arrow keys Windows sends for Shift + Numpad
        smartRes = "OFF",    -- OFF, NORMAL, COMBAT: dead players get your resurrection
        selfCastDeclined = "", -- self-cast key clash the user chose to keep
        otherFrames = { player = false, target = false, focus = false, addons = false },
    },
    -- user-placed buff indicators:
    -- { spell = "Renew", anchor = "TOP", mode = "MINE"|"ANY"|"MISSING"|"MISSING_MINE", size = 14 }
    indicators = {},
    -- sounds when an aura is gained / fades / stacks:
    -- { spell = "Weakened Soul", trigger = "ADDED"|"REMOVED"|"STACKS", who = "ALL"|"ME", sound = "chime" }
    auraSounds = { enabled = true, list = {} },
    useOwnProfile = false,   -- false = use the shared Default profile
    profile = {},            -- this character's own settings (when useOwnProfile)
}

------------------------------------------------------------------------
-- Utility
------------------------------------------------------------------------
local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" and #v > 0 and type(dst[k]) == "table" then
            -- lists (e.g. hidden debuffs) are the user's own: never refill removed entries
        elseif type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
L.CopyDefaults = CopyDefaults

local ACCENT_HEX = "4cd98c"
function L:Print(...)
    print("|cff" .. ACCENT_HEX .. "Lifeline|r:", ...)
end

------------------------------------------------------------------------
-- Secret-value helpers
-- WoW Forever runs on the Midnight client: during restricted content many
-- combat values (health, auras, range...) come back as "secret" values.
-- We may pass them straight to widgets (StatusBar:SetValue, FontString:SetText)
-- but must never compare, do math on, or concatenate them.
------------------------------------------------------------------------
local issecretvalue = _G.issecretvalue

function L.IsSecret(v)
    if issecretvalue then
        return issecretvalue(v) and true or false
    end
    return false
end

-- returns v only if it is safe to inspect in Lua, otherwise nil
function L.Readable(v)
    -- check secrecy *before* any comparison: comparing a secret errors
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- call a function that may return secrets; returns readable first result or nil
function L.SafeBool(fn, ...)
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    if not ok then return nil end
    return L.Readable(v)
end


------------------------------------------------------------------------
-- After-combat queue (secure frame changes can't happen in combat)
------------------------------------------------------------------------
local queued = {}
function L:RunAfterCombat(key, fn)
    if not InCombatLockdown() then
        fn()
    else
        queued[key] = fn
    end
end

------------------------------------------------------------------------
-- Event plumbing
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
L.eventFrame = ev   -- exposed for the offline test harness
local handlers = {}

function L:On(event, fn)
    handlers[event] = handlers[event] or {}
    table.insert(handlers[event], fn)
    ev:RegisterEvent(event)
end

ev:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if list then
        for i = 1, #list do list[i](event, ...) end
    end
end)

L:On("PLAYER_REGEN_ENABLED", function()
    for key, fn in pairs(queued) do
        queued[key] = nil
        fn()
    end
end)

------------------------------------------------------------------------
-- Profiles
--   LifelineDB.default        shared "Default" settings (all characters)
--   LifelineCharDB.profile    this character's own settings
--   LifelineCharDB.useOwnProfile  which of the two this character uses
-- Click-casting and buff indicators are always per character.
------------------------------------------------------------------------
local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = DeepCopy(v) end
    return c
end

-- growth used to be one shared setting; it's now per party / raid
-- frame layers above a unit frame's overlay (higher draws on top):
-- icons 1-3, ready check & res icon 10, LOW MANA 11, DRINKING 12,
-- CC'D 14, ICE BLOCK & SOULSTONE 15 (StatusEffects.lua)
L.LAYER_LOWMANA = 11
L.LAYER_DRINKING = 12

-- (none left: WoW Forever ignores spell IDs for debuffs, so the lists were removed in 1.2.5)
L.DEBUFF_LISTS = {}

local function MigrateProfile(p)
    if type(p) ~= "table" then return end
    p.dispelOnlyMine = nil   -- setting removed in 1.0.1 (dispel highlight is always "what you can remove")
    p.dispelSound, p.dispelSoundKey = nil, nil   -- dispel sound removed in 1.1.7
    -- 1.2.4: STUNNED + SILENCED (spell ID lists the game ignores) became one CC'D banner
    if p.statusStunned ~= nil or p.statusSilenced ~= nil then
        if p.statusCC == nil then p.statusCC = not (p.statusStunned == false and p.statusSilenced == false) end
        p.statusStunned, p.statusSilenced, p.statusStunExtra, p.statusSilenceExtra = nil, nil, nil, nil
    end
    -- 1.2.5: the debuff spell-ID lists did nothing (the game ignores IDs for debuffs)
    p.debuffHide, p.debuffImportant, p.dispelIgnore = nil, nil, nil
    -- 1.1.3: the expiring buff flash was removed
    p.expireWarn, p.expireSeconds = nil, nil
    -- 1.0.6: the 11-20 and 21-40 raid layouts start as copies of your raid layout
    if type(p.raid) == "table" then
        if p.raid20 == nil then p.raid20 = DeepCopy(p.raid) end
        if p.raid40 == nil then p.raid40 = DeepCopy(p.raid) end
    end
    if type(p.growth) == "string" then
        for _, k in ipairs({ "party", "raid" }) do
            p[k] = p[k] or {}
            if p[k].growth == nil then p[k].growth = p.growth end
        end
        p.growth = nil
    end
end

function L:ActivateProfile()
    MigrateProfile(LifelineDB.default)
    MigrateProfile(L.cdb.profile)
    if L.cdb.useOwnProfile then
        L.cdb.profile = CopyDefaults(L.defaults, L.cdb.profile)
        L.db = L.cdb.profile
    else
        LifelineDB.default = CopyDefaults(L.defaults, LifelineDB.default)
        L.db = LifelineDB.default
    end
end

function L:ProfileName()
    return L.cdb.useOwnProfile and ((UnitName("player") or "Character") .. " (own)") or "Default"
end

-- switch this character between Default and its own settings
function L:SetUseOwnProfile(own)
    if InCombatLockdown() then L:Print("You can't switch profiles in combat.") return end
    own = own and true or false
    if own == (L.cdb.useOwnProfile and true or false) then return end
    -- first time going character-specific: start from a copy of Default
    if own and (type(L.cdb.profile) ~= "table" or next(L.cdb.profile) == nil) then
        L.cdb.profile = DeepCopy(LifelineDB.default)
    end
    L.cdb.useOwnProfile = own
    L:ApplyProfileChange()
end

function L:CopyDefaultToCharacter()
    if InCombatLockdown() then return end
    L.cdb.profile = DeepCopy(LifelineDB.default)
    L:ApplyProfileChange()
end

function L:ResetCurrentProfile()
    if InCombatLockdown() then return end
    for k in pairs(L.db) do L.db[k] = nil end
    CopyDefaults(L.defaults, L.db)
    L:ApplyProfileChange()
end

function L:ApplyProfileChange()
    L:ActivateProfile()
    L:Refresh(true)
    if L.Anchor_Update then L:Anchor_Update() end
    if L.Minimap_Update then L:Minimap_Update() end
    if L.HideBlizzard_Apply then L:HideBlizzard_Apply() end
    if L.Options_RefreshControls then L:Options_RefreshControls() end
end

L:On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    LifelineDB = LifelineDB or {}
    -- older installs kept settings at the top level: move them into Default
    if LifelineDB.default == nil then
        local old = LifelineDB
        LifelineDB = { default = (next(old) ~= nil) and old or {} }
    end
    LifelineCharDB = CopyDefaults(L.charDefaults, LifelineCharDB)
    L.cdb = LifelineCharDB
    L:ActivateProfile()
    if L.OnInitialize then L:OnInitialize() end
end)

L:On("PLAYER_LOGIN", function()
    if L.Headers_Create   then L:Headers_Create() end
    if L.HideBlizzard_Apply then L:HideBlizzard_Apply() end
    if L.ClickCast_Apply  then L:ClickCast_Apply() end
    if L.Minimap_Create   then L:Minimap_Create() end
    L:Print("v" .. L.version .. " loaded. Type |cff" .. ACCENT_HEX .. "/ll|r for options.")
end)

------------------------------------------------------------------------
-- Settings refresh (called by the options panel)
------------------------------------------------------------------------
function L:Refresh(full)
    if L.Ind_InvalidateCache then L:Ind_InvalidateCache() end
    if full and L.Headers_ApplyLayout then
        L:RunAfterCombat("layout", function() L:Headers_ApplyLayout() end)
    end
    if L.Buttons_RefreshAll then L:Buttons_RefreshAll() end
    if L.Preview_Refresh then L:Preview_Refresh() end
    if L.Example_Refresh then L:Example_Refresh() end
    if L.Opt and L.Opt.win and L.Opt.win:IsShown() and L.Options_RefreshControls then L:Options_RefreshControls() end
end

------------------------------------------------------------------------
-- Run fn once, `delay` seconds after the last call with this key. Roster and
-- aura events come in bursts (a raid forming can fire dozens in a second);
-- this collapses each burst into a single run.
------------------------------------------------------------------------
local debounced = {}
function L:Debounce(key, delay, fn)
    if debounced[key] then return end
    debounced[key] = true
    C_Timer.After(delay, function()
        debounced[key] = nil
        fn()
    end)
end

------------------------------------------------------------------------
-- Raid layout for a raid size (Layout > Separate layouts by raid size)
------------------------------------------------------------------------
function L:RaidSizeKey(size)
    if not L.db.raidBySize then return "raid" end
    size = size or (IsInRaid() and GetNumGroupMembers() or 10)
    if size > 20 then return "raid40" elseif size > 10 then return "raid20" end
    return "raid"
end
function L:RaidCfg(size) return L.db[L:RaidSizeKey(size)] or L.db.raid end

-- rebuild the raid layout when the raid crosses 10 or 20 players
local lastRaidKey
L:On("GROUP_ROSTER_UPDATE", function()
    if not L.db or not L.db.raidBySize then lastRaidKey = nil return end
    local key = L:RaidSizeKey()
    if key ~= lastRaidKey then
        lastRaidKey = key
        if L.Headers_ApplyLayout then
            L:RunAfterCombat("layout", function() L:Headers_ApplyLayout() end)
        end
    end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
SLASH_LIFELINE1 = "/lifeline"
SLASH_LIFELINE2 = "/ll"
SlashCmdList.LIFELINE = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "lock" then
        L:SetLocked(true)
    elseif msg == "unlock" or msg == "move" then
        L:SetLocked(false)
    elseif msg == "test" or msg == "preview" then
        if L.Preview_Toggle then L:Preview_Toggle() end
    elseif msg == "debug" then
        if L.Debug_Report then L:Debug_Report() end
    elseif msg == "news" or msg == "whatsnew" or msg == "changes" then
        if L.WhatsNew_Show then L:WhatsNew_Show() end
    elseif msg == "showcase" or msg == "test all" then
        if L.Showcase_Toggle then L:Showcase_Toggle() end
    elseif msg == "reset" then
        L.db.position = CopyDefaults(L.defaults.position, {})
        L:Refresh(true)
        L:Print("Frame position reset.")
    elseif msg == "minimap" then
        L.db.minimap.hide = not L.db.minimap.hide
        if L.Minimap_Update then L:Minimap_Update() end
    elseif msg == "help" then
        L:Print("/ll - open settings")
        L:Print("/ll unlock | lock - move the frames")
        L:Print("/ll test - toggle the preview layout")
        L:Print("/ll showcase - preview with every indicator switched on")
        L:Print("/ll news - what's new in this version")
        L:Print("/ll reset - reset frame position")
        L:Print("/ll minimap - toggle the minimap button")
    else
        if L.Options_Toggle then L:Options_Toggle() end
    end
end

function L:SetLocked(locked)
    L.db.locked = locked
    if L.Anchor_Update then L:Anchor_Update() end
    L:Print(locked and "Frames locked." or "Frames unlocked - drag the green bar to move.")
    if L.Options_RefreshControls then L:Options_RefreshControls() end
end

function Lifeline_OnAddonCompartmentClick()
    if L.Options_Toggle then L:Options_Toggle() end
end
