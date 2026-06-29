# Task 21 — Achievements system
**Tier**: 2 → Sonnet | **Depends on**: 04 (win flag exists as an achievement source). Parallel-safe with 22/23.

---

<goal>
Build the achievements system per `docs/release_pipeline.md` → "Achievements": definitions, detection, unlock toast, Records sub-panel. Steam sync is task 24 — design the unlock API so it can hook in (a single `achievement_unlocked(id)` signal is enough).
</goal>

<context>
- `scripts/ui/hub_records_panel.gd` already displays 7 lifetime stats from ProgressionManager — achievements piggyback on that stat plumbing where possible.
- Detection rule from the spec: compare accumulated values at run-end (and on hub load), not per-frame. A few event-shaped achievements (first boss kill, first extraction, game cleared) can unlock immediately on their EventBus/manager signal.
- Unlock state persists in the save (additive key; task 11's migration tolerates additive keys — verify).
</context>

<requirements>
- `data/achievements.gd`: static array of definitions — id, title, description, icon (reuse item/UI icons per `docs/item_icon_catalogue.md`), threshold, stat_key or event trigger.
- 12 achievements, all reachable in normal play, e.g.: first extraction, first boss kill, game cleared, kill milestones (500/5000), extraction count (5/25), unlock all characters, clear with N characters, discover N mod combos (CodexManager has discovery state), reach max depth without damage taken in a block, total gold earned. Adjust to what stats actually exist — check ProgressionManager before finalizing.
- Unlock toast: 2–3s overlay, works in arena AND hub, queues if multiple unlock at once (CombatFeedbackManager style precedent; combo_discovery_popup.gd is a similar existing pattern — reuse its approach).
- Records panel: achievements sub-section/tab — icon + title + description, locked entries greyed with hidden-or-shown description per definition flag; progress fraction shown for threshold achievements (e.g. 3120/5000 kills).
- `achievement_unlocked(id)` signal on the owning manager for task 24.
- Verify: trigger at least 3 achievements in a debug run (add temporary debug thresholds if needed, then restore), confirm toast, persistence across relaunch, and Records display. UI checked for overflow at 3× scaling.
</requirements>

<output_format>
Data file + detection + toast + panel changes, grouped conventional commits. Summary: the 12 achievements as a table.
</output_format>
