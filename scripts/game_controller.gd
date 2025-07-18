class_name GameController
extends Node2D

## Main game controller that coordinates all systems for multiplayer
## Manages the integration between grid, turns, characters, networking, and UI

# Scene references for all character classes
@export var swordsman_scene: PackedScene = preload("res://players/swordsman/Swordsman.tscn")
@export var archer_scene: PackedScene = preload("res://players/archer/Archer.tscn")
@export var pyromancer_scene: PackedScene = preload("res://players/pyromancer/Pyromancer.tscn")

# Scene references for enemies
@export var skeleton_scene: PackedScene = preload("res://enemies/skeleton/Skeleton.tscn")

# System managers
var grid_manager: GridManager
var turn_manager: TurnManager

# Game entities - now supports multiple players
var player_characters: Dictionary = {} # peer_id -> BaseCharacter
var enemy_characters: Array[BaseCharacter] = [] # Array of enemy characters
var current_player_id: int = -1
var is_spawning_characters: bool = false  # Prevent duplicate spawning

# Starting positions for players
var starting_positions: Array[Vector2i] = [
	Vector2i(0, 0),    # Player 1
	Vector2i(-2, 2),   # Player 2
	Vector2i(2, -2)    # Player 3
]

# Starting positions for enemies (for testing)
var enemy_spawn_positions: Array[Vector2i] = [
	Vector2i(3, -2)    # Single skeleton in top right area
]

# UI references
@onready var combat_ui: Control = $CombatUI
@onready var tilemap_layer: TileMapLayer = $CombatArea/TileMapLayer

# UI elements
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

# Confirmation modal for Give up
var give_up_confirmation_dialog: AcceptDialog

func _ready() -> void:
	_initialize_systems()
	_setup_ui_references()
	
	# Don't initialize multiplayer game immediately - defer to next frame to ensure clean state
	call_deferred("_deferred_multiplayer_initialization")

func _deferred_multiplayer_initialization() -> void:
	"""Initialize multiplayer game after ensuring clean state"""
	# Reset any stuck state flags
	is_spawning_characters = false
	player_characters.clear()
	current_player_id = -1
	
	# Clear any existing dynamic UI elements
	_clear_turn_order_displays()
	
	# Wait one more frame to ensure scene is fully ready
	await get_tree().process_frame
	
	_initialize_multiplayer_game()

func _exit_tree() -> void:
	"""Cleanup when the scene is being destroyed"""
	
	# Reset spawning flag to prevent issues in next run
	is_spawning_characters = false
	
	# Clear character references
	for peer_id in player_characters.keys():
		var character = player_characters[peer_id]
		if character and is_instance_valid(character):
			# Disconnect signals to prevent memory leaks
			if character.health_changed.is_connected(_on_health_changed):
				character.health_changed.disconnect(_on_health_changed)
			if character.movement_points_changed.is_connected(_on_movement_points_changed):
				character.movement_points_changed.disconnect(_on_movement_points_changed)
			if character.ability_points_changed.is_connected(_on_ability_points_changed):
				character.ability_points_changed.disconnect(_on_ability_points_changed)
			if character.character_selected.is_connected(_on_character_selected):
				character.character_selected.disconnect(_on_character_selected)
			if character.movement_completed.is_connected(_on_movement_completed):
				character.movement_completed.disconnect(_on_movement_completed)
	
	player_characters.clear()
	current_player_id = -1
	
	# Clear dynamic UI elements
	_clear_turn_order_displays()
	
	# Disconnect grid manager signals
	if grid_manager and grid_manager.tile_clicked.is_connected(_on_tile_clicked):
		grid_manager.tile_clicked.disconnect(_on_tile_clicked)
	
	# Disconnect turn manager signals
	if turn_manager:
		if turn_manager.turn_started.is_connected(_on_turn_started):
			turn_manager.turn_started.disconnect(_on_turn_started)
		if turn_manager.turn_ended.is_connected(_on_turn_ended):
			turn_manager.turn_ended.disconnect(_on_turn_ended)
	
	# Disconnect button signals
	if give_up_button and give_up_button.pressed.is_connected(_on_give_up_pressed):
		give_up_button.pressed.disconnect(_on_give_up_pressed)
	
	if give_up_confirmation_dialog:
		if give_up_confirmation_dialog.confirmed.is_connected(_on_give_up_confirmed):
			give_up_confirmation_dialog.confirmed.disconnect(_on_give_up_confirmed)
		if give_up_confirmation_dialog.canceled.is_connected(_on_give_up_canceled):
			give_up_confirmation_dialog.canceled.disconnect(_on_give_up_canceled)

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

