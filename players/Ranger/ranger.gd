class_name RangerCharacter
extends "res://scripts/base_character.gd"

## Ranger character specialization of BaseCharacter
## Inherits all tactical combat functionality from BaseCharacter

func _ready() -> void:
	character_type = "Ranger"
	# Rangers are quick and agile with high initiative
	base_initiative = 14
	super()