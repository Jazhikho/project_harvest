# PROJECT HARVEST - DETAILED GAME LOOP

This document outlines the complete behavior flow from game startup to player death, detailing every action, script, and function involved in the game loop.

## GAME INITIALIZATION SEQUENCE

### Application Startup
1) Godot engine loads project configuration from `project.godot`
2) Engine initializes autoload systems in order: [**project.godot**: autoload section]
   - AudioManager [**AudioManager.gd**: `_ready()`]
   - SaveManager [**SaveManager.gd**: `_ready()`]
   - SceneManager [**SceneManager.gd**: `_ready()`]
   - InputManager [**InputManager.gd**: `_ready()`]
   - MessageBus [**MessageBus.gd**: `_ready()`]
   - GameStateManager [**GameStateManager.gd**: `_ready()`]
   - ItemManager [**ItemManager.gd**: `_ready()`]
   - SpawnManager [**SpawnManager.gd**: `_ready()`]
   - TileManager [**TileManager.gd**: `_ready()`]
   - EventManager [**EventManager.gd**: `_ready()`]
   - GameDirector [**GameDirector.gd**: `_ready()`]
   - SettingsManager [**SettingsManager.gd**: `_ready()`]
   - MazeManager [**MazeManager.gd**: `_ready()`]
   - WeirdThingsManager [**WeirdThingsManager.gd**: `_ready()`]
   - SanityManager [**SanityManager.gd**: `_ready()`]
   - HarvestLogger [**HarvestLogger.gd**: `_ready()`]
   - PlayerInventory [**PlayerInventory.gd**: `_ready()`]
   - TileStateManager [**TileStateManager.gd**: `_ready()`]
   - EnemyManager [**EnemyManager.gd**: `_ready()`]
   - EffigyManager [**EffigyManager.gd**: `_ready()`]
3) Each autoload calls `call_deferred("_initialize")` to ensure proper initialization order [**BaseManager.gd**: `_ready()`]
4) Systems connect to MessageBus for event communication [**BaseManager.gd**: `_connect_base_events()`]
5) Main menu scene loads automatically [**project.godot**: `run/main_scene`]

### Main Menu Display
6) MainMenu scene instantiates [**Main.tscn**: scene structure]
7) MainMenu script initializes UI elements [**MainMenu.gd**: `_ready()`]
8) System checks for existing save data [**MainMenu.gd**: `_check_save_data()` calls **SaveManager.gd**: `has_save_data()`]
9) If save exists, "CONTINUE" button enables [**MainMenu.gd**: `_check_save_data()`]
10) If no save, "CONTINUE" button remains disabled [**MainMenu.gd**: `_check_save_data()`]
11) Audio settings load from AudioManager [**MainMenu.gd**: `_load_settings()`]
12) Input device detection occurs [**MainMenu.gd**: `_detect_input_device()`]
13) Focus set to START button [**MainMenu.gd**: `_ready()`]

### Menu Interactions
14) Player clicks START button [**MainMenu.gd**: `_on_start_pressed()`]
15) If save data exists, confirmation dialog appears [**MainMenu.gd**: `_on_start_pressed()`]
16) Player confirms new game or cancels [**MainMenu.gd**: `_start_new_game()` or dialog cancellation]
17) If confirmed, existing save deleted [**MainMenu.gd**: `_start_new_game()` calls **SaveManager.gd**: `delete_save()`]
18) Game scene loads [**MainMenu.gd**: `_start_new_game()` calls **SceneManager.gd**: `load_game_scene()`]

### Alternative: Continue Game
19) Player clicks CONTINUE button [**MainMenu.gd**: `_on_continue_pressed()`]
20) Save data loads [**MainMenu.gd**: `_on_continue_pressed()` calls **SaveManager.gd**: `load_game()`]
21) Game scene loads with existing data [**SceneManager.gd**: `load_game_scene()`]

## GAME SCENE INITIALIZATION

