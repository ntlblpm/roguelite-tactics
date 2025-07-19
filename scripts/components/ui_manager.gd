class_name UIManager
extends Node

## Manages all UI elements and updates for the combat interface
## Handles stat displays, turn order, chat messages, and ability bar

signal give_up_requested()
signal end_turn_requested()

# UI references
var combat_ui: Control
var hp_text: Label
var ap_text: Label
var mp_text: Label
var end_turn_button: Button
var give_up_button: Button
var chat_panel: ChatPanel

# Turn order UI elements
var current_entity_name: Label
var current_entity_hp: Label
var current_entity_status: Label
var turn_order_panel: VBoxContainer
var turn_order_displays: Array[Control] = []
var turn_order_hp_labels: Dictionary = {}  # Character -> HP Label mapping

# Confirmation modal for Give up
var give_up_confirmation_dialog: AcceptDialog

# Ability bar elements
var ability_buttons: Array[Button] = []

func initialize(ui_root: Control) -> void:
	"""Initialize UI manager with combat UI root"""
	combat_ui = ui_root
	_setup_ui_references()

func _setup_ui_references() -> void:
	"""Setup references to UI elements"""
	if not combat_ui:
		return
		
	# Get stat display elements
	hp_text = combat_ui.get_node("UILayer/MainUI/StatDisplay/VBoxContainer/HPDisplay/HPContainer/HPText")
	ap_text = combat_ui.get_node("UILayer/MainUI/StatDisplay/VBoxContainer/HBoxContainer/APDisplay/APContainer/APText")
	mp_text = combat_ui.get_node("UILayer/MainUI/StatDisplay/VBoxContainer/HBoxContainer/MPDisplay/MPContainer/MPText")
	
	# Get control elements
	end_turn_button = combat_ui.get_node("UILayer/MainUI/FightControls/ButtonContainer/EndTurnBtn")
	give_up_button = combat_ui.get_node("UILayer/MainUI/FightControls/ButtonContainer/GiveUpBtn")
	chat_panel = combat_ui.get_node("UILayer/MainUI/ChatPanel")
	
	# Get turn order UI elements
	turn_order_panel = combat_ui.get_node("UILayer/MainUI/TurnOrderPanel")
	current_entity_name = combat_ui.get_node("UILayer/MainUI/TurnOrderPanel/CurrentEntity/CurrentEntityContainer/CurrentEntityName")
	current_entity_hp = combat_ui.get_node("UILayer/MainUI/TurnOrderPanel/CurrentEntity/CurrentEntityContainer/CurrentEntityHP")
	current_entity_status = combat_ui.get_node("UILayer/MainUI/TurnOrderPanel/CurrentEntity/CurrentEntityContainer/CurrentEntityStatus")
	
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
		hp_text.text = "%d/%d" % [hp_current, hp_max]
	if mp_text:
		mp_text.text = "%d/%d" % [mp_current, mp_max]
	if ap_text:
		ap_text.text = "%d/%d" % [ap_current, ap_max]

func update_hp_display(current: int, maximum: int) -> void:
	"""Update HP display"""
	if hp_text:
		hp_text.text = "%d/%d" % [current, maximum]

func update_mp_display(current: int, maximum: int) -> void:
	"""Update MP display"""
	if mp_text:
		mp_text.text = "%d/%d" % [current, maximum]

func update_ap_display(current: int, maximum: int) -> void:
	"""Update AP display"""
	if ap_text:
		ap_text.text = "%d/%d" % [current, maximum]

func add_system_message(message: String) -> void:
	"""Add a system message to the chat panel"""
	if chat_panel:
		chat_panel.add_system_message(message)

func add_combat_message(message: String) -> void:
	"""Add a combat message to the chat panel"""
	if chat_panel:
		chat_panel.add_combat_message(message)

func update_turn_order(characters_in_order: Array[BaseCharacter], current_character: BaseCharacter, current_index: int, turn_manager: TurnManager) -> void:
	"""Update the turn order UI to show all characters in initiative order"""
	if not turn_order_panel:
		return
	
	# Clear existing dynamic displays
	_clear_turn_order_displays()
	
	# Hide the static NextEntity panels since we're creating dynamic ones
	_hide_static_next_entity_panels()
	
	# Update the main current entity display
	if current_character and is_instance_valid(current_character):
		_update_current_entity_display(current_character, turn_manager)
	
	# Create displays for all characters in turn order
	for i in range(characters_in_order.size()):
		var character = characters_in_order[i]
		if not character or not is_instance_valid(character):
			continue
			
		var is_current = (i == current_index and turn_manager.is_turn_active)
		
		# Skip the current character as it's already shown in the CurrentEntity panel
		if is_current:
			continue
			
		var character_display = _create_character_turn_display(character, i, current_index)
		turn_order_panel.add_child(character_display)
		turn_order_displays.append(character_display)

