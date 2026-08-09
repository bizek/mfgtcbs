# Polish Plan — 2026-08-08

Successor to `polish_plan_2026-08-01.md`, which is now almost entirely done (its Tier 0, Tier 1.1,
Tier 2.1 and Tier 2.2 all shipped, plus a body of extraction work that grew out of it). Same rules
as that document: **every line below carries the check that proves it**, tiers rise in cost and fall
in certainty, and nothing here has been changed yet.

**Audio is deliberately excluded** (Ben, 2026-08-08). The outstanding audio work is real and is
recorded in §"Excluded" at the bottom so it is not lost, but nothing in Tiers 0–3 depends on it.

> **The headline finding is Tier 3.** Two existing planning docs — this plan's predecessor §3.1 and
> `level_selection_plan.md` §2 — both assert that a second biome is a from-scratch content project.
> **That is out of date.** 21 finished descent blocks for two other biomes are compiled and sitting
> on disk, in the same LDtk project, with their tilesets already registered, and no code path can
> reach any of them. See §3.1.

---

## Step 0 — commit the working tree first

`git status` shows **21 modified files and 2 staged deletions**: the whole mod + level-up rework
(`mod_levelup_rework_plan.md` step 5), including the deletion of `data/mods.gd` and
`data/factories/mod_combo_factory.gd`, a save-format bump to v2, and the class-lock enforcement.
`docs/mod_levelup_rework_plan.md` §6 records it as complete and statically verified.

Nothing else in this plan should start on top of an uncommitted 1500-line/1751-line diff. Commit it
before touching anything below.

---

## Tier 0 — Confirmed defects (cheap, no design decisions)

### 0.1 The main menu's CREDITS button can never work

`scripts/main_menu.gd:269` looks for `res://scenes/credits.tscn`. The file is at
`res://scenes/ui/credits.tscn` — `scripts/ui/win_screen.gd:47` uses the correct path, so the credits
roll itself works when you win.

```gdscript
# main_menu.gd:269
if ResourceLoader.exists("res://scenes/credits.tscn"):
```

The `ResourceLoader.exists` guard is exactly why nobody noticed: instead of erroring it falls to
`_show_toast("Credits — coming soon")`, so the button has silently claimed to be unimplemented for
as long as it has existed. RTR task 04 is recorded as done and the credits scene *is* done.

**Fix:** one path. Then delete the `exists` guard — it now only hides the next typo.

### 0.2 Two player-facing font sites are still off the pixel grid

Both were found on 2026-08-07 and recorded in CLAUDE.md; neither has been fixed.

| Site | Value | Why it was missed originally |
|---|---|---|
| `scripts/ui/glyph_bar.gd:45` | `normal_font_size` 14 | `normal_font_size`, not `font_size` |
| `scripts/pickups/keystone_pickup.gd:62` | `ls.font_size = 14` | a `LabelSettings` property, not a theme override |

At 14, m5x7 glyphs fuse rather than soften — this is the illegibility case, not a crispness nit. The
panel hint bar and the keystone pickup label are both player-facing.

**Fix:** 14 → 16 on both, then re-check layout. This is the whole reason it was deferred: the hint
bar is width-constrained and the pickup label floats over a world object.

### 0.3 `scenes/flamggy/` is a foreign mini-project committed into the repo, and it ships

10 tracked files, 158 KB, including **its own `project.godot`**, a `flame_mascot.glb`, and four
`.gdshader` files. Every internal `res://` reference in it resolves against the wrong root and is
broken (`res://flame_toon.gdshader`, `res://body_material.tres`, …). A repo-wide grep for
`flamggy|flame_mascot|flame_test` outside that folder returns nothing.

Both export presets carry `exclude_filter="*/backups/*"` only, so it is packed into the Windows and
Linux builds.

**Fix:** delete it, or move it out of the project tree. If it is wanted, it needs its own repo — a
nested `project.godot` inside a Godot project is a hazard on its own.

### 0.4 Repo hygiene

