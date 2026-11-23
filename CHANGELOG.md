# Lifeline

## v1.2.5 - Scroll wheel with Shift, Ctrl and Alt

### Fixes
- Shift, Ctrl and Alt now work with the scroll wheel (and mouse buttons 6 and up). The game wasn't passing the held modifier along with the wheel, so a binding like Shift + Scroll Up did nothing
- Changing a scroll wheel binding now works right away, no /reload needed. Before, the wheel kept your previous bindings until you reloaded
- Spell bindings that use Shift, Ctrl or Alt on a click now cast through a small /cast macro, the same way targeting does

/ll debug now also logs scroll-wheel use in the "last clicks" list.

## v1.2.4 - CC'D banner, crowd control in the middle & debuff filters that work in combat

### CC'D banner
- STUNNED and SILENCED are replaced by one orange CC'D banner. WoW Forever doesn't let addons match enemy debuffs by spell ID, so the old stun and silence lists never fired in a real fight
- CC'D uses the game's own crowd-control check instead, the same kind of check that colors dispellable debuffs: stuns, fears, polymorphs and the like show in combat with nothing to set up
- The "Also count as silenced / stunned" lists are gone, since the game ignored them. If you had both banners turned off, CC'D starts off too

### Crowd control big in the middle
- New "Show crowd control big in the middle" option (Auras > Debuff Filters, on by default): the stun, fear or polymorph itself shows as a bigger icon in the middle of the frame, so you can see which one it is. It stays out of the small debuff row so it doesn't show twice, and works in combat
- The big middle icon (boss debuffs, crowd control) now shows even with "Show debuffs" turned off. That setting only controls the small debuff row

### Debuff Filters reworked
- Everything on Auras > Debuff Filters now uses the game's own checks, so it all works in combat
- New "Hide minor debuffs" option (off by default): the debuff row uses the game's raid filter, which hides clutter like Recently Bandaged. It also hides Weakened Soul, so priests may want to leave it off. Mob debuffs still show
- "Never show these", "Show these big in the middle" and "Don't highlight these" are gone. WoW Forever ignores spell IDs for debuffs, so those lists never worked in a real fight. Boss debuffs and crowd control still show big in the middle

### Fixes
- Fixed an "AddOn 'Lifeline' tried to call the protected function" error when someone joined the group (or a raid grew) during combat. New frames now set up their mouse clicks the secure way, so they work right away
- The Dispels tab no longer points to the removed "skip specific debuffs" option

/ll debug now also lists the debuffs on you (with spell IDs when the game shows them) and the last few that landed on you.

## v1.2.3 - Readable names on every class color

- Names and health text now have a thin black outline, so they stay readable on light class colors like priest white, rogue yellow and paladin pink
- New "Text outline" setting under Appearance > Bars & Text: Thin outline (new default), Thick outline, Shadow only (the old look) or None. It covers names, health text and DEAD / OFFLINE / AFK, and shows live on the Example

## v1.2.2 - Shift + click targeting fix

- Shift + click (or any modifier + click) on a frame now targets that player. On WoW Forever the game's built-in target action did nothing while a modifier was held, so Lifeline now targets with a tiny /target macro instead, the same way VuhDo does. "Target unit" and "Set focus" bindings use the same trick

## v1.2.1 - Easy-copy debug report

- /ll debug now opens a small window with the report already selected: press Ctrl+C to copy it, then paste it in Discord with Ctrl+V. No more copying lines out of the chat box
- Click inside the box or press "Select all" if the selection gets lost. Esc or Close shuts the window
- Works in combat too

## v1.2.0 - Status banners, tags & your own dispel look

### Banners (new Indicators > Status Effects tab)
- New banners across the bottom of a player's frame, like DRINKING:
  - ICE BLOCK (frosty white-blue): the mage is in Ice Block, so heals won't land - help someone else
  - STUNNED (orange): the player is stunned
  - SILENCED (purple): the player can't cast
- When several apply, the most important shows: ICE BLOCK, then STUNNED, then SILENCED, then DRINKING
- They work in combat: the game itself shows the banner, the same way the dispel highlight works
- Comes with a starter list of common silences and stuns (Silence, Counterspell, Kick, Spell Lock, Shield Bash, Hammer of Justice, Kidney Shot, Cheap Shot, Bash, Pounce, War Stomp, Charge and Intercept stuns, Concussion Blow, engineering grenades and more)
- Missing one, like a dungeon mob's silence? Add it by name or spell ID ("Also count as silenced" / "Also count as stunned")
- All three are on by default and each can be switched off

