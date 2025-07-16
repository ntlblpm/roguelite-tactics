# Sanctum System Implementation Summary

## Overview

The Sanctum system provides a comprehensive character progression and upgrade management interface for the roguelite tactics game. Players can view their roster progress, individual class levels, and spend upgrade points on various enhancements.

## Implemented Components

### 1. Progression Manager (`scripts/progression_manager.gd`)
- **Functionality**: Core progression data management and persistence
- **Features**:
  - Tracks class levels (Swordsman, Archer, Pyromancer) with max level 50
  - Manages experience points with exponential scaling
  - Handles upgrade point allocation and spending
  - Calculates roster level (sum of all class levels)
  - JSON-based save/load system using `user://progression_save.json`
  - Automatic level-up detection and upgrade point granting

### 2. Upgrade Definitions (`scripts/upgrade_definitions.gd`)
- **Functionality**: Defines all available upgrades for classes and roster
- **Features**:
  - **Roster Upgrades** (6 types): Apply to all classes
    - Health Mastery, Action Efficiency, Mobility Training
    - Combat Veteran, Tactical Awareness, Experience Gain
  - **Class-Specific Upgrades** (8 per class): Specialized bonuses
    - **Swordsman**: Melee combat, armor, defense focus
    - **Archer**: Ranged combat, mobility, precision focus  
    - **Pyromancer**: Magic damage, spell efficiency, elemental focus
  - Configurable max levels and stat bonuses per upgrade

### 3. Sanctum UI (`scripts/sanctum_ui.gd`)
- **Functionality**: Main interface for progression management
- **Features**:
  - **Tabbed Interface**: "True" (roster) + individual class tabs
  - **True Tab**: Shows roster level, all class summaries, roster upgrades
  - **Class Tabs**: Individual class progression, available points, class upgrades
  - **Dynamic Upgrade Displays**: Shows current level, max level, upgrade buttons
  - **Real-time Updates**: Reflects changes immediately after purchases

### 4. Experience System (`scripts/experience_system.gd`)
- **Functionality**: Awards experience based on combat completion
- **Features**:
  - **Enemy Types**: Basic (25 XP), Elite (50 XP), Boss (100 XP)
  - **Boss Bonus**: Bosses award double experience as specified
  - **Fight Integration**: Can be called from combat systems
  - **Class Selection**: Supports different participating classes
  - **Flexible Integration**: Works with existing or new combat systems

### 5. Sanctum Scene (`scenes/Sanctum.tscn`)
- **Functionality**: Complete UI layout with proper navigation
- **Features**:
  - **Navigation**: Back button returns to main menu
  - **Responsive Layout**: Scrollable upgrade lists
  - **Visual Organization**: Clear separation of information sections

## Integration Points

### Main Menu Integration
- Sanctum button now properly navigates to the progression screen
- Seamless scene transitions between main menu and Sanctum

### Save System
- Automatic saving when progression changes occur
- Cross-session persistence of all upgrade progress
- Robust loading with fallback to default values

### Combat Integration Ready
- Experience system can be easily integrated with combat completion
- Supports different enemy types and boss encounters
- Debug functions available for testing (F5-F8 keys in Sanctum)

## How to Use

### For Players
1. **Access**: Click "SANCTUM" button from main menu
2. **Navigation**: Use tabs to switch between roster and class views
3. **Upgrades**: Click "Upgrade" buttons when you have available points
4. **Experience**: Gain experience by completing fights in runs

### For Developers
1. **Award Experience**: Use `ExperienceSystem` to award XP after fights
2. **Add Upgrades**: Modify `upgrade_definitions.gd` to add new upgrades
3. **Testing**: Use debug keys (F5-F8) in Sanctum for testing
4. **Integration**: Reference `progression_manager` for stat bonuses during gameplay

## File Structure
```
scripts/
├── progression_manager.gd     # Core progression logic
├── upgrade_definitions.gd     # Upgrade definitions
├── sanctum_ui.gd             # UI controller
└── experience_system.gd      # Experience awarding

scenes/
└── Sanctum.tscn              # Main progression UI scene
```

## Debug Features
- **F5**: Add test XP to Swordsman
- **F6**: Add test XP to Archer  
- **F7**: Add test XP to Pyromancer
- **F8**: Reset all progression (testing only)

## Next Steps
- Integrate experience system with combat completion
- Apply upgrade bonuses to character stats during gameplay
- Expand upgrade trees based on gameplay feedback
- Add visual feedback for level-ups and achievements 