--[[
    Lifeline - Settings window: the order pages are built in, and the sidebar
    sections (each one page, or several behind sub-tabs).
]]

local _, L = ...
local O = L.Opt

-- every page, in build order (each Options*.lua file registers its builders)
O.TAB_BUILDERS = {}
for _, name in ipairs({
    "General",
    "Layout",
    "Tank Frames",
    "Bars & Text",
    "Textures & Colors",
    "Indicators",
    "Dispels",
    "Status Effects",
    "Cast Bars",
    "Auras",
    "Buff Indicators",
    "Aura Sounds",
    "Click-Casting",
    "Controller",
    "Profiles",
    "About",
}) do
    local build = O.PAGE_BUILDERS[name]
    if build then O.TAB_BUILDERS[#O.TAB_BUILDERS + 1] = { name, build } end
end

-- the sidebar: each entry holds one page, or several behind sub-tabs
-- ({ sub-tab label, page name }). About opens from the "i" in the title bar.
O.SECTIONS = {
    { name = "General",       pages = { { "General", "General" } } },
    { name = "Layout",        pages = { { "Party & Raid", "Layout" }, { "Tank Frames", "Tank Frames" } } },
    { name = "Appearance",    pages = { { "Bars & Text", "Bars & Text" }, { "Textures & Colors", "Textures & Colors" } } },
    { name = "Indicators",    pages = { { "Icons & Status", "Indicators" }, { "Dispels", "Dispels" },
                                        { "Status Effects", "Status Effects" }, { "Cast Bars", "Cast Bars" } } },
    { name = "Auras",         pages = { { "Buffs & Debuffs", "Auras" }, { "Buff Indicators", "Buff Indicators" },
                                        { "Debuff Filters", "Debuff Filters" }, { "Aura Sounds", "Aura Sounds" } } },
    { name = "Click-Casting", pages = { { "Click-Casting", "Click-Casting" } } },
    { name = "Controller",    pages = { { "Controller", "Controller" } } },
    { name = "Profiles",      pages = { { "Profiles", "Profiles" } } },
}
