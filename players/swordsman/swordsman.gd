class_name SwordsmanCharacter
extends "res://scripts/base_character.gd"

## Swordsman character specialization of BaseCharacter
## Inherits all tactical combat functionality from BaseCharacter

func _ready() -> void:
	character_type = "Swordsman"
	# Swordsmen have balanced initiative - medium value
	base_initiative = 11
	current_initiative = base_initiative
	super()
