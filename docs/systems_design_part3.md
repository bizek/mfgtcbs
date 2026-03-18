# Systems Design Document (Part 3)
### Phase 4 Output | Meta-Progression and Level/Arena System

---

## System 7: Meta-Progression System

**Purpose:** Everything that happens between runs. The hub, spending, loadouts, unlocks, and the long-term hooks that keep players coming back across sessions.

**Boundaries:** This system handles the hub space, resource spending, character/equipment management, and progression tracking. It does NOT handle what loot drops during runs (that's the Loot System) or what upgrades appear during runs (that's the Upgrade System). This is the "before and after" of a run — the bookends.

### The Hub: Simple Visual Room (Option B)

The hub is a single room/area the player character walks around in. Interactive stations handle different functions. The room visually upgrades as the player invests resources, providing tangible evidence of progress.

**Hub Stations:**

| Station | Function | Description |
|---------|----------|-------------|
| Armory | Equip loadout | Select starting weapons, mods, and artifacts for next run |
| Research Terminal | Activate blueprints | Spend resources to unlock new items in the run drop pool |
| Roster | Unlock/select characters | Spend resources to unlock new characters; select active character |
| Workshop | Hub upgrades | Spend resources to improve hub capabilities (more artifact slots, Insurance, etc.) |
| Lore Archive | View collected lore | Browse collected lore fragments. No cost. |
| Records Terminal | View statistics | Personal bests, run history, achievement tracking. No cost. |
| Launch Pad | Start a run | Begin the next descent |

**Hub Visual Progression:**
- The hub starts bare, damaged, minimal. Functional but rough.
- As the player invests resources into Workshop upgrades and generally progresses, the hub visually improves: better lighting, repaired structures, new decorations, functional equipment humming.
- This is purely cosmetic feedback on progression but it's powerful — the player's "home" reflects their success.
- Serves Pillar 4 (The Descent): the hub is the contrast point. A small pocket of warmth and safety against the vast unknown the player descends into.

**Hub Feel Principles:**
- **Fast.** Getting from "run just ended" to "next run starting" should take under 60 seconds if the player wants to go fast. No forced menus, no mandatory interactions. Walk to the Launch Pad and go.
- **Rewarding to linger.** But if the player WANTS to browse the armory, read lore, plan a build — that should feel good too. No rush, no pressure.
- **Atmospheric.** Music shifts to something calmer. Ambient sounds. The hub is a breather between the intensity of runs.

### Resource Economy

**One Universal Currency: Resources**

All extracted resources are the same currency. Simple, clean, no confusion about "which currency buys what."

**Spending Categories:**

| Category | Cost Range | What You Get |
|----------|-----------|-------------|
| Character Unlocks | High | New playable character with unique starting kit |
| Blueprint Activation | Medium | New weapon/mod added to run drop pool |
| Hub Upgrades | Medium-High | Permanent capability improvements |
| Insurance (per run) | Medium | Protect one item from death penalty |

**Economy Principle:** The player should always have something worth saving for, but never feel like they can't afford to make ANY progress. Multiple price tiers ensure that even a modest extraction yields enough to buy something — a cheap blueprint, a small hub upgrade. Big-ticket items (characters, major upgrades) are aspirational but not demoralizing.

### Character Roster (v1 Launch Characters)

Each character has:
- A unique starting weapon (cannot be unequipped, defines early-run playstyle)
- A unique passive ability (always active, shapes build direction)
- Slightly adjusted base stats (not dramatic, but noticeable)

| Character | Starting Weapon | Passive Ability | Stat Adjustments | Fantasy |
|-----------|----------------|-----------------|------------------|---------|
| The Drifter | Standard Sidearm (balanced ranged) | None — baseline stats, no gimmick | Balanced across the board | The "learn the game" character. Reliable, no surprises. |
| The Scavenger | Salvage Cutter (short range, wide arc) | +25% Pickup Radius, +15% Loot Find | Lower Damage, Higher Movement Speed | The extraction optimizer. Finds more, fights less efficiently. |
| The Warden | Heavy Repeater (slow, high damage) | Armor doubles when below 50% HP | High HP, High Armor, Low Movement Speed | The immovable wall. Survives deep phases through sheer toughness. |
| The Spark | Overcharged Pistol (fast, fragile) | +50% Crit Damage | High Damage, High Attack Speed, Low HP | The glass cannon. Kills everything fast or dies trying. |
| The Shade | Phantom Blade (melee, fast) | Dodge grants brief invisibility (0.5s) | High Dodge Chance, High Movement Speed, Low Armor | The untouchable. Weaves through danger. |
| The Herald | Signal Beacon (mediocre weapon) | Active abilities deal +30% damage and have -20% cooldown | Average stats, extra active ability slot | The ability specialist. Weapon is weak, abilities are everything. |
| The Cursed | Void Siphon (drains enemy HP) | Starts every run at Unsettled Instability (25%) but gains +20% to all base stats | Boosted everything, permanent Instability penalty | The expert character. Maximum risk, maximum power. |

