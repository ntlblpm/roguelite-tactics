class_name AssassinCharacter
extends "res://scripts/base_character.gd"

## Assassin character specialization of BaseCharacter
## Inherits all tactical combat functionality from BaseCharacter

func _ready() -> void:
	character_type = "Assassin"
	# Assassins are extremely fast with the highest initiative
	base_initiative = 16
	super()