# Task 05 — Character Overhaul design doc: fantasy archetype mapping
**Tier**: 3 → Opus | **Depends on**: none (M2 entry point). Ben reviews the output before 06/07 run.

---

<role>
You are the game designer for Extraction Survivors, a Godot 4 survivors/extraction hybrid built entirely on Minifantasy pixel art. You are proposing a full character roster overhaul for the solo dev (Ben) to approve.
</role>

<objective>
Produce a design document mapping all 7 existing characters to fantasy class archetypes backed by sprite sets from the Minifantasy True Heroes packs. The goal: each character gets a coherent class fantasy (name, sprite, passive, starting weapon) so future kit design answers to the archetype instead of being invented from scratch. This doc is the contract for implementation tasks that follow — every ambiguity you leave unresolved becomes a blocked session later.
</objective>

<context>
- Current roster (from `data/characters.gd`, `CharacterData.ALL`): The Drifter (free, no passive), The Scavenger (+pickup radius/loot find), The Warden (armor doubles below 50% HP), The Spark (+0.75 crit multiplier), The Shade (15% dodge + invisibility on dodge), The Herald (ability damage/CDR, slots reserved for future actives), The Cursed (+20% all stats, starts at instability 31).
- Character-exclusive weapons exist: Warden's Repeater, Spark's Pistol, Herald's Beacon (`data/weapons.gd`, drop_weight 0).
- Sprite sources: `assets/minifantasy/Minifantasy_TrueHeroes_v1.0`, `_True_Heroes_II_v1.0`, `_True_Heroes_III_v1.1`, `_True_Heroes_IV_v1.1`. Each hero has Idle/Walk/Attack/Dmg/Die (some Jump) sheets. Inventory what classes actually exist in each pack before mapping — do not assume.
- Portraits: `assets/minifantasy/Minifantasy_Portrait_Generator_Graphical_Assets_v1.0`.
- Player scene already uses `AnimatedSprite2D` (`scripts/entities/player.gd:90`, node `$Sprite`) — implementation will be a per-character SpriteFrames swap.
- Suggested starting points (overridable if the packs suggest better fits): Shade→Rogue, Spark→Wizard/Sorcerer, Warden→Knight/Paladin, Scavenger→Ranger, Cursed→Death Knight/Cursed One, Herald→Battlemage/Cleric, Drifter→an everyman class (Squire/Adventurer).
- Check each used pack's license file (`CommercialLicense.txt` vs Patreon) and note which license covers commercial use.
</context>

<constraints>
- Exactly 7 characters; keep the existing unlock-cost ladder (free → 5000) and passive POWER level — this is an identity overhaul, not a balance rework. Passives may be re-themed/renamed but mechanical changes need explicit justification.
- Every chosen sprite set must have at minimum Idle/Walk/Attack/Dmg/Die animations at consistent frame sizes; record sheet paths and frame counts per animation in the doc.
- Starting weapons must make class sense (Knight with a bow fails this test); reuse existing weapons from `data/weapons.gd` where possible, flag any weapon that needs a re-theme.
</constraints>

<reasoning_guidance>
- Inventory first, map second: list available True Heroes classes with their animation completeness, then assign.
- Weigh silhouette distinctness — 7 heroes must read differently at 640×360 gameplay scale.
- For each mapping, sanity-check the passive against the fantasy ("dodge + vanish" is perfect Rogue; if a passive fights its class, propose the minimal re-theme).
- Resolve every "it depends": name, class, sprite paths, portrait approach, passive name + description copy, starting weapon, unlock cost, one-line character fantasy.
</reasoning_guidance>

<output_format>
Write `docs/character_overhaul_design.md`:
1. Sprite inventory table (pack → classes → animation completeness → license status)
2. One section per character: old name → new name, class, sprite sheet paths + frame counts, portrait plan, passive (id, themed name, description copy), starting weapon, unlock cost, one-line fantasy
3. Implementation notes: anything tasks 06–08 must know (frame size differences between packs, attack animation timing concerns, weapon re-themes needed)
4. Open questions for Ben (only if genuinely unresolvable)
</output_format>

<success_criteria>
A follow-up session can implement the sprite pipeline and renames from this doc alone, without opening the asset packs to make decisions. Ben can approve or redline it in one read.
</success_criteria>
