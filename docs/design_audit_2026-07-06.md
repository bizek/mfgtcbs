# Whole-Game Design Audit — 2026-07-06

**Author:** Claude Fable (creative-director hat), at Ben's request: "one last thing Fable can do
to help this game succeed." Scope: the *sum* of the systems, not any one implementation. Every
claim below was verified against the working copy (not docs) on branch `feat/combo-combat-chains`
@ 302c581.

**How to read this:** §1 is the decision list — everything else is the evidence. Each decision
has a deadline expressed as "before task NN" so it slots into the Road to Release plan.

---

## 1. Decision list for Ben

| # | Decision | Recommendation | Decide before |
|---|----------|----------------|---------------|
| D1 | **What are weapons now?** The combo overhaul orphaned the weapon layer (§3) | **RESOLVED 2026-07-06 (Ben) — "class gear" design, see §3.1:** class-locked themed weapons + 2 universal trinket slots, green/blue/purple rarity, smart-loot drop bias toward the current class (purples rare + heavily on-class) | Implemented by **task 34** (new); task 31 depends on it |
| D2 | Evolutions: keep all 12? | Prune to ~6 distinctive ones; kill the redundant pairs (Juggernaut/Fortress are the same recipe twice); class flavor moves to task 33's ability upgrades | Task 33 |
| D3 | Cross-layer name collisions (§4.2) | Rename before they ship together: tree `m_second_wind` vs level-up "Second Wind" (same name, different effects!), tree `m_juggernaut` vs evolution "Juggernaut", tree `f_deadeye` vs The Deadeye | Task 26 |
| D4 | First boot goes hub-first | First boot (no save) should fast-path into a run; introduce the hub AFTER the first death/extraction, when its stations mean something | Task 10 + 16 |
| D5 | Working title "Extraction Survivors" | It describes the formula and has zero identity — pick a real name | Task 25 (store copy locks it) |
| D6 | Hit-stop priority | The juice pass must treat combo-finisher impact as P1, not polish — the finisher payoff IS the pitch (§5) | Task 17 |
| D7 | Death must show what you kept | Run-end screens surface banked passive points + currency ("death is progress") | Task 26 |

Everything not listed here survived the audit: the descent structure, the extraction gamble,
instability/insurance, the combo matrix + Codex + mastery chain, the workshop's QoL-only role,
and the passive tree's permanent-vs-run-scoped split are all coherent. Do not touch them.

---

## 2. The power-layer map

What a player's damage/survivability is assembled from today (live = shipped in the working copy):

| Layer | Scope | Status |
|---|---|---|
| 1. Character base stats + passive | permanent, per-class | live |
| 2. Combo kit (LMB/RMB/Q/E/dash moveset) | per-class | live, all 10 |
| 3. Weapon (damage stat + mod slots) | persistent equipment | live — **but orphaned, §3** |
| 4. Generic weapon mods (15) | persistent loot | live |
| 5. Mod combos (69 pairs, 8 triples) + mastery bonuses | emergent from 4 | live |
| 6. Level-up upgrades (22-entry pool) | run-scoped | live |
| 7. Evolutions (12 recipes) | run-scoped | live |
| 8. Workshop upgrades | permanent QoL/slots | live |
| 9. Research blueprints (expand drop pool) | permanent unlock | live |
| 10. Passive tree (59 nodes) | permanent | speced, tasks 26–28 |
| 11. Class ability mods | persistent loot | speced, tasks 31–32 |
| 12. Class ability level-up upgrades | run-scoped | speced, task 33 |

Twelve layers. That is not automatically a problem — ARPGs live on stacked systems — but it is
a **solo-dev balancing surface** and a **legibility surface**, and both grow multiplicatively.
The audit's job was to find where layers overlap without adding a decision. Findings in §4.

---

## 3. Flagship finding: the combo overhaul orphaned the weapon layer

**Evidence.** All 10 characters carry a `melee_kit`; `player.gd::set_combo_ability` drops weapon
auto-fire for every one of them ("the combo IS the attack"). `WeaponData`'s behavior vocabulary —
projectile / spread / beam / orbit / artillery / melee — **never executes for any playable
character anymore.** The Frost Scattergun's "5-shot cryo cone" identity literally cannot express.
Three characters start with Arcane Blade as a mute stat stick; The Deadeye starts with another
character's signature pistol. Meanwhile whole subsystems still treat weapons as first-class
content: mid-run weapon drops, armory weapon selection, blueprint research that adds *weapons*
to the drop pool, weapon rarity/mod slots, insurance valuation.

