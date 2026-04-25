# Mod Interaction Matrix

**69 authored doubles, 8 authored triples, ~150+ emergent triples possible.**

Every mod pair has a defined interaction. Named combos have unique mechanical effects. Stat mod interactions are scaling notes rather than named combos unless the combination is particularly distinctive. Numbers are placeholders — balance pass comes later.

---

## Mod Reference

| Category | Mods |
|----------|------|
| **Behavior** | Pierce, Chain, Explosive, Split, Gravity, Ricochet |
| **Elemental** | Fire, Cryo, Shock, DOT Applicator |
| **Stat** | Lifesteal, Size, Crit Amplifier |
| **Unique** | Instability Siphon, Accelerating |

---

## 1. Behavior × Behavior

15 pairs. Each produces a visually distinct projectile behavior.

| Pair | Combo Name | Mechanic | Fantasy |
|------|-----------|----------|---------|
| **Pierce + Chain** | **Shrapnel Storm** | Projectile pierces up to 3 enemies; each pierced enemy also chains to the nearest un-pierced enemy within 120px at 60% damage. One shot can trigger 3 separate chain arcs. | The bullet tears through a crowd and pulls everyone around it into the carnage. |
| **Pierce + Explosive** | **Tunnel Bomb** | Projectile pierces silently through all targets. On pierce-expiry (after the 3rd enemy or natural range end), a delayed explosion fires backward along the travel path, dealing full AoE damage to all previously pierced enemies simultaneously. | You watch the shot pass through — then the whole line detonates. |
| **Pierce + Split** | **Flechette** | On expiry, the 3 sub-projectiles each inherit pierce (1 each). Sub-projectile damage is 40% of base, but each can hit 1 additional enemy. | One shot quietly fans into a razor spread that still punches through. |
| **Pierce + Gravity** | **Needle Vortex** | Projectile homes toward the nearest enemy. On contact, it pierces through them and continues in a straight line — the homing only applies to the first target. | It hunts the first one down, then drills through everything behind them. |
| **Pierce + Ricochet** | **Phase Bolt** | Projectile pierces enemies AND bounces off walls. Each wall bounce resets the pierce counter to full (3). A single shot can pierce 12+ enemies across 3 bounces. | Ricocheting pinball needle that refuses to stop hitting things. |
| **Chain + Explosive** | **Bouncing Bomb** | On chain arrival at the secondary target, an explosion fires at the chain destination (not the origin). The explosion deals 30% AoE damage centered on the chained-to enemy. | The chain isn't just a hop — it plants a bomb. |
| **Chain + Split** | **Hydra** | On chain arrival, the chained projectile splits into 3 sub-projectiles at the chain destination. Each sub-projectile can chain once more (1 chain hop each, 40% of chain damage). | One shot becomes a chain that becomes three shots that each chain again. |
| **Chain + Gravity** | **Seeker Chain** | The chain bounce is guided: instead of bouncing to the geometrically nearest enemy, it homes to the nearest enemy to the chain target, extending the chain range to 200px. | Chains that don't miss — the second hop hunts. |
| **Chain + Ricochet** | **Billiard** | Each wall bounce increases chain range by 40px (base 120px → 200px at 2 bounces). Projectile gains "momentum" from walls, making chains from bounced shots reach further. | The longer it's been bouncing, the further it reaches when it finally hits. |
| **Explosive + Split** | **Cluster Bomb** | The explosion spawns the 3 sub-projectiles outward at the impact point (evenly spread, 120° apart) rather than at expiry. Sub-projectiles fire away from the explosion. | Grenade goes off, and the shrapnel scatters in every direction. |
| **Explosive + Gravity** | **Seeking Missile** | Homing projectile. Explosion radius increased by 50% (40px → 60px). The missile locks on and delivers a bigger payload. | It finds you. Then the explosion is worse than you expected. |
| **Explosive + Ricochet** | **Bouncing Grenade** | Projectile explodes on every wall bounce (up to 3 explosions). Each explosion deals 30% AoE damage independently. The final impact also explodes normally. | Grenade bounces around the room detonating each time it touches a wall. |
| **Split + Gravity** | **Star Formation** | The 3 sub-projectiles all independently home toward the nearest enemies. They acquire separate targets if multiple enemies are present. | One shot splits into 3 heat-seeking darts that all want blood. |
| **Split + Ricochet** | **Scatter Shot** | Sub-projectiles each bounce off walls once (1 bounce per sub). Sub-projectile damage increases to 50% (up from 40%) to compensate for unpredictable angles. | The shot dies and throws bouncers in three directions. |
| **Gravity + Ricochet** | **Spiral Orbit** | After each wall bounce, the projectile re-acquires the nearest enemy as a new homing target. Effectively: home → wall → re-home → wall → re-home. Never stops seeking. | It spirals through the room, bouncing off walls and always curving back toward someone. |

