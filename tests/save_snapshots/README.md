# Save Snapshots

Frozen `ProgressionManager` save files, one per format version. They are regression
fixtures: **every change to the save format must still load these cleanly** (via
`_migrate_save`) without losing unlocks, stats, or records.

| File | Format | Notes |
|------|--------|-------|
| `v1.json` | version 1 | A real dev save (12-class roster era) stamped `"version": 1`. The oldest format the shipping build must accept. |

## The rule (mirrored in `progression_manager.gd`)

When you change the save format:

1. Bump `ProgressionManager.SAVE_VERSION`.
2. Add a `_migrate_vN_to_vN+1(data)` step and wire it into `_migrate_save()`.
3. Add the new representative save here as `v<N+1>.json`.
4. Confirm **every** older snapshot in this folder still loads cleanly after migration.

## What the loader guarantees (verified 2026-07-21)

- **Versionless save** (`"version"` absent, i.e. every pre-versioning dev save) → treated
  as v0 and migrated to current. To reproduce a v0 fixture, take `v1.json` and delete its
  `"version"` field.
- **Current-version save** → loaded directly, no migration.
- **Corrupt / unparseable file** → copied to `user://save_corrupt_<unix>.json`, then the
  game starts fresh (defaults). The evidence is never silently overwritten.
- **Newer-version save** (`version` > `SAVE_VERSION`) → refused wholesale (never partially
  loaded); `ProgressionManager.save_newer_than_supported` is set and the main menu hides
  CONTINUE and steers the player to New Game.
