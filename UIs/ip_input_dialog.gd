class_name IPInputDialog
extends AcceptDialog

## Reusable IP input dialog for joining multiplayer games
## Emits ip_confirmed signal when user confirms IP address

signal ip_confirmed(ip_address: String)

@onready var line_edit: LineEdit
@onready var error_label: Label

func _ready() -> void:
	title = "Join Game"
	_setup_dialog()

func _setup_dialog() -> void:
	"""Setup the dialog content"""
	# Create main container
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Instruction label
	var instruction_label = Label.new()
	instruction_label.text = "Enter the host's IP address:"
	vbox.add_child(instruction_label)
	
	# IP input field
	line_edit = LineEdit.new()
	line_edit.placeholder_text = "127.0.0.1"
	line_edit.text = "127.0.0.1"
	line_edit.custom_minimum_size = Vector2(200, 0)
	vbox.add_child(line_edit)
	
	# Error label (initially hidden)
	error_label = Label.new()
	error_label.text = ""
	error_label.modulate = Color.RED
	error_label.visible = false
	vbox.add_child(error_label)
	
	# Connect signals
	confirmed.connect(_on_confirmed)
	line_edit.text_submitted.connect(_on_text_submitted)
	
	# Focus the input field when dialog opens
	call_deferred("_focus_input")

func _focus_input() -> void:
	"""Focus the input field"""
	if line_edit:
		line_edit.grab_focus()

func _on_confirmed() -> void:
	"""Handle dialog confirmation"""
	var ip = line_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	
	if _validate_ip(ip):
		ip_confirmed.emit(ip)
	else:
		_show_error("Invalid IP address format")

func _on_text_submitted(_text: String) -> void:
	"""Handle text submission (Enter key)"""
	_on_confirmed()

func _validate_ip(ip: String) -> bool:
	"""Basic IP address validation"""
	if ip == "localhost":
		return true
	
	var parts = ip.split(".")
	if parts.size() != 4:
		return false
	
	for part in parts:
		if not part.is_valid_int():
			return false
		var num = part.to_int()
		if num < 0 or num > 255:
			return false
	
	return true

func _show_error(message: String) -> void:
	"""Show error message"""
	error_label.text = message
	error_label.visible = true

func reset_dialog() -> void:
	"""Reset dialog to default state"""
	line_edit.text = "127.0.0.1"
	error_label.visible = false 
