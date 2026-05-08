# Session Prompt: Combo Discovery HUD Notification

**Model:** Haiku
**Scope:** Small HUD element that flashes when a combo triggers for the first time
**Depends On:** Session 04 (combo effect system emits `combo_first_triggered` signal)
**Output:** HUD notification scene and script

## Context

Survivors-like extraction game in Godot 4.6 (GDScript). When a player triggers a mod combo for the first time during a run, we want a satisfying on-screen notification — think achievement popup energy. The combo effect system (Session 04) emits a signal `combo_first_triggered(combo_name: String, combo_type: int)` that this HUD element listens for.

## Your Task

### 1. ComboDiscoveryPopup Scene
Create `combo_discovery_popup.tscn` + `combo_discovery_popup.gd`:
- Centered horizontally, positioned upper-third of screen
- Shows combo name in large text with a color accent based on combo_type
- Subtitle text: "COMBO DISCOVERED!" or "LEGENDARY COMBO DISCOVERED!" for triples
- Animate in: scale up from 0 + fade in (0.3s)
- Hold for 2 seconds
- Animate out: fade out + slight upward drift (0.5s)
- If multiple combos trigger rapidly, queue them — don't overlap

### 2. Color Mapping
- BEHAVIOR_BEHAVIOR → White/Silver
- BEHAVIOR_ELEMENTAL → color of the elemental mod (orange for fire, cyan for cryo, yellow for shock, dark red for bleed)
- ELEMENTAL_ELEMENTAL → gradient or split of both element colors
- STAT_INTERACTION → Gold
- TRIPLE_LEGENDARY → Gold with a glow/pulse effect

### 3. Integration
- This scene should be a child of the run HUD
- Listens for the signal from the combo effect system
- Self-manages its animation queue
- No gameplay logic — purely visual feedback

## Technical Notes
- Use Tween for animations (Godot 4 style)
- Keep it lightweight — this fires during combat
- The popup should never block gameplay input
- Use a CanvasLayer to ensure it renders above game elements

## What NOT To Do
- Don't implement combo detection or effects — just consume the signal
- Don't persist discovery state — CodexManager handles that
- Don't add sound effects yet — just the visual notification
