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
	
	# Format button text with AP cost, damage, range, and cooldown
	var button_text = ability.ability_name + "\n"
	button_text += "Damage: " + str(ability.damage) + "\n"
	button_text += "Range: " + str(ability.range) + "\n"
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
	var is_player_turn = button.get_meta("is_player_turn", true)
	var base_brightness = 1.0 if is_player_turn else 0.6
	
	if ability.current_cooldown > 0:
		# On cooldown - show red tint
		button.modulate = Color(1.0 * base_brightness, 0.5 * base_brightness, 0.5 * base_brightness, 1.0)
	elif character.resources.current_ability_points < ability.ap_cost:
		# Not enough AP - show blue tint
		button.modulate = Color(0.5 * base_brightness, 0.5 * base_brightness, 1.0 * base_brightness, 1.0)
	elif not can_use:
		# Other reason - grey out
		button.modulate = Color(0.5 * base_brightness, 0.5 * base_brightness, 0.5 * base_brightness, 1.0)
	else:
		# Can use - normal color
		button.modulate = Color(base_brightness, base_brightness, base_brightness, 1.0)

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
		
	# Targeting mode activated
	
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
	
	# Targeting cancelled
	
	targeting_mode_changed.emit(false, null)

func _show_ability_range(character: BaseCharacter, ability: AbilityComponent) -> void:
	"""Show the range for an ability using blue highlights"""
	if not grid_manager:
		return
		
	# Use the generic show_range_preview function for ability ranges
	grid_manager.show_range_preview(
		character.grid_position,
		ability.range,
		Color(1.0, 0.0, 0.0, 0.5),  # Red color for abilities
		true,  # Include entities (abilities target characters)
		"tiles",  # Highlight target tile on hover
		null  # No moving character for ability targeting
	)

func activate_ability_by_index(ability_index: int) -> void:
	"""Activate an ability by its index in the ability bar"""
	# Only process if it's the local player's turn
	if not turn_manager or not turn_manager.is_local_player_turn() or not turn_manager.is_character_turn_active():
		return
	
	var ability_buttons = ui_manager.get_ability_buttons()
	if ability_index < ability_buttons.size():
		_on_ability_button_pressed(ability_index)


func handle_tile_click(grid_position: Vector2i) -> void:
	"""Handle tile click in ability targeting mode"""
	if not ability_targeting_mode or not selected_ability or not current_character:
		return
	
	# Store ability reference and name before await in case selected_ability becomes null
	var ability_name = selected_ability.ability_name
	var ability_ref = selected_ability
	
	# Connect to damage signal to capture damage information
	var damage_info = {"targets": [], "damage": 0}
	var damage_handler = func(targets: Array[BaseCharacter], damage_amount: int):
		damage_info.targets = targets
		damage_info.damage = damage_amount
	
	ability_ref.ability_damage_dealt.connect(damage_handler, CONNECT_ONE_SHOT)
	
	# Attempt to use the ability
	var ability_successful = await ability_ref.use_ability(grid_position)
	
	if ability_successful:
		# Wait a frame to ensure damage signal has been emitted
		await get_tree().process_frame
		
		if ui_manager and damage_info.targets.size() > 0:
			# Format the enhanced combat message
			var target = damage_info.targets[0]  # Get first target
			var caster_name = current_character.character_type
			var target_name = target.character_type
			
			# Determine colors based on AI control
			var caster_color = "red" if current_character.is_ai_controlled() else "green"
			var target_color = "red" if target.is_ai_controlled() else "green"
			
			# Format message with colors
			var formatted_message = "[color=%s]%s[/color] [color=white]used[/color] [color=white]%s[/color] [color=white]on[/color] [color=%s]%s[/color] [color=white]for[/color] [b]%d[/b] [color=white]damage[/color]." % [
				caster_color, caster_name,
				ability_name,
				target_color, target_name,
				damage_info.damage
			]
			
			ui_manager.add_formatted_combat_message_multiplayer.rpc(formatted_message)
		elif ui_manager and ability_successful:
			# Fallback for abilities without targets
			var caster_name = current_character.character_type
			var caster_color = "red" if current_character.is_ai_controlled() else "green"
			var formatted_message = "[color=%s]%s[/color] [color=white]used[/color] [color=white]%s[/color]." % [
				caster_color, caster_name, ability_name
			]
			ui_manager.add_formatted_combat_message_multiplayer.rpc(formatted_message)
		
		# Emit signal
		ability_used.emit(current_character, ability_ref, grid_position)
	
	# Disconnect handler if still connected
	if ability_ref.ability_damage_dealt.is_connected(damage_handler):
		ability_ref.ability_damage_dealt.disconnect(damage_handler)
		
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
		var is_player_turn = button.get_meta("is_player_turn", false)
		var base_brightness = 1.0 if is_player_turn else 0.6
		button.modulate = Color(0.5 * base_brightness, 0.5 * base_brightness, 0.5 * base_brightness, 1.0)

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
