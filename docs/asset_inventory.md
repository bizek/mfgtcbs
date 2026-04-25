# Asset Inventory
### Phase 6 Output | What We Have to Work With

---

## Asset Strategy

**Core decision: MiniFantasy by Krishna Palacio is our complete visual library.**

We own 74 MiniFantasy commercial packs, all located in `/assets/minifantasy/`. This collection covers every visual category the game needs — tilesets, characters, enemies, weapons, VFX, and UI — in a single cohesive pixel art style. No additional asset hunting is required.

**Why MiniFantasy works perfectly for this game:**
- Consistent art style across all 74 packs — everything looks like it belongs together
- Multiple environment themes already match our 5-phase progression (dungeon → caves → swamp → hellscape → sci-fi vault)
- Dedicated sci-fi packs (Reliquary Vault, Space Derelict) cover Phase 5 without needing palette tricks
- Multiple creature and hero packs provide more enemy and character variety than the game needs
- Commercial license covers Steam release

**How we deliver the science-fantasy tone:**
- Fantasy art provides the visual foundation for early phases
- Sci-fi packs (Reliquary Vault, Space Derelict) carry Phase 5's alien aesthetic
- Atmosphere carries the sci-fantasy feel: lighting, color grading, particle effects
- Lore, naming, and UI text carry the science element (terminals, not scrolls; extraction, not escape)
- The deeper phases get WEIRDER — color palette shifts, visual distortion effects, and void-themed particles turn familiar dungeon tiles into something alien

---

## License

**One license applies to all visual assets: MiniFantasy Commercial License (Krishna Palacio)**

| Requirement | Detail |
|-------------|--------|
| Commercial use | ✅ Allowed in videogames and audio-visual projects |
| Modification | ✅ Assets can be edited and altered |
| Redistribution | ❌ Cannot redistribute or resell the raw assets |
| Attribution | Required — credit Krishna Palacio in game credits |
| Notification | Required — send creator a link to the completed project |

**Credits entry (copy this into the game credits screen):**

```
Pixel Art Assets: MiniFantasy by Krishna Palacio
https://krishna-palacio.itch.io/
```

No per-pack tracking needed — the single MiniFantasy credit covers all 74 packs.

---

## Asset Needs by Category

### 1. Tilesets (Arena Floors, Walls, Environment)

**What we need:** 5 visually distinct tilesets for 5 phase themes, each creating a different atmospheric feel for top-down dungeon arenas.

**Assigned MiniFantasy packs:**

| Phase | Theme | Primary Pack | Supplemental Pack |
|-------|-------|-------------|-------------------|
| Phase 1 — The Threshold | Classic dungeon, warm torchlight | `Minifantasy_Dungeon_v2.3_Commercial_Version` | `Minifantasy_DeepCaves_v2.0` |
| Phase 2 — The Descent | Crypt, cold stone, undead | `Minifantasy_Crypt_Of_The_Forgotten_v1.0` | `Minifantasy_DeepCaves_v2.0` |
| Phase 3 — The Deep | Dark swamp, bioluminescence | `Minifantasy_SilentSwamp_v1.0` | `Minifantasy_Gloom_Hollows_v1.0` |
| Phase 4 — The Abyss | Hellscape, nightmare realm | `Minifantasy_Nightmare_Realm_v1.0` | `Minifantasy_Hellscape_v1.0` |
| Phase 5 — The Core | Sci-fi vault, space derelict | `Minifantasy_Scifi_Reliquary_Vault_v1.0` | `Minifantasy_Scifi_SpaceDerelict_v1.0` |

**Verdict: COVERED.** Each phase has a dedicated MiniFantasy environment pack. Phase 4-5 require no palette manipulation — the Nightmare Realm and Sci-Fi packs already carry the right aesthetic.

---

### 2. Player Characters

**What we need:** 7 playable characters with idle, walk, and attack animations. Top-down perspective.

