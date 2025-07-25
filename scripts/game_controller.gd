class_name GameController
extends Node2D

## Main game controller that coordinates all systems for multiplayer
## Now uses composition pattern with specialized manager components

# System managers
var grid_manager: GridManager
var turn_manager: TurnManager

# Component managers
var spawn_manager: SpawnManager
var ui_manager: UIManager
var input_handler: InputHandler
var ability_system: AbilitySystem
var network_sync_manager: NetworkSyncManager

# Scene references
@onready var combat_ui: Control = $CombatUI
@onready var tilemap_layer: TileMapLayer = $CombatArea/TileMapLayer

# Current player tracking
var current_player_id: int = -1

func _ready() -> void:
	# Check if room data was set by the loading screen
	if has_meta("room_data"):
		var room_data = get_meta("room_data")
		# Room data will be used by spawn manager when it initializes
		print("GameController: Using procedurally generated room data")
	
	_initialize_systems()
	_initialize_components()
	_connect_component_signals()
	
	# Don't initialize multiplayer game immediately - defer to next frame to ensure clean state
	call_deferred("_deferred_multiplayer_initialization")

func _exit_tree() -> void:
	"""Cleanup when the scene is being destroyed"""
	# Clean up components
	if spawn_manager:
		spawn_manager.clear_existing_characters()
	if ui_manager:
		ui_manager.cleanup()
	if input_handler:
		input_handler.cleanup()
	if ability_system:
		ability_system.cleanup()
	
	# Reset current player
	current_player_id = -1

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

func _initialize_components() -> void:
	"""Initialize all component managers"""
	print("[GameController] Initializing components")
	
	# Create spawn manager
	spawn_manager = SpawnManager.new()
	spawn_manager.name = "SpawnManager"
	add_child(spawn_manager)
	print("[GameController] SpawnManager created and added as child")
	
	# Debug: Print the spawn manager's path
	print("[GameController] SpawnManager path: %s" % spawn_manager.get_path())
	
	spawn_manager.initialize($CombatArea)
	spawn_manager.grid_manager = grid_manager  # Pass grid manager reference directly
	print("[GameController] SpawnManager initialized with CombatArea and grid_manager reference")
	
	# Create UI manager
	ui_manager = UIManager.new()
	ui_manager.name = "UIManager"
	add_child(ui_manager)
	ui_manager.initialize(combat_ui)
	
	# Create ability system
	ability_system = AbilitySystem.new()
	ability_system.name = "AbilitySystem"
	add_child(ability_system)
	ability_system.initialize(grid_manager, ui_manager, turn_manager)
	
	# Create input handler
	input_handler = InputHandler.new()
	input_handler.name = "InputHandler"
	add_child(input_handler)
	input_handler.initialize(grid_manager, turn_manager, ability_system, ui_manager)
	
	# Create network sync manager
	network_sync_manager = NetworkSyncManager.new()
	network_sync_manager.name = "NetworkSyncManager"
	add_child(network_sync_manager)
	network_sync_manager.initialize(spawn_manager, turn_manager)

func _connect_component_signals() -> void:
	"""Connect signals between components"""
	# Spawn manager signals
	spawn_manager.characters_spawned.connect(_on_characters_spawned)
	spawn_manager.spawn_completed.connect(_on_spawn_completed)
	
	# UI manager signals
	ui_manager.give_up_requested.connect(_on_give_up_requested)
	ui_manager.end_turn_requested.connect(_on_end_turn_requested)
	
	# Input handler is set up to call methods directly
	
	# Ability system signals
	ability_system.ability_used.connect(_on_ability_used)
	
	# Turn manager signals
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.turn_ended.connect(_on_turn_ended)
	
	# Network sync signals
	network_sync_manager.sync_completed.connect(_on_network_sync_completed)

func _deferred_multiplayer_initialization() -> void:
	"""Initialize multiplayer game after ensuring clean state"""
	# Wait one more frame to ensure scene is fully ready
	await get_tree().process_frame
	
	# If host and no room data exists, generate it
	if NetworkManager.is_host and not has_meta("room_data"):
		await _generate_room_with_loading()
	
	_initialize_multiplayer_game()

