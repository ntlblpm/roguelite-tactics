class_name AbilityComponent
extends Node

## Composable ability component for characters
## Handles ability configuration, validation, and execution

# Area of effect patterns
enum AreaOfEffect {
	SINGLE_TARGET,
	ADJACENT_TILES,
	CROSS_PATTERN,
	DIAGONAL_PATTERN,
	ALL_ADJACENT
}

# Valid target types
enum TargetType {
	ENEMIES,
	ALLIES, 
	ALL
}

# Exported ability configuration
@export var ability_name: String = "Basic Attack"
@export var description: String = "A basic attack ability"
@export var damage: int = 10
@export var ap_cost: int = 3
@export var range: int = 1
@export var area_of_effect: AreaOfEffect = AreaOfEffect.SINGLE_TARGET
@export var valid_targets: TargetType = TargetType.ENEMIES
@export var take_damage_delay: float = 0.5
@export var animation: String = "Attack1"
@export var sound_effect: AudioStream
@export var cooldown: int = 0

# Internal state
var current_cooldown: int = 0
var owner_character: BaseCharacter

# Signals
signal ability_used(target_position: Vector2i, affected_targets: Array[BaseCharacter])
signal ability_animation_started()
signal ability_damage_dealt(targets: Array[BaseCharacter], damage_amount: int)

func _ready() -> void:
	owner_character = get_parent() as BaseCharacter
	if not owner_character:
		push_error("AbilityComponent must be a child of a BaseCharacter")

## Ability Validation

func can_use_ability(target_position: Vector2i) -> bool:
	"""Check if the ability can be used at the target position"""
	if not owner_character:
		return false
	
	# Check cooldown
	if current_cooldown > 0:
		return false
	
	# Check AP cost
	if owner_character.current_ability_points < ap_cost:
		return false
	
	# Check range
	if not _is_position_in_range(target_position):
		return false
	
	# Check if there are valid targets
	var targets = _get_affected_targets(target_position)
	return not targets.is_empty()

func _is_position_in_range(target_position: Vector2i) -> bool:
	"""Check if target position is within ability range"""
	var distance = abs(owner_character.grid_position.x - target_position.x) + abs(owner_character.grid_position.y - target_position.y)
	return distance <= range

## Target Selection

func _get_affected_targets(target_position: Vector2i) -> Array[BaseCharacter]:
	"""Get all characters affected by the ability at target position"""
	var affected_positions = _get_affected_positions(target_position)
	var targets: Array[BaseCharacter] = []
	
	if not owner_character.grid_manager:
		return targets
	
	for pos in affected_positions:
		var character = owner_character.grid_manager.get_character_at_position(pos)
		if character and _is_valid_target(character):
			targets.append(character)
	
	return targets

func _get_affected_positions(target_position: Vector2i) -> Array[Vector2i]:
	"""Get all grid positions affected by the ability"""
	var positions: Array[Vector2i] = []
	
	match area_of_effect:
		AreaOfEffect.SINGLE_TARGET:
			positions.append(target_position)
		
		AreaOfEffect.ADJACENT_TILES:
			positions.append(target_position)
			positions.append(target_position + Vector2i(1, 0))
			positions.append(target_position + Vector2i(-1, 0))
			positions.append(target_position + Vector2i(0, 1))
			positions.append(target_position + Vector2i(0, -1))
		
		AreaOfEffect.CROSS_PATTERN:
			positions.append(target_position)
			positions.append(target_position + Vector2i(1, 0))
			positions.append(target_position + Vector2i(-1, 0))
			positions.append(target_position + Vector2i(0, 1))
			positions.append(target_position + Vector2i(0, -1))
		
		AreaOfEffect.DIAGONAL_PATTERN:
			positions.append(target_position)
			positions.append(target_position + Vector2i(1, 1))
			positions.append(target_position + Vector2i(-1, -1))
			positions.append(target_position + Vector2i(1, -1))
			positions.append(target_position + Vector2i(-1, 1))
		
		AreaOfEffect.ALL_ADJACENT:
			for x in range(-1, 2):
				for y in range(-1, 2):
					positions.append(target_position + Vector2i(x, y))
	
	# Filter out invalid grid positions
	return positions.filter(func(pos): return owner_character.grid_manager.is_position_valid(pos))

