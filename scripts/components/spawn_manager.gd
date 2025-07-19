class_name SpawnManager
extends Node

## Manages character and enemy spawning for the game
## Handles scene instantiation, positioning, and multiplayer authority

signal characters_spawned(player_characters: Dictionary, enemy_characters: Array)
signal spawn_completed()

# Scene references for all character classes
@export var knight_scene: PackedScene = preload("res://players/Knight/Knight.tscn")
@export var ranger_scene: PackedScene = preload("res://players/Ranger/Ranger.tscn")
@export var pyromancer_scene: PackedScene = preload("res://players/Pyromancer/Pyromancer.tscn")
@export var assassin_scene: PackedScene = preload("res://players/Assassin/Assassin.tscn")

# Scene references for enemies
@export var skeleton_scene: PackedScene = preload("res://enemies/Skeleton/Skeleton.tscn")

# Starting positions for players
@export var starting_positions: Array[Vector2i] = [
	Vector2i(0, 0),    # Player 1
	Vector2i(-2, 2),   # Player 2
	Vector2i(2, -2)    # Player 3
]

# Starting positions for enemies
@export var enemy_spawn_positions: Array[Vector2i] = [
	Vector2i(3, -1)    # Single skeleton in top right area
]

var spawn_parent: Node2D
var is_spawning_characters: bool = false
var spawned_player_characters: Dictionary = {} # peer_id -> BaseCharacter
var spawned_enemy_characters: Array[BaseCharacter] = []

func initialize(parent: Node2D) -> void:
	"""Initialize the spawn manager with a parent node for spawned entities"""
	spawn_parent = parent

func spawn_all_characters(players_data: Array) -> void:
	"""Spawn characters for all players and enemies"""
	if is_spawning_characters:
		return
	
	is_spawning_characters = true
	
	# Clear any existing characters first
	await clear_existing_characters()
	
	# Spawn player characters
	for i in range(players_data.size()):
		var player_data = players_data[i]
		var position_index = i % starting_positions.size()
		var start_position = starting_positions[position_index]
		
		spawn_character(player_data.peer_id, player_data.selected_class, start_position)
	
	# Spawn enemies
	spawn_enemies()
	
	is_spawning_characters = false
	
	# Emit signals
	characters_spawned.emit(spawned_player_characters, spawned_enemy_characters)
	spawn_completed.emit()

func spawn_character(peer_id: int, character_class: String, grid_position: Vector2i) -> BaseCharacter:
	"""Spawn a character for a specific player"""
	var character_scene: PackedScene = get_character_scene(character_class)
	
	if not character_scene:
		push_error("No scene found for character class: " + character_class)
		return null
	
	# Instantiate the character
	var character = character_scene.instantiate() as BaseCharacter
	character.name = character_class + "_" + str(peer_id)
	
	# Set multiplayer authority
	character.set_multiplayer_authority(peer_id)
	
	# Position character
	character.grid_position = grid_position
	character.target_grid_position = grid_position
	
	# Add to scene
	if spawn_parent:
		spawn_parent.add_child(character)
	
	# Store reference
	spawned_player_characters[peer_id] = character
	
	# Ensure character renders above movement highlights
	character.z_index = 2
	
	return character

func spawn_enemies() -> void:
	"""Spawn enemy characters"""
	# Spawn skeletons at predefined positions
	for i in range(min(1, enemy_spawn_positions.size())):  # Spawn up to 1 skeleton
		var spawn_position = enemy_spawn_positions[i]
		spawn_enemy("Skeleton", spawn_position, i)

func spawn_enemy(enemy_type: String, grid_position: Vector2i, enemy_id: int) -> BaseCharacter:
	"""Spawn a single enemy"""
	var enemy_scene: PackedScene = get_enemy_scene(enemy_type)
	
	if not enemy_scene:
		push_error("No scene found for enemy type: " + enemy_type)
		return null
	
	# Instantiate the enemy
	var enemy = enemy_scene.instantiate() as BaseCharacter
	enemy.name = enemy_type + "_" + str(enemy_id)
	
	# Set multiplayer authority to host (enemies are controlled by host)
	enemy.set_multiplayer_authority(1)
	
	# Position enemy
	enemy.grid_position = grid_position
	enemy.target_grid_position = grid_position
	
	# Add to scene
	if spawn_parent:
		spawn_parent.add_child(enemy)
	
	# Store reference
	spawned_enemy_characters.append(enemy)
	
	# Ensure enemy renders above movement highlights
	enemy.z_index = 2
	
	return enemy

func clear_existing_characters() -> void:
	"""Clear any existing characters to prevent duplicates"""
	# Clear player characters
	for peer_id in spawned_player_characters.keys():
		var character = spawned_player_characters[peer_id]
		if character and is_instance_valid(character):
			character.queue_free()
	
	spawned_player_characters.clear()
	
	# Clear enemies
	for enemy in spawned_enemy_characters:
		if enemy and is_instance_valid(enemy):
			enemy.queue_free()
	
	spawned_enemy_characters.clear()
	
	# Only wait a frame if we're still in the tree
	if is_inside_tree() and get_tree():
		await get_tree().process_frame

func get_character_scene(character_class: String) -> PackedScene:
	"""Get the appropriate scene for a character class"""
	match character_class:
		"Knight":
			return knight_scene
		"Ranger":
			return ranger_scene
		"Pyromancer":
			return pyromancer_scene
		"Assassin":
			return assassin_scene
		_:
			return knight_scene

func get_enemy_scene(enemy_type: String) -> PackedScene:
	"""Get the appropriate scene for an enemy type"""
	match enemy_type:
		"Skeleton":
			return skeleton_scene
		_:
			return skeleton_scene

func get_player_characters() -> Dictionary:
	"""Get all spawned player characters"""
	return spawned_player_characters

func get_enemy_characters() -> Array[BaseCharacter]:
	"""Get all spawned enemy characters"""
	return spawned_enemy_characters

func get_all_characters() -> Array[BaseCharacter]:
	"""Get all characters (players and enemies)"""
	var characters: Array[BaseCharacter] = []
	# Add player characters
	for character in spawned_player_characters.values():
		characters.append(character)
	# Add enemy characters
	for enemy in spawned_enemy_characters:
		characters.append(enemy)
	return characters
