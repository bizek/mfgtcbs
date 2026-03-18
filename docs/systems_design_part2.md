# Systems Design Document (Part 2)
### Phase 4 Output | Enemies, Loot, and Extraction

---

## System 4: Enemy System

**Purpose:** Define what enemies are as data, what types exist, how they behave, and how they scale across phases.

**Boundaries:** This system defines enemy types, behaviors, and scaling patterns. It does NOT handle specific enemy content (individual enemy designs with exact stats — that's Phase 10 data). It does NOT handle combat math (that's the Combat System). This defines the categories and rules; content fills them later.

### Enemy Data Structure

Every enemy is defined by:
- **Role** — its category (Fodder, Swarmer, Brute, etc.)
- **Stats** — subset of the Stat System (HP, Damage, Movement Speed, Armor, plus any special properties)
- **Behavior Pattern** — how it moves, targets, and attacks
- **Phase Range** — which phases it can appear in
- **Loot Table** — what it can drop (references Loot System)
- **Visual/Audio Profile** — what it looks like, what sounds it makes (defined later with assets)

### Enemy Roles

| Role | Speed | HP | Damage | Count | Purpose |
|------|-------|----|--------|-------|---------|
| Fodder | Slow | Very Low | Low | Massive | XP pinatas. The horde. Satisfying to mow down. |
| Swarmer | Fast | Low | Low-Med | Large packs | Pressure positioning. Dangerous in volume. |
| Brute | Slow | High | High | Few | Demands attention. Blocks paths. Priority threat. |
| Ranged/Caster | Stationary/Slow | Medium | Medium | Moderate | Forces movement. Creates danger zones. Priority target. |
| Elite | Varies | Boosted | Boosted | Rare | Amped-up version of any role with special modifiers. Mini-challenge. |
| Miniboss | Slow | Very High | Very High | 1-2 per phase | Guards extraction points. Unique attack patterns. Event-level enemy. |

### Special Enemy Types (v1)

**Stalkers** — Invisible until within a close range of the player. Sudden appearance with a distinct audio sting. Low HP but high burst damage. Terrifying in dark, deep phases. Force the player to stay alert even when the screen seems clear. Appear Phase 3+.

**Mimics** — Disguised as loot pickups (weapons, mods, resources). When the player gets within pickup radius, the mimic reveals itself and attacks. Punishes autopilot. Rewards attentive players who notice subtle visual tells (slightly wrong color, faint movement). Appear Phase 2+. Extremely on-brand for an extraction game — even the loot is dangerous.

**Heralds** — Don't attack directly. Emit an aura that buffs all nearby enemies (damage, speed, or armor). Fragile but high priority — killing the Herald immediately weakens the surrounding group. Creates triage decisions: do I focus the Herald or deal with the immediate threats? Appear Phase 3+.

**Anchors** — Plant themselves in a location and create a persistent damage/slow zone. Area denial. Force the player out of comfortable kiting paths and into new territory. Must be killed to remove the zone. Appear Phase 2+.

**Carriers** — Contain guaranteed valuable loot but attempt to FLEE the player rather than attack. Fast, evasive, low HP but hard to pin down. Chasing a Carrier pulls you out of position and into danger. Risk/reward: the loot is worth it, but the chase might kill you. Appear Phase 2+.

**Phase-Warped** — Phase 5 exclusive enemies. Visually alien — distinct from everything in earlier phases. Unusual movement patterns, unfamiliar attacks. Exist to make Phase 5 feel like you've crossed into somewhere you don't belong. Mechanically they use the same data structure as other enemies, just with unique behavior patterns and stats. Atmosphere-first design.

### Special Enemy Types (v1.5 — Post-Launch)

**Parasites** — Attach to the player on contact. While attached: disable one weapon slot or drain a stat. Removed by specific actions (dash ability, taking damage, reaching a cleanse zone). Needs a unique attachment/debuff system.

**Hive Minds** — A cluster of linked enemies sharing an HP pool. Must be killed simultaneously (or near-simultaneously) with AOE — otherwise they regenerate. Needs a linked-entity health system.

