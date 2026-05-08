# Mod Combo System — Session Prompts

## Overview
These session prompts implement the full mod interaction + codex discovery system.
Copy-paste each prompt into a Claude Code session in order.

## Execution Order & Dependencies

```
Session 01 (Sonnet) — Mod Interaction Matrix Design Doc
    │   Pure design work. No code. Produces the master reference doc.
    │
    ├── Session 02 (Haiku) — Codex Data Structure
    │       Reads the design doc, creates GDScript resources and CodexManager.
    │       │
    │       ├── Session 03 (Sonnet) — Codex UI in Armory
    │       │       Builds the grid UI. Reads from CodexManager.
    │       │
    │       ├── Session 04 (Sonnet) — Combo Effect System (Runtime)
    │       │       The big one. Implements actual combo effects during runs.
    │       │       │
    │       │       ├── Session 05 (Haiku) — HUD Notification
    │       │       │       Small popup when combos are first discovered in-run.
    │       │       │
    │       │       └── Session 06 (Haiku) — Mastery Bonus System
    │       │               Defines and applies mastery rewards.
    │       │
    │       └── (Sessions 05 & 06 can run in parallel after 04)
    │
    └── (Session 03 can run in parallel with 04)
```

## Model Assignments
- **Sonnet**: Design doc, UI, combo effect system (complex reasoning / creative work)
- **Haiku**: Data structures, small UI elements, bonus definitions (mechanical / well-scoped)

## Notes
- Each prompt tells the session what files it depends on — make sure they exist
- Every prompt says "read CLAUDE.md first" or references the project docs folder
- No prompt modifies existing weapon/mod code — they all layer on top
- VFX is not included here — that's a separate set of sessions after the system works
- Sound design is not included — same, separate sessions later
- Balance tuning is not included — numbers from the design doc are placeholders
