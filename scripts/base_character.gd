class_name BaseCharacter
extends CharacterBody2D

## Base class for all playable characters with tactical combat stats and grid-based movement
## Manages HP, MP, AP resources and handles turn-based combat mechanics

# Combat stats
@export var base_initiative: int = GameConstants.DEFAULT_INITIATIVE
var current_initiative: int = GameConstants.DEFAULT_INITIATIVE

# Combatant resources component
@onready var resources: CombatantResourcesComponent = $CombatantResourcesComponent

# Grid position
var grid_position: Vector2i = Vector2i.ZERO
var target_grid_position: Vector2i = Vector2i.ZERO
var is_moving: bool = false

# Movement and animation
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var movement_tween: Tween
var current_path: Array[Vector2] = []

# Animation state tracking
var is_dead: bool = false

# Direction tracking for animations
var current_facing_direction: GameConstants.Direction = GameConstants.Direction.BOTTOM_RIGHT

# Signals for UI updates (forwarded from resources component)
signal health_changed(current: int, maximum: int)
signal movement_points_changed(current: int, maximum: int)
signal ability_points_changed(current: int, maximum: int)
signal turn_ended()
signal character_selected()
signal movement_completed(new_position: Vector2i)
signal character_died(character: BaseCharacter)
signal death_sequence_completed()

# Reference to grid manager (will be set externally)
var grid_manager: Node = null

# Character type name for logging (override in subclasses)
var character_type: String = "Character"

# Material management for outline shader
var default_material: ShaderMaterial = null
var current_turn_material: ShaderMaterial = null
var is_current_turn: bool = false

# Material resource paths
const PLAYER_OUTLINE_MATERIAL_PATH: String = "res://resources/materials/player_outline_material.tres"
const ENEMY_OUTLINE_MATERIAL_PATH: String = "res://resources/materials/enemy_outline_material.tres"
const CURRENT_PLAYER_OUTLINE_MATERIAL_PATH: String = "res://resources/materials/current_player_outline_material.tres"
const CURRENT_ENEMY_OUTLINE_MATERIAL_PATH: String = "res://resources/materials/current_enemy_outline_material.tres"

func _ready() -> void:
	_initialize_stats()
	_setup_movement_tween()
	_setup_animation_signals()
	_initialize_materials()
	_connect_turn_signals()
	_connect_resource_signals()
	
	# Start with idle animation
	if animated_sprite:
		_play_animation(GameConstants.IDLE_ANIMATION_PREFIX)

func _exit_tree() -> void:
	"""Cleanup when the character is being destroyed"""
	
	# Stop any running tweens
	if movement_tween and movement_tween.is_valid():
		movement_tween.kill()
		movement_tween = null
	
	# Clear animation signals
	if animated_sprite and animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_animation_finished)
	
	# Disconnect turn manager signals
	_disconnect_turn_signals()
	
	# Unregister from grid manager
	if grid_manager:
		grid_manager.unregister_character(self)
	
	# Clear references
	grid_manager = null
	current_path.clear()
	default_material = null
	current_turn_material = null
	
	# Reset state to clean values
	is_moving = false
	is_dead = false
	is_current_turn = false

func _initialize_stats() -> void:
	"""Initialize character stats to maximum values"""
	current_initiative = base_initiative

func _setup_movement_tween() -> void:
	"""Create and configure the movement tween"""
	movement_tween = create_tween()
	movement_tween.stop()

func _setup_animation_signals() -> void:
	"""Connect animation finished signal"""
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)

func _initialize_materials() -> void:
	"""Initialize outline materials based on character type"""
	if not animated_sprite:
		return
	
	# Load appropriate materials based on character type
	if is_ai_controlled():
		# Enemy materials
		default_material = load(ENEMY_OUTLINE_MATERIAL_PATH) as ShaderMaterial
		current_turn_material = load(CURRENT_ENEMY_OUTLINE_MATERIAL_PATH) as ShaderMaterial
	else:
		# Player materials
		default_material = load(PLAYER_OUTLINE_MATERIAL_PATH) as ShaderMaterial
		current_turn_material = load(CURRENT_PLAYER_OUTLINE_MATERIAL_PATH) as ShaderMaterial
	
	# Apply default material
	_apply_default_material()

