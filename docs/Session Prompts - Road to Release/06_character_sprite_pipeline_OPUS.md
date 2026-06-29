# Task 06 — Per-character animated sprite pipeline
**Tier**: 3 → Opus | **Depends on**: 05 (approved `docs/character_overhaul_design.md`)

---

<role>
You are implementing the character sprite system for a Godot 4.6 survivors game with a component-based engine. Architecture quality matters: 7 characters now, more later, and this system touches the player scene that every run uses.
</role>

<objective>
Make the player render as the selected character's fantasy class with full animations (Idle/Walk/Attack/Dmg/Die), driven entirely by data in `CharacterData.ALL`. Today all characters share one sprite. The design contract is `docs/character_overhaul_design.md` — sprite sheet paths, frame counts, and timing notes live there; read it first and follow it exactly.
</objective>

<context>
- Read `docs/engine_reference.md` and `docs/character_overhaul_design.md` before coding.
- Player scene: `scenes/player.tscn`; script `scripts/entities/player.gd` already has `@onready var sprite: AnimatedSprite2D = $Sprite` (line ~90). Find every place the current animations are played/flipped before changing anything.
- Character selection flows: `ProgressionManager.selected_character` → `player._load_character_stats()` reads `CharacterData.ALL` (`data/characters.gd`).
- CLAUDE.md rules apply hard here: never hand-edit `.tscn` — use the Godot MCP tools for any scene-structure change; typed GDScript; data lives in Resources/static data, logic in components.
</context>

<constraints>
- Data-driven: `CharacterData.ALL` entries gain sprite metadata (sheet paths, frame counts, fps, frame size) per the design doc. Adding character #8 later must require zero code changes — only data + assets.
- Build `SpriteFrames` resources per character. Decide deliberately between: (a) pre-built `.tres` SpriteFrames resources generated once, or (b) runtime construction from sheet metadata. Weigh editor-friendliness, load time, and .import handling; document the choice.
- Animation state mapping: Idle ↔ no movement, Walk ↔ moving, Dmg ↔ on hit (must not interrupt-lock movement), Die ↔ death sequence before game-over screen, Attack ↔ tie to weapon fire only if it reads well at survivor fire rates — if attack anims fight the auto-fire cadence, default to Idle/Walk and document why.
- Handle differing frame sizes/offsets between True Heroes packs (design doc §3 flags these) — character swap must not shift the collision shape or feet position.
- Sprite flipping must follow existing movement/aim conventions.
</constraints>

<reasoning_guidance>
Trace the current sprite usage end-to-end first (hub preview may also render the player — check `scripts/hub.gd`, which colors a hub player per character). Decide where animation-state logic lives (player.gd vs a small helper) consistent with existing component patterns. Test the worst case: character with the largest frame-size delta from the current sprite.
</reasoning_guidance>

<output_format>
Code + scene changes (MCP tools) + any generated SpriteFrames resources, committed in grouped conventional commits. Update `docs/character_overhaul_design.md` implementation-notes section with what was built. Verify all 7 characters in a debug run: correct animations in hub and arena, correct death animation, no console errors.
</output_format>

<success_criteria>
Selecting any of the 7 characters shows the correct fantasy class fully animated in both hub and arena; collision/feet alignment is stable across all 7; adding a hypothetical 8th character is a pure data+asset exercise.
</success_criteria>
