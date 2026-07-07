# Audio Pipeline

## Status

**Implemented 2026-07-06** (task 14), **real assets wired 2026-07-06** (task 15). `AudioManager` autoload (`scripts/managers/audio_manager.gd`) + data-driven sound table (`data/factories/sound_table.gd`) are live. All P1 manifest entries (5 hit types, crit, kill, deaths, weapon swings, pickups, level-up, extraction success) plus hub/caves/boss music are wired to real CC0 assets (Kenney.nl SFX packs, OpenGameArt.org CC0 music — see `docs/asset_inventory.md` §7-8 for the per-file source table). Most P2 entries are wired too (block/dodge, boss intro, mod/keystone pickups, UI sounds, extraction lifecycle). Task-14 synthesized `placeholder_*.wav` files have been deleted. Remaining gaps (status effect cues, biomes 2–5 music, ambient layers) have no good-fit free asset yet and are left as table entries pointing at nonexistent files — AudioManager no-ops on missing files. Sections below marked *(spec)* describe intent that is not yet exercised (biomes 2–5 music files, ducking).

## How to Add a Sound (the recipe)

1. Drop the audio file under `assets/audio/` (see Asset Layout; OGG for real assets, placeholders are WAV).
2. Add an entry to `SoundTable.ALL` in `data/factories/sound_table.gd`:
   ```gdscript
   "sfx_my_sound": {
       "streams": ["res://assets/audio/sfx/combat/my_sound.ogg"],  # >1 path = random variation
       "volume_db": -8.0,        # base loudness offset
       "pitch_variance": 0.08,   # ±8% random pitch (default; 0.0 for jingles/stingers)
       "max_per_frame": 2,       # K: same-sound cap per frame (default 2)
       "min_interval_ms": 30,    # cross-frame retrigger throttle (default 30)
       "positional": true,       # true = plays from the AudioStreamPlayer2D pool at a world pos
   },
   ```
3. Trigger it:
   - **Combat events**: if the trigger is an EventBus signal AudioManager already handles (hits, crit, kill, death, block, dodge, status apply, pickup), just add the ID to the relevant lookup map at the bottom of `sound_table.gd` (`HIT_SOUND_BY_DAMAGE_TYPE`, `STATUS_SOUND`, `PICKUP_SOUND`). No code.
   - **New signal**: connect it in `AudioManager._connect_signals()` and call `play(id, world_pos)`.
   - **UI / non-EventBus moments**: call `AudioManager.play_ui("sfx_my_sound")` from the UI script.
4. Music: add to `SoundTable.MUSIC` and either point a level's `music_id` at it (`data/factories/level_data.gd`) or call `AudioManager.play_music("mus_x")` at the scene hook.

Missing file → one `push_warning` at first play, then silent no-op. The game runs fine with zero assets present.

## Runtime Architecture (as built)