func _connect_turn_signals() -> void:
	"""Connect to turn manager signals for material switching"""
	# Find the turn manager in the scene tree
	var turn_manager: TurnManager = get_tree().get_first_node_in_group("turn_manager")
	if not turn_manager:
		# Try to find it by type in the scene
		turn_manager = _find_turn_manager_in_scene()
	
	if turn_manager:
		# Connect to turn signals
		if not turn_manager.turn_started.is_connected(_on_turn_started):
			turn_manager.turn_started.connect(_on_turn_started)
		if not turn_manager.turn_ended.is_connected(_on_turn_ended):
			turn_manager.turn_ended.connect(_on_turn_ended)

func _find_turn_manager_in_scene() -> TurnManager:
	"""Find TurnManager in the scene tree"""
	var root = get_tree().get_root()
	return _recursive_find_turn_manager(root)

func _recursive_find_turn_manager(node: Node) -> TurnManager:
	"""Recursively search for TurnManager in node tree"""
	if node is TurnManager:
		return node as TurnManager
	
	for child in node.get_children():
		var result = _recursive_find_turn_manager(child)
		if result:
			return result
	
	return null

func _on_turn_started(character: BaseCharacter) -> void:
	"""Handle when a turn starts"""
	if character == self:
		is_current_turn = true
		_apply_current_turn_material()
	else:
		is_current_turn = false
		_apply_default_material()

func _on_turn_ended(character: BaseCharacter) -> void:
	"""Handle when a turn ends"""
	if character == self:
		is_current_turn = false
		_apply_default_material()

func _apply_default_material() -> void:
	"""Apply the default outline material"""
	if animated_sprite and default_material:
		animated_sprite.material = default_material

func _apply_current_turn_material() -> void:
	"""Apply the current turn outline material"""
	if animated_sprite and current_turn_material:
		animated_sprite.material = current_turn_material

func set_material_override(material: ShaderMaterial) -> void:
	"""Manually set a material override (useful for special effects)"""
	if animated_sprite:
		animated_sprite.material = material

func get_current_material() -> ShaderMaterial:
	"""Get the currently applied material"""
	if animated_sprite:
		return animated_sprite.material as ShaderMaterial
	return null


func _disconnect_turn_signals() -> void:
	"""Disconnect from turn manager signals during cleanup"""
	var turn_manager: TurnManager = get_tree().get_first_node_in_group("turn_manager")
	if not turn_manager:
		turn_manager = _find_turn_manager_in_scene()
	
	if turn_manager:
		# Disconnect turn signals
		if turn_manager.turn_started.is_connected(_on_turn_started):
			turn_manager.turn_started.disconnect(_on_turn_started)
		if turn_manager.turn_ended.is_connected(_on_turn_ended):
			turn_manager.turn_ended.disconnect(_on_turn_ended)

func _connect_resource_signals() -> void:
	"""Connect resource component signals to forward them"""
	if resources:
		resources.health_changed.connect(_on_health_changed)
		resources.movement_points_changed.connect(_on_movement_points_changed)
		resources.ability_points_changed.connect(_on_ability_points_changed)
		resources.resources_depleted.connect(_on_resources_depleted)

func _on_health_changed(current: int, maximum: int) -> void:
	"""Forward health changed signal"""
	health_changed.emit(current, maximum)

func _on_movement_points_changed(current: int, maximum: int) -> void:
	"""Forward movement points changed signal"""
	movement_points_changed.emit(current, maximum)

func _on_ability_points_changed(current: int, maximum: int) -> void:
	"""Forward ability points changed signal"""
	ability_points_changed.emit(current, maximum)

func _on_resources_depleted() -> void:
	"""Handle when resources are depleted (HP reaches 0)"""
	request_death()

