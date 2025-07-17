class_name BaseEnemy
extends BaseCharacter

## Base class for all enemy characters with AI behavior
## Provides automated turn logic, pathfinding, and targeting for enemy AI

# AI behavior constants
const AI_TURN_DELAY: float = 1.0  # Delay before AI takes action for visual clarity

# Target tracking
var current_target: BaseCharacter = null
var available_targets: Array[BaseCharacter] = []

# AI state
var is_ai_turn_active: bool = false

# Signals for AI actions
signal ai_turn_started()
signal ai_turn_completed()
signal ai_action_performed(action_type: String)

func _ready() -> void:
	# Set character type for base enemy (override in subclasses)
	character_type = "Enemy"
	super()

func _exit_tree() -> void:
	"""Cleanup AI-specific resources"""
	_stop_ai_turn()
	super()

## AI Turn Management

func start_ai_turn() -> void:
	"""Start the AI turn with a visual delay"""
	if is_ai_turn_active:
		print("WARNING: AI turn already active for ", character_type)
		return
	
	print("=== AI TURN STARTED: ", character_type, " ===")
	is_ai_turn_active = true
	ai_turn_started.emit()
	
	# Add visual delay for better player experience
	await get_tree().create_timer(AI_TURN_DELAY).timeout
	
	# Execute AI logic
	_execute_ai_logic()

func _execute_ai_logic() -> void:
	"""Main AI logic - find targets, move, and attack"""
	if not is_ai_turn_active:
		return
	
	print("Executing AI logic for ", character_type)
	
	# Find available targets
	_update_available_targets()
	
	if available_targets.is_empty():
		print("No targets found for ", character_type)
		_end_ai_turn()
		return
	
	# Select best target
	current_target = _select_best_target()
	if not current_target:
		print("No valid target selected for ", character_type)
		_end_ai_turn()
		return
	
	print(character_type, " targeting: ", current_target.character_type, " at ", current_target.grid_position)
	
	# Execute AI actions (movement and/or attack)
	await _execute_ai_actions()
	
	# End turn
	_end_ai_turn()

func _execute_ai_actions() -> void:
	"""Execute movement and attack actions based on AI logic"""
	var target_position = current_target.grid_position
	var current_position = grid_position
	
	# Check if already adjacent to target
	if _is_adjacent_to_target(current_position, target_position):
		print(character_type, " is already adjacent to target, attempting attack")
		await _attempt_attack()
		return
	
	# Try to move closer to target
	var best_move_position = _find_best_move_position()
	if best_move_position != Vector2i(-999, -999):
		print(character_type, " moving from ", current_position, " to ", best_move_position)
		await _perform_movement(best_move_position)
		
		# Check if now adjacent after movement
		if _is_adjacent_to_target(grid_position, target_position):
			print(character_type, " is now adjacent after movement, attempting attack")
			await _attempt_attack()
	else:
		print(character_type, " cannot move closer to target")

func _end_ai_turn() -> void:
	"""Complete the AI turn and end"""
	if not is_ai_turn_active:
		return
	
	print("=== AI TURN ENDED: ", character_type, " ===")
	is_ai_turn_active = false
	ai_turn_completed.emit()
	
	# End the character's turn (this will refresh AP/MP and signal turn manager)
	end_turn()

func _stop_ai_turn() -> void:
	"""Force stop AI turn (for cleanup)"""
	is_ai_turn_active = false

## Target Selection and Management

func _update_available_targets() -> void:
	"""Find all valid targets (player characters)"""
	available_targets.clear()
	
	if not grid_manager:
		print("ERROR: No grid manager found for enemy targeting")
		return
	
	# Get all characters from grid manager's character positions
	for character in grid_manager.character_positions.keys():
		if character != self and character is BaseCharacter and not character.is_dead:
			# Only target player characters (not other enemies)
			if not character is BaseEnemy:
				available_targets.append(character)
	
	print(character_type, " found ", available_targets.size(), " potential targets")

func _select_best_target() -> BaseCharacter:
	"""Select the best target using distance and RNG for ties"""
	if available_targets.is_empty():
		return null
	
	# Calculate distances to all targets
	var target_distances: Array[Dictionary] = []
	
	for target in available_targets:
		var distance = _calculate_grid_distance(grid_position, target.grid_position)
		target_distances.append({
			"target": target,
			"distance": distance
		})
	
	# Sort by distance (closest first)
	target_distances.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Find all targets at minimum distance
	var min_distance = target_distances[0].distance
	var closest_targets: Array[BaseCharacter] = []
	
	for entry in target_distances:
		if entry.distance == min_distance:
			closest_targets.append(entry.target)
		else:
			break
	
	# Random selection from equidistant targets
	if closest_targets.size() > 1:
		print(character_type, " has ", closest_targets.size(), " equidistant targets, choosing randomly")
	
	return closest_targets[randi() % closest_targets.size()]

