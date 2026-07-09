# Release Pipeline

## Status

This doc tracks close-to-launch work: unfinished polish items, export setup, distribution plumbing, and post-release safety. Read alongside the higher-level roadmap for prioritization context.

Verification source: `docs/verification_findings.md` (generated 2026-05-02). All "confirmed" and "absent" calls below come from that audit, not estimates.

---

## Polish Items

### Tutorial

**Verified state:** No TutorialManager script exists. No tutorial autoload is registered in `project.godot`. The one tutorial-related reference in code is a comment in `scripts/entities/player.gd` noting "Phase 1 is exempt (tutorial phase)" — a hysteresis note, not a wired system. **The tutorial did not ship.**

**Decision needed:** Either build a TutorialManager for v1 or formally document that Phase 1 is the tutorial experience (no system, context-free first run).

Recommendation: skip a TutorialManager for v1. Instead, add a one-time "first run" flag to ProgressionManager that shows tooltip overlays during the first Caves run (weapon fires, first pickup, first extraction point reached). This requires no new autoload and no dedicated manager — just a checked flag and a thin overlay scene.

**Acceptance criteria (either path):**
- [ ] A new player can identify what their weapon does within 10 seconds of spawning
- [ ] A new player can find and attempt an extraction point without external guidance
- [ ] Every system encountered for the first time has one visible in-context cue (tooltip, highlight, or prompt)

---

### Settings Menu

**Verified state:** No settings script exists. No settings scene has been located. Settings are completely absent.

This is a blocking v1 item for any platform submission (audio sliders alone are typically required for Steam certification).

**Required surfaces:**

Audio:
- [ ] Master volume slider
- [ ] Music volume slider
- [ ] SFX volume slider
- [ ] Mute toggle

Display:
- [ ] Fullscreen toggle
- [ ] Vsync on/off
- [ ] Screen shake intensity (0–100%)

Controls:
- [ ] Keyboard rebinding (all InputMap actions)
- [ ] Controller support toggle / deadzone slider

Accessibility:
- [ ] Damage number toggle (on/off)
- [ ] Screen flash intensity (for hit flashes, phase transitions)
- [ ] Text size scale (at least Small / Normal / Large given 3× viewport)
- [ ] Color-blind mode (at minimum: deuteranopia-safe palette swap for status effect colors)

**Persistence rule:** Settings must save to a file separate from the progression save (`user://settings.cfg` or equivalent). Deleting your run progress must not reset audio levels. Use Godot's `ConfigFile` class — it is simpler than JSON and handles hot-reload gracefully.

**Implementation order:** audio sliders → fullscreen → save/load → controls rebinding → accessibility. Ship in that priority.

---

### Achievements

**Verified state:** `hub_records_panel.gd` exists and displays 7 lifetime stats. No achievement definitions, detection hooks, or unlock UI exist.

Required for a complete implementation:

- [ ] Achievement data file: `data/achievements.gd` with static array of `AchievementDefinition` (id, title, description, icon, threshold, stat_key)
- [ ] Detection hooks: listen on EventBus signals; compare accumulated values against `ProgressionManager` state at run-end (not per-frame)
- [ ] Unlock toast: a 2–3 second overlay notification on unlock (reuse `CombatFeedbackManager` style for arena; separate overlay for hub)
- [ ] Achievements sub-panel inside Records
- [ ] Steam achievement sync (if shipping on Steam): call `Steam.set_achievement(id)` on unlock; call `Steam.store_stats()` once per session

Start with 10–12 clear, achievable achievements (kill counts, extraction clears, boss kills, character unlocks). Avoid "play for 100 hours" filler.

---

### End-Game / Win State

**Verified state:** No win state, credits scene, or "Inferno cleared" flag exists in code. The game currently has no terminal success condition.

**Decisions required:**

1. **Is Inferno the final biome?** Recommendation: yes — extracting from Inferno Phase 5 triggers win. One clear endpoint, no ambiguity.
2. **What does winning do?** Recommendation for v1: credits screen → return to hub → account-level "Inferno Cleared" flag in ProgressionManager → one cosmetic unlock per character (palette swap or title suffix). This is shippable in a day or two and gives closure without scoping into new game+.
3. **Is the win per-character or per-account?** Recommendation: per-account flag (did anyone extract from Inferno?), with per-character "cleared with X" tracking stored alongside character stats in ProgressionManager.
4. **New game+ / harder difficulty:** Cut to v1.5. The phase scaling multipliers already make Phase 5 Inferno brutal. Ship the win state first.

