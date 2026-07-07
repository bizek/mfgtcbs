# Task 16 — First-run onboarding tooltips
**Tier**: 2 → Sonnet | **Depends on**: M2 complete (tooltips reference final character identities). Parallel-safe with 17.

---

<goal>
Add lightweight first-run onboarding — NO TutorialManager (decision recorded in `docs/release_pipeline.md` → "Tutorial"): a one-time flag in ProgressionManager plus contextual tooltip overlays during the first run.
</goal>

<context>
- Acceptance criteria from the release doc: a new player can (a) identify what their weapon does within 10 seconds of spawning, (b) find and attempt extraction without external guidance, (c) get one visible in-context cue per first-encountered system.
- Cue moments (first run only, each shows once): spawn (WASD to move, aim with the mouse, LMB chains your combo — tap to chain, hold for the channel), RMB special (first time the player has been in combat ~5s without using it), Q/E class skills (same nudge pattern), Space dash (first time surrounded or after first damage taken), first enemy kill / XP pickup (move to collect), first level-up screen (pick an upgrade), first weapon/mod pickup (what it is), depth meter (descend to find the portal), first time instability rises (name it, point at the meter — design-audit §5.5: "Unsettled" means nothing to a new player until anchored), first extraction window (channel to extract). Combat is manual combo-chain combat (docs/combat_chain_architecture.md) — there is NO auto-fire; never describe the weapon as firing automatically. Keep input hints generic across the 10 class kits (every kit has LMB combo / RMB special / Q/E skills / Space dash; the specific moves differ per class).
- `ProgressionManager` stores a `first_run_complete` flag (persisted; respect save versioning from task 11 — no version bump needed for additive keys if `_migrate_save` tolerates missing keys; verify it does).
- Implement as one thin overlay scene (HUD layer) that listens to existing EventBus/manager signals — no new autoload. HUD: `scripts/ui/hud.gd`.
- Style: small panel, hub palette, auto-dismiss after ~5s or on the prompted action; never pause the game; never stack more than one.
</context>

<requirements>
- Tooltips trigger once each, in a sensible order, only when `first_run_complete` is false; flag set on first run end (extraction OR death).
- Text sized for 3× viewport scaling; readable but unobtrusive (corner placement, not center-screen except the spawn cue).
- A debug-panel button "Reset first-run" for testing (`scripts/ui/debug_panel.gd`).
- Verify: fresh save → full first run shows all cues exactly once; second run shows none.
</requirements>

<output_format>
Overlay scene + flag + debug reset, grouped conventional commit. List final tooltip copy in the summary for Ben's review.
</output_format>
