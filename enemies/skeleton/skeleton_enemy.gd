class_name SkeletonEnemy
extends BaseEnemy

## Skeleton enemy implementation
## A basic melee enemy that moves to the closest player and attacks with a sword

# Skeleton-specific constants
const SKELETON_ATTACK_COST: int = 3
const SKELETON_ATTACK_DAMAGE: int = 10
const SKELETON_ATTACK_RANGE: int = 1  # Melee range

func _ready() -> void:
	# Override base stats for skeleton
	character_type = "Skeleton"
	
	# Skeleton stats: 50 HP, 6 AP, 3 MP
	max_health_points = 50
	max_ability_points = 6
	max_movement_points = 3
	base_initiative = 5  # Lower initiative than most players
	
	# Initialize current stats to max
	current_health_points = max_health_points
	current_ability_points = max_ability_points
	current_movement_points = max_movement_points
	current_initiative = base_initiative
	
	super()

## Combat Implementation

func _attempt_attack() -> void:
	"""Attempt to attack the current target using Attack1 animation"""
	if not current_target:
		return
	
	if not _can_attack_target(current_target):
		return
	
	# Play attack animation
	_play_attack_animation()
	
	# Wait for animation to complete before dealing damage
	await _wait_for_attack_animation()
	
	# Deal damage to target
	_deal_damage_to_target(current_target)
	
	# Consume ability points with network synchronization
	current_ability_points -= SKELETON_ATTACK_COST
	_sync_ability_points.rpc(current_ability_points)
	
	# Emit AI action signal
	ai_action_performed.emit("attack")

func _play_attack_animation() -> void:
	"""Play the attack animation facing the target"""
	if not current_target or not animated_sprite:
		return
	
	# Determine direction to face target
	var direction_to_target = GameConstants.determine_movement_direction(grid_position, current_target.grid_position)
	current_facing_direction = direction_to_target
	
	# Use the synchronized animation method to ensure all clients see the attack
	_play_animation_synchronized.rpc("Attack1", direction_to_target)

func _wait_for_attack_animation() -> void:
	"""Wait for the attack animation to finish with timeout to prevent hanging"""
	if not animated_sprite:
		return
	
	# Wait for animation to complete with timeout to prevent hanging
	if animated_sprite.is_playing():
		# Use a race condition approach with a timer
		var timer = get_tree().create_timer(2.0)  # 2-second timeout
		var animation_finished: bool = false
		
		# Connect to animation finished signal temporarily
		var animation_connection = func(): animation_finished = true
		animated_sprite.animation_finished.connect(animation_connection, CONNECT_ONE_SHOT)
		
		# Wait for either animation to finish or timeout
		while animated_sprite.is_playing() and not timer.time_left <= 0:
			await get_tree().process_frame
			if animation_finished:
				break
		
		# Clean up connection if it still exists
		if animated_sprite.animation_finished.is_connected(animation_connection):
			animated_sprite.animation_finished.disconnect(animation_connection)
		
		# If animation is still playing after timeout, force it to stop
		if animated_sprite.is_playing():
			print("Warning: Skeleton animation timed out, forcing completion")
			# Return to idle animation to ensure proper state
			_play_animation(GameConstants.IDLE_ANIMATION_PREFIX)

func _deal_damage_to_target(target: BaseCharacter) -> void:
	"""Deal damage to the target character"""
	if not target or target.is_dead:
		return
	
	target.take_damage(SKELETON_ATTACK_DAMAGE)

## Override Base Enemy Methods

func _get_attack_cost() -> int:
	"""Get the AP cost for skeleton attack"""
	return SKELETON_ATTACK_COST

func _get_attack_damage() -> int:
	"""Get the damage for skeleton attack"""
	return SKELETON_ATTACK_DAMAGE

func _is_target_in_attack_range(target: BaseCharacter) -> bool:
	"""Check if target is in melee range"""
	if not target:
		return false
	
	var distance = _calculate_grid_distance(grid_position, target.grid_position)
	return distance <= SKELETON_ATTACK_RANGE

## Death Handling

func _handle_death() -> void:
	"""Handle skeleton death with flavor text"""
	super()

## Animation Handling

func _on_animation_finished() -> void:
	"""Handle animation completion"""
	if not animated_sprite:
		return
	
	var finished_animation: String = animated_sprite.animation
	
	# Handle attack animation completion - return to idle
	if finished_animation.begins_with("Attack") and not is_dead:
		_play_animation(GameConstants.IDLE_ANIMATION_PREFIX)
	
	# Call parent implementation for other animations
	super() 
