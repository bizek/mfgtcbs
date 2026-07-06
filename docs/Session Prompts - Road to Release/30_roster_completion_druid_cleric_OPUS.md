# Task 30 — Roster completion: The Druid + The Cleric
**Tier**: 3 → Opus (kit design + cross-system: combo graphs, skills, pets/summons, shapeshift)
**Depends on**: none hard. Run BEFORE 31 (class mod architecture) so the mod design doc covers all 12 classes.

---

<goal>
Add the last two characters of the locked 12-class roster (Ben, 2026-07-04 — see
`docs/character_overhaul_design.md` §1 "Roster expansion target"): **Druid** (True Heroes I) and
**Cleric** (True Heroes II). Pure data + assets per the factory pattern — a new combo character
is a new `CharacterData.ALL` entry plus ChainFactory/SkillFactory builders; no engine code.
</goal>

<context>
- Read CLAUDE.md, then `docs/combat_chain_architecture.md`, then how the three newest characters
  (Ravager/Whisper/Deadeye in `data/characters.gd` + their ChainFactory/SkillFactory builders)
  were wired — they are the pattern to mirror, including the Q/E skill layer and class dashes.
- **Full asset utilization is mandatory** (CLAUDE.md rule): all four facing rows via the
  established quadrant system, frame-matched `_Effect` overlays on the ComboFx sprite, and the
  ENTIRE special package per class:
  - Druid (Pack I): Root_Summoning, Shape_Shifting (3 forms) — the shapeshift forms are the kit's
    identity; design them as combo stances or a transform skill, whatever the choreography-graph
    machinery supports without new engine systems.
  - Cleric (Pack II): Divine Fire, Prayers, IdleStart/End flourish.
- Any summon (roots, spirit animals) follows the CLAUDE.md pet standard: autonomous entity with
  own locomotion + leash — never lerp-glued. Reuse the FireFamiliar/BloodElemental pattern.
- Passives: design one per character in the existing style (flat, readable, class-flavored — see
  Bloodrage/Killing Intent/Calm Hands). Unlock costs continue the ladder past Deadeye's 6000.
- Portraits via the Portrait Generator pipeline notes in character_overhaul_design.md §3 — if the
  app can't be run in-session, use the row-0 idle upscale fallback and flag it for Ben.
</context>

<requirements>
- KIT DESIGN FIRST: append a §2.8/§2.9-style section per character to
  `docs/character_overhaul_design.md` (sprite tables, combo graph, RMB special, Q/E skills, dash
  style, passive, costs) and summarize it for Ben's approval in your first reply BEFORE bulk
  implementation. Ben approves or redlines; then implement.
- Both characters: CharacterData entries (sprite blocks with exact per-pack filenames — verify on
  disk, packs have naming gotchas), ChainFactory combo graph, SkillFactory Q/E skills, hub
  roster/launch panel presence (should be automatic — verify, and check panel overflow at 3×
  per the CLAUDE.md hub UI rule since the roster grows to 12).
- Update the passive-tree affinity table in `docs/passive_tree_spec.md` §1 (provisional slots:
  Cleric→Might, Druid→Arcana — confirm or change with Ben during kit approval) and the affinity
  data table in the hub passive panel if task 28 has run.
- Validate-compile everything; smoke-test both characters spawn, combo, skill, and dash in a
  debug run. Rendered feel checks are Ben's in Godot — list what to verify.
</requirements>

<output_format>
Design doc sections + data/factory code, grouped conventional commits. Summary: both kits at a
glance + Ben's playtest checklist.
</output_format>
