"""Generate 5 block variant LDtk levels for the Caves biome."""
import json
import uuid
import os
import random

PROJECT_PATH = os.path.join(os.path.dirname(__file__), "..", "assets", "Maps", "Levels", "Level 1 - Caves.ldtk")
LEVELS_DIR = os.path.join(os.path.dirname(PROJECT_PATH), "Level 1 - Caves")

BLOCK_W = 81  # tiles
BLOCK_H = 60  # tiles
BLOCK_PX_W = 648
BLOCK_PX_H = 480
GRID = 8

# Layer UIDs (from project defs)
ENTITIES_UID = 507
CRYPT_TILES_UID = 449
CRYPT_LAYER_UID = 433
COLLISION_UID = 4
CAVE_TILES_UID = 426
CAVES_BG_UID = 508

# Entity UIDs
SPAWN_ZONE_UID = 479
OBSTACLE_UID = 484
MARKER_UID = 489
EXTRACTION_UID = 474

# Field UIDs for entities (from project defs)
FIELD_SPAWN_PHASE = 609
FIELD_SPAWN_DENSITY = 610
FIELD_SPAWN_POOL = 611
FIELD_SPAWN_MIN_DIST = 612
FIELD_MARKER_TAG = 619
FIELD_MARKER_ID = 620
FIELD_MARKER_PAYLOAD = 621
FIELD_EXTRACT_KIND = 604
FIELD_EXTRACT_RADIUS = 605
FIELD_EXTRACT_CHANNEL = 606
FIELD_EXTRACT_NOTES = 607
FIELD_BIOME = 465
FIELD_SCHEMA = 471

CAVE_TILESET_PATH = "../../minifantasy/Minifantasy_DeepCaves_v2.0/Minifantasy_DeepCaves_Assets/Tileset/CavesTileset.png"
CRYPT_TILESET_PATH = "../../minifantasy/Minifantasy_Crypt_v2.0/Minifantasy_Crypt_Assets/Tileset/Crypt.png"


def make_iid():
    return str(uuid.uuid4())


def make_collision_grid(variant):
    grid = [0] * (BLOCK_W * BLOCK_H)

    def set_val(row, col, val):
        if 0 <= row < BLOCK_H and 0 <= col < BLOCK_W:
            grid[row * BLOCK_W + col] = val

    # Base: fill inside borders with floor
    for r in range(BLOCK_H):
        for c in range(2, BLOCK_W - 2):
            set_val(r, c, 1)

    if variant == "open":
        pass

    elif variant == "pillars":
        pillars = [(15, 20), (15, 60), (30, 40), (45, 20), (45, 60)]
        for pr, pc in pillars:
            for dr in range(-1, 2):
                for dc in range(-1, 2):
                    set_val(pr + dr, pc + dc, 0)

    elif variant == "choke":
        for r in range(25, 36):
            for c in range(2, 34):
                set_val(r, c, 0)
            for c in range(48, BLOCK_W - 2):
                set_val(r, c, 0)

    elif variant == "split":
        spine_col = 40
        for r in range(10, 50):
            for dc in range(-1, 2):
                set_val(r, spine_col + dc, 0)
        # Gap at row 30 for crossing
        for dc in range(-1, 2):
            set_val(30, spine_col + dc, 1)

    elif variant == "merchant":
        # Gate wall at col 59, rows 20-40, with a door gap at rows 28-31
        for r in range(20, 41):
            set_val(r, 59, 0)
        for r in range(28, 32):
            set_val(r, 59, 1)

    return grid


def make_spawn_zone():
    return {
        "__identifier": "EnemySpawnZone",
        "__grid": [10, 10],
        "__pivot": [0.5, 0.5],
        "__tags": ["gameplay", "spawn"],
        "__tile": None,
        "__smartColor": "#CC2222",
        "iid": make_iid(),
        "width": 520,
        "height": 360,
        "defUid": SPAWN_ZONE_UID,
        "px": [80, 80],
        "fieldInstances": [
            {"__identifier": "phase", "__type": "LocalEnum.SpawnPhase", "__value": "Any",
             "__tile": None, "defUid": FIELD_SPAWN_PHASE, "realEditorValues": []},
            {"__identifier": "density", "__type": "LocalEnum.SpawnDensity", "__value": "Medium",
             "__tile": None, "defUid": FIELD_SPAWN_DENSITY,
             "realEditorValues": [{"id": "V_String", "params": ["Medium"]}]},
            {"__identifier": "enemy_pool_override", "__type": "String", "__value": "",
             "__tile": None, "defUid": FIELD_SPAWN_POOL, "realEditorValues": []},
            {"__identifier": "min_distance_from_player", "__type": "Float", "__value": 300,
             "__tile": None, "defUid": FIELD_SPAWN_MIN_DIST, "realEditorValues": []},
        ],
        "__worldX": 80,
        "__worldY": 80,
    }


