class_name VfxLayerConfig
extends Resource
## Configures one layer of a visual effect. Multi-layer effects use multiple entries.

@export var sprite_frames: SpriteFrames
@export var animation: String = ""
@export var z_index: int = 0
@export var offset: Vector2 = Vector2.ZERO
@export var scale: Vector2 = Vector2.ONE
## Tint applied to the spawned sprite, so one source sheet can serve several fantasies
## (the pack's green Poison aura recoloured to crimson for Bleed).
@export var modulate: Color = Color.WHITE

## Optional intro animation played before looping.
@export var start_animation: String = ""

## Optional outro animation played when effect is stopped.
@export var end_animation: String = ""
