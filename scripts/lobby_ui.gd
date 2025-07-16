class_name LobbyUI
extends Control

## Lobby UI for multiplayer class selection and connection management
## Handles host/join functionality, class selection with progression display, and game starting

# UI References  
@onready var disconnect_button: Button = $VBoxContainer/NetworkSection/DisconnectButton

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var class_container: VBoxContainer = $VBoxContainer/ClassSelection
@onready var swordsman_button: Button = $VBoxContainer/ClassSelection/SwordsmanSection/SwordsmanButton
@onready var swordsman_level: Label = $VBoxContainer/ClassSelection/SwordsmanSection/SwordsmanLevel
@onready var archer_button: Button = $VBoxContainer/ClassSelection/ArcherSection/ArcherButton
@onready var archer_level: Label = $VBoxContainer/ClassSelection/ArcherSection/ArcherLevel
@onready var pyromancer_button: Button = $VBoxContainer/ClassSelection/PyromancerSection/PyromancerButton
@onready var pyromancer_level: Label = $VBoxContainer/ClassSelection/PyromancerSection/PyromancerLevel

@onready var players_list: VBoxContainer = $VBoxContainer/PlayersSection/PlayersList
@onready var start_game_button: Button = $VBoxContainer/StartGameButton
@onready var back_button: Button = $VBoxContainer/BackButton

# Class button tracking
var class_buttons: Dictionary = {}
var current_selected_class: String = "Swordsman"

# Player display tracking
var player_displays: Dictionary = {} # peer_id -> Control node

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_update_ui_state()
	
	# If connected, select the local player's class based on progression
	if NetworkManager and NetworkManager.is_connected:
		print("Lobby: Connected, setting up player info...")
		_setup_connected_state()
		
		# For hosts, refresh player list immediately since they already have their data
		# For joiners, wait for initial player sync to complete
		if NetworkManager.is_host:
			_refresh_players_list()
		else:
			# Joiners will refresh the list when they receive the first player_connected or player_info_updated signal
			print("Lobby: Waiting for initial player sync as joiner...")

func _setup_ui() -> void:
	"""Setup initial UI state"""
	# Setup class buttons dictionary
	class_buttons = {
		"Swordsman": swordsman_button,
		"Archer": archer_button,
		"Pyromancer": pyromancer_button
	}
	
	# Update class levels if we can access progression
	_update_class_levels()
	
	# Select default class
	_select_class("Swordsman")

func _setup_connected_state() -> void:
	"""Setup UI when we're already connected (from main menu direct actions)"""
	# Update the local player's class selection based on progression or default
	if NetworkManager and NetworkManager.local_player_info:
		var player_class = NetworkManager.local_player_info.selected_class
		_select_class(player_class)
	
	# Update status to reflect current state
	_update_ui_state()

func _connect_signals() -> void:
	"""Connect all UI signals"""
	# Network buttons
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	
	# Class selection buttons
	swordsman_button.pressed.connect(_on_swordsman_pressed)
	archer_button.pressed.connect(_on_archer_pressed)
	pyromancer_button.pressed.connect(_on_pyromancer_pressed)
	
	# Start game button
	start_game_button.pressed.connect(_on_start_game_pressed)
	
	# Back button
	back_button.pressed.connect(_on_back_pressed)
	
	# Network manager signals
	if NetworkManager:
		NetworkManager.player_connected.connect(_on_player_connected)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		NetworkManager.player_info_updated.connect(_on_player_info_updated)
		NetworkManager.connection_failed.connect(_on_connection_failed)
		NetworkManager.disconnected_from_server.connect(_on_disconnected_from_server)
		NetworkManager.game_started.connect(_on_game_started)

func _update_ui_state() -> void:
	"""Update UI state based on network connection"""
	var is_connected = NetworkManager and NetworkManager.is_connected
	var is_host = NetworkManager and NetworkManager.is_host
	
	# Network section - only show disconnect when connected
	disconnect_button.visible = is_connected
	
	# Class selection - always visible since we only enter lobby when connected
	class_container.visible = true
	
	# Start game button - only visible when connected as host
	start_game_button.visible = is_connected and is_host
	start_game_button.text = "Start Run"
	
	# Status
	if is_connected:
		if is_host:
			status_label.text = "Hosting - Waiting for players..."
		else:
			status_label.text = "Connected to host"
	else:
		status_label.text = "Connection lost - use Back button to return to main menu"

func _update_class_levels() -> void:
	"""Update class level displays from progression data"""
	if not FileAccess.file_exists("user://progression_save.json"):
		swordsman_level.text = "Lv. 1"
		archer_level.text = "Lv. 1"
		pyromancer_level.text = "Lv. 1"
		return
	
	var file = FileAccess.open("user://progression_save.json", FileAccess.READ)
	if not file:
		return
	
	var json_data = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_data)
	
	if parse_result == OK:
		var data = json.data
		if data.has("class_levels"):
			var levels = data.class_levels
			swordsman_level.text = "Lv. " + str(int(levels.get("Swordsman", 1)))
			archer_level.text = "Lv. " + str(int(levels.get("Archer", 1)))
			pyromancer_level.text = "Lv. " + str(int(levels.get("Pyromancer", 1)))

