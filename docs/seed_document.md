# Seed Document — Untitled Survivors-Like
### Project Foundation (Revised)

---

## The Developer

**Who:** Ben, solo developer. No formal game dev training but technically literate — comfortable with AI-assisted workflows, modding communities, and technical concepts. Working in Godot 4.6 with GDScript, using Claude Code Desktop with godot-mcp-pro (WebSocket on port 6505) and godot-doc-mcp for implementation.

**Working style:** Works best with AI doing the heavy lifting on code and generation. Ben provides creative direction, taste, curation, and decision-making. Previous game dev attempts stalled because design and building happened simultaneously — this project follows a strict phase-based methodology (design docs → architecture → prototype → build) to break that pattern.

**Skills:** Can type, can prompt, can source free assets, can follow technical instructions with explanation. Not an artist, not a musician, not a programmer by trade.

**Budget:** $0 beyond Claude subscription. All assets sourced from owned MiniFantasy commercial packs (74 packs) and free CC0 audio libraries.

---

## The Game

**Genre:** Survivors-like extraction hybrid. Top-down 2D horde-survival with build-crafting and extraction shooter risk/reward mechanics. The core loop combines the escalating chaos and auto-attack power fantasy of Vampire Survivors with the "keep or lose everything" tension of extraction shooters like Marathon.

**What Makes This Different:** The extraction layer. Every other survivors-like ends when you die or a timer runs out. In this game, the player chooses when to leave — and everything they've collected during the run is only kept on successful extraction. Death means losing all loot. This transforms every moment of gameplay into a risk/reward decision: push deeper for better loot, or extract now and keep what you have.

**Setting:** Science-fantasy. Ancient unknowable forces meet advanced technology. Cosmic horror, deep-space dread, impossible architecture, and dark magic coexisting with technology. Not campy, not bright. Dark, atmospheric, vast.

**Aesthetic Vision — "Hyperreal Sublime":**
Environments that suggest impossible scale and unknowable depth. Dark palettes, atmospheric lighting, a sense that the space you're fighting in is a tiny pocket of a vast, incomprehensible place. The game should feel like descending into something ancient and enormous. Delivered through pixel art (MiniFantasy assets) enhanced with lighting, particle effects, shaders, and atmospheric audio — the art provides the foundation while presentation carries the tone.

**Core Fantasy:** The player ventures into something unknown — an ancient, vast, terrible place where science and magic have blurred — growing powerful enough to survive it and escape with what they find. Each run is a descent through 5 phases, each deeper and more hostile than the last. Progression is both mechanical (meta-unlocks, better loadouts) and narrative (understanding what this place IS).

**Run Length:** 15-20 minutes per run across 5 phases.

**Monetization:** One-time purchase on Steam, $5-10 range. Post-launch content updates (arenas, characters, weapons) at no additional cost initially.

**Platform:** PC first, Steam primary distribution.

---

## Inspiration Games

- **He Is Coming** — Core mechanical reference. Adventuring auto-battler structure. Build-crafting loop, escalating difficulty, satisfying power spikes.
- **Vampire Survivors** — Genre-defining. Accessibility, dopamine pacing, "one more run" factor. Avoid: can feel mindless/passive.
- **There Are No Orcs** — Quick-hit dopamine, satisfying destruction loops.
- **BALL x PIT** — Satisfying physics/chaos feedback.
- **Marathon (Bungie)** — Aesthetic AND mechanical inspiration. Deep-space cosmic horror, fragmented lore, plus the extraction shooter tension of risking everything you've found.

---

## Design Values

- **Quick dopamine hits** — satisfying feedback on kills, pickups, level-ups, build choices
- **Build diversity** — many viable paths through weapon + mod combinations, interesting choices, synergy discovery
- **Respecting the player's time** — every minute should feel worthwhile, no padding, no grinding for grinding's sake
- **Atmosphere** — the game should FEEL like something, not just be a mechanical exercise
- **Progression that matters** — both within a run (power curve) and across runs (meta-progression at the hub)
- **Accessible complexity** — easy to start, deep to master, never overwhelming
- **Extraction tension** — every decision is colored by "should I leave now or push deeper?"

---

## Anti-Goals

- **Disrespecting the player's time** — forced grinding, artificial padding, waiting for the sake of waiting
- **Complexity without depth** — lots of systems that don't meaningfully interact
- **Scope creep** — this is a solo dev side hustle, not a AAA title. Ship something.
- **Generic aesthetic** — "another pixel art horde game" won't stand out. Atmosphere and extraction mechanics are the differentiators.
- **Design paralysis** — when in doubt, prototype and iterate.

---

## Constraints

| Constraint | Reality |
|---|---|
| Team | Solo (Ben + Claude) |
| Budget | $0 (beyond Claude sub) |
| Engine | Godot 4.6 (GDScript) |
| Art | MiniFantasy commercial packs (74 packs, all visual needs covered) |
| Audio | Free/CC0 music and SFX (OpenGameArt, Kenney, Pixabay, itch.io) |
| Timeline | Side hustle pace. No hard deadline, but bias toward shipping. |
| Distribution | Steam (primary target) |
| Platform | PC first |
| Monetization | One-time purchase, $5-10 |

---

## Current State

The game has a working prototype with:
- Core combat (auto-attack + active abilities)
- Hub with meta-progression and save/load
- 6 weapons across multiple behavior types
- 5 playable characters (Drifter, Scavenger, Warden, Spark, Shade) with 2 post-launch characters planned (Herald, Cursed)
- 5 enemy types plus elite modifiers
- 10 weapon mods
- All 4 extraction types functional (Timed, Guarded, Locked, Sacrifice)
- Debug menu for testing
- Currently in polish pass (UI, VFX, bug fixing, balancing) before audio implementation

---

*This document provides the project overview. For detailed system designs, see the Systems Design documents (Parts 1-3). For architecture and data structures, see the Architecture Blueprint. For formulas and numbers, see Core Framework Decisions. For the mechanical grammar, see Mechanical Vocabulary.*
