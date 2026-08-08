# Polish Plan — 2026-08-01

> **Status 2026-08-02: Tier 0 and Tier 1 are DONE**, plus a body of extraction work that grew out
> of Ben's playtest the same day and is NOT part of this plan. In commit order:
>
> | Commit | What |
> |---|---|
> | `dc37254` | Tier 0 + Tier 1 of this plan |
> | `d84830a` | Results screen — full after-action report; `RunReportManager` now always on |
> | `1a8ad69` | `GatewayExtraction` — descent's first-ever early exit |
> | `afecb67` | Three-rung convex payout curve + the miniboss rung |
> | `b64ec9b` | Silenced the bogus "no Region entities" warning on descent blocks |
>
> **The headline finding of the day is not in this document**: descent mode, the default run
> path, had **no early exit at all**. See `docs/engine_reference.md` → Extraction System.
>
> Corrections to this plan's own claims, found while doing the work:
>
> * Tier 0.1 was **7 dead entries, not 6** — the first sweep only checked `ability_upgrades.gd`,
>   so it missed `owl_attack` in `class_mods.gd` (`druid_diving_owl`). A startup validator now
>   makes that class of miss impossible.
> * Tier 0.2 was **6 of 12 characters, not 6 of 13** — the 13th file, `the_herald.png`, is an
>   orphan left by the Herald→Demon rename and is referenced by nothing. Left on disk; deleting
>   it is Ben's call.
> * Tier 1.2 shipped its **machinery but not its audio**: the three loop .ogg files do not exist
>   and REAPER was not running to render them. See §"What is left" at the bottom.
> * Found while wiring: the `Logger` autoload is **unreachable by its own name** in Godot 4.6.
>   Details at the bottom.


Written overnight from Ben's "come up with a plan to further continue polishing". Everything in
Tier 0 is a **confirmed defect found while writing this**, not a guess — each line has the grep that
proves it. Tiers rise in cost and fall in certainty.

Nothing here has been changed yet. The whole point is that you can wake up and say "do Tier 0" (or
any single item) without another round of investigation.

---

## Tier 0 — Confirmed dead content and visible gaps (cheap, no design decisions)

### 0.1 Three ability upgrades and three class mods are silently doing nothing

The `mod_levelup_rework_plan.md` §2.3 prediction was right, and the rot is already here. I ran the
cross-check it recommended: every `target.anim` in `ability_upgrades.gd` / `class_mods.gd` against
every `phase.animation` defined in `data/factories/*.gd`.

Three targets match nothing:

| Target anim | Dead entries | Why |
|---|---|---|
| `beast_attack` | `ability_upgrades.gd:160` (Wild Maul), `class_mods.gd:226` | Verdant shapeshifting removed in `0f5dfed` |
| `hound_attack` | `ability_upgrades.gd:180` (Pack Frenzy), `class_mods.gd:256` | same commit |
| `hellfire` | `ability_upgrades.gd:336` (Conflagration), `class_mods.gd:455` | Demon's heavy plays `hellfire_2`, not `hellfire` (`chain_factory.gd:1069`) |

`ClassModFactory._apply_dicts_to_abilities` scans phases for the anim and applies nothing when it
doesn't match — no warning, no error. A player taking **Conflagration** gets a level-up choice that
reads "+35% damage, +20% radius" and does literally nothing.

`hellfire` is a one-character fix (`hellfire` → `hellfire_2`). The two Verdant ones can't be
retargeted, because the abilities they describe no longer exist — "Beast Maul" and "Hound Frenzy"
were shapeshift moves. They need rewriting against the new bear/hound summon kit, which means the
Verdant is running on 1 real ability upgrade out of 3.

**Do:** fix `hellfire`, rewrite the two Verdant upgrades + two Verdant class mods against the summon
kit, then add the startup validator so this can never rot silently again. The validator is ~20 lines
and belongs in `ClassModFactory` — assert each `target.anim` resolves in its kit and push a
`Logger.warn` per orphan.

