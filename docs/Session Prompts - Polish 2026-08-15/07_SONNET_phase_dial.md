# Task 07: The phase dial

> **Tier:** 2 → Sonnet-class · **Depends on:** 01 committed; Ben's gate D-D — Ben must have said
> yes to a dial AND answered the descent question below. **Est. tokens:** ~1.5k in / ~3k out
> Paste everything below the rule into a fresh session, with Ben's answers filled in.

---

**BEN'S ANSWERS:**
- Sheet: **[ Minifantasy_GuiClock.png | Minifantasy_GuiDayNightDial.png ]**
- In descent mode the dial shows: **[ wall-clock phase | spatial depth (get_effective_phase) ]**

<goal>
The run is a 5-phase clock, but the only "where am I in the run" signal is a fading centre flash
(`hud.gd:598` `_build_phase_flash_label`) plus a countdown warning. Wire one of the two legacy
16×16 animated dial sheets into the HUD so run position reads at a glance.
</goal>

<context>
- The two candidate sheets are flagged in `docs/ui_pack_inventory.md` §Legacy as the only assets
  with no overhaul equivalent: `Minifantasy_GuiClock.png` and `Minifantasy_GuiDayNightDial.png`,
  both 16×16 animated. Read that inventory section for layout/frame info before slicing.
- **The descent subtlety (why this needed Ben):** combat and loot scaling read
  `GameManager.get_effective_phase()` — spatial DEPTH in descent mode, wall-clock `phase_number`
  otherwise. In descent the wall clock still advances and still drives the free extraction
  window. The dial must show whichever one Ben picked, consistently, and must not imply the
  other. If he picked depth, the extraction-window warning stays with the flash label — do not
  move it onto the dial.
- HUD home: `scripts/ui/hud.gd` — recently rethemed to the Grim sheet; follow its existing
  atlas-rect + update patterns. New sheet rects belong in the established homes
  (`ui_icons.gd` is the pattern home for pack rects).
- 16×16 at 3× viewport scaling renders 48px on screen — small. Position it adjacent to the
  existing timer panel; do not crowd the keystone/portal pill stack.
</context>

<requirements>
- Animate by phase: the dial's frame maps to phase 1–5 (or depth fraction if Ben picked depth).
  Smooth per-frame animation only if the sheet's frame count supports it without judder.
- No new fonts, no text on the dial. If a numeral is wanted later, that is Ben feedback, not
  this session.
- Respect `Settings` visibility/accessibility toggles the HUD already honours (check how the
  timer panel handles them and do the same).
- Verify in-engine in BOTH modes: Training Room (flat, wall-clock) and a descent (ask Ben to
  open Godot; god mode + suppressed spawns traversal is fine; back up `progression.json`
  first, restore after).
- Update `docs/ui_pack_inventory.md` — move the chosen sheet from §Legacy to the utilization
  record; note the rejected sheet's status honestly.
- One conventional commit; update `docs/polish_plan_2026-08-15.md` §2.4 and the
  00_EXECUTION_PLAN status table.
</requirements>

<output_format>
The commit plus a report with an in-engine screenshot of the dial in each mode, the frame→phase
mapping chosen, and the inventory doc updated.
</output_format>
