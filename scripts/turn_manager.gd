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

# Death handling
var waiting_for_death_sequence: bool = false

func _ready() -> void:
	# Add to group for easy discovery by characters
	add_to_group("turn_manager")
	pass

func _exit_tree() -> void:
	"""Cleanup when the turn manager is being destroyed"""
	
	# Disconnect button signals
	if end_turn_button and end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.disconnect(_on_end_turn_pressed)
	
	# Disconnect character signals
	for character in characters:
		if character and is_instance_valid(character):
			if character.turn_ended.is_connected(_on_character_turn_ended):
				character.turn_ended.disconnect(_on_character_turn_ended)
			if character.has_signal("character_died") and character.character_died.is_connected(_on_character_died):
				character.character_died.disconnect(_on_character_died)
			if character.has_signal("death_sequence_completed") and character.death_sequence_completed.is_connected(_on_death_sequence_completed):
				character.death_sequence_completed.disconnect(_on_death_sequence_completed)
	
	# Clear references
	characters.clear()
	current_character = null
	end_turn_button = null
	chat_panel = null
	
	# Reset state
	current_character_index = 0
	turn_number = 1
	is_turn_active = false

func initialize_multiplayer(character_list: Array[BaseCharacter], ui_button: Button, chat: ChatPanel) -> void:
	"""Initialize the turn manager with multiple characters"""
	
	# Clean up any existing connections first
	_cleanup_existing_connections()
	
	characters = character_list.duplicate()
	end_turn_button = ui_button
	chat_panel = chat
	
	if characters.size() == 0:
		return
	
	# Sort characters by initiative (higher goes first), with tree order as tiebreaker
	characters.sort_custom(_compare_characters_by_initiative)
	
	current_character_index = 0
	current_character = characters[current_character_index]
	
	# Connect signals
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	# Connect all character signals
	for character in characters:
		if character and not character.turn_ended.is_connected(_on_character_turn_ended):
			character.turn_ended.connect(_on_character_turn_ended)
		if character and not character.character_died.is_connected(_on_character_died):
			character.character_died.connect(_on_character_died)
		if character and not character.death_sequence_completed.is_connected(_on_death_sequence_completed):
			character.death_sequence_completed.connect(_on_death_sequence_completed)
	
	# DON'T start the first turn immediately - let the game controller handle synchronization first

func _compare_characters_by_initiative(a: BaseCharacter, b: BaseCharacter) -> bool:
	"""Compare function for sorting characters by initiative (higher first), with tree order as tiebreaker"""
	# Compare by initiative first (higher initiative goes first)
	if a.current_initiative != b.current_initiative:
		return a.current_initiative > b.current_initiative
	
	# In case of tie, earlier entity in the tree wins (use get_index())
	return a.get_index() < b.get_index()

@rpc("any_peer", "call_local", "reliable")
func _start_turn() -> void:
	"""Start a new turn for the current character"""
	if characters.size() == 0:
		return
	
	# Only host should start turns to maintain synchronization
	if multiplayer.get_remote_sender_id() != 1 and not NetworkManager.is_host:
		return
	
	# Skip dead or invalid characters
	var attempts = 0
	while current_character_index < characters.size() and attempts < characters.size():
		var char = characters[current_character_index]
		if not is_instance_valid(char) or char.is_dead:
			current_character_index = (current_character_index + 1) % characters.size()
			attempts += 1
		else:
			break
	
	# Safety check: if all characters are dead or invalid, return
	if attempts >= characters.size() or _all_characters_dead():
		return
	
	is_turn_active = true
	current_character = characters[current_character_index]
	
	# Turn started
	
	turn_started.emit(current_character)
	combat_phase_changed.emit("player_turn")
	
	# Check if this is an AI-controlled enemy and start their AI logic
	if current_character.is_ai_controlled():
		combat_phase_changed.emit("enemy_turn")
		# Start AI logic on the next frame to ensure proper setup
		call_deferred("_start_enemy_ai_turn")
	
	# Sync turn state across all clients
	_broadcast_turn_update.rpc()

