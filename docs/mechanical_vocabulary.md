# Mechanical Vocabulary
### Phase 5 Output | The Grammar of the Game

---

## What This Document Is

This is the **grammar** of the game. Every weapon, mod, enemy, upgrade, and interaction is a "sentence" built from the vocabulary defined here. No new mechanics need to be invented to add content — everything is a combination of these building blocks.

**Why this matters:**
- Without a shared vocabulary, every new mechanic requires inventing new systems
- With a shared vocabulary, every new mechanic is just a new combination of existing pieces
- The vocabulary IS the framework — it defines what the code needs to support
- Synergies and combos emerge naturally from the vocabulary rather than being hardcoded
- New content (weapons, mods, enemies, upgrades) is authored by combining vocabulary terms, not by writing new code

**How to read this document:** Each category defines a TYPE of mechanical building block. Specific content (individual weapons, specific mods) is NOT defined here — that's data created in Phase 10. This document defines what TYPES of things can exist.

---

## Category 1: Damage Types

Every source of damage in the game deals one (or more) damage types. Enemies can resist or be vulnerable to specific types. Damage types are the foundation of elemental builds and synergy systems.

### v1 Damage Types

| Damage Type | Visual Identity | Associated Status | Fantasy |
|-------------|----------------|-------------------|---------|
| **Physical** | White/gray impacts | None (default) | Bullets, blades, blunt force. The baseline. |
| **Fire** | Orange/red, flames | Burning (DOT) | Heat, combustion, destruction over time. |
| **Cryo** | Blue/white, frost | Chilled → Frozen (slow → stun) | Cold, ice, slowing, shattering. |
| **Shock** | White-blue, crackling arcs | Shocked (chain damage) | Electricity, arcing, multi-target potential. |
| **Void** | Dark purple/black, distortion | Void-Touched (instability bleed) | Cosmic horror. The deep. The unknown. The game's signature element. |

**5 types for v1.** Enough for distinct elemental builds without overwhelming the player. Physical is the default; the four elemental types each have a clear identity, visual language, and associated status effect.

### v1.5 Planned: Additional Damage Types

| Damage Type | Visual Identity | Associated Status | Fantasy |
|-------------|----------------|-------------------|---------|
| **Toxic** | Green, dripping, corrosive | Corroded (armor shred) | Acid, poison, dissolving defenses. |
| **Radiant** | White/gold, intense light | Illuminated (bonus damage taken) | Pure energy. Burst damage. Revelation. |

### v2 Planned: Secondary (Mixed) Damage Types

Two primary damage types combine into a secondary type with unique properties. This emerges from the existing vocabulary — a weapon with two damage types applied simultaneously creates the secondary effect.

| Combination | Secondary Type | Effect Concept |
|-------------|---------------|----------------|
| Fire + Cryo | **Steam** | Blinds/obscures enemies (reduced accuracy, wander behavior) |
| Fire + Shock | **Hellfire** | High single-target burst damage, ignores armor |
| Fire + Void | **Inferno** | DOT that scales with Instability level |
| Cryo + Shock | **Shatter** | Frozen enemies take massive bonus damage from Shock (combo finisher) |
| Cryo + Void | **Entropy** | Slows AND causes random negative effects (stat drain, disorientation) |
| Shock + Void | **Surge** | Chain damage that increases Instability per enemy hit but deals massive damage |

**Design Note:** Secondary types are NOT in v1 scope. They are documented here because the vocabulary is designed to support them — the system of damage types + status effects already allows for "if both conditions are present, trigger a secondary interaction." This is a natural expansion point, not a retrofit.

---

## Category 2: Status Effects

Conditions applied to entities (player or enemies). Each has a source, an effect, a duration, and potential interactions with other statuses.

### Combat Status Effects

