class MazeModel {
    constructor(width, height, cellSize) {
        this.width = width;
        this.height = height;
        this.cellSize = cellSize;
        this.maze = [];
        this.visibleCells = {};
        this.mazeExit = { x: 0, y: 0 };
        this.mazeExitTrigger = { x: 0, y: 0 };
        this.lastMazeChange = 0;
        this.mazeChangeInterval = 30000; // 30 seconds
        this.fogOfWar = true;
        
        this.initializeMaze();
    }
    
    initializeMaze() {
        // Initialize the maze grid
        for (let y = 0; y < this.height; y++) {
            this.maze[y] = [];
            for (let x = 0; x < this.width; x++) {
                this.maze[y][x] = {
                    walls: {
                        top: true,
                        right: true,
                        bottom: true,
                        left: true
                    },
                    visited: false
                };
            }
        }
    }
    
    generateMaze() {
        // Reset the maze
        this.initializeMaze();
        
        // Start from a random cell
        let startX = 1 + Math.floor(Math.random() * (this.width - 2));
        let startY = 1 + Math.floor(Math.random() * (this.height - 2));
        
        // Create a stack for backtracking
        let stack = [];
        
        // Mark the start cell as visited
        this.maze[startY][startX].visited = true;
        stack.push({ x: startX, y: startY });
        
        // Continue until the stack is empty
        while (stack.length > 0) {
            // Get the current cell
            let current = stack[stack.length - 1];
            
            // Find all unvisited neighbors
            let neighbors = this.getUnvisitedNeighbors(current.x, current.y);
            
            if (neighbors.length > 0) {
                // Choose a random neighbor
                let randomIndex = Math.floor(Math.random() * neighbors.length);
                let next = neighbors[randomIndex];
                
                // Remove the wall between the current cell and the chosen neighbor
                this.removeWall(current, next);
                
                // Mark the neighbor as visited
                this.maze[next.y][next.x].visited = true;
                
                // Push the neighbor to the stack
                stack.push(next);
            } else {
                // Backtrack
                stack.pop();
            }
        }
        
        // Reset visited flags for gameplay
        for (let y = 0; y < this.height; y++) {
            for (let x = 0; x < this.width; x++) {
                this.maze[y][x].visited = false;
            }
        }
        
        // Clear visibility data
        this.visibleCells = {};
        
        // Add creepy patterns
        this.addCreepyPatterns();
        
        this.lastMazeChange = Date.now();
    }
    
    getUnvisitedNeighbors(x, y) {
        let neighbors = [];
        
        // Check the cell above
        if (y > 0 && !this.maze[y-1][x].visited) {
            neighbors.push({ x: x, y: y-1, direction: 'top' });
        }
        
        // Check the cell to the right
        if (x < this.width - 1 && !this.maze[y][x+1].visited) {
            neighbors.push({ x: x+1, y: y, direction: 'right' });
        }
        
        // Check the cell below
        if (y < this.height - 1 && !this.maze[y+1][x].visited) {
            neighbors.push({ x: x, y: y+1, direction: 'bottom' });
        }
        
        // Check the cell to the left
        if (x > 0 && !this.maze[y][x-1].visited) {
            neighbors.push({ x: x-1, y: y, direction: 'left' });
        }
        
        return neighbors;
    }
    
    removeWall(cell1, cell2) {
        if (cell1.y > cell2.y) {
            this.maze[cell1.y][cell1.x].walls.top = false;
            this.maze[cell2.y][cell2.x].walls.bottom = false;
        } else if (cell1.y < cell2.y) {
            this.maze[cell1.y][cell1.x].walls.bottom = false;
            this.maze[cell2.y][cell2.x].walls.top = false;
        } else if (cell1.x > cell2.x) {
            this.maze[cell1.y][cell1.x].walls.left = false;
            this.maze[cell2.y][cell2.x].walls.right = false;
        } else if (cell1.x < cell2.x) {
            this.maze[cell1.y][cell1.x].walls.right = false;
            this.maze[cell2.y][cell2.x].walls.left = false;
        }
    }
    
