# Task 23 — Export presets + itch.io pipeline
**Tier**: 2 → Sonnet | **Depends on**: 10 (menu-first boot) recommended; runnable any time in M7.

---

<goal>
Set up export presets and a repeatable build+upload pipeline, shipping to itch.io first as the pipeline test (per `docs/release_pipeline.md` → "Export Presets" + "Distribution → itch.io"). Exercising the full export→upload cycle BEFORE launch is the point.
</goal>

<context>
- Godot 4.6.1, Compatibility renderer. Export templates must match the editor version exactly.
- Targets now: Windows Desktop x86_64 (embedded PCK, single exe, debug off) and Linux/X11 x86_64 (self-contained; doubles as the Steam Deck binary later). macOS deferred (needs notarization — out of scope this task).
- Headless build command shape: `godot --headless --export-release "Windows Desktop" build/windows/extraction-survivors.exe`.
- Butler: install + `butler login` are interactive/credentialed — generate the commands and a script, but flag the login + first push for Ben to run if credentials aren't available in-session.
- `export_presets.cfg` is committed; `build/` is gitignored.
</context>

<requirements>
- Both presets created (via Godot MCP export tools or export_presets.cfg authored carefully — this cfg file is one Godot generates; creating it textually is acceptable, verify by running an export).
- A `build.ps1` (PowerShell 5.1-compatible: no `&&`, no ternary) that: reads version from project.godot, exports both targets to `build/<platform>/`, and prints the butler push commands (`butler push build/windows <user>/extraction-survivors:windows --userversion <ver>`, same for linux). Butler user/slug as variables at the top for Ben to fill.
- Run the Windows export in-session; launch the exe and reach the main menu (smoke level — full checklist is Ben's, in release_pipeline.md).
- Document in `docs/release_pipeline.md`: mark completed checkboxes, add the exact build commands, note the clean-machine test as Ben's TODO.
- Flag for Ben: Windows code signing (SmartScreen) is a paid-cert decision — list options briefly in the doc, don't attempt it.
</requirements>

<output_format>
export_presets.cfg + build.ps1 + .gitignore + doc updates, grouped conventional commit. Summary: export result, exe smoke result, Ben's remaining manual steps.
</output_format>