---

## 2. Behavior × Elemental

24 combos. Elemental effects still apply normally; these describe the additional interaction.

### Pierce × Elemental

| Pair | Combo Name | Mechanic | Fantasy |
|------|-----------|----------|---------|
| **Pierce + Fire** | **Flaming Lance** | The pierce trail leaves a lingering fire zone for 1.5s. Enemies that walk through the path take Burning. | The bullet is gone but the air it travelled through is still on fire. |
| **Pierce + Cryo** | **Ice Spear** | All pierced targets receive Chilled simultaneously in a single pass. If 3+ targets are pierced, the first already-Chilled one is instantly pushed to Frozen. | One throw of a spear freezes the whole row. |
| **Pierce + Shock** | **Arc Chain** | Each additional enemy pierced after the first triggers Conductor on the previous pierced enemy (the existing Shocked chain effect fires backward down the pierce line). Requires a Shock source elsewhere to pre-shock targets. | The bolt drills through and detonates every shocked body it already passed. |
| **Pierce + DOT Applicator** | **Bloodletter** | Each enemy pierced receives a separate Bleed application with full 4s duration. All bleed timers run independently. | One shot walks through four people and each one starts bleeding. |

### Chain × Elemental

| Pair | Combo Name | Mechanic | Fantasy |
|------|-----------|----------|---------|
| **Chain + Fire** | **Firebrand** | The chain arc carries fire. The chain destination target is also Ignited on arrival (Burning applied). Fire spreads along the chain. | The bullet hops and the next person catches fire too. |
| **Chain + Cryo** | **Freeze Relay** | Chain applies Chilled to the secondary target on arrival. If the secondary target was already Chilled, Frozen triggers immediately. | Cold jumps from one person to the next until someone shatters. |
| **Chain + Shock** | **Arc Flash** | The chain arc itself is treated as a Shocked trigger on the secondary target — Conductor fires at chain destination immediately on arrival. No separate Shocked status required; the chain IS the shock. | The chain doesn't just hop — it's a lightning strike that automatically Conductors. |
| **Chain + DOT Applicator** | **Bleeding Edge** | Chain arc applies Bleed to the secondary target on arrival (separate stack from any bleed on the primary). | Hit one, the second one starts bleeding too. |

### Explosive × Elemental

| Pair | Combo Name | Mechanic | Fantasy |
|------|-----------|----------|---------|
| **Explosive + Fire** | **Napalm Burst** | The explosion leaves a persistent fire pool at the impact point for 2s. Enemies that enter or stand in the pool receive Burning. | Grenade goes off, leaves a burning puddle. Classic. |
| **Explosive + Cryo** | **Flash Freeze** | The explosion applies Chilled to all enemies in the AoE radius simultaneously. Enemies that already have 2 Chilled stacks are instantly Frozen by the blast. | Cryo grenade — everything in the radius slows at once. |
| **Explosive + Shock** | **Static Pulse** | Explosion applies Shocked to every enemy in the AoE. Multiple Shocked enemies in proximity will all trigger Conductor on the next hit received. | One blast and the whole cluster is live wires. |
| **Explosive + DOT Applicator** | **Frag Round** | Each enemy hit by the explosion also receives a Bleed (counted as a hit). An explosion hitting 5 enemies applies 5 independent bleeds. | Shrapnel cuts everyone. Everyone bleeds. |