func _calculate_grid_distance(from: Vector2i, to: Vector2i) -> int:
	"""Calculate Manhattan distance between two grid positions"""
	return abs(from.x - to.x) + abs(from.y - to.y)

## Movement Logic

func _find_best_move_position() -> Vector2i:
	"""Find the best position to move towards the target"""
	if not current_target or current_movement_points <= 0:
		return Vector2i(-999, -999)  # Invalid position marker
	
	var target_pos = current_target.grid_position
	var current_pos = grid_position
	
	# Get all possible move positions within movement range
	var possible_moves = _get_valid_move_positions()
	
	if possible_moves.is_empty():
		return Vector2i(-999, -999)
	
	# Find the position that gets us closest to the target
	var best_position = Vector2i(-999, -999)
	var best_distance = 999999
	
	for move_pos in possible_moves:
		var distance = _calculate_grid_distance(move_pos, target_pos)
		
		# Prefer positions that are adjacent to target
		if _is_adjacent_to_target(move_pos, target_pos):
			print(character_type, " found adjacent position: ", move_pos)
			return move_pos
		
		# Otherwise, find closest position
		if distance < best_distance:
			best_distance = distance
			best_position = move_pos
	
	return best_position

func _get_valid_move_positions() -> Array[Vector2i]:
	"""Get all valid positions within movement range"""
	var valid_positions: Array[Vector2i] = []
	
	if not grid_manager:
		return valid_positions
	
	var current_pos = grid_position
	var move_range = current_movement_points
	
	# Check all positions within Manhattan distance of movement range
	for x in range(current_pos.x - move_range, current_pos.x + move_range + 1):
		for y in range(current_pos.y - move_range, current_pos.y + move_range + 1):
			var test_pos = Vector2i(x, y)
			
			# Skip current position
			if test_pos == current_pos:
				continue
			
			# Check if within movement range
			var distance = _calculate_grid_distance(current_pos, test_pos)
			if distance > move_range:
				continue
			
			# Check if position is valid and unoccupied
			if grid_manager.is_position_valid(test_pos) and not grid_manager.is_position_occupied_by_character(test_pos):
				valid_positions.append(test_pos)
	
	return valid_positions

func _is_adjacent_to_target(from_pos: Vector2i, target_pos: Vector2i) -> bool:
	"""Check if a position is adjacent to the target"""
	var distance = _calculate_grid_distance(from_pos, target_pos)
	return distance == 1

func _perform_movement(target_position: Vector2i) -> void:
	"""Execute movement to target position"""
	if current_movement_points <= 0:
		print("No movement points available for ", character_type)
		return
	
	if not grid_manager:
		print("ERROR: No grid manager for movement")
		return
	
	# Calculate movement cost
	var distance = _calculate_grid_distance(grid_position, target_position)
	if distance > current_movement_points:
		print("Movement distance ", distance, " exceeds available MP ", current_movement_points)
		return
	
	# Execute movement using existing BaseCharacter method
	var success = attempt_move_to(target_position)
	if success:
		print(character_type, " successfully moved to ", target_position)
		ai_action_performed.emit("movement")
		
		# Wait for movement animation to complete
		if is_moving:
			await movement_completed
	else:
		print(character_type, " failed to move to ", target_position)

## Combat Logic (Override in subclasses)

func _attempt_attack() -> void:
	"""Attempt to attack the current target - override in subclasses"""
	print("Base enemy attack - should be overridden in subclasses")
	# Subclasses should implement specific attack logic here

func _can_attack_target(target: BaseCharacter) -> bool:
	"""Check if we can attack the target - override in subclasses"""
	# Basic checks that apply to all enemies
	if not target or target.is_dead:
		return false
	
	if current_action_points < _get_attack_cost():
		return false
	
	# Check if target is in attack range
	return _is_target_in_attack_range(target)

func _get_attack_cost() -> int:
	"""Get the AP cost for attacking - override in subclasses"""
	return 3  # Default attack cost

func _get_attack_damage() -> int:
	"""Get the damage for attacking - override in subclasses"""
	return 10  # Default attack damage

func _is_target_in_attack_range(target: BaseCharacter) -> bool:
	"""Check if target is in attack range - override in subclasses"""
	# Default: melee range (adjacent)
	return _is_adjacent_to_target(grid_position, target.grid_position)

## Integration with Turn System

func is_ai_controlled() -> bool:
	"""Check if this character is AI controlled"""
	return true

func handle_turn_start() -> void:
	"""Handle when it's this enemy's turn"""
	print(character_type, " turn started - beginning AI logic")
	start_ai_turn()

## Death Handling Override

func _handle_death() -> void:
	"""Handle enemy death"""
	print(character_type, " enemy has been defeated!")
	is_dead = true
	_stop_ai_turn()
	_play_animation(GameConstants.DIE_ANIMATION_PREFIX)
	
	# TODO: Award experience to players
	# TODO: Drop loot
	# TODO: Remove from turn order 
