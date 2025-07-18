class_name SanctumUI
extends Control

## Main Sanctum UI controller for character progression and upgrade management
## Handles tab switching, upgrade purchasing, and progression display

# References to progression system
var progression_manager

# UI References
@onready var tab_container: TabContainer = $MainContainer/TabContainer
@onready var back_button: Button = $MainContainer/TopBar/BackButton

# Tab panels
@onready var true_tab: Control = $MainContainer/TabContainer/True
@onready var swordsman_tab: Control = $MainContainer/TabContainer/Swordsman
@onready var archer_tab: Control = $MainContainer/TabContainer/Archer
@onready var pyromancer_tab: Control = $MainContainer/TabContainer/Pyromancer

# Current selected tab
var current_tab: String = "True"

# Signals
signal back_to_main_menu()

func _ready() -> void:
	_setup_progression_manager()
	_connect_signals()
	_setup_initial_display()

func _setup_progression_manager() -> void:
	"""Setup connection to the progression manager autoload"""
	# Use the global ProgressionManager autoload
	progression_manager = ProgressionManager
	
	if progression_manager:
		# Connect progression signals
		progression_manager.experience_gained.connect(_on_experience_gained)
		progression_manager.level_gained.connect(_on_level_gained)
		progression_manager.upgrade_purchased.connect(_on_upgrade_purchased)
	
	# Load initial data
	_refresh_current_display()

func _connect_signals() -> void:
	"""Connect UI signals"""
	back_button.pressed.connect(_on_back_button_pressed)
	tab_container.tab_changed.connect(_on_tab_changed)

func _setup_initial_display() -> void:
	"""Setup the initial display for all tabs"""
	_update_true_tab()
	_update_class_tab("Swordsman")
	_update_class_tab("Archer")
	_update_class_tab("Pyromancer")

func _update_true_tab() -> void:
	"""Update the True (roster) tab display"""
	var roster_level: int = progression_manager.get_roster_level()
	var available_points: int = progression_manager.get_available_roster_upgrade_points()
	
	# Update roster level display
	var roster_level_label: Label = true_tab.get_node("VBoxContainer/RosterInfo/RosterLevelLabel")
	roster_level_label.text = "Roster Level: " + str(roster_level)
	
	# Update available points display
	var points_label: Label = true_tab.get_node("VBoxContainer/RosterInfo/AvailablePointsLabel")
	points_label.text = "Available Upgrade Points: " + str(available_points)
	
	# Update class level summaries
	var class_summary: VBoxContainer = true_tab.get_node("VBoxContainer/ClassSummary")
	for i in range(class_summary.get_child_count()):
		var class_node: Control = class_summary.get_child(i)
		if class_node.name in ["SwordsmanSummary", "ArcherSummary", "PyromancerSummary"]:
			var character_class: String = class_node.name.replace("Summary", "")
			_update_class_summary(class_node, character_class)
	
	# Update roster upgrades
	_update_roster_upgrades()

func _update_class_summary(summary_node: Control, character_class: String) -> void:
	"""Update a class summary in the True tab"""
	var level: int = progression_manager.get_class_level(character_class)
	var experience: int = progression_manager.get_class_experience(character_class)
	var next_level_exp: int = progression_manager.get_experience_for_next_level(character_class)
	
	var level_label: Label = summary_node.get_node("HBoxContainer/LevelLabel")
	var exp_label: Label = summary_node.get_node("HBoxContainer/ExpLabel")
	
	level_label.text = character_class + " Level: " + str(level)
	if level < 50:
		exp_label.text = "XP: " + str(experience) + " (+" + str(next_level_exp) + " to next)"
	else:
		exp_label.text = "XP: " + str(experience) + " (MAX LEVEL)"

func _update_roster_upgrades() -> void:
	"""Update the roster upgrades section"""
	var upgrades_container: VBoxContainer = true_tab.get_node("VBoxContainer/ScrollContainer/UpgradesContainer")
	
	# Clear existing upgrade displays
	for child in upgrades_container.get_children():
		child.queue_free()
	
	# Add upgrade displays for each roster upgrade
	var upgrade_defs = load("res://scripts/upgrade_definitions.gd")
	if upgrade_defs:
		var roster_upgrades: Array[Dictionary] = upgrade_defs.get_roster_upgrades()
		for upgrade in roster_upgrades:
			_create_upgrade_display(upgrades_container, "Roster", upgrade)

func _update_class_tab(character_class: String) -> void:
	"""Update a specific class tab"""
	var tab_node: Control = get_node("MainContainer/TabContainer/" + character_class)
	
	# Update class info
	var level: int = progression_manager.get_class_level(character_class)
	var experience: int = progression_manager.get_class_experience(character_class)
	var next_level_exp: int = progression_manager.get_experience_for_next_level(character_class)
	var available_points: int = progression_manager.get_available_upgrade_points(character_class)
	
	var level_label: Label = tab_node.get_node("VBoxContainer/ClassInfo/LevelLabel")
	var exp_label: Label = tab_node.get_node("VBoxContainer/ClassInfo/ExpLabel")
	var points_label: Label = tab_node.get_node("VBoxContainer/ClassInfo/PointsLabel")
	
	level_label.text = character_class + " Level: " + str(level)
	if level < 50:
		exp_label.text = "Experience: " + str(experience) + " (+" + str(next_level_exp) + " to next)"
	else:
		exp_label.text = "Experience: " + str(experience) + " (MAX LEVEL)"
	points_label.text = "Available Upgrade Points: " + str(available_points)
	
	# Update class upgrades
	_update_class_upgrades(character_class)

