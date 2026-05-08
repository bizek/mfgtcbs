# Session Prompt: Mod Combo Effect System — Runtime Implementation

**Model:** Sonnet
**Scope:** The system that detects and triggers mod combos during gameplay
**Depends On:** Session 01 (design doc) and Session 02 (data structures). Session 03 (UI) is NOT required.
**Output:** Combo detection, effect execution, and codex integration scripts

## Context

We have a survivors-like extraction game in Godot 4.6 (GDScript). Weapons have 1-2 mod slots. We've designed a full mod interaction matrix (Session 01) and built the data backbone (Session 02). Now we need the runtime system that actually MAKES combos happen during a run.

## Important: Read CLAUDE.md First

Before starting work, read the project's CLAUDE.md file for current architecture context, file paths, and conventions. The weapon and mod systems already exist — you're adding a layer on top, not replacing anything.

## Architecture Overview

The combo system sits between the existing mod system and the projectile/effect system:
1. Player equips weapon with mods → existing system
2. **NEW: Combo Detector** checks equipped mods against the combo registry
3. **NEW: Combo Effect Resolver** modifies projectile behavior and/or registers status effect listeners
4. Projectile fires / hits / expires → existing system
5. **NEW: Combo effects trigger** at appropriate lifecycle points
6. **NEW: CodexManager.record_trigger()** called when a combo effect fires

## Your Task

### 1. ComboDetector (`combo_detector.gd`)
A utility that checks a weapon's equipped mods and returns active combos:
- `func get_active_combos(equipped_mods: Array[StringName]) -> Array[ModCombo]`
- Should handle 2-mod combos from the pair
- Should also check for triple combos if a weapon has 2 mods + an innate property
- Cache results — only recalculate when loadout changes

### 2. ComboEffectResolver (`combo_effect_resolver.gd`)
Takes active combos and applies them to weapon/projectile behavior:
- Distinguish between:
  - **On-fire effects** — modify the projectile when it's created (e.g., Pierce+Fire = leave burning trail)
  - **On-hit effects** — trigger when projectile hits an enemy (e.g., Explosive+Cryo = frost nova)
  - **On-expiry effects** — trigger when projectile expires/reaches max range (e.g., Split+Gravity = homing children)
  - **Passive effects** — always active while equipped (e.g., stat interactions)
  - **Status-listener effects** — trigger when a status effect is applied to an enemy that already has another status (elemental combos like Frostfire)
- Each authored combo should have a dedicated effect function
- Emergent combos (non-authored) should just apply both mod effects normally — the "combo" is the natural stacking

### 3. Authored Combo Effects
Implement the actual effects for all authored double combos from the design doc. This is the bulk of the work. For each:
- Create the effect function
- Define the trigger point (on-fire, on-hit, on-expiry, passive, status-listener)
- Call `CodexManager.record_trigger()` when the effect fires
- Add a brief comment noting the intended VFX tag (actual VFX is a separate session)

### 4. Triple Combo Detection
For the 5-8 authored legendary triples:
- Triple detection should check if all 3 required mods are present
- Triples should OVERRIDE their component doubles, not stack on top (to avoid double-dipping)
- When a triple fires, it should emit a signal that the UI can catch for a special notification

### 5. In-Run Discovery Notification
When a combo triggers for the FIRST time (CodexManager says revealed == false):
- Emit a signal: `combo_first_triggered(combo_name, combo_type)`
- The HUD can catch this and show a "FROSTFIRE DISCOVERED!" flash
- Don't build the HUD element itself — just emit the signal with all needed data

### 6. Integration Points
Document (in comments) where this system hooks into existing code:
- Where does ComboDetector get called? (loadout change in armory or run start)
- Where does ComboEffectResolver inject into the projectile lifecycle?
- Where do status-listener combos hook into the status effect system?
- Don't modify existing files yet — just document the integration points clearly

## Technical Notes
- Combo effects should be data-driven where possible — a combo definition that says "on_hit: apply_aoe(cryo, 50px)" rather than a bespoke function per combo
- Use an enum for trigger types: ON_FIRE, ON_HIT, ON_EXPIRY, PASSIVE, STATUS_LISTENER
- Performance matters — combo checks happen frequently. Use dictionaries and caching
- Some combos modify projectile properties (pierce trail), others spawn new effects (frost nova). The resolver needs to handle both patterns

## What NOT To Do
- Don't modify existing weapon or mod scripts — this system layers on top
- Don't implement VFX — just tag effects with vfx_hint strings
- Don't build UI notifications — just emit signals
- Don't balance numbers — use the values from the design doc as-is, we'll tune later
- Don't implement the mastery bonus system yet — just track triggers
