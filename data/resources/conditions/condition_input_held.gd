class_name ConditionInputHeld
extends Resource
## Combo branch condition: the given input action has been held continuously for >= min_duration.
## Branches a tapped chain into a held channel (e.g. Fighter's Whirlwind). See
## docs/combat_chain_architecture.md §2/§3. MUST be listed before a ConditionInputBuffered for the
## same action in a phase's branches array (first-passing-branch-wins) so a held press channels
## instead of advancing the chain.

@export var action: String = ""           ## InputMap action, e.g. "light_attack"
@export var min_duration: float = 0.0     ## seconds held continuously; 0 = held at all this frame
@export var negate: bool = false          ## true = pass when the action is NOT held (released).
                                          ## Used to EXIT a held channel: loop via default_next while
                                          ## held, branch out the instant the button is released.