### Split × Elemental

| Pair | Combo Name | Mechanic | Fantasy |
|------|-----------|----------|---------|
| **Split + Fire** | **Fire Flower** | Each of the 3 sub-projectiles independently applies Burning. Spread shot becomes a three-point igniter. | Shot dies and throws three burning sparks. |
| **Split + Cryo** | **Ice Fan** | Each sub-projectile independently applies Chilled. Wide-spread chill coverage from a single shot. | Fanning cryo burst — freeze the flanks. |
| **Split + Shock** | **Fork Lightning** | Each sub-projectile independently applies Shocked. A single shot can apply Shocked to 3 separate targets simultaneously, setting up a massive Conductor payoff on the next hit. | One shot, three shock primes. Whatever comes after is devastating. |
| **Split + DOT Applicator** | **Razor Fan** | Each sub-projectile independently applies Bleed. Three bleeds in three directions. | The spread is already good. Now everyone it touches bleeds. |

### Gravity × Elemental

| Pair | Combo Name | Mechanic | Fantasy |
|------|-----------|----------|---------|
| **Gravity + Fire** | **Comet** | Homing firebolt. On impact, Burning is applied with +50% duration (4.5s instead of 3s). The guaranteed hit earns a longer burn. | A burning meteor locks onto you. There's nowhere to run. |
| **Gravity + Cryo** | **Frost Seeker** | Homing cryo orb. Guaranteed hit means guaranteed Chilled. Seek range increases to 200px (up from 150px) as the projectile "searches" longer. | It finds you. You slow. It finds the next one. |
| **Gravity + Shock** | **Lightning Rod** | Homing shot that, on impact, applies Shocked and immediately triggers Conductor (combines both effects into one guaranteed hit). The homing guarantees both the Shocked and the Conductor fire. | It locks on and detonates them with lightning on arrival. |
| **Gravity + DOT Applicator** | **Bloodhound** | Homing projectile preferentially targets enemies that are already Bleeding (re-evaluates target each frame). On hit, Bleed duration refreshes to full (4s). | Follows the wounded. Makes sure they keep bleeding. |

### Ricochet × Elemental

| Pair | Combo Name | Mechanic | Fantasy |
|------|-----------|----------|---------|
| **Ricochet + Fire** | **Wildfire** | Each wall bounce briefly ignites the bounce-point, leaving a 0.8s fire zone at the wall contact location. Enemies that approach the walls take Burning. | The bullet bounces and leaves flames across the walls. |
| **Ricochet + Cryo** | **Ice Ball** | Each enemy hit by a bounced projectile (not first impact) receives an additional Chilled stack (2 stacks instead of 1 per hit). Bouncing builds freeze faster. | The more it bounces, the colder each hit gets. |
| **Ricochet + Shock** | **Thunderball** | Projectile applies Shocked on every enemy impact (both first hit and bounced hits). A single ricochet pass can shock 3+ enemies. | Bouncing ball of electricity — each contact shocks. |
| **Ricochet + DOT Applicator** | **Ricochet Razor** | Each wall bounce refreshes the Bleed duration on any currently-bleeding targets near the bounce point (20px radius). Bleed accumulates while the projectile bounces. | The longer it bounces, the deeper the cuts stay open. |

---

## 3. Elemental × Elemental

7 combos. Three existing (confirmed) and four new.

