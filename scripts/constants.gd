class_name GameConstants
extends RefCounted

## Global constants and enums for the roguelite tactics game
## Contains shared enumerations and constant values used across multiple systems

# Character facing directions for isometric movement
enum Direction {
	BOTTOM_RIGHT,
	BOTTOM_LEFT, 
	TOP_LEFT,
	TOP_RIGHT
}

# Combat-related constants
const DEFAULT_HEALTH_POINTS: int = 100
const DEFAULT_MOVEMENT_POINTS: int = 3
const DEFAULT_ACTION_POINTS: int = 6
const DEFAULT_INITIATIVE: int = 10

# Grid and movement constants
const GRID_TILE_SIZE: int = 64
const MOVEMENT_ANIMATION_DURATION: float = 0.5

# Animation constants
const IDLE_ANIMATION_PREFIX: String = "Idle"
const RUN_ANIMATION_PREFIX: String = "Run"
const DIE_ANIMATION_PREFIX: String = "Die"
const TAKE_DAMAGE_ANIMATION_PREFIX: String = "TakeDamage"

# Direction suffix mapping
static func get_direction_suffix(direction: Direction) -> String:
	"""Get the animation suffix for a given direction"""
	match direction:
		Direction.BOTTOM_RIGHT:
			return "BottomRight"
		Direction.BOTTOM_LEFT:
			return "BottomLeft"
		Direction.TOP_LEFT:
			return "TopLeft"
		Direction.TOP_RIGHT:
			return "TopRight"
		_:
			return "BottomRight"

# Direction utilities
static func determine_movement_direction(from: Vector2i, to: Vector2i) -> Direction:
	"""Determine the movement direction based on grid positions"""
	var delta: Vector2i = to - from
	
	# Handle diagonal movements first (most common in isometric)
	if delta.x > 0 and delta.y > 0:
		return Direction.BOTTOM_RIGHT
	elif delta.x < 0 and delta.y > 0:
		return Direction.BOTTOM_LEFT
	elif delta.x < 0 and delta.y < 0:
		return Direction.TOP_LEFT
	elif delta.x > 0 and delta.y < 0:
		return Direction.TOP_RIGHT
	# Handle cardinal directions
	elif delta.x > 0:  # Moving right
		return Direction.BOTTOM_RIGHT
	elif delta.x < 0:  # Moving left
		return Direction.TOP_LEFT
	elif delta.y > 0:  # Moving down
		return Direction.BOTTOM_LEFT
	elif delta.y < 0:  # Moving up
		return Direction.TOP_RIGHT
	else:
		# No movement, return a default direction
		return Direction.BOTTOM_RIGHT 