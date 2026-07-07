# Task 01 — Commit the dirty working tree
**Tier**: 1 → Haiku | **Depends on**: none

---

Commit all uncommitted changes in this repo as grouped conventional commits.

The working tree contains: LDtk level/block edits under `assets/Maps/Levels/` (Merchant block tile painting + PropCollision schema propagation), `scripts/systems/ldtk_loader.gd` (PropCollision IntGrid layer support), `docs/ldtk_schema.md` + `docs/ldtk_workflow.md` (PropCollision documentation), `project.godot`, and `.claude/settings.local.json`.

Steps:
1. Run `git status` and `git diff --stat` to see everything.
2. Group into logical commits (e.g. one for the loader feature + docs, one for LDtk content, one for settings). Use conventional commit format matching `git log` style (`feat(ldtk): ...`, `chore: ...`).
3. After staging each group and after the final commit, run `git status` to confirm zero unstaged or untracked files remain.

Output format: the commits themselves. Reply with a one-line summary per commit hash. Do not push.
