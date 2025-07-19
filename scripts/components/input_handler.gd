class_name InputHandler
extends Node

## Handles all player input for the combat system
## Manages keyboard shortcuts, tile clicks, and ability targeting

var grid_manager: GridManager
var turn_manager: TurnManager
var ability_system: AbilitySystem
var ui_manager: UIManager
var game_controller: Node

func initialize(p_grid_manager: GridManager, p_turn_manager: TurnManager, p_ability_system: AbilitySystem, p_ui_manager: UIManager) -> void:
	"""Initialize the input handler with required systems"""
	grid_manager = p_grid_manager
	turn_manager = p_turn_manager
	ability_system = p_ability_system
	ui_manager = p_ui_manager
	game_controller = get_parent()  # Assuming input handler is child of game controller
	
	# Connect to grid manager for tile clicks
	if grid_manager:
		grid_manager.tile_clicked.connect(_on_tile_clicked)

func _ready() -> void:
	"""Set up input handling"""
	set_process_input(true)

func _input(event: InputEvent) -> void:
	"""Handle input actions using InputMap"""
	
	# Check if chat is focused - if so, don't process game shortcuts
	if ui_manager and ui_manager.get_chat_panel() and ui_manager.get_chat_panel().is_chat_focused():
		# Only allow Escape to exit chat
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel_ability"):
			ui_manager.get_chat_panel().chat_input.release_focus()
		return
	
	# Handle Enter key to focus chat
	if event.is_action_pressed("ui_text_submit"):
		if ui_manager and ui_manager.get_chat_panel():
			ui_manager.get_chat_panel().chat_input.grab_focus()
		return
	
	# Handle ability shortcuts
	for i in range(1, 7):
		if event.is_action_pressed("ability_" + str(i)):
			if ability_system:
				ability_system.activate_ability_by_index(i - 1)
			return
	
	# Handle end turn
	if event.is_action_pressed("end_turn"):
		if turn_manager:
			turn_manager._on_end_turn_pressed()
		return
	
	# Handle Escape key with priority logic
	# Both cancel_ability and give_up are mapped to Escape key
	if event.is_action_pressed("cancel_ability") or event.is_action_pressed("give_up"):
		# First check if ability targeting is active
		if ability_system and ability_system.is_in_targeting_mode():
			ability_system.cancel_ability_targeting()
		# Otherwise, show give up dialog
		elif ui_manager:
			ui_manager._on_give_up_pressed()
		return
	
	# Handle grid toggle
	if event.is_action_pressed("toggle_grid"):
		if game_controller and game_controller.has_method("_toggle_grid_borders"):
			game_controller._toggle_grid_borders()
		return


func _on_tile_clicked(grid_position: Vector2i) -> void:
	"""Handle when a tile is clicked"""
	# Forward the tile click to game controller
	if game_controller and game_controller.has_method("_on_tile_clicked"):
		game_controller._on_tile_clicked(grid_position)


func cleanup() -> void:
	"""Clean up input handler connections"""
	if grid_manager and grid_manager.tile_clicked.is_connected(_on_tile_clicked):
		grid_manager.tile_clicked.disconnect(_on_tile_clicked)
