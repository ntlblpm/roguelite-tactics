class_name SkeletonKnight
extends BaseEnemy

## Skeleton Knight enemy implementation
## An armored skeleton with higher defense and moderate attack power
## Uses AIController and AbilityComponent for intelligent behavior

func _ready() -> void:
	# Override base stats for Skeleton Knight
	character_type = "SkeletonKnight"
	base_initiative = 6  # Slightly higher than basic skeleton
	
	super()