func _is_valid_target(character: BaseCharacter) -> bool:
	"""Check if character is a valid target for this ability"""
	if character == owner_character:
		return false
	
	if character.is_dead:
		return false
	
	match valid_targets:
		TargetType.ENEMIES:
			# Target enemies (different type from owner)
			if owner_character is BaseEnemy:
				return not (character is BaseEnemy)
			else:
				return character is BaseEnemy
		
		TargetType.ALLIES:
			# Target allies (same type as owner)
			if owner_character is BaseEnemy:
				return character is BaseEnemy
			else:
				return not (character is BaseEnemy)
		
		TargetType.ALL:
			return true
	
	return false

## Ability Execution

func use_ability(target_position: Vector2i) -> bool:
	"""Execute the ability at the target position"""
	if not can_use_ability(target_position):
		return false
	
	var targets = _get_affected_targets(target_position)
	if targets.is_empty():
		return false
	
	# Consume AP
	owner_character.current_ability_points -= ap_cost
	if owner_character.has_method("_sync_ability_points"):
		owner_character._sync_ability_points.rpc(owner_character.current_ability_points)
	
	# Set cooldown
	current_cooldown = cooldown
	
	# Execute ability sequence
	await _execute_ability_sequence(target_position, targets)
	
	# Emit completion signal
	ability_used.emit(target_position, targets)
	
	return true

func _execute_ability_sequence(target_position: Vector2i, targets: Array[BaseCharacter]) -> void:
	"""Execute the full ability sequence: animation -> delay -> damage"""
	# Play animation
	await _play_ability_animation(target_position)
	
	# Wait for damage delay
	if take_damage_delay > 0:
		await owner_character.get_tree().create_timer(take_damage_delay).timeout
	
	# Deal damage
	_deal_damage_to_targets(targets)
	
	# Play sound effect
	_play_sound_effect()

func _play_ability_animation(target_position: Vector2i) -> void:
	"""Play the ability animation facing the target"""
	if not owner_character.animated_sprite or animation.is_empty():
		return
	
	ability_animation_started.emit()
	
	# Determine direction to face target
	var direction_to_target = GameConstants.determine_movement_direction(owner_character.grid_position, target_position)
	owner_character.current_facing_direction = direction_to_target
	
	# Play animation with direction
	if owner_character.has_method("_play_animation_synchronized"):
		owner_character._play_animation_synchronized.rpc(animation, direction_to_target)
	else:
		owner_character._play_animation(animation + GameConstants.get_direction_suffix(direction_to_target))
	
	# Wait for animation to complete
	await _wait_for_animation_completion()

func _wait_for_animation_completion() -> void:
	"""Wait for ability animation to finish with timeout"""
	if not owner_character.animated_sprite or not owner_character.animated_sprite.is_playing():
		return
	
	var timer = owner_character.get_tree().create_timer(2.0)
	var animation_finished: bool = false
	
	var animation_connection = func(): animation_finished = true
	owner_character.animated_sprite.animation_finished.connect(animation_connection, CONNECT_ONE_SHOT)
	
	while owner_character.animated_sprite.is_playing() and not timer.time_left <= 0:
		await owner_character.get_tree().process_frame
		if animation_finished:
			break
	
	if owner_character.animated_sprite.animation_finished.is_connected(animation_connection):
		owner_character.animated_sprite.animation_finished.disconnect(animation_connection)

func _deal_damage_to_targets(targets: Array[BaseCharacter]) -> void:
	"""Deal damage to all target characters"""
	for target in targets:
		if target and not target.is_dead:
			target.take_damage(damage)
	
	ability_damage_dealt.emit(targets, damage)

func _play_sound_effect() -> void:
	"""Play the ability sound effect"""
	if not sound_effect:
		return
	
	# Create temporary audio player if owner doesn't have one
	var audio_player = AudioStreamPlayer2D.new()
	owner_character.add_child(audio_player)
	audio_player.stream = sound_effect
	audio_player.play()
	
	# Clean up after sound finishes
	audio_player.finished.connect(func(): audio_player.queue_free())

## Turn Management

func on_turn_start() -> void:
	"""Called when owner's turn starts - reduce cooldown"""
	if current_cooldown > 0:
		current_cooldown -= 1

func reset_cooldown() -> void:
	"""Reset ability cooldown (for external cooldown management)"""
	current_cooldown = 0

## Utility Methods

func get_ability_info() -> Dictionary:
	"""Get ability information for UI display"""
	return {
		"name": ability_name,
		"description": description,
		"damage": damage,
		"ap_cost": ap_cost,
		"range": range,
		"cooldown": cooldown,
		"current_cooldown": current_cooldown,
		"can_use": can_use_ability(owner_character.grid_position) if owner_character else false
	}
