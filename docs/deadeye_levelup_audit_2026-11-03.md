# Deadeye level-up audit (2026-11-03)

Quest step `deadeye-picks.1`. A point-in-time record: it maps the Deadeye's real phase graph and host
code against its 8 class mods + 2 evolutions, so `deadeye-picks.2` (propose five picks) starts from
what is actually free. Read against source on 2026-11-03: `data/factories/chain_factory.gd`,
`data/factories/skill_factory.gd`, `scripts/entities/player.gd`, `data/class_mods.gd`,
`data/ability_upgrades.gd`, `data/factories/gear_unique_factory.gd`, `data/passive_tree.gd`.

## 1. The kit as the code builds it

| Graph | Phase (`anim`) | Effects on the phase | Host side |
|---|---|---|---|
| light (LMB) | 0 `attack` — Shot | 1 bullet, `aimed_single`, dmg×0.85 | — |
| light | 1 `attack_2` — Shot II | 1 bullet, `aimed_single`, dmg×0.85 | — |
| light | 2 `fan` — finisher | 5 bullets, `spread` 26°, dmg×0.60, pierce 1 | — |
| heavy (RMB tap) | `fan` | same builder as light phase 2 | — |
| channel (RMB hold) | `storm` | 5 bullets, `spread` 22°, dmg×0.82, pierce 2, `wait` 0.7s loop | `_show_storm_fx()`: the 8 directional DS barrage strips, 52px ahead. **Draws only, no damage path.** |
| skill_q (9s) | `reload` (37f, hit f30) | `loaded_chambers`: +40% All damage for 8s | — |
| skill_e (6s) | `whip` | AreaDamage r36, dmg×1.0, **the only AoE in the kit** | `whip_fx` overlay |
| passive | — | — | Calm Hands: +25% All above 80% HP (`_update_calm_hands`) |
| dash | — | no `dash_style`, no `dodge` anim | — |

Facts that matter for authoring:

- **`anim: "fan"` matches two phases**: the light finisher and the heavy tap. `graph: "light"`
  matches the light fan too.
- **Zero Deadeye host seams in `player.BASE_STATS`.** Every other passed kit has three or more.
- **Desert Storm's tick is its `wait_duration`.** An `extend_window` aimed at `storm` would make the
  storm fire *slower*, not make it easier to confirm. Don't use that op on this phase.
- Every bullet goes through `_bullet_config`. There's no `impact_aoe` and no bounce, so an AoE-radius
  op has nothing to reach. Pierce is the only per-bullet dial, and no op exposes it.

## 2. The current six picks, each against the mods

| Pick | What it does | Verdict |
|---|---|---|
| HAIR TRIGGER | `add_projectiles` fan +2 | **Duplicate.** Same op, target and count as the rare mod FAN THE HAMMER +2, and the LEADSTORM evo adds +2 more on top. Cut. |
| STORM SURGE | `scale_aoe` storm dmg×1.35 | **Duplicate.** It reaches the bullets' DealDamage, so it works, but it's the uncommon mod SUPPRESSING STORM (×1.3) again, and stronger once ranked to 3. Cut. |
| COLD STEEL | +8% crit chance | **Duplicate and a stat stick.** It's the QUICKDRAW mod (+10%) and passive node `f_deadeye` (+2%/rank) again. It does work: `_upgrade_modifier_key` maps the pair correctly. Cut. |
| WHIPCRACK | `scale_aoe` whip r×1.3 d×1.3 | **Duplicate, and the mod is better.** LASH AND DRAW is r×1.4 d×1.3. Cut. |
| DOUBLE TAP | `add_projectiles` attack_2 +1 | **Survives.** No mod touches the light shots' count. Extra shots fan at `AIMED_EXTRA_FAN` 6°. It's small and only covers one of the two pulls, so it can stay or be replaced. |
| HOLLOW POINTS | bleed on `fan` | **Same id and name as the epic mod HOLLOW POINTS**: the Spark/TEMPEST CALL bug, with two "Hollow Points" in one run. With the mod equipped, the light fan gets bleed twice (it collapses to one), so the pick only adds the heavy-tap fan. Cut. |

Result: **five of six duplicate a class mod, one of them by literal id.** Only Double Tap says
something the mod layer doesn't. Like the Demon, this needs a full replacement, not a top-up.

## 3. Ground the mod layer already owns (stay off it)

- Fan bullet count: FAN THE HAMMER +2, plus LEADSTORM +2.
- Storm bullet count: HOT LOADS +2.
- Storm damage: SUPPRESSING STORM ×1.3.
- On-hit statuses on the light graph: bleed (HOLLOW POINTS), burning (INCENDIARY ROUNDS), searing
  wound (HELLFIRE IRON).
- Whip size and damage: LASH AND DRAW.
- Crit chance (QUICKDRAW) and crit multiplier (DEAD AIM).
- Kill → attack speed: the gear unique Deadman's Hand (`u_fanfire`).

## 4. Unowned design space: candidate seams for step .2

Ranked by how much each one is "the thing the player watches", per the pass's recurring lesson.
These are seams, not picks; choosing five is step .2.

