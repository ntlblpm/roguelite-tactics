class_name BaseCharacter
extends CharacterBody2D

## Base class for all playable characters with tactical combat stats and grid-based movement
## Manages HP, MP, AP resources and handles turn-based combat mechanics

# Combat stats
@export var max_health_points: int = GameConstants.DEFAULT_HEALTH_POINTS
@export var max_movement_points: int = GameConstants.DEFAULT_MOVEMENT_POINTS
@export var max_action_points: int = GameConstants.DEFAULT_ACTION_POINTS
@export var base_initiative: int = GameConstants.DEFAULT_INITIATIVE

var current_health_points: int = GameConstants.DEFAULT_HEALTH_POINTS
var current_movement_points: int = GameConstants.DEFAULT_MOVEMENT_POINTS
var current_action_points: int = GameConstants.DEFAULT_ACTION_POINTS
var current_initiative: int = GameConstants.DEFAULT_INITIATIVE

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

# Signals for UI updates
signal health_changed(current: int, maximum: int)
signal movement_points_changed(current: int, maximum: int)
signal action_points_changed(current: int, maximum: int)
signal turn_ended()
signal character_selected()
signal movement_completed(new_position: Vector2i)

# Reference to grid manager (will be set externally)
var grid_manager: Node = null

# Character type name for logging (override in subclasses)
var character_type: String = "Character"

func _ready() -> void:
	_initialize_stats()
	_setup_movement_tween()
	_setup_animation_signals()
	
	# Start with idle animation
	if animated_sprite:
		_play_animation(GameConstants.IDLE_ANIMATION_PREFIX)

func _initialize_stats() -> void:
	"""Initialize character stats to maximum values"""
	current_health_points = max_health_points
	current_movement_points = max_movement_points
	current_action_points = max_action_points
	current_initiative = base_initiative
	
	# Emit initial stat updates
	_emit_stat_updates()

func _setup_movement_tween() -> void:
	"""Create and configure the movement tween"""
	movement_tween = create_tween()
	movement_tween.stop()

func _setup_animation_signals() -> void:
	"""Connect animation finished signal"""
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)

func _emit_stat_updates() -> void:
	"""Emit all stat update signals for UI"""
	print("DEBUG: ", character_type, " emitting stat updates - HP: ", current_health_points, "/", max_health_points, " MP: ", current_movement_points, "/", max_movement_points, " AP: ", current_action_points, "/", max_action_points)
	health_changed.emit(current_health_points, max_health_points)
	movement_points_changed.emit(current_movement_points, max_movement_points)
	action_points_changed.emit(current_action_points, max_action_points)

func _play_animation(base_name: String, direction: GameConstants.Direction = current_facing_direction) -> void:
	"""Play an animation with the appropriate directional suffix"""
	if not animated_sprite:
		return
	
	var animation_name: String = base_name + GameConstants.get_direction_suffix(direction)
	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	else:
		print("Warning: Animation '", animation_name, "' not found!")

# Input handling moved to GameController to avoid conflicts

func attempt_move_to(target_position: Vector2i) -> bool:
	"""Attempt to move to a grid position using pathfinding, consuming MP if successful"""
	print("DEBUG: attempt_move_to called for target: ", target_position)
	print("DEBUG: current grid_position: ", grid_position)
	print("DEBUG: current_movement_points: ", current_movement_points)
	
	if not grid_manager or is_moving:
		print("DEBUG: No grid manager or already moving")
		return false
	
	# Check if target position is valid and pathable
	if not grid_manager.is_position_valid(target_position):
		print("DEBUG: Target position is not valid")
		return false
	
	if not grid_manager.is_position_walkable(target_position):
		print("DEBUG: Target position is not walkable")
		return false
	
	# Find path to target position
	var path: Array[Vector2i] = grid_manager.find_path(grid_position, target_position, current_movement_points)
	
	# Check if path exists and is within movement range
	if path.size() == 0:
		print("No valid path to target position or not enough movement points!")
		return false
	
	print("DEBUG: Found path with ", path.size(), " steps: ", path)
	
	# Calculate the actual movement cost of the path
	var movement_cost: int = _calculate_path_cost(path)
	
	# Check if we have enough MP
	if movement_cost > current_movement_points:
		print("Not enough movement points! Need: ", movement_cost, " Have: ", current_movement_points)
		return false
	
	# Execute the movement along the path
	_execute_path_movement(path, movement_cost)
	return true

func _calculate_path_cost(path: Array[Vector2i]) -> int:
	"""Calculate the total movement cost of a path"""
	# Since each step in the path costs exactly 1 movement point,
	# the total cost is simply the number of steps
	return path.size()

