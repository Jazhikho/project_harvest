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
- **Game Design Document** (comprehensive 140+ line specification)
- **2D Prototype** (Creepy Maze proof-of-concept in HTML5/JavaScript)
- **Core Systems Architecture** (modular ES6 implementation)

### 🔄 In Progress
- **3D Prototype** (transitioning to Godot Engine)
- **Maze Generation System** (upgrading from 2D to 3D chunks)
- **Harvest Log System** (persistent run data storage)

### 📋 Planned Features
- **Advanced Entity AI** (Stalker hunt patterns, Watcher psychological effects)
- **Harvest Echo System** (Corpses, notes, and whispers from prior runs)
- **Audio/Visual Polish** (Dynamic lighting, corn maze aesthetics)
- **Meta-Narrative Integration** (Dr. Amundsen's experiment logs)
- **Multiple Landmark Areas** (Scarecrow Crossroads, Equipment Shed)

## 🏗️ Technical Architecture

### Current Stack
- **Engine:** Godot 4.x (transitioning from HTML5 prototype)
- **Language:** GDScript + JavaScript (legacy prototype)
- **Platform:** PC (Windows/Linux/Mac)

### Project Structure
```
project_harvest/
├── GDD.md                     # Game Design Document
├── project.godot              # Godot project file
├── Concept Files/             # Prototype implementations
│   └── CreepyMaze/           # 2D HTML5 prototype
│       ├── index.html        # Main prototype entry
│       ├── js/               # Modular JavaScript implementation
│       └── README.md         # Prototype documentation
└── README.md                 # This file
```

## 🚀 Getting Started

### Prerequisites
- **Godot Engine 4.x** for main development
- **Modern Web Browser** for prototype testing
- **Local Web Server** (Python/Node.js) for prototype

### Running the 2D Prototype
1. Navigate to `Concept Files/CreepyMaze/`
2. Start a local web server:
   ```bash
   # Using Python
   python -m http.server 8000
   
   # Using Node.js
   npx http-server
   ```
3. Open `http://localhost:8000` in your browser

### Development Setup
1. Clone the repository
2. Open `project.godot` in Godot Engine
3. Review `GDD.md` for full design specifications
4. Check prototype implementation for reference mechanics

## 📅 Development Timeline

**Target:** September 28, 2024 (Minimum Viable Product)
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
