class_name TurnManager
extends Node

## Turn management system for tactical combat
## Handles turn order, turn ending, and resource management

# Current turn state
var current_character: SwordsmanCharacter = null
var turn_number: int = 1
var is_turn_active: bool = false

# Character references
var characters: Array[SwordsmanCharacter] = []

# Signals
signal turn_started(character: SwordsmanCharacter)
signal turn_ended(character: SwordsmanCharacter)
signal combat_phase_changed(phase: String)

# References to UI elements
var end_turn_button: Button = null
var chat_panel: ChatPanel = null

func _ready() -> void:
	pass

func initialize(swordsman: SwordsmanCharacter, ui_button: Button, chat: ChatPanel) -> void:
	"""Initialize the turn manager with character and UI references"""
	current_character = swordsman
	characters = [swordsman]
	end_turn_button = ui_button
	chat_panel = chat
	
	# Connect signals
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	if current_character:
		current_character.turn_ended.connect(_on_character_turn_ended)
	
	# Start the first turn
	_start_turn()

func _start_turn() -> void:
	"""Start a new turn for the current character"""
	is_turn_active = true
	
	# Log turn start
	if chat_panel:
		chat_panel.add_combat_message("Turn %d - %s's turn begins" % [turn_number, "Swordsman"])
	
	print("=== Turn ", turn_number, " Started ===")
	print("Current character: Swordsman")
	print("Stats: ", current_character.get_stats_summary())
	
	turn_started.emit(current_character)
	combat_phase_changed.emit("player_turn")

func _on_end_turn_pressed() -> void:
	"""Handle end turn button press"""
	if not is_turn_active or not current_character:
		return
	
	end_current_turn()

func end_current_turn() -> void:
	"""End the current character's turn"""
	if not is_turn_active or not current_character:
		return
	
	is_turn_active = false
	
	# Log turn end
	if chat_panel:
		chat_panel.add_combat_message("Swordsman ends their turn - Resources refreshed!")
	
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

func _prepare_next_turn() -> void:
	"""Prepare for the next turn"""
	turn_number += 1
	
	# For now, we only have one character (swordsman), so just restart their turn
	# In the future, this would cycle through multiple characters
	
	# Small delay before starting next turn for better UX
	await get_tree().create_timer(0.5).timeout
	_start_turn()

func get_current_character() -> SwordsmanCharacter:
	"""Get the currently active character"""
	return current_character

func get_turn_number() -> int:
	"""Get the current turn number"""
	return turn_number

func is_character_turn_active() -> bool:
	"""Check if a character's turn is currently active"""
	return is_turn_active

func force_end_turn() -> void:
	"""Force end the current turn (for debug or special cases)"""
	if is_turn_active:
		if chat_panel:
			chat_panel.add_system_message("Turn forcibly ended")
		end_current_turn()

func add_character(character: SwordsmanCharacter) -> void:
	"""Add a character to the turn order (for future expansion)"""
	if character and character not in characters:
		characters.append(character)
		character.turn_ended.connect(_on_character_turn_ended)
		print("Added character to turn order: ", character.name)

func remove_character(character: SwordsmanCharacter) -> void:
	"""Remove a character from the turn order"""
	if character in characters:
		characters.erase(character)
		if character.turn_ended.is_connected(_on_character_turn_ended):
			character.turn_ended.disconnect(_on_character_turn_ended)
		print("Removed character from turn order: ", character.name)

func get_turn_summary() -> String:
	"""Get a summary of the current turn state"""
	if not current_character:
		return "No active character"
	
	return "Turn %d | %s | %s" % [
		turn_number,
		"Swordsman",
		current_character.get_stats_summary()
	]

func debug_print_turn_state() -> void:
	"""Debug function to print current turn state"""
	print("=== Turn Manager State ===")
	print("Turn number: ", turn_number)
	print("Active turn: ", is_turn_active)
	print("Current character: ", current_character.name if current_character else "None")
	print("Characters count: ", characters.size())
	if current_character:
		print("Character stats: ", current_character.get_stats_summary())
	print("==========================") 