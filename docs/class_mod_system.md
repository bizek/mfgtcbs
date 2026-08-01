# Class Mod System — Two-Layer Mod Model

**Status:** Complete. Architecture + plumbing (task 31), all 12 classes' content (task 32), and the
applicability model extended to level-up choices (task 33) are all shipped.

**Live count: 48 class mods — 4 per class × 12 classes** (`data/class_mods.gd`, verified 2026-07-21).
An earlier revision of this header said 46; that predated the final Gunslinger/Deadeye entries.

Locked with Ben 2026-07-06. This is the design-of-record for how mods/upgrades match the per-class
combo kits.

---

## 1. The problem

Every character now runs a **combo kit** and **drops weapon auto-fire** (`player.set_combo_ability` —
"the combo IS the attack"). The old mod pool is one flat list of 17 **generic** mods (`data/mods.gd`)
built for the auto-fire era: `PIERCE`, `CHAIN`, `EXPLOSIVE`, elementals, etc. Those only bite when a
projectile/weapon actually fires. A pure-melee kit (Fighter, Paladin, Ninja, Cleric, Druid) gets
nothing from `PIERCE` — yet it still showed up in loot and the armory. "You don't see the Spark mods
while playing as the Drifter" was the goal.

Two layers fix this:

1. **Generic layer** (`ModData`, unchanged behavior) — gains **applicability tags** so a class only
   ever sees generics that do something for its kit.
2. **Class layer** (`ClassModData`, NEW) — per-class mods that reshape *that class's own* combo
   nodes / RMB special / Q-E skills / dash. This is where melee kits get their build depth.

---

## 2. Applicability model

One resolver — `data/mod_applicability.gd` (`ModApplicability`) — answers *"does this mod do anything
for the character the player is currently running?"* everywhere it's asked: loot rolls, the merchant,
the armory, and (task 33) the level-up pool.

### Kit capability tags
`ModApplicability.KIT_CAPABILITIES` declares what each combo kit **emits**, authored by reading every
kit in `ChainFactory`/`SkillFactory` (not invented):

| Capability   | Meaning                                                        |
|--------------|---------------------------------------------------------------|
| `melee_hit`  | lands melee / player-centered AoE hits (every combo kit)      |
| `projectile` | fires projectiles as part of the combo (arrows, bolts, bombs) |

| Kit | Caps | | Kit | Caps |
|-----|------|-|-----|------|
| fighter | `melee_hit` | | bard | `melee_hit, projectile` |
| paladin | `melee_hit` | | barbarian | `melee_hit, projectile` |
| ninja | `melee_hit` | | rogue | `melee_hit, projectile` |
| cleric | `melee_hit` | | ranger | `melee_hit, projectile` |
| druid | `melee_hit` | | wizard | `melee_hit, projectile` |
| | | | blood_mage | `melee_hit, projectile` |
| | | | gunslinger | `melee_hit, projectile` |

### Generic mod tags
Each `ModData` entry carries `requires: [...]` (kit-capability tags). A generic mod is applicable when
`requires` is **empty** (universal) OR shares a tag with the kit's caps.

- **Universal** (`requires: []`): `LIFESTEAL`, `CRIT AMPLIFIER`, `INSTABILITY SIPHON` — player-stat /
  global-behavior mods, so every kit benefits.
- **Projectile** (`requires: ["projectile"]`): everything else (pierce, chain, explosive, elementals,
  size, split, gravity, ricochet, accelerating, dot, multishot, napalm, the boss unique).

So the **Fighter sees exactly 3 generics** (the universals); the **Wizard sees all 17**. Verified in
smoke test.

> **Deliberate v1 scope:** projectile generics gate to `projectile` kits because combo characters drop
> weapon auto-fire — those mods only fire through combo *projectiles*, and even then only for kits that
> launch them. Routing generic elementals/DoT/size into **melee combo hits** is left as future space
> (see §6). Melee kits get their depth from the **class layer** instead — that is the whole point.

