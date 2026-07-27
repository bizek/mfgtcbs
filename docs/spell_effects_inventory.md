# Spell Effects Packs — Inventory & Coverage

Coverage record for the two Minifantasy spell-effect packs, in the style the `/minifantasy-pack`
skill enforces: every sheet gets a home or an explicit reason it has none.

- `assets/minifantasy/Minifantasy_Spell Effects_v1.0` — "Pack I", 4 elements × 3 asset classes
- `assets/minifantasy/Minifantasy_Spell_Effects_II_v1.0` — "Pack II", 3 magic schools

**Authoring facts that apply to every sheet in both packs:**
- Frame duration is **100ms → 10 fps native**. The codebase generally runs them at 10–16 fps;
  anything faster is a deliberate snap, not an error.
- Aura sheets are **row 0 intro / row 1 loop / row 2 outro** — the same phased model as
  `VfxLayerConfig` and `GroundZoneVfx`. Pack II's Arcane/Shadow *tileables* ship a single loop
  row instead, so their intro/outro fall back to the loop art plus a fade.
- Tileable sheets are **8×8**; premade AoEs are assembled from them and are frequently
  **non-square** (`Fire_Wave_E` 80×40, `Ice_Lance_N` 24×64, shockwaves 8×80). Loading those
  requires `player._spawn_pack_fx(..., cell_h)` — the square-only version could not open them.
- `.import` files are present for every sheet, so everything is load-ready.

---

## Pack I — Minifantasy_Spell Effects_v1.0

Four elements: **Fire · Ice · Electric · Poison**. Each ships an Aura, a Burst, a Tileable and a
set of premade AoEs built from that tileable.

| Sheet (per element) | Layout | Status | Home |
|---|---|---|---|
| `Aura_Fire` | 32px, 8f × 3 rows | **WIRED** | `StatusVfxFactory` → burning |
| `Aura_Ice` | 32px, 8f × 3 rows | **WIRED** | `StatusVfxFactory` → chilled/frozen; `player._show_ice_aura` (Spark Frost Burst) |
| `Aura_Electric` | 32px, 8f × 3 rows | **WIRED** | `StatusVfxFactory` → shocked; `player._cast_storm_call` per-enemy strike |
| `Aura_Poison` | 32px, 8f × 3 rows | **WIRED** | `StatusVfxFactory` → bleed (tinted crimson) |
| `Burst_Fire` | 32px, 15f | **WIRED** | Spark Fire Burst finisher (`characters.gd` `fireburst_fx`) |
| `Burst_Ice` | 32px, 15f | **WIRED** | Spark Frost Burst pop; frost-projectile impact (`WeaponFactory`) |
| `Burst_Electric` | 32px, 15f | **WIRED** | Storm Call caster pulse |
| `Burst_Poison` | 32px, 15f | free | — |
| `Tileable_Fire` | 8px, 8f × 3 rows | **WIRED** | `GroundZoneVfx` element `"fire"` |
| `Tileable_Ice` | 8px, 8f × 3 rows × **3 variants** | **WIRED** | `GroundZoneVfx` `"ice"` (variant 1); `WeaponFactory` frost projectile (all 3 variants) |
| `Tileable_Electric` | 8px, 8f × 3 rows | **WIRED** | `GroundZoneVfx` `"electric"` |
| `Tileable_Poison` | 8px, 8f × 3 rows | **WIRED** | `GroundZoneVfx` `"poison"` |

### Premade AoEs

| Sheet | Size / frames | Status | Home or intended use |
|---|---|---|---|
| `Electric_Expansive_Shock` | 56×56, 26f | **WIRED** | `player._spawn_shockwave_ring` — every shockwave in the game |
| `Poison_Magic_Trap` | 40×40, 47f | **WIRED** | `Telegraph2D` circle/ring wind-up art |
| `Fire_Burning_Hell` | 200×200, 16f | free | Archdemon's Call ultimate — biggest sheet in either pack |
| `Fire_Wildfire` | 72×72, 48f | free | alternate Brimstone Circle footprint |
| `Fire_Deflagration` | 64×64, 26f | free | Hellfire finisher pop |
| `Fire_Wave_N/S/E/W` | 40×80 / 80×40 | free | directional hellfire cone (needs `cell_h`) |
| `Ice_Frostbite` | 88×88, 20f | free | heavier Frost Burst |
| `Ice_Lance_N/S/E/W` | 24×64 / 64×24 | free | directional Spark cold attack (needs `cell_h`) |
| `Ice_Wall_H/V` | 56×8 / 8×56 | free | ward wall (needs `cell_h`) |
| `Ice_X` | 40×40, 28f | free | AoE marker |
| `Electric_Lightning_Cross` | 152×152, 26f | free | Storm Call per-enemy strike (currently `Aura_Electric`) |
| `Electric_Shockwave_N/S/E/W` | 8×80 / 80×8 | free | directional shock (needs `cell_h`) |
| `Electric_Simple_AOE` | 40×40, 24f | free | AoE marker |
| `Poison_Concentric_Sink` | 120×120, 48f | free | Blood Eruption pool (recolour crimson) |
| `Poison_Spiral` | 112×120, 86f | free | longest animation in either pack |
| `Poison_Growing_Cloud` | 56×56, 48f | free | Druid Thornburst nova |

---

## Pack II — Minifantasy_Spell_Effects_II_v1.0

### Arcane school

