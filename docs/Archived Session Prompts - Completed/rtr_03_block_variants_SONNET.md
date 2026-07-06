# Task 03 — Author 3–4 new inner cave block variants + altar markers
**Tier**: 2 → Sonnet | **Depends on**: 01 (clean tree). Parallel-safe with 02.

---

<goal>
Add 3–4 new inner block variants to the Caves descent so 8 sampled inner slots stop visibly repeating (only 4 normal variants exist: 01_Open, 02_Pillars, 03_Choke, 04_Split). Also place at least two `altar`-payload Marker entities across the pool — currently altars rely on `any` anchors only.
</goal>

<context>
- Read `docs/ldtk_schema.md` and `docs/ldtk_workflow.md` in full before touching any LDtk file — they define the layer stack, entity defs, Marker tag/payload contract, and authoring rules.
- LDtk project: `assets/Maps/Levels/Level 1 - Caves.ldtk` with per-block `.ldtkl` files in the sibling folder. Blocks follow the `Block_Caves_NN_Name` naming pattern.
- Block sequence logic and the normal pool live in `scripts/main_arena.gd` (~line 290, `BLOCK_COUNT = 10`) — new variants must be added to the pool there.
- Existing blocks are valid references for layer structure, IntGrid Floor painting (value 1 walkable; 0 and 2 solid), seam alignment (player must walk across block seams), and EventTrigger marker placement.
- `EventSpawnManager` consumes Markers with `tag=EventTrigger`; payloads: `any`, `merchant`, `altar`.
</context>

<requirements>
- Each new block: full IntGrid Floor painted, walkable top and bottom seam openings aligned with existing blocks, Cave_Tiles visuals, at least one EventTrigger marker (`any` or `altar` payload).
- Distinct layouts — aim for shapes not covered by the existing four (e.g. cavern loop, narrow ledges, central hazard chamber).
- Copy an existing `.ldtkl` as the starting template; update the `.ldtk` project file's level table and `externalRelPath` correctly (see commit d9458a7 for a past externalRelPath fix).
- Register new variants in the normal pool in `main_arena.gd`.
- Verify in-game: run several descents in debug mode, confirm new blocks load, seams are walkable, markers fire events, no loader warnings in the output log.
</requirements>

<output_format>
New `.ldtkl` files + project file update + the pool change, committed as one conventional commit. Summarize each new block's layout in a sentence.
</output_format>
