---
name: minifantasy-pack
description: Fully wire a Minifantasy character/enemy asset pack into the game — every sheet in the folder gets a home, nothing is left orphaned. Use when adding or rebuilding a playable character or enemy from a Minifantasy pack, wiring a kit/skills/summon/dash from pack art, or whenever Ben says the pack isn't being "fully utilized" / "use all the assets" / mentions unused sheets. Enforces the CLAUDE.md full-asset-utilization rule with a coverage checklist.
---

# Minifantasy Pack Wiring

Minifantasy packs ship a **complete kit** — body anims, projectiles, cast poses, world VFX,
ground-layer decals, impacts, summoned-minion bodies, alt-forms. The recurring failure (Ben has
flagged it repeatedly) is wiring the obvious pieces — body + one projectile — and silently
orphaning the rest: the orbiting-AoE loop, the "rises from the ground" VFX with its below-bodies
ground layer, the dematerialize bursts, the minion's hurt anim. Those orphaned sheets are the
difference between "a character" and "the character the artist drew."

The fix is **discipline, not cleverness**: enumerate *every* PNG in the pack, give each one a
concrete home in the engine, and skip nothing without a written reason. This skill is that
checklist plus the map of where each kind of sheet plugs in.

The packs are laid out consistently, so this generalizes across every character. Read
`references/wiring-map.md` for the full sheet-type → engine-home table with exact
file:function citations — that's the load-bearing reference; keep it open while wiring.

## The core discipline: a coverage table

Before writing any code, build a coverage table. This is the whole point of the skill — it makes
"fully utilize the pack" mechanical instead of something you keep half-doing.

1. **Enumerate** every `.png` under the pack folder (Glob `**/*.png`). Ignore `_GIFs/` previews.
2. **Classify** each sheet by the taxonomy in `references/wiring-map.md` (body / cast pose /
   projectile / spin-loop / standalone world VFX / ground layer / impact / minion body / alt-form /
   shadow / effect-overlay).
3. **Assign a home** to each: a concrete destination (a `sprite.anims` key, a `ProjectileConfig`,
   a `_spawn_*` world-VFX hook, a minion entity, a dash branch) — or an explicit **skip-with-reason**
   (see the skip list below). Every row ends `→ <home>` or `→ SKIP: <reason>`. No blank rows.
4. Only then wire it. When done, re-walk the table: **every PNG is wired or skipped-with-reason.**

Present the coverage table to Ben as part of the work — it's the proof the pack is fully used, and
it's exactly the accounting he asks for.

### Legitimately skippable (state the reason, don't just omit)
- `_Shadows/` / `*_Shadow.png` — the engine draws its own shadows; pack shadows go unused.
- `_GIFs/` — preview GIFs, never imported.
- `AnimationInfo.txt`, `CommercialLicense.txt`, `Acknowledgment.txt` — docs, not art.
- `Jump.png` — this game has no jump.
- `No_Effect/` (clean-body) — only needed if you want to recolor/replace the baked glow; the base
  sheet already includes the effect. `Only_Effect/` (glow-only overlay) — wire only if you want a
  separable `<anim>_fx` overlay layer; otherwise the baked-in glow on the base sheet is enough.

Everything else — cast poses, every projectile sheet, standalone VFX, ground layers, impacts,
minion bodies, alt-forms — is content the player will see and should get a home.

## Procedure

1. **Locate & confirm the pack.** Note the assets root (True Heroes = `Minifantasy_..._Assets`;
   True Villains = `_Minifantasy_..._Assets`, leading underscore). Villain sheets are **bare
   filenames** (`Attack.png`), Heroes prefix the class (`WizardAttack.png`). Copy every path
   exactly — special subfolders vary between single (`_Shadows/`) and double (`__Shadows/`)
   underscores within the same pack.
2. **Build the coverage table** (above).
3. **Wire, home-type by home-type**, following `references/wiring-map.md`. Reuse existing factories
   and host hooks — a new character is almost pure data plus a few kit/skill/host functions; never
   invent a new rendering path when a `_spawn_*`/`ProjectileConfig`/pet-entity pattern already fits.
4. **Verify** (see below). Then present the coverage table + a screenshot.

## Wiring homes (summary — full detail in references/wiring-map.md)

| Sheet kind | Engine home |
|---|---|
| Idle/Walk/Attack/Dmg/Die body | `CharacterData.sprite.anims` → `CharacterSpriteFactory.build()` |
| Cast pose (special body) | choreography phase `animation` in `ChainFactory`/`SkillFactory` |
| Projectile (prefer a `Spinning_*`/directionless loop) | `ProjectileConfig.sprite_frames` in `ChainFactory` |
| Impact | `ProjectileConfig.impact_sprite_frames` (`_oneshot_row_frames`) or world one-shot |
| Standalone world VFX (`Stand_Alone_*`, orbit loops) | player `_spawn_*` hook on `anim.begins_with(...)` |
| Ground layer (`*_Ground.png`) | same hook, separate sprite at `z_index` below bodies |
| Minion body (`<Minion>/`) | new `scripts/entities/<minion>.gd` (autonomous-pet standard) |
| Alt-form (`Soul_Shape/` etc.) | dash `dash_style` branch / `dodge` anim mapping |

## Gotchas that bite every time
- **Directional projectile flight sheets often bake the caster into frame 0**, and the
  ProjectileManager freezes directional projectiles on frame 0 (it only animates when
  `config.animation` is set, which it isn't for directional). Result: the "projectile" renders as a
  tiny caster. **Prefer the pack's `Spinning_*`/directionless loop** as an animated non-directional
  projectile. Always eyeball the sheet (Read the PNG) before choosing.
- **Verify world-VFX cell size** (32 vs 64) from AnimationInfo.txt or an in-game render. Slicing a
  32px-2-row sheet at 64px draws a 2×2 block of four sub-frames per cell — one emerge looks like ~4
  subjects, ×N reads as a battalion (shipped for the Necromancer). See wiring-map.md.
- Type array element access — never `:=` on untyped array/dict access (crashes type inference).
- The Godot editor holds a **stale `CharacterData`** across cross-class references after a
  `characters.gd` edit (unchanged factories keep the pre-edit binding). Verify builds in the
  **running game** via `execute_game_script`, not editor-context `execute_editor_script`.

## Verification
- `mcp__godot-mcp-pro__validate_script` on each edited `.gd`. Note: `validate_script` false-fails
  any file with an already-registered `class_name` ("hides a global script class") — confirm by
  validating an untouched `class_name` file; a clean compile of a dependent script proves the deps.
- `reload_project` to import new PNGs + register new `class_name`s.
- `play_scene` → `execute_game_script`: build the character's SpriteFrames / kit / projectile /
  minion frames and assert the new anims exist and projectile frame-0 comes from the right sheet;
  spawn the projectiles/VFX and `get_game_screenshot` to confirm they render as intended.
