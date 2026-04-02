# Systems Design Document (Part 1)
### Phase 4 Output | Stats, Combat, and Upgrades

---

## System 1: Stat/Attribute System

**Purpose:** Define the numbers that describe every entity in the game. Every other system reads from these stats.

**Boundaries:** This system DEFINES stats and their ranges. It does NOT handle how stats change (that's the Upgrade System) or how they're used in formulas (that's the Combat System). This is the dictionary, not the grammar.

### Core Stats (Every Entity Has These)

**Offensive:**
| Stat | Description | Felt As |
|------|-------------|---------|
| Damage | Base damage per hit | Enemies die faster |
| Attack Speed | Rate of auto-attacks | More projectiles / swings on screen |
| Crit Chance | % chance of critical hit | Occasional big satisfying numbers |
| Crit Damage | Multiplier on crits (base 1.5x) | Crits feel impactful |
| AOE | Size of attack hitboxes | Attacks feel bigger, catch more enemies |
| Projectile Count | Number of projectiles per attack | Screen fills with more firepower |
| Projectile Speed | Velocity of projectiles | Snappier, more responsive attacks |
| Pierce | Enemies a projectile passes through | Shots feel powerful, cut through hordes |
| DOT | Damage over time from status effects | Enemies melt after being hit |

**Defensive:**
| Stat | Description | Felt As |
|------|-------------|---------|
| Health (HP) | Die at zero | Can take more hits before panicking |
| Armor | Flat damage reduction (subtract from each hit, minimum 1 damage) | Hits feel less threatening |
| Shield | Regenerating secondary HP | Safety buffer that refills, less cautious play |
| Dodge Chance | % to avoid damage entirely | Satisfying "miss" moments in dense fights |
| Health Regen | Passive HP/sec recovery | Can recover from mistakes over time |
| Damage Resistance | Reduction to specific damage types | Resilience against certain enemies/phases |
| Knockback Resistance | Resist displacement | Staying in position, feeling immovable |

**Utility:**
| Stat | Description | Felt As |
|------|-------------|---------|
| Movement Speed | How fast you move | Responsive, zippy, can outrun threats |
| Pickup Radius | Collection range for items | Vacuuming up loot and XP without effort |
| XP Gain | Bonus to experience earned | Leveling up faster, more upgrade choices |
| Loot Find | Increased drop chance/quality | More shiny things on the ground |
| Cooldown Reduction | Abilities recharge faster | Abilities feel available more often |
| Luck | Affects random rolls across the board | "Everything is going my way" feeling |
| Vision/Reveal Radius | How far you can see in dark phases | Safety, awareness, atmosphere interaction |

### Derived/Contextual Stats (From Upgrades, Mods, or Effects — Not Base Stats)

These are powerful concepts that emerge from the upgrade, mod, and corruption systems rather than being numbers on every entity:

| Stat/Effect | Source | Description |
|-------------|--------|-------------|
| Greed | Upgrade/Mod effect | Increases loot find but also increases enemy difficulty. Pure risk/reward. |
| Depth Attunement | Upgrade/Mod effect | Stronger in deeper phases, weaker in early ones. Rewards pushing deep. |
| Extraction Speed | Base stat on some characters, moddable | How fast you activate an extraction point. Life or death in tense moments. |
| Instability | Passive system effect | Rises as you carry more valuable loot. More loot = harder enemies/wilder effects. The game punishes hoarding. Directly serves extraction tension. |
| Elemental Affinity | Weapon/Mod property | Bonus to a specific damage type. Emerges from loadout, not base stats. |

### Design Notes
- Stats must be FELT, not just read. Every stat increase should produce a noticeable gameplay change.
- Stat ranges and scaling formulas are defined in Core Framework Decisions.
- Enemies have a subset of these stats (primarily HP, Damage, Movement Speed, Armor, and any special properties). Not every stat applies to every entity.

---

## System 2: Combat System

**Purpose:** Define how fighting works moment-to-moment. This is the core verb for 90% of a run.

**Boundaries:** This system handles attacks, damage, targeting, and moment-to-moment combat feel. It does NOT handle what weapons exist (that's content), how the player gets stronger (that's Upgrades), or what enemies do specifically (that's Enemy System). This is the engine, not the fuel.

### Combat Model: Hybrid Auto-Attack + Active Abilities

**Movement:** Player moves freely in top-down 2D (WASD or controller stick). Movement is the primary skill expression — positioning matters constantly.

**Auto-Attacks:** Equipped weapons fire automatically based on their weapon type patterns (interval, direction, spread, etc.). The player does not aim or trigger basic attacks. This keeps the cognitive load on positioning and decisions, not mechanical inputs.

**Active Abilities:** The player has 1-2 active ability slots with manual activation and cooldowns. These are the skill-expression moments — a dash to reach an extraction point, a burst ability to clear a path, a shield for a clutch survival moment. Active abilities can come from character kits, weapons, or upgrades.

**Why Hybrid?** Auto-attacks handle the constant horde pressure (satisfying, low effort, screen full of action). Active abilities create deliberate, high-impact moments where the player's skill and timing matter. This serves both casual players (auto-attacks carry them) and skilled players (ability timing separates good from great).

### Weapon Slots

The player has **1 weapon slot at start, expandable to a maximum of 3 via hub upgrades** (Armory Expansion I and II).

- Weapons fire simultaneously in their own patterns (like Vampire Survivors)
- Each weapon has its own stats (damage, attack speed, projectile behavior, etc.)
- Each weapon has 1-3 mod slots depending on rarity (Common/Uncommon: 1, Rare/Epic: 2, Legendary: 3)
- Weapons are LOOT — found during runs, extractable to keep permanently
- The combination of weapons + mods IS the player's build identity for that run
- **Depth comes from mod combinations, not weapon count.** 3 weapons × up to 3 mods each = 12 gear decisions per run, plus passives, abilities, corruption upgrades, and extraction perks.

**Weapons as Extraction Loot:** Finding a powerful weapon during a run creates an instant extraction tension moment: "This weapon is amazing. Do I extract now to keep it, or keep going and risk losing it?"

### Finisher/Execution Mechanic

Enemies at low HP (below 10-15% threshold) enter a **vulnerable/staggered state** (visual indicator — flickering, staggered, glowing).

- **Auto-triggers on proximity:** Moving within finisher radius of a staggered enemy executes the finisher automatically. No button press required — consistent with the auto-attack philosophy of keeping cognitive load on positioning, not inputs.
- Finishers grant bonus rewards: extra XP, higher loot drop chance, or specific resource drops
- **Risk/reward:** You have to get close to a potentially dangerous enemy cluster to execute. Is the bonus worth the risk?
- Ties into build diversity: some builds invest in finisher bonuses (execution radius, execution rewards), others ignore it entirely

### Environmental Hazards

Hand-designed arenas include environmental hazards that affect BOTH player and enemies:

- **Damage Zones** — areas that deal damage over time (energy fields, toxic pools, unstable ground)
- **Displacement Hazards** — things that push entities (vents, gravitational anomalies, collapsing terrain)
- **Terrain Blockers** — obstacles that block movement and projectiles (pillars, walls, debris)
- **Traps** — triggered hazards (pressure plates, proximity mines, falling objects)

**Design principle:** Hazards are tools, not just threats. A skilled player uses hazards to their advantage — kiting enemies through damage zones, using pillars as cover, triggering traps on pursuing hordes. This adds spatial strategy without adding input complexity.

### ~~Overcharge Mechanic~~ → MOVED TO v1.5

*Rationale: The weapon slot system (multiple weapons firing simultaneously) and weapon mod variety already incentivize diverse weapon use. Overcharge adds a punishment system requiring its own UI, tuning, and edge-case handling for a problem that's largely already solved. Revisit post-launch if weapon spam becomes an issue.*

### Combat Feel Principles (Non-Negotiable)
- **Juice is mandatory.** Screen shake on big hits. Hit flash on enemies. Satisfying death animations. Damage numbers. Pickup sounds. The game must FEEL impactful.
- **Enemy deaths should be satisfying.** Enemies should pop, burst, dissolve, shatter — not just disappear. Each kill is a micro-reward.
- **Readability over spectacle.** When there are 200 enemies on screen, the player must still be able to see: their character, dangerous enemies/attacks, pickups, and extraction points. Visual hierarchy matters.

---

## System 3: Upgrade/Build System

**Purpose:** How the player gets stronger during a run and across runs. This is what makes each run feel different and drives the "one more run" pull.

**Boundaries:** This system handles upgrade choices, weapon mods, build construction, and power progression. It does NOT handle specific upgrade/weapon content (that's data defined later), combat math (that's Combat System formulas), or meta-progression spending (that's Meta-Progression System).

### In-Run Progression: Level-Up Choices

**XP → Level Up → Choose an Upgrade**

Target: **15-20 level-ups per full run** (through Phase 5). Front-loaded — several in Phase 1 (feels good, build takes shape fast), fewer in Phase 5 (focused on survival and extraction).

When the player levels up, they're presented with upgrade choices:

- **Tiered choices with reroll:** Normally 3-4 options of varying rarity (Common, Uncommon, Rare, Epic). Rarity of options is influenced by Luck stat and current phase depth.
- **Reroll system:** Limited uses per run. Base 2 rerolls, upgradeable to 4 via Workshop (Reroll Capacity I: 2→3, Reroll Capacity II: 3→4). Each reroll gives a fresh set of options. Scarcity makes each reroll a meaningful decision.
- **Rarity tiers:** Common (stat boosts, basic effects) → Uncommon (notable effects, minor synergies) → Rare (powerful effects, clear build-defining) → Epic (game-changing, rare to see). Legendary upgrades exist but only appear in Phase 4-5 or through Evolution.

### Upgrade Categories

**Weapons:** New weapons added to your loadout. Occupy weapon slots. Each has a distinct fire pattern and stat profile.

**Weapon Mods:** Attachments that modify a specific equipped weapon.
- Mods snap onto weapon mod slots (Common/Uncommon weapons: 1 slot, Rare/Epic: 2 slots, Legendary: 3 slots)
- Mods change how the weapon feels and performs (pierce mod, split shot mod, DOT mod, AOE mod, etc.)
- The same weapon with different mods plays differently — a basic rifle + pierce mod vs. basic rifle + chain lightning mod = two different experiences
- Mods are LOOT — findable during runs, extractable, and equippable at the hub for future runs
- **Mod as extraction loot:** Like weapons, finding a great mod creates extraction tension. "This mod would complete my build for future runs. Do I extract now to keep it?"

**Passive Upgrades:** Flat stat bonuses and effects that apply globally.
- +X% Damage, +X Armor, +X Pickup Radius, etc.
- Some have conditional triggers: "When below 50% HP, gain +30% Movement Speed"
- Stack and compound — multiple small passives create significant power

**Active Abilities:** Abilities assigned to active ability slots.
- Dash, Shield Burst, AOE Nuke, Gravity Pull, etc.
- Can be upgraded when seen again (Level 1 → Level 2 → Level 3, like VS)
- Active abilities can come from level-up choices, weapon set bonuses, or character kits

**Synergy Triggers:** Upgrades that do nothing alone but combo with other upgrades.
- "When you crit, release a shockwave" (needs crit chance to function)
- "Fire damage applies Burn. Burn damage has a chance to spread." (needs a fire weapon)
- "Enemies killed by DOT effects explode" (needs DOT sources)
- These are the "discovery" upgrades — when a player realizes two things combo together, that's a high-dopamine moment

**Extraction Perks:** Upgrades specific to the extraction mechanic (UNIQUE TO THIS GAME).
- Faster extraction activation speed
- Bonus loot multiplier on successful extraction
- Emergency extraction (auto-extract at X% HP, once per run)
- Extraction shield (temporary invulnerability while extracting)
- These perks create a build sub-archetype: the player who invests in extraction perks is playing a different game than the player who goes pure damage

### Corruption Upgrades (v1 Feature — Directly Serves Extraction Tension)

Corruption upgrades are powerful options with an explicit downside:

- "+50% Damage, but extraction takes twice as long"
- "+100% Loot Find, but enemies deal +25% damage"
- "Gain an extra weapon slot, but lose 30% max HP"
- "Legendary drops can appear in Phase 2+, but Instability rises 50% faster"

**Why these are essential for v1:** Every corruption upgrade is a miniature extraction decision. You're trading safety for power or loot, which is the core tension of the entire game. A player who takes three corruption upgrades is playing with fire — they're more powerful but extracting is harder. This is the extraction-survivors hybrid in microcosm.

### Evolution/Fusion System (v1 Feature)

Specific upgrade combinations fuse into a super-upgrade:

- Weapon A + specific Mod + specific Passive = Evolved Weapon (dramatically more powerful, unique visual/behavior)
- **15+ evolution recipes at launch.** Enough for community discovery and multiple recipes per weapon behavior archetype.
- Evolutions are discoverable (not spelled out) — players share them, write guides, datamine them. Community engagement driver.
- Evolutions also appear as lore-relevant combinations (thematic fusions, not random pairings)

### Scope Notes (v1 vs Later)

| Feature | Version | Rationale |
|---------|---------|-----------|
| Tiered choices + limited rerolls | v1 | Core upgrade presentation. Base 2 rerolls, upgradeable to 4 via hub. |
| Weapons + Weapon Mods | v1 | Core build identity, key extraction loot |
| Passive Upgrades | v1 | Genre staple, must have |
| Active Abilities | v1 | Hybrid combat model requires these |
| Synergy Triggers | v1 | Creates depth and discovery |
| Extraction Perks | v1 | Unique to this game, serves extraction tension |
| Corruption Upgrades | v1 | Directly serves core tension |
| Evolution/Fusion (15+ recipes) | v1 | Build goals + community engagement |
| Overcharge Mechanic | v1.5 | Weapon slots already encourage variety; adds UI/tuning cost for marginal benefit |
| Sacrifice Mechanic (destroy upgrade for better one) | v1.5 | Good idea but not essential for launch |
| Loot-Linked Upgrades (power scales with carried loot) | v1.5 | Cool but adds complexity, can be added later |

---

## System Connections (How These Three Talk to Each Other)

```
STAT SYSTEM (defines the numbers)
    ↓ read by
COMBAT SYSTEM (uses stats in damage/defense formulas, applies stat effects)
    ↓ feeds into
UPGRADE SYSTEM (modifies stats, adds weapons, creates build identity)
    ↓ loops back to
COMBAT SYSTEM (upgraded stats change combat performance)
```

**Data flow example:**
1. Player has a weapon with 10 base Damage and a Fire DOT mod
2. Player attacks an enemy → Combat System reads Damage stat, applies hit
3. Fire DOT mod triggers → Combat System applies DOT based on DOT stat
4. Enemy dies → drops XP → player levels up → Upgrade System presents choices
5. Player picks "+20% Crit Chance" → Stat System updates Crit Chance
6. Next attack → Combat System reads new Crit Chance, rolls crit, applies Crit Damage multiplier (1.5x base)
7. Player has synergy upgrade "Crits release shockwave" → shockwave triggers on crit
8. Shockwave kills nearby enemies → more XP, more drops, more loot to agonize over extracting with

---

## Resolved Decisions (Previously Open Questions)

| Question | Decision | Rationale |
|----------|----------|-----------|
| Weapon slot count | 1 starting, max 3 via hub | Depth comes from mod combinations, not weapon count |
| Mod slots per weapon | 1-3 based on rarity (C/U: 1, R/E: 2, L: 3) | Scales naturally with loot quality |
| Instability scaling | Breakpoint tiers (Stable/Unsettled/Volatile/Critical) | See Core Framework Decisions for exact thresholds |
| Evolution recipes at launch | 15+ | Community discovery driver |
| Reroll currency | Limited uses per run (base 2, upgradeable to 4 via hub) | Simple, no extra economy to track |
| Overcharge + abilities | N/A — Overcharge deferred to v1.5 | Not needed with weapon slot system |
| Finisher activation | Auto-trigger on proximity | Matches auto-attack philosophy |

---

*Next: Systems 4-6 (Enemies, Loot, Extraction). These systems consume what we've defined here — enemies USE stats, loot FEEDS upgrades, extraction RISKS everything.*