**Why it matters for success.** A new player who picks up the Frost Scattergun and sees nothing
change except a damage number has just learned "loot in this game is fake." That single moment
poisons the extraction hook — the whole loop is about loot being worth risking your life for.

**Options.**
- **(A) Reframe:** weapons become stat/element relics (damage, damage type, mod slots) — honest
  UI copy, keep drops. Cheapest, but "a relic that is secretly a shotgun" stays weird.
- **(B) Weapons shape the kit:** equipping a ranged weapon swaps your kit's projectile type /
  a combo node. Deepest, most work, and it dilutes the per-class identity Ben spent three weeks
  building.
- **(C) Signature weapon per class** (recommended): each class OWNS its weapon (Ranger = Hunter's
  Bow, Deadeye = his own sidearm, etc. — finish the set); mid-run *weapon* drops are cut; the
  loot budget shifts to mods, class mods, gold, and blueprint fragments. The player-facing story
  becomes one sentence: **"your class is your weapon; mods are your build."**

**The bonus of (C):** it collapses the two-layer mod model. If the class owns one weapon, then
weapon-mod slots and class-mod slots are the same thing — **one kit mod board** (slots grown via
rarity/workshop), holding generic mods (elemental/behavioral, combo-matrix-eligible) and class
mods (ability-targeting) side by side. Task 31 gets simpler, the armory gets simpler, the player
model gets simpler, and nothing designed is thrown away — WeaponData survives as each class's
signature stat block, and the Research station repurposes to activating mods/class mods into the
drop pool (it mostly is that already).

### 3.1 RESOLUTION (Ben, 2026-07-06): the "class gear" design

Ben's design, superseding options A–C (it is A's honesty + C's class identity + rarity):

- **Weapons are class-locked and themed** — each class has its own weapon line matching its kit
  fantasy; a Barbarian never holds a bow. The existing signature weapons become the green tier.
- **Two universal trinket slots** — class-agnostic stat items; the pressure valve so every drop
  moment has something usable. Gives the Workshop's dormant Artifact Chamber slots a body.
- **Rarity: green / blue / purple** — green = some stats, blue = more stats, purple = stats +
  one unique special effect. Rarity also drives mod-slot count (1/2/3, per the existing design).
- **Smart-loot drop bias** — playing a class significantly biases drops toward it (~75–80%,
  tuning lever); off-class loot still drops. **Purples are rare, and when one drops the on-class
  chance is very high (~90%)** — the jackpot moment is engineered to be an immediate hit.
- **Off-class drops are cargo, not misses** — they bank to that character's per-character stash
  (loadouts are already per-character); the roster panel badges characters with new gear waiting.
  This creates a character-unlock pull the roster ladder lacked.
- **Honesty rules preserved:** item cards show real stats (≤3 lines + unique line at 3× scaling);
  weapon damage type tints combo FX so pickups visibly change the attack; dead behavior fields
  (spread/orbit/artillery/beam) are retired from player-facing data; purple uniques are built
  ONLY from existing status/trigger/modifier machinery.

Why this passes the audit's test: rarity color is pre-verbal loot valuation — it makes the
bank-or-dive decision and insurance sharper, not weaker. Smart-loot makes drops feel personal.
Class-locking restores weapon identity without touching kit structure.

**Consequences for the plan:** new task 34 (class gear & rarity system) runs after 30 and
before 31; the two-layer mod model in 31 STANDS (weapons remain mod carriers, class mods remain
their own family); Research/blueprints repurpose to activating higher-tier gear into the pool.

---

## 4. Layer collisions (evidence for D2/D3)

### 4.1 Same effect, four+ places
- **Sustain:** Bloodthirst (level-up, heal on kill) · Vampiric Blade (evolution) · Lifesteal
  (mod) · `a_siphon` (tree) · `m_bloodletter` (tree, heal on kill). Five sources whose stacking
  the player cannot predict.
- **Crit:** 3 character passives + 2 level-ups + 3 evolutions + crit_amp mod + 7 tree nodes.
- **On-crit procs:** static_discharge (level-up) · lightning_reflexes (evolution) ·
  `a_ignition` (tree).