- **Pools** (created once in `_ready()`, zero node churn): 10 `AudioStreamPlayer` (global/UI SFX) + 16 `AudioStreamPlayer2D` (positional combat SFX, `max_distance` 480) + 2 music players (crossfade pair) + 1 dedicated loop player (extraction hum). Hard voice ceiling: 29.
- **Positional vs global split**: hits, enemy deaths, statuses, block/dodge = positional (they happen at enemy positions, off-screen combat attenuates). Crit, kill confirm, player death, pickups, level-up, extraction, UI, music = global (player-centric feedback).
- **Limiter** (the zero-cooldown / horde-frame defense, precedent: CombatFeedbackManager's composite buffering):
  - per sound: at most `max_per_frame` (K, default 2, hits 3) instances per frame;
  - each extra same-frame instance plays at −2 dB (stack falloff);
  - across frames: `min_interval_ms` throttle (default 30 ms);
  - pools cap total voices regardless.
  - Loudest realistic frame (AoE kill on a horde + pickup vacuum): 3 hit + 2 death ≤ 5 positional voices; 2 crit + 2 kill + 2 pickup + 1 level-up ≤ 7 global voices — well under the 26 SFX-voice ceiling and, with −6…−10 dB base volumes, under clipping on the SFX bus.
- **Pool acquisition**: round-robin, prefer idle, steal oldest when saturated. Music/loop players are never stolen (separate pools).
- **Music**: `play_music(id)` crossfades over 1.5 s via the two-player pair; same-ID calls no-op. Looping is manual (`finished` → replay) so tracks loop whether or not import loop points are set. Boss flow: `final_boss_spawned` → save current track, cut to `mus_boss`; `final_boss_defeated` → boss death SFX + restore biome track.
- **Settings**: AudioManager only plays into the existing `Master/Music/SFX` buses; `Settings` (task 09) owns bus volumes/mute, so the sliders affect everything with no extra wiring.

### Wired triggers (task 14 proof set)

| Trigger | Sound |
|---|---|
| `EventBus.on_hit_dealt` | `sfx_hit_{physical,fire,cryo,shock,void}` via `HIT_SOUND_BY_DAMAGE_TYPE` (engine types `Ice`→cryo, `Lightning`→shock, `True`→physical). Also plays `sfx_swing_{light,heavy}` at the attacker's position when `hit_data.ability` is a ChainFactory combo (tag `"Combo"`, `ability_id` ending `_light`/`_heavy`) — see `_play_swing_sfx()` in audio_manager.gd |
| `EventBus.on_crit` / `on_kill` | `sfx_crit`, `sfx_kill` |
| `EventBus.on_death` | `sfx_death_player` / `sfx_death_enemy_elite` / `sfx_death_enemy_normal` |
| `EventBus.on_block` / `on_dodge` | `sfx_block`, `sfx_dodge` |
| `EventBus.on_status_applied` | table-ready (no good-fit free asset yet, task 15 left open) |
| `EventBus.on_pickup` (now emitted by all five pickup scripts) | `sfx_pickup_{xp,currency,weapon,mod,keystone}` |
| `UpgradeManager.level_up_ready` | `sfx_level_up` |
| `GameManager.run_started` | biome music via `LevelData.get_music_id(current_level)` |
| `GameManager.final_boss_spawned` / `final_boss_defeated` | `mus_boss` in/out + `sfx_boss_intro` / `sfx_death_enemy_boss` |
| `GameManager.extraction_window_opened` / `extraction_successful` / `player_died` | warning / complete + music fade-outs |
| `ExtractionManager` channel started/interrupted/complete | hum loop lifecycle |
| `hub.gd` / `main_menu.gd` `_ready()` | `AudioManager.play_music("mus_hub")` (direct call — non-EventBus moment) |

Placeholder assets are synthesized WAVs named `placeholder_*.wav` — replace by dropping real OGGs and updating the table paths.

---

## Architectural Decision: AudioManager Autoload

**Decision: build an AudioManager autoload.**

The game's audio is inherently global: hit sounds need to play wherever in the arena combat happens, music changes on phase transitions, and volume settings must apply uniformly. A single autoload listener satisfies all of this cleanly. It connects to EventBus, GameManager, and ExtractionManager signals in `_ready()` and routes sounds from one place.

Alternative considered — **per-system audio** (HealthComponent plays its own hit SFX, each weapon plays its own fire sound, etc.): rejected. It scatters audio decisions into a dozen scripts, makes volume/mute control awkward (every sound-emitting node needs to know the current bus volume), and turns adding a new sound event into a multi-file change. The EventBus already aggregates every combat event worth hearing; AudioManager listens there.

AudioManager is registered as an autoload alongside the other managers. It owns no game state. It only reads events and plays sounds.

---

## Asset Layout

```
assets/audio/
├── music/
│   ├── hub.ogg
│   ├── caves.ogg
│   ├── catacombs.ogg
│   ├── nightmare_realm.ogg
│   ├── threshold.ogg
│   └── inferno.ogg
└── sfx/
    ├── combat/
    │   ├── hit_physical.ogg
    │   ├── hit_fire.ogg
    │   ├── hit_cryo.ogg
    │   ├── hit_shock.ogg
    │   ├── hit_void.ogg
    │   ├── crit.ogg
    │   ├── kill.ogg
    │   ├── death_player.ogg
    │   ├── death_enemy.ogg
    │   ├── block.ogg
    │   └── dodge.ogg
    ├── status/
    │   ├── burning.ogg
    │   ├── chilled.ogg
    │   ├── shocked.ogg
    │   └── void_debuff.ogg
    ├── pickup/
    │   └── pickup_loot.ogg
    ├── ui/
    │   ├── ui_select.ogg
    │   └── ui_confirm.ogg
    ├── extraction/
    │   ├── extraction_warning.ogg
    │   ├── extraction_channel_hum.ogg
    │   ├── extraction_success.ogg
    │   └── extraction_interrupted.ogg
    └── ambient/
        ├── caves_ambient.ogg
        └── (one per biome, added as biomes ship)
```

All audio files use OGG Vorbis. No MP3 — Godot's OGG decoder is patent-free and performs better in the streaming context. Music tracks must be loopable (set loop points in Godot's import settings, not in the DAW/source file).