`git worktree list` shows three detached `.claude/worktrees/` checkouts (`cool-maxwell-4071da`,
`crazy-gould-e4450f`, `mystifying-franklin-ae1506`), and `git branch` shows ten stale branches
(six `claude/*`, four `feat*/`). Every grep in this repo now has to be filtered with
`grep -v worktrees` because the worktrees contain full copies of the source.

**Fix:** `git worktree remove` the three, delete merged branches. Mechanical.

---

## Tier 1 — Highest visible return, no design decisions needed

### 1.1 The HUD is the last surface still on the Classic sheet

`scripts/ui/hud.gd:10` loads `_Classic_UI.png`. `assets/ui/grim_theme.tres` — wired as
`project.godot [gui] theme/custom` and reaching every Control in the game — is built from
`_Grim_UI.png` (`tools/build_ui_theme.gd:37`).

The gap-3 theme pass did not cause this; it made it visible. Every menu, panel, button, tab, slider
and focus ring in the game now comes from Grim, and the one surface a player stares at for an
entire run comes from a different art set. `hud.gd` is written for exactly this swap — its header
says *"To retheme, only these rects + `UI_SHEET_PATH` change."*

**Do:** re-derive the 8 rects against the Grim sheet's bar and panel groups (`ui_pack_inventory.md`
§Grim has the band coordinates), swap the path, verify on screen. The bar fills are the fiddly part
— Grim's capsule column stride differs from Classic's 256.

**Verify before committing.** I can read which sheet each file loads, but not what the two look like
side by side; open Godot and compare before spending the work.

### 1.2 Every scene transition is a hard cut

Nine `change_scene_to_file` calls (`main_menu` ×4, `hub_launch_panel`, `credits`,
`extraction_success_screen`, `game_over_screen`, `win_screen`) and **no fade anywhere** — a grep for
a fade/transition helper across `scripts/ui/` and `scripts/managers/` returns nothing.

The two that matter most are the ones a player crosses every single run: hub → descent, and results
→ hub. A hard cut is the single loudest "this is a prototype" tell left in the game, and the fix is
a ~40-line autoload (`fade out → change_scene → fade in`) plus nine call-site swaps.

### 1.3 Damage numbers are the only vector-font text in the game

`scripts/ui/combat_feedback_manager.gd` draws at `FONT_SIZE = 7` via `draw_string` and never assigns
`font`, so it falls through to `ThemeDB.fallback_font`. Because that is a vector font it does not
fuse at 7px — so this is a *style* inconsistency, not the crispness bug, and it was consciously left
alone in the 2026-08-03 font pass pending a look decision.

It is now the last one. Everything else in the game is m5x7 at 16 or 32.

**Needs a look decision, not a size change:** either a bitmap digit set (best — damage numbers want
their own weight anyway) or m3x6. Forcing m5x7 @ 16 would nearly double every number over the play
field and is not the answer.

### 1.4 Cursor states — the small remainder of UI gap 2

Most of gap 2 is done and the inventory's open-gap line for it is stale. `GameCursor` already ships
the reticle, the pointer, and hostile tinting — `player.gd:1714` calls `set_hostile`, `hub.gd:99`
and `main_menu.gd:50` call `use_pointer`, `main_arena.gd:122` calls `use_aim`.

What is left is genuinely small: `ROW_GREEN` is defined and unused (`game_cursor.gd:34`), there is
no cooldown/out-of-range state, and the pack's click-effect strip (6f, 100ms) is unwired. A
fire-confirm pop at the aim point is the piece with real feel value.

**Update `ui_pack_inventory.md` while doing this** — its headline still lists gap 2 as open.

### 1.5 UI gap 10 — window buttons, dividers, decoration

The remaining "makes panels look authored rather than generated" sheet group. Cheapest of the
open UI-pack gaps now that slots, tabs, tags, selectors and icons have all landed. `ui_icons.gd`
is the established home for new sheet rects.

---

## Tier 2 — Needs a decision from Ben

### 2.1 NEW GAME skips the hub entirely

```
main_menu.gd:244  CONTINUE  → res://scenes/hub.tscn
main_menu.gd:279  NEW GAME  → res://scenes/main_arena.tscn   (via _start_new_game)
```

