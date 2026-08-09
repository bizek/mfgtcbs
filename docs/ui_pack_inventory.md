# Minifantasy UI Overhaul — Inventory & Coverage

Coverage record for `assets/minifantasy/Minifantasy_UI _Overhaul_v1.0`, in the style the
`/minifantasy-pack` skill enforces: every sheet gets a home or an explicit reason it has none.
Audited 2026-07-31 against source.

> **Note the path.** The folder name contains a stray space: `Minifantasy_UI _Overhaul_v1.0`.
> Any `res://` string must reproduce it exactly.

## Headline

At audit time (2026-07-31) **the entire project referenced one file from this pack**:
`scripts/ui/hud.gd:10` loaded `_Classic_UI.png` and pulled 8 rects out of it. Nothing else — no
scene, no other script, no `project.godot` setting — touched the pack.

Since then: the controller and keycap sheets are wired through `InputGlyphs` (gap 1), the cursor
sheet through `GameCursor` (gap 2), **the Grim sheet backs a project-wide `Theme`** (gap 3), and
gaps 4 (slots + grids), 6 (tabs), 7 (labels & tags), 8 (selectors) and 9 (icons) are done.

**The HUD moved from Classic to Grim on 2026-08-08**, so the pack's oldest consumer is no longer
the odd one out — see "Current utilization" below and gap 3.

**Open as of 2026-08-09: the tail of gap 2, then 5 and 11** — the click-effect pop and the
per-class reticle, the resource orbs, and the emotions/bubbles. Gap 10 is done apart from its
vertical plaques and medallions, which are recorded rather than wired (no screen at 640×360 has
room for them).
`scripts/ui/ui_icons.gd` (`UIIcons`) is the shared atlas helper; new sheet rects belong there,
next to the reasoning for them.

## Pack shape

Two trees:

| Tree | PNGs | Status |
|---|---|---|
| `_Minifantasy_UI_Overhaul_Assets/` | 51 | Current set. 42 are content; 3 mockups + 3 guideline layers + 3 10x guideline renders are documentation. |
| `Legacy_Assets/Minifantasy_Userinterface_Assets_(OLD__VERSION)/` | 73 | Superseded by the overhaul. Two exceptions worth keeping — see [Legacy tree](#legacy-tree). |

11 `.aseprite` sources ship alongside, so anything here is editable at source rather than
pixel-patched.

**Facts that apply to every sheet:**

- Panels, buttons, labels, grids and bars are **16×16 sliced** — nine-patch directly, no
  re-slicing. Icons, controller and keyboard glyphs are **8×8**.
- Each style ships **separate layers**: composite (`_Name.png`), art without outline
  (`Name_Only`), outline alone (`Name_Outline`), drop shadows (`_Name_Shadows`), and for Grim
  and Stylized a window-background layer (`Name_Bg_Only`). Recolouring or restyling means
  compositing layers, not repainting.
- The three styles are **mix-and-match compatible** — the pack says so explicitly in
  `_UI_Versions_Info.txt`. Grim panels with Classic bars is a supported combination.
- `.import` files are present for every sheet, so everything is load-ready.
- **No fonts ship with the pack.** The project already uses `assets/fonts/m5x7.ttf`; nothing to
  reconcile. The pack's `_A_Word_About_Fonts.txt` recommends dark text, which assumes light
  panels — for our dark descent aesthetic the Grim set (light-on-dark) is the matching choice.
- Every sheet carries a `_Use_Guidelines/` folder whose `Use_Guideline_Layer.png` is
  pixel-aligned to the sheet. Compositing it over the sheet labels every group; that is how the
  group names below were read.

---

## Style sheets

### Classic — `Classic_Minifantasy_UI/_Classic_UI.png` (1872×848)

Three colour families side by side: **gold/tan · parchment/cream · white/grey**.

Groups: PANELS · SLOTS · DIALOG PANELS · DIVIDERS · TOGGLE BUTTONS ·
PUSH BUTTONS (frame 160×160, tile 16×16) · CHECK BOXES · SLIDERS · LABELS & TAGS ·
RESOURCE BARS · RESOURCE METERS (5 colours, spanning the sheet bottom).

This is the only sheet currently in use. Measured rects live in `hud.gd` as consts.

### Grim — `Grim_Minifantasy_UI/_Grim_UI.png` (4528×1984)

The one that matches the game. Dark plates, cold steel/bone outlines — Mock_Up_1 is a
cave-crawler HUD that reads almost as our descent mode.

Macro layout is **5 colour columns × 3 ornament rows**, plus a resource-meter band:

| Axis | Bands (px) |
|---|---|
| Colour columns | C0 `0–847` · C1 `940–1759` · C2 `1852–2671` · C3 `2764–3583` · C4 `3676–4495` (stride 912) |
| Ornament rows | R0 `112–592` · R1 `652–1136` · R2 `1192–1684` |
| Meter band | `1732–1920`, five colour blocks on the same 912 stride |

Ornament rows are a **built-in visual hierarchy**, not three redundant copies:

- **R0** — plain plate, rivet-dot edge. Dense lists, inventory grids, debug panels.
- **R1** — corner brackets. Standard panels.
- **R2** — full filigree with corner and mid-edge flourishes. Hero panels, modals, titles.

Per-cell groups: DECORATION · WINDOW BUTTONS · PANELS · DIVIDERS · SLIDERS · TABS · SLOTS ·
CHECK BOXES · TOGGLE BUTTONS · RESOURCE'S BARS & CONTAINERS ·
PUSH BUTTONS (frame 128×128, tile 16×16).

Two details worth knowing before authoring against it:

- **Push-button strips carry their own palette**, independent of the column's frame colour:
  brown · green · blue · red/magenta · white, 4 tints each, in small/wide/tall/square.
- **Resource containers include orbs.** Three sizes on a 32px stride with pre-rendered drain
  frames (~14 / ~10 / ~6 frames full→empty), in red · blue · yellow · green · purple. These are
  Diablo-style globes, already animated — not something to build.

### Stylized — `Stylized_Minifantasy_UI/Stylized_UI.png` (4528×1952)

Same macro layout and same group set as Grim, bright warm palette (orange/blue/yellow/green/grey),
heavier outlines. Reads as cheerful; wrong register for descent, plausible for the hub if we ever
want the hub to feel like a safe place by contrast. Mock_Up_3 shows the intended look.

---

## General resources — `_General_UI_Resources/`

| Sheet | Size | Layout | Contents |
|---|---|---|---|
| `Icons/_Icons.png` | 576×432 | 8×8 on an 8px lattice, **8 tints** | General (gear, screen, home, save/load, lock, bin, players, filters, achievements, shop, arrows, check/cross, maths, video controls), Character (map, compass, book, scroll, lens, quill, chest, anvil, blueprint, crossed swords, armor, shield, hammer, backpack, heart, magic spark, lightning, stamina, food, water), Social (10 platforms × 9 tints) |
| `Cursors/_Cursors.png` | 440×72 | 16×16 grid, 27 cursors × **4 tints** (rows y 0/16/32/48; tints default/white/red/green) | 4 large arrows, 4 small arrows, **4 crosshairs**, hand, hand-clicking, **melee attack, ranged attack, magic attack**, hammer, pickaxe, axe, sickle, shovel, hoe, rod, gear, purse, conversation |
| `Cursors/Click_Effects/Click_Effects.png` | 64×208 | 16×16 frames, **100ms native**, **4 columns × 13 rows** | 2 effects (rows 0–5 collapsing-in, row 6 blank, rows 7–12 expanding-out) × **4 frames** in 6 colours. Counted 2026-08-09 — this row said "~6 frames", which made the effect look 50% longer than it is |
| `Controls/Controller/_Controllers.png` | 504×360 | 8×8 | **Xbox** `y16–120` · **PlayStation** `y128–224` · **Switch** `y248–352`. Sticks, D-pads, face buttons, shoulders and triggers. Every button has regular + **pressed** state; white-outline variants for highlight |
| `Controls/Keyboard_Mouse/_Keyboard_And_Mouse.png` | 568×400 | 8×8 | Full keyboard, **pressed + unpressed**, in 4 variants (light/dark × outlined/plain). Mouse bodies and hand icons at `y336–384` |
| `Labels_And_Tags/_Labels_And_Tags.png` | 320×448 | 16×16 sliced | 2 designs (pill bookmark, ribbon banner) × **8 colours** × (plain / white-outlined) |
| `Selectors/_Selectors.png` | 432×320 | — | Full box, corner brackets, dashed box, corner ticks, plus arrow/chevron/diamond pointer sets, each in **4 tints** (white/black/red/green) |
| `Grids/Grids.png` | 1360×496 | 16×16 sliced | Separators, single boxes, 3×3 and 5×5 grid frames, in 5 tints × 5 line styles. Measured — see [gap 4](#4-slots--grids--done-2026-08-08) |
| `Character_Emotions/_Emotions.png` | 152×104 | 8×8 | ~50 expression faces (happy, angry, shocked, crying, dead, love, music, ellipsis…) |
| `Character_Emotions/_Bubble.png` | 280×72 | — | Speech bubbles, 8 tail directions × 4 sizes |

---

## Current utilization

`scripts/ui/hud.gd` — the pack's oldest consumer. **Moved from the Classic sheet to Grim on
2026-08-08**; it was the last surface in the game still on Classic, which read as a different game
next to the Grim-backed Theme. Rects measured off `_Grim_UI.png` with a connected-component pass:

| Rect | Used for |
|---|---|
| 5× capsule fill `42×6 @ y1821`, **912px** column stride (red x=67, blue 979, yellow 1891, green 2803, purple 3715) | HP (red), XP (blue), extraction (green); yellow/purple reachable via `_fill_region_for_color` for boss bars |
| 2× end-cap nub `4×6 @ x=120` (+stride) | HP and XP bar end gems |
| `PANEL_SQUARE` / `PANEL_PILL` — both `48×48 @ (112,160)`, PANELS group column 0 row **R0**, 5px margins | Grim ships no dedicated 48×16 pill; a nine-patch takes its aspect from the target, so one rect serves both. R0 (plain plate) rather than R1/R2 because a HUD pill is the plainest thing in the game — the same rect and margin the theme's `PanelDense` uses. |

Thinner fill variants exist at `y=1854` (40×3), `y=1887` (40×2) and `y=1919` (40×1) if a slimmer
meter is ever wanted. The old Classic rects were `40×6 @ y709` on a 256 stride with `(64,384)` /
`(64,352)` panels — recorded here only so the diff is legible.

`scripts/managers/input_glyphs.gd` is the pack's second consumer as of 2026-07-31 — see gap 1.

Everything else in the UI layer is procedural. As audited 2026-07-31, with the 2026-08-07 state
in bold:

- No `Theme` resource existed and `project.godot` had no `gui/theme` section. **Both now exist —
  see gap 3.**
- "21 UI scripts build their chrome from `StyleBoxFlat` / `ColorRect` in code." **That count was
  low by more than half: 53 scripts call `add_theme_*_override`.** Heaviest are
  `passive_tree_debug_panel.gd`, `hub_roster_panel.gd`, `hub_armory_panel.gd`,
  `codex_grid_panel.gd`, `hub_panel_base.gd`. They still do, and still win over the theme.
- No custom mouse cursor was set anywhere. **`GameCursor` now owns it — see gap 2.**

---

## Gap list — what should use what

Ordered by value per unit of work. Item 1 is done; 2 onward are open.

### 1. Controller + keyboard glyph art → `InputGlyphs` — **DONE (2026-07-31)**

`InputGlyphs` now carries the atlas alongside the text glyphs. Text API (`hint`, `action_glyph`)
is unchanged; a parallel BBCode API (`hint_bb`, `action_glyph_bb`, `event_glyph_bb`) emits inline
`[img region=…]`, and `action_glyph_texture()` returns an `AtlasTexture` for node-based callers.
**Every art path falls back to the text glyph**, so an input with no sprite still prints its name.

Also fills the "only Xbox shipped" hole `_GLYPH_SETS` admitted to — PlayStation and Nintendo now
ship as both text and art, and `_refresh_family()`'s existing detection lights up automatically.
Commit `cba9918` (refund hint vs. baked Xbox glyph) was this gap biting.

Wired surfaces: all six `GlyphBar` hint bars (hub, pause, settings, level-up, merchant, insurance)
· world interact prompts (merchant, summon altar, hub) · first-run tutorial cues · HUD skill slots.

Still on the text path, deliberately: `settings_panel.gd` Controls tab and `hub_passives_panel.gd`
both render arbitrary rebind targets, where a key's *name* is the point.

**Atlas geometry**, measured off alpha, for anything built on this later:

| | Controller (`_Controllers.png`, 504×360) |
|---|---|
| Family stride | Xbox `+0` · PlayStation `+120` · Nintendo `+240` in y |
| Face buttons (7×8) | top `(288, 64)` · left `(280, 72)` · right `(296, 72)` · bottom `(288, 80)`, **+ family stride** |
| Pressed face | same, `+32` in x |
| Variant used | white-outlined, unpressed (the outlined row is `+32` in y from the plain row) |
| Sticks / D-pad | one shared set, no family offset — L stick `(34,146,12,12)`, R `(98,146,12,12)`, leans at ±18px; D-pad 8×8 up `(152,96)` left `(136,112)` right `(168,112)` down `(152,128)` |

| | Keycaps (`_Keyboard_And_Mouse.png`, 568×400) |
|---|---|
| Regular caps (7×8) | `x = 40 + 16·col`, `y = 72 + 16·row`; rows are digits / QWERTYUIOP / ASDFGHJKL / ZXCVBNM |
| Wide caps (15×8) | `x = 16`, rows 0–4 = Tab / Shift / Ctrl / Alt / Space |
| Loose | Backspace `(200,72,15,8)` · Enter `(200,99,15,13)` · arrows `(232,120)` `(224,136)` `(232,136)` `(240,136)` |
| Pressed | the whole grid `+160` in y |
| Mouse (7×8) | LMB `(105,336)` · RMB `(121,336)` · MMB `(137,336)` |
| Absent | Esc, F-keys, punctuation — genuinely not on the sheet, these take the text path |

**Pressed-state art is mapped but unused.** Every region getter takes a `pressed` flag and the
tables carry both states; no caller passes `true` yet. Wiring it to held-channel abilities is a
behaviour change, not an art change — the data is already here when that's wanted.

One fidelity note: the Nintendo face buttons are dark grey with light letters in the source art,
where Xbox and PlayStation are coloured. They read dimmer on dark panels. That is the pack's
drawing, not a wrong region.

### 2. Cursors → the manual-aim reticle — **mostly DONE (2026-08-02)**

`GameCursor` (autoload) owns the pointer. Crosshair 1 (`COL_RETICLE = 8`, the open-centre bracket)
while playing, the large arrow in menus, both nearest-neighbour upscaled to the viewport's integer
factor because the hardware cursor is drawn in real screen pixels and is *not* upscaled with the
game. Hostile tinting is live: `player.gd` calls `set_hostile()` each aiming frame and the reticle
switches to the red tint row. Hotspot is (8,8) for both cells, measured off the sheet's alpha.

**Still open, and both are design calls rather than wiring:**

- **The click-effect pop.** `Cursors/Click_Effects/Click_Effects.png` is **64×208 = 4 columns ×
  13 rows** of 16×16 cells: two variants (rows 0–5 *collapsing in*, row 6 blank, rows 7–12
  *expanding out*) in 6 colours — red, gold, blue, orange, magenta, green. **That is 4 frames, not
  the 6 this document claimed before 2026-08-08**; at the pack's stated 100ms that is a 400ms ring.
  This is a combo game whose light chain fires several times a second, so a 400ms ring per swing is
  clutter, not confirmation. It wants either a much shorter duration or a restriction to deliberate
  actions (skills, dash) rather than every hit. Decide the trigger before wiring it.
- **The per-class reticle.** The melee / ranged / magic attack cursors map onto kit archetype, but
  the reticle already carries hostile state, and a cooldown state is ambiguous in a kit with a
  cooldown-free light chain and two cooldown skills — "on cooldown" would have to mean a specific
  ability. `ROW_GREEN` is defined and unused, reserved for whichever state wins.

### 3. A `Theme` resource off the Grim sheet — **DONE (2026-08-07)**

`assets/ui/grim_theme.tres`, wired as `project.godot [gui] theme/custom`, so it reaches **every**
Control including the ~250 built procedurally in code. Generated by `tools/build_ui_theme.gd`
(an `EditorScript`) rather than hand-written, because a Theme this size is otherwise thousands of
lines of opaque `SubResource` ids with no provenance for any rect.

**Where the rects came from.** The pack ships `_Use_Guidelines/Use_Guideline_Layer.png`, a 1:1
overlay that boxes each group in a distinct colour. Clustering those boxes and component-labelling
the sheet's alpha inside them yields every sprite rect exactly; nine-patch margins were then
measured by walking in from each edge until the rows stopped changing. Nothing was eyeballed.

| Theme type | Grim source | Margin |
|---|---|---|
| `Panel` / `PanelContainer` | PANELS R1 corner-bracket plate `Rect2(112, 704, 48, 48)` | 9 |
| `PanelDense` (variation) | PANELS R0 plain plate `Rect2(112, 160, 48, 48)` | 5 |
| `PanelHero` / `PopupPanel` | PANELS R2 filigree `Rect2(108, 1244, 56, 56)` | 13 |
| `SlotPanel` (variation) | SLOTS R1 `Rect2(109, 285, 22, 22)` | 2 |
| `Button` + 4 palette variations | PUSH BUTTONS R1 square, 4 tints on a 128 stride | 6 |
| `CheckBox` / `CheckButton` | CHECK BOXES R1 square + round, on/off | — |
| `HSlider` / `VSlider` | SLIDERS R1 track + grabber | 6 |
| `HSeparator` | DIVIDERS R1 `Rect2(323, 678, 42, 3)` | 6 |
| `LineEdit` / `SpinBox` | PANELS R0 (recessed, the opposite of a raised button) | 5 |
| `OptionButton` + `PopupMenu` | button plate + R1 panel plate | 6 / 9 |

The three ornament rows are used as the hierarchy the artist built in — R0 dense, R1 standard,
R2 hero — not as three interchangeable looks. The five colour columns become Button type
variations: `Button` (brown), `ConfirmButton` (green), `InfoButton` (blue), `DangerButton` (red),
`NeutralButton` (grey). Set one with `btn.theme_type_variation = &"DangerButton"`.

**The font default matters as much as the art.** `default_font` = m5x7 at 16, so a Control no
longer renders in Godot's vector font just because its script forgot to call `add_theme_font_override`
— the failure mode that had shipped in six player-facing scripts (see CLAUDE.md's font section).

Scrollbars are in-palette `StyleBoxFlat`, not art: the pack has no scrollbar sheet, and Godot's
default light-grey bar was the loudest thing on an otherwise dark screen.

**Retiring the hand-styled overrides — first pass done 2026-08-07.** Override calls across
`scripts/` went **711 → 539**, and `add_theme_font_override` is now at **zero**: every one of the
118 call sites passed `m5x7`, which is exactly what `Theme.default_font` supplies. Also gone: every
`add_theme_font_size_override(..., 16)`, since 16 is `default_font_size`.

Verified before deleting anything, not assumed — a fresh `Label`, `Button`, `RichTextLabel`,
`CheckBox`, `OptionButton` and `LineEdit` with no override each resolve to the same m5x7 resource
at size 16. Deleting on a wrong assumption would have reproduced the exact vector-font bug the
font pass existed to fix.

What is deliberately **kept**: `separation` and `margin_*` constants (layout, not theme), semantic
`font_color` overrides (rarity, role, damage type), per-screen styleboxes, and any size that is not
16. Those are design, not duplication. Roughly 539 calls remain and most of them should.

### 4. Slots + grids — **DONE (2026-08-08)**

The armory's mod and weapon slots now use the pack's real item slot, via a `SlotButton` theme
variation. The two ornament tiers **are** the states: R0 `Rect2(109, 237, 22, 22)` idle,
R1 `Rect2(109, 285, 22, 22)` hover/pressed.

**Tiled, not stretched, and that is the whole finding.** The slot is authored as a 22×22 *square*
item cell; a mod row is ~190px wide. Nine-patch stretching smeared its edge detail into an uneven
dashed line. The pack's own note says the set is "16x16px sliced to facilitate the creation of
panels of any size" — i.e. tile the middle. With `AXIS_STRETCH_MODE_TILE` the edge repeats at its
authored scale and the row reads as a proper slot. Same lesson as the Paladin breastplate in the
portrait pass: **the art has an intended shape, and a wide row is not a square cell.**

The rarity colour stays in `hub_armory_panel.gd` rather than the theme, because which mod is
socketed is the panel's business. It duplicates the theme's stylebox and modulates it — the same
split `hub_panel_base` uses for panel accents — lifted 55% toward white first, or a mid-saturation
rarity colour drags the bone outline down to something that reads as dirt. A flat-box fallback
remains for when no `SlotButton` is available, so the armory is never left unstyled.

**Grids, 2026-08-08.** `Grids.png` is now measured and wired, and `codex_grid_panel.gd` no longer
draws a single box of its own. The rects live in `UIIcons` beside the icon and tag rects — added
there rather than in a new `UIGrids` class specifically to dodge the unresolvable-`class_name` trap
that `RunReportView`, `GatewayExtraction` and `UIIcons` itself each hit.

**Sheet geometry**, component-labelled off the alpha:

| | `Grids.png` (1360×496) |
|---|---|
| Macro layout | 5 tint **columns**, stride 272 · 5 line-style **rows**, stride 96, first block at y=16 |
| Verification | all 25 blocks compared pixel for pixel — the alpha layout is *identical* in every one, so one set of block-local offsets addresses the whole sheet |
| Line styles, in row order | solid · short dash · dotted · long dash · woven double |
| Tints, sampled off the solid box edge | 0 `#77431d` brown · 1 `#9a7357` tan · 2 `#494949` grey · 3 `#000000` black · 4 `#ffffff` white |
| Block-local rects | box 28×28 `(26,10)` · box 12×12 `(114,34)` · quartered box `(74,42,28,28)` · h-rule `(80,23,16,1)` · v-rule `(88,0,1,16)` · 3×3 `(138,26,44,44)` · 5×5 `(196,20,56,56)` |

Three findings worth keeping:

- **The tints are LINE colours, not fills**, and only white is usable. On a near-black descent
  panel the brown and black variants are invisible, and white is the only one that survives a
  modulate to an arbitrary accent. The helpers all read tint 4 and tint it.
- **The two grid blocks are built differently**, which is the whole hint for how to use them. The
  3×3 is nine separate 12×12 cells on a 16px pitch (gaps between). The 5×5 is contiguous — 12×12
  cells on an **11px** pitch, i.e. adjacent cells *share* their border column. The codex list
  copies the second: cell frame per row, `VBoxContainer` separation **−1**, borders in common.
- **Tiled, never stretched**, same as the slots above. The rules are one full 16px period of the
  pattern, so `AXIS_STRETCH_MODE_TILE` reproduces a dashed line exactly at any length; stretching
  one dash across a 600px panel is the failure mode.

The codex's outer shell went to the theme's default `Panel` (R1 corner brackets) — not R0, even
though R0 is the tier the pack labels "dense lists and inventory grids". The density here comes
from the row cells, and the shell is a modal sitting on top of the armory's own R1 plate; dropping
it to the plainest tier made the thing in front read as less important than the thing behind it.
The vertical rule between the list and the detail card was then **removed**: both halves carry
their own frame, and a third line 4px from both just reads as a smudge.

### 5. Resource orbs → HP / class resource

Pre-animated globes in 5 colours × 3 sizes, sitting in the Grim meter band to the right of the bar
fills (x≈415+ at y≈1740–1960 in column 0) with ~14 / ~10 / ~6 drain frames full→empty. Mock_Up_1
shows them as the anchor of a dark HUD.

**Half of this gap is moot: there is no class resource.** A grep across `hud.gd` and `player.gd`
finds no mana/rage/energy pool — skills are purely cooldown-gated. So the only live option is the
HP readout, which now competes with the Grim capsule bar wired in gap 3's wake (see "Current
utilization"). Worth deciding alongside any further HUD work rather than on its own.

### 6. Tabs → settings / codex categories — **DONE (2026-08-07)**

Grim TABS group, colour column 0, the brighter right-hand sub-group, wired as `TabContainer` /
`TabBar` styleboxes in the project theme. No per-screen work was needed: the settings panel already
used a real `TabContainer`, so this is theme-only.

The pack draws tabs at **two heights, and that IS the selected/unselected metaphor** — the active
tab is taller and stands proud of the row. Using `TAB_SHORT` (48×15) for unselected and `TAB_TALL`
(48×23) for selected gets that from the art instead of faking it with colour. The body below the
row uses the standard R1 plate so the tab strip and its panel read as one object.

### 7. Labels & tags → rarity + codex state — **DONE (2026-08-08)**

`UIIcons.rarity_tag()` builds the pack's horizontal pill with the rarity name inside it, and the
extraction results screen's haul manifest uses it — `Weapon: Thornstaff [UNCOMMON]` is now a green
pill instead of bracket text. The haul is a run's payoff moment and it was carrying that entirely
in punctuation.

Rects: horizontal pill `48×12`, `x=16` plain / `x=176` white-outlined, 16px vertical stride from
`y=82`. Colours **sampled, not read off a render**: 82 orange `#d6812d` · 98 gold `#e7b14a` ·
114 green `#4e9f4c` · 130 blue `#5064c2` · 146 purple `#af50c2` · 162 red `#c25050` ·
178 tan `#cf9b5d` · 194 cream `#faddb4`.

Four of the five game rarities land on a near-exact match — uncommon→green, rare→blue,
epic→purple, legendary→gold. `common` has no grey in the set and takes the cream, which reads as
"plain" beside the others and is the right role for it.

Text on a pill goes **dark** (`TAG_INK`): the fills are mid-to-light and bone-on-gold is
unreadable at 16px. Nine-patch margins keep the rounded caps intact and stretch only the flat
middle, or the pill goes oval. `ReportView.tagged_line()` falls back to the exact previous bracket
string when the sheet is unavailable, so a loot line can never lose its rarity entirely.

**Codex state markers, 2026-08-08.** The generic builder is now `UIIcons.pill(colour, text, icon)`;
`rarity_tag()` is a thin wrapper on it. The sheet's **second design** is wired too — `ribbon()`.

Measured: the pill and the ribbon share one 8-colour ramp **in the same order**, so one index
addresses both. Ribbon is 48×14 horizontal from y=305 (vertical 14×48 at y=240), pill 48×12 from
y=82 (vertical 12×48 at y=16); both run x=16 plain / x=176 white-outlined on a 16px stride.

Where each design goes is decided by SHAPE, not preference:

| Surface | Art | Why |
|---|---|---|
| Codex detail pane, state line | pill + a separate hint label | `[ DISCOVERED — trigger in a run to reveal ]` had the state and its how-to inside one pair of brackets; the state is the half you scan for |
| Codex list row, "new since you last looked" | **ribbon**, 48×14 | authored at a fixed height with a clipped label, so it fits a 16px row. A pill carrying the same word is **23** tall — m5x7's line box at 16 — and would collide with the rows either side |
| Codex list row, mastered / not-yet-revealed | **icon** pills, 18×12 | all the room a row has. Gold + trophy, tan + question mark |

State→colour climbs the sheet's own ramp with the state: cream (inert) → tan → blue → gold. The map
lives in `codex_grid_panel.gd`, not in `UIIcons` — same split as the armory's rarity-coloured slots,
because codex states are the codex's vocabulary and rarity is the game's.

Two things measured on screen rather than assumed:

- **An icon pill must have its height floored at the art's 12px.** Left to its content it is 8 tall
  — the icon's height — and the two 5px rounded caps have nowhere to go, so they collide into a
  bowtie with no flat middle. A word pill is 23 and unaffected.
- **The ribbon's word centres on the band between the notched top row and the fringed bottom row**,
  not on the art's full height (`offset_bottom = -4`); at −2 the baseline still sat on the fringe.

The "NEW" state itself is new game state: `CodexManager.unseen`, populated on discover / reveal /
mastery and cleared by `mark_all_seen()` when the panel hides — so badges last a whole browsing
session rather than vanishing on the first click. It is deliberately **not** persisted:
`CodexManager.save_data()` is keyed by `combo_id`, so a top-level `"unseen"` key would collide with
the combo namespace, and the loop the badge exists for (finish a run → walk into the hub → open the
codex) happens inside one process anyway.

**Two font bugs surfaced and were fixed while in there** — both invisible in a diff and obvious on
screen, both the exact failure mode CLAUDE.md's font section describes:

- The whole detail column was sized **9–14**, below m5x7's 16px native grid, where glyphs *fuse*.
  It is now 16 throughout, which forced the panel from hand-accumulated pixel offsets onto real
  containers (a button is ~23 tall at 16, and the filter/sort rows were 15px apart). The overlay
  also grew 460×262 → 620×340; the old size was drawn around 9px text.
- Two decorative marks were rendering in Godot's **vector fallback**, because m5x7 has no glyph for
  either: the mastery `★` (now the trophy pill) and the `►` in the hover hint. The `►` was the
  worse of the two — its taller line box pushed that row's text down past its own bottom border.

### 8. Selectors → controller focus ring — **DONE (2026-08-07)**

`_Selectors.png` corner brackets, `Rect2(255, 95, 18, 18)` (white tint; +48 per tint), as the
theme's `focus` stylebox for Button, every button variation, CheckBox and OptionButton.

`draw_center = false` plus a 2px expand margin, so the ring sits **outside** the control and never
paints over its plate — the old flat 2px ring sat exactly on the border and disappeared against a
button that already had one.

**`ui_nav_utils.apply_focus_ring` had to change or none of this would ever appear.** An override
applied there wins over the theme, and it is called on most buttons in the game. It now duplicates
the theme's ring and re-tints it, so the `accent` argument still means something, and falls back to
the old flat ring if no themed one exists.

The designs are **not on an even vertical stride** — solid `y47`, brackets `y95`, dotted `y143`.
Assuming a stride produced misaligned crops on the first attempt; the rects above are measured
bounding boxes.

### 9. Icons → stat rows, currencies, settings — **DONE (2026-08-07)**

`scripts/ui/ui_icons.gd` (`UIIcons`) is the shared atlas helper. Wired at three sites:

| Site | Icons |
|---|---|
| Roster stat rows | heart (HP), shield (ARMOR), bolt (SPEED) |
| Armory weapon bars | crossed swords (DMG), bolt (SPD), arrow (RNG) |
| Settings tab row | speaker, monitor, gamepad, person |

Labels are kept beside the stat icons deliberately. At 8×8 a heart and a shield are
distinguishable, but ARMOR vs SPEED is not something to make a player infer from a silhouette —
icon for recognition, word for confirmation. The tab row is the exception and the icon does real
work there, because a tab has room for only a few characters.

**The level-up cards are deliberately NOT iconified.** Their leading marks are ASCII on purpose
(`level_up_screen.gd` documents why: shape as a non-colour cue for colourblind players, with every
mark verified present in m5x7 after ★/✦ silently fell back to a vector font). The character-set
icons are pre-coloured, so they would fight the per-role accent colour that card carries — this is
a design trade, not an oversight.

The two stat-row helpers take a ready `TextureRect`, not a sheet coordinate, so a caller can draw
from either set without the row knowing which. RNG is why: the character set has no arrow, and a
hammer would have been a lie.

Measured layout, since it is not a plain lattice. **Two sets with different geometry:**

- **Character set** — top-right, two rows on a 16px horizontal stride: `y=24` from `x=384`
  (11 icons) and `y=40` from `x=376` (12 icons). The second row is offset by 8, so a single
  lattice origin does **not** describe both. Useful ones, all on `y=40`: heart `472`,
  shield `424`, crossed swords `392`, hammer `440`, bolt `504`, spark `488`, muscle `520`.
- **General set** — a 10 wide × 6 tall block on a 16px lattice from `(16, 16)`, repeated across
  8 tint blocks: 2 columns (`x +168`) × 4 rows (`y +104`).

**The character set ships fully pre-coloured** (red heart, yellow bolt, cyan spark), so it needs no
modulate and tinting one fights the art. The general set is **mostly** greyscale — "mostly" matters,
because several keep a colour accent (the monitor's blue screen, the gamepad's coloured face
buttons) and those accents are exactly what make each tab identifiable at 8×8.

Two traps this hit, both already documented elsewhere in the repo and both hit anyway:
`AtlasTexture.filter_clip` is required (8px art on a 16px stride bleeds its neighbour otherwise),
and a brand-new `class_name` is unresolvable until the editor rescans — consumers reach it as
`const Icons := preload(...)` under a different local name, the same fix `RunReportView` uses.

### 10. Window buttons · dividers · decoration — **dividers DONE (2026-08-09)**

Smaller wins that make panels look authored rather than generated.

**Dividers.** The theme had carried an `HSeparator` stylebox since gap 3, and **it drew nothing
from 2026-08-07 until 2026-08-09**. Two independent mistakes, both silent:

1. `_nine(DIVIDER, 6, 0)` set all four *texture* margins to 6 on a source strip that is `42×3`.
   Top + bottom claimed 12px of a 3px region, so the nine-patch centre row had negative height.
2. The *content* margins were 0, and Godot's `Separator` draws its stylebox into a rect whose
   height is `style.get_minimum_size().y` — the sum of the top and bottom content margins. Zero
   sum means a zero-height draw, so even with (1) fixed it stayed invisible.

Fixed in `tools/build_ui_theme.gd` (horizontal texture margin 6 to protect the arrow tips,
vertical 0, content margin summing to 3) and the theme regenerated — the diff against the
committed `.tres` is exactly those margin lines and nothing else. Five scripts had shipped
separators nobody had ever seen: `pause_menu`, `level_up_screen`, `insurance_panel`, `debug_panel`,
`passive_tree_debug_panel`. `VSeparator` was never affected; it uses a `StyleBoxFlat` with a 1px
content margin, which is why it always drew.

`RunReportView.heading()` and the new `RunReportView.rule()` now use real separators instead of
drawing rules as `"── … ──────"` text. **U+2500 is not in m5x7** (`FontFile.has_char` — the same
check that caught `★` and `✦`), so those rules had been rendering outside the pixel font on both
results screens. `•` and `━` are also absent; `·`, `×`, `»`, `^`, `&`, `#`, `*`, `+`, `-`, `=`, `_`
are all present. **Run `has_char` before putting any non-ASCII glyph in a player-facing string.**

**Window buttons — DONE (2026-08-09).** WINDOW BUTTONS group, colour column 0: **6×6 cells on an
8px stride**, three columns (minimise x=213 · restore x=221 · close x=229) over three tint rows
(y=21 · 37 · 53). The rows are *not* labelled by the pack, so they are named in `UIIcons` for how
they read once composited over the hub title bar's own brown: `DIM` (black frame, dim glyph),
`RAISED` (raised brown frame, light glyph), `BRIGHT` (black frame, bright glyph). **BRIGHT is the
only one legible at 12px on a dark plate**, so it is idle; RAISED is wired as hover/focus, which
uses the artist's state rather than a modulate hack.

`UIIcons.apply_window_button(btn, kind)` dresses any Button, scaling the 6px art by an **integer**
factor (2× → 12px). It returns false and leaves the button's text alone when the sheet is missing,
so a missing pack degrades to "X" rather than to a blank square. Applied at
`hub_panel_base.gd` — which covers all five hub panels **and** the settings panel, since that
delegates its close to the base — and `codex_grid_panel.gd`.

**Decoration — title flourish DONE (2026-08-09), the rest deliberately unused.** The group is
4 vertical plaques (20/17/16/15 × 48), 4 horizontal banners (48 × 20/17/16/15) and 3 medallions
(40×32, 32×24, 22×16), at x=646–856 for ornament row R1.

`UIIcons.title_flourish()` uses the flattest banner (`48×15 @ 672,952`) under the main-menu title.
**Use it at or near its native 48px width.** These are *nameplates*, not rules: nine-patched out
to 120px the solid fill stretches into a dark smear with a visible notch, which was tried first and
looked worse than nothing. At native width it reads as the ornament the artist drew.

The vertical plaques and medallions have no home yet — at 640×360 the screens that could carry them
are already tight, and forcing one in cost the main menu's tagline until the title block was lifted
to compensate. Recorded rather than wired.

### 11. Emotions + speech bubbles → hub NPCs

`merchant.gd` and `summon_altar.gd` are live entities. ~50 faces × 8-direction bubbles is flavour
for the hub, not a mechanic. Lowest priority; listed so it is not lost.

---

## Legacy tree

`Legacy_Assets/Minifantasy_Userinterface_Assets_(OLD__VERSION)/` (73 PNGs) is superseded by the
overhaul for every widget class — panels, buttons, bars, icons, cursors and controls all have
better equivalents above. Do not author against it.

Two assets have **no overhaul equivalent** and are worth remembering:

- `Miscellany/Clock/Minifantasy_GuiClock.png` — 16×16 animated clock.
- `Miscellany/Day_Night_Dial/Minifantasy_GuiDayNightDial.png` — 16×16 animated dial.

The run is a **5-phase clock**. A dial is a more legible read of "which phase am I in" than a
number, and the art already exists. Flagged, not proposed — phase display is a design call.