def make_event_anchor(grid_x, grid_y, anchor_id, payload):
    return {
        "__identifier": "Marker",
        "__grid": [grid_x, grid_y],
        "__pivot": [0, 0],
        "__tags": [],
        "__tile": None,
        "__smartColor": "#FFCC22",
        "iid": make_iid(),
        "width": 8,
        "height": 8,
        "defUid": MARKER_UID,
        "px": [grid_x * GRID, grid_y * GRID],
        "fieldInstances": [
            {"__identifier": "tag", "__type": "LocalEnum.MarkerTag", "__value": "EventTrigger",
             "__tile": None, "defUid": FIELD_MARKER_TAG,
             "realEditorValues": [{"id": "V_String", "params": ["EventTrigger"]}]},
            {"__identifier": "id", "__type": "String", "__value": anchor_id,
             "__tile": None, "defUid": FIELD_MARKER_ID,
             "realEditorValues": [{"id": "V_String", "params": [anchor_id]}]},
            {"__identifier": "payload", "__type": "String", "__value": payload,
             "__tile": None, "defUid": FIELD_MARKER_PAYLOAD,
             "realEditorValues": [{"id": "V_String", "params": [payload]}]},
        ],
        "__worldX": grid_x * GRID,
        "__worldY": grid_y * GRID,
    }


def make_locked_extraction(grid_x, grid_y):
    return {
        "__identifier": "Extraction",
        "__grid": [grid_x, grid_y],
        "__pivot": [0.5, 0.5],
        "__tags": ["gameplay", "extraction"],
        "__tile": None,
        "__smartColor": "#3FFF55",
        "iid": make_iid(),
        "width": 96,
        "height": 96,
        "defUid": EXTRACTION_UID,
        "px": [grid_x * GRID, grid_y * GRID],
        "fieldInstances": [
            {"__identifier": "kind", "__type": "LocalEnum.ExtractionType", "__value": "Locked",
             "__tile": None, "defUid": FIELD_EXTRACT_KIND,
             "realEditorValues": [{"id": "V_String", "params": ["Locked"]}]},
            {"__identifier": "unlock_radius", "__type": "Float", "__value": 48,
             "__tile": None, "defUid": FIELD_EXTRACT_RADIUS, "realEditorValues": []},
            {"__identifier": "channel_seconds", "__type": "Float", "__value": 2,
             "__tile": None, "defUid": FIELD_EXTRACT_CHANNEL, "realEditorValues": []},
            {"__identifier": "notes", "__type": "String",
             "__value": "Behind merchant gate - requires keystone",
             "__tile": None, "defUid": FIELD_EXTRACT_NOTES,
             "realEditorValues": [{"id": "V_String", "params": ["Behind merchant gate - requires keystone"]}]},
        ],
        "__worldX": grid_x * GRID,
        "__worldY": grid_y * GRID,
    }


def make_entity_instances(variant):
    entities = [make_spawn_zone()]

    if variant == "pillars":
        entities.append(make_event_anchor(40, 30, "event_anchor_01", "any"))
    elif variant == "choke":
        entities.append(make_event_anchor(40, 20, "event_anchor_01", "any"))
    elif variant == "split":
        entities.append(make_event_anchor(20, 30, "event_anchor_01", "any"))
    elif variant == "merchant":
        entities.append(make_event_anchor(35, 30, "merchant_anchor", "merchant"))
        entities.append(make_locked_extraction(69, 30))

    return entities


def make_empty_layer(identifier, layer_type, uid, level_uid, tileset_uid=None, tileset_path=None):
    return {
        "__identifier": identifier,
        "__type": layer_type,
        "__cWid": BLOCK_W,
        "__cHei": BLOCK_H,
        "__gridSize": GRID,
        "__opacity": 1,
        "__pxTotalOffsetX": 0,
        "__pxTotalOffsetY": 0,
        "__tilesetDefUid": tileset_uid,
        "__tilesetRelPath": tileset_path,
        "iid": make_iid(),
        "levelId": level_uid,
        "layerDefUid": uid,
        "pxOffsetX": 0,
        "pxOffsetY": 0,
        "visible": True,
        "optionalRules": [],
        "intGridCsv": [],
        "autoLayerTiles": [],
        "seed": random.randint(1000000, 9999999),
        "overrideTilesetUid": None,
        "gridTiles": [],
        "entityInstances": [],
    }


