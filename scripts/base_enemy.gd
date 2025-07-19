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
	# Set character type if not already set by subclass
	if character_type == "Character":  # Default from BaseCharacter
		# Try to derive type from class name
		var script_name = get_script().resource_path.get_file().get_basename()
		if script_name.ends_with("_enemy"):
			character_type = script_name.replace("_enemy", "").capitalize()
		else:
			character_type = "Unknown Enemy"
	super()
	
	# Connect AI controller signals after it's ready
	call_deferred("_connect_ai_signals")
	
	# Connect resource depletion signal for death handling
	if resources:
		resources.resources_depleted.connect(_on_resources_depleted)

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

func _on_resources_depleted() -> void:
	"""Handle when resources are depleted (HP reaches 0)"""
	_handle_death()

## AI Turn Management

func start_ai_turn() -> void:
	"""Start the AI turn using AIController"""
	if ai_controller:
		ai_controller.start_ai_turn()
	else:
		# Fallback if no AI controller
		end_turn()


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
