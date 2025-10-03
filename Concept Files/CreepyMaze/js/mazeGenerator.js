// Maze generation and modification logic
const GRID_WIDTH = 20;
const GRID_HEIGHT = 20;

export function generateMaze(maze) {
    for (let y = 0; y < GRID_HEIGHT; y++) {
        maze[y] = [];
        for (let x = 0; x < GRID_WIDTH; x++) {
            maze[y][x] = { walls: { top: true, right: true, bottom: true, left: true }, visited: false };
        }
    }
    let startX = 1 + Math.floor(Math.random() * (GRID_WIDTH - 2));
    let startY = 1 + Math.floor(Math.random() * (GRID_HEIGHT - 2));
    maze[startY][startX].visited = true;
    let stack = [{ x: startX, y: startY }];
    while (stack.length > 0) {
        let current = stack[stack.length - 1];
        let neighbors = getUnvisitedNeighbors(current.x, current.y, maze);
        if (neighbors.length > 0) {
            let next = neighbors[Math.floor(Math.random() * neighbors.length)];
            removeWall(current, next, maze);
            maze[next.y][next.x].visited = true;
            stack.push(next);
        } else {
            stack.pop();
        }
    }
    for (let y = 0; y < GRID_HEIGHT; y++) {
        for (let x = 0; x < GRID_WIDTH; x++) {
            maze[y][x].visited = false;
        }
    }
    addCreepyPatterns(maze);
    return maze;
}

// Get all unvisited neighboring cells
function getUnvisitedNeighbors(x, y, maze) {
    let neighbors = [];
    
    // Check the cell above
    if (y > 0 && !maze[y-1][x].visited) {
        neighbors.push({ x: x, y: y-1, direction: 'top' });
    }
    
    // Check the cell to the right
    if (x < GRID_WIDTH - 1 && !maze[y][x+1].visited) {
        neighbors.push({ x: x+1, y: y, direction: 'right' });
    }
    
    // Check the cell below
    if (y < GRID_HEIGHT - 1 && !maze[y+1][x].visited) {
        neighbors.push({ x: x, y: y+1, direction: 'bottom' });
    }
    
    // Check the cell to the left
    if (x > 0 && !maze[y][x-1].visited) {
        neighbors.push({ x: x-1, y: y, direction: 'left' });
    }
    
    return neighbors;
}

// Remove the wall between two cells
function removeWall(cell1, cell2, maze) {
    if (cell1.y > cell2.y) {
        maze[cell1.y][cell1.x].walls.top = false;
        maze[cell2.y][cell2.x].walls.bottom = false;
    } else if (cell1.y < cell2.y) {
        maze[cell1.y][cell1.x].walls.bottom = false;
        maze[cell2.y][cell2.x].walls.top = false;
    } else if (cell1.x > cell2.x) {
        maze[cell1.y][cell1.x].walls.left = false;
        maze[cell2.y][cell2.x].walls.right = false;
    } else if (cell1.x < cell2.x) {
        maze[cell1.y][cell1.x].walls.right = false;
        maze[cell2.y][cell2.x].walls.left = false;
    }
}

// Add some creepy patterns to make the maze more interesting
function addCreepyPatterns(maze) {
    // Add some random "distorted" areas
    for (let i = 0; i < 3; i++) {
        let centerX = 4 + Math.floor(Math.random() * (GRID_WIDTH - 8));
        let centerY = 4 + Math.floor(Math.random() * (GRID_HEIGHT - 8));
        let radius = 2 + Math.floor(Math.random() * 2);
        
        for (let y = centerY - radius; y <= centerY + radius; y++) {
            for (let x = centerX - radius; x <= centerX + radius; x++) {
                if (y >= 0 && y < GRID_HEIGHT && x >= 0 && x < GRID_WIDTH) {
                    // Randomly remove or add walls in this area
                    if (Math.random() < 0.4) {
                        if (Math.random() < 0.5 && x > 0) {
                            maze[y][x].walls.left = !maze[y][x].walls.left;
                            maze[y][x-1].walls.right = maze[y][x].walls.left;
                        }
                        if (Math.random() < 0.5 && y > 0) {
                            maze[y][x].walls.top = !maze[y][x].walls.top;
                            maze[y-1][x].walls.bottom = maze[y][x].walls.top;
                        }
                    }
                }
            }
        }
    }
}

// Change a part of the maze
function changeMazePart(maze, playerX, playerY) {
    // Find an area to change
    let centerX = Math.max(3, Math.min(GRID_WIDTH - 3, playerX + (Math.random() < 0.5 ? -1 : 1) * (2 + Math.floor(Math.random() * 3))));
    let centerY = Math.max(3, Math.min(GRID_HEIGHT - 3, playerY + (Math.random() < 0.5 ? -1 : 1) * (2 + Math.floor(Math.random() * 3))));
    
    // Change some walls in a small area
    for (let y = centerY - 1; y <= centerY + 1; y++) {
        for (let x = centerX - 1; x <= centerX + 1; x++) {
            if (y >= 0 && y < GRID_HEIGHT && x >= 0 && x < GRID_WIDTH) {
                // Don't modify the outer walls
                if (y > 0 && x > 0 && y < GRID_HEIGHT - 1 && x < GRID_WIDTH - 1) {
                    // Randomly modify walls
                    if (Math.random() < 0.5) {
                        // Toggle a random wall
                        let wall = ['top', 'right', 'bottom', 'left'][Math.floor(Math.random() * 4)];
                        
                        // Toggle the wall and its neighbor's corresponding wall
                        let neighborX = x + (wall === 'right' ? 1 : (wall === 'left' ? -1 : 0));
                        let neighborY = y + (wall === 'bottom' ? 1 : (wall === 'top' ? -1 : 0));
                        
                        if (neighborY >= 0 && neighborY < GRID_HEIGHT && neighborX >= 0 && neighborX < GRID_WIDTH) {
                            maze[y][x].walls[wall] = !maze[y][x].walls[wall];
                            
                            // Update the neighbor's corresponding wall
                            let oppositeWall = {
                                'top': 'bottom',
                                'right': 'left',
                                'bottom': 'top',
                                'left': 'right'
                            }[wall];
                            
                            maze[neighborY][neighborX].walls[oppositeWall] = maze[y][x].walls[wall];
                        }
                    }
                }
            }
        }
    }
}

export { getUnvisitedNeighbors, removeWall, addCreepyPatterns, changeMazePart }; 