### Scene Loading
22) Game.tscn instantiates with all child nodes [**Game.tscn**: scene structure]
23) GameController initializes [**GameController.gd**: `_ready()`]
24) Player entity spawns at default position [**Game.tscn**: Player node, **Player.gd**: `_ready()`]
25) Start tile loads in MazeContainer [**Game.tscn**: StartTile node]
26) UI elements initialize (PauseMenu, InventoryUI) [**GameController.gd**: `_ready()`]
27) Fade-in transition begins [**GameController.gd**: `fade_in()`]
28) GameController connects to UI signals [**GameController.gd**: `_ready()`]

### Player Initialization
29) Player sets up collision properties [**Player.gd**: `_ready()` calls **CollisionHelper.setup_player_collision()**]
30) Mouse capture activates [**Player.gd**: `_ready()` calls `Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)`]
31) Player connects to core systems [**Player.gd**: `_initialize_systems()`]
32) Flashlight battery randomizes between 60-300 seconds [**Player.gd**: `_ready()`]
33) Player emits spawn event [**Player.gd**: `_initialize_systems()` calls **MessageBus**: `emit_event("player_spawned")`]

### Game Systems Activation
34) GameController triggers game initialization [**GameController.gd**: `call_deferred("_initialize_game")`]
35) TileManager initializes game tiles [**GameController.gd**: `_initialize_game()` calls **TileManager.gd**: `initialize_game_tiles()`]
36) MessageBus emits game_started event [**GameController.gd**: `_initialize_game()` calls **MessageBus**: `emit_event("game_started")`]
37) SaveManager marks run as active [**SaveManager.gd**: `_on_game_started()` calls `start_run()`]
38) GameController connects to player death events [**GameController.gd**: `_initialize_game()`]

### Initial Tile Setup
39) Start tile registers with TileManager [**TileManager.gd**: `initialize_game_tiles()`]
40) Start tile position set to Vector2i(0,0) [**TileManager.gd**: tile registration]
41) TileStateManager marks start tile as ACTIVE [**TileStateManager.gd**: `set_tile_state()`]
42) Initial tile connections spawn from start tile [**GameController.gd**: `_initialize_game()` calls **TileManager.gd**: `_spawn_tile_connections()`]

## CORE GAME LOOP - TILE ENTRY SEQUENCE

### Player Movement Detection
43) Player moves using WASD input [**Player.gd**: `_input()` and `_handle_movement()`]
44) Player physics processed each frame [**Player.gd**: `_physics_process()` calls `move_and_slide()`]
45) Player collision with tile entry areas detected [**TileStateManager.gd**: area monitoring]
46) TileStateManager processes tile entry [**TileStateManager.gd**: `_on_player_entered_tile()`]

### Tile State Transitions
47) Current tile marked as PREVIOUS [**TileStateManager.gd**: `_set_tile_state(TileState.PREVIOUS)`]
48) New tile marked as ACTIVE [**TileStateManager.gd**: `_set_tile_state(TileState.ACTIVE)`]
49) Player position updated in GameStateManager [**TileStateManager.gd**: calls **GameStateManager.gd**: `set_state("current_tile_position")`]
50) Tiles explored counter incremented [**GameStateManager.gd**: state tracking]

### Tile Connection Analysis
51) Active tile's available doors detected [**TileManager.gd**: `_spawn_tile_connections()` calls tile's `get_available_doors()`]
52) For each door direction, connecting position calculated [**TileManager.gd**: `_get_connecting_position()`]
53) World wrapping applied to position (7x7 grid) [**TileManager.gd**: `_apply_world_wrapping()`]
54) System checks if connection already established [**TileManager.gd**: `_is_connection_established()`]
55) If connection exists, skip to next door [**TileManager.gd**: connection logic]

