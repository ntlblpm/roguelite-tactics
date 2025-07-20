extends PanelContainer
class_name TurnOrderSlot

@onready var viewport_rect: TextureRect = $VBoxContainer/ViewportTextureRect
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var hp_bar: ProgressBar = $VBoxContainer/HPContainer/HPBar
@onready var hp_value_label: Label = $VBoxContainer/HPContainer/HPLabel
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
		# Color based on player vs enemy
		if character.is_ai_controlled():
			name_label.modulate = Color.RED
		else:
			name_label.modulate = Color.GREEN
	
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
	
	# Set initial border and name style
	_update_border()
	_update_name_style()

func _get_character_type_name(char: BaseCharacter) -> String:
	# Use the character_type property that exists in BaseCharacter
	var raw_name = char.character_type
	
	# Format the name by adding spaces between camelCase words
	var formatted_name = ""
	for i in range(raw_name.length()):
		var char_at = raw_name[i]
		# Add space before uppercase letters (except first character)
		if i > 0 and char_at == char_at.to_upper() and char_at != "_":
			formatted_name += " "
		formatted_name += char_at
	
	# Handle special cases like "AI" or consecutive capitals
	formatted_name = formatted_name.replace("A I", "AI")
	
	return formatted_name

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
		
		# Center the preview in the viewport, shifted down by 5px
		character_preview.position = Vector2(32, 29)  # Center X, shifted down 5px
		
		# Set camera to center of viewport, following the character position
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
	_update_border()
	_update_name_style()

func _update_border() -> void:
	if not character:
		return
	
	# Create and apply stylebox
	var stylebox = StyleBoxFlat.new()
	
	# Always have 1px white border, 2px for current turn
	if is_current_turn:
		stylebox.border_width_left = 2
		stylebox.border_width_right = 2
		stylebox.border_width_top = 2
		stylebox.border_width_bottom = 2
	else:
		# 1px border when not current turn
		stylebox.border_width_left = 1
		stylebox.border_width_right = 1
		stylebox.border_width_top = 1
		stylebox.border_width_bottom = 1
	
	# White border for all
	stylebox.border_color = Color.WHITE
	stylebox.bg_color = Color(0.1, 0.1, 0.1, 0.8)  # Dark background
	stylebox.corner_radius_top_left = 4
	stylebox.corner_radius_top_right = 4
	stylebox.corner_radius_bottom_left = 4
	stylebox.corner_radius_bottom_right = 4
	
	add_theme_stylebox_override("panel", stylebox)

func _update_name_style() -> void:
	if not name_label:
		return
	
	# Create a font variation for bold text
	if is_current_turn:
		var font = name_label.get_theme_font("font")
		if font:
			var font_variation = FontVariation.new()
			font_variation.base_font = font
			font_variation.variation_embolden = 0.5  # Make text bold
			name_label.add_theme_font_override("font", font_variation)
	else:
		# Remove font override to return to normal weight
		name_label.remove_theme_font_override("font")

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
