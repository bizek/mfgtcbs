# Hub Reference

The hub is a single room with seven interactive stations. The player walks between them between runs. Getting from "run just ended" to "next run starting" is intentionally fast — under 60 seconds if the player wants to go straight in.

---

## Stations

### Armory
Select starting weapons, weapon mods, and artifacts for the next run. Mods attach to weapons in their mod slots (Common/Uncommon weapons: 1 slot, Rare/Epic: 2 slots, Legendary: 3 slots). This is the primary loadout screen — the combination of weapon + mods defines run identity. Script: `hub_armory_panel.gd`.

### Research Terminal
Spend resources to activate Blueprints, permanently adding new weapons or mods to the run drop pool. Once activated, the item will appear in future drops. Blueprint cost is medium; worthwhile when a weapon or mod suits a planned build direction. Script: `hub_research_panel.gd`.

### Roster
View and unlock characters. The Drifter is the starting character; others are purchased with resources. Each character has a unique starting weapon, a passive ability, and adjusted base stats. No forced unlock order — the player saves toward whichever character interests them. Script: `hub_roster_panel.gd`.

### Workshop
Purchase permanent hub upgrades:

| Upgrade | Effect |
|---------|--------|
| Insurance License | Unlocks the ability to insure one item per run (saved on death). |
| Armory Expansion I | +1 starting weapon slot (start with 2 weapons). |
| Armory Expansion II | +1 starting weapon slot (start with 3 weapons). |
| Artifact Chamber I | Unlock 2nd artifact equipment slot. |
| Artifact Chamber II | Unlock 3rd artifact equipment slot. |
| Reroll Capacity I | +1 level-up reroll per run (2→3). |
| Reroll Capacity II | +1 level-up reroll per run (3→4). |
| Extraction Intel I | Extraction points visible on minimap from further away. |
| Extraction Intel II | Preview which extraction types appear in the next run. |

Script: `hub_workshop_panel.gd`.

### Passives
Spend banked **passive points** into the passive skill tree (Core + Might / Finesse / Arcana branches + 3 bridges). Points are earned per character level gained during a run (banked on both extraction and death). Nodes show name, effect, cost, rank/max, and state — available / locked (tier gate: "REQ N BRANCH") / maxed. Notables (◆) and keystones (★) are visually distinct. Respec is free (`refund_all`). The selected character's affinity branch is subtly highlighted. Reads the `PassiveTreeData` node table and the ProgressionManager passive API; all gate logic lives in ProgressionManager (`node_gate_met` / `node_gate_text`), zero progression logic in the panel. Script: `hub_passives_panel.gd` (code-built panel, reuses `hub_panel_base.tscn`). See `docs/passive_tree_spec.md` and `docs/passive_tree.md`.

### Records
Run statistics and personal bests: runs completed, extractions, deaths, kills, deepest phase reached, loot records. Read-only. Script: `hub_records_panel.gd`.

### Launch Pad
Start the next run. Script: `hub_launch_panel.gd`.

---

## Not Yet Implemented

- **Lore Archive** — planned viewer for lore fragments collected during runs. No script exists.
- **Codex** — planned viewer for mod combo discovery state. `CodexManager` autoload is wired; hub panel not built.
- **Insurance UI** — pre-run item insurance workflow exists in `ProgressionManager`; dedicated hub panel not yet built.
