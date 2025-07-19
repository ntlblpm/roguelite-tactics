extends PanelContainer
class_name TurnOrderSlot

@onready var viewport_rect: TextureRect = $HBoxContainer/ViewportTextureRect
@onready var name_label: Label = $HBoxContainer/NameLabel
@onready var hp_bar: ProgressBar = $HBoxContainer/HPBarContainer/HPBar
@onready var hp_value_label: Label = $HBoxContainer/HPBarContainer/HPValueLabel
@onready var viewport: SubViewport = $CharacterViewport
@onready var camera: Camera2D = $CharacterViewport/Camera2D

var character_preview: Node2D  # Can be Sprite2D or AnimatedSprite2D

func _ready() -> void:
	# Debug: Check if nodes are found
	if not name_label:
		push_error("TurnOrderSlot: name_label not found!")
	if not hp_bar:
		push_error("TurnOrderSlot: hp_bar not found!")
	if not hp_value_label:
		push_error("TurnOrderSlot: hp_value_label not found!")
	if not viewport_rect:
		push_error("TurnOrderSlot: viewport_rect not found!")
	if not viewport:
		push_error("TurnOrderSlot: viewport not found!")
	if not camera:
		push_error("TurnOrderSlot: camera not found!")
	
	# Configure viewport
	if viewport:
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

var character: BaseCharacter
var is_current_turn: bool = false

func setup(character_ref: BaseCharacter) -> void:
	character = character_ref
	
	if not character or not is_instance_valid(character):
		return
	
	# Ensure nodes are ready
	if not is_node_ready():
		await ready
	
	# Set character type name
	if name_label:
		name_label.text = _get_character_type_name(character)
	
	# Setup viewport texture
	if viewport_rect and viewport:
		viewport_rect.texture = viewport.get_texture()
		viewport_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	# Setup camera to follow character
	_setup_character_camera()
	
	# Connect to health changes
	if character.resources:
		character.resources.health_changed.connect(_on_health_changed)
		_update_hp_display(character.resources.current_health_points, character.resources.max_health_points)

func _get_character_type_name(char: BaseCharacter) -> String:
	# Use the character_type property that exists in BaseCharacter
	return char.character_type

func _setup_character_camera() -> void:
	if not character or not is_instance_valid(character) or not camera or not viewport:
		return
	
	# Create a preview sprite that copies the character's appearance
	if character_preview:
		character_preview.queue_free()
	
	# Find the character's sprite (could be Sprite2D or AnimatedSprite2D)
	var sprite = character.get_node_or_null("AnimatedSprite2D")
	if not sprite:
		sprite = character.get_node_or_null("CharacterSprite")
	if not sprite:
		# Try to find any sprite child
		for child in character.get_children():
			if child is Sprite2D or child is AnimatedSprite2D:
				sprite = child
				break
	
	if sprite:
		if sprite is AnimatedSprite2D:
			# Clone AnimatedSprite2D
			character_preview = AnimatedSprite2D.new()
			character_preview.sprite_frames = sprite.sprite_frames
			character_preview.animation = sprite.animation
			character_preview.frame = sprite.frame
			character_preview.play(sprite.animation)
		elif sprite is Sprite2D:
			# Clone Sprite2D
			character_preview = Sprite2D.new()
			character_preview.texture = sprite.texture
			character_preview.hframes = sprite.hframes
			character_preview.vframes = sprite.vframes
			character_preview.frame = sprite.frame
		
		viewport.add_child(character_preview)
		
		# Center the preview in the viewport
		character_preview.position = Vector2(32, 32)  # Center of 64x64 viewport
		
		# Set camera to center of viewport
		camera.position = Vector2(32, 32)
		camera.zoom = Vector2(1, 1)  # Adjust zoom to fit character
	else:
		push_warning("TurnOrderSlot: Could not find sprite for character " + character.character_type)

func _on_health_changed(current: int, maximum: int) -> void:
	_update_hp_display(current, maximum)

func _update_hp_display(current: int, maximum: int) -> void:
	if hp_bar:
		hp_bar.max_value = maximum
		hp_bar.value = current
		
		# Color code based on health percentage
		var health_percent = float(current) / float(maximum) if maximum > 0 else 0
		if health_percent > 0.6:
			hp_bar.modulate = Color.GREEN
		elif health_percent > 0.3:
			hp_bar.modulate = Color.YELLOW
		else:
			hp_bar.modulate = Color.RED
	
	if hp_value_label:
		hp_value_label.text = "%d/%d" % [current, maximum]

func set_current_turn(is_current: bool) -> void:
	is_current_turn = is_current
	
	if is_current and character:
		# Add a colored border based on character type
		var border_color: Color
		
		if not character.is_ai_controlled():
			# It's a player character - check if it's the local player or another player
			if character.get_multiplayer_authority() == multiplayer.get_unique_id():
				border_color = Color.GREEN  # Local player's turn
			else:
				border_color = Color.BLUE   # Other player's turn
		else:
			border_color = Color.RED  # Enemy turn
		
		# Apply border by adding a stylebox override
		var stylebox = StyleBoxFlat.new()
		stylebox.border_width_left = 3
		stylebox.border_width_right = 3
		stylebox.border_width_top = 3
		stylebox.border_width_bottom = 3
		stylebox.border_color = border_color
		stylebox.bg_color = Color(0.1, 0.1, 0.1, 0.8)  # Dark background
		stylebox.corner_radius_top_left = 4
		stylebox.corner_radius_top_right = 4
		stylebox.corner_radius_bottom_left = 4
		stylebox.corner_radius_bottom_right = 4
		
		add_theme_stylebox_override("panel", stylebox)
	else:
		# Remove border when not current turn
		remove_theme_stylebox_override("panel")

func _process(_delta: float) -> void:
	if character and is_instance_valid(character) and character_preview:
		# Update preview sprite to match character's current animation/frame
		var sprite = character.get_node_or_null("AnimatedSprite2D")
		if not sprite:
			sprite = character.get_node_or_null("CharacterSprite")
		if not sprite:
			for child in character.get_children():
				if child is Sprite2D or child is AnimatedSprite2D:
					sprite = child
					break
		
		if sprite:
			if sprite is AnimatedSprite2D and character_preview is AnimatedSprite2D:
				character_preview.animation = sprite.animation
				character_preview.frame = sprite.frame
				character_preview.flip_h = sprite.flip_h
				character_preview.flip_v = sprite.flip_v
			elif sprite is Sprite2D and character_preview is Sprite2D:
				character_preview.frame = sprite.frame
				character_preview.flip_h = sprite.flip_h
				character_preview.flip_v = sprite.flip_v

func cleanup() -> void:
	if character and is_instance_valid(character) and character.resources:
		if character.resources.health_changed.is_connected(_on_health_changed):
			character.resources.health_changed.disconnect(_on_health_changed)
	
	if character_preview and is_instance_valid(character_preview):
		character_preview.queue_free()
		character_preview = null
