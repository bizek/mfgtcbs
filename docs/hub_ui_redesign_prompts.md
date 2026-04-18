# Hub UI Redesign — Continuation Session Prompts

The Armory panel was redesigned in a prior session and serves as the canonical reference.
These prompts continue that work across the remaining hub panels.

## How to Use

Paste each prompt into a fresh Claude Code session in this repo.
All prompts are **Tier 2 (Sonnet-class)** except Records and Launch which are **Tier 1 (Haiku-class)**.

## Execution Order

```
Phase 1:  Panel Base Chrome       (sets foundation for all panels)
Phase 2:  Workshop, Research, Roster  (can run in parallel)
Phase 3:  Records, Launch             (simplest — read-only reskins)
```

## Shared Design System Reference

Every prompt below inherits this design system. It is established in `scripts/ui/hub_armory_panel.gd`.

```gdscript
# Color palette
const C_CARD    := Color(0.082, 0.075, 0.063)
const C_CARD_HI := Color(0.102, 0.092, 0.076)
const C_PLATE   := Color(0.055, 0.050, 0.042)
const C_BORDER  := Color(0.165, 0.145, 0.125)
const C_B_HOT   := Color(0.478, 0.255, 0.063)
const C_B_ACT   := Color(0.690, 0.353, 0.082)
const C_AMBER    := Color(0.831, 0.447, 0.102)
const C_AMBER_HI := Color(0.941, 0.565, 0.188)
const C_AMBER_LO := Color(0.353, 0.173, 0.031)
const C_RED_HI   := Color(0.820, 0.157, 0.063)
const C_GREEN_HI := Color(0.314, 0.690, 0.188)
const C_T0 := Color(0.800, 0.690, 0.565)  # bright text
const C_T1 := Color(0.541, 0.408, 0.282)  # mid text
const C_T2 := Color(0.314, 0.235, 0.157)  # dim text
const FONT := HubPanelBase.PIXEL_FONT      # m5x7.ttf
const FS_LG := 21  # titles
const FS_MD := 19  # body
const FS_SM := 16  # labels
const FS_XS := 13  # tags, meta

# Helper: styled label appended to parent
func _lbl(parent: Control, text: String, sz: int, col: Color) -> Label

# Helper: flat button (strips chrome, applies bg colors)
func _style_btn_flat(btn: Button, normal_bg: Color, hover_bg: Color) -> void

# Helper: 1px horizontal rule
func _rule(parent: Control, col: Color = C_BORDER) -> void  # ColorRect, h=1, expand_fill
```

**Hard constraints (apply to every prompt):**
- Any `MarginContainer` or `VBoxContainer` set to FULL_RECT **must** have `mouse_filter = Control.MOUSE_FILTER_IGNORE` — otherwise it blocks the title bar close button.
- Never use `var x := expr` when the type can't be inferred. Use `var x: bool = expr` etc.
- Do **not** hand-edit `.tscn` files. Script-only changes only (unless using the Godot MCP editor tools).
- `populate(pm)` clears and rebuilds dynamic children via `queue_free()` loop. No persistent node refs for dynamic content.

---

## Prompt 1 — Hub Panel Base Chrome [Tier 2]

