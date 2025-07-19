class_name AbilitySystem
extends Node

## Manages ability usage, targeting, and UI updates
## Handles ability bar display, cooldowns, and targeting modes

signal ability_used(character: BaseCharacter, ability: AbilityComponent, target_position: Vector2i)
signal targeting_mode_changed(active: bool, ability: AbilityComponent)

var grid_manager: GridManager
var ui_manager: UIManager
var turn_manager: TurnManager

# Ability state
var selected_ability: AbilityComponent = null
var ability_targeting_mode: bool = false
var current_character: BaseCharacter = null

func initialize(p_grid_manager: GridManager, p_ui_manager: UIManager, p_turn_manager: TurnManager) -> void:
	"""Initialize the ability system with required managers"""
	grid_manager = p_grid_manager
	ui_manager = p_ui_manager
	turn_manager = p_turn_manager
	
	# Connect to ability buttons
	if ui_manager:
		var ability_buttons = ui_manager.get_ability_buttons()
		for i in range(ability_buttons.size()):
			var button = ability_buttons[i]
			if button:
				button.pressed.connect(_on_ability_button_pressed.bind(i))

func update_ability_bar(character: BaseCharacter) -> void:
	"""Update the ability bar to show the current character's abilities"""
	current_character = character
	
	# Clear ability targeting mode
	cancel_ability_targeting()
	
	var ability_buttons = ui_manager.get_ability_buttons()
	if ability_buttons.is_empty():
		return
	
	# Get all ability components from the character
	var abilities: Array[Node] = character.get_children().filter(func(child): return child is AbilityComponent)
	
	# Update each button
	for i in range(ability_buttons.size()):
		var button: Button = ability_buttons[i]
		
		if i < abilities.size():
			var ability: AbilityComponent = abilities[i]
			_update_ability_button(button, ability, character)
		else:
			# Hide unused buttons
			button.visible = false
			button.set_meta("ability", null)

func _update_ability_button(button: Button, ability: AbilityComponent, character: BaseCharacter) -> void:
	"""Update a single ability button"""
	button.visible = true
	
	# Format button text with AP cost and cooldown
	var button_text = ability.ability_name + "\n"
	button_text += "AP: " + str(ability.ap_cost)
	
	# Show cooldown if active
	if ability.current_cooldown > 0:
		button_text += " (CD: " + str(ability.current_cooldown) + ")"
	
	button.text = button_text
	
	# Update button state based on availability
	var can_use: bool = ability.current_cooldown == 0 and character.resources.current_ability_points >= ability.ap_cost
	button.disabled = not can_use
	
	# Store ability reference in button metadata
	button.set_meta("ability", ability)
	
	# Update visual state
	if ability.current_cooldown > 0:
		# On cooldown - show red tint
		button.modulate = Color(1.0, 0.5, 0.5, 1.0)
	elif character.resources.current_ability_points < ability.ap_cost:
		# Not enough AP - show blue tint
		button.modulate = Color(0.5, 0.5, 1.0, 1.0)
	elif not can_use:
		# Other reason - grey out
		button.modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		# Can use - normal color
		button.modulate = Color.WHITE

func _on_ability_button_pressed(button_index: int) -> void:
	"""Handle ability button press"""
	var ability_buttons = ui_manager.get_ability_buttons()
	if button_index >= ability_buttons.size():
		return
		
	var button: Button = ability_buttons[button_index]
	if not button.visible or button.disabled:
		return
		
	var ability: AbilityComponent = button.get_meta("ability")
	if not ability:
		return
		
	start_ability_targeting(ability)

func start_ability_targeting(ability: AbilityComponent) -> void:
	"""Enter ability targeting mode"""
	ability_targeting_mode = true
	selected_ability = ability
	
	# Clear any existing movement highlights
	if grid_manager:
		grid_manager.clear_movement_highlights()
		
	# Show ability range
	if current_character and grid_manager:
		_show_ability_range(current_character, ability)
		
	if ui_manager:
		ui_manager.add_system_message("Select a target for " + ability.ability_name)
	
	targeting_mode_changed.emit(true, ability)

