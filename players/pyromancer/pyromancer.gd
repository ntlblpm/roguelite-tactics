class_name PyromancerCharacter
extends "res://scripts/base_character.gd"

## Pyromancer character specialization of BaseCharacter
## Inherits all tactical combat functionality from BaseCharacter

func _ready() -> void:
	character_type = "Pyromancer"
	super() 
