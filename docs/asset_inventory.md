# Asset Inventory
### Phase 6 Output | What We Have to Work With

---

## Asset Strategy

**Core decision: Fantasy assets as the visual base.** The free asset market for top-down fantasy pixel art is massive — dungeon tilesets, character sprites, enemy animations, VFX, UI elements, and audio are all abundantly available. Science-fantasy specific assets are nearly nonexistent for free.

**How we deliver the science-fantasy tone without sci-fi assets:**
- Fantasy art provides the visual foundation (tilesets, characters, enemies)
- Atmosphere carries the sci-fantasy feel: lighting, color grading, particle effects, post-processing
- Lore, naming, and UI text carry the science element (terminals, not scrolls; extraction, not escape; the hub is a station, not a tavern)
- Audio design bridges the gap: dark ambient, drones, electronic undertones mixed with fantasy sounds
- The deeper phases get WEIRDER — color palette shifts, visual distortion effects, and void-themed particles turn familiar dungeon tiles into something alien

**This is the Dark Souls trick:** medieval assets, cosmic horror atmosphere. The art says "dungeon." The vibe says "something unknowable."

---

## Asset Sources (Free / CC0 / Open License)

### Primary Sources

| Source | URL | What's There | License Notes |
|--------|-----|-------------|---------------|
| **itch.io** | itch.io/game-assets/free | Largest free game asset marketplace. Tilesets, characters, enemies, VFX, UI, audio. | Varies per asset — check each. Many are CC0 or "free for commercial use with credit." |
| **OpenGameArt.org** | opengameart.org | Large library of CC0 and CC-BY game art, music, and sound effects. | Mostly CC0 or CC-BY (attribution required). Check each asset. |
| **Kenney.nl** | kenney.nl/assets | High-quality CC0 asset packs. More stylized/modern but some useful elements. | CC0 — no attribution required. Gold standard for licensing. |
| **CraftPix.net** | craftpix.net/freebies | Curated free asset packs including dungeon tilesets, characters, objects. | Free packs are royalty-free for commercial use. Check specific pack terms. |
| **GameDev Market** | gamedevmarket.net | Some free packs available. Dark dungeon ambient music (41 tracks). | Pro License — commercial use allowed. |
| **Pixabay** | pixabay.com/music | Royalty-free music and sound effects. Dungeon/dark ambient available. | Pixabay License — free commercial use, no attribution required. |

### Key Rule: ALWAYS Check Licenses
Before using ANY asset, verify:
1. Is commercial use allowed?
2. Is attribution/credit required? (If so, add to credits list)
3. Can the asset be redistributed as part of a game sold on Steam?
4. Are there any restrictions on modification (recoloring, editing)?

Maintain a running **credits document** that tracks every asset used, its source, its license, and any attribution requirements.

---

## Asset Needs by Category

### 1. Tilesets (Arena Floors, Walls, Environment)

**What we need:** 5 visually distinct tilesets for 5 phase themes, each creating a different atmospheric feel for top-down dungeon arenas.

**What's available (confirmed free sources):**

| Pack / Source | Description | Usability |
|---------------|-------------|-----------|
| Anokolisa — Free Pixel Art Topdown Tileset | 500+ sprites, dungeon environments, 16x16. Heroes, enemies, weapons included. | High — good base for Phase 1-2 |
| Pixel_Poem — 2D Pixel Dungeon Asset Pack | Dark dungeon tiles, animated objects (water, traps, torches, chests). Free version available. Popular with Godot devs. | High — strong dark atmosphere, good for Phase 1-3 |
| CraftPix — Free 2D Top-Down Pixel Dungeon | Dungeon tiles, animated traps, torches, chests, decorative objects. 16x16. | High — supplements above packs |
| Free Game Assets — Top-Down Pixel Dungeon Level | Ground tiles, water, objects. PSD/PNG format. | Medium — supplement pack |

**Gap: Phase 4-5 "alien/void" aesthetics.** Standard dungeon tiles won't look alien enough for deep phases.

