# Core Framework Decisions
### Phase 8 Output | The Math Behind Everything

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

**Launch Roster (5 characters):**

| Character | HP | Damage | Move Speed | Armor | Special |
|-----------|-----|--------|------------|-------|---------|
| The Drifter | 100 | 10 | 200 | 0 | None — pure baseline |
| The Scavenger | 80 | 8 | 220 | 0 | +25% Pickup Radius, +15% Loot Find |
| The Warden | 150 | 10 | 160 | 5 | Armor doubles below 50% HP |
| The Spark | 60 | 14 | 210 | 0 | +50% Crit Damage (2.25x total) |
| The Shade | 75 | 9 | 240 | 0 | 15% Dodge Chance, dodge grants 0.5s invisibility |

**Post-Launch Characters (2 additions):**

| Character | HP | Damage | Move Speed | Armor | Special |
|-----------|-----|--------|------------|-------|---------|
| The Herald | 90 | 8 | 200 | 0 | +30% ability damage, -20% ability cooldowns, extra ability slot |
| The Cursed | 120 | 12 | 210 | 3 | Starts at 25% Instability. +20% all base stats but permanent penalty. |

---

## Damage Formula

### Base Damage Calculation

```
Raw Damage = Weapon Base Damage × (1 + Player Damage% Bonus)

If Crit: Raw Damage × Crit Damage Multiplier

After Armor: Final Damage = Raw Damage - Defender Armor (minimum 1 damage)

After Resistance: Final Damage × (1 - Damage Type Resistance%)
```

### Why Flat Armor (Not Percentage)

Flat armor (subtract X from every hit) means:
- It's very effective against many small hits (Fodder swarms) — each hit reduced by flat amount
- It's less effective against single big hits (Brutes, Minibosses) — flat reduction is a smaller % of total
- This naturally makes armor good against hordes but not a complete defense against bosses
- Easy to understand: "5 armor means every hit does 5 less damage"

### Armor Formula Detail

```
Final Damage = max(Raw Damage - Armor, 1)
```

Minimum 1 damage ensures no enemy is fully immune to any attack. Even a max-armor build still takes chip damage from Fodder — you're never invincible.

### Damage Type Resistance

Enemies can have resistance (or vulnerability) to specific damage types:

```
Resistance: 25% = take 75% damage of that type
Vulnerability: -25% = take 125% damage of that type
```

Most enemies have 0% resistance to everything (neutral). Special/elite enemies and Phase-Warped enemies may have specific resistances/vulnerabilities to create tactical variety.

### Example Damage Calculations

**Drifter with base weapon vs Fodder enemy (5 HP, 0 Armor):**
- Raw: 10 × 1.0 = 10 damage
- After Armor: 10 - 0 = 10
- Result: Fodder dies in 1 hit. Feels good. ✓

**Drifter with base weapon vs Brute enemy (80 HP, 5 Armor):**
- Raw: 10 × 1.0 = 10 damage
- After Armor: 10 - 5 = 5
- Result: 16 hits to kill. Takes ~16 seconds at 1.0 attack speed. Brute is a real threat. ✓

**Spark with +50% damage upgrade vs Brute (80 HP, 5 Armor):**
- Raw: 14 × 1.5 = 21 damage
- After Armor: 21 - 5 = 16
- Crit (2.25x): 14 × 1.5 × 2.25 = 47.25 → 47 - 5 = 42
- Result: 5 hits to kill (or 2 crits). Glass cannon fantasy delivered. ✓

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

### Phase Duration

| Phase | Duration | Cumulative Time | Notes |
|-------|----------|-----------------|-------|
| Phase 1 | 3:00 | 0:00 - 3:00 | Short intro. Learn the build. |
| Phase 2 | 3:30 | 3:00 - 6:30 | Slightly longer. Build developing. |
| Phase 3 | 4:00 | 6:30 - 10:30 | Mid-run. Stakes rising. |
| Phase 4 | 3:30 | 10:30 - 14:00 | Intense. Tightens before the climax. |
| Phase 5 | 4:00 - 6:00 | 14:00 - 18:00/20:00 | Variable length. Ends when player extracts or dies. |
| **Total** | **~18 minutes** | | Within our 15-20 minute target |

### Phase Transitions

- Extraction window: 15 seconds (Timed extraction available)
- Transition animation: 3-5 seconds
- Total between-phase downtime: ~20 seconds

Phase 5 has no automatic timer — it continues until the player extracts or dies. The Final Extraction point activates at the 4-minute mark, but enemies keep spawning and escalating. Surviving past 6 minutes in Phase 5 should be nearly impossible for most builds, creating a natural endpoint.

---

## Enemy Stat Scaling

### Base Enemy Stats by Role (Phase 1 Values)

| Role | HP | Damage | Move Speed | Armor |
|------|-----|--------|------------|-------|
| Fodder | 5 | 3 | 80 | 0 |
| Swarmer | 8 | 5 | 150 | 0 |
| Brute | 80 | 15 | 60 | 5 |
| Ranged/Caster | 20 | 8 | 40 | 0 |
| Elite (modifier on any role) | ×2 HP | ×1.5 Damage | same | +3 |
| Miniboss | 300 | 20 | 50 | 10 |