### The switch-character edge case
Loadouts are per-character (generic mods live on the weapon; each character runs its own weapon; class
mods live on the character). An already-owned generic that isn't applicable to the current class is
**never destroyed** — the armory shows it **greyed with "(no effect for this class)"** and still lets
you slot it (harmless). Class mods for another class simply don't appear in this character's class-mod
card.

---

## 3. Class-mod family

`data/class_mods.gd` (`ClassModData`) — same data-factory spirit as `ModData`. **Zero behavior**
(CLAUDE.md); `ClassModFactory` reads it and mutates kit data at build time.

```
"<id>": {
  id, name, kit,            # kit = CharacterData "melee_kit" this mod belongs to
  desc, color,
  target: { graph?, anim }, # graph = "light"/"heavy"/"channel"/"skill_q"/… (optional);
                            # anim  = ChoreographyPhase.animation to hit (wherever it appears)
  op,                       # scale_aoe | add_pull | add_status | add_projectile_status |
                            # add_projectiles | modifier | kit_flag
  params,                   # op-specific numbers
}
```

### The one seam — `ClassModFactory` (`data/factories/class_mod_factory.gd`)
`player._load_combo` builds the kit + skills fresh, then:
```gdscript
var class_mods := ProgressionManager.get_active_class_mods(char_id)   # equipped ∩ this kit
ClassModFactory.apply_to_kit(kit_id, kit, class_mods)                 # mutate light/heavy/channel
ClassModFactory.apply_to_skills(kit_id, skills, class_mods)           # mutate skill_q/skill_e/…
for m in ClassModFactory.build_modifiers(kit_id, class_mods): modifier_component.add_modifier(m)
```
Mutations happen on freshly-built AbilityDefinitions every load, so nothing accumulates. Player
modifiers carry the `classmod_` source prefix and are stripped on every rebuild / weapon switch.

### v1 operations (mirror existing kit primitives — no bespoke code paths)
- **`scale_aoe`** — multiply the matched phase's `AreaDamageEffect`/`DealDamageEffect`
  `aoe_radius`/`base_damage` (`radius_mult`, `damage_mult`).
- **`add_pull`** — append a toward-player `DisplacementEffect` (same i-frame-gated system as the
  Uppercut fling / Shield-Bash shove). Params: `distance`, `duration`, `arc_height`.
- **`add_status`** — append an `ApplyStatusEffectData` from a `StatusFactory` id (`params.status`,
  `stacks`, `apply_to_self`). Dispatched to nearby enemies by the existing combo effect router.
- **`modifier`** — kit-agnostic player `ModifierDefinition` while equipped (`stat`, `op`, `value`).
- **`add_projectile_status`** — inject an `ApplyStatusEffectData` into the matched phase's
  `SpawnProjectilesEffect.projectile.on_hit_effects`, so the status lands per enemy hit rather than
  in the phase's AoE pool. Use for ranged nodes.
- **`add_projectiles`** — increment `SpawnProjectilesEffect.count` (`count`). Fan the Hammer +2.

### Beyond phases — `kit_flag` (added 2026-07-31)
`ClassModFactory` mutates *phases*, which cannot express a mod whose effect is **which graph runs**
or **how the entity routes**. `kit_flag` mods are skipped by both apply loops; the entity reads the
equipped id directly in `player._load_combo`. First user: **SPLIT QUIVER** (Ranger) — it lifts the
quiver stance onto the light chain and makes every armed arrow carry the off-hand element as well
as its own. Prefer a phase op whenever one will do; `kit_flag` moves behaviour out of data.

New ops are added here (one `match` case) as task 32 needs them — never per-mod scripts.

---

## 4. Storage, loot, codex, insurance, save

**Touchpoint list** (everything that assumed one flat pool — all now handled):

