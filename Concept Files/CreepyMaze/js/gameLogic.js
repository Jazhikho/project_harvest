// Main game logic
import { generateMaze, changeMazePart } from './mazeGenerator.js';
import { Player } from './player.js';
import { drawMaze, drawPlayer, drawWeirdThings } from './renderer.js';
import { WeirdThings, getWeirdMessage, applyWeirdEffect } from './weirdThings.js';
import { updateVisibility } from './utils.js';

export class Game {
    constructor() {
        this.maze = [];
        this.player = new Player();
        this.weirdThings = new WeirdThings();
        this.weirdFindings = 0;
        this.gameOver = false;
        this.visibleCells = {};
        this.lastMazeChange = 0;
        this.mazeChangeInterval = 30000;
        this.fogOfWar = true;
        this.storyProgress = 0;
        this.mazeExit = { x: 0, y: 0 };
        this.mazeExitTrigger = { x: 0, y: 0 };
        this.canvas = null;
        this.ctx = null;
        this.messageOverlay = null;
        
        console.log("Game object constructed");
    }
    
    init() {
        console.log("Initializing game");
        // Initialize DOM elements first
        try {
            this.canvas = document.getElementById('gameCanvas');
            if (!this.canvas) {
                throw new Error('Canvas element not found');
            }
            
            this.ctx = this.canvas.getContext('2d');
            if (!this.ctx) {
                throw new Error('Canvas context not available');
            }
            
            this.messageOverlay = document.getElementById('message-overlay');
            if (!this.messageOverlay) {
                throw new Error('Message overlay element not found');
            }
            
            console.log("DOM elements initialized successfully");
        } catch (error) {
            console.error("Error initializing DOM elements:", error);
            return;
        }
        
        // Now initialize game state
        try {
            generateMaze(this.maze);
            this.weirdThings.placeWeirdThings(this.maze, this.player);
            this.placeExit();
            
            // Set up event listeners
            document.addEventListener('keydown', (e) => this.handleKeyDown(e));
            document.addEventListener('mousemove', window.handleMouseMove);
            
            // Show initial message
            this.showMessage("You wake up in an unfamiliar place. The darkness feels... alive. Your flashlight reveals just enough to navigate. Find the exit, but beware what lurks in this maze...");
            
            // Start the game loop
            console.log("Starting game loop");
            requestAnimationFrame(() => this.gameLoop());
            
        } catch (error) {
            console.error("Error initializing game state:", error);
        }
    }

    handleKeyDown(event) {
        if (this.gameOver || parseFloat(this.messageOverlay.style.opacity || 0) > 0) return;
        if (this.player.move(event.key, this.maze)) {
            updateVisibility(this.player, this.maze, this.visibleCells);
            
            // Check for exit or jumpscare trigger
            this.checkExitTrigger();
            
            // Only do these checks if the game is still running
            if (!this.gameOver) {
                // Check for weird things
                this.checkWeirdThings();
                
                // Check if it's time to change the maze
                this.checkMazeChange();
                
                // Progress the narrative based on exploration
                this.progressNarrative();
            }
        }
    }

    gameLoop() {
        try {
            if (!this.ctx || !this.canvas || this.gameOver) {
                return;
            }
            
            drawMaze(this.ctx, this.maze, this.player, this.fogOfWar, this.visibleCells);
            drawPlayer(this.ctx, this.player);
            drawWeirdThings(this.ctx, this.weirdThings.items, this.fogOfWar, this.visibleCells);
            
            // Continue the game loop
            requestAnimationFrame(() => this.gameLoop());
        } catch (error) {
            console.error("Error in game loop:", error);
        }
    }

    // Check for weird things at the player's position
    checkWeirdThings() {
        const weirdThing = this.weirdThings.getWeirdThingAt(this.player.x, this.player.y);
        
        if (weirdThing && !weirdThing.found) {
            weirdThing.found = true;
            this.weirdFindings++;
            
            // Update the counter
            document.getElementById('counter').textContent = this.weirdFindings;
            
            // Show a message
            this.showMessage(getWeirdMessage(weirdThing.type));
            
            // Apply a weird effect
            const fogOfWarRef = { value: this.fogOfWar };
            applyWeirdEffect(
                weirdThing.type, 
                this.canvas, 
                () => changeMazePart(this.maze, this.player.x, this.player.y),
                fogOfWarRef
            );
            this.fogOfWar = fogOfWarRef.value;
        }
    }

    // Trigger the jumpscare effect
    triggerJumpscare() {
        // Play a sound (if available)
        // Set game over flag
        this.gameOver = true;
        
        // Show the jumpscare overlay
        const jumpscare = document.getElementById('jumpscare-overlay');
        const jumpscareSound = new Audio('data:audio/wav;base64,UklGRjIAAABXQVZFZm10IBIAAAABAAEAQB8AAEAfAAABAAgAAABMYXZmNTkuMzIuMTAzAAAAAAAAAAAAAA==');
        
        // Flash the jumpscare
        jumpscare.style.opacity = '1';
        
        // Try to play sound
        try {
            jumpscareSound.play();
        } catch (e) {
            console.log("Sound couldn't play, continuing without sound");
        }
        
        // Shake the screen
        const gameContainer = document.getElementById('game-container');
        gameContainer.style.animation = 'shake 0.5s';
        
        // Apply fast flashing
        this.canvas.style.animation = 'flash 0.1s infinite';
        
        // Stop the animations and keep showing the jumpscare
        setTimeout(() => {
            gameContainer.style.animation = '';
            this.canvas.style.animation = '';
            // Keep the jumpscare visible
        }, 1000);
    }

