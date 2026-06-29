extends Node2D
## Phantom aim target for manual fire (player.gd). Stands in for an enemy in the projectile
## spawn pipeline, which reads `global_position` and `is_alive` off the target to compute the
## firing direction. Position is moved to the mouse cursor before each shot; `is_alive` stays
## true so the spawn guards (projectile_manager) and EffectDispatcher.execute_effect treat it
## as a valid live target. Carries no health/faction, so it must only stand in where the
## pipeline reads position/is_alive (projectile direction, artillery GroundZone placement) —
## never as a DealDamage target. Beam/melee resolve real enemies instead (player.gd).
var is_alive: bool = true
