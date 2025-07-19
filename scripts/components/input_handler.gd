class_name InputHandler
extends Node

## Handles all player input for the combat system
## Manages keyboard shortcuts, tile clicks, and ability targeting

signal tile_clicked(grid_position: Vector2i)
signal ability_shortcut_pressed(ability_index: int)
signal escape_pressed()
signal debug_key_pressed(key: String)

var grid_manager: GridManager
var turn_manager: TurnManager
var ability_system: AbilitySystem
var ui_manager: UIManager

# Input state
var is_input_enabled: bool = true

func initialize(p_grid_manager: GridManager, p_turn_manager: TurnManager, p_ability_system: AbilitySystem, p_ui_manager: UIManager) -> void:
	"""Initialize the input handler with required systems"""
	grid_manager = p_grid_manager
	turn_manager = p_turn_manager
	ability_system = p_ability_system
	ui_manager = p_ui_manager
	
	# Connect to grid manager for tile clicks
	if grid_manager:
		grid_manager.tile_clicked.connect(_on_tile_clicked)

func _input(event: InputEvent) -> void:
	"""Handle keyboard shortcuts and other input"""
	if not event is InputEventKey or not event.pressed:
		return
	
	if not is_input_enabled:
		return
	
	var key_code = event.keycode
	
	# Handle ability shortcuts 1-6
	if _is_ability_shortcut(key_code):
		var ability_index = _get_ability_index(key_code)
		if ability_index >= 0:
			ability_shortcut_pressed.emit(ability_index)
			get_viewport().set_input_as_handled()
	
	# ESC to cancel
	elif key_code == KEY_ESCAPE:
		escape_pressed.emit()
		get_viewport().set_input_as_handled()
	
	# Debug keys
	elif key_code == KEY_F1:
		debug_key_pressed.emit("F1")
		get_viewport().set_input_as_handled()
	elif key_code == KEY_F2:
		debug_key_pressed.emit("F2")
		get_viewport().set_input_as_handled()
	elif key_code == KEY_F3:
		debug_key_pressed.emit("F3")
		get_viewport().set_input_as_handled()
	elif key_code == KEY_F4:
		debug_key_pressed.emit("F4")
		get_viewport().set_input_as_handled()
	elif key_code == KEY_G:
		debug_key_pressed.emit("G")
		get_viewport().set_input_as_handled()

func _is_ability_shortcut(key_code: int) -> bool:
	"""Check if the key is an ability shortcut"""
	return (key_code >= KEY_1 and key_code <= KEY_6) or (key_code >= KEY_KP_1 and key_code <= KEY_KP_6)

func _get_ability_index(key_code: int) -> int:
	"""Get the ability index from the key code"""
	if key_code >= KEY_1 and key_code <= KEY_6:
		return key_code - KEY_1
	elif key_code >= KEY_KP_1 and key_code <= KEY_KP_6:
		return key_code - KEY_KP_1
	return -1

func _on_tile_clicked(grid_position: Vector2i) -> void:
	"""Handle when a tile is clicked"""
	if not is_input_enabled:
		return
	
	# Only allow input if it's the local player's turn
	if not can_process_input():
		_handle_invalid_turn_input()
		return
	
	# Get the character whose turn it is
	var current_character = turn_manager.get_current_character()
	if not current_character:
		return
	
	# Block input if the current character is AI-controlled
	if current_character.is_ai_controlled():
		if ui_manager:
			ui_manager.add_system_message("Cannot control enemy characters - AI is taking its turn")
		return
	
	# Forward the tile click
	tile_clicked.emit(grid_position)

func can_process_input() -> bool:
	"""Check if input can be processed based on turn state"""
	if not turn_manager:
		return false
		
	return turn_manager.is_character_turn_active() and turn_manager.is_local_player_turn()

func _handle_invalid_turn_input() -> void:
	"""Handle input when it's not the player's turn"""
	if not turn_manager or not ui_manager:
		return
		
	if turn_manager.is_character_turn_active() and not turn_manager.is_local_player_turn():
		var current_character = turn_manager.get_current_character()
		if current_character:
			var player_name = _get_player_name_for_character(current_character)
			ui_manager.add_system_message("It's " + player_name + "'s turn, not yours!")

func _get_player_name_for_character(character: BaseCharacter) -> String:
	"""Get a display name for the character's player"""
	var authority = character.get_multiplayer_authority()
	
	# Check NetworkManager for player name
	if NetworkManager and NetworkManager.connected:
		var players = NetworkManager.get_players_list()
		for player_info in players:
			if player_info.peer_id == authority:
				return player_info.player_name
	
	# Fallback names
	if authority == 1:
		return "Host"
	else:
		return "Player " + str(authority)

func set_input_enabled(enabled: bool) -> void:
	"""Enable or disable input processing"""
	is_input_enabled = enabled

func cleanup() -> void:
	"""Clean up input handler connections"""
	if grid_manager and grid_manager.tile_clicked.is_connected(_on_tile_clicked):
		grid_manager.tile_clicked.disconnect(_on_tile_clicked)