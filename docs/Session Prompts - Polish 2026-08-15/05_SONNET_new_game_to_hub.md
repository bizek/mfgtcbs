# Task 05: NEW GAME lands in the hub

> **Tier:** 2 → Sonnet-class · **Depends on:** 01 committed; Ben's gate D-B — run ONLY if Ben
> decided plan §2.1 as "NEW GAME should go to the hub". If he said "intended as-is", archive this
> prompt unrun and record the decision in `docs/polish_plan_2026-08-15.md` §2.1.
> **Est. tokens:** ~1k in / ~1.5k out · Paste everything below the rule into a fresh session.

---

<goal>
A brand-new player currently goes main menu → straight into a descent as "The Drifter", never
seeing the roster, armory, launch panel, or the biome choice (which now exists). Reroute NEW GAME
to the hub, without breaking the first-run onboarding flow.
</goal>

<context>
- Verified 2026-08-15: `scripts/main_menu.gd:279` and `:316` (`_start_new_game`) both go to
  `res://scenes/main_arena.tscn` via `SceneTransition.change_scene`; CONTINUE goes to
  `res://scenes/hub.tscn` (`:266`). `:383` is a second caller of `_start_new_game` — find out
  what it is before touching it.
- First-run onboarding is `scripts/ui/first_run_overlay.gd`; its cues were written to trigger on
  the first RUN (they branch descent vs arena). Landing in the hub first means the player's
  actual first screen is now the hub — check whether any "first time" cue should exist there or
  whether the overlay simply fires on the first descent as before. Do not design new tutorial
  content; just make sure nothing fires in the wrong place or never fires.
- `progression_manager.gd:94` defaults `selected_character` to "The Drifter" — landing in the
  hub makes the roster visible before the first run, which is the point of the change.
</context>

<requirements>
- NEW GAME → `res://scenes/hub.tscn` through `SceneTransition` with the same fade params CONTINUE
  uses, unless `_start_new_game` does state reset work that CONTINUE's path does not — read both
  paths fully first and keep any reset logic.
- Check `:383`'s caller and give it the same destination if it is a "start fresh" path.
- Verify in-engine (ask Ben to open Godot; back up `progression.json` first): from a fresh save,
  NEW GAME → hub renders, launch panel works, launching a descent from there triggers the
  first-run overlay's descent cues. Restore the save after.
- One conventional commit. Update `docs/polish_plan_2026-08-15.md` §2.1 (decision + done) and the
  00_EXECUTION_PLAN status table.
</requirements>

<output_format>
The commit plus a three-line report: what `:383` turned out to be, what reset logic (if any) was
preserved, and the first-run verification result.
</output_format>
