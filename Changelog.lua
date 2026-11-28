--[[
    Lifeline - Changes shown in the "What's new" window.
    Generated from CHANGELOG.md (newest first).
]]

local _, L = ...

L.CHANGES = {
    { version = "1.2.6", title = "Keyboard keys and MMO mice in Click-Casting", lines = {
        { "h", "Click-Casting tabs" },
        { "b", "Click-Casting now has two tabs: Mouse (your normal click-casting) and MMO Mouse & Keys" },
        { "h", "Keyboard keys" },
        { "b", "Bind keyboard keys to your frames: click \"Press a key...\" on the MMO Mouse & Keys tab and press the key you want" },
        { "b", "Keys work with Shift, Ctrl and Alt, just like mouse buttons" },
        { "b", "Keys only take over while your cursor is on a Lifeline frame; everywhere else they do their normal job" },
        { "b", "Keys can cast spells, run macros, target or set focus (the game only opens the unit menu from a real click)" },
        { "h", "MMO mice" },
        { "b", "New \"Quick set: MMO mice only\": adds the 12 side buttons of MMO mice like the Razer Naga and Corsair Scimitar in one go, after you confirm. Pick Numpad keys (the usual default) or the number row (1-0, -, =)" },
        { "b", "New optional \"Shift + Numpad fix\": Windows turns Shift + Numpad keys into arrow keys (Shift + Num 2 made you walk backwards). With this on, Shift + Numpad bindings work over your frames. It takes over the arrow keys, Home, End, Page Up, Page Down and Insert while your cursor is on a frame" },
        { "b", "Shift + Num 5 is grayed out, since Windows never sends it to the game" },
        { "h", "Also" },
        { "b", "Presets and profile import/export now include your keys" },
        { "b", "The scroll wheel keeps zooming the camera over your frames unless you've bound it" },
    } },
    { version = "1.2.5", title = "Scroll wheel with Shift, Ctrl and Alt", lines = {
        { "h", "Fixes" },
        { "b", "Shift, Ctrl and Alt now work with the scroll wheel (and mouse buttons 6 and up). The game wasn't passing the held modifier along with the wheel, so a binding like Shift + Scroll Up did nothing" },
        { "b", "Changing a scroll wheel binding now works right away, no /reload needed. Before, the wheel kept your previous bindings until you reloaded" },
        { "b", "Spell bindings that use Shift, Ctrl or Alt on a click now cast through a small /cast macro, the same way targeting does" },
        { "t", "/ll debug now also logs scroll-wheel use in the \"last clicks\" list." },
    } },
    { version = "1.2.4", title = "CC'D banner, crowd control in the middle & debuff filters that work in combat", lines = {
        { "h", "CC'D banner" },
        { "b", "STUNNED and SILENCED are replaced by one orange CC'D banner. WoW Forever doesn't let addons match enemy debuffs by spell ID, so the old stun and silence lists never fired in a real fight" },
        { "b", "CC'D uses the game's own crowd-control check instead, the same kind of check that colors dispellable debuffs: stuns, fears, polymorphs and the like show in combat with nothing to set up" },
        { "b", "The \"Also count as silenced / stunned\" lists are gone, since the game ignored them. If you had both banners turned off, CC'D starts off too" },
        { "h", "Crowd control big in the middle" },
        { "b", "New \"Show crowd control big in the middle\" option (Auras > Debuff Filters, on by default): the stun, fear or polymorph itself shows as a bigger icon in the middle of the frame, so you can see which one it is. It stays out of the small debuff row so it doesn't show twice, and works in combat" },
        { "b", "The big middle icon (boss debuffs, crowd control) now shows even with \"Show debuffs\" turned off. That setting only controls the small debuff row" },
        { "h", "Debuff Filters reworked" },
        { "b", "Everything on Auras > Debuff Filters now uses the game's own checks, so it all works in combat" },
        { "b", "New \"Hide minor debuffs\" option (off by default): the debuff row uses the game's raid filter, which hides clutter like Recently Bandaged. It also hides Weakened Soul, so priests may want to leave it off. Mob debuffs still show" },
        { "b", "\"Never show these\", \"Show these big in the middle\" and \"Don't highlight these\" are gone. WoW Forever ignores spell IDs for debuffs, so those lists never worked in a real fight. Boss debuffs and crowd control still show big in the middle" },
        { "h", "Fixes" },
        { "b", "Fixed an \"AddOn 'Lifeline' tried to call the protected function\" error when someone joined the group (or a raid grew) during combat. New frames now set up their mouse clicks the secure way, so they work right away" },
        { "b", "The Dispels tab no longer points to the removed \"skip specific debuffs\" option" },
        { "t", "/ll debug now also lists the debuffs on you (with spell IDs when the game shows them) and the last few that landed on you." },
    } },
}
