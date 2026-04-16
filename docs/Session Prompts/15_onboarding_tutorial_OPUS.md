# Session Prompt: Onboarding Tutorial System

**Model:** Opus
**Scope:** Design + implement a lightweight contextual tutorial for first-time players
**Output:** TutorialManager autoload script, EventBus signal additions, HUD node descriptions, ProgressionManager field additions

## Project Context

Extraction Survivors — top-down 2D arena survivor/extraction hybrid in Godot 4.6.1 (GDScript). Component-based entity system with data-driven content. 480×270 viewport, 4× integer scaling to 1920×1080 — all UI font sizes and positions must account for this.

- Autoloads: EventBus, GameManager, ProgressionManager, UpgradeManager, EnemySpawnManager, ExtractionManager
- EventBus is the combat signal bus — the tutorial should connect to it, not modify combat systems
- ProgressionManager handles save/load — tutorial completion state should persist here
- HUD is the in-game overlay UI (`scripts/ui/` area) — tutorial tooltips should attach here
- Do not hand-edit `.tscn` files — describe scene node additions for the Godot editor
- Do not weave tutorial logic into GameManager, player.gd, or combat components

## Prerequisites

**Run this session only after Tasks 07–13 are complete.** The tutorial teaches systems that must be verified working before they're explained to new players.

## What This Task Is

New players need to understand 5 things to survive their first run:
1. WASD to move; weapons fire automatically
2. Kill enemies → collect XP orbs → level up → pick an upgrade
3. Mod drops can be equipped to weapons at hub (or during run if applicable)
4. Reach the extraction zone → hold still to channel → extract
5. Carrying too much loot increases instability — don't be greedy

The tutorial delivers this as **contextual tooltips**: a small non-blocking panel appears the first time each mechanic is encountered, shows a one-line instruction, and dismisses either automatically (on action completion) or on button press. Players never see it again after their first run.

**Constraints:**
- Maximum 5–6 tutorial steps — this is a lite tutorial, not a full guided playthrough
- Tooltips must be advisory — never block input or pause the game
- Skippable: "Skip Tutorial" option in the pause menu during first run
- Permanently dismissed after first completion or skip
- Tutorial system is a separate autoload (`TutorialManager`) — it observes events, it does not own them

## Your Task

### Step 1 — Read first

Read these files before designing anything:
1. `scripts/autoloads/event_bus.gd` (or wherever EventBus is defined) — what signals already exist for level-up, mod pickup, extraction zone entry, and loot pickup? Note which are present and which need to be added.
2. `scripts/managers/progression_manager.gd` — find the save/load structure; understand how to add a `tutorial_complete: bool` field (or equivalent)
3. The HUD scene script (find under `scripts/ui/`) — understand the existing overlay layout so tooltips can be positioned sensibly

### Step 2 — Design

Before writing implementation code, produce a design table:

| Step | Trigger event | Tooltip text (max 15 words) | Dismiss condition |
|------|--------------|----------------------------|-------------------|
| 1 | Run start | … | Auto after 5 seconds |
| 2 | First XP orb collected | … | Player levels up |
| … | … | … | … |

Then answer: where does TutorialManager live in the scene tree? (Autoload is recommended — it survives scene transitions.) How do you prevent two tutorial steps from stacking if two trigger events fire within 1 second of each other?

### Step 3 — Implement

Produce all of the following:

**TutorialManager (new autoload script):**
- Connects to EventBus signals on `_ready`
- Tracks which steps have been shown (Dictionary of step_id → bool)
- On each trigger: if the step hasn't been shown and tutorial is not complete, show the tooltip
- Queue mechanism: if a step is already visible, queue the next one — never stack two tooltips
- `func skip_tutorial()` — marks all steps shown, saves completion to ProgressionManager
- `func _mark_complete()` — called when all steps have been shown; saves to ProgressionManager

**EventBus additions** (only signals that don't already exist):
- Add any missing signals needed by the tutorial steps (e.g., `xp_collected`, `extraction_zone_entered`)
- Do not duplicate signals that already exist

**HUD additions** (describe for Godot editor, do not hand-edit .tscn):**
- A `TutorialTooltip` Control node: Panel + Label + optional dismiss Button
- Position: bottom-center of screen, above the HUD bar
- Font size: appropriate for 480×270 base resolution (will scale 4× automatically)
- Animated in/out: a simple tween fade — describe the tween call, don't build an AnimationPlayer for this

**ProgressionManager additions:**
- Add `var tutorial_complete: bool = false` to the saved state
- Add it to the save and load functions — show the exact lines to add, not a full rewrite

**Pause menu addition:**
- The pause menu should show a "Skip Tutorial" button during the first run only (when `not ProgressionManager.tutorial_complete`)
- Describe the scene change and add the button press handler

## Design Principles

- Every tooltip should disappear the moment the player does the thing it's describing — don't leave instructions on screen after they're irrelevant
- Prefer EventBus signal triggers over timer-based triggers — the tutorial teaches by example, not by lecture
- The tutorial should feel like the game noticed you needed help, not like it's forcing you through a checklist
- When in doubt about wording: shorter is better. "Move with WASD" beats "Use the WASD keys on your keyboard to move your character."

## Output Format

**Part 1 — Design**
- Tutorial step table (as above)
- Scene tree placement and queue mechanism answer (2–3 sentences each)

**Part 2 — Implementation**
- TutorialManager autoload script (complete GDScript)
- EventBus signal additions (exact lines to add)
- HUD TutorialTooltip node description (node type, name, parent, key properties, tween logic)
- ProgressionManager save/load additions (exact lines only)
- Pause menu "Skip Tutorial" button handler (exact lines + scene node description)