func _setup_ui_references() -> void:
	"""Setup references to UI elements"""
	if combat_ui:
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

func _initialize_multiplayer_game() -> void:
	"""Initialize the multiplayer game based on NetworkManager data"""
	if not NetworkManager or not NetworkManager.connected:
		return
	
	# Get player data from NetworkManager
	var players = NetworkManager.get_players_list()
	
	if NetworkManager.is_host:
		# Convert PlayerInfo objects to dictionaries for RPC transmission
		var players_data: Array = []
		for player_info in players:
			players_data.append({
				"peer_id": player_info.peer_id,
				"player_name": player_info.player_name,
				"selected_class": player_info.selected_class,
				"class_levels": player_info.class_levels
			})
		
		# Host spawns all characters and broadcasts to all clients
		_spawn_all_characters.rpc(players_data)
		
		# Wait for spawning confirmation from all clients before proceeding
		await _wait_for_all_characters_spawned(players_data.size())
	else:
		# Joining player - wait for character spawning RPC from host
		
		# Wait for characters to be spawned via the host's RPC
		await _wait_for_all_characters_spawned(players.size())
	
	# Now connect systems with guaranteed character availability
	_connect_systems()

func _wait_for_all_characters_spawned(expected_count: int) -> void:
	"""Wait for all characters to be properly spawned before proceeding"""
	
	var max_attempts: int = 50  # 5 seconds at 10 FPS, increased for network latency
	var attempts: int = 0
	
	while attempts < max_attempts:
		# Check if we have the expected number of valid characters
		var valid_character_count: int = 0
		for peer_id in player_characters:
			var character = player_characters[peer_id]
			if character and is_instance_valid(character) and character.is_inside_tree():
				# Additional validation - ensure character has essential properties
				var character_authority = character.get_multiplayer_authority()
				if character_authority > 0 and character_authority == peer_id:
					# Ensure character is properly initialized with stats
					if character.resources and character.resources.max_health_points > 0 and character.character_type != "":
						valid_character_count += 1
		
		if valid_character_count >= expected_count:
			# Additional frame wait to ensure everything is settled
			await get_tree().process_frame
			return
		
		attempts += 1
		await get_tree().create_timer(0.1).timeout  # Wait 100ms between checks

@rpc("any_peer", "call_remote", "reliable")
func _request_game_state() -> void:
	"""Request current game state from host (for late joiners)"""
	if not NetworkManager.is_host:
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Send current game state to the requesting player
	var players = NetworkManager.get_players_list()
	var players_data: Array = []
	for player_info in players:
		players_data.append({
			"peer_id": player_info.peer_id,
			"player_name": player_info.player_name,
			"selected_class": player_info.selected_class,
			"class_levels": player_info.class_levels
		})
	
	# Get current character states for synchronization
	var character_states: Dictionary = {}
	for peer_id in player_characters:
		var character = player_characters[peer_id]
		if character and is_instance_valid(character):
			character_states[peer_id] = character.get_character_state()
	
	# Get current turn state
	var turn_state: Dictionary = {}
	if turn_manager:
		turn_state = turn_manager.get_turn_state()
	
	# Send comprehensive game state specifically to the requesting player
	_receive_game_state.rpc_id(sender_id, players_data, character_states, turn_state)

@rpc("authority", "call_local", "reliable")
func _receive_game_state(players_data: Array, character_states: Dictionary, turn_state: Dictionary) -> void:
	"""Receive and process game state from host (for late joiners)"""
	
	# Spawn all characters first - this already has duplicate protection
	_spawn_all_characters_internal(players_data)
	
	# Wait for characters to be properly spawned using the same validation
	await _wait_for_all_characters_spawned(players_data.size())
	
	# Apply character states
	for peer_id in character_states:
		if player_characters.has(peer_id):
			var character = player_characters[peer_id]
			if character and is_instance_valid(character):
				character.set_character_state(character_states[peer_id])
	
	# Apply turn state
	if turn_manager and turn_state.size() > 0:
		turn_manager.sync_turn_state(turn_state)