**Unlock Order:** The Drifter is free (starting character). Other characters unlock via resource spending at the Roster station. No forced order — the player picks which character interests them most and saves toward it.

**Design Note:** Characters should be unlockable at a pace that feels natural. The second character should feel achievable within the first few sessions of play. Later characters cost more but by then the player is extracting more efficiently. The curve matches the player's skill growth.

### Loadout System

Before each run, the player equips:

| Slot | What Goes Here | Starting Capacity | Expandable? |
|------|---------------|-------------------|-------------|
| Character | Selected character from Roster | 1 (The Drifter) | Unlock more characters |
| Starting Weapons | Weapons from extracted collection | 1 slot (character's starting weapon fills it) | Hub upgrade to add 1-2 more starting weapon slots |
| Weapon Mods | Pre-attached to starting weapons | Based on weapon mod slots | Find weapons with more mod slots |
| Artifacts | Passive items from extracted collection | 1 slot | Hub upgrade to unlock slot 2 (and maybe 3) |
| Insurance | Select one item to insure | 1 (after unlocking Insurance at Workshop) | No — always 1 per run |

**Loadout Philosophy:** You start each run with a foundation (character + starting gear), but the MAJORITY of your power comes from what you find during the run. The loadout gives direction, not dominance. A well-equipped player has an advantage, but a new player with no collection can still have a great run if they get good upgrade choices.

### Progression Visibility: The Mix

**Visible Goals (things the player can see and work toward):**
- Character unlock costs visible at the Roster (but presented as exciting milestones, not daunting grind bars)
- Blueprint activation costs visible at the Research Terminal
- Hub upgrade paths visible at the Workshop (next upgrade + cost)
- Current resource total always visible
- Run statistics and personal bests at the Records Terminal

**Surprise Unlocks (things that just happen):**
- First time extracting from Phase 3 → surprise unlock (could be a character discount, a free blueprint, a cosmetic, a lore dump)
- Milestone surprises — extracting your 10th weapon, surviving your first Phase 5, using all extraction types in one run, etc.
- These are NEVER telegraphed. The player doesn't know they're coming. They just... happen. Delight, not obligation.
- Surprise unlocks should never be the ONLY way to get something essential. They're bonuses, easter eggs, moments of joy.

**What Is Never Shown:**
- "You need X more runs to unlock Y." Never count runs. Never make the player think in terms of repetitions.
- Overall completion percentage. No "you've completed 23% of the game." That makes 77% feel like a burden.
- Time played (unless the player specifically seeks it out in a stats menu). Don't remind people how much time they've spent.

### Hub Upgrades (Workshop)

| Upgrade | Cost Tier | Effect |
|---------|-----------|--------|
| Insurance License | Medium | Unlocks the ability to insure one item per run |
| Armory Expansion I | Medium | +1 starting weapon slot (start runs with 2 weapons) |
| Armory Expansion II | High | +1 starting weapon slot (start runs with 3 weapons) |
| Artifact Chamber I | Medium | Unlock 2nd artifact equipment slot |
| Artifact Chamber II | High | Unlock 3rd artifact equipment slot |
| Extraction Intel I | Medium | Extraction points visible on minimap from further away |
| Extraction Intel II | High | Preview which extraction types will be in the next run |
| Lore Decoder | Medium | Lore fragments reveal bonus context (expanded lore text) |
| Hub Restoration I-V | Scaling | Visual upgrades to the hub. Each tier makes it look better. Pure cosmetic satisfaction. |

### v1.5 Meta-Progression Features

- **Prestige/Reset System** — Reset progression for cosmetic rewards or difficulty modifiers. Adds endgame replayability.
- **Challenge Runs** — Unlock modifiers that make runs harder for better rewards (no extraction until Phase 3, double Instability, etc.)
- **Expanding Hub (Option C)** — Multiple rooms unlocked over time. Each with unique function and atmosphere.
- **Cosmetics** — Character skins, weapon visual effects, hub decorations. No gameplay impact.

---

## System 8: Level/Arena System

**Purpose:** Define how physical space works during a run. What the player sees, where things are, and how the sense of descent is delivered spatially.

**Boundaries:** This system handles arena structure, phase transitions, spatial layout rules, and visual theming. It does NOT handle specific arena content (individual layouts — that's generated data). It does NOT handle what enemies spawn where (that's Enemy System using spawn zones defined here). This is the stage; other systems are the actors.

### Arena Structure: One Arena Per Phase

Each run consists of 5 phases, each in a distinct arena. The game randomly selects one arena from that phase's pool. At launch, 1 arena per phase (5 total), expandable with additional arenas added to each phase's pool post-launch.

**Run Flow:**
```
Hub → Launch → Phase 1 Arena → [Transition] → Phase 2 Arena → [Transition] → Phase 3 Arena → [Transition] → Phase 4 Arena → [Transition] → Phase 5 Arena → [Extract or Die] → Hub
```

### Arena Data Structure

Every arena is defined as a **data file** that the game engine reads and populates with assets. Claude Code generates these layouts; Ben reviews and approves them.

An arena data file contains:

| Data Field | Description |
|-----------|-------------|
| Phase | Which phase this arena belongs to (1-5) |
| Dimensions | Arena size (width x height in grid units) |
| Terrain Map | Grid of walkable, blocked, and hazard tiles |
| Spawn Zones | Coordinates where enemies appear (edges, portals, specific points) |
| Extraction Points | Locations and types for each extraction type present in this arena |
| Hazard Placements | Positions and types of environmental hazards |
| Cover Objects | Positions of obstacles that block movement/projectiles |
| Hidden Spots | Locations where Keystones, lore fragments, or bonus loot are tucked away |
| Visual Theme | Which tileset/asset set to use for rendering |
| Ambient Config | Lighting settings, particle effects, fog density, color palette |
| Lore Hook | Optional environmental storytelling element unique to this arena |

**Why Data-Driven Arenas Matter:**
- Adding a new arena = adding a new data file. No code changes.
- Claude Code can generate layouts that follow the design rules automatically.
- Layouts can be visualized as simple grids for review before assets are placed.
- Post-launch content is just "design more arenas, add them to the pool."

### Arena Layout Rules (What Every Arena Must Have)

Regardless of phase or visual theme, every arena follows these rules:

1. **Size scales with phase.** Phase 1 arenas are smaller (player feels contained, manageable). Phase 5 arenas are larger (player feels exposed, overwhelmed). Exact dimensions TBD in Phase 8 (framework decisions).

2. **Spawn zones are distributed around the perimeter and/or at designated portal points.** Enemies should come from multiple directions. The player should never be able to "corner camp" safely.

3. **At least one Timed Extraction point** at a fixed location. Visible from most of the arena. The player should always know where it is.

4. **Guarded Extraction point** at a distinct, slightly inconvenient location (not center, not near the Timed point). The guardian is visible from a distance.

5. **Locked Extraction point (Phase 3+ only)** at a visible but separate location. Clearly sealed/inactive until a Keystone is used.

6. **Sacrifice Extraction point (Phase 2+ only)** at its own location. Visually ominous, distinct from other extraction types.

7. **Environmental hazards** placed to create interesting terrain without blocking essential paths. Hazards should offer risk/reward — a damage zone between you and the extraction point creates tension, not frustration.

8. **Cover objects** distributed to create natural kiting paths and tactical positioning without creating exploitable safe zones.

9. **Hidden spots** (1-3 per arena) that reward exploration. Not critical path, but a Keystone or lore fragment tucked behind cover or in a hazard zone creates a micro risk/reward moment.

10. **No dead ends.** The player should always have an escape route. Getting trapped in geometry is a design failure, not a difficulty feature.

### Phase Visual Themes

Each phase has a distinct visual identity that reinforces the sense of descent. Exact assets depend on what's available (Phase 6 — Asset Inventory), but the design direction is:

**Phase 1 — The Threshold**
- *Feel:* Entry point. Recognizable. "You can still turn back."
- *Palette:* Muted grays, dim blues, occasional warm light sources
- *Environment:* Damaged structures, scattered debris, broken technology mixed with organic growth. Looks like something that was once built by people.
- *Lighting:* Dim but functional. The player can see everything clearly.
- *Sound:* Distant rumbles. Dripping. Faint mechanical hum.

**Phase 2 — The Descent**
- *Feel:* Deeper. Less familiar. "Something is wrong here."
- *Palette:* Darker grays, cold blues, first hints of unnatural color (faint green/purple bioluminescence)
- *Environment:* Architecture becomes less recognizable. Organic elements mixing with corroded machinery. Walls that might be breathing. Geometry that's slightly off.
- *Lighting:* Darker overall with more contrast. Pools of light and shadow.
- *Sound:* The mechanical hum is gone. Organic sounds. Something in the walls.

**Phase 3 — The Deep**
- *Feel:* Alien. Hostile. "This place doesn't want you here."
- *Palette:* Deep blacks, bioluminescent accents (blue, green, violet), occasional hot spots of orange/red
- *Environment:* Impossible geometry visible at the edges. Structures that blend organic and mechanical seamlessly. The "floor" might not be floor. Gravity feels visual — things hang at odd angles in the background.
- *Lighting:* Dark with dramatic bioluminescent lighting. The player's immediate area is lit; the edges fade into oppressive darkness.
- *Sound:* Low-frequency drones. Sounds that shouldn't exist. Occasional silence that's worse than noise.

**Phase 4 — The Abyss**
- *Feel:* Near-total sensory oppression. "You should not be here."
- *Palette:* Almost monochrome darkness with intense, saturated accent colors (searing white, deep crimson, electric blue)
- *Environment:* Reality feels thin. Visual distortions at screen edges. The environment seems to shift when you're not looking directly at it. Background elements suggest impossible scale — structures stretching into infinite darkness.
- *Lighting:* Point lights only. The player's vision/reveal radius stat matters here — you can only see so far. Enemies emerge from darkness.
- *Sound:* Distorted. Familiar sounds at wrong pitches. Your own footsteps echo differently. The audio itself feels unstable.

**Phase 5 — The Core**
- *Feel:* The source. Ancient. Vast. "No one was meant to be here."
- *Palette:* Whatever the core IS — something luminous at the center of all this darkness. Intense contrast between the light of the core and the surrounding void.
- *Environment:* The architecture (if you can call it that) defies understanding. The background suggests something enormous — a structure, an entity, a phenomenon. The arena floor feels like a platform over an abyss. Maximum hyperreal sublime energy within asset constraints.
- *Lighting:* Dramatic. The Core itself provides light. Everything else is void.
- *Sound:* A tone. A frequency. Something that might be alive. Or might be a machine. Or might be a god. The sound design should leave it ambiguous.

### Phase Transitions

**Transition Sequence (between phases):**
1. Current phase ends (final wave cleared or phase timer completes)
2. Timed Extraction portal opens (15-20 second window)
3. Player either extracts (run ends, go to hub with loot) OR the window closes
4. **Descent Transition** plays:
   - Brief animation/screen effect (3-5 seconds max)
   - Visual: the player character descends deeper (falling, walking down, being pulled — thematic to the setting)
   - Info overlay: Phase name, current Instability level, loot summary (quick glance at what you're carrying)
   - This doubles as a loading mask for the next arena
5. New arena loads. Next phase begins immediately — enemies start spawning within seconds.

**Transition Principles:**
- **Fast.** Never more than 5 seconds. If loading takes longer, start preloading during the extraction window.
- **Atmospheric.** The transition itself reinforces the descent fantasy. Each transition should feel like going deeper.
- **Informative.** The brief info overlay reminds the player what they're risking by continuing. Instability level + loot summary = "here's what you'll lose if you die." Serves Pillar 1 (information before decision).

### Arena Generation Workflow

How new arenas get created (for both launch and post-launch content):

1. **Design brief:** Define the phase, theme, size, and any special features (unique hazard, notable lore hook, unusual layout).
2. **Claude Code generates layout:** A data file with terrain grid, spawn zones, extraction points, hazards, cover, and hidden spots — all following the Arena Layout Rules above.
3. **Visualization:** Claude generates a simple visual map (grid/ASCII or rendered preview) for Ben to review.
4. **Review and approve:** Ben approves the layout or requests changes.
5. **Asset mapping:** The layout's visual theme field determines which tileset/asset set the engine uses to render it.
6. **In-engine test:** Load the arena, spawn enemies, walk around, verify it plays well.
7. **Add to pool:** The approved arena data file is added to its phase's pool. The game can now randomly select it.

### Launch Content Scope

| Phase | Arenas at Launch | Post-Launch Goal |
|-------|-----------------|-----------------|
| Phase 1 — The Threshold | 1 | 2-3 |
| Phase 2 — The Descent | 1 | 2-3 |
| Phase 3 — The Deep | 1 | 2-3 |
| Phase 4 — The Abyss | 1 | 2-3 |
| Phase 5 — The Core | 1 | 2-3 |
| **Total** | **5** | **10-15** |

One arena per phase is the minimum viable launch. The data-driven approach means adding more arenas post-launch is pure content work, not engineering work.

### v1.5 Level/Arena Features

- **Arena pool expansion** — Additional arenas per phase for run variety
- **Arena modifiers** — Random modifiers applied to arenas (low gravity, darkness, enemy speed boost). Adds variety without new content.
- **Secret arenas** — Rare arena variants with unique challenges and exclusive loot. Discovery/community moments.
- **Interconnected rooms (Option C)** — Multiple rooms per phase connected by corridors. More exploration feel. Significant scope increase.

---

## How Systems 7-8 Connect to Everything Else

```
RUN ENDS (extract or die)
    ↓
META-PROGRESSION (Hub)
    ├── Spend resources (from Loot System)
    ├── Equip loadout (weapons/mods/artifacts from extraction)
    ├── Activate blueprints (expand future run drop pools)
    ├── Upgrade hub capabilities (Workshop)
    ├── Select character (Roster)
    └── Launch next run
         ↓
LEVEL/ARENA SYSTEM
    ├── Select arena for Phase 1 (from pool)
    ├── Load arena data → place assets
    ├── Define spawn zones → Enemy System uses them
    ├── Define extraction points → Extraction System uses them
    ├── Define hazards → Combat System interacts with them
    └── Phase transition → select next arena → repeat
```

**Full Loop Example:**
1. Player extracts from Phase 3 with a rare weapon, 2 mods, a blueprint, and a pile of resources.
2. Hub: spends resources to activate the blueprint (new shotgun type now appears in future runs). Equips the rare weapon with both mods. Saves remaining resources toward unlocking The Shade.
3. Notices the hub looks slightly better — a light fixture they hadn't seen before is now working. (Visual upgrade from cumulative spending.)
4. Launches next run. Phase 1 arena loads — The Threshold. Familiar but the weapon loadout is different this time.
5. By Phase 2, the player finds the newly unlocked shotgun as a drop. "The blueprint paid off!"
6. Phase 3 arena is dark, hostile, alien. Instability is climbing. Two extraction types visible. The player pushes for Phase 4...

---

## All 8 Systems — Complete Dependency Map

```
STAT SYSTEM (defines all numbers)
    ↓
COMBAT SYSTEM (uses stats, handles fighting)
    ↓                    ↑
UPGRADE SYSTEM          ENEMY SYSTEM
(modifies stats,        (uses stats,
 build choices)         spawns in arenas)
    ↓                    ↓
LOOT SYSTEM (drops from enemies, collected by player)
    ↓
INSTABILITY (rises with loot, increases difficulty)
    ↓
EXTRACTION SYSTEM (player decides when to leave)
    ↓
META-PROGRESSION (hub, spending, loadouts)
    ↓
LEVEL/ARENA SYSTEM (where runs take place)
    ↓
    └──→ loops back to COMBAT (new run begins)
```

---

*Phase 4 (Systems Design) is complete. All 8 core systems are defined at the conceptual level with clear purposes, boundaries, connections, and scope decisions.*

*Next: Phase 5 — Define the Mechanical Vocabulary. Before designing any specific weapon, enemy, or upgrade, we define the GRAMMAR — the categories of mechanical interaction the game supports.*
