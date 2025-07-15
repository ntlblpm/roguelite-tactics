# Cursor Tactics - Game Design Document

## Game Overview

**Genre**: Multiplayer Isometric Roguelike Tactics  
**Platform**: Desktop Only  
**Players**: 1-4 Players  
**Session Length**: ~2 hours per run  
**Art Style**: Placeholder assets initially  

## Core Concept

A tactical combat game where 1-4 players cooperatively navigate procedurally generated encounters, managing AP/MP resources in turn-based combat similar to Dofus. Players have persistent progression through class levels and roster levels, while individual runs feature separate character progression and equipment discovery.

## Multiplayer Architecture

- **Networking**: Peer-to-peer with one player hosting
- **Connection**: Direct player-to-player connections
- **Lobby System**: Basic lobby for players to find and join each other
- **Save Data**: Local-only, no central server
- **Save Synchronization**: No restrictions on mixed progression levels

## Progression Systems

### Persistent Progression (Saved Locally)

#### Class Levels
- Individual levels for each of the 4 classes: Swordsman, Archer, Wizard, Cleric
- Each class level provides points for class-specific upgrade trees
- Class trees only apply when playing that specific class
- Focus on numerical bonuses (damage, health, AP/MP, etc.)

#### Roster Level
- Sum of all class levels combined
- Provides points for roster-wide upgrade trees
- Roster trees apply to all classes
- Universal bonuses that benefit any character

#### Equipment System (Persistent)
- **Equipment Slots**: 13 total per class
  - 1 Weapon
  - 1 Armor
  - 10 Rings
  - 1 Amulet
- **Equipment Sources**:
  - **Drops**: Normal enemies have low chance, bosses always drop equipment
  - **Shop**: Rotating inventory with shop-exclusive items
- **Loot Distribution**: Each player receives class-appropriate equipment from enemy kills
- **Rarity System**: Multiple equipment tiers (common, rare, epic, etc.) with varying drop rates and stats
- **Loadout Management**: 
  - Multiple loadout presets per class
  - Equipment selection between runs only (no mid-run switching)
- **Currency**: Gold earned during runs and from selling equipment
- **Storage**: No inventory limits currently planned

### Run-Based Progression

#### Character Level
- Starts from 1 at the beginning of each run
- Gained through combat encounters
- Provides skill tree advancement points
- Determines available abilities and powers
- Completely separate from persistent levels

#### Gold Currency
- Earned during combat encounters
- Found from defeating enemies and bosses
- Used for purchasing equipment from shop
- Gained from selling unwanted equipment

## Combat System

### Core Mechanics
- **Turn Order**: Based on initiative stat
- **Action Points (AP)**: Base 6 per turn, used for abilities
- **Movement Points (MP)**: Base 3 per turn, used for movement
- **Movement**: Diamond grid-based, 1 MP = 1 tile (4-directional: top-left, top-right, bottom-left, bottom-right)
- **Modifiers**: AP/MP can be modified by levels, abilities, equipment, buffs/debuffs

### Grid-Based Combat
- **Movement System**: 4-directional movement on diamond grid (top-left, top-right, bottom-left, bottom-right)
- **Range Calculation**: Distance measured along grid paths, not Euclidean distance
- **Line of Sight**: Calculated using diamond grid tile blocking rules
- **Area Effects**: Spells affect tiles in patterns (cross, diagonal, square, etc.)
- **Positioning**: Strategic placement crucial due to limited movement and LOS mechanics

### Combat Flow
1. Initiative determines turn order
2. On player turn: spend AP for abilities, MP for movement
3. Movement and abilities must follow diamond grid constraints
4. Turn ends when player chooses or no more actions possible
5. Continue until all enemies defeated or party dies

## Classes (Initial 4)

### Swordsman
- **Role**: Melee DPS/Tank hybrid
- **Characteristics**: High health, close-range abilities
- **Playstyle**: Front-line combatant with defensive options

### Archer
- **Role**: Ranged Physical DPS
- **Characteristics**: High damage from distance, lower health
- **Playstyle**: Positioning-focused, precision strikes

### Wizard
- **Role**: Magical DPS/Area Control
- **Characteristics**: Elemental abilities, area effects
- **Playstyle**: Spell combinations, battlefield control

### Cleric
- **Role**: Support/Healer
- **Characteristics**: Healing abilities, buffs, some defensive magic
- **Playstyle**: Team support, resource management

## Grid System & Level Design

### Diamond Grid Layout (Dofus-Inspired)
- **Base Dimensions**: 20 tiles wide × 28 tiles tall rectangular container
- **Playable Area**: Diamond/rhombus shape within the rectangular grid
- **Total Playable Tiles**: ~560 tiles (varies slightly by room generation)
- **Diamond Characteristics**:
  - Top and bottom rows: Fewer accessible tiles (tapered edges)
  - Middle rows: Maximum width (full 20 tiles)
  - Diagonal edge cutoffs: Creates characteristic diamond battlefield shape

### Grid Mechanics
- **Movement**: Along diamond grid directions (top-left, top-right, bottom-left, bottom-right)
- **Targeting**: Spell and ability targeting follows grid diagonal patterns
- **Line of Sight (LOS)**: Calculated based on diamond tile arrangement
- **Coordinate System**: Isometric coordinate mapping for diamond layout
- **Tile Types**:
  - **Walkable**: Standard movement tiles
  - **Blocked**: Obstacles, walls, impassable terrain
  - **Special**: Interactive tiles (switches, traps, etc.)

