--[[
    Lifeline - Import / Export
    Settings are turned into a plain text string you can paste anywhere
    (Discord, a website, another character). The format is our own simple
    serializer + base64 - nothing in an import string is ever run as code,
    and every value is checked against Lifeline's own defaults before use.
]]

local _, L = ...

local HEADER = "LIFELINE1:"

------------------------------------------------------------------------
-- Serializer
--   n<number>;  s<len>:<bytes>  T  F  t ...pairs... e
------------------------------------------------------------------------
local function Serialize(v, out)
    local t = type(v)
    if t == "number" then
        out[#out + 1] = "n" .. tostring(v) .. ";"
    elseif t == "string" then
        out[#out + 1] = "s" .. #v .. ":" .. v
    elseif t == "boolean" then
        out[#out + 1] = v and "T" or "F"
    elseif t == "table" then
        out[#out + 1] = "t"
        for k, val in pairs(v) do
            local kt, vt = type(k), type(val)
            if (kt == "string" or kt == "number") and (vt == "string" or vt == "number" or vt == "boolean" or vt == "table") then
                Serialize(k, out)
                Serialize(val, out)
            end
        end
        out[#out + 1] = "e"
    end
end

local function Deserialize(str)
    local pos = 1
    local depth = 0
    local function read()
        local c = str:sub(pos, pos)
        if c == "n" then
            local e = str:find(";", pos, true)
            if not e then error("bad number") end
            local n = tonumber(str:sub(pos + 1, e - 1))
            if not n then error("bad number") end
            pos = e + 1
            return n
        elseif c == "s" then
            local colon = str:find(":", pos, true)
            if not colon then error("bad string") end
            local len = tonumber(str:sub(pos + 1, colon - 1))
            if not len or len < 0 then error("bad string") end
            local s = str:sub(colon + 1, colon + len)
            if #s ~= len then error("bad string") end
            pos = colon + len + 1
            return s
        elseif c == "T" then pos = pos + 1 return true
        elseif c == "F" then pos = pos + 1 return false
        elseif c == "t" then
            depth = depth + 1
            if depth > 20 then error("too deep") end
            pos = pos + 1
            local t = {}
            while str:sub(pos, pos) ~= "e" do
                if pos > #str then error("unterminated table") end
                local k = read()
                if type(k) == "table" then error("bad key") end
                t[k] = read()
            end
            pos = pos + 1
            depth = depth - 1
            return t
        end
        error("unexpected data")
    end
    local ok, v = pcall(read)
    if not ok then return nil, v end
    return v
end

------------------------------------------------------------------------
-- Base64
------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64DEC = {}
for i = 1, 64 do B64DEC[B64:sub(i, i)] = i - 1 end

local function Encode(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

local function Decode(data)
    data = data:gsub("[^%w%+/=]", "")
    if #data % 4 ~= 0 then return nil end
    local out = {}
    for i = 1, #data, 4 do
        local q = { data:byte(i, i + 3) }
        local v, pad = 0, 0
        for j = 1, 4 do
            local ch = string.char(q[j])
            local d
            if ch == "=" then d = 0 pad = pad + 1 else d = B64DEC[ch] end
            if not d then return nil end
            v = v * 64 + d
        end
        local b1 = math.floor(v / 65536) % 256
        local b2 = math.floor(v / 256) % 256
        local b3 = v % 256
        out[#out + 1] = string.char(b1)
        if pad < 2 then out[#out + 1] = string.char(b2) end
        if pad < 1 then out[#out + 1] = string.char(b3) end
    end
    return table.concat(out)
end

------------------------------------------------------------------------
-- Validation: only keep values whose key and type match the defaults
------------------------------------------------------------------------
local function Sanitize(src, defaults)
    local out = {}
    for k, def in pairs(defaults) do
        local v = src[k]
        if type(def) == "table" then
            if type(v) == "table" then out[k] = Sanitize(v, def) end
        elseif type(v) == type(def) then
            out[k] = v
        end
    end
    return out
end

local VALID_CC = {}
for _, t in ipairs(L.CC_TYPES) do VALID_CC[t.value] = true end

local function SanitizeClickCast(src)
    if type(src) ~= "table" then return nil end
    local out = { enabled = src.enabled ~= false, bindings = {}, extraButtons = {},
                  smartRes = "OFF",
                  selfCastDeclined = (L.cdb and L.cdb.clickCast and L.cdb.clickCast.selfCastDeclined) or "" }
    out.otherFrames = { player = false, target = false, focus = false, addons = false }
    if type(src.otherFrames) == "table" then
        for k in pairs(out.otherFrames) do out.otherFrames[k] = src.otherFrames[k] == true end
    end
    for _, o in ipairs(L.CC_SMARTRES) do
        if src.smartRes == o.value then out.smartRes = o.value end
    end
    if type(src.extraButtons) == "table" then
        for _, n in ipairs(src.extraButtons) do
            if type(n) == "number" and n >= L.CC_EXTRA_MIN and n <= L.CC_EXTRA_MAX and n % 1 == 0 then
                out.extraButtons[#out.extraButtons + 1] = n
            end
        end
    end
    if type(src.bindings) == "table" then
        for key, b in pairs(src.bindings) do
            if type(key) == "string" and #key < 40 and key:match("^[A-Z%-]+%w*$")
                and type(b) == "table" and VALID_CC[b.type] then
                local value = type(b.value) == "string" and b.value:sub(1, 255) or nil
                out.bindings[key] = { type = b.type, value = value, fixedRank = (b.fixedRank == true) or nil,
                    autoTarget = (b.autoTarget == true) or nil }
            end
        end
    end
    return out
end

local function SanitizeSounds(src)
    if type(src) ~= "table" or type(src.list) ~= "table" then return nil end
    local function valid(list, v)
        for _, o in ipairs(list) do if o.value == v then return true end end
    end
    local out = { enabled = src.enabled ~= false, list = {} }
    for i = 1, math.min(#src.list, L.SOUND_MAX) do
        local e = src.list[i]
        if type(e) == "table" and type(e.spell) == "string" and e.spell ~= "" then
            out.list[#out.list + 1] = {
                spell = e.spell:sub(1, 80),
                trigger = valid(L.SOUND_TRIGGERS, e.trigger) and e.trigger or "ADDED",
                who = valid(L.SOUND_WHO, e.who) and e.who or "ALL",
                sound = valid(L.SOUNDS, e.sound) and e.sound or "chime",
            }
        end
    end
    return out
end

local function SanitizeIndicators(src)
    if type(src) ~= "table" then return nil end
    local anchors, modes, sizes = {}, {}, {}
    for _, a in ipairs(L.IND_ANCHORS) do anchors[a.value] = true end
    for _, m in ipairs(L.IND_MODES) do modes[m.value] = true end
    for _, s in ipairs(L.IND_SIZES) do sizes[s.value] = true end
    local out = {}
    for i = 1, math.min(#src, L.IND_MAX) do
        local ind = src[i]
        if type(ind) == "table" and type(ind.spell) == "string" and ind.spell ~= "" then
            out[#out + 1] = {
                spell  = ind.spell:sub(1, 100),
                anchor = anchors[ind.anchor] and ind.anchor or "TOPRIGHT",
                mode   = modes[ind.mode] and ind.mode or "MINE",
                size   = sizes[ind.size] and ind.size or 14,
            }
        end
    end
    return out
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------
-- parts = { settings = bool, clickCast = bool, indicators = bool }
function L:Profile_Export(parts)
    local payload = { v = 1, addon = "Lifeline", version = L.version }
    if parts.settings then payload.settings = L.db end
    if parts.clickCast then payload.clickCast = L.cdb.clickCast end
    if parts.indicators then
        payload.indicators = L.cdb.indicators
        payload.auraSounds = L.cdb.auraSounds
    end
    local out = {}
    Serialize(payload, out)
    return HEADER .. Encode(table.concat(out))
end

local function ReplaceContents(dst, src)
    for k in pairs(dst) do dst[k] = nil end
    for k, v in pairs(src) do dst[k] = v end
end

-- returns ok, message
function L:Profile_Import(text, parts)
    text = (text or ""):gsub("%s", "")
    if text == "" then return false, "Paste an import string into the box first." end
    if text:sub(1, #HEADER) ~= HEADER then return false, "That isn't a Lifeline import string." end
    local raw = Decode(text:sub(#HEADER + 1))
    if not raw then return false, "The import string is damaged - make sure you copied all of it." end
    local payload = Deserialize(raw)
    if type(payload) ~= "table" or payload.addon ~= "Lifeline" then
        return false, "The import string is damaged - make sure you copied all of it."
    end
    if InCombatLockdown() then return false, "You can't import in combat." end

    local done = {}
    if parts.settings and type(payload.settings) == "table" then
        local clean = L.CopyDefaults(L.defaults, Sanitize(payload.settings, L.defaults))
        -- class color overrides: only known class tokens with numeric 0-1 r/g/b
        clean.classColors = {}
        for _, key in ipairs(L.DEBUFF_LISTS) do
            local src = payload.settings[key]
            if type(src) == "table" then
                local list = {}
                for n = 1, math.min(#src, 40) do
                    if type(src[n]) == "string" and src[n] ~= "" then list[#list + 1] = src[n]:sub(1, 80) end
                end
                clean[key] = list
            end
        end
        if type(payload.settings.classColors) == "table" then
            for class, c in pairs(payload.settings.classColors) do
                if type(class) == "string" and RAID_CLASS_COLORS[class] and type(c) == "table"
                    and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
                    clean.classColors[class] = {
                        r = math.min(1, math.max(0, c.r)), g = math.min(1, math.max(0, c.g)), b = math.min(1, math.max(0, c.b)),
                    }
                end
            end
        end
        -- custom dispel colors: only the four types, numeric 0-1 r/g/b
        clean.dispelCustom = {}
        if type(payload.settings.dispelCustom) == "table" then
            for _, k in ipairs({ "Magic", "Curse", "Disease", "Poison" }) do
                local c = payload.settings.dispelCustom[k]
                if type(c) == "table" and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
                    clean.dispelCustom[k] = { r = math.min(1, math.max(0, c.r)), g = math.min(1, math.max(0, c.g)), b = math.min(1, math.max(0, c.b)) }
                end
            end
        end
        ReplaceContents(L.db, clean)
        if L.DispelColorsChanged then L:DispelColorsChanged() end
        done[#done + 1] = "layout & appearance"
    end
    if parts.clickCast then
        local cc = SanitizeClickCast(payload.clickCast)
        if cc then
            L.cdb.clickCast = cc
            done[#done + 1] = "click-casting"
        end
    end
    if parts.indicators then
        local inds = SanitizeIndicators(payload.indicators)
        if inds then
            L.cdb.indicators = inds
            done[#done + 1] = #inds .. " buff indicator" .. (#inds == 1 and "" or "s")
        end
        local snd = SanitizeSounds(payload.auraSounds)
        if snd then
            L.cdb.auraSounds = snd
            done[#done + 1] = #snd.list .. " aura sound" .. (#snd.list == 1 and "" or "s")
            if L.Sounds_Request then L:Sounds_Request() end
        end
    end
    if #done == 0 then return false, "Nothing to import - the string doesn't contain the parts you ticked." end

    L:Refresh(true)
    L:Anchor_Update()
    if L.ClickCast_Apply then L:ClickCast_Apply() end
    if L.Minimap_Update then L:Minimap_Update() end
    if L.Options_RefreshControls then L:Options_RefreshControls() end
    return true, "Imported " .. table.concat(done, ", ") .. "."
end

-- what an import string contains, for the status line
function L:Profile_Peek(text)
    text = (text or ""):gsub("%s", "")
    if text:sub(1, #HEADER) ~= HEADER then return nil end
    local raw = Decode(text:sub(#HEADER + 1))
    local payload = raw and Deserialize(raw)
    if type(payload) ~= "table" or payload.addon ~= "Lifeline" then return nil end
    return {
        settings = type(payload.settings) == "table",
        clickCast = type(payload.clickCast) == "table",
        indicators = type(payload.indicators) == "table" and #payload.indicators or nil,
        version = type(payload.version) == "string" and payload.version or "?",
    }
end
