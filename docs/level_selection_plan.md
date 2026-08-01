# Level Transition → Level Selection — plan

**Status:** design proposal, nothing implemented. Written 2026-08-01 from Ben's note
"Level transition - Level selection". Needs one decision from Ben (§3) before code starts.

## 1. What exists today

A run is **one biome, start to finish**. `GameManager.current_level` (1–5) is set in the hub before
`start_run()` and never changes during the run. `MainArena` reads it once to pick the floor art, the
wave table, the music and the two bosses (`LevelData.LEVELS`), then `BlockManager.build_descent()`
stacks N cave blocks vertically and the whole descent happens inside that one biome.

The only "transition" in the game is `LdtkExitZone` → the portal at the bottom of the stack, plus
the extraction zones. There is no mid-run choice of destination and no post-run choice either: you
extract, you land in the hub, you pick a biome from the hub and go again.

Relevant seams, in the order a change would touch them:

| Seam | File | Note |
|---|---|---|
| `current_level` | `game_manager.gd:55`, set in `start_run()` | the single source of "which biome" |
| biome content | `data/factories/level_data.gd` `LEVELS` | **only level 1 is populated**; 2–5 are stubs with empty `wave_composition` and `scene_map` |
| `is_configured(level_id)` | `level_data.gd:126` | already the right gate for "is this biome playable" |
| descent build | `main_arena.gd:420` → `BlockManager.build_descent()` | takes a block count + block level ids |
| block sequence | `block_manager.gd:196` `_build_block_sequence()` | already picks a *sequence* of blocks — the natural place for branching |
| exit | `ldtk_exit_zone.gd` | has `setup()` / `unlock()`; currently one exit per descent |

## 2. The blocker nobody can design around

**Four of the five biomes are empty.** Levels 2–5 have a name and a music id and nothing else — no
wave composition, no scene map, no floor for three of them. Any "choose your next level" UI built
today would offer one real option and four that spawn nothing.

So level selection is not really a UI task. It is:

1. content work to make a second biome exist, then
2. a small amount of plumbing.

The plumbing below is genuinely small. The content is the project. Sequencing matters: build the
selector against **two** real biomes, not one, or it can't be tested.

## 3. The decision Ben needs to make

These are three different games. Pick one and the implementation falls out.

### Option A — Choose the next biome when you extract (recommended)
Extraction succeeds → instead of dropping straight to the hub, show a small map of the biomes you
have unlocked and let the player either **bank the run** (go to hub, keep loot) or **push on** into
the chosen biome carrying current loot and instability at increased risk.

- **Why this one:** it is the only option that adds a *decision* rather than a menu. It makes the
  extraction choice interesting ("I have good loot, do I press?"), it reuses the existing
  extraction-success screen as the host, and it needs no changes to the descent generator at all —
  each biome is still one self-contained descent.
- Cost: a new panel on the success screen, a "continue run" path in `GameManager` that resets the
  phase clock and rebuilds `MainArena` with a new `current_level` without settling loot, and a rule
  for how instability/difficulty carries across.
- Risk: run length becomes unbounded. Needs a cap (e.g. instability keeps rising, or a hard 3-biome
  chain).

### Option B — Choose a branch mid-descent
The block stack forks: at certain depths the player picks left/right, each leading to a different
block set (a "safe" branch and a "rich" branch).

- **Why:** deepens the existing descent rather than adding a layer above it. `_build_block_sequence`
  already assembles the stack, so this is the most natural fit to the code.
- Cost: highest. Blocks would need entry/exit sockets that line up horizontally, `BlockManager`
  becomes a graph builder instead of a stacker, and the flow field / camera assume a single vertical
  column today.
- Verdict: real, but this is a rewrite of the descent generator. Not a next step.

### Option C — Just a hub biome picker
Formalize what already happens implicitly: a proper level-select screen in the hub with unlock
state, recommended power, and biome preview.

- **Why:** cheapest by far, and it is the thing that is actually missing from a *shipping* build —
  right now biome choice is invisible.
- Cost: one hub panel reading `LevelData.is_configured` + a ProgressionManager unlock flag.
- Verdict: worth doing **regardless of which of A/B you pick**, because A and B both need the
  player to understand what a biome is before they can choose between them.

**Recommendation: do C now (it is small and unblocks nothing else), design toward A, and treat B as
a post-launch idea.** But C is only worth building once a second biome exists — see §2.

## 4. If A is chosen — implementation sketch

1. `LevelData`: fill in biome 2 (`The Catacombs`) — wave composition, scene map, floor path. This is
   the bulk of the work and is content, not code.
2. `ProgressionManager`: add `unlocked_biomes: Array[int]`, defaulting to `[1]`, saved/loaded
   alongside the other stats (mirror the `abandons` field added 2026-08-01 for the shape of it).
3. `GameManager`: add `continue_run(next_level: int)` — the mirror of `on_extraction_complete()`
   that does **not** clear `loot_carried`, does **not** call `record_extraction`, bumps a new
   `biomes_this_run` counter, sets `current_level`, and re-enters `MainArena`.
4. `ExtractionSuccessScreen`: two buttons — "Extract (bank N gold)" and "Descend deeper →", the
   latter opening the biome picker. Reuse `UINav` focus handling like `pause_menu.gd`.
5. Difficulty carry: `get_effective_phase()` already abstracts depth-vs-clock. Simplest honest rule
   is that a chained biome starts at the phase the previous one ended on, so pushing on is
   immediately harder.
6. Loss rule: dying or abandoning in a chained biome loses **everything** accumulated across the
   chain, using the existing `run_failed` path — no new settlement logic needed.

## 5. What is already in place and does not need rebuilding

- `run_failed(abandoned)` (added 2026-08-01) is the single teardown signal for any run that ends
  without extracting, so a chained run only needs to emit it once at the end of the chain.
- `LevelData.is_configured()` is exactly the "can this be offered" predicate.
- `AudioManager` already swaps music off `LevelData.get_music_id(current_level)`, so a biome change
  mid-run gets its music for free.
- `EnemySpawnManager.configure_level()` is already called per-level rather than per-run.