func _play_animation(base_name: String, direction: GameConstants.Direction = current_facing_direction) -> void:
	"""Play an animation with the appropriate directional suffix, with fallback support"""
	if not animated_sprite:
		return
	
	var direction_suffix = GameConstants.get_direction_suffix(direction)
	var animation_name: String = base_name + direction_suffix
	
	# Try directional animation first
	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
		return
	
	# Fallback: try "Takedamage" variant (inconsistent casing in scene files)
	if base_name == "TakeDamage":
		var alt_name = "Takedamage" + direction_suffix
		if animated_sprite.sprite_frames.has_animation(alt_name):
			animated_sprite.play(alt_name)
			return
	
	# Fallback: try lowercase variant for other naming inconsistencies
	var lowercase_name = base_name.to_lower() + direction_suffix
	if animated_sprite.sprite_frames.has_animation(lowercase_name):
		animated_sprite.play(lowercase_name)
		return
	
	# Fallback: try non-directional animation (just the base name)
	if animated_sprite.sprite_frames.has_animation(base_name):
		animated_sprite.play(base_name)
		return
	
	# Fallback: try lowercase base name
	if animated_sprite.sprite_frames.has_animation(base_name.to_lower()):
		animated_sprite.play(base_name.to_lower())
		return
	

@rpc("call_local", "any_peer", "reliable")
func _play_animation_synchronized(base_name: String, direction: GameConstants.Direction = current_facing_direction) -> void:
	"""Play an animation synchronized across all clients via RPC"""
	# Update facing direction for all clients
	current_facing_direction = direction
	
	# Play the animation on all clients
	_play_animation(base_name, direction)

# Input handling moved to GameController to avoid conflicts

func attempt_move_to(target_position: Vector2i) -> bool:
	"""Attempt to move to a grid position using pathfinding, consuming MP if successful"""
	
	if not grid_manager or is_moving:
		return false
	
	# Check if target position is valid and pathable
	if not grid_manager.is_position_valid(target_position):
		return false
	
	if not grid_manager.is_position_walkable(target_position, self):
		return false
	
	# Find path to target position
	var path: Array[Vector2i] = grid_manager.find_path(grid_position, target_position, resources.get_movement_points(), self)
	
	# Check if path exists and is within movement range
	if path.size() == 0:
		return false
	
	# Calculate the actual movement cost of the path
	var movement_cost: int = _calculate_path_cost(path)
	
	# Check if we have enough MP
	if movement_cost > resources.get_movement_points():
		return false
	
	# Execute the movement via RPC to synchronize across all clients
	_execute_networked_movement.rpc(path, movement_cost)
	return true

@rpc("any_peer", "call_local", "reliable")
func _execute_networked_movement(path: Array[Vector2i], cost: int) -> void:
	"""Execute movement across all clients (RPC method)"""
	_execute_path_movement(path, cost)

func _calculate_path_cost(path: Array[Vector2i]) -> int:
	"""Calculate the total movement cost of a path"""
	# Since each step in the path costs exactly 1 movement point,
	# the total cost is simply the number of steps
	return path.size()

func _execute_path_movement(path: Array[Vector2i], cost: int) -> void:
	"""Execute movement along a path"""
	if path.size() == 0:
		return
	
	# Consume movement points (only on the character owner's client)
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		resources.consume_movement_points(cost)
	
	# Update grid position to final destination on all clients
	var old_position = grid_position
	grid_position = path[-1]
	target_grid_position = path[-1]
	
	# Update grid manager position tracking
	if grid_manager:
		grid_manager.move_character_position(self, old_position, grid_position)
	
	# Emit movement completed signal for grid manager updates
	movement_completed.emit(grid_position)
	
	# Start movement animation on all clients
	_animate_path_movement(path)


@rpc("any_peer", "call_local", "reliable")
func _sync_position(new_grid_position: Vector2i) -> void:
	"""Synchronize character position across all clients"""
	grid_position = new_grid_position
	target_grid_position = new_grid_position
	
	# Update world position
	if grid_manager:
		global_position = grid_manager.grid_to_world(grid_position)

func _animate_path_movement(path: Array[Vector2i]) -> void:
	"""Animate character movement along a path"""
	if path.size() == 0:
		return
	
	is_moving = true
	
	# Stop any existing tween
	if movement_tween:
		movement_tween.kill()
	
	# Convert path to world positions
	current_path = []
	current_path.append(global_position) # Start from current position
	for grid_pos in path:
		current_path.append(grid_manager.grid_to_world(grid_pos))
	
	# Calculate total duration based on path length
	var total_duration: float = GameConstants.MOVEMENT_ANIMATION_DURATION * path.size()
	
	# Create new tween
	movement_tween = create_tween()
	movement_tween.set_ease(Tween.EASE_IN_OUT)
	movement_tween.set_trans(Tween.TRANS_SINE)
	
	# Use tween_method to smoothly interpolate through all path points
	movement_tween.tween_method(_interpolate_along_current_path, 0.0, 1.0, total_duration)
	movement_tween.tween_callback(_on_movement_complete)
	
	# Start with run animation in current direction, will be updated during movement
	_play_animation(GameConstants.RUN_ANIMATION_PREFIX, current_facing_direction)

