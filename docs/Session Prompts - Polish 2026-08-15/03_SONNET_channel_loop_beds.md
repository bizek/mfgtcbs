# Task 03: The three channel-loop beds

> **Tier:** 2 → Sonnet-class · **Depends on:** 01 committed; Ben's gate D-A (un-exclude audio)
> **Not parallel with Task 04** (both touch `sound_table.gd` if entries need tweaks).
> **Est. tokens:** ~1.2k in / ~2k out · Paste everything below the rule into a fresh session.

---

<goal>
Every held channel in the game (Immolate, Dictum, Dome, the barrages) runs silent for its whole
duration. The code side has been built and verified since 2026-08-02 — `AudioManager.play_channel_loop`
is called from `player.gd:1691`, keyed by `SoundTable.CHANNEL_LOOP_BY_KIT` — but the three loop
files have never been rendered. Produce them; they light up with zero code change.
</goal>

<context>
- The exact deliverables, recorded in `polish_plan_2026-08-01.md` §"What is left" and re-verified
  missing on 2026-08-15:

```
assets/audio/sfx/combat/channel_loop_fire.ogg      low roaring bed      (Immolate, Hellfire)
assets/audio/sfx/combat/channel_loop_arcane.ogg    dry rattle/whisper   (Bone / Bramble Barrage)
assets/audio/sfx/combat/channel_loop_martial.ogg   low physical rumble  (Taunt, Dictum, dome)
```

- Seamless ~2s loops, mixed QUIET — they sit under the per-beat channel hits, not beside them.
  `play_channel_loop` reads volume and pitch from the SoundTable entry, so final level can be
  trimmed in data.
- Pipeline: REAPER MCP bridge (ask Ben to launch REAPER if it times out), render to
  `assets/audio/_incoming/`, then move into place. The dash stingers in `assets/audio/sfx/dash/`
  were synthesized in-house the same way — use them as the quality bar.
- Check `data/factories/sound_table.gd` for the exact ids/paths the three entries expect before
  rendering. The Wizard has no bed BY DESIGN (charge-release, not a hold) — do not add one.
</context>

<requirements>
- Loop seam inaudible at 2s period — verify by listening across the seam, not by waveform eyeball.
- Distinct at a glance: fire=roar, arcane=dry rattle/whisper, martial=physical rumble. No shared
  source sample across the three.
- In-engine verification in the **Training Room only** (F11 panel, HIT BACK OFF): hold a channel
  from a kit mapped to each bed and confirm start-on-press, loop-under-hits, stop-on-release.
  Back up `progression.json` before entering the engine; restore after.
- Zero GDScript edits expected. If a SoundTable entry's volume needs trimming, that one-line data
  change is in scope; anything more is a finding, not a fix.
</requirements>

<output_format>
Three .ogg files in place with imports, a short report (per-bed synthesis recipe, in-engine
verification result per kit tested), REAPER project saved per the pipeline docs, and the
00_EXECUTION_PLAN status table updated.
</output_format>