| Status Pair | Combo Name | Trigger | Effect | Notes |
|-------------|-----------|---------|--------|-------|
| **Burning + Chilled** | **Frostfire** | Burning applied to a Chilled target | Consume Chilled → 12 Fire AoE (45px) | Existing. Confirmed. |
| **Burning + Frozen** | **Shatter** | Burning applied to a Frozen target | Consume Frozen → 20 Ice AoE (50px) | Existing. Confirmed. |
| **Hit while Shocked** | **Conductor** | Any hit received while Shocked | Consume Shocked → 10 Lightning AoE (80px) | Existing. Confirmed. |
| **Burning + Shocked** | **Hellfire** | Burning applied to a Shocked target (or Shocked applied while Burning) | Consume both → 15 Hellfire AoE (55px). Deals hybrid Fire+Lightning damage (split evenly). | New. Covers Fire+Shock co-application. |
| **Chilled + Shocked** | **Superconductor** | Shocked applied to a Chilled target | Consume Chilled → 18 Cold Lightning AoE (60px). Slow is transferred to nearby enemies as a 50% chain slow (1.5s). | New. Cryo+Shock. |
| **Burning + Bleeding** | **Searing Wound** | Burning active on a target that is also Bleeding | While both active: Bleed tick rate doubles (2 dmg/s → 4 dmg/s). Neither status is consumed — they amplify each other until one expires. | New. Sustained dual-DoT amplifier. |
| **Frozen + Bleeding** | **Hemorrhage** | Target is both Frozen and Bleeding when the Frozen stun expires | On Frozen expiry: deal bonus damage equal to (Bleed stacks × 5) as a burst. Bleed continues. | New. Execute mechanic — big burst when freeze breaks. |
| **Shocked + Bleeding** | **Galvanized** | Target is both Shocked and Bleeding; Conductor triggers | Conductor AoE spreads one Bleed stack to each enemy it hits. | New. Bleed multiplier via Conductor. |

---

## 4. Stat Mod Interactions

Stat mods interact by scaling or redirecting existing effects. These are rules, not named combos (exceptions noted).

### Size Increase

Size increases projectile and hitbox scale by 1.5×. Secondary effects:

| Paired With | Interaction |
|-------------|-------------|
| Pierce | Wider hitbox catches more enemies per pass. No mechanical change — just more reliable pierces on dense packs. |
| Chain | Chain detection radius scales with projectile size (+25% chain range, ~150px). |
| Explosive | AoE radius scales with projectile size (+40% explosion radius, ~56px). |
| Split | Sub-projectiles are also larger (hitbox and visual). Sub-projectile damage increases to 50% (from 40%) — bigger shards hit harder. |
| Gravity | Homing seek range scales (+40% range, ~210px). The larger projectile "feels" enemies from further away. |
| Ricochet | Larger hitbox means more reliable wall-hits at glancing angles. Bounce count unchanged. |
| Fire | On-hit burn area is slightly expanded (burning "splash" at 15px radius instead of single-point). |
| Cryo | Chill application radius at impact +20px (area chill on hit). |
| Shock | Shocked chain range +30px (80px → 110px) when combined with Shock mod. |
| DOT Applicator | Bleed application gets a small splash radius (10px) — nearby enemies to impact point also receive Bleed. |
| Lifesteal | More surface area = more incidental contacts on grazed enemies. Minor practical benefit. |
| Crit Amplifier | **"Massive Crit"**: Larger projectile has +5% additional crit chance (easier to land crits with a bigger hitbox). |
| Instability Siphon | No interaction. |
| Accelerating | No interaction. |

### Crit Amplifier

Adds +15% crit chance and +0.3× crit damage multiplier. Secondary effects:

| Paired With | Interaction |
|-------------|-------------|
| Pierce | Crit on the first pierced enemy. Remaining pierce targets take 50% of the crit bonus (diminishing return through pierces — still better than no crit). |
| Chain | Chain only triggers on a crit (otherwise normal hit, no chain). On crit-chain, chain damage increases to 80% (up from 60%). Higher risk, higher payoff. |
| Explosive | Critical hits increase explosion radius by 30% (+12px). Crit → bigger boom. |
| Split | Crits spawn 5 sub-projectiles instead of 3. Non-crits spawn 3. |
| Gravity | Homed shots (target acquired and hit) always crit. Removes crit RNG for homing shots specifically. |
| Ricochet | Each wall bounce grants +5% crit chance for that shot's lifetime (stacks to +15% at 3 bounces). Bounced shots crit more. |
| Fire | Crits apply 2 Burning stacks simultaneously (double ignite on crit). |
| Cryo | Crits immediately apply 2 Chill stacks (instead of 1) on impact. |
| Shock | **"Static Strike"**: Crits instantly trigger Conductor without consuming Shocked. Shocked status remains; Conductor fires as a bonus. |
| DOT Applicator | Crits refresh all active DoT durations on the target to their full value. Never let the bleed expire. |
| Lifesteal | **"Vampiric Strike"**: Crits leech at 3× rate (15% of crit damage instead of 5%). Burst heal on crits. |
| Instability Siphon | Kills by crit hit reduce Instability by 2 instead of 1. Execution crits pay double. |
| Accelerating | At full ramp speed, +10% additional crit chance bonus. Frenzy rewards accuracy. |

### Lifesteal

Returns 5% of damage dealt as HP. Secondary effects:

| Paired With | Interaction |
|-------------|-------------|
| Pierce | Each pierced enemy heals independently. Piercing 3 enemies returns 15% of base damage as HP in one shot. |
| Chain | Chain hit also triggers lifesteal. One shot heals twice if chain connects. |
| Explosive | Every enemy hit by the AoE heals the player. Explosions into dense packs = significant burst healing. |
| Split | Each sub-projectile heals independently. Three sub-hits = up to 15% damage returned. |
| Gravity | No bonus interaction — but homing guarantees the lifesteal connects. Reliable healing from homed shots. |
| Ricochet | Each wall bounce that hits an enemy heals. Up to 4× healing from a single shot with 3 bounces. |
| Fire | Burn tick damage also leeches (5% of each burn tick heals the player). DoT becomes a sustain tool. |
| Cryo | On Frozen trigger (3 Chill stacks), heal a flat HP burst (e.g., 8 HP). Freeze = small heal. |
| Shock | Conductor AoE damage also leeches. Chain lightning sustains HP. |
| DOT Applicator | Bleed tick damage also leeches. Both DoTs (Fire + Bleed if both active) leech simultaneously. |
| Instability Siphon | "Vital Extraction": Each kill heals (via Lifesteal) AND reduces Instability. Full combat loop — fight well, stay healthy, stay calm. |
| Accelerating | More attacks per second = more healing per second. Ramp period is a rising sustain curve. |

---

## 5. Instability Siphon & Accelerating

These mods tie into the meta-loop. Interactions below focus on meaningful synergies.

### Instability Siphon

Base: kills reduce Instability by 1.

| Paired With | Interaction | Design Note |
|-------------|-------------|-------------|
| Pierce | Each kill along a pierce path reduces Instability by 1 (multi-kill pierce = multi-siphon). | Reward for killing efficiently. |
| Chain | Chain kills (secondary target dies) also reduce Instability by 1. | Chaining into a kill feels doubly rewarded. |
| Explosive | Each kill inside an explosion radius reduces Instability by 1. Multi-kill explosion = large siphon spike. | The reason to go for clustered groups. |
| Split | Each sub-projectile kill reduces Instability by 1. | Spray into a crowd for maximum siphon. |
| Gravity | No bonus. Homing just reliably delivers the guaranteed siphon. | Reliable but not exceptional. |
| Ricochet | Kill with a bounced shot (not the first impact) reduces Instability by 2 (trick shot bonus). | Skill expression reward — threading the room pays off. |
| Fire | Kill while Burning is active on target reduces Instability by 2. DoT kills count. | Ignite → kill = efficient siphon. |
| Cryo | Kill a Frozen target reduces Instability by 2. Shatter-kill is worth extra. | Execute the frozen = big reduction. |
| Shock | Conductor kill (kill by chain lightning AoE) reduces Instability by 3. Conducting to a kill is the best siphon source in the game. | High-risk chain setup = high reward. |
| DOT Applicator | Kill by Bleed tick (DoT executes the enemy, not a direct hit) reduces Instability by 2. Passive kills count. | DoT builds that "let things die" get extraction value. |
| Size | No interaction. | — |
| Lifesteal | See Lifesteal section ("Vital Extraction"). | — |
| Crit Amplifier | See Crit section. (Crit kills → 2 reduction.) | — |
| Accelerating | **"Frenzy Extraction"**: At full ramp (3s in), all kills reduce Instability by 2 instead of 1. Ramp up → go fast → defuse the timer. | The ramp matters. Getting to full speed is the objective. |