func _generate_room_with_loading() -> void:
	"""Host generates room data and sends loading updates to clients"""
	# Send loading screen start signal to all clients
	_show_loading_screen.rpc()
	
	# Show local loading UI
	_update_loading_progress(0.1, "Generating room layout...")
	await get_tree().create_timer(0.1).timeout
	
	# Generate room data
	var room_data = RoomGenerator.generate()
	set_meta("room_data", room_data)
	
	# Send progress update
	_update_loading_progress.rpc(0.3, "Creating battlefield...")
	await get_tree().create_timer(0.1).timeout
	
	# Send room data to all clients
	_receive_room_data.rpc(room_data)
	
	_update_loading_progress.rpc(0.5, "Preparing terrain...")
	await get_tree().create_timer(0.1).timeout
	
	# Apply room data locally
	_apply_room_data_to_tilemap(room_data)
	
	_update_loading_progress.rpc(0.8, "Positioning combatants...")
	await get_tree().create_timer(0.1).timeout
	
	# Final update
	_update_loading_progress.rpc(1.0, "Entering combat!")
	await get_tree().create_timer(0.2).timeout
	
	# Hide loading UI
	_hide_loading_screen.rpc()

func _initialize_multiplayer_game() -> void:
	"""Initialize the multiplayer game based on NetworkManager data"""
	print("[GameController] _initialize_multiplayer_game called")
	
	if not NetworkManager or not NetworkManager.connected:
		print("[GameController] NetworkManager not available or not connected")
		return
	
	# Connect grid manager to tilemap BEFORE spawning to ensure proper terrain validation
	print("[GameController] Checking tilemap_layer: %s" % tilemap_layer)
	print("[GameController] Checking grid_manager: %s" % grid_manager)
	
	if tilemap_layer and grid_manager:
		print("[GameController] Connecting grid_manager to tilemap_layer")
		grid_manager.set_tilemap_layer(tilemap_layer)
		
		# Wait a frame to ensure tilemap data is ready
		await get_tree().process_frame
		print("[GameController] Grid manager connected to tilemap, proceeding with spawn")
	else:
		push_error("[GameController] Missing tilemap_layer or grid_manager!")
	
	# Get player data from NetworkManager
	var players = NetworkManager.get_players_list()
	print("[GameController] Players list: %s" % str(players))
	
	if NetworkManager.is_host:
		print("[GameController] Host initiating character spawning")
		# Host initiates character spawning
		network_sync_manager.initiate_multiplayer_game(players)
		
		# Wait for spawning to complete
		await spawn_manager.spawn_completed
		print("[GameController] Host spawning completed")
	else:
		print("[GameController] Client waiting for character spawning from host")
		# Joining player - wait for character spawning from host
		await spawn_manager.spawn_completed
		print("[GameController] Client spawning completed")
	
	# Now connect systems with guaranteed character availability
	print("[GameController] Connecting systems")
	_connect_systems()

func _connect_systems() -> void:
	"""Connect all systems together after characters are spawned"""
	# Grid manager is already connected to tilemap in _initialize_multiplayer_game
	
	# Get spawned characters
	var player_characters = spawn_manager.get_player_characters()
	var enemy_characters = spawn_manager.get_enemy_characters()
	
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
		
		# Connect death signal for all player characters (host checks game end)
		if NetworkManager.is_host:
			character.character_died.connect(_on_character_died)
		
		character_list.append(character)
	
	# Process enemy characters
	for enemy in enemy_characters:
		if not enemy or not is_instance_valid(enemy):
			continue
		
		# Set grid manager reference
		enemy.grid_manager = grid_manager
		
		# Position enemy in world coordinates and register with grid manager
		enemy.set_grid_position(enemy.grid_position)
		
		# Connect death signal for enemies (host checks game end)
		if NetworkManager.is_host:
			enemy.character_died.connect(_on_character_died)
		
		character_list.append(enemy)
	
	if character_list.size() == 0:
		return
	
	# Initialize turn manager with all characters
	if turn_manager and character_list.size() > 0:
		turn_manager.initialize_multiplayer(
			character_list, 
			ui_manager.get_end_turn_button(), 
			ui_manager.get_chat_panel()
		)
		
		# For non-host players, request current turn state from host
		if not NetworkManager.is_host:
			network_sync_manager.request_sync_as_client()
		else:
			# Host immediately updates UI and prepares to start
			_update_turn_order_ui()
			
			# Small delay to ensure all clients are ready, then start the first turn
			await get_tree().create_timer(0.5).timeout
			
			# Sync initial turn state to all clients before starting
			network_sync_manager.sync_initial_turn_state()
			
			# Additional delay for clients to process the sync
			await get_tree().create_timer(0.2).timeout
			turn_manager.start_first_turn()
	
	# Show grid borders by default
	if grid_manager:
		grid_manager.show_grid_borders()
		ui_manager.add_system_message("Grid borders enabled - Press G to toggle")

