# Programmatic Sprite Animation Generation for Godot

This document explains how to programmatically generate complete sprite animations for Godot .tscn files using Python scripts.

## Overview

Instead of manually creating hundreds of AtlasTexture resources and animation definitions, we developed a Python script that automatically generates complete .tscn files with all sprite animations configured.

## Problem Statement

The Knight character required:
- 24 different animations (Idle, Walk, Run, Attack1-5, Die, TakeDamage, etc.)
- 4 directions per animation (BottomRight, BottomLeft, TopLeft, TopRight)
- 15 frames per direction
- **Total: 1440 AtlasTexture definitions + 96 animation definitions**

Creating this manually would be extremely time-consuming and error-prone.

## Solution Architecture

### 1. Pattern Analysis

First, we analyzed the existing sprite animation pattern:

```
Frame Size: 128x128 pixels
Grid Layout: 15 columns × 8 rows (standard sprite sheet layout)
Direction Mapping:
  - Row 2 (Y = 128): BottomRight
  - Row 4 (Y = 384): BottomLeft  
  - Row 6 (Y = 640): TopLeft
  - Row 8 (Y = 896): TopRight
Frame X positions: 0, 128, 256, 384, ..., 1792 (15 frames)
```

### 2. Animation Configuration

```python
animations = [
    # Animation name, ExtResource ID, UID, loop, speed
    ("idle", "3_idle", "uid://dslkwcqu1ais2", False, 15.0),
    ("walk", "4_walk", "uid://bkss27qxad02l", True, 30.0),
    ("run", "5_run", "uid://bvrrxs4m205ql", True, 30.0),
    ("attack1", "6_attack1", "uid://lp3b0aba1nl5", False, 30.0),
    # ... 24 animations total
]
```

### 3. Script Architecture

The generation script (`generate_knight_animations.py`) consists of:

1. **Configuration Data**: Animation definitions with UIDs, loop settings, speeds
2. **Pattern Generation**: Functions to create AtlasTextures and animations
3. **File Assembly**: Combine all parts into valid .tscn format

## Key Implementation Details

### 1. Extracting Real UIDs

Instead of using placeholder UIDs, we extracted actual UIDs from Godot's .import files:

```bash
cd "/path/to/assets/entities/knight/"
for file in *.png.import; do 
    echo "$(basename "$file" .png.import): $(grep 'uid=' "$file" | cut -d'"' -f2)"
done
```

This prevented "invalid UID" warnings in Godot.

### 2. AtlasTexture Generation

```python
def generate_atlas_textures():
    atlas_textures = []
    for anim_name, ext_resource_id, _, _, _ in animations:
        for dir_code, y_offset in directions:
            for frame in range(frames_per_animation):
                x_pos = frame * frame_size
                atlas_texture = f'''[sub_resource type="AtlasTexture" id="AtlasTexture_{anim_name}_{dir_code}_{frame}"]
atlas = ExtResource("{ext_resource_id}")
region = Rect2({x_pos}, {y_offset}, {frame_size}, {frame_size})
'''
                atlas_textures.append(atlas_texture)
    return '\n'.join(atlas_textures)
```

### 3. Animation Definition Generation

```python
def generate_sprite_frames():
    sprite_animations = []
    for anim_name, _, _, loop, speed in animations:
        for dir_code, _ in directions:
            frame_refs = []
            for frame in range(frames_per_animation):
                frame_refs.append(f'SubResource("AtlasTexture_{anim_name}_{dir_code}_{frame}")')
            
            animation_name = anim_name.title() + dir_names[dir_code]
            frames_str = ", ".join(frame_refs)
            
            sprite_animation = '{"frames": [' + frames_str + '],\n"loop": ' + str(loop).lower() + ',\n"name": &"' + animation_name + '",\n"speed": ' + str(speed) + '\n}'
            sprite_animations.append(sprite_animation)
    
    return ',\n'.join(sprite_animations)
```

## Critical Issues and Solutions

### 1. Double Brace Problem

**Issue**: F-strings were creating double braces `{{` instead of single braces `{`

**Solution**: Replaced f-string with string concatenation:
```python
# Wrong (creates double braces)
sprite_animation = f'''{{"{frames_str}"}}'''

# Correct
sprite_animation = '{"frames": [' + frames_str + ']}'
```

### 2. Animation Array Formatting

**Issue**: Parse error "Expected ':'" due to incorrect array formatting

**Solution**: Ensured proper comma separation without extra braces:
```python
# Wrong
return '},\n{'.join(sprite_animations)  # Adds extra braces

# Correct  
return ',\n'.join(sprite_animations)    # Simple comma separation
```

### 3. Load Steps Calculation

**Formula**: `external_resources + atlas_textures + other_sub_resources`
```python
total_atlas_textures = len(animations) * 4 * 15  # 24 * 4 * 15 = 1440
total_load_steps = 26 + total_atlas_textures + 3  # 1469 total
```

## Final Results

The script successfully generated:
- **6300 lines** of valid .tscn content
- **26 external resources** (sprite sheets + other assets)
- **1440 AtlasTexture definitions** (24 animations × 4 directions × 15 frames)
- **96 animation definitions** (24 animations × 4 directions)
- **Zero parse errors** in Godot

## Usage Instructions

1. **Analyze Sprite Pattern**: Determine frame size, grid layout, direction mapping
2. **Extract UIDs**: Get real UIDs from .import files to avoid warnings
3. **Configure Script**: Set up animation data with correct paths and settings
4. **Run Script**: Execute to generate complete .tscn file
5. **Verify**: Test in Godot to ensure no parse errors

## Benefits

- **Time Savings**: Reduced manual work from days to minutes
- **Accuracy**: Eliminated human error in repetitive tasks
- **Consistency**: Ensured uniform naming and formatting
- **Maintainability**: Easy to add new animations or modify existing ones
- **Scalability**: Can generate any number of animations programmatically

## Script Location

The complete generation script is located at:
`/generate_knight_animations.py`

This approach can be adapted for any character with similar sprite sheet layouts by modifying the configuration data and frame specifications.

## Best Practices

1. **Always extract real UIDs** from .import files
2. **Use string concatenation** instead of f-strings for Godot syntax
3. **Test incrementally** with smaller animation sets first
4. **Validate syntax** with simple comma separation
5. **Follow Godot naming conventions** for consistency

This programmatic approach transforms a tedious manual process into an automated, reliable system that can be reused for any character sprite implementation.