### Accelerating

Base: +50% attack speed over 3s ramp-up. Secondary effects:

| Paired With | Interaction |
|-------------|-------------|
| Pierce | Ramp does not affect pierce count, but faster shots mean pierce chains resolve more quickly. Minor density benefit. |
| Chain | At full ramp, chain range increases to 160px (up from 120px). Faster shots carry more energy. |
| Explosive | At full ramp, explosion radius +30% (52px). Velocity translates to impact force. |
| Split | At full ramp, split spawns 4 sub-projectiles instead of 3. More fragments at peak firing rate. |
| Gravity | At full ramp, homing seek range +60% (240px). Faster projectiles track from further away. |
| Ricochet | At full ramp, +1 extra bounce (4 total instead of 3). More energy in the shot. |
| Fire | Faster reapplication closes the Burning stack window. Easier to stack Frostfire / Shatter / Hellfire triggers. |
| Cryo | Faster attacks build Chill stacks faster. Frozen triggers are dramatically faster with full ramp. |
| Shock | At full ramp, every 3rd hit auto-applies Shocked (no Shock mod required if using this combo). Bonus: Conductor can fire from the auto-shock. |
| DOT Applicator | At full ramp, each hit applies 2 Bleed stacks (up from 1). DoT buildup accelerates dramatically. |
| Size | No interaction. |
| Lifesteal | See Lifesteal section. (More hits = more healing.) |
| Crit Amplifier | See Crit section. (Full ramp = +10% crit bonus.) |
| Instability Siphon | See Instability Siphon section ("Frenzy Extraction"). |

---

## 6. Legendary Triple Combos

8 authored triples. These require exactly the 3 listed mods and produce an additional effect beyond the pairwise interactions.

---

### "DOOMSDAY DEVICE"
**Required:** Explosive + Split + Size

**Mechanic:** The main shot explodes on contact. The explosion itself spawns the 3 sub-projectiles (Explosive+Split pairwise). Because Size applies, the sub-projectiles are 1.5× scale, deal 55% damage each, and the explosion radius is +40% (56px). Triple activations all benefit from size scaling simultaneously.

**Discovery Fantasy:** You fire one shot. It detonates. Three large blasts scatter outward from the explosion. The screen fills with impact indicators. You feel briefly invincible.

---

### "VAMPIRE LORD"
**Required:** Pierce + Lifesteal + DOT Applicator

**Mechanic:** Pierce bleeds every target in the path (Bloodletter pairwise). All Bleed ticks also leech HP (Lifesteal+DOT pairwise). Triple bonus: while Bleeding targets are present, the projectile homes toward the most-wounded (lowest HP%) bleeding target, gaining a slight curve on approach. You are hunted by your own wounds.

**Discovery Fantasy:** You fire into a group. Everything bleeds. Your HP bar starts climbing as the room takes damage. Each shot finds the weakest one.

---

### "ABSOLUTE ZERO"
**Required:** Cryo + Size + Crit Amplifier

**Mechanic:** Size increases chill AoE radius on hit to area-effect. Crits apply 2 stacks immediately. Crit+Cryo pairwise. Triple bonus: any enemy that reaches Frozen while both Size and Crit are active emits a 50px cryo pulse on Freeze trigger — a secondary AoE freeze wave centered on the frozen target.

