# Core Framework Decisions
### Phase 8 Output | The Math Behind Everything

> **Status (Late-Alpha):** Live values live in `data/characters.gd`, `data/loot_tables.gd`, and the relevant manager scripts. **When in conflict, code wins.**
>
> **Reconciled with code 2026-07-21.** Section-by-section:
>
> | Section | State |
> |---|---|
> | Character stats & roster | ✅ live (12 characters, post-pacing-rebalance speeds) |
> | Phase timing & names | ✅ live (`GameManager.PHASE_DURATIONS`) |
> | Extraction window | ✅ live (18s) |
> | Enemy phase scaling | ✅ live (HP/DMG/SPAWN multipliers match) |
> | Instability tiers & bonuses | ✅ live (`LootTables.INSTABILITY_TIERS`) |
> | Instability per loot item | ✅ live (`LootTables.RARITY_INSTABILITY`) |
> | Enemy cap | ✅ live (90) |
> | Loot drop rates | ✅ live (bumped 2026-07-19) |
> | Rarity weights per phase | ✅ live (`LootTables.PHASE_RARITY_WEIGHTS`) |
> | Spawn rates (per-minute table) | ⚠️ design intent — spawn loop is formula-driven, not rate-driven |
> | Baseline stat table (200 px/s etc.) | ⚠️ design history — superseded per-character |
> | Economy / hub costs / meta XP | ⚠️ unverified — last checked 2026-05-02 |
> | Weapon rarity stat ranges | ⚠️ unverified, and the weapon model is being reworked (see `weapon-scaling-reference.md`) |

---

## Important Note

**Every number in this document is a starting point for prototyping, not a final value.** The prototype exists to test whether these numbers FEEL right. Expect to tune aggressively during and after Phase 9. The goal here is to have concrete values to build from, not perfect values to ship with.

That said, the FORMULAS and RELATIONSHIPS matter more than the specific numbers. If the damage formula is sound but the base damage is too high, that's a tuning pass. If the damage formula itself is flawed, that's a redesign.

---

## Core Stat Baselines (The Drifter — Default Character)

The Drifter is the baseline. All other characters are defined as modifications to these values.

### Player Base Stats

