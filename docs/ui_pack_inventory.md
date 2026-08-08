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
sheet through `GameCursor` (gap 2), and **the Grim sheet now backs a project-wide `Theme`**
(gap 3, done 2026-08-07). Gaps 4–11 are still open.

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
| `Cursors/Click_Effects/Click_Effects.png` | 64×208 | 16×16 frames, **100ms native**, 4 colour columns | 2 effects (collapsing-in, expanding-out) × ~6 frames |
| `Controls/Controller/_Controllers.png` | 504×360 | 8×8 | **Xbox** `y16–120` · **PlayStation** `y128–224` · **Switch** `y248–352`. Sticks, D-pads, face buttons, shoulders and triggers. Every button has regular + **pressed** state; white-outline variants for highlight |
| `Controls/Keyboard_Mouse/_Keyboard_And_Mouse.png` | 568×400 | 8×8 | Full keyboard, **pressed + unpressed**, in 4 variants (light/dark × outlined/plain). Mouse bodies and hand icons at `y336–384` |
| `Labels_And_Tags/_Labels_And_Tags.png` | 320×448 | 16×16 sliced | 2 designs (pill bookmark, ribbon banner) × **8 colours** × (plain / white-outlined) |
| `Selectors/_Selectors.png` | 432×320 | — | Full box, corner brackets, dashed box, corner ticks, plus arrow/chevron/diamond pointer sets, each in **4 tints** (white/black/red/green) |
| `Grids/Grids.png` | 1360×496 | 16×16 sliced | Separators, single boxes, 3×3 and 5×5 grid frames, in 5 tints × 5 line styles (solid/dashed/dotted/ticked/rounded) |
| `Character_Emotions/_Emotions.png` | 152×104 | 8×8 | ~50 expression faces (happy, angry, shocked, crying, dead, love, music, ellipsis…) |
| `Character_Emotions/_Bubble.png` | 280×72 | — | Speech bubbles, 8 tail directions × 4 sizes |

---

## Current utilization

`scripts/ui/hud.gd:10` — the pack's single consumer:

| Rect | Used for |
|---|---|
| 5× capsule fill `40×6 @ y709`, 256px column stride | HP (red), XP (blue), extraction (green); yellow/purple reachable via `_fill_region_for_color` for boss bars |
| 2× end-cap nub `4×6` | HP and XP bar end gems |
| `PANEL_PILL` `48×16 @ (64,352)` | nine-patch, 5px margins |
| `PANEL_SQUARE` `48×48 @ (64,384)` | nine-patch, 6px margins |

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

### 2. Cursors → the manual-aim reticle

The game is built on cursor aim and ships the OS arrow. The sheet has 4 crosshair designs in
4 tints — enough for real state feedback (neutral / hostile under cursor / ability on cooldown /
out of range). The **melee / ranged / magic** attack cursors map cleanly onto kit archetype, so
the reticle could read the equipped class. Click effects (100ms, 6 frames) give a fire-confirm
pop at the aim point. Consider whether this competes with existing crosshair feedback before
committing to the per-class variant.

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

### 4. Slots + grids → armory, passive tree, codex

`hub_armory_panel.gd` and `codex_grid_panel.gd` draw their own boxes. The pack has real item slots
(including 4-way D-pad clusters for equip layouts) and pre-built 3×3 / 5×5 grid frames on a 16px
slice, in 5 line styles.

### 5. Resource orbs → HP / class resource

Pre-animated globes in 5 colours × 3 sizes. Mock_Up_1 shows them as the anchor of a dark HUD. An
option for the HP readout, or for a class-resource meter that currently has no distinct visual.

### 6. Tabs → settings / codex categories — **DONE (2026-08-07)**

Grim TABS group, colour column 0, the brighter right-hand sub-group, wired as `TabContainer` /
`TabBar` styleboxes in the project theme. No per-screen work was needed: the settings panel already
used a real `TabContainer`, so this is theme-only.

The pack draws tabs at **two heights, and that IS the selected/unselected metaphor** — the active
tab is taller and stands proud of the row. Using `TAB_SHORT` (48×15) for unselected and `TAB_TALL`
(48×23) for selected gets that from the art instead of faking it with colour. The body below the
row uses the standard R1 plate so the tab strip and its panel read as one object.

### 7. Labels & tags → rarity, class, "NEW"

8 colours × 2 designs. Maps directly onto a rarity scale, and onto the codex's
discovered/mastered markers.

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

### 9. Icons → stat rows, currencies, settings

Heart, shield, crossed swords, lightning, stamina, backpack, anvil, magic spark — the character
set covers most of what the armory and level-up screens spell out in words. The general set
(gear, sound, screen, controller, save) covers the settings panel rows.

### 10. Window buttons · dividers · decoration

Smaller wins that make panels look authored rather than generated.

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
