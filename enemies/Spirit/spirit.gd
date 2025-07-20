class_name Spirit
extends BaseEnemy

## Spirit enemy implementation
## A fast, ethereal enemy with low defense but high evasion
## Uses AIController and AbilityComponent for intelligent behavior

func _ready() -> void:
	# Override base stats for Spirit
	character_type = "Spirit"
	base_initiative = 8  # High initiative for quick strikes
	
	super()