func _select_class(selected_class: String) -> void:
	"""Select a character class"""
	current_selected_class = selected_class
	
	# Update button states
	for class_key in class_buttons:
		var button = class_buttons[class_key]
		if class_key == selected_class:
			button.modulate = Color.GREEN
			button.text = class_key + " (Selected)"
		else:
			button.modulate = Color.WHITE
			button.text = class_key
	
	# Update network - only available when connected
	if NetworkManager and NetworkManager.is_connected:
		NetworkManager.update_player_class(selected_class)
	else:
		print("Warning: Cannot select class - not connected to a game")

func _create_player_display(player_info: NetworkManager.PlayerInfo) -> Control:
	"""Create a display widget for a player"""
	var container = HBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = player_info.player_name
	name_label.custom_minimum_size = Vector2(100, 0)
	container.add_child(name_label)
	
	var class_label = Label.new()
	class_label.text = player_info.selected_class
	class_label.custom_minimum_size = Vector2(80, 0)
	container.add_child(class_label)
	
	var level_label = Label.new()
	var level = player_info.class_levels.get(player_info.selected_class, 1)
	level_label.text = "Lv. " + str(int(level))
	level_label.custom_minimum_size = Vector2(50, 0)
	container.add_child(level_label)
	
	return container

func _update_player_display(peer_id: int, player_info: NetworkManager.PlayerInfo) -> void:
	"""Update an existing player display"""
	if not player_displays.has(peer_id):
		return
	
	var container = player_displays[peer_id]
	var name_label = container.get_child(0) as Label
	var class_label = container.get_child(1) as Label
	var level_label = container.get_child(2) as Label
	
	name_label.text = player_info.player_name
	class_label.text = player_info.selected_class
	var level = player_info.class_levels.get(player_info.selected_class, 1)
	level_label.text = "Lv. " + str(int(level))

func _refresh_players_list() -> void:
	"""Refresh the entire players list"""
	# Clear existing displays
	for child in players_list.get_children():
		child.queue_free()
	player_displays.clear()
	
	if not NetworkManager or not NetworkManager.is_connected:
		return
	
	# Add all connected players
	for player_info in NetworkManager.get_players_list():
		var display = _create_player_display(player_info)
		players_list.add_child(display)
		player_displays[player_info.peer_id] = display

# Network button handlers

func _on_disconnect_pressed() -> void:
	"""Handle disconnect button press"""
	NetworkManager.disconnect_from_network()
	_update_ui_state()
	_refresh_players_list()

func _on_start_game_pressed() -> void:
	## Handle start game button press
	var is_connected = NetworkManager and NetworkManager.is_connected
	
	if not is_connected:
		status_label.text = "Error: Not connected to a game"
		return
	
	# Check if we have at least the host player
	if NetworkManager.get_player_count() == 0:
		status_label.text = "Need at least 1 player to start"
		return
	
	# Start the multiplayer game
	NetworkManager.start_game()

func _on_swordsman_pressed() -> void:
	"""Handle swordsman class selection"""
	_select_class("Swordsman")

func _on_archer_pressed() -> void:
	"""Handle archer class selection"""
	_select_class("Archer")

func _on_pyromancer_pressed() -> void:
	"""Handle pyromancer class selection"""
	_select_class("Pyromancer")

# Network event handlers
func _on_player_connected(peer_id: int, player_info: NetworkManager.PlayerInfo) -> void:
	"""Handle when a new player connects"""
	print("Player connected: ", player_info.player_name)
	_refresh_players_list()

func _on_player_disconnected(peer_id: int) -> void:
	"""Handle when a player disconnects"""
	print("Player disconnected: ", peer_id)
	_refresh_players_list()

func _on_player_info_updated(peer_id: int, player_info: NetworkManager.PlayerInfo) -> void:
	"""Handle when player info is updated"""
	# If the player display doesn't exist yet, refresh the entire list (for initial sync)
	if not player_displays.has(peer_id):
		_refresh_players_list()
	else:
		_update_player_display(peer_id, player_info)

func _on_connection_failed() -> void:
	"""Handle connection failure"""
	status_label.text = "Connection failed"
	_update_ui_state()

func _on_disconnected_from_server() -> void:
	"""Handle disconnection from server"""
	status_label.text = "Disconnected from server"
	_update_ui_state()
	_refresh_players_list()

func _on_game_started() -> void:
	"""Handle when the game starts"""
	print("Game starting from lobby...")
	# Transition to TestRoom scene
	get_tree().change_scene_to_file("res://scenes/TestRoom.tscn")

func _on_back_pressed() -> void:
	"""Handle back button press"""
	# Disconnect from network if connected
	if NetworkManager and NetworkManager.is_connected:
		NetworkManager.disconnect_from_network()
	
	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn") 
