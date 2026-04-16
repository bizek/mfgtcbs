# Session Prompt: Combo Mastery Bonus System

**Model:** Haiku
**Scope:** Apply mastery bonuses when a combo is mastered
**Depends On:** Session 02 (CodexManager tracks trigger counts), Session 04 (combo effects exist)
**Output:** Mastery bonus definitions and application logic

## Context

Survivors-like extraction game in Godot 4.6 (GDScript). The CodexManager (Session 02) tracks how many times each combo has been triggered. When a combo hits its mastery threshold (default 50 triggers), it becomes "mastered." Now we need mastered combos to actually grant a bonus.

## Your Task

### 1. MasteryBonus Resource
Create `mastery_bonus.gd` as a Resource:
- `bonus_type: int` — enum: RADIUS_INCREASE, DAMAGE_INCREASE, DURATION_INCREASE, COOLDOWN_REDUCTION, EXTRA_PROC, COST_REDUCTION
- `bonus_value: float` — the modifier value (e.g., 0.1 for +10%)
- `description: String` — human-readable (e.g., "+10% explosion radius")

### 2. Add MasteryBonus to ModCombo
Extend the ModCombo resource (from Session 02) to include:
- `mastery_bonus: MasteryBonus` — what you get for mastering this combo

### 3. Mastery Bonus Definitions
Go through the combo registry and assign an appropriate mastery bonus to each combo. Guidelines:
- AoE combos → radius increase (10-15%)
- DOT/damage combos → damage increase (10-15%)  
- Status effect combos → duration increase (0.5-1s)
- Utility combos (like Instability Siphon interactions) → extra proc chance or increased effect
- Triple legendaries → something unique and powerful (20-25% bonus)
- Keep bonuses simple and consistent — this isn't a second mod system, just a reward

### 4. Bonus Application
Create `mastery_applicator.gd`:
- `func get_active_mastery_bonuses(active_combos: Array[ModCombo]) -> Dictionary`
  - Returns a dictionary of bonus_type → total_value for all mastered active combos
- The combo effect system (Session 04) can query this to modify its effect values
- This should be a simple lookup — the combo effect resolver calls it once at loadout time and stores the result

### 5. Mastery Signal
When a combo reaches mastery mid-run:
- `CodexManager` emits `combo_mastered(combo_id)`
- The HUD notification system (Session 05) can catch this for a special "MASTERED!" popup

## Technical Notes
- Mastery bonuses should be additive, not multiplicative (avoid power scaling issues)
- A player could theoretically have multiple mastered combos active — bonuses of the same type should stack additively
- Keep the mastery threshold consistent at 50 for now — we can tune per-combo later

## What NOT To Do
- Don't modify the combo effect system's core logic — just provide a bonus lookup it can query
- Don't build UI — the codex grid (Session 03) will read mastery state from CodexManager
- Don't implement the actual modification of effect values — just provide the data. Session 04's system applies it.
