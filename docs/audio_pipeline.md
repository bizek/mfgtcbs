# Audio Pipeline

## Status

Pre-implementation spec. As of 2026-05-02, no audio assets have shipped — no `assets/audio/` directory exists, no AudioManager autoload is registered in `project.godot`, and no AudioStreamPlayer nodes appear in any scene. This doc is the agreed plan that audio implementation will follow.

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

AudioManager owns a fixed pool of AudioStreamPlayer nodes (not AudioStreamPlayer2D — the game is small enough that positional falloff is not needed for SFX; everything is audible). Pool size: **16 players** for combat SFX + **2 players** for music (current track, crossfade target) + **1 player** for extraction channel hum (looping). Total: 19 nodes, created in `_ready()`, never destroyed.

Pool acquisition is round-robin with fallback: try the next slot; if it's playing a non-music stream, steal it (lower-priority sounds are expendable during heavy combat). Music players are never stolen.

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

Store the three float values (0.0–1.0, not dB) in `ProgressionManager`'s settings save dictionary under keys `"vol_master"`, `"vol_music"`, `"vol_sfx"`. AudioManager applies saved values at startup. The settings menu spec will decide exact UI layout; AudioManager just exposes `set_master_volume(v: float)`, `set_music_volume(v: float)`, `set_sfx_volume(v: float)` as its public API.

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
