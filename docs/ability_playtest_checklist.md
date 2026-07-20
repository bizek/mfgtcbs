# Ability Playtest Checklist — All 12 Characters

Source of truth: `data/factories/chain_factory.gd` (combos/channels) + `data/factories/skill_factory.gd`
(Q/E skills) + `data/characters.gd` (dash styles). This is what SHOULD happen. Fill in **Observed**
under each ability with what actually happens, then we reconcile.

**Terminology / inputs:**
- **Light** = LMB tap chain. **Heavy** = RMB tap chain. **Channel** = RMB hold. Some kits also have
  a **hold-LMB** branch.
- × numbers are multipliers on the weapon's base damage. r = base hit radius in px (scales with
  melee_range stat, capped at 2×).

**Shared timing rules (apply everywhere):**
- Chain cancel/buffer window: **0.75s** from phase entry. Tap within it → next phase. Let it lapse →
  chain ends (combo meter exhale).
- Heavy follow-up window (RMB → RMB): **0.55s**.
- Hold-LMB branches trigger after holding **0.18s**.
- All channels: player is slowed while channeling; release RMB → channel ends.
- Dash cancels any in-progress combo; grants i-frames + phases through enemy bodies for 0.16s.
- Mid-combo RMB finishers are **gated**: they require chain depth ≥ 2nd phase (pressing RMB on the
  opener does nothing / starts nothing extra).

---

## 1. Sellsword (Fighter)

**Light (LMB):** Attack (0.9×, r28) → Swirl (0.7×, r30) → Tempest (1.05×, r40, finisher) → tap loops
back to Attack.
- Hold LMB during Attack or Swirl → **Whirlwind**: spin ticks 0.30× r30 every 0.22s while held,
  ends on release.
- RMB during Swirl or Tempest → **Cataclysm** (1.8×, r55, terminal).

> Observed:

**Heavy (RMB tap):** Uppercut (0.6×, r35 + arc fling ~88px, i-frame-gated) → RMB again → Cataclysm.

> Observed:

**Channel (RMB hold):** Taunt — shield-hammer loop, 0.5× r46 shockwave every 0.56s.

> Observed:

**Q — Second Wind (CD 12s):** heal 12% max HP + "steeled" −15% damage taken for 4s.
*(2026-07-20: re-bodied — slow sword-raise salute + green ring/flash, no more Taunt bang.)*

> Observed:

**E — Shield Rush (CD 8s):** *(2026-07-20: replaced Blade Flurry)* shield-first charge toward
the cursor — phases through the pack, clips everyone in the corridor (0.9×), yanks them to the
arrival point, then slams (1.1×, r40 + ring).

> Observed:

**Dash:** standard.

> Observed:

---

## 2. Scavenger (Ranger)

**Light (LMB):** Shot (1 arrow, 0.8×) → Double Shot (2 arrows, 0.55× each) → Triple Shot (3-arrow
fan, 0.5× each, finisher) → tap loops back to Shot. All cursor-aimed real projectiles.
- RMB during Double or Triple → **Throwing Knife** (1.2×, pierces 1 enemy, lands with
  knife-on-ground sheet; terminal).

> Observed:

**Heavy (RMB tap):** Melee (0.9×, r26) → Double Melee (1.3×, r30). The "back off" knives.

> Observed:

**Channel (RMB hold):** Conceal — crouch under the cloak; invisible (enemies stop chasing) while
held, refreshed every 0.9s. No damage.

> Observed:

**Q — Skirmisher's Step (CD 10s):** shove nearby enemies + +25% move speed for 4s.
*(2026-07-20: also 1s guaranteed dodge ("SLIPPERY" chip) + refunds one dash charge.)*

> Observed:

**E — Arrow Storm (CD 8s):** 6-arrow fan at the cursor, 0.5× each, wide 44° spread.

> Observed:

**Dash:** standard.

> Observed:

---

## 3. Warden (Paladin)

**Light (LMB):** Strike (1.0×, r30) → Strike II (0.8×, r30) → Shield Bash (0.9×, r34 + shove,
finisher) → tap loops back to Strike.
- Hold LMB during Strike or Strike II → **Blades of Justice**: dictum channel, 0.7× r50 every
  0.75s while held.
- RMB during Strike II or Bash → **Holy Hammer** *(2026-07-20 redesign)*: each RMB press
  throws ONE blessed hammer on its own outward spiral — keep pressing within 0.55s to keep
  throwing; hammers fan around the Warden.

> Observed:

**Heavy (RMB tap):** Shield Bash (0.6× + shove) → RMB again → Holy Hammer (per-press hammers,
as above).

> Observed:

**Channel (RMB hold):** **Reckoning** *(2026-07-20 redesign; tick damage removed same day —
it killed everything before the bubble could soak)* — plant the shield: the dome deals
NOTHING while held; every hit taken is absorbed (gold flash, no HP loss). Release RMB — or
soak 30% max HP, which bursts it — to detonate stored damage ×1.5 in r70 (gold ring).

> Observed:

**Q — Aegis Vow (CD 12s):** heal 10% max HP + "aegis" −20% damage taken for 5s.

