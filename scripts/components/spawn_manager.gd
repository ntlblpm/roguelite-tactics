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
@export var skeleton_knight_scene: PackedScene = preload("res://enemies/SkeletonKnight/SkeletonKnight.tscn")
@export var undead_mage_scene: PackedScene = preload("res://enemies/UndeadMage/UndeadMage.tscn")
@export var spirit_scene: PackedScene = preload("res://enemies/Spirit/Spirit.tscn")
@export var dark_lord_scene: PackedScene = preload("res://enemies/DarkLord/DarkLord.tscn")

# Starting positions for players
@export var starting_positions: Array[Vector2i] = [
	Vector2i(0, 0),    # Player 1
	Vector2i(-2, 2),   # Player 2
	Vector2i(2, -2)    # Player 3
]

# Grid manager reference (set by GameController)
var grid_manager: GridManager

# Starting positions for enemies
@export var enemy_spawn_positions: Array[Vector2i] = [
	Vector2i(3, -1),    # Top right area
	Vector2i(-3, 1),   # Bottom left area
	Vector2i(1, 3),    # Bottom right area
	Vector2i(-1, -3),  # Top left area
	Vector2i(4, 4)     # Far corner
]

# Dynamic spawn positions (can be set via room generation)
var dynamic_player_spawns: Array[Vector2i] = []
var dynamic_enemy_spawns: Array[Vector2i] = []

var spawn_parent: Node2D
var is_spawning_characters: bool = false
var spawned_player_characters: Dictionary = {} # peer_id -> BaseCharacter
var spawned_enemy_characters: Array[BaseCharacter] = []

func initialize(parent: Node2D) -> void:
	"""Initialize the spawn manager with a parent node for spawned entities"""
	spawn_parent = parent
	
	# Check if dynamic spawn positions were set from room generation
	if has_meta("player_spawns"):
		dynamic_player_spawns = get_meta("player_spawns")
	if has_meta("enemy_spawns"):
		dynamic_enemy_spawns = get_meta("enemy_spawns")

func spawn_all_characters(players_data: Array, enemy_types: Array = []) -> void:
	"""Spawn characters for all players and enemies"""
	if is_spawning_characters:
		return
	
	is_spawning_characters = true
	
	# Clear any existing characters first
	await clear_existing_characters()
	
	# Spawn player characters
	for i in range(players_data.size()):
		var player_data = players_data[i]
		var start_position: Vector2i
		
		# Use dynamic spawns if available, otherwise use default positions
		if dynamic_player_spawns.size() > 0:
			var position_index = i % dynamic_player_spawns.size()
			start_position = dynamic_player_spawns[position_index]
		else:
			var position_index = i % starting_positions.size()
			start_position = starting_positions[position_index]
		
		spawn_character(player_data.peer_id, player_data.selected_class, start_position)
	
	# Spawn enemies based on player count
	spawn_enemies_with_types(players_data.size(), enemy_types)
	
	is_spawning_characters = false
	
	# Emit signals
	characters_spawned.emit(spawned_player_characters, spawned_enemy_characters)
	spawn_completed.emit()

func spawn_character(peer_id: int, character_class: String, grid_position: Vector2i) -> BaseCharacter:
	"""Spawn a character for a specific player"""
	print("[SpawnManager] spawn_character called for peer %d, class %s at position %s" % [peer_id, character_class, grid_position])
	
	# Validate spawn position if grid manager is available
	if grid_manager:
		print("[SpawnManager] Validating spawn position %s with grid manager" % grid_position)
		if not grid_manager.is_position_walkable(grid_position):
			push_warning("[SpawnManager] Position %s is not walkable, finding nearest walkable tile" % grid_position)
			grid_position = _find_nearest_walkable_position(grid_position, grid_manager)
			print("[SpawnManager] New spawn position after validation: %s" % grid_position)
		else:
			print("[SpawnManager] Position %s is walkable, proceeding with spawn" % grid_position)
	else:
		push_warning("[SpawnManager] GridManager reference not set, spawning without position validation")
	
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

