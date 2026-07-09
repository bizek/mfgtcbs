class_name ClassModData

## ClassModData — Static database of CLASS mods: the second layer of the two-layer mod model
## (task 31, docs/class_mod_system.md). Where ModData mods tune the (generic) weapon, class mods
## reshape a specific class's COMBO KIT — a combo node, the RMB special, a Q/E skill, or the dash.
##
## Data only, zero behavior (CLAUDE.md). ClassModFactory reads these and mutates the kit
## AbilityDefinitions at build time (player._load_combo). Each entry:
##   id      — unique mod id (also the owned_mods / drop id)
##   name    — display name (armory / pickups)
##   kit     — CharacterData "melee_kit" this mod belongs to (gates applicability + drops)
##   desc    — player-facing text
##   color   — pickup beam / armory tint
##   target  — { "graph"?: "light"|"heavy"|"channel"|"skill_q"|"skill_e"|..., "anim": "<phase anim>" }
##             graph is optional; when omitted the op applies to every graph in the kit. anim is
##             matched against ChoreographyPhase.animation, so a mod can hit a node wherever it
##             appears (e.g. Cataclysm lives in both the light and heavy graphs).
##   op      — how ClassModFactory applies it (see that factory's match):
##             "scale_aoe"   — multiply the matched phase's AreaDamageEffect radius / damage
##             "add_pull"    — append a toward-player DisplacementEffect (suck enemies in)
##             "add_status"  — append an ApplyStatusEffectData (StatusFactory id in params.status)
##             "modifier"    — kit-agnostic player ModifierDefinition while equipped (no target)
##   params  — op-specific numbers
##
## NOTE (v1): class mods deliberately do NOT participate in the generic elemental combo matrix
## (the 69 pairs in ModComboFactory / Codex). They never enter weapon_mods, so codex discovery
## is untouched. Cross-layer synergies are reserved as future space (see design doc).

const ALL: Dictionary = {
	## ── Fighter (The Sellsword) — PILOT (task 31). Task 32 authors the rest of the roster. ──
	"fighter_overcharged_cataclysm": {
		"id": "fighter_overcharged_cataclysm",
		"name": "OVERCHARGED CATACLYSM",
		"kit": "fighter",
		"desc": "Cataclysm lands 35% harder across a 40% wider crater.",
		"color": Color(1.0, 0.55, 0.15),
		"target": { "anim": "cataclysm" },   ## both the light (phase 4) and heavy (phase 1) finishers
		"op": "scale_aoe",
		"params": { "radius_mult": 1.4, "damage_mult": 1.35 },
	},
	"fighter_tempest_vortex": {
		"id": "fighter_tempest_vortex",
		"name": "TEMPEST VORTEX",
		"kit": "fighter",
		"desc": "Tempest becomes a vortex — enemies are dragged into the blade before it hits.",
		"color": Color(0.55, 0.75, 1.0),
		"target": { "graph": "light", "anim": "tempest" },
		"op": "add_pull",
		## distance is a CEILING — the displacement clamps to the actual gap to the player so it
		## never overshoots. Keep it well past the combo's catch radius (~90px * reach) so every
		## caught enemy is dragged the whole way IN to the blade, not a fixed short hop.
		"params": { "distance": 260.0, "duration": 0.16, "arc_height": 4.0 },
	},
}


## Stable display order per kit (armory / pickers). Only ids present here appear in the class-mod
## drop pool and armory list — mirrors ModData.ORDER excluding hidden/unique entries.
const ORDER: Array = [
	"fighter_overcharged_cataclysm",
	"fighter_tempest_vortex",
]


## All class-mod ids bound to a kit, in ORDER.
static func ids_for_kit(kit_id: String) -> Array:
	var out: Array = []
	for mod_id: String in ORDER:
		if ALL.get(mod_id, {}).get("kit", "") == kit_id:
			out.append(mod_id)
	return out
