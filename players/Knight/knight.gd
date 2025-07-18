class_name KnightCharacter
extends "res://scripts/base_character.gd"

## Knight character specialization of BaseCharacter
## Inherits all tactical combat functionality from BaseCharacter

func _ready() -> void:
	character_type = "Knight"
	# Knights are balanced melee fighters with solid initiative
	base_initiative = 11
	super()
