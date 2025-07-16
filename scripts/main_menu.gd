class_name MainMenu
extends Control

## Main menu screen for the roguelite tactics game
## Handles navigation to different game modes and screens

@onready var host_run_button: Button = $VBoxContainer/HostRunButton
@onready var join_run_button: Button = $VBoxContainer/JoinRunButton
@onready var sanctum_button: Button = $VBoxContainer/SanctumButton
@onready var exit_button: Button = $VBoxContainer/ExitButton

func _ready() -> void:
	_connect_buttons()
	
	# Set focus to the first button for keyboard navigation
	host_run_button.grab_focus()

func _connect_buttons() -> void:
	"""Connect button signals to their respective handler functions"""
	host_run_button.pressed.connect(_on_host_run_pressed)
	join_run_button.pressed.connect(_on_join_run_pressed)
	sanctum_button.pressed.connect(_on_sanctum_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func _on_host_run_pressed() -> void:
	"""Handle HOST RUN button press - opens lobby management for hosting games"""
	print("HOST RUN selected - Opening lobby management...")
	# TODO: Implement scene change to lobby hosting screen
	# get_tree().change_scene_to_file("res://scenes/HostLobby.tscn")

func _on_join_run_pressed() -> void:
	"""Handle JOIN RUN button press - opens interface to join existing games"""
	print("JOIN RUN selected - Opening join game interface...")
	# TODO: Implement scene change to join game screen
	# get_tree().change_scene_to_file("res://scenes/JoinLobby.tscn")

func _on_sanctum_pressed() -> void:
	"""Handle SANCTUM button press - opens character progression and roster management"""
	print("SANCTUM selected - Opening character progression...")
	get_tree().change_scene_to_file("res://scenes/Sanctum.tscn")

func _on_exit_pressed() -> void:
	"""Handle EXIT button press - quit the game"""
	print("Exiting game...")
	get_tree().quit()

func _input(event: InputEvent) -> void:
	"""Handle input events for additional navigation"""
	if event.is_action_pressed("ui_cancel"):
		# ESC key functionality - could show settings or confirmation dialog
		_on_exit_pressed() 