    // Show a message overlay
    showMessage(message) {
        const messageContent = document.getElementById('message-content');
        messageContent.textContent = message;
        this.messageOverlay.style.opacity = '1';
        this.messageOverlay.classList.add('pulse');
        
        setTimeout(() => {
            this.messageOverlay.style.opacity = '0';
            this.messageOverlay.classList.remove('pulse');
        }, 3000);
    }

    // Place the exit and the trigger for the jumpscare
    placeExit() {
        // Place the exit far from the player's starting position
        let attempts = 0;
        do {
            this.mazeExit.x = 20 - 2 - Math.floor(Math.random() * 3);
            this.mazeExit.y = 20 - 2 - Math.floor(Math.random() * 3);
            attempts++;
        } while ((Math.abs(this.mazeExit.x - this.player.x) < 10 || 
                Math.abs(this.mazeExit.y - this.player.y) < 10) && attempts < 20);
        
        // Create a path to the exit
        let x = this.mazeExit.x, y = this.mazeExit.y;
        while (x > 1 || y > 1) {
            if (x > 1 && Math.random() < 0.5) {
                this.maze[y][x].walls.left = false;
                this.maze[y][x-1].walls.right = false;
                x--;
            } else if (y > 1) {
                this.maze[y][x].walls.top = false;
                this.maze[y-1][x].walls.bottom = false;
                y--;
            } else if (x > 1) {
                this.maze[y][x].walls.left = false;
                this.maze[y][x-1].walls.right = false;
                x--;
            }
        }
        
        // Place the trigger one step away from the exit
        // Determine which direction to place the trigger based on the walls
        if (!this.maze[this.mazeExit.y][this.mazeExit.x].walls.left) {
            this.mazeExitTrigger.x = this.mazeExit.x - 1;
            this.mazeExitTrigger.y = this.mazeExit.y;
        } else if (!this.maze[this.mazeExit.y][this.mazeExit.x].walls.top) {
            this.mazeExitTrigger.x = this.mazeExit.x;
            this.mazeExitTrigger.y = this.mazeExit.y - 1;
        } else if (!this.maze[this.mazeExit.y][this.mazeExit.x].walls.right) {
            this.mazeExitTrigger.x = this.mazeExit.x + 1;
            this.mazeExitTrigger.y = this.mazeExit.y;
        } else {
            this.mazeExitTrigger.x = this.mazeExit.x;
            this.mazeExitTrigger.y = this.mazeExit.y + 1;
        }
    }

    // Check if the player has reached the exit trigger or exit
    checkExitTrigger() {
        // If player is at the exit trigger position
        if (this.player.x === this.mazeExitTrigger.x && this.player.y === this.mazeExitTrigger.y) {
            // Trigger the jumpscare
            this.triggerJumpscare();
        }
        
        // If player is at the actual exit
        if (this.player.x === this.mazeExit.x && this.player.y === this.mazeExit.y) {
            // Show game over with different message
            this.showMessage("You've reached the exit, but at what cost? The darkness lingers...");
            setTimeout(() => {
                this.showGameOver();
            }, 2000);
        }
    }
    
    // Show game over screen
    showGameOver() {
        const jumpscare = document.getElementById('jumpscare-overlay');
        jumpscare.style.opacity = '1';
        this.gameOver = true;
    }

    // Progress the narrative based on exploration and findings
    progressNarrative() {
        // Base narrative progression on number of weird findings and exploration progress
        if (this.weirdFindings === 3 && this.storyProgress === 0) {
            this.showMessage("The objects seem connected somehow. Your head begins to ache as whispers grow louder...");
            this.storyProgress = 1;
        } else if (this.weirdFindings >= 5 && this.storyProgress === 1) {
            this.showMessage("Something's following you. Don't look back. Find the exit BEFORE it finds you.");
            this.storyProgress = 2;
            
            // Make the maze start changing more frequently
            this.mazeChangeInterval = 15000;
        }
        
        // Random narrative moments
        if (Math.random() < 0.01 && this.storyProgress >= 1) {
            const narrativeMessages = [
                "Was that shadow there before?",
                "The air feels colder here.",
                "You hear faint scratching sounds from the walls.",
                "Something whispers your name from behind you.",
                "The walls seem to breathe."
            ];
            
            this.showMessage(narrativeMessages[Math.floor(Math.random() * narrativeMessages.length)]);
        }
    }

    // Check if it's time to change the maze
    checkMazeChange() {
        const currentTime = Date.now();
        
        if (currentTime - this.lastMazeChange > this.mazeChangeInterval) {
            this.lastMazeChange = currentTime;
            
            // Show a message
            this.showMessage("The maze shifts around you...");
            
            // Change part of the maze
            setTimeout(() => {
                // Make sure player position isn't changed
                let oldPlayerX = this.player.x;
                let oldPlayerY = this.player.y;
                
                // Regenerate a small part of the maze or change some walls
                if (Math.random() < 0.3) {
                    // Major change - regenerate the maze but keep player position
                    generateMaze(this.maze);
                    this.player.x = oldPlayerX;
                    this.player.y = oldPlayerY;
                } else {
                    // Minor change - just change some walls
                    for (let i = 0; i < 5; i++) {
                        changeMazePart(this.maze, this.player.x, this.player.y);
                    }
                }
                
                // Place new weird things
                this.weirdThings.placeWeirdThings(this.maze, this.player);
            }, 1000);
        }
    }
} 