| Touchpoint | File | Change |
|-----------|------|--------|
| Generic mod DB | `data/mods.gd` | `requires` tag on every entry |
| Class mod DB | `data/class_mods.gd` | **new** registry + `ids_for_kit()` |
| Resolver | `data/mod_applicability.gd` | **new** — caps, applicability, droppable pool, unified `get_mod` |
| Kit build seam | `data/factories/class_mod_factory.gd` | **new** — the one apply seam |
| Combo install | `scripts/entities/player.gd::_load_combo` | apply class mods; strip `classmod_` on rebuild |
| Loot roll | `scripts/main_arena.gd::_spawn_mod_drop` | draw from `droppable_pool(current char)` |
| Mod pickup | `scripts/pickups/mod_pickup.gd` | unified name/tint lookup; class mods bag (never auto-equip to a weapon slot) |
| Inventory + class loadout | `scripts/managers/progression_manager.gd` | `character_mods` dict; `get/set/remove_character_mod`, `get_active_class_mods`, `class_mod_slots` |
| Armory | `scripts/ui/hub_armory_panel.gd` | class-mod card + inline picker; grey inapplicable generics; hide class mods from the weapon picker |
| Insurance | `scripts/ui/insurance_panel.gd` | already ID-based (`"[Mod] " + id`) — class mods flow through unchanged |
| Save/load | `scripts/managers/progression_manager.gd` | `character_mods` saved; defensive `.get(...,{})` — pre-task-31 saves load clean |

**Loot.** Drop rolls draw from `ModApplicability.droppable_pool(selected_character)` = applicable
generics **+** this class's class mods. An unusable mod can never drop mid-run.

**Inventory.** `owned_mods` stays a single flat list holding **both** kinds of mod (just IDs), so the
collect → extract-commit → insurance flow is unchanged. Generic mods equip into `weapon_mods[weapon_id]`
(existing). Class mods equip into `character_mods[char_id]` (new) — per-character, so switching
character keeps loadouts isolated.

**Slots.** `ProgressionManager.class_mod_slots()` = **2** for now (flat). Task 34's class-gear rarity
is slated to drive this later; kept behind a function so callers don't hardcode.

**Codex / combo matrix.** Class mods **do not** participate in the 69-pair elemental combo matrix.
They never enter `weapon_mods`, so `CodexManager` discovery (`_discover_combos_for_weapon`,
`get_combos_for_mod_pair`, `required_mods`) is untouched and cannot regress. Cross-layer synergies are
reserved as future space (§6).

---

## 5. Pilot — Fighter (implemented + smoke-tested)

Two class mods, end-to-end (data → drop pool → armory equip → build-time kit mutation), tied to real
Fighter kit nodes:

| Mod | Node | Op | Effect |
|-----|------|----|--------|
| **OVERCHARGED CATACLYSM** | Cataclysm (light phase 4 **and** heavy phase 1) | `scale_aoe` | ×1.35 damage, ×1.40 radius. Verified: r 55→77, dmg 19.8→26.7 on both graphs. |
| **TEMPEST VORTEX** | Tempest (light finisher) | `add_pull` | Appends a `toward_source` displacement — drags enemies into the blade. Verified: Tempest gains the pull effect, `destination = toward_source`. |

Smoke test (editor) confirmed: Fighter applicable generics = `[lifesteal, crit_amp, instability_siphon]`;
droppable pool adds both pilots; both mutations land on the freshly-built kit. **In-run visual (the
crater size + the suck-in) needs Ben's eyes in a live run** — the data path is proven, the felt result
is a playtest check.

---

