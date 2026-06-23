# Character Overhaul Design — Fantasy Class Identities

**Status:** Proposal for Ben's approval.
**Author:** Claude (game designer hat), 2026-06-21.
**Goal:** Map all 7 existing characters (`data/characters.gd`) onto coherent fantasy-class
archetypes backed by **Minifantasy True Heroes** sprite sets, so future kit design answers to
an archetype instead of being invented from scratch. This doc is the contract for the
sprite-pipeline + rename implementation that follows — it should be implementable without
re-opening the asset packs.

**Headline finding:** the existing names were *already* archetypal. Six of seven map onto a
class cleanly and keep their name; only **The Drifter** (class-agnostic) gets a recommended
rename. The "overhaul" is therefore: assign a class + sprite set, re-theme passive copy to the
class, fix two starting weapons that fail the class test, and wire a per-character
`SpriteFrames` swap.

---

## 1. Sprite Inventory

All four **True Heroes** packs share one convention (verified, not assumed):

- **Frame size: 32×32, uniform across all four packs.** No inter-pack scaling needed.
- **Sheet layout: rows = 4 facing directions, columns = animation frames.** A `128×128`
  Walk sheet is `4 frames × 4 directions`; a `512×128` Idle is `16 frames × 4 directions`.
- **`Die` is the only single-row sheet** for every class (death is non-directional) — this is
  the proof the other sheets' 4 rows are *directions*, not a wrapped animation.
- **Row 0 = facing Down / front** (toward camera); **row 2 = facing Up / back**. Determined by
  analysing the attack-swing arc and which side of the body is visible. Rows 1 & 3 are the
  remaining facings (side/diagonal) — exact order is worth a 60-second scrub-confirm in-editor
  before bulk slicing, but **v1 only needs row 0** (see §3).

### Class availability & animation completeness

Every class below has the required **Idle / Walk / Attack / Dmg / Die** at 32×32, plus a Jump
sheet. ✅ = present. "Attack*" notes a class whose attack ships as a different sheet.

| Pack (folder) | Class | Idle | Walk | Attack | Dmg | Die | Extras | License |
|---|---|---|---|---|---|---|---|---|
| **I** `Minifantasy_TrueHeroes_v1.0` | Barbarian | ✅16f | ✅4f | ✅6f | ✅4f | ✅20f | BattleCry, Guard, ThrowThings, ThunderBlade | Commercial |
| | Druid | ✅16f | ✅4f | ✅4f | ✅4f | ✅31f | Root summon, 3× shapeshift forms | Commercial |
| | **Rogue** | ✅16f | ✅4f | ✅4f | ✅4f | ✅26f | **Dodge, Run, Shurikens** | Commercial |
| **II** `Minifantasy_True_Heroes_II_v1.0` | **Bard** | ✅16f | ✅4f | ✅4f | ✅4f | ✅25f | IdleStart/End flourish | Commercial |
| | Cleric | ✅12f | ✅4f | ✅6f | ✅4f | ✅35f | IdleStart/End flourish | Commercial |
| | **Paladin** | ✅12f | ✅4f | ✅6f | ✅4f | ✅20f | IdleStart/End flourish | Commercial |
| **III** `Minifantasy_True_Heroes_III_v1.1` | **Fighter** | ✅16f | ✅4f | ✅4f | ✅4f | ✅15f | Idle_Special (31f), Attack_Effect | Commercial |
| | **Ranger** | ✅16f | ✅4f | **SingleShot 10f** | ✅4f | ✅24f | Diagonal+Ortho shots, Arrow projectile | Commercial |
| | **Wizard** | ✅16f | ✅4f | ✅6f | ✅4f | ✅20f | Idle_Special (18f), Attack_Effect | Commercial |
| **IV** `Minifantasy_True_Heroes_IV_v1.1` | **Blood_Mage** | ✅16f | ✅4f | ✅6f | ✅4f | ✅23f | Attack_Effect | Commercial |
| | Ninja_Assassin | ✅16f | ✅4f | ✅6f | ✅4f | ✅18f | Attack_Effect | Commercial |
| | Tech-Aug. Gunslinger | ✅16f | ✅4f | **Shot 7f** | ✅4f | ✅21f | Diagonal+Ortho shots, Impact | Commercial |

