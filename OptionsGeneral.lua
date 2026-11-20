--[[
    Lifeline - Settings pages: General, Profiles and About
    Shared helpers come from OptionsCore.lua (L.Opt); the sidebar order is
    in OptionsSections.lua.
]]

local _, L = ...
local C = L.C
local O = L.Opt
local Bind, Track = O.Bind, O.Track
local DB, PARTY, RAID, PETS = O.DB, O.PARTY, O.RAID, O.PETS
local NewPage, Check, Slider, Drop, Note = O.NewPage, O.Check, O.Slider, O.Drop, O.Note
local GrowthOptions, ORIENT, pct = O.GrowthOptions, O.ORIENT, O.pct


local function BuildGeneral()
    local p = NewPage("General")
    p:Head("Frames", 1)
    Check(p, 1, "Hide Blizzard party & raid frames", DB, "hideBlizzard", false,
        "Turning this off needs a /reload to bring the default frames back.")
    Check(p, 1, "Hide Blizzard raid manager", DB, "hideBlizzardManager", false,
        "The little world-marker / ready-check panel on the left edge. Needs a /reload to undo.")
    Check(p, 1, "Show frames when solo", DB, "showSolo", true)
    Check(p, 1, "Show yourself in party", DB, "showPlayerInParty", true)
    Check(p, 1, "Show example frames beside settings", DB, "showExample", false,
        "A live example docked to the right of this window that updates as you change settings.")
    Slider(p, 1, "Overall scale", 0.5, 2.0, 0.05, DB, "scale", true, pct)

    p:Head("Range", 2)
    Check(p, 2, "Fade out-of-range members", DB, "rangeFade", false)
    Slider(p, 2, "Out-of-range opacity", 0.1, 1.0, 0.05, DB, "oorAlpha", false, pct)
    do
        local box = CreateFrame("Frame", nil, p)
        box:SetSize(260, 44)
        local lbl = L.Text(box, 12)
        lbl:SetPoint("TOPLEFT")
        lbl:SetText("Range of this spell (blank = 40 yards)")
        local e = L.EditBox(box, 260, 22)
        e:SetPoint("BOTTOMLEFT")
        local function save(s2) L.db.rangeSpell = (s2:GetText() or ""):match("^%s*(.-)%s*$") end
        e:SetScript("OnEnterPressed", function(s2) save(s2) s2:ClearFocus() end)
        e:HookScript("OnEditFocusLost", save)
        L.AcceptLinks(e, "replace", function(s2) save(s2) s2:ClearFocus() end)
        box.Refresh = function() if not e:HasFocus() then e:SetText(L.db.rangeSpell or "") end end
        box:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("Range by spell", 1, 1, 1)
            GameTooltip:AddLine("Type or shift-click a friendly spell, e.g. your main heal. Frames then fade when a player is out of that spell's range.", nil, nil, nil, true)
            GameTooltip:Show()
        end)
        box:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p:Add(Track(box), 2, 10)
    end

    p:Head("Highlights", 2)
    Check(p, 2, "White border on your target", DB, "showTargetHL", false)
    Check(p, 2, "Brighten frame on mouseover", DB, "showMouseoverHL", false)
    Check(p, 2, "Red border when a member has aggro", DB, "showAggro", false,
        "Only shown when the game lets addons read threat (it may be hidden in restricted content).")

    p:Head("Pets", 2)
    Check(p, 2, "Show pets", PETS, "enabled", true,
        "Hunter and warlock pets get their own smaller frames, placed just past the party or raid frames in the same growth direction.")
    Slider(p, 2, "Pet width", 30, 160, 1, PETS, "width", true)
    Slider(p, 2, "Pet height", 14, 60, 1, PETS, "height", true)

    p:Head("Tooltips", 1)
    Drop(p, 1, "Unit tooltips on frames", {
        { value = "ALWAYS",   text = "Always show" },
        { value = "NOCOMBAT", text = "Hide in combat" },
        { value = "NEVER",    text = "Never show" },
    }, DB, "tooltipMode", false)
    Check(p, 1, "List my click-cast bindings in the tooltip", DB, "tooltipBindings", false,
        "Adds your bindings (e.g. Shift + Left  Renew) under the player's name when you hover a frame.")

    p:Head("Updates", 1)
    Check(p, 1, "Tell me when a newer version is out", DB, "updateNotice", false,
        "Lifeline compares versions with other Lifeline users in your party, raid and guild (hidden addon messages, nothing in chat) and tells you once when someone has a newer one.")
    Check(p, 1, "Show what's new after an update", DB, "whatsNew", false,
        "A small window listing the changes the first time you log in on a new version. Type /ll news to see it any time.")

    p:Head("Minimap", 1)
    local mm = L.Check(p, "Show minimap button", function() return not L.db.minimap.hide end,
        function(v) L.db.minimap.hide = not v if L.Minimap_Update then L:Minimap_Update() end end)
    mm:SetWidth(270)
    p:Add(Track(mm), 1, 4)
