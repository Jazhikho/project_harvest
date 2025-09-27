# Project Harvest 🌽

A survival horror game set in a shifting corn maze where the maze itself is alive, reshaping and remembering every previous attempt. Players enter expecting a fun Halloween attraction but quickly discover they're part of an experimental harvest program.

## 🎯 Core Concept

**Project Harvest** blends procedural horror with meta-narrative replayability. Each failed run becomes part of the maze's memory - your previous attempts manifest as corpses, notes, and whispers in subsequent playthroughs. The game pulls system date/time to create unique "harvest logs" that persist between sessions.

**Key Inspiration Sources:**
- **Creepy Maze System:** Procedural shifting maze with pickups and jumpscares
- **Forgotten in the Woods:** Branching narrative, sanity mechanics, and the Watcher entity

## 🎮 Key Features

### Core Horror Mechanics
- **🌪️ Living Maze:** 20×20 procedural grid that actively reshapes during gameplay
- **🔦 Limited Vision:** First-person perspective with dynamic fog and lighting
- **🎭 Weird Things:** Mysterious artifacts (dolls, music boxes, mirrors) that trigger disturbing effects
- **🧠 Sanity System:** Psychological degradation affects entity encounters and maze hostility

### Unique Entities  
- **👁️ The Watcher:** Half-formed duplicate that flickers at vision's edge
- **🌾 The Stalker:** Apex predator activated by collecting too many Weird Things
- **🤖 Overseer Eyes:** Bio-organic surveillance that tracks your every move
- **💀 The Choir:** Whispers of harvested subjects that drain sanity over time

### Meta-Horror Features
- **⚱️ Harvest System:** Each run logged with timestamp and death data
- **🔄 Echo System:** Failed attempts manifest as corpses, notes, and whispers in future runs  
- **🚪 False Exit:** No true escape - the maze weaponizes hope itself
- **📊 Experiment Logs:** Dr. Amundsen's research tracks every subject across time

## 🎲 Gameplay Loop

1. **Navigate** the maze with limited vision
2. **Collect** Weird Things and lore fragments  
3. **Manage** sanity while avoiding supernatural entities
4. **Survive** dynamic maze shifts that alter known paths
5. **Solve** landmark puzzles to unlock the exit
6. **Escape or Fail** → Your attempt becomes part of the next run's horror

## 🛠️ Development Status

Currently in **early development** phase with:

### ✅ Completed
- **Game Design Document** (comprehensive specification focused on Godot implementation)
- **Core Godot Architecture** (autoload managers and tile streaming system)
- **Base Tile System** (modular 3D maze segments with door connectivity)
- **Player Controller** (FPS movement with grid-based navigation)

### 🔄 In Progress
- **Spawning Behavior** (tile generation and entity placement logic)
- **Weird Things System** (artifact spawning and interaction mechanics)
- **Entity AI** (Watcher and Stalker behavior implementation)
- **Harvest Log System** (persistent run data and echo spawning)

### 📋 Planned Features
- **Advanced Entity AI** (Stalker hunt patterns, Watcher psychological effects)
- **Harvest Echo System** (Corpses, notes, and whispers from prior runs)
- **Audio/Visual Polish** (Dynamic lighting, corn maze aesthetics)
- **Meta-Narrative Integration** (Dr. Amundsen's experiment logs)
- **Multiple Landmark Areas** (Scarecrow Crossroads, Equipment Shed)

## 🏗️ Technical Architecture

### Current Stack
- **Engine:** Godot 4.4.1
- **Language:** GDScript
- **Platform:** PC (Windows/Linux/Mac)

### Project Structure
```
project_harvest/
├── GDD.md                     # Game Design Document
├── project.godot              # Godot project file
├── scripts/                   # Core game systems
│   ├── autoloads/            # Global managers (GameDirector, TileManager, etc.)
│   ├── entities/             # Player, Stalker, Watcher implementations
│   ├── tiles/                # Tile system and door logic
│   └── ui/                   # HUD and interface systems
├── scenes/                    # Game scenes and prefabs
│   ├── tiles/                # Modular maze segment scenes
│   ├── entities/             # Entity prefabs
│   └── ui/                   # Interface scenes
├── assets/                    # 3D models, textures, audio
└── Concept Files/             # Legacy 2D prototype (reference only)
```

## 🚀 Getting Started

### Prerequisites
- **Godot Engine 4.4.1** for main development
- **Git** for version control

### Development Setup
1. Clone the repository
2. Open `project.godot` in Godot Engine 4.4.1
3. Review `GDD.md` for full design specifications
4. Run the project to test current graybox implementation

### Current Development Focus
- **Graybox Testing:** Validating tile connectivity and spawning patterns
- **Spawning Behavior:** Implementing proper entity and Weird Things placement
- **Performance Optimization:** Ensuring stable frame rates with dynamic tile streaming

## 📅 Development Timeline

**Target:** September 28, 2025 (Minimum Viable Product)
**Available Time:** 1-2 hours daily

See [TIMELINE.md](TIMELINE.md) for detailed week-by-week development schedule.

## 🎯 Minimum Viable Product (Sept 30)

### Core Requirements
- [ ] **Maze Generation:** 10+ modular 3D chunks with procedural assembly
- [ ] **Player Systems:** FPS controller with flashlight and grid-based logic  
- [ ] **Weird Things:** 3-5 interactive artifacts with narrative effects
- [ ] **Sanity System:** HUD display with visual feedback and decay mechanics
- [ ] **Entity AI:** Watcher spawning and basic stalking behavior
- [ ] **Horror Elements:** False exit door with jumpscare trigger
- [ ] **Harvest Features:** Run logging and echo system for replayability
- [ ] **Content Areas:** 2+ landmark locations (Scarecrow Crossroads, Equipment Shed)

## 🧪 Design Philosophy

**"Each run is another harvested subject. The maze remembers. Your past selves litter the corridors."**

Project Harvest explores themes of:
- **Identity Fragmentation:** Encounters with doppelgängers and past selves
- **Experimental Horror:** Subjects unknowingly participating in consciousness experiments  
- **Temporal Recursion:** Failed attempts become environmental storytelling
- **Psychological Conditioning:** Weird Things as fragments of prior test runs

## 🤝 Contributing

This is currently a solo development project. Documentation and prototypes are available for reference and learning.

## 📄 License

*License to be determined - currently in development*

---

*"You aren't escaping alone—you're competing with every version of you that's already been consumed."*