func _interpolate_along_current_path(progress: float) -> void:
	"""Interpolate character position along current_path based on progress (0.0 to 1.0)"""
	if current_path.size() < 2:
		return
	
	# Special case: if we're at the very end, go to the final position
	if progress >= 1.0:
		global_position = current_path[-1]
		return
	
	# Calculate which segment we're in and the local progress within that segment
	var segment_count: int = current_path.size() - 1
	var scaled_progress: float = progress * segment_count
	var segment_index: int = int(scaled_progress)
	var segment_progress: float = scaled_progress - segment_index
	
	# Clamp to valid range
	segment_index = clamp(segment_index, 0, segment_count - 1)
	segment_progress = clamp(segment_progress, 0.0, 1.0)
	
	# Interpolate between the two points in the current segment
	var start_pos: Vector2 = current_path[segment_index]
	var end_pos: Vector2 = current_path[segment_index + 1]
	var new_position: Vector2 = start_pos.lerp(end_pos, segment_progress)
	
	# Update facing direction based on current movement direction
	_update_facing_direction_for_movement(start_pos, end_pos)
	
	# Set the position
	global_position = new_position

func _update_facing_direction_for_movement(start_pos: Vector2, end_pos: Vector2) -> void:
	"""Update character facing direction based on movement vector"""
	var movement_vector: Vector2 = end_pos - start_pos
	
	# Only update direction if there's actual movement
	if movement_vector.length() > 0.1:
		# Convert world movement to grid movement to use existing direction logic
		var start_grid: Vector2i = grid_manager.world_to_grid(start_pos)
		var end_grid: Vector2i = grid_manager.world_to_grid(end_pos)
		
		var new_direction: GameConstants.Direction = GameConstants.determine_movement_direction(start_grid, end_grid)
		
		# Update direction and ensure run animation is playing
		if new_direction != current_facing_direction:
			current_facing_direction = new_direction
			_play_animation(GameConstants.RUN_ANIMATION_PREFIX, current_facing_direction)
		else:
			# Even if direction didn't change, make sure we're playing the run animation
			# This handles the case where the character was idle and starts moving in the same direction
			if not animated_sprite.animation.begins_with(GameConstants.RUN_ANIMATION_PREFIX):
				_play_animation(GameConstants.RUN_ANIMATION_PREFIX, current_facing_direction)

func _on_movement_complete() -> void:
	"""Called when movement animation is complete"""
	is_moving = false
	
	# Ensure visual position matches the final grid position
	if grid_manager:
		global_position = grid_manager.grid_to_world(grid_position)
	
	# Return to idle animation in the current facing direction
	_play_animation(GameConstants.IDLE_ANIMATION_PREFIX)

func end_turn() -> void:
	"""End character's turn and refresh resources"""
	_refresh_resources()
	turn_ended.emit()

func _refresh_resources() -> void:
	"""Refresh MP and AP to maximum values"""
	resources.refresh_resources()


func is_ai_controlled() -> bool:
	"""Check if this character is AI controlled - override in enemy classes"""
	return false

func set_grid_position(new_position: Vector2i) -> void:
	"""Set the character's grid position (for initial placement)"""
	grid_position = new_position
	target_grid_position = new_position
	if grid_manager:
		global_position = grid_manager.grid_to_world(grid_position)
		# Register character position with grid manager
		grid_manager.register_character_position(self, grid_position)


func heal(amount: int) -> void:
	"""Heal the character"""
	resources.heal(amount)


@rpc("any_peer", "call_remote", "reliable")
func request_death() -> void:
	"""Request character death - validated by host"""
	if not multiplayer.is_server():
		return
	
	# Validate death conditions
	if is_dead or resources.current_health_points > 0:
		return
	
	# Host authorizes death and broadcasts to all peers
	_start_death_sequence.rpc()