**Discovery Fantasy:** You one-shot a group into a slow, then two enemies freeze simultaneously and the freeze-pulse ripples outward and catches three more. The whole arena is a glacier.

---

### "STORM BREAKER"
**Required:** Ricochet + Shock + Explosive

**Mechanic:** Projectile shocks on every contact (Thunderball pairwise). Each wall bounce also explodes (Bouncing Grenade pairwise). Triple bonus: each bounce-explosion counts as a "hit" and triggers Conductor on any Shocked enemies within 80px of the bounce point. Bounce → explode → conduct. Every wall is a detonator.

**Discovery Fantasy:** You fire at a wall and the room lights up. Bouncing explosions. Lightning arcing between confused enemies. You fired one bullet.

---

### "EXTRACTION TITAN"
**Required:** Instability Siphon + Explosive + Fire

**Mechanic:** Explosions leave fire pools (Napalm Burst pairwise). Kills while Burning reduces Instability by 2 (Siphon+Fire pairwise). Triple bonus: each multi-kill explosion (3+ enemies killed by one blast) reduces Instability by a flat 5 in addition to per-kill reductions. Explosions that clear groups pay triple.

**Discovery Fantasy:** You're running hot, Instability climbing. One grenade into a pack. 5 kills. The number drops by 15. You bought yourself another minute.

---

### "WORLD SERPENT"
**Required:** Gravity + Chain + Split

**Mechanic:** Homing shot chains on impact (Seeker Chain pairwise). On chain arrival, spawns 3 homing sub-projectiles (Hydra pairwise). Triple bonus: the 3 sub-projectiles from the chain destination each also home — but to different enemies (they acquire separate targets if available). One shot becomes 1 homing hit + 1 chain + 3 independent homing strikes.

**Discovery Fantasy:** You fire one round. It finds someone. It jumps to someone else. Three missiles shoot out of the second person and find three more. Seven targets from one trigger pull.

---

### "CRIMSON REAPER"
**Required:** DOT Applicator + Crit Amplifier + Accelerating

**Mechanic:** Crits refresh all DoT durations (Crit+DOT pairwise). At full ramp, each hit applies 2 Bleed stacks (Accelerating+DOT pairwise). Triple bonus: at full ramp, crit hits deal bonus damage equal to 15% of the target's total active Bleed stacks as a burst (e.g., 10 Bleed stacks → +1.5 bonus damage per crit hit). Stack Bleed high, then crit for burst execution.

**Discovery Fantasy:** Everything you hit starts hemorrhaging. By round 10, the stacks are enormous. Then a crit lands and a third of their health vanishes. The longer the fight goes, the nastier each crit becomes.

---

### "FROSTFIRE METEOR"
**Required:** Gravity + Fire + Cryo

**Mechanic:** Homing guarantees the shot lands (Comet and Frost Seeker pairwise). Since both Fire and Cryo are active, every hit applies both Burning and Chilled simultaneously — guaranteed Frostfire proc on every landed shot (Frostfire triggers because Burning is applied to a Chilled target). Triple bonus: the Frostfire AoE is increased to 55px (up from 45px) when triggered by a homed shot.

**Discovery Fantasy:** Every single shot is a mini-Frostfire. The homing removes the setup requirement. You just... fire, and every target explodes in fire-ice. No management. Pure destruction.

---

## Summary

| Section | Count |
|---------|-------|
| Behavior × Behavior named combos | 15 |
| Behavior × Elemental named combos | 24 |
| Elemental × Elemental combos | 7 (3 existing + 4 new) |
| Stat mod interaction rules | ~23 (across all 3 stats) |
| Instability Siphon interactions | 13 |
| Accelerating interactions | 12 |
| Legendary Triple combos | 8 |
| **Total authored doubles** | **69** |
| **Total authored triples** | **8** |
| Emergent triples (unspecified) | ~150+ |
