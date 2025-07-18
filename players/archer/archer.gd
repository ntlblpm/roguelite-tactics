class_name ArcherCharacter
extends "res://scripts/base_character.gd"

## Archer character specialization of BaseCharacter
## Inherits all tactical combat functionality from BaseCharacter

func _ready() -> void:
	character_type = "Archer"
	# Archers are quick and agile - higher initiative
	base_initiative = 14
	super()
