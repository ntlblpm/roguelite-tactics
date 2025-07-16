class_name SwordsmanCharacter
extends CharacterBody2D

## Swordsman character with tactical combat stats and grid-based movement
## Manages HP, MP, AP resources and handles turn-based combat mechanics

# Combat stats
@export var max_health_points: int = GameConstants.DEFAULT_HEALTH_POINTS
@export var max_movement_points: int = GameConstants.DEFAULT_MOVEMENT_POINTS
@export var max_action_points: int = GameConstants.DEFAULT_ACTION_POINTS

var current_health_points: int = GameConstants.DEFAULT_HEALTH_POINTS
var current_movement_points: int = GameConstants.DEFAULT_MOVEMENT_POINTS
var current_action_points: int = GameConstants.DEFAULT_ACTION_POINTS

# Grid position
var grid_position: Vector2i = Vector2i.ZERO
var target_grid_position: Vector2i = Vector2i.ZERO
var is_moving: bool = false

# Movement and animation
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var movement_tween: Tween

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
	"""Attempt to move to a grid position, consuming MP if successful"""
	if not grid_manager or is_moving:
		return false
	
	# Check if target position is valid and pathable
	if not grid_manager.is_position_valid(target_position) or not grid_manager.is_position_walkable(target_position):
		return false
	
	# Calculate movement cost using grid manager
	var movement_cost: int = grid_manager.calculate_movement_cost(grid_position, target_position)
	
	# Check if we have enough MP
	if movement_cost > current_movement_points:
		print("Not enough movement points! Need: ", movement_cost, " Have: ", current_movement_points)
		return false
	
	# Execute the movement
	_execute_movement(target_position, movement_cost)
	return true

func _execute_movement(target_position: Vector2i, cost: int) -> void:
	"""Execute movement to target position"""
	# Determine movement direction and update facing
	current_facing_direction = GameConstants.determine_movement_direction(grid_position, target_position)
	
	# Consume movement points
	current_movement_points -= cost
	movement_points_changed.emit(current_movement_points, max_movement_points)
	
	# Update grid position immediately (before animation)
	grid_position = target_position
	target_grid_position = target_position
	
	# Emit movement completed signal immediately for instant range updates
	movement_completed.emit(grid_position)
	
	# Start movement animation
	_animate_movement_to_position(grid_manager.grid_to_world(target_position))

func _animate_movement_to_position(world_position: Vector2) -> void:
	"""Animate character movement to world position"""
	is_moving = true
	
	# Stop any existing tween
	if movement_tween:
		movement_tween.kill()
	
	# Create new tween
	movement_tween = create_tween()
	movement_tween.set_ease(Tween.EASE_OUT)
	movement_tween.set_trans(Tween.TRANS_QUART)
	
	# Animate position
	movement_tween.tween_property(self, "global_position", world_position, GameConstants.MOVEMENT_ANIMATION_DURATION)
	movement_tween.tween_callback(_on_movement_complete)
	
	# Play appropriate movement animation in the correct direction
	_play_animation(GameConstants.RUN_ANIMATION_PREFIX)

func _on_movement_complete() -> void:
	"""Called when movement animation is complete"""
	is_moving = false
	
	# Return to idle animation in the current facing direction
	_play_animation(GameConstants.IDLE_ANIMATION_PREFIX)
	
	print("Movement animation completed at grid position: ", grid_position, " - MP remaining: ", current_movement_points)

func end_turn() -> void:
	"""End character's turn and refresh resources"""
	_refresh_resources()
	turn_ended.emit()
	print("Turn ended - Resources refreshed")

func _refresh_resources() -> void:
	"""Refresh MP and AP to maximum values"""
	current_movement_points = max_movement_points
	current_action_points = max_action_points
	_emit_stat_updates()

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
	"""Handle character death"""
	print("Swordsman has died!")
	is_dead = true
	_play_animation(GameConstants.DIE_ANIMATION_PREFIX)

func get_stats_summary() -> String:
	"""Get a formatted string of current character stats"""
	return "HP: %d/%d | MP: %d/%d | AP: %d/%d" % [
		current_health_points, max_health_points,
		current_movement_points, max_movement_points,
		current_action_points, max_action_points
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
