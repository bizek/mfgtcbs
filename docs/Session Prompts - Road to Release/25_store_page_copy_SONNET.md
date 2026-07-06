# Task 25 — Store page copy
**Tier**: 2 → Sonnet | **Depends on**: M2 complete (character identities final). Runnable any time after; no code.

---

<goal>
Write the store copy for itch.io and Steam: short description, long description, feature bullets, tags. Capsule art / screenshots / trailer are Ben's — this is text only.

PREREQUISITES (design audit, `docs/design_audit_2026-07-06.md`): D5 — Ben must have picked the
game's real name first ("Extraction Survivors" is a working title and fails the positioning
test). Use the audit's §6 one-sentence pitch as the positioning spine: "Pick a hero with a real
combo kit, carve through the horde, and decide at every portal: bank your loot, or dive deeper."
</goal>

<context>
- Ground every claim in the real game — read `docs/architecture_blueprint.md` (design principles), `docs/character_overhaul_design.md` (the fantasy-class roster — count the LIVE characters in `data/characters.gd` at write time; 10 today, 12 planned), `docs/combat_chain_architecture.md` (manual combo-chain combat), `docs/mod_interaction_matrix.md` (69 combos — a genuine selling point), `docs/class_mod_system.md` if it exists by then (per-class ability mods), and the hub/extraction loop docs. Do not invent features.
- Genre positioning: this is NOT an auto-fire survivors-like — combat is manual combo-chain melee/ranged (tap-to-chain, hold-to-channel, class skills, dash) in a horde arena. Positioning: character-action combat × horde survival × extraction risk/reward (bank your loot or push deeper). The two differentiators to lead with: real combo combat where every class plays like its own character-action kit, and the descent structure (10-block dive, merchant mid-way, boss-gated portal). Comps: Hades-adjacent combat feel meets Vampire Survivors horde density meets extraction-loop stakes.
- Pixel-art fantasy (Minifantasy aesthetic), solo-dev project. Tone: confident, concrete, zero marketing fluff ("epic", "stunning" banned).
</context>

<requirements>
- Steam short description: ≤300 chars, hook + loop + differentiator.
- Long description: 250–400 words, markdown/BBCode-friendly structure — hook paragraph, "The Loop" (descend/fight/extract-or-push), features list (the class roster with real combo kits, weapon + class mods, mod-combo discovery, boss, passive tree + meta-progression hub), closing line.
- Feature bullets: 6–8, each ≤12 words, each verifiable in-game.
- Tags: 10–15 Steam tags ordered by relevance (e.g. Action Roguelike, Bullet Heaven, Pixel Graphics, Extraction…).
- itch.io variant: same long description trimmed ~30% with a more personal solo-dev voice.
- 2–3 candidate taglines for the capsule art.
</requirements>

<output_format>
Write `docs/store_page_copy.md` with sections per deliverable. No commit of anything else.
</output_format>