**Phase Bosses** — Dedicated boss encounters at the end of specific phases. Unique arenas, scripted attack patterns, significant health pools. The escalating horde + minibosses at guarded extractions serve a similar role for v1 at much lower scope cost. Revisit post-launch.

### Elite Modifiers

Elites are any base enemy type with 1-2 modifiers applied:

- **Shielded** — Has a shield that must be broken before HP damage applies
- **Splitting** — On death, splits into 2-3 smaller versions of itself
- **Exploding** — On death, detonates in an AOE. Punishes melee/close builds.
- **Vampiric** — Heals on hit. Must be burst down or it sustains forever.
- **Hasting** — Periodically surges to double speed for a few seconds.
- **Reflecting** — Returns a percentage of damage taken back to attacker. Punishes glass cannons.
- **Summoning** — Periodically spawns fodder enemies. Must be prioritized.

Modifiers are data flags, not unique systems. Easy to add more post-launch.

### Enemy Scaling Across Phases

| Phase | Composition | Density | Elite Chance | Special Types |
|-------|------------|---------|-------------|---------------|
| Phase 1 — The Threshold | 80% Fodder, 20% Swarmers | Low | None | None |
| Phase 2 — The Descent | 50% Fodder, 25% Swarmers, 15% Brutes, 10% Ranged | Medium | Low (~5%) | Mimics, Anchors, Carriers |
| Phase 3 — The Deep | 30% Fodder, 25% Swarmers, 20% Brutes, 15% Ranged, 10% Elite | High | Medium (~15%) | + Stalkers, Heralds |
| Phase 4 — The Abyss | 20% Fodder, 20% Swarmers, 25% Brutes, 20% Ranged, 15% Elite | Very High | High (~25%) | All special types active |
| Phase 5 — The Core | Everything + Phase-Warped | Maximum | Very High (~40%) | Phase-Warped enemies dominate |

**Minibosses** appear guarding extraction points at any phase. Their stats scale with the current phase.

---

## System 5: Loot System

**Purpose:** Define what drops, what's valuable, what the player extracts with, and how loot drives both in-run excitement and between-run progression.