func _update_current_entity_display(character: BaseCharacter, turn_manager: TurnManager) -> void:
	"""Update the main current entity display"""
	if current_entity_name:
		var player_name = _get_player_name_for_character(character)
		current_entity_name.text = player_name + " (" + character.character_type + ")"
	
	if current_entity_hp:
		current_entity_hp.text = "HP: %d/%d" % [character.resources.current_health_points, character.resources.max_health_points]
	
	if current_entity_status:
		# Check if it's the local player's turn
		var is_local_turn = turn_manager.is_local_player_turn()
		if is_local_turn:
			current_entity_status.text = "YOUR TURN"
			current_entity_status.modulate = Color.GREEN
		else:
			current_entity_status.text = "WAITING"
			current_entity_status.modulate = Color.YELLOW

func _create_character_turn_display(character: BaseCharacter, turn_index: int, current_index: int) -> Control:
	"""Create a UI display for a character in the turn order"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(130, 40)
	
	var container = VBoxContainer.new()
	container.anchors_preset = Control.PRESET_FULL_RECT
	container.offset_left = 4
	container.offset_top = 4
	container.offset_right = -4
	container.offset_bottom = -4
	panel.add_child(container)
	
	var name_label = Label.new()
	var player_name = _get_player_name_for_character(character)
	name_label.text = player_name + " (" + character.character_type + ")"
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(name_label)
	
	var hp_label = Label.new()
	hp_label.text = "HP: %d/%d" % [character.resources.current_health_points, character.resources.max_health_points]
	hp_label.add_theme_font_size_override("font_size", 8)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(hp_label)
	
	# Store HP label reference and connect to health changes
	turn_order_hp_labels[character] = hp_label
	if character.resources:
		character.resources.health_changed.connect(_on_character_health_changed.bind(character))
	
	var init_label = Label.new()
	init_label.text = "Init: %d" % character.current_initiative
	init_label.add_theme_font_size_override("font_size", 8)
	init_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(init_label)
	
	# Color code based on turn position
	if turn_index == current_index + 1:
		# Next to act
		panel.modulate = Color(1.0, 1.0, 0.7)  # Light yellow
	elif turn_index > current_index:
		# Upcoming
		panel.modulate = Color(0.9, 0.9, 0.9)  # Light gray
	else:
		# Already acted this round
		panel.modulate = Color(0.7, 0.7, 0.7)  # Darker gray
	
	return panel

func _on_character_health_changed(current: int, maximum: int, character: BaseCharacter) -> void:
	"""Update HP display in turn order when a character's health changes"""
	if character in turn_order_hp_labels:
		var hp_label = turn_order_hp_labels[character]
		if hp_label and is_instance_valid(hp_label):
			hp_label.text = "HP: %d/%d" % [current, maximum]

func _clear_turn_order_displays() -> void:
	"""Clear all dynamic turn order displays"""
	# Disconnect health signals
	for character in turn_order_hp_labels:
		if character and is_instance_valid(character) and character.resources:
			if character.resources.health_changed.is_connected(_on_character_health_changed):
				character.resources.health_changed.disconnect(_on_character_health_changed)
	
	for display in turn_order_displays:
		if display and is_instance_valid(display):
			display.queue_free()
	turn_order_displays.clear()
	turn_order_hp_labels.clear()

func _hide_static_next_entity_panels() -> void:
	"""Hide the static NextEntity panels since we're using dynamic ones"""
	if turn_order_panel:
		var next_entity1 = turn_order_panel.get_node_or_null("NextEntity1")
		var next_entity2 = turn_order_panel.get_node_or_null("NextEntity2")
		var next_entity3 = turn_order_panel.get_node_or_null("NextEntity3")
		
		if next_entity1:
			next_entity1.visible = false
		if next_entity2:
			next_entity2.visible = false
		if next_entity3:
			next_entity3.visible = false

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
		add_system_message("Give up confirmation dialog opened")

func _on_give_up_confirmed() -> void:
	"""Handle Give up confirmation"""
	add_combat_message("Giving up and returning to main menu...")
	give_up_requested.emit()

func _on_give_up_canceled() -> void:
	"""Handle Give up cancellation"""
	add_system_message("Give up canceled - continuing the fight!")

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