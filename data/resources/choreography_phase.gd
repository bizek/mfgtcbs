class_name ChoreographyPhase
extends Resource
## One phase of a ChoreographyDefinition sequence.

## What happens in this phase
@export var animation: String = ""                    ## Anim to play ("" = hold current frame)
@export var effects: Array[Resource] = []             ## Effect sub-resources to fire
@export var hit_frame: int = -1                       ## Frame to fire effects (-1 = fire on phase entry)
@export var displacement: DisplacementEffect          ## Displacement to execute (null = none)
@export var retarget: TargetingRule                    ## Resolve fresh targets for this phase (null = keep previous)

## Entity state during this phase
@export var set_untargetable: bool = false
@export var set_invulnerable: bool = false

## How this phase ends
@export var exit_type: String = "anim_finished"       ## "anim_finished", "wait", "displacement_complete"
@export var wait_duration: float = 0.0                ## For "wait" exit type (max seconds)
@export var telegraph_speed_scale: float = 1.0        ## Sprite playback speed during telegraph wind-up (reset to 1.0 on exit)

## What comes next
@export var default_next: int = -1                    ## Phase index (-1 = end choreography)
@export var branches: Array[ChoreographyBranch] = []  ## Conditional branching (evaluated during "wait" exit type)

## Channel hold: when this phase self-loops (default_next = its own index), don't restart the
## body animation — a finished one-shot stays frozen on its last frame (Guard's raised sword,
## the Torrent pour pose). The runner re-fires the overlay hook and tick effects on each
## re-entry instead, since a frozen body never reaches its hit_frame again.
@export var hold_anim_on_reentry: bool = false

## Recovery locomotion set. When this phase's one-shot body finishes drawing while the phase is
## still live, the runner hands the sprite back to the host's locomotion (choreo_on_phase_recovery).
## Normally that means walk/idle; a phase whose pose must persist through the recovery — the
## Ravager carrying a pile overhead — names a prefix here and the host plays "<prefix>_walk" /
## "<prefix>_idle" instead. "" = ordinary walk/idle. Only consulted by hosts that own a locomotion
## block (the player); a boss body just freezes as before.
@export var recovery_locomotion: String = ""

## Combo feel
@export var is_finisher: bool = false                  ## Landing this phase's hit is a kit's payoff
                                                        ## moment (Cataclysm, Bomb, Holy Hammer, ...).
                                                        ## ChoreographyRunner fires choreo_on_finisher_hit()
                                                        ## on the host when this phase's effects land.
