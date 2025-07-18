class_name AIController
extends Node

## AI Controller component for intelligent ability-based enemy behavior
## Automatically discovers abilities and makes strategic decisions

# AI behavior constants
const AI_TURN_DELAY: float = 1.0

# Owner reference
var owner_character: BaseCharacter
var available_abilities: Array[AbilityComponent] = []
var current_target: BaseCharacter = null
var available_targets: Array[BaseCharacter] = []

# AI state
var is_ai_turn_active: bool = false

# Signals
signal ai_turn_started()
signal ai_turn_completed()
signal ai_action_performed(action_type: String)

func _ready() -> void:
	owner_character = get_parent() as BaseCharacter
	if not owner_character:
		push_error("AIController must be a child of a BaseCharacter")
		return
	
	# Discover abilities after the scene is fully loaded
	call_deferred("_discover_abilities")

func _exit_tree() -> void:
	_stop_ai_turn()

## Ability Discovery

func _discover_abilities() -> void:
	"""Find all AbilityComponent children of the owner"""
	available_abilities.clear()
	
	for child in owner_character.get_children():
		if child is AbilityComponent:
			available_abilities.append(child)
	
	print("AI discovered %d abilities for %s" % [available_abilities.size(), owner_character.character_type])

## AI Turn Management

func start_ai_turn() -> void:
	"""Start the AI turn with a visual delay"""
	if is_ai_turn_active:
		return
	
	is_ai_turn_active = true
	ai_turn_started.emit()
	
	# Refresh ability cooldowns
	for ability in available_abilities:
		ability.on_turn_start()
	
	# Add visual delay for better player experience
	await owner_character.get_tree().create_timer(AI_TURN_DELAY).timeout
	
	# Execute AI logic
	_execute_ai_logic()

func _execute_ai_logic() -> void:
	"""Main AI logic - find targets, evaluate abilities, move and attack"""
	if not is_ai_turn_active:
		return
	
	# Find available targets
	_update_available_targets()
	
	if available_targets.is_empty():
		_end_ai_turn()
		return
	
	# Select best target
	current_target = _select_best_target()
	if not current_target:
		_end_ai_turn()
		return
	
	# Execute AI actions
	await _execute_ai_actions()
	
	# End turn
	_end_ai_turn()

func _execute_ai_actions() -> void:
	"""Execute the best available action based on abilities"""
	# Get usable abilities (filtered by AP cost and cooldown)
	var usable_abilities = _get_usable_abilities()
	
	if usable_abilities.is_empty():
		# No abilities available, just move closer
		await _move_closer_to_target()
		return
	
	# Sort abilities by priority (highest cooldown first)
	usable_abilities.sort_custom(func(a, b): return a.cooldown > b.cooldown)
	
	# Try each ability in priority order
	for ability in usable_abilities:
		var best_action = _evaluate_ability_action(ability)
		if best_action.can_execute:
			await _execute_ability_action(ability, best_action)
			return
	
	# No abilities can be used effectively, move closer
	await _move_closer_to_target()

func _end_ai_turn() -> void:
	"""Complete the AI turn"""
	if not is_ai_turn_active:
		return
	
	is_ai_turn_active = false
	ai_turn_completed.emit()
	
	# End the character's turn
	if owner_character.has_method("end_turn"):
		owner_character.end_turn()

func _stop_ai_turn() -> void:
	"""Force stop AI turn (for cleanup)"""
	is_ai_turn_active = false

## Target Management

func _update_available_targets() -> void:
	"""Find all valid targets (player characters)"""
	available_targets.clear()
	
	if not owner_character.grid_manager:
		return
	
	# Get all characters from grid manager
	for character in owner_character.grid_manager.character_positions.keys():
		if character != owner_character and character is BaseCharacter and not character.is_dead:
			# Only target player characters (not other enemies)
			if not character is BaseEnemy:
				available_targets.append(character)

func _select_best_target() -> BaseCharacter:
	"""Select the best target using distance and RNG for ties"""
	if available_targets.is_empty():
		return null
	
	# Calculate distances to all targets
	var target_distances: Array[Dictionary] = []
	
	for target in available_targets:
		var distance = _calculate_grid_distance(owner_character.grid_position, target.grid_position)
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
	return closest_targets[randi() % closest_targets.size()]

## Ability Management

func _get_usable_abilities() -> Array[AbilityComponent]:
	"""Get abilities that can be used (have enough AP and are off cooldown)"""
	var usable: Array[AbilityComponent] = []
	
	for ability in available_abilities:
		if ability.current_cooldown <= 0 and owner_character.resources.get_ability_points() >= ability.ap_cost:
			usable.append(ability)
	
	return usable

