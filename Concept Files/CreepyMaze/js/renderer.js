// Rendering logic
const CELL_SIZE = 30;
const CANVAS_WIDTH = CELL_SIZE * 20;
const CANVAS_HEIGHT = CELL_SIZE * 20;

export function drawMaze(ctx, maze, player, fogOfWar, visibleCells) {
    ctx.clearRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);
    ctx.strokeStyle = '#8a0303';
    ctx.lineWidth = 2;
    for (let y = 0; y < 20; y++) {
        for (let x = 0; x < 20; x++) {
            if (fogOfWar && !visibleCells[`${x},${y}`]) continue;
            const distance = Math.sqrt(Math.pow(x - player.x, 2) + Math.pow(y - player.y, 2));
            const alpha = fogOfWar ? Math.max(0, 1 - distance / 5) : 1;
            const cellX = x * CELL_SIZE;
            const cellY = y * CELL_SIZE;
            ctx.fillStyle = `rgba(20, 20, 20, ${alpha})`;
            ctx.fillRect(cellX, cellY, CELL_SIZE, CELL_SIZE);
            const cell = maze[y][x];
            if (cell.walls.top) { ctx.beginPath(); ctx.moveTo(cellX, cellY); ctx.lineTo(cellX + CELL_SIZE, cellY); ctx.stroke(); }
            if (cell.walls.right) { ctx.beginPath(); ctx.moveTo(cellX + CELL_SIZE, cellY); ctx.lineTo(cellX + CELL_SIZE, cellY + CELL_SIZE); ctx.stroke(); }
            if (cell.walls.bottom) { ctx.beginPath(); ctx.moveTo(cellX, cellY + CELL_SIZE); ctx.lineTo(cellX + CELL_SIZE, cellY + CELL_SIZE); ctx.stroke(); }
            if (cell.walls.left) { ctx.beginPath(); ctx.moveTo(cellX, cellY); ctx.lineTo(cellX, cellY + CELL_SIZE); ctx.stroke(); }
        }
    }
}

// Draw the player
export function drawPlayer(ctx, player) {
    const centerX = player.x * CELL_SIZE + CELL_SIZE / 2;
    const centerY = player.y * CELL_SIZE + CELL_SIZE / 2;
    const radius = CELL_SIZE / 3;
    
    // Draw player circle
    ctx.beginPath();
    ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
    ctx.fillStyle = '#aaa';
    ctx.fill();
    ctx.strokeStyle = '#555';
    ctx.lineWidth = 1;
    ctx.stroke();
    
    // Draw eyes
    const eyeOffset = radius * 0.4;
    const eyeRadius = radius * 0.2;
    
    ctx.beginPath();
    ctx.arc(centerX - eyeOffset, centerY - eyeOffset, eyeRadius, 0, Math.PI * 2);
    ctx.arc(centerX + eyeOffset, centerY - eyeOffset, eyeRadius, 0, Math.PI * 2);
    ctx.fillStyle = '#000';
    ctx.fill();
}

// Draw weird things
export function drawWeirdThings(ctx, weirdThings, fogOfWar, visibleCells) {
    weirdThings.forEach(thing => {
        // Skip if the thing has been found or is not visible
        if (thing.found || (fogOfWar && !visibleCells[`${thing.x},${thing.y}`])) {
            return;
        }
        
        const centerX = thing.x * CELL_SIZE + CELL_SIZE / 2;
        const centerY = thing.y * CELL_SIZE + CELL_SIZE / 2;
        const size = CELL_SIZE * 0.4;
        
        // Draw based on type
        switch (thing.type) {
            case 0: // Doll
                ctx.fillStyle = '#d68c78';
                ctx.beginPath();
                ctx.arc(centerX, centerY - size * 0.3, size * 0.4, 0, Math.PI * 2); // Head
                ctx.fill();
                
                ctx.fillStyle = '#a33';
                ctx.fillRect(centerX - size * 0.3, centerY, size * 0.6, size * 0.8); // Body
                break;
                
            case 1: // Music box
                ctx.fillStyle = '#a30';
                ctx.fillRect(centerX - size * 0.5, centerY - size * 0.3, size, size * 0.6); // Box
                
                ctx.strokeStyle = '#dd0';
                ctx.beginPath();
                ctx.arc(centerX, centerY - size * 0.3, size * 0.3, 0, Math.PI, true); // Handle
                ctx.stroke();
                break;
                
            case 2: // Mirror
                ctx.fillStyle = '#777';
                ctx.fillRect(centerX - size * 0.4, centerY - size * 0.6, size * 0.8, size * 1.2); // Frame
                
                ctx.fillStyle = '#acd';
                ctx.fillRect(centerX - size * 0.3, centerY - size * 0.5, size * 0.6, size); // Glass
                break;
                
            case 3: // Symbols
                ctx.fillStyle = '#550';
                
                // Draw random symbols
                for (let i = 0; i < 5; i++) {
                    const symbolX = centerX + (Math.random() - 0.5) * size;
                    const symbolY = centerY + (Math.random() - 0.5) * size;
                    
                    ctx.beginPath();
                    if (i % 2 === 0) {
                        ctx.arc(symbolX, symbolY, size * 0.15, 0, Math.PI * 2);
                    } else {
                        ctx.moveTo(symbolX, symbolY - size * 0.15);
                        ctx.lineTo(symbolX + size * 0.15, symbolY + size * 0.15);
                        ctx.lineTo(symbolX - size * 0.15, symbolY + size * 0.15);
                        ctx.closePath();
                    }
                    ctx.fill();
                }
                break;
                
            case 4: // Pocket watch
                ctx.fillStyle = '#cb8';
                ctx.beginPath();
                ctx.arc(centerX, centerY, size * 0.5, 0, Math.PI * 2); // Watch body
                ctx.fill();
                
                ctx.strokeStyle = '#333';
                ctx.beginPath();
                ctx.moveTo(centerX, centerY);
                ctx.lineTo(centerX, centerY - size * 0.3); // Hour hand
                ctx.moveTo(centerX, centerY);
                ctx.lineTo(centerX + size * 0.2, centerY); // Minute hand
                ctx.stroke();
                break;
        }
    });
} 