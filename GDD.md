# Game Design Document for: Project Harvest

## A Halloween Horror Rogue-Lite Walking Sim

**Author:** Christopher B. Del Gesso  
**Institution:** Lindenwood University  
**Course:** GAM56800: Game Development  
**Professor:** Ben Fulcher  
**Date:** Sunday, 4 September 2025

---

## Table of Contents

- [Game Overview](#game-overview)
- [Philosophy](#philosophy)
- [Common Questions](#common-questions)
- [Feature Set](#feature-set)
- [Core Gameplay Loop](#core-gameplay-loop)
- [Game Characters](#game-characters)
- [User Interface](#user-interface)
- [User Experience (UX)](#user-experience-ux)
- [Musical Scores and Sound Effects](#musical-scores-and-sound-effects)
- [Influences and References](#influences-and-references)
- [Bibliography](#bibliography)

---

## Game Overview

## Philosophy

### Philosophical Point #1
> When in doubt, keep it stupid simple.

### Philosophical Point #2
> This game is a school project and part of my portfolio. Scope is intentionally limited, but execution should be careful and complete.

### Philosophical Point #3
> MVP first, feature creep later. Ship the core, then iterate. When uncertain, see Point #1.

---

## Common Questions

### What is the game (Elevator Pitch)

**Project Harvest** is a first-person horror rogue-lite walking sim set in a shifting corn maze. It begins like a seasonal attraction and slowly reveals its true purpose: the maze is an apparatus designed to harvest those who enter. The player pieces together the mystery while navigating procedural tiles, managing a hidden sanity state, and evading entities that embody surveillance, pursuit, and prior failures.

### Why create this game?

This fulfills a course assignment and advances my portfolio. It also honors a close friend with whom I conceived the original concept and who passed away last year.

### Where does the game take place?

Inside **"Crazy Jeri's Happy Fun Time Harvest Corn Maze Experience!"** A neglected roadside farm attraction hides a research site where identity is fragmented and harvested.

### What do I control?

A first-person protagonist equipped with a flashlight and a simple inventory. The player explores, reads found notes, collects artifacts, and interacts with specific event tiles to progress narrative beats.

### What is the main focus?

The apparent goal is to escape the maze. The real goal is to uncover the nature and authorship of the maze, culminating in a confrontation with the idea of identity itself. Repeated runs are expected; echoes of prior deaths reappear as effigies, notes, and world changes. The ending intentionally problematizes agency and identity.

### Who is the game for?

**Teens and up.** No twitch skills required, but the tone and psychological elements are not suitable for younger audiences. **Target platform:** Windows.

## Feature Set

### MVP (Minimum Viable Product) Goals

#### Core Features (Must Have)

**Player Control**
- **Movement:** walk, sprint, look
- **Interaction:** pick up/read notes, use simple world props, basic inventory open/close

**Procedural Shifting Maze**
- Modular 20×20 meter tiles assembled at runtime
- 5 base shapes (dead end, straight, corner, T-junction, cross) rotated/connected
- Behind-the-player culling; forward spawning; a few "stable island" event tiles

**Entities**
- **Effigies:** appear at or near prior death locations; become more active/unnatural as sanity drops
- **Watchers:** organic eyes among the corn; non-damaging, escalate tension/sanity effects
- **The Stalker:** featureless pursuer that shifts from distant glimpses to timed hunts as sanity falls
- **The Architect (Dr. Amundsen):** never seen; present via notes, PA-style lines, environmental control

**Systems**
- **Sanity:** hidden meter that modulates visuals, audio, entity frequency, and tile hostility
- **Flashlight battery:** limited use with flicker/failure at low charge
- **Logged runs:** time, death cause, discoveries; prior runs echo as props/notes/effigies

**Narrative/Interactables**
- Semi-randomized notes from prior subjects and the experimenter
- Key items (e.g., key, photo, music box) to gate specific event tiles
- False Exit set piece that delivers the "no true escape" theme

**UI**
- Main menu, pause, inventory, results screen, basic save (time, deaths, collectibles revealed), credits

**Audio/FX**
- Footsteps, corn rustle, whispers, distant screams
- Minimal stingers for encounters and pick-ups

### Nice-to-Have Features

- Short intro cutscene (arriving at the farm, greeted by "Jeri")
- Protagonist VO for inner thoughts (inconsistent timbre to reflect identity drift)
- Faux "difficulty" settings that mock the player without actually changing difficulty
- Internally shifting sub-walls within select tiles
- Pulling the player's OS username for unsettling diegetic messaging

## Core Gameplay Loop

> "They ask me why. Why persist? Because the self is a disease. Multiplicity is cure. Reintegration is ascension…" — Dr. Amundsen

1. **Spawn** at a start tile leading into procedural maze segments.
2. **Explore** with limited vision, reading notes and collecting artifacts needed to unlock event tiles.
3. **Endure** escalating pressure: sanity falls over time and with encounters; The Stalker graduates from presence to pursuit.
4. **Encounter** stable story tiles that anchor progress across runs.
5. **Fail or "escape":** death or the False Exit logs the run. New effigies/echoes spawn next run at late-run tiles.
6. **Repeat** with increased world memory, new notes, and shifting tile mixes to push deeper.

---

## Game Characters

### Overview

There are no "traditional" companions. The maze refracts the player into multiple roles: **subject, witness, pursuer, and author.**

### Main Character – The Protagonist(s)

Identity is unstable. In text (and potentially VO), narration drifts between first, second, and third person as sanity drops. The player never sees a reliable reflection. Inventory uses "my" language early, then slips.

### The Architect – Dr. Amundsen

The unseen architect of Project Harvest, running experiments in duplication, partition, and reintegration. His stated aim is scientific progress; his actual aim is dominion over identity. He appears in notes, signage, PA lines, and surveillance detritus. The maze is both his lab and his abattoir; cruelty is an acceptable budget line.

### The Effigies

Markers of prior runs. At high sanity they read as "harmless scarecrows"; at low sanity they distort, twitch, and edge closer when unwatched. They host notes and items from previous subjects and from the player's past deaths, doubling as landmarks in a world that refuses to stay put.

### The Stalker

A pressure valve for pacing. Early glimpses raise dread. As sanity dips, patrols become chases in controlled pulses that force movement and route choice. It cannot be killed, only evaded.

### The Watchers

Organic surveillance embedded in the corn. They track and "judge" but don't attack. Their presence increases paranoia and nudges sanity downward, unlocking more distortions and spawns.

### The Choir

A disembodied chorus of fragments. Whisper layers begin as wind, then articulate misdirection and doubts near items, event tiles, or threats.

## User Interface

### Controls

#### Keyboard (Primary)

| Action | Key |
|--------|-----|
| Move | `WASD` / Arrow Keys |
| Run | `Spacebar` |
| Interact | `E` |
| Flashlight toggle | `F` |
| Inventory | `I` |
| Pause | `P` |
| Menu | `Esc` |
| Look | Mouse |

#### Controller Support (Nice-to-Have)

| Action | Button |
|--------|--------|
| Move | Left stick/D-pad |
| Look | Right stick |
| Run | A/Cross |
| Interact | X/Square |
| Flashlight | Y/Triangle |
| Inventory | B/Circle |
| Pause | Start |
| Menu | Menu |

### HUD Elements

No persistent HUD. Contextual prompts display briefly. **Sanity is hidden** but expressed through VFX, audio layering, encounter frequency, and world behavior.

### Inventory

Simple panel that slides up with scrollable item slots. Notes open to full-screen readable panels.

### Menu Systems

#### Main Menu
- Start
- Settings
- Credits
- Quit

> **Note:** Quitting mid-run counts as a "death" and logs the run summary

#### Settings
- Audio sliders (Master, Music, SFX)
- Control remapping (Nice-to-have)
- Graphics toggle (if needed)
- Reset Data (wipe saves)

## User Experience (UX)

### Player Onboarding

1. **Autodetect input device**; show compact control hints that fade.
2. **Short in-world tutorialization** through narrated thoughts: flashlight use, picking up a note, first interactable.
3. **On first "Weird Thing,"** surface sprint reminder diegetically ("tighten laces").
4. **First entity glimpse** and first stable event tile occur within 3–5 tiles to establish tone and loop.

---

## Musical Scores and Sound Effects

### Diegetic Audio

#### Movement
- Light footfalls; accelerated steps while sprinting
- Subtle scrape on plant collision
- Effigy rustle when repositioning

#### Environment
- Corn wind beds; intermittent crow calls scaling with sanity thresholds

#### Feedback
- Paper "fwip" for note pick-ups
- Flashlight click; sputter at low battery
- The Choir near points of interest; distant screams at critical sanity

### Non-Diegetic Audio

#### Music Tracks
- **Main Menu:** warped carnival loop oscillating between eerie and off-kilter jolly
- **Exploration Bed:** sparse drones that emerge if the player lingers
- **Stalker Cue:** sharp percussive build that spikes and releases
- **End Credits:** somber, unresolved motif

#### UI Audio
- Soft scratch for menu navigation
- Subtle snap on confirm
- Whispering gust between scene transitions

---

## Influences and References

### Game Influences

- **Del Gesso, C. B.** (2025). *FORGOTTEN IN THE WOODS* [HTML game]. Created with the assistance of Anthropic's Claude AI.
- **Del Gesso, C. B.** (2025). *Creepy Maze* [HTML/JS game]. Created with the assistance of Anthropic's Claude AI.
- **Silent Hill** (video game). (1999). Konami Computer Entertainment Tokyo.

### Other Media Influences

- **King, S.** (Writer), & **Kiersch, F.** (Director). (1984). *Children of the Corn* [Film]. New World Pictures.
- **Duncan, D. S.** (Director). (2023). *Dark Harvest* [Film]. Metro-Goldwyn-Mayer.
- **Slenderman meme.** (2009). Created by E. Knudsen (Victor Surge) [Internet meme].
- **Petscop** [Creepypasta web series]. (2017–2019). YouTube. Created by Tony Domenico.

### Other Influence

- **Del Gesso, C. B., & Amundsen, J.** (2020). *Project Harvest* [Unpublished game concept discussion].

---

## Bibliography

- Del Gesso, C. B. (2025). *Creepy Maze* [HTML/JS game]. Created with the assistance of Anthropic's Claude AI.
- Del Gesso, C. B. (2025). *FORGOTTEN IN THE WOODS* [HTML game]. Created with the assistance of Anthropic's Claude AI.
- Del Gesso, C. B., & Amundsen, J. (2020). *Project Harvest* [Unpublished game concept discussion].
- Duncan, D. S. (Director). (2023). *Dark Harvest* [Film]. Metro-Goldwyn-Mayer.
- King, S. (Writer), & Kiersch, F. (Director). (1984). *Children of the Corn* [Film]. New World Pictures.
- OpenAI. (2025). *ChatGPT* [Large language model]. https://chat.openai.com. Used for concept art and Game Design Document suggestions.
- Petscop [Creepypasta web series]. (2017–2019). YouTube. Created by Tony Domenico.
- Silent Hill (video game). (1999). Konami Computer Entertainment Tokyo.
- Slenderman meme. (2009). Created by E. Knudsen (Victor Surge) [Internet meme].

---

## Notes on Scope Alignment

- All systems are expressed in MVP language and map to a single-semester deliverable.
- Identity theme is threaded through narration, entities, and meta-progression without requiring cutscenes.
- "False Exit" and run logging anchor the rogue-lite loop and portfolio value.