func _on_characters_spawned(player_characters: Dictionary, enemy_characters: Array) -> void:
	"""Handle when characters are spawned"""
	# Characters are now available in spawn_manager
	pass

func _on_spawn_completed() -> void:
	"""Handle when spawning is completed"""
	# Spawning is done, systems can be connected
	pass

func _on_give_up_requested() -> void:
	"""Handle give up request from UI"""
	# Ensure proper cleanup before scene change
	await _cleanup_before_scene_change()
	
	# Return to main menu
	get_tree().change_scene_to_file("res://UIs/MainMenu.tscn")

func _on_end_turn_requested() -> void:
	"""Handle end turn request from UI"""
	# End turn is handled by turn manager which has the button reference
	pass

func _on_tile_clicked(grid_position: Vector2i) -> void:
	"""Handle tile click from input handler"""
	# Check if in ability targeting mode
	if ability_system.is_in_targeting_mode():
		ability_system.handle_tile_click(grid_position)
		return
	
	# Get current character
	var current_character = turn_manager.get_current_character()
	if not current_character:
		return
	
	# Direct turn check - only allow movement during local player's turn
	if not turn_manager.is_local_player_turn():
		return
	
	# Check if clicking on current character (selection)
	if grid_position == current_character.grid_position:
		current_character.character_selected.emit()
		return
	
	# Attempt to move character to clicked position
	var movement_successful = current_character.attempt_move_to(grid_position)
	
	if movement_successful:
		var player_name = _get_player_name_for_character(current_character)


func _on_ability_used(character: BaseCharacter, ability: AbilityComponent, target_position: Vector2i) -> void:
	"""Handle when an ability is used"""
	# Update UI after ability use
	ability_system.update_ability_bar(character)

func _on_turn_started(character: BaseCharacter) -> void:
	"""Handle when a turn starts"""
	_update_turn_order_ui()
	
	# Update UI turn state (button brightness based on turn)
	var is_local_turn = turn_manager and turn_manager.is_local_player_turn()
	ui_manager.update_turn_state(is_local_turn, character)
	
	# Update the stat display to show the current character's stats
	if turn_manager and turn_manager.is_local_player_turn():
		var current_turn_character = turn_manager.get_current_character()
		if current_turn_character and not current_turn_character.is_ai_controlled():
			# Update stat displays
			ui_manager.update_stats(
				current_turn_character.resources.current_health_points,
				current_turn_character.resources.max_health_points,
				current_turn_character.resources.current_movement_points,
				current_turn_character.resources.max_movement_points,
				current_turn_character.resources.current_ability_points,
				current_turn_character.resources.max_ability_points
			)
			
			# Show movement range
			if grid_manager and current_turn_character.resources.get_movement_points() > 0:
				grid_manager.highlight_movement_range(
					current_turn_character.grid_position, 
					current_turn_character.resources.get_movement_points(), 
					current_turn_character
				)
			
			# Update ability bar
			ability_system.update_ability_bar(current_turn_character)
		elif current_turn_character and current_turn_character.is_ai_controlled():
			# Enemy turn
			if grid_manager:
				grid_manager.clear_movement_highlights()
	else:
		# Not local player's turn
		if grid_manager:
			grid_manager.clear_movement_highlights()
		ability_system.disable_all_abilities()

func _on_turn_ended(character: BaseCharacter) -> void:
	"""Handle when a turn ends"""
	# Update turn order UI to reflect the change
	_update_turn_order_ui()

func _on_network_sync_completed() -> void:
	"""Handle when network sync is completed"""
	_update_turn_order_ui()
	
	# Update current character display
	var current_character = turn_manager.get_current_character()
	if current_character and turn_manager.is_local_player_turn():
		ui_manager.update_stats(
			current_character.resources.current_health_points,
			current_character.resources.max_health_points,
			current_character.resources.current_movement_points,
			current_character.resources.max_movement_points,
			current_character.resources.current_ability_points,
			current_character.resources.max_ability_points
		)

func _on_health_changed(current: int, maximum: int) -> void:
	"""Update HP display when character health changes"""
	ui_manager.update_hp_display(current, maximum)

func _on_movement_points_changed(current: int, maximum: int) -> void:
	"""Update MP display when movement points change"""
	ui_manager.update_mp_display(current, maximum)
	
	# Update movement highlights
	if grid_manager and turn_manager and turn_manager.is_local_player_turn() and turn_manager.is_character_turn_active() and current > 0:
		var current_character = turn_manager.get_current_character()
		if current_character and not current_character.is_ai_controlled():
			grid_manager.highlight_movement_range(current_character.grid_position, current, current_character)
	elif grid_manager:
		grid_manager.clear_movement_highlights()