    addCreepyPatterns() {
        // Add some random "distorted" areas
        for (let i = 0; i < 3; i++) {
            let centerX = 4 + Math.floor(Math.random() * (this.width - 8));
            let centerY = 4 + Math.floor(Math.random() * (this.height - 8));
            let radius = 2 + Math.floor(Math.random() * 2);
            
            for (let y = centerY - radius; y <= centerY + radius; y++) {
                for (let x = centerX - radius; x <= centerX + radius; x++) {
                    if (y >= 0 && y < this.height && x >= 0 && x < this.width) {
                        // Randomly remove or add walls in this area
                        if (Math.random() < 0.4) {
                            if (Math.random() < 0.5 && x > 0) {
                                this.maze[y][x].walls.left = !this.maze[y][x].walls.left;
                                this.maze[y][x-1].walls.right = this.maze[y][x].walls.left;
                            }
                            if (Math.random() < 0.5 && y > 0) {
                                this.maze[y][x].walls.top = !this.maze[y][x].walls.top;
                                this.maze[y-1][x].walls.bottom = this.maze[y][x].walls.top;
                            }
                        }
                    }
                }
            }
        }
    }
    
    changeMazePart() {
        // Find an area to change
        let centerX = Math.max(3, Math.min(this.width - 3, this.playerX + (Math.random() < 0.5 ? -1 : 1) * (2 + Math.floor(Math.random() * 3))));
        let centerY = Math.max(3, Math.min(this.height - 3, this.playerY + (Math.random() < 0.5 ? -1 : 1) * (2 + Math.floor(Math.random() * 3))));
        
        // Change some walls in a small area
        for (let y = centerY - 1; y <= centerY + 1; y++) {
            for (let x = centerX - 1; x <= centerX + 1; x++) {
                if (y >= 0 && y < this.height && x >= 0 && x < this.width) {
                    // Don't modify the outer walls
                    if (y > 0 && x > 0 && y < this.height - 1 && x < this.width - 1) {
                        // Randomly modify walls
                        if (Math.random() < 0.5) {
                            // Toggle a random wall
                            let wall = ['top', 'right', 'bottom', 'left'][Math.floor(Math.random() * 4)];
                            
                            // Toggle the wall and its neighbor's corresponding wall
                            let neighborX = x + (wall === 'right' ? 1 : (wall === 'left' ? -1 : 0));
                            let neighborY = y + (wall === 'bottom' ? 1 : (wall === 'top' ? -1 : 0));
                            
                            if (neighborY >= 0 && neighborY < this.height && neighborX >= 0 && neighborX < this.width) {
                                this.maze[y][x].walls[wall] = !this.maze[y][x].walls[wall];
                                
                                // Update the neighbor's corresponding wall
                                let oppositeWall = {
                                    'top': 'bottom',
                                    'right': 'left',
                                    'bottom': 'top',
                                    'left': 'right'
                                }[wall];
                                
                                this.maze[neighborY][neighborX].walls[oppositeWall] = this.maze[y][x].walls[wall];
                            }
                        }
                    }
                }
            }
        }
    }
    
    placeExit(playerX, playerY) {
        this.playerX = playerX;
        this.playerY = playerY;
        
        // Place the exit far from the player's starting position
        let attempts = 0;
        do {
            this.mazeExit.x = this.width - 2 - Math.floor(Math.random() * 3);
            this.mazeExit.y = this.height - 2 - Math.floor(Math.random() * 3);
            attempts++;
        } while ((Math.abs(this.mazeExit.x - playerX) < 10 || 
                  Math.abs(this.mazeExit.y - playerY) < 10) && attempts < 20);
        
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
    
    updateVisibility(playerX, playerY) {
        // Mark the current cell as visible
        this.visibleCells[`${playerX},${playerY}`] = true;
        
        // Mark adjacent cells as visible
        if (!this.maze[playerY][playerX].walls.top) {
            this.visibleCells[`${playerX},${playerY-1}`] = true;
        }
        if (!this.maze[playerY][playerX].walls.right) {
            this.visibleCells[`${playerX+1},${playerY}`] = true;
        }
        if (!this.maze[playerY][playerX].walls.bottom) {
            this.visibleCells[`${playerX},${playerY+1}`] = true;
        }
        if (!this.maze[playerY][playerX].walls.left) {
            this.visibleCells[`${playerX-1},${playerY}`] = true;
        }
    }
    
    shouldChangeMaze() {
        const currentTime = Date.now();
        return currentTime - this.lastMazeChange > this.mazeChangeInterval;
    }
    
    updateMazeChangeInterval(newInterval) {
        this.mazeChangeInterval = newInterval;
    }
    
    setFogOfWar(enabled) {
        this.fogOfWar = enabled;
    }
}

export default MazeModel; 