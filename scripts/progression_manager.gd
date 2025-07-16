class_name ProgressionManager
extends Node

## Manages player progression including class levels, experience, and upgrade trees
## Handles saving and loading progression data to local filesystem

# Progression data structure
var progression_data: Dictionary = {
	"class_levels": {
		"Swordsman": 1,
		"Archer": 1,
		"Pyromancer": 1
	},
	"class_experience": {
		"Swordsman": 0,
		"Archer": 0,
		"Pyromancer": 0
	},
	"class_upgrades": {
		"Swordsman": {},
		"Archer": {},
		"Pyromancer": {}
	},
	"roster_upgrades": {},
	"total_experience": 0
}

# Experience requirements per level (exponential scaling)
const BASE_EXPERIENCE_REQUIRED: int = 100
const EXPERIENCE_MULTIPLIER: float = 1.15

# Save file path
const SAVE_FILE_PATH: String = "user://progression_save.json"

# Signals for UI updates
signal experience_gained(character_class: String, amount: int)
signal level_gained(character_class: String, new_level: int)
signal upgrade_purchased(character_class: String, upgrade_id: String)

# Class names array for easy iteration
const CLASS_NAMES: Array[String] = ["Swordsman", "Archer", "Pyromancer"]

func _ready() -> void:
	load_progression_data()

func get_experience_required_for_level(level: int) -> int:
	"""Calculate experience required to reach a specific level"""
	if level <= 1:
		return 0
	
	var total_required: int = 0
	for i in range(2, level + 1):
		total_required += int(BASE_EXPERIENCE_REQUIRED * pow(EXPERIENCE_MULTIPLIER, i - 2))
	
	return total_required

func get_experience_for_next_level(character_class: String) -> int:
	"""Get experience needed for the next level of a specific class"""
	var current_level: int = progression_data.class_levels[character_class]
	var current_exp: int = progression_data.class_experience[character_class]
	var required_exp: int = get_experience_required_for_level(current_level + 1)
	
	return max(0, required_exp - current_exp)

func get_roster_level() -> int:
	"""Calculate the roster level (sum of all class levels)"""
	var total: int = 0
	for character_class in CLASS_NAMES:
		total += progression_data.class_levels[character_class]
	return total

func get_class_level(character_class: String) -> int:
	"""Get the current level of a specific class"""
	return progression_data.class_levels.get(character_class, 1)

func get_class_experience(character_class: String) -> int:
	"""Get the current experience of a specific class"""
	return progression_data.class_experience.get(character_class, 0)

func add_experience(character_class: String, amount: int) -> void:
	"""Add experience to a specific class and handle level ups"""
	if character_class not in CLASS_NAMES:
		print("Warning: Unknown class name: ", character_class)
		return
	
	progression_data.class_experience[character_class] += amount
	progression_data.total_experience += amount
	
	experience_gained.emit(character_class, amount)
	_check_for_level_up(character_class)
	save_progression_data()

func _check_for_level_up(character_class: String) -> void:
	"""Check if a class has gained enough experience to level up"""
	var current_level: int = progression_data.class_levels[character_class]
	var current_exp: int = progression_data.class_experience[character_class]
	
	# Check if we can level up (max level 50)
	while current_level < 50:
		var required_exp: int = get_experience_required_for_level(current_level + 1)
		
		if current_exp >= required_exp:
			current_level += 1
			progression_data.class_levels[character_class] = current_level
			level_gained.emit(character_class, current_level)
			print(character_class, " leveled up to level ", current_level, "!")
		else:
			break

func get_available_upgrade_points(character_class: String) -> int:
	"""Get the number of unspent upgrade points for a class"""
	var level: int = get_class_level(character_class)
	var spent_points: int = 0
	
	# Count spent upgrade points
	if character_class in progression_data.class_upgrades:
		for upgrade_id in progression_data.class_upgrades[character_class]:
			spent_points += progression_data.class_upgrades[character_class][upgrade_id]
	
	# Each level above 1 grants 1 upgrade point
	return max(0, level - 1 - spent_points)

