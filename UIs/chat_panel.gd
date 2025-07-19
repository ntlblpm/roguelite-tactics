class_name ChatPanel
extends Panel

## Chat panel for displaying and sending messages in the game
## Handles message display, input processing, and potential multiplayer communication

@onready var chat_display: RichTextLabel = $ChatContainer/ChatDisplay
@onready var chat_input: LineEdit = $ChatContainer/ChatInput

# Signal emitted when a message is sent (useful for multiplayer)
signal message_sent(message: String, sender: String)

# Maximum number of messages to keep in chat history
const MAX_MESSAGES: int = 100
var message_history: Array[String] = []

func _ready() -> void:
	# Connect signals
	chat_input.text_submitted.connect(_on_message_submitted)
	chat_input.focus_entered.connect(_on_focus_entered)
	chat_input.focus_exited.connect(_on_focus_exited)
	
	# Set initial visual state
	chat_input.modulate = Color(0.8, 0.8, 0.8, 0.8)
	chat_input.placeholder_text = "Press Enter to chat..."
	
	# Add initial system message
	add_system_message("Press Enter to type a message")
	
	# Don't auto-focus on start

func _on_message_submitted(message_text: String) -> void:
	"""Handle when user submits a message by pressing Enter"""
	if message_text.strip_edges().is_empty():
		return
	
	# Add the message to display
	add_message("Player", message_text)
	
	# Emit signal for multiplayer or other systems
	message_sent.emit(message_text, "Player")
	
	# Clear input and release focus
	chat_input.clear()
	chat_input.release_focus()

func add_message(sender: String, message: String) -> void:
	"""Add a regular chat message from a player"""
	var formatted_message: String = "[color=white][b]%s:[/b] %s[/color]" % [sender, message]
	_append_to_display(formatted_message)

func add_system_message(message: String) -> void:
	"""Add a system message (gray colored)"""
	var formatted_message: String = "[color=gray][i]%s[/i][/color]" % message
	_append_to_display(formatted_message)

func add_combat_message(message: String) -> void:
	"""Add a combat-related message (yellow colored)"""
	var formatted_message: String = "[color=yellow]%s[/color]" % message
	_append_to_display(formatted_message)

func add_error_message(message: String) -> void:
	"""Add an error message (red colored)"""
	var formatted_message: String = "[color=red][b]Error:[/b] %s[/color]" % message
	_append_to_display(formatted_message)

func _append_to_display(formatted_message: String) -> void:
	"""Internal method to append message to display and manage history"""
	# Add to history
	message_history.append(formatted_message)
	
	# Trim history if too long
	if message_history.size() > MAX_MESSAGES:
		message_history = message_history.slice(message_history.size() - MAX_MESSAGES)
	
	# Update display
	chat_display.text = "\n".join(message_history)

func clear_chat() -> void:
	"""Clear all messages from the chat"""
	message_history.clear()
	chat_display.text = ""

func toggle_visibility() -> void:
	"""Toggle chat panel visibility"""
	visible = !visible
	if visible:
		chat_input.grab_focus()

func _on_focus_entered() -> void:
	"""Handle when chat input gains focus"""
	# Visual feedback that chat is active
	chat_input.modulate = Color(1.0, 1.0, 1.0, 1.0)
	add_system_message("Chat active - press Escape to exit")

func _on_focus_exited() -> void:
	"""Handle when chat input loses focus"""
	# Visual feedback that chat is inactive
	chat_input.modulate = Color(0.8, 0.8, 0.8, 0.8)
	# Clear any partial input
	if not chat_input.text.is_empty():
		chat_input.clear()

func is_chat_focused() -> bool:
	"""Check if chat input is currently focused"""
	return chat_input and chat_input.has_focus()

# Method to receive messages from other players (for multiplayer)
func receive_message(sender: String, message: String) -> void:
	"""Receive a message from another player (multiplayer)"""
	add_message(sender, message) 
