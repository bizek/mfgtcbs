---
tags: [design, weapons, mods, upgrades, reference]
---

# Weapon Scaling Reference

Two independent scaling axes: **Level-Up Upgrades** (player-wide stat boosts) and **Weapon Mods** (per-weapon behavior changes). Both affect every weapon, but mods interact differently depending on weapon behavior type.

---

## Weapons at a Glance

| Weapon | Behavior | Damage Type | Mod Slots | Notes |
|---|---|---|---|---|
| Hurled Steel | projectile | physical | 2 | Starter, never drops |
| Frost Scattergun | spread | cryo | 2 | 5 projectiles per shot |
| Ember Beam | beam | fire | 1 | 12 ticks/sec, 72 DPS base |
| Lightning Orb | orbit | shock | 1 | 3 orbiting orbs, passive |
| Void Mortar | artillery | void | 2 | 1s fuse, 64px AoE |
| Arcane Blade | melee | physical | 2 | 200° arc, 2.5 swings/sec — scales with mods |
| Warden's Repeater | projectile | physical | 2 | Slow, heavy — char exclusive |
| Spark's Pistol | projectile | physical | 1 | 2 shots/sec — char exclusive |
| Herald's Call | projectile | physical | 1 | Weak auto — char exclusive |

---

## Weapon × Mod Synergy

**Key:** ⭐ great synergy · ✓ works fine · ~ weak/marginal · — doesn't apply

| Mod | Hurled Steel | Scattergun | Ember Beam | Lightning Orb | Void Mortar | Arcane Blade | Repeater | Spark's | Herald's |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **PIERCE** | ⭐ | ~ | — | — | — | — | ⭐ | ✓ | ✓ |
| **CHAIN** | ✓ | ~ | ✓ | ✓ | ~ | ✓ | ⭐ | ✓ | ✓ |
| **EXPLOSIVE** | ✓ | ⭐ | — | — | ~ | ~ | ⭐ | ✓ | ~ |
| **FIRE** | ✓ | ✓ | ~ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **CRYO** | ✓ | ~ | ✓ | ✓ | ⭐ | ⭐ | ⭐ | ✓ | ✓ |
| **SHOCK** | ✓ | ✓ | ✓ | ~ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **LIFESTEAL** | ✓ | ⭐ | ⭐ | ✓ | ~ | ⭐ | ✓ | ⭐ | ~ |
| **SIZE** | ✓ | ⭐ | ~ | ⭐ | ⭐ | ⭐ | ✓ | ✓ | ✓ |
| **CRIT AMP** | ✓ | ✓ | ✓ | ✓ | ⭐ | ⭐ | ⭐ | ✓ | ~ |
| **INSTABILITY SIPHON** | ✓ | ⭐ | ✓ | ✓ | ✓ | ✓ | ✓ | ⭐ | ~ |
| **SPLIT** | ⭐ | ~ | — | — | — | — | ⭐ | ✓ | ✓ |
| **GRAVITY** | ⭐ | ~ | — | — | — | — | ⭐ | ✓ | ✓ |
| **RICOCHET** | ⭐ | ~ | — | — | — | — | ⭐ | ✓ | ✓ |
| **ACCELERATING** | ✓ | ✓ | ⭐ | ~ | — | ⭐ | ~ | ⭐ | ~ |
| **DOT APPLICATOR** | ✓ | ⭐ | ⭐ | ✓ | ~ | ⭐ | ✓ | ⭐ | ✓ |
| **MULTISHOT** | ✓ | ~ | ⭐ | ~ | ~ | — | ✓ | ✓ | ✓ |
| **NAPALM** | — | — | ⭐ | — | — | — | — | — | — |

> **Notes on — ratings:**
> - PIERCE / SPLIT / GRAVITY / RICOCHET only work on projectile-type weapons
> - EXPLOSIVE requires an impact point; beam/orbit/melee don't have one
> - NAPALM is functionally Ember Beam-exclusive (scorches beam path)
> - ACCELERATING requires sustained fire; artillery's slow fuse cycle doesn't benefit

---

## Level-Up Upgrade Pool

All upgrades are **player-wide** — they affect every weapon equally.

### Base Upgrades (17)