@rpc("authority", "call_local", "reliable")
func _start_death_sequence() -> void:
	"""Start the death sequence on all peers"""
	if is_dead:
		return
	
	is_dead = true
	character_died.emit(self)
	
	# Start the visual death sequence
	await _do_death_sequence()
	
	# Notify turn manager that death sequence is complete
	death_sequence_completed.emit()

func _do_death_sequence() -> void:
	"""Perform the visual death sequence"""
	# Play death animation if available
	_play_animation(GameConstants.DIE_ANIMATION_PREFIX)
	
	# Wait for death animation to complete
	if animated_sprite and animated_sprite.animation != "":
		await animated_sprite.animation_finished
	
	# Apply fade effect
	var fade_shader = preload("res://shaders/fade_shader.gdshader")
	if fade_shader and animated_sprite:
		var material = ShaderMaterial.new()
		material.shader = fade_shader
		material.set_shader_parameter("u_alpha", 1.0)
		animated_sprite.material = material
		
		# Animate fade out
		var fade_tween = create_tween()
		fade_tween.tween_property(material, "shader_parameter/u_alpha", 0.0, 1.0)
		await fade_tween.finished
	else:
		# Fallback: use modulate alpha
		var fade_tween = create_tween()
		fade_tween.tween_property(self, "modulate:a", 0.0, 1.0)
		await fade_tween.finished
	
	# Remove from grid
	if grid_manager:
		grid_manager.unregister_character(self)
	
	# Let subclasses do custom cleanup
	_handle_death()
	
	# Remove from scene
	queue_free()

func _handle_death() -> void:
	"""Handle character death - override in subclasses for custom death messages"""
	pass

func get_stats_summary() -> String:
	"""Get a formatted string of current character stats"""
	return "%s | Init: %d" % [
		resources.get_stats_summary(),
		current_initiative
	]

func set_facing_direction(direction: GameConstants.Direction) -> void:
	"""Manually set the character's facing direction"""
	current_facing_direction = direction
	if not is_moving:
		_play_animation(GameConstants.IDLE_ANIMATION_PREFIX)

func get_facing_direction() -> GameConstants.Direction:
	"""Get the character's current facing direction"""
	return current_facing_direction

func get_character_state() -> Dictionary:
	"""Get current character state for synchronization"""
	return {
		"grid_position": grid_position,
		"target_grid_position": target_grid_position,
		"resources": resources.get_resource_state(),
		"current_initiative": current_initiative,
		"current_facing_direction": current_facing_direction,
		"is_moving": is_moving,
		"is_dead": is_dead,
		"is_current_turn": is_current_turn
	}

func set_character_state(state: Dictionary) -> void:
	"""Set character state from synchronization data"""
	
	grid_position = state.get("grid_position", Vector2i.ZERO)
	target_grid_position = state.get("target_grid_position", Vector2i.ZERO)
	
	# Set resource state if provided
	if state.has("resources") and resources:
		resources.set_resource_state(state.resources)
	
	current_initiative = state.get("current_initiative", base_initiative)
	current_facing_direction = state.get("current_facing_direction", GameConstants.Direction.BOTTOM_RIGHT)
	is_moving = state.get("is_moving", false)
	is_dead = state.get("is_dead", false)
	is_current_turn = state.get("is_current_turn", false)
	
	# Update material based on turn state
	if is_current_turn:
		_apply_current_turn_material()
	else:
		_apply_default_material()
	
	# Update world position
	if grid_manager:
		global_position = grid_manager.grid_to_world(grid_position)
		# Register character position with grid manager
		grid_manager.register_character_position(self, grid_position)

@rpc("any_peer", "call_local", "reliable")
func _sync_character_state(state: Dictionary) -> void:
	"""Synchronize complete character state across all clients"""
	set_character_state(state)

func _on_animation_finished() -> void:
	"""Handle when an animation finishes playing"""
	if not animated_sprite:
		return
	
	var finished_animation: String = animated_sprite.animation
	
	# Don't return to idle if character is dead
	if is_dead:
		return
	
	# For death animations, we want to stay on the final frame
	if finished_animation.begins_with(GameConstants.DIE_ANIMATION_PREFIX):
		return
	
	# Return to idle after any non-looping animation finishes
	# This includes: Attack, Special, Taunt, TakeDamage, etc.
	# The animated sprite will stop on these animations since they have loop = false
	_play_animation(GameConstants.IDLE_ANIMATION_PREFIX) 
