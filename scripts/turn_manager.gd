class_name TurnManager
extends Node

## Turn management system for multiplayer tactical combat
## Handles turn order, turn ending, and resource management for multiple players

# Current turn state
var current_character: BaseCharacter = null
var current_character_index: int = 0
var turn_number: int = 1
var is_turn_active: bool = false

# Character references
var characters: Array[BaseCharacter] = []

# Signals
signal turn_started(character: BaseCharacter)
signal turn_ended(character: BaseCharacter)
signal combat_phase_changed(phase: String)

# References to UI elements
var end_turn_button: Button = null
var chat_panel: ChatPanel = null

func _ready() -> void:
	pass

func initialize(swordsman: SwordsmanCharacter, ui_button: Button, chat: ChatPanel) -> void:
	"""Initialize the turn manager with single character (legacy support)"""
	var character_list: Array[BaseCharacter] = [swordsman as BaseCharacter]
	initialize_multiplayer(character_list, ui_button, chat)

func initialize_multiplayer(character_list: Array[BaseCharacter], ui_button: Button, chat: ChatPanel) -> void:
	"""Initialize the turn manager with multiple characters"""
	print("=== TURN MANAGER INITIALIZATION ===")
	print("Received character list size: ", character_list.size())
	for i in range(character_list.size()):
		var character = character_list[i]
		print("Character ", i, ": ", character.character_type, " (Authority: ", character.get_multiplayer_authority(), ") Init: ", character.current_initiative)
	
	characters = character_list.duplicate()
	end_turn_button = ui_button
	chat_panel = chat
	
	if characters.size() == 0:
		print("Error: No characters provided to TurnManager")
		return
	
	# Sort characters by initiative (higher goes first), with tree order as tiebreaker
	characters.sort_custom(_compare_characters_by_initiative)
	
	print("Characters after sorting by initiative:")
	for i in range(characters.size()):
		var character = characters[i]
		print("Position ", i, ": ", character.character_type, " (Authority: ", character.get_multiplayer_authority(), ") Init: ", character.current_initiative)
	
	current_character_index = 0
	current_character = characters[current_character_index]
	
	# Connect signals
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	# Connect all character signals
	for character in characters:
		if character and not character.turn_ended.is_connected(_on_character_turn_ended):
			character.turn_ended.connect(_on_character_turn_ended)
	
	print("TurnManager initialized with ", characters.size(), " characters")
	print("=== TURN MANAGER READY ===")
	
	# Start the first turn
	_start_turn()

func _compare_characters_by_initiative(a: BaseCharacter, b: BaseCharacter) -> bool:
	"""Compare function for sorting characters by initiative (higher first), with tree order as tiebreaker"""
	# Compare by initiative first (higher initiative goes first)
	if a.current_initiative != b.current_initiative:
		return a.current_initiative > b.current_initiative
	
	# In case of tie, earlier entity in the tree wins (use get_index())
	return a.get_index() < b.get_index()

@rpc("authority", "call_local", "reliable")
func _start_turn() -> void:
	"""Start a new turn for the current character"""
	if characters.size() == 0:
		return
	
	is_turn_active = true
	current_character = characters[current_character_index]
	
	# Log turn start
	if chat_panel:
		var player_name = _get_player_name_for_character(current_character)
		chat_panel.add_combat_message("Turn %d - %s (%s) begins their turn" % [turn_number, player_name, current_character.character_type])
	
	print("=== Turn ", turn_number, " Started ===")
	print("Current character: ", current_character.character_type, " (Authority: ", current_character.get_multiplayer_authority(), ")")
	print("Stats: ", current_character.get_stats_summary())
	
	turn_started.emit(current_character)
	combat_phase_changed.emit("player_turn")

func _get_player_name_for_character(character: BaseCharacter) -> String:
	"""Get a display name for the character's player"""
	var authority = character.get_multiplayer_authority()
	
	# Check NetworkManager for player name
	if NetworkManager and NetworkManager.is_connected:
		var players = NetworkManager.get_players_list()
		for player_info in players:
			if player_info.peer_id == authority:
				return player_info.player_name
	
	# Fallback names
	if authority == 1:
		return "Host"
	else:
		return "Player " + str(authority)

func _on_end_turn_pressed() -> void:
	"""Handle end turn button press"""
	if not is_turn_active or not current_character:
		return
	
	# Only allow the current player to end their own turn
	var local_authority = multiplayer.get_unique_id()
	if current_character.get_multiplayer_authority() != local_authority:
		if chat_panel:
			chat_panel.add_system_message("You can only end your own turn!")
		return
	
	# Send RPC to end turn
	if NetworkManager and NetworkManager.is_host:
		_end_current_turn.rpc()
	else:
		_request_end_turn.rpc_id(1)  # Send to host

