# Task 13 — SFX/music asset manifest
**Tier**: 1 → Haiku | **Depends on**: none (M4 entry point; output is Ben's shopping list)

---

Produce an audio asset manifest for this Godot survivors game by enumerating every sound-worthy event.

Sources to scan: `scripts/systems/event_bus` signals (find the EventBus autoload script via project.godot), `docs/mechanical_vocabulary.md` (weapon behaviors, status effects), `docs/audio_pipeline.md` if it lists prior decisions, and the weapon list in `data/weapons.gd`.

Categories to cover: weapon fire (per behavior family, not per weapon), **combo kits (per swing family, not per class — light swing, heavy finisher, channel loop, ranged combo shot; scan ChainFactory in `data/factories/chain_factory.gd` for the phase vocabulary across all 10 kits)**, **Q/E class skills + RMB specials (per skill family: shout/cry, summon, thrown, ground slam, song, smoke/stealth)**, **dash (generic whoosh + the class-flavored variants: teleport blink, deadly dash strike — see `dash_style` in data/characters.gd)**, **pets (FireFamiliar/BloodElemental: summon, attack, expire)**, impacts/hits, enemy deaths (normal/elite/boss), player damage + death, pickups (XP, currency, weapon, mod, keystone), level-up, extraction channel start/loop/complete, merchant/altar interaction, UI (click, hover, panel open/close, purchase, error), boss (intro, phase transition, signature attacks), ambient/music (hub loop, Caves loop, boss track).

Output format: write `docs/audio_asset_manifest.md` — a markdown table with columns: ID (snake_case, e.g. `sfx_pickup_xp`), Category, Trigger (signal or code site), Priority (P1 ship-blocking / P2 polish), Notes (e.g. "needs 2–3 variations", "loopable"). End with a count summary per priority and a note to check Minifantasy SFX packs first for style cohesion. No additional commentary.