| Stat | Base Value | Notes |
|------|-----------|-------|
| Max HP | 100 | Round number. Easy to reason about. "I have 73 HP" is instantly meaningful. |
| HP Regen | 0 | No passive regen by default. Must be earned through upgrades. Makes health pickups valuable. |
| Armor | 0 | No armor by default. Flat damage reduction. |
| Shield | 0 | No shield by default. Gained through upgrades/artifacts. |
| Movement Speed | 200 | Pixels per second. Feels responsive without being twitchy at 16x16 scale. |
| Damage | 10 | Base weapon damage (Drifter's starting weapon). |
| Attack Speed | 1.0 | Attacks per second (Drifter's starting weapon). |
| Crit Chance | 5% | Low base. Meaningful to invest in. |
| Crit Damage | 1.5x | 150% damage on crit (universal base). Can be upgraded. The Spark gets 2.25x via passive. |
| Dodge Chance | 0% | No dodging by default. Earned through upgrades or character choice (The Shade). |
| Pickup Radius | 50 | Pixels. Starts small — upgrading this should feel amazing. |
| Loot Find | 0% | No bonus. Baseline drop rates. |
| XP Gain | 0% | No bonus. Baseline XP rates. |
| Luck | 0 | Neutral. Affects upgrade rarity rolls, drop quality. |
| Cooldown Reduction | 0% | No CDR by default. |
| Vision Radius | 300 | Pixels. How far the player can see clearly. Matters in Phase 4-5 darkness. |
| Extraction Speed | 1.0x | Multiplier on extraction channel time. 1.0 = standard speed. |
| Weapon Slots | 1 | Starting slots. Expandable via hub upgrades (max 3). |
| Active Ability Slots | 1 | Starting slots. Some characters get 2. |

### Character Stat Modifiers (Relative to Drifter Baseline)

**All 12 Characters (live — source: `data/characters.gd`, reconciled 2026-07-21):**

The roster completed at 12/12. Each character now carries a `char_class` (its fantasy archetype) and a `melee_kit` id, which is what actually selects its combo-chain moveset from `ChainFactory` / `SkillFactory`. Internal `id` keys are the original Drifter-era names; `display_name` is what the player sees.

| id (internal) | Display / Class | Kit | HP | Armor | Move | Starting Weapon | Passive |
|---|---|---|---|---|---|---|---|
| The Drifter | THE SELLSWORD · Fighter | `fighter` | 100 | 0 | 54 | Mercenary's Edge | — (pure baseline) |
| The Scavenger | THE SCAVENGER · Ranger | `ranger` | 80 | 0 | 60 | Hunter's Bow | Forager's Eye |
| The Warden | THE WARDEN · Paladin | `paladin` | 150 | 5 | 48 | Warden's Repeater | Last Bastion |
| The Spark | THE SPARK · Wizard | `wizard` | 60 | 0 | 58 | Apprentice Flame | Arcane Overload |
| The Shade | THE SHADE · Rogue | `rogue` | 75 | 0 | 66 | Shadowfang | Shadowstep |
| The Herald | THE HERALD · Bard | `bard` | 90 | 0 | 54 | Herald's Call | Rallying Anthem |
| The Cursed | THE CURSED · Blood Mage | `blood_mage` | 120 | 3 | 58 | Void Mortar | Blood Pact |
| The Ravager | THE RAVAGER · Barbarian | `barbarian` | 130 | 2 | 52 | Ravager's Cleaver | Bloodrage |
| The Whisper | THE WHISPER · Ninja | `ninja` | 70 | 0 | 64 | Whisper's Kiss | Killing Intent |
| The Deadeye | THE DEADEYE · Gunslinger | `gunslinger` | 85 | 0 | 58 | Peacemaker | Calm Hands |
| The Verdant | THE VERDANT · Druid | `druid` | 110 | 2 | 56 | Thornstaff | Primal Vigor |
| The Devout | THE DEVOUT · Cleric | `cleric` | 100 | 4 | 52 | Ember Censer | Last Rites |

*Base damage is not defined at the character level — damage scaling flows through the modifier and upgrade system.*

> **Move speed — read this before "fixing" anything.** The 200 px/s figure in the baseline table above is the **original design target and is no longer the live value**. The deliberate-pacing rebalance (2026-07-07, `docs/pacing_rebalance.md`) cut every character roughly 2.2× from the original numbers — the Drifter went 120 → 66 → **54**. The live spread is 48 (Warden, slowest) to 66 (Shade, fastest). The baseline table's 200 is design-history; `data/characters.gd` is the truth.

---

## Damage Formula

### Damage Pipeline (8-Step)

Implemented in `DamageCalculator.calculate_damage()`. Full pipeline:

1. **Base damage** = `base_damage × (1 + scaling_value × coefficient)`
2. **Conversion** — source modifier converts damage type (first match wins, True damage immune)
3. **Offensive modifiers** — `raw × (1 + source bonus for damage_type + source bonus for "All")`
4. **Dodge** — target dodge_chance roll → HitData.is_dodged
5. **Block** — target block_chance roll → partial mitigation via block_mitigation %
6. **Resistance** — `raw × (1 - effective_resist / (effective_resist + 100))` where effective_resist = resist × (1 - source pierce)
7. **Damage taken** — target damage_taken modifiers + vulnerability (per-type + "All")
8. **Crit** — source crit_chance roll → `raw × (1 + crit_multiplier)`

### Why Percentage-Based Armor

Armor uses the formula `reduction = armor / (armor + 100)`:
- 5 armor = 4.8% reduction (small, Fodder-level)
- 10 armor = 9.1% reduction (guardian-level)
- 100 armor = 50% reduction (theoretical cap target)
- Scales smoothly — never reaches 100% reduction
- Source "pierce" reduces effective armor by a percentage before the formula

### Damage Type Resistance

Implemented as `ModifierDefinition` with `operation = "resist"` and `target_tag` = damage type name. Vulnerability uses `operation = "vulnerability"`. Both per-type and "All" variants stack additively.

### Example Damage Calculations

**Drifter (18 base damage) vs Fodder (30 HP, 0 Armor):**
- Raw: 18, Resist: 0/(0+100) = 0% reduction → 18 damage
- Result: 2 hits to kill. Fast. ✓

**Drifter (18 base damage) vs Brute (80 HP, 5 Armor):**
- Raw: 18, Resist: 5/(5+100) = 4.8% → 18 × 0.952 = 17.1 damage
- Result: ~5 hits to kill. Noticeable tankiness without being a slog. ✓

**Spark (+50% damage bonus, 2.25x crit) vs Brute (80 HP, 5 Armor):**
- Raw: 14 × 1.5 = 21, Resist: 4.8% → 20.0 damage
- Crit: 21 × 2.25 = 47.25, Resist → 45.0 damage
- Result: 4 hits or 2 crits. Glass cannon fantasy delivered. ✓

---

## XP and Leveling

### XP Per Kill

| Enemy Role | Base XP | Notes |
|-----------|---------|-------|
| Fodder | 1 | Tiny per kill, massive in volume |
| Swarmer | 2 | Slightly more per kill |
| Brute | 10 | Rewarding to take down |
| Ranged/Caster | 5 | Priority target bonus |
| Elite | 15 | Mini-challenge reward |
| Miniboss | 50 | Event-level reward |
| Special (Carrier, Stalker, etc) | 8-15 | Varies by type |

### XP to Level Up

Leveling uses a soft curve — early levels are fast, later levels slow down but never become a grind.

```
XP needed for level N = Base × (1 + (N-1) × Growth Rate)

Base = 10
Growth Rate = 0.3
```

| Level | XP Required | Cumulative XP | Approx Time to Reach (Phase 1 pace) |
|-------|------------|---------------|--------------------------------------|
| 1→2 | 10 | 10 | ~15 seconds |
| 2→3 | 13 | 23 | ~30 seconds |
| 3→4 | 16 | 39 | ~50 seconds |
| 4→5 | 19 | 58 | ~1:15 |
| 5→6 | 22 | 80 | ~1:45 |
| 8→9 | 31 | 178 | ~3:30 |
| 10→11 | 37 | 252 | ~5:00 |
| 15→16 | 52 | 475 | ~9:00 |
| 20→21 | 67 | 770 | ~14:00 |

**Target: ~15-20 level-ups per full run (through Phase 5).** This gives the player 15-20 upgrade choices, which is enough to form a build identity without overwhelming them. Level-ups are front-loaded — you get several in Phase 1 (feels good, build takes shape fast) and fewer in Phase 5 (you're mostly done building, focused on survival and extraction).

XP Gain bonus stat accelerates this curve. +50% XP Gain at Level 10 means reaching Level 20 faster → more upgrade choices → stronger build.

---

## Phase Timing

Each biome run comprises 5 wave-phases. **Confirmed against `GameManager.PHASE_DURATIONS` on 2026-07-21** — the table below is live, not a target.

### Wave-Phase Duration (per biome)

| Wave-Phase | Name | Duration | Cumulative | Notes |
|------------|------|----------|------------|-------|
| Wave-Phase 1 | The Threshold | 3:00 | 0:00 – 3:00 | Short intro. Learn the build. |
| Wave-Phase 2 | The Descent | 3:30 | 3:00 – 6:30 | Slightly longer. Build developing. |
| Wave-Phase 3 | The Deep | 4:00 | 6:30 – 10:30 | Mid-run. Stakes rising. |
| Wave-Phase 4 | The Abyss | 3:30 | 10:30 – 14:00 | Intense. Tightens before the climax. |
| Wave-Phase 5 | The Core | 4:00 | 14:00 – 18:00 | Ends when the player extracts, dies, or downs the final boss. |
| **Total** | | **~18 minutes** | | Within the 15–20 minute target |

`PHASE_NAMES` and `MAX_PHASES = 5` live alongside the durations in `scripts/managers/game_manager.gd`.

> **In descent mode the clock is not the difficulty.** `phase_number` still advances on this timer because other systems hang off `phase_started` (carrier/herald resets, miniboss arming), but combat and loot scaling read `GameManager.get_effective_phase()`, which derives the 1–5 tier from **spatial depth** via `DepthTracker`. A player who descends fast meets phase-4 enemies well before the 10:30 mark. Treat the timings above as pacing intent, not as the difficulty curve.

### Phase Transitions

- Extraction window: **18 seconds** (`GameManager.extraction_window_duration`) — confirmed 2026-07-21. The 15-second figure previously recorded here was never the shipped value.
- Transition animation: 3–5 seconds
- Total between-phase downtime: ~20 seconds

Wave-Phase 5 has no automatic timer — it continues until the player extracts or dies. The Final Extraction point activates at the 4-minute mark, but enemies keep spawning and escalating. Surviving past 6 minutes in Wave-Phase 5 should be nearly impossible for most builds, creating a natural endpoint.

---

## Enemy Stat Scaling

### Base Enemy Stats by Role (Wave-Phase 1 Values)

| Role | HP | Damage | Move Speed | Armor |
|------|-----|--------|------------|-------|
| Fodder | 5 | 3 | 80 | 0 |
| Swarmer | 8 | 5 | 150 | 0 |
| Brute | 80 | 15 | 60 | 5 |
| Ranged/Caster | 20 | 8 | 40 | 0 |
| Elite (modifier on any role) | ×2 HP | ×1.5 Damage | same | +3 |
| Miniboss | 300 | 20 | 50 | 10 |

### Wave-Phase Scaling Multipliers (per biome)

Enemy stats scale with each wave-phase within a biome. Source: `scripts/managers/enemy_spawn_manager.gd`.

| Wave-Phase | HP Multiplier | Damage Multiplier | Spawn Rate Multiplier |
|------------|--------------|-------------------|-----------------------|
| Wave-Phase 1 | 1.0x | 1.0x | 1.0x |
| Wave-Phase 2 | 1.5x | 1.2x | 1.2x |
| Wave-Phase 3 | 2.5x | 1.4x | 1.5x |
| Wave-Phase 4 | 4.0x | 1.7x | 1.8x |
| Wave-Phase 5 | 6.0x | 2.0x | 2.2x |

*HP multipliers match the original design exactly. Damage multipliers were tuned down from the prototype values. The "Speed Multiplier" column from the prototype has been replaced by Spawn Rate Multiplier (`PHASE_SPAWN_MULT` in code) — per-phase enemy move-speed scaling is not currently implemented.*

**Example: Brute in Wave-Phase 4**
- HP: 80 × 4.0 = 320
- Damage: 15 × 1.7 = 22.5
- Armor: 5 (doesn't scale — player damage outscales armor naturally)

This feels like a significant threat that requires a developed build to handle efficiently.

### Instability Scaling (Stacks on Top of Phase Scaling)

**Live — matches `LootTables.INSTABILITY_TIERS` exactly (verified 2026-07-21).** Thresholds are
absolute instability points, *not* percentages; an earlier revision of this table labelled them
0-25% / 25-50% / etc., which contradicted the threshold table further down this doc.

| Instability Tier | Threshold | Enemy Stat Bonus | Elite Spawn Rate Bonus | Other Effects |
|------------------|-----------|-----------------|----------------------|---------------|
| STABLE | 0+ | +0% | +0% | None |
| UNSETTLED | 31+ | +12% all stats | +5% elite rate | Subtle — player may not notice |
| VOLATILE | 71+ | +28% all stats | +12% elite rate | Noticeable. Hazards deal 25% more damage. |
| CRITICAL | 121+ | +50% all stats | +20% elite rate | Oppressive. Hazards intensify. Spawn rate +20%. |

Applied via `GameManager.get_instability_multiplier()` → `1.0 + tier.stat_bonus`, which
`EnemySpawnManager` folds into enemy HP alongside the phase multiplier. The Cursed starts every run
at 31 (Unsettled) by passive.

**Instability + Phase stacking example: Wave-Phase 4 Brute at Critical Instability**
- Base HP: 80
- Phase 4 multiplier: × 4.0 = 320
- Critical Instability: × 1.5 = 480 HP
- That Brute is now a mini-miniboss. Extracting looks very appealing.

---

## Spawn Rates

### Enemies Per Minute (Approximate)

| Phase | Fodder/min | Swarmers/min | Brutes/min | Ranged/min | Elites/min |
|-------|-----------|-------------|-----------|-----------|-----------|
| Phase 1 | 20 | 5 | 0 | 0 | 0 |
| Phase 2 | 25 | 10 | 2 | 2 | 0.5 |
| Phase 3 | 30 | 15 | 4 | 4 | 2 |
| Phase 4 | 35 | 20 | 6 | 5 | 4 |
| Phase 5 | 40 | 25 | 8 | 8 | 8 |

**Active enemies on screen cap: 90** (`EnemySpawnManager.max_enemies`, verified 2026-07-21 — the
150 figure recorded here previously was a design target, never the shipped value). New spawns queue
if the cap is reached. This prevents both performance issues and visual noise overload.

> The per-minute table above is a design-era estimate and has **not** been reconciled against
> `EnemySpawnManager`'s actual spawn loop, which derives counts from `enemies_per_spawn × difficulty ×
> PHASE_SPAWN_MULT` rather than from fixed rates. Treat it as intent. The multipliers themselves are
> live: `PHASE_HP_MULT = [1.0, 1.5, 2.5, 4.0, 6.0]`, `PHASE_DMG_MULT = [1.0, 1.2, 1.4, 1.7, 2.0]`,
> `PHASE_SPAWN_MULT = [1.0, 1.2, 1.5, 1.8, 2.2]` — all three match this doc's scaling tables.

### Special Enemy Spawn Rules

| Enemy | First Appears | Spawn Method |
|-------|--------------|-------------|
| Mimics | Phase 2 | Replace a loot drop (1 in 20 chance for non-resource drops) |
| Anchors | Phase 2 | Spawn at random arena positions (1-2 per phase) |
| Carriers | Phase 2 | Spawn at arena edges, attempt to cross and flee (1 per phase, 2 in Phase 4+) |
| Stalkers | Phase 3 | Spawn invisible at arena edges (2-3 per phase, 4-5 in Phase 5) |
| Heralds | Phase 3 | Spawn surrounded by a pack (1 per phase, 2 in Phase 4+) |
| Phase-Warped | Phase 5 | Replace ~30% of Fodder/Swarmer spawns |

---

## Instability System Numbers

### Instability Per Loot Item

| Loot Category | Instability Added |
|---------------|------------------|
| Resources (small drop) | +1 |
| Resources (medium drop) | +3 |
| Resources (large drop) | +5 |
| Common Weapon/Mod | +5 |
| Uncommon Weapon/Mod | +8 |
| Rare Weapon/Mod | +12 |
| Epic Weapon/Mod | +18 |
| Legendary Weapon/Mod | +25 |
| Blueprint | +10 |
| Artifact | +15 |
| Lore Fragment | +2 |
| Cursed Item (any) | Listed value × 2 |

### Instability Thresholds

| Tier | Threshold | Practical Meaning |
|------|-----------|-------------------|
| Stable | 0 - 30 | A few small pickups. Phase 1-2 normal play. |
| Unsettled | 31 - 70 | Moderate loot haul. Mid-run typical. |
| Volatile | 71 - 120 | Good haul. Rare+ items in pocket. |
| Critical | 121+ | Massive haul or several high-value items. You're pushing it. |

**Example scenario:** Player picks up 10 small resource drops (+10), 2 common weapons (+10), 1 rare mod (+12), and 1 blueprint (+10) = 42 Instability → Unsettled tier. This feels right for a Phase 2-3 haul.

If they also found a Legendary weapon (+25) and a Cursed artifact (+30): 42 + 25 + 30 = 97 → Volatile. The game is noticeably harder. Extraction is looking very smart right about now.

---

## Extraction Timing

All four extraction types are live (`timed_extraction.gd`, `guarded_extraction.gd`, `locked_extraction.gd`, `sacrifice_extraction.gd`). Confirmed values are sourced from those files; unconfirmed values retain the design baseline with an inline note.

### Timed Extraction

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Warning before portal | 10 seconds *(unverified — see verification_findings §8)* | Enough to plan movement. Audio + visual cue. |
| Portal active window | 18 seconds *(unverified — see verification_findings §8)* | Reachable from most arena positions if player prioritizes. |
| Channel time | 4 seconds ✓ | Long enough to feel tense, short enough to not be tedious. |

### Guarded Extraction

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Guardian spawn | Run start | Always visible, always a known option. |
| Guardian scaling | Phase multiplier × 1.5 | Tougher than standard enemies but not impossibly so. |
| Window after guardian kill | 25 seconds ✓ | Longer than timed — you earned it. |
| Guardian respawn delay | 45 seconds ✓ | Enough time for one attempt per phase if you fail. |
| Channel time | 4 seconds ✓ | Same as timed. |

### Locked Extraction

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Appears in | Phase 3+ arenas | Not available in early phases. |
| Keystone drop chance | ~5% from Elites, guaranteed from Miniboss first kill per phase | Rare enough to be exciting, not so rare it's never seen. |
| Channel time | 2 seconds ✓ | Faster — the Keystone was the price. |
| Loot bonus | Phase 3: +25%, Phase 4: +50%, Phase 5: +100% *(unverified — see verification_findings §8)* | Scales to incentivize holding the Keystone for deeper phases. |

### Sacrifice Extraction

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Appears in | Phase 2+ arenas *(unverified — see verification_findings §8)* | Available relatively early. |
| Activation | Instant ✓ | No channel — the sacrifice was the cost. |
| Item selection | UI pause — player picks from carried loot | Quick selection screen. Timer visible if enemies approaching. |

---

## Loot Drop Rates

### Base Drop Chance Per Kill (Before Loot Find Bonus)

*Rates bumped 2026-07-19 (playtest pass): common enemies ≈4×, specials ≈2×.
Target: tester reaches meta-content in 2–3 runs. See per-run income table below.*

| Enemy Role | Resource | Weapon/Mod | Old Resource | Multiplier |
|-----------|----------|------------|-------------|------------|
| Fodder | **15%** | 0% | 3% | 5× |
| Swarmer | **18%** | 0.5% | 4.5% | 4× |
| Brute | **45%** | 8% | 20% | 2.25× |
| Caster/Ranged | **28%** | 4% | 10% | 2.8× |
| Stalker | **28%** | 4% | 10% | 2.8× |
| Guardian | **55%** | 40% | 30% | 1.8× |
| Carrier | **55%** | 50% | 30% | 1.8× |
| Herald | **55%** | 25% | 25% | 2.2× |
| Anchor | **40%** | 8% | 15% | 2.7× |
| Bosses | 100% | 90–100% | 100% | — |

### Per-Run Resource Income Estimate (~300 kills, locked extraction)

| Deepest Phase | Old Income | New Income | Multiplier |
|--------------|-----------|-----------|------------|
| Phase 1 only | ~8 | ~39 | ×4.9 |
| Phase 2 | ~37 | ~150 | ×4.1 |
| Phase 3 | ~157 | ~490 | ×3.1 |
| Phase 4 | ~438 | ~1157 | ×2.6 |
| Full P5 run | ~893 | ~2424 | ×2.7 |

*Death payouts at 25% of above. Locked-extraction bonus applies on top (+25/50/100% for P3/4/5).*

Hub upgrade costs for context: insurance_license 300 · channel_accelerator_1 400 · armory_expansion_1 750

**Phase scaling on drop quality:** Drop chances above determine IF something drops. The RARITY of what drops is scaled by phase:

| Phase | Common Weight | Uncommon Weight | Rare Weight | Epic Weight | Legendary Weight |
|-------|-------------|----------------|------------|------------|-----------------|
| Phase 1 | 80% | 18% | 2% | 0% | 0% |
| Phase 2 | 60% | 30% | 8% | 2% | 0% |
| Phase 3 | 40% | 35% | 18% | 6% | 1% |
| Phase 4 | 20% | 30% | 30% | 15% | 5% |
| Phase 5 | 5% | 20% | 35% | 25% | 15% |

**Loot Find bonus:** Each point of Loot Find increases drop chances by that percentage. +15% Loot Find on The Scavenger means a Fodder's 3% drop chance becomes 3.45%. Sounds small, but over hundreds of Fodder kills per run, it adds up significantly.

---

## Health Pickup Economy

Players don't regenerate HP by default. Health management is a key tension driver.

| Source | Heal Amount | Frequency |
|--------|-----------|-----------|
| Health Orb (enemy drop) | 10 HP (10% of base max) | ~3% chance per kill (all enemies) |
| Finisher heal (if upgrade taken) | 5-15 HP (varies) | Every finisher execution |
| Lifesteal mod | 3-8% of damage dealt | Per hit (on the modded weapon only) |
| Vampiric mod | 15 HP | Per kill (on the modded weapon only) |
| HP Regen (from upgrades) | 1-3 HP/sec | Continuous |
| On Phase Start heal (if upgrade taken) | Full heal | Once per phase transition |

**Design principle:** HP is scarce by default. Investing in healing (through upgrades, mods, or build choices) is a meaningful decision that trades offensive power for sustainability. Players who don't invest in healing must play more carefully or extract earlier. This ties HP economy directly into Pillar 1 (extraction tension).

---

## Meta XP and Resource Economy

### Meta XP on Run End

```
Base Meta XP = (Total Enemies Killed × XP Value) + (Phase Bonus × Phases Completed)

Phase Bonus: Phase 1 = 50, Phase 2 = 100, Phase 3 = 200, Phase 4 = 400, Phase 5 = 800

On Successful Extraction: Base Meta XP × (1 + Extraction Phase Bonus%)
On Death: Base Meta XP × 0.25 (25% — locked value. Extraction always beats death economically.)
```

**Example: Extract from Phase 3 with ~500 kills**
- Kill XP: ~500 enemies × avg 3 XP = 1500
- Phase bonus: 50 + 100 + 200 = 350
- Base: 1850
- Phase 3 extraction bonus (+25%): 1850 × 1.25 = 2312 Meta XP

**Example: Die on Phase 4 with ~800 kills**
- Kill XP: ~800 enemies × avg 3 XP = 2400
- Phase bonus: 50 + 100 + 200 + 400 = 750
- Base: 3150
- Death penalty (×0.25): 3150 × 0.25 = 787 Meta XP

**Extraction from Phase 3 (2312 XP) is worth more than dying on Phase 4 (787 XP).** This strongly incentivizes extraction over pushing recklessly. The math supports Pillar 1.

### Resource Amounts (Extracted Loot)

Resources are the universal currency. Approximate per-run resource extraction:

| Extraction Point | Estimated Resources |
|-----------------|-------------------|
| Phase 1 extract | 50-100 |
| Phase 2 extract | 150-300 |
| Phase 3 extract | 400-700 |
| Phase 4 extract | 800-1500 |
| Phase 5 extract | 1500-3000+ |

### Hub Spending Costs (Approximate)

| Purchase | Cost | Runs to Afford (Phase 3 extract avg) |
|----------|------|--------------------------------------|
| Cheapest blueprint | 200 | ~1 run |
| Average blueprint | 500 | 1-2 runs |
| Cheap hub upgrade | 750 | 1-2 runs |
| First character unlock | 1000 | 2-3 runs |
| Mid-tier character unlock | 2500 | 4-6 runs |
| Expensive character unlock | 5000 | 8-12 runs |
| Major hub upgrade | 3000 | 5-7 runs |
| Insurance (per use) | 300 | ~1 run |

**Pacing feel:** After your first successful extraction (even Phase 2), you can buy SOMETHING. A blueprint, insurance for next run, a small upgrade. You're never sitting on zero progress. The expensive unlocks (characters, major upgrades) are aspirational but achievable within a few sessions. Matches the "never count runs" philosophy.

---

## Weapon Stat Ranges

### By Rarity

| Rarity | Damage Range | Attack Speed Range | Special Properties |
|--------|-------------|-------------------|-------------------|
| Common | 6-10 | 0.6-1.2/sec | No special properties |
| Uncommon | 10-16 | 0.8-1.5/sec | May have 1 built-in effect |
| Rare | 16-24 | 0.8-1.8/sec | 1 built-in effect, better base stats |
| Epic | 24-35 | 1.0-2.0/sec | 1-2 built-in effects |
| Legendary | 35-50 | 1.0-2.5/sec | 2 built-in effects, unique behavior |

### Mod Slot Count by Rarity

| Rarity | Mod Slots |
|--------|-----------|
| Common | 1 |
| Uncommon | 1 |
| Rare | 2 |
| Epic | 2 |
| Legendary | 3 |

---

## Active Ability Baseline

| Parameter | Value |
|-----------|-------|
| Base cooldown | 8-15 seconds (varies by ability) |
| Cooldown Reduction cap | 50% (minimum 50% of base cooldown) |
| Damage scaling | Abilities scale with player's Damage stat at 1.5x multiplier |
| Duration (for buffs/shields) | 2-5 seconds |

---

## Arena Dimensions

<!-- TODO: verify phase vs biome — this table was authored under the old design where Phase 1–5 = 5 sequential biomes. In the current structure, a run takes place inside one biome; the "Phase X" rows below may describe different levels within a biome, different wave-phases, or simply be stale biome-level data. Verify against ldtk_workflow.md before acting on these numbers. -->

| Phase | Arena Size (tiles) | Arena Size (pixels at 16px/tile) | Player Screen Proportion |
|-------|-------------------|----------------------------------|-------------------------|
| Phase 1 | 40 × 30 | 640 × 480 | Contained, can see most of arena |
| Phase 2 | 50 × 38 | 800 × 608 | Slightly larger, edges unseen |
| Phase 3 | 60 × 45 | 960 × 720 | Notable space, must explore |
| Phase 4 | 55 × 42 | 880 × 672 | Slightly tighter than Phase 3 — claustrophobic |
| Phase 5 | 70 × 52 | 1120 × 832 | Largest. Vast. Enemies come from everywhere. |

**Camera:** Follows the player with slight lookahead in movement direction. Screen shows roughly 20×15 tiles around the player (320×240 pixel viewport scaled up, or equivalent). Vision Radius stat affects the lit area within this view.

<!-- TODO: verify phase vs biome — "Phase 4 smaller than Phase 3" is biome-era design intent; unclear whether this still applies to wave-phases within a single biome or to specific levels in a biome. --> **Phase 4 intentionally smaller than Phase 3.** This creates a claustrophobic feel — more enemies in less space. Contrasts with Phase 5's vastness.

---

## Tuning Levers (What to Adjust First During Playtesting)

When something doesn't feel right, these are the first knobs to turn:

| Feels Wrong | Adjust This |
|------------|-------------|
| Dying too fast | Reduce enemy Damage multipliers OR increase Health Orb drop rate |
| Dying too slow / no tension | Increase enemy Damage multipliers OR reduce Health Orb drops |
| Levels come too fast | Increase XP curve Growth Rate |
| Levels come too slow | Decrease XP curve Growth Rate or increase XP per kill |
| Extraction is too easy | Reduce extraction channel window OR increase channel time |
| Extraction is too hard to reach | Increase portal active window OR add extraction speed upgrades earlier |
| Instability is too punishing | Reduce Instability per item OR widen tier thresholds |
| Instability is ignorable | Increase Instability per item OR increase enemy stat bonuses per tier |
| Runs are too short | Increase phase durations |
| Runs are too long | Decrease phase durations |
| Early game too boring | Increase Phase 1 spawn rate OR add Swarmers earlier |
| Late game impossible | Reduce Phase 4-5 scaling multipliers |
| Loot too scarce | Increase base drop rates |
| Loot too common (Instability spikes immediately) | Reduce drop rates OR reduce Instability per common item |
| Hub progression too slow | Reduce purchase costs OR increase resource drops |
| Hub progression too fast (nothing to chase) | Increase costs OR add more unlock tiers |

---

*Phase 8 (Core Framework Decisions) is complete. All formulas, stat baselines, scaling curves, economy values, and timing parameters are defined with concrete numbers ready for prototyping.*

*Next: Phase 9 — PROTOTYPE. Build the minimum systems needed to demonstrate the core loop. Get something on screen. Validate that the math FEELS right.*