---

## AudioManager Responsibilities

**Does:**
- Plays and stops music; crossfades between biomes and on hub entry
- Listens on EventBus for combat signals → dispatches SFX
- Listens on GameManager for phase/run lifecycle signals → switches music
- Listens on ExtractionManager for extraction lifecycle signals → plays extraction SFX
- Listens on GameManager for hub/UI transitions → plays UI SFX
- Manages Godot AudioServer bus volumes for Master, Music, and SFX
- Pools a fixed set of AudioStreamPlayers to avoid node churn during heavy combat

**Does not:**
- Make gameplay decisions. It reads events; it never writes game state.
- Hold references to game entities. It reads signal payloads for positional audio only.
- Block on asset loading. All SFX are preloaded in `_ready()`; no `load()` calls during combat.

---

## Audio Bus Layout

Three buses in Godot's AudioServer:

```
Master
├── Music   (bus index 1)
└── SFX     (bus index 2)
```

All AudioStreamPlayers for music use the Music bus. All SFX players use the SFX bus. This gives independent volume sliders and a single mute point per category. Bus configuration lives in `res://default_bus_layout.tres` (Godot creates this file automatically).

---

## Signal-Driven Triggering

AudioManager subscribes to three signal sources in `_ready()`: EventBus (combat), GameManager (lifecycle), and ExtractionManager (extraction lifecycle).

**EventBus signals AudioManager listens to:**

| Signal | SFX response |
|--------|-------------|
| `on_hit_dealt(source, target, hit_data)` | Play `hit_{damage_type}.ogg` |
| `on_crit(source, target, hit_data)` | Play `crit.ogg` (on top of hit sound) |
| `on_kill(killer, victim)` | Play `kill.ogg` |
| `on_death(entity)` | Play `death_player.ogg` or `death_enemy.ogg` by entity faction |
| `on_block(source, target, hit_data, mitigated)` | Play `block.ogg` |
| `on_dodge(source, target, hit_data)` | Play `dodge.ogg` |
| `on_status_applied(source, target, status_id, stacks)` | Play status cue if `status_id` has a mapped SFX |
| `on_pickup(entity, pickup_type)` | Play `pickup_loot.ogg` |

**GameManager signals AudioManager listens to:**

| Signal | Audio response |
|--------|---------------|
| `run_started` | Crossfade to biome music track for current level |
| `phase_started(phase_number)` | Re-evaluate music (phase 5 may warrant a stinger) |
| `extraction_window_opened` | Play `extraction_warning.ogg` |
| `game_paused` | Bus volume duck (not stop) |
| `game_unpaused` | Restore bus volumes |
| `player_died` | Stop music; play `death_player.ogg` |
| `extraction_successful` | Play `extraction_success.ogg`; stop music |
| `final_boss_spawned(display_name)` | Layer boss stinger over current music (future) |

**ExtractionManager signals AudioManager listens to:**

| Signal | Audio response |
|--------|---------------|
| `extraction_channel_started` | Begin `extraction_channel_hum.ogg` loop |
| `extraction_interrupted` | Stop hum; play `extraction_interrupted.ogg` |
| `extraction_complete` | Stop hum; defer to GameManager.extraction_successful |

