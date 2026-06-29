class_name ConditionInputBuffered
extends Resource
## Combo branch condition: the given input action was buffered (tapped) within the cancel window.
## Evaluated by the player host's evaluate_choreography_condition() against the CombatInputBuffer.
## See docs/combat_chain_architecture.md §2. List AFTER a ConditionInputHeld for the same action
## so a hold resolves to the channel branch, not a tap-advance.

@export var action: String = ""           ## InputMap action, e.g. "light_attack"
@export var within_window: float = 0.0    ## seconds; <= 0 = use the phase's cancel-window metadata