A brand-new player goes menu → descent, and never sees the roster, the armory, the launch panel, or
a biome choice. They run as `"The Drifter"` (`progression_manager.gd:94`, the default) and only meet
the hub after their first extraction or death, when the results screen sends them there.

This may well be deliberate — "skip the menus, get to combat" is a defensible first-run design, and
`main_arena` bootstraps its own run (`start_run()` at `main_arena.gd:247`) so nothing is broken.
But it is the one flow decision in the game I cannot infer from the code.

**Needs you:** intended, or should NEW GAME land in the hub like CONTINUE does?

### 2.2 The mod rework has never been played

From `mod_levelup_rework_plan.md` §"Still open", unchanged: 96 mods across 12 characters and 24
evolutions exist, were verified statically and in editor-side simulation, and **have not been felt
in a run**. The 8-per-class numbers are first-pass values and the two per-class evolutions are not
balanced against each other.

This is the largest untested surface in the game right now and it is brand new. Training Room per
class is the cheap version; a real playtest by Ben is the real one.

### 2.3 Mod rarity and pricing were not revisited

Same source. Every mod is class gear now, so the merchant charges one flat `MOD_PRICE` for all of
them, and loot rarity no longer influences which mod drops — the pool is 8 deep per character,
unweighted. The rarity pills that landed on the haul manifest in `54cfd02` therefore describe a
distinction the mod economy no longer makes.

**Needs you:** should mods carry rarity again (drop weight + price), or is a flat class roster the
intent now that they are 8-deep and hand-picked?

### 2.4 UI gap 5 — resource orbs, and the half of it that is moot

The pack's animated globes are proposed for "HP, or a class-resource meter". **There is no class
resource** — a grep across `hud.gd` and `player.gd` finds no mana/rage/energy pool; skills are
purely cooldown-gated. So only the HP half applies, and it competes directly with 1.1: if the HUD
is being re-derived off Grim anyway, decide the orb question in the same pass rather than twice.

### 2.5 The phase dial

`ui_pack_inventory.md` §Legacy flags two assets with no overhaul equivalent:
`Minifantasy_GuiClock.png` and `Minifantasy_GuiDayNightDial.png`, both 16×16 animated. The run is a
5-phase clock and the HUD announces phases with a fading centre label
(`hud.gd:598` `_build_phase_flash_label`) plus a countdown warning. A dial reads "where am I in the
run" at a glance in a way a flash does not.

**Needs you:** this is a phase-display design call, not a wiring job.

### 2.6 UI gap 11 — hub NPC emotions and speech bubbles

`merchant.gd` and `summon_altar.gd` are live entities; ~50 faces × 8-direction bubbles is hub
flavour. Lowest priority of everything in this document, listed so it stays on the record.

---

## Tier 3 — The wall, and it is much lower than both plans say

### 3.1 Biome 2 already has its layouts. 21 finished blocks are unreachable.

This corrects `polish_plan_2026-08-01.md` §3.1 and `level_selection_plan.md` §2, which both conclude
that a second biome is a from-scratch project.

**What exists.** 35 `.ldtkl` blocks on disk (excluding backups), all registered as levels in the one
`Level 1 - Caves.ldtk` project:

| Prefix | Blocks | Sketches in `blocks/` | Tileset registered in the project |
|---|---|---|---|
| `Block_Caves_` | 13 | 6 | `CavesTileset` + shadows + props |
| `Block_Crypt_` | **11** | 10 | `Crypt` + `CryptShadows` + `CryptProps` |
| `Block_NMRealm_` | **10** | 8 | `Solid_Tileset` + shadows + `Props` |
| `Block_Warp_` | 1 | — | `Warp_floor` + `Warp_Props` |

The Crypt set was authored deliberately — `c537cd5 feat(tools,levels): crypt block style + 10
generated crypt blocks`.

