# Audio Asset Manifest — Extraction Survivors

Complete enumeration of sound-worthy events across all game systems. Organized by category, with EventBus signal triggers and implementation notes.

**Status (2026-07-06, task 15):** All P1 entries wired to real CC0 assets (Kenney.nl + OpenGameArt.org, see `docs/asset_inventory.md` §7-8). Most P2 entries wired too. Remaining gaps have no good-fit free asset yet — see the TODO block at the end of this file. ✅ = wired to a real asset; unmarked P2 rows with no note are still open.

**Re-source pass (2026-07-10):** Ben rejected the current SFX set (everything except `mus_hub` and the cave ambience, which stay). Replacement source: the **Leohpaz Minifantasy audio packs** — the official audio companions to the exact Minifantasy art packs the game uses (True Heroes I–IV SFX are authored per character animation package). License: personal + commercial use OK, no redistribution, credits optional, no generative AI. See the "Re-source shopping list" section at the end of this file for the slot-by-slot mapping. Swap-in is file-replacement only: keep the same `res://assets/audio/...` paths (or edit `data/factories/sound_table.gd` stream lists) — zero code changes.

---

## Combat SFX — Weapon Fire & Combo Hits

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| ✅ `sfx_swing_light` | Combat | `ChainFactory` light swing phase (hit_frame) | P1 | Light attack impact; all 10 kits share one sound family. Used by: Fighter Attack, Rogue Slash, Paladin Strike, Wizard Bolt, Blood Mage Shard, Ranger Shot, Bard Strike, Barbarian Cleave, Ninja Slash, Gunslinger Shot. Needs 2–3 variations (quick, crisp). |
| ✅ `sfx_swing_heavy` | Combat | `ChainFactory` heavy swing phase (hit_frame) | P1 | Heavy finisher impact (Cataclysm, Bomb, Hammer, Thunder Blade, etc.). Needs 2–3 variations (impact + rumble). |
| `sfx_channel_loop` | Combat | `ChainFactory` channel phase tick (per beat) | P2 | Looped ability tick for held-RMB channels (Taunt shockwave, Fan of Blades, Dome, Torrent, Vampirize, Conceal, Song, Guard, Thousand Blades Storm, Desert Storm). Soft, repetitive. One loop sound per channel family (shockwave, projectile, song, etc.) — 5–6 variations. |
| ✅ `sfx_projectile_fire` | Combat | `EventBus.on_ability_used` for any non-Combo, non-Melee ability (player weapon release + enemy ability wind-ups) | P2 | Wired 2026-07-09: aliases the swing_light whooshes with wide pitch variance (no dedicated CC0 asset found). Replace streams with per-family variants later, zero code changes needed. |
| ✅ `sfx_melee_swing_arc` | Combat | `EventBus.on_ability_used` for Melee-tagged non-Combo abilities | P2 | Wired 2026-07-09: aliases swing_heavy whooshes, pitch-varied. |
| ✅ `sfx_channel_loop_fire/arcane/martial` | Combat | `player.gd _tick_channel_audio()`, polled while `choreography_runner.current_phase_is_held_channel()` | P2 | Sustained bed under a held channel (Immolate/Hellfire→fire, Bone/Bramble Barrage→arcane, Taunt/Dictum/Reckoning dome→martial) so holding into empty air isn't silent. **Original, composed in REAPER 2026-08-15** (`tools/sfx_forge/channel_loop_{fire,arcane,martial}.py` + `build_channel_loops.py`) — three seamless ~2s loops, peak-normalized to -6 dBFS (not LUFS-matched like the biome music), `SoundTable` applies -18 dB on top to sit them under the beat hits. In-engine verified in the Training Room: RMB-hold on demonologist/necromancer/fighter starts, loops across the seam, stops on release. Distinct from `sfx_channel_loop` above (the still-open per-beat tick), which this does not replace. |

---