@rpc("any_peer", "call_local", "reliable")
func _spawn_all_characters(players_data: Array) -> void:
	"""Spawn characters for all players (called by host)"""
	
	# Only host should initiate character spawning to prevent conflicts
	if multiplayer.get_remote_sender_id() != 1 and not NetworkManager.is_host:
		return
	
	# Prevent duplicate spawning
	if is_spawning_characters:
		return
	
	_spawn_all_characters_internal(players_data)

func _spawn_all_characters_internal(players_data: Array) -> void:
	"""Internal method to spawn characters (shared by RPC and local calls)"""
	if is_spawning_characters:
		return
	
	is_spawning_characters = true
	
	# Clear any existing characters first to prevent duplicates
	await _clear_existing_characters()
	
	# Extra validation - ensure we're still in a valid state to spawn
	if not NetworkManager or not NetworkManager.connected:
		is_spawning_characters = false
		return
	
	for i in range(players_data.size()):
		var player_data = players_data[i]
		var position_index = i % starting_positions.size()
		var start_position = starting_positions[position_index]
		
		_spawn_character(player_data.peer_id, player_data.selected_class, start_position)
	
	# Spawn enemies after players
	_spawn_enemies()
	
	is_spawning_characters = false

func _clear_existing_characters() -> void:
	"""Clear any existing characters to prevent duplicates"""
	
	for peer_id in player_characters.keys():
		var character = player_characters[peer_id]
		if character and is_instance_valid(character):
					# Disconnect signals before freeing
			if character.health_changed.is_connected(_on_health_changed):
				character.health_changed.disconnect(_on_health_changed)
			if character.movement_points_changed.is_connected(_on_movement_points_changed):
				character.movement_points_changed.disconnect(_on_movement_points_changed)
			if character.ability_points_changed.is_connected(_on_ability_points_changed):
				character.ability_points_changed.disconnect(_on_ability_points_changed)
			if character.character_selected.is_connected(_on_character_selected):
				character.character_selected.disconnect(_on_character_selected)
			if character.movement_completed.is_connected(_on_movement_completed):
				character.movement_completed.disconnect(_on_movement_completed)
			
			character.queue_free()
	
	player_characters.clear()
	
	# Clear enemies too
	for enemy in enemy_characters:
		if enemy and is_instance_valid(enemy):
			enemy.queue_free()
	
	enemy_characters.clear()
	
	# Wait a frame to ensure cleanup is complete
	await get_tree().process_frame

func _spawn_character(peer_id: int, character_class: String, grid_position: Vector2i) -> void:
	"""Spawn a character for a specific player"""
	var character_scene: PackedScene
	
	# Select the appropriate scene based on class
	match character_class:
		"Swordsman":
			character_scene = swordsman_scene
		"Archer":
			character_scene = archer_scene
		"Pyromancer":
			character_scene = pyromancer_scene
		_:
			character_scene = swordsman_scene
	
	# Instantiate the character
	var character = character_scene.instantiate() as BaseCharacter
	character.name = character_class + "_" + str(peer_id)
	
	# Set multiplayer authority
	character.set_multiplayer_authority(peer_id)
	
	# Position character
	character.grid_position = grid_position
	character.target_grid_position = grid_position
	
	# Add to scene
	$CombatArea.add_child(character)
	
	# Store reference
	player_characters[peer_id] = character
	
	# Ensure character renders above movement highlights
	character.z_index = 2

func _spawn_enemies() -> void:
	"""Spawn enemy characters for testing"""
	
	# Spawn skeletons at predefined positions
	for i in range(min(1, enemy_spawn_positions.size())):  # Spawn up to 1 skeleton
		var spawn_position = enemy_spawn_positions[i]
		_spawn_enemy("Skeleton", spawn_position, i)

func _spawn_enemy(enemy_type: String, grid_position: Vector2i, enemy_id: int) -> void:
	"""Spawn a single enemy"""
	var enemy_scene: PackedScene
	
	# Select the appropriate enemy scene
	match enemy_type:
		"Skeleton":
			enemy_scene = skeleton_scene
		_:
			enemy_scene = skeleton_scene
	
	if not enemy_scene:
		return
	
	# Instantiate the enemy
	var enemy = enemy_scene.instantiate() as BaseCharacter
	enemy.name = enemy_type + "_" + str(enemy_id)
	
	# Set multiplayer authority to host (enemies are controlled by host)
	enemy.set_multiplayer_authority(1)
	
	# Position enemy
	enemy.grid_position = grid_position
	enemy.target_grid_position = grid_position
	
	# Add to scene
	$CombatArea.add_child(enemy)
	
	# Store reference
	enemy_characters.append(enemy)
	
	# Ensure enemy renders above movement highlights
	enemy.z_index = 2