### Tile Generation Decision Tree
56) Check for permanent tile at wrapped position [**TileManager.gd**: `_has_permanent_tile_at()`]
57) If permanent tile exists, establish connection [**TileManager.gd**: `_establish_connection()`]
58) If position is (0,0), check for existing start tile [**TileManager.gd**: start tile protection logic]
59) If start tile found at (0,0), establish connection [**TileManager.gd**: connection logic]
60) If no existing tile, create random tile [**TileManager.gd**: `_create_random_tile()`]

### New Tile Creation
61) Random tile scene selected from available tiles [**TileManager.gd**: `_select_random_tile_scene()`]
62) Tile scene instantiated [**TileManager.gd**: `_instantiate_tile_scene()`]
63) Tile positioned relative to source tile [**TileManager.gd**: positioning logic]
64) Tile aligned for door connection [**TileManager.gd**: `_align_tiles()`]
65) Tile added to MazeContainer [**TileManager.gd**: scene tree management]
66) Tile registered in active tiles system [**TileManager.gd**: `_register_tile()`]
67) TileStateManager registers tile as CONNECTING [**TileStateManager.gd**: `register_tile()`]
68) Connection established between tiles [**TileManager.gd**: `_establish_connection()`]
69) Tile generation event emitted [**MessageBus**: `emit_event("tile_generated")`]

## TILE SPAWNING SEQUENCE

### Spawn Point Detection
70) SpawnManager receives tile_generated event [**SpawnManager.gd**: `_on_tile_generated()`]
71) Item spawn points collected from Maze/ItemSpawn [**SpawnManager.gd**: `_get_item_spawn_points()`]
72) Entity spawn points collected from Maze/EntitySpawn [**SpawnManager.gd**: `_get_entity_spawn_points()`]
73) Spawn points arrays shuffled randomly [**SpawnManager.gd**: `process_tile_spawning()`]

### Death Location Check
74) Tile position checked against death locations [**SpawnManager.gd**: calls **GameStateManager.gd**: `get_unused_death_at_position()`]
75) If death data found, backpack spawning initiated [**SpawnManager.gd**: `_spawn_backpack_at_death()`]
76) Backpack contains previous run's inventory [**SpawnManager.gd**: death data processing]
77) Effigy spawns at first entity point [**SpawnManager.gd**: effigy spawning logic]
78) Death location marked as used [**GameStateManager.gd**: `mark_death_used()`]
79) Spawning sequence ends early [**SpawnManager.gd**: early return]

### Regular Item Spawning
80) If no death location, regular item spawning begins [**SpawnManager.gd**: `_spawn_items()`]
81) Each spawn point rolled for 10% chance [**SpawnManager.gd**: `ITEM_SPAWN_CHANCE = 0.1`]
82) If successful, available items queried [**ItemManager.gd**: `get_spawnable_items()`]
83) Random item selected from available pool [**ItemManager.gd**: `select_random_item()`]
84) Item visual spawned at location [**SpawnManager.gd**: `_spawn_item_visual()`]
85) Item spawn event emitted [**MessageBus**: `emit_event("item_spawned")`]
86) Spawning breaks after first successful item [**SpawnManager.gd**: break logic]

### Entity Spawning System
87) Entity spawn conditions evaluated [**SpawnManager.gd**: `_spawn_entities()`]
88) Current sanity level retrieved [**GameStateManager.gd**: `get_state("sanity")`]
89) Tiles explored count retrieved [**GameStateManager.gd**: `get_state("tiles_explored")`]
90) Weird things collected count retrieved [**WeirdThingsManager.gd**: `get_collected_count()`]
91) Base spawn chance calculated as 10% + sanity bonus + exploration bonus + collection bonus [**SpawnManager.gd**: `_calculate_entity_spawn_chance()`]
92) Sanity bonus: 20% - (sanity / 5) [**SpawnManager.gd**: sanity calculation]
93) Exploration bonus: (tiles_explored - 10) * 1% [**SpawnManager.gd**: exploration calculation]
94) Collection bonus: (weird_things_collected - 10) * 1% [**SpawnManager.gd**: collection calculation]
95) Final spawn chance clamped between 0% and 100% [**SpawnManager.gd**: chance clamping]
96) Each entity type rolled against calculated chance [**SpawnManager.gd**: entity rolling]
97) If successful, EnemyManager spawns entity [**EnemyManager.gd**: `spawn_enemy()`]
98) Entity spawning breaks after first success [**SpawnManager.gd**: break logic]