| Sheet | Layout | Status | Home or intended use |
|---|---|---|---|
| `Orb_Only_Orb` | 32px, 16f × 3 rows | **WIRED** | `OrbitOrb` (Lightning Orb mod) |
| `Arcane_Tileable` | 8px, 12f, 1 row | **WIRED** | `GroundZoneVfx` `"arcane"` — Word of Pain, King's Court |
| `Arcane_Beam` + `_Cast` | 8px beam / 24px cast | free | Spark channelled beam (ships a `_Use_Guideline.png` diagram) |
| `Arcane_Missile` ortho/diag | 32px, 9f × 4 rows | free | Spark light-chain arcane bolt |
| `_Arcane_Missile_Projectile` | 96×96 (3×3) | free | 8-way projectile grid |
| `Arcane_Missile_Impact` | 32px, 11f | free | bolt impact |
| `Arcane_Burst` (+2 standalones) | 32px, 16f | free | self/targeted burst |
| `Arcane_Orb` / `(alternative)` / `Orb_Cast_Only` / `Orb_Only_Ray` | 32px, 16f × 3 rows | free | orb cast + ray variants |
| `Arcane_Pulse` (+4 standalones) | 32px, 14f × 4 rows | free | cast / loop / end / big-explosion |

### Shadow school

| Sheet | Layout | Status | Home or intended use |
|---|---|---|---|
| `Sting` | 32px, 16f × **4 rows** | **PARTIAL** | Ember Beam body — `player_vfx_helper.gd` uses **row 0 only**, rotated; rows 1–3 unused |
| `_Missile_Projectile` | 96×96 (3×3) | **WIRED** | Ember Beam muzzle flash |
| `Missile_Impact` | 16px, 8f | **WIRED** | Ember Beam impact |
| `Aura_1` | 32px, 32f × 3 rows | **WIRED** | `StatusVfxFactory` → void_touched, abyssal_slow |
| `Double_Tileable_Effect` | 8px, 23f, 1 row | **WIRED** | `GroundZoneVfx` `"shadow"` — all Void enemy/boss zones |
| `Aura_2/3/4` | 32px, 32f × 3 rows | free | 2–4 orbiting orbs — matches the Shade's Bone Swirl ring-count mechanic |
| `Aura_To_Missile` ortho/diag, `Aura_To_Sting` | 32px, 4 rows | free | **orbit→projectile transition frames the bone sheet lacks** |
| `Aura_Impact` | 8×16 | free | orb collision pop |
| `_Missile` ortho/diag | 32px, 10f × 4 rows | free | void bolt cast |
| `Tendrils` Appear/Idle/Attack | 32px wide | free | Shade second summon, or a Void zone |
| `Double_Sting` | 32px, 19f | free | twin short-range strike |
| `Left/Right_Tileable_Effect` | 8px | free | directional shadow tiles |

### Cartomancy school

Unused wholesale — no current kit is a cartomancer. Recorded here because it is a **complete
character in a box**: six Fate cards whose mechanics the pack itself specifies (Death = DOT,
Emperor = tileable wall, Hermit = blink, Sun = blind, Sword = direct damage, Wheel = random
buff/debuff — which maps onto the instability system), plus `Draw`, an orbiting-card aura
(`Aura_1..4` + `Aura_Impact`) and three tileables.

Two sheets are worth stealing for existing characters even without that character:
`Sun_Effect` (32px, 3-row start/loop/end golden radiance) for the Devout's Sanctuary, and
`Emperor_Effect` (8×16, appear/disappear) as a ward wall.

### Mix'n'match premades

| Sheet | Frames | Status | Intended use |
|---|---|---|---|
| `Blade_Storm` | 56×56, 39f | free | Whisper's Thousand Blades |
| `Arcane_Cross` | 56×56, 29f | free | AoE marker |
| `Tangled_Shadows` | 56×56, 30f | free | Shade AoE |

---

## Coverage summary

Roughly **111 sprite sheets** across both packs. **21 are wired** (10 before this pass), and the
newly-wired ones are load-bearing rather than decorative — they are what makes ground zones,
four more status effects, every shockwave, telegraphs and the orbit orb visible at all.

The largest remaining blocks are the Arcane school (a near-complete replacement kit for the
Spark, which currently works around a fire-mage asset pack) and Cartomancy (a whole unbuilt
character). Both are recorded above rather than left as loose files.

## Gotchas

- **`z_index` and the arena floor.** `scenes/main_arena.tscn`'s `ArenaFloor` TextureRect used to
  sit at `z_index 0` — the same layer as bodies — so every ground decal drawn at the codebase's
  conventional `z = -1` was painted *underneath the floor and never seen*. This silently affected
  the pre-existing Brimstone sigil and corpse-ground decals too. `ArenaFloor` is now `z_index -5`;
  it is a backdrop and nothing should ever render beneath it. Keep decals at `-1`.
- **`_spawn_pack_fx` assumes square cells** unless you pass `cell_h`. Every "needs `cell_h`" row
  above is a sheet that will silently slice wrong without it.
- **Pack II frame counts differ from Pack I.** Shadow auras are 32 frames per row where Pack I is
  8; `StatusVfxFactory.ELEMENTS` carries a per-element `frames` count for this reason.
- **`validate_script` cannot validate any script with a `class_name`** — it compiles into a temp
  script and reports "hides a global script class". Verify in the Training Room instead.