**Bold** = used in this overhaul. Leftovers (Barbarian, Druid, Cleric, Ninja_Assassin,
Gunslinger) are a clean bench for future characters. A **True Villains** pack (Dark Priest,
Demonologist, Supreme Necromancer) also exists for future antagonist-flavored unlocks.

### License status — all clear for commercial use

Every used pack **and** the Portrait Generator ship the identical **Minifantasy Commercial
License** (`CommercialLicense.txt` in each pack root; the Portrait pack's `Patreon_*.url` is a
promo link, not a separate license). Terms:

- ✅ Use in commercial projects, unlimited; ✅ edit/alter the assets.
- ❌ Re-distribute/re-sell assets (or altered versions) as assets/images/NFTs.
- ⚠️ **MUST** credit **"Krishna Palacio"** in the game credits, and **send Krishna a link to the
  project on release.** → Add to the attribution/credits doc as a release checklist item.

---

## 2. Character Mappings

Unlock-cost ladder and passive **power** are unchanged (identity overhaul, not a balance
rework). `passive_id` strings are **keys read by `player.gd`** and must **not** change — only the
display name / `passive_desc` copy is re-themed. Per-character `color` fields stay as-is (they
encode identity and drive hub-UI accents).

Sprite paths are relative to project root; prepend `res://` for Godot. Frame counts are **row 0**
(the row v1 slices). Recommended fps explained in §3.

---

### 2.1 The Drifter → **The Sellsword** — Fighter (Pack III)

> *A nameless blade-for-hire who learned to fight by surviving — no magic, no tricks, just steel.*

The only character whose name doesn't already signal a class. The Fighter sprite is an armored
sword-and-**shield** everyman — the cleanest "learn-the-game" silhouette in the set. "Sellsword"
keeps the Drifter's rootless vibe while fitting the armored fighter. *(Fallbacks: keep "The
Drifter"; or "The Squire" for a more beginner-flavored read.)*

| Anim | Sheet (`…/Fighter/General_Animations/`) | Dims | Frames (r0) | fps |
|---|---|---|---|---|
| idle | `Figther_Idle.png` *(sic — misspelled in-pack)* | 512×128 | 16 | 9 |
| walk | `Figther_walk.png` | 128×128 | 4 | 10 |
| attack | `Figther_Attack.png` (+ `Figther_Attack_Effect.png` overlay) | 128×128 | 4 | 20 |
| damage | `Figther_Dmg.png` | 128×128 | 4 | 15 |
| death | `Figther_Die.png` (single row) | 480×32 | 15 | 18 |

- **Path root:** `assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/General_Animations/`
- **Portrait:** Generator → **human**, short dark hair, light stubble/classic short beard, neutral steel tones.
- **Passive:** `none` (unchanged). Copy: *"None — a plain blade and a steady hand."*
- **Starting weapon:** **Hurled Steel** (keep). Physical thrown blade; reads as a sword-throw paired with the melee swing. No re-theme required.
- **Unlock cost:** 0 (free, always unlocked).

---

### 2.2 The Scavenger → **The Scavenger** — Ranger (Pack III)

> *A wilds-runner who reads every battlefield for salvage, loosing arrows from the tree line.*

Green hooded archer/survivalist — a natural "finds more, fights less efficiently" loot
optimizer. Name already fits; keep it. *(Alt: "The Outrider.")*

| Anim | Sheet (`…/Ranger/General_Animations/`) | Dims | Frames (r0) | fps |
|---|---|---|---|---|
| idle | `Ranger_Idle.png` | 512×128 | 16 | 9 |
| walk | `Ranger_walk.png` | 128×128 | 4 | 10 |
| attack | `Ranger_SingleShot_Orthogonal.png` ⚠️ *no plain Attack sheet* | 320×128 | 10 | 50 |
| damage | `Ranger_Dmg.png` | 128×128 | 4 | 15 |
| death | `Ranger_Die.png` (single row) | 768×32 | 24 | 24 |
| *(projectile)* | `Single_Arrow_Projectile.png` (3×3 @ 32px) | 96×96 | — | — |

