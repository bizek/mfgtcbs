# Audio Asset Manifest — Extraction Survivors

Complete enumeration of sound-worthy events across all game systems. Organized by category, with EventBus signal triggers and implementation notes.

---

## Combat SFX — Weapon Fire & Combo Hits

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| `sfx_swing_light` | Combat | `ChainFactory` light swing phase (hit_frame) | P1 | Light attack impact; all 10 kits share one sound family. Used by: Fighter Attack, Rogue Slash, Paladin Strike, Wizard Bolt, Blood Mage Shard, Ranger Shot, Bard Strike, Barbarian Cleave, Ninja Slash, Gunslinger Shot. Needs 2–3 variations (quick, crisp). |
| `sfx_swing_heavy` | Combat | `ChainFactory` heavy swing phase (hit_frame) | P1 | Heavy finisher impact (Cataclysm, Bomb, Hammer, Thunder Blade, etc.). Needs 2–3 variations (impact + rumble). |
| `sfx_channel_loop` | Combat | `ChainFactory` channel phase tick (per beat) | P2 | Looped ability tick for held-RMB channels (Taunt shockwave, Fan of Blades, Dome, Torrent, Vampirize, Conceal, Song, Guard, Thousand Blades Storm, Desert Storm). Soft, repetitive. One loop sound per channel family (shockwave, projectile, song, etc.) — 5–6 variations. |
| `sfx_projectile_fire` | Combat | `SpawnProjectilesEffect` on hit_frame (beam, artillery, summon projectiles) | P2 | Ranged weapon fire (Ember Beam ticks, Void Mortar fuse, Wizard Fireball release, Blood Shard, Chord bolt, Arrow volleys, Gun bullets, Thunder bolt). Varies by spell family. Needs 3–4 family variants (arcane whoosh, fire crackle, ice whistle, lightning snap). |
| `sfx_melee_swing_arc` | Combat | `AreaDamageEffect` on melee arc swing | P2 | Generic melee whoosh (Rogue Fan finisher, Paladin bash, Barbarian Sunder shove). Light, atmospheric. One family suffices. |

---

## Combat SFX — Impacts & Elemental Reactions

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| `sfx_hit_physical` | Combat | `EventBus.on_hit_dealt` where `damage_type == "Physical"` | P1 | Physical impact sound. Ship-critical. Needs 2–3 impact variations (dull thud, sharp crack, heavy thump). |
| `sfx_hit_fire` | Combat | `EventBus.on_hit_dealt` where `damage_type == "Fire"` | P1 | Fire impact (crackle + burn). Needs 2–3 variants. |
| `sfx_hit_cryo` | Combat | `EventBus.on_hit_dealt` where `damage_type == "Cryo"` | P1 | Ice impact (sharp sting, freeze sparkle). Needs 2–3 variants. |
| `sfx_hit_shock` | Combat | `EventBus.on_hit_dealt` where `damage_type == "Shock"` | P1 | Lightning impact (zap, chain crackle). Needs 2–3 variants. |
| `sfx_hit_void` | Combat | `EventBus.on_hit_dealt` where `damage_type == "Void"` | P1 | Void/distortion impact (eerie whoosh, dark warble). Needs 2–3 variants. |
| `sfx_crit` | Combat | `EventBus.on_crit` | P1 | Crit sound (ping, chime, satisfying pop). Plays on top of hit sound. Ship-critical. |
| `sfx_block` | Combat | `EventBus.on_block` | P2 | Shield/armor deflection. Played when damage is mitigated. |
| `sfx_dodge` | Combat | `EventBus.on_dodge` | P2 | Dodge/evasion whoosh (swift, clean). Tied to player's dodge passive (Shade) or dodge triggers. |
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
| `sfx_kill` | Combat | `EventBus.on_kill` | P1 | Enemy death — player scored the kill. Satisfying, celebratory. Ship-critical. |
| `sfx_death_enemy_normal` | Combat | `EventBus.on_death` where victim is normal enemy | P1 | Normal enemy death. Varied from elite. Needs 2 variations (generic grunt vs. specialized enemy type). |
| `sfx_death_enemy_elite` | Combat | `EventBus.on_death` where victim is elite enemy | P2 | Elite enemy death (deeper, more dramatic than normal). Varies from normal + boss. |
| `sfx_death_enemy_boss` | Combat | `EventBus.on_death` where victim is boss | P2 | Boss enemy death (epic, memorable). Triggers `GameManager.on_boss_death` signal if available. |
| `sfx_death_player` | Combat | `EventBus.on_death` where victim is player | P1 | Player death. Stinger or sad tone. Ship-critical. |