**Solution:** Recolor/palette-shift existing dungeon tiles for deeper phases. A warm brown dungeon recolored to deep purple/black with bioluminescent blue accents instantly feels alien. Godot's shader system can handle this with color replacement shaders — no asset editing required. Phase 5 gets the most extreme color treatment plus particle overlay effects.

**Verdict: COVERED.** Multiple free dungeon tilesets available. Deeper phases achieved through palette shifting and post-processing.

---

### 2. Player Characters

**What we need:** 7 playable characters with at minimum: idle, walk, and attack animations. Top-down perspective.

**What's available:**
- Anokolisa pack includes 3 hero sprites with animations
- Multiple free character packs on itch.io (top-down RPG characters, 16x16 and 32x32)
- Character base sprites that can be recolored/modified for variety

**Gap:** We need 7 distinct characters. Free packs typically offer 3-6.

**Solution:**
- Use 2-3 base character packs and differentiate through palette swaps, accessory variations, and weapon visuals
- Characters don't need to look radically different in a top-down pixel art game — distinct color schemes and weapon types are enough to read as "different character"
- Prioritize visual clarity: each character should have a distinct silhouette color (The Drifter = neutral gray, The Spark = bright orange, The Shade = deep purple, The Cursed = void black with glow, etc.)

**Verdict: COVERED with effort.** Mix of existing packs + palette swaps. May need 2-3 source packs combined.

---

### 3. Enemies

**What we need:** Multiple enemy types per role (Fodder, Swarmer, Brute, Ranged, Elite, Miniboss) with at minimum idle and death animations. Visually distinct across phases.

**What's available:**
- Anokolisa pack includes 8 enemy types
- Multiple free monster/creature packs on itch.io
- Dungeon-themed enemy packs (skeletons, slimes, bats, demons, undead)
- CraftPix dungeon object packs include some animated enemies

**Gap:** Phase-Warped enemies (Phase 5) need to look distinctly alien/wrong.

**Solution:**
- Phase 1-3 enemies: standard fantasy dungeon enemies (skeletons, slimes, bats, demons, etc.) — abundantly available
- Phase 4 enemies: same base sprites with color distortion (void purple palette, glitch effects overlay)
- Phase 5 Phase-Warped: heaviest palette manipulation + particle effects. A skeleton recolored to void-black with glowing eyes and a distortion shader looks nothing like a normal skeleton.
- Elite modifiers (Shielded, Exploding, etc.) are visual OVERLAYS — a shield bubble sprite, an explosion animation on death. One set of overlay VFX works for all enemy types.

**Verdict: COVERED.** Fantasy enemy packs are abundant. Deeper phase variants through palette/shader work.

---

### 4. Weapons & Projectiles

**What we need:** Visual representations for weapon types (projectiles, beams, melee arcs, orbiting objects, AOE effects) matching our 10 behavior types and 5 damage types.

**What's available:**
- Anokolisa pack includes 50 weapon sprites
- Dedicated projectile/VFX packs on itch.io
- "Super Pixel Effects Gigapack" — updated near-weekly, covers explosions, projectiles, impacts, magic effects

**Gap:** Void-themed weapons/projectiles are niche. Most free VFX are fire/ice/lightning (convenient since those match our damage types).

**Solution:**
- Fire/Cryo/Shock projectiles: directly available from magic VFX packs (fireballs, ice shards, lightning bolts)
- Physical projectiles: standard bullet/arrow sprites — very common
- Void projectiles: recolor existing magic effects to dark purple/black. A purple fireball with distortion particles = a void projectile.
- Weapon sprites (swords, guns, staves): abundantly available. Weapon visuals are small and only need to read clearly on a 16x16 or 32x32 character.

**Verdict: COVERED.** VFX packs handle projectiles. Void effects via recoloring.

---

### 5. VFX (Explosions, Impacts, Status Effects, Pickups)

**What we need:** Hit effects, death effects, status effect indicators (burning, frozen, shocked, void-touched), explosion animations, pickup glow effects, extraction portal effects.

