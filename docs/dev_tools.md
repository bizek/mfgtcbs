# Dev Tools — Animation Lab & Training Room

Both are debug-mode only (`GameManager.debug_mode`). Neither ships enabled, but the
Animation Lab's *output* does: `data/anim_overrides.json` is read by exported builds.

---

## Training Room

**Main menu → TRAINING ROOM.** A flat arena with no clock, no waves, no extraction. Built so
ability work doesn't need a full run — and because Reckoning literally could not be tested in
a real run (its own tick damage killed everything before the dome could soak a hit).

Panel controls (F11 hides the panel):

| Control | What it does |
|---|---|
| **CLASS ◀ ▶** | Swap character live. Reloads the room — sprite, kit, weapon, passives, dash style all rebuild clean. |
| **DUMMIES** | Respawn the stationary row. They never die (HP is pinned every frame) and deal no damage. |
| **HIT BACK** | Dummies deal contact damage. **Required** for testing Guard, Reckoning, or anything that reacts to being hit. |
| **PACK** | Spawn 8 live fodder that actually chase — pathing, knockback, AoE, charm tests. |
| **CLEAR** | Remove every enemy. |
| **SLOW-MO** | 0.25× time. Pair with the Animation Lab to read hit frames as they land. |
| **HEAL** | Top the player back up. |
| Readout | Damage total, DPS over the trailing 5s, and best single hit. RESET METER zeroes it. |

F10 (Animation Lab) and F1 (debug panel) work in here too.

---

## Animation Lab (F10)

Edits how the current character's animations are **sliced and timed**, without touching code.
Everything is authored per character + per animation and saved to `data/anim_overrides.json`.

### Which animation belongs to which button?

This is the thing to understand first. Every combo step, skill and channel is a **phase** that
plays one **named animation** — `attack`, `attack_2`, `bash`, `dome`, `rally`, and so on. The
Lab edits those names, so you need to know which press plays which name.

The panel answers that both directions:

- **pick by input** — a dropdown of every press/hold in the current character's kit, reading
  like `LMB chain step 2 (tap LMB) [finisher] ▸ bash`. Choose the press you care about and it
  jumps to the animation that press plays.
- **the blue line under the animation dropdown** — for whatever animation is selected, it
  lists every input that plays it, e.g.
  `plays on: LMB chain step 2 (tap LMB) [finisher] · RMB tap start (tap RMB)`.

The list is built from the character's **live** kit, so class mods and upgrades are reflected.
Note that one animation is often shared by several inputs (Shield Bash is both the light
chain's finisher and the heavy chain's opener) — editing it changes **all** of them. If you
want them to differ, they need separate sheet entries, which is a code change; ask and I'll
split it.

`[HOLD BODY: stages apply]` in that line is the signal that intro/loop/outro staging is
meaningful for that animation. For everything else, stages are ignored.

### So: choosing which part plays per press

- **For a tap** (a combo step, Q, E) — the animation plays start to finish, so use
  **From / To** to choose which slice of the sheet that press plays, and **Hit** for when it
  connects.
- **For a hold** (RMB channel) — that's what stages are for: **INTRO** plays on the press,
  **LOOP** repeats for as long as you hold, **OUTRO** plays on release.

### The basic pass (trim / retime / re-pin)

1. Pick an animation — via **pick by input**, or directly from the animation dropdown.
2. **From / To** — which columns of the sheet actually play (inclusive, 0-based).
   Use it to cut flabby wind-ups or dead tail frames.
3. **FPS** — playback speed.
4. **Hit** — which frame of the trimmed animation fires the damage/effect.
   `-1` keeps whatever the kit code authored.
5. **REPLAY** previews without saving. **APPLY+SAVE** writes the file and rebuilds the live
   player immediately — the next swing uses it. **CLEAR** removes the override.

### Lining up the hit frame

The strip under the preview is one cell per frame: **gold** = the hit frame, **white outline**
= the frame playing right now. The preview backdrop flashes amber on the impact frame, so the
timing reads in motion rather than only when paused.

- **Click any cell** to pin the hit frame there.
- **`||`** pauses; **◀ ▶** step one frame at a time (stepping auto-pauses).
- **SET HIT = FRAME** pins the hit to whatever frame is currently displayed — scrub to the
  moment the weapon actually connects, click it, done.

Nothing is written until APPLY+SAVE.

### Per-direction editing

The direction dropdown switches between **ALL DIRS** (edits the animation as a whole) and one
specific facing. With a facing selected, tick **edit** and that row gets its own:

| Field | Use |
|---|---|
| From / To | different trim for this facing |
| FPS | different speed for this facing |
| **Row** | which sheet row this facing reads — fixes packs whose rows aren't in the standard order |
| **Hit** | different impact frame for this facing |

The preview shows the selected facing's actual row, so a mismatched row is visible immediately.
Only fields that differ from the animation-level values get written, so a per-direction entry
stays minimal. Per-direction hit frames are resolved at swing time against the facing that's
actually playing.

Stages are edited at the ALL DIRS level (the stage controls disable when a specific facing is
selected).

### Staging (the important part — for held abilities)

A channel used to replay its *whole* sheet every tick, which is why Fire Torrent read as
"struggling to start a fire" and Guard looked like raising and lowering the sword on repeat.
Staging fixes that structurally:

- **INTRO** — plays once when the channel starts (the wind-up).
- **LOOP** — the only part that repeats while the button is held.
- **OUTRO** — plays once on release.

To author it: pick a stage from the stage dropdown, tick **on**, set From/To for that segment,
repeat for the others, then APPLY+SAVE. **SEQUENCE** in the same dropdown previews intro → loop
→ outro back to back so cut points can be judged in one pass.

Any held ability picks this up automatically — no code change per ability. A body with no
authored stages keeps the old behavior (plays once, freezes on the last frame).

Damage timing note: staged channels tick on their ability's own cadence (e.g. Torrent every
0.67s), *not* on `hit_frame`, because a looping segment's frame numbers don't line up with the
kit's authored hit index.

### Importing PNGs the game isn't using yet

The Minifantasy packs ship far more than the anim tables in `characters.gd` reference. The
Warden's Dictums folder, for example, contains a complete `Dome_Of_Rightfulness/` set —
`DomeStart / DomeCycle / DomeEnd` plus matching `DomeBase*` layers — while the game was only
using the single flat `DomeDictumEffect.png`.

At the bottom of the Lab:

1. **SCAN PACK** — walks the current character's asset folder (skipping `GIFs/` and
   `Shadows/`) and lists every PNG.
2. Pick one. The line underneath shows the name it will get and the sheet's dimensions in
   frames, e.g. `-> 'dome_cycle'  8 cols x 1 rows`.
3. **IMPORT AS ANIM** registers it. From then on it behaves exactly like a table animation —
   selectable, trimmable, stageable, and usable as a stage's source.

Imported entries live under `_custom_anims` in the overrides file, so no code edit is needed.

### Layered stages (body + fx + base)

Each stage can drive three layers at once:

| Layer | Where it draws | Set by |
|---|---|---|
| **body** | the character itself | `From/To`, or the **plays** dropdown for a whole other animation |
| **fx** | above the character | the **+ fx** dropdown |
| **base** | *below* the character | `"base"` in the JSON |

The `base` layer exists because the packs say so — `_AnimationInfo.txt` in the Dictums folder
reads: *"'Base' layers Should be placed below the character."* The player now renders those on
their own sprite at `z_index -1`.

This is what makes your dome example work: the body holds the Warden's cast pose while the
effect layers swap from `DomeStart` to a looping `DomeCycle` and finally `DomeEnd`.

### Cross-sheet stages

Some packs split a held ability across two sheets — the Ravager's Guard raises on
`BlockGuardUp` and lowers on `BlockGuardDown`. Hand-edit those in the JSON:

```json
"guard": {
  "stages": {
    "intro": [0, 2],
    "loop":  [3, 3],
    "outro": { "sheet": "res://…/BlockGuardDown.png", "from": 0, "to": 3 }
  }
}
```

The Lab shows those bounds and **preserves them verbatim** on save as long as you don't edit
that stage's spinboxes, so saving from the panel won't clobber a hand-authored entry.

### Full override shape

```json
"bash": {
  "from": 0, "to": 7, "fps": 18.0, "hit_frame": 3,
  "stages": { "intro": [0, 2], "loop": [3, 5], "outro": [6, 7] },
  "dirs": {
    "down_left": { "row": 1, "hit_frame": 4 },
    "up_right":  { "from": 1, "to": 7 }
  }
}
```

Every field is optional. Facings are `down_right`, `down_left`, `up_right`, `up_left`.

### Pack audit (2026-07-20)

Every character's pack was cross-referenced against all sheet paths used anywhere in code
(matching on filename, since runtime paths are built as `DIR_CONST + "file.png"`). Shadows,
Jump and Idle_Special sheets were excluded — shadows are a separate render pass, the others
have no gameplay hook.

**Seeded and wired:**

| Character | Sheets | Wired as |
|---|---|---|
| Warden | Dome + Blades `Start/Cycle/End`, `DomeBase*` | dome/dictum stage fx + base layers |
| Herald | `BalladSongBase`, `EnhancementSongBase`, `Enhamcement` | song base layers (+ spare shimmer) |
| Ravager | `BattleCryEffectBackLayer` | `cry` base layer |
| Devout | `HealingwodsFrontLayer` / `BackLayer` | `pray_heal` fx + base |
| Spark | `Explossion_Full_Effect`, `Deflagration_Only_Effect` | registered (64px cells) — unassigned |
| Verdant | Beast/Hound/Owl `Idle`, `Walk`, `Dmg`, morph + revert | registered — unassigned |

**Deliberately not seeded** — `*_Orthogonal.png` sheets (Ranger, Warden, Spark, Herald, Cursed,
Deadeye, Devout). These are the N/E/S/W cardinal versions of sheets already in use in their
Diagonal form. The facing system uses four *diagonal* quadrant rows, so these are duplicates
until someone does a true 8-way facing pass; registering them now would only clutter the
dropdown. Same for `ThunderBladeProjectiles.png` (a combined sheet whose per-frame files are
already wired) and `DomeBaseDictumEffect.png` (base layer for the flat dome effect the staged
version replaces).

### Seeded examples

`data/anim_overrides.json` ships with starting points to retune:

- **The Spark / torrent** — intro 0-3, loop 4-15, outro 16-19 (single sheet)
- **The Ravager / guard** — intro 0-2, loop 3-3, cross-sheet outro from `BlockGuardDown`
- **The Warden / dome** — the full worked example: body columns 0-7 / 8-11 / 12-14 with
  `DomeStart → DomeCycle → DomeEnd` on the fx layer and `DomeBaseStart → DomeBaseCycle →
  DomeBaseEnd` underneath
- **The Warden / dictum** — same shape using `BladesStart → BladesCycle → BladesEnd`

Verified in-engine: the Warden build produces `dome_intro/loop/outro` (8/4/3 frames) plus
`_fx` and `_base` variants (8/8/8), with looping set only on the cycle segments.

---

## Gotcha: `validate_script` via Godot MCP

It reports a false `Parse error — hides a global script class` for **any** file declaring
`class_name` (it compiles the file standalone, so the name collides with its own registered
global). Verified against untouched files. Trust it only for scripts without `class_name`;
otherwise check `get_editor_errors`.
