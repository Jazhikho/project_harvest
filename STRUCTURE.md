# Project Harvest - Folder Structure 📁

This document outlines the complete folder structure and organization of the Project Harvest Godot project.

## 📂 Root Directory Structure

```
project_harvest/
├── 📄 GDD.md                    # Game Design Document
├── 📄 README.md                 # Project overview and setup
├── 📄 TIMELINE.md               # Development timeline
├── 📄 STRUCTURE.md              # This file - project structure guide
├── 📄 project.godot             # Godot project configuration
├── 🖼️ icon.svg                  # Project icon
│
├── 📁 scripts/                  # All GDScript files
│   ├── 📁 autoloads/           # Singleton managers (always loaded)
│   ├── 📁 entities/            # Character and entity scripts
│   ├── 📁 systems/             # Core game systems
│   ├── 📁 ui/                  # User interface scripts
│   └── 📁 utils/               # Utility and helper scripts
│
├── 📁 scenes/                   # Godot scene files (.tscn)
│   ├── 📁 entities/            # Entity scene prefabs
│   ├── 📁 environments/        # Environment and level scenes
│   └── 📁 ui/                  # UI scene components
│
├── 📁 assets/                   # All game assets
│   ├── 📁 audio/               # Sound effects and music
│   ├── 📁 models/              # 3D models and meshes
│   ├── 📁 textures/            # Textures and materials
│   └── 📁 effects/             # Particle effects and shaders
│
├── 📁 resources/               # Godot resource files (.tres)
├── 📁 data/                    # JSON data and configuration files
└── 📁 Concept Files/           # Original prototypes and reference
    └── 📁 CreepyMaze/          # JavaScript HTML5 prototype
```

## 🔧 Scripts Directory Breakdown

### `/scripts/autoloads/` - Core Game Managers
These are singleton scripts that persist throughout the game session:

- **`GameDirector.gd`** - Main game state coordination and narrative progression
- **`MazeManager.gd`** - Maze generation, shifting, and spatial logic  
- **`SanityManager.gd`** - Player psychological state and visual effects
- **`WeirdThingsManager.gd`** - Artifact placement and effect handling
- **`HarvestLogger.gd`** - Run persistence and echo system (core feature)

### `/scripts/entities/` - Characters and Interactive Objects
- **`Player.gd`** - First-person controller with grid-based movement
- **`Watcher.gd`** - Half-formed duplicate entity (psychological horror)
- **`Stalker.gd`** - Apex predator entity (active threat)
- *(Future entities: Overseer Eyes, Caretakers, Residual Subjects)*

### `/scripts/systems/` - Game Systems
- **`InputManager.gd`** - Centralized input handling and mapping
- *(Future systems: AudioManager, EffectsManager, SaveSystem)*

### `/scripts/ui/` - User Interface
- **`HUD.gd`** - Main heads-up display (sanity, counter, messages)
- *(Future UI: MainMenu, PauseMenu, InventoryUI, GameOverScreen)*

### `/scripts/utils/` - Utilities and Helpers
- *(Future utilities: MathHelpers, DebugTools, Extensions)*

## 🎬 Scenes Directory Structure

### `/scenes/Main.tscn` - Primary Game Scene
The main game scene containing:
- Player with FPS controller
- Entity container (Watcher, Stalker)
- Maze container (for procedural chunks)
- UI layer with HUD
- World environment and lighting

### Future Scene Organization:
- **`/scenes/entities/`** - Reusable entity prefabs
- **`/scenes/environments/`** - Maze chunks and landmark areas
- **`/scenes/ui/`** - UI component scenes

## 🎨 Assets Directory Guidelines

### `/assets/audio/`
- **`ambience/`** - Corn rustling, wind, carnival distant music
- **`effects/`** - Jumpscare stings, footsteps, weird thing sounds
- **`voices/`** - Whispers, choir echoes, Dr. Amundsen recordings

### `/assets/models/`
- **`maze/`** - Corn stalks, walls, fence pieces
- **`entities/`** - Watcher, Stalker, player hands/tools
- **`props/`** - Weird things (dolls, music boxes, mirrors)
- **`structures/`** - Scarecrows, equipment shed, harvest infrastructure

### `/assets/textures/`
- **`corn/`** - Corn stalk variations, weathered organic materials
- **`horror/`** - Distortion effects, corruption patterns
- **`ui/`** - HUD elements, message overlays

## 🎯 Key Architectural Decisions

### **Autoload Pattern**
Core systems use Godot's autoload feature for:
- Cross-scene persistence
- Centralized state management  
- Event-driven communication between systems

### **Grid-Based 3D Movement**
Player movement combines:
- 3D first-person controls for immersion
- Grid-based logic for maze navigation
- Smooth interpolation between grid positions

### **Modular Entity Design**
Each entity follows a consistent pattern:
- State machine for behavior management
- Signal-based communication with core systems
- Configurable parameters for different variants

### **Meta-Persistence System**
The Harvest Logger implements the core feature:
- JSON-based run data storage
- Cross-session echo spawning
- Timestamp-based narrative integration

## 🔄 Development Workflow

### **Week 1 Focus Areas:**
1. **Core Systems** - Finalize autoload managers
2. **Player Control** - FPS movement with grid constraints  
3. **Basic Maze** - Procedural generation and rendering

### **Asset Integration:**
1. Create placeholder primitive meshes first
2. Replace with custom models as available
3. Implement audio last (after core mechanics)

### **Testing Strategy:**
1. Individual system testing via debug scenes
2. Integration testing in Main.tscn
3. Harvest system testing with simulated runs

## 📝 File Naming Conventions

- **Scripts:** PascalCase (e.g., `GameDirector.gd`)
- **Scenes:** PascalCase (e.g., `PlayerController.tscn`)  
- **Assets:** snake_case (e.g., `corn_stalk_01.fbx`)
- **Resources:** snake_case (e.g., `watcher_material.tres`)

## 🎮 Scene Setup Workflow

1. **Main Scene** serves as the primary game container
2. **Entity scenes** are instantiated dynamically by managers
3. **UI scenes** overlay the 3D environment
4. **Environment chunks** are created procedurally by MazeManager

---

**Next Steps:** Begin Week 1 development with autoload system testing and basic maze generation implementation.

*"The maze remembers. Every folder, every script, every asset becomes part of the harvest."*
