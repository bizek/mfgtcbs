# Task 15 — Full SFX/music wiring pass
**Tier**: 2 → Sonnet | **Depends on**: 14 (audio system built) + audio assets on disk (Ben's sourcing pass)

---

<goal>
Wire every P1 entry in `docs/audio_asset_manifest.md` to its real asset file through the AudioManager sound table, plus all three music tracks. P2 entries: wire whatever assets exist, leave the rest documented as open.
</goal>

<context>
- Architecture + "how to add a sound" recipe: `docs/audio_pipeline.md` (written by task 14). Follow it exactly — this task should be almost entirely sound-table data entries plus a few new EventBus subscriptions for events task 14 didn't cover.
- Assets: `assets/audio/sfx/` and `assets/audio/music/`. Normalize obviously-mismatched volumes via the table's per-sound volume field, not by editing files.
- Manifest: `docs/audio_asset_manifest.md` — work through it top to bottom, checking off entries.
</context>

<requirements>
- Every P1 manifest entry: asset assigned, trigger verified in-game (debug run), volume sane relative to neighbors.
- Multi-variation sounds (hits, deaths) rotate variants per the table's design.
- Music: hub loop on hub load, Caves loop on run start, boss track on boss spawn, crossfades clean, loops seamless (check loop points — flag any file that pops at the seam for Ben to re-export).
- UI sounds on hub panels, level-up screen, merchant, pause menu.
- Full descent playthrough with audio: no spam, no silence where the manifest expects sound, no errors. Then mute SFX bus and confirm music-only works (slider regression check).
- Update the manifest: mark wired entries, list any missing assets as a TODO block for Ben.
</requirements>

<output_format>
Sound-table data + minor wiring code + updated manifest, grouped conventional commits. Summary: counts wired (P1/P2), list of missing assets.
</output_format>