```
<goal>
Add dark industrial decorative chrome to HubPanelBase so every hub panel
gains a consistent amber accent rule under the title bar and a slightly
warmer close-button hover treatment.
</goal>

<context>
Project: Godot 4.6.1, GDScript. Extraction survivors game.
File to modify: scripts/ui/hub_panel_base.gd
Reference for the aesthetic: scripts/ui/hub_armory_panel.gd (read it first)

HubPanelBase is a Panel with a ColorRect TitleBar (height 29px) and a ContentContainer
below it. Its _ready() already applies accent_color to the title bar and border.
The armory panel's accent_color is Color(0.9, 0.6, 0.12) (amber).

The panel background was recently updated in hub_panel_base.tscn to
Color(0.052, 0.047, 0.038, 0.97) — warm near-black instead of blue-dark.

What is currently MISSING from the chrome:
1. A 1–2px amber accent rule sitting just below the title bar bottom edge,
   separating it from the content area. Should use accent_color at ~50% alpha.
2. The close button hover is currently a harsh red. Soften it to
   Color(0.55, 0.18, 0.12, 0.80) — dark red, less alarming.
3. An optional subtle left-edge accent strip (2px wide, full content height,
   accent_color at 20% alpha) to give panels a slight left-border glow.
</context>

<requirements>
- Add the accent rule as a ColorRect child of TitleBar, anchored to its
  bottom edge (anchor_top=1, anchor_bottom=1, offset_top=-2, offset_bottom=0,
  anchor_left=0, anchor_right=1). Color = accent_color at 0.5 alpha.
- Update the close button hover StyleBoxFlat bg_color to Color(0.55, 0.18, 0.12, 0.80).
  The hover stylebox is SubResource("StyleBoxFlat_close_hover") in the .tscn —
  but since we can't hand-edit .tscn, override it in _ready() via
  add_theme_stylebox_override on the CloseButton node.
- Add the left-edge strip as a 2px ColorRect child of ContentContainer,
  anchored full-height on the left edge. Color = accent_color at 0.18 alpha.
  Give it mouse_filter = MOUSE_FILTER_IGNORE.
- All additions go in _ready() after the existing accent_color logic.
- Do not change any existing signals, exports, or helpers.
</requirements>

<output_format>
Updated scripts/ui/hub_panel_base.gd in full. No other files.
</output_format>
```

---

## Prompt 2 — Workshop Panel [Tier 2]

```
<goal>
Rewrite hub_workshop_panel.gd to match the dark industrial aesthetic
established in hub_armory_panel.gd, while keeping all existing functionality.
</goal>

<context>
Project: Godot 4.6.1, GDScript. Extraction survivors game.
Files to read first:
  - scripts/ui/hub_armory_panel.gd   (canonical reference for the new style)
  - scripts/ui/hub_workshop_panel.gd (current implementation to redesign)
  - scripts/ui/hub_panel_base.gd     (base class, provides PIXEL_FONT + helpers)

The Workshop panel shows 5 permanent hub upgrades the player can purchase
with resources. Each upgrade has a name, current tier / max tier, cost,
effect description, and a BUY button. Upgrades are disabled when: owned/maxed,
insufficient resources, or at max tier.

The current panel uses HubPanelBase's add_row() helper and simple flat buttons.
The redesign should instead build upgrade "rows" as styled cards — similar to
the weapon cards in the Armory panel but simpler (no stat bars needed).
</context>

<requirements>
- Copy the color constants and helpers (_lbl, _style_btn_flat) from the
  armory panel into this script. Do not import them — inline them.
- Each upgrade is a card: Panel with C_CARD background, 1px C_BORDER border,
  3px left amber strip (C_AMBER if purchasable, C_BORDER if maxed/locked).
- Inside each card (HBoxContainer layout):
    LEFT: VBoxContainer — upgrade name (FS_MD, C_T0) + tier badge (FS_XS, C_T2)
          e.g. "ARMORY EXPANSION" + "TIER 1 / 2"
    RIGHT: VBoxContainer — cost label (FS_XS, C_T2) + BUY/OWNED button
- BUY button states:
    purchasable → C_AMBER text, C_AMBER_LO background on hover
    maxed/owned → "MAXED" text, C_GREEN_HI color, disabled
    unaffordable → "LOCKED" text, C_T2 color, disabled
- Section header: "HUB UPGRADES" label (FS_SM, C_T2) + 1px amber rule.
- Footer: resources remaining (FS_SM, C_T1) + hub tier (FS_XS, C_T2).
- Full-rect MarginContainer must have mouse_filter = MOUSE_FILTER_IGNORE.
- All dynamic children cleared via queue_free() loop at top of populate().
</requirements>

<output_format>
Full rewrite of scripts/ui/hub_workshop_panel.gd. No other files.
</output_format>
```

---

## Prompt 3 — Research Panel [Tier 2]