### Tags
- New SOULSTONE tag (off by default): small purple text at the top center of the frame while a player can resurrect themselves. Works in combat, and can be nudged under Element positions
- The LOW MANA settings moved here from the Alerts tab, so all the tags are in one place, and your settings carry over
- LOW MANA now always shows on top of icons (incoming cast, ready check, resurrection, big debuffs) so it never gets hidden. Banners like STUNNED or DRINKING still cover it, since they matter more

### Your own dispel look (new Indicators > Dispels tab)
- New "Custom" dispel colors, next to Standard and Colorblind-friendly. Click the Magic, Curse, Disease or Poison swatch to pick your own color; right-click one to reset it, or reset them all at once
- Glow controls for the Border & glow style: strength, height, direction (from the bottom, from the top, from both edges, or an even wash) and border thickness (1 to 4 pixels)
- The "Health bar color" style is now called "Debuff tint on the bar", to make clear it only tints the bar while a dispellable debuff is up - your normal health colors don't change
- Debuff tint fill: Solid or Gradient (bright where the bar starts, darker toward the end, following your fill direction), with a gradient strength slider
- All of it works in combat, shows live on the Example as you change it, and comes along when you export your layout & appearance

### Fixes
- Fixed party frames sometimes turning into a "staircase" (each frame below and to the right of the last) a minute or so after logging in or reloading. Lifeline now checks your frame layout after group changes, after combat and every 15 seconds out of combat, and puts it back if anything changed it
- "Open unit menu" now works on any click-casting binding, like middle-click or Shift + Right Click. Before, the game only opened the menu from a plain right-click, so other bindings did nothing
- Player names written in other alphabets (Russian, Korean, Chinese) no longer show as empty boxes. Your chosen font is still used for normal letters, and the game's own fonts fill in the rest

### Settings tidy-up
- The DRINKING banner's checkbox moved next to the other banners (Indicators > Status Effects)
- Aura Sounds moved into the Auras section, and the Alerts section is gone - the sidebar is down to 7 sections
- All your settings carry over

/ll debug also shows whether the game is drawing the banners and tags, how your party frames are anchored, any layout repairs (if another addon changed your layout, it shows where that change came from), and your last few clicks on frames with the action each one triggered. Behind the scenes, the code got a cleanup after all the recent additions - nothing changes in game.

## v1.1.8 - Dispel highlight in combat & debuffs you can skip

### Dispels
- The dispel highlight now works in combat. The game hides debuffs from addons during a fight, so Lifeline now lets the game itself light up the frame when someone has a debuff you can remove, the same way your debuff row and buff indicators keep working in combat
- All three "Dispel highlight" styles (Border & glow, Health bar color, Both) work this way, with the right color per type and the colorblind-friendly colors
- New "Don't highlight these debuffs" list under Auras > Debuff Filters. Debuffs on it still show in the debuff row, but don't color the frame - handy for harmless ones you don't want to spend a global cooldown on. Works in combat too
- Add a debuff by name or spell ID (or shift-click it). Names are matched the first time Lifeline sees the debuff out of combat; spell IDs work right away. The list is included when you export your layout & appearance
- /ll debug shows whether the game is drawing the highlight on your client

### Alerts
- Removed the dispel sound. The game doesn't let addons see debuffs in combat, so it could only play out of combat (and sometimes went off late, right after a fight). For debuffs you need to hear, add them under Alerts > Aura Sounds, which the game plays in combat too

## v1.1.6 - Dispel colors on the health bar & auto target

### Click-casting
- New "Target" switch on each spell binding (auto target): clicking a frame with that binding makes the player your target and casts the spell on them in one click. Off by default, since it replaces your current target
- Works with fixed ranks, smart resurrection, the mouse wheel and extra buttons, and click-casting on the player, target and focus frames
- Binding hints in the frame tooltip show it, e.g. "Flash Heal + target", and presets and export codes keep the setting

