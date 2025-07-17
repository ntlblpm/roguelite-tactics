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
	max_action_points = 6
	max_movement_points = 3
	base_initiative = 5  # Lower initiative than most players
	
	# Initialize current stats to max
	current_health_points = max_health_points
	current_action_points = max_action_points
	current_movement_points = max_movement_points
	current_initiative = base_initiative
	
	super()
	
	print("Skeleton created with stats: ", get_stats_summary())

## Combat Implementation

func _attempt_attack() -> void:
	"""Attempt to attack the current target using Attack1 animation"""
	if not current_target:
		print("Skeleton has no target to attack")
		return
	
	if not _can_attack_target(current_target):
		print("Skeleton cannot attack target: insufficient AP or out of range")
		return
	
	print("Skeleton attacking ", current_target.character_type, " for ", SKELETON_ATTACK_DAMAGE, " damage")
	
	# Play attack animation
	_play_attack_animation()
	
	# Wait for animation to complete before dealing damage
	await _wait_for_attack_animation()
	
	# Deal damage to target
	_deal_damage_to_target(current_target)
	
	# Consume action points
	current_action_points -= SKELETON_ATTACK_COST
	action_points_changed.emit(current_action_points, max_action_points)
	
	# Emit AI action signal
	ai_action_performed.emit("attack")

func _play_attack_animation() -> void:
	"""Play the attack animation facing the target"""
	if not current_target or not animated_sprite:
		return
	
	# Determine direction to face target
	var direction_to_target = GameConstants.determine_movement_direction(grid_position, current_target.grid_position)
	current_facing_direction = direction_to_target
	
	# Play Attack1 animation with direction
	var animation_name = "Attack1" + GameConstants.get_direction_suffix(direction_to_target)
	animated_sprite.play(animation_name)
	
	print("Skeleton playing attack animation: ", animation_name)

func _wait_for_attack_animation() -> void:
	"""Wait for the attack animation to finish"""
	if not animated_sprite:
		return
	
	# Wait for animation to complete
	if animated_sprite.is_playing():
		await animated_sprite.animation_finished

func _deal_damage_to_target(target: BaseCharacter) -> void:
	"""Deal damage to the target character"""
	if not target or target.is_dead:
		return
	
	print("Skeleton deals ", SKELETON_ATTACK_DAMAGE, " damage to ", target.character_type)
	target.take_damage(SKELETON_ATTACK_DAMAGE)
	
	# Check if target died
	if target.current_health_points <= 0:
		print("Skeleton has defeated ", target.character_type, "!")

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
	print("The skeleton crumbles to dust!")
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
