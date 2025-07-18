class_name CombatantResourcesComponent
extends Node

## Component to manage combatant resources (HP, MP, AP)
## Handles stat changes, synchronization, and signal emission

# Combat stats - exported for editor configuration
@export var max_health_points: int = GameConstants.DEFAULT_HEALTH_POINTS
@export var max_movement_points: int = GameConstants.DEFAULT_MOVEMENT_POINTS
@export var max_ability_points: int = GameConstants.DEFAULT_ABILITY_POINTS

# Current values
var current_health_points: int = GameConstants.DEFAULT_HEALTH_POINTS
var current_movement_points: int = GameConstants.DEFAULT_MOVEMENT_POINTS
var current_ability_points: int = GameConstants.DEFAULT_ABILITY_POINTS

# Signals for UI updates
signal health_changed(current: int, maximum: int)
signal movement_points_changed(current: int, maximum: int)
signal ability_points_changed(current: int, maximum: int)
signal resources_depleted()

# Reference to parent character for multiplayer authority checks
var parent_character: BaseCharacter

func _ready() -> void:
	parent_character = get_parent() as BaseCharacter
	_initialize_stats()

func _initialize_stats() -> void:
	"""Initialize character stats to maximum values"""
	current_health_points = max_health_points
	current_movement_points = max_movement_points
	current_ability_points = max_ability_points
	
	# Emit initial stat updates
	_emit_stat_updates()

func _emit_stat_updates() -> void:
	"""Emit all stat update signals for UI"""
	health_changed.emit(current_health_points, max_health_points)
	movement_points_changed.emit(current_movement_points, max_movement_points)
	ability_points_changed.emit(current_ability_points, max_ability_points)

# Health Management
func take_damage(damage: int) -> void:
	"""Apply damage to the character"""
	current_health_points = max(0, current_health_points - damage)
	
	# Synchronize HP across all clients
	_sync_health_points.rpc(current_health_points)
	
	if current_health_points <= 0:
		resources_depleted.emit()

func heal(amount: int) -> void:
	"""Heal the character"""
	current_health_points = min(max_health_points, current_health_points + amount)
	
	# Synchronize HP across all clients
	_sync_health_points.rpc(current_health_points)

@rpc("any_peer", "call_local", "reliable")
func _sync_health_points(new_hp: int) -> void:
	"""Synchronize health points across all clients"""
	current_health_points = new_hp
	
	# Emit health changed signal for all clients to update UI
	health_changed.emit(current_health_points, max_health_points)

# Movement Points Management
func consume_movement_points(cost: int) -> bool:
	"""Consume movement points if available. Returns true if successful"""
	if cost > current_movement_points:
		return false
	
	current_movement_points -= cost
	
	# Synchronize MP across all clients
	_sync_movement_points.rpc(current_movement_points)
	
	return true

func get_movement_points() -> int:
	"""Get current movement points"""
	return current_movement_points

@rpc("any_peer", "call_local", "reliable")
func _sync_movement_points(new_mp: int) -> void:
	"""Synchronize movement points across all clients"""
	current_movement_points = new_mp
	
	# Emit movement points changed signal for all clients to update UI
	movement_points_changed.emit(current_movement_points, max_movement_points)

# Ability Points Management
func consume_ability_points(cost: int) -> bool:
	"""Consume ability points if available. Returns true if successful"""
	if cost > current_ability_points:
		return false
	
	current_ability_points -= cost
	
	# Synchronize AP across all clients
	_sync_ability_points.rpc(current_ability_points)
	
	return true

func get_ability_points() -> int:
	"""Get current ability points"""
	return current_ability_points

@rpc("any_peer", "call_local", "reliable")
func _sync_ability_points(new_ap: int) -> void:
	"""Synchronize ability points across all clients"""
	current_ability_points = new_ap
	
	# Emit ability points changed signal for all clients to update UI
	ability_points_changed.emit(current_ability_points, max_ability_points)

# Resource Refresh (for turn end)
func refresh_resources() -> void:
	"""Refresh MP and AP to maximum values"""
	current_movement_points = max_movement_points
	current_ability_points = max_ability_points
	
	# Synchronize resource refresh across all clients
	_sync_movement_points.rpc(current_movement_points)
	_sync_ability_points.rpc(current_ability_points)

# Stat Access
func get_health_stats() -> Dictionary:
	"""Get health stats as dictionary"""
	return {
		"current": current_health_points,
		"maximum": max_health_points
	}

func get_movement_stats() -> Dictionary:
	"""Get movement stats as dictionary"""
	return {
		"current": current_movement_points,
		"maximum": max_movement_points
	}

func get_ability_stats() -> Dictionary:
	"""Get ability stats as dictionary"""
	return {
		"current": current_ability_points,
		"maximum": max_ability_points
	}

func get_all_stats() -> Dictionary:
	"""Get all stats as dictionary"""
	return {
		"health": get_health_stats(),
		"movement": get_movement_stats(),
		"ability": get_ability_stats()
	}

func get_stats_summary() -> String:
	"""Get a formatted string of current character stats"""
	return "HP: %d/%d | MP: %d/%d | AP: %d/%d" % [
		current_health_points, max_health_points,
		current_movement_points, max_movement_points,
		current_ability_points, max_ability_points
	]

# State Management for Multiplayer Sync
func get_resource_state() -> Dictionary:
	"""Get current resource state for synchronization"""
	return {
		"current_health_points": current_health_points,
		"current_movement_points": current_movement_points,
		"current_ability_points": current_ability_points
	}

func set_resource_state(state: Dictionary) -> void:
	"""Set resource state from synchronization data"""
	current_health_points = state.get("current_health_points", max_health_points)
	current_movement_points = state.get("current_movement_points", max_movement_points)
	current_ability_points = state.get("current_ability_points", max_ability_points)
	
	# Emit stat updates for all clients to see the changes
	_emit_stat_updates()

@rpc("any_peer", "call_local", "reliable")
func _sync_resource_state(state: Dictionary) -> void:
	"""Synchronize complete resource state across all clients"""
	set_resource_state(state)