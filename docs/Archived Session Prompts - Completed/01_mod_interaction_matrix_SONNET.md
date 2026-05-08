# Session Prompt: Mod Interaction Matrix — Design Document

**Model:** Sonnet
**Scope:** Design doc only — NO code, NO implementation
**Output:** A single markdown file `mod_interaction_matrix.md` in the project docs folder

## Context

We're building a survivors-like extraction hybrid in Godot 4.6. Weapons have 1-2 mod slots. Mods come in four categories: Behavior, Elemental, Stat, and Unique/Economic. We want every mod pair to have a defined interaction — a named combo with a specific mechanical effect. This is a core dopamine loop (think: Alchemy mobile game "what does this make?").

## Current Mod List

### Behavior Mods
- Pierce — Pass through 3 enemies
- Chain — Bounce to 1 enemy (120px, 60% dmg)
- Explosive — AoE on hit (40px, 30% dmg)
- Split — Create 3 sub-projectiles on expiry (40% dmg)
- Gravity (Homing) — Curve toward nearest enemy
- Ricochet — Bounce off walls 3 times

### Elemental Mods
- Fire — Burning (3 dmg/sec, 3s)
- Cryo — Chilled (-30% speed, 3s); 3 stacks → Frozen (1.5s stun)
- Shock — Shocked (5s); next hit chains 10 AoE damage (80px)
- DOT Applicator — Bleed (2 dmg/sec, 4s)

### Stat Mods
- Lifesteal — 5% damage → HP
- Size Increase — 1.5× projectile/hitbox scale
- Crit Amplifier — +15% crit chance, +0.3× crit damage

### Unique/Economic Mods
- Instability Siphon — Kills reduce Instability by 1
- Accelerating — +50% atk spd over 3s ramp-up

### Existing Elemental Combos
- Frostfire: Burning + Chilled → 12 Fire AoE (45px)
- Shatter: Burning + Frozen → 20 Ice AoE (50px)
- Conductor: Hit while Shocked → 10 Lightning AoE (80px)

## Your Task

Create a comprehensive mod interaction matrix document with the following structure:

### 1. Behavior × Behavior Grid
For every pair of behavior mods (Pierce+Chain, Pierce+Explosive, Pierce+Split, Pierce+Gravity, Pierce+Ricochet, Chain+Explosive, Chain+Split, Chain+Gravity, Chain+Ricochet, Explosive+Split, Explosive+Gravity, Explosive+Ricochet, Split+Gravity, Split+Ricochet, Gravity+Ricochet), define:
- **Combo Name** — a short evocative name
- **Mechanic** — 1-2 sentences describing exactly what happens
- **Fantasy** — one sentence on why this feels good to the player

### 2. Behavior × Elemental Grid
For every behavior mod paired with every elemental mod (24 combos), same format: name, mechanic, fantasy.

### 3. Elemental × Elemental Grid
Expand beyond the existing three combos. Cover Fire+Bleed, Cryo+Bleed, Shock+Bleed, and confirm/refine the existing Frostfire/Shatter/Conductor entries.

### 4. Stat Mod Interactions
Define how each stat mod interacts with every behavior mod, every elemental mod, and each other stat mod. These can be simpler — a scaling bonus or enhanced effect rather than a named combo.

### 5. Instability Siphon & Accelerating Interactions
These are unique mods that touch the meta-loop. Define how they interact with behavior, elemental, and stat mods. Focus on combos that tie combat performance to extraction risk/reward.

### 6. Authored Triple Combos (5-8 max)
Select the most exciting three-mod combinations and give them:
- **Legendary Name**
- **Required Mods** (exactly 3)
- **Mechanic** — what the unique triple-only effect is
- **Discovery Fantasy** — why finding this combo feels legendary

## Design Principles to Follow
- Every pair should have SOMETHING, even if it's just an enhanced version of both effects
- Named combos are better than unnamed stat boosts — names stick in player memory
- Interactions should be visually distinct (different VFX implication) where possible
- Don't worry about balance numbers — just define the mechanic. Numbers come later
- If a combo genuinely doesn't make sense, say so and explain why, but try hard to make it work
- Err on the side of "this sounds broken and awesome" — survivors-likes thrive on power fantasy

## Output Format
Single markdown file. Use tables where grids are clearest, prose where description needs room. Include a summary count at the top: "X authored doubles, Y authored triples, Z emergent triples possible."
