import MazeModel from '../models/MazeModel.js';
import PlayerModel from '../models/PlayerModel.js';
import WeirdThingsModel from '../models/WeirdThingsModel.js';
import GameStateModel from '../models/GameStateModel.js';
import MazeRenderer from '../views/MazeRenderer.js';
import PlayerRenderer from '../views/PlayerRenderer.js';
import WeirdThingsRenderer from '../views/WeirdThingsRenderer.js';
import UIController from './UIController.js';

class GameController {
    constructor(canvas, counterElement, messageOverlay, messageContent, jumpscareFace) {
        // Constants
        this.GRID_WIDTH = 20;
        this.GRID_HEIGHT = 20;
        this.CELL_SIZE = 30;
        
        // Models
        this.mazeModel = new MazeModel(this.GRID_WIDTH, this.GRID_HEIGHT, this.CELL_SIZE);
        this.playerModel = new PlayerModel();
        this.weirdThingsModel = new WeirdThingsModel();
        this.gameState = new GameStateModel();
        
        // Renderers
        this.ctx = canvas.getContext('2d');
        this.mazeRenderer = new MazeRenderer(this.ctx, this.CELL_SIZE);
        this.playerRenderer = new PlayerRenderer(this.ctx, this.CELL_SIZE);
        this.weirdThingsRenderer = new WeirdThingsRenderer(this.ctx, this.CELL_SIZE);
        
        // UI Controller
        this.uiController = new UIController(counterElement, messageOverlay, messageContent, jumpscareFace);
        
        // Input handlers
        this.setupEventListeners();
    }
    
    initGame() {
        // Generate the maze
        this.mazeModel.generateMaze();
        
        // Place the exit
        this.mazeModel.placeExit(this.playerModel.x, this.playerModel.y);
        
        // Place weird things
        this.weirdThingsModel.placeWeirdThings(
            this.GRID_WIDTH, 
            this.GRID_HEIGHT,
            this.playerModel.x,
            this.playerModel.y
        );
        
        // Show initial message
        this.uiController.showMessage("You wake up in an unfamiliar place. The darkness feels... alive. Your flashlight reveals just enough to navigate. Find the exit, but beware what lurks in this maze...");
        
        // Start the game loop
        this.gameLoop();
    }
    
    setupEventListeners() {
        // Handle keyboard input
        document.addEventListener('keydown', this.handleKeyDown.bind(this));
        
        // Handle mouse movement for custom cursor
        document.addEventListener('mousemove', this.uiController.handleMouseMove.bind(this.uiController));
    }
    
    handleKeyDown(event) {
        // Don't handle input if message is showing or if game is over
        if (this.uiController.isMessageShowing() || this.gameState.isGameOver()) {
            return;
        }
        
        let moved = false;
        
        switch (event.key) {
            case 'ArrowUp':
                moved = this.playerModel.moveUp(this.mazeModel.maze);
                break;
            case 'ArrowRight':
                moved = this.playerModel.moveRight(this.mazeModel.maze);
                break;
            case 'ArrowDown':
                moved = this.playerModel.moveDown(this.mazeModel.maze);
                break;
            case 'ArrowLeft':
                moved = this.playerModel.moveLeft(this.mazeModel.maze);
                break;
        }
        
        // If the player moved, update the game state
        if (moved) {
            // Mark current position as visited (for fog of war)
            this.mazeModel.updateVisibility(this.playerModel.x, this.playerModel.y);
            
            // Check for exit or jumpscare trigger
            this.checkExitTrigger();
            
            // Only do these checks if the game is still running
            if (!this.gameState.isGameOver()) {
                // Check for weird things
                this.checkWeirdThings();
                
                // Check if it's time to change the maze
                this.checkMazeChange();
                
                // Progress the narrative based on exploration
                this.progressNarrative();
            }
        }
    }
    
    checkExitTrigger() {
        const playerPos = this.playerModel.getPosition();
        
        // If player is at the exit trigger position
        if (playerPos.x === this.mazeModel.mazeExitTrigger.x && 
            playerPos.y === this.mazeModel.mazeExitTrigger.y) {
            // Trigger the jumpscare
            this.triggerJumpscare();
        }
        
        // If player is at the actual exit
        if (playerPos.x === this.mazeModel.mazeExit.x && 
            playerPos.y === this.mazeModel.mazeExit.y) {
            // Show game over with different message
            this.uiController.showMessage("You've reached the exit, but at what cost? The darkness lingers...");
            setTimeout(() => {
                this.showGameOver();
            }, 2000);
        }
    }
    