## Combat SFX — Impacts & Elemental Reactions

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| ✅ `sfx_hit_physical` | Combat | `EventBus.on_hit_dealt` where `damage_type == "Physical"` | P1 | Physical impact sound. Ship-critical. Needs 2–3 impact variations (dull thud, sharp crack, heavy thump). |
| ✅ `sfx_hit_fire` | Combat | `EventBus.on_hit_dealt` where `damage_type == "Fire"` | P1 | Fire impact (crackle + burn). Needs 2–3 variants. |
| ✅ `sfx_hit_cryo` | Combat | `EventBus.on_hit_dealt` where `damage_type == "Cryo"` | P1 | Ice impact (sharp sting, freeze sparkle). Needs 2–3 variants. |
| ✅ `sfx_hit_shock` | Combat | `EventBus.on_hit_dealt` where `damage_type == "Shock"` | P1 | Lightning impact (zap, chain crackle). Needs 2–3 variants. |
| ✅ `sfx_hit_void` | Combat | `EventBus.on_hit_dealt` where `damage_type == "Void"` | P1 | Void/distortion impact (eerie whoosh, dark warble). Needs 2–3 variants. |
| ✅ `sfx_crit` | Combat | `EventBus.on_crit` | P1 | Crit sound (ping, chime, satisfying pop). Plays on top of hit sound. Ship-critical. |
| ✅ `sfx_block` | Combat | `EventBus.on_block` | P2 | Shield/armor deflection. Played when damage is mitigated. |
| ✅ `sfx_dodge` | Combat | `EventBus.on_dodge` | P2 | Dodge/evasion whoosh (swift, clean). Tied to player's dodge passive (Shade) or dodge triggers. |
| `sfx_status_burn_apply` | Combat | `EventBus.on_status_applied` where `status_id == "burning"` | P2 | Burning applied to enemy (ignition spark). |
| `sfx_status_burn_tick` | Combat | Enemy's StatusEffectComponent tick while Burning | P2 | Ongoing burn damage sound (fire crackle). Low-volume loop or single tick. |
| `sfx_status_chill_apply` | Combat | `EventBus.on_status_applied` where `status_id == "chilled"` | P2 | Frost applied (ice crystallize). |
| `sfx_status_frozen` | Combat | `EventBus.on_status_applied` where `status_id == "frozen"` | P2 | Freeze lock sound (icy shatter). |
| `sfx_status_shocked_apply` | Combat | `EventBus.on_status_applied` where `status_id == "shocked"` | P2 | Shock applied (arc snap). |
| `sfx_status_void_apply` | Combat | `EventBus.on_status_applied` where `status_id == "void_touched"` | P2 | Void-Touched applied (distortion pop). |

---

## Combat SFX — Deaths & Elimination

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| ✅ `sfx_kill` | Combat | `EventBus.on_kill` | P1 | Enemy death — player scored the kill. Satisfying, celebratory. Ship-critical. |
| ✅ `sfx_death_enemy_normal` | Combat | `EventBus.on_death` where victim is normal enemy | P1 | Normal enemy death. Varied from elite. Needs 2 variations (generic grunt vs. specialized enemy type). |
| ✅ `sfx_death_enemy_elite` | Combat | `EventBus.on_death` where victim is elite enemy | P2 | Elite enemy death (deeper, more dramatic than normal). Varies from normal + boss. |
| ✅ `sfx_death_enemy_boss` | Combat | `EventBus.on_death` where victim is boss | P2 | Boss enemy death (epic, memorable). Triggers `GameManager.on_boss_death` signal if available. |
| ✅ `sfx_death_player` | Combat | `EventBus.on_death` where victim is player | P1 | Player death. Stinger or sad tone. Ship-critical. |

---

## Dash & Movement SFX

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| ✅ `sfx_dash_generic` | Movement | `player._on_dash_started()` → `_dash_sound_id()` fallback | P2 | Generic dash whoosh. Fallback if no class variant plays. |
| ✅ `sfx_dash_teleport` | Movement | Wizard/Necromancer dash (`dash_style == "teleport"`/`"planeshift"`) | P2 | Teleport blink (magical pop in/out). Planeshift (The Shade) reuses this stinger. |
| ✅ `sfx_dash_deadly` | Movement | Ninja (The Whisper) dash (`dash_style == "deadly"`) | P2 | Deadly Dash strike trail (swift blade sweep, ghostly). |
| ✅ `sfx_dash_dodge_roll` | Movement | Rogue/Demonologist dodge/hop (dodge anim plays on dash, or `dash_style == "ashenstep"`) | P2 | Rolling dodge (tumble, cloth rustle). |