func _on_ability_points_changed(current: int, maximum: int) -> void:
	"""Update AP display when ability points change"""
	ui_manager.update_ap_display(current, maximum)

func _on_character_selected() -> void:
	"""Handle when the character is selected"""
	if grid_manager and turn_manager and turn_manager.is_local_player_turn() and turn_manager.is_character_turn_active():
		var current_character = turn_manager.get_current_character()
		if current_character and not current_character.is_ai_controlled():
			grid_manager.highlight_movement_range(
				current_character.grid_position, 
				current_character.resources.get_movement_points(), 
				current_character
			)

func _on_movement_completed(new_position: Vector2i) -> void:
	"""Handle when the character's movement is completed"""
	if grid_manager and turn_manager and turn_manager.is_local_player_turn() and turn_manager.is_character_turn_active():
		var current_character = turn_manager.get_current_character()
		if current_character and not current_character.is_ai_controlled():
			grid_manager.highlight_movement_range(new_position, current_character.resources.get_movement_points(), current_character)

func _update_turn_order_ui() -> void:
	"""Update the turn order UI"""
	if not turn_manager:
		return
	
	var characters = turn_manager.get_characters_in_turn_order()
	var current_character = turn_manager.get_current_character()
	var current_index = turn_manager.current_character_index
	
	ui_manager.update_turn_order(characters, current_character, current_index, turn_manager)

func _cleanup_before_scene_change() -> void:
	"""Perform cleanup before changing scenes"""
	# Disconnect from multiplayer if connected
	if NetworkManager and NetworkManager.connected:
		NetworkManager.disconnect_from_network()
	
	# Clear game state
	current_player_id = -1
	
	# Wait a frame to ensure cleanup is processed
	await get_tree().process_frame

func get_current_player_character() -> BaseCharacter:
	"""Get the current player's character"""
	if current_player_id != -1:
		var player_characters = spawn_manager.get_player_characters()
		if player_characters.has(current_player_id):
			return player_characters[current_player_id]
	return null

func get_all_characters() -> Array[BaseCharacter]:
	"""Get all characters (players and enemies)"""
	return spawn_manager.get_all_characters()

func get_character_by_peer_id(peer_id: int) -> BaseCharacter:
	"""Get character by peer ID"""
	var player_characters = spawn_manager.get_player_characters()
	return player_characters.get(peer_id, null)

func get_grid_manager() -> GridManager:
	"""Get reference to the grid manager"""
	return grid_manager

func get_turn_manager() -> TurnManager:
	"""Get reference to the turn manager"""
	return turn_manager

func _get_player_name_for_character(character: BaseCharacter) -> String:
	"""Get a display name for the character's player"""
	var authority = character.get_multiplayer_authority()
	
	if NetworkManager and NetworkManager.connected:
		var players = NetworkManager.get_players_list()
		for player_info in players:
			if player_info.peer_id == authority:
				return player_info.player_name
	
	if authority == 1:
		return "Host"
	else:
		return "Player " + str(authority)


func _on_character_died(character: BaseCharacter) -> void:
	"""Handle when any character dies - check for game end conditions"""
	if not NetworkManager.is_host:
		return
	
	# Update UI to reflect the death
	_update_turn_order_ui()
	
	# Wait a frame to ensure the death is fully processed
	await get_tree().process_frame
	
	# Check victory condition (all enemies dead)
	var all_enemies_dead: bool = true
	var enemy_characters = spawn_manager.get_enemy_characters()
	for enemy in enemy_characters:
		if enemy and is_instance_valid(enemy) and not enemy.is_dead:
			all_enemies_dead = false
			break
	
	if all_enemies_dead:
		# Victory!
		print("[GameController] Host triggering victory for all players")
		await get_tree().create_timer(2.0).timeout
		_trigger_victory.rpc()
		return
	
	# Check defeat condition (all players dead)
	var all_players_dead: bool = true
	var player_characters = spawn_manager.get_player_characters()
	for peer_id in player_characters:
		var player = player_characters[peer_id]
		if player and is_instance_valid(player) and not player.is_dead:
			all_players_dead = false
			break
	
	if all_players_dead:
		# Defeat!
		print("[GameController] Host triggering defeat for all players")
		await get_tree().create_timer(2.0).timeout
		_trigger_defeat.rpc()

