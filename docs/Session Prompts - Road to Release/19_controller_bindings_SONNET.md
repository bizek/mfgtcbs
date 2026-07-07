# Task 19 — Controller support: gameplay bindings + aim
**Tier**: 2 → Sonnet | **Depends on**: none (M6 entry point)

---

<goal>
Make a full run playable on controller without touching the keyboard. Verified state: only keyboard bindings exist in project.godot's InputMap.
</goal>

<context>
- Spec: `docs/release_pipeline.md` → "Controller Support Audit" (bindings section).
- Enumerate current InputMap actions from project.godot first. The combat model is manual combo-chain combat (docs/combat_chain_architecture.md, docs/manual_fire.md): mouse-cursor aim, LMB = light combo (tap AND hold gestures — ConditionInputBuffered/ConditionInputHeld read real press/release timing), RMB = special (tap and hold variants), Q/E = class skills, Space = dash. Map: left stick = movement, right stick = aim, right trigger/R1 = light combo, left trigger/L1 = special, face buttons = Q/E skills + interact, B/circle or a bumper = dash, start = pause. Tap-vs-hold must work identically on triggers (the input layer tracks held_for — verify it reads joypad actions the same as mouse buttons).
- Aim: the player faces and strikes toward the cursor (quadrant facing rows). Implement: right stick sets the aim vector when deflected beyond deadzone and it persists while sticks are idle (a melee combo needs a stable facing, not a snap-to-nearest); consider soft aim-assist toward the nearest enemy within a small cone for ranged combo shots. Keyboard/mouse behavior must be 100% unchanged.
- Use Godot's InputMap joypad events in project.godot (via `set_input_action` MCP tool or ProjectSettings) — not runtime-only bindings, so task 12's rebinding can read them.
- Add deadzone handling on both sticks (Godot's built-in action deadzone; default 0.2–0.25).
</context>

<requirements>
- Every gameplay action joypad-bound; movement analog (use `Input.get_vector` if movement currently reads discrete actions — check player.gd and preserve feel).
- Right-stick aim works in a full descent: combos strike where aimed (all four facing rows engage correctly), tap/hold combo branches and channels work on triggers, Q/E skills and dash fire, merchant/altar/extraction interactions work on face buttons.
- Mid-session connect/disconnect (`Input.joy_connection_changed`) does not crash; input just works from whichever device acts.
- Verify with a controller: full Caves run, spawn to extraction, keyboard untouched. If no physical controller is available in this session, state that clearly and list exactly what Ben must verify by hand.
</requirements>

<output_format>
InputMap changes + aim code, grouped conventional commit. Summary: binding table (action → button/axis).
</output_format>
