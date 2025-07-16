# LLM Guide: Godot Sprite Sheet Animation Implementation

## Overview
This guide provides step-by-step instructions for implementing proper sprite sheet animations in Godot `.tscn` files, specifically for multi-directional character animations.

⚠️ **IMPORTANT:** Godot .tscn files do NOT support comments. Never add // or /* */ comments to .tscn files.

## Key Requirements

### Scene File Structure
```
[gd_scene load_steps=N format=3 uid="uid://..."]

[ext_resource type="Texture2D" ...]
[sub_resource type="AtlasTexture" ...]
[sub_resource type="SpriteFrames" ...]

[node name="Character" type="Node2D"]
[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
```

### Sprite Sheet Specifications
- **Frame Size**: Varies (64x64 for knight, 128x128 for skeleton)
- **Grid Layout**: 15 columns × 8 rows (standard)
- **Directional Mapping**:
  - Row 2 (Y = frame_height * 1): BottomRight
  - Row 4 (Y = frame_height * 3): BottomLeft  
  - Row 6 (Y = frame_height * 5): TopLeft
  - Row 8 (Y = frame_height * 7): TopRight

## Implementation Steps

### 1. Calculate Load Steps
```
Total = external_resources + atlas_textures + 1
external_resources = number of sprite sheets (e.g., 24)
atlas_textures = sprite_sheets × directions × frames_per_direction
Example: 24 sheets × 4 directions × 15 frames = 1440 + 24 + 1 = 1465
```

### 2. External Resources
```gdscript
[ext_resource type="Texture2D" uid="uid://..." path="res://path/to/spritesheet.png" id="N_id"]
```

### 3. AtlasTexture Pattern
For each animation frame, create an AtlasTexture:
```gdscript
[sub_resource type="AtlasTexture" id="AtlasTexture_{animation}_{direction}_{frame}"]
atlas = ExtResource("{id}")
region = Rect2({x}, {y}, {frame_width}, {frame_height})
```

**Frame Position Calculation:**
- X = frame_number × frame_width (0, 128, 256, 384, ...)
- Y = row_number × frame_height (128, 384, 640, 896 for 128px frames)

**Direction Mapping Examples (128x128 frames):**
- BottomRight: Y = 128, frames 0-14
- BottomLeft: Y = 384, frames 0-14  
- TopLeft: Y = 640, frames 0-14
- TopRight: Y = 896, frames 0-14

### 4. Animation Definitions
```gdscript
[sub_resource type="SpriteFrames" id="SpriteFrames_1"]
animations = [{
"frames": [SubResource("AtlasTexture_walk_br_0"), SubResource("AtlasTexture_walk_br_1"), ...],
"loop": true,
"name": &"WalkBottomRight",
"speed": 30.0
}, {
"frames": [SubResource("AtlasTexture_walk_bl_0"), SubResource("AtlasTexture_walk_bl_1"), ...],
"loop": true,
"name": &"WalkBottomLeft", 
"speed": 30.0
}, {
"frames": [SubResource("AtlasTexture_attack1_br_0"), SubResource("AtlasTexture_attack1_br_1"), ...],
"loop": false,
"name": &"Attack1BottomRight",
"speed": 30.0
}, {
"frames": [SubResource("AtlasTexture_idle_br_0"), SubResource("AtlasTexture_idle_br_1"), ...],
"loop": false,
"name": &"IdleBottomRight",
"speed": 15.0
}]
```

## Complete Example (Attack1 Animation, 128x128 frames)

