class_name NetworkSyncManager
extends Node

## Manages network synchronization for multiplayer games
## Handles game state syncing, late joiners, and turn synchronization

signal sync_completed()
signal late_joiner_synced(peer_id: int)

var spawn_manager: SpawnManager
var turn_manager: TurnManager

func initialize(p_spawn_manager: SpawnManager, p_turn_manager: TurnManager) -> void:
	"""Initialize the network sync manager with required systems"""
	spawn_manager = p_spawn_manager
	turn_manager = p_turn_manager

@rpc("any_peer", "call_remote", "reliable")
func request_game_state() -> void:
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
	var player_characters = spawn_manager.get_player_characters()
	for peer_id in player_characters:
		var character = player_characters[peer_id]
		if character and is_instance_valid(character):
			character_states[peer_id] = character.get_character_state()
	
	# Get current turn state
	var turn_state: Dictionary = {}
	if turn_manager:
		turn_state = turn_manager.get_turn_state()
	
	# Send comprehensive game state specifically to the requesting player
	receive_game_state.rpc_id(sender_id, players_data, character_states, turn_state)

@rpc("authority", "call_local", "reliable")
func receive_game_state(players_data: Array, character_states: Dictionary, turn_state: Dictionary) -> void:
	"""Receive and process game state from host (for late joiners)"""
	
	# Spawn all characters first
	spawn_manager.spawn_all_characters(players_data)
	
	# Wait for characters to be properly spawned
	await spawn_manager.spawn_completed
	
	# Apply character states
	var player_characters = spawn_manager.get_player_characters()
	for peer_id in character_states:
		if player_characters.has(peer_id):
			var character = player_characters[peer_id]
			if character and is_instance_valid(character):
				character.set_character_state(character_states[peer_id])
	
	# Apply turn state
	if turn_manager and turn_state.size() > 0:
		turn_manager.sync_turn_state(turn_state)
	
	late_joiner_synced.emit(multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func spawn_all_characters_rpc(players_data: Array) -> void:
	"""Spawn characters for all players (called by host)"""
	
	# Only host should initiate character spawning to prevent conflicts
	if multiplayer.get_remote_sender_id() != 1 and not NetworkManager.is_host:
		return
	
	spawn_manager.spawn_all_characters(players_data)

@rpc("any_peer", "call_remote", "reliable")
func request_turn_sync() -> void:
	"""Request current turn state from host"""
	if not NetworkManager.is_host or not turn_manager:
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Send current turn state to the requesting player
	sync_turn_state.rpc_id(sender_id)

@rpc("any_peer", "call_local", "reliable")
func sync_turn_state() -> void:
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
	
	sync_completed.emit()

func initiate_multiplayer_game(players: Array) -> void:
	"""Initialize the multiplayer game (called by host)"""
	if not NetworkManager.is_host:
		return
	
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
	spawn_all_characters_rpc.rpc(players_data)

func sync_initial_turn_state() -> void:
	"""Sync initial turn state to all clients (called by host)"""
	if not NetworkManager.is_host:
		return
		
	sync_turn_state.rpc()

func request_sync_as_client() -> void:
	"""Request game state sync as a client"""
	if NetworkManager.is_host:
		return
		
	request_turn_sync.rpc_id(1)