### Dispels
- Debuffs you can dispel can now color the health bar itself: blue for Magic, purple for Curse, brown for Disease and green for Poison. Pick it under Indicators > Dispels > "Dispel highlight": Border & glow (as before, the default), Health bar color, or Both
- The bar goes back to its normal color as soon as the debuff is gone, and dead or offline players keep their gray bar
- Works with the colorblind-friendly dispel colors too
- If the game won't let Lifeline color the bar in combat, the frame falls back to the border so you still see the debuff

## v1.1.5 - Buff indicators fill from the corner, cleanup & fixes

### Buff indicators
- Buff indicators sharing a spot now fill from the corner: whichever of them are up start in the corner and line up without gaps (e.g. Power Word: Shield sits in the corner when Renew isn't up). Prefer the old way? Buff Indicators > "Icons at the same spot" > Keep fixed spots
- Buff indicators recognize every rank of a spell you know, not just one
- Removed the expiring buff flash: indicators already show their countdown, and the game hides buff timers from addons in combat, so the flash couldn't work reliably there. The setting is gone from Alerts
- New installs only show the buffs you set up as buff indicators: "Show buffs you cast" (Auras tab) now starts off. Existing settings are unchanged

### Fixes
- The ready check icon (and the resurrection / summon icons in the same spot) now shows in front of the player's name instead of behind it
- Fixed a Lua error ("ClickCast.lua:431: attempt to call a nil value") when turning off click-casting on the player, target or focus frame while you have scroll wheel bindings

### Under the hood
- Less work in raids: the debuff filter stops checking players' debuffs once every debuff name you entered has been matched, and bursts of group changes (a raid forming) are handled once instead of dozens of times
- Removed leftover code from earlier versions, and split the settings pages into one file per section to make future updates safer
- /ll debug shows spell names and whether each reminder's buff is up or missing

## v1.1.0 - Expiring buff flash & tidier buff icons
- Fixed buff indicators not flashing when they're about to run out. Lifeline now tracks the buff's timer itself instead of waiting on the game's icon, which never reported it
- The flash also works in combat: Lifeline follows each buff by its ID, so a buff refreshed mid-fight (e.g. recasting Renew) is picked up, and it stops as soon as the buff falls off
- Fixed buff indicators covering icons in the "Your buffs" row (e.g. Renew on top of Power Word: Shield): the buff row now starts next to the indicators in the top-right corner, and the debuff row next to any in the bottom-left corner
- Indicators sharing a spot always sit side by side in list order, also when some are "missing" reminders
- New /ll debug command: prints what Lifeline can see about your buff indicators, to copy into a bug report

## v1.0.8 - Tidier settings window & update notices

### Settings window
- The settings sidebar is down from 14 entries to 8: General, Layout, Appearance, Indicators, Auras, Alerts, Click-Casting and Profiles
- Related pages now sit together behind sub-tabs at the top of the page:
  - Layout: Party & Raid, Tank Frames
  - Appearance: Bars & Text, Textures & Colors
  - Indicators: Icons & Status, Cast Bars
  - Auras: Buffs & Debuffs, Buff Indicators, Debuff Filters
  - Alerts: Alerts, Aura Sounds
- Debuff Filters has its own page instead of sharing the Auras page
- Each section remembers the sub-page you last used
- About (slash commands and Discord) moved to the "i" button in the title bar
- The window is a little taller so every page fits comfortably
- Scrolling lists use a slim scroll bar in Lifeline's style instead of the game's gray arrows
- No settings were changed, only where they are in the window

### Updates
- **Update notice**: Lifeline tells you when a newer version is out. It quietly compares versions with other Lifeline users in your party, raid and guild (hidden addon messages, nothing in chat) and shows one line in chat when someone has a newer one. Turn it off in General
- **What's new**: after an update, a small window lists what changed since the version you had. Type /ll news to see it again, or turn it off in General

## v1.0.7 - Debuff filters, alerts, tank frames & more
Everything new can be switched on or off.

### Debuffs (Auras tab)
- **Never show these debuffs**: hide clutter like Recently Bandaged from the debuff row. Add debuffs by name or spell ID
- **Show these big in the middle**: debuffs you add show as a bigger icon in the middle of the frame instead of in the row
- **Boss debuffs big in the middle** (on by default) with an adjustable size
- Debuffs added by name are matched the first time Lifeline sees them out of combat; spell IDs work right away

### New Alerts tab
- **Expiring buffs** (on by default): buff indicators flash a red edge during their last few seconds (1-10, default 3), so you can refresh a HoT in time
- **Dispel sound** (off by default): plays a sound when someone gets a debuff you can remove, no spell list needed
- **Low mana** (off by default): a LOW MANA tag on frames below a set mana percent, healers only or everyone

### Click-casting
- **Bindings in the tooltip** (General tab, on by default): hovering a frame lists your bindings, e.g. "Shift + Left  Renew(Rank 1)"
- **Click-cast on other frames**: the player, target and focus frames, and other addons' unit frames that support click-casting, can use your bindings too (Click-Casting tab, off by default)

### Raids
- **Tank frames** (new Tank Frames tab, off by default): a separate group with its own size and mover that keeps your tanks in one place - players with the Tank role or set as main tank / main assist, or players you list by name
- **Group labels** (Layout tab, off by default): "Group 1", "Group 2"... next to each raid group

### Other
- **Range by spell** (General tab): frames fade at the range of a spell you pick, e.g. your main heal, instead of the standard 40 yards
- **/ll showcase**: opens the preview with every indicator switched on, so you can see everything at once without changing your settings
- New element positions for the big debuff and the LOW MANA tag
- **Font and texture previews** (Textures & Colors): the font list shows each font name written in that font, and the texture list shows each texture as a sample bar
- A new font or bar texture now shows on your frames right away, without a /reload

## v1.0.6 - Smarter click-casting, cast bars, overheal, aura sounds & more
Everything new can be switched on or off.

### Click-casting
- **Per-spell ranks**: a plain spell name (Renew) always casts your highest rank, including ranks you train later. Type a rank, e.g. Renew(Rank 1), and that binding keeps that rank. A Fixed / Auto button on the row switches a binding between keeping its rank and auto-upgrading
- Shift-clicking a lower rank from your spellbook puts that rank in the box and keeps it
- **Smart resurrection** (off by default): clicking a dead player with any spell binding casts your resurrection instead. Choose "Also combat resurrection" to use Rebirth in combat on classes that have one. Living players still get the bound spell
- **Presets**: save your bindings under a name and load or delete them later. Presets are saved per class and shared by all your characters of that class
- **Self-cast key warning**: if a binding uses the game's self-cast key (Alt by default), the spell would land on you instead of the frame you clicked. Lifeline tells you once and can turn the self-cast key off for you, and the Click-Casting tab shows a warning while the clash exists

### Health bars
- **Overheal** (Bars & Text): a bright strip shows the part of an incoming heal that would be wasted, either at the edge of the bar or sticking out past the frame, with an adjustable width. Works in combat
- **Status timers** (Indicators): frames show AFK, and how long a player has been dead, offline or AFK (for example DEAD 1:12). Releasing to a ghost doesn't restart the clock

### Cast bars (new Cast Bars tab, both off by default)
- **Cast bars on frames**: see what each group member is casting, with the spell icon and name, at the top or bottom of the frame and any height. Casts are gold, channels green, and interrupted casts flash red
- **Incoming cast warnings**: when an enemy casts at a group member, that player's frame shows the spell icon with a countdown. Needs enemy nameplates turned on

### Aura sounds (new Aura Sounds tab)
- Play a sound when a buff or debuff is gained, fades or gains a stack, on you or anyone in your group - for example Weakened Soul fading. The game plays the sound itself, so it works in combat
- Ten sounds to pick from, including six new Lifeline sounds, with a Play button to test them
- Aura sounds are included when you export or import buff indicators

### Layout
- **Separate layouts by raid size** (off by default): give 10, 20 and 40-player raids their own size, spacing and layout. Lifeline switches when the raid crosses 10 or 20 players. Your existing raid layout is the starting point for all three

### Indicators
- **Main tank and main assist icons** (off by default)
- **Threat icon** (off by default): a small square that turns orange when a player is about to pull and red when they have aggro, optionally yellow for high threat
- **Colorblind-friendly dispel colors**

### New Textures & Colors tab
- **Health fill direction**: left to right, right to left, bottom to top or top to bottom. Heal prediction, absorbs and overheal follow it
- **Bar texture and font**: pick any texture or font registered by your other addons (LibSharedMedia)
- **Bar opacity** and **background opacity** sliders
- **Dead & offline color** for the background of dead and offline frames
- The class color settings moved here from Bars & Text

### Other
- Long dropdown lists scroll with the mouse wheel
- The live example and preview show overheal, the death timer, cast bars, the incoming cast icon and the main tank icon

## v1.0.4 - Class colors
- New Class colors section (Bars & Text): pick your own color for any class, or tone down every class with the "Darken class colors" slider - handy if Priest white is too bright
- Right-click a class to reset it to Blizzard's color; "Reset all class colors" puts everything back
- Your class colors are used on health bars, class-colored names, the preview and the live example, and are included when you export a profile

## v1.0.3 - Buffs stay visible in combat
- Fixed buffs and debuffs disappearing from party & raid frames in combat: your buffs row, the debuff row and active buff indicators are now drawn by the game's own aura containers, which keep working while WoW Forever hides aura details from addons
- Buff and debuff icons show the spell image, duration swipe and stack count
- Spells placed as buff indicators still stay out of the "buffs you cast" row, in and out of combat
- Missing-buff reminders are unchanged (they show out of combat)

## v1.0.1 - Cleanup & performance
- Internal cleanup: removed unused code and old settings, and split the settings window code into smaller files
- Less work per buff/debuff update on raid frames (cached buff indicator lookups)
- Preview, example and pet sample frames now share one builder, so they always look and behave the same

## v1.0.0 - Initial release

Clean, lightweight party & raid frames built for **WoW Forever**, from the maker of Artisan Network and Salvage Station.

### Frames & layout
- Party (2-5) and raid (6-40) frames, each with their own width, height, spacing, orientation and growth direction
- Growth choices that match the orientation: top to bottom / bottom to top for vertical, left to right / right to left for horizontal
- Raid layouts: one column per group, or combined by role, by class or in raid order
- Sort by group order, name or role
- Optional pet frames for hunter and warlock pets, placed just past the party or raid frames with their own size
- Drag-to-move anchor, overall scale, and a live preview for party, 10, 25 and 40 players
- Hides Blizzard's party & raid frames (and optionally the raid manager)

### Bars & text
- Class-colored, dark or single-color health bars with adjustable background darkness
- Incoming heals and absorb shields that stop at the frame edge, with an option to only show heals you're casting
- Power bar with adjustable height, or filled for healers only
- Names (optionally class colored) with health as percent or missing health
- Move the name, health text and every icon in any direction (Element positions)

### Indicators
- Role, leader/assistant, raid marker, ready check, resurrection and summon pending
- Dispellable debuffs color the frame border and add a soft tint (only what your class can remove)
- Debuff icons and your own buffs/HoTs with duration swipes and stack counts
- Red border for aggro, white border for your target, mouseover highlight, out-of-range fading
- DRINKING banner across the bottom of anyone drinking

### Buff indicators
- Place any buff's icon at one of nine spots on the frame, at the size you choose
- Show it while the buff is up (cast by you or anyone), or only when it's **missing** - perfect for Fortitude, Spirit, Intellect and Mark reminders
- Single-target and group versions count as the same buff (Fortitude / Prayer of Fortitude, Arcane Intellect / Brilliance, Mark / Gift of the Wild, Blessings / Greater Blessings, and more)
- Missing reminders hide in combat and on dead, offline or pet frames, so they never nag at the wrong time

### Click-casting
- Left, right, middle click, scroll up/down and extra mouse buttons (4-16), each with Shift, Ctrl or Alt
- Target, menu, focus, cast a spell or run macro text - shift-click spells straight from your spellbook into the box
- Saved per character and works in combat; detects Clique and hands click-casting over to it

### Profiles & sharing
- Use the shared Default profile or give a character its own settings
- Export your layout, click-casting and buff indicators as a code to share in Discord or move to another character

### Settings window
- Clean dark settings window with a live example panel beside it that updates as you change settings - including a ready check preview and sample pets
- Unit tooltips: always, hide in combat or never
- Minimap button and addon compartment entry

### Commands
`/ll` settings · `/ll unlock` / `/ll lock` · `/ll test` preview · `/ll reset` position · `/ll minimap` toggle button

Bugs & ideas: join **The Forge** on Discord - https://discord.gg/yskDeZjQj7
