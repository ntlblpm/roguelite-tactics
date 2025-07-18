class_name MainMenu
extends Control

## Main menu screen for the roguelite tactics game
## Handles navigation to different game modes and screens

@onready var host_run_button: Button = $VBoxContainer/HostRunButton
@onready var join_run_button: Button = $VBoxContainer/JoinRunButton
@onready var sanctum_button: Button = $VBoxContainer/SanctumButton
@onready var exit_button: Button = $VBoxContainer/ExitButton

var ip_dialog: IPInputDialog

func _ready() -> void:
	_connect_buttons()
	_setup_ip_dialog()
	
	# Set focus to the first button for keyboard navigation
	host_run_button.grab_focus()

func _connect_buttons() -> void:
	"""Connect button signals to their respective handler functions"""
	host_run_button.pressed.connect(_on_host_run_pressed)
	join_run_button.pressed.connect(_on_join_run_pressed)
	sanctum_button.pressed.connect(_on_sanctum_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func _setup_ip_dialog() -> void:
	"""Setup the IP input dialog for joining games"""
	ip_dialog = IPInputDialog.new()
	add_child(ip_dialog)
	ip_dialog.ip_confirmed.connect(_on_ip_confirmed)

func _on_host_run_pressed() -> void:
	## Handle HOST RUN button press - directly start hosting and go to lobby
	
	if NetworkManager.create_host("Host"):
		get_tree().change_scene_to_file("res://UIs/Lobby.tscn")
	else:
		# TODO: Show error dialog to user
		pass

func _on_join_run_pressed() -> void:
	## Handle JOIN RUN button press - show IP dialog and directly join
	ip_dialog.reset_dialog()
	ip_dialog.popup_centered()

func _on_ip_confirmed(ip_address: String) -> void:
	"""Handle IP confirmation from dialog - directly join the game"""
	
	if NetworkManager.join_host(ip_address, "Player"):
		get_tree().change_scene_to_file("res://UIs/Lobby.tscn")
	else:
		# TODO: Show error dialog to user
		pass

func _on_sanctum_pressed() -> void:
	"""Handle SANCTUM button press - opens character progression and roster management"""
	get_tree().change_scene_to_file("res://UIs/Sanctum.tscn")

func _on_exit_pressed() -> void:
	"""Handle EXIT button press - quit the game"""
	get_tree().quit()

func _input(event: InputEvent) -> void:
	"""Handle input events for additional navigation"""
	if event.is_action_pressed("ui_cancel"):
		# ESC key functionality - could show settings or confirmation dialog
		_on_exit_pressed() 