func _execute_path_movement(path: Array[Vector2i], cost: int) -> void:
	"""Execute movement along a path"""
	if path.size() == 0:
		return
	
	# Consume movement points
	current_movement_points -= cost
	movement_points_changed.emit(current_movement_points, max_movement_points)
	
	# Update grid position to final destination immediately
	grid_position = path[-1]
	target_grid_position = path[-1]
	
	# Emit movement completed signal immediately for instant range updates
	movement_completed.emit(grid_position)
	
	# Start movement animation along the path (direction will be set dynamically)
	_animate_path_movement(path)


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
	
	print("DEBUG: Path construction - grid_path: ", path)
	print("DEBUG: Path construction - final grid position should be: ", grid_position)
	print("DEBUG: Path construction - world_path: ", current_path)
	
	# Calculate total duration based on path length
	var total_duration: float = GameConstants.MOVEMENT_ANIMATION_DURATION * path.size()
	
	# Create new tween
	movement_tween = create_tween()
	movement_tween.set_ease(Tween.EASE_IN_OUT)
	movement_tween.set_trans(Tween.TRANS_SINE)
	
	# Use tween_method to smoothly interpolate through all path points
	print("DEBUG: Starting path animation with ", current_path.size(), " points, duration: ", total_duration)
	print("DEBUG: World path: ", current_path)
	movement_tween.tween_method(_interpolate_along_current_path, 0.0, 1.0, total_duration)
	movement_tween.tween_callback(_on_movement_complete)
	
	# Start with run animation in current direction, will be updated during movement
	_play_animation(GameConstants.RUN_ANIMATION_PREFIX, current_facing_direction)


func _interpolate_along_current_path(progress: float) -> void:
	"""Interpolate character position along current_path based on progress (0.0 to 1.0)"""
	if current_path.size() < 2:
		print("DEBUG: current_path too small: ", current_path.size())
		return
	
	# Special case: if we're at the very end, go to the final position
	if progress >= 1.0:
		global_position = current_path[-1]
		print("DEBUG: Final progress reached, setting to last position: ", global_position)
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
	
	# Debug output (less verbose)
	if int(progress * 100) % 20 == 0: # Only print every 20%
		print("DEBUG: progress=", progress, " segment=", segment_index, " moving to: ", new_position)
	
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
		print("DEBUG: Final position corrected to: ", global_position, " for grid: ", grid_position)
	
	# Return to idle animation in the current facing direction
	_play_animation(GameConstants.IDLE_ANIMATION_PREFIX)
	
	print("Movement animation completed at grid position: ", grid_position, " - MP remaining: ", current_movement_points)

func end_turn() -> void:
	"""End character's turn and refresh resources"""
	print("DEBUG: ", character_type, " ending turn - current MP: ", current_movement_points, " current AP: ", current_action_points)
	_refresh_resources()
	turn_ended.emit()
	print("DEBUG: ", character_type, " turn ended - new MP: ", current_movement_points, " new AP: ", current_action_points)

func _refresh_resources() -> void:
	"""Refresh MP and AP to maximum values"""
	print("DEBUG: ", character_type, " refreshing resources - before: MP=", current_movement_points, " AP=", current_action_points)
	current_movement_points = max_movement_points
	current_action_points = max_action_points
	print("DEBUG: ", character_type, " refreshing resources - after: MP=", current_movement_points, " AP=", current_action_points)
	_emit_stat_updates()
	print("DEBUG: ", character_type, " emitted stat updates")

func set_grid_position(new_position: Vector2i) -> void:
	"""Set the character's grid position (for initial placement)"""
	grid_position = new_position
	target_grid_position = new_position
	if grid_manager:
		global_position = grid_manager.grid_to_world(grid_position)

func take_damage(damage: int) -> void:
	"""Apply damage to the character"""
	current_health_points = max(0, current_health_points - damage)
	health_changed.emit(current_health_points, max_health_points)
	
	# Play damage animation
	_play_animation(GameConstants.TAKE_DAMAGE_ANIMATION_PREFIX)
	
	if current_health_points <= 0:
		_handle_death()

func heal(amount: int) -> void:
	"""Heal the character"""
	current_health_points = min(max_health_points, current_health_points + amount)
	health_changed.emit(current_health_points, max_health_points)

func _handle_death() -> void:
	"""Handle character death - override in subclasses for custom death messages"""
	print(character_type, " has died!")
	is_dead = true
	_play_animation(GameConstants.DIE_ANIMATION_PREFIX)

func get_stats_summary() -> String:
	"""Get a formatted string of current character stats"""
	return "HP: %d/%d | MP: %d/%d | AP: %d/%d | Init: %d" % [
		current_health_points, max_health_points,
		current_movement_points, max_movement_points,
		current_action_points, max_action_points,
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

func _on_animation_finished() -> void:
	"""Handle when an animation finishes playing"""
	if not animated_sprite:
		return
	
	var finished_animation: String = animated_sprite.animation
	
	# Handle damage animation completion - return to idle
	if finished_animation.begins_with(GameConstants.TAKE_DAMAGE_ANIMATION_PREFIX) and not is_dead:
		_play_animation(GameConstants.IDLE_ANIMATION_PREFIX)
	
	# For death animations, we want to stay on the final frame, so do nothing
	# The animation will automatically stop on the last frame since loop is false 