func _start_enemy_ai_turn() -> void:
	"""Start AI logic for the current enemy character"""
	if not current_character or not is_turn_active:
		return
	
	if not current_character.is_ai_controlled():
		return
	
	# Call the enemy's AI turn start method
	if current_character.has_method("start_ai_turn"):
		current_character.start_ai_turn()
	else:
		# Force end turn to prevent getting stuck
		_end_current_turn.rpc()

@rpc("any_peer", "call_local", "reliable")
func _broadcast_turn_update() -> void:
	"""Broadcast turn state update to all clients"""
	
	# Only host should broadcast turn updates
	if multiplayer.get_remote_sender_id() != 1 and not NetworkManager.is_host:
		return
	
	# The signal emission will trigger UI updates on all clients
	if current_character:
		turn_started.emit(current_character)

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

func _on_end_turn_pressed() -> void:
	"""Handle end turn button press"""
	if not is_turn_active or not current_character:
		return
	
	# Only allow the current player to end their own turn
	var local_authority = multiplayer.get_unique_id()
	if current_character.get_multiplayer_authority() != local_authority:
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

@rpc("any_peer", "call_local", "reliable") 
func _end_current_turn() -> void:
	"""End the current character's turn"""
	if not is_turn_active or not current_character:
		return
	
	# Only host should end turns to maintain synchronization
	if multiplayer.get_remote_sender_id() != 1 and not NetworkManager.is_host:
		return
	
	is_turn_active = false
	
	# Turn ending
	
	# End the character's turn (this will refresh their resources)
	current_character.end_turn()
	
	turn_ended.emit(current_character)
	
	# Prepare for next turn
	_prepare_next_turn()

func _on_character_turn_ended() -> void:
	"""Handle when a character signals their turn has ended"""
	# This is called after the character has refreshed their resources
	# For AI characters, we need to advance to next turn without calling end_turn() again
	if NetworkManager and NetworkManager.is_host:
		_advance_to_next_turn.rpc()

@rpc("any_peer", "call_local", "reliable")
func _advance_to_next_turn() -> void:
	"""Advance to next turn without calling end_turn() again (for signal-based turn ending)"""
	if not is_turn_active or not current_character:
		return
	
	# Only host should advance turns to maintain synchronization
	if multiplayer.get_remote_sender_id() != 1 and not NetworkManager.is_host:
		return
	
	is_turn_active = false
	
	# Turn ending (character already called end_turn() so resources are refreshed)
	
	# NOTE: Don't call current_character.end_turn() here - it was already called by the character
	# that emitted the signal, which is what triggered this method
	
	turn_ended.emit(current_character)
	
	# Prepare for next turn
	_prepare_next_turn()

@rpc("any_peer", "call_local", "reliable")
func _prepare_next_turn() -> void:
	"""Prepare for the next turn"""
	if characters.size() == 0:
		return
	
	# Only host should prepare next turn
	if multiplayer.get_remote_sender_id() != 1 and not NetworkManager.is_host:
		return
	
	# Move to next character, skipping dead or invalid ones
	var start_index = current_character_index
	current_character_index = (current_character_index + 1) % characters.size()
	
	# Skip dead or invalid characters
	var attempts = 0
	while attempts < characters.size():
		var char = characters[current_character_index]
		if not is_instance_valid(char) or char.is_dead:
			current_character_index = (current_character_index + 1) % characters.size()
			attempts += 1
		else:
			break
	
	# If we've checked all characters and they're all dead or invalid, stop
	if attempts >= characters.size() or _all_characters_dead():
		return
	
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
	
	# First check if this is an AI-controlled character (enemy)
	if current_character.is_ai_controlled():
		# AI characters are never controlled by local players, even if they have the same authority
		return false
	
	# Check if the current character belongs to the local player
	var local_authority = multiplayer.get_unique_id()
	return current_character.get_multiplayer_authority() == local_authority

func force_end_turn() -> void:
	"""Force end the current turn (for debug or special cases)"""
	if is_turn_active:
		if NetworkManager and NetworkManager.is_host:
			_end_current_turn.rpc()

func add_character(character: BaseCharacter) -> void:
	"""Add a character to the turn order"""
	if character and character not in characters:
		characters.append(character)
		character.turn_ended.connect(_on_character_turn_ended)