- **Path root:** `…/Minifantasy_True_Heroes_III_Assets/Ranger/General_Animations/`
- **Portrait:** Generator → **human or halfling**, hood-up read via keen eyes + brown/auburn hair, green/brown palette.
- **Passive:** `scavenger_passive` (unchanged mechanics). Themed name **"Forager's Eye."** Copy: *"+25% Pickup Radius. +15% Loot Find."*
- **Starting weapon:** ⚠️ **NEW — "Hunting Bow"** (replaces Arcane Blade; a melee blade on a ranger fails the class test). Suggested data (mirror Hurled Steel, arrow-themed): `behavior: projectile`, `damage_type: physical`, `damage: 11`, `attack_speed: 1.1`, `projectile_speed: 420`, `projectile_count: 1`, `lifetime: 3.0`, `drop_weight: 0`, `mod_slots: 2`, tint scrap-green, projectile sprite = `Single_Arrow_Projectile`.
- **Unlock cost:** 1000.

---

### 2.3 The Warden → **The Warden** — Paladin (Pack II)

> *An oathbound guardian who plants their feet and dares the horde to move them.*

Blue-and-gold heavy armor with a shield — the "immovable wall" made literal. Name is perfect
as-is; a warden *is* a paladin-guardian.

| Anim | Sheet (`…/Paladin/General_Animations/`) | Dims | Frames (r0) | fps |
|---|---|---|---|---|
| idle | `PaladinIdle.png` (`IdleStart/End` are optional flourishes) | 384×128 | 12 | 8 |
| walk | `PaladinWalk.png` | 128×128 | 4 | 9 |
| attack | `PaladinAttack.png` | 192×128 | 6 | 30 |
| damage | `PaladinDmg.png` | 128×128 | 4 | 15 |
| death | `PaladinDie.png` (single row) | 640×32 | 20 | 22 |

- **Path root:** `assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/General_Animations/`
- **Portrait:** Generator → **human**, stern, strong brow/jaw, dark hair; gold/steel palette.
- **Passive:** `warden_passive` (unchanged). Themed **"Last Bastion."** Copy: *"Armor doubles while below 50% HP."*
- **Starting weapon:** **Warden's Repeater** (keep mechanics — slow, heavy, "each shot counts" *is* the tank identity). ⚠️ **Soft re-theme flag:** "Repeater" connotes a crossbow/gun, which sits oddly on a sword-and-shield Paladin. Re-skin the projectile + rename to a hurled holy bolt / thrown warhammer (e.g. *"Warden's Judgment"*) so the swing-throw reads. **Stats unchanged.**
- **Unlock cost:** 1000.

---

### 2.4 The Spark → **The Spark** — Wizard (Pack III)

> *A reckless arcanist who overcharges every spell — devastating, and one misstep from ash.*

Pointy-hat, staff-wielding arcane caster = the canonical glass-cannon mage. Name fits ("spark" =
a burst of arcane/lightning). **Color caveat:** the robe is *red*, but Spark's identity is
electric-yellow — resolve by keeping yellow as the weapon/FX/UI accent (the `color` fields and
projectile tint stay yellow); an optional yellow palette-shift of the robe is a later polish, not
a blocker.

| Anim | Sheet (`…/Wizard/General_Animations/`) | Dims | Frames (r0) | fps |
|---|---|---|---|---|
| idle | `Wizard_Idle.png` (`Wizard_Idle_Special` 18f optional) | 512×128 | 16 | 9 |
| walk | `Wizard_Walk.png` | 128×128 | 4 | 10 |
| attack | `Wizard_Attack.png` (+ `Wizard_Attack_Effect.png` fire-arc overlay) | 192×128 | 6 | 30 |
| damage | `Wizard_Dmg.png` | 128×128 | 4 | 15 |
| death | `Wizard_Die.png` (single row) | 640×32 | 20 | 22 |