func _connect_systems() -> void:
	"""Connect all systems together"""
	# Connect grid manager to tilemap
	if tilemap_layer:
		grid_manager.set_tilemap_layer(tilemap_layer)
	
	# Setup all player characters
	
	# At this point, characters should already be validated by _wait_for_all_characters_spawned
	if player_characters.size() == 0:
		return
	
	var character_list: Array[BaseCharacter] = []
	
	# Process player characters
	for peer_id in player_characters:
		var character = player_characters[peer_id]
		if not character or not is_instance_valid(character):
			continue
		
		# Set grid manager reference
		character.grid_manager = grid_manager
		
		# Position character in world coordinates and register with grid manager
		character.set_grid_position(character.grid_position)
		
		# Connect character signals to UI updates (only for local player)
		if peer_id == multiplayer.get_unique_id():
			current_player_id = peer_id
			character.health_changed.connect(_on_health_changed)
			character.movement_points_changed.connect(_on_movement_points_changed)
			character.ability_points_changed.connect(_on_ability_points_changed)
			character.character_selected.connect(_on_character_selected)
			character.movement_completed.connect(_on_movement_completed)
		
		character_list.append(character)
	
	# Process enemy characters
	for enemy in enemy_characters:
		if not enemy or not is_instance_valid(enemy):
			continue
		
		# Set grid manager reference
		enemy.grid_manager = grid_manager
		
		# Position enemy in world coordinates and register with grid manager
		enemy.set_grid_position(enemy.grid_position)
		
		character_list.append(enemy)
	
	if character_list.size() == 0:
		return
	
	# Connect grid manager tile clicks to character movement (only for local player)
	if grid_manager:
		grid_manager.tile_clicked.connect(_on_tile_clicked)
	
	# Initialize turn manager with all characters
	if turn_manager and character_list.size() > 0 and end_turn_button and chat_panel:
		turn_manager.initialize_multiplayer(character_list, end_turn_button, chat_panel)
		
		# Connect turn manager signals for UI updates
		turn_manager.turn_started.connect(_on_turn_started)
		turn_manager.turn_ended.connect(_on_turn_ended)
		
		# For non-host players, request current turn state from host
		if not NetworkManager.is_host:
			_request_turn_sync.rpc_id(1)
		else:
			# Host immediately updates UI and prepares to start
			_hide_static_next_entity_panels()
			_update_turn_order_ui()
			
			# Small delay to ensure all clients are ready, then start the first turn
			await get_tree().create_timer(0.5).timeout
			
			# Sync initial turn state to all clients before starting
			_sync_turn_state.rpc()
			
			# Additional delay for clients to process the sync
			await get_tree().create_timer(0.2).timeout
			turn_manager.start_first_turn()
	
	# Connect Give up button and confirmation dialog
	if give_up_button:
		give_up_button.pressed.connect(_on_give_up_pressed)
	
	if give_up_confirmation_dialog:
		give_up_confirmation_dialog.confirmed.connect(_on_give_up_confirmed)
		give_up_confirmation_dialog.canceled.connect(_on_give_up_canceled)
	
	# Show grid borders by default
	if grid_manager:
		grid_manager.show_grid_borders()
		if chat_panel:
			chat_panel.add_system_message("Grid borders enabled - Press G to toggle")

@rpc("any_peer", "call_remote", "reliable")
func _request_turn_sync() -> void:
	"""Request current turn state from host"""
	if not NetworkManager.is_host or not turn_manager:
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Send current turn state to the requesting player
	_sync_turn_state.rpc_id(sender_id)

