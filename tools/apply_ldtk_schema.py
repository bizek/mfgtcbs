"""
Apply LDtk schema v1 to existing .ldtk project files.

Idempotent: schema entities/enums/fields preserve existing UIDs across reruns
so placed instances stay linked. Run on a closed .ldtk file (LDtk caches it
in memory and will overwrite our changes if open).

Schema (v1):
  - Enums: ExtractionType, SpawnPhase, SpawnDensity, BiomeId, ObstacleKind,
           MarkerTag, RegionKind, BossId, Facing, TransitionKind
  - Level fields: biome, schema_version (importer-routing essentials only)
  - Entity defs: Level_Instructions (per-level metadata + folded singletons),
                 Extraction, EnemySpawnZone, Obstacle, Marker, Region
  - Removed entities (folded into Level_Instructions): PlayerSpawn, BossSpawn, LevelExit
  - Entities layer (top of stack)
  - IntGrid values 1-5 on the Collision layer

Run:  python tools/apply_ldtk_schema.py "assets/Maps/Levels/Level 1 - Caves.ldtk"
"""

import json
import sys
from pathlib import Path


# ─── UID ALLOCATION ───────────────────────────────────────────────────────────

class UidGen:
    def __init__(self, start: int):
        self.value = start

    def next(self) -> int:
        v = self.value
        self.value += 1
        return v


# ─── ENUM BUILDERS ────────────────────────────────────────────────────────────

def make_enum(identifier: str, values: list[str], uid: int) -> dict:
    return {
        "identifier": identifier,
        "uid": uid,
        "values": [
            {"id": v, "tileRect": None, "color": 0}
            for v in values
        ],
        "iconTilesetUid": None,
        "externalRelPath": None,
        "externalFileChecksum": None,
        "tags": [],
    }


# ─── FIELD DEF BUILDERS ───────────────────────────────────────────────────────

def _base_field(identifier: str, ftype_short: str, uid: int, doc: str = None,
                is_array: bool = False) -> dict:
    """Shared field-def shell. Mirrors LDtk 1.5.3's exact JSON shape — verified against
    a hand-authored field. Order of keys matches LDtk output for clean diffs."""
    return {
        "identifier": identifier,
        "doc": doc,
        "__type": ftype_short,
        "uid": uid,
        "type": f"F_{ftype_short}",
        "isArray": is_array,
        "canBeNull": is_array,
        "arrayMinLength": None,
        "arrayMaxLength": None,
        "editorDisplayMode": "Hidden",
        "editorDisplayScale": 1,
        "editorDisplayPos": "Above",
        "editorLinkStyle": "StraightArrow",
        "editorDisplayColor": None,
        "editorAlwaysShow": False,
        "editorShowInWorld": True,
        "editorCutLongValues": True,
        "editorTextSuffix": None,
        "editorTextPrefix": None,
        "useForSmartColor": False,
        "exportToToc": False,
        "searchable": False,
        "min": None,
        "max": None,
        "regex": None,
        "acceptFileTypes": None,
        "defaultOverride": None,
        "textLanguageMode": None,
        "symmetricalRef": False,
        "autoChainRef": True,
        "allowOutOfLevelRef": True,
        "allowedRefs": "OnlySame",
        "allowedRefsEntityUid": None,
        "allowedRefTags": [],
        "tilesetUid": None,
    }


def field_int(identifier: str, uid: int, default: int = 0, doc: str = None,
              is_array: bool = False) -> dict:
    f = _base_field(identifier, "Int", uid, doc, is_array=is_array)
    if not is_array:
        f["defaultOverride"] = {"id": "V_Int", "params": [default]}
    return f


def field_float(identifier: str, uid: int, default: float = 0.0, doc: str = None,
                is_array: bool = False) -> dict:
    f = _base_field(identifier, "Float", uid, doc, is_array=is_array)
    if not is_array:
        f["defaultOverride"] = {"id": "V_Float", "params": [default]}
    return f


def field_string(identifier: str, uid: int, default: str = "", doc: str = None,
                 is_array: bool = False) -> dict:
    f = _base_field(identifier, "String", uid, doc, is_array=is_array)
    if default and not is_array:
        f["defaultOverride"] = {"id": "V_String", "params": [default]}
    return f