> Observed:

**E — Bulwark Slam (CD 6s):** big shield smash, 1.1× r48 + shove.

> Observed:

**Dash:** standard.

> Observed:

---

## 4. Spark (Wizard)

**Light (LMB):** Bolt A ↔ Bolt B alternate on taps (0.75× fast projectile each, cursor-aimed).
- Hold LMB from either bolt → **Charge**: cast anim crawls at 0.3× speed, player slowed. Release →
  **Fireball** scaled by charge time; holding past 1.6s auto-releases at full power. Fireball:
  1.1× direct + 0.9× splash in r34 explosion.

> Observed:

**Heavy (RMB tap):** Summon Fire Familiar — spawns/refreshes the familiar pet + small 0.4× r24
burst on cast.

> Observed:

**Channel (RMB hold):** Fire Torrent — flame pours toward the cursor; 0.55× r30 AoE centered ahead
of you along aim, every 0.67s.

> Observed:

**Q — Mana Surge (CD 10s):** +30% damage for 6s.

> Observed:

**E — Flame Nova (CD 7s):** fire ring, 1.4× r60 + shove. Panic button.

> Observed:

**Dash:** **teleport blink** (not a sprint).

> Observed:

---

## 5. Shade (Rogue)

**Light (LMB):** Slash (0.9×, r26) → Slash II (0.7×, r26) → Shuriken Fan (1.05×, r60, finisher) →
tap loops back to Slash. No hold-LMB branch (Flurry was cut).
- RMB during Slash II or Fan → **Bomb** (lobbed at cursor: 1.8× in small r16 blast — the visual IS
  the hit zone — + 64px knockback; terminal).

> Observed:

**Heavy (RMB tap):** Shuriken Fan (0.6×, r60) → RMB again → Bomb.

> Observed:

**Channel (RMB hold):** Fan of Blades — shuriken loop, 0.5× r60 every 0.5s.

> Observed:

**Q — Vanish (CD 14s):** dodge roll + concealed for 3s (enemies stop chasing; attacking breaks it).

> Observed:

**E — Eviscerate (CD 6s):** vicious close burst, 1.5× in tight r36.

> Observed:

**Dash:** standard.

> Observed:

---

## 6. Herald (Bard)

**Light (LMB):** *(2026-07-20 flow flip: ranged by default)* Chord (0.85× sound-bolt at cursor)
→ Chord II (0.85× bolt) → melee Strike (1.2×, r30, finisher) → tap loops back to Chord.
- RMB during Chord II or Strike → **Apotheosis** (1.6× r60 divine burst + self +20% damage for
  6s; terminal — now at native sprite size + ring, no more pixelation).

> Observed:

**Heavy (RMB tap):** Vicious Mockery (0.6× r70 + "mocked" −20% damage dealt on every enemy hit,
4s) → RMB again → Apotheosis.

> Observed:

**Channel (RMB hold):** Perform — plays the ACTIVE song every 0.8s beat while held:
- **Ballad**: heals per beat (floating notes).
- **Enhancement**: refreshes +15% damage buff (fades ~1.2s after you stop).

> Observed:

**Q — Song cycle (no CD):** toggles Ballad ↔ Enhancement (stance switch, host-side, no cast).

> Observed:

**E — Charming Serenade (CD 12s):** the nearest few enemies are charmed for 5s — they turn and
fight the horde for you (heart wisps).

> Observed:

**Dash:** standard.

> Observed:

---

## 7. Cursed (Blood Mage)

**Light (LMB):** Shard (0.7× blood projectile) → Shard II (0.6×) → Blood Shards volley (3 shards,
0.55× each, narrow cone, finisher) → tap loops back to Shard.
- Hold LMB during Shard or Shard II → **Extract Power**: pays 5% max HP, grants +25% damage for 6s
  (terminal).
- RMB during Shard II or volley → **Summon Blood Elemental** (spawns/refreshes the pet + 0.4× r24
  ignition burst; terminal).

> Observed:

**Heavy (RMB tap):** Blood Slam (1.2×, r42) → RMB again → Blood Spikes (1.7×, r55 ground burst).

> Observed:

**Channel (RMB hold):** Vampirize — two-beat loop every 0.5s: Extract (0.45× r50 damage tick) →
Consume (0.15× r40 + heals you if the extract connected, drain wisps).

> Observed:

**Q — Blood Surge (CD 10s):** +30% damage for 6s — costs 5% max HP (extract cast, blood-price hook
fires).

> Observed:

**E — Blood Eruption (CD 8s):** *(2026-07-20 rework)* ground opens (1.0× r48 + shove) and
STAYS open — a blood pool lingers underfoot for 5s (0.15× bleed per 0.5s); every enemy that
dies inside a pool heals you 3% max HP (drain wisp).

> Observed:

**Dash:** standard.

> Observed:

---

## 8. Ravager (Barbarian)