**What's available:**
- Multiple free pixel art VFX packs on itch.io (explosions, impacts, particles)
- unTied Games — Five Free Pixel Explosions (CC-BY, 60fps)
- Dedicated spell/magic effect packs (fire, ice, lightning animations)
- Particle effect texture packs for Godot's particle system

**Gap:** Some effects (extraction portal, Instability visual overlay, void distortion) are game-specific and won't exist in any pack.

**Solution:**
- Common effects (explosions, hit flashes, elemental VFX): covered by free packs
- Game-specific effects (extraction portal, Instability overlay): built in Godot's particle system using basic particle textures. Godot's GPU particle system is powerful and can create portals, distortion fields, and atmospheric overlays from simple sprite textures.
- Status effect indicators: simple colored overlays or icon bubbles above enemies. Can be created from basic shape sprites.

**Verdict: MOSTLY COVERED.** Free packs handle 80% of needs. Game-specific effects built in Godot's particle system from basic textures.

---

### 6. UI Elements

**What we need:** Health bar, shield bar, Instability meter, XP bar, level-up choice panels, extraction channeling bar, minimap frame, hub interface panels, damage numbers, pickup indicators.

**What's available:**
- BDragon1727 — Basic Pixel Health Bar and Scroll Bar (free)
- Multiple free pixel UI packs on itch.io (buttons, panels, frames, bars)
- CC0 health bars and hearts
- Free fantasy/RPG GUI packs with inventory panels, buttons, frames

**Gap:** Instability meter and extraction-specific UI elements are game-specific.

**Solution:**
- Standard UI (health bar, XP bar, panels, buttons): covered by free packs
- Game-specific UI (Instability meter, extraction channel bar): custom-built from basic UI elements. A health bar reskinned with void colors = Instability meter. These are simple colored rectangles with borders — achievable with basic sprite editing or even Godot's built-in UI theming.
- Damage numbers and pickup text: Godot's font rendering handles this. Use a free pixel art font.

**Verdict: COVERED.** Free UI packs + minor customization for game-specific elements.

---

### 7. Audio — Music

**What we need:** Ambient/atmospheric tracks for 5 phase themes + hub music. Dark, moody, escalating tension. Loopable.

**What's available:**
- **juanjo_sound — Dark Dungeon Ambient Music** (41 free tracks on GameDev Market + itch.io, Elder Scrolls-inspired, original compositions, no AI)
- **OpenGameArt.org CC0 Music collection** — includes dark ambient, dungeon ambience, loopable tracks
- **Pixabay** — royalty-free dark/dungeon music
- **Loopable Dungeon Ambience** on OpenGameArt (CC0)
- **Free dungeon music loops** on itch.io (CC0)
- **Retro Synth Horror Music** on itch.io (John Carpenter-inspired — could work for sci-fantasy tone)

**This is actually one of our strongest categories.** 41 tracks from juanjo_sound alone covers the entire game several times over. Mix dark dungeon ambient for Phase 1-3, layer in electronic/synth horror elements for Phase 4-5 to push the sci-fantasy angle.

**Verdict: ABUNDANTLY COVERED.** More free dark ambient music exists than we can use.

---

### 8. Audio — Sound Effects

**What we need:** Hit impacts, enemy death sounds, weapon fire sounds, pickup chimes, UI click sounds, extraction portal hum, ambient environment sounds, status effect audio cues.

**What's available:**
- OpenGameArt.org has extensive CC0 SFX libraries
- itch.io free SFX packs (combat, UI, ambient)
- Pixabay SFX library
- Kenney.nl audio packs (CC0)
- Sci-Fi SFX packs on itch.io (useful for extraction/void/tech sounds)

**Gap:** Some game-specific sounds (extraction channel sound, Instability ambient shift, void-themed effects) may need to be assembled from layered free SFX.

**Solution:**
- Combat SFX (hits, explosions, weapon fire): abundantly available
- UI SFX (clicks, level-up chime, pickup sounds): abundantly available
- Game-specific SFX: layer existing free sounds. A low drone + crystal chime = extraction portal sound. Distorted bass rumble = Instability rising. Reversed/pitch-shifted standard sounds = void effects.