### Phase Scaling Multiplier

Enemy stats scale with each phase:

| Phase | HP Multiplier | Damage Multiplier | Speed Multiplier |
|-------|--------------|-------------------|------------------|
| Phase 1 | 1.0x | 1.0x | 1.0x |
| Phase 2 | 1.5x | 1.3x | 1.1x |
| Phase 3 | 2.5x | 1.6x | 1.15x |
| Phase 4 | 4.0x | 2.0x | 1.2x |
| Phase 5 | 6.0x | 2.5x | 1.25x |

**Example: Brute in Phase 4**
- HP: 80 × 4.0 = 320
- Damage: 15 × 2.0 = 30
- Armor: 5 (doesn't scale — player damage outscales armor naturally)

This feels like a significant threat that requires a developed build to handle efficiently.

### Instability Scaling (Stacks on Top of Phase Scaling)

| Instability Tier | Enemy Stat Bonus | Elite Spawn Rate Bonus | Other Effects |
|------------------|-----------------|----------------------|---------------|
| Stable (0-25%) | +0% | +0% | None |
| Unsettled (25-50%) | +12% all stats | +5% elite rate | Subtle — player may not notice |
| Volatile (50-75%) | +28% all stats | +12% elite rate | Noticeable. Hazards deal 25% more damage. |
| Critical (75-100%) | +50% all stats | +20% elite rate | Oppressive. Hazards intensify. Spawn rate +20%. |

**Instability + Phase stacking example: Phase 4 Brute at Critical Instability**
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

**Active enemies on screen cap: 150.** New spawns queue if cap is reached. This prevents both performance issues and visual noise overload.

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

### Timed Extraction

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Warning before portal | 10 seconds | Enough to plan movement. Audio + visual cue. |
| Portal active window | 18 seconds | Reachable from most arena positions if player prioritizes. |
| Channel time | 4 seconds | Long enough to feel tense, short enough to not be tedious. |

### Guarded Extraction

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Guardian spawn | Run start | Always visible, always a known option. |
| Guardian scaling | Phase multiplier × 1.5 | Tougher than standard enemies but not impossibly so. |
| Window after guardian kill | 25 seconds | Longer than timed — you earned it. |
| Guardian respawn delay | 45 seconds | Enough time for one attempt per phase if you fail. |
| Channel time | 4 seconds | Same as timed. |

### Locked Extraction

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Appears in | Phase 3+ arenas | Not available in early phases. |
| Keystone drop chance | ~5% from Elites, guaranteed from Miniboss first kill per phase | Rare enough to be exciting, not so rare it's never seen. |
| Channel time | 2 seconds | Faster — the Keystone was the price. |
| Loot bonus | Phase 3: +25%, Phase 4: +50%, Phase 5: +100% | Scales to incentivize holding the Keystone for deeper phases. |

### Sacrifice Extraction

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Appears in | Phase 2+ arenas | Available relatively early. |
| Activation | Instant after item selection | No channel — the sacrifice was the cost. |
| Item selection | UI pause — player picks from carried loot | Quick selection screen. Timer visible if enemies approaching. |

---

## Loot Drop Rates

### Base Drop Chance Per Kill (Before Loot Find Bonus)

| Enemy Role | Any Extractable Drop | Resource | Weapon/Mod | Blueprint | Artifact |
|-----------|---------------------|----------|------------|-----------|----------|
| Fodder | 3% | 3% | 0% | 0% | 0% |
| Swarmer | 5% | 4.5% | 0.5% | 0% | 0% |
| Brute | 30% | 20% | 8% | 2% | 0% |
| Ranged | 15% | 10% | 4% | 1% | 0% |
| Elite | 60% | 25% | 25% | 8% | 2% |
| Miniboss | 100% | 30% | 40% | 20% | 10% |
| Carrier | 100% | 30% | 50% | 15% | 5% |

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

| Phase | Arena Size (tiles) | Arena Size (pixels at 16px/tile) | Player Screen Proportion |
|-------|-------------------|----------------------------------|-------------------------|
| Phase 1 | 40 × 30 | 640 × 480 | Contained, can see most of arena |
| Phase 2 | 50 × 38 | 800 × 608 | Slightly larger, edges unseen |
| Phase 3 | 60 × 45 | 960 × 720 | Notable space, must explore |
| Phase 4 | 55 × 42 | 880 × 672 | Slightly tighter than Phase 3 — claustrophobic |
| Phase 5 | 70 × 52 | 1120 × 832 | Largest. Vast. Enemies come from everywhere. |

**Camera:** Follows the player with slight lookahead in movement direction. Screen shows roughly 20×15 tiles around the player (320×240 pixel viewport scaled up, or equivalent). Vision Radius stat affects the lit area within this view.

**Phase 4 intentionally smaller than Phase 3.** This creates a claustrophobic feel — more enemies in less space. Contrasts with Phase 5's vastness.

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