**Light (LMB):** Cleave (1.0×, r32) → Cleave II (0.8×, r32) → Sunder (1.4×, r48 + shove, finisher)
→ tap loops back to Cleave.
- RMB during Cleave II or Sunder → **Thunder Blade** (1.2× r40 melee + a Lightning bolt projectile
  0.9× at the cursor — always Lightning regardless of weapon element; terminal).

> Observed:

**Heavy (RMB tap):** Sunder (0.7×, r44 + shove) → RMB again → Thunder Blade.

> Observed:

**Channel (RMB hold):** Guard — sword up, feet planted: ALL damage from the frontal arc is blocked
outright while held (BlockImpact flash on every stopped hit). No damage dealt.

> Observed:

**Q — Battle Cry (CD 10s):** +25% damage for 6s + nearby enemies "shaken" (−35% move speed, 3s).

> Observed:

**E — Throw Things (CD 5s):** hurl a slab at the cursor — 1.3× r30 burst at the landing point.

> Observed:

**Dash:** standard.

> Observed:

---

## 9. Whisper (Ninja)

**Light (LMB):** Slash (0.9×, r26) → Slash II (0.7×, r26) → tap loops back to Slash (two-hit loop).
- RMB during Slash II → **Thousand Blades burst**: crouch wind-up (no hit) → blade nova (1.4×,
  r50) → flourish out (0.6×, r40); terminal.

> Observed:

**Heavy (RMB tap):** Thousand Blades burst standalone (same wind-up → nova → flourish trio).

> Observed:

**Channel (RMB hold):** Thousand Blades Storm — crouch intro, then the storm ticks 0.5× r50 every
0.4s while held, flourish out (0.6× r45) on release. The only channel with an intro AND outro.

> Observed:

**Q — Sharpen (CD 12s):** long 27-frame whetstone ritual — +35% damage for 8s lands near the END.
Getting the full ritual off is the skill.

> Observed:

**E — Smoke Bomb (CD 10s):** vanish in the puff — concealed until you attack (8s safety cap).

> Observed:

**Dash:** **Deadly Dash** — strikes enemies along the dash path (ghost trail).

> Observed:

---

## 10. Deadeye (Gunslinger)

**Light (LMB):** Shot ↔ Shot II alternate on taps — one fast near-hitscan bullet each (0.85×,
cursor-aimed, impact burst on landing).
- RMB during Shot II → **Fan the Hammer** (terminal).

> Observed:

**Heavy (RMB tap):** Fan the Hammer — the whole cylinder: 5 bullets, 0.45× each, wide 44° fan, FTH
impact on each landing.

> Observed:

**Channel (RMB hold):** Desert Storm — tight 3-bullet 22° cone toward the cursor, 0.35× each,
every 0.7s, with the directional barrage strip overlay.

> Observed:

**Q — Reload (CD 9s):** long 37-frame cylinder ritual — +30% damage for 6s lands near the END.
Interrupt it and get nothing.

> Observed:

**E — Whip Attack (CD 6s):** tech-whip crack — 1.0× r36 + shove to buy shooting room.

> Observed:

**Dash:** standard.

> Observed:

---

## 11. Verdant (Druid)

**Light (LMB):** Claw (0.9×, r28) → Claw II (0.7×, r28) → tap → **Beast morph** (wind-up, no hit)
→ **Beast Maul** (1.3×, r46 + shove, finisher) → tap loops back to Claw.
- RMB during Claw II or Maul → **Owl morph** (wind-up) → **Owl Swoop** (1.2×, wide r52 rake;
  terminal).

> Observed:

**Heavy (RMB tap):** Root Summoning — roots erupt at the cursor: r40 ground zone for 4s, ticking
every 0.5s: 0.25× damage + "rooted" (−60% move speed, refreshed each tick).

> Observed:

**Channel (RMB hold):** Hound Frenzy — fight as the forest hound: fast 0.4× r30 melee ticks every
0.3s while held.

> Observed:

**Q — Regrowth (CD 12s):** nature mend — heal 15% max HP.

> Observed:

**E — Thornburst (CD 6s):** bramble nova — 1.3× r58 + shove.

> Observed:

**Dash:** standard.

> Observed:

---

## 12. Devout (Cleric)

**Light (LMB):** Smite (0.9×, r30) → Smite II (0.7×, r30) → Divine Fire (1.0× holy bolt projectile
at cursor, Fire damage, impact burst; finisher) → tap loops back to Smite.
- RMB during Smite II or Divine Fire → **Word of Pain** (curse zone at the cursor: r44 for 4s,
  0.3× Fire per 0.5s tick, with the WordOfPain decal; terminal).

> Observed:

**Heavy (RMB tap):** Divine Fire (0.7× bolt) → RMB again → Word of Pain.

> Observed:

**Channel (RMB hold):** Healing Words — pray: heal 4% max HP per 0.9s beat (HealingWords overlay +
sparkles).

> Observed:

**Q — Sanctuary (CD 12s):** heal 12% max HP + "blessed" −20% damage taken for 5s.

> Observed:

**E — Spirit Guardians (CD 14s):** summon the guardian pet + small holy pulse (0.3× r26) on cast.

> Observed:

**Dash:** standard.

> Observed:
