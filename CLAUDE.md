# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Communication Guidelines

- Always let me know what my second best suggestion would have been
- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files over creating new ones
- NEVER proactively create documentation unless explicitly requested
- NEVER implement more simple solution for sole purpose of passing a build

# Roguelite Tactics - Multiplayer Tactical RPG

## Project Architecture

This is a multiplayer isometric tactical RPG built in Godot 4.4 featuring peer-to-peer networking, turn-based combat, and persistent character progression. Supports 1-4 players in cooperative gameplay.

### Core Systems

#### Game Controller (`scripts/game_controller.gd`)
- Central coordinator managing all game systems (1008 lines)
- Handles character spawning, multiplayer synchronization, UI coordination
- Host spawns all entities, clients receive state updates
- Entry point for most game logic

#### Turn Management (`scripts/turn_manager.gd`)
- Initiative-based turn order system with host authority
- Manages MP/AP refresh, turn transitions, AI integration
- Critical for multiplayer synchronization

#### Character System (`scripts/base_character.gd`)
- Base class for all characters (players + enemies) - 435 lines
- Grid-based movement with pathfinding and animation
- RPC-based movement synchronization
- Core stats: HP, MP (movement points), AP (ability points), Initiative

#### Grid System (`scripts/grid_manager.gd`)
- Diamond-shaped battlefield (20x20) with isometric coordinates
- Flood-fill pathfinding algorithm for movement validation
- Visual feedback for movement ranges and path previews

#### Networking (`scripts/network_manager.gd`)
- Peer-to-peer ENet backend with host authority
- PlayerInfo synchronization across clients
- Autoload singleton for global network state

#### Progression System (`scripts/progression_manager.gd`)
- Persistent character advancement with JSON save files
- Class levels, roster levels, upgrade trees
- Experience system with exponential scaling

### Key Entry Points

1. **Main Menu** (`scenes/MainMenu.tscn`) - Game launcher
2. **Lobby** (`scenes/Lobby.tscn`) - Multiplayer lobby for class selection  
3. **Combat** (`scenes/CombatArea.tscn`) - Main battlefield gameplay
4. **Sanctum** (`scenes/Sanctum.tscn`) - Character progression interface

### Multiplayer Authority Model

- **Host (Peer ID 1)**: Controls all game state, spawns characters, manages turns, handles AI
- **Clients (Peer 2+)**: Receive state updates, control only their own character
- **RPC Patterns**: Movement, turn management, combat actions synchronized via RPCs

### Character Classes

Available player classes:
- **SwordsmanCharacter**: Melee fighter with close combat abilities
- **ArcherCharacter**: Ranged attacker with bow skills
- **PyromancerCharacter**: Magic user with fire spells

Enemy types:
- **SkeletonEnemy**: Basic AI enemy with pathfinding and attack behavior

### AI System

- **BaseEnemy** provides core AI behavior
- Turn-integrated AI with target selection and pathfinding
- Seamless integration with turn manager and multiplayer

## Development Workflow

### Running the Game
- Open project in Godot 4.4
- Run MainMenu scene to start
- Host creates game, clients join via IP
- No external build tools required

### Key Development Patterns

#### Multiplayer Considerations
- Always check `is_multiplayer_authority()` before state changes
- Use `@rpc("call_local", "any_peer", "reliable")` for synchronized actions
- Host handles spawning, clients receive spawn commands
- Turn management must be host-authoritative

#### Turn-Based Logic
- Check `turn_manager.is_local_player_turn()` before allowing player actions
- Verify `turn_manager.is_character_turn_active()` for turn state
- Use `current_turn_character.is_ai_controlled()` to distinguish AI vs player turns

#### Grid Movement
- Convert between world coordinates and grid positions via `grid_manager`
- Use `highlight_movement_range()` for visual feedback
- Validate movement with pathfinding before executing

### Architecture Considerations

#### Current Technical Debt
- **Monolithic classes**: BaseCharacter (435 lines), GameController (1008 lines)
- **Tight coupling**: Direct references between systems
- **Mixed concerns**: UI logic mixed with game logic in GameController

## Godot 4.4 Development Guidelines

### Core Development Guidelines

