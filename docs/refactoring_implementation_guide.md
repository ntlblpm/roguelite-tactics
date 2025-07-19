# Refactoring Implementation Guide

This document provides detailed implementation strategies for transforming the Roguelite Tactics codebase into a maintainable, scalable architecture through component-based design, system decomposition, and dependency injection.

## Table of Contents

1. [Component-Based Architecture Implementation](#1-component-based-architecture-implementation)
2. [GameController Decomposition Strategy](#2-gamecontroller-decomposition-strategy)
3. [Dependency Injection System](#3-dependency-injection-system)
4. [Implementation Timeline](#4-implementation-timeline)

## 1. Component-Based Architecture Implementation

### Overview

Transform monolithic character classes into flexible, reusable components that follow the Single Responsibility Principle. This approach enables better testing, code reuse, and maintainability.

### Core Component Definitions

#### 1.1 Health Component

```gdscript
# components/health_component.gd
class_name HealthComponent
extends Node

## Manages character health, damage, and healing
## Emits signals for all health-related events

# Signals
signal health_changed(current: int, maximum: int)
signal damage_taken(amount: int, source: Node)
signal healed(amount: int, source: Node)
signal died()
signal revived()

# Configuration
@export var max_health: int = 100
@export var starting_health: int = -1  # -1 means use max_health
@export var allow_overheal: bool = false
@export var death_threshold: int = 0

# State
var current_health: int = 0
var is_alive: bool = true

# Statistics tracking
var total_damage_taken: int = 0
var total_healing_received: int = 0
var times_died: int = 0

func _ready() -> void:
	if starting_health == -1:
		current_health = max_health
	else:
		current_health = starting_health
	
	# Emit initial state
	health_changed.emit(current_health, max_health)

func take_damage(amount: int, source: Node = null) -> int:
	"""Apply damage and return actual damage dealt"""
	if not is_alive or amount <= 0:
		return 0
	
	var actual_damage = min(amount, current_health - death_threshold)
	current_health -= actual_damage
	total_damage_taken += actual_damage
	
	damage_taken.emit(actual_damage, source)
	health_changed.emit(current_health, max_health)
	
	if current_health <= death_threshold:
		_handle_death()
	
	return actual_damage

func heal(amount: int, source: Node = null) -> int:
	"""Apply healing and return actual healing done"""
	if not is_alive or amount <= 0:
		return 0
	
	var actual_healing: int
	if allow_overheal:
		actual_healing = amount
		current_health += amount
	else:
		actual_healing = min(amount, max_health - current_health)
		current_health = min(current_health + amount, max_health)
	
	total_healing_received += actual_healing
	
	healed.emit(actual_healing, source)
	health_changed.emit(current_health, max_health)
	
	return actual_healing

func set_health(value: int) -> void:
	"""Directly set health value (use sparingly)"""
	current_health = clamp(value, death_threshold, max_health if not allow_overheal else value)
	health_changed.emit(current_health, max_health)
	
	if current_health <= death_threshold and is_alive:
		_handle_death()
	elif current_health > death_threshold and not is_alive:
		_handle_revival()

func _handle_death() -> void:
	"""Process character death"""
	is_alive = false
	times_died += 1
	died.emit()

func _handle_revival() -> void:
	"""Process character revival"""
	is_alive = true
	revived.emit()

func get_health_percentage() -> float:
	"""Get health as percentage (0.0 to 1.0)"""
	return float(current_health) / float(max_health) if max_health > 0 else 0.0

func is_full_health() -> bool:
	"""Check if at maximum health"""
	return current_health >= max_health

func is_critical() -> bool:
	"""Check if health is below 25%"""
	return get_health_percentage() < 0.25

# Serialization support
func serialize() -> Dictionary:
	return {
		"current_health": current_health,
		"max_health": max_health,
		"is_alive": is_alive,
		"stats": {
			"total_damage_taken": total_damage_taken,
			"total_healing_received": total_healing_received,
			"times_died": times_died
		}
	}

func deserialize(data: Dictionary) -> void:
	current_health = data.get("current_health", max_health)
	max_health = data.get("max_health", max_health)
	is_alive = data.get("is_alive", true)
	
	var stats = data.get("stats", {})
	total_damage_taken = stats.get("total_damage_taken", 0)
	total_healing_received = stats.get("total_healing_received", 0)
	times_died = stats.get("times_died", 0)
	
	health_changed.emit(current_health, max_health)
```

#### 1.2 Movement Component

```gdscript
# components/movement_component.gd
class_name MovementComponent
extends Node

## Handles grid-based movement, pathfinding, and movement point management

# Signals
signal movement_requested(target: Vector2i, path: Array[Vector2i])
signal movement_started(from: Vector2i, to: Vector2i)
signal movement_completed(position: Vector2i)
signal movement_cancelled(reason: String)
signal movement_points_changed(current: int, maximum: int)
signal position_changed(old_pos: Vector2i, new_pos: Vector2i)

# Dependencies (injected)
var grid_manager: GridManager
var animation_component: AnimationComponent  # Optional

# Configuration
@export var base_movement_points: int = 3
@export var movement_speed: float = 300.0  # pixels per second
@export var allow_diagonal: bool = false
@export var animation_enabled: bool = true

# State
var current_position: Vector2i = Vector2i.ZERO
var movement_points: int = 0
var max_movement_points: int = 0
var is_moving: bool = false
var current_path: Array[Vector2i] = []

# Movement modifiers
var movement_point_modifiers: Dictionary = {}  # id -> modifier value

func _ready() -> void:
	max_movement_points = base_movement_points
	movement_points = max_movement_points
	movement_points_changed.emit(movement_points, max_movement_points)

func initialize(start_position: Vector2i, grid: GridManager) -> void:
	"""Initialize component with starting position and grid reference"""
	current_position = start_position
	grid_manager = grid
	position_changed.emit(Vector2i.ZERO, current_position)

func can_move_to(target: Vector2i) -> bool:
	"""Check if movement to target is valid"""
	if is_moving or movement_points <= 0:
		return false
	
	if not grid_manager:
		push_error("MovementComponent: No grid_manager set")
		return false
	
	var path = grid_manager.find_path(current_position, target, movement_points)
	return path.size() > 0

func request_movement(target: Vector2i) -> bool:
	"""Request movement to target position"""
	if not can_move_to(target):
		movement_cancelled.emit("Invalid movement target")
		return false
	
	var path = grid_manager.find_path(current_position, target, movement_points)
	if path.is_empty():
		movement_cancelled.emit("No valid path found")
		return false
	
	var cost = path.size() - 1  # Exclude starting position
	if cost > movement_points:
		movement_cancelled.emit("Insufficient movement points")
		return false
	
	current_path = path
	movement_requested.emit(target, path)
	
	# Execute movement
	_execute_movement(path, cost)
	return true

func _execute_movement(path: Array[Vector2i], cost: int) -> void:
	"""Execute the actual movement along path"""
	is_moving = true
	var old_position = current_position
	
	movement_started.emit(old_position, path[-1])
	
	# Update position immediately for game logic
	current_position = path[-1]
	position_changed.emit(old_position, current_position)
	
	# Consume movement points
	movement_points -= cost
	movement_points_changed.emit(movement_points, max_movement_points)
	
	# Animate if component available
	if animation_enabled and animation_component:
		await animation_component.animate_movement(path, movement_speed)
	
	is_moving = false
	current_path.clear()
	movement_completed.emit(current_position)

func teleport_to(position: Vector2i) -> void:
	"""Instantly move to position without consuming movement points"""
	var old_position = current_position
	current_position = position
	position_changed.emit(old_position, current_position)
	movement_completed.emit(current_position)

func refresh_movement_points() -> void:
	"""Restore movement points to maximum"""
	_recalculate_max_movement_points()
	movement_points = max_movement_points
	movement_points_changed.emit(movement_points, max_movement_points)

func add_movement_modifier(id: String, value: int) -> void:
	"""Add a modifier to movement points"""
	movement_point_modifiers[id] = value
	_recalculate_max_movement_points()

func remove_movement_modifier(id: String) -> void:
	"""Remove a movement point modifier"""
	movement_point_modifiers.erase(id)
	_recalculate_max_movement_points()

func _recalculate_max_movement_points() -> void:
	"""Recalculate maximum movement points with modifiers"""
	var total_modifier = 0
	for modifier in movement_point_modifiers.values():
		total_modifier += modifier
	
	max_movement_points = max(1, base_movement_points + total_modifier)
	movement_points = min(movement_points, max_movement_points)
	movement_points_changed.emit(movement_points, max_movement_points)

func get_valid_move_positions() -> Array[Vector2i]:
	"""Get all positions this unit can move to"""
	if not grid_manager:
		return []
	
	return grid_manager.get_positions_within_range(current_position, movement_points)

func cancel_movement() -> void:
	"""Cancel current movement if in progress"""
	if is_moving:
		is_moving = false
		current_path.clear()
		movement_cancelled.emit("Movement cancelled by user")

# Serialization
func serialize() -> Dictionary:
	return {
		"position": {"x": current_position.x, "y": current_position.y},
		"movement_points": movement_points,
		"max_movement_points": max_movement_points,
		"modifiers": movement_point_modifiers.duplicate()
	}

func deserialize(data: Dictionary) -> void:
	var pos_data = data.get("position", {})
	current_position = Vector2i(pos_data.get("x", 0), pos_data.get("y", 0))
	movement_points = data.get("movement_points", max_movement_points)
	max_movement_points = data.get("max_movement_points", base_movement_points)
	movement_point_modifiers = data.get("modifiers", {})
	
	position_changed.emit(Vector2i.ZERO, current_position)
	movement_points_changed.emit(movement_points, max_movement_points)
```

#### 1.3 Network Sync Component

```gdscript
# components/network_sync_component.gd
class_name NetworkSyncComponent
extends Node

## Handles network synchronization for any game object
## Provides automatic state synchronization and RPC management

# Signals
signal state_synchronized(data: Dictionary)
signal sync_error(error: String)
signal authority_changed(new_authority: int)

# Configuration
@export var sync_interval: float = 0.1  # Seconds between syncs
@export var sync_properties: Array[String] = []  # Properties to auto-sync
@export var reliable_sync: bool = true
@export var sync_to_all: bool = true  # false = sync only to authority

# State
var is_authority: bool = false
var last_sync_time: float = 0.0
var pending_state: Dictionary = {}
var sync_timer: Timer

# Components to sync
var tracked_components: Dictionary = {}  # component_name -> component

func _ready() -> void:
	# Set up sync timer
	sync_timer = Timer.new()
	sync_timer.wait_time = sync_interval
	sync_timer.timeout.connect(_on_sync_timer)
	add_child(sync_timer)
	
	# Check multiplayer authority
	_update_authority()
	
	if is_authority and sync_interval > 0:
		sync_timer.start()

func _update_authority() -> void:
	"""Update authority status based on multiplayer"""
	var parent = get_parent()
	if parent and parent.has_method("is_multiplayer_authority"):
		var was_authority = is_authority
		is_authority = parent.is_multiplayer_authority()
		
		if was_authority != is_authority:
			authority_changed.emit(parent.get_multiplayer_authority())
			
			if is_authority:
				sync_timer.start()
			else:
				sync_timer.stop()

func register_component(name: String, component: Node, properties: Array[String] = []) -> void:
	"""Register a component for automatic synchronization"""
	tracked_components[name] = {
		"component": component,
		"properties": properties if properties.size() > 0 else sync_properties
	}

func unregister_component(name: String) -> void:
	"""Remove a component from synchronization"""
	tracked_components.erase(name)

func sync_now() -> void:
	"""Force immediate synchronization"""
	if not is_authority:
		return
	
	var state = _collect_state()
	
	if sync_to_all:
		_sync_state.rpc(state)
	else:
		# Sync only to server/host
		_sync_state.rpc_id(1, state)
	
	last_sync_time = Time.get_ticks_msec() / 1000.0

func _on_sync_timer() -> void:
	"""Timer callback for periodic sync"""
	sync_now()

func _collect_state() -> Dictionary:
	"""Collect state from all tracked components"""
	var state = {}
	
	# Collect component states
	for comp_name in tracked_components:
		var comp_data = tracked_components[comp_name]
		var component = comp_data["component"]
		var properties = comp_data["properties"]
		
		if not is_instance_valid(component):
			continue
		
		var comp_state = {}
		
		# Use serialize method if available
		if component.has_method("serialize"):
			comp_state = component.serialize()
		else:
			# Manual property collection
			for prop in properties:
				if prop in component:
					comp_state[prop] = component.get(prop)
		
		state[comp_name] = comp_state
	
	# Add custom state
	state["timestamp"] = Time.get_ticks_msec()
	state["authority"] = get_parent().get_multiplayer_authority() if get_parent() else 0
	
	return state

@rpc("any_peer", "call_local", "reliable")
func _sync_state(state: Dictionary) -> void:
	"""Receive and apply synchronized state"""
	# Verify sender authority
	var sender_id = multiplayer.get_remote_sender_id()
	var expected_authority = state.get("authority", 0)
	
	if sender_id != expected_authority and sender_id != 1:  # Allow host override
		sync_error.emit("Unauthorized sync from peer %d" % sender_id)
		return
	
	# Apply component states
	for comp_name in state:
		if comp_name in ["timestamp", "authority"]:
			continue
		
		if comp_name in tracked_components:
			var comp_data = tracked_components[comp_name]
			var component = comp_data["component"]
			
			if not is_instance_valid(component):
				continue
			
			var comp_state = state[comp_name]
			
			# Use deserialize method if available
			if component.has_method("deserialize"):
				component.deserialize(comp_state)
			else:
				# Manual property application
				for prop in comp_state:
					if prop in component:
						component.set(prop, comp_state[prop])
	
	state_synchronized.emit(state)

# Manual RPC helpers for specific events
@rpc("any_peer", "call_local", "reliable")
func sync_event(event_name: String, data: Dictionary) -> void:
	"""Sync a specific event across network"""
	if not is_authority:
		return
	
	# Emit as signal if exists
	if has_signal(event_name):
		emit_signal(event_name, data)

func request_full_sync() -> void:
	"""Request complete state sync from authority"""
	if is_authority:
		sync_now()
	else:
		_request_sync.rpc_id(get_parent().get_multiplayer_authority())

@rpc("any_peer", "call_remote", "reliable")
func _request_sync() -> void:
	"""Handle sync request from client"""
	if is_authority:
		sync_now()
```

#### 1.4 Combat Stats Component

```gdscript
# components/combat_stats_component.gd
class_name CombatStatsComponent
extends Node

## Manages combat-related statistics and calculations

# Signals
signal stat_changed(stat_name: String, old_value: int, new_value: int)
signal initiative_rolled(value: int)

# Base stats
@export var base_attack: int = 10
@export var base_defense: int = 5
@export var base_initiative: int = 10
@export var base_accuracy: int = 85
@export var base_evasion: int = 10
@export var base_critical_chance: int = 5
@export var base_critical_multiplier: float = 1.5

# Current stats (with modifiers)
var attack: int = 0
var defense: int = 0
var initiative: int = 0
var accuracy: int = 0
var evasion: int = 0
var critical_chance: int = 0
var critical_multiplier: float = 0.0

# Stat modifiers
var stat_modifiers: Dictionary = {}  # "stat_name:modifier_id" -> value

func _ready() -> void:
	_recalculate_all_stats()

func add_modifier(stat: String, id: String, value: int) -> void:
	"""Add a stat modifier"""
	var key = "%s:%s" % [stat, id]
	stat_modifiers[key] = value
	_recalculate_stat(stat)

func remove_modifier(stat: String, id: String) -> void:
	"""Remove a stat modifier"""
	var key = "%s:%s" % [stat, id]
	stat_modifiers.erase(key)
	_recalculate_stat(stat)

func remove_all_modifiers_by_id(id: String) -> void:
	"""Remove all modifiers with given ID"""
	var keys_to_remove = []
	for key in stat_modifiers:
		if key.ends_with(":" + id):
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		stat_modifiers.erase(key)
	
	_recalculate_all_stats()

func roll_initiative() -> int:
	"""Roll for turn order initiative"""
	var roll = randi_range(1, 20) + initiative
	initiative_rolled.emit(roll)
	return roll

func calculate_damage(target_defense: int, is_critical: bool = false) -> int:
	"""Calculate damage against target defense"""
	var damage = max(1, attack - target_defense)
	
	if is_critical:
		damage = int(damage * critical_multiplier)
	
	return damage

func calculate_hit_chance(target_evasion: int) -> int:
	"""Calculate chance to hit target"""
	return clamp(accuracy - target_evasion, 5, 95)

func roll_critical() -> bool:
	"""Check if attack is critical"""
	return randi_range(1, 100) <= critical_chance

func _recalculate_stat(stat_name: String) -> void:
	"""Recalculate a specific stat with modifiers"""
	var old_value = get(stat_name)
	var base_value = get("base_" + stat_name)
	var total_modifier = 0
	
	# Sum all modifiers for this stat
	for key in stat_modifiers:
		if key.begins_with(stat_name + ":"):
			total_modifier += stat_modifiers[key]
	
	var new_value = base_value + total_modifier
	
	# Apply minimum values
	match stat_name:
		"attack", "defense", "accuracy":
			new_value = max(0, new_value)
		"initiative":
			new_value = max(1, new_value)
		"evasion", "critical_chance":
			new_value = clamp(new_value, 0, 100)
	
	set(stat_name, new_value)
	
	if old_value != new_value:
		stat_changed.emit(stat_name, old_value, new_value)

func _recalculate_all_stats() -> void:
	"""Recalculate all stats"""
	for stat in ["attack", "defense", "initiative", "accuracy", "evasion", "critical_chance"]:
		_recalculate_stat(stat)
	
	# Special handling for critical multiplier
	critical_multiplier = base_critical_multiplier
	for key in stat_modifiers:
		if key.begins_with("critical_multiplier:"):
			critical_multiplier += stat_modifiers[key]

func get_stats_summary() -> Dictionary:
	"""Get summary of all current stats"""
	return {
		"attack": attack,
		"defense": defense,
		"initiative": initiative,
		"accuracy": accuracy,
		"evasion": evasion,
		"critical_chance": critical_chance,
		"critical_multiplier": critical_multiplier
	}
```

### Character Assembly with Components

```gdscript
# entities/character.gd
class_name Character
extends CharacterBody2D

## Base character class using component architecture

# Component references
@onready var health_component: HealthComponent = $HealthComponent
@onready var movement_component: MovementComponent = $MovementComponent
@onready var combat_stats: CombatStatsComponent = $CombatStatsComponent
@onready var ability_points: AbilityPointsComponent = $AbilityPointsComponent
@onready var animation_component: AnimationComponent = $AnimationComponent
@onready var network_sync: NetworkSyncComponent = $NetworkSyncComponent

# Character configuration
@export var character_name: String = "Character"
@export var character_class: String = "Fighter"
@export var team: int = 0  # 0 = player team, 1+ = enemy teams

# Visual elements
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var selection_indicator: Node2D = $SelectionIndicator

# State
var is_selected: bool = false
var is_my_turn: bool = false

# Signals
signal character_ready()
signal selected()
signal deselected()

func _ready() -> void:
	# Set component dependencies
	movement_component.animation_component = animation_component
	
	# Connect component signals
	_connect_component_signals()
	
	# Register components for networking
	if network_sync:
		network_sync.register_component("health", health_component)
		network_sync.register_component("movement", movement_component)
		network_sync.register_component("combat_stats", combat_stats)
		network_sync.register_component("ability_points", ability_points)
	
	# Initialize animation
	if animation_component and sprite:
		animation_component.sprite = sprite
		animation_component.play_animation("idle")
	
	character_ready.emit()

func _connect_component_signals() -> void:
	"""Connect all component signals to character handlers"""
	# Health signals
	health_component.died.connect(_on_death)
	health_component.health_changed.connect(_on_health_changed)
	
	# Movement signals
	movement_component.movement_completed.connect(_on_movement_completed)
	movement_component.position_changed.connect(_on_position_changed)
	
	# Combat signals
	combat_stats.stat_changed.connect(_on_stat_changed)

func initialize_on_grid(grid_position: Vector2i, grid_manager: GridManager) -> void:
	"""Initialize character position on grid"""
	movement_component.initialize(grid_position, grid_manager)
	global_position = grid_manager.grid_to_world(grid_position)
	grid_manager.set_entity_at_position(grid_position, self)

func start_turn() -> void:
	"""Called when character's turn begins"""
	is_my_turn = true
	movement_component.refresh_movement_points()
	if ability_points:
		ability_points.refresh_ability_points()
	
	# Visual feedback
	if animation_component:
		animation_component.play_animation("ready")

func end_turn() -> void:
	"""Called when character's turn ends"""
	is_my_turn = false
	
	# Clear any temporary effects
	if is_selected:
		deselect()

func select() -> void:
	"""Select this character"""
	if is_selected:
		return
	
	is_selected = true
	if selection_indicator:
		selection_indicator.visible = true
	
	selected.emit()

func deselect() -> void:
	"""Deselect this character"""
	if not is_selected:
		return
	
	is_selected = false
	if selection_indicator:
		selection_indicator.visible = false
	
	deselected.emit()

# Component event handlers
func _on_death() -> void:
	"""Handle character death"""
	# Play death animation
	if animation_component:
		animation_component.play_animation("death")
		await animation_component.animation_finished
	
	# Remove from grid
	var grid_manager = movement_component.grid_manager
	if grid_manager:
		grid_manager.set_entity_at_position(movement_component.current_position, null)
	
	# Clean up
	queue_free()

func _on_health_changed(current: int, maximum: int) -> void:
	"""Handle health changes"""
	# Update health bar if exists
	if has_node("HealthBar"):
		$HealthBar.value = health_component.get_health_percentage()

func _on_movement_completed(position: Vector2i) -> void:
	"""Handle movement completion"""
	# Could trigger post-movement abilities or effects
	pass

func _on_position_changed(old_pos: Vector2i, new_pos: Vector2i) -> void:
	"""Handle position changes"""
	# Update world position
	if movement_component.grid_manager:
		global_position = movement_component.grid_manager.grid_to_world(new_pos)

func _on_stat_changed(stat_name: String, old_value: int, new_value: int) -> void:
	"""Handle stat changes"""
	# Could update UI or trigger effects
	pass

# Public interface
func can_act() -> bool:
	"""Check if character can perform actions"""
	return is_my_turn and health_component.is_alive and not movement_component.is_moving

func get_save_data() -> Dictionary:
	"""Get character data for saving"""
	var data = {
		"name": character_name,
		"class": character_class,
		"team": team,
		"components": {}
	}
	
	# Save component states
	for component in get_children():
		if component.has_method("serialize"):
			data.components[component.name] = component.serialize()
	
	return data

func load_save_data(data: Dictionary) -> void:
	"""Load character from save data"""
	character_name = data.get("name", character_name)
	character_class = data.get("class", character_class)
	team = data.get("team", team)
	
	# Load component states
	var components_data = data.get("components", {})
	for component_name in components_data:
		var component = get_node_or_null(component_name)
		if component and component.has_method("deserialize"):
			component.deserialize(components_data[component_name])
```

## 2. GameController Decomposition Strategy

### Overview

Breaking down the monolithic GameController into focused, single-responsibility systems that communicate through events rather than direct coupling.

### New System Architecture

```
CombatScene
├── Systems (Node)
│   ├── EventBus (Autoload)
│   ├── ServiceLocator (Autoload)
│   ├── GameStateManager
│   ├── SpawnManager
│   ├── CharacterRegistry
│   └── InputController
├── World (Node2D)
│   ├── GridManager
│   ├── TurnManager
│   └── Characters (Node2D)
└── UI (CanvasLayer)
    ├── CombatUIManager
    ├── TurnOrderPresenter
    ├── AbilityBarController
    └── ChatPresenter
```

### Detailed System Implementations

#### 2.1 Event Bus (Global Communication)

```gdscript
# autoload/event_bus.gd
extends Node

## Central event system for decoupled communication

# Character Events
signal character_spawned(character: Character, position: Vector2i, spawner_id: int)
signal character_died(character: Character)
signal character_selected(character: Character)
signal character_deselected(character: Character)
signal character_moved(character: Character, from: Vector2i, to: Vector2i)
signal character_action_completed(character: Character, action: String)

# Turn Events
signal turn_started(character: Character)
signal turn_ended(character: Character)
signal turn_order_changed(characters: Array[Character])
signal round_completed(round_number: int)

# Combat Events
signal damage_dealt(attacker: Character, target: Character, damage: int)
signal healing_done(healer: Character, target: Character, amount: int)
signal ability_used(character: Character, ability_name: String, targets: Array)
signal status_applied(character: Character, status: String, duration: int)

# Game State Events
signal game_started()
signal game_paused()
signal game_resumed()
signal victory_achieved(winning_team: int)
signal defeat_occurred()
signal game_state_changed(old_state: String, new_state: String)

# UI Request Events
signal ui_notification_requested(message: String, type: String, duration: float)
signal ui_update_requested(element: String, data: Dictionary)
signal camera_focus_requested(target: Node2D, smooth: bool)
signal screen_shake_requested(intensity: float, duration: float)

# System Events
signal save_requested(slot: int)
signal load_requested(slot: int)
signal settings_changed(setting: String, value: Variant)
signal scene_transition_requested(scene_path: String, transition_type: String)

# Networking Events
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal network_error(error: String)
signal sync_requested(data: Dictionary)

# Helper functions for common patterns
func emit_character_action(character: Character, action: String, data: Dictionary = {}) -> void:
	"""Emit a character action with optional data"""
	var full_data = data.duplicate()
	full_data["character"] = character
	full_data["action"] = action
	full_data["timestamp"] = Time.get_ticks_msec()
	
	emit_signal("character_action_completed", character, action)

func request_ui_update(element: String, data: Dictionary) -> void:
	"""Request UI update with validation"""
	if element.is_empty():
		push_error("EventBus: Empty UI element name")
		return
	
	ui_update_requested.emit(element, data)

func log_event(event_name: String, data: Dictionary = {}) -> void:
	"""Log an event for debugging/analytics"""
	if OS.is_debug_build():
		print("[Event] %s: %s" % [event_name, data])
```

#### 2.2 Spawn Manager

```gdscript
# systems/spawn_manager.gd
class_name SpawnManager
extends Node

## Manages all character spawning and despawning

# Character scene registry
@export var character_scenes: Dictionary = {
	"knight": preload("res://players/Knight/Knight.tscn"),
	"ranger": preload("res://players/Ranger/Ranger.tscn"),
	"pyromancer": preload("res://players/Pyromancer/Pyromancer.tscn"),
	"assassin": preload("res://players/Assassin/Assassin.tscn"),
	"skeleton": preload("res://enemies/Skeleton/Skeleton.tscn")
}

# Spawn configuration
@export var player_spawn_points: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(-2, 2),
	Vector2i(2, -2),
	Vector2i(0, 3)
]

@export var enemy_spawn_zones: Array[Rect2i] = [
	Rect2i(5, -2, 3, 3),  # Top right zone
	Rect2i(-5, -2, 3, 3)  # Top left zone
]

# Dependencies
var character_registry: CharacterRegistry
var grid_manager: GridManager
var character_container: Node2D

# State
var spawn_queue: Array[Dictionary] = []
var is_spawning: bool = false

func _ready() -> void:
	# Get dependencies from ServiceLocator
	character_registry = ServiceLocator.get_service("CharacterRegistry")
	grid_manager = ServiceLocator.get_service("GridManager")
	
	# Listen for network events
	EventBus.peer_connected.connect(_on_peer_connected)

func initialize(container: Node2D) -> void:
	"""Initialize with character container"""
	character_container = container

func spawn_player_character(class_name: String, peer_id: int, spawn_index: int = -1) -> Character:
	"""Spawn a player character"""
	if not class_name in character_scenes:
		push_error("SpawnManager: Unknown character class: " + class_name)
		return null
	
	# Determine spawn position
	var spawn_pos: Vector2i
	if spawn_index >= 0 and spawn_index < player_spawn_points.size():
		spawn_pos = player_spawn_points[spawn_index]
	else:
		spawn_pos = _find_available_spawn_point(player_spawn_points)
	
	if spawn_pos == Vector2i(-999, -999):  # Invalid position
		push_error("SpawnManager: No available spawn points")
		return null
	
	# Create character
	var character = _create_character(class_name, spawn_pos, peer_id)
	character.team = 0  # Player team
	
	# Register and announce
	character_registry.register_character(character, peer_id)
	EventBus.character_spawned.emit(character, spawn_pos, peer_id)
	
	# Sync to clients if host
	if NetworkManager.is_host:
		_sync_character_spawn.rpc(class_name, spawn_pos, peer_id)
	
	return character

func spawn_enemy_character(enemy_type: String, position: Vector2i = Vector2i(-999, -999)) -> Character:
	"""Spawn an enemy character"""
	if not enemy_type in character_scenes:
		push_error("SpawnManager: Unknown enemy type: " + enemy_type)
		return null
	
	# Determine spawn position
	var spawn_pos = position
	if spawn_pos == Vector2i(-999, -999):
		spawn_pos = _find_enemy_spawn_position()
	
	if spawn_pos == Vector2i(-999, -999):
		push_error("SpawnManager: No valid enemy spawn position")
		return null
	
	# Create enemy
	var enemy = _create_character(enemy_type, spawn_pos, 0)  # 0 = AI controlled
	enemy.team = 1  # Enemy team
	
	# Add AI component if not present
	if not enemy.has_node("AIComponent"):
		var ai = preload("res://components/ai_component.gd").new()
		ai.name = "AIComponent"
		enemy.add_child(ai)
	
	# Register and announce
	character_registry.register_character(enemy, 0)
	EventBus.character_spawned.emit(enemy, spawn_pos, 0)
	
	return enemy

func spawn_character_batch(spawn_data: Array[Dictionary]) -> void:
	"""Spawn multiple characters efficiently"""
	spawn_queue.append_array(spawn_data)
	
	if not is_spawning:
		_process_spawn_queue()

func despawn_character(character: Character) -> void:
	"""Properly remove a character"""
	if not character:
		return
	
	# Unregister
	character_registry.unregister_character(character)
	
	# Clear from grid
	if grid_manager and character.has_node("MovementComponent"):
		var movement = character.get_node("MovementComponent")
		grid_manager.set_entity_at_position(movement.current_position, null)
	
	# Cleanup
	character.queue_free()

func _create_character(type: String, position: Vector2i, authority: int) -> Character:
	"""Internal character creation"""
	var scene = character_scenes[type]
	var character = scene.instantiate()
	
	# Set multiplayer authority
	character.set_multiplayer_authority(authority)
	
	# Add to scene
	character_container.add_child(character)
	
	# Initialize on grid
	if character.has_method("initialize_on_grid"):
		character.initialize_on_grid(position, grid_manager)
	
	return character

func _find_available_spawn_point(points: Array[Vector2i]) -> Vector2i:
	"""Find an unoccupied spawn point"""
	for point in points:
		if grid_manager.is_position_empty(point):
			return point
	
	# Try nearby positions
	for point in points:
		var nearby = grid_manager.get_neighbors(point)
		for pos in nearby:
			if grid_manager.is_position_empty(pos):
				return pos
	
	return Vector2i(-999, -999)  # No valid position

func _find_enemy_spawn_position() -> Vector2i:
	"""Find random position in enemy spawn zones"""
	if enemy_spawn_zones.is_empty():
		return Vector2i(-999, -999)
	
	# Try random positions in zones
	for i in range(10):  # Max attempts
		var zone = enemy_spawn_zones[randi() % enemy_spawn_zones.size()]
		var x = zone.position.x + randi() % zone.size.x
		var y = zone.position.y + randi() % zone.size.y
		var pos = Vector2i(x, y)
		
		if grid_manager.is_position_empty(pos):
			return pos
	
	return Vector2i(-999, -999)

func _process_spawn_queue() -> void:
	"""Process queued spawns"""
	is_spawning = true
	
	while spawn_queue.size() > 0:
		var data = spawn_queue.pop_front()
		
		match data.get("type", ""):
			"player":
				spawn_player_character(
					data.get("class", "knight"),
					data.get("peer_id", 1),
					data.get("spawn_index", -1)
				)
			"enemy":
				spawn_enemy_character(
					data.get("enemy_type", "skeleton"),
					data.get("position", Vector2i(-999, -999))
				)
		
		# Small delay between spawns for visual effect
		await get_tree().create_timer(0.1).timeout
	
	is_spawning = false

# Networking
@rpc("authority", "call_local", "reliable")
func _sync_character_spawn(type: String, position: Vector2i, authority: int) -> void:
	"""Sync character spawn to clients"""
	if NetworkManager.is_host:
		return  # Host already spawned
	
	var character = _create_character(type, position, authority)
	character_registry.register_character(character, authority)
	EventBus.character_spawned.emit(character, position, authority)

func _on_peer_connected(peer_id: int) -> void:
	"""Handle new peer connection - sync existing characters"""
	if not NetworkManager.is_host:
		return
	
	# Send all existing characters to new peer
	for character in character_registry.get_all_characters():
		var movement = character.get_node_or_null("MovementComponent")
		if movement:
			var type = character.character_class.to_lower()
			var pos = movement.current_position
			var auth = character.get_multiplayer_authority()
			_sync_character_spawn.rpc_id(peer_id, type, pos, auth)
```

#### 2.3 Character Registry

```gdscript
# systems/character_registry.gd
class_name CharacterRegistry
extends Node

## Central registry for all active characters

# Character tracking
var all_characters: Array[Character] = []
var player_characters: Dictionary = {}  # peer_id -> Character
var enemy_characters: Array[Character] = []
var characters_by_team: Dictionary = {}  # team -> Array[Character]

# Signals
signal character_registered(character: Character)
signal character_unregistered(character: Character)
signal registry_updated()

func _ready() -> void:
	# Register self with ServiceLocator
	ServiceLocator.register("CharacterRegistry", self)
	
	# Listen for character death
	EventBus.character_died.connect(_on_character_died)

func register_character(character: Character, peer_id: int = 0) -> void:
	"""Register a new character"""
	if character in all_characters:
		push_warning("Character already registered")
		return
	
	# Add to main list
	all_characters.append(character)
	
	# Add to specific lists
	if peer_id > 0:
		player_characters[peer_id] = character
	else:
		enemy_characters.append(character)
	
	# Add to team list
	if not character.team in characters_by_team:
		characters_by_team[character.team] = []
	characters_by_team[character.team].append(character)
	
	character_registered.emit(character)
	registry_updated.emit()

func unregister_character(character: Character) -> void:
	"""Remove character from registry"""
	if not character in all_characters:
		return
	
	# Remove from all lists
	all_characters.erase(character)
	enemy_characters.erase(character)
	
	# Remove from player list
	for peer_id in player_characters:
		if player_characters[peer_id] == character:
			player_characters.erase(peer_id)
			break
	
	# Remove from team list
	if character.team in characters_by_team:
		characters_by_team[character.team].erase(character)
		if characters_by_team[character.team].is_empty():
			characters_by_team.erase(character.team)
	
	character_unregistered.emit(character)
	registry_updated.emit()

func get_character_by_peer_id(peer_id: int) -> Character:
	"""Get player character by peer ID"""
	return player_characters.get(peer_id, null)

func get_characters_by_team(team: int) -> Array[Character]:
	"""Get all characters on a team"""
	return characters_by_team.get(team, [])

func get_all_characters() -> Array[Character]:
	"""Get all registered characters"""
	return all_characters.duplicate()

func get_living_characters() -> Array[Character]:
	"""Get all living characters"""
	var living: Array[Character] = []
	for character in all_characters:
		if character.has_node("HealthComponent"):
			var health = character.get_node("HealthComponent")
			if health.is_alive:
				living.append(character)
	return living

func get_characters_in_range(position: Vector2i, range: int) -> Array[Character]:
	"""Get all characters within range of position"""
	var grid_manager = ServiceLocator.get_service("GridManager")
	if not grid_manager:
		return []
	
	var in_range: Array[Character] = []
	for character in all_characters:
		if character.has_node("MovementComponent"):
			var movement = character.get_node("MovementComponent")
			var distance = grid_manager.get_distance(position, movement.current_position)
			if distance <= range:
				in_range.append(character)
	
	return in_range

func get_closest_enemy(character: Character) -> Character:
	"""Find closest enemy to character"""
	var enemies = get_characters_by_team(1 - character.team)  # Simple team flip
	if enemies.is_empty():
		return null
	
	var grid_manager = ServiceLocator.get_service("GridManager")
	if not grid_manager or not character.has_node("MovementComponent"):
		return enemies[0]  # Fallback
	
	var char_movement = character.get_node("MovementComponent")
	var closest: Character = null
	var min_distance: int = 999999
	
	for enemy in enemies:
		if not enemy.has_node("MovementComponent"):
			continue
		
		var enemy_movement = enemy.get_node("MovementComponent")
		var distance = grid_manager.get_distance(
			char_movement.current_position,
			enemy_movement.current_position
		)
		
		if distance < min_distance:
			min_distance = distance
			closest = enemy
	
	return closest

func clear_registry() -> void:
	"""Clear all registrations"""
	all_characters.clear()
	player_characters.clear()
	enemy_characters.clear()
	characters_by_team.clear()
	registry_updated.emit()

func _on_character_died(character: Character) -> void:
	"""Auto-unregister dead characters after delay"""
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(character):
		unregister_character(character)

# Utility functions
func get_team_stats(team: int) -> Dictionary:
	"""Get statistics for a team"""
	var characters = get_characters_by_team(team)
	var stats = {
		"total": characters.size(),
		"alive": 0,
		"total_health": 0,
		"total_max_health": 0
	}
	
	for character in characters:
		if character.has_node("HealthComponent"):
			var health = character.get_node("HealthComponent")
			if health.is_alive:
				stats.alive += 1
				stats.total_health += health.current_health
				stats.total_max_health += health.max_health
	
	return stats

func debug_print_registry() -> void:
	"""Print registry state for debugging"""
	print("=== Character Registry ===")
	print("Total characters: ", all_characters.size())
	print("Player characters: ", player_characters.size())
	print("Enemy characters: ", enemy_characters.size())
	print("Teams: ", characters_by_team.keys())
	for team in characters_by_team:
		print("  Team %d: %d characters" % [team, characters_by_team[team].size()])
```

#### 2.4 Combat UI Manager

```gdscript
# ui/combat_ui_manager.gd
class_name CombatUIManager
extends Control

## Manages all combat UI elements and updates

# UI element references
@onready var stats_panel: Panel = $StatsPanel
@onready var hp_label: Label = $StatsPanel/VBox/HPLabel
@onready var mp_label: Label = $StatsPanel/VBox/MPLabel
@onready var ap_label: Label = $StatsPanel/VBox/APLabel

@onready var turn_indicator: Control = $TurnIndicator
@onready var current_turn_label: Label = $TurnIndicator/CurrentTurnLabel

@onready var ability_bar: HBoxContainer = $AbilityBar
@onready var end_turn_button: Button = $ControlButtons/EndTurnButton

# State
var selected_character: Character = null
var is_player_turn: bool = false

func _ready() -> void:
	# Register with ServiceLocator
	ServiceLocator.register("CombatUI", self)
	
	# Connect to events
	_connect_event_bus()
	
	# Connect UI signals
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	# Initial UI state
	_hide_all_panels()

func _connect_event_bus() -> void:
	"""Connect to all relevant events"""
	# Character events
	EventBus.character_selected.connect(_on_character_selected)
	EventBus.character_deselected.connect(_on_character_deselected)
	EventBus.character_spawned.connect(_on_character_spawned)
	
	# Turn events
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.turn_ended.connect(_on_turn_ended)
	
	# Combat events
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.healing_done.connect(_on_healing_done)
	
	# UI requests
	EventBus.ui_update_requested.connect(_on_ui_update_requested)
	EventBus.ui_notification_requested.connect(_on_notification_requested)

func _on_character_selected(character: Character) -> void:
	"""Handle character selection"""
	selected_character = character
	
	# Show stats panel
	stats_panel.visible = true
	_update_stats_display()
	
	# Connect to character's component signals
	if character.has_node("HealthComponent"):
		var health = character.get_node("HealthComponent")
		if not health.health_changed.is_connected(_on_selected_health_changed):
			health.health_changed.connect(_on_selected_health_changed)
	
	if character.has_node("MovementComponent"):
		var movement = character.get_node("MovementComponent")
		if not movement.movement_points_changed.is_connected(_on_selected_mp_changed):
			movement.movement_points_changed.connect(_on_selected_mp_changed)
	
	if character.has_node("AbilityPointsComponent"):
		var ap = character.get_node("AbilityPointsComponent")
		if not ap.ability_points_changed.is_connected(_on_selected_ap_changed):
			ap.ability_points_changed.connect(_on_selected_ap_changed)

func _on_character_deselected(character: Character) -> void:
	"""Handle character deselection"""
	if selected_character == character:
		selected_character = null
		stats_panel.visible = false
		
		# Disconnect signals
		if character.has_node("HealthComponent"):
			var health = character.get_node("HealthComponent")
			if health.health_changed.is_connected(_on_selected_health_changed):
				health.health_changed.disconnect(_on_selected_health_changed)

func _on_turn_started(character: Character) -> void:
	"""Handle turn start"""
	var is_local = character.get_multiplayer_authority() == multiplayer.get_unique_id()
	is_player_turn = is_local
	
	# Update turn indicator
	turn_indicator.visible = true
	current_turn_label.text = "%s's Turn" % character.character_name
	
	# Show/hide controls based on turn
	end_turn_button.visible = is_local
	end_turn_button.disabled = false
	
	# Update ability bar
	if is_local:
		_populate_ability_bar(character)

func _on_turn_ended(character: Character) -> void:
	"""Handle turn end"""
	is_player_turn = false
	end_turn_button.disabled = true
	_clear_ability_bar()

func _update_stats_display() -> void:
	"""Update displayed stats for selected character"""
	if not selected_character:
		return
	
	# Update HP
	if selected_character.has_node("HealthComponent"):
		var health = selected_character.get_node("HealthComponent")
		hp_label.text = "HP: %d/%d" % [health.current_health, health.max_health]
		hp_label.modulate = Color.WHITE
		if health.is_critical():
			hp_label.modulate = Color.RED
	
	# Update MP
	if selected_character.has_node("MovementComponent"):
		var movement = selected_character.get_node("MovementComponent")
		mp_label.text = "MP: %d/%d" % [movement.movement_points, movement.max_movement_points]
	
	# Update AP
	if selected_character.has_node("AbilityPointsComponent"):
		var ap = selected_character.get_node("AbilityPointsComponent")
		ap_label.text = "AP: %d/%d" % [ap.current_points, ap.max_points]

func _populate_ability_bar(character: Character) -> void:
	"""Populate ability bar for character"""
	_clear_ability_bar()
	
	# Get abilities from character
	var abilities = character.get_children().filter(func(n): return n is AbilityComponent)
	
	for i in range(abilities.size()):
		var ability = abilities[i]
		var button = _create_ability_button(ability, i)
		ability_bar.add_child(button)

func _create_ability_button(ability: AbilityComponent, index: int) -> Button:
	"""Create button for ability"""
	var button = Button.new()
	button.text = ability.ability_name
	button.tooltip_text = ability.description
	
	# Add hotkey display
	if index < 6:
		button.text += " (%d)" % (index + 1)
	
	# Connect signal
	button.pressed.connect(func(): _on_ability_button_pressed(ability))
	
	# Set enabled state
	button.disabled = not ability.can_use()
	
	return button

func _clear_ability_bar() -> void:
	"""Clear all ability buttons"""
	for child in ability_bar.get_children():
		child.queue_free()

func _on_ability_button_pressed(ability: AbilityComponent) -> void:
	"""Handle ability button press"""
	if not ability.can_use():
		return
	
	# Request ability usage through event
	EventBus.ability_used.emit(selected_character, ability.ability_name, [])

func _on_end_turn_pressed() -> void:
	"""Handle end turn button"""
	if is_player_turn:
		var turn_manager = ServiceLocator.get_service("TurnManager")
		if turn_manager:
			turn_manager.request_end_turn()

func _on_damage_dealt(attacker: Character, target: Character, damage: int) -> void:
	"""Show damage numbers"""
	var damage_text = preload("res://ui/DamageText.tscn").instantiate()
	damage_text.show_damage(damage, target.global_position)
	get_tree().current_scene.add_child(damage_text)

func _on_notification_requested(message: String, type: String, duration: float) -> void:
	"""Show notification"""
	# Implementation depends on notification system
	print("[%s] %s" % [type, message])

func _hide_all_panels() -> void:
	"""Hide all UI panels"""
	stats_panel.visible = false
	turn_indicator.visible = false

# Signal handlers for selected character
func _on_selected_health_changed(current: int, maximum: int) -> void:
	if selected_character:
		_update_stats_display()

func _on_selected_mp_changed(current: int, maximum: int) -> void:
	if selected_character:
		_update_stats_display()

func _on_selected_ap_changed(current: int, maximum: int) -> void:
	if selected_character:
		_update_stats_display()

func _on_ui_update_requested(element: String, data: Dictionary) -> void:
	"""Handle generic UI update requests"""
	match element:
		"stats":
			_update_stats_display()
		"abilities":
			if selected_character:
				_populate_ability_bar(selected_character)
		"turn_order":
			# Handled by TurnOrderPresenter
			pass
```

### System Integration Example

```gdscript
# scenes/combat_scene.gd
extends Node2D

## Main combat scene that integrates all systems

# System nodes
@onready var systems: Node = $Systems
@onready var world: Node2D = $World
@onready var ui: CanvasLayer = $UI

# Core systems
var game_state_manager: GameStateManager
var spawn_manager: SpawnManager
var character_registry: CharacterRegistry
var input_controller: InputController

# World systems
@onready var grid_manager: GridManager = $World/GridManager
@onready var turn_manager: TurnManager = $World/TurnManager
@onready var characters_container: Node2D = $World/Characters

# UI systems
@onready var combat_ui: CombatUIManager = $UI/CombatUIManager
@onready var turn_order_presenter: TurnOrderPresenter = $UI/TurnOrderPresenter

func _ready() -> void:
	# Initialize core systems
	_initialize_systems()
	
	# Register systems with ServiceLocator
	_register_services()
	
	# Connect systems
	_connect_systems()
	
	# Start game
	_start_combat()

func _initialize_systems() -> void:
	"""Initialize all systems"""
	# Create system instances
	game_state_manager = GameStateManager.new()
	spawn_manager = SpawnManager.new()
	character_registry = CharacterRegistry.new()
	input_controller = InputController.new()
	
	# Add to scene
	systems.add_child(game_state_manager)
	systems.add_child(spawn_manager)
	systems.add_child(character_registry)
	systems.add_child(input_controller)
	
	# Initialize with dependencies
	spawn_manager.initialize(characters_container)
	input_controller.initialize(grid_manager)

func _register_services() -> void:
	"""Register all services with ServiceLocator"""
	ServiceLocator.register("GameStateManager", game_state_manager)
	ServiceLocator.register("SpawnManager", spawn_manager)
	ServiceLocator.register("CharacterRegistry", character_registry)
	ServiceLocator.register("InputController", input_controller)
	ServiceLocator.register("GridManager", grid_manager)
	ServiceLocator.register("TurnManager", turn_manager)

func _connect_systems() -> void:
	"""Connect systems through events"""
	# Game state changes
	EventBus.game_state_changed.connect(_on_game_state_changed)
	
	# Victory/defeat conditions
	EventBus.victory_achieved.connect(_on_victory)
	EventBus.defeat_occurred.connect(_on_defeat)

func _start_combat() -> void:
	"""Initialize combat"""
	# Spawn player characters based on NetworkManager data
	for peer_id in NetworkManager.players:
		var player_data = NetworkManager.players[peer_id]
		spawn_manager.spawn_player_character(
			player_data.selected_class,
			peer_id,
			player_data.spawn_index
		)
	
	# Spawn enemies (host only)
	if NetworkManager.is_host:
		spawn_manager.spawn_enemy_character("skeleton", Vector2i(5, 0))
		spawn_manager.spawn_enemy_character("skeleton", Vector2i(4, 2))
	
	# Start turn system
	await get_tree().create_timer(0.5).timeout
	turn_manager.initialize_turn_order(character_registry.get_all_characters())
	
	# Emit game started
	EventBus.game_started.emit()

func _on_game_state_changed(old_state: String, new_state: String) -> void:
	"""Handle game state changes"""
	print("Game state changed: %s -> %s" % [old_state, new_state])

func _on_victory(winning_team: int) -> void:
	"""Handle victory"""
	# Show victory screen
	var victory_screen = preload("res://ui/VictoryScreen.tscn").instantiate()
	ui.add_child(victory_screen)

func _on_defeat() -> void:
	"""Handle defeat"""
	# Show defeat screen
	var defeat_screen = preload("res://ui/DefeatScreen.tscn").instantiate()
	ui.add_child(defeat_screen)
```

## 3. Dependency Injection System

### Overview

Implement a service locator pattern to manage dependencies and eliminate tight coupling between systems.

### Service Locator Implementation

```gdscript
# autoload/service_locator.gd
extends Node

## Global service locator for dependency injection
## Provides centralized access to game services

# Service registry
var _services: Dictionary = {}
var _service_interfaces: Dictionary = {}  # interface_name -> service_name
var _initialization_queue: Array = []

# Singleton instance
static var _instance: ServiceLocator

func _init() -> void:
	_instance = self

func _ready() -> void:
	# Process any queued services
	_process_initialization_queue()

# Static access
static func register(service_name: String, service: Object, interfaces: Array[String] = []) -> void:
	"""Register a service with optional interface names"""
	if _instance:
		_instance._register_service(service_name, service, interfaces)
	else:
		# Queue for later if ServiceLocator not ready
		_initialization_queue.append({
			"name": service_name,
			"service": service,
			"interfaces": interfaces
		})

static func get_service(service_name: String) -> Object:
	"""Get a service by name"""
	if _instance:
		return _instance._get_service(service_name)
	else:
		push_error("ServiceLocator not initialized")
		return null

static func get_interface(interface_name: String) -> Object:
	"""Get a service by interface name"""
	if _instance:
		return _instance._get_interface(interface_name)
	else:
		push_error("ServiceLocator not initialized")
		return null

static func has_service(service_name: String) -> bool:
	"""Check if a service is registered"""
	if _instance:
		return _instance._has_service(service_name)
	return false

static func unregister(service_name: String) -> void:
	"""Remove a service"""
	if _instance:
		_instance._unregister_service(service_name)

static func clear_all() -> void:
	"""Clear all services (useful for testing)"""
	if _instance:
		_instance._clear_all_services()

# Instance methods
func _register_service(service_name: String, service: Object, interfaces: Array[String]) -> void:
	"""Internal service registration"""
	if service_name in _services:
		push_warning("Service already registered: " + service_name)
		return
	
	_services[service_name] = service
	
	# Register interfaces
	for interface in interfaces:
		if interface in _service_interfaces:
			push_warning("Interface already registered: " + interface)
		else:
			_service_interfaces[interface] = service_name
	
	# Call initialization if service supports it
	if service.has_method("on_service_registered"):
		service.on_service_registered()
	
	print("Service registered: " + service_name)

func _get_service(service_name: String) -> Object:
	"""Internal service retrieval"""
	if not service_name in _services:
		push_error("Service not found: " + service_name)
		return null
	
	return _services[service_name]

func _get_interface(interface_name: String) -> Object:
	"""Internal interface retrieval"""
	if not interface_name in _service_interfaces:
		push_error("Interface not found: " + interface_name)
		return null
	
	var service_name = _service_interfaces[interface_name]
	return _get_service(service_name)

func _has_service(service_name: String) -> bool:
	"""Check if service exists"""
	return service_name in _services

func _unregister_service(service_name: String) -> void:
	"""Internal service removal"""
	if not service_name in _services:
		return
	
	var service = _services[service_name]
	
	# Call cleanup if service supports it
	if service.has_method("on_service_unregistered"):
		service.on_service_unregistered()
	
	# Remove from registry
	_services.erase(service_name)
	
	# Remove interface mappings
	var interfaces_to_remove = []
	for interface in _service_interfaces:
		if _service_interfaces[interface] == service_name:
			interfaces_to_remove.append(interface)
	
	for interface in interfaces_to_remove:
		_service_interfaces.erase(interface)
	
	print("Service unregistered: " + service_name)

func _clear_all_services() -> void:
	"""Clear all services"""
	# Call cleanup on all services
	for service_name in _services:
		var service = _services[service_name]
		if service.has_method("on_service_unregistered"):
			service.on_service_unregistered()
	
	_services.clear()
	_service_interfaces.clear()

func _process_initialization_queue() -> void:
	"""Process any services queued before ServiceLocator was ready"""
	for item in _initialization_queue:
		_register_service(item.name, item.service, item.interfaces)
	
	_initialization_queue.clear()

# Debug functions
func debug_print_services() -> void:
	"""Print all registered services"""
	print("=== Registered Services ===")
	for service_name in _services:
		print("  - " + service_name)
	
	print("=== Registered Interfaces ===")
	for interface in _service_interfaces:
		print("  - %s -> %s" % [interface, _service_interfaces[interface]])
```

### Dependency Injection Container

```gdscript
# systems/dependency_container.gd
class_name DependencyContainer
extends RefCounted

## Container for managing dependencies with scoping support

# Dependency scopes
enum Scope {
	SINGLETON,   # One instance for entire game
	TRANSIENT,   # New instance each time
	SCOPED       # One instance per scope (e.g., per scene)
}

# Registration data
class Registration:
	var factory: Callable
	var scope: Scope
	var instance: Object = null
	var interfaces: Array[String] = []
	
	func _init(p_factory: Callable, p_scope: Scope, p_interfaces: Array[String] = []):
		factory = p_factory
		scope = p_scope
		interfaces = p_interfaces

# Registrations
var _registrations: Dictionary = {}  # type_name -> Registration
var _interface_mappings: Dictionary = {}  # interface -> type_name

# Scoped instances
var _scoped_instances: Dictionary = {}  # scope_name -> {type_name -> instance}
var _current_scope: String = "default"

func register(type_name: String, factory: Callable, scope: Scope = Scope.TRANSIENT, interfaces: Array[String] = []) -> void:
	"""Register a type with factory function"""
	_registrations[type_name] = Registration.new(factory, scope, interfaces)
	
	# Map interfaces
	for interface in interfaces:
		_interface_mappings[interface] = type_name

func register_singleton(type_name: String, instance: Object, interfaces: Array[String] = []) -> void:
	"""Register an existing instance as singleton"""
	var registration = Registration.new(Callable(), Scope.SINGLETON, interfaces)
	registration.instance = instance
	_registrations[type_name] = registration
	
	# Map interfaces
	for interface in interfaces:
		_interface_mappings[interface] = type_name

func resolve(type_name: String) -> Object:
	"""Resolve a dependency by type name"""
	if not type_name in _registrations:
		# Try interface mapping
		if type_name in _interface_mappings:
			type_name = _interface_mappings[type_name]
		else:
			push_error("Type not registered: " + type_name)
			return null
	
	var registration = _registrations[type_name]
	
	match registration.scope:
		Scope.SINGLETON:
			return _get_or_create_singleton(type_name, registration)
		Scope.TRANSIENT:
			return _create_instance(registration)
		Scope.SCOPED:
			return _get_or_create_scoped(type_name, registration)
	
	return null

func _get_or_create_singleton(type_name: String, registration: Registration) -> Object:
	"""Get or create singleton instance"""
	if registration.instance == null:
		registration.instance = _create_instance(registration)
	return registration.instance

func _create_instance(registration: Registration) -> Object:
	"""Create new instance using factory"""
	if not registration.factory.is_valid():
		return null
	
	var instance = registration.factory.call()
	
	# Auto-inject dependencies if supported
	if instance.has_method("inject_dependencies"):
		instance.inject_dependencies(self)
	
	return instance

func _get_or_create_scoped(type_name: String, registration: Registration) -> Object:
	"""Get or create scoped instance"""
	if not _current_scope in _scoped_instances:
		_scoped_instances[_current_scope] = {}
	
	var scope_instances = _scoped_instances[_current_scope]
	
	if not type_name in scope_instances:
		scope_instances[type_name] = _create_instance(registration)
	
	return scope_instances[type_name]

func begin_scope(scope_name: String) -> void:
	"""Begin a new dependency scope"""
	_current_scope = scope_name
	if not scope_name in _scoped_instances:
		_scoped_instances[scope_name] = {}

func end_scope(scope_name: String) -> void:
	"""End a dependency scope and clean up"""
	if scope_name in _scoped_instances:
		# Clean up scoped instances
		for instance in _scoped_instances[scope_name].values():
			if instance.has_method("on_scope_ended"):
				instance.on_scope_ended()
		
		_scoped_instances.erase(scope_name)
	
	# Reset to default scope
	if _current_scope == scope_name:
		_current_scope = "default"

# Factory helper functions
static func create_factory(scene_path: String) -> Callable:
	"""Create a factory for a scene"""
	return func(): return load(scene_path).instantiate()

static func create_factory_with_params(callable: Callable, params: Array) -> Callable:
	"""Create a factory with bound parameters"""
	return func(): return callable.callv(params)
```

### Service Base Class

```gdscript
# systems/base_service.gd
class_name BaseService
extends Node

## Base class for all services

# Service metadata
var service_name: String = ""
var service_version: String = "1.0.0"
var dependencies: Array[String] = []

# Lifecycle state
var is_initialized: bool = false
var is_shutting_down: bool = false

# Dependency references
var _resolved_dependencies: Dictionary = {}

func _init(p_service_name: String = "") -> void:
	if p_service_name:
		service_name = p_service_name
	else:
		service_name = get_class()

func initialize() -> void:
	"""Initialize service after dependencies are resolved"""
	if is_initialized:
		return
	
	# Resolve dependencies
	_resolve_dependencies()
	
	# Custom initialization
	_on_initialize()
	
	is_initialized = true
	print("Service initialized: " + service_name)

func shutdown() -> void:
	"""Shutdown service and cleanup"""
	if is_shutting_down:
		return
	
	is_shutting_down = true
	
	# Custom cleanup
	_on_shutdown()
	
	# Clear dependencies
	_resolved_dependencies.clear()
	
	print("Service shutdown: " + service_name)

func _resolve_dependencies() -> void:
	"""Resolve all required dependencies"""
	for dep_name in dependencies:
		var service = ServiceLocator.get_service(dep_name)
		if service:
			_resolved_dependencies[dep_name] = service
		else:
			push_error("Failed to resolve dependency: " + dep_name)

func get_dependency(dep_name: String) -> Object:
	"""Get a resolved dependency"""
	return _resolved_dependencies.get(dep_name, null)

# Virtual methods for subclasses
func _on_initialize() -> void:
	"""Override for custom initialization"""
	pass

func _on_shutdown() -> void:
	"""Override for custom cleanup"""
	pass

func on_service_registered() -> void:
	"""Called when registered with ServiceLocator"""
	initialize()

func on_service_unregistered() -> void:
	"""Called when unregistered from ServiceLocator"""
	shutdown()

# Validation
func validate_dependencies() -> bool:
	"""Check if all dependencies are available"""
	for dep_name in dependencies:
		if not ServiceLocator.has_service(dep_name):
			return false
	return true

func get_service_info() -> Dictionary:
	"""Get service information"""
	return {
		"name": service_name,
		"version": service_version,
		"initialized": is_initialized,
		"dependencies": dependencies,
		"resolved_dependencies": _resolved_dependencies.keys()
	}
```

### Example Service Implementation

```gdscript
# services/combat_service.gd
class_name CombatService
extends BaseService

## Service for handling combat calculations and rules

func _init() -> void:
	super._init("CombatService")
	dependencies = ["CharacterRegistry", "GridManager"]

func calculate_damage(attacker: Character, target: Character, ability: AbilityComponent = null) -> int:
	"""Calculate damage with all modifiers"""
	var base_damage = 0
	
	# Get attacker stats
	if attacker.has_node("CombatStatsComponent"):
		var attacker_stats = attacker.get_node("CombatStatsComponent")
		base_damage = attacker_stats.attack
		
		# Add ability damage if provided
		if ability:
			base_damage += ability.base_damage
	
	# Get target defense
	var defense = 0
	if target.has_node("CombatStatsComponent"):
		var target_stats = target.get_node("CombatStatsComponent")
		defense = target_stats.defense
	
	# Calculate final damage
	var final_damage = max(1, base_damage - defense)
	
	# Apply modifiers
	final_damage = _apply_damage_modifiers(final_damage, attacker, target)
	
	return final_damage

func execute_attack(attacker: Character, target: Character, ability: AbilityComponent = null) -> void:
	"""Execute a complete attack"""
	# Check hit chance
	var hit_chance = calculate_hit_chance(attacker, target)
	if randf() * 100 > hit_chance:
		EventBus.ui_notification_requested.emit("Miss!", "combat", 1.0)
		return
	
	# Calculate damage
	var damage = calculate_damage(attacker, target, ability)
	
	# Check critical
	var is_critical = false
	if attacker.has_node("CombatStatsComponent"):
		var stats = attacker.get_node("CombatStatsComponent")
		is_critical = stats.roll_critical()
		if is_critical:
			damage = int(damage * stats.critical_multiplier)
	
	# Apply damage
	if target.has_node("HealthComponent"):
		var health = target.get_node("HealthComponent")
		health.take_damage(damage, attacker)
	
	# Emit event
	EventBus.damage_dealt.emit(attacker, target, damage)
	
	# Use ability points if ability was used
	if ability and attacker.has_node("AbilityPointsComponent"):
		var ap = attacker.get_node("AbilityPointsComponent")
		ap.consume_points(ability.ap_cost)

func calculate_hit_chance(attacker: Character, target: Character) -> float:
	"""Calculate chance to hit"""
	var base_chance = 85.0
	
	if attacker.has_node("CombatStatsComponent") and target.has_node("CombatStatsComponent"):
		var attacker_stats = attacker.get_node("CombatStatsComponent")
		var target_stats = target.get_node("CombatStatsComponent")
		base_chance = attacker_stats.calculate_hit_chance(target_stats.evasion)
	
	return clamp(base_chance, 5.0, 95.0)

func _apply_damage_modifiers(damage: int, attacker: Character, target: Character) -> int:
	"""Apply damage modifiers from buffs, terrain, etc."""
	var modified_damage = damage
	
	# Example: Check terrain bonus
	var grid_manager = get_dependency("GridManager")
	if grid_manager:
		# Add terrain-based modifiers
		pass
	
	return modified_damage

func get_targets_in_range(character: Character, range: int, include_allies: bool = false) -> Array[Character]:
	"""Get all valid targets within range"""
	var registry = get_dependency("CharacterRegistry")
	var grid_manager = get_dependency("GridManager")
	
	if not registry or not grid_manager:
		return []
	
	var char_pos = character.get_node("MovementComponent").current_position
	var all_targets = registry.get_characters_in_range(char_pos, range)
	
	# Filter by team
	var valid_targets: Array[Character] = []
	for target in all_targets:
		if target == character:
			continue
		
		if include_allies or target.team != character.team:
			valid_targets.append(target)
	
	return valid_targets
```

### Dependency Injection in Components

```gdscript
# Example of component using dependency injection
class_name EnhancedMovementComponent
extends MovementComponent

## Movement component with dependency injection support

var _grid_service: GridManager
var _combat_service: CombatService

func _ready() -> void:
	super._ready()
	_resolve_services()

func _resolve_services() -> void:
	"""Resolve required services"""
	_grid_service = ServiceLocator.get_service("GridManager")
	_combat_service = ServiceLocator.get_service("CombatService")
	
	if not _grid_service:
		push_error("MovementComponent: GridManager service not found")

func request_movement(target: Vector2i) -> bool:
	"""Enhanced movement with service usage"""
	if not _grid_service:
		return false
	
	# Use injected service instead of direct reference
	var path = _grid_service.find_path(current_position, target, movement_points)
	
	if path.is_empty():
		movement_cancelled.emit("No valid path found")
		return false
	
	# Check for opportunity attacks using combat service
	if _combat_service:
		var enemies = _combat_service.get_targets_in_range(get_parent(), 1)
		if enemies.size() > 0:
			EventBus.ui_notification_requested.emit(
				"Movement will provoke opportunity attacks!",
				"warning",
				2.0
			)
	
	# Continue with movement
	return super.request_movement(target)
```

### Testing with Dependency Injection

```gdscript
# tests/test_combat_service.gd
extends GutTest

var container: DependencyContainer
var combat_service: CombatService
var mock_registry: MockCharacterRegistry
var mock_grid: MockGridManager

func before_each():
	# Create dependency container
	container = DependencyContainer.new()
	
	# Register mocks
	mock_registry = MockCharacterRegistry.new()
	mock_grid = MockGridManager.new()
	
	container.register_singleton("CharacterRegistry", mock_registry)
	container.register_singleton("GridManager", mock_grid)
	
	# Create service with injected mocks
	combat_service = CombatService.new()
	combat_service._resolved_dependencies = {
		"CharacterRegistry": mock_registry,
		"GridManager": mock_grid
	}

func test_damage_calculation():
	# Create test characters
	var attacker = create_test_character({"attack": 20})
	var target = create_test_character({"defense": 10})
	
	# Test damage calculation
	var damage = combat_service.calculate_damage(attacker, target)
	
	assert_eq(damage, 10, "Damage should be attack - defense")

func test_service_dependency_resolution():
	# Register service with ServiceLocator
	ServiceLocator.register("CharacterRegistry", mock_registry)
	ServiceLocator.register("GridManager", mock_grid)
	ServiceLocator.register("CombatService", combat_service)
	
	# Test dependency resolution
	assert_true(combat_service.validate_dependencies())
	
	combat_service.initialize()
	assert_true(combat_service.is_initialized)
	
	# Test service retrieval
	var retrieved = ServiceLocator.get_service("CombatService")
	assert_eq(retrieved, combat_service)

func create_test_character(stats: Dictionary) -> Character:
	var character = Character.new()
	
	# Add mock components
	var stats_comp = MockCombatStatsComponent.new()
	stats_comp.attack = stats.get("attack", 10)
	stats_comp.defense = stats.get("defense", 5)
	character.add_child(stats_comp)
	
	return character
```

## 4. Implementation Timeline

### Phase 1: Foundation (Week 1-2)
- [ ] Create EventBus autoload
- [ ] Implement ServiceLocator
- [ ] Create base component classes (Health, Movement, CombatStats)
- [ ] Set up testing framework
- [ ] Convert one character to component architecture as proof of concept

### Phase 2: Core Systems (Week 3-4)
- [ ] Extract SpawnManager from GameController
- [ ] Create CharacterRegistry
- [ ] Implement InputController
- [ ] Create CombatUIManager
- [ ] Begin GameController decomposition

### Phase 3: Integration (Week 5-6)
- [ ] Complete UI separation
- [ ] Implement dependency injection throughout
- [ ] Convert all characters to components
- [ ] Update multiplayer synchronization
- [ ] Create GameStateManager

### Phase 4: Testing & Polish (Week 7-8)
- [ ] Write comprehensive tests
- [ ] Performance optimization
- [ ] Documentation
- [ ] Bug fixes and polish

This refactoring will transform the codebase into a maintainable, scalable architecture that supports future growth while maintaining all current functionality.