## 6. Future space (noted, not built)
- Route generic elemental/DoT/size mods into **melee combo hits** so melee kits benefit from the
  generic layer too (would widen every melee kit's generic pool).
- **Cross-layer synergies** (a class mod that reacts to an equipped generic elemental) — would extend
  the codex matrix; deliberately out of v1 to keep the 69 pairs intact.
- Class-mod **rarity** + gear sockets (task 34) feeding `class_mod_slots()`.

---

## 7. Per-class class mods — **all shipped** (was: task 32 content proposal)

3–4 per class, each tied to a **real** kit node (read from `ChainFactory`/`SkillFactory`). "Op" is the
`ClassModFactory` operation it would use (new ops flagged **†** — small additions to the factory
`match`). Default drop source: **drops while playing that class**; a couple are flagged as
merchant/boss-tier.

### The Sellsword — Fighter  *(4 shipped)*
| Mod | Node | Op | Shipped |
|-----|------|----|---------|
| Overcharged Cataclysm ✅ | Cataclysm (both graphs) | scale_aoe | ×1.35 dmg / ×1.4 radius |
| Tempest Vortex ✅ | Tempest (light) | add_pull | drags enemies into the blade |
| Sustained Whirlwind ✅ | Swirl+Whirlwind (light, anim:"swirl") | scale_aoe | ×1.4 radius |
| Concussive Taunt ✅ | Taunt (channel) | add_status | applies Chilled (−30% move speed) |

### The Warden — Paladin  *(4 shipped)*
| Mod | Node | Op | Shipped |
|-----|------|----|---------|
| Thunderous Bash ✅ | Shield Bash (both graphs) | scale_aoe | ×1.35 radius / ×1.25 dmg |
| Blessed Hammer Storm ✅ | Holy Hammer | scale_aoe | ×1.40 dmg |
| Dictum's Reach ✅ | Blades of Justice (dictum) | scale_aoe | ×1.45 radius |
| Retribution Dome ✅ | Dome of Rightfulness (channel) | add_status | Ignites each retribution tick |

### The Whisper — Ninja  *(4 shipped)*
| Mod | Node | Op | Shipped |
|-----|------|----|---------|
| Bleeding Blades ✅ | All light phases | add_status | Bleed on every cut including blade storm |
| Endless Storm ✅ | Thousand Blades Storm (channel, anim:"blades") | scale_aoe | ×1.5 radius |
| Honed Edge ✅ | — (modifier) | modifier | +12% crit_chance while equipped |
| Choking Smoke ✅ | — (modifier) | modifier | −12% damage_taken while equipped |

### The Devout — Cleric  *(4 shipped)*
| Mod | Node | Op | Shipped |
|-----|------|----|---------|
| Purifying Fire ✅ | Divine Fire bolt (anim:"divine_fire") | scale_aoe | ×1.35 projectile dmg |
| Words of Agony ✅ | Word of Pain zone (anim:"pray_pain") | scale_aoe | ×1.5 zone radius |
| Radiant Smite ✅ | Smite (anim:"attack") | scale_aoe | ×1.25 dmg |
| Greater Sanctuary ✅ | — (modifier) | modifier | −15% damage_taken while equipped |

### The Verdant — Druid  *(4 shipped)*
| Mod | Node | Op | Shipped |
|-----|------|----|---------|
| Savage Maul ✅ | Beast Maul (anim:"beast_attack") | scale_aoe | ×1.3 radius / ×1.25 dmg |
| Diving Owl ✅ | Owl Swoop (anim:"owl_attack") | scale_aoe | ×1.4 radius |
| Strangling Roots ✅ | Root Summoning zone (heavy, anim:"root_cast") | scale_aoe | ×1.5 zone radius |
| Pack Leader ✅ | Hound Frenzy (channel) | scale_aoe | ×1.35 radius / ×1.2 dmg |

### The Shade — Rogue  *(4 shipped)*
| Mod | Node | Op | Shipped |
|-----|------|----|---------|
| Serrated Shuriken ✅ | Shuriken Fan (anim:"fan") | add_projectile_status | Bleed on each shard |
| Bigger Bomb ✅ | Bomb (anim:"bomb") | scale_aoe | ×1.4 radius / ×1.35 dmg |
| Twin Fan ✅ | Fan of Blades (channel, anim:"fan") | scale_aoe | ×1.45 radius |
| Deep Cuts ✅ | — (modifier) | modifier | +12% crit_chance while equipped |

### The Scavenger — Ranger  *(5 shipped)*
| Mod | Node | Op | Shipped |
|-----|------|----|---------|
| Barbed Arrows ✅ | All light-chain projectiles | add_projectile_status | Bleed on every arrow |
| Impaling Knife ✅ | Throwing Knife (anim:"knife") | scale_aoe | ×1.5 projectile dmg |
| Explosive Tips ✅ | Triple Shot (anim:"triple_shot") | add_projectile_status | Ignites each arrow hit |
| Ghost Step ✅ | — (modifier) | modifier | +15% move_speed while equipped |
| **Split Quiver** ✅ | — (routing) | kit_flag | Quiver stance rides the light chain too, and each armed arrow carries the off-hand element under its own — a Fire arrow lands Chilled then Burning and trips Frostfire on its own hit |

### The Spark — Wizard  *(4 shipped)*
| Mod | Node | Op | Shipped |
|-----|------|----|---------|
| Fireball: Scorched Earth ✅ | Fireball Release (anim:"fireball_2") | add_projectile_status | Ignites each fireball hit |
| Overload Bolts ✅ | All light-chain phases | scale_aoe | ×1.3 projectile + fireball dmg |
| Torrent Surge ✅ | Fire Torrent (channel, anim:"torrent") | scale_aoe | ×1.5 AoE radius |
| Ember Familiar ✅ | — (modifier) | modifier | +15% damage while equipped |

### The Cursed — Blood Mage  *(4 shipped)*
| Mod | Node | Op | Shipped |
|-----|------|----|---------|
| Hemorrhage Shards ✅ | Blood Shards volley (anim:"shards") | add_projectile_status | Bleed on each shard |
| Deeper Pact ✅ | — (modifier) | modifier | +20% damage while equipped |
| Bloodquake ✅ | Blood Spikes (anim:"spikes") | scale_aoe | ×1.45 radius / ×1.2 dmg |
| Sanguine Drain ✅ | — (modifier) | modifier | +18% damage (increases Vampirize yield host-side) |

### The Herald — Bard  *(4 shipped)*
| Mod | Node | Op | Shipped |
|-----|------|----|---------|
| Piercing Chord ✅ | Dissonant Chord (anim:"chord") | scale_aoe | ×1.35 projectile dmg |
| Cruel Mockery ✅ | Vicious Mockery (anim:"mockery") | scale_aoe | ×1.35 radius / ×1.2 dmg |
| Rousing Ballad ✅ | — (modifier) | modifier | +15% damage while equipped |
| Encore ✅ | Apotheosis (anim:"apotheosis") | scale_aoe | ×1.5 radius / ×1.25 dmg |

### The Ravager — Barbarian  *(4 shipped)*
| Mod | Node | Op | Shipped |
|-----|------|----|---------|
| Earthsplitter ✅ | Sunder (both graphs) | scale_aoe | ×1.45 radius / ×1.25 dmg |
| Chained Lightning ✅ | Thunder Blade (anim:"thunder") | scale_aoe | ×1.4 dmg (melee AoE + bolt) |
| Iron Wall ✅ | — (modifier) | modifier | −18% damage_taken while equipped |
| Deafening Cry ✅ | — (modifier) | modifier | +15% damage while equipped |

### The Deadeye — Gunslinger  *(4 shipped)*
| Mod | Node | Op | Shipped |
|-----|------|----|---------|
| Fan the Hammer +2 ✅ | Fan the Hammer (anim:"fan") | add_projectiles | +2 bullets (5→7) |
| Hollow Points ✅ | All light-chain shots | add_projectile_status | Bleed on every bullet |
| Suppressing Storm ✅ | Desert Storm (channel, anim:"storm") | scale_aoe | ×1.3 bullet dmg per tick |
| Quickdraw ✅ | — (modifier) | modifier | +10% crit_chance while equipped |