| Status Effect | Source | Effect | Duration | Stacks? |
|---------------|--------|--------|----------|---------|
| **Burning** | Fire damage | DOT: takes fire damage over time | Medium (3-5s) | Intensity (more sources = faster burn) |
| **Chilled** | Cryo damage | Slow: reduced movement and attack speed | Medium (3-5s) | Yes → at max stacks becomes **Frozen** |
| **Frozen** | Max Chill stacks | Stun: cannot move or attack | Short (1-2s) | No (breaks after duration or damage threshold) |
| **Shocked** | Shock damage | Chain: when hit, damage chains to nearby enemies | Medium (4-6s) | No (refreshes duration on reapply) |
| **Void-Touched** | Void damage | On death: enemy explodes, damages nearby enemies AND adds slight Instability to player | Until death | No |
| **Corroded** | Toxic damage (v1.5) | Armor shred: reduced armor/defense | Long (6-8s) | Intensity (more stacks = less armor) |
| **Illuminated** | Radiant damage (v1.5) | Exposed: takes bonus damage from all sources | Short (2-3s) | No (refreshes duration) |

### Mechanical Status Effects

| Status Effect | Source | Effect | Duration |
|---------------|--------|--------|----------|
| **Staggered** | Reaching low HP threshold (10-15%) | Vulnerable: enables finisher/execution mechanic | Until killed or HP recovers above threshold |
| **Marked** | Specific abilities/mods | Targeted: takes bonus damage from the player who applied it | Medium (5s) |
| **Weakened** | Specific abilities/mods | Debuff: enemy deals reduced damage | Medium (4-6s) |
| **Slowed** | Various (non-Cryo sources: terrain, abilities) | Movement speed reduction only (lighter than Chilled) | Varies by source |
| **Rooted** | Specific abilities/mods | Cannot move but can still attack | Short (1-3s) |

### Status Interaction Rules

- Multiple different statuses CAN coexist on one entity (Burning + Chilled + Marked = all active)
- Status effects that conflict logically are resolved: Burning removes Frozen (but not Chilled). Frozen cannot be applied while Burning is active at high intensity.
- Synergy upgrades can reference specific statuses as triggers ("On applying Burning, deal bonus damage" or "Shocked enemies take +20% Cryo damage")

---

## Category 3: Weapon Behavior Types

Every weapon has a behavior type that defines its fire pattern. The behavior type is independent of damage type — a Projectile weapon can deal Physical, Fire, Void, or any other damage type.

### v1 Weapon Behaviors

| Behavior | Pattern | Range | Best Against | Weakness |
|----------|---------|-------|-------------|----------|
| **Projectile** | Single shot in a direction, travels in a line | Long | Single targets, ranged enemies | Low AOE, misses if enemies dodge |
| **Spread** | Multiple projectiles in a cone | Short-Medium | Close packs, wide groups | Damage falls off at range |
| **Beam** | Continuous stream in a direction | Medium-Long | Single high-HP targets (Brutes) | Narrow, can't hit multiple spread enemies |
| **Orbit** | Projectiles circle the player passively | Close (player radius) | Surrounding swarms | Doesn't reach ranged enemies |
| **AOE Burst** | Periodic explosion outward from the player | Medium radius | Dense hordes | Periodic, not constant. Enemies between bursts are safe. |
| **Melee** | Arc/swing around the player | Very close | Anything adjacent, high damage | Must be in danger zone to deal damage |
| **Homing** | Projectiles seek nearest enemy | Long | Ranged enemies, cleanup | Lower damage, less player control |
| **Artillery** | Fires at a target location, explodes on delay | Long (targeted) | Area denial, clusters | Delay means enemies may move. Prediction skill. |
| **Chain** | Hits one enemy, bounces to next closest | Medium | Spread-out groups | Fewer targets than true AOE |
| **Nova** | Expands outward from impact point | Medium radius from impact | Clustered enemies at a distance | Requires initial hit to trigger |

### v1.5 Weapon Behaviors

| Behavior | Pattern | Notes |
|----------|---------|-------|
| **Summon** | Creates a temporary entity (turret/drone/minion) that fights independently | Needs AI, pathfinding, lifetime management — a system, not just projectile math |

### Behavior + Damage Type = Weapon Identity

A weapon is defined by combining a behavior with a damage type (and stats). Examples:

| Weapon Concept | Behavior | Damage Type | Result |
|----------------|----------|-------------|--------|
| Standard Rifle | Projectile | Physical | Basic ranged weapon. Reliable. |
| Flamethrower | Beam | Fire | Continuous fire stream. Applies Burning. |
| Frost Shotgun | Spread | Cryo | Close-range cone of ice. Applies Chilled rapidly. |
| Lightning Orb | Orbit | Shock | Orbiting electric spheres. Shocked enemies near you. |
| Void Mortar | Artillery | Void | Targeted void explosion. Void-Touched on hit. |
| Arcane Blade | Melee | Physical | Wide arc swing. High damage, get in their face. |

Any behavior can combine with any damage type. This means 10 behaviors × 5 damage types = **50 possible base weapon archetypes** from vocabulary alone, before mods or stat variations.

---

## Category 4: Mod Effect Types

Mods attach to weapons and modify their behavior. Each mod has an effect type that changes how the weapon performs. Mods do NOT change the weapon's base behavior type — they augment it.

### v1 Mod Effects

| Mod Effect | What It Does | Example |
|-----------|-------------|---------|
| **Elemental Conversion** | Changes the weapon's damage type | Physical Rifle → Fire Rifle (now applies Burning) |
| **Pierce** | Projectiles pass through enemies instead of stopping | Projectile weapon hits entire line of enemies |
| **Split** | Projectiles split into smaller projectiles on hit or at max range | One shot becomes a cluster on impact |
| **Chain** | Hits bounce to additional nearby targets | Single-target weapon gains multi-target potential |
| **Explosive** | Hits cause a small AOE explosion at impact | Every hit has splash damage |
| **DOT Applicator** | Hits apply a DOT matching the weapon's damage type | Fire weapon guaranteed to apply Burning |
| **Lifesteal** | Percentage of damage dealt returns as HP | Sustain tool. Offsets aggressive play. |
| **Vampiric** | Kills with this weapon restore HP | Burst healing on kill. Rewards finishing enemies. |
| **Size Increase** | Projectiles and hitboxes are larger | Easier to hit, catches more enemies. Feels powerful. |
| **Gravity** | Projectiles pull enemies slightly toward their path | Crowd control utility. Groups enemies for AOE. |
| **Ricochet** | Projectiles bounce off walls and terrain | Arena geometry becomes part of the weapon's effectiveness |
| **Crit Amplifier** | Increased crit chance and crit damage for this weapon | Focused crit build enabler |
| **Instability Siphon** | Kills with this weapon reduce Instability slightly | Risk mitigation. Lets you carry more loot safely. |
| **Execution Enhancer** | Increased finisher radius and finisher rewards for this weapon | Finisher build enabler. More range, more reward. |
| **Accelerating** | Projectile speed or attack speed ramps up over time while firing | Rewards sustained engagement. Beam weapons love this. |

### Mod Stacking Rules

- A weapon can have 1-3 mod slots (depending on weapon rarity/type)
- The same mod type CANNOT be equipped twice on one weapon
- Different mods on the same weapon all apply simultaneously
- Some mod combinations are especially powerful (Pierce + Chain = projectile passes through AND bounces). These are discoverable synergies, not bugs.

---

## Category 5: Trigger/Proc Conditions

Triggers define WHEN an effect activates. Used by synergy upgrades, advanced mods, corruption upgrades, and character abilities.

### High-Frequency Triggers (Fire Often)

These triggers activate regularly during normal gameplay. Effects attached to these should be moderate — they'll proc constantly.

| Trigger | When It Fires | Frequency |
|---------|--------------|-----------|
| **On Hit** | Player damages an enemy | Very High (every attack that connects) |
| **On Kill** | Player kills an enemy | High (constant in a horde game) |
| **On Crit** | Player lands a critical hit | Medium-High (depends on Crit Chance stat) |
| **On Damage Taken** | Player takes damage | Medium (depends on build/skill) |
| **On Loot Pickup** | Extractable loot is collected | Medium (depends on Loot Find/phase) |
| **Periodic** | Every X seconds | Configurable (every 3s, 5s, 10s, etc.) |