@rpc("authority", "call_local", "reliable")
func _trigger_victory() -> void:
	"""Trigger victory screen for all players"""
	print("[GameController] Victory RPC received on peer %d" % multiplayer.get_unique_id())
	
	# Don't disconnect from network yet - we need to stay connected for scene transition
	current_player_id = -1
	
	# Small delay to ensure all clients receive this RPC
	await get_tree().create_timer(0.5).timeout
	
	# Now change scene (this will handle network cleanup)
	get_tree().change_scene_to_file("res://UIs/VictoryScreen.tscn")

@rpc("authority", "call_local", "reliable")
func _trigger_defeat() -> void:
	"""Trigger defeat screen for all players"""
	print("[GameController] Defeat RPC received on peer %d" % multiplayer.get_unique_id())
	
	# Don't disconnect from network yet - we need to stay connected for scene transition
	current_player_id = -1
	
	# Small delay to ensure all clients receive this RPC
	await get_tree().create_timer(0.5).timeout
	
	# Now change scene (this will handle network cleanup)
	get_tree().change_scene_to_file("res://UIs/DefeatScreen.tscn")

func _toggle_grid_borders() -> void:
	"""Toggle grid border visibility"""
	if grid_manager:
		grid_manager.toggle_grid_borders()

# Loading screen RPCs
@rpc("call_local", "authority", "reliable")
func _show_loading_screen() -> void:
	"""Show loading screen UI"""
	if combat_ui and combat_ui.has_node("LoadingOverlay"):
		var loading_overlay = combat_ui.get_node("LoadingOverlay")
		loading_overlay.visible = true

@rpc("call_local", "authority", "reliable")
func _hide_loading_screen() -> void:
	"""Hide loading screen UI"""
	if combat_ui and combat_ui.has_node("LoadingOverlay"):
		var loading_overlay = combat_ui.get_node("LoadingOverlay")
		loading_overlay.visible = false

@rpc("call_local", "authority", "reliable")
func _update_loading_progress(progress: float, status: String) -> void:
	"""Update loading screen progress"""
	if combat_ui and combat_ui.has_node("LoadingOverlay"):
		var loading_overlay = combat_ui.get_node("LoadingOverlay")
		if loading_overlay.has_node("VBoxContainer/ProgressBar"):
			var progress_bar = loading_overlay.get_node("VBoxContainer/ProgressBar")
			progress_bar.value = progress
		if loading_overlay.has_node("VBoxContainer/StatusLabel"):
			var status_label = loading_overlay.get_node("VBoxContainer/StatusLabel")
			status_label.text = status

@rpc("call_local", "authority", "reliable")
func _receive_room_data(room_data: Dictionary) -> void:
	"""Receive and apply room data from host"""
	set_meta("room_data", room_data)
	
	# Apply to tilemap if we're a client
	if not NetworkManager.is_host:
		_apply_room_data_to_tilemap(room_data)
	
	# Update spawn manager with new spawn positions
	if spawn_manager and room_data.has("player_spawns") and room_data.has("enemy_spawns"):
		var room_size := 13  # From RoomGenerator.ROOM_SIZE
		
		# Convert spawn positions to centered coordinates
		var centered_player_spawns := []
		for spawn in room_data.player_spawns:
			var centered_spawn := Vector2i(spawn.x - room_size / 2, spawn.y - room_size / 2)
			centered_player_spawns.append(centered_spawn)
		
		var centered_enemy_spawns := []
		for spawn in room_data.enemy_spawns:
			var centered_spawn := Vector2i(spawn.x - room_size / 2, spawn.y - room_size / 2)
			centered_enemy_spawns.append(centered_spawn)
		
		spawn_manager.set_meta("player_spawns", centered_player_spawns)
		spawn_manager.set_meta("enemy_spawns", centered_enemy_spawns)

func _apply_room_data_to_tilemap(room_data: Dictionary) -> void:
	"""Apply generated room data to the tilemap"""
	print("[GameController] Applying room data to tilemap")
	
	if not tilemap_layer:
		push_error("[GameController] No tilemap layer found")
		return
	
	# Clear existing tiles
	tilemap_layer.clear()
	
	# Apply generated tiles
	var room_size := 13  # From RoomGenerator.ROOM_SIZE
	var tile_index := 0
	
	for y in room_size:
		for x in room_size:
			var atlas_coords := room_data.tile_atlas_coords[tile_index] as Vector2i
			# Adjust coordinates for the tilemap (centered at 0,0)
			var map_x := x - room_size / 2
			var map_y := y - room_size / 2
			tilemap_layer.set_cell(Vector2i(map_x, map_y), 1, atlas_coords)  # source_id = 1
			tile_index += 1
	
	print("[GameController] Room data applied to tilemap")
