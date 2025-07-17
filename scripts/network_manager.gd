extends Node

## Network manager singleton for P2P multiplayer
## Handles host/client connections, player info synchronization, and lobby management

# Network constants
const DEFAULT_PORT: int = 7000
const MAX_PLAYERS: int = 3

# Network state
var multiplayer_peer: ENetMultiplayerPeer
var is_host: bool = false
var is_connected: bool = false

# Player data structure
var players: Dictionary = {} # peer_id -> PlayerInfo
var local_player_info: PlayerInfo
var host_peer_id: int = 1

# Player info class
class PlayerInfo:
	var peer_id: int
	var player_name: String
	var selected_class: String = "Swordsman"
	var class_levels: Dictionary = {"Swordsman": 1, "Archer": 1, "Pyromancer": 1}
	var is_ready: bool = false
	
	func _init(id: int, name: String):
		peer_id = id
		player_name = name

# Signals
signal player_connected(peer_id: int, player_info: PlayerInfo)
signal player_disconnected(peer_id: int)
signal player_info_updated(peer_id: int, player_info: PlayerInfo)
signal connection_failed()
signal disconnected_from_server()
signal game_started()

func _ready() -> void:
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func create_host(player_name: String = "Host") -> bool:
	## Create a host for other players to connect to
	print("=== CREATING HOST ===")
	print("Creating host on port ", DEFAULT_PORT)
	
	# Ensure clean state before creating host
	disconnect_from_network()
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	
	if error != OK:
		print("Failed to create server: ", error)
		multiplayer_peer = null
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	is_host = true
	is_connected = true
	
	# Create local player info with progression data
	local_player_info = PlayerInfo.new(1, player_name)
	_load_player_progression(local_player_info)
	players[1] = local_player_info
	
	print("Host created successfully with peer ID: ", 1)
	print("=== HOST CREATION COMPLETE ===")
	return true

func join_host(ip_address: String, player_name: String = "Client") -> bool:
	## Connect to a host
	print("=== JOINING HOST ===")
	print("Connecting to host at ", ip_address, ":", DEFAULT_PORT)
	
	# Ensure clean state before joining
	disconnect_from_network()
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_client(ip_address, DEFAULT_PORT)
	
	if error != OK:
		print("Failed to create client: ", error)
		multiplayer_peer = null
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	is_host = false
	
	# Create local player info with progression data
	local_player_info = PlayerInfo.new(0, player_name) # Will be set to actual peer_id when connected
	_load_player_progression(local_player_info)
	
	print("Attempting to connect to host...")
	print("=== JOIN ATTEMPT INITIATED ===")
	return true

func disconnect_from_network() -> void:
	## Disconnect from the network
	print("=== DISCONNECTING FROM NETWORK ===")
	
	# Set disconnected state immediately to prevent race conditions
	is_connected = false
	
	# Properly close the multiplayer peer
	if multiplayer_peer:
		print("Closing multiplayer peer...")
		multiplayer_peer.close()
		multiplayer_peer = null
	
	# Clear multiplayer state
	if multiplayer:
		multiplayer.multiplayer_peer = null
		print("Cleared multiplayer peer reference")
	
	# Reset network state
	is_host = false
	host_peer_id = 1
	
	# Clear all player data
	players.clear()
	local_player_info = null
	
	print("Network state cleared successfully")
	print("=== DISCONNECTION COMPLETE ===")

func update_player_class(new_class: String) -> void:
	## Update the local player's selected class and broadcast to others
	if not local_player_info:
		return
	
	local_player_info.selected_class = new_class
	players[local_player_info.peer_id] = local_player_info
	
	# Broadcast the change to all other players
	_sync_player_info.rpc(local_player_info.peer_id, _player_info_to_dict(local_player_info))

func start_game() -> void:
	## Start the game (host only)
	if not is_host:
		print("Only host can start the game")
		return
	
	print("Host starting game...")
	_start_game.rpc()

func get_players_list() -> Array[PlayerInfo]:
	## Get list of all connected players
	var player_list: Array[PlayerInfo] = []
	for player_info in players.values():
		player_list.append(player_info)
	return player_list

func get_local_player() -> PlayerInfo:
	## Get the local player info
	return local_player_info

func get_player_count() -> int:
	## Get number of connected players
	return players.size()

