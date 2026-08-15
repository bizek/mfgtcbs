# Task 11: The next biome — The Threshold (4) or The Inferno (5)

> **Tier:** 3 → Opus-class · **Depends on:** 01 committed (its commit is the template); after 08
> ideally · Gated on Ben's decision D-E. **Est. tokens:** ~4k in / ~8k out — this is the largest
> task in the plan; expect it to span more than one session (blocks, then enemies, then landing).
> Paste everything below the rule into a fresh session, with Ben's answers filled in.

---

**BEN'S ANSWERS (required — do not start without all three):**
- Biome: **[ 4 — The Threshold | 5 — The Inferno ]**
- Asset pack for the enemy roster: **[ pack folder under assets/ ]**
- Identity in one sentence (what the biome FEELS like, e.g. the Catacombs' "ordered undead
  legion" vs the Nightmare Realm's "nothing here belongs together"): **[ ... ]**

<role>
You are building a full descent biome for a block-based survivor/extraction game, following a
pipeline that has now shipped two biomes. You are not inventing process — you are executing a
proven recipe with new content and taste.
</role>

<objective>
`LevelData.LEVELS[4]` (The Threshold) and `[5]` (The Inferno) are name + music id stubs, and no
block prefix exists for either (`blocks/` has caves, crypt, nmrealm, warp — verified 2026-08-15).
Build the chosen biome end to end: block set, enemy roster, wave table, bosses, and the LevelData
entry — landing it exactly the way the Nightmare Realm landed.
</objective>

<context>
- **The template is the biome-3 commit from task 01** (`git log` for the Nightmare Realm landing
  commit). Study its full diff before writing anything: LevelData `blocks` dict shape, registry
  wiring, factory structure (`nightmare_enemy_data.gd` for the roster pattern,
  `centaur_king_data.gd` / `angel_of_death_data.gd` for bosses), the scene-generator tool
  pattern (`tools/gen_nightmare_scenes.gd`), and the two compiler-generated bookend blocks.
- Blocks: use the `/blockgen` skill — text sketches in `blocks/<biome>/` → `tools/block_compiler.py`
  → `.ldtkl` + previews. Read `docs/block_sketch_workflow.md` and `docs/ldtk_schema.md` first;
  the block-edge convention doc note (`41afbaa`) exists because ignoring it buried a player in
  rock. Required set: `00_Entry`, ~9 inner blocks, Merchant, Portal. A new tileset must be
  registered in the LDtk project — the caves/crypt/nmrealm registrations are the pattern; check
  what the chosen pack provides for floors/walls/props.
- Enemies: `docs/engine_reference.md` → "New Enemy" + "Enemy Role Taxonomy". Aim for the same
  role spread the other biomes use (fodder/swarmer/skirmisher/ranged/caster/heavy + specials),
  ~10–14 types, one miniboss, one final boss with choreography
  (`docs/boss_authoring_reference.md`). **Full pack utilization**: all facing rows, effect
  overlays, special-animation packages; check `anim_overrides.json` `_custom_anims` for name
  collisions before adding sheets.
- Wave composition: 5 phases, weights sum to 1.0 per phase, escalating the way LEVELS[2] and
  [3] do — read both and keep the biome's identity sentence in charge of WHO escalates.
- Enemy scaling and difficulty read `get_effective_phase()` (spatial depth in descent);
  `docs/core_framework_decisions.md` has the scaling formulas — new enemies inherit them via
  EnemyDefinition, don't hand-tune HP against them.
- Music (`threshold.ogg` / `inferno.ogg`) is task 02's pattern, NOT this task — leave the
  music id wired and the file absent; note it in the report.
</context>

<constraints>
- Data factories + registry + generated scenes only — no new systems, no new scripts beyond a
  scene-generator variant and the enemy data files.
- Decorative block passes stay non-colliding (repo rule).
- The biome must fall back gracefully until finished: `LevelData.has_blocks()` gates descent —
  do not add a partial `blocks` dict to LEVELS until the block set is complete, or the launch
  panel will offer a broken destination.
</constraints>

<reasoning_guidance>
Sequence the work so each session ends landable: (a) block set compiled + previewed, (b) enemy
factories + scenes + registry, (c) LevelData entry + smoke test + commit — (c) is the only step
that makes the biome player-visible, so partial work never ships. Taste decisions worth real
thought: which pack creatures map to which combat roles (a wrong fodder pick makes phase 1
tedious), and what the biome's block silhouettes do differently — the Nightmare Realm's isles
and rifts read instantly as not-caves; the new set needs its own such signature.
</reasoning_guidance>

<output_format>
Per the sequence above: grouped conventional commits at each landable point, a smoke-tested
descent (entry walkable, waves from the new roster, merchant/portal reachable, bosses spawn —
Ben opens Godot, `progression.json` backed up/restored), `docs/polish_plan_2026-08-15.md` §3.1
and the 00_EXECUTION_PLAN status table updated, and a final report listing what music/audio
remains for task 02's pattern.
</output_format>

<success_criteria>
The biome is selectable from the launch panel and survivable end to end; every enemy uses its
pack's real assets fully; the wave table escalates according to the identity sentence; no
system code changed — the whole biome is data, scenes, and blocks, proving the pipeline for
whichever biome comes last.
</success_criteria>
