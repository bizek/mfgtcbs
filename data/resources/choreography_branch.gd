class_name ChoreographyBranch
extends Resource
## Conditional branch within a ChoreographyPhase.

@export var condition: Resource                        ## Typed condition sub-resource
@export var next_phase: int = -1                      ## Phase index to jump to when condition met
