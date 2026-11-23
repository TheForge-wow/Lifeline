--[[
    Lifeline - Click-casting
    Bind mouse buttons and the scroll wheel (+ Shift/Ctrl/Alt) to target, menu,
    focus, a spell or a macro.

    Mouse buttons are plain secure attributes on each unit button. The scroll
    wheel can't "click" a frame, so while the mouse is over a Lifeline frame a
    secure snippet points the wheel bindings at a hidden proxy button that
    carries the hovered unit; leaving the frame gives the wheel back to the
    camera.
    Bindings are stored per character and applied as secure attributes, so they
    work in combat. If Clique is installed, Lifeline leaves click-casting to it.
]]

local _, L = ...

-- Built-in buttons. Mouse buttons 4+ are added per character from the
-- Click-Casting tab (cdb.clickCast.extraButtons). Buttons 4 and 5 can click a
-- frame directly; 6 and up can't, so like the wheel they're bound to the hidden
-- proxy while your cursor is over a Lifeline frame ("proxy" = virtual button).
local BASE_TOP = {
    { key = "BUTTON1", label = "Left Click",   n = 1 },
    { key = "BUTTON2", label = "Right Click",  n = 2 },
    { key = "BUTTON3", label = "Middle Click", n = 3 },
}
local BASE_BOTTOM = {
    { key = "WHEELUP",   label = "Scroll Up",   wheel = "wheelup",   bindKey = "MOUSEWHEELUP" },
    { key = "WHEELDOWN", label = "Scroll Down", wheel = "wheeldown", bindKey = "MOUSEWHEELDOWN" },
}
L.CC_EXTRA_MIN, L.CC_EXTRA_MAX = 4, 16

function L:CC_ExtraButton(n)
    if n <= 5 then
        return { key = "BUTTON" .. n, label = "Button " .. n, n = n, extra = true }
    end
    return { key = "BUTTON" .. n, label = "Button " .. n, wheel = "button" .. n, bindKey = "BUTTON" .. n, extra = n }
end