### Low-Frequency Triggers (Fire Rarely)

These triggers activate infrequently. Effects attached to these MUST be dramatic and memorable — the player needs to feel the payoff. (Design Rule: If a trigger fires fewer than 5 times per run, its effect must be worth remembering.)

| Trigger | When It Fires | Frequency | Minimum Payoff Standard |
|---------|--------------|-----------|------------------------|
| **On Finisher** | Player executes a vulnerable enemy | Low-Medium | Strong — bonus loot, burst heal, AOE explosion |
| **On Dodge** | Player successfully dodges | Medium (build-dependent) | Moderate-Strong — brief invulnerability, counterattack |
| **On Low HP** | Player drops below 25% HP | Rare | Massive — emergency shield, speed burst, damage spike |
| **On Extraction Start** | Player begins channeling extraction | Very Rare (1-4 per run) | Massive — invulnerability bubble, AOE clear, guaranteed survival window |
| **On Phase Start** | New phase begins | Very Rare (4 per run) | Massive — full heal, temporary stat doubling, free upgrade choice |
| **On Level Up** | Player gains a level | Rare-ish (10-15 per run) | Strong — burst AOE, temporary buff, bonus pickup radius pulse |
| **On Instability Threshold** | Instability crosses into new tier | Very Rare (2-3 per run) | Massive — stat spike, visual transformation, temporary power mode |
| **On Status Apply** | A status effect is applied to an enemy | High (with elemental builds) | Moderate — bonus damage, spread effect, secondary proc |

**Design Rule for Low-Frequency Triggers:** If the player can't remember the last time a trigger fired, the effect wasn't big enough. Low-frequency triggers are moments, not background noise. "On Phase Start: +5% damage" is WRONG. "On Phase Start: fully restore HP and gain 5 seconds of invulnerability" is RIGHT.

---

## Category 6: Targeting Types

Targeting defines WHO or WHERE an effect applies. Used by weapons, abilities, mods, and triggered effects.

### v1 Targeting Types

| Targeting Type | What It Hits | Use Case |
|---------------|-------------|----------|
| **Self** | The player character | Buffs, heals, shields, self-targeted abilities |
| **Nearest Enemy** | Closest enemy to the player | Default for homing weapons, auto-targeted abilities |
| **Random Enemy** | Random enemy within range | Chaos effects, proc chains |
| **All in Radius (Point)** | All enemies within radius of a specific point | AOE explosions, artillery impacts, nova effects |
| **All in Radius (Self)** | All enemies within radius of the player | AOE bursts, orbit weapons, melee attacks |
| **All on Screen** | Every visible enemy | Rare, powerful. Screen-clear abilities. |
| **Aimed Direction** | Enemies in the direction of player movement/facing | Projectile weapons, beam weapons, spread weapons |
| **Ground Target** | A specific location on the ground | Artillery weapons, placed hazards, zone creation |
| **Highest HP Enemy** | Enemy with most remaining HP | Priority targeting for single-target weapons. Boss killers. |
| **Lowest HP Enemy** | Enemy with least remaining HP | Cleanup targeting. Finisher synergy. |
| **Status-Affected** | Only enemies with a specific status effect | Conditional targeting. "Only targets Burning enemies." Synergy enabler. |

---

## Vocabulary Stress Test

Per the methodology: take weird, out-there ideas and see if they can be described using only vocabulary terms. If they can, the vocabulary is complete.

### Test 1: "A weapon that freezes enemies, and frozen enemies explode when hit by fire"
- Weapon: Behavior(Spread) + DamageType(Cryo) → applies Chilled → stacks to Frozen
- Synergy Upgrade: Trigger(On Hit) + Condition(target is Frozen) + DamageType(Fire) → Effect: AOE Burst at target, removes Frozen
- **PASS.** Fully describable.

