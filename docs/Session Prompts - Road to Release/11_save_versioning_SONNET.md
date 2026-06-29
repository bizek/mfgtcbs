# Task 11 — Save versioning + migration scaffold
**Tier**: 2 → Sonnet | **Depends on**: none. Parallel-safe with 09/10.

---

<goal>
Add version-stamped saves and a migration path to `ProgressionManager` before release locks the format. Verified absent: no `version` field exists in the save JSON today.
</goal>

<context>
Spec: `docs/release_pipeline.md` → "Save Migration" section. Saves are JSON managed by `scripts/managers/progression_manager.gd`.
</context>

<requirements>
- `"version": 1` integer at the save JSON root, written on every save.
- `_migrate_save(data: Dictionary, from_version: int) -> Dictionary` applying incremental per-version steps (currently a no-op chain ending at 1; structure ready for v2).
- Load behavior: missing version field → treat as version 0 and migrate (covers all pre-existing dev saves); `version > CURRENT` → warn ("save from a newer version") and offer fresh start, never partially load.
- Corrupt JSON → back up the bad file to `user://save_corrupt_<timestamp>.json`, start fresh, log it. Do not silently overwrite the evidence.
- Snapshot: copy a representative current save to `tests/save_snapshots/v1.json` and add a comment block in progression_manager.gd stating the rule: every future format change bumps the version, adds a migration step, and must load this snapshot cleanly.
- Test: load a versionless save (migrates), a v1 save (clean), a corrupt file (backup + fresh), a fake v99 save (warning path). Verify unlocks/stats/records survive the versionless→v1 migration.
</requirements>

<output_format>
progression_manager.gd changes + snapshot file + grouped conventional commit. List the four test results in the summary.
</output_format>