### Room Structure
- **Camera**: Fixed isometric view optimized for diamond grid visibility
- **Size**: All rooms fit within the same camera position/angle/zoom
- **Grid Consistency**: Every encounter uses the same 20×28 diamond grid layout
- **Generation**: Completely new layouts between encounters
- **Implementation**: Replace entire room scene between encounters

### Encounter Types
- **Regular Combat**: Standard enemy encounters on diamond grid
- **Elite Encounters**: Stronger enemies with better rewards
- **Final Boss**: Single boss encounter that ends the run

## Equipment & Shop System

### Equipment Mechanics
- **Equipment Slots Per Class**: 13 total (1 weapon, 1 armor, 10 rings, 1 amulet)
- **Class Specificity**: All equipment is class-locked
- **Rarity Tiers**: Common, Rare, Epic (expandable system)
- **Stat Bonuses**: Equipment provides numerical improvements to combat stats
- **Drop Rates**: 
  - Normal enemies: Low chance of equipment drops
  - Bosses: Guaranteed equipment drops
- **Loot Distribution**: Each party member receives class-appropriate equipment

### Shop System
- **Currency**: Gold (earned in runs, from selling equipment)
- **Inventory**: Rotating selection of equipment for all classes
- **Shop Exclusives**: Certain high-tier items only available for purchase
- **Buy/Sell**: Players can purchase new equipment and sell unwanted items
- **Refresh Mechanism**: Shop inventory rotates periodically

### Loadout Management
- **Multiple Presets**: Players can save multiple equipment configurations per class
- **Pre-Run Setup**: Equipment must be selected before starting a run
- **No Mid-Run Changes**: Equipment cannot be swapped during active runs
- **Quick Selection**: Easy switching between saved loadout presets

## Run Structure

### Run Flow
1. **Class Selection**: Each player chooses their class
2. **Loadout Selection**: Players choose their equipment loadout
3. **Character Building**: Players start at character level 1
4. **Encounter Progression**: Navigate through generated encounters
5. **Equipment Discovery**: Find class-appropriate equipment during run
6. **Final Boss**: Culminating encounter
7. **Run End**: Success (boss defeated) or failure (party death)

### End Conditions
- **Success**: Final boss defeated
- **Failure**: Entire party dies
- **Dropout**: Players can leave but cannot rejoin

### Rewards
- **Gold**: Currency for shop purchases
- **Equipment**: Permanent additions to equipment collection
- **Persistent XP**: Class and roster experience regardless of run outcome
- **Bonus Rewards**: Additional progression for successful runs

## Technical Implementation Priority

### Phase 1: Core Mechanics
- Diamond grid system implementation (20×28 with diamond playable area)
- Isometric coordinate mapping and tile management
- 4-directional movement system with diamond grid constraints
- Turn-based combat framework
- AP/MP resource management
- Line of Sight calculation system
- Single-player combat prototype

### Phase 2: Character Systems
- Class implementation (4 initial classes)
- Character level progression and skill trees
- Basic ability system
- Equipment slot system (13 slots per class)

### Phase 3: Persistent Progression
- Save data system (local storage)
- Class level tracking
- Roster level calculation
- Upgrade tree implementation
- Equipment inventory and persistence
- Gold currency system
- Equipment loadout management

### Phase 3.5: Equipment & Shop
- Equipment drop system with rarity tiers
- Shop system with rotating inventory
- Buy/sell equipment functionality
- Loadout preset management
- Equipment stat application to characters

### Phase 4: Multiplayer Integration
- P2P networking implementation
- Host/client architecture
- Lobby system
- Synchronized combat state

### Phase 5: Content Generation
- Procedural room generation
- Enemy spawning system
- Encounter balance and variety
- Final boss implementation

### Phase 6: Polish & Expansion
- UI/UX improvements
- Additional classes (expansion)
- Content balancing
- Performance optimization

## Technical Considerations

### Godot 4.4 Specific
- Use MultiplayerSpawner for networked entities
- Implement proper RPC calls for turn synchronization
- Use MultiplayerAPI for P2P networking
- Scene-based room replacement system

### Diamond Grid Implementation
- **Coordinate System**: Convert between world coordinates and diamond grid coordinates
- **Grid Representation**: 2D array with boolean flags for walkable/blocked tiles
- **Isometric Rendering**: Use Godot's isometric projection for proper visual alignment
- **Tile Mapping**: Map rectangular array indices to diamond shape accessibility
- **Movement Validation**: Check grid boundaries and tile accessibility for movement
- **Pathfinding**: Implement A* or similar algorithm respecting diamond grid constraints
- **LOS Algorithm**: Ray-casting or Bresenham-style algorithm adapted for diamond grid
- **Visual Feedback**: Highlight valid movement tiles and ability ranges during player turns

### Save Data Structure
```
PlayerSave {
  class_levels: {
    swordsman: int,
    archer: int,
    wizard: int,
    cleric: int
  },
  roster_level: int,
  upgrade_trees: {
    class_upgrades: {...},
    roster_upgrades: {...}
  },
  gold: int,
  equipment: {
    swordsman: {
      inventory: [Equipment],
      loadouts: {
        "loadout_1": {equipment_slots},
        "loadout_2": {equipment_slots},
        ...
      }
    },
    archer: {...},
    wizard: {...},
    cleric: {...}
  }
}
```

### Performance Targets
- Smooth 60 FPS during combat
- Minimal latency for multiplayer actions
- Quick room generation/loading times
- Efficient memory usage for long sessions

## Future Expansion Plans

- Additional classes beyond initial 4
- New encounter types and mechanics
- Extended upgrade tree options
- Quality of life improvements
- Potential mobile platform consideration 