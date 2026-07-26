# Wiring Map — Minifantasy sheet types → engine homes

The one reference for classifying every sheet in a pack and plugging it into *this* codebase.
Each section: what the sheet looks like, where it goes, and the exact function to mirror.

## Pack layout (standard)

```
<Pack>/
  General_Animations/
    Idle / Walk / Attack / Dmg / Die / Jump .png     ← the body (4 facing rows; Die usually 1 row)
    *_Effect.png          (True Heroes: merged glow overlay)
    No_Effect/ Only_Effect/  (True Villains: split — base sheet already has glow baked in)
    _Shadows/  _GIFs/  AnimationInfo.txt
  Special_Animations/<Name>/
    <Name>_Cast.png            ← caster body pose (4 rows) for the ability
    <Name>_Orthogonal.png      ← 8-way projectile flight, cardinal rows  ┐ often bake the caster
    <Name>_Diagonal.png        ← 8-way projectile flight, diagonal rows  ┘ into frame 0 — beware
    Spinning_<Name>.png        ← directionless projectile spin loop (PREFER this for projectiles)
    <Name>_Rise.png            ← world VFX: the effect rising/forming, centered on caster
    <Name>.png                 ← world VFX loop (e.g. orbiting bones; may have rows = intensity)
    Stand_Alone_<Name>.png     ← world VFX detached from the caster (spawns at a target point)
    Stand_Alone_<Name>_Ground.png ← the ground/floor layer of that VFX (renders BELOW bodies)
    <Name>_Impact.png          ← hit/impact burst (single row)
    <Minion>/                  ← a summoned minion's OWN full body kit (Idle/Walk/Attack/Dmg/Die)
    <AltForm>/ (e.g. Soul_Shape/)  ← an alternate player form (Idle/Fly)
    No_Effect/ Only_Effect/ _Shadows/ __Shadows/ _GIFs/ __GIFs/
```

Cell size is usually 32×32; some world-VFX sheets are 64×64 (pass the size as spec slot-3 int).
Row count = `sheet_height / cell` — the sprite factory auto-detects it (single-row = base anim only).

**Verify cell size before slicing world-VFX sheets — guessing wrong silently multiplies the content.**
A 576×64 "rise" sheet is ambiguous: 9 frames @64px, OR 18 frames × 2 rows @32px. Slice a 32px-2-row
sheet at 64px and every cell becomes a **2×2 block of four 32px sub-frames** drawn at once — one emerge
renders as ~4 skeletons, and ×N summons reads as a battalion (this shipped for the Necromancer's Rise
Corpse). The pack's AnimationInfo.txt states the true frame size; if it's silent, render the sheet
in-game at 32px-row0 vs 64px-row0 (scaled up, one frame) and screenshot — the correct size shows ONE
clean subject, the wrong size shows a cluster. Character-body-scale effects (a rising skeleton) are
almost always 32px; only genuinely tall/column effects (Bone_Swirl_Rise) are 64px.

---

## 1. Body sheets → CharacterData `sprite.anims`

Home: `data/characters.gd` → the character's `"sprite"` block. Sliced by
`data/factories/character_sprite_factory.gd` `build()` / `all_anim_specs()` (generic — no code edit).

- Spec shape: `"<anim>": ["<Sheet>.png", <frame_count>, <fps>]`. Bare filename joins `sprite.dir`;
  a `res://`-prefixed path is used verbatim (specials in subfolders).
- Factory auto-detects rows from height: 4-row sheets emit `<anim>` + `<anim>_<facing>` (facings
  `down_right/down_left/up_right/up_left`); single-row (Die) emits just `<anim>`.
- 64px cells: put the size as a plain int in slot 3 → `["X.png", 8, 12.0, 64]`.
- 8-way facing for a body anim: slot-3 dict `{"ortho": "<OrthoSheet>.png"}` adds cardinal rows.
- Re-slice the same sheet under a second name (e.g. `attack_2`, `bone_cast`) at a different fps when
  a combo needs the runner's `play()` to restart it — same-anim `play()` won't restart mid-anim.
- Effect overlays: name a sibling `"<anim>_fx"` pointing at the `Only_Effect/` sheet ONLY if you
  want a separable glow layer (`player._setup_combo_fx`); villain base sheets already glow, so
  usually skip.

## 2. Cast poses → choreography phase `animation`

The special-ability caster body (`<Name>_Cast.png`, `Rise_Corpse.png`, `_ClericPray.png`) is the
`animation` of a `ChoreographyPhase`. Homes:
- Combo nodes: `data/factories/chain_factory.gd` — `build_kit()` case + `build_<kit>_light/heavy/channel`.
- Q/E skills: `data/factories/skill_factory.gd` — `build_kit_skills()` + `build_<kit>_*`.