func spawn_enemies_with_types(player_count: int, enemy_types: Array) -> void:
	"""Spawn enemy characters with predetermined types for multiplayer sync"""
	# Use dynamic spawns if available, otherwise use default positions
	var spawn_positions := dynamic_enemy_spawns if dynamic_enemy_spawns.size() > 0 else enemy_spawn_positions
	print("SpawnManager: Available spawn positions: %d" % spawn_positions.size())
	
	# If enemy types weren't provided (host needs to generate them)
	if enemy_types.is_empty() and multiplayer.is_server():
		enemy_types = generate_enemy_types(player_count)
	
	# Spawn enemies based on the provided types
	for i in range(enemy_types.size()):
		if i < spawn_positions.size():
			print("SpawnManager: Spawning %s at position %s" % [enemy_types[i], spawn_positions[i]])
			spawn_enemy(enemy_types[i], spawn_positions[i], i)
		else:
			push_warning("No spawn position available for enemy #%d" % i)

func generate_enemy_types(player_count: int) -> Array:
	"""Generate enemy types array (host only)"""
	var types: Array = []
	
	# One skeleton per player
	for i in range(player_count):
		types.append("Skeleton")
	
	# One random enemy from the other types
	var random_enemy_types: Array[String] = ["SkeletonKnight", "UndeadMage", "DarkLord"]
	var random_type: String = random_enemy_types.pick_random()
	types.append(random_type)
	
	print("SpawnManager (Host): Generated enemy types: %s" % str(types))
	return types

func spawn_enemy(enemy_type: String, grid_position: Vector2i, enemy_id: int) -> BaseCharacter:
	"""Spawn a single enemy"""
	print("[SpawnManager] spawn_enemy called for type %s at position %s" % [enemy_type, grid_position])
	
	# Validate spawn position if grid manager is available
	if grid_manager:
		print("[SpawnManager] Validating enemy spawn position %s with grid manager" % grid_position)
		if not grid_manager.is_position_walkable(grid_position):
			push_warning("[SpawnManager] Enemy position %s is not walkable, finding nearest walkable tile" % grid_position)
			grid_position = _find_nearest_walkable_position(grid_position, grid_manager)
			print("[SpawnManager] New enemy spawn position after validation: %s" % grid_position)
		else:
			print("[SpawnManager] Enemy position %s is walkable, proceeding with spawn" % grid_position)
	else:
		push_warning("[SpawnManager] GridManager reference not set, spawning enemy without position validation")
	
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
		"SkeletonKnight":
			return skeleton_knight_scene
		"UndeadMage":
			return undead_mage_scene
		"Spirit":
			return spirit_scene
		"DarkLord":
			return dark_lord_scene
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

func _find_nearest_walkable_position(position: Vector2i, grid_manager: Node) -> Vector2i:
	"""Find the nearest walkable position to the given position using a spiral search"""
	print("[SpawnManager] Finding nearest walkable position to %s" % position)
	
	# Check if the current position is already walkable
	if grid_manager.is_position_walkable(position):
		print("[SpawnManager] Position %s is already walkable" % position)
		return position
	
	# Search in expanding rings around the position
	var positions_checked := 0
	for radius in range(1, 10):  # Search up to 10 tiles away
		print("[SpawnManager] Checking radius %d around position %s" % [radius, position])
		# Check all positions at this radius
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				# Only check positions on the ring edge
				if abs(dx) == radius or abs(dy) == radius:
					var check_pos := Vector2i(position.x + dx, position.y + dy)
					positions_checked += 1
					var is_walkable = grid_manager.is_position_walkable(check_pos)
					if positions_checked <= 20:  # Only print first 20 to avoid spam
						print("[SpawnManager] Checking position %s: walkable=%s" % [check_pos, is_walkable])
					if is_walkable:
						print("[SpawnManager] Found walkable position %s after checking %d positions" % [check_pos, positions_checked])
						return check_pos
	
	# If no walkable position found, return original (will likely cause issues)
	push_error("[SpawnManager] Could not find any walkable position near %s after checking %d positions" % [position, positions_checked])
	return position
