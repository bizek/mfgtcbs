class_name EchoAtNearbyEffect
extends Resource
## Effect sub-resource: replay a payload at several OTHER nearby enemies.
##
## Path of Exile's Ancestral Call, which is where Ben got it (2026-09-05): a melee hit also lands
## on a couple of enemies you did not swing at. The engine had no primitive for this —
## OverflowChainEffect is about spilling OVERKILL onto the next target, which needs something to
## die first and carries no visual of its own, so it is a different mechanic entirely.
##
## What this does: pick up to `copies` enemies within `search_radius` of the source, spread apart by
## at least `min_separation` so the echoes do not stack into one blob, and dispatch `effects`
## centred on each of them. AreaDamageEffect centres on its target's position, so an AoE handed a
## nearby enemy as its target simply lands over there — no new geometry code.
##
## The payload is authored as a COPY of the phase's own effects rather than a reference, because
## an echo is meant to hit for less than the real swing (Ancestral Call is the same) and because a
## shared resource scaled in place would leak the change into the original.
##
## Nothing recursive can happen: this effect is not an AreaDamageEffect, so the `echo_aoe` op that
## builds it never picks it up as a payload for a second echo.

## Effects dispatched at each echo position. Authored by ClassModFactory's "echo_aoe" op, which
## clones the targeted phase's AreaDamageEffects into here.
@export var effects: Array[Resource] = []

## How many EXTRA impacts. 2 means three slams total, counting the real one.
@export var copies: int = 2

## How far from the source to look for somewhere to echo.
@export var search_radius: float = 170.0

## Minimum gap between chosen echo positions. Without it, a tight pack puts all the copies on top
## of each other and the whole point — several impacts across the fight — is lost.
@export var min_separation: float = 40.0