-- every button the user can bind, in display order
function L:CC_GetButtons()
    local list = {}
    for _, b in ipairs(BASE_TOP) do list[#list + 1] = b end
    local extras = (L.cdb and L.cdb.clickCast and L.cdb.clickCast.extraButtons) or {}
    local nums = {}
    for _, n in ipairs(extras) do
        n = tonumber(n)
        if n and n >= L.CC_EXTRA_MIN and n <= L.CC_EXTRA_MAX then nums[#nums + 1] = n end
    end
    table.sort(nums)
    for _, n in ipairs(nums) do
        local b = L:CC_ExtraButton(n)
        b.extraNum = n
        list[#list + 1] = b
    end
    for _, b in ipairs(BASE_BOTTOM) do list[#list + 1] = b end
    return list
end

function L:CC_AddButton(n)
    local cc = L.cdb.clickCast
    cc.extraButtons = cc.extraButtons or {}
    for _, v in ipairs(cc.extraButtons) do if v == n then return end end
    table.insert(cc.extraButtons, n)
    L:ClickCast_Apply()
end

function L:CC_RemoveButton(n)
    local cc = L.cdb.clickCast
    for i = #(cc.extraButtons or {}), 1, -1 do
        if cc.extraButtons[i] == n then table.remove(cc.extraButtons, i) end
    end
    -- forget its bindings on every modifier
    for _, mod in ipairs(L.CC_MODS) do cc.bindings[mod.key .. "BUTTON" .. n] = nil end
    L:ClickCast_Apply()
end

L.CC_MODS = {
    { key = "",       label = "",       attr = "" },
    { key = "SHIFT-", label = "Shift + ", attr = "shift-" },
    { key = "CTRL-",  label = "Ctrl + ",  attr = "ctrl-" },
    { key = "ALT-",   label = "Alt + ",   attr = "alt-" },
}
L.CC_TYPES = {
    { value = "none",   text = "Nothing" },
    { value = "target", text = "Target unit" },
    { value = "menu",   text = "Open unit menu" },
    { value = "focus",  text = "Set focus" },
    { value = "spell",  text = "Cast spell" },
    { value = "macro",  text = "Run macro text" },
}

------------------------------------------------------------------------
-- Ranks
-- A plain spell name ("Renew") casts the highest rank you know, so newly
-- trained ranks are picked up automatically. A binding with a rank in it
-- ("Renew(Rank 1)") keeps that rank when it's locked (bind.fixedRank) -
-- typing or shift-clicking a lower rank locks it, and the lock button on the
-- row switches the binding back to auto-upgrading.
------------------------------------------------------------------------
local RANK_PATTERNS = {
    "%s*%(%s*[Rr][Aa][Nn][Kk]%s*%d+%s*%)$",
    "%s+[Rr][Aa][Nn][Kk]%s*%d+$",
}

function L:CC_StripRank(name)
    name = (name or ""):match("^%s*(.-)%s*$")
    for _, pat in ipairs(RANK_PATTERNS) do name = name:gsub(pat, "") end
    return name
end

function L:CC_HasRank(value)
    value = (value or ""):match("^%s*(.-)%s*$")
    for _, pat in ipairs(RANK_PATTERNS) do
        if value:find(pat) then return true end
    end
    return false
end

-- the spell text a binding actually casts
function L:CC_SpellName(value, fixedRank)
    value = (value or ""):match("^%s*(.-)%s*$")
    if fixedRank and L:CC_HasRank(value) then
        -- normalize "Renew Rank 1" to the game's "Renew(Rank 1)"
        local base = L:CC_StripRank(value)
        local n = value:match("(%d+)%s*%)?$")
        return ("%s(Rank %s)"):format(base, n)
    end
    return L:CC_StripRank(value)
end

-- after the spell text of a binding changes: a typed rank locks it
function L:CC_SetSpellValue(bind, value)
    bind.value = value
    if L:CC_HasRank(value) then bind.fixedRank = true else bind.fixedRank = nil end
end

-- older versions had one "Always cast the highest rank" switch for everything
L:On("ADDON_LOADED", function(_, name)
    local cc = L.cdb and L.cdb.clickCast
    if not cc or cc.highestRank == nil then return end
    if cc.highestRank == false then
        for _, b in pairs(cc.bindings or {}) do
            if b.type == "spell" and L:CC_HasRank(b.value) then b.fixedRank = true end
        end
    end
    cc.highestRank = nil
end)

------------------------------------------------------------------------
-- Smart resurrection
-- A spell binding clicked on a dead friendly player casts your class's
-- resurrection instead (and, if chosen, its combat resurrection in combat).
-- Living players still get the bound spell. Spell IDs give us the name in the
-- game's language; the English name is the fallback.
------------------------------------------------------------------------
L.CC_SMARTRES = {
    { value = "OFF",    text = "Off" },
    { value = "NORMAL", text = "Out of combat" },
    { value = "COMBAT", text = "Also combat resurrection" },
}
local RES_SPELLS = {
    PRIEST      = { normal = { { 2006, "Resurrection" } } },
    PALADIN     = { normal = { { 7328, "Redemption" } } },
    SHAMAN      = { normal = { { 2008, "Ancestral Spirit" } } },
    DRUID       = { normal = { { 50769, "Revive" } }, combat = { { 20484, "Rebirth" } } },
    MONK        = { normal = { { 115178, "Resuscitate" } } },
    EVOKER      = { normal = { { 361227, "Return" } } },
    DEATHKNIGHT = { combat = { { 61999, "Raise Ally" } } },
}

-- the name of the first spell in the list that you actually know
local function KnownSpell(list)
    for _, entry in ipairs(list or {}) do
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(entry[1])
        if not L.Readable(name) then name = entry[2] end
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
        if info and L.Readable(info.name) then return info.name end
        if not C_Spell and GetSpellInfo and GetSpellInfo(name) then return name end
    end
end

function L:CC_ResSpells()
    local _, class = UnitClass("player")
    local set = RES_SPELLS[class or ""]
    if not set then return nil, nil end
    return KnownSpell(set.normal), KnownSpell(set.combat)
end

function L:CC_SmartResMacro(spell)
    local cc = L.cdb and L.cdb.clickCast
    local mode = cc and cc.smartRes or "OFF"
    if mode == "OFF" or not spell or spell == "" then return nil end
    local normal, combat = L:CC_ResSpells()
    if mode ~= "COMBAT" then combat = nil end
    if not normal and not combat then return nil end
    local parts = {}
    if normal then parts[#parts + 1] = "[@mouseover,help,dead,nocombat] " .. normal end
    if combat then parts[#parts + 1] = "[@mouseover,help,dead,combat] " .. combat end
    parts[#parts + 1] = "[@mouseover] " .. spell
    return "/cast " .. table.concat(parts, "; ")
end

-- re-apply when a resurrection spell is learned (or a respec drops one)
local lastRes
local function ResSignature()
    local a, b = L:CC_ResSpells()
    return tostring(a) .. "|" .. tostring(b)
end
L:On("SPELLS_CHANGED", function()
    local cc = L.cdb and L.cdb.clickCast
    if not cc or (cc.smartRes or "OFF") == "OFF" then return end
    local sig = ResSignature()
    if lastRes == nil then lastRes = sig return end
    if sig ~= lastRes then
        lastRes = sig
        L:ClickCast_Apply()
    end
end)

local applied = {}   -- attribute names we've set, so we can clear them

local function CliqueOwnsClicks()
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return isLoaded and isLoaded("Clique")
end
L.CliqueOwnsClicks = CliqueOwnsClicks

-- Build { {attrName, value}, ... } for the current bindings
-- wheelMode = true builds the proxy's attributes and also returns the list of
-- { "SHIFT-MOUSEWHEELUP", "wheelup" } bindings to set while hovering a frame
-- third result: menu bindings on anything but a plain right-click, as
-- { prefix, suffix }. WoW Forever only opens the unit menu straight from a
-- plain right-click, so those go through a helper button (MenuDelegate).
-- Targeting and focus go through a tiny macro instead of the game's built-in
-- "target"/"focus" actions: on WoW Forever the built-in ones are dropped when
-- a modifier is held (Shift + click did nothing). VuhDo does the same.
local TARGET_MACRO = "/target [@mouseover]"
local FOCUS_MACRO = "/focus [@mouseover]"

local function BuildAttributes(wheelMode)
    local out, wheelKeys, menus = {}, {}, {}
    local function add(k, v) out[#out + 1] = { k, v } end

    -- sensible defaults even with click-casting off
    if not wheelMode then
        add("*type1", "macro")
        add("*macrotext1", TARGET_MACRO)
        add("*type2", "togglemenu")
    end

    local cc = L.cdb and L.cdb.clickCast
    if not cc or not cc.enabled or CliqueOwnsClicks() then return out, wheelKeys, menus end

    for _, btn in ipairs(L:CC_GetButtons()) do
        for _, mod in ipairs(L.CC_MODS) do
            local bind = cc.bindings[mod.key .. btn.key]
            if bind and bind.type and (not btn.wheel) == (not wheelMode) then
                local p, n = mod.attr, btn.n
                if btn.wheel then
                    -- The wheel (and buttons 6+) "click" the proxy through a key binding.
                    -- On WoW Forever a binding click doesn't carry Shift/Ctrl/Alt into
                    -- the shift-/ctrl-/alt- attribute lookup, so the modifier goes into
                    -- the click's own name instead ("shiftwheelup") with no prefix.
                    local modName = mod.key:gsub("%-", ""):lower()
                    local click = modName .. btn.wheel
                    p, n = "", "-" .. click
                    if bind.type ~= "none" then
                        wheelKeys[#wheelKeys + 1] = { mod.key .. btn.bindKey, click }
                    end
                end
                if bind.type == "none" then
                    add(p .. "type" .. n, "")
                elseif bind.type == "target" then
                    add(p .. "type" .. n, "macro")
                    add(p .. "macrotext" .. n, TARGET_MACRO)
                elseif bind.type == "menu" then
                    add(p .. "type" .. n, "togglemenu")
                    if not btn.wheel and not (p == "" and tostring(n) == "2") then menus[#menus + 1] = { p, n } end
                elseif bind.type == "focus" then
                    add(p .. "type" .. n, "macro")
                    add(p .. "macrotext" .. n, FOCUS_MACRO)
                elseif bind.type == "spell" and bind.value and bind.value ~= "" then
                    local spell = L:CC_SpellName(bind.value, bind.fixedRank)
                    local res = L:CC_SmartResMacro(spell)
                    if bind.autoTarget then
                        -- auto target: make the player your target, then cast on them
                        add(p .. "type" .. n, "macro")
                        add(p .. "macrotext" .. n, "/target [@mouseover]\n" .. (res or ("/cast [@mouseover] " .. spell)))
                    elseif res then
                        add(p .. "type" .. n, "macro")
                        add(p .. "macrotext" .. n, res)
                    elseif p ~= "" then
                        -- with Shift/Ctrl/Alt held, WoW Forever drops the built-in
                        -- spell action (same as targeting did), so cast through a macro
                        add(p .. "type" .. n, "macro")
                        add(p .. "macrotext" .. n, "/cast [@mouseover] " .. spell)
                    else
                        add(p .. "type" .. n, "spell")
                        add(p .. "spell" .. n, spell)
                    end
                elseif bind.type == "macro" and bind.value and bind.value ~= "" then
                    add(p .. "type" .. n, "macro")
                    add(p .. "macrotext" .. n, bind.value)
                end
            end
        end
    end
    return out, wheelKeys, menus
end

------------------------------------------------------------------------
-- Unit menu on other clicks (middle-click, Shift-Right...)
-- The game's menu action only works when it comes straight from a plain
-- right-click. For any other click, the frame hands the click to a small
-- invisible helper button sitting on top of it, and the helper opens the
-- menu (on release). Same unit, same menu - the game's own.
------------------------------------------------------------------------
local function MenuDelegate(f)
    if f.__llMenu then return f.__llMenu end
    if InCombatLockdown() then return nil end
    local d = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
    d:EnableMouse(false)
    d:RegisterForClicks("AnyUp")
    d:SetAllPoints(f)
    d:SetAttribute("useparent-unit", true)
    d:SetAttribute("useOnKeyDown", false)
    d.__applied = {}
    f.__llMenu = d
    return d
end

local function ApplyMenus(f, menus)
    if InCombatLockdown() then return end
    local d = f.__llMenu
    if d then
        for name in pairs(d.__applied) do d:SetAttribute(name, nil) end
        wipe(d.__applied)
    end
    if #menus == 0 then return end
    d = MenuDelegate(f)
    if not d then return end
    for _, m in ipairs(menus) do
        local p, n = m[1], m[2]
        f:SetAttribute(p .. "type" .. n, "click")
        f:SetAttribute(p .. "clickbutton" .. n, d)
        d:SetAttribute(p .. "type" .. n, "togglemenu")
        d.__applied[p .. "type" .. n] = true
    end
end

------------------------------------------------------------------------
-- Click-casting on other unit frames (Click-Casting tab): the game's player,
-- target and focus frames, and frames from other addons that register for
-- click-casting the standard way (the ClickCastFrames list Clique made common).
------------------------------------------------------------------------
local otherApplied = {}   -- frame -> true while it carries our bindings

local function OtherFrames()
    local out = {}
    local cc = L.cdb and L.cdb.clickCast
    local o = cc and cc.otherFrames
    if not o or not cc.enabled or CliqueOwnsClicks() then return out end
    local function add(f) if f and f.SetAttribute and not f.__ll and not f:IsForbidden() then out[f] = true end end
    if o.player then add(_G.PlayerFrame) end
    if o.target then add(_G.TargetFrame) end
    if o.focus then add(_G.FocusFrame) end
    if o.addons and type(ClickCastFrames) == "table" then
        for f, on in pairs(ClickCastFrames) do
            if type(f) == "table" and on then add(f) end
        end
    end
    return out
end

-- Restricted-code snippet run by the header for every new button (works in combat)
function L:ClickCast_Snippet()
    local lines = {}
    for _, kv in ipairs(BuildAttributes()) do
        lines[#lines + 1] = ("self:SetAttribute(%q, %q)"):format(kv[1], kv[2])
    end
    return table.concat(lines, "\n    ")
end

function L:ClickCast_ApplyButton(b)
    if InCombatLockdown() or b.fake then return end
    for name in pairs(applied) do b:SetAttribute(name, nil) end
    local attrs, _, menus = BuildAttributes()
    for _, kv in ipairs(attrs) do
        b:SetAttribute(kv[1], kv[2])
    end
    ApplyMenus(b, menus)
end

function L:ClickCast_Apply()
    lastRes = ResSignature()
    L:RunAfterCombat("clickcast", function()
        lastRes = ResSignature()
        local attrs, _, menus = BuildAttributes()
        -- clear everything we set last time
        for _, b in ipairs(L.buttons) do
            if not b.fake then
                for name in pairs(applied) do b:SetAttribute(name, nil) end
            end
        end
        wipe(applied)
        for _, kv in ipairs(attrs) do applied[kv[1]] = true end
        for _, m in ipairs(menus) do applied[m[1] .. "clickbutton" .. m[2]] = true end
        for _, b in ipairs(L.buttons) do L:ClickCast_ApplyButton(b) end
        -- other unit frames: add ours, and give frames we no longer handle their defaults back
        local want = OtherFrames()
        for f in pairs(otherApplied) do
            if not want[f] then
                for name in pairs(applied) do f:SetAttribute(name, nil) end
                f:SetAttribute("*type1", "target")
                f:SetAttribute("*type2", "togglemenu")
                otherApplied[f] = nil
            end
        end
        for f in pairs(want) do
            for name in pairs(applied) do f:SetAttribute(name, nil) end
            for _, kv in ipairs(attrs) do f:SetAttribute(kv[1], kv[2]) end
            ApplyMenus(f, menus)
            otherApplied[f] = true
        end
        L:ClickCast_ApplyWheel()
        -- update the header snippet so new buttons get the same bindings
        for _, h in ipairs(L.headers or {}) do
            h:SetAttribute("initialConfigFunction", L:Headers_InitSnippet(h))
        end
    end)
end

------------------------------------------------------------------------
-- Scroll wheel
------------------------------------------------------------------------
local proxy, wheelHandler
local wrapped = {}          -- button -> true
local proxyApplied = {}

local function EnsureProxy()
    if proxy then return end
    proxy = CreateFrame("Button", "LifelineWheelProxy", UIParent, "SecureActionButtonTemplate")
    proxy:SetSize(1, 1)
    proxy:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 10, -10)  -- off screen
    proxy:SetAlpha(0)
    proxy:EnableMouse(false)
    proxy:RegisterForClicks("AnyUp", "AnyDown")
    proxy:Show()

    -- wheel "clicks" show in /ll debug too
    proxy:HookScript("PostClick", function(self, button, down) if L._LogClick then L._LogClick(self, button, down) end end)

    wheelHandler = CreateFrame("Frame", "LifelineWheelHandler", UIParent, "SecureHandlerBaseTemplate")
    wheelHandler:SetFrameRef("proxy", proxy)
end

-- One hover snippet for every frame, wrapped once. It reads the current wheel
-- keys from the handler's attributes, so changing a binding only updates those
-- attributes: no re-wrapping (an old wrapper left behind used to reset the keys
-- to the previous bindings until a /reload).
local ENTER_SNIPPET = [[
    local proxy = owner:GetFrameRef("proxy")
    proxy:SetAttribute("unit", self:GetAttribute("unit"))
    self:ClearBindings()
    local n = owner:GetAttribute("wk-n") or 0
    for i = 1, n do
        local key, click = owner:GetAttribute("wk-key" .. i), owner:GetAttribute("wk-click" .. i)
        if key and click then self:SetBindingClick(true, key, "LifelineWheelProxy", click) end
    end
]]
local LEAVE_SNIPPET = "self:ClearBindings()"

local function Unwrap(b)
    if not wrapped[b] then return end
    for _, script in ipairs({ "OnEnter", "OnLeave", "OnHide" }) do
        pcall(SecureHandlerUnwrapScript, b, script)
    end
    -- give the wheel back to the camera over Lifeline's own frames
    if b.__ll and b.EnableMouseWheel and not InCombatLockdown() then b:EnableMouseWheel(false) end
    wrapped[b] = nil
end

-- the wheel bindings set while hovering belong to the frame; outside secure
-- code the game clears them with ClearOverrideBindings (frames have no
-- ClearBindings method there)
local function ClearWheel(b)
    if ClearOverrideBindings and not InCombatLockdown() then pcall(ClearOverrideBindings, b) end
end

local currentEnter, currentKeys

-- /ll debug: what the wheel keys were bound to the last time you hovered a frame
L.wheelHover = nil
local function NoteHover(b)
    if not currentKeys then return end
    local lines = {}
    for _, kb in ipairs(currentKeys) do
        local ok, action = pcall(rawget(_G, "GetBindingAction") or function() return nil end, kb[1], true)
        lines[#lines + 1] = kb[1] .. " -> " .. ((ok and action and action ~= "") and action or "(nothing)")
    end
    local dt = rawget(_G, "date")
    L.wheelHover = { when = dt and dt("%H:%M:%S") or "?", unit = tostring(b:GetAttribute("unit")),
        wheel = b.IsMouseWheelEnabled and tostring(b:IsMouseWheelEnabled()) or "?", lines = lines }
end

local function WrapButton(b)
    if b.fake or InCombatLockdown() or not currentEnter then return end
    if not wheelHandler then return end
    if wrapped[b] then
        if b.EnableMouseWheel then b:EnableMouseWheel(true) end
        return
    end
    SecureHandlerWrapScript(b, "OnEnter", wheelHandler, ENTER_SNIPPET)
    SecureHandlerWrapScript(b, "OnLeave", wheelHandler, LEAVE_SNIPPET)
    SecureHandlerWrapScript(b, "OnHide", wheelHandler, LEAVE_SNIPPET)
    -- like Clique: the frame has to take mouse wheel events for wheel bindings to fire over it
    if b.EnableMouseWheel then b:EnableMouseWheel(true) end
    if not b.__llHoverNote then
        b.__llHoverNote = true
        b:HookScript("OnEnter", function(self) NoteHover(self) end)
    end
    wrapped[b] = true
end

function L:ClickCast_ApplyWheel()
    if InCombatLockdown() then return end
    EnsureProxy()
    local attrs, wheelKeys = BuildAttributes(true)

    for name in pairs(proxyApplied) do proxy:SetAttribute(name, nil) end
    wipe(proxyApplied)
    for _, kv in ipairs(attrs) do
        proxy:SetAttribute(kv[1], kv[2])
        proxyApplied[kv[1]] = true
    end

    currentKeys = #wheelKeys > 0 and wheelKeys or nil
    -- the hover snippet reads these
    local oldN = wheelHandler:GetAttribute("wk-n") or 0
    for i = 1, math.max(oldN, #wheelKeys) do
        local kb = wheelKeys[i]
        wheelHandler:SetAttribute("wk-key" .. i, kb and kb[1] or nil)
        wheelHandler:SetAttribute("wk-click" .. i, kb and kb[2] or nil)
    end
    wheelHandler:SetAttribute("wk-n", #wheelKeys)
    if #wheelKeys > 0 then
        currentEnter = true
        for _, b in ipairs(L.buttons) do WrapButton(b) end
        for f in pairs(OtherFrames()) do WrapButton(f) end
        for b in pairs(wrapped) do
            if not b.__ll and not otherApplied[b] then Unwrap(b) ClearWheel(b) end
        end
    else
        currentEnter = nil
        for b in pairs(wrapped) do
            if b.__ll then
                -- keep the (now empty) hover snippet; just give the wheel back to the camera
                if b.EnableMouseWheel then b:EnableMouseWheel(false) end
            else
                Unwrap(b)
            end
            ClearWheel(b)
        end
    end
end

-- Header-spawned buttons: apply bindings out of combat too (covers edits made after spawn)
hooksecurefunc(L, "Button_Init", function(_, b)
    if b.fake then return end
    if InCombatLockdown() then
        -- spawned mid-combat: mouse buttons already work via the header snippet,
        -- the scroll wheel hooks up as soon as combat ends
        L:RunAfterCombat("clickcast", function() L:ClickCast_Apply() end)
        return
    end
    L:ClickCast_ApplyButton(b)
    if currentEnter and not wrapped[b] then WrapButton(b) end
end)


------------------------------------------------------------------------
-- Self-cast key check
-- The game has a self-cast key (Alt by default). Holding it while casting
-- sends the spell to you, so a binding like Alt + Left Click = Renew would
-- heal you instead of the frame you clicked. We ask once per set of clashing
-- bindings and can switch the self-cast key off for you.
------------------------------------------------------------------------
local MOD_NAME = { ALT = "Alt", CTRL = "Ctrl", SHIFT = "Shift" }

function L:CC_SelfCastKey()
    local key = GetModifiedClick and GetModifiedClick("SELFCAST")
    key = L.Readable(key)
    if type(key) ~= "string" then return nil end
    key = key:upper()
    -- the setting can also read "ALT-CTRL" etc.; we only need the first part
    for mod in key:gmatch("[A-Z]+") do
        if MOD_NAME[mod] then return mod end
    end
end

-- list of binding labels that use the self-cast key, and a signature for them
function L:CC_SelfCastConflicts()
    local cc = L.cdb and L.cdb.clickCast
    local key = L:CC_SelfCastKey()
    if not cc or not cc.enabled or not key or CliqueOwnsClicks() then return nil end
    local hits = {}
    for _, btn in ipairs(L:CC_GetButtons()) do
        local bind = cc.bindings[key .. "-" .. btn.key]
        if bind and bind.type == "spell" and bind.value and bind.value ~= "" then
            hits[#hits + 1] = MOD_NAME[key] .. " + " .. btn.label
        end
    end
    if #hits == 0 then return nil end
    return hits, key .. ":" .. table.concat(hits, ","), MOD_NAME[key]
end

function L:CC_DisableSelfCastKey()
    if InCombatLockdown() then L:Print("Can't change the self-cast key in combat.") return end
    if not SetModifiedClick then return end
    pcall(SetModifiedClick, "SELFCAST", "NONE")
    if SaveBindings and GetCurrentBindingSet then pcall(SaveBindings, GetCurrentBindingSet()) end
    L:Print("Self-cast key turned off. You can set it again in the game's Key Bindings (Targeting).")
    if L.Options_RefreshControls then L:Options_RefreshControls() end
end

function L:CC_CheckSelfCast()
    if InCombatLockdown() or not L.Confirm then return end
    local hits, sig, keyName = L:CC_SelfCastConflicts()
    local cc = L.cdb and L.cdb.clickCast
    if not hits or cc.selfCastDeclined == sig then return end
    L.Confirm("Self-cast key clash",
        ("Your self-cast key is |cffffffff%s|r, and these bindings use it:\n|cffffffff%s|r\n\n" ..
         "Holding the self-cast key sends the spell to you instead of the frame you click. " ..
         "Turn the game's self-cast key off?"):format(keyName, table.concat(hits, ", ")),
        "Turn it off", "Keep it",
        function() L:CC_DisableSelfCastKey() end,
        function() cc.selfCastDeclined = sig end)
end

-- check a few seconds after login (out of combat) and after binding edits
L:On("PLAYER_LOGIN", function()
    C_Timer.After(4, function() L:CC_CheckSelfCast() end)
end)
hooksecurefunc(L, "ClickCast_Apply", function()
    if L.Opt and L.Opt.win and L.Opt.win:IsShown() then
        C_Timer.After(0.2, function() L:CC_CheckSelfCast() end)
    end
end)


------------------------------------------------------------------------
-- Presets: named sets of bindings, saved per class and shared by all your
-- characters of that class (LifelineDB.ccPresets[class][name]).
------------------------------------------------------------------------
local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = DeepCopy(v) end
    return o
end

local function PresetStore()
    LifelineDB.ccPresets = LifelineDB.ccPresets or {}
    local _, class = UnitClass("player")
    class = L.Readable(class) or "ANY"
    LifelineDB.ccPresets[class] = LifelineDB.ccPresets[class] or {}
    return LifelineDB.ccPresets[class]
end

function L:CC_PresetNames()
    local names = {}
    for n in pairs(PresetStore()) do names[#names + 1] = n end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

function L:CC_SavePreset(name)
    name = (name or ""):match("^%s*(.-)%s*$"):sub(1, 40)
    if name == "" then return false end
    local cc = L.cdb.clickCast
    PresetStore()[name] = { bindings = DeepCopy(cc.bindings), extraButtons = DeepCopy(cc.extraButtons or {}),
                            smartRes = cc.smartRes }
    L:Print(("Saved click-casting preset \"%s\"."):format(name))
    return true
end

function L:CC_LoadPreset(name)
    local p = PresetStore()[name or ""]
    if not p then return false end
    local cc = L.cdb.clickCast
    cc.bindings = DeepCopy(p.bindings or {})
    cc.extraButtons = DeepCopy(p.extraButtons or {})
    if p.smartRes then cc.smartRes = p.smartRes end
    L:ClickCast_Apply()
    L:Print(("Loaded click-casting preset \"%s\"%s."):format(name,
        InCombatLockdown() and " - it applies when combat ends" or ""))
    return true
end

function L:CC_DeletePreset(name)
    local store = PresetStore()
    if not store[name or ""] then return false end
    store[name] = nil
    return true
end


------------------------------------------------------------------------
-- Tooltip hint: your bindings, e.g. "Shift + Left  Renew(Rank 1)"
------------------------------------------------------------------------
local SHORT = { BUTTON1 = "Left", BUTTON2 = "Right", BUTTON3 = "Middle", WHEELUP = "Wheel up", WHEELDOWN = "Wheel down" }
local TYPE_TEXT = { target = "Target", menu = "Menu", focus = "Focus" }

function L:CC_TooltipLines()
    local cc = L.cdb and L.cdb.clickCast
    if not cc or not cc.enabled or CliqueOwnsClicks() then return nil end
    local lines = {}
    for _, mod in ipairs(L.CC_MODS) do
        for _, btn in ipairs(L:CC_GetButtons()) do
            local bind = cc.bindings[mod.key .. btn.key]
            local what
            if bind then
                if bind.type == "spell" and bind.value and bind.value ~= "" then
                    what = L:CC_SpellName(bind.value, bind.fixedRank)
                    if bind.autoTarget then what = what .. " + target" end
                elseif bind.type == "macro" and bind.value and bind.value ~= "" then
                    what = "Macro"
                else
                    what = TYPE_TEXT[bind.type]
                end
            end
            if what then
                local key = SHORT[btn.key] or btn.label
                lines[#lines + 1] = { mod.label .. key, what }
                if #lines >= 14 then return lines end
            end
        end
    end
    return lines
end

------------------------------------------------------------------------
-- Click log for /ll debug (1.2.0): the last few clicks on a frame, which
-- action the game resolved for each, and whether a menu was open right
-- after. Read-only - it never changes what a click does.
------------------------------------------------------------------------
L.clickLog = {}

local function MenuOpen()
    local ok, open = pcall(function()
        local m = Menu and Menu.GetManager and Menu.GetManager()
        return m and m.GetOpenMenu and m:GetOpenMenu() ~= nil
    end)
    if not ok then return "unknown" end
    return open and "yes" or "no"
end

local function LogClick(b, button, down)
    if b.fake then return end
    local mods = (IsShiftKeyDown() and "Shift-" or "") .. (IsControlKeyDown() and "Ctrl-" or "") .. (IsAltKeyDown() and "Alt-" or "")
    local resolved = "?"
    if SecureButton_GetModifiedAttribute then
        local ok, t = pcall(SecureButton_GetModifiedAttribute, b, "type", button)
        if ok then resolved = (type(t) == "string" and t ~= "") and t or "(nothing)" end
    end
    local entry = {
        when = date("%H:%M:%S"), click = mods .. tostring(button), down = down and "press" or "release",
        unit = tostring(b.unit or (b.GetAttribute and b:GetAttribute("unit"))), action = resolved, menu = "...",
    }
    table.insert(L.clickLog, 1, entry)
    while #L.clickLog > 5 do table.remove(L.clickLog) end
    C_Timer.After(0.15, function() entry.menu = MenuOpen() end)
end

L._LogClick = LogClick

hooksecurefunc(L, "Button_Init", function(_, b)
    if b.fake or b.__llClickLog then return end
    b.__llClickLog = true
    b:HookScript("PostClick", function(self, button, down) LogClick(self, button, down) end)
end)

function L:ClickLog_Lines()
    local out = {}
    for _, e in ipairs(L.clickLog) do
        out[#out + 1] = ("%s %s (%s) on %s -> action: %s | menu open after: %s"):format(e.when, e.click, e.down, e.unit, e.action, e.menu)
    end
    return out
end