```
<goal>
Rewrite hub_research_panel.gd to match the dark industrial aesthetic
established in hub_armory_panel.gd, while keeping all blueprint-purchase
functionality intact.
</goal>

<context>
Project: Godot 4.6.1, GDScript. Extraction survivors game.
Files to read first:
  - scripts/ui/hub_armory_panel.gd   (canonical reference for the new style)
  - scripts/ui/hub_research_panel.gd (current implementation — NOTE: this panel
    builds its own HubPanelBase at runtime rather than using a .tscn instance)
  - data/weapons.gd                  (WeaponData.ALL — weapons with unlock_id != "" are purchasable)

The Research panel sells weapon blueprints. Each purchasable weapon shows:
  - Weapon display name + behavior class tag (e.g. [SPREAD])
  - Description (one line, small)
  - Blueprint cost in resources
  - BUY button (disabled if already owned or can't afford)

The current panel uses a ScrollContainer because there can be many weapons.
Keep the ScrollContainer — the list can overflow the panel height.
</context>

<requirements>
- Copy the color constants and helpers (_lbl, _style_btn_flat) from armory panel.
- Each weapon entry is a compact row card: Panel (C_CARD bg, 1px C_BORDER border,
  3px left strip — C_AMBER_HI if purchasable, C_GREEN_HI if owned, C_BORDER if locked).
- Row layout (HBoxContainer):
    LEFT (expand): weapon name (FS_MD, C_T0) + "[BEHAVIOR]" tag (FS_XS, C_T2)
                   + description on next line (FS_XS, C_T2, clip_text=true)
    RIGHT: cost label (FS_XS, C_T2) + BUY/OWNED button
- BUY button states:
    purchasable → C_AMBER text, hover C_AMBER_LO bg
    owned       → "OWNED" text, C_GREEN_HI, disabled
    unaffordable → show cost in C_RED_HI, "BUY" disabled
- Header: "WEAPON RESEARCH" + 1px amber rule + resources label right-aligned.
- ScrollContainer must have mouse_filter = MOUSE_FILTER_IGNORE.
  Its VBoxContainer child also gets MOUSE_FILTER_IGNORE.
- Full-rect MarginContainer gets MOUSE_FILTER_IGNORE.
</requirements>

<output_format>
Full rewrite of scripts/ui/hub_research_panel.gd. No other files.
</output_format>
```

---

## Prompt 4 — Roster Panel [Tier 2]

```
<goal>
Rewrite hub_roster_panel.gd to match the dark industrial aesthetic
established in hub_armory_panel.gd, while keeping all character
selection and purchase functionality intact.
</goal>

<context>
Project: Godot 4.6.1, GDScript. Extraction survivors game.
Files to read first:
  - scripts/ui/hub_armory_panel.gd  (canonical reference for the new style)
  - scripts/ui/hub_roster_panel.gd  (current implementation to redesign)
  - data/characters.gd or similar   (CharacterData.ALL — character stats, colors)

The Roster panel has two columns:
  LEFT (~40% width): scrollable list of character buttons, one per character.
  RIGHT (~60% width): detail view for the selected character showing
    name, HP/Armor/Speed stats, starting weapon, passive ability description,
    and a SELECT / BUY action button.

Characters have a .color field used as their identity accent color (cyan, orange, etc.)
The current panel uses ColorRect highlights and dot indicators next to each character.
Keep this concept — the character's own color should bleed into their card.
</context>

<requirements>
- Copy the color constants and helpers from the armory panel.
- Character list: each entry is a Button styled as a compact card.
  - Background: C_CARD normally, C_CARD_HI when selected.
  - Left strip (3px): character's own .color when selected, C_BORDER otherwise.
  - Text: character name (FS_MD), color = character .color if owned, C_T2 if locked.
  - Small "●" dot indicator left of name, colored with character .color.
  - Selected character's card gets 1px border in C_B_ACT.
- Detail pane (right): dark card (C_PLATE bg, 1px C_BORDER border).
  - Header: character name (FS_LG, character .color) + class/role tag (FS_XS, C_T2).
  - Stats section: HP / ARMOR / SPEED as labeled rows with value (FS_MD, C_T0).
    Use the anchor-based ColorRect bar pattern from the armory panel to show
    stat bars (normalize against reasonable maxes, e.g. HP max=200, Speed max=200).
  - Passive: label "PASSIVE" (FS_XS, C_T2) + description text (FS_SM, C_T1).
  - Separator rule + SELECT/BUY button at bottom.
    SELECT → C_AMBER text, C_AMBER_LO hover (only if owned)
    BUY    → C_GREEN_HI text, show cost (if affordable)
    unaffordable BUY → C_T2 text, disabled
    already selected → "ACTIVE" text, C_GREEN_HI, disabled
- Layout: HBoxContainer root split into left list + right detail.
- Full-rect containers: MOUSE_FILTER_IGNORE.
</requirements>

<output_format>
Full rewrite of scripts/ui/hub_roster_panel.gd. No other files.
</output_format>
```