---

## Skills, Summons & Pets (Q/E) — task 15 close-out, 2026-08-15

**Design decision:** NOT one sound per skill/pet. Every Q/E skill's `AbilityDefinition.tags` carries a
category (`SkillFactory._ability(..., category)`) chosen per-skill at its build site — "Buff" (self
status/heal), "Offensive" (damage-dealing cast), "Summon" (spawns a companion), or "Movement"
(stance/utility, no damage or status). `SkillComponent.trigger()` emits `EventBus.on_ability_used`
(the same signal weapon fire uses) and `AudioManager._on_ability_used` reads `tags[1]` to route to
one of 4 shared stingers below. A future skill gets a voice automatically the moment its build
function passes a category — no new sample, no new wiring. Pet ATTACKS are deliberately silent
(the mix is already dense; only the summon moment is voiced, per CLAUDE.md pet standard).

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| ✅ `sfx_skill_buff` | Ability | Any `Skill`-tagged ability with `tags[1] == "Buff"` (Second Wind, Sanctuary, Sharpen, Battle Cry, Reload, Aegis Shield, Lay on Hands, Smoke Bomb, …) | P2 | Rising self-cast chime. |
| ✅ `sfx_skill_offensive` | Ability | `tags[1] == "Offensive"` (Frost Burst, Storm Call, Blood Eruption, Throw Things, Whip Attack, Archdemon's Call, Shield Rush, …) | P2 | Cast-release burst (zap + crack). |
| ✅ `sfx_skill_movement` | Ability | `tags[1] == "Movement"` (Quiver Swap is the only user today) | P2 | Light whoosh, deliberately distinct from any `sfx_dash_*`. |
| ✅ `sfx_summon_arrive` | Ability | `tags[1] == "Summon"` (Summon Angry Demon, Rise Corpse, Bone Legion, Summon Blood Elemental, Mirror Archer, Summon Bear, Summon Hounds, Spirit Guardians) | P2 | Deeper rising swell + low toll — "something is climbing out of the ground." Plays once on cast; not repeated per pet hit. |

---

## Pickups & Loot

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| ✅ `sfx_pickup_xp` | Pickup | `EventBus.on_pickup` where `pickup_type == "xp"` | P1 | XP pickup chime. Short, satisfying. Ship-critical. Needs 1–2 variations (soft vs. "leveling up soon" higher pitch). |
| ✅ `sfx_pickup_currency` | Pickup | `EventBus.on_pickup` where `pickup_type == "currency"` | P1 | Money/gold pickup clink. Similar to XP but distinct (cash register tone). |
| ✅ `sfx_pickup_weapon` | Pickup | `EventBus.on_pickup` where `pickup_type == "weapon"` | P1 | Weapon drop (metallic shine, magical glow if legendary). Distinct from currency. |
| ✅ `sfx_pickup_mod` | Pickup | `EventBus.on_pickup` where `pickup_type == "mod"` | P2 | Mod pickup (glow, tech sparkle). |
| ✅ `sfx_pickup_keystone` | Pickup | `EventBus.on_pickup` where `pickup_type == "keystone"` | P2 | Keystone/upgrade pickup (crystalline chime, special resonance). |

---

## Level-Up & Progression

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| ✅ `sfx_level_up` | UI | `GameManager.on_level_up` or UpgradeManager panel opens | P1 | Level-up fanfare (ascending notes, celebratory). Ship-critical. |
| ✅ `sfx_upgrade_select` | UI | Player clicks an upgrade choice on the UpgradeManager panel | P2 | Selection confirm sound (soft chime). |

---

## Extraction System

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| ✅ `sfx_extraction_warning` | Extraction | `GameManager.extraction_window_opened` | P2 | Warning tone (alarm, alert rising tone). Alerts the player extraction is available. |
| ✅ `sfx_extraction_channel_start` | Extraction | `ExtractionManager.extraction_channel_started` | P2 | Extraction channeling begins (magical warmth, hum onset). Short intro. |
| ✅ `sfx_extraction_channel_loop` | Extraction | ExtractionManager ticks during extraction (loopable hum) | P2 | Loopable background hum while channeling. Sustained, meditative. ~1–2s loop. Stand-in asset (`spaceEngineLow`) — not a purpose-made drone, revisit if it doesn't read as "channeling." |
| ✅ `sfx_extraction_channel_complete` | Extraction | `ExtractionManager.extraction_complete` + `GameManager.extraction_successful` | P1 | Extraction success (magical surge, triumphant chime). Plays as hum stops. |
| ✅ `sfx_extraction_interrupted` | Extraction | `ExtractionManager.extraction_interrupted` | P2 | Extraction interrupted (harsh buzz, failure tone). Played when channel is broken. |

---

## UI Interactions

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| ✅ `sfx_ui_click` | UI | Any hub panel button clicked (shop, armory, codex, etc.) | P2 | Button click (soft pop, satisfying). One generic sound for all non-purchase actions. Table entry ready; hub panel scripts still need `AudioManager.play_ui()` call sites wired (see TODO). |
| `sfx_ui_hover` | UI | Mouse hovers over interactive element | P2 | Hover highlight (subtle whoosh or tone). Optional — can skip if click-only feedback is sufficient. Skipped per manifest note. |
| ✅ `sfx_ui_panel_open` | UI | Hub panel transitions open | P2 | Panel slide/fade-in sound (whoosh, swish). One for all panels. Table entry ready; call sites pending (see TODO). |
| ✅ `sfx_ui_panel_close` | UI | Hub panel transitions closed | P2 | Panel slide/fade-out sound (reverse whoosh). Table entry ready; call sites pending (see TODO). |
| ✅ `sfx_ui_purchase` | UI | Player completes a transaction (buy weapon, buy mod, level-up purchase) | P2 | Purchase confirmation (cash register, satisfying chime). Distinct from generic click. Table entry ready; call sites pending (see TODO). |
| ✅ `sfx_ui_error` | UI | Invalid action (insufficient currency, unavailable action, etc.) | P2 | Error beep (negative buzz, "nope" tone). Table entry ready; call sites pending (see TODO). |
| ✅ `sfx_ui_cancel` | UI | Player cancels an action or closes a menu | P2 | Cancel sound (soft decline tone, back-button sound). Table entry ready; call sites pending (see TODO). |

---

## Merchant & Altar Interactions

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| `sfx_merchant_open` | Hub | Hub merchant/shop NPC dialogue initiates | P2 | Merchant greeting (jingle, vendor tone). Tied to merchant NPC state. |
| `sfx_altar_interact` | Hub | Altar interactable is activated (future: stat-boosting stations, etc.) | P2 | Altar activation sound (sacred chime, magical resonance). |

---

## Boss Encounters

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| ✅ `sfx_boss_intro` | Boss | `GameManager.final_boss_spawned` or boss enters arena | P2 | Boss entrance sound (stinger, dramatic music sting, or SFX layer). Short, memorable. |
| `sfx_boss_phase_transition` | Boss | Boss changes phases (end phase 1 → phase 2, etc.) | P2 | Phase transition cue (whoosh, energy surge, warning tone). One per boss or per phase family. |

---

## Music — Ambient & Biome Loops

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| ✅ `mus_hub` | Music | Hub/base camp active; no extraction channel running | P1 | Hub background loop (calm, contemplative). 2–3 min loopable track. Ship-critical. |
| ✅ `mus_caves` | Music | Phase 1–4 in Caves biome active | P1 | Caves ambient track (dark dungeon mood, sparse, tense). Loopable, 15+ min. Committed track loops at ~94s (shorter than spec) — acceptable for now, revisit if the seam is audible. |
| ✅ `mus_catacombs` | Music | Phase 1–4 in Catacombs biome active | P2 | **Original, composed in REAPER 2026-08-15** (`tools/sfx_forge/music_catacombs.py`). 96.0 s loop, 60 BPM, A Phrygian, open fifths only. Processional footfall on beats 1 and 3, crypt bell every 8 bars, one descending motif in the B section. −27.7 LUFS (matches `caves.ogg` exactly). Loop is phase-continuous by construction — see the loop architecture note below. |
| ✅ `mus_nightmare_realm` | Music | Phase 1–4 in Nightmare Realm biome active | P2 | **Original, composed in REAPER 2026-08-15** (`tools/sfx_forge/music_nightmare.py`). 114.0 s loop, deliberately **pulse-less** — no beat at any marchable interval (measured). 110/113 Hz detuned pair beats at 3 Hz (roughness, not rhythm); consonant A-minor bells at off-grid times, hitting the Eb tritone 3× per loop. −27.7 LUFS. |
| `mus_threshold` | Music | Phase 1–4 in Threshold biome active | P2 | Threshold (climactic, building tension). Loopable. |
| `mus_inferno` | Music | Phase 1–4 in Inferno biome active | P2 | Inferno (intense, aggressive). Loopable. |
| ✅ `mus_boss` | Music | Boss encounter active (final_boss_spawned) | P2 | Boss music layer or full track (epic, memorable). Replaces or layers over biome music. One track or per-boss stinger. Committed track loops at ~33s — short for a boss encounter; revisit if it feels repetitive. |

---

## TODO — Missing Assets (task 15 gaps for Ben)

No good-fit free CC0/CC-BY asset was found for these in the time available. Table entries exist and point at nonexistent files (AudioManager no-ops silently); drop a file at the given path and the sound goes live with zero code changes.

| ID(s) | Path(s) | Why it's open |
|---|---|---|
| `sfx_status_burn_apply`, `sfx_status_chill_apply`, `sfx_status_frozen`, `sfx_status_shocked_apply`, `sfx_status_void_apply` | `assets/audio/sfx/status/*.ogg` | No short, subtle "status applied" stingers found in the Kenney packs pulled for this pass; worth a dedicated OpenGameArt/Kenney search pass. |
| `sfx_status_burn_tick` | *(no table entry yet)* | Needs a StatusEffectComponent tick hook in addition to an asset — not started. |
| `sfx_channel_loop` | *(no table entry yet)* | Needs per-family loop variants (5-6) and a ChoreographyRunner channel-tick hook — bigger scope than a data-only pass. (`sfx_projectile_fire` / `sfx_melee_swing_arc` were wired 2026-07-09 via `EventBus.on_ability_used`, reusing pitch-varied swing whooshes as stand-in assets.) |
| `sfx_boss_phase_transition` | *(no table entry yet)* | No per-phase transition signal currently emitted by boss choreography. |
| `sfx_merchant_open`, `sfx_altar_interact` | *(no table entries yet)* | Merchant purchase/error sounds are wired (`sfx_ui_purchase`/`sfx_ui_error`); the greeting/altar stingers themselves are unassigned. |
| `sfx_ui_hover` | *(intentionally skipped)* | Manifest marks this optional; click-only feedback is sufficient. |
| `amb_caves_drip`, `amb_caves_wind`, `amb_threshold_hum`, `amb_inferno_crackle` | *(no table entries yet)* | Lowest-priority polish per the manifest; not started. |
| `mus_threshold`, `mus_inferno` | `assets/audio/music/{threshold,inferno}.ogg` | Biomes 4-5 aren't shipped yet (per `docs/audio_pipeline.md` step 6, "add one track per biome as each biome ships"). `mus_catacombs` and `mus_nightmare_realm` were **closed 2026-08-15** — composed rather than sourced; re-run `tools/sfx_forge/build_biome_music.py` to rebuild either, and use the same module for the remaining two. |

**Loop-seam QA needed (agent has no audio playback):** `mus_caves` and `mus_boss` are third-party OpenGameArt loops — Ben should listen for a pop/click at the loop point before ship. `mus_hub` (converted from MP3) tapers to near-silence at both ends and is very unlikely to pop.

### Loop architecture for the composed biome tracks (2026-08-15)

`mus_catacombs` and `mus_nightmare_realm` are seamless *by construction* rather than by
crossfade, which matters if anyone edits them later. Two rules make it work, both enforced
in `tools/sfx_forge/music_lib.py`:

1. **Render two periods, keep the second.** Every discrete event is emitted at `t` and at
   `t + SONG`, and the render covers `[0, 2*SONG]`. By the second period the reverb has rung
   up, so that period is one cycle of the steady state of a signal that repeats forever — the
   tail that "should" wrap into the head is already in it. No splice at the seam.
2. **Whole-Hz drones over a whole-second loop.** REAPER's JS tonegenerator quantizes Base
   Frequency to whole Hz (ask for 36.7049, get 37.0), so a sustained oscillator only lands on
   the same phase at both ends if `freq × SONG` is an integer. Both tracks are centred on A
   (55 / 110 / 165 Hz) for exactly this reason. Breaking this rule does not error — it just
   produces a click, which is how it was found.

Measured on the shipped files: the sample step across the join is **0.16×** (Catacombs) and
**0.02×** (Nightmare) of the 99.9th-percentile *interior* step, i.e. smaller than jitter the
waveform already contains. Both loop points also sit inside the spread of ordinary interior
bar lines on rms and spectral similarity, so neither reads as a restart.

**Still needs Ben's ears:** the agent has no audio playback, so everything above is measurement,
not listening. The two judgement calls most likely to want a knob turn are named in the session
report — the Nightmare Realm's 3 Hz drone beat (`abyss_detune` level) and the Catacombs' footfall
prominence (`footfall` level).

---

## Ambient Layers (Optional Polish)

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| `amb_caves_drip` | Ambient | Caves biome active (background ambience) | P2 | Water dripping (cave ambience layer). Subtle, loopable. |
| `amb_caves_wind` | Ambient | Caves biome active | P2 | Wind through caverns (distant, hollow). Optional; skip if budget tight. |
| `amb_threshold_hum` | Ambient | Threshold biome active | P2 | Threshold humming (magical energy, eerie tone). Optional. |
| `amb_inferno_crackle` | Ambient | Inferno biome active | P2 | Fire crackle (distant flames, ambient heat). Optional. |

---

## Summary

| Priority | Count | Categories |
|---|---|---|
| **P1 (Ship-blocking)** | 14 | Hit impacts (5 types), Crit, Kill, Player Death, Weapon Fire, XP Pickup, Currency Pickup, Weapon Pickup, Level-Up, Extraction Success, Hub Music |
| **P2 (Polish)** | 63 | Swing families, Channel loops, Dodges/Blocks, Status effects, Elite/Boss deaths, Dashes (3 variants), Skills (6), Pets (6), Mod/Keystone pickups, Upgrade select, Extraction warning/loop/interrupt, UI (7 sounds), Boss intro/phase, 5 biome tracks, Ambient layers (4) |
| **Total** | **77** | Unique audio assets required |

---

## Asset Sourcing & Next Steps

**Check Minifantasy SFX packs first** for style cohesion. The Minifantasy character asset packs ship with some SFX content; audit whether any of the attack/impact/footstep/defeat sounds align with intended tones before sourcing additional libraries.

---

## Re-source shopping list (2026-07-10 pass)

Confirmed: Leohpaz (the official Minifantasy audio partner) publishes companion SFX packs
for the exact art packs this game uses. All packs: personal + commercial use OK, no
redistribution, credits optional, no generative AI. Individual packs ≈ $2.99; the
**Leohpaz Complete SFX Bundle** ($49.99, itch.io/s/79857) covers everything below.

**Free audition first (zero cost, hear the style):** "RPG Essentials SFX - Free" (48 sounds)
and the "Minifantasy - Dungeon Audio Pack" (free; 62 SFX incl. sword hits/misses, chest and
door foley, 2 loopable music tracks).

| Sound slots (SoundTable ids) | Pack | Why |
|---|---|---|
| `sfx_swing_light/heavy`, `sfx_melee_swing_arc`, `sfx_projectile_fire`, `sfx_hit_physical`, `sfx_block` | **Minifantasy - Weapons SFX** (40) | Purpose-made weapon swings/impacts in the house style. |
| Per-class combos, Q/E skills, dashes, `sfx_death_player` | **Minifantasy - True Heroes I–IV SFX** (63/90/65/82) | Authored per character animation package we already wire: Warcry, Guard, Throw, Thunderblade, Shuriken, Bomb, Dodge, Root/Shapeshift, etc. Covers all 12 classes. |
| `sfx_hit_fire/cryo/shock/void`, `sfx_status_*` (all 5 TODO slots), `sfx_crit` | **Minifantasy - Magic and Sorcery SFX** (35) + **Magic Weapons SFX** (109) | Elemental impacts + apply stingers, matching the mod/status system. |
| `sfx_death_enemy_normal/elite`, `sfx_kill` | **Minifantasy - Creatures SFX** (153) + **Ancient Danger Creatures SFX** (60) | Per-creature vocals for the cave roster (fodder/bats/brutes/casters). |
| `sfx_boss_intro`, `sfx_death_enemy_boss`, phase stingers | **Minifantasy - True Villains SFX** (79) + **Boss Encounter SFX** (19) | Goblin King / Ancient Troll voices + encounter stingers. |
| `sfx_pickup_*`, `sfx_ui_*`, `sfx_upgrade_select` | **Retro RPG 100 UI SFX** + **Inventory SFX** (25) | Full UI/pickup coverage in one retro-consistent voice. |
| `sfx_level_up`, `sfx_extraction_channel_complete` | **RPG Jingles and Fanfares** | Proper fanfares instead of repurposed chimes. |
| `sfx_extraction_warning/channel_start/channel_loop/interrupted` | **Portals and Runes SFX** (41) | Actual portal hums/surges — replaces the `spaceEngineLow` stand-in drone. |
| `amb_caves_drip/wind` + descent depth polish | **Mining Cave SFX** (42) + **Ambiences and Perspectives** (56) | Cave ambience layers (keeps, but deepens, the liked cave track). |
| `mus_boss`, future biome tracks | **RPG Music Pack Vol 1-3 (Retro or Orchestral)** | Audition against `mus_hub` (KEEP) to pick the matching family. |

**KEEP unchanged:** `mus_hub` (hub music) and `mus_caves` (cave ambience) — Ben approved these.

**Swap workflow:** Ben downloads packs → drop raw files under `assets/audio/_incoming/<pack_name>/`
→ Claude converts (wav→ogg where useful), renames onto the existing `res://assets/audio/...`
paths (or edits `data/factories/sound_table.gd` stream lists), and retunes `volume_db`
per slot. AudioManager needs zero code changes.

**Primary sources** (per `docs/audio_pipeline.md` §7):
- **Music**: juanjo_sound (Dark Dungeon Ambient), OpenGameArt.org (CC0), Pixabay (royalty-free)
- **SFX**: Kenney.nl (CC0), OpenGameArt.org (CC0), itch.io free packs, Pixabay SFX

**Synthesis opportunities** (per audio_pipeline.md §7):
- Extraction hum: low drone + crystal chime (layered CC0 SFX)
- Void hits: reversed/pitch-shifted standard impact
- Channel ticks: vary by spell family (whoosh, crackle, chime)

**Implementation order** (per audio_pipeline.md §8):
1. AudioManager skeleton + SFX pool
2. Combat core: hit (5 types), crit, kill, death (P1 → plays immediately)
3. Pickup chime + UI clicks (feedback loop)
4. Hub music (proves music system)
5. Per-biome music (as biomes ship)
6. Extraction lifecycle SFX
7. Status effect cues (subtle, layered)
8. Ambient layers (lowest priority during crunch)
9. Weapon/class-specific variants (polish pass)

---

*Generated 2026-07-06. All IDs follow snake_case convention (sfx_*, mus_*, amb_*). Trigger sites reference EventBus signals, ChainFactory/SkillFactory choreography phases, and manager autoloads per audio_pipeline.md architecture.*