**Boundaries:** This system defines loot categories, drop mechanics, and the Instability system. It does NOT handle specific loot content (individual weapons/mods — that's data). It does NOT handle what happens with loot at the hub (that's Meta-Progression). It does NOT handle upgrade choices during level-ups (that's the Upgrade System). This is about what falls on the ground and why it matters.

### Core Principle: No Manual Looting

All pickups are **auto-collected** within the player's Pickup Radius. There is no manual loot interaction, no inventory management screen, no "press E to pick up." The player moves through the battlefield and things get collected. This keeps the pace fast, the dopamine constant, and respects the player's time (Pillar 2).

Pickup Radius is one of the most satisfying stats to upgrade — turning the player into a loot vacuum that hoovers up everything on screen.

### No Inventory Limit

The player can carry unlimited extractable loot. There are no "drop this to pick up that" decisions. The Instability system serves as the natural check on hoarding — the more you carry, the harder the game gets. The tension is "do I extract with all this?" not "which of these do I keep?"

### Pickup Streams

Two distinct streams of pickups exist on the battlefield:

**Run Pickups (Non-Extractable — Lost When Run Ends Regardless):**
| Pickup | Source | Purpose |
|--------|--------|---------|
| XP Gems | All enemy kills | Level up → upgrade choices |
| In-Run Currency | Enemy kills, breakables | Reroll upgrade choices during level-up |
| Health Orbs | Enemy kills (low chance), breakables | Sustain during combat |

**Extractable Loot (Kept on Successful Extraction — Lost on Death):**
| Pickup | Source | Rarity | Purpose |
|--------|--------|--------|---------|
| Resources | All enemies (scaling amount by phase) | Common | Universal currency for hub spending |
| Weapons | Elite/Miniboss kills, Carriers, hidden spots | Uncommon-Legendary | Equippable gear for future runs |
| Weapon Mods | Elite/Miniboss kills, Carriers, hidden spots | Uncommon-Legendary | Attach to weapons, modify behavior |
| Blueprints | Phase 2+ drops, miniboss kills | Rare-Epic | Unlock new items in future run drop pools |
| Artifacts | Phase 3+ drops, miniboss kills, locked caches | Rare-Legendary | Powerful passive equippables (limited slots at hub) |
| Lore Fragments | Hidden arena locations, rare drops | Uncommon | World-building collectibles. No mechanical value. |
| Keystones | Rare elite drops, hidden arena locations | Rare | Keys for Locked Extraction points. Used within the run, not extracted. |

### Loot Visual/Audio Hierarchy

Loot must be instantly readable on a chaotic screen (Master Rule: information before decision):

- **Resources** — Small, subtle pickup. Quiet sound. Constant background collection.
- **Weapons/Mods** — Larger pickup with a glow. Distinct sound. Player should notice.
- **Blueprints/Artifacts** — Prominent visual effect (beam of light? pulsing glow?). Attention-grabbing sound. This is a moment.
- **Keystones** — Unique visual unlike anything else. Unmistakable. Finding one should feel like an event.
- **Lore Fragments** — Subtle but distinct. Players who care will recognize them; players who don't won't be distracted.

### Loot Quality Scaling by Phase

| Phase | Resource Amount | Weapon/Mod Rarity | Blueprint Chance | Artifact Chance | Keystone Chance |
|-------|----------------|-------------------|-----------------|-----------------|-----------------|
| Phase 1 | Low | Common-Uncommon | None | None | None |
| Phase 2 | Medium | Uncommon-Rare | Low | None | None |
| Phase 3 | High | Rare-Epic | Medium | Low | Low |
| Phase 4 | Very High | Epic-Legendary | High | Medium | Medium |
| Phase 5 | Maximum | Legendary (exclusive pool) | Guaranteed | High | High |

### Instability System

**Core Mechanic:** As the player accumulates extractable loot during a run, a hidden (or visible? — TBD) **Instability value** rises. Higher Instability = harder enemies.

**How It Scales:**

| Instability Level | Trigger | Effect |
|-------------------|---------|--------|
| Stable (0-25%) | Early run, minimal loot | No effect. Baseline difficulty. |
| Unsettled (25-50%) | Moderate loot accumulated | Enemies gain +10-15% stats. Subtle. Player might not consciously notice. |
| Volatile (50-75%) | Significant loot haul | Enemies gain +25-30% stats. Elite spawn rate increases. Noticeable difficulty shift. |
| Critical (75-100%) | Massive loot haul / deep phase | Enemies gain +50%+ stats. Elite modifiers stack (enemies get 2 modifiers). Environmental hazards intensify. You are being hunted. |

**Design Notes:**
- Instability should be VISIBLE to the player (a meter, a visual effect on the screen edges, a color shift in the environment). Information before decision (Master Rule 2). The player should know they're carrying too much and the world is reacting.
- Different loot types contribute different Instability amounts (a Legendary weapon adds more than a handful of resources)
- Instability resets to zero on extraction or death
- Certain upgrades and corruption perks interact with Instability (Greed increases it faster, some perks reduce it, etc.)

### Cursed Loot (v1)

Some loot drops are **Cursed** — visually distinct (different color, ominous particles).

- Cursed items are significantly more powerful than their normal counterparts
- Picking up a Cursed item adds a large chunk of Instability
- The player can see it's cursed before walking into pickup radius (visual tell from a distance)
- Creates an instant micro-decision: "That cursed weapon is amazing, but it'll push me to Volatile Instability. Is it worth it?"
- Simple to implement — just a flag on the loot data that adds bonus Instability on pickup

### Insurance (v1 — Hub Feature)

A hub upgrade that allows the player to **insure** one item before a run begins.

- If the player dies, the insured item is saved (returned to hub inventory)
- Cost: significant resource investment per use. Not cheap.
- Only one item can be insured per run
- Creates a strategic pre-run decision: "Which item am I most afraid to lose? That's the one I insure."
- Also serves as a resource sink to prevent currency hoarding at the hub

### v1.5 Loot Features

- **Loot Echoes** — After extracting a rare item, ghost versions have a small chance to appear in future runs. Needs cross-run tracking.
- **Loot Magnets** — Environmental objects that attract nearby loot to one spot. Needs physics/attraction system.

---

## System 6: Extraction System

**Purpose:** The mechanical details of how extraction works. This is the system that defines the game's identity.

**Boundaries:** This system handles extraction point spawning, activation, and rewards. It does NOT handle what loot exists (that's Loot System) or what you do with extracted loot (that's Meta-Progression). This is the exit door — how it opens, what it costs to use, and what happens when you walk through it.

### Extraction Type 1: Timed Extraction (The Reliable Option)

**When:** End of each phase (Phases 1-4). Does not appear mid-phase.

**Spawn Behavior:**
1. Phase ends (final wave cleared or timer threshold reached)
2. 10-second warning: audio cue + visual indicator showing WHERE the portal will appear
3. Portal materializes at the designated arena location
4. Active window: 15-20 seconds
5. Portal closes. Next phase begins.

**Activation:**
- Player enters the extraction zone (visible radius around the portal)
- Channeled activation: 3-5 seconds of standing in the zone
- Enemies do NOT stop spawning during the extraction window
- Taking damage during channel: does NOT interrupt, but the player must survive the channel duration
- Visual feedback: progress bar or ring filling around the player during channel

**Design Rationale:** This is the "baseline" extraction. Predictable, learnable, always there. New players learn the extraction concept through this type. The tension comes from positioning (being on the wrong side of the arena when it spawns) and surviving the channel under fire.

### Extraction Type 2: Guarded Extraction (The Costly Option)

**When:** A guarded extraction point is present in the arena from the start of the run (or appears starting at a specific phase — TBD).

**Spawn Behavior:**
- Fixed location in the arena, visible from the beginning
- A miniboss-tier guardian stands on the point
- Guardian scales with current phase (fighting it in Phase 1 is easy; Phase 4 is a real fight)

**Activation:**
1. Player kills the guardian
2. Extraction point activates for a limited window (20-30 seconds — longer than timed, since you earned it)
3. Same channeled activation as timed extraction
4. After window closes, a new (harder) guardian spawns after a delay

**Design Rationale:** This is the "I need to leave NOW" option, but it has a price. The guardian fight costs health, ability cooldowns, and time. Rewards aggressive/skilled players. Also creates an interesting strategic option: some builds might specifically optimize for guardian killing, making this their primary extraction method.

### Extraction Type 3: Locked Extraction (The Jackpot Option)

**When:** Appears in Phase 3+ only. A sealed extraction point visible but inactive.

**Spawn Behavior:**
- Sealed point appears in the arena at Phase 3
- Distinct visual: clearly an extraction point, clearly locked
- Remains visible and locked until a Keystone is used on it

**Activation:**
1. Player finds a Keystone during the run (rare drop or hidden location)
2. Player moves to the locked extraction point
3. Uses the Keystone → extraction activates immediately (instant or very fast channel — the cost was finding the key)
4. Extraction is one-use (Keystone is consumed)

**Bonus:** Locked extraction grants a loot multiplier on all extracted loot:
- Used in Phase 3: +25% loot value bonus
- Used in Phase 4: +50% loot value bonus
- Used in Phase 5: +100% loot value bonus

**Design Rationale:** This is the "lucky find" extraction. Finding a Keystone is an event. The decision of WHEN to use it (now for safety, or later for a bigger bonus) is one of the most interesting decisions in the game. Directly serves Pillar 1.

### Extraction Type 4: Sacrifice Extraction (v1 — The Desperate Option)

**When:** Available from Phase 2+. A secondary extraction point that requires a sacrifice to activate.

**Spawn Behavior:**
- Appears in the arena at Phase 2 or later
- Visually distinct: ominous, different from other extraction types
- Always visible, always available (no window, no guardian)

**Activation:**
1. Player enters the sacrifice extraction zone
2. Must SELECT one piece of extractable loot to sacrifice (destroyed permanently)
3. Extraction activates immediately after sacrifice
4. Player extracts with everything EXCEPT the sacrificed item

**Design Rationale:** This is the "agonizing choice" extraction. You can leave anytime, but it costs you something. Which item do you sacrifice? Your worst item (easy choice, low tension)? Or your best item because you're about to die and saving everything else is worth more (brutal choice, maximum tension)? The selection UI is simple — a quick list of carried loot, tap one to sacrifice. Minimal engineering cost.

### Extraction Reward Scaling

Successful extraction grants:
- **All carried extractable loot** (minus sacrificed item if using Sacrifice Extraction)
- **Full meta XP** for the run (based on enemies killed, phases completed, depth reached)
- **Extraction bonus** scaling with depth:

| Extract From | Loot Bonus | Meta XP Bonus |
|-------------|-----------|---------------|
| Phase 1 | None | None |
| Phase 2 | +10% resources | +10% XP |
| Phase 3 | +25% resources | +25% XP |
| Phase 4 | +50% resources | +50% XP |
| Phase 5 | +100% resources | +100% XP |

Locked Extraction bonus stacks on top of phase bonus.

### Death Penalty (Confirmed)

- **All extractable loot: LOST**
- **Meta XP: earned at penalized rate (~25-33% of what a successful extraction would have granted)**
- **Run pickups: inherently gone (only existed within the run)**
- **Insured item (if any): SAVED** (returned to hub)

### Extraction Feel Principles

- **Extraction should feel like an ESCAPE, not a menu option.** The audio, visuals, and mechanical pressure during extraction should create genuine tension.
- **The player should always know where extraction options are.** Extraction points should be visible, marked on any minimap, and never hidden. Information before decision.
- **Extraction is a REWARD, not a punishment for leaving.** The game should never make the player feel bad for extracting early. A Phase 2 extraction with good loot is a win.

### v1.5 Extraction Features

- **Unstable Extraction** — Mid-phase flickering portal. High skill/awareness reward. Needs its own spawn/timing system.
- **Corrupted Extraction** — Extract with a debuff carried into next run. Needs cross-run state tracking.
- **Chain Extraction** — Send one item to safety mid-run. Undermines the all-or-nothing tension; revisit only if testing shows death penalty is too harsh.

---

## How Systems 4-6 Connect

```
ENEMY SYSTEM (creates threats)
    ↓ killed by
COMBAT SYSTEM (player fights enemies using stats/weapons)
    ↓ enemies drop
LOOT SYSTEM (pickups appear on battlefield)
    ↓ loot accumulates
INSTABILITY (difficulty rises with loot carried)
    ↓ creates pressure toward
EXTRACTION SYSTEM (player decides when to leave)
    ↓ successful extraction feeds
META-PROGRESSION (hub, unlocks, next run)
```

**Gameplay moment example:**
1. Player is in Phase 3. Build is clicking — AOE fire weapon + DOT synergy melting waves.
2. A Carrier enemy appears. Player chases it across the arena, kills it. It drops a Rare weapon mod.
3. Mod auto-collects. Instability ticks up to Volatile. Enemies noticeably get tougher.
4. Player spots the Locked Extraction. They found a Keystone earlier from an Elite kill.
5. Timed extraction portal warning plays. 10 seconds until it opens at the far end of the arena.
6. Decision: Use the Keystone on the Locked Extraction for a +25% bonus right now? Run to the Timed Extraction for a safe standard exit? Or push into Phase 4 where that Keystone is worth +50% bonus but Instability is already Volatile?
7. Player pushes to Phase 4. Enemies are brutal. They're at 30% HP. The guardian on the Guarded Extraction is a Phase 4 miniboss.
8. They use the Keystone on the Locked Extraction. +50% bonus on everything. They extract. Victory.
9. At the hub: resources spent on unlocks, new weapon mod equipped for next run, lore fragment reveals a piece of the world's story.

---

## Open Questions (For Remaining Systems)

- What does the hub look like and how does spending work? (System 7: Meta-Progression)
- How are arenas structured? How do phase transitions work spatially? (System 8: Level/Arena System)
- Is Instability visible as a number, a meter, or an environmental effect? (Visual design question)
- How many arenas per phase at launch? (Content scope question)
- What's the minimap situation? (UI question for architecture phase)

---

*Next: Systems 7-8 (Meta-Progression and Level/Arena System). These are the bookends — what happens between runs, and what the runs look like spatially.*
