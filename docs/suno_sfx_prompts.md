# Suno Sounds — SFX prompt sheet

Replacing the REAPER-synthesized SFX (Ben, 2026-10-09: "basic and not very good") with
Suno **Sounds** (Create → Sounds, Pro plan). Each generation costs 2 credits and returns
**two takes**, so a pair can fill a 2-stream variation slot in `sound_table.gd`.

## How the loop works

1. **Generate**: paste the prompt, set **Type** and **BPM**, then click Create. Ben does this in suno.com,
   or Claude drives it through Claude in Chrome.
2. **Pick**: Ben listens to both takes and keeps the best (Claude can't hear). If neither
   fits, note *what* is wrong ("too musical", "too long", "too bright") and Claude rewrites
   the prompt.
3. **Download WAV** into `assets/audio/_incoming/suno/` with the **target filename** below
   (for example `combo_drop.wav`, or `hit_fire_0.wav` and `hit_fire_1.wav` for a pair).
4. **Claude installs**: trim the lead-in silence, fade the tail, normalize to -1 dBFS, convert to OGG,
   run a seam check on loops, move the file to its `sfx/` dir, update its `sound_table.gd` entry, and record
   the source in `docs/asset_inventory.md` (Suno Pro, date, prompt).

**Prompt rules** (from Suno's help article, plus what in-game SFX need):
- Short and concrete. Use sound words like *whoosh, crackle, thump, zap, shimmer, rumble*.
- Always state the **length** ("0.5 seconds"). Sounds has no duration control.
- Add **"no music"** to every prompt, and add **"no melody, no drums"** to loops. Loops tend to turn into
  musical arrangements.
- Ask for **"close, dry"** sound. The game adds positional falloff, and baked-in reverb muddies a horde.
- Loops: set **BPM 120**, because one 4/4 bar at 120 BPM is exactly 2 s, which matches the current 2 s beds.

---

## Batch 1: the `ears` quest sounds (start here)

| Target file | Type | Prompt | Keep it if… |
|---|---|---|---|
| `combat/combo_drop` | One Shot | `soft breathy exhale whoosh, gentle downward pitch fall, airy and calm, close and dry, 0.6 seconds, no impact, no music` | It feels like a sigh, not a buzzer. It has no click at the start and plays quietly at -14 dB. |
| `combat/channel_loop_fire` | Loop · 120 | `steady low roaring fire, furnace whoosh with soft crackle, constant intensity, seamless 2 second loop, no music, no melody, no drums` | The level stays flat with no swells or pops. Hits have to cut through it at -18 dB. |
| `combat/channel_loop_arcane` | Loop · 120 | `dry rattling bones and dark whispering hiss over a faint eerie hum, steady texture, seamless 2 second loop, no music, no melody, no drums` | It reads as necromancy or arcane, it has no voices that sound like words, and it is steady. |
| `combat/channel_loop_martial` | Loop · 120 | `low steady ground rumble with faint chainmail and armor shuffle, tense and physical, seamless 2 second loop, no music, no melody, no drums` | It sounds heavy and grounded, with no war-drum hits (beats come from the hits). |

## Batch 2: the other in-house REAPER renders

| Target file | Type | Prompt |
|---|---|---|
| `dash/dash_generic` | One Shot | `quick cloth whoosh, fast body moving past through air, close and dry, 0.3 seconds, no music` |
| `dash/dash_teleport` | One Shot | `magical blink teleport, short rising zip with a sparkling shimmer tail, 0.4 seconds, no music` |
| `dash/dash_deadly` | One Shot | `fast blade whoosh with a thin metallic ring, sword slicing air, close and dry, 0.3 seconds, no music` |
| `dash/dash_dodge_roll` | One Shot | `body roll on a dirt floor, cloth and leather tumble with two soft thuds, close and dry, 0.4 seconds, no music` |
| `skills/skill_buff` | One Shot | `magical power up, warm rising shimmer swell, short and bright, 0.7 seconds, no music` |
| `skills/skill_offensive` | One Shot | `dark spell cast, punchy energy burst with a short whoosh, 0.5 seconds, no music` |
| `skills/skill_movement` | One Shot | `quick magical swoosh, light gust of wind, 0.4 seconds, no music` |
| `skills/summon_arrive` | One Shot | `dark summoning, deep magical thump with a ghostly rising whoosh, creature materializing, 1 second, no music` |

## Batch 3: gaps with no asset yet (status cues)

| Target file | Type | Prompt |
|---|---|---|
| `status/burn_apply` | One Shot | `flame igniting, quick fire whoosh catching with a short crackle, 0.4 seconds, no music` |
| `status/chill_apply` | One Shot | `frost spreading, crisp crystalline ice crackle, 0.4 seconds, no music` |
| `status/frozen` | One Shot | `ice freezing solid, sharp ice crack with a glassy clink, 0.6 seconds, no music` |
| `status/shocked_apply` | One Shot | `electric zap, short crackling spark burst, 0.3 seconds, no music` |
| `status/void_apply` | One Shot | `dark void suction, reversed whoosh with an eerie low warble, 0.5 seconds, no music` |
| `combat/status_buff_apply` *(new file, replaces pitched block.ogg)* | One Shot | `magical ward snapping on, bright shield shimmer, 0.4 seconds, no music` |

Later candidates are the Kenney CC0 sounds (hits, crit, kill, pickups, UI, extraction). Ben should say which of
those also feel weak before any credits go to them.