func get_available_roster_upgrade_points() -> int:
	"""Get the number of unspent roster upgrade points"""
	var roster_level: int = get_roster_level()
	var spent_points: int = 0
	
	# Count spent roster upgrade points
	for upgrade_id in progression_data.roster_upgrades:
		spent_points += progression_data.roster_upgrades[upgrade_id]
	
	# Each roster level grants 1 upgrade point
	return max(0, roster_level - 3 - spent_points) # -3 because we start with 3 total levels

func purchase_class_upgrade(character_class: String, upgrade_id: String) -> bool:
	"""Purchase a class upgrade if player has enough points"""
	if get_available_upgrade_points(character_class) <= 0:
		return false
	
	if character_class not in progression_data.class_upgrades:
		progression_data.class_upgrades[character_class] = {}
	
	if upgrade_id not in progression_data.class_upgrades[character_class]:
		progression_data.class_upgrades[character_class][upgrade_id] = 0
	
	progression_data.class_upgrades[character_class][upgrade_id] += 1
	upgrade_purchased.emit(character_class, upgrade_id)
	save_progression_data()
	return true

func purchase_roster_upgrade(upgrade_id: String) -> bool:
	"""Purchase a roster upgrade if player has enough points"""
	if get_available_roster_upgrade_points() <= 0:
		return false
	
	if upgrade_id not in progression_data.roster_upgrades:
		progression_data.roster_upgrades[upgrade_id] = 0
	
	progression_data.roster_upgrades[upgrade_id] += 1
	upgrade_purchased.emit("Roster", upgrade_id)
	save_progression_data()
	return true

func get_upgrade_level(character_class: String, upgrade_id: String) -> int:
	"""Get the current level of a specific upgrade"""
	if character_class == "Roster":
		return progression_data.roster_upgrades.get(upgrade_id, 0)
	else:
		if character_class not in progression_data.class_upgrades:
			return 0
		return progression_data.class_upgrades[character_class].get(upgrade_id, 0)

func save_progression_data() -> void:
	"""Save progression data to local file system"""
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		print("Error: Could not open save file for writing")
		return
	
	var json_string: String = JSON.stringify(progression_data)
	file.store_string(json_string)
	file.close()
	print("Progression data saved successfully")

func load_progression_data() -> void:
	"""Load progression data from local file system"""
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("No save file found, using default progression data")
		save_progression_data() # Create initial save file
		return
	
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		print("Error: Could not open save file for reading")
		return
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	
	if parse_result != OK:
		print("Error: Could not parse save file JSON")
		return
	
	var loaded_data: Dictionary = json.data
	
	# Merge loaded data with default structure to handle version updates
	_merge_progression_data(loaded_data)
	print("Progression data loaded successfully")

func _merge_progression_data(loaded_data: Dictionary) -> void:
	"""Merge loaded data with default structure to handle missing fields"""
	for key in loaded_data:
		if key in progression_data:
			if typeof(progression_data[key]) == TYPE_DICTIONARY and typeof(loaded_data[key]) == TYPE_DICTIONARY:
				for subkey in loaded_data[key]:
					progression_data[key][subkey] = loaded_data[key][subkey]
			else:
				progression_data[key] = loaded_data[key]

func reset_progression() -> void:
	"""Reset all progression data (for debugging/testing)"""
	progression_data = {
		"class_levels": {
			"Swordsman": 1,
			"Archer": 1,
			"Pyromancer": 1
		},
		"class_experience": {
			"Swordsman": 0,
			"Archer": 0,
			"Pyromancer": 0
		},
		"class_upgrades": {
			"Swordsman": {},
			"Archer": {},
			"Pyromancer": {}
		},
		"roster_upgrades": {},
		"total_experience": 0
	}
	save_progression_data()
	print("Progression data reset") 