def field_text(identifier: str, uid: int, default: str = "", doc: str = None,
               is_array: bool = False) -> dict:
    """Multi-line string."""
    f = _base_field(identifier, "Text", uid, doc, is_array=is_array)
    if default and not is_array:
        f["defaultOverride"] = {"id": "V_String", "params": [default]}
    return f


def field_bool(identifier: str, uid: int, default: bool = False, doc: str = None,
               is_array: bool = False) -> dict:
    f = _base_field(identifier, "Bool", uid, doc, is_array=is_array)
    if not is_array:
        f["defaultOverride"] = {"id": "V_Bool", "params": [default]}
    return f


def field_enum(identifier: str, uid: int, enum_uid: int, enum_name: str,
               default: str, doc: str = None, is_array: bool = False) -> dict:
    f = _base_field(identifier, f"LocalEnum.{enum_name}", uid, doc, is_array=is_array)
    f["type"] = f"F_Enum({enum_uid})"
    f["__type"] = f"LocalEnum.{enum_name}"
    if not is_array:
        f["defaultOverride"] = {"id": "V_String", "params": [default]}
    return f


def field_point(identifier: str, uid: int, doc: str = None, is_array: bool = False) -> dict:
    """Point field — click a grid cell on the level to set it. LDtk shows a marker
    on the level with a line back to the parent entity."""
    f = _base_field(identifier, "Point", uid, doc, is_array=is_array)
    # Points have no scalar default
    return f


# ─── ENTITY DEF BUILDER ───────────────────────────────────────────────────────

def make_entity(identifier: str, uid: int, *,
                width: int = 16, height: int = 16,
                color: str = "#FFFFFF",
                tags: list[str] = None,
                resizable: bool = False,
                fill_opacity: float = 1,
                line_opacity: float = 1,
                hollow: bool = False,
                pivot_x: float = 0.5, pivot_y: float = 0.5,
                max_count: int = 0,  # 0 = unlimited
                limit_scope: str = "PerLevel",
                doc: str = None,
                field_defs: list[dict] = None) -> dict:
    """Mirrors LDtk 1.5.3's entity def JSON shape exactly. Key order matters only for
    diff cleanliness — LDtk re-serializes on save."""
    return {
        "identifier": identifier,
        "uid": uid,
        "tags": tags or [],
        "exportToToc": False,
        "allowOutOfBounds": False,
        "doc": doc,
        "width": width,
        "height": height,
        "resizableX": resizable,
        "resizableY": resizable,
        "minWidth": None,
        "maxWidth": None,
        "minHeight": None,
        "maxHeight": None,
        "keepAspectRatio": False,
        "tileOpacity": 1,
        "fillOpacity": fill_opacity,
        "lineOpacity": line_opacity,
        "hollow": hollow,
        "color": color,
        "renderMode": "Rectangle",
        "showName": True,
        "tilesetId": None,
        "tileRenderMode": "FitInside",
        "tileRect": None,
        "uiTileRect": None,
        "nineSliceBorders": [],
        "maxCount": max_count,
        "limitScope": limit_scope,
        "limitBehavior": "MoveLastOne",
        "pivotX": pivot_x,
        "pivotY": pivot_y,
        "fieldDefs": field_defs or [],
    }


# ─── LAYER DEF BUILDER ────────────────────────────────────────────────────────

def make_entities_layer(identifier: str, uid: int, grid_size: int = 8) -> dict:
    return {
        "__type": "Entities",
        "identifier": identifier,
        "type": "Entities",
        "uid": uid,
        "doc": None,
        "uiColor": None,
        "gridSize": grid_size,
        "guideGridWid": 0,
        "guideGridHei": 0,
        "displayOpacity": 1,
        "inactiveOpacity": 1,
        "hideInList": False,
        "hideFieldsWhenInactive": False,
        "canSelectWhenInactive": True,
        "renderInWorldView": True,
        "pxOffsetX": 0,
        "pxOffsetY": 0,
        "parallaxFactorX": 0,
        "parallaxFactorY": 0,
        "parallaxScaling": True,
        "requiredTags": [],
        "excludedTags": [],
        "autoTilesKilledByOtherLayerUid": None,
        "uiFilterTags": [],
        "useAsyncRender": False,
        "intGridValues": [],
        "intGridValuesGroups": [],
        "autoRuleGroups": [],
        "autoSourceLayerDefUid": None,
        "tilesetDefUid": None,
        "tilePivotX": 0,
        "tilePivotY": 0,
        "biomeFieldUid": None,
    }


