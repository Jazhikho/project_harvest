class MazeRenderer {
    constructor(ctx, cellSize) {
        this.ctx = ctx;
        this.cellSize = cellSize;
    }
    
    drawMaze(maze, fogOfWar, visibleCells, playerPosition) {
        // Set the line style
        this.ctx.strokeStyle = '#8a0303';
        this.ctx.lineWidth = 2;
        
        // Draw each cell
        for (let y = 0; y < maze.length; y++) {
            for (let x = 0; x < maze[y].length; x++) {
                // Skip if using fog of war and cell is not visible
                if (fogOfWar && !visibleCells[`${x},${y}`]) {
                    continue;
                }
                
                // Set the fill style based on distance from player for a gradient effect
                const distance = Math.sqrt(Math.pow(x - playerPosition.x, 2) + Math.pow(y - playerPosition.y, 2));
                const alpha = fogOfWar ? Math.max(0, 1 - distance / 5) : 1;
                
                // Cell position
                const cellX = x * this.cellSize;
                const cellY = y * this.cellSize;
                
                // Fill the cell with a dark color
                this.ctx.fillStyle = `rgba(20, 20, 20, ${alpha})`;
                this.ctx.fillRect(cellX, cellY, this.cellSize, this.cellSize);
                
                // Draw the walls
                const cell = maze[y][x];
                
                // Top wall
                if (cell.walls.top) {
                    this.ctx.beginPath();
                    this.ctx.moveTo(cellX, cellY);
                    this.ctx.lineTo(cellX + this.cellSize, cellY);
                    this.ctx.stroke();
                }
                
                // Right wall
                if (cell.walls.right) {
                    this.ctx.beginPath();
                    this.ctx.moveTo(cellX + this.cellSize, cellY);
                    this.ctx.lineTo(cellX + this.cellSize, cellY + this.cellSize);
                    this.ctx.stroke();
                }
                
                // Bottom wall
                if (cell.walls.bottom) {
                    this.ctx.beginPath();
                    this.ctx.moveTo(cellX, cellY + this.cellSize);
                    this.ctx.lineTo(cellX + this.cellSize, cellY + this.cellSize);
                    this.ctx.stroke();
                }
                
                // Left wall
                if (cell.walls.left) {
                    this.ctx.beginPath();
                    this.ctx.moveTo(cellX, cellY);
                    this.ctx.lineTo(cellX, cellY + this.cellSize);
                    this.ctx.stroke();
                }
            }
        }
    }
}

export default MazeRenderer; 