**Assigned MiniFantasy packs:**

| Character Archetype | Primary Pack | Notes |
|--------------------|-------------|-------|
| The Drifter (soldier) | `Minifantasy_TrueHeroes_v1.0` | Core warrior hero set |
| The Spark (engineer) | `Minifantasy_True_Heroes_II_v1.0` | Second hero set, different silhouettes |
| The Shade (rogue) | `Minifantasy_Dark_Brotherhood_v1.0` | Assassin/rogue aesthetic |
| The Warden (nature) | `Minifantasy_Forest_Dwellers_v1.0` | Nature/ranger archetype |
| The Cursed (void) | `Minifantasy_True_Heroes_III_v1.1` | Third hero set, palette to void black **(post-launch)** |
| The Herald (support) | `Minifantasy_True_Heroes_IV_v1.1` | Fourth hero set **(post-launch)** |
| Custom/modular | `Minifantasy_AMyriadOfNPCs_v.1.0` | Modular body parts for unique builds |

**Verdict: COVERED.** 4 True Heroes packs + Dark Brotherhood + Forest Dwellers = more character bases than needed. AMyriadOfNPCs provides modular customization if any archetype needs a distinct look.

---

### 3. Enemies

**What we need:** Multiple enemy types per role (Fodder, Swarmer, Brute, Ranged, Elite, Miniboss) with idle, walk, attack, and death animations. Visually distinct across phases.

**Assigned MiniFantasy packs by phase:**

| Phase Range | Enemy Type | Pack |
|------------|-----------|------|
| All phases (core) | Creatures, beasts | `Minifantasy_Creatures_v3.3_Commercial_Version` |
| All phases (monsters) | Goblins, imps, slimes | `Minifantasy_Monster_Creatures_v1.0` |
| Phase 1-2 | Undead (skeletons, zombies) | `Minifantasy_Undead_Creatures_v1.0` |
| Phase 2-3 | Necropolis undead, liches | `Minifantasy_Necropolis_v1.0` |
| Phase 1-3 | Orc warriors, berserkers | `Minifantasy_Dark_Orc_Army_v1.0` |
| Phase 2-4 | Orc kingdom variants | `Minifantasy_Orc_Kingdom_v1.0` |
| Phase 3-4 | Elite humanoid villains | `Minifantasy_True_Villains_I_v1.0` |
| Phase 4-5 | Nightmare entities | `Minifantasy_Nightmare_Realm_v1.0` + shader work |

**Phase-Warped enemies (Phase 5):** Take Creatures or Undead base sprites and apply void palette shader (deep purple/black, glowing accents). The Nightmare Realm pack provides additional alien variants.

**Elite modifiers** (Shielded, Exploding, etc.) are visual OVERLAYS — a shield bubble sprite or explosion animation on death from the Spell Effects packs. One set of overlay VFX works for all enemy types.

**Verdict: COVERED.** 8 creature/enemy packs provide deep variety. Phase-scaled visual variety achieved through pack switching + minimal shader work for Phase 4-5 extremes.

---

### 4. Weapons & Projectiles

**What we need:** Visual representations for weapon types (projectiles, beams, melee arcs, orbiting objects, AOE effects) matching our 10 behavior types and 5 damage types.

**Assigned MiniFantasy packs:**

| Need | Pack |
|------|------|
| Physical weapon sprites (swords, guns, axes) | `Minifantasy_Weapons_v3.0` |
| Magic weapon sprites + trail effects | `Minifantasy_Magic_Weapons_And_Effects_v1.0` |
| Projectile animations (fireballs, ice, lightning) | `Minifantasy_Spell_Effects_v1.0` |
| Additional spell projectiles and AOE | `Minifantasy_Spell_Effects_II_v1.0` |
| Sorcery effects, beams, orbs | `Minifantasy_MagicAndSorcery_v1.1` |