### Test 2: "A corruption upgrade that makes you deal double damage but every pickup increases difficulty"
- Corruption Upgrade: StatMod(Damage × 2.0) + Trigger(On Loot Pickup) + Effect(Instability + X%)
- **PASS.** Fully describable.

### Test 3: "A mod that makes your bullets bounce off walls and apply poison"
- Mod: Effect(Ricochet) + Effect(Elemental Conversion → Toxic [v1.5]) + Effect(DOT Applicator)
- **PASS.** Fully describable (Toxic is v1.5, but the vocabulary supports it).

### Test 4: "An ability that creates a safe zone around the extraction point while you're channeling"
- Active Ability: Trigger(On Extraction Start) + Targeting(All in Radius, Point: extraction location) + Effect(damage enemies in zone + push them out) + Duration(channel duration)
- **PASS.** Fully describable.

### Test 5: "A character whose weapons get stronger the more Instability they have"
- Character Passive: Trigger(On Instability Threshold) + Effect(StatMod: Damage scales with Instability %)
- Or as continuous: Stat formula where Damage has an Instability multiplier
- **PASS.** Describable as either a trigger or a stat formula.

### Test 6: "A Mimic enemy that disguises as a legendary weapon drop and explodes when you try to pick it up"
- Enemy Type: Visual(mimics loot visual hierarchy — legendary glow) + Trigger(player enters pickup radius) + Behavior(reveal + AOE Burst) + DamageType(Physical or Void)
- **PASS.** Fully describable.

### Test 7: "An evolution/fusion weapon that chains lightning between frozen enemies, shattering them all"
- Evolved Weapon: Behavior(Chain) + DamageType(Shock) + Targeting(Status-Affected: Frozen) + On Hit Effect(remove Frozen + AOE Burst at target, DamageType Cryo)
- This is the Cryo + Shock = Shatter secondary type from the v2 plan, achievable as an evolution recipe in v1
- **PASS.** Fully describable.

### Test 8: "The game gets visually darker and audio more distorted as Instability rises"
- Not a mechanical vocabulary item — this is a presentation/feedback layer that reads from the Instability value
- The vocabulary doesn't need to describe this; the Instability system already provides the data, and visual/audio presentation is a separate concern
- **PASS (out of scope for vocabulary, handled by presentation layer).**

**Vocabulary Status: COMPLETE for v1.** All tested scenarios are fully describable using the defined categories. No missing categories identified.

---

## Vocabulary Summary (Quick Reference)

| Category | Count (v1) | Purpose |
|----------|-----------|---------|
| Damage Types | 5 (Physical, Fire, Cryo, Shock, Void) | What kind of damage |
| Status Effects | 11 (7 combat + 4 mechanical) | Conditions on entities |
| Weapon Behaviors | 10 | How weapons attack |
| Mod Effects | 15 | How mods change weapons |
| Trigger Conditions | 14 (6 high-freq + 8 low-freq) | When effects activate |
| Targeting Types | 11 | Who/where effects apply |

**Total vocabulary terms: 66**

Every weapon, mod, enemy ability, upgrade, synergy, and corruption upgrade is a combination of these 66 terms. Adding content means combining existing terms, not building new systems.

---

## Vocabulary Expansion Roadmap

| Version | Additions |
|---------|-----------|
| v1.5 | Toxic + Radiant damage types, Corroded + Illuminated statuses, Summon weapon behavior |
| v2 | Secondary (mixed) damage types (Steam, Hellfire, Inferno, Shatter, Entropy, Surge) |
| Post-v2 | New mod effects, new trigger conditions, new targeting types as needed for content variety |

The vocabulary is designed to grow. Each new term expands the possibility space multiplicatively — adding 1 new damage type doesn't add 1 new option, it adds dozens of new combinations across weapons, mods, and synergies.

---

*Phase 5 (Mechanical Vocabulary) is complete. Every mechanical interaction in the game can now be described as a combination of vocabulary terms.*

*Next: Phase 6 — Asset Inventory. Before designing specific content, we catalogue what art, audio, and visual assets are available (free/open-source) and identify gaps. Design from constraints, not into constraints.*
