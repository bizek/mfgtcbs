# 28 — Passive Tree Hub UI Panel

**Tier:** 3 → Opus-class (rendered UI at 3× scaling, MCP scene tooling, graph layout)
**Depends on:** 26 (API). Run after 27 if possible (keystone visuals), but not blocked by it.

```
You are working in a Godot 4.6.1 GDScript survivor/extraction game (Extraction Survivors,
E:\Projects\extraction-survivors). Read CLAUDE.md, docs/hub_reference.md, then
docs/passive_tree_spec.md §5.4 (authoritative UI requirements), then docs/passive_tree.md (the
ProgressionManager API + node-state recipe written by the backend session).

GOAL: Build the hub panel where the player spends passive points into the tree, wired into the
hub as a new station/tab.

PROJECT UI RULES (mandatory):
- NEVER hand-edit .tscn files — use the Godot MCP editor tools (godot-mcp-pro) for ALL scene
  structure changes. Hand-editing strips instanced sub-scene ownership and font UIDs.
- 640×360 viewport at 3× integer scaling. Match the font sizes of existing hub panels.
- The tree WILL overflow the viewport: wrap it in a ScrollContainer with SHOW_AS_NEEDED
  (never SHOW_NEVER — it clips).

PATTERN TO FOLLOW: hub panels extend scripts/ui/hub_panel_base.gd (see hub_workshop_panel.gd,
hub_roster_panel.gd, etc.). Mirror how they're instantiated/opened by scripts/hub.gd and
registered as stations, how they read ProgressionManager, and how they refresh. Slot the new
panel in consistently with docs/hub_reference.md.

PANEL REQUIREMENTS (spec §5.4):
- Unspent passive points shown prominently; lifetime points somewhere subtle.
- Layout: Core section, then three branch columns (Might / Finesse / Arcana) rendered as tier
  rows with simple connector lines between tiers; the 3 bridge nodes sit between their two
  columns. Readability over flashiness at this resolution.
- Each node: name, effect text, cost, rank/max_ranks, and state —
  available / locked (show "requires N pts in <Branch>" from the tier-gate rule) / maxed.
  Notables and keystones visually distinct (larger and/or bordered).
- Click an available node → ProgressionManager.allocate() → live-refresh points + ALL node
  states (a tier-gate can open mid-session). Respec button → refund_all() → full refresh.
- Optional flavor if cheap: subtle highlight on the selected character's affinity branch —
  read the mapping from docs/passive_tree_spec.md §1 (10 characters: Sellsword/Warden/Ravager→
  Might, Scavenger/Shade/Whisper/Deadeye→Finesse, Spark/Herald/Cursed→Arcana). Drive it from a
  small data table so adding Druid/Cleric later is a one-line change.

CONSTRAINTS:
- Typed GDScript; never := on untyped array access.
- ZERO progression logic in the UI — the panel only calls the ProgressionManager API and reads
  PassiveTreeData. If you need a rule the API doesn't expose, add it to ProgressionManager,
  not the panel.
- Node buttons can be built in code from PassiveTreeData (a generated grid inside an
  MCP-created scene shell is fine and avoids 59 hand-placed scene nodes) — but the panel
  scene/shell itself goes through MCP tools.
- Before declaring done: verify no overflow/clipping at 3×, and that allocate/respec round-trip
  updates every affected node state.

DELIVERABLES: the panel scene + script wired into the hub. This is rendered UI — summarize
what you built and ask Ben to open Godot to verify layout, scaling, allocate/respec flow, and
live state updates. Ben runs Godot himself for rendered checks.
```