func cancel_ability_targeting() -> void:
	"""Cancel ability targeting mode"""
	if not ability_targeting_mode:
		return
		
	ability_targeting_mode = false
	selected_ability = null
	
	# Clear highlights and show movement range again
	if grid_manager and current_character:
		grid_manager.clear_movement_highlights()
		if current_character.resources.get_movement_points() > 0:
			grid_manager.highlight_movement_range(
				current_character.grid_position, 
				current_character.resources.get_movement_points(), 
				current_character
			)
	
	if ui_manager:
		ui_manager.add_system_message("Ability targeting cancelled")
	
	targeting_mode_changed.emit(false, null)

func _show_ability_range(character: BaseCharacter, ability: AbilityComponent) -> void:
	"""Show the range for an ability using blue highlights"""
	if not grid_manager:
		return
		
	# Use the generic show_range_preview function for ability ranges
	grid_manager.show_range_preview(
		character.grid_position,
		ability.range,
		Color(0.2, 0.5, 1.0, 0.5),  # Blue color for abilities
		true,  # Include entities (abilities target characters)
		"tiles",  # Highlight target tile on hover
		null  # No moving character for ability targeting
	)

func handle_ability_shortcut(ability_index: int) -> void:
	"""Handle ability shortcut key press"""
	# Only process if it's the local player's turn
	if not turn_manager or not turn_manager.is_local_player_turn() or not turn_manager.is_character_turn_active():
		return
	
	var ability_buttons = ui_manager.get_ability_buttons()
	if ability_index < ability_buttons.size():
		_on_ability_button_pressed(ability_index)

func handle_escape_key() -> void:
	"""Handle escape key press"""
	if ability_targeting_mode:
		cancel_ability_targeting()

func handle_tile_click(grid_position: Vector2i) -> void:
	"""Handle tile click in ability targeting mode"""
	if not ability_targeting_mode or not selected_ability or not current_character:
		return
	
	# Store ability name before await in case selected_ability becomes null
	var ability_name = selected_ability.ability_name
	
	# Attempt to use the ability
	var ability_successful = await selected_ability.use_ability(grid_position)
	
	if ability_successful:
		if ui_manager:
			var player_name = _get_player_name_for_character(current_character)
			ui_manager.add_combat_message("%s used %s!" % [player_name, ability_name])
		
		# Emit signal
		ability_used.emit(current_character, selected_ability, grid_position)
		
		# Update UI after ability use
		update_ability_bar(current_character)
		
		# Update stat displays
		if current_character.resources:
			ui_manager.update_stats(
				current_character.resources.current_health_points,
				current_character.resources.max_health_points,
				current_character.resources.current_movement_points,
				current_character.resources.max_movement_points,
				current_character.resources.current_ability_points,
				current_character.resources.max_ability_points
			)
	else:
		if ui_manager:
			ui_manager.add_system_message("Invalid target for " + ability_name)
	
	# Exit ability targeting mode
	cancel_ability_targeting()

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

func disable_all_abilities() -> void:
	"""Disable all ability buttons"""
	var ability_buttons = ui_manager.get_ability_buttons()
	for button in ability_buttons:
		button.disabled = true
		button.modulate = Color(0.5, 0.5, 0.5, 1.0)

func is_in_targeting_mode() -> bool:
	"""Check if currently in ability targeting mode"""
	return ability_targeting_mode

func get_selected_ability() -> AbilityComponent:
	"""Get the currently selected ability"""
	return selected_ability

func cleanup() -> void:
	"""Clean up ability system connections"""
	if ui_manager:
		var ability_buttons = ui_manager.get_ability_buttons()
		for i in range(ability_buttons.size()):
			var button = ability_buttons[i]
			if button and button.pressed.is_connected(_on_ability_button_pressed):
				button.pressed.disconnect(_on_ability_button_pressed)