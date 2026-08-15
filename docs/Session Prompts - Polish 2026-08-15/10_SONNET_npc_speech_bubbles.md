# Task 10: Hub NPC emotions and speech bubbles (optional)

> **Tier:** 2 → Sonnet-class · **Depends on:** 01 committed · No gate, lowest priority in the
> set — run when nothing above it is runnable.
> **Est. tokens:** ~1.2k in / ~2.5k out · Paste everything below the rule into a fresh session.

---

<goal>
The merchant and summon altar are live entities in the hub with no reactions. Wire the UI pack's
emotion faces + speech bubbles (UI gap 11 in `docs/ui_pack_inventory.md`) so the hub reads
inhabited: an idle emote now and then, a reaction on interact, a reaction on purchase.
</goal>

<context>
- Read `docs/ui_pack_inventory.md` gap 11 first for the sheet layout (~50 faces × 8-direction
  bubbles) and where the atlas bands sit. New sheet rects go in the established home
  (`ui_icons.gd` pattern).
- The two entities: `scripts/**/merchant.gd` and `summon_altar.gd` (locate them — they also
  appear in descent merchant blocks, where this should work too, same code path).
- Bubbles are world-space over 16px-ish sprites at 3× scaling — small. One face per bubble, no
  text. If any text is ever added it must be m5x7 @ 16 minimum, but the design intent here is
  faces only.
- This is decorative: **no collision, no gameplay effect**, and per the level-generation rule,
  nothing colliding may be scattered.
</context>

<requirements>
- Three trigger moments only: idle (rare, randomized, hysteresis so it never spams), on
  interaction open, on transaction (purchase / summon). Pick emotive faces that fit each
  (e.g. greeting on open, pleased on purchase, grumble on close-without-buying if the sheet
  has one).
- Bubble pops in/out with a short scale or fade — no lingering UI. Respect `GameCursor` modes
  (bubbles are world objects, not UI panels; they must not capture focus or input).
- Verify in-engine in the hub AND at a descent merchant block (ask Ben to open Godot; back up
  `progression.json`, restore after).
- Update `docs/ui_pack_inventory.md` gap 11 → utilization record with the rects used and the
  faces chosen.
- One conventional commit; update the 00_EXECUTION_PLAN status table.
</requirements>

<output_format>
The commit plus a short report with a screenshot of a bubble in the hub, the trigger table
(moment → face), and the inventory doc updated.
</output_format>