**Example wiring (one signal, complete):**

```gdscript
# AudioManager._ready()
EventBus.on_hit_dealt.connect(_on_hit_dealt)

func _on_hit_dealt(source, target, hit_data) -> void:
    var sfx_path := "res://assets/audio/sfx/combat/hit_%s.ogg" % hit_data.damage_type.to_lower()
    _play_sfx(sfx_path)

func _play_sfx(path: String) -> void:
    var player: AudioStreamPlayer = _get_free_sfx_player()
    if player == null:
        return  # pool exhausted — skip, don't crash
    var stream: AudioStream = _sfx_cache.get(path)
    if stream == null:
        return  # path not preloaded — log warning in debug mode only
    player.stream = stream
    player.play()
```

The damage type strings coming off `hit_data` are the engine's canonical set: `"Physical"`, `"Fire"`, `"Cryo"`, `"Shock"`, `"Void"`. `.to_lower()` maps them directly to file names.

---

## SFX Player Pool

Superseded by the "Runtime Architecture (as built)" section above: the shipped design splits SFX into a **10-player global pool** (`AudioStreamPlayer`) and a **16-player positional pool** (`AudioStreamPlayer2D`) so off-screen horde combat attenuates instead of stacking at full volume, plus 2 music players and 1 loop player — 29 nodes total, created in `_ready()`, never destroyed.

Pool acquisition is round-robin with fallback: prefer an idle slot; if the whole pool is busy, steal the next slot round-robin (lower-priority sounds are expendable during heavy combat). Music and loop players live outside the SFX pools and are never stolen.

---

## Per-Biome Music

The current biome is determined by the active level ID, which GameManager knows at `run_started`. `LevelData.LEVELS` needs a `"music_id"` key added to each level entry:

```gdscript
# data/factories/level_data.gd  — add to each LEVELS entry:
1: {
    "name": "The Cave",
    "music_id": "caves",       # ← new field
    "floor_path": "...",
    ...
}
```

AudioManager maps `music_id` → OGG path via a simple dictionary:

```gdscript
const MUSIC_TRACKS := {
    "hub":             "res://assets/audio/music/hub.ogg",
    "caves":           "res://assets/audio/music/caves.ogg",
    "catacombs":       "res://assets/audio/music/catacombs.ogg",
    "nightmare_realm": "res://assets/audio/music/nightmare_realm.ogg",
    "threshold":       "res://assets/audio/music/threshold.ogg",
    "inferno":         "res://assets/audio/music/inferno.ogg",
}
```

**Crossfade:** when switching tracks, fade out the current music player over 1.5 seconds while fading in the next one. A Tween handles the volume curve. If the same track is already playing (re-entering hub), do nothing.

**Ducking:** during the level-up screen and while `extraction_channel_started` is active, duck the Music bus to 40% volume via Tween. Restore on screen close / extraction resolution.

Phase 5 (warped enemies / instability peak) does not get a separate track — the existing biome music is sufficient. A boss stinger on `final_boss_spawned` is a future polish item.

---

## Volume Settings

When the settings menu ships, expose three sliders (0–100) and one mute toggle:

| Control | Maps to |
|---------|---------|
| Master volume | `AudioServer.set_bus_volume_db(0, linear_to_db(v))` |
| Music volume | `AudioServer.set_bus_volume_db(1, linear_to_db(v))` |
| SFX volume | `AudioServer.set_bus_volume_db(2, linear_to_db(v))` |
| Mute all | `AudioServer.set_bus_mute(0, true/false)` |

As shipped (task 09), volume settings live in the `Settings` autoload (`scripts/managers/settings.gd`, persisted to `user://settings.cfg`), not ProgressionManager. `Settings` applies bus volumes at startup and on slider change; AudioManager deliberately has no volume API — it only plays into the buses, so the sliders and mute affect everything with zero coupling.

Use `linear_to_db()` for conversion. Do not store dB values — sliders in linear space are more intuitive.