---

## Prompt 5 — Records Panel [Tier 1]

```
Rewrite scripts/ui/hub_records_panel.gd to match this dark industrial aesthetic.
Read the current file and scripts/ui/hub_armory_panel.gd first.

The Records panel is read-only: it shows 7 lifetime stats as labeled rows
(Total Runs, Successful Extractions, Deaths, Total Kills, Deepest Phase,
Most Loot, Extraction Rate %).

Design: each stat row is a compact HBoxContainer inside the panel's content area.
  - Stat label on left: FS_XS, Color(0.314, 0.235, 0.157)
  - Value on right: FS_MD, Color(0.800, 0.690, 0.565) (bright amber-white)
  - Thin 1px rule (Color(0.165, 0.145, 0.125)) between rows
  - Section header "MISSION RECORDS" in FS_SM, dim color, with amber rule beneath
  - Panel accent rule: 1px Color(0.831, 0.447, 0.102) at 40% alpha below the header
Font: HubPanelBase.PIXEL_FONT at the sizes above.
Use populate(pm) to set values from ProgressionManager as before.

Constraints:
  - Full-rect MarginContainer must have mouse_filter = Control.MOUSE_FILTER_IGNORE
  - No new nodes in the .tscn — build everything in code inside populate()

Output: full rewrite of scripts/ui/hub_records_panel.gd only.
```

---

## Prompt 6 — Launch Panel [Tier 1]

```
Rewrite scripts/ui/hub_launch_panel.gd to match this dark industrial aesthetic.
Read the current file and scripts/ui/hub_armory_panel.gd first.

The Launch panel shows the current loadout (character + weapons) and has one
"BEGIN DESCENT" button to start the run.

Design target:
  - Dark card (Color(0.082, 0.075, 0.063)) with 1px Color(0.165, 0.145, 0.125) border
    containing the loadout summary.
  - Section header "DEPLOYMENT BRIEF" in FS_SM, dim, with amber rule beneath.
  - Each loadout row: label on left (FS_XS, dim) + value on right (FS_MD, bright).
    Character name: colored with character's own .color value.
    Weapon slots: Color(0.800, 0.690, 0.565).
    Passive row: FS_XS, Color(0.541, 0.408, 0.282) for the description text.
  - Separator rule + "BEGIN DESCENT" button at bottom.
    Button: Color(0.820, 0.157, 0.063) text (alert red), C_AMBER_LO hover bg,
    1px Color(0.690, 0.353, 0.082) border. FS_LG, all-caps, full width.
    On hover, text brightens to Color(1.0, 0.4, 0.2).
Font: HubPanelBase.PIXEL_FONT throughout.
Constants: inline the color values directly — no need to declare named consts for a small file.

Constraints:
  - Full-rect MarginContainer: mouse_filter = Control.MOUSE_FILTER_IGNORE
  - Do not change scene topology or any gameplay logic (_start_run etc.)

Output: full rewrite of scripts/ui/hub_launch_panel.gd only.
```