# ─── MAIN ─────────────────────────────────────────────────────────────────────

SCHEMA_VERSION = 1


def apply_schema(ldtk_path: Path) -> None:
    print(f"Reading {ldtk_path}…")
    with open(ldtk_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    uids = UidGen(data["nextUid"])

    # ── 1. Project settings ──────────────────────────────────────────────
    data["defaultLevelWidth"] = 648
    data["defaultLevelHeight"] = 1504
    # "Free" allows mixed casing (PascalCase entities + snake_case fields).
    # "Capitalize" auto-PascalCases everything which breaks our snake_case fields.
    data["identifierStyle"] = "Free"
    print("  project settings: defaultLevel=648x1504, identifierStyle=Free")

    # ── 2. Enums ─────────────────────────────────────────────────────────
    enum_specs = [
        ("ExtractionType", ["Timed", "Guarded", "Locked", "Sacrifice"]),
        ("SpawnPhase", ["Phase1", "Phase2", "Phase3", "Phase4", "Phase5", "Any"]),
        ("SpawnDensity", ["Low", "Medium", "High"]),
        ("BiomeId", ["Caves", "Catacombs", "NightmareRealm", "Threshold", "Inferno"]),
        ("ObstacleKind", ["Rock", "Crate", "Pillar", "Bones", "Tree", "Stalagmite"]),
        ("MarkerTag", ["LootSpawn", "EventTrigger", "Cinematic"]),
        ("RegionKind", ["Maze", "PreBoss", "Boss", "Safe"]),
        ("BossId", ["CaveTroll", "CryptLich", "NightmareKing", "ThresholdGuardian", "InfernoLord"]),
        ("Facing", ["Up", "Down", "Left", "Right"]),
        ("TransitionKind", ["Fade", "Cut", "Stairs"]),
    ]
    # Preserve UIDs of existing enums (so any field refs stay valid)
    existing_enum_uids = {e["identifier"]: e["uid"] for e in data["defs"].get("enums", [])}
    schema_enum_names = {name for name, _ in enum_specs}
    # Drop existing schema enums; keep non-schema enums untouched
    data["defs"]["enums"] = [
        e for e in data["defs"].get("enums", [])
        if e["identifier"] not in schema_enum_names
    ]
    enum_uids: dict[str, int] = {}
    for name, values in enum_specs:
        uid = existing_enum_uids.get(name, uids.next())
        data["defs"]["enums"].append(make_enum(name, values, uid))
        enum_uids[name] = uid
        action = "preserved uid" if name in existing_enum_uids else "added"
        print(f"  enum {name}: {action} {uid}")

    # ── 3. Level fields ──────────────────────────────────────────────────
    # Most metadata moves to the Level_Instructions entity (Hans's pattern).
    # Only fields the importer needs BEFORE entity parsing stay as level fields.
    schema_lf_names = {
        "biome",          # importer routes tilesets/wave defaults on this
        "schema_version", # importer rejects mismatched levels before any work
    }
    before_count = len(data["defs"].get("levelFields", []))
    data["defs"]["levelFields"] = [
        f for f in data["defs"].get("levelFields", [])
        if f["identifier"] in schema_lf_names
    ]
    removed = before_count - len(data["defs"]["levelFields"])
    if removed:
        print(f"  level fields: removed {removed} non-schema field(s)")

    # Preserve UIDs of existing schema-named level fields (so per-level instances stay linked)
    existing_lf_uids = {f["identifier"]: f["uid"] for f in data["defs"]["levelFields"]}
    # Wipe schema fields; rebuild from spec below
    data["defs"]["levelFields"] = [
        f for f in data["defs"]["levelFields"]
        if f["identifier"] not in schema_lf_names
    ]

    def _add_lf(builder, identifier: str, *args, **kwargs) -> None:
        uid = existing_lf_uids.get(identifier, uids.next())
        field = builder(identifier, uid, *args, **kwargs)
        data["defs"]["levelFields"].append(field)
        action = "preserved uid" if identifier in existing_lf_uids else "added"
        print(f"  level field {identifier}: {action} {uid}")

    _add_lf(lambda i, u: field_enum(i, u, enum_uids["BiomeId"], "BiomeId", "Caves",
            doc="Drives tileset, music, default wave composition lookup. "
                "Read by importer before entity parsing."), "biome")
    _add_lf(lambda i, u: field_int(i, u, SCHEMA_VERSION,
            doc=f"Schema version. Must equal {SCHEMA_VERSION}; "
                "importer rejects mismatches before parsing."), "schema_version")

    # ── 4. Entity defs ───────────────────────────────────────────────────
    schema_entity_names = {
        "Level_Instructions",
        "Extraction", "EnemySpawnZone", "Obstacle", "Marker", "Region",
    }
    # Singletons folded INTO Level_Instructions as Point fields. Strip if present.
    deprecated_entity_names = {"PlayerSpawn", "BossSpawn", "LevelExit"}

    # Preserve UIDs of existing schema entities (so placed instances stay linked)
    existing_entity_uids = {
        e["identifier"]: e["uid"] for e in data["defs"].get("entities", [])
    }
    # Strip schema entities (will rebuild), deprecated singletons, and "Entity" placeholder
    data["defs"]["entities"] = [
        e for e in data["defs"].get("entities", [])
        if (e["identifier"] not in schema_entity_names
            and e["identifier"] not in deprecated_entity_names
            and e["identifier"] != "Entity")
    ]
    if "Entity" in existing_entity_uids:
        print("  entity Entity: removed (LDtk default placeholder)")
    for dep in deprecated_entity_names:
        if dep in existing_entity_uids:
            print(f"  entity {dep}: removed (folded into Level_Instructions)")

    def _add_entity(builder, identifier: str) -> None:
        uid = existing_entity_uids.get(identifier, uids.next())
        entity = builder(identifier, uid)
        data["defs"]["entities"].append(entity)
        action = "preserved uid" if identifier in existing_entity_uids else "added"
        print(f"  entity {identifier}: {action} {uid}")

    # Level_Instructions — Hans's pattern, extended with our game-specific fields
    # and the three former singleton entities (PlayerSpawn/BossSpawn/LevelExit) folded in
    # as Point fields. One source of truth for per-level config.
    _add_entity(lambda i, u: make_entity(
        i, u, width=8, height=8, color="#00FF00",
        tags=[], max_count=0,
        pivot_x=0, pivot_y=0,  # Hans's convention: top-left pivot
        doc="Per-level metadata bundle. Place ONE on every level. "
            "Holds name, monster pool, boss, loot pool, music, player/boss/exit "
            "positions, notes for Claude.",
        field_defs=[
            # ── Hans's core 7 ─────────────────────────────────────────────
            field_string("Level_Name", uids.next(), "",
                         doc="Display name (e.g. \"Goblin Stockade\")."),
            field_string("Monster_Spawns", uids.next(), "",
                         doc="Comma-separated enemy IDs for the spawn pool. "
                             "Empty = use biome default from LevelData.LEVELS."),
            field_string("Boss_Spawn", uids.next(), "",
                         doc="Boss enemy ID (e.g. \"cave_troll\"). Empty = no boss."),
            field_string("Loot_Pool", uids.next(), "",
                         doc="Loot pool identifier. Empty = biome default."),
            field_int("Room_Distance_Tri", uids.next(), 0, is_array=True,
                      doc="Distance markers for room transitions / pacing tuning."),
            field_string("Misc_Overrides", uids.next(), "", is_array=True,
                         doc="Free-form key=value overrides. "
                             "Known keys: difficulty, phase_timer_<N>, seed, "
                             "xp_multiplier, extraction_reward_multiplier."),
            field_text("Misc_Notes", uids.next(), "", is_array=True,
                       doc="Multi-line notes — design intent, instructions for Claude, "
                           "boss behavior hints, etc."),
            # ── Game-specific additions ───────────────────────────────────
            field_string("Music_Id", uids.next(), "",
                         doc="Audio bus key. Empty = biome default."),
            field_int("Recommended_Player_Level", uids.next(), 1,
                     doc="For hub UI gating/sorting."),
            field_string("Tags", uids.next(), "", is_array=True,
                         doc='Free-form labels (e.g. "tutorial", "boss-rush", '
                             '"shortcut") for /level routing and meta-progression filters.'),
            # ── Folded-in singleton: PlayerSpawn ──────────────────────────
            field_point("Player_Spawn_Pos", uids.next(),
                        doc="Click a cell to set player spawn position. REQUIRED."),
            field_enum("Player_Facing", uids.next(),
                       enum_uids["Facing"], "Facing", "Down",
                       doc="Initial facing direction for the player on level enter."),
            # ── Folded-in singleton: BossSpawn ────────────────────────────
            field_point("Boss_Spawn_Pos", uids.next(),
                        doc="Click a cell inside the Boss region to set boss spawn. "
                            "Leave unset if Boss_Spawn (above) is empty."),
            field_float("Boss_Intro_Delay", uids.next(), 1.5,
                        doc="Seconds between boss appearing and aggression."),
            field_float("Boss_Camera_Zoom", uids.next(), 1.0,
                        doc="Camera zoom override during boss fight. 1.0 = no change."),
            # ── Folded-in singleton: LevelExit ────────────────────────────
            field_point("Level_Exit_Pos", uids.next(),
                        doc="Click a cell to set the level exit position. REQUIRED."),
            field_string("Next_Level_Id", uids.next(), "",
                         doc='LDtk identifier of the next level (e.g. "Level_1"). '
                             'Empty = end of biome → return to hub.'),
            field_enum("Exit_Transition", uids.next(),
                       enum_uids["TransitionKind"], "TransitionKind", "Fade",
                       doc="Visual transition when the player uses the exit."),
        ],
    ), "Level_Instructions")

    _add_entity(lambda i, u: make_entity(
        i, u, width=96, height=96, color="#3FFF55",
        tags=["gameplay", "extraction"], fill_opacity=0.2,
        doc="Player extracts here. Place inside Maze or Boss regions.",
        field_defs=[
            field_enum("kind", uids.next(),
                       enum_uids["ExtractionType"], "ExtractionType", "Timed",
                       doc="Drives marker color and unlock conditions."),
            field_float("unlock_radius", uids.next(), 48.0,
                        doc="Player must be within this radius to channel."),
            field_float("channel_seconds", uids.next(), 3.0,
                        doc="Time to extract once channeling starts."),
            field_text("notes", uids.next(), "",
                       doc="Author-only — not read by importer."),
        ],
    ), "Extraction")

    _add_entity(lambda i, u: make_entity(
        i, u, width=64, height=64, color="#CC2222",
        tags=["gameplay", "spawn"], resizable=True, fill_opacity=0.3,
        doc="Rectangle the EnemySpawnManager may spawn enemies inside.",
        field_defs=[
            field_enum("phase", uids.next(),
                       enum_uids["SpawnPhase"], "SpawnPhase", "Any",
                       doc="When this zone is active."),
            field_enum("density", uids.next(),
                       enum_uids["SpawnDensity"], "SpawnDensity", "Medium",
                       doc="Relative spawn weight vs. other active zones."),
            field_text("enemy_pool_override", uids.next(), "",
                       doc='Optional per-zone enemy weights. '
                           'Format: {"cave_fodder":0.7,"cave_bat":0.3}'),
            field_float("min_distance_from_player", uids.next(), 300.0,
                        doc="Suppress spawns inside this radius from player."),
        ],
    ), "EnemySpawnZone")

    _add_entity(lambda i, u: make_entity(
        i, u, width=16, height=16, color="#8A6A4A",
        tags=["gameplay", "static"], pivot_x=0.5, pivot_y=1.0,
        doc="Static collidable prop. Sprite chosen by `kind`.",
        field_defs=[
            field_enum("kind", uids.next(),
                       enum_uids["ObstacleKind"], "ObstacleKind", "Rock",
                       doc="Which sprite/footprint to use."),
            field_int("variant_index", uids.next(), 0,
                      doc="0+ = specific variant. -1 = random per-load."),
            field_float("collision_radius", uids.next(), 18.0,
                        doc="Circle collider radius. 0 = no collider."),
            field_float("scale", uids.next(), 3.0,
                        doc="Sprite scale (3× matches existing convention)."),
        ],
    ), "Obstacle")

    _add_entity(lambda i, u: make_entity(
        i, u, width=8, height=8, color="#FFCC22",
        tags=["gameplay", "marker"],
        doc="Generic tagged position. Read by name, not by type.",
        field_defs=[
            field_enum("tag", uids.next(),
                       enum_uids["MarkerTag"], "MarkerTag", "LootSpawn",
                       doc="Categorizes the marker for system lookup."),
            field_string("id", uids.next(), "",
                         doc="Unique key within the level."),
            field_text("payload", uids.next(), "",
                       doc="Free-form data passed to whatever system reads this marker."),
        ],
    ), "Marker")

    _add_entity(lambda i, u: make_entity(
        i, u, width=256, height=256, color="#22CCCC",
        tags=["gameplay", "region"], resizable=True,
        fill_opacity=0.2, hollow=True,
        doc="Tags an area as Maze/PreBoss/Boss/Safe. "
            "Regions must tile top-to-bottom with no gaps.",
        field_defs=[
            field_enum("kind", uids.next(),
                       enum_uids["RegionKind"], "RegionKind", "Maze",
                       doc="Drives gameplay rules per the schema."),
            field_string("id", uids.next(), "",
                         doc="Optional unique key for logs and scripted refs."),
            field_bool("enter_seal", uids.next(), False,
                       doc="If true, importer spawns invisible walls behind player on entry."),
            field_int("kill_quota", uids.next(), 0,
                      doc="For PreBoss: # kills inside region before boss spawns. 0 = no quota."),
            field_float("timer_seconds", uids.next(), 0.0,
                        doc="For PreBoss: boss spawns after this much time inside."),
        ],
    ), "Region")

    # PlayerSpawn / BossSpawn / LevelExit are intentionally absent — they're folded
    # into Level_Instructions as Point + Enum + Float fields (see above).

    # ── 5. Layers: add Entities layer at top, normalize CaveLayer → Collision ─
    layers: list[dict] = data["defs"]["layers"]
    layer_idents = {l["identifier"] for l in layers}

    # Add Entities layer at top of stack (LDtk top = rendered last/in front)
    if "Entities" not in layer_idents:
        entities_layer = make_entities_layer("Entities", uids.next(), grid_size=8)
        layers.insert(0, entities_layer)
        print(f"  layer Entities: added (uid {entities_layer['uid']})")
    else:
        print("  layer Entities: already present, skipping")

    # Normalize CaveLayer → Collision identifier + add IntGrid values
    cave_layer = next((l for l in layers if l["identifier"] == "CaveLayer"), None)
    collision_layer = next((l for l in layers if l["identifier"] == "Collision"), None)

    target_intgrid_values = [
        {"value": 1, "identifier": "Floor",       "color": "#3A6B3A", "tile": None, "groupUid": 0},
        {"value": 2, "identifier": "Wall",        "color": "#3F2A1A", "tile": None, "groupUid": 0},
        {"value": 3, "identifier": "Pit",         "color": "#1A1A2A", "tile": None, "groupUid": 0},
        {"value": 4, "identifier": "LowCover",    "color": "#7A5A3A", "tile": None, "groupUid": 0},
        {"value": 5, "identifier": "SpawnBlock",  "color": "#552255", "tile": None, "groupUid": 0},
    ]

    target_layer = collision_layer or cave_layer
    if target_layer is not None:
        if cave_layer is not None and collision_layer is None:
            cave_layer["identifier"] = "Collision"
            print("  layer CaveLayer -> Collision: renamed")
        # Canonicalize IntGrid values: schema is authoritative.
        # Existing .ldtkl files reference cells by numeric value, so renaming
        # the identifier is safe — only editor label changes.
        target_layer["intGridValues"] = list(target_intgrid_values)
        print("  layer Collision: IntGrid values canonicalized to schema "
              "(Floor=1, Wall=2, Pit=3, LowCover=4, SpawnBlock=5)")
    else:
        print("  WARN: no CaveLayer or Collision found - skipping rename")

    # ── 6. Bump nextUid ─────────────────────────────────────────────────
    data["nextUid"] = uids.value
    print(f"  nextUid: bumped to {data['nextUid']}")

    # ── 7. Write back ───────────────────────────────────────────────────
    with open(ldtk_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent="\t", ensure_ascii=False)
        f.write("\n")
    print(f"\nWrote {ldtk_path}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python apply_ldtk_schema.py <path-to-ldtk>")
        sys.exit(1)
    apply_schema(Path(sys.argv[1]))