func _update_class_upgrades(character_class: String) -> void:
	"""Update the upgrade displays for a specific class"""
	var tab_node: Control = get_node("MainContainer/TabContainer/" + character_class)
	var upgrades_container: VBoxContainer = tab_node.get_node("VBoxContainer/ScrollContainer/UpgradesContainer")
	
	# Clear existing upgrade displays
	for child in upgrades_container.get_children():
		child.queue_free()
	
	# Add upgrade displays for each class upgrade
	var upgrade_defs = load("res://scripts/upgrade_definitions.gd")
	if upgrade_defs:
		var class_upgrades: Array[Dictionary] = upgrade_defs.get_class_upgrades(character_class)
		for upgrade in class_upgrades:
			_create_upgrade_display(upgrades_container, character_class, upgrade)

func _create_upgrade_display(parent: VBoxContainer, character_class: String, upgrade: Dictionary) -> void:
	"""Create a display panel for a single upgrade"""
	var upgrade_panel: Panel = Panel.new()
	upgrade_panel.custom_minimum_size = Vector2(600, 80)
	
	var hbox: HBoxContainer = HBoxContainer.new()
	upgrade_panel.add_child(hbox)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	
	# Upgrade info section
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var name_label: Label = Label.new()
	name_label.text = upgrade.name
	name_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(name_label)
	
	var desc_label: Label = Label.new()
	desc_label.text = upgrade.description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_label)
	
	# Progress section
	var progress_vbox: VBoxContainer = VBoxContainer.new()
	progress_vbox.custom_minimum_size = Vector2(150, 0)
	hbox.add_child(progress_vbox)
	
	var current_level: int = progression_manager.get_upgrade_level(character_class, upgrade.id)
	var max_level: int = upgrade.max_level
	
	var level_label: Label = Label.new()
	level_label.text = "Level: " + str(current_level) + "/" + str(max_level)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_vbox.add_child(level_label)
	
	# Upgrade button
	var upgrade_button: Button = Button.new()
	upgrade_button.text = "Upgrade"
	upgrade_button.custom_minimum_size = Vector2(100, 40)
	
	# Check if upgrade can be purchased
	var can_upgrade: bool = current_level < max_level
	var has_points: bool = false
	
	if character_class == "Roster":
		has_points = progression_manager.get_available_roster_upgrade_points() > 0
	else:
		has_points = progression_manager.get_available_upgrade_points(character_class) > 0
	
	upgrade_button.disabled = not (can_upgrade and has_points)
	
	# Connect button signal
	upgrade_button.pressed.connect(_on_upgrade_button_pressed.bind(character_class, upgrade.id))
	hbox.add_child(upgrade_button)
	
	parent.add_child(upgrade_panel)

func _on_upgrade_button_pressed(character_class: String, upgrade_id: String) -> void:
	"""Handle upgrade button press"""
	var success: bool = false
	
	if character_class == "Roster":
		success = progression_manager.purchase_roster_upgrade(upgrade_id)
	else:
		success = progression_manager.purchase_class_upgrade(character_class, upgrade_id)
	
	if success:
		# Refresh the current tab display
		if current_tab == "True":
			_update_true_tab()
		else:
			_update_class_tab(current_tab)

func _on_tab_changed(tab_index: int) -> void:
	"""Handle tab change"""
	var tab_names: Array[String] = ["True", "Swordsman", "Archer", "Pyromancer"]
	if tab_index < tab_names.size():
		current_tab = tab_names[tab_index]

func _on_back_button_pressed() -> void:
	"""Handle back button press"""
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_experience_gained(character_class: String, amount: int) -> void:
	"""Handle experience gained signal"""
	# Refresh displays if needed
	_refresh_current_display()

func _on_level_gained(character_class: String, new_level: int) -> void:
	"""Handle level gained signal"""
	# Refresh displays to show new available points
	_refresh_current_display()

func _on_upgrade_purchased(character_class: String, upgrade_id: String) -> void:
	"""Handle upgrade purchased signal"""
	# Display is already refreshed in _on_upgrade_button_pressed
	pass

func _refresh_current_display() -> void:
	"""Refresh the currently visible tab"""
	if current_tab == "True":
		_update_true_tab()
	else:
		_update_class_tab(current_tab)

# Debug function for testing
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F5:
				# Add test experience to Swordsman
				progression_manager.add_experience("Swordsman", 200)
			KEY_F6:
				# Add test experience to Archer
				progression_manager.add_experience("Archer", 150)
			KEY_F7:
				# Add test experience to Pyromancer
				progression_manager.add_experience("Pyromancer", 180)
			KEY_F8:
				# Reset progression (for testing)
				progression_manager.reset_progression()
				_setup_initial_display() 