@rpc("any_peer", "call_local", "reliable")
func _sync_turn_state() -> void:
	"""Synchronize turn state across all clients"""
	if not turn_manager:
		return
	
	# Only allow host to broadcast turn state to prevent conflicts
	if multiplayer.get_remote_sender_id() != 1 and not NetworkManager.is_host:
		return
	
	# Get current turn state from turn manager
	var turn_state = turn_manager.get_turn_state()
	
	# For non-host clients, sync the turn state from the received data
	if not NetworkManager.is_host:
		turn_manager.sync_turn_state(turn_state)
	
	# Update turn order UI for all players
	_hide_static_next_entity_panels()
	_update_turn_order_ui()
	
	# Update current character display
	var current_character = turn_manager.get_current_character()
	if current_character:
		_update_current_entity_display(current_character)
		
		# Update stat displays if it's the local player's turn
		if turn_manager.is_local_player_turn():
			if hp_text:
				hp_text.text = "%d/%d" % [current_character.resources.current_health_points, current_character.resources.max_health_points]
			if mp_text:
				mp_text.text = "%d/%d" % [current_character.resources.current_movement_points, current_character.resources.max_movement_points]
			if ap_text:
				ap_text.text = "%d/%d" % [current_character.resources.current_ability_points, current_character.resources.max_ability_points]

func _on_health_changed(current: int, maximum: int) -> void:
	"""Update HP display when character health changes"""
	# Only update UI for the local player's character
	var sender_character = get_current_player_character()
	if not sender_character:
		return
	
	# Update HP text only if this is the local player's character
	if hp_text:
		hp_text.text = "%d/%d" % [current, maximum]

func _on_movement_points_changed(current: int, maximum: int) -> void:
	## Update MP display when movement points change
	
	# Only update UI for the local player's character
	var sender_character = get_current_player_character()
	if not sender_character:
		return
	
	# Update MP text only if this is the local player's character
	if mp_text:
		mp_text.text = "%d/%d" % [current, maximum]
	
	# Update movement highlights only if it's the local player's turn AND the turn is actually active
	# This prevents highlights from flashing during turn transitions when resources are refreshed
	var current_turn_character: BaseCharacter = null
	if grid_manager and turn_manager and turn_manager.is_local_player_turn() and turn_manager.is_character_turn_active() and current > 0:
		current_turn_character = turn_manager.get_current_character()
		if current_turn_character:
			# Double-check that this is not an AI character
			if current_turn_character.is_ai_controlled():
				return  # Don't update movement highlights for AI characters
			
			grid_manager.highlight_movement_range(current_turn_character.grid_position, current, current_turn_character)
	elif grid_manager:
		# Clear highlights if no movement points remaining or not local player's turn or turn not active
		grid_manager.clear_movement_highlights()
		if chat_panel and turn_manager and turn_manager.is_local_player_turn() and turn_manager.is_character_turn_active() and current <= 0:
			current_turn_character = turn_manager.get_current_character()
			if current_turn_character and not current_turn_character.is_ai_controlled():
				chat_panel.add_system_message("No movement points remaining - Movement range cleared")

func _on_ability_points_changed(current: int, maximum: int) -> void:
	## Update AP display when ability points change
	
	# Only update UI for the local player's character
	var sender_character = get_current_player_character()
	if not sender_character:
		return
	
	# Update AP text only if this is the local player's character
	if ap_text:
		ap_text.text = "%d/%d" % [current, maximum]

func _on_character_selected() -> void:
	"""Handle when the character is selected"""
	# Only highlight movement for the local player's turn and when the turn is actually active
	if grid_manager and turn_manager and turn_manager.is_local_player_turn() and turn_manager.is_character_turn_active():
		var current_turn_character = turn_manager.get_current_character()
		if current_turn_character:
			# Double-check that this is not an AI character
			if current_turn_character.is_ai_controlled():
				return  # Don't show movement highlights for AI characters
			
			# Show movement range when selected
			grid_manager.highlight_movement_range(current_turn_character.grid_position, current_turn_character.resources.get_movement_points(), current_turn_character)
			
			if chat_panel:
				chat_panel.add_system_message(current_turn_character.character_type + " selected - Movement range highlighted")