- **Verdict:** the *permanent (tree) vs run-scoped (level-up) vs equipment (mod)* split is a
  defensible mental model — keep it — but within the run-scoped layer, evolutions duplicate
  level-ups (Juggernaut/Fortress are both `max_hp+armor`). Prune evolutions (D2) and, in task 18,
  budget sustain globally: decide the max heal-per-second a full sustain stack may reach and tune
  the five sources against that number, not individually.

### 4.2 Name collisions (D3 — fix before the tree ships)
- "Second Wind": level-up status (on dodge, heal 3%) AND tree `m_second_wind` (below 30% HP,
  +25% move speed). Same name, different effects, both visible to one player. Rename the tree node
  (e.g. "Adrenaline Surge").
- "Juggernaut": evolution AND tree `m_juggernaut`. Rename one.
- "Deadeye": tree `f_deadeye` AND The Deadeye (character). Rename the node (e.g. "Steady Aim").

### 4.3 Doc drift found in passing
- `hub_reference.md` says the Codex panel isn't built — it is (`codex_grid_panel.gd`); same for
  insurance. Update when the hub next changes.
- XP target says 15–20 level-ups/run; the passive-tree spec assumes 8–15. Reconcile in task 18
  (whichever is true after the pacing pass drives passive-point income).

---

## 5. First-ten-minutes teardown

The path today (menu doesn't exist yet): boot → hub → find Launch Pad → descend as Sellsword.

1. **Boot → hub is a cold open (D4).** A new player lands in a room of 7+ stations with nothing
   to spend and nothing unlocked. Every station is noise until the first run ends. Fast-path the
   first boot into a run; walk them into the hub afterward, when passive points, loot, and unlock
   currency make every station self-explanatory. This is a boot-flow branch in task 10 plus copy
   in 16 — small change, outsized retention effect.
2. **Minute one must prove "this is not an auto-fire game."** The Sellsword's tap-chain works,
   but the *sell* is the finisher landing in a crowd. Two cheap levers: (a) task 17 makes
   combo-finisher hit-stop/shake a P1 requirement (D6) — currently it lists crits and boss kills
   only; (b) the first block guarantees one tight pack in the opening 30 seconds that a
   Swirl→Tempest visibly deletes — one block-compiler spawn-zone tweak, no new systems.
3. **The methodical pace must read as *weighty*, not *slow*.** After pacing pass 2 the player
   walks 53–68 px/s. The difference between "deliberate" and "sluggish" is entirely feedback
   (juice pass) and threat readability (already good post-rebalance). Watch this axis in the
   first friend playtest — it is the single biggest feel risk of the pacing direction.
4. **First death must teach the loop (D7).** The extraction fantasy has two halves: "I banked my
   loot" and "even my death fed the tree." The game-over screen should show banked passive
   points + kept currency the moment task 26 ships. If death feels like a rogue-lite reset with
   paperwork, the genre promise breaks.
5. **Instability** is the run's risk dial but is nearly invisible to a new player (Cursed starts
   "Unsettled" — a word with no anchor yet). Not a cut — a legibility item: the first time
   instability rises, one onboarding cue (task 16) names it and points at the meter.

---

## 6. The one-sentence test

Working pitch (use in task 25, the trailer, and every description):

> **"Pick a hero with a real combo kit, carve through the horde, and decide at every portal:
> bank your loot, or dive deeper."**

Positioning: *a horde survivor where you actually fight* — Hades-adjacent combat feel ×
Vampire Survivors density × extraction stakes. Every system either serves that sentence or
should justify itself against it. Applying the test: class kits ✓ · descent/portals ✓ ·
mods/combos ✓ (the "build" you risk) · passive tree ✓ (the "always progress" consolation) ·
mid-run weapon drops ✗ (§3) · generic evolutions ~ (D2).

**D5:** "Extraction Survivors" fails the sentence — it names the formula, not the fantasy, and
is unsearchable next to genre giants. Naming needs a dedicated session with Ben before task 25;
the descent fiction (depth, the Heart, instability) is the richest vein.

---

## 7. What this changes in the plan

- **Task 31 blocked on D1** (annotated in the prompt). If Ben picks (C), 31's design space
  shrinks pleasantly: one mod board, one applicability model, Research repurposed.
- Task 33 executes D2 (evolution prune) alongside its existing scope.
- Task 26 executes D3 renames + D7 run-end display.
- Task 10/16 execute D4; task 17 executes D6; task 16 adds the instability cue (§5.5).
- Task 25 waits on D5 and uses §6 verbatim as its positioning input.
- No new implementation prompts are needed — the audit lands as inputs to existing ones, which
  was the goal.
