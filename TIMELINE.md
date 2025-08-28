# Project Harvest - Development Timeline 📅
**Duration:** August 28 - September 28, 2024 (32 days)  
**Available Time:** 1-2 hours daily (~45 hours total)  
**Target:** Minimum Viable Product (MVP)

---

## 🎯 Overview & Milestones

| Week | Focus Area | Key Deliverable | Hours |
|------|------------|-----------------|-------|
| **Week 1** (Aug 28 - Sep 3) | Foundation & Setup | Godot project + basic maze | ~10h |
| **Week 2** (Sep 4 - Sep 10) | Living Maze System | 100×100 procedural shifting maze | ~10h |
| **Week 3** (Sep 11 - Sep 17) | Entities & Horror | Watcher, Stalker, and Overseer Eyes | ~10h |
| **Week 4** (Sep 18 - Sep 24) | Harvest Integration | Echo system + weird things effects | ~10h |
| **Week 5** (Sep 25 - Sep 28) | Polish & Meta-Horror | Dr. Amundsen logs + false exit | ~5h |

---

## 📋 Week-by-Week Breakdown

### **Week 1: Foundation & Setup** (Aug 28 - Sep 3)
*Goal: Establish solid technical foundation*

#### **Day 1 (Aug 28) - Project Setup** [1.5h]
- [ ] Create Godot project structure
- [ ] Set up autoload managers (GameDirector, MazeManager, etc.)
- [ ] Import assets folder structure
- [ ] Test basic scene setup

#### **Day 2 (Aug 29) - Scene Architecture** [1.5h]
- [ ] Create main game scene hierarchy
- [ ] Set up basic lighting system
- [ ] Create player spawn point
- [ ] Test camera controller basics

#### **Day 3 (Aug 30) - Maze Foundation** [2h]
- [ ] Port maze generation logic from JS prototype
- [ ] Create basic 3D tile system (walls, floors)
- [ ] Test 20x20 grid generation
- [ ] Basic collision setup

#### **Day 4 (Aug 31) - Visual Systems** [1.5h]
- [ ] Implement fog-of-war prototype
- [ ] Basic flashlight mechanics
- [ ] Simple corn maze textures/materials
- [ ] Test lighting visibility

#### **Day 5 (Sep 1) - Player Basics** [1.5h]
- [ ] FPS controller implementation
- [ ] Grid-based movement logic
- [ ] Flashlight attachment and controls
- [ ] Basic movement sound effects

#### **Day 6 (Sep 2) - Polish Week 1** [1h]
- [ ] Fix major bugs from week
- [ ] Optimize performance issues
- [ ] Document progress

#### **Day 7 (Sep 3) - Buffer/Rest** [1h]
- [ ] Catch up on any delayed tasks
- [ ] Plan week 2 priorities

**Week 1 Target:** Playable maze with basic FPS movement and fog-of-war

---

### **Week 2: Living Maze System** (Sep 4 - Sep 10)  
*Goal: 100×100 procedural shifting maze with distortion zones*

#### **Day 8 (Sep 4) - Maze Chunks** [2h]
- [ ] Create modular 3D maze pieces (straight, corner, T-junction, cross)
- [ ] Implement chunk swapping system
- [ ] Test procedural assembly

#### **Day 9 (Sep 5) - Maze Shifting** [1.5h]
- [ ] Port `changeMazePart` logic from prototype
- [ ] Implement timer-based maze shifts
- [ ] Add visual/audio feedback for shifts

#### **Day 10 (Sep 6) - Distortion Zones** [1.5h]
- [ ] Create special maze areas with enhanced shifting
- [ ] Implement proximity-triggered distortions
- [ ] Test maze stability

#### **Day 11 (Sep 7) - Navigation Polish** [1.5h]
- [ ] Improve collision detection
- [ ] Add maze boundary enforcement
- [ ] Implement smooth transitions during shifts

#### **Day 12 (Sep 8) - Maze Audio** [1h]
- [ ] Ambient maze sounds
- [ ] Shifting audio cues
- [ ] Spatial audio testing

#### **Day 13 (Sep 9) - Integration Testing** [1.5h]
- [ ] Full maze generation + shifting tests
- [ ] Performance optimization
- [ ] Bug fixes

#### **Day 14 (Sep 10) - Week 2 Buffer** [1h]
- [ ] Documentation and planning
- [ ] Address any critical issues

**Week 2 Target:** Fully functional shifting maze system

---

### **Week 3: Entities & Horror** (Sep 11 - Sep 17)
*Goal: Watcher, Stalker, Overseer Eyes, and psychological horror systems*

#### **Day 15 (Sep 11) - Sanity System** [1.5h]
- [ ] Implement sanity manager (0-100 scale)
- [ ] Create visual feedback (screen effects, color grading)
- [ ] Basic sanity loss triggers

#### **Day 16 (Sep 12) - The Watcher** [2h]
- [ ] Create Watcher entity prefab
- [ ] Implement probability-based spawning
- [ ] Basic stalking behavior AI

#### **Day 17 (Sep 13) - Weird Things Foundation** [1.5h]
- [ ] Create weird things spawning system
- [ ] Implement 3 basic weird thing types
- [ ] Pickup interaction mechanics

#### **Day 18 (Sep 14) - Weird Things Effects** [1.5h]
- [ ] Screen flicker effects
- [ ] Local maze distortion triggers
- [ ] Audio/visual feedback system

#### **Day 19 (Sep 15) - Inventory System** [1h]
- [ ] Basic inventory manager
- [ ] Simple UI display
- [ ] Item collection mechanics

#### **Day 20 (Sep 16) - Entity Integration** [1.5h]
- [ ] Watcher-sanity interaction
- [ ] Weird things affect sanity
- [ ] Test entity spawning balance

#### **Day 21 (Sep 17) - Week 3 Polish** [1h]
- [ ] Bug fixes and optimization
- [ ] Balance sanity mechanics

**Week 3 Target:** Interactive entities with sanity/inventory systems

---

### **Week 4: Harvest Integration** (Sep 18 - Sep 24) 
*Goal: Echo system, weird things effects, and harvest mechanics*

#### **Day 22 (Sep 18) - Landmark Puzzles** [2h]
- [ ] Create Scarecrow Crossroads area
- [ ] Implement rope puzzle mechanics
- [ ] Test puzzle-key system

#### **Day 23 (Sep 19) - Irrigation Pond** [1.5h]
- [ ] Create pond landmark area
- [ ] Implement reflection scare
- [ ] Add battery cache reward

#### **Day 24 (Sep 20) - Exit Gate** [1.5h]
- [ ] Create exit gate structure
- [ ] Implement 3-key requirement system
- [ ] Basic code entry mechanics

#### **Day 25 (Sep 21) - Jumpscare System** [1.5h]
- [ ] Create jumpscare overlay system
- [ ] Implement exit-door pre-trigger
- [ ] Test timing and effectiveness

#### **Day 26 (Sep 22) - Game Flow** [1.5h]
- [ ] Connect all systems into complete loop
- [ ] Test win/lose conditions
- [ ] Balance difficulty progression

#### **Day 27 (Sep 23) - UI/HUD** [1h]
- [ ] Weird findings counter
- [ ] Sanity indicator
- [ ] Inventory display

#### **Day 28 (Sep 24) - Week 4 Integration** [1h]
- [ ] Full gameplay test
- [ ] Major bug fixes

**Week 4 Target:** Complete playable game loop with win condition

---

### **Week 5: Polish & Meta-Horror** (Sep 25 - Sep 28)
*Goal: Dr. Amundsen integration, false exit, and MVP completion*

#### **Day 29 (Sep 25) - Harvest System Foundation** [1.5h]
- [ ] Implement run logging (JSON save system)
- [ ] Create timestamp-based run identification
- [ ] Basic echo spawning system

#### **Day 30 (Sep 26) - Echo Implementation** [1.5h]
- [ ] Spawn corpse/effigy of previous run
- [ ] Generate notes from prior attempts
- [ ] Test replay echo placement

#### **Day 31 (Sep 27) - Final Polish** [1h]
- [ ] Audio implementation and mixing
- [ ] Visual effects polish
- [ ] Performance optimization

#### **Day 32 (Sep 28) - MVP Completion** [1h]
- [ ] Final testing and bug fixes
- [ ] Documentation update
- [ ] MVP build preparation

**Week 5 Target:** Fully functional MVP with harvest replay system

---

## 🔧 Technical Priorities

### **Critical Path Items** (Cannot be delayed)
1. **Maze Generation** (Week 1-2) - Foundation for everything
2. **Player Controller** (Week 1) - Required for testing
3. **Sanity System** (Week 3) - Core mechanic dependency
4. **Exit Gate** (Week 4) - Win condition requirement
5. **Harvest System** (Week 5) - Unique selling point

### **Nice-to-Have Features** (Cut if needed)
- Advanced Watcher AI behaviors
- Complex audio mixing
- Multiple weird thing subtypes
- Advanced visual effects
- Additional landmark puzzles

---

## 📊 Risk Assessment & Mitigation

### **High Risk Areas**
1. **3D Maze Performance** - May need optimization or simplification
2. **Harvest System Complexity** - Could be simplified to basic logging
3. **Entity AI** - May need to reduce complexity if time-constrained

### **Mitigation Strategies**
- **Daily Progress Check** - Reassess timeline every 3 days
- **Feature Prioritization** - Cut nice-to-haves if behind schedule
- **Prototype Fallback** - Can revert to 2D if 3D proves too complex

---

## 🎯 Definition of Success (MVP)

By September 28, the game must have:
- ✅ **Playable maze** with shifting mechanics
- ✅ **Functional sanity** system with feedback
- ✅ **Basic weird things** collection (minimum 3 types)
- ✅ **Watcher entity** with spawning
- ✅ **Exit gate** with key requirement
- ✅ **Harvest logging** system with timestamped runs
- ✅ **At least 1 echo** spawning in subsequent runs

**Success Metric:** A complete playthrough from start to finish that demonstrates the core "harvest" concept and replayability mechanic.

---

*"Every hour invested brings us closer to harvesting something truly unique."*