**Acceptance criteria:**
- [ ] Inferno Phase 5 extraction triggers a distinct win flow (not just hub return)
- [ ] Credits are accessible (at minimum from win screen; ideally from main menu too)
- [ ] Win state is recorded in save and persists across sessions
- [ ] A second win on the same account does not break anything

---

### Main Menu

**Verified state:** Game opens directly into the hub. No main menu scene exists.

Required:
- [ ] Title screen with: New Game, Continue (disabled if no save), Settings, Quit
- [ ] Credits accessible from title (or win screen — both is ideal)
- [ ] MiniFantasy UI Overhaul aesthetic consistent with hub panels (C_CARD, C_AMBER, C_BORDER palette)
- [ ] "Continue" reads the save state from ProgressionManager and routes to hub; "New Game" clears save after confirmation dialog

This is roughly a half-day scene build. Do it after the settings menu is wired, so the Settings button can immediately connect.

---

### Audio

**Verified state:** Audio assets are completely absent. No `assets/audio/`, `assets/sfx/`, or `assets/music/` directories exist. Zero audio implementation found.

This is a significant missing system. Blocking checklist:

- [ ] Source or create SFX: weapon fire, hit impact, enemy death, pickup collect, extraction channel start/complete, level-up chime
- [ ] Source or create music: hub ambient loop, at least one biome loop (Caves), boss encounter variant
- [ ] Wire AudioStreamPlayer nodes for music (autoplay loop) and a pooled SFX player
- [ ] Connect SFX to EventBus signals (damage dealt, enemy killed, etc.)
- [ ] Respect settings menu volume sliders once those are built

Likely the longest single item on this list. Prioritize SFX before music — a silent game is worse than a music-free one.

---

### Lore Archive Station

**Verified state:** Designed in the archived `systems_design_part3.md`. Not scripted. Not present as a hub panel script. `hub_reference.md` lists it as "not yet implemented" alongside Insurance and Codex.

Recommendation: cut to v1.5 unless lore content is already written. The Codex panel (CodexManager autoload exists, but no UI panel script) covers most of the discovery-satisfaction loop. Shipping a placeholder Lore Archive button that says "Coming Soon" is acceptable; shipping an empty panel is not.

---

## Controller Support Audit

**Verified state:** Only keyboard bindings are visible in `project.godot`'s InputMap. No joypad bindings confirmed in the project file. No controller-specific autoload or handler was found.

Controller support is required for Steam Deck certification (Deck Verified requires full controller navigation with no keyboard dependency).

**Checklist — Input bindings:**
- [ ] Every `InputMap` action has a joypad equivalent assigned (buttons + analog axes)
- [ ] Aim: twin-stick (right stick controls aim direction) OR auto-aim on nearest enemy when no stick input
- [ ] Dodge/interact/extraction: mapped to face buttons
- [ ] Hub open/close: mapped to shoulder buttons or start

**Checklist — UI navigation:**
- [ ] Hub panels navigable with D-pad and left stick (`ui_focus_next` / `ui_focus_prev` wired on all interactive controls)
- [ ] All buttons and sliders in hub panels (Armory, Workshop, Research, Roster, Records, Launch) focusable and activatable with confirm button
- [ ] ScrollContainers scrollable via D-pad (Godot 4 handles this via `ui_up` / `ui_down` if focus is set correctly)
- [ ] Settings menu fully navigable on controller (required before submitting)

**Checklist — Hot-swap and UX:**
- [ ] Plugging in a controller mid-session is detected (`Input.joy_connection_changed` signal)
- [ ] UI prompt glyphs switch to controller icons when a controller is active (even a simple "A to confirm" label change is sufficient for v1)
- [ ] Unplugging the controller mid-run does not crash or freeze (graceful fallback to keyboard)

**Acceptance criteria:**
- [ ] Full Caves run completable on controller without touching keyboard
- [ ] Hub fully navigable on controller without touching keyboard
- [ ] Settings menu accessible and adjustable on controller

---

## Export Presets

Presets live in `export_presets.cfg` (committed). Build output goes to `build/` (gitignored). Set up 2026-07-09; both presets verified with real headless exports.

### Build commands

Repeatable path: run `build.ps1` at the repo root (exports both targets, prints the butler push commands). Raw commands, if needed individually:

```
# Godot binary: E:\Godot\Godot_v4.6.1-stable_win64.exe (4.6.1.stable.official)
# Export templates: %APPDATA%\Godot\export_templates\4.6.1.stable\  (must match editor version exactly)
# NOTE: the output directory must exist before exporting (Godot errors with
#       "The given export path doesn't exist" otherwise) — build.ps1 creates it.

godot --headless --path E:\Projects\extraction-survivors --export-release "Windows Desktop" build/windows/extraction-survivors.exe
godot --headless --path E:\Projects\extraction-survivors --export-release "Linux/X11" build/linux/extraction-survivors.x86_64
```

Windows quirk: the Godot editor exe is a GUI-subsystem binary, so a plain shell invocation returns immediately and swallows output. `build.ps1` uses `Start-Process -Wait` with output redirection to get real exit codes; the `_console.exe` wrapper from the official download also works.

### Windows Desktop (x86_64)
- [x] Preset created, export template downloaded (4.6.1.stable templates installed 2026-07-09)
- [x] Embedded PCK (single executable — verified 151 MB exe, launches to main menu)
- [x] Debug info disabled for release (`--export-release`; console wrapper debug-only)
- [ ] Code signing with a valid certificate (eliminates Windows SmartScreen "unknown publisher" block — see "Windows Code Signing Options" below; **Ben's decision, not attempted**)
- [ ] Test on a clean Windows machine with no Godot installed (**Ben TODO**)

### Windows Code Signing Options (decision needed — Ben)

Unsigned exes trip SmartScreen ("Windows protected your PC") until download reputation accumulates. Options, cheapest first:

1. **Ship unsigned (v1 on itch.io)** — free. itch.io players expect this; SmartScreen warning appears but "More info → Run anyway" works. Reputation builds slowly with downloads. Reasonable for the itch pipeline test and early releases.
2. **Azure Trusted Signing** — ~$10/month subscription. Microsoft-backed, integrates with signtool. Individual-developer validation is available; cheapest legitimate signing route for a solo dev.
3. **Standard OV certificate** (Sectigo, SSL.com, Certum ~€70/yr "Open Source" tier) — signs the exe but SmartScreen reputation still builds over time; doesn't instantly remove the warning.
4. **EV certificate** (~$250–500/yr + hardware token or cloud HSM) — instant SmartScreen reputation. Overkill for itch.io; reconsider if/when shipping on Steam is imminent (Steam's own client wrapper reduces the need).

Recommendation: option 1 for the itch.io pipeline test now; revisit 2 before a wider launch.

### macOS (Universal Binary)
- [ ] Preset created with arm64 + x86_64 targets
- [ ] Notarization required for distribution outside App Store (Gatekeeper blocks unsigned apps by default on macOS 13+)
- [ ] Use Godot's built-in codesign/notarize steps or an external CI step
- [ ] Test on both Apple Silicon and Intel if possible

### Linux / X11 (x86_64)
- [x] Preset created (`Linux/X11` in export_presets.cfg)
- [x] Export as self-contained binary (embedded PCK, single 119 MB x86_64 binary — export verified 2026-07-09; runtime behavior untested, no Linux box in-session)
- [ ] Test on a clean Ubuntu 22.04 LTS VM (**Ben TODO**)

### Steam Deck (Linux)
- [ ] Same binary as Linux/X11, but verify separately
- [ ] Full controller navigation (see Controller Support section above)
- [ ] 1280×800 resolution renders correctly (Godot's viewport scaling should handle this — verify 3× scale fallback at non-1080p)
- [ ] Submit for Steam Deck Verified review after all controller criteria pass

---

## Distribution

### If shipping on Steam
- [ ] Steamworks SDK integration (use the [GodotSteam](https://godotsteam.com/) plugin — it is the standard for Godot 4 + Steam)
- [ ] App ID registered, depot IDs created for each platform
- [ ] Steam Cloud saves enabled (`user://` save path syncs automatically via Steamworks — low effort, high value)
- [ ] Achievement sync: call `Steam.set_achievement()` on each unlock; `Steam.store_stats()` once per session end
- [ ] Build pipeline: `godot --headless --export-release "Windows Desktop" build/windows/game.exe` → Steam content builder (`steamcmd +run_app_build`)
- [ ] Store page: capsule art, screenshots, trailer, short description, system requirements
- [ ] Demo / Early Access decision made before visibility goes public
- [ ] Controller support badge requires full joypad navigation (Deck Verified is a separate, stricter tier)

### If shipping on itch.io
- [ ] [Butler](https://itch.io/docs/butler/) installed and authenticated (`butler login`) (**Ben TODO** — interactive/credentialed, not run in-session)
- [ ] Upload pipeline (**Ben TODO**: fill `$ButlerUser`/`$ItchSlug` at the top of `build.ps1`; it prints these after each build):
  ```
  butler push build/windows <user>/extraction-survivors:windows --userversion 1.0.0
  butler push build/linux <user>/extraction-survivors:linux --userversion 1.0.0
  ```
- [ ] Pricing and visibility configured (pay-what-you-want, fixed price, or free)
- [ ] Web playable build: not recommended given asset size and lack of web export testing, unless explicitly prioritized
- [ ] itch.io does not require code signing or notarization — simplest platform to ship first for testing the export pipeline

### Other storefronts
GOG, Epic Games Store, and Microsoft Store are out of scope unless explicitly decided.

---

## Save Migration

Saves are JSON managed by `ProgressionManager`. There are two failure modes: format changes mid-development silently corrupt existing saves, and format changes post-release break players' saves with no recovery path.

**Mitigations to implement before v1:**

- [ ] Add a `"version": 1` integer field to the root of the save JSON (if not already present — check `progression_manager.gd`)
- [ ] Add a `_migrate_save(data: Dictionary, from_version: int) -> Dictionary` function to ProgressionManager that applies incremental transformations
- [ ] Each save format change increments the version and adds a migration step
- [ ] Snapshot a "v1.0" save file into `tests/save_snapshots/v1.0.json` before release; every subsequent change must have a passing migration from that snapshot
- [ ] On load, if `data.version < CURRENT_VERSION`, run migrations before returning data; if `data.version > CURRENT_VERSION`, show a "save from a newer version" warning and offer to start fresh rather than corrupting state

**Pre-release save test:**
- [ ] Create a save at v1.0 snapshot state
- [ ] Apply one format change, confirm migration runs cleanly
- [ ] Confirm all character unlocks, stat records, and run history survive migration

---

## Smoke Test Checklist

Run before every release build. No automation required — this is a manual 20-minute walkthrough.

**Boot:**
- [ ] Game opens to main menu (when built)
- [ ] New Game → character select → biome select works end-to-end
- [ ] Continue loads an existing save correctly
- [ ] Settings opens, sliders move, changes persist after restart

**Gameplay:**
- [ ] Full Caves run from spawn to extraction: enemies spawn, weapons fire, pickups drop, extraction channels
- [ ] Level-up screen appears and all upgrade options are selectable
- [ ] Run ends on extraction (not death) and returns to hub with run rewards applied
- [ ] Boss encounter in at least one biome triggers and completes correctly
- [ ] Phase transitions (1→2→3→4→5) occur without errors; EnemySpawnManager phase multipliers step up

**Persistence:**
- [ ] Save after a run, quit, relaunch: character unlocks and stat records persist
- [ ] Settings change persists across relaunch

**Platform:**
- [ ] Keyboard + mouse: full run playable
- [ ] Controller: full run playable without keyboard (when controller support is complete)
- [ ] No errors or warnings in Godot output log during a full run

**Stability:**
- [ ] Three consecutive runs without restarting the game: no memory growth visible in OS task manager
- [ ] Enemy cap reached (if applicable) does not cause framerate cliff

---

## Post-Release Safety

### Crash Reporting
- [ ] Integrate a crash reporter before launch. Options: Sentry (has a Godot 4 SDK), custom crash webhook, or a "please send this log file" dialog on crash (lowest friction for solo dev)
- [ ] At minimum: catch uncaught errors via `get_tree().connect("error_logged", ...)` and write them to `user://crash.log` with a timestamp and save state dump

### Hotfix Pipeline
- [ ] Confirm you can push a new build within 24 hours of a critical bug report
- [ ] Test the full export → upload cycle at least once before launch (not for the first time during a fire)
- [ ] Keep a list of the three most likely critical bugs (save corruption, crash on launch, extraction softlock) and know the fix path for each

### Telemetry (Optional, Opt-In)
- Recommendation: skip for v1 unless you already have infrastructure. Manual community feedback and Godot's output log are sufficient for a solo dev's first release.
- If added: opt-in only, clearly disclosed in settings, captures run outcome + character + biome (no PII). Useful for balance tuning if you get enough players.

### Versioning
- [ ] `project.godot` version string matches release tag
- [ ] Version displayed somewhere in-game (title screen or settings footer)
- [ ] Git tag created for each public release (`git tag v1.0.0`)