**Damage type coverage:**
- Fire: fireballs, flame effects from Spell Effects
- Cryo: ice shard, frost effects from Spell Effects II
- Shock: lightning bolt, arc effects from Spell Effects
- Physical: projectile impacts from Weapons + Spell Effects
- Void: recolor existing magic effects to dark purple/black — Spell Effects provides the base animations

**Verdict: COVERED.** Five dedicated packs handle every projectile type and weapon behavior.

---

### 5. VFX (Explosions, Impacts, Status Effects, Pickups)

**What we need:** Hit effects, death effects, status effect indicators, explosion animations, pickup glow effects, extraction portal effects.

**Assigned MiniFantasy packs:**

| Need | Pack |
|------|------|
| Explosions, blast effects | `Minifantasy_Spell_Effects_v1.0` |
| Elemental hit effects (fire, ice, lightning) | `Minifantasy_Spell_Effects_II_v1.0` |
| Weapon impact flashes, trails | `Minifantasy_Magic_Weapons_And_Effects_v1.0` |
| Sorcery AOE, summon effects | `Minifantasy_MagicAndSorcery_v1.1` |

**Game-specific effects (built in Godot):**
- Extraction portal: GPU particle system, use basic glow textures from Spell Effects as base
- Instability overlay: CanvasModulate + particle density increase, no additional sprites needed
- Status effect indicators: small icon overlays above enemies, use Spell Effects frames as source textures
- Void distortion: Godot shader (screen-space distortion, no additional art needed)

**Verdict: MOSTLY COVERED.** MiniFantasy handles 80%+ of VFX. Game-specific effects (extraction portal, Instability overlay) built in Godot's particle system from Spell Effects textures.

---

### 6. UI Elements

**What we need:** Health bar, shield bar, Instability meter, XP bar, level-up choice panels, extraction channeling bar, minimap frame, hub interface panels, damage numbers, pickup indicators.

**Assigned MiniFantasy packs:**

| Need | Pack |
|------|------|
| All UI chrome (bars, panels, buttons, frames) | `Minifantasy_UI_Overhaul_v1.0` |

**Game-specific UI:**
- Instability meter: reskin a health bar from UI Overhaul with void-purple color
- Extraction channel bar: reskin a progress bar from UI Overhaul
- Damage numbers and pickup text: Godot's font rendering — use a free pixel art font
- Hub panels: UI Overhaul provides panel frames, content is laid out in Godot's UI system

**Verdict: COVERED.** UI Overhaul provides all required chrome elements.

---

### 7. Audio — Music

**What we need:** Atmospheric tracks for 5 phase themes + hub music. Dark, moody, escalating tension. Loopable.

MiniFantasy packs are visual only — no audio is included. Audio requires external sources.

**Free audio sources (existing strategy unchanged):**
- **juanjo_sound — Dark Dungeon Ambient Music** (41 tracks, itch.io/GameDev Market, Elder Scrolls-inspired)
- **OpenGameArt.org CC0 Music** — dark ambient, dungeon ambience, loopable tracks
- **Pixabay** — royalty-free dark/dungeon music

Mix dark dungeon ambient for Phase 1-3, layer in electronic/synth horror elements for Phase 4-5. juanjo_sound's 41 tracks alone covers the entire game several times over.

**Verdict: COVERED (external sources).** Audio is the only category not served by MiniFantasy.

---

### 8. Audio — Sound Effects

**What we need:** Hit impacts, death sounds, weapon fire sounds, pickup chimes, UI clicks, extraction portal hum, ambient sounds, status effect cues.

MiniFantasy packs are visual only — no SFX included. SFX requires external sources.

**Free SFX sources (existing strategy unchanged):**
- OpenGameArt.org CC0 SFX libraries
- itch.io free SFX packs (combat, UI, ambient)
- Pixabay SFX library
- Kenney.nl audio packs (CC0)

**Game-specific SFX:** Layer existing free sounds. Low drone + crystal chime = extraction portal. Distorted bass rumble = Instability rising. Reversed/pitch-shifted standard sounds = void effects.

**Verdict: COVERED (external sources).** Same strategy as before — free SFX libraries are extensive.

---

## Asset Pipeline Summary

| Category | Status | Primary Source | Notes |
|----------|--------|----------------|-------|
| Tilesets | ✅ Covered | MiniFantasy (5 dedicated packs) | One pack per phase, no palette work needed for Phase 1-4 |
| Player Characters | ✅ Covered | MiniFantasy TrueHeroes I-IV + Dark Brotherhood + Forest Dwellers | More bases than needed |
| Enemies | ✅ Covered | MiniFantasy Creatures, Monster Creatures, Undead, Orcs, Villains | Phase-scaled via pack switching |
| Weapons & Projectiles | ✅ Covered | MiniFantasy Weapons + Spell Effects I & II + Magic Weapons | All 5 damage types covered |
| VFX | ✅ Mostly Covered | MiniFantasy Spell Effects I & II + Magic Weapons | Game-specific effects in Godot particles |
| UI Elements | ✅ Covered | MiniFantasy UI Overhaul | Game-specific meters = reskinned bars |
| Music | ✅ Covered (external) | juanjo_sound, OpenGameArt, Pixabay | MiniFantasy has no audio |
| Sound Effects | ✅ Covered (external) | OpenGameArt, itch.io, Kenney, Pixabay | MiniFantasy has no audio |

---

## Full Pack Inventory

All 74 MiniFantasy packs in `/assets/minifantasy/`:

| Pack | Game Role |
|------|-----------|
| `Minifantasy_AMyriadOfNPCs_v.1.0` | Modular character body parts for custom builds |
| `Minifantasy_Ancient_Forests` | Environment supplement (unused unless forest arena added) |
| `Minifantasy_Aquatic_Adventures_v1.0` | Environment supplement (reserve) |
| `Minifantasy_Builders_v1.0` | Hub environment / prop supplement |
| `Minifantasy_CastlesAndStrongholds_v.2.0` | Environment supplement (reserve) |
| `Minifantasy_CraftingAndProfessions_v1.0` | Hub visual / NPC supplement |
| `Minifantasy_CraftingAndProfessions2_v1.0` | Hub visual / NPC supplement |
| `Minifantasy_Creatures_v3.3_Commercial_Version` | **Primary enemy sprites (all phases)** |
| `Minifantasy_Crypt_Of_The_Forgotten_v1.0` | **Phase 2 tileset** |
| `Minifantasy_Dark_Brotherhood_v1.0` | **Player character — The Shade archetype** |
| `Minifantasy_Dark_Orc_Army_v1.0` | **Phase 1-3 enemy set** |
| `Minifantasy_DeepCaves_v2.0` | **Phase 1-2 tileset supplement** |
| `Minifantasy_DesolateDesert_v2.0` | Environment supplement (reserve) |
| `Minifantasy_Dungeon_v2.3_Commercial_Version` | **Phase 1 tileset (primary)** |
| `Minifantasy_DwarvenKingdom_v1.0` | Environment supplement (reserve) |
| `Minifantasy_Dwarven_Workshop_v1.0` | Hub environment supplement |
| `Minifantasy_ElvenKingdom_v.1.0` | Environment supplement (reserve) |
| `Minifantasy_Enchanted_Companions_v1.0` | Familiar/companion visuals (future feature) |
| `Minifantasy_Fae_Depths_v1.0` | Phase 3 environment supplement |
| `Minifantasy_Farm_v3.0` | Hub environment supplement |
| `Minifantasy_Forest_Dwellers_v1.0` | **Player character — The Warden archetype** |
| `Minifantasy_ForgottenPlains_v3.5_Commercial_Version` | Environment supplement (reserve) |
| `Minifantasy_Gloom_Hollows_v1.0` | **Phase 3 tileset supplement** |
| `Minifantasy_Hellscape_v1.0` | **Phase 4 tileset supplement** |
| `Minifantasy_IcyWilderness_v1.0` | Environment supplement (reserve) |
| `Minifantasy_Lost_Civilization_v.1.0` | Phase 5 supplement / lost tech aesthetic |
| `Minifantasy_Lost_Jungle_v1.0` | Environment supplement (reserve) |
| `Minifantasy_MagicAndSorcery_v1.1` | **Sorcery VFX, beams, orbs** |
| `Minifantasy_Magic_Weapons_And_Effects_v1.0` | **Weapon sprites + hit effects + trails** |
| `Minifantasy_Maps_v2.1` | Minimap / overworld visuals |
| `Minifantasy_Medieval_Carnival_v1.0` | Hub supplement (reserve) |
| `Minifantasy_Medieval_City_v1.1` | Hub environment |
| `Minifantasy_Modern_Apocalypse_v1.0` | Phase 5 supplement |
| `Minifantasy_Modern_Town_v1.0` | Hub environment |
| `Minifantasy_Monster_Creatures_v1.0` | **Secondary enemy sprites (all phases)** |
| `Minifantasy_Mountain_Stronghold_v1.0` | Environment supplement (reserve) |
| `Minifantasy_Mounts_v1.0` | Unused unless mount mechanic added |
| `Minifantasy_Necropolis_v1.0` | **Phase 2-3 undead enemy set** |
| `Minifantasy_Nightmare_Realm_v1.0` | **Phase 4 tileset (primary) + Phase 4-5 enemy supplement** |
| `Minifantasy_Orc_Kingdom_v1.0` | **Phase 2-4 orc enemy set** |
| `Minifantasy_Persian_Palace_v1.0` | Environment supplement (reserve) |
| `Minifantasy_Pharaoh_Tomb_v1.0` | Environment supplement (reserve) |
| `Minifantasy_Plants_&_Foliage_v1.0` | Environment decoration supplement |
| `Minifantasy_Portrait_Generator_Graphical_Assets_v1.0` | Character portraits for hub UI |
| `Minifantasy_RTS_Humans_v1.0` | Human soldier supplement (reserve) |
| `Minifantasy_RTS_Orcs_v1.0` | Orc supplement (reserve) |
| `Minifantasy_Raided_Village_v1.0` | Environment supplement (reserve) |
| `Minifantasy_Scifi_Reliquary_Vault_v1.0` | **Phase 5 tileset (primary)** |
| `Minifantasy_Scifi_SpaceDerelict_v1.0` | **Phase 5 tileset supplement** |
| `Minifantasy_Sewers_v1.0` | Phase 2-3 environment supplement |
| `Minifantasy_Ships And Docks v1.1` | Unused (reserve) |
| `Minifantasy_SilentSwamp_v1.0` | **Phase 3 tileset (primary)** |
| `Minifantasy_Spell Effects_v1.0` | **Projectile animations, explosions, impacts** |
| `Minifantasy_Spell_Effects_II_v1.0` | **Elemental projectile animations** |
| `Minifantasy_Temple_Of_The_Snake_God_v1.0_Commercial_Version` | Environment supplement (reserve) |
| `Minifantasy_Temples_And_Shrines_v1.0` | Phase 1-2 supplement / extraction point visuals |
| `Minifantasy_TinyOverworld_v1.0` | Overworld / map screen (future) |
| `Minifantasy_Tiny_Overworld_II_v1.0` | Overworld / map screen supplement (future) |
| `Minifantasy_Towers_v1.0` | Environment supplement (reserve) |
| `Minifantasy_Towns2_v1.5` | Hub environment supplement |
| `Minifantasy_Towns_v3.0` | Hub environment |
| `Minifantasy_Trains_v1.0` | Unused (reserve) |
| `Minifantasy_TrueHeroes_v1.0` | **Player character — The Drifter archetype** |
| `Minifantasy_True_Heroes_II_v1.0` | **Player character — The Spark archetype** |
| `Minifantasy_True_Heroes_III_v1.1` | **Player character — The Cursed archetype (post-launch)** |
| `Minifantasy_True_Heroes_IV_v1.1` | **Player character — The Herald archetype (post-launch)** |
| `Minifantasy_True_Villains_I_v1.0` | **Phase 3-4 elite humanoid enemies** |
| `Minifantasy_UI _Overhaul_v1.0` | **All UI chrome — bars, panels, buttons, frames** |
| `Minifantasy_Undead_Creatures_v1.0` | **Phase 1-2 undead enemy set** |
| `Minifantasy_Warp_Lands_v1.0` | Phase 4-5 environment supplement |
| `Minifantasy_Weapons_v3.0` | **Physical weapon sprites** |
| `Minifantasy_Wild_West_Town_v1.0` | Unused (reserve) |
| `Minifantasy_Wildlife_v1.0` | Passive creature supplement (future) |
| `Minifantasy_Wizards_Academy_v1.0` | Phase 2-3 supplement / mage enemies |

