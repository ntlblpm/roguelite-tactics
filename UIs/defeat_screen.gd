extends Control

@onready var main_menu_button: Button = $VBox/MainMenuButton

func _ready() -> void:
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://UIs/MainMenu.tscn")
