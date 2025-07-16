class_name GameController
extends Node2D

## Main game controller that coordinates all systems
## Manages the integration between grid, turns, characters, and UI

# Scene references
@export var swordsman_scene: PackedScene = preload("res://players/swordsman/Swordsman.tscn")

# System managers
var grid_manager: GridManager
var turn_manager: TurnManager

# Game entities
var swordsman: SwordsmanCharacter

# UI references
@onready var combat_ui: Control = $CombatUI
@onready var tilemap_layer: TileMapLayer = $CombatArea/TileMapLayer

# UI elements
var hp_text: Label
var ap_text: Label
var mp_text: Label
var end_turn_button: Button
var chat_panel: ChatPanel

func _ready() -> void:
	_initialize_systems()
	_setup_ui_references()
	_create_swordsman()
	_connect_systems()
	
	print("Game initialized successfully!")

func _initialize_systems() -> void:
	"""Initialize core game systems"""
	# Create grid manager
	grid_manager = GridManager.new()
	grid_manager.name = "GridManager"
	add_child(grid_manager)
	
	# Create turn manager
	turn_manager = TurnManager.new()
	turn_manager.name = "TurnManager"
	add_child(turn_manager)
	
	print("Core systems initialized")

func _setup_ui_references() -> void:
	"""Setup references to UI elements"""
	if combat_ui:
		# Get stat display elements
		hp_text = combat_ui.get_node("UILayer/MainUI/StatDisplay/VBoxContainer/HPDisplay/HPContainer/HPText")
		ap_text = combat_ui.get_node("UILayer/MainUI/StatDisplay/VBoxContainer/HBoxContainer/APDisplay/APContainer/APText")
		mp_text = combat_ui.get_node("UILayer/MainUI/StatDisplay/VBoxContainer/HBoxContainer/MPDisplay/MPContainer/MPText")
		
		# Get control elements
		end_turn_button = combat_ui.get_node("UILayer/MainUI/FightControls/ButtonContainer/EndTurnBtn")
		chat_panel = combat_ui.get_node("UILayer/MainUI/ChatPanel")
		
		print("UI references setup complete")

func _create_swordsman() -> void:
	"""Create and setup the swordsman character"""
	# Instantiate swordsman
	swordsman = swordsman_scene.instantiate() as SwordsmanCharacter
	swordsman.name = "Swordsman"
	
	# Position swordsman at center of grid
	var start_position: Vector2i = Vector2i(0, 0)
	swordsman.grid_position = start_position
	swordsman.target_grid_position = start_position
	
	# Add to scene
	$CombatArea.add_child(swordsman)
	
	print("Swordsman created at grid position: ", start_position)

func _connect_systems() -> void:
	"""Connect all systems together"""
	# Connect grid manager to tilemap
	if tilemap_layer:
		grid_manager.set_tilemap_layer(tilemap_layer)
	
	# Set grid manager reference in swordsman
	if swordsman:
		swordsman.grid_manager = grid_manager
		
		# Position swordsman in world coordinates
		swordsman.global_position = grid_manager.grid_to_world(swordsman.grid_position)
		
		# Connect character signals to UI updates
		swordsman.health_changed.connect(_on_health_changed)
		swordsman.movement_points_changed.connect(_on_movement_points_changed)
		swordsman.action_points_changed.connect(_on_action_points_changed)
		swordsman.character_selected.connect(_on_character_selected)
		swordsman.movement_completed.connect(_on_movement_completed)
	
	# Connect grid manager tile clicks to swordsman movement
	if grid_manager:
		grid_manager.tile_clicked.connect(_on_tile_clicked)
	
	# Initialize turn manager
	if turn_manager and swordsman and end_turn_button and chat_panel:
		turn_manager.initialize(swordsman, end_turn_button, chat_panel)
	
	print("All systems connected")

func _on_health_changed(current: int, maximum: int) -> void:
	"""Update HP display when character health changes"""
	if hp_text:
		hp_text.text = "%d/%d" % [current, maximum]

func _on_movement_points_changed(current: int, maximum: int) -> void:
	"""Update MP display when movement points change"""
	if mp_text:
		mp_text.text = "%d/%d" % [current, maximum]
	
	# Update movement highlights when MP changes
	if grid_manager and swordsman and current > 0:
		grid_manager.highlight_movement_range(swordsman.grid_position, current)
	elif grid_manager:
		# Clear highlights if no movement points remaining
		grid_manager.clear_movement_highlights()
		if chat_panel:
			chat_panel.add_system_message("No movement points remaining - Movement range cleared")

func _on_action_points_changed(current: int, maximum: int) -> void:
	"""Update AP display when action points change"""
	if ap_text:
		ap_text.text = "%d/%d" % [current, maximum]

func _on_character_selected() -> void:
	"""Handle when the character is selected"""
	if grid_manager and swordsman:
		# Show movement range when selected
		grid_manager.highlight_movement_range(swordsman.grid_position, swordsman.current_movement_points)
		
		if chat_panel:
			chat_panel.add_system_message("Swordsman selected - Movement range highlighted")

func _on_tile_clicked(grid_position: Vector2i) -> void:
	"""Handle when a tile is clicked"""
	if not swordsman or not turn_manager or not turn_manager.is_character_turn_active():
		return
	
	# Check if clicking on swordsman (selection)
	if grid_position == swordsman.grid_position:
		swordsman.character_selected.emit()
		return
	
	# Attempt to move swordsman to clicked position
	if swordsman.attempt_move_to(grid_position):
		if chat_panel:
			chat_panel.add_combat_message("Swordsman moved to " + str(grid_position))

func _on_movement_completed(new_position: Vector2i) -> void:
	"""Handle when the character's movement is completed"""
	if grid_manager and swordsman:
		# Immediately update movement range from the new position
		grid_manager.highlight_movement_range(new_position, swordsman.current_movement_points)
		if chat_panel:
			chat_panel.add_system_message("Movement range updated from new position: " + str(new_position))

func _input(event: InputEvent) -> void:
	# Handle debug keys
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				_debug_print_game_state()
			KEY_F2:
				_debug_test_movement()
			KEY_F3:
				_debug_test_damage()

func _debug_print_game_state() -> void:
	"""Debug function to print current game state"""
	print("\n=== GAME STATE DEBUG ===")
	if swordsman:
		print("Swordsman stats: ", swordsman.get_stats_summary())
		print("Swordsman grid position: ", swordsman.grid_position)
		print("Swordsman world position: ", swordsman.global_position)
	
	if turn_manager:
		turn_manager.debug_print_turn_state()
	
	if grid_manager and swordsman:
		grid_manager.debug_print_tile_info(swordsman.grid_position)
	
	print("========================\n")

func _debug_test_movement() -> void:
	"""Debug function to test movement"""
	if swordsman:
		var test_position: Vector2i = Vector2i(swordsman.grid_position.x + 1, swordsman.grid_position.y)
		print("Testing movement to: ", test_position)
		swordsman.attempt_move_to(test_position)

func _debug_test_damage() -> void:
	"""Debug function to test damage"""
	if swordsman:
		print("Testing damage - Before: ", swordsman.current_health_points)
		swordsman.take_damage(10)
		print("After taking 10 damage: ", swordsman.current_health_points)

func get_swordsman() -> SwordsmanCharacter:
	"""Get reference to the swordsman character"""
	return swordsman

func get_grid_manager() -> GridManager:
	"""Get reference to the grid manager"""
	return grid_manager

func get_turn_manager() -> TurnManager:
	"""Get reference to the turn manager"""
	return turn_manager 