---

## Sprite Catalogue

Hans compiled a curated catalogue of all usable characters with their full animation sets, specials, and palette swap recipes: **`docs/sprite_catalogue.md`**

Key sections:
- **A-List** — Hero & Villain sprites with deep animation sets (True Heroes I-IV, True Villains). Primary player class casting pool.
- **B-List** — Military/faction units (RTS Humans, Orcs, Dark Brotherhood). Good for enemies and NPCs.
- **D-List** — Creatures & Monsters, including boss-tier and undead.
- **Patreon Exclusives** — 100+ additional units from the `All_Exclusives_20260409/` archive.
- **Palette Swap Recipes** — Executed swaps documented with exact tool parameters (e.g. Demonologist → Witch Doctor).

Already extracted and in use: `ranger/`, `demonologist/`, `witch_doctor/`, `giant/`.

---

## The Palette-Shift Strategy

Phases 1-4 use MiniFantasy packs as-is — the environmental packs already provide distinct looks. Palette shifting is reserved for edge cases only:

**When to apply palette/shader work:**
- Phase 5 enemy variants: take Phase 1-3 enemy sprites (Creatures, Undead) and apply void palette shader (deep purple/black with bioluminescent accents) to create Phase-Warped variants without needing separate sprites
- Any Phase 4-5 enemy that needs to look "wrong" but doesn't have a dedicated pack equivalent

**Pre-baked palette swap tool:** `tools/palette_swap.py` — Python script (requires Pillow) for producing recolored PNG variants from source sprites. Workflow: `analyze` to inspect hue ranges, then `swap` with explicit target palette.

```
python tools/palette_swap.py analyze <image>
python tools/palette_swap.py swap <image> --hue-range LO HI --palette HEX... -o output.png
```

Full recipe for the Demonologist → Witch Doctor swap is documented in `docs/sprite_catalogue.md` under "Executed Palette Swaps".

**Godot tools for palette shifting (runtime):**
- **CanvasModulate** — global color tinting per scene
- **Shaders** — color replacement, distortion, glow
- **GPU Particles** — fog, floating particles, atmospheric density
- **Light2D** — dynamic lighting to reinforce phase atmosphere

The MiniFantasy packs eliminate the need for heavy palette manipulation that was previously planned. The Nightmare Realm and Hellscape packs already look alien; the Sci-Fi packs already look like a different world.

---

*Phase 6 (Asset Inventory) is complete. We have 74 MiniFantasy commercial packs covering all visual needs. No asset sourcing required — implementation can begin directly from `/assets/minifantasy/`.*

*Next: Phase 7 — Architecture Blueprint (Plain English). Define the code structure in plain english before writing any code. What systems exist, what they're responsible for, how they communicate, and what data structures look like.*
