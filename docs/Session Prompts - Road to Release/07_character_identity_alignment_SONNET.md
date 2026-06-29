# Task 07 — Character identity alignment (names, passives, weapons)
**Tier**: 2 → Sonnet | **Depends on**: 05 (approved design doc). Parallel-safe with 06 ONLY if 06 hasn't started editing `data/characters.gd` — coordinate; otherwise run after 06.

---

<goal>
Apply the approved `docs/character_overhaul_design.md` to all character data and copy: new names, re-themed passive names/descriptions, starting-weapon assignments, and any weapon re-themes the doc specifies. No mechanical balance changes beyond what the doc explicitly justifies.
</goal>

<context>
- `data/characters.gd` (`CharacterData.ALL`) — names, costs, passives, starting weapons.
- `data/factories/character_factory.gd` — passive modifier construction keyed by passive_id (e.g. `shade_passive`); renaming passive ids requires updating every match arm and any save-state references — grep broadly (`scripts/`, `data/`), including `progression_manager.gd` for stored character ids.
- IMPORTANT: saved games store character ids/unlocks. If character ids change, existing saves break. Prefer keeping internal ids stable and changing only display names — if the design doc demands id changes, add a save-load alias map in ProgressionManager instead.
- Character-exclusive weapons: `data/weapons.gd` (Warden's Repeater, Spark's Pistol, Herald's Beacon) — re-theme names/descriptions per the doc.
- UI copy surfaces: roster panel (`scripts/ui/hub_roster_panel.gd`), launch panel (`scripts/ui/hub_launch_panel.gd`), unlock descriptions.
</context>

<requirements>
- All display names, passive copy, and weapon names match the design doc verbatim.
- Internal ids stay stable unless the doc says otherwise (see save-compatibility note above).
- A pre-overhaul save still loads: correct unlocks, correct selected character, new names displayed.
- Check copy lengths against panel layouts at 3× viewport scaling — long class names must not overflow buttons/labels (per CLAUDE.md UI rules, verify overflow before declaring done).
- Verify each of the 7 in a quick debug run: passive applies (check stats), correct starting weapon equips.
</requirements>

<output_format>
Code/data changes + one grouped conventional commit. Summary table: old name → new name → passive → weapon.
</output_format>