**Verdict: COVERED.** Free SFX libraries are extensive. Game-specific sounds achievable through layering.

---

## Asset Pipeline Summary

| Category | Status | Primary Sources | Gap-Filling Method |
|----------|--------|----------------|-------------------|
| Tilesets | ✅ Covered | Anokolisa, Pixel_Poem, CraftPix | Palette shifting for deeper phases |
| Player Characters | ✅ Covered (with effort) | Multiple itch.io packs combined | Palette swaps for 7 distinct characters |
| Enemies | ✅ Covered | Anokolisa + supplemental packs | Palette/shader work for deep phase variants |
| Weapons & Projectiles | ✅ Covered | Weapon sprites + VFX packs | Void effects via recoloring |
| VFX | ✅ Mostly Covered | Free VFX packs + Godot particles | Game-specific effects built in engine |
| UI Elements | ✅ Covered | Free UI packs + customization | Instability meter = reskinned health bar |
| Music | ✅ Abundantly Covered | juanjo_sound (41 tracks), OpenGameArt, Pixabay | Synth/horror layers for Phase 4-5 |
| Sound Effects | ✅ Covered | OpenGameArt, itch.io, Kenney, Pixabay | Layering for game-specific sounds |

---

## The Palette-Shift Strategy (Critical Technique)

This is how we get 5 visually distinct phase themes from 1-2 base tilesets:

**Phase 1 — The Threshold:** Base dungeon tileset, warm torchlight colors. As-is from the free pack.
**Phase 2 — The Descent:** Same tileset, cooled color palette. Remove warm tones, add blue-gray. Reduce light intensity.
**Phase 3 — The Deep:** Dramatic palette shift. Dark blacks with bioluminescent accents (blue, green, purple). Fog/particle overlay.
**Phase 4 — The Abyss:** Near-monochrome. Deep void colors with harsh accent lights. Heavy fog. Distortion shader at screen edges.
**Phase 5 — The Core:** Maximum contrast. Void black + intense core light source. Particle density maxed. The dungeon tiles are barely recognizable under the atmospheric effects.

Godot supports this through:
- **CanvasModulate** — global color tinting per scene
- **Shaders** — color replacement, distortion, glow effects
- **GPU Particles** — fog, floating particles, ambient effects
- **Light2D** — dynamic lighting and shadow casting

The same stone wall looks warm and safe in Phase 1 and alien and hostile in Phase 5, purely through color and atmosphere.

---

## Immediate Action Items (For Prototype Phase)

When we reach Phase 9 (Prototype), these are the first assets to download:

1. **Anokolisa's Free Pixel Art Topdown Tileset** — dungeon tiles, heroes, enemies, weapons. This single pack covers initial prototyping.
2. **One free VFX pack** — basic explosions, hit effects, elemental particles.
3. **One free UI pack** — health bar, basic panels.
4. **juanjo_sound's Dark Dungeon Ambient Vol. 1** — 16 tracks for prototype atmosphere.
5. **One free SFX pack** — basic combat sounds.

That's enough to prototype with. Full asset sourcing happens during Phase 10 (Build Out) when we know exactly what content we're creating.

---

## License Tracking Template

Every asset used MUST be tracked:

```
Asset: [Name]
Source: [URL]
Author: [Creator name]
License: [CC0 / CC-BY / Custom]
Attribution Required: [Yes/No]
Attribution Text: [Exact credit text if required]
Used For: [What it's used for in our game]
Modified: [Yes/No — description of modifications]
```

This list becomes the game's credits screen. Non-negotiable — skipping attribution on CC-BY assets is a legal and ethical violation.

---

*Phase 6 (Asset Inventory) is complete. We know what's available, what gaps exist, and how to fill them. The palette-shift strategy gives us 5 distinct visual phases from minimal base assets.*

*Next: Phase 7 — Architecture Blueprint (Plain English). Define the code structure in plain english before writing any code. What systems exist, what they're responsible for, how they communicate, and what data structures look like.*
