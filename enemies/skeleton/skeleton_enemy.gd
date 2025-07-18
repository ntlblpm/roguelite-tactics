class_name SkeletonEnemy
extends BaseEnemy

## Skeleton enemy implementation
## A basic melee enemy that moves to the closest player and attacks with a sword
## Uses AIController and AbilityComponent for intelligent behavior

func _ready() -> void:
	# Override base stats for skeleton
	character_type = "Skeleton"
	base_initiative = 5  # Lower initiative than most players
	
	super()

 