### Tile Cleanup Process
99) TileManager identifies distant tiles for cleanup [**TileManager.gd**: `_cleanup_tiles_for_position()`]
100) Tiles beyond connection range marked for removal [**TileManager.gd**: cleanup distance logic]
101) Entities on removed tiles cleaned up [**TileManager.gd**: entity cleanup]
102) Items on removed tiles cleaned up [**TileManager.gd**: item cleanup]
103) Tile nodes removed from scene [**TileManager.gd**: `queue_free()`]
104) Tile references removed from tracking [**TileManager.gd**: dictionary cleanup]

## PLAYER INTERACTION SYSTEMS

### Movement and Physics
105) Player input processed each frame [**Player.gd**: `_input()`]
106) Movement vector calculated from WASD input [**Player.gd**: `_handle_movement()`]
107) Sprint multiplier applied if shift held [**Player.gd**: movement speed calculation]
108) Velocity applied to CharacterBody3D [**Player.gd**: `move_and_slide()`]
109) Mouse look updates camera rotation [**Player.gd**: `_handle_mouse_look()`]

### Flashlight System
110) Flashlight battery drains over time when active [**Player.gd**: `_update_flashlight()`]
111) F key toggles flashlight on/off [**Player.gd**: `_input()` and `_toggle_flashlight()`]
112) When battery dies, 10 sanity lost immediately [**Player.gd**: `_update_flashlight()` battery death check]
113) Darkness timer tracks time spent without light [**Player.gd**: `darkness_timer` tracking]
114) Every 15 seconds in darkness, 1 sanity lost [**Player.gd**: `_update_flashlight()` darkness drain]
115) Flashlight state updates visual and lighting [**Player.gd**: `_update_flashlight_state()`]
116) Battery depletion disables flashlight [**Player.gd**: flashlight logic]

### Interaction System
117) Raycast checks for interactables each frame [**Player.gd**: `_check_interactions()`]
118) Interaction prompt displayed for valid targets [**Player.gd**: `_show_interaction_prompt()`]
119) E key triggers interaction attempt [**Player.gd**: `_input()` and `_try_interact()`]
120) Interactable object's interact method called [**Player.gd**: `_try_interact()`]
121) Interaction result processed [various interactable scripts]

### Item Collection
122) Player collision with item detected [**SpawnManager.gd**: `_on_item_pickup()`]
123) Item ID retrieved from item node [**SpawnManager.gd**: item metadata]
124) Item collection event emitted [**MessageBus**: `emit_event("item_collected")`]
125) Item added to player inventory [**PlayerInventory.gd**: `add_item()`]
126) WeirdThingsManager tracks weird object collections [**WeirdThingsManager.gd**: `_on_item_collected()`]
127) Item visual removed from scene [**SpawnManager.gd**: `queue_free()`]
128) ItemManager updates item availability [**ItemManager.gd**: availability tracking]

### Inventory Management
129) I key opens inventory UI [**GameController.gd**: `_input()` and `toggle_inventory()`]
130) Game pauses when inventory opens [**GameController.gd**: `get_tree().paused = true`]
131) Inventory UI displays collected items [**InventoryUI.gd**: `show_inventory()`]
132) Mouse mode switches to visible [**InventoryUI.gd**: UI interaction]
133) Inventory closes with I key or UI button [**InventoryUI.gd**: close mechanisms]
134) Game unpauses when inventory closes [**GameController.gd**: `_on_inventory_closed()`]

## ENTITY BEHAVIOR SYSTEMS

### Effigy Behavior
135) Effigy monitors player sanity level [**Effigy.gd**: `_process()` and sanity checking]
136) Stage visibility updates based on sanity [**Effigy.gd**: `_update_stage_for_sanity()`]
137) Movement speed scales with sanity level [**Effigy.gd**: speed calculation]
138) Effigy checks if player is looking [**Effigy.gd**: `_is_player_looking()`]
139) Movement only occurs when not observed [**Effigy.gd**: movement conditions]
140) Effigy follows player at appropriate distance [**Effigy.gd**: `_update_movement()`]
141) Sanity drain applied when too close [**Effigy.gd**: proximity effects]

### Stalker Behavior
142) Stalker state transitions based on sanity [**Stalker.gd**: `_check_state_transitions()`]
143) At >70% sanity: Stalker remains idle, watching [**Stalker.gd**: `StalkerState.PATROLLING`]
144) At 50-70% sanity: Stalker moves at half speed, stops 2m away [**Stalker.gd**: `StalkerState.HUNTING`]
145) At 30-50% sanity: Stalker actively pursues without stopping [**Stalker.gd**: pursuit logic]
146) At <30% sanity: Speed increases toward player speed [**Stalker.gd**: speed scaling]
147) Navigation updates periodically toward player [**Stalker.gd**: `_update_navigation()`]
148) Collision with player triggers death [**Stalker.gd**: `_trigger_player_caught()`]

### Watcher Behavior
149) Watcher spawns in areas of low sanity [**SpawnManager.gd**: conditional spawning]
150) Applies passive sanity drain when in range [**Watcher.gd**: proximity effects]
151) Remains stationary but tracks player visually [**Watcher.gd**: tracking behavior]
152) Multiple watchers can spawn on same tile [**SpawnManager.gd**: spawning logic]

## PAUSE AND MENU SYSTEMS

### Pause Menu
153) ESC key opens pause menu [**GameController.gd**: `_input()` and `toggle_pause()`]
154) Game pauses and mouse becomes visible [**GameController.gd**: `toggle_pause()`]
155) Pause menu displays with animation [**PauseMenu.gd**: `show_menu()`]
156) Resume button unpauses game [**PauseMenu.gd**: `_on_resume_pressed()`]
157) Settings button opens settings panel [**PauseMenu.gd**: `_on_settings_pressed()`]
158) Main menu button shows confirmation dialog [**PauseMenu.gd**: `_on_main_menu_pressed()`]
159) Quit button shows quit confirmation dialog [**PauseMenu.gd**: `_on_quit_pressed()`]

### Settings System
160) Audio sliders adjust volume levels [**PauseMenu.gd**: volume slider callbacks]
161) Settings changes saved to SettingsManager [**SettingsManager.gd**: setting persistence]
162) Back button returns to main pause menu [**PauseMenu.gd**: `_on_back_pressed()`]

### Confirmation Dialogs
163) Quit confirmation explains death recording [**PauseMenu.gd**: quit dialog text]
164) Main menu confirmation warns about run termination [**PauseMenu.gd**: main menu dialog]
165) Confirmation triggers death recording [**PauseMenu.gd**: `_on_quit_confirmed()` and `_on_main_menu_confirmed()`]
166) GameController handles termination [**GameController.gd**: `_terminate_subject()`]

## DEATH AND GAME END SYSTEMS

### Player Death Triggers
167) Health reaches 0 [**Player.gd**: `take_damage()` and health check]
168) Sanity reaches 0 [**GameStateManager.gd**: `modify_sanity()` and threshold check]
169) Stalker collision [**Stalker.gd**: `_trigger_player_caught()`]
170) Force quit detection [**Player.gd**: `_notification(NOTIFICATION_WM_CLOSE_REQUEST)`]
171) Voluntary quit/menu return [**PauseMenu.gd**: confirmation dialogs]

### Death Processing
172) Death cause determined and recorded [**Player.gd**: `die()` or other death triggers]
173) Current tile position retrieved [**GameStateManager.gd**: `get_state("current_tile_position")`]
174) Death data compiled with position, cause, inventory [death processing scripts]
175) Player death event emitted [**MessageBus**: `emit_event("player_died")`]
176) Mouse released and input disabled [**Player.gd**: `die()`]

### Death Location Recording
177) Death location recorded in GameStateManager [**GameStateManager.gd**: `record_death_location()`]
178) Player inventory retrieved and stored [**GameStateManager.gd**: inventory processing]
179) Special handling for start tile (0,0) deaths [**GameStateManager.gd**: adjacent tile distribution]
180) Death data added to persistent death locations [**GameStateManager.gd**: death tracking]
181) Save data updated with death count [**SaveManager.gd**: `record_death()`]
182) Run marked as inactive in save data [**SaveManager.gd**: run state update]

### Permanent Tile Movement
**NOTE**: This system is planned but not currently implemented. When implemented, it should:
183) Check each permanent tile for movement chance [**GameStateManager.gd**: planned permanent tile logic]
184) 50% chance for each permanent tile to stay in place [planned movement system]
185) If moving, equal chance for each direction (N/E/S/W) [planned movement system]
186) New permanent tile positions saved for next run [planned persistence system]

### Scene Transition
187) GameController receives death event [**GameController.gd**: `_on_player_died()`]
188) Death screen trigger initiated [**GameController.gd**: `trigger_death()`]
189) UI elements hidden [**GameController.gd**: UI cleanup]
190) Fade out transition begins [**GameController.gd**: `fade_out()`]
191) Scene changes to death screen [**SceneManager.gd**: `load_death_screen()`]

### Death Screen Display
192) Death screen scene loads with death type [**SceneManager.gd**: death screen instantiation]
193) Death message displayed based on cause [**DeathScreen.gd**: message display]
194) Statistics shown (deaths, time played, etc.) [**DeathScreen.gd**: stats display]
195) Continue button returns to main menu [**DeathScreen.gd**: continue button]
196) Game loop ends, awaiting new game start [main menu return]

## LOOP CONTINUATION CONDITIONS

The core game loop (steps 43-196) repeats continuously while the player is alive and active:
- **Loop continues if**: Player is alive (health > 0), sanity > 0, and no death triggers activated
- **Loop breaks if**: Any death condition met (health ≤ 0, sanity ≤ 0, stalker collision, force quit, voluntary termination)
- **Tile entry loop** (steps 47-104) repeats each time player enters a new tile
- **Spawning loop** (steps 70-104) executes once per new tile generation
- **Entity behavior loops** (steps 135-152) run continuously while entities are active
- **Input processing loops** (steps 105-134, 153-166) run every frame while game is active
- **Flashlight sanity drain** (steps 112-116) processes continuously while in darkness

## IMPLEMENTATION NOTES

### Currently Implemented Systems
- All autoload initialization and core game loop
- Tile generation, connection, and cleanup systems with crash protection
- Player movement, interaction, and death mechanics
- Enhanced flashlight system with sanity drain mechanics
- Entity behavior (Effigy, Stalker, Watcher) with sanity-based states
- New entity spawning formula with exploration/collection bonuses
- Proper tiles explored and weird things collected tracking
- Death location recording and backpack spawning
- UI systems (pause menu, inventory, death screen)
- Save/load functionality with run state tracking

### Planned But Not Implemented
- **Permanent tile movement system**: 50% chance movement logic needs implementation in GameStateManager
- **Advanced door alignment**: TileManager door connection logic needs verification
- **Entity scene files**: Missing effigy.tscn and watcher.tscn causing placeholder spawns
- **Puzzle tile system**: Permanent tiles with puzzle IDs need full implementation
- **Advanced maze shifting**: GameDirector maze shift timing needs completion

### System Dependencies
- All systems depend on MessageBus for event communication
- GameStateManager serves as central state authority
- TileManager coordinates with TileStateManager for tile lifecycle
- SpawnManager coordinates with ItemManager and EnemyManager for spawning decisions
- Player death triggers cascade through multiple systems for proper cleanup
