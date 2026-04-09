class_name ChoreographyDefinition
extends Resource
## Data-driven multi-phase ability sequence.
## Lives on AbilityDefinition.choreography. Executor lives on entity scripts.

@export var phases: Array[ChoreographyPhase] = []
