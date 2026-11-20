--[[
    Lifeline - Settings window: shared state, data binding and page helpers
]]

local _, L = ...
local C = L.C

-- Shared state + helpers for the settings window, used by OptionsPages.lua,
-- OptionsExample.lua and OptionsWindow.lua through L.Opt.
local O = {}
O.PAGE_BUILDERS = {}   -- page name -> builder, filled by the Options*.lua page files
L.Opt = O
O.pages, O.tabs = {}, {}
local controls = {}   -- every widget with :Refresh()

------------------------------------------------------------------------
-- DB binding helpers
------------------------------------------------------------------------
local function Bind(tblFn, key, full)
    local get = function() return tblFn()[key] end
    local set = function(v)
        tblFn()[key] = v
        L:Refresh(full)
    end
    return get, set
end
local function DB() return L.db end
local function PARTY() return L.db.party end
local function PETS() return L.db.pets end
-- the raid layout being edited (Layout > Separate layouts by raid size)
O.raidEdit = "raid"
local function RAID()
    if not L.db.raidBySize then return L.db.raid end
    return L.db[O.raidEdit] or L.db.raid
end
O.RaidEditing = RAID

local function Track(w) controls[#controls + 1] = w return w end

function L:Options_RefreshControls()
    for _, w in ipairs(controls) do if w.Refresh then w.Refresh() end end
    if O.win and O.win.lockBtn then
        O.win.lockBtn.text:SetText(L.db.locked and "Unlock Frames" or "Lock Frames")
    end
    if O.win and O.win.profileText then
        O.win.profileText:SetText("Profile: " .. L:ProfileName())
    end
end

------------------------------------------------------------------------
-- Page layout: two columns that stack downwards
------------------------------------------------------------------------
local function NewPage(name)
    local p = CreateFrame("Frame", nil, O.win.body)
    p:SetAllPoints()
    p:Hide()
    p.y = { -6, -6 }
    p.x = { 0, 290 }
    function p:Add(w, col, gap)
        col = col or 1
        w:SetParent(self)
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", self.x[col], self.y[col])
        self.y[col] = self.y[col] - (w:GetHeight() + (gap or 8))
        return w
    end
    function p:Head(text, col)
        local h = L.Header(self, text)
        h:SetWidth(col and 270 or 560)
        self:Add(h, col or 1, 6)
        if not col then self.y[2] = self.y[1] end
        return h
    end
    function p:Sync() local m = math.min(self.y[1], self.y[2]) self.y[1], self.y[2] = m, m end
    -- extra breathing room before the next block (both columns)
    function p:Space(n) self:Sync() self.y[1] = self.y[1] - (n or 12) self.y[2] = self.y[1] end
    O.pages[name] = p
    return p
end

local function Check(page, col, label, tblFn, key, full, tip)
    local g, s = Bind(tblFn, key, full)
    local w = L.Check(page, label, g, s, tip)
    w:SetWidth(270)
    return page:Add(Track(w), col, 4)
end
local function Slider(page, col, label, minV, maxV, step, tblFn, key, full, fmt)
    local g, s = Bind(tblFn, key, full)
    local w = L.Slider(page, label, minV, maxV, step, g, s, fmt)
    w:SetWidth(260)
    return page:Add(Track(w), col, 10)
end
local function Drop(page, col, label, opts, tblFn, key, full)
    local g, s = Bind(tblFn, key, full)
    local w = L.Dropdown(page, label, opts, g, s, 260)
    return page:Add(Track(w), col, 10)
end
local function Note(page, col, text, width)
    local f = CreateFrame("Frame", nil, page)
    local t = L.Text(f, 11, C.muted)
    t:SetPoint("TOPLEFT")
    t:SetWidth(width or 260)
    t:SetWordWrap(true)
    t:SetText(text)
    f:SetSize(width or 260, math.max(14, t:GetStringHeight()))
    f.text = t
    -- a note wider than one column spans both: start below both columns,
    -- and push both down, so nothing in the other column runs into it
    if (width or 260) > 300 then
        page:Sync()
        page:Add(f, col, 8)
        page:Sync()
        return f
    end
    return page:Add(f, col, 8)
end

------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------
-- growth labels depend on the orientation they're paired with
local GROWTH_TEXT = {
    VERTICAL = {
        DOWN_RIGHT = "Top to bottom, columns left to right",
        DOWN_LEFT  = "Top to bottom, columns right to left",
        UP_RIGHT   = "Bottom to top, columns left to right",
        UP_LEFT    = "Bottom to top, columns right to left",
    },
    HORIZONTAL = {
        DOWN_RIGHT = "Left to right, rows going down",
        DOWN_LEFT  = "Right to left, rows going down",
        UP_RIGHT   = "Left to right, rows going up",
        UP_LEFT    = "Right to left, rows going up",
    },
}
local GROWTH_ORDER = { "DOWN_RIGHT", "DOWN_LEFT", "UP_RIGHT", "UP_LEFT" }
local function GrowthOptions(cfgFn)
    local opts = {}
    for i, v in ipairs(GROWTH_ORDER) do opts[i] = { value = v, text = v } end
    opts.Relabel = function()
        local t = GROWTH_TEXT[cfgFn().orientation] or GROWTH_TEXT.VERTICAL
        for _, o in ipairs(opts) do o.text = t[o.value] end
    end
    opts.Relabel()
    return opts
end
local ORIENT = { { value = "VERTICAL", text = "Vertical (columns)" }, { value = "HORIZONTAL", text = "Horizontal (rows)" } }
local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end


-- exported for the other Options*.lua files
O.Bind, O.Track = Bind, Track
O.DB, O.PARTY, O.RAID, O.PETS = DB, PARTY, RAID, PETS
O.NewPage, O.Check, O.Slider, O.Drop, O.Note = NewPage, Check, Slider, Drop, Note
O.GrowthOptions, O.ORIENT, O.pct = GrowthOptions, ORIENT, pct