func _evaluate_ability_action(ability: AbilityComponent) -> Dictionary:
	"""Evaluate if and how an ability can be used effectively"""
	var result = {
		"can_execute": false,
		"target_position": Vector2i.ZERO,
		"move_position": Vector2i.ZERO,
		"requires_movement": false
	}
	
	if not current_target:
		return result
	
	var target_pos = current_target.grid_position
	var current_pos = owner_character.grid_position
	var movement_range = owner_character.resources.get_movement_points()
	var ability_range = ability.range
	var total_range = movement_range + ability_range
	
	# Check if target is within total range (movement + ability)
	var distance_to_target = _calculate_grid_distance(current_pos, target_pos)
	if distance_to_target > total_range:
		return result
	
	# Check if we can use the ability from current position
	if ability.can_use_ability(target_pos):
		result.can_execute = true
		result.target_position = target_pos
		result.move_position = current_pos
		result.requires_movement = false
		return result
	
	# Try to find a position we can move to that puts target in range
	var best_move_pos = _find_move_position_for_ability(ability, target_pos)
	if best_move_pos != Vector2i(-999, -999):
		result.can_execute = true
		result.target_position = target_pos
		result.move_position = best_move_pos
		result.requires_movement = true
	
	return result

func _find_move_position_for_ability(ability: AbilityComponent, target_pos: Vector2i) -> Vector2i:
	"""Find the best position to move to for using an ability"""
	if not owner_character.grid_manager:
		return Vector2i(-999, -999)
	
	# Get all valid movement positions
	var valid_moves = owner_character.grid_manager.get_valid_movement_positions(
		owner_character.grid_position, 
		owner_character.resources.get_movement_points(), 
		owner_character
	)
	
	# Find positions where the ability can target the enemy
	for move_pos in valid_moves:
		var distance_to_target = _calculate_grid_distance(move_pos, target_pos)
		if distance_to_target <= ability.range:
			# This position would allow us to use the ability
			return move_pos
	
	return Vector2i(-999, -999)

## Action Execution

func _execute_ability_action(ability: AbilityComponent, action: Dictionary) -> void:
	"""Execute the planned ability action"""
	# Move if required
	if action.requires_movement:
		await _perform_movement(action.move_position)
	
	# Use the ability
	var success = await ability.use_ability(action.target_position)
	if success:
		ai_action_performed.emit("ability_" + ability.ability_name.to_lower())

func _move_closer_to_target() -> void:
	"""Move closer to target when no abilities can be used"""
	if not current_target:
		return
	
	var best_move_position = _find_closest_move_position()
	if best_move_position != Vector2i(-999, -999):
		await _perform_movement(best_move_position)

func _find_closest_move_position() -> Vector2i:
	"""Find the position that gets us closest to the target"""
	if not current_target or owner_character.resources.get_movement_points() <= 0:
		return Vector2i(-999, -999)
	
	if not owner_character.grid_manager:
		return Vector2i(-999, -999)
	
	var target_pos = current_target.grid_position
	var possible_moves = owner_character.grid_manager.get_valid_movement_positions(
		owner_character.grid_position,
		owner_character.resources.get_movement_points(),
		owner_character
	)
	
	if possible_moves.is_empty():
		return Vector2i(-999, -999)
	
	# Find the position that gets us closest to the target
	var best_position = Vector2i(-999, -999)
	var best_distance = 999999
	
	for move_pos in possible_moves:
		var distance = _calculate_grid_distance(move_pos, target_pos)
		if distance < best_distance:
			best_distance = distance
			best_position = move_pos
	
	return best_position

func _perform_movement(target_position: Vector2i) -> void:
	"""Execute movement to target position"""
	if owner_character.resources.get_movement_points() <= 0:
		return
	
	# Execute movement using existing BaseCharacter method
	var success = owner_character.attempt_move_to(target_position)
	if success:
		ai_action_performed.emit("movement")
		
		# Wait for movement animation to complete
		while owner_character.is_moving:
			await owner_character.get_tree().process_frame

## Utility Methods

func _calculate_grid_distance(from: Vector2i, to: Vector2i) -> int:
	"""Calculate Manhattan distance between two grid positions"""
	return abs(from.x - to.x) + abs(from.y - to.y)

## Integration Methods

func is_ai_controlled() -> bool:
	"""Check if this character is AI controlled"""
	return true