---

## Dash & Movement SFX

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| `sfx_dash_generic` | Movement | Player inputs `dash` action / `player.dash()` called | P2 | Generic dash whoosh. Fallback if no class variant plays. |
| `sfx_dash_teleport` | Movement | Wizard (The Spark) dash (`dash_style == "teleport"`) | P2 | Teleport blink (magical pop in/out). One pack for both teleport_out and teleport_in anims. |
| `sfx_dash_deadly` | Movement | Ninja (The Whisper) dash (`dash_style == "deadly"`) | P2 | Deadly Dash strike trail (swift blade sweep, ghostly). |
| `sfx_dash_dodge_roll` | Movement | Rogue (The Shade) dodge roll (dodge anim plays on dash) | P2 | Rolling dodge (tumble, cloth rustle). |

---

## Skills & Neutral Abilities (Q/E)

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| `sfx_skill_shout` | Ability | Barbarian `skill_q` (Battle Cry) hit_frame | P2 | Roar/shout sound. Battle Cry visual already has cry_fx overlay. |
| `sfx_skill_ritual` | Ability | Ninja `skill_q` (Sharpen) hit_frame / whetstone ritual | P2 | Sharpening stone ritual sound (whetstone scrape, culminating in a "ready" ding). Loopable or single. |
| `sfx_skill_reload` | Ability | Gunslinger `skill_q` (Reload) ticks during animation + hit_frame | P2 | Mechanical reload (cylinder spin, click-clack, final snap). Multi-frame sequence or one shot. |
| `sfx_skill_throw_impact` | Ability | Barbarian `skill_e` (Throw Things) hit_frame | P2 | Impact of thrown junk hitting the ground. Heavy thud + crash. |
| `sfx_skill_smoke_puff` | Ability | Ninja `skill_e` (Smoke Bomb) hit_frame | P2 | Smoke puff (whoosh + distant fade-out). Played on vanish. |
| `sfx_skill_whip_crack` | Ability | Gunslinger `skill_e` (Whip Attack) hit_frame | P2 | Whip crack (sharp, tech-enhanced). Played on hit. |
| `sfx_skill_song_charm` | Ability | Bard `skill_e` (Charming Serenade) hit_frame + song loop | P2 | Siren song / charm melody. Loopable per beat (SONG_TICK = 0.8s). One charm song suffices. |

---

## Pet Summons & Attacks

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| `sfx_pet_summon_fire` | Summon | Wizard `ChainFactory.build_wizard_summon()` hit_frame (FireFamiliar spawns) | P2 | Fire Familiar summoning sound (magical ignition, phoenix cry). |
| `sfx_pet_fire_attack` | Combat | FireFamiliar `_start_strike()` called | P2 | Fire Familiar bite attack (quick snap, flame crackle). Loopable per cooldown. |
| `sfx_pet_fire_expire` | Combat | FireFamiliar `disperse()` called (lifetime ends or player dies) | P2 | Fire Familiar disappears (dissipate, fade). |
| `sfx_pet_summon_blood` | Summon | Blood Mage `ChainFactory.build_blood_mage_light()` phase 4 hit_frame (BloodElemental spawns) | P2 | Blood Elemental summoning sound (blood squelch, dark pulse). |
| `sfx_pet_blood_attack` | Combat | BloodElemental `_start_strike()` called | P2 | Blood Elemental pound attack (heavy thud, wet impact). Loopable per cooldown. |
| `sfx_pet_blood_expire` | Combat | BloodElemental `banish()` called (lifetime ends or player dies) | P2 | Blood Elemental vanishes (absorption, return-to-void sound). |

---

## Pickups & Loot

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| `sfx_pickup_xp` | Pickup | `EventBus.on_pickup` where `pickup_type == "xp"` | P1 | XP pickup chime. Short, satisfying. Ship-critical. Needs 1–2 variations (soft vs. "leveling up soon" higher pitch). |
| `sfx_pickup_currency` | Pickup | `EventBus.on_pickup` where `pickup_type == "currency"` | P1 | Money/gold pickup clink. Similar to XP but distinct (cash register tone). |
| `sfx_pickup_weapon` | Pickup | `EventBus.on_pickup` where `pickup_type == "weapon"` | P1 | Weapon drop (metallic shine, magical glow if legendary). Distinct from currency. |
| `sfx_pickup_mod` | Pickup | `EventBus.on_pickup` where `pickup_type == "mod"` | P2 | Mod pickup (glow, tech sparkle). |
| `sfx_pickup_keystone` | Pickup | `EventBus.on_pickup` where `pickup_type == "keystone"` | P2 | Keystone/upgrade pickup (crystalline chime, special resonance). |