---

## Asset Sourcing

Audio is the only asset category not covered by the MiniFantasy packs (visual only). Sources confirmed in `docs/asset_inventory.md` sections 7–8:

**Music:**
- **juanjo_sound — Dark Dungeon Ambient Music** (41 tracks, itch.io / GameDev Market). Elder Scrolls-inspired dark ambient. 41 tracks covers the entire game several times over. Use for all five biomes + hub.
- **OpenGameArt.org CC0 Music** — supplement or fallback. CC0 = no attribution required.
- **Pixabay** — royalty-free dark/dungeon tracks as additional options.

**SFX:**
- **Kenney.nl audio packs** (CC0). Extensive combat, UI, and interface sounds.
- **OpenGameArt.org CC0 SFX libraries** — hit impacts, death sounds, ambience.
- **itch.io free SFX packs** — combat, UI, ambient.
- **Pixabay SFX library** — broad catalog, royalty-free.

**No SFX assets are committed yet.** The sourcing strategy names categories of free SFX, not specific files. Before committing audio assets: verify the license for each file (CC0 preferred; attribution-required CC licenses are acceptable but require a credits entry), and record the source URL in `docs/asset_inventory.md`.

**Synthesis/layering strategy for game-specific sounds:**
- Extraction portal hum: low drone + crystal chime layered from two CC0 SFX
- Instability rising: distorted bass rumble (pitch-shifted from a standard rumble SFX)
- Void-type hits: reversed/pitch-shifted standard impact sounds
- Channel hum (looping): must have a clean loop point — test in Godot before committing

**Target content for early biomes:**
- Caves music: dark dungeon ambient, sparse, tense. Pick a juanjo_sound track with minimal melody — it will loop for 15+ minutes.
- Catacombs music: heavier, slower pulse. Same source.
- Per-biome ambient SFX (dripping, wind, etc.) are lower priority than combat SFX.

---

## Implementation Order

Ship in this order so each step makes the game more playable:

1. **AudioManager skeleton** — autoload registration, bus wiring, SFX pool, preloader, volume API. No sounds yet; just the structure.
2. **Combat SFX core: hit, crit, kill, death** — the four sounds that make combat feel real. Any free CC0 hit/death sounds will do for now.
3. **Pickup chime** — one sound for `on_pickup`.
4. **UI clicks** — `ui_select.ogg` and `ui_confirm.ogg` for hub panel interactions.
5. **Hub music** — one looping ambient track. Proves the music system end-to-end.
6. **Per-biome music** — add one track per biome as each biome ships. Caves first.
7. **Extraction lifecycle SFX** — warning tone, channel hum (looping), success, interrupted.
8. **Status effect cues** — burning, chilled, shocked, void. Subtle; one short sound each.
9. **Ambient layers** — per-biome environment sound (dripping, wind). Lowest combat priority.
10. **Polish pass** — weapon-specific fire sounds, boss intro stingers, layered hit variants by damage type stack.

Steps 1–4 together = a fully audible feedback loop for the core combat experience. Steps 5–7 = biome immersion. Steps 8–10 = polish.

---

## Acceptance Criteria

Audio is release-ready when:

- [ ] All 5 biomes have a looping music track with clean loop points
- [ ] Hub has its own music track distinct from biome music
- [ ] Combat feedback loop is fully audible: hit (by damage type), crit, kill, enemy death, player death, pickup
- [ ] UI interactions have click feedback on all hub panel actions
- [ ] Extraction lifecycle is audible: warning tone, channel hum during channeling, success and interrupted variants
- [ ] Music crossfades cleanly between hub and arena (no abrupt cut)
- [ ] Music ducks correctly during level-up screen and extraction channeling
- [ ] Settings menu controls master, music, and SFX volume independently and values persist across sessions
- [ ] Mute toggle works at runtime
- [ ] No audio clipping, crackling, or abrupt cuts during normal play
- [ ] No AudioStreamPlayer nodes instantiated at runtime (all from pool)
- [ ] All audio assets have confirmed licenses recorded in `docs/asset_inventory.md`
