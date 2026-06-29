# Task 19 — Controller support: gameplay bindings + aim
**Tier**: 2 → Sonnet | **Depends on**: none (M6 entry point)

---

<goal>
Make a full run playable on controller without touching the keyboard. Verified state: only keyboard bindings exist in project.godot's InputMap.
</goal>

<context>
- Spec: `docs/release_pipeline.md` → "Controller Support Audit" (bindings section).
- Enumerate current InputMap actions from project.godot first; map every gameplay action to joypad (left stick = WASD movement; face buttons = interact/dodge/confirm; start = pause).
- Aim: weapons auto-fire — determine how aim direction is currently derived (mouse position? nearest enemy?) by reading the weapon/targeting code (`docs/engine_reference.md` targeting vocabulary, BehaviorComponent). Implement: right stick aims when deflected beyond deadzone; when idle, fall back to existing behavior (auto-aim nearest if that's the current model). Keyboard/mouse behavior must be 100% unchanged.
- Use Godot's InputMap joypad events in project.godot (via `set_input_action` MCP tool or ProjectSettings) — not runtime-only bindings, so task 12's rebinding can read them.
- Add deadzone handling on both sticks (Godot's built-in action deadzone; default 0.2–0.25).
</context>

<requirements>
- Every gameplay action joypad-bound; movement analog (use `Input.get_vector` if movement currently reads discrete actions — check player.gd and preserve feel).
- Right-stick aim works in a full descent: weapons fire where aimed, merchant/altar/extraction interactions work on face buttons.
- Mid-session connect/disconnect (`Input.joy_connection_changed`) does not crash; input just works from whichever device acts.
- Verify with a controller: full Caves run, spawn to extraction, keyboard untouched. If no physical controller is available in this session, state that clearly and list exactly what Ben must verify by hand.
</requirements>

<output_format>
InputMap changes + aim code, grouped conventional commit. Summary: binding table (action → button/axis).
</output_format>
