# Task 02: Biome music — The Catacombs and The Nightmare Realm

> **Tier:** 3 → Opus-class · **Depends on:** 01 committed; Ben's gate D-A (un-exclude audio)
> **Est. tokens:** ~3k in / ~7k out · Paste everything below the rule into a fresh session.

---

<role>
You are the audio director for a Minifantasy-styled pixel survivor/extraction game, working
entirely through the REAPER MCP bridge — you compose by placing MIDI, synthesis, and FX chains
programmatically, then render.
</role>

<objective>
Two of the game's three playable biomes run in total silence: `mus_catacombs` and
`mus_nightmare_realm` are wired in the sound table but `assets/audio/music/` contains only
`boss.ogg`, `caves.ogg`, `hub.ogg` (verified 2026-08-15). Produce `catacombs.ogg` and
`nightmare_realm.ogg` — loopable biome tracks that drop in with zero code change — and get them
on disk, imported, and heard in-engine.
</objective>

<context>
- Pipeline: `docs/audio_pipeline.md` and `docs/audio_asset_manifest.md`. REAPER runs with the
  file bridge (starts with REAPER — ask Ben to launch REAPER if the MCP times out). Render to
  `assets/audio/_incoming/`, audition, then move to `assets/audio/music/`.
- Reference mix: `caves.ogg` — match its loudness and its restraint. Music sits UNDER a dense
  combat SFX bed (combo pitch ladders, per-beat hits, status stingers); it must never compete.
- Biome identities, from their rosters and art:
  - **The Catacombs** (level 2): an ordered undead legion — skeleton ranks, zombie archers,
    crypt cavalry, a Skeleton Minotaur miniboss, a Zombie Giant boss. Disciplined dread.
    Processional, low, patient.
  - **The Nightmare Realm** (level 3): deliberately motley — "nothing here belongs together"
    (the wave-composition comment in `data/factories/level_data.gd`). Vermin, deep ones,
    psychics, spore turrets, an Angel of Death. Wrongness, not menace: detuned, unstable,
    beautiful in places.
- Run length is 15–30 minutes, so a ~1.5–2 minute seamless loop per track is the shape.
- `AudioManager` handles the music bus, volume settings, and crossfade; the sound-table entries
  already exist. Confirm the exact expected file paths in `data/factories/sound_table.gd` before
  rendering — the deliverable is drop-in.
</context>

<constraints>
- OGG Vorbis, loop-clean: the seam must be inaudible. Prefer composing the ending INTO the
  beginning (shared pad/drone across the loop point) over a naive hard cut. Verify the seam by
  listening across it (render, then play the tail+head).
- Loudness matched to `caves.ogg` (measure it via REAPER, don't guess).
- No borrowed motifs from `boss.ogg` — the boss cue must stay special.
- Do not edit any GDScript. If a path mismatch exists, fix the FILE NAME, not the code, unless
  the sound table is provably wrong — then flag it in the report instead.
</constraints>

<reasoning_guidance>
Before placing a note: pick each biome's two or three defining timbres and its tempo/pulse
strategy (the Catacombs wants a pulse; the Nightmare Realm may want to avoid one). Decide loop
architecture up front — intro-less AB or ABA forms loop better than through-composed. Great here
means: a player who mutes and unmutes mid-run can tell which biome they are in with their eyes
closed, and neither track fatigues across 20 minutes of hearing it.
</reasoning_guidance>

<output_format>
1. `assets/audio/music/catacombs.ogg` and `nightmare_realm.ogg` on disk with Godot imports
   generated (ask Ben to have Godot open, or trigger a reimport via the MCP).
2. In-engine verification: start a run in each biome (Training Room rule does not apply to
   listening checks, but prefer verifying via the level-select + immediate abandon rather than
   playing out a run; back up `progression.json` first regardless).
3. Session report: instrumentation and loop architecture per track, measured loudness vs
   `caves.ogg`, and the REAPER project files saved under the pipeline's project folder for
   Ben's later feel pass.
4. Update `docs/audio_asset_manifest.md` and the 00_EXECUTION_PLAN status table.
</output_format>

<success_criteria>
Both files exist, loop without an audible seam, sit under combat SFX at matched loudness, are
distinguishable from each other blind, and required zero code edits. Ben can open the REAPER
projects and turn knobs without reverse-engineering anything.
</success_criteria>
