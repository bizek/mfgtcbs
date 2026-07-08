# Class Mod System — Two-Layer Mod Model

**Status:** Architecture + plumbing implemented (task 31). Fighter pilot live. **This doc needs Ben's
redline before task 32 authors the full per-class content.**

Locked with Ben 2026-07-06. This is the design-of-record for how mods/upgrades match the per-class
combo kits. Task 32 = author all class-mod content. Task 33 = apply the same applicability model to
level-up choices.

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
  op,                       # scale_aoe | add_pull | add_status | modifier
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

## 7. Per-class proposed class mods — **FOR BEN'S REDLINE** (content = task 32)

3–4 per class, each tied to a **real** kit node (read from `ChainFactory`/`SkillFactory`). "Op" is the
`ClassModFactory` operation it would use (new ops flagged **†** — small additions to the factory
`match`). Default drop source: **drops while playing that class**; a couple are flagged as
merchant/boss-tier.

### The Sellsword — Fighter  *(2 shipped as pilot)*
| Mod | Node | Op | Sketch |
|-----|------|----|--------|
| Overcharged Cataclysm ✅ | Cataclysm | scale_aoe | ×1.35 dmg / ×1.4 radius (shipped) |
| Tempest Vortex ✅ | Tempest | add_pull | drag enemies into the finisher (shipped) |
| Sustained Whirlwind | Whirlwind (held) | scale_aoe | +40% Whirlwind tick radius — the spin-to-win option |
| Concussive Taunt | Taunt channel | add_status† (stagger/slow) | shockwave ticks also slow the ring |

### The Warden — Paladin
| Mod | Node | Op | Sketch |
|-----|------|----|--------|
| Thunderous Bash | Shield Bash | scale_aoe + tune shove | bigger shove distance + hit |
| Blessed Hammer Storm | Holy Hammer | scale_aoe | +damage on the hammerdin slam |
| Dictum's Reach | Blades of Justice (dictum) | scale_aoe | wider orbiting-blade tick |
| Retribution Dome | Dome of Rightfulness | add_status† (burn) | dome retribution also Ignites |

### The Whisper — Ninja
| Mod | Node | Op | Sketch |
|-----|------|----|--------|
| Bleeding Blades | Slash / Slash II | add_status (bleed) | the quick slashes apply Bleed |
| Endless Storm | Thousand Blades (Storm) | scale_aoe | +radius on the blade nova |
| Honed Edge | (Q Sharpen) | modifier | Sharpen grants a larger/longer crit buff |
| Choking Smoke | (E Smoke Bomb) | add_status† | Smoke also blinds/slows enemies caught in it |

### The Devout — Cleric
| Mod | Node | Op | Sketch |
|-----|------|----|--------|
| Purifying Fire | Divine Fire (bolt) | scale_aoe / add_status | holy bolt hits harder / Ignites |
| Words of Agony | Word of Pain (zone) | scale_aoe† (zone radius) | wider, longer curse zone |
| Radiant Smite | Smite / Smite II | scale_aoe | heavier opening smites |
| Greater Sanctuary | (Q Sanctuary) | modifier | Sanctuary heal/def buff is stronger |

### The Verdant — Druid
| Mod | Node | Op | Sketch |
|-----|------|----|--------|
| Savage Maul | Beast Maul | scale_aoe + shove | bigger maul + harder shove |
| Diving Owl | Owl Swoop | scale_aoe | wider swoop arc |
| Strangling Roots | Root Summoning (zone) | scale_aoe† / add_status | roots snare harder / longer |
| Pack Leader | Hound Frenzy | scale_aoe | faster/bigger hound bites |

### The Shade — Rogue
| Mod | Node | Op | Sketch |
|-----|------|----|--------|
| Serrated Shuriken | Shuriken Fan | add_status (bleed) | the fan applies Bleed |
| Bigger Bomb | Bomb | scale_aoe + blast tune | ×dmg / ×radius on the lob |
| Twin Fan | Fan of Blades (channel) | scale_aoe | wider channel tick |
| Deep Cuts | Slash / Slash II | modifier | +crit while the light chain is running |

### The Scavenger — Ranger
| Mod | Node | Op | Sketch |
|-----|------|----|--------|
| Barbed Arrows | Shot/Double/Triple | add_status (bleed) | volleys apply Bleed |
| Impaling Knife | Throwing Knife | scale_aoe | heavier skewer |
| Explosive Tips | Triple Shot | add_status† / scale_aoe | fan finisher gains a small blast |
| Ghost Step | Conceal (channel) | modifier | longer/faster conceal refresh |

### The Spark — Wizard
| Mod | Node | Op | Sketch |
|-----|------|----|--------|
| Fireball: Scorched Earth | Fireball Release | add_status† (ground fire) | fireball leaves burning ground |
| Overload Bolts | Bolt A / Bolt B | scale_aoe | punchier tap bolts |
| Torrent Surge | Fire Torrent (channel) | scale_aoe | wider flame cone |
| Ember Familiar | (RMB Summon Fire Familiar) | modifier | tougher/stronger familiar |

### The Cursed — Blood Mage
| Mod | Node | Op | Sketch |
|-----|------|----|--------|
| Hemorrhage Shards | Blood Shards volley | add_status (bleed) | shards apply Bleed |
| Deeper Pact | Extract Power | modifier | bigger damage buff per pact |
| Bloodquake | Blood Spikes | scale_aoe | wider spike burst |
| Sanguine Drain | Vampirize (channel) | modifier | more heal per drain beat |

### The Herald — Bard
| Mod | Node | Op | Sketch |
|-----|------|----|--------|
| Piercing Chord | Dissonant Chord | scale_aoe | louder sound-bolt |
| Cruel Mockery | Vicious Mockery | scale_aoe / stronger debuff | wider insult, deeper damage-down |
| Rousing Ballad | Perform: Ballad | modifier | stronger per-beat heal |
| Encore | Apotheosis | scale_aoe | bigger divine burst |

### The Ravager — Barbarian
| Mod | Node | Op | Sketch |
|-----|------|----|--------|
| Earthsplitter | Sunder | scale_aoe + shove | wider ground-break + harder shove |
| Chained Lightning | Thunder Blade (bolt) | scale_aoe | fatter lightning bolt |
| Iron Wall | Guard (channel) | modifier | wider block arc / brief thorns |
| Deafening Cry | (Q Battle Cry) | modifier | stronger/longer fury + shaken |

### The Deadeye — Gunslinger
| Mod | Node | Op | Sketch |
|-----|------|----|--------|
| Fan the Hammer +2 | Fan the Hammer | scale_aoe / +bullets† | more/heavier bullets in the fan |
| Hollow Points | Shot / Shot II | add_status† (bleed) | bullets cause Bleed |
| Suppressing Storm | Desert Storm (channel) | scale_aoe | wider bullet cone |
| Quickdraw | (Q Reload) | modifier | Reload grants a brief fire-rate/damage buff |

**Notes for redline:** ops marked **†** need a small `ClassModFactory` addition (ground-zone spawn,
extra-bullet count, generic status-on-hit for melee) — cheap, all data-driven. Ben to redline names,
which nodes to touch, and rough magnitudes before task 32 mass-produces the content + numbers.
