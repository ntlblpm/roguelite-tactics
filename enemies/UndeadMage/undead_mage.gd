class_name UndeadMage
extends BaseEnemy

## Undead Mage enemy implementation
## A magic-wielding enemy with ranged attacks and spell abilities
## Uses AIController and AbilityComponent for intelligent behavior

func _ready() -> void:
	# Override base stats for Undead Mage
	character_type = "UndeadMage"
	base_initiative = 7  # Moderate initiative
	
	super()
