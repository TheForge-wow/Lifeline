--[[
    Lifeline - Bar textures and fonts
    Uses LibSharedMedia-3.0 when another addon has loaded it (most UI packs
    do), so every bar texture and font they register can be picked in
    Textures & Colors. Without it you get Lifeline's flat bar and the game font.
]]

local _, L = ...

L.DEFAULT_TEXTURE = "Lifeline Flat"
L.DEFAULT_FONT = "Game default"

local registered = false
local function LSM()
    local lib = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lib and not registered then
        registered = true
        pcall(lib.Register, lib, "statusbar", L.DEFAULT_TEXTURE, L.WHITE)
    end
    return lib
end

function L:BarTexture()
    local name = L.db and L.db.barTexture
    if not name or name == L.DEFAULT_TEXTURE then return L.WHITE end
    local lib = LSM()
    local path = lib and lib:Fetch("statusbar", name, true)
    return path or L.WHITE
end

function L:FrameFont()
    local name = L.db and L.db.frameFont
    if not name or name == L.DEFAULT_FONT then return L.FONT end
    local lib = LSM()
    local path = lib and lib:Fetch("font", name, true)
    return path or L.FONT
end

------------------------------------------------------------------------
-- Names in any alphabet (1.2.0)
-- Most fonts only have English/Western letters, so a Russian, Korean or
-- Chinese name came out as boxes. Names now use a font family: your chosen
-- font for normal letters, and the game's own fonts for other alphabets,
-- picked letter by letter by the game.
------------------------------------------------------------------------
local FALLBACK = {
    { alphabet = "korean",             file = "Fonts\\2002.TTF" },
    { alphabet = "simplifiedchinese",  file = "Fonts\\ARKai_T.ttf" },
    { alphabet = "traditionalchinese", file = "Fonts\\blei00d.TTF" },
    { alphabet = "russian",            file = "Fonts\\FRIZQT___CYR.TTF" },
}
local families, familyCount = {}, 0

local function Family(path, size, flags)
    local key = ("%s|%d|%s"):format(path, size, flags or "")
    if families[key] ~= nil then return families[key] or nil end
    families[key] = false
    local create = rawget(_G, "CreateFontFamily")
    if not create then return nil end
    local members = { { alphabet = "roman", file = path, height = size, flags = flags or "" } }
    for _, m in ipairs(FALLBACK) do
        members[#members + 1] = { alphabet = m.alphabet, file = m.file, height = size, flags = flags or "" }
    end
    familyCount = familyCount + 1
    local ok, fam = pcall(create, "LifelineNameFont" .. familyCount, members)
    if ok and fam then families[key] = fam end
    return families[key] or nil
end

------------------------------------------------------------------------
-- Text outline (1.2.3): names and health text on light class colors
-- (priest white, rogue yellow) washed out with only a thin drop shadow.
------------------------------------------------------------------------
local OUTLINE_FLAGS = { SHADOW = "", THIN = "OUTLINE", THICK = "THICKOUTLINE", NONE = "" }
function L:TextOutlineFlags()
    return OUTLINE_FLAGS[L.db and L.db.textOutline or "THIN"] or "OUTLINE"
end
-- call after the font is set: a font object brings its own shadow along
function L:TextOutlineShadow(fs)
    local style = L.db and L.db.textOutline or "THIN"
    if style == "SHADOW" then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
end

-- give a name FontString the frame font, with other alphabets covered
function L:SetNameFont(fs, size, flags)
    local path = L:FrameFont()
    local fam = Family(path, size, flags)
    if fam and pcall(fs.SetFontObject, fs, fam) then return end
    fs:SetFont(path, size, flags or "")
end

-- options for the Textures & Colors dropdowns (refilled every time the page opens)
-- each option carries its file so the menu can draw a preview of it
-- (fonts are written in their own font, textures get a sample bar)
local function Fill(list, kind, default, defaultPath)
    wipe(list)
    local key = (kind == "font") and "font" or "texture"
    list[1] = { value = default, text = default, [key] = defaultPath }
    local lib = LSM()
    if lib then
        for _, name in ipairs(lib:List(kind) or {}) do
            if name ~= default then
                list[#list + 1] = { value = name, text = name, [key] = lib:Fetch(kind, name, true) }
            end
        end
    end
    return list
end
L.TEXTURE_OPTIONS, L.FONT_OPTIONS = {}, {}
function L:Media_RefreshLists()
    Fill(L.TEXTURE_OPTIONS, "statusbar", L.DEFAULT_TEXTURE, L.WHITE)
    Fill(L.FONT_OPTIONS, "font", L.DEFAULT_FONT, L.FONT)
    return LSM() ~= nil
end

-- textures registered after we load show up when the settings page opens;
-- re-style frames once everything is in so a saved texture/font is found
L:On("PLAYER_LOGIN", function()
    C_Timer.After(1, function()
        if L.Buttons_RefreshAll and L.db and (L.db.barTexture ~= L.DEFAULT_TEXTURE or L.db.frameFont ~= L.DEFAULT_FONT) then
            L:Buttons_RefreshAll()
        end
    end)
end)

-- A font file from another addon is loaded the first time something uses it,
-- and text set while it's still loading keeps the old font. Re-applying a
-- moment later picks it up, so a new font shows without a /reload.
function L:Media_ReapplySoon()
    for _, delay in ipairs({ 0.1, 0.5, 1.5 }) do
        C_Timer.After(delay, function()
            if L.Buttons_RefreshAll then L:Buttons_RefreshAll() end
            if L.GroupLabels_Update then L:GroupLabels_Update() end
        end)
    end
end