func remove_character(character: BaseCharacter) -> void:
	"""Remove a character from the turn order"""
	if character in characters:
		var character_index = characters.find(character)
		characters.erase(character)
		
		# Adjust current index if needed
		if character_index <= current_character_index:
			current_character_index = max(0, current_character_index - 1)
		
		# Disconnect signals
		if character.turn_ended.is_connected(_on_character_turn_ended):
			character.turn_ended.disconnect(_on_character_turn_ended)
		if character.character_died.is_connected(_on_character_died):
			character.character_died.disconnect(_on_character_died)
		if character.death_sequence_completed.is_connected(_on_death_sequence_completed):
			character.death_sequence_completed.disconnect(_on_death_sequence_completed)

func get_turn_order_display() -> String:
	"""Get a display string showing turn order and current player"""
	var display_parts: Array[String] = []
	
	for i in range(characters.size()):
		var character = characters[i]
		# Skip invalid or dead characters
		if not is_instance_valid(character) or character.is_dead:
			continue
		
		var player_name = _get_player_name_for_character(character)
		var hp_display = "%d/%d HP" % [character.resources.current_health_points, character.resources.max_health_points]
		
		var entry = "%s (%s) - %s" % [player_name, character.character_type, hp_display]
		
		# Mark current player
		if i == current_character_index and is_turn_active:
			entry = "► " + entry + " ◄"
		
		display_parts.append(entry)
	
	return "\n".join(display_parts)

func get_characters_in_turn_order() -> Array[BaseCharacter]:
	"""Get all characters in their current turn order"""
	return characters.duplicate()

func _on_character_died(character: BaseCharacter) -> void:
	"""Handle when a character dies"""
	if not character:
		return
	
	# Character defeated
	
	# If it's the current character's turn, wait for death sequence
	if character == current_character and is_turn_active:
		waiting_for_death_sequence = true
		# Disable end turn button during death sequence
		if end_turn_button:
			end_turn_button.disabled = true

func _on_death_sequence_completed() -> void:
	"""Handle when a character's death sequence is complete"""
	if waiting_for_death_sequence:
		waiting_for_death_sequence = false
		# Re-enable end turn button
		if end_turn_button:
			end_turn_button.disabled = false
		
		# End the current turn and move to next character
		if NetworkManager and NetworkManager.is_host:
			is_turn_active = false
			turn_ended.emit(current_character)
			_prepare_next_turn()

func _all_characters_dead() -> bool:
	"""Check if all characters are dead or invalid"""
	for character in characters:
		if is_instance_valid(character) and not character.is_dead:
			return false
	return true

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

func get_turn_state() -> Dictionary:
	"""Get current turn state for synchronization"""
	return {
		"turn_number": turn_number,
		"current_character_index": current_character_index,
		"is_turn_active": is_turn_active,
		"characters_count": characters.size()
	}

func sync_turn_state(turn_state: Dictionary) -> void:
	"""Synchronize turn state from host"""
	
	turn_number = turn_state.get("turn_number", 1)
	current_character_index = turn_state.get("current_character_index", 0)
	is_turn_active = turn_state.get("is_turn_active", false)
	
	# Update current character reference
	if current_character_index < characters.size():
		current_character = characters[current_character_index]
		
		# Emit turn_started signal to trigger UI updates on clients
		if is_turn_active and current_character:
			turn_started.emit(current_character)

func start_first_turn() -> void:
	"""Start the first turn after all systems are properly synchronized"""
	if characters.size() == 0:
		return
	
	# Only host should start the turn
	if NetworkManager and NetworkManager.is_host:
		_start_turn.rpc()

func _cleanup_existing_connections() -> void:
	"""Clean up any existing signal connections"""
	# Disconnect button signals
	if end_turn_button and end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.disconnect(_on_end_turn_pressed)
	
	# Disconnect character signals
	for character in characters:
		if character and is_instance_valid(character):
			if character.turn_ended.is_connected(_on_character_turn_ended):
				character.turn_ended.disconnect(_on_character_turn_ended)
			if character.has_signal("character_died") and character.character_died.is_connected(_on_character_died):
				character.character_died.disconnect(_on_character_died)
			if character.has_signal("death_sequence_completed") and character.death_sequence_completed.is_connected(_on_death_sequence_completed):
				character.death_sequence_completed.disconnect(_on_death_sequence_completed) 
