class_name DarkLord
extends BaseEnemy

## Dark Lord enemy implementation
## A powerful boss enemy with high stats and multiple abilities
## Uses AIController and AbilityComponent for intelligent behavior

func _ready() -> void:
	# Override base stats for Dark Lord
	character_type = "DarkLord"
	base_initiative = 10  # Higher initiative than most characters
	
	super()