- **Path root:** `…/Minifantasy_True_Heroes_III_Assets/Wizard/General_Animations/`
- **Portrait:** Generator → **human or elf**, older/wise, white-grey hair, sharp eyes. *(Note: the generator has no hats — the pointy hat won't read in the portrait; identity carries via the electric-yellow UI accent.)*
- **Passive:** `spark_passive` (unchanged). Themed **"Arcane Overload."** Copy: *"+50% Crit Damage (2.25× total)."*
- **Starting weapon:** ⚠️ **Re-theme "Spark's Pistol" → "Spark's Wand"** (a wizard with a pistol fails the class test). Mechanics identical (rapid, low-damage projectile). **Recommended justified tweak:** `damage_type` physical → **shock**, matching the electric "Spark" identity and the existing yellow tint (negligible balance impact). New copy: *"Rapid arcane sparks. Fragile but relentless."*
- **Unlock cost:** 1500.

---

### 2.5 The Shade → **The Shade** — Rogue (Pack I)

> *A cutthroat who simply isn't where the blow lands — gone in a wisp of shadow.*

Compact hooded thief. **"Dodge + vanish" is the textbook Rogue passive**, and this Rogue ships
native **Dodge / Run / Shurikens** special animations — the Dodge sheet can directly drive the
dodge passive's feedback. Name perfect as-is.

| Anim | Sheet (`…/Rogue/General_Animations/`) | Dims | Frames (r0) | fps |
|---|---|---|---|---|
| idle | `Minifantasy_TrueHeroesRogueIdle.png` | 512×128 | 16 | 9 |
| walk | `Minifantasy_TrueHeroesRogueWalk.png` | 128×128 | 4 | 10 |
| attack | `Minifantasy_TrueHeroesRogueAttack.png` | 128×128 | 4 | 20 |
| damage | `Minifantasy_TrueHeroesRogueDmg.png` | 128×128 | 4 | 15 |
| death | `Minifantasy_TrueHeroesRogueDie.png` (single row) | 832×32 | 26 | 26 |
| *(extras)* | `…RogueDodge.png`, `…RogueRun.png`, `…RogueShurikens.png` | — | — | — |

- **Path root:** `assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Rogue/General_Animations/` (specials under `…/Special_Animations/Mobility/` and `…/Shurikens/`).
- **Portrait:** Generator → **human**, dark hair, shadowed eyes, no beard; deep-violet UI accent.
- **Passive:** `shade_passive` (unchanged). Themed **"Shadowstep."** Copy: *"15% Dodge Chance. Dodging cloaks you in shadow for 0.5s."*
- **Starting weapon:** **Arcane Blade** (keep). A fast **violet** melee arc fits a rogue's knife-work *and* matches the Shade's deep-violet identity — a happy accident worth keeping.
- **Unlock cost:** 2000.
- **Alternate:** **Ninja_Assassin** (Pack IV) if Ben prefers a darker/eastern, blacker silhouette over the earthy Rogue. Trade-off: lose the native Dodge animation. See §4 Q3.

---

### 2.6 The Herald → **The Herald** — Bard (Pack II)

> *A battle-bard whose songs do the real damage — the blade is just punctuation.*

Teal/blue performer holding an **instrument** — a near-exact color match to the Herald's signal
teal, and the instrument *is* the "Call." A bard's whole kit is ability/support, perfectly
fitting the design ("weapon is weak, abilities are everything"). Name fits (a herald heralds; the
bard sounds the call).

| Anim | Sheet (`…/Bard/General_Animations/`) | Dims | Frames (r0) | fps |
|---|---|---|---|---|
| idle | `BardIdle.png` (`BardIdleStart/End` 6f flourishes optional) | 512×128 | 16 | 9 |
| walk | `BardWalk.png` | 128×128 | 4 | 10 |
| attack | `BardAttack.png` | 128×128 | 4 | 20 |
| damage | `BardDmg.png` | 128×128 | 4 | 15 |
| death | `BardDie.png` (single row) | 800×32 | 25 | 25 |

- **Path root:** `…/Minifantasy_True_Heroes_II_Assets/Bard/General_Animations/`
- **Portrait:** Generator → **elf or human**, charismatic, fair hair; teal/blue accent.
- **Passive:** `herald_passive` (unchanged). Themed **"Rallying Anthem."** Copy: *"Abilities +30% damage, −20% cooldown. +1 ability slot."*
- **Starting weapon:** **Herald's Call** (keep). Weak auto-projectile = a sonic "note"; re-skin the projectile to a teal music-note. Name already perfect.
- **Unlock cost:** 2500.

---

### 2.7 The Cursed → **The Cursed** — Blood Mage (Pack IV)

> *A heretic who pays in their own blood for power no sane mage would touch.*

Crimson hooded sinister caster — the strongest thematic **and** color match in the roster. A
blood mage sacrifices life/blood for power, which *is* the "+20% all stats, start Unsettled,
maximum risk" fantasy. Name perfect as-is.

| Anim | Sheet (`…/Blood_Mage/General_Animations/`) ⚠️ *generic filenames* | Dims | Frames (r0) | fps |
|---|---|---|---|---|
| idle | `Idle.png` | 512×128 | 16 | 9 |
| walk | `Walk.png` | 128×128 | 4 | 10 |
| attack | `Attack.png` (+ `Attack_Effect.png` blood/void overlay) | 192×128 | 6 | 30 |
| damage | `Dmg.png` | 128×128 | 4 | 15 |
| death | `Die.png` (single row) | 736×32 | 23 | 24 |

- **Path root:** `assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/General_Animations/` — files are generically named (`Idle/Walk/Attack/Dmg/Die.png`); **disambiguate by folder**, not filename.
- **Portrait:** Generator → **human** (gaunt, pale, red-ish hair) or **orc** for a monstrous read; crimson accent.
- **Passive:** `cursed_passive` (unchanged). Themed **"Blood Pact."** Copy: *"Begin each run Unsettled (+instability). +20% to all base stats."*
- **Starting weapon:** **Void Mortar** (keep). A lobbed void/blood AoE fits a cursed caster. Optional: re-skin to a blood/hemorrhage shell — but void works as-is.
- **Unlock cost:** 5000.

---

### Mapping at a glance

| Old name | New name | Class (pack) | Passive (themed) | Starting weapon | Unlock |
|---|---|---|---|---|---|
| The Drifter | **The Sellsword** ¹ | Fighter (III) | — (none) | Hurled Steel | 0 |
| The Scavenger | The Scavenger | Ranger (III) | Forager's Eye | **Hunting Bow** (new) | 1000 |
| The Warden | The Warden | Paladin (II) | Last Bastion | Warden's Repeater (soft re-theme) | 1000 |
| The Spark | The Spark | Wizard (III) | Arcane Overload | **Spark's Wand** (re-theme) | 1500 |
| The Shade | The Shade | Rogue (I) | Shadowstep | Arcane Blade | 2000 |
| The Herald | The Herald | Bard (II) | Rallying Anthem | Herald's Call (re-skin) | 2500 |
| The Cursed | The Cursed | Blood Mage (IV) | Blood Pact | Void Mortar | 5000 |

¹ Only proposed rename; all others keep their name. See §4 Q1.

---

## 3. Implementation Notes (for the sprite-pipeline + rename tasks)

**Sprite swap mechanism.** `player.gd:90` already uses `@onready var sprite: AnimatedSprite2D =
$Sprite`. Build **one `SpriteFrames` resource per character** with exactly these five animation
names (the engine plays them by name): `idle`, `walk`, `attack`, `damage`, `death`
(`player.gd` calls `sprite.play("idle"|"walk"|"attack"|"damage"|"death")`). Select/assign the
per-character `SpriteFrames` at spawn from the chosen `CharacterData` id.

**Slicing recipe (v1 — single-facing + flip).** The engine only flips horizontally
(`player.gd:452 → sprite.flip_h = input_dir.x < 0`); there is **no** directional-row logic.
So for v1, **slice row 0 (Down/front-facing) only** for `idle/walk/attack/damage`, and the whole
single `Die` row for `death`. The character always faces the camera and flips for left/right —
the standard survivors convention. Frame counts to slice = the "Frames (r0)" column in each table
(= sheet width ÷ 32). The remaining 3 rows are full directional data if 4-direction facing is
ever added later. *(Confirm row→direction order with a 60-second frame-scrub before bulk
slicing; analysis says r0=Down, r2=Up.)*

**⚠️ Attack-fire timing is a footgun.** `player.gd:357-360` fires the weapon at
`fire_delay = attack_frame_count / attack_fps`. If the attack animation runs long, **fast weapons
fire late.** Set each character's **`attack` animation fps** so the whole swing lands in
~0.18–0.22 s regardless of frame count:

| Attack frames | Characters | Rec. attack fps | Swing duration |
|---|---|---|---|
| 4 | Sellsword, Shade, Herald | ~20 | 0.20 s |
| 6 | Warden, Spark, Cursed | ~30 | 0.20 s |
| 10 (Ranger SingleShot) | Scavenger | ~50 | 0.20 s |

Sanity check against the fastest weapons: Arcane Blade 1.8/s (0.56 s interval) and Spark's Wand
2.0/s (0.50 s interval) both comfortably exceed a 0.20 s swing. ✅

**Other fps:** idle ~8–9 (calm loop), walk ~9–10, damage ~15 (one-shot, must clear fast — the
flinch interrupts and is gated by the 0.55 s i-frame window in `player.gd`), death tuned to
~0.7–1.0 s total (frame_count ÷ fps; values in tables).

**Per-pack filename gotchas (will silently break paths if missed):**
- **Pack III / Fighter** files are misspelled **`Figther_*`** (and lowercase `Figther_walk.png`).
- **Pack IV** (Blood_Mage) files are **generic** (`Idle/Walk/Attack/Dmg/Die.png`) — keyed by folder only.
- **Pack I** (Rogue) uses the long `Minifantasy_TrueHeroesRogue*` prefix.
- **Pack II** (Bard/Paladin) uses `ClassName`-prefixed files (`BardIdle.png`, `PaladinAttack.png`).

**Ranger has no `Attack` sheet** — map `attack` → `Ranger_SingleShot_Orthogonal.png` (10f).
`Ranger_SingleShot_Diagonal.png` and `Single_Arrow_Projectile.png` are bonus content for a true
bow weapon. (The unused Gunslinger is the same shape: `Shot_Orthogonal` instead of Attack.)

**Optional `Attack_Effect` overlays** ship for Fighter, Wizard, Blood_Mage (and bench Barbarian/
Ninja): a separate FX sheet aligned frame-for-frame to the Attack sheet (slash gleam, fire arc,
blood burst). Ignore for v1, or composite as a second short-lived `Sprite2D` on attack.

**Weapon work summary (tasks 06–08):**
- **New:** `Hunting Bow` (Scavenger) — exclusive, `drop_weight: 0`, suggested data in §2.2.
- **Re-theme (mechanics-light):** `Spark's Pistol` → `Spark's Wand` (+ `damage_type: shock`).
- **Soft re-theme (visual/name only):** `Warden's Repeater` → thrown holy bolt/warhammer.
- **Re-skin only:** `Herald's Call` → teal note; `Void Mortar` → optional blood shell.
- **Unchanged:** `Hurled Steel`, `Arcane Blade`.
- **Do NOT change** any `passive_id` string or the `CharacterData` `color*` fields — both are
  consumed by live code (`player.gd` passive checks; hub UI tints).

**Hub / character-select.** Confirm the hub character preview points at the new `SpriteFrames`
(or a static row-0 idle frame). Per CLAUDE.md: account for 3× viewport scaling and wrap any
overflowing select panel in a `ScrollContainer` (SHOW_AS_NEEDED). The 32×32 sprite renders at
~32 px in the 640×360 arena — consistent with current player scale.

**Portrait pipeline.** The Portrait Generator is an interactive HTML app (not scriptable here)
that exports face headshots as PNG, with races human/elf/dwarf/goblin/orc/halfling and
hair/beard/eyes/mouth components — **no class costuming, hats, or hoods.** So portraits convey
race + face-mood + palette, not class gear. Recommended pipeline: run the app once per character
using the **race + features + accent color** specified in each §2 entry, export PNG, drop into
the character-select UI. *(Zero-effort fallback if class-gear matching matters more than face
polish: upscale the row-0 idle frame 4× as a pixel portrait — guaranteed on-class, but tiny.)*

---

### Built — sprite system (implemented & verified)

- **Runtime construction (chosen over pre-built `.tres`):** `data/factories/character_sprite_factory.gd` —
  `CharacterSpriteFactory.build(char_id) -> SpriteFrames` slices row `dir_row` (0) of each sheet into
  32×32 `AtlasTexture` frames (`filter_clip = true`), one animation per `anims` entry. Mirrors the
  `enemy_guardian.gd` slicing idiom. Picked so **adding character #8 is pure data + assets, zero code**.
- **Data:** each `CharacterData.ALL` entry gained a `"sprite"` block — `dir`, `frame_size`, `dir_row`,
  and `anims` = `{ name: [sheet_file, frame_count, fps] }`. Loop is derived (idle/walk loop; attack/
  damage/death one-shot).
- **Arena player:** `player.gd._apply_character_sprite()` (called in `_ready` right after
  `_load_character_stats`) builds + assigns `sprite.sprite_frames`, sets nearest filtering, plays idle;
  falls back to the scene's baked frames if metadata/sheets are missing. **The existing animation state
  machine (idle/walk/attack/damage/death by name + `flip_h`) was reused unchanged** — no rewrite.
- **Hub:** `hub.gd` replaced the tinted-block avatar with an `AnimatedSprite2D` (idle/walk + flip) built
  from the same factory, parented under a rebuildable `_avatar_holder`. `_apply_player_visual()` re-runs
  on roster-panel close, so selecting a character updates the hub avatar live. Tinted-block fallback kept.
- **No `.tscn` edits, no per-character offset:** all True Heroes frames are 32×32 centered on the body
  origin, so feet/collision stay aligned across all 7 (verified via overlay). The scene's baked Rogue
  `SpriteFrames` stays as a runtime-overridden fallback.
- **fps used:** idle 8–9, walk 9–10, attack **20** (4-frame) / **30** (6-frame) / **50** (Ranger's
  10-frame SingleShot), damage 15, death tuned to ~0.9–1.0 s — keeping `fire_delay = attack_frames/fps ≈ 0.2 s`.
- **Verification:** headless run builds all 7 with exact expected frame counts/fps; hub runs clean (no
  console errors) with the Fighter rendering and walking; arena `_apply_character_sprite()` executes
  without error (confirmed via runtime stack trace — the descent's slow LDtk loading, not sprites, is why
  MCP screenshots of the arena time out).
- **Out-of-scope bug noticed:** `weapon_factory.gd:314 _get_projectile_sprite_frames()` calls
  `add_animation("default")` on a `SpriteFrames` that already has it → harmless C++ condition warning on
  every run. Pre-existing, unrelated to characters; worth a separate cleanup.

## 4. Open Questions for Ben

Each already has a recommended default baked into §2/§3, so **none of these block
implementation** — they're redline points, not unknowns.

1. **Rename The Drifter → "The Sellsword"?** Recommended (fixes the one class-agnostic name; the
   Fighter sprite is an armored everyman). Fallbacks: keep "The Drifter", or "The Squire". The
   other six names are recommended to stay.
2. **Spark's red robe vs electric-yellow identity** — ship the red Wizard sprite with yellow
   FX/UI accent (recommended, zero art work), or budget a yellow robe palette-shift?
3. **The Shade: Rogue (recommended) vs Ninja_Assassin?** Rogue ships a native Dodge animation
   that maps to the passive and keeps the cool Pack-IV classes as a future tier; Ninja is darker/
   stealthier but loses the Dodge sheet.
4. **Facing model** — ship single-facing + `flip_h` (recommended, matches the current engine), or
   invest now in 4-direction slicing (the sheet data supports it)?
5. **Adopt the themed passive names** (Forager's Eye, Last Bastion, Arcane Overload, Shadowstep,
   Rallying Anthem, Blood Pact), or keep the current plain `passive_desc` text? Mechanics are
   identical either way.