| ID | Display Name | Effect | Category |
|---|---|---|---|
| `damage_up` | Damage Up | +20% Damage | Offense |
| `crit_chance_up` | Critical Strike | +5% Crit Chance | Offense |
| `crit_damage_up` | Critical Power | +25% Crit Damage | Offense |
| `attack_speed_up` | Attack Speed Up | +15% Attack Speed | Offense |
| `projectile_count_up` | Multi Shot | +1 Projectile | Offense |
| `pierce_up` | Pierce | +1 Pierce | Offense |
| `projectile_size_up` | Bigger Shots | +25% Projectile Size | Offense |
| `max_hp_up` | Max HP Up | +20 Max HP | Defense |
| `armor_up` | Armor Up | +3 Armor | Defense |
| `move_speed_up` | Speed Up | +15% Move Speed | Utility |
| `pickup_radius_up` | Magnetism | +30% Pickup Radius | Utility |
| `bloodthirst` | Bloodthirst | On Kill: Heal 5% Max HP | Passive |
| `static_discharge` | Static Discharge | On Crit: Lightning AoE | Passive |
| `serrated_strikes` | Serrated Strikes | Hits apply Bleed | Passive |
| `adrenaline_rush` | Adrenaline Rush | On Kill: +25% Speed (3s) | Passive |
| `thorns_passive` | Thorns | Reflect 8 dmg when hit | Passive |
| `second_wind` | Second Wind | On Dodge: Heal 3% Max HP | Passive |

### Evolution Upgrades (11)

Evolutions replace their prerequisites when unlocked and appear as a guaranteed choice once requirements are met.

### Offense

```mermaid
flowchart TD
    damage_up["Damage Up · +20% DMG"] --> glass_cannon
    crit_chance_up["Critical Strike · +5% Crit"] --> glass_cannon
    crit_chance_up --> assassin
    crit_damage_up["Critical Power · +25% Crit DMG"] --> assassin
    crit_damage_up --> titan_rounds
    projectile_size_up["Bigger Shots · +25% Size"] --> titan_rounds
    projectile_count_up["Multi Shot · +1 Projectile"] --> bullet_storm
    attack_speed_up["Attack Speed Up · +15% AtkSpd"] --> bullet_storm
    pickup_radius_up["Magnetism · +30% Pickup"] --> magnetar
    pierce_up["Pierce · +1 Pierce"] --> magnetar

    glass_cannon(["GLASS CANNON\n+40% DMG · +10% Crit · −15 HP"])
    assassin(["ASSASSIN\n+10% Crit · +50% CritDMG · +15% Move"])
    titan_rounds(["TITAN ROUNDS\n+40% Size · +50% Crit DMG"])
    bullet_storm(["BULLET STORM\n+2 Proj · +25% AtkSpd"])
    magnetar(["MAGNETAR\n+50% Pickup · +2 Pierce"])
```

### Defense & Movement

```mermaid
flowchart TD
    max_hp_up["Max HP Up · +20 HP"] --> juggernaut
    armor_up["Armor Up · +3 Armor"] --> juggernaut
    max_hp_up --> fortress
    armor_up --> fortress
    move_speed_up["Speed Up · +15% Move"] --> velocity
    attack_speed_up["Attack Speed Up · +15% AtkSpd"] --> velocity
    move_speed_up --> overdrive
    adrenaline_rush["Adrenaline Rush · Kill → Speed"] --> overdrive

    juggernaut(["JUGGERNAUT\n+40 HP · +5 Armor"])
    fortress(["FORTRESS\n+30 HP · +4 Armor · −10% Move"])
    velocity(["VELOCITY\n+25% Move · +20% AtkSpd"])
    overdrive(["OVERDRIVE\nKill → +40% Speed (4s)"])
```

> `max_hp_up + armor_up` can resolve to either **Juggernaut** or **Fortress** — both are eligible; one is chosen randomly.

### Passives

```mermaid
flowchart TD
    bloodthirst["Bloodthirst · Kill → Heal 5%"] --> vampiric_blade
    serrated_strikes["Serrated Strikes · Hits → Bleed"] --> vampiric_blade
    static_discharge["Static Discharge · Crit → AoE"] --> lightning_reflexes
    second_wind["Second Wind · Dodge → Heal 3%"] --> lightning_reflexes

    vampiric_blade(["VAMPIRIC BLADE\nHits → Bleed · Kill → Heal 8%"])
    lightning_reflexes(["LIGHTNING REFLEXES\nCrit → AoE 20 · Dodge → Heal 5%"])
```

---

## Mod Combo Reference

See [[mod_interaction_matrix]] for all 69 named double-mod combos and 8 legendary triples.