end

local function BuildProfiles()
    local p = NewPage("Profiles")
    local parts = { settings = true, clickCast = true, indicators = true }

    -- profile choice -------------------------------------------------
    p:Head("Profile", nil)
    local prof = L.Dropdown(p, "This character uses", {
        { value = "DEFAULT", text = "Default - shared by all your characters" },
        { value = "OWN",     text = "Its own settings - just this character" },
    }, function() return L.cdb.useOwnProfile and "OWN" or "DEFAULT" end,
       function(v) L:SetUseOwnProfile(v == "OWN") end, 330)
    p:Add(Track(prof), 1, 8)

    local pbtns = CreateFrame("Frame", nil, p)
    pbtns:SetSize(560, 24)
    local copyBtn = L.Button(pbtns, "Copy Default to this character", 220, 24, function()
        L:CopyDefaultToCharacter()
        L:Print("Copied the Default profile onto " .. (UnitName("player") or "this character") .. ".")
    end)
    copyBtn:SetPoint("LEFT")
    local resetBtn
    local armed = false
    resetBtn = L.Button(pbtns, "Reset this profile", 160, 24, function()
        if not armed then
            armed = true
            resetBtn.text:SetText("Click again to reset")
            resetBtn.text:SetTextColor(C.danger[1], C.danger[2], C.danger[3])
            C_Timer.After(3, function()
                armed = false
                resetBtn.text:SetText("Reset this profile")
                resetBtn.text:SetTextColor(C.text[1], C.text[2], C.text[3])
            end)
            return
        end
        armed = false
        resetBtn.text:SetText("Reset this profile")
        resetBtn.text:SetTextColor(C.text[1], C.text[2], C.text[3])
        L:ResetCurrentProfile()
        L:Print("Profile reset to Lifeline's defaults.")
    end)
    resetBtn:SetPoint("LEFT", copyBtn, "RIGHT", 8, 0)
    local pnote = L.Text(pbtns, 11, C.muted)
    pnote:SetPoint("LEFT", resetBtn, "RIGHT", 12, 0)
    pnote:SetWidth(160)
    pnote:SetWordWrap(true)
    pnote:SetText("Click-casting, buff indicators and aura sounds are always per character.")
    pbtns.Refresh = function() copyBtn:SetShown(L.cdb.useOwnProfile and true or false)
        resetBtn:ClearAllPoints()
        if copyBtn:IsShown() then resetBtn:SetPoint("LEFT", copyBtn, "RIGHT", 8, 0) else resetBtn:SetPoint("LEFT") end
    end
    p:Add(Track(pbtns), 1, 14)
    p:Sync()

    p:Head("Share your setup", nil)
    Note(p, 1, "Export turns your setup into a code you can paste in Discord or onto another character. To import, paste a code and click Import - layout & appearance goes into the profile this character is using.", 560)

    local function part(label, key, col)
        local w = L.Check(p, label, function() return parts[key] end, function(v) parts[key] = v end)
        w:SetWidth(180)
        return w
    end
    local row = CreateFrame("Frame", nil, p)
    row:SetSize(560, 22)
    local c1 = part("Layout & appearance", "settings")
    c1:SetParent(row) c1:SetPoint("LEFT", 0, 0)
    local c2 = part("Click-casting", "clickCast")
    c2:SetParent(row) c2:SetPoint("LEFT", 190, 0)
    local c3 = part("Buff indicators & aura sounds", "indicators")
    c3:SetParent(row) c3:SetPoint("LEFT", 330, 0)
    p:Add(row, 1, 10)
    p:Sync()

    -- big text box
    local holder = CreateFrame("Frame", nil, p)
    holder:SetSize(560, 130)
    L.Skin(holder, C.panel2)
    local scroll = L.ScrollFrame(holder)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -16, 6)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetMaxLetters(0)
    box:SetAutoFocus(false)
    box:SetFont(L.FONT, 11, "")
    box:SetTextColor(C.text[1], C.text[2], C.text[3])
    box:SetWidth(520)
    box:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    scroll:SetScrollChild(box)
    holder:EnableMouse(true)
    holder:SetScript("OnMouseDown", function() box:SetFocus() end)
    p:Add(holder, 1, 10)
    p:Sync()

    local status = L.Text(p, 12, C.muted)
    status:SetWidth(560)
    status:SetWordWrap(true)
    local function say(text, good)
        local c = good == nil and C.muted or (good and C.accent or C.danger)
        status:SetTextColor(c[1], c[2], c[3])
        status:SetText(text)
    end

    box:SetScript("OnTextChanged", function(s, user)
        if not user then return end
        local info = L:Profile_Peek(s:GetText())
        if info then
            local has = {}
            if info.settings then has[#has + 1] = "layout & appearance" end
            if info.clickCast then has[#has + 1] = "click-casting" end
            if info.indicators then has[#has + 1] = info.indicators .. " buff indicators" end
            say("Code from Lifeline v" .. info.version .. " - contains " .. table.concat(has, ", ") .. ". Click Import to apply.")
        elseif s:GetText() ~= "" then
            say("That doesn't look like a Lifeline code yet.", false)
        else
            say("")
        end
    end)

    local btns = CreateFrame("Frame", nil, p)
    btns:SetSize(560, 26)
    local exp = L.Button(btns, "Export", 110, 26, function()
        if not (parts.settings or parts.clickCast or parts.indicators) then
            say("Tick at least one thing to export.", false) return
        end
        box:SetText(L:Profile_Export(parts))
        box:SetFocus()
        box:HighlightText()
        say("Copied into the box and selected - press Ctrl+C to copy it.", true)
    end, true)
    exp:SetPoint("LEFT")
    local imp = L.Button(btns, "Import", 110, 26, function()
        local ok, msg = L:Profile_Import(box:GetText(), parts)
        say(msg, ok)
    end)
    imp:SetPoint("LEFT", exp, "RIGHT", 8, 0)
    local clr = L.Button(btns, "Clear", 80, 26, function() box:SetText("") box:ClearFocus() say("") end)
    clr:SetPoint("LEFT", imp, "RIGHT", 8, 0)
    p:Add(btns, 1, 10)
    p:Sync()
    p:Add(status, 1, 6)
end

local function BuildAbout()
    local p = NewPage("About")
    p:Head("Lifeline", nil)
    Note(p, 1, "Clean, lightweight party & raid frames built for WoW Forever. Part of the same family as Artisan Network and Salvage Station.", 560)
    Note(p, 1, "|cffffffffSlash commands|r\n/ll  -  open this window\n/ll unlock  |  /ll lock  -  move the frames\n/ll test  -  toggle the preview layout\n/ll showcase  -  preview with every indicator switched on\n/ll news  -  what's new in this version\n/ll reset  -  reset the frame position\n/ll minimap  -  toggle the minimap button", 560)
    Note(p, 1, "|cffffffffBugs, ideas & beta builds|r - join The Forge on Discord:", 560)
    local e = L.EditBox(p, 300, 22)
    e:SetText(L.discord)
    e:SetScript("OnTextChanged", function(s) s:SetText(L.discord) s:HighlightText() end)
    e:SetScript("OnEditFocusGained", function(s) s:HighlightText() end)
    p:Add(e, 1, 8)
    local news = L.Button(p, "What's new", 120, 24, function() L:WhatsNew_Show() end, true)
    p:Add(news, 1, 12)
end

-- register the pages (OptionsSections.lua puts them in order)
O.PAGE_BUILDERS["General"] = BuildGeneral
O.PAGE_BUILDERS["Profiles"] = BuildProfiles
O.PAGE_BUILDERS["About"] = BuildAbout
