class_name UIManager
extends Node

## Manages all UI elements and updates for the combat interface
## Handles stat displays, turn order, chat messages, and ability bar

signal give_up_requested()
signal end_turn_requested()

# UI references
var combat_ui: Control
var hp_text: Label
var hp_progress_bar: ProgressBar
var ap_text: Label
var mp_text: Label
var ap_display_panel: Panel
var mp_display_panel: Panel
var end_turn_button: Button
var give_up_button: Button
var chat_panel: ChatPanel

# Turn order UI elements
var turn_order_panel: VBoxContainer
var turn_order_displays: Array[TurnOrderSlot] = []
var turn_order_slot_scene: PackedScene
var current_entity_slot: TurnOrderSlot

# Confirmation modal for Give up
var give_up_confirmation_dialog: AcceptDialog

# Ability bar elements
var ability_buttons: Array[Button] = []

# Turn state
var is_player_turn: bool = false

func initialize(ui_root: Control) -> void:
	"""Initialize UI manager with combat UI root"""
	combat_ui = ui_root
	_setup_ui_references()

func _setup_ui_references() -> void:
	"""Setup references to UI elements"""
	if not combat_ui:
		return
	
	# Load the turn order slot scene
	turn_order_slot_scene = load("res://UIs/TurnOrderSlot.tscn")
	if not turn_order_slot_scene:
		push_error("UIManager: Failed to load TurnOrderSlot.tscn")
		
	# Get stat display elements
	hp_text = combat_ui.get_node("UILayer/MainUI/StatDisplay/VBoxContainer/HPDisplay/HPText")
	hp_progress_bar = combat_ui.get_node("UILayer/MainUI/StatDisplay/VBoxContainer/HPDisplay/HPProgressBar")
	ap_text = combat_ui.get_node("UILayer/MainUI/StatDisplay/VBoxContainer/HBoxContainer/APDisplay/APContainer/APText")
	mp_text = combat_ui.get_node("UILayer/MainUI/StatDisplay/VBoxContainer/HBoxContainer/MPDisplay/MPContainer/MPText")
	ap_display_panel = combat_ui.get_node("UILayer/MainUI/StatDisplay/VBoxContainer/HBoxContainer/APDisplay")
	mp_display_panel = combat_ui.get_node("UILayer/MainUI/StatDisplay/VBoxContainer/HBoxContainer/MPDisplay")
	
	# Get control elements
	end_turn_button = combat_ui.get_node("UILayer/MainUI/FightControls/ButtonContainer/EndTurnBtn")
	give_up_button = combat_ui.get_node("UILayer/MainUI/FightControls/ButtonContainer/GiveUpBtn")
	chat_panel = combat_ui.get_node("UILayer/MainUI/ChatPanel")
	
	# Get turn order UI elements
	turn_order_panel = combat_ui.get_node("UILayer/MainUI/TurnOrderPanel")
	
	# Get confirmation dialog
	give_up_confirmation_dialog = combat_ui.get_node("UILayer/MainUI/GiveUpConfirmationDialog")
	
	# Get ability buttons
	ability_buttons.clear()
	for i in range(1, 7):
		var button: Button = combat_ui.get_node("UILayer/MainUI/AbilityBar/AbilityContainer/AbilityGrid/Ability" + str(i))
		if button:
			ability_buttons.append(button)
	
	# Connect button signals
	if give_up_button:
		give_up_button.pressed.connect(_on_give_up_pressed)
	
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	if give_up_confirmation_dialog:
		give_up_confirmation_dialog.confirmed.connect(_on_give_up_confirmed)
		give_up_confirmation_dialog.canceled.connect(_on_give_up_canceled)

func update_stats(hp_current: int, hp_max: int, mp_current: int, mp_max: int, ap_current: int, ap_max: int) -> void:
	"""Update all stat displays"""
	if hp_text:
		hp_text.text = "HP:   %d/%d" % [hp_current, hp_max]
	if hp_progress_bar:
		hp_progress_bar.max_value = hp_max
		hp_progress_bar.value = hp_current
	if mp_text:
		mp_text.text = "MP:  %d/%d" % [mp_current, mp_max]
	if ap_text:
		ap_text.text = "AP:  %d/%d" % [ap_current, ap_max]
	
	# Update discrete bar displays
	if ap_display_panel and ap_display_panel.has_method("update_ap_display"):
		ap_display_panel.update_ap_display(ap_current, ap_max)
	if mp_display_panel and mp_display_panel.has_method("update_mp_display"):
		mp_display_panel.update_mp_display(mp_current, mp_max)

func update_hp_display(current: int, maximum: int) -> void:
	"""Update HP display"""
	if hp_text:
		hp_text.text = "HP:   %d/%d" % [current, maximum]
	if hp_progress_bar:
		hp_progress_bar.max_value = maximum
		hp_progress_bar.value = current

func update_mp_display(current: int, maximum: int) -> void:
	"""Update MP display"""
	if mp_text:
		mp_text.text = "MP:  %d/%d" % [current, maximum]
	if mp_display_panel and mp_display_panel.has_method("update_mp_display"):
		mp_display_panel.update_mp_display(current, maximum)

func update_ap_display(current: int, maximum: int) -> void:
	"""Update AP display"""
	if ap_text:
		ap_text.text = "AP:  %d/%d" % [current, maximum]
	if ap_display_panel and ap_display_panel.has_method("update_ap_display"):
		ap_display_panel.update_ap_display(current, maximum)

func add_system_message(message: String) -> void:
	"""Add a system message to the chat panel"""
	if chat_panel:
		chat_panel.add_system_message(message)

func add_combat_message(message: String) -> void:
	"""Add a combat message to the chat panel"""
	if chat_panel:
		chat_panel.add_combat_message(message)