---

## Level-Up & Progression

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| `sfx_level_up` | UI | `GameManager.on_level_up` or UpgradeManager panel opens | P1 | Level-up fanfare (ascending notes, celebratory). Ship-critical. |
| `sfx_upgrade_select` | UI | Player clicks an upgrade choice on the UpgradeManager panel | P2 | Selection confirm sound (soft chime). |

---

## Extraction System

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| `sfx_extraction_warning` | Extraction | `GameManager.extraction_window_opened` | P2 | Warning tone (alarm, alert rising tone). Alerts the player extraction is available. |
| `sfx_extraction_channel_start` | Extraction | `ExtractionManager.extraction_channel_started` | P2 | Extraction channeling begins (magical warmth, hum onset). Short intro. |
| `sfx_extraction_channel_loop` | Extraction | ExtractionManager ticks during extraction (loopable hum) | P2 | Loopable background hum while channeling. Sustained, meditative. ~1–2s loop. |
| `sfx_extraction_channel_complete` | Extraction | `ExtractionManager.extraction_complete` + `GameManager.extraction_successful` | P1 | Extraction success (magical surge, triumphant chime). Plays as hum stops. |
| `sfx_extraction_interrupted` | Extraction | `ExtractionManager.extraction_interrupted` | P2 | Extraction interrupted (harsh buzz, failure tone). Played when channel is broken. |

---

## UI Interactions

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| `sfx_ui_click` | UI | Any hub panel button clicked (shop, armory, codex, etc.) | P2 | Button click (soft pop, satisfying). One generic sound for all non-purchase actions. |
| `sfx_ui_hover` | UI | Mouse hovers over interactive element | P2 | Hover highlight (subtle whoosh or tone). Optional — can skip if click-only feedback is sufficient. |
| `sfx_ui_panel_open` | UI | Hub panel transitions open | P2 | Panel slide/fade-in sound (whoosh, swish). One for all panels. |
| `sfx_ui_panel_close` | UI | Hub panel transitions closed | P2 | Panel slide/fade-out sound (reverse whoosh). |
| `sfx_ui_purchase` | UI | Player completes a transaction (buy weapon, buy mod, level-up purchase) | P2 | Purchase confirmation (cash register, satisfying chime). Distinct from generic click. |
| `sfx_ui_error` | UI | Invalid action (insufficient currency, unavailable action, etc.) | P2 | Error beep (negative buzz, "nope" tone). |
| `sfx_ui_cancel` | UI | Player cancels an action or closes a menu | P2 | Cancel sound (soft decline tone, back-button sound). |

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
| `sfx_boss_intro` | Boss | `GameManager.final_boss_spawned` or boss enters arena | P2 | Boss entrance sound (stinger, dramatic music sting, or SFX layer). Short, memorable. |
| `sfx_boss_phase_transition` | Boss | Boss changes phases (end phase 1 → phase 2, etc.) | P2 | Phase transition cue (whoosh, energy surge, warning tone). One per boss or per phase family. |

---

## Music — Ambient & Biome Loops

| ID | Category | Trigger | Priority | Notes |
|---|---|---|---|---|
| `mus_hub` | Music | Hub/base camp active; no extraction channel running | P1 | Hub background loop (calm, contemplative). 2–3 min loopable track. Ship-critical. |
| `mus_caves` | Music | Phase 1–4 in Caves biome active | P1 | Caves ambient track (dark dungeon mood, sparse, tense). Loopable, 15+ min. |
| `mus_catacombs` | Music | Phase 1–4 in Catacombs biome active | P2 | Catacombs ambient (heavier, slower pulse than Caves). Loopable. |
| `mus_nightmare_realm` | Music | Phase 1–4 in Nightmare Realm biome active | P2 | Nightmare Realm (unsettling, chaotic energy). Loopable. |
| `mus_threshold` | Music | Phase 1–4 in Threshold biome active | P2 | Threshold (climactic, building tension). Loopable. |
| `mus_inferno` | Music | Phase 1–4 in Inferno biome active | P2 | Inferno (intense, aggressive). Loopable. |
| `mus_boss` | Music | Boss encounter active (final_boss_spawned) | P2 | Boss music layer or full track (epic, memorable). Replaces or layers over biome music. One track or per-boss stinger. |

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
