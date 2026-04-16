# Session Prompt: Void Instability Debuff Auto-Application

**Model:** Sonnet
**Scope:** Wire void_touched status to auto-apply/remove based on instability threshold
**Output:** Player automatically receives void_touched debuff at high instability, loses it when instability drops

## Project Context

Extraction Survivors — top-down 2D arena survivor/extraction hybrid in Godot 4.6.1 (GDScript). Component-based entity system with data-driven content.

- GameManager autoload tracks game state including instability
- StatusEffectComponent on each entity manages active status effects
- `data/factories/status_factory.gd` contains all StatusEffectDefinition instances
- All status effects applied via `StatusEffectComponent.apply_status()` (or equivalent — read to confirm)
- Signals for inter-system comms; prefer signal-based hooks over modifying manager internals
- Debug mode: `GameManager.debug_mode = true` enables F1–F5 hotkeys for testing

## What This Task Is

The game has an instability mechanic — carrying too much loot or staying in a phase too long raises instability. At high instability, the player should suffer the `void_touched` debuff (a pre-existing StatusEffectDefinition). This debuff should auto-apply when instability crosses a threshold and auto-remove when it drops back below.

**Design spec:**
- Apply `void_touched` when instability reaches 70% of maximum
- Remove `void_touched` when instability drops below 60% of maximum (hysteresis band — prevents flickering)
- Only applies in Phases 2–5 (Phase 1 is the tutorial phase — instability shouldn't punish new players)
- This is reactive, not polled — hook into the instability update function or signal

## Your Task

### Step 1 — Read first

Read these files:
1. `scripts/managers/game_manager.gd` — find where instability is stored (check if it's 0–100 or 0.0–1.0) and where it's updated (find `add_instability`, `set_instability`, or equivalent). Check if GameManager emits a signal when instability changes.
2. `data/factories/status_factory.gd` — find the `void_touched` definition; note its exact string ID and what debuffs it applies.
3. `scripts/player/player.gd` or `scripts/components/status_effect_component.gd` — find the `apply_status()` and `remove_status()` (or equivalent) API on StatusEffectComponent.

### Step 2 — Implement

Based on what you find:

**If GameManager emits a signal on instability change** (preferred): connect to that signal from wherever the player entity initializes; in the handler, check the threshold and apply/remove void_touched.

**If no signal exists**: add one to GameManager — `signal instability_changed(new_value: float)` — emit it wherever instability is updated. Then connect as above.

The threshold logic (assume instability is normalized to 0.0–1.0; adjust if it's 0–100):
```
if instability >= 0.7 and not has_void_touched:
    apply void_touched
elif instability < 0.6 and has_void_touched:
    remove void_touched
```

Phase check: wrap the above in `if GameManager.current_phase >= 2` (or equivalent phase field name).

## Rules

- Read all three files before writing code
- Do not use a polling loop — reactive only
- The `void_touched` status ID must match exactly what's in StatusFactory — read it, don't guess
- If `current_phase` is named differently in GameManager, use the actual field name

## Output Format

1. **How instability works** — storage type (0–1 or 0–100), update function name, whether a signal exists (1–2 sentences)
2. **void_touched ID** — exact string from StatusFactory
3. **Code change** — the implementation with file path; include the signal addition if needed
4. **Verification** — enable `GameManager.debug_mode = true`, use debug hotkeys to spike instability above 70%, confirm `void_touched` appears in the player's status list