# Network event handlers
func _on_peer_connected(peer_id: int) -> void:
	## Called when a new peer connects
	print("Peer connected: ", peer_id)
	
	if is_host:
		# Send existing player info to the new peer
		for existing_peer_id in players:
			var player_info = players[existing_peer_id]
			_sync_player_info.rpc_id(peer_id, existing_peer_id, _player_info_to_dict(player_info))

func _on_peer_disconnected(peer_id: int) -> void:
	## Called when a peer disconnects
	print("Peer disconnected: ", peer_id)
	
	if players.has(peer_id):
		players.erase(peer_id)
	
	player_disconnected.emit(peer_id)

func _on_connected_to_server() -> void:
	## Called when successfully connected to server as client
	print("=== CONNECTED TO SERVER ===")
	print("Connected to server successfully")
	
	# Extra validation - ensure we're still trying to connect
	if not multiplayer_peer:
		print("WARNING: Connected to server but multiplayer_peer is null")
		return
	
	is_connected = true
	
	# Update local player info with actual peer_id
	var actual_peer_id = multiplayer.get_unique_id()
	print("Received peer ID: ", actual_peer_id)
	
	# Validate peer ID
	if actual_peer_id <= 0:
		print("ERROR: Invalid peer ID received: ", actual_peer_id)
		connection_failed.emit()
		return
	
	local_player_info.peer_id = actual_peer_id
	players[actual_peer_id] = local_player_info
	
	# Send our player info to the host
	_request_player_sync.rpc_id(1, _player_info_to_dict(local_player_info))
	print("Sent player sync request to host")
	print("=== SERVER CONNECTION COMPLETE ===")

func _on_connection_failed() -> void:
	## Called when connection to server fails
	print("Connection to server failed")
	connection_failed.emit()

func _on_server_disconnected() -> void:
	## Called when disconnected from server
	print("=== SERVER DISCONNECTED ===")
	print("Disconnected from server - cleaning up state")
	
	# Ensure we properly clean up state
	disconnect_from_network()
	
	disconnected_from_server.emit()
	print("=== SERVER DISCONNECTION HANDLED ===")

# RPC methods
@rpc("any_peer", "call_local", "reliable")
func _sync_player_info(peer_id: int, player_data: Dictionary) -> void:
	## Synchronize player info across all clients
	var player_info = _dict_to_player_info(peer_id, player_data)
	players[peer_id] = player_info
	
	# Always emit signal for player info updates (including local player)
	player_info_updated.emit(peer_id, player_info)

@rpc("any_peer", "call_remote", "reliable")
func _request_player_sync(player_data: Dictionary) -> void:
	## Request to sync player info (client to host)
	if not is_host:
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	var player_info = _dict_to_player_info(sender_id, player_data)
	players[sender_id] = player_info
	
	# Broadcast new player to everyone
	_sync_player_info.rpc(sender_id, player_data)
	player_connected.emit(sender_id, player_info)

@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	## Start the game for all players
	print("Game starting...")
	game_started.emit()

# Helper methods
func _load_player_progression(player_info: PlayerInfo) -> void:
	## Load player progression data from save file
	# Try to load progression data
	if FileAccess.file_exists(ProgressionManager.SAVE_FILE_PATH):
		var file = FileAccess.open(ProgressionManager.SAVE_FILE_PATH, FileAccess.READ)
		if file:
			var json_data = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_data)
			
			if parse_result == OK:
				var data = json.data
				if data.has("class_levels"):
					player_info.class_levels = data.class_levels.duplicate()
			else:
				print("Failed to parse progression data")
	
	print("Loaded progression for ", player_info.player_name, ": ", player_info.class_levels)

func _player_info_to_dict(player_info: PlayerInfo) -> Dictionary:
	## Convert PlayerInfo to dictionary for network transmission
	return {
		"player_name": player_info.player_name,
		"selected_class": player_info.selected_class,
		"class_levels": player_info.class_levels,
		"is_ready": player_info.is_ready
	}

func _dict_to_player_info(peer_id: int, data: Dictionary) -> PlayerInfo:
	## Convert dictionary back to PlayerInfo
	var player_info = PlayerInfo.new(peer_id, data.get("player_name", "Unknown"))
	player_info.selected_class = data.get("selected_class", "Swordsman")
	player_info.class_levels = data.get("class_levels", {"Swordsman": 1, "Archer": 1, "Pyromancer": 1})
	player_info.is_ready = data.get("is_ready", false)
	return player_info 