- Use strict typing in GDScript for better error detection and IDE support
- Implement _ready() and other lifecycle functions with explicit super() calls
- Use @onready annotations instead of direct node references in _ready()
- Prefer composition over inheritance where possible
- Use signals for loose coupling between nodes
- Follow Godot's node naming conventions (PascalCase for nodes, snake_case for methods)

### Code Style

- Use type hints for all variables and function parameters
- Document complex functions with docstrings
- Keep methods focused and under 30 lines when possible
- Use meaningful variable and function names
- Group related properties and methods together

### Naming Conventions

- Files: Use snake_case for all filenames (e.g., player_character.gd, main_menu.tscn)
- Classes: Use PascalCase for custom class names with class_name (e.g., PlayerCharacter)
- Variables: Use snake_case for all variables including member variables (e.g., health_points)
- Constants: Use ALL_CAPS_SNAKE_CASE for constants (e.g., MAX_HEALTH)
- Functions: Use snake_case for all functions including lifecycle functions (e.g., move_player())
- Enums: Use PascalCase for enum type names and ALL_CAPS_SNAKE_CASE for enum values
- Nodes: Use PascalCase for node names in the scene tree (e.g., PlayerCharacter, MainCamera)
- Signals: Use snake_case in past tense to name events (e.g., health_depleted, enemy_defeated)

### Scene Organization

- Keep scene tree depth minimal for better performance
- Use scene inheritance for reusable components
- Implement proper scene cleanup on queue_free()
- Use SubViewport nodes carefully due to performance impact
- Provide step-by-step instructions to create Godot scene(s) instead of providing scene source code

### Signal Best Practices

- Use clear, contextual signal names that describe their purpose (e.g., player_health_changed)
- Utilize typed signals to improve safety and IDE assistance (e.g., signal item_collected(item_name: String))
- Connect signals in code for dynamic nodes, and in the editor for static relationships
- Avoid overusing signals - reserve them for important events, not frequent updates
- Pass only necessary data through signal arguments, avoiding entire node references when possible
- Use an autoload "EventBus" singleton for global signals that need to reach distant nodes
- Minimize signal bubbling through multiple parent nodes
- Always disconnect signals when nodes are freed to prevent memory leaks
- Document signals with comments explaining their purpose and parameters

### Resource Management

- Implement proper resource cleanup in _exit_tree()
- Use preload() for essential resources, load() for optional ones
- Consider PackedByteArray storage impact on backwards compatibility
- Implement resource unloading for unused assets

### Performance Best Practices

- Use node groups judiciously for managing collections, and prefer direct node references for frequent, specific access to individual nodes.
- Implement object pooling for frequently spawned objects
- Use physics layers to optimize collision detection
- Prefer packed arrays (PackedVector2Array, etc.) over regular arrays

### Error Handling

- Implement graceful fallbacks for missing resources
- Use assert() for development-time error checking
- Log errors appropriately in production builds
- Handle network errors gracefully in multiplayer games

### TileMap Implementation

- TileMap node is deprecated - use multiple TileMapLayer nodes instead
- Convert existing TileMaps using the TileMap bottom panel toolbox option "Extract TileMap layers"
- Access TileMap layers through TileMapLayer nodes
- Update navigation code to use TileMapLayer.get_navigation_map()
- Store layer-specific properties on individual TileMapLayer nodes

## Common Development Tasks

When working on character behavior:
1. Check if changes affect multiplayer synchronization
2. Verify turn-based logic with AI vs player character handling
3. Test movement validation and grid positioning
4. Ensure proper cleanup in _exit_tree()

When adding new features:
1. Consider host/client authority model
2. Use existing signal patterns for communication
3. Follow existing RPC patterns for multiplayer sync
4. Test with multiple clients

## Project Structure Notes

- **Autoload Singletons**: NetworkManager, ProgressionManager
- **Scene Organization**: Each major system has dedicated scenes
- **Resource Management**: JSON saves in user data directory
- **Error Handling**: Comprehensive error handling for network issues

## Recent Changes

The codebase shows active development with recent improvements to:
- Skeleton enemy turn behavior
- Action/ability points system
- Turn manager AI integration
- Movement highlight system for AI vs player differentiation