func _on_tile_clicked(grid_position: Vector2i) -> void:
	"""Handle when a tile is clicked"""
	
	# Only allow input if it's the local player's turn AND the current character is not AI-controlled
	var current_turn_character: BaseCharacter = null
	if not turn_manager or not turn_manager.is_character_turn_active() or not turn_manager.is_local_player_turn():
		if turn_manager and turn_manager.is_character_turn_active() and not turn_manager.is_local_player_turn():
			current_turn_character = turn_manager.get_current_character()
			if current_turn_character and chat_panel:
				var player_name = _get_player_name_for_character(current_turn_character)
				chat_panel.add_system_message("It's " + player_name + "'s turn, not yours!")
		return
	
	# Get the character whose turn it is
	current_turn_character = turn_manager.get_current_character()
	if not current_turn_character:
		return
	
	# IMPORTANT: Block input if the current character is AI-controlled (enemy)
	if current_turn_character.is_ai_controlled():
		if chat_panel:
			chat_panel.add_system_message("Cannot control enemy characters - AI is taking its turn")
		return
	
	# Check if clicking on current character (selection)
	if grid_position == current_turn_character.grid_position:
		current_turn_character.character_selected.emit()
		return
	
	# Attempt to move character to clicked position
	var movement_successful = current_turn_character.attempt_move_to(grid_position)
	
	if movement_successful:
		if chat_panel:
			var player_name = _get_player_name_for_character(current_turn_character)
			chat_panel.add_combat_message("%s (%s) moved to %s" % [player_name, current_turn_character.character_type, str(grid_position)])
	else:
		if chat_panel:
			chat_panel.add_system_message("Cannot move to that position")

func _on_movement_completed(new_position: Vector2i) -> void:
	"""Handle when the character's movement is completed"""
	# Only update movement highlights if it's the local player's turn and the turn is actually active
	if grid_manager and turn_manager and turn_manager.is_local_player_turn() and turn_manager.is_character_turn_active():
		var current_turn_character = turn_manager.get_current_character()
		if current_turn_character:
			# Double-check that this is not an AI character
			if current_turn_character.is_ai_controlled():
				return  # Don't update movement highlights for AI characters
			
			# Immediately update movement range from the new position
			grid_manager.highlight_movement_range(new_position, current_turn_character.resources.get_movement_points(), current_turn_character)
			if chat_panel:
				chat_panel.add_system_message("Movement range updated from new position: " + str(new_position))

func _on_turn_started(_character: BaseCharacter) -> void:
	"""Handle when a turn starts - update turn order UI and display current character stats"""
	_update_turn_order_ui()
	
	# Update the stat display to show the current character's stats (if it's the local player's turn AND not AI)
	if turn_manager and turn_manager.is_local_player_turn():
		var current_turn_character = turn_manager.get_current_character()
		if current_turn_character:
			# Check if the current character is AI-controlled (enemy)
			if current_turn_character.is_ai_controlled():
				# It's an enemy turn - clear movement highlights and don't update player UI
				if grid_manager:
					grid_manager.clear_movement_highlights()
				if chat_panel:
					chat_panel.add_combat_message("Enemy " + current_turn_character.character_type + " is taking their turn...")
				return
			
			# It's a real player turn - update UI normally
			# Manually update the stat displays to show the current character's stats
			if hp_text:
				hp_text.text = "%d/%d" % [current_turn_character.resources.current_health_points, current_turn_character.resources.max_health_points]
			if mp_text:
				mp_text.text = "%d/%d" % [current_turn_character.resources.current_movement_points, current_turn_character.resources.max_movement_points]
			if ap_text:
				ap_text.text = "%d/%d" % [current_turn_character.resources.current_ability_points, current_turn_character.resources.max_ability_points]
			
			# Show movement range for the current character
			if grid_manager and current_turn_character.resources.get_movement_points() > 0:
				grid_manager.highlight_movement_range(current_turn_character.grid_position, current_turn_character.resources.get_movement_points(), current_turn_character)
	else:
		# If it's not the local player's turn, clear movement highlights
		if grid_manager:
			grid_manager.clear_movement_highlights()

func _on_turn_ended(_character: BaseCharacter) -> void:
	"""Handle when a turn ends"""
	pass  # Turn order UI will be updated when next turn starts

func _update_turn_order_ui() -> void:
	"""Update the turn order UI to show all characters in initiative order"""
	if not turn_manager or not turn_order_panel:
		return
	
	# Safety check: ensure we have characters before updating UI
	var characters_in_order = turn_manager.get_characters_in_turn_order()
	if characters_in_order.size() == 0:
		# Defer the update to next frame to allow character initialization to complete
		call_deferred("_update_turn_order_ui")
		return
	
	# Clear existing dynamic displays
	_clear_turn_order_displays()
	
	# Hide the static NextEntity panels since we're creating dynamic ones
	_hide_static_next_entity_panels()
	
	# Get all characters in turn order
	var current_character = turn_manager.get_current_character()
	var current_character_index = turn_manager.current_character_index
	
	for i in range(characters_in_order.size()):
		var character = characters_in_order[i]
		if character and is_instance_valid(character):
			pass
		else:
			return  # Exit if we have invalid characters
	
	# Update the main current entity display
	if current_character and is_instance_valid(current_character):
		_update_current_entity_display(current_character)
	
	# Create displays for all characters in turn order
	for i in range(characters_in_order.size()):
		var character = characters_in_order[i]
		if not character or not is_instance_valid(character):
			continue
			
		var is_current = (i == current_character_index and turn_manager.is_turn_active)
		
		# Skip the current character as it's already shown in the CurrentEntity panel
		if is_current:
			continue
			
		var character_display = _create_character_turn_display(character, i, current_character_index)
		turn_order_panel.add_child(character_display)
		turn_order_displays.append(character_display)

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

