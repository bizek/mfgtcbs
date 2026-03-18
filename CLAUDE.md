# CLAUDE.md — Extraction Survivors Prototype

## Project Overview

This is a **survivors-like / extraction hybrid** game built in **Godot 4.3** using **GDScript**. It combines the horde-survival build-crafting of Vampire Survivors with the risk/reward extraction loop of games like Marathon and Escape from Tarkov. Top-down 2D perspective, dark science-fantasy setting.

**Developer:** Solo dev (Ben) + Claude. Ben provides creative direction. Claude handles code generation and implementation.

**Design docs are in `/docs/`.** Read them before making architectural decisions. They contain 8 phases of deliberate design work and represent locked decisions unless Ben says otherwise.

---

## Key Design Documents (in /docs/)

| Document | What It Contains |
|----------|-----------------|
| seed_document.md | Project foundation — who Ben is, what the game is, constraints, inspirations |
| core_loop.md | What the player does minute-to-minute. 5-phase descent structure, extraction mechanics, death penalty |
| design_pillars.md | 5 non-negotiable design rules. Anti-goals. Master design rules. TEST ALL DECISIONS AGAINST THESE. |
| systems_design_part1.md | Stat System, Combat System (hybrid auto + active), Upgrade/Build System |
| systems_design_part2.md | Enemy System, Loot System (no inventory limit, Instability), Extraction System (4 types) |
| systems_design_part3.md | Meta-Progression (hub), Level/Arena System (1 arena per phase, data-driven) |
| mechanical_vocabulary.md | The grammar: 5 damage types, 11 status effects, 10 weapon behaviors, 15 mod effects, 14 triggers, 11 targeting types |
| asset_inventory.md | Free asset sources, palette-shift strategy for 5 phase themes, license tracking |
| architecture_blueprint.md | Full code architecture: 11 autoload singletons, entity scene structures, signal flow diagrams, data file examples |
| core_framework_decisions.md | ALL the math: damage formula (flat armor), XP curve, phase timing, enemy scaling, Instability thresholds, economy |
| game_dev_methodology.md | The phase-based methodology we're following |

---

## Architecture Summary

### Engine & Language
- Godot 4.3, GDScript
- Top-down 2D
- Pixel art assets (16x16 base, free/CC0 sources)

### Autoloaded Singletons
- **GameManager** — Game state machine, phase transitions
- **StatManager** — Central stat authority for all entities
- **CombatManager** — Damage resolution (flat armor formula)
- **UpgradeManager** — Level-up choices, build tracking, evolution recipes
- **LootManager** — Drop tables, pickup spawning, Instability tracking
- **ExtractionManager** — Extraction point state and channeling
- **EnemySpawnManager** — Wave composition, spawn timing, difficulty scaling
- **ProgressionManager** — Save data, unlocks, hub state (not needed for prototype)
- **ArenaManager** — Arena loading from data files
- **AudioManager** — Music, SFX, ambient transitions
- **UIManager** — HUD, menus, level-up screen

### Communication Pattern
Systems communicate via **Godot signals** (observer pattern). Systems do NOT directly call each other. They emit signals that other systems listen to.

### Data-Driven Design
Everything with 10+ instances is DATA, not code:
- Weapons, mods, enemies, upgrades, arenas = data files (JSON or .tres)
- Adding content = adding data entries, NOT writing new scripts

---

## Core Gameplay Loop

```
DROP IN → PHASE 1 → [EXTRACT?] → PHASE 2 → [EXTRACT?] → ... → PHASE 5 → [EXTRACT OR DIE] → HUB
```

- 5 phases, ~3-4 minutes each, 15-20 min total run
- Enemies spawn in escalating waves (survivors-like)
- Player auto-attacks + has active abilities
- XP gems → level up → choose upgrades (3 tiered choices + reroll)
- Extractable loot drops (weapons, mods, resources, blueprints, artifacts)
- **Instability rises with loot carried** → enemies get harder
- 4 extraction types: Timed, Guarded, Locked (keystone), Sacrifice
- **Death = lose ALL extractable loot. Penalized meta XP (25%).**
- Successful extraction = keep everything + phase bonus

---

## Key Formulas (from core_framework_decisions.md)

**Damage:** `Final = max(RawDamage - Armor, 1)`
**Crit:** `RawDamage × CritDamageMultiplier` (if crit roll succeeds)
**XP to level:** `Base(10) × (1 + (Level-1) × 0.3)`
**Phase enemy scaling:** HP ×[1.0, 1.5, 2.5, 4.0, 6.0], Damage ×[1.0, 1.3, 1.6, 2.0, 2.5]
**Instability tiers:** Stable(0-30), Unsettled(31-70), Volatile(71-120), Critical(121+)

---

## Prototype Scope (Phase 9)

Build ONLY these for the prototype:
- ✅ Player movement (WASD), auto-firing weapon (nearest enemy targeting)
- ✅ Fodder + Swarmer enemies chasing player
- ✅ XP gems drop → level up → 3 upgrade choices (stat boosts)
- ✅ Health system (contact damage from enemies, health orb drops)
- ✅ One arena (simple tilemap or colored background with bounds)
- ✅ Timed extraction (portal opens after phase timer, channel 4 sec)
- ✅ Basic HUD (health bar, XP bar, level, kills, extraction UI)
- ✅ Death → game over screen
- ✅ Extraction → success screen
- ✅ Difficulty scaling over time (more enemies, faster spawns)

Do NOT build for prototype:
- ❌ Hub / meta-progression / saves
- ❌ Weapon mods / multiple weapon slots
- ❌ Multiple extraction types (just Timed)
- ❌ Instability system (simplified only)
- ❌ Multiple characters
- ❌ Audio (silence or single placeholder track)
- ❌ Polish / juice / VFX beyond functional feedback
- ❌ Multiple phases (one escalating phase)

---

## Coding Conventions

- GDScript (not C#)
- Use typed variables where possible: `var speed: float = 200.0`
- Use signals for inter-system communication
- Autoloaded singletons for managers
- Entity scenes: CharacterBody2D for player/enemies, Area2D for projectiles/pickups
- Collision layers: 1=player, 2=enemies, 3=player_projectiles, 4=enemy_projectiles, 5=pickups, 6=extraction
- Use `@export` for values that should be editable in the inspector
- Use `## Comment` for documentation comments
- File organization: scripts/managers/, scripts/entities/, scripts/ui/, scenes/, assets/, data/

---

## Design Pillars (Quick Reference — Details in design_pillars.md)

1. **"The Extract Decision"** — Every system should make the stay-or-go choice harder and more interesting
2. **"Respect the Clock"** — Every minute should be active, rewarding, and fun
3. **"Easy to Play, Hard to Master"** — Simple inputs, deep decision space
4. **"The Descent"** — Atmosphere woven into mechanics, not just visuals
5. **"Ship It"** — When in doubt, simpler option. Scope is the enemy.

---

## Important Notes

- This project follows a strict design-first methodology. All 8 design phases are complete. We are now in Phase 9 (Prototype).
- Ben has started and abandoned game projects before because design and building happened simultaneously. This time is different.
- When in doubt about a design decision, check the design docs first. If the answer isn't there, ask Ben.
- Placeholder art is fine. Colored rectangles are fine. The prototype validates FEEL, not LOOK.
- The prototype is DISPOSABLE. Its purpose is to validate decisions. If something fundamental is wrong, we throw it away and redesign.
