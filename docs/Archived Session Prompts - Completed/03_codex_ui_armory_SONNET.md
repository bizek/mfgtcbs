# Session Prompt: Codex UI — Armory Integration

**Model:** Sonnet
**Scope:** UI scene and script for the codex grid in the armory
**Depends On:** Session 01 (design doc) and Session 02 (data structures) must be complete
**Output:** Codex UI scene and scripts

## Context

We have a survivors-like extraction game in Godot 4.6 (GDScript). The armory is a hub screen where players equip weapons and mods before a run. We've built:
- A mod interaction matrix defining every combo (Session 01)
- A CodexManager autoload with CodexEntry resources tracking discovery/reveal/mastery (Session 02)

Now we need the UI that lets players SEE the codex in the armory. This is a key dopamine system — the half-filled grid that says "there's more to discover."

## Design Intent

The codex should feel like a collection/achievement system. Think Pokédex energy — you see silhouettes of what you haven't found yet. The grid itself is a motivator.

## Your Task

### 1. Codex Grid Panel
Create a UI panel (`codex_grid_panel.tscn` + `codex_grid_panel.gd`) that displays:
- A grid/matrix with mod names on both axes
- Each cell represents a mod pair combo
- Cell states:
  - **Unknown** (grey/dark) — player hasn't slotted this pair in armory yet. Show "?" icon
  - **Discovered** (dim color) — player slotted the pair in armory, combo name is visible, but mechanic shows "???"
  - **Revealed** (bright color) — player triggered it in a run, full description visible
  - **Mastered** (gold border/glow) — player hit the mastery threshold, bonus description visible
- Clicking/hovering a cell shows a detail tooltip or side panel with:
  - Combo name (if discovered+)
  - Combo description (if revealed+) or "???" 
  - Mastery progress bar (if revealed+)
  - Mastery bonus (if mastered)
- A completion counter: "47/82 Combos Discovered" style header

### 2. Armory Integration Hook
The codex grid should integrate into the existing armory flow:
- When a player slots two mods onto a weapon in the armory, call `CodexManager.discover_combo()` for that pair
- The codex grid should visually update in real-time when a new combo is discovered (small animation/flash on the cell)
- Create a tab or button in the armory that opens the codex grid as an overlay or side panel

### 3. Reactive Mod Slot Preview
When the player is hovering a mod over an occupied slot (considering a pair), the codex grid should highlight the relevant cell:
- If unknown → pulse the "?" to hint "there's something here"
- If discovered → briefly show the combo name
- This creates a preview loop: "if I equip this mod, I'll discover THAT combo"

### 4. Filter/Sort Options
Simple filters:
- Show All / Discovered Only / Undiscovered Only / Mastered Only
- Filter by mod category (Behavior, Elemental, Stat, Unique)
- Sort by: discovery order, alphabetical, mastery progress

## Technical Constraints
- Use the existing container hierarchy pattern (MarginContainer → VBoxContainer) — we've already standardized on this for hub panels
- The grid will have ~80+ cells. Use a GridContainer or dynamically built grid, but make sure it performs well
- Pull all data from CodexManager — the UI should be purely a view layer with no combo logic of its own
- Color-code cells by combo_type to make the grid scannable at a glance
- Emit signals for any interaction so other armory systems can react

## Visual Style Notes
- Cells should use the mod's associated color as an accent when revealed
- Unknown cells should feel mysterious, not empty — a slight shimmer or "?" icon
- Mastered cells should feel prestigious — gold border, subtle particle or glow
- The grid should feel like a treasure map that's slowly being filled in

## What NOT To Do
- Don't implement combo EFFECTS or gameplay triggers
- Don't modify the CodexManager logic — just read from it
- Don't build the in-run combo trigger notification (that's a separate session)
- Don't worry about the mastery bonus actually applying to gameplay yet