1. **Desert Storm barrage strip (host VFX → mechanic).** The pack's directional impact strips play
   ahead of the Deadeye every storm beat and deal nothing. It's the same bug as the Spark's ice aura
   and the Demon's fissure, and the obvious seam. Make the strip a place-anchored blast: query the
   grid yourself, because EffectDispatcher AoEs anchor on an entity (`reference_aoe_needs_entity_target`).
   It needs flat 0.0-based stats: strip damage, then strip length/width or a second strip.
   Count scales spectacle. This is the natural home for the capstone chain.
2. **Pierce / ricochet (vocabulary gap).** `ProjectileConfig` has `pierce_count` and on-bounce fields,
   but no op reaches them. A bullet that skips to a second body is spectacle the mods can't buy.
   It needs a new op (`add_pierce`), or a host ricochet seam if bounce isn't supported for
   directional bullets. Check that before promising it.
3. **Reload (Q) as a payload, not just a buff.** The 37-frame ritual only sets a +40% timer. Seams:
   "loaded rounds" (the next N shots after a reload are empowered: count-based, readable on the HUD)
   or the reload finishing with a free fan. Host-side, keyed on the `loaded_chambers` status, not on
   the `reload` anim name (the `cur_anim.begins_with` trap).
4. **Whip (E): the kit's only AoE, and only scaled.** `add_shockwave` / `add_ground_zone` / `echo_aoe`
   / `add_pull` all work here and no mod uses them. `add_pull` fits LASH AND DRAW's name, which the
   mod itself never delivered: drag a pack into the storm cone. Pulls are i-frame-gated displacement
   toward the player. Player knockback is cut (`project_knockback_removed`), but a pull is a
   different verb. Confirm it with Ben anyway.
5. **Crit events, not crit stats.** The mods own crit chance and crit multiplier. Nothing reacts
   *when* a crit lands. The gear layer has `_on_crit_aoe` for another class's unique, so the
   mechanism exists. A "dead-eye" crit that ricochets or detonates is identity, not a number.
6. **Calm Hands extension.** It's a host threshold already, and something else could ride the
   same >80% HP gate. Lower priority: it rewards not getting hit, which no pick can make visible.

Out of scope for picks, flagged for Ben: the Deadeye has **no class dash**, and `General_Animations/Jump.png`
is the pack's only unwired sheet. That's a "pack tool" gap (`feedback_full_asset_utilization`), not
level-up work.

## 5. Checks for whoever builds it (step .3/.4)

- `ORDER_BY_KIT["gunslinger"]` is the reachability list. Cut ids must leave it and ALL together, or
  `validate_kit_order` flags them.
- Pick ids must not reuse a class-mod id (`gunslinger_hollow_points`).
- New host stats are flat 0.0-based entries in `player.BASE_STATS`. Mark them DERIVED in the balance
  registry if anything overwrites them.
- Measure in the Training Room only, with HIT BACK off. The `Fodder` dummy never dies, and the
  editor serves a stale `AbilityUpgradeData` after an edit.

## 6. Step .2 decision (2026-11-19, Ben approved)

Final roster: **DOUBLE TAP** (kept) + the five below. HAIR TRIGGER, STORM SURGE, COLD STEEL, WHIPCRACK
and HOLLOW POINTS (pick) are cut — remove them from `ALL` and `ORDER_BY_KIT` together.

| Pick | Ranks | What it does | Seam |
|---|---|---|---|
| DUST DEVIL | 3 | The Desert Storm barrage strip deals damage every storm beat, at the spot it's drawn | New host stat `storm_strip_damage` (flat 0.0). Place-anchored grid query over the strip's rect in `_show_storm_fx`'s position. Not an EffectDispatcher AoE |
| TWIN DEVILS | 2, requires Dust Devil | +1 strip per rank, fanned about ±25° off aim | New host stat `storm_strip_count`. Each extra strip is its own sprite and its own hit query |
| HABOOB | capstone, requires Twin Devils | Releasing a storm channel fires all 8 directional strips at once in a ring | Host hook on the storm channel's release. Uses every `STORM_FX_FILES` sheet at once |
| BANK SHOT | 2 | Light-chain bullets bounce off a wall once (+1 per rank) and lock on to the nearest enemy after | New op `add_bounce`: sets `bounce_count` + `re_home_after_bounce` on the phase's ProjectileConfig. Add it to `MAX_RANK_BY_OP` and the shared applier. Find where the Training Room's walls are before measuring |
| SPEED LOADER | 3 | Finishing Reload (Q) loads 6 rounds. Each of the next 6 shots fires +1 bullet and pierces one more enemy. The HUD counts the rounds down | Host counter, triggered by the `loaded_chambers` status being applied, NOT by the `reload` anim name. New host stat for the per-round bonus |

Parked, not approved: LASSO (Whip `add_pull`, needs a knockback-adjacent call from Ben) and CRACK SHOT
(crit → a bullet bounces to another enemy). Both are candidates if the Deadeye should reach ~11 entries
like the other kits.