### AtlasTextures (BottomRight Direction)
```gdscript
[sub_resource type="AtlasTexture" id="AtlasTexture_attack1_br_0"]
atlas = ExtResource("1_1mvjd")
region = Rect2(0, 128, 128, 128)

[sub_resource type="AtlasTexture" id="AtlasTexture_attack1_br_1"] 
atlas = ExtResource("1_1mvjd")
region = Rect2(128, 128, 128, 128)

[sub_resource type="AtlasTexture" id="AtlasTexture_attack1_br_2"]
atlas = ExtResource("1_1mvjd") 
region = Rect2(256, 128, 128, 128)

[sub_resource type="AtlasTexture" id="AtlasTexture_attack1_br_3"]
atlas = ExtResource("1_1mvjd") 
region = Rect2(384, 128, 128, 128)
```

### Animation Definition
```gdscript
{
"frames": [SubResource("AtlasTexture_attack1_br_0"), SubResource("AtlasTexture_attack1_br_1"), SubResource("AtlasTexture_attack1_br_2"), ...],
"loop": true,
"name": &"Attack1BottomRight",
"speed": 30.0
}
```

## Naming Conventions

### AtlasTexture IDs
Pattern: `AtlasTexture_{animation}_{direction}_{frame}`
- animation: walk, attack1, idle, etc.
- direction: br (BottomRight), bl (BottomLeft), tl (TopLeft), tr (TopRight)  
- frame: 0-14 (15 frames total)

### Animation Names
Pattern: `{Animation}{Direction}`
- Examples: WalkBottomRight, Attack1TopLeft, IdleBottomRight

## Common Settings

### Animation Speed
- **30 FPS**: Standard speed for most animations (walk, run, attacks, etc.)
- **15 FPS**: Slower speed for idle animations

### Loop Settings
- **true**: Run and walk animations only
- **false**: All other animations (idle, attacks, die, take_damage, etc.)

## Critical Pitfalls to Avoid

### 1. Scene Format Errors
❌ **NEVER use `preload()` in .tscn files**
```gdscript
// WRONG
"texture": preload("res://path/to/texture.png")

// CORRECT  
"texture": ExtResource("id")
```

### 2. Comment Usage Errors
❌ **NEVER add comments to .tscn files**
```gdscript
// WRONG - This will cause parse errors
// Idle BottomRight frames (0-14)
[sub_resource type="AtlasTexture" id="AtlasTexture_idle_br_0"]

// CORRECT - No comments in .tscn files
[sub_resource type="AtlasTexture" id="AtlasTexture_idle_br_0"]
```

**⚠️ CRITICAL:** Godot scene files (.tscn) do not support any form of comments (// or /* */). Adding comments will cause "Parse Error: Unexpected end of file" or similar parsing failures.

**📝 Documentation Alternative:** Use descriptive ID names for AtlasTextures (e.g., `AtlasTexture_attack1_br_0`) instead of comments to maintain readability.

### 3. Frame Position Errors
- Ensure X/Y calculations match sprite sheet layout
- Verify frame_width and frame_height are correct
- Check row mapping (row 2 = Y of frame_height × 1, not × 2)

### 4. Resource Reference Errors
- All ExtResource IDs must be unique
- AtlasTexture IDs must be unique  
- SubResource references must match exact IDs

## Validation Checklist

- [ ] Load steps count matches total resources
- [ ] All external resources have unique IDs
- [ ] AtlasTexture regions don't exceed sprite sheet bounds
- [ ] Animation frame arrays reference correct AtlasTextures
- [ ] Animation names follow naming convention
- [ ] Default animation exists and is valid
- [ ] No preload() functions in .tscn file
- [ ] **No comments (// or /* */) anywhere in .tscn file**

## Frame Size Reference

| Character Type | Frame Size | Row Y Values |
|---------------|------------|--------------|
| Knight | 64x64 | 64, 192, 320, 448 |
| Skeleton | 128x128 | 128, 384, 640, 896 |
| Custom | WxH | H×1, H×3, H×5, H×7 |

## Performance Notes

- Each sprite sheet creates 60 AtlasTextures (15 frames × 4 directions)
- 24 animations = 1440 AtlasTextures total
- This is normal and expected for full character animation sets
- Godot handles this efficiently at runtime 