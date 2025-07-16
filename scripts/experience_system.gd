class_name ExperienceSystem
extends Node

## System for awarding experience to characters based on combat completion
## Integrates with ProgressionManager to handle experience gain and level ups

# Experience values for different enemy types
const BASIC_ENEMY_EXPERIENCE: int = 25
const ELITE_ENEMY_EXPERIENCE: int = 50
const BOSS_ENEMY_EXPERIENCE: int = 100  # Bosses give double the normal fight experience

# Class that participated in the fight (determined by player's selected class)
var participating_class: String = "Swordsman"  # Default, can be set before combat

# Reference to progression manager (will be set when needed)
var progression_manager = null

func _ready() -> void:
	# Find or create progression manager
	_setup_progression_manager()

func _setup_progression_manager() -> void:
	"""Setup reference to progression manager"""
	# Try to find existing progression manager in scene tree
	progression_manager = get_tree().get_first_node_in_group("progression_manager")
	
	# If not found, check if we can access it through an autoload or singleton
	if progression_manager == null:
		# For now, we'll create it locally when needed
		print("Progression manager not found, will create when needed")

func set_participating_class(character_class: String) -> void:
	"""Set which class is participating in the current fight"""
	participating_class = character_class
	print("Experience will be awarded to: ", participating_class)

func award_experience_for_fight(enemy_types: Array[String]) -> void:
	"""Award experience based on the enemies defeated in a fight"""
	var total_experience: int = 0
	
	for enemy_type in enemy_types:
		total_experience += _get_experience_for_enemy(enemy_type)
	
	print("Awarding ", total_experience, " experience to ", participating_class)
	_award_experience_to_class(participating_class, total_experience)

func award_experience_for_boss_fight(boss_type: String) -> void:
	"""Award experience for boss fight (double normal amount)"""
	var base_experience: int = _get_experience_for_enemy(boss_type)
	var boss_experience: int = base_experience * 2  # Bosses give double
	
	print("Awarding ", boss_experience, " boss experience to ", participating_class)
	_award_experience_to_class(participating_class, boss_experience)

func _get_experience_for_enemy(enemy_type: String) -> int:
	"""Get experience value for a specific enemy type"""
	match enemy_type.to_lower():
		"skeleton", "basic", "weak":
			return BASIC_ENEMY_EXPERIENCE
		"elite", "strong", "veteran":
			return ELITE_ENEMY_EXPERIENCE
		"boss", "darklord", "final":
			return BOSS_ENEMY_EXPERIENCE
		_:
			print("Unknown enemy type: ", enemy_type, " - using basic experience")
			return BASIC_ENEMY_EXPERIENCE

func _award_experience_to_class(character_class: String, amount: int) -> void:
	"""Award experience to a specific class through the progression manager"""
	# Ensure we have a progression manager
	if progression_manager == null:
		_find_or_create_progression_manager()
	
	if progression_manager != null and progression_manager.has_method("add_experience"):
		progression_manager.add_experience(character_class, amount)
		print("Experience awarded successfully!")
	else:
		print("Warning: Could not award experience - progression manager not available")

func _find_or_create_progression_manager() -> void:
	"""Connect to the progression manager autoload"""
	# Use the global ProgressionManager autoload
	progression_manager = ProgressionManager
	
	if progression_manager:
		print("Connected to ProgressionManager autoload")
	else:
		print("Error: ProgressionManager autoload not found")

func _find_node_by_type(node: Node, type_name: String) -> Node:
	"""Recursively search for a node by its class name"""
	if node.get_script() != null:
		var script_path: String = node.get_script().resource_path
		if script_path.get_file().get_basename() == "progression_manager":
			return node
	
	for child in node.get_children():
		var result: Node = _find_node_by_type(child, type_name)
		if result != null:
			return result
	
	return null

# Convenience functions for common scenarios
func award_basic_fight_experience() -> void:
	"""Award experience for a basic fight (1-2 basic enemies)"""
	award_experience_for_fight(["basic", "basic"])

func award_elite_fight_experience() -> void:
	"""Award experience for an elite fight (1 elite enemy)"""
	award_experience_for_fight(["elite"])

func award_mixed_fight_experience() -> void:
	"""Award experience for a mixed fight (2 basic + 1 elite)"""
	award_experience_for_fight(["basic", "basic", "elite"])

func award_boss_fight_experience() -> void:
	"""Award experience for a boss fight"""
	award_experience_for_boss_fight("boss")

# Debug functions for testing
func debug_award_test_experience() -> void:
	"""Award some test experience for debugging"""
	print("Debug: Awarding test experience")
	_award_experience_to_class(participating_class, 150)

func debug_set_class_and_award(character_class: String, amount: int) -> void:
	"""Debug function to set class and award specific amount"""
	set_participating_class(character_class)
	_award_experience_to_class(character_class, amount) 