    triggerJumpscare() {
        // Set game over flag
        this.gameState.setGameOver();
        
        // Show the jumpscare via UI controller
        this.uiController.triggerJumpscare();
    }
    
    showGameOver() {
        this.uiController.showGameOver();
        this.gameState.setGameOver();
    }
    
    checkWeirdThings() {
        const playerPos = this.playerModel.getPosition();
        const result = this.weirdThingsModel.findWeirdThing(playerPos.x, playerPos.y);
        
        if (result.found) {
            // Update the counter
            this.uiController.updateCounter(this.weirdThingsModel.getWeirdFindings());
            
            // Show a message
            this.uiController.showMessage(result.message);
            
            // Apply a weird effect
            this.applyWeirdEffect(result.type);
        }
    }
    
    applyWeirdEffect(type) {
        switch (type) {
            case 0: // Brief flicker
                this.uiController.applyFlickerEffect();
                break;
            case 1: // Maze slightly changes
                this.mazeModel.changeMazePart();
                break;
            case 2: // Fog of war temporarily removed
                const fogBackup = this.mazeModel.fogOfWar;
                this.mazeModel.setFogOfWar(false);
                setTimeout(() => {
                    this.mazeModel.setFogOfWar(fogBackup);
                }, 3000);
                break;
            case 3: // Distorted view
                this.uiController.applyDistortionEffect();
                break;
            case 4: // Something follows you
                // This will be handled in the game loop
                break;
        }
    }
    
    checkMazeChange() {
        if (this.mazeModel.shouldChangeMaze()) {
            // Update the lastMazeChange time
            this.mazeModel.lastMazeChange = Date.now();
            
            // Show a message
            this.uiController.showMessage("The maze shifts around you...");
            
            // Change part of the maze
            setTimeout(() => {
                // Make sure player position isn't changed
                let oldPlayerX = this.playerModel.x;
                let oldPlayerY = this.playerModel.y;
                
                // Regenerate a small part of the maze or change some walls
                if (Math.random() < 0.3) {
                    // Major change - regenerate the maze but keep player position
                    this.mazeModel.generateMaze();
                    this.playerModel.setPosition(oldPlayerX, oldPlayerY);
                } else {
                    // Minor change - just change some walls
                    for (let i = 0; i < 5; i++) {
                        this.mazeModel.changeMazePart();
                    }
                }
                
                // Place new weird things
                this.weirdThingsModel.placeWeirdThings(
                    this.GRID_WIDTH, 
                    this.GRID_HEIGHT,
                    this.playerModel.x,
                    this.playerModel.y
                );
            }, 1000);
        }
    }
    
    progressNarrative() {
        // Progress story based on weird findings
        const storyUpdate = this.gameState.progressStoryBasedOnFindings(
            this.weirdThingsModel.getWeirdFindings()
        );
        
        if (storyUpdate.changed) {
            this.uiController.showMessage(this.gameState.getNarrativeMessage());
            
            // Make the maze start changing more frequently if story progressed to level 2
            if (storyUpdate.storyProgress === 2) {
                this.mazeModel.updateMazeChangeInterval(15000);
            }
        }
        
        // Check for random narrative moments
        const randomMessage = this.gameState.getRandomNarrativeMoment();
        if (randomMessage) {
            this.uiController.showMessage(randomMessage);
        }
    }
    
    gameLoop() {
        // Clear the canvas
        this.ctx.clearRect(0, 0, this.GRID_WIDTH * this.CELL_SIZE, this.GRID_HEIGHT * this.CELL_SIZE);
        
        // Draw the maze
        this.mazeRenderer.drawMaze(
            this.mazeModel.maze, 
            this.mazeModel.fogOfWar, 
            this.mazeModel.visibleCells, 
            this.playerModel.getPosition()
        );
        
        // Draw the player
        this.playerRenderer.drawPlayer(this.playerModel.getPosition());
        
        // Draw weird things
        this.weirdThingsRenderer.drawWeirdThings(
            this.weirdThingsModel.weirdThings, 
            this.mazeModel.fogOfWar, 
            this.mazeModel.visibleCells
        );
        
        // Request the next frame
        requestAnimationFrame(this.gameLoop.bind(this));
    }
}

export default GameController; 