@rpc("any_peer", "call_remote", "reliable")
func _request_end_turn() -> void:
	"""Request to end turn (client to host)"""
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Verify it's the current player's turn
	if current_character and current_character.get_multiplayer_authority() == sender_id:
		_end_current_turn.rpc()

@rpc("authority", "call_local", "reliable") 
func _end_current_turn() -> void:
	"""End the current character's turn"""
	if not is_turn_active or not current_character:
		return
	
	is_turn_active = false
	
	# Log turn end
	if chat_panel:
		var player_name = _get_player_name_for_character(current_character)
		chat_panel.add_combat_message("%s (%s) ends their turn - Resources refreshed!" % [player_name, current_character.character_type])
	
	print("=== Turn ", turn_number, " Ended ===")
	print("Final stats: ", current_character.get_stats_summary())
	
	# End the character's turn (this will refresh their resources)
	current_character.end_turn()
	
	turn_ended.emit(current_character)
	
	# Prepare for next turn
	_prepare_next_turn()

func _on_character_turn_ended() -> void:
	"""Handle when a character signals their turn has ended"""
	# This is called after the character has refreshed their resources
	print("Character turn ended signal received")

@rpc("authority", "call_local", "reliable")
func _prepare_next_turn() -> void:
	"""Prepare for the next turn"""
	if characters.size() == 0:
		return
	
	# Move to next character
	current_character_index = (current_character_index + 1) % characters.size()
	
	# If we've cycled through all characters, increment turn number
	if current_character_index == 0:
		turn_number += 1
	
	# Small delay before starting next turn for better UX
	await get_tree().create_timer(0.5).timeout
	_start_turn.rpc()

func get_current_character() -> BaseCharacter:
	"""Get the currently active character"""
	return current_character

func get_turn_number() -> int:
	"""Get the current turn number"""
	return turn_number

func is_character_turn_active() -> bool:
	"""Check if a character's turn is currently active"""
	return is_turn_active

func is_local_player_turn() -> bool:
	"""Check if it's the local player's turn"""
	if not current_character:
		return false
	
	# Check if the current character belongs to the local player
	var local_authority = multiplayer.get_unique_id()
	return current_character.get_multiplayer_authority() == local_authority

func force_end_turn() -> void:
	"""Force end the current turn (for debug or special cases)"""
	if is_turn_active:
		if chat_panel:
			chat_panel.add_system_message("Turn forcibly ended")
		if NetworkManager and NetworkManager.is_host:
			_end_current_turn.rpc()

func add_character(character: BaseCharacter) -> void:
	"""Add a character to the turn order"""
	if character and character not in characters:
		characters.append(character)
		character.turn_ended.connect(_on_character_turn_ended)
		print("Added character to turn order: ", character.name)

func remove_character(character: BaseCharacter) -> void:
	"""Remove a character from the turn order"""
	if character in characters:
		var character_index = characters.find(character)
		characters.erase(character)
		
		# Adjust current index if needed
		if character_index <= current_character_index:
			current_character_index = max(0, current_character_index - 1)
		
		if character.turn_ended.is_connected(_on_character_turn_ended):
			character.turn_ended.disconnect(_on_character_turn_ended)
		print("Removed character from turn order: ", character.name)

func get_turn_order_display() -> String:
	"""Get a display string showing turn order and current player"""
	var display_parts: Array[String] = []
	
	for i in range(characters.size()):
		var character = characters[i]
		var player_name = _get_player_name_for_character(character)
		var hp_display = "%d/%d HP" % [character.current_health_points, character.max_health_points]
		
		var entry = "%s (%s) - %s" % [player_name, character.character_type, hp_display]
		
		# Mark current player
		if i == current_character_index and is_turn_active:
			entry = "► " + entry + " ◄"
		
		display_parts.append(entry)
	
	return "\n".join(display_parts)

func get_characters_in_turn_order() -> Array[BaseCharacter]:
	"""Get all characters in their current turn order"""
	return characters.duplicate()

func get_turn_summary() -> String:
	"""Get a summary of the current turn state"""
	if not current_character:
		return "No active character"
	
	var player_name = _get_player_name_for_character(current_character)
	return "Turn %d | %s (%s) | %s" % [
		turn_number,
		player_name,
		current_character.character_type,
		current_character.get_stats_summary()
	]

func debug_print_turn_state() -> void:
	"""Debug function to print current turn state"""
	print("=== Turn Manager State ===")
	print("Turn number: ", turn_number)
	print("Active turn: ", is_turn_active)
	print("Current character index: ", current_character_index)
	print("Current character: ", current_character.name if current_character else "None")
	print("Characters count: ", characters.size())
	if current_character:
		print("Character authority: ", current_character.get_multiplayer_authority())
		print("Character stats: ", current_character.get_stats_summary())
	print("Is local player turn: ", is_local_player_turn())
	print("==========================") 