**Why none of them can load.** `scripts/main_arena.gd:426-437` hardcodes the inner block pool as ten
`Block_Caves_*` string literals, with `Block_Caves_00_Entry` / `_09_Portal` / `_05_Merchant` as
fixed bookends. `BlockManager.BLOCK_PREFIX` is `"Block_Caves_"` (`block_manager.gd:17`). `LevelData`
has no block field at all. There is no code path anywhere that names a Crypt or NMRealm block.

**What is actually missing for The Catacombs (level 2)**, versus what the old estimate assumed:

| Piece | State |
|---|---|
| Block layouts | ✅ 11 compiled, plus 10 `.block` sketches to regenerate or extend from |
| Tileset wiring | ✅ already in the LDtk project — nothing to import |
| Enemy art | ✅ `Minifantasy_Undead_Creatures_v1.0`: 13 creatures, incl. Skeleton Minotaur and Zombie Giant (miniboss / boss shaped) |
| `LevelData.LEVELS[2]` | ❌ stub — `floor_path`, `wave_composition`, `scene_map`, `miniboss_id`, `final_boss_id` all empty |
| Enemy defs + scenes | ❌ ~6 new `EnemyDefinition`s + `.tscn`s, following the cave set exactly |
| Block pool plumbing | ❌ move `main_arena.gd`'s hardcoded list into `LevelData`, key `BLOCK_PREFIX` off the level |
| Entry / portal / merchant blocks | ⚠️ Crypt has `00_Entry`; no Crypt portal or merchant block exists |
| Music | ❌ `mus_catacombs` → `catacombs.ogg` does not exist (**audio — excluded**) |

That is still a real chunk of work, but it is *content authored against existing patterns*, not a
project. And the plumbing step is worth doing on its own merits regardless: a hardcoded biome-1
block list inside `main_arena` is the reason 60% of the authored level content is dead.

**Recommended split:**

1. **3.1a — the plumbing alone** (small, Tier-1-sized). Move the block pool + prefix into
   `LevelData`, so a biome's blocks are declared beside its waves. Nothing changes for the player;
   biome 2 stops being blocked on a refactor.
2. **3.1b — The Catacombs** (the real job). Undead enemy set, wave table, floor, bosses, and a Crypt
   portal + merchant block via `/blockgen`.
3. **3.1c — level selection**, which `level_selection_plan.md` correctly says needs two real biomes
   before it can be tested.

---

## Excluded — audio (recorded, not planned)

Seven referenced `.ogg` files do not exist on disk. `AudioManager` no-ops on missing files, so all
seven are silent rather than broken:

```
assets/audio/sfx/combat/channel_loop_fire.ogg      ← the wired-but-silent held-channel bed
assets/audio/sfx/combat/channel_loop_arcane.ogg
assets/audio/sfx/combat/channel_loop_martial.ogg
assets/audio/music/catacombs.ogg                   ← biome 2-5 music
assets/audio/music/nightmare_realm.ogg
assets/audio/music/threshold.ogg
assets/audio/music/inferno.ogg
```

The three channel loops are the concrete remainder of RTR task 15 — machinery built and verified,
assets missing. `catacombs.ogg` is a soft dependency of Tier 3.1b.

---

## Suggested order

1. **Step 0** — commit the mod/level-up rework.
2. **Tier 0** in one pass — credits path, two font sites, delete `flamggy`, prune worktrees. All
   mechanical, no decisions, one commit.
3. **1.2 (fades)** — best feel-per-hour on the list, touches nine call sites and nothing else.
4. **1.1 (HUD → Grim)** — after you have eyeballed the two sheets side by side. Fold the 2.4 orb
   decision into it.
5. **2.2 (play the mod rework)** — the largest untested surface, and it is new. Ideally before more
   is built on top of it.
6. **3.1a (block pool plumbing)** — small, unblocks the biggest thing.
7. Then choose between **3.1b** (the Catacombs), **1.3/1.4/1.5** (visual finish), and the Tier 2
   decisions.

Items 1–3 and 6 need nothing from you. 4 needs a five-second look. 5 needs a play session.
2.1, 2.3, 2.5 and 1.3's look question are the four decisions on this page.
