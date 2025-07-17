class_name SkeletonEnemy
extends BaseEnemy

## Skeleton enemy implementation
## A basic melee enemy that moves to the closest player and attacks with a sword
## Uses AIController and AbilityComponent for intelligent behavior

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
