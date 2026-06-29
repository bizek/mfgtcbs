# Task 25 — Store page copy
**Tier**: 2 → Sonnet | **Depends on**: M2 complete (character identities final). Runnable any time after; no code.

---

<goal>
Write the store copy for itch.io and Steam: short description, long description, feature bullets, tags. Capsule art / screenshots / trailer are Ben's — this is text only.
</goal>

<context>
- Ground every claim in the real game — read `docs/architecture_blueprint.md` (design principles), `docs/character_overhaul_design.md` (the 7 fantasy heroes), `docs/mod_interaction_matrix.md` (69 combos — a genuine selling point), and the hub/extraction loop docs. Do not invent features.
- Genre positioning: survivors-like × extraction. Honest comps: Vampire Survivors (auto-fire horde combat) meets extraction-loop risk/reward (bank your loot or push deeper). The descent structure (10-block dive, merchant mid-way, boss-gated portal) is the differentiator — lead with it.
- Pixel-art fantasy (Minifantasy aesthetic), solo-dev project. Tone: confident, concrete, zero marketing fluff ("epic", "stunning" banned).
</context>

<requirements>
- Steam short description: ≤300 chars, hook + loop + differentiator.
- Long description: 250–400 words, markdown/BBCode-friendly structure — hook paragraph, "The Loop" (descend/fight/extract-or-push), features list (7 heroes, weapon mods + combo discovery, boss, meta-progression hub), closing line.
- Feature bullets: 6–8, each ≤12 words, each verifiable in-game.
- Tags: 10–15 Steam tags ordered by relevance (e.g. Action Roguelike, Bullet Heaven, Pixel Graphics, Extraction…).
- itch.io variant: same long description trimmed ~30% with a more personal solo-dev voice.
- 2–3 candidate taglines for the capsule art.
</requirements>

<output_format>
Write `docs/store_page_copy.md` with sections per deliverable. No commit of anything else.
</output_format>