### 0.2 Six of thirteen character portraits don't exist on disk

Every `res://assets/...png` referenced in `data/` and `scripts/` was checked against the filesystem.
128 paths, 6 missing — all portraits:

```
assets/characters/portraits/the_deadeye.png
assets/characters/portraits/the_demon.png
assets/characters/portraits/the_devout.png
assets/characters/portraits/the_ravager.png
assets/characters/portraits/the_verdant.png
assets/characters/portraits/the_whisper.png
```

`hub_roster_panel.gd:186` guards with `ResourceLoader.exists`, so nothing crashes — the roster just
renders 7 rows with a portrait and 6 without, and the detail header does the same. It's the most
visible unfinished edge in the hub, and it's the first screen a new player sees.

Note `the_herald.png` still exists but is orphaned — the Herald became the Demon.

**Needs you:** portraits are art. Either point me at a crop source per character (the packs' idle
frames upscaled would match the 7 that exist, if that's how they were made) or say "generate them
from the idle sheets" and I'll do it consistently across all 13 including replacing the Herald.

---

## Tier 1 — Feel polish with the highest visible return

### 1.1 The cursor (UI pack gap 2)

This game is **manual cursor-aim** — the reticle is the single most-looked-at object on screen, for
the entire run — and it's still the OS default arrow. `docs/ui_pack_inventory.md` §Gap 2 already
identifies the pack's cursor sheet and where it goes. Highest feel-per-hour item on this list by a
wide margin, and it needs no design decision.

Extras that fall out for nearly free once a custom cursor exists: a distinct reticle while a heavy
is charging, and a subtle state change when an enemy is under the cursor.

### 1.2 Held channels have no looping sound

`AudioManager.play_loop` has exactly **zero callers outside the extraction hum**. Every held channel
in the game — Immolate, Dictum, Dome, the Verdant's barrage, every channel graph — runs silent for
its whole duration and then a hit lands. This is the concrete remainder of task 15, and the
machinery (`_loop_player`, `stop_loop`, run-start safety net) is already built and proven by
extraction. It's wiring, not architecture.

### 1.3 Status apply sounds cover 5 of ~46 statuses

`SoundTable.STATUS_SOUND` maps `burning`, `chilled`, `frozen`, `shocked`, `void_touched`. The game
applies ~46 distinct status ids. "Unmapped statuses are silent by design" is a fair default — but
`bleed`, `rooted`, `aegis_shield`, `frenzy`, `second_wind` and the elite affixes are all moments the
player should hear. No new assets needed for most of them; the existing 68 files can be re-pitched.

### 1.4 Kill the dead `sfx_swing_light`

Defined in the sound table, referenced nowhere — light-chain swings ride the `sfx_combo_step` pitch
ladder now. One-line delete. (Every other "unreferenced" id I flagged turned out to be reached
through `HIT_SOUND_BY_DAMAGE_TYPE` / `STATUS_SOUND` / `PICKUP_SOUND` — those are fine.)

---

## Tier 2 — Structural, needs a decision from you

### 2.1 The level-up pool runs out of class identity at level 4

Verified: **3 ability upgrades per kit** (necromancer 4), 12 kits, 37 total. `generate_choices`
reserves one slot per level-up for a class upgrade, so by level 4 a run has taken everything its
class has to say and every level-up afterward is a stat stick from a pool that is 16 stat sticks out
of 22.

This is the single biggest structural problem in the game's power progression, it is the thing
`mod_levelup_rework_plan.md` §3 recommends, and it is **purely additive content** — expanding to
~8 per kit with ranks touches no system, breaks no save, and each class is testable alone in the
Training Room. It is by far the highest gameplay-depth return available right now.

**Needs you:** this is gated on the roster freezing, and three kits changed yesterday. If the roster
is now stable, say so and this becomes the biggest and best next chunk of work. If more kit churn is
coming, it stays gated and Tier 0's validator is what protects it in the meantime.

### 2.2 A real `Theme` resource (UI pack gap 3)

21 scripts hand-style their controls. A Grim-sheet `Theme` would make the hub coherent and would
delete a lot of per-panel styling code. Medium cost, high consistency payoff, no design decision —
but it touches every panel, so it wants to be its own session, not a corner of another one.

---

## Tier 3 — The wall everything else eventually hits

### 3.1 Biome 2 (The Catacombs)

`level_data.gd` levels 2–5 are name + music id and nothing else: empty `wave_composition`, empty
`scene_map`, and no floor path for three of them. `mus_catacombs`, `mus_nightmare_realm`,
`mus_threshold`, `mus_inferno` are all referenced by the sound table and **none of the four .ogg
files exist on disk**.

`level_selection_plan.md` already reached this conclusion from the other direction: level selection
isn't a UI task, it's a content wall. One real second biome unblocks level selection, run variety,
and most of what "replayability polish" would mean. It is also, by an order of magnitude, the
largest item on this page — it's a project, not a polish pass.

Not recommended as the next thing. Recommended as the thing you decide about after Tier 0 and 1.

---

## Suggested order

1. **Tier 0.1** — dead upgrades + the validator. Small, and it stops the bleeding on every future kit edit.
2. **Tier 1.1** — the cursor. Best feel-per-hour on the list.
3. **Tier 1.2 + 1.3 + 1.4** — the audio remainder, in one pass.
4. **Tier 0.2** — portraits, as soon as you tell me where the art comes from.
5. Then decide between **2.1** (depth), **2.2** (coherence), and **3.1** (content).

Items 1–3 need nothing from you and I can start on any of them the moment you say go.

---

## Open threads, newest first (2026-08-02)

**Tier 2.1 — level-up depth. DONE 2026-08-07.** The kit pool went from 3 unique entries to 6
(necromancer 7), and entries became rankable, so a run now has **14–19 class picks** instead of 3.
The ability slot no longer runs dry — simulated 15 consecutive level-ups on the Demonologist and
every one still offered a class-flavoured choice.

- **Ranks needed almost no engine.** `apply_upgrade` already appended duplicates and
  `apply_upgrade_dicts_to_kit` already re-applied every stored dict to a pristine kit, so two
  copies of a `scale_aoe` multiplied twice for free. The only thing blocking repeats was the
  "already owned" filter in `generate_choices`. Verified mechanically rather than by inspection:
  Hell Breach at rank 3 measured 54.00 → 132.86 radius, ratio 2.460 = 1.35³ exactly.
- **The cap is keyed on the op, not the entry** (`MAX_RANK_BY_OP`). Whether an upgrade can repeat
  is a property of what the op does: `scale_aoe` / `add_projectiles` / `modifier` stack, while
  `add_status` / `add_projectile_status` must stay rank 1 — appending the same status twice
  collapses back to one, so rank 2 would be a pick that visibly does nothing.
- **The new content is biased at Q and E on purpose.** Of the original 37 entries exactly ONE
  (`ninja_smoke_ambush`) targeted a skill, so a kit's two most characterful buttons never grew
  during a run. Most kits now get at least one upgrade that improves a skill. Every target was
  chosen against a live dump of `ChainFactory.build_kit` + `SkillFactory.build_kit_skills`, not
  from memory.

**A live bug found while doing it: the Druid had ONE ability upgrade, not three.**
`ORDER_BY_KIT["druid"]` still listed `druid_wild_maul` and `druid_pack_frenzy` — the two ids the
Tier 0.1 rewrite renamed to `druid_seedstorm` and `druid_wild_barrage` on 2026-08-02. Neither
existed in `ALL`, and `get_upgrades_for_kit` skips misses silently, so two thirds of the Verdant's
class identity had been unreachable ever since.

The 0.1 validator could not catch this: it checks that a `target.anim` resolves to a phase, and an
entry that is never *reached* never produces a target to check. `AbilityUpgradeData.validate_kit_order()`
now closes that gap — it asserts every `ALL` entry is listed, every listed id exists, kits agree,
no duplicates, no rankable status op, and every `params.status` resolves in StatusFactory (which
`validate_status_ids` never covered, since it walks the generic pool and evolutions only). Wired
into `GameManager._validate_content` beside the other two.

**Tier 2.2 — the `Theme` resource. DONE 2026-08-07.** `assets/ui/grim_theme.tres`, generated by
`tools/build_ui_theme.gd` off the Grim sheet and wired project-wide. Full coverage table in
`docs/ui_pack_inventory.md` gap 3. Four things worth carrying forward:

- **This plan said "21 hand-styled scripts". It is 53.** `grep -c add_theme_*_override` over
  `scripts/`. The estimate in Tier 2.2 was low by more than half, which matters because those
  overrides win over the theme — so wiring the theme changed nothing on the screens that already
  styled themselves, exactly as it should. The palette was taken from the colour literals those
  scripts already use so the two layers agree.
- **The measurable win is on the screens nobody had styled.** The pause menu's buttons had no
  styling at all and now carry the pack's push-button plates; so do the level-up reroll, the
  results screens' return button, and every checkbox and slider grabber in settings.
- **Removing a blocking override is the actual work, and it is dangerous.** Five hub panel scenes
  each baked a copy of the old flat plate onto their `PanelBase` instance, so removing it from the
  base scene changed nothing. Editing them out is not an option: saving any of those five drops
  every node parented under `PanelBase/ContentContainer` — measured at 27 nodes / 278 lines from
  `hub_roster_panel.tscn`, reverted. They are stripped at runtime from `hub_panel_base.gd` instead.
  Recorded in CLAUDE.md's Godot Rules.

  **Re-tested 2026-08-07 after Ben pushed back on the first write-up, which was wrong about the
  cause.** The claim was that the MCP `save_scene` tool was at fault and that Godot's own save might
  be safe. Neither holds. The `.tscn` files are valid and complete, and `PackedScene.instantiate()`
  returns the full tree in all three edit states — so the runtime was never at risk and the scenes
  are not malformed. The truncation happens at **editor load**: the edited-scene tree contains 8 of
  32 nodes, reproduced on an untouched file and on a pristine copy, and a save merely writes what
  was loaded. Adding `[editable path="PanelBase"]` flips `is_editable_instance` to true but does not
  restore the nodes, so it is not the fix either. The rule is therefore broader than first written —
  never save these five from any path — and the reassurance that the files themselves were damaged
  was also wrong: they are fine.
- **`validate_script` false-failed on `hub_panel_base.gd`** with `Parse Error: Class "HubPanelBase"
  hides a global script class` — the known `class_name` limitation, not a real error. The check that
  works is a `CACHE_MODE_IGNORE` reload plus a method count; a plain `load()` serves the stale
  cached copy and will happily report a method list missing the function you just added.

**Death screen + tutorial — DONE 2026-08-03.** Ben: the death screen should have just as much
information as the win screen, including what killed the player.

Both screens now share `RunReportView` (`scripts/ui/run_report_view.gd`) so they cannot drift.
`RunReportManager` gained two things it never tracked: **damage taken bucketed by source**
(the mirror of damage-by-ability) and the **killing blow**. The only thing recorded before was
`_death_cause`, a bare `enemy_id` that went to a debug JSON no player ever sees.

The death screen leads with **KILLED BY**, then **WHAT HIT YOU** — because those answer different
questions and the difference matters. In the verification run the killing blow was the Bone Warden
while the Cave Stalker had done 51% of the damage; only the second number changes how you play the
next run.

Tutorial: the first-run cue said *"channel at the portal to extract"*, which describes the **flat
arena**. Descent is the default path and works nothing like that. It now branches, and a new cue
teaches the town portal — nothing anywhere told a player that key exists.

**Two bugs found on the way, both fixed:**

- `modify_instability()` never updated `peak_instability`; only `add_instability()` did. Every
  void-touched death raises instability through the first one, so the peak was under-reported on
  **both** results screens.
- The 25% death salvage was hardcoded separately in `game_over_screen.gd` and
  `progression_manager.gd`. Now noted as needing to match, so the screen cannot silently lie.

**Verification gap — CLOSED 2026-08-03, and it was a real bug, not a cache.** After an editor
restart the extraction success screen still failed to parse: two `ReportView.line()` calls in the
loot manifest were passing four arguments to a three-argument function, left over from the
migration. Both fixed; the screen now renders in full, including the exact weapon and mod lines
that were broken.

**The lesson is about how it was missed.** The migration was "verified" by grepping call sites for
a trailing *numeric literal* — but these two ended in `Color.WHITE), 17)`, where the offending arg
follows a nested call, so the pattern never matched. A `## grep audit` is not a compile. The signal
that would have caught it in one step is `mcp__godot-mcp-pro__validate_script`, which reports
"Parse error" with the file and line; `Script.can_instantiate()` is NOT a usable check — it returns
false for every non-tool script in the editor, including known-good ones. Use method count (0 means
it failed) or `validate_script`.

The stale-cache theory was wrong, and reporting it as "probably fine, restart to confirm" was
too generous to code that had never once compiled.

**The paid town portal — BUILT 2026-08-03.** The free gateway arrives on the phase clock and you
catch it or miss it; the purchased town portal is one you trigger whenever you like. That
distinction is the product, and it dodges the death-spiral of paid-escape economies since the free
window still exists for a broke player.

- **Bought from the merchant for 25 loot** — the dearest thing on the shelf, and bought with
  `loot_carried`, the haul you are trying to leave with. The price is the decision: give up a
  slice of the run to guarantee you keep the rest. Offered only in descent, and only when you
  hold none.
- **Spent with `[T]`** (new input action, D-pad Down on a pad). It opens the same gateway the
  free window opens — same dome, same dash, same touch-to-leave — out of band and **persistent**,
  because a portal you paid for should not evaporate on a timer you do not control.
- **Pays 1.0x**, same as the free escape. You are buying safety, not a bonus.
- **Survives `_advance_phase()`**, unlike the keystone it otherwise mirrors: a keystone is a
  per-phase key the run hands you, a portal is a thing you bought and keep until you spend it.
- **HUD pill under the keystone pill**, carrying its own key prompt.

Every refusal path is verified and none of them consume the portal: no anchor (non-descent),
boss seal, gateway already open, dead player. Guard order means the anchor check short-circuits
first, which is why the boss-seal branch needed a stubbed BlockManager to reach in testing.

**The final-boss seal stays** (Ben, 2026-08-03): `is_extraction_allowed()` is not overridden, so
the climax remains a commitment. The portal covers everything before it, which is where being
overwhelmed actually happens.

**Success path verified** in a controlled descent (Ben-authorised, 2026-08-03): god mode on,
`EnemySpawnManager.max_enemies = 0` to suppress spawns, ten blocks built. Pressing physical `[T]`
through the real input pipeline consumed the portal and opened a gateway 230px away — the
`GATEWAY_MAX_DASH` cap, exactly — with `extraction_window_active == false`, which is the feature's
whole claim: it ignores the phase clock. `is_persistent` true, `payout_type` "gateway". Walking in
settled 500 loot at **x1.00** and rendered the results screen. Save restored byte-identical after.

**Currency naming — DONE 2026-08-03. HAUL / VAULT** (Ben's pick).

`GameManager.loot_carried` is player-facing **HAUL** — carried, at risk, zeroed on death.
`ProgressionManager.resources` is player-facing **VAULT** — banked, safe. Those two are the entire
reason the extraction tension exists, and the UI had been calling them "LOOT" and
"RESOURCES"/"RES", plus "gold" in one achievement: four names for two things, and the two that
mattered read as synonyms.

Every player-facing string now uses one of the two — HUD counter and the AT RISK warning, merchant
(header, subtitle, and the `%d HAUL` price column), level-up weapon cache, pause-menu abandon
confirm, records, roster, research, workshop, first-run tutorial cue, one mod description, one
achievement. The results screen carries the most weight, because it is the only place a player
watches one become the other: it now reads **HAUL** at the top and **── BANKED TO VAULT** at the
bottom.

**The identifiers were deliberately NOT renamed** (Ben's call). `resources` is a save key, so
renaming it costs a migration and buys the player nothing. Anchor comments on both declarations
map each internal name to its player-facing one. "loot" survives as a verb and as the word for
stuff on the ground — you loot things, and what you carry out is your haul, so the menu subtitle
"descend. loot. extract." and the `loot_find` stat ("+15% Loot Find") are correct as they stand.

Two dead placeholders left alone: `hub_records_panel.tscn` and `hub_roster_panel.tscn` still carry
"Most Loot (run)" / "Resources: 0" as design-time label text, but both panels `queue_free()` every
child and rebuild from code, so neither string ever reaches a player. Not worth re-serialising two
more scenes into the in-progress font pass.

Verified on screen: HUD, merchant, research, workshop, results.

**Upgrade pool bias — DONE 2026-08-03.** Ben, on difficulty: *"before we remove mob numbers, lets
give player's methods of dealing with it."* Enemies spawn on a **340px ring** around the player and
walk inward, so what answers them is crowd-clear, reach and space-making — not `+20% damage`.

Every pool entry now carries a `role` (`crowd` / `space` / `survive` / `power`), and four new
universal upgrades were added, each worth more the more enemies are on you and near-worthless
against one target:

| Upgrade | Effect | Engine primitive |
|---|---|---|
| **Cinder Skin** | 5 Fire / 0.5s to everything inside 70px | `aura_radius` + `aura_tick_effects` (the path the Shade's bone swirl already used) |
| **Volatile Remains** | on kill, the corpse detonates for 22 Fire at 65px | `on_kill` listener, centred on the victim |
| **Glacial Guard** | when hit, chill everything within 100px | `on_hit_received` listener, 2.0s internal cooldown |
| **Last Stand** | while 5+ enemies target you: −20% damage taken, +20% move speed | `targeting_count_threshold` — **first use in the game** |

Plus two evolutions so the branch has a top end: **PYRE** (Cinder Skin + Volatile Remains) and
**BULWARK** (Glacial Guard + Last Stand).

The draw reserves one slot for a crowd/space answer **until the player owns two of them**, then
tapers off. The taper is the whole balance point: guaranteeing an answer every level-up for a full
run measured at 83% of generic slots and squeezed power picks to 7.6% — biasing the pool, not
deleting builds. Measured after the change: 100% of early level-ups offer an answer, and once the
taper is spent the free slots read space 34% · power 24% · survive 22% · crowd 20%.

All four verified live in the Training Room (aura damage, corpse burst at range, chill nova plus
its cooldown, and the surge's `("All","damage_taken")` modifier pair). The startup validator now
also checks that every upgrade/evolution `status_id` resolves in `StatusFactory` — a miss there is
silent at runtime, exactly like the anim-target class it already covered.

**Level-up card colours — DONE 2026-08-03.** Each card now carries a role colour on its name, a
matching 3px left accent bar, a role-tinted plate, and a leading glyph: `*` crowd (orange) · `»`
space (cyan) · `#` survive (green) · `+` power (bone) · `&` evolution (gold) · `^` kit upgrade
(character colour). Descriptions stay neutral grey so they stay readable.

Two pre-existing bugs surfaced and were fixed on the way:

- **`★` and `✦` were not in m5x7.** The two marks meant to make evolution and kit-upgrade cards
  feel special were the only blurry things on them, silently falling back to Godot's vector font.
  Every glyph above is verified with `FontFile.has_char()` — check before adding another.
- **Ten descriptions overflowed the card.** All seven evolutions plus three kit upgrades run past
  the 197px of usable width, the worst at 285px, and clipped on the old single-string button too.
  Descriptions now wrap, and the three cards on offer share one height computed from the longest.

Verified in the Training Room across all six treatments, including the worst case — three
two-line cards *with* the weapon cache open still fit the 360px viewport.

**`descent_portal` (3.0x) is unverified.** Its type assignment and settlement path are shared
with the two verified rungs, but reaching it needs a full ten-block descent plus the boss.

**`Level_Instructions` warning.** Blocks 3, 6 and 8 warn; the other seven don't. Unlike the Region
warning that was silenced alongside it, that inconsistency may be real authoring drift.

## What is left (2026-08-02)

**One asset job, ~15 minutes in REAPER.** The held-channel audio bed is fully wired and verified
— the predicate, the second loop slot, start/stop, the per-kit map — but three files do not exist:

```
assets/audio/sfx/combat/channel_loop_fire.ogg      low roaring bed      (Immolate, Hellfire)
assets/audio/sfx/combat/channel_loop_arcane.ogg    dry rattle/whisper   (Bone / Bramble Barrage)
assets/audio/sfx/combat/channel_loop_martial.ogg   low physical rumble  (Taunt, Dictum, dome)
```

Seamless ~2s loops, quiet enough to sit under the per-beat hits. Drop them in and they light up
with no code change — `play_channel_loop` already reads volume and pitch from the SoundTable
entry. Until then it stays deliberately silent: the only true loop asset in the library is
`extraction_channel_hum.ogg`, and re-voicing an extraction cue for ordinary combat would teach
the player the wrong thing.

**Also worth Ben's eye, not blocking:**

- The six new portraits all wear clothes; four of the original six are bare-shouldered. The new
  ones look more finished. `tools/gen_portraits.py` makes parity a one-line change per character
  plus `--force`.
- `assets/characters/portraits/the_herald.png` is orphaned. Delete or keep.
- The Wizard is the one kit with no channel bed, correctly: its "channel" slot is a
  charge-and-release fireball, not a sustained hold, so the predicate excludes it. If it should
  hum while charging, that is a design call rather than a bug.

## The `Logger` autoload does not work by name (Godot 4.6)

Writing `Logger.log_info(...)` from any script **compiles and then fails at runtime**:

```
Static function "log_info()" not found in base "GDScriptNativeClass".
```

Godot 4.6 ships a *native* `Logger` class and it wins name resolution over the autoload. The
three calls added on 2026-08-02 were the first code outside `logger.gd` ever to call it, which is
why this had never surfaced — task 22's crash logging works only because `logger.gd` calls itself.
The fix used in `game_manager.gd` is `get_node_or_null("/root/Logger")`. Anything that wants the
crash log must do the same, so it is worth knowing before the next thing tries to log.

## Correction to an existing doc

`mod_levelup_rework_plan.md` §2.5 flags `SkillFactory._ward_buff` as a suspected live tag/operation
bug — filing damage reduction as `("damage_taken", "bonus")` while `DamageCalculator` reads
`("All", "damage_taken")`. **It's wrong.** `skill_factory.gd:659-660` sets `target_tag = "All"` and
`operation = "damage_taken"`, which is exactly what `damage_calculator.gd:77` reads. The ward buff
works. The general point in that section — that `sum_modifiers` fails silently on a wrong pair — still
stands and is still worth an assertion; the cited instance just isn't one.