Shared helpers (reuse, don't reinvent): `_ability`, `_aoe`, `_branch_buffered`, `_branch_held`,
`_damage_type`. `hit_frame` on the phase = the frame effects fire. To let the host branch on which
cast played (e.g. two summons off one sheet), give each a **distinct anim name** and branch on
`anim.begins_with(...)` host-side — see the Cleric's `pray_pain/heal/guardian` sharing one pray body.

## 3. Projectiles → ProjectileConfig.sprite_frames

Home: a `_<name>()` builder in `chain_factory.gd` returning a `SpawnProjectilesEffect` whose
`ProjectileConfig.sprite_frames` is a helper-built `SpriteFrames`. Mirror `_bone_missile` or
`_divine_fire_bolt`.

**Prefer the directionless `Spinning_*` loop.** Build a single looping `&"default"` anim from its
row, set `cfg.use_directional_anims = false` and `cfg.animation = "default"` so it animates in flight
(the manager rotates it toward travel). This avoids the trap below.

**Directional flight sheets (`_Orthogonal`+`_Diagonal`) — verify frame 0 first.** The ProjectileManager
(`scripts/systems/projectile_manager.gd` `_resolve_texture`) uses only frame 0 for directional
projectiles (it animates via `config.animation`, which is empty for directional), and these sheets
routinely put the **caster wind-up** in frame 0 → the projectile renders as a tiny caster (the exact
bug that shipped for the Necromancer). If you do use them, `_slice_dir_rows` with rows
`{n:0,e:1,s:2,w:3}` / `{ne:0,se:1,sw:2,nw:3}` and `use_directional_anims = true` — but only after
Reading the PNG and confirming frame 0 is a clean projectile. Frame helpers: `_grid8_frames`
(single-frame 3×3 grid), `_slice_dir_rows` (multi-frame dir rows), `_oneshot_row_frames` (impacts).

## 4. Impacts → ProjectileConfig.impact_sprite_frames / world one-shot

`<Name>_Impact.png` (single row) → `_oneshot_row_frames(path, fps)` → `cfg.impact_sprite_frames`
with `cfg.impact_animation = "impact"`. For a non-projectile ability, spawn it as a world one-shot
(see §5).

## 5. Standalone world VFX + ground layers → player `_spawn_*` hooks

The pieces most often orphaned. `Stand_Alone_*`, `<Name>_Rise`, orbiting loops (`<Name>.png`), and
`*_Ground.png` are **world-anchored** — they don't belong to the character SpriteFrames. Spawn them
from a host hook in `scripts/entities/player.gd` `choreo_fire_effects` (the `if cur_anim.begins_with(...)`
block, ~L1371), on the phase's anim name.

Patterns to mirror (all in `player.gd`):
- `_spawn_spikes_ground(radius)` — one-shot 32px sheet at the player, scaled to the hit radius.
- `_spawn_drain_wisp(at)` — one-shot at a world point.
- `_spawn_sunder_cracks()` — a lingering **ground decal** at `z_index = -1` (below bodies) that holds
  then fades. Use this shape for any `*_Ground.png` layer and for orbit loops that should sit under
  the character.

So the "rises from the ground" summon VFX = `Stand_Alone_<Name>_Ground` at `z_index < 0` +
`Stand_Alone_<Name>` above it, both spawned at the minion's spawn point. An orbiting-AoE loop =
`<Name>_Rise` one-shot then the looping `<Name>.png` centered on the caster for the ability's
duration, radius-matched to the AoE.

## 6. Minion bodies → new pet entity

A `<Minion>/` subfolder with its own Idle/Walk/Attack/Dmg/Die = a summoned companion. Create
`scripts/entities/<minion>.gd` modeled on `scripts/entities/skeletal_champion.gd` (or
`spirit_guardian.gd`). **Autonomous-pet standard (CLAUDE.md, non-negotiable):** own constant-speed
locomotion + catch-up, hunt prey within a player-centric leash, settle/roam with hysteresis — never
lerp-glued to the player. It slices its own sheets (`DIR_ROWS`, single-row Die) and reads the
player's live `damage` stat at strike time via `DamageCalculator`. Spawn it from a player `_spawn_*`
hook (like `_spawn_skeletal_champion`), one persistent at a time (resummon `banish()`es the old);
short-lived swarms set a `lifetime` + lower `damage_mult`. Wire the minion's **Dmg** sheet too (a
hurt flash/anim on hit) — it's a commonly-missed sheet.

## 7. Alt-forms → dash / transform

`Soul_Shape/` (Idle/Fly) or similar = an alternate player form. Simplest home: map the character's
`dodge` anim to the form's Fly sheet so the dash plays it, and add a `dash_style` branch in
`player._start_dash` (mirror `"teleport"`/`"deadly"`/`"planeshift"`) for the enter/exit bursts
(`Plane_Shift_Out` at departure, `Plane_Shift_In` at arrival) + the dash SFX case in `_dash_sound_id`.

---

## Per-kit registries to update (when adding/rebuilding a character)
Keyed by the `melee_kit` id — update each when the kit id changes:
- `data/mod_applicability.gd` `KIT_CAPABILITIES` — `["melee_hit"]` + `"projectile"` if it fires any.
- `data/class_mods.gd` — 4 `"kit": <id>` mods + add their ids to the ORDER list.
- `data/ability_upgrades.gd` — a block of `"kit": <id>` upgrades + an `ORDER_BY_KIT[<id>]` entry.
- `data/weapons.gd` — class weapons (`"class_lock": "<Char>"`, `"kit": <id>`, tiers green/blue/purple).
- `data/factories/gear_unique_factory.gd` — the purple weapon's `unique` (build + describe), assembled
  only from existing effect/modifier/status machinery.
- `data/factories/character_factory.gd` `build_passive_modifiers` — flat-stat passive, or `pass` if the
  passive is a host behavior hook (e.g. an `_on_kill_*` in player.gd).

## Verification recipe
1. `validate_script` each edited `.gd` (see SKILL.md note on the `class_name` false-fail).
2. `reload_project` (imports new PNGs, registers new `class_name`s).
3. `play_scene main` → `execute_game_script`:
   - `CharacterSpriteFactory.build("<Char>")` → assert every new anim name present.
   - `ChainFactory.build_kit(<id>, wd)` / `SkillFactory.build_kit_skills(...)` → assert phases.
   - For each projectile: assert `sprite_frames.get_frame_texture(anim,0)` comes from the intended
     sheet (`AtlasTexture.atlas.resource_path`) — catches the frame-0-caster trap.
   - Spawn projectiles/VFX and `get_game_screenshot` to eyeball them.
4. Walk the coverage table one last time — every PNG wired or skipped-with-reason.