func add_formatted_combat_message(formatted_message: String) -> void:
	"""Add a pre-formatted combat message to the chat panel"""
	if chat_panel:
		chat_panel.add_formatted_combat_message(formatted_message)

@rpc("any_peer", "call_local", "reliable")
func add_formatted_combat_message_multiplayer(formatted_message: String) -> void:
	"""Add a pre-formatted combat message across all peers"""
	add_formatted_combat_message(formatted_message)

func update_turn_order(characters_in_order: Array[BaseCharacter], current_character: BaseCharacter, current_index: int, turn_manager: TurnManager) -> void:
	"""Update the turn order UI to show all characters in initiative order"""
	if not turn_order_panel:
		return
	
	# Clear existing dynamic displays
	_clear_turn_order_displays()
	
	
	# Update the main current entity display
	if current_character and is_instance_valid(current_character):
		_update_current_entity_display(current_character, turn_manager)
	
	# Create a reordered list showing upcoming turns
	var upcoming_characters: Array[BaseCharacter] = []
	var total_chars = characters_in_order.size()
	
	# Add characters in the order they'll take their turns
	# Starting from the character after the current one
	for offset in range(1, total_chars):
		var index = (current_index + offset) % total_chars
		var character = characters_in_order[index]
		if character and is_instance_valid(character):
			upcoming_characters.append(character)
	
	# Create displays for upcoming characters
	for i in range(upcoming_characters.size()):
		var character = upcoming_characters[i]
		var original_index = characters_in_order.find(character)
		var character_display = _create_character_turn_display(character, i, -1)  # Pass -1 as we're showing upcoming order
		turn_order_panel.add_child(character_display)
		turn_order_displays.append(character_display)

func _update_current_entity_display(character: BaseCharacter, turn_manager: TurnManager) -> void:
	"""Update the main current entity display"""
	# Clear old current entity slot
	if current_entity_slot and is_instance_valid(current_entity_slot):
		current_entity_slot.cleanup()
		current_entity_slot.queue_free()
		current_entity_slot = null
	
	# Create new slot for current entity
	if turn_order_slot_scene and character:
		current_entity_slot = turn_order_slot_scene.instantiate() as TurnOrderSlot
		if current_entity_slot:
			# Insert at position 1 (after TurnOrderLabel)
			turn_order_panel.add_child(current_entity_slot)
			turn_order_panel.move_child(current_entity_slot, 1)
			current_entity_slot.setup(character)
			current_entity_slot.set_current_turn(true)

func _create_character_turn_display(character: BaseCharacter, turn_index: int, current_index: int) -> TurnOrderSlot:
	"""Create a UI display for a character in the turn order"""
	if not turn_order_slot_scene:
		return null
		
	var slot = turn_order_slot_scene.instantiate() as TurnOrderSlot
	if slot:
		slot.setup(character)
		# No color differentiation - all slots use the same appearance
	
	return slot


func _clear_turn_order_displays() -> void:
	"""Clear all dynamic turn order displays"""
	for slot in turn_order_displays:
		if slot and is_instance_valid(slot):
			slot.cleanup()
			slot.queue_free()
	turn_order_displays.clear()
	
	# Also clear current entity slot
	if current_entity_slot and is_instance_valid(current_entity_slot):
		current_entity_slot.cleanup()
		current_entity_slot.queue_free()
		current_entity_slot = null


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

func _on_give_up_pressed() -> void:
	"""Handle Give up button press - show confirmation dialog"""
	if give_up_confirmation_dialog:
		give_up_confirmation_dialog.popup_centered()

func _on_give_up_confirmed() -> void:
	"""Handle Give up confirmation"""
	give_up_requested.emit()

func _on_give_up_canceled() -> void:
	"""Handle Give up cancellation"""
	pass

func _on_end_turn_pressed() -> void:
	"""Handle end turn button press"""
	end_turn_requested.emit()

func get_ability_buttons() -> Array[Button]:
	"""Get all ability buttons"""
	return ability_buttons

func get_end_turn_button() -> Button:
	"""Get the end turn button"""
	return end_turn_button

func get_chat_panel() -> ChatPanel:
	"""Get the chat panel"""
	return chat_panel

func update_turn_state(is_local_player_turn: bool, current_character: BaseCharacter) -> void:
	"""Update UI based on whether it's the local player's turn"""
	is_player_turn = is_local_player_turn
	
	# Update button states
	_update_button_states(is_local_player_turn)

func _update_button_states(is_local_player_turn: bool) -> void:
	"""Enable/disable buttons based on turn state"""
	# End turn button
	if end_turn_button:
		end_turn_button.disabled = not is_local_player_turn
		if is_local_player_turn:
			end_turn_button.modulate = Color(1.2, 1.2, 1.2)  # Slightly brighter
		else:
			end_turn_button.modulate = Color(0.6, 0.6, 0.6)  # Dimmed
	
	# Store turn state for ability system coordination
	for button in ability_buttons:
		if button:
			button.set_meta("is_player_turn", is_local_player_turn)

func cleanup() -> void:
	"""Clean up UI resources"""
	_clear_turn_order_displays()
	
	# Disconnect button signals
	if give_up_button and give_up_button.pressed.is_connected(_on_give_up_pressed):
		give_up_button.pressed.disconnect(_on_give_up_pressed)
	
	if end_turn_button and end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.disconnect(_on_end_turn_pressed)
	
	if give_up_confirmation_dialog:
		if give_up_confirmation_dialog.confirmed.is_connected(_on_give_up_confirmed):
			give_up_confirmation_dialog.confirmed.disconnect(_on_give_up_confirmed)
		if give_up_confirmation_dialog.canceled.is_connected(_on_give_up_canceled):
			give_up_confirmation_dialog.canceled.disconnect(_on_give_up_canceled)