def make_block_level(name, variant, level_uid, world_x):
    collision_grid = make_collision_grid(variant)
    entities = make_entity_instances(variant)

    entities_layer = make_empty_layer("Entities", "Entities", ENTITIES_UID, level_uid)
    entities_layer["entityInstances"] = entities

    crypt_tiles = make_empty_layer("CryptTiles", "Tiles", CRYPT_TILES_UID, level_uid, 431, CRYPT_TILESET_PATH)
    crypt_layer = make_empty_layer("CryptLayer", "IntGrid", CRYPT_LAYER_UID, level_uid, 431, CRYPT_TILESET_PATH)
    crypt_layer["intGridCsv"] = [0] * (BLOCK_W * BLOCK_H)

    collision_layer = make_empty_layer("Collision", "IntGrid", COLLISION_UID, level_uid, 2, CAVE_TILESET_PATH)
    collision_layer["intGridCsv"] = collision_grid

    cave_tiles = make_empty_layer("Cave_Tiles", "Tiles", CAVE_TILES_UID, level_uid, 2, CAVE_TILESET_PATH)
    caves_bg = make_empty_layer("CavesBackground", "Tiles", CAVES_BG_UID, level_uid, 2, CAVE_TILESET_PATH)

    return {
        "__header__": {
            "fileType": "LDtk Project JSON",
            "app": "LDtk",
            "doc": "https://ldtk.io/json",
            "schema": "https://ldtk.io/files/JSON_SCHEMA.json",
            "appAuthor": "Sebastien 'deepnight' Benard",
            "appVersion": "1.5.3",
            "url": "https://ldtk.io",
        },
        "identifier": name,
        "iid": make_iid(),
        "uid": level_uid,
        "worldX": world_x,
        "worldY": 0,
        "worldDepth": 0,
        "pxWid": BLOCK_PX_W,
        "pxHei": BLOCK_PX_H,
        "__bgColor": "#696A79",
        "bgColor": None,
        "useAutoIdentifier": False,
        "bgRelPath": None,
        "bgPos": None,
        "bgPivotX": 0.5,
        "bgPivotY": 0.5,
        "__smartColor": "#ADADB5",
        "__bgPos": None,
        "externalRelPath": None,
        "fieldInstances": [
            {"__identifier": "biome", "__type": "LocalEnum.BiomeId", "__value": "Caves",
             "__tile": None, "defUid": FIELD_BIOME,
             "realEditorValues": [{"id": "V_String", "params": ["Caves"]}]},
            {"__identifier": "schema_version", "__type": "Int", "__value": 1,
             "__tile": None, "defUid": FIELD_SCHEMA,
             "realEditorValues": [{"id": "V_Int", "params": [1]}]},
        ],
        "layerInstances": [
            entities_layer,
            crypt_tiles,
            crypt_layer,
            collision_layer,
            cave_tiles,
            caves_bg,
        ],
    }


def main():
    with open(PROJECT_PATH, "r", encoding="utf-8") as f:
        project = json.load(f)

    blocks = [
        ("Block_Caves_01_Open", "open", 100, 1400),
        ("Block_Caves_02_Pillars", "pillars", 101, 2100),
        ("Block_Caves_03_Choke", "choke", 102, 2800),
        ("Block_Caves_04_Split", "split", 103, 3500),
        ("Block_Caves_05_Merchant", "merchant", 104, 4200),
    ]

    for name, variant, uid, world_x in blocks:
        level_data = make_block_level(name, variant, uid, world_x)

        level_path = os.path.join(LEVELS_DIR, name + ".ldtkl")
        with open(level_path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(level_data, f, indent="\t", ensure_ascii=False)
            f.write("\n")

        project["levels"].append({
            "identifier": name,
            "iid": level_data["iid"],
            "uid": uid,
            "worldX": world_x,
            "worldY": 0,
            "worldDepth": 0,
            "pxWid": BLOCK_PX_W,
            "pxHei": BLOCK_PX_H,
            "__bgColor": "#696A79",
            "bgColor": None,
            "useAutoIdentifier": False,
            "bgRelPath": None,
            "bgPos": None,
            "bgPivotX": 0.5,
            "bgPivotY": 0.5,
            "__smartColor": "#ADADB5",
            "__bgPos": None,
            "externalRelPath": name + ".ldtkl",
            "fieldInstances": level_data["fieldInstances"],
            "layerInstances": None,
        })

        print(f"Created: {name} ({level_path})")

    max_uid = max(uid for _, _, uid, _ in blocks) + 1
    if project.get("nextUid", 0) <= max_uid:
        project["nextUid"] = max_uid + 100

    with open(PROJECT_PATH, "w", encoding="utf-8", newline="\n") as f:
        json.dump(project, f, indent="\t", ensure_ascii=False)
        f.write("\n")

    print(f"\nUpdated parent project with {len(blocks)} new levels")
    print(f"Total levels in project: {len(project['levels'])}")


if __name__ == "__main__":
    main()
