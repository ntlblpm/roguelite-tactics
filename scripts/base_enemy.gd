class_name BaseEnemy
extends BaseCharacter

## Base class for all enemy characters with AI behavior
## Uses AIController component for intelligent ability-based AI

# Reference to AI controller component
@onready var ai_controller: AIController = $AIController

# Signals for AI actions (forwarded from AIController)
signal ai_turn_started()
signal ai_turn_completed()
signal ai_action_performed(action_type: String)

func _ready() -> void:
	# Set character type for base enemy (override in subclasses)
	character_type = "Enemy"
	super()
	
	# Connect AI controller signals after it's ready
	call_deferred("_connect_ai_signals")

func _connect_ai_signals() -> void:
	"""Connect AIController signals to forward them"""
	if ai_controller:
		ai_controller.ai_turn_started.connect(_on_ai_turn_started)
		ai_controller.ai_turn_completed.connect(_on_ai_turn_completed)
		ai_controller.ai_action_performed.connect(_on_ai_action_performed)

func _on_ai_turn_started() -> void:
	"""Forward AI turn started signal"""
	ai_turn_started.emit()

func _on_ai_turn_completed() -> void:
	"""Forward AI turn completed signal"""
	ai_turn_completed.emit()

func _on_ai_action_performed(action_type: String) -> void:
	"""Forward AI action performed signal"""
	ai_action_performed.emit(action_type)

## AI Turn Management

func start_ai_turn() -> void:
	"""Start the AI turn using AIController"""
	if ai_controller:
		ai_controller.start_ai_turn()
	else:
		# Fallback if no AI controller
		end_turn()

## Legacy Methods (for backwards compatibility with existing enemy subclasses)

func _get_attack_cost() -> int:
	"""Get the AP cost for attacking - legacy method"""
	return 3

func _get_attack_damage() -> int:
	"""Get the damage for attacking - legacy method"""
	return 10

func _is_target_in_attack_range(target: BaseCharacter) -> bool:
	"""Check if target is in attack range - legacy method"""
	return false

## Integration with Turn System

func is_ai_controlled() -> bool:
	"""Check if this character is AI controlled"""
	return true

## Death Handling Override

func _handle_death() -> void:
	"""Handle enemy death"""
	is_dead = true
	if ai_controller:
		ai_controller._stop_ai_turn()
	_play_animation(GameConstants.DIE_ANIMATION_PREFIX)
	
	# TODO: Award experience to players
	# TODO: Drop loot
	# TODO: Remove from turn order 
