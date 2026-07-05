# 26 — Passive Tree Backend (data, points, save/load, run-start apply)

**Tier:** 2 → Sonnet-class
**Depends on:** nothing open (pacing Phases 1–3 shipped)
**Blocks:** 27 (behaviors), 28 (hub UI)

```
You are working in a Godot 4.6.1 GDScript survivor/extraction game (Extraction Survivors,
repo root E:\Projects\extraction-survivors). Read CLAUDE.md first, then
docs/passive_tree_spec.md — it is the AUTHORITATIVE design for this task. Do not re-decide
anything the spec locks; implement it.

GOAL: Build the passive skill tree BACKEND: the node data file, the points economy +
persistence in ProgressionManager, tier-gating rules, and run-start stat application.
Behavior/keystone nodes are OUT OF SCOPE (a later session) — author their data entries per the
spec but leave them inert (skip nodes with a "behavior" key during application, and make
can_allocate still allow buying them). The hub UI is also out of scope.

IMPLEMENT (per spec sections 2, 3, 4, 5.1, 5.2, 5.3, 6.1):
1. data/passive_tree.gd (class_name PassiveTreeData) — static NODES dictionary with ALL 59
   nodes from spec §4, exactly the ids/values/tiers/costs/ranks listed. Zero behavior in the
   data file. Also add small static helpers if useful (e.g. nodes_in_branch()).
2. ProgressionManager (scripts/managers/progression_manager.gd) — the API in spec §5.2:
   passive_points / passive_allocations / lifetime_passive_points, get_passive_points(),
   get_node_ranks(), branch_ranks(), can_allocate() (points + max_ranks + the §3 tier gate:
   branch tier N needs 3×N ranks in that branch; bridges need ≥4 ranks in either adjacent
   branch; core always open), allocate(), refund_all(), bank_passive_points(). Extend
   save_data()/load_data() following the existing style EXACTLY — defensive .get() defaults,
   old saves must load clean.
3. Award wiring — add a defaulted levels_gained parameter to record_extraction() and
   record_death(); bank max(levels_gained, 0) points. Find every call site (search the working
   copy — likely game_manager.gd / extraction flow / death flow) and pass the player's final
   level minus 1.
4. Run-start application — player.gd: _apply_passive_tree() called right after
   _load_character_stats() (AFTER CharacterFactory.build_base_modifiers). Translate each
   allocated stat node's effects list into ModifierDefinitions on modifier_component,
   multiplying value × ranks. Confirm dash (dash_speed/dash_cooldown/dash_charges) and
   melee_range nodes actually move gameplay — those stats are already get_stat()-driven.
5. xp_gain hook (spec §6.1) — in the player XP-gain path, multiply gained XP by
   1.0 + modifier_component.sum_modifiers("xp_gain", "bonus").

CONSTRAINTS:
- Typed GDScript; never := on untyped array element access (project rule — it crashes type
  inference). Resource subclasses are @export data only.
- Don't touch UpgradeManager's in-run upgrades — the tree stacks WITH them by design.
- No .tscn edits needed in this task; if you think you need one, stop and re-read the scope.

DELIVERABLES:
- The code above, validate-compiled (use the Godot MCP validate/build tools if available).
- docs/passive_tree.md — the API doc for the UI session: every public method signature, the
  save keys, the tier-gate rule, and a 5-line "how to render a node's state" recipe
  (available/locked/maxed logic in terms of the API).
- Summarize the changes; ask Ben to playtest stat nodes in Godot (he runs Godot himself).
```