func _clear_turn_order_displays() -> void:
	"""Clear all dynamic turn order displays"""
	for display in turn_order_displays:
		if display and is_instance_valid(display):
			display.queue_free()
	turn_order_displays.clear()

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

func _update_current_entity_display(character: BaseCharacter) -> void:
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

func get_current_player_character() -> BaseCharacter:
	"""Get the current player's character"""
	if current_player_id != -1 and player_characters.has(current_player_id):
		return player_characters[current_player_id]
	return null

func get_all_characters() -> Array[BaseCharacter]:
	"""Get all characters (players and enemies)"""
	var characters: Array[BaseCharacter] = []
	# Add player characters
	for character in player_characters.values():
		characters.append(character)
	# Add enemy characters
	for enemy in enemy_characters:
		characters.append(enemy)
	return characters

func get_character_by_peer_id(peer_id: int) -> BaseCharacter:
	"""Get character by peer ID"""
	return player_characters.get(peer_id, null)

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
			KEY_F4:
				_debug_test_enemy_ai()
			KEY_G:
				_toggle_grid_borders()

func _debug_print_game_state() -> void:
	"""Debug function to print current game state"""
	pass

func _debug_test_movement() -> void:
	"""Debug function to test movement"""
	var current_character = get_current_player_character()
	if current_character:
		var test_position: Vector2i = Vector2i(current_character.grid_position.x + 1, current_character.grid_position.y)
		current_character.attempt_move_to(test_position)

func _debug_test_damage() -> void:
	"""Debug function to test damage application"""
	var current_character = get_current_player_character()
	if current_character:
		current_character.take_damage(10)

func _debug_test_enemy_ai() -> void:
	"""Debug function to test enemy AI"""
	if enemy_characters.size() == 0:
		return
	
	# Force test AI logic for first enemy
	var enemy = enemy_characters[0]
	if enemy and enemy.has_method("start_ai_turn"):
		enemy.start_ai_turn()
		if chat_panel:
			chat_panel.add_system_message("DEBUG: Forced AI turn for " + enemy.character_type)

func _toggle_grid_borders() -> void:
	"""Debug function to toggle grid border visibility"""
	if grid_manager:
		grid_manager.toggle_grid_borders()

func _on_give_up_pressed() -> void:
	"""Handle Give up button press - show confirmation dialog"""
	if give_up_confirmation_dialog:
		give_up_confirmation_dialog.popup_centered()
		if chat_panel:
			chat_panel.add_system_message("Give up confirmation dialog opened")

func _on_give_up_confirmed() -> void:
	"""Handle Give up confirmation - return to main menu"""
	
	# Add a system message before leaving
	if chat_panel:
		chat_panel.add_combat_message("Giving up and returning to main menu...")
	
	# Ensure proper cleanup before scene change
	await _cleanup_before_scene_change()
	
	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_give_up_canceled() -> void:
	"""Handle Give up cancellation - close dialog and continue playing"""
	if chat_panel:
		chat_panel.add_system_message("Give up canceled - continuing the fight!")

func _cleanup_before_scene_change() -> void:
	"""Perform cleanup before changing scenes"""
	
	# Reset spawning flag
	is_spawning_characters = false
	
	# Disconnect from multiplayer if connected
	if NetworkManager and NetworkManager.connected:
		NetworkManager.disconnect_from_network()
	
	# Clear game state
	player_characters.clear()
	current_player_id = -1
	
	# Clear dynamic UI elements
	_clear_turn_order_displays()
	
	# Wait a frame to ensure cleanup is processed
	await get_tree().process_frame

func get_grid_manager() -> GridManager:
	"""Get reference to the grid manager"""
	return grid_manager

func get_turn_manager() -> TurnManager:
	"""Get reference to the turn manager"""
	return turn_manager 
