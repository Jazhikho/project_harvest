class WeirdThingsRenderer {
    constructor(ctx, cellSize) {
        this.ctx = ctx;
        this.cellSize = cellSize;
    }
    
    drawWeirdThings(weirdThings, fogOfWar, visibleCells) {
        weirdThings.forEach(thing => {
            // Skip if the thing has been found or is not visible
            if (thing.found || (fogOfWar && !visibleCells[`${thing.x},${thing.y}`])) {
                return;
            }
            
            const centerX = thing.x * this.cellSize + this.cellSize / 2;
            const centerY = thing.y * this.cellSize + this.cellSize / 2;
            const size = this.cellSize * 0.4;
            
            // Draw based on type
            switch (thing.type) {
                case 0: // Doll
                    this.drawDoll(centerX, centerY, size);
                    break;
                    
                case 1: // Music box
                    this.drawMusicBox(centerX, centerY, size);
                    break;
                    
                case 2: // Mirror
                    this.drawMirror(centerX, centerY, size);
                    break;
                    
                case 3: // Symbols
                    this.drawSymbols(centerX, centerY, size);
                    break;
                    
                case 4: // Pocket watch
                    this.drawPocketWatch(centerX, centerY, size);
                    break;
            }
        });
    }
    
    drawDoll(centerX, centerY, size) {
        this.ctx.fillStyle = '#d68c78';
        this.ctx.beginPath();
        this.ctx.arc(centerX, centerY - size * 0.3, size * 0.4, 0, Math.PI * 2); // Head
        this.ctx.fill();
        
        this.ctx.fillStyle = '#a33';
        this.ctx.fillRect(centerX - size * 0.3, centerY, size * 0.6, size * 0.8); // Body
    }
    
    drawMusicBox(centerX, centerY, size) {
        this.ctx.fillStyle = '#a30';
        this.ctx.fillRect(centerX - size * 0.5, centerY - size * 0.3, size, size * 0.6); // Box
        
        this.ctx.strokeStyle = '#dd0';
        this.ctx.beginPath();
        this.ctx.arc(centerX, centerY - size * 0.3, size * 0.3, 0, Math.PI, true); // Handle
        this.ctx.stroke();
    }
    
    drawMirror(centerX, centerY, size) {
        this.ctx.fillStyle = '#777';
        this.ctx.fillRect(centerX - size * 0.4, centerY - size * 0.6, size * 0.8, size * 1.2); // Frame
        
        this.ctx.fillStyle = '#acd';
        this.ctx.fillRect(centerX - size * 0.3, centerY - size * 0.5, size * 0.6, size); // Glass
    }
    
    drawSymbols(centerX, centerY, size) {
        this.ctx.fillStyle = '#550';
        
        // Draw random symbols
        for (let i = 0; i < 5; i++) {
            const symbolX = centerX + (Math.random() - 0.5) * size;
            const symbolY = centerY + (Math.random() - 0.5) * size;
            
            this.ctx.beginPath();
            if (i % 2 === 0) {
                this.ctx.arc(symbolX, symbolY, size * 0.15, 0, Math.PI * 2);
            } else {
                this.ctx.moveTo(symbolX, symbolY - size * 0.15);
                this.ctx.lineTo(symbolX + size * 0.15, symbolY + size * 0.15);
                this.ctx.lineTo(symbolX - size * 0.15, symbolY + size * 0.15);
                this.ctx.closePath();
            }
            this.ctx.fill();
        }
    }
    
    drawPocketWatch(centerX, centerY, size) {
        this.ctx.fillStyle = '#cb8';
        this.ctx.beginPath();
        this.ctx.arc(centerX, centerY, size * 0.5, 0, Math.PI * 2); // Watch body
        this.ctx.fill();
        
        this.ctx.strokeStyle = '#333';
        this.ctx.beginPath();
        this.ctx.moveTo(centerX, centerY);
        this.ctx.lineTo(centerX, centerY - size * 0.3); // Hour hand
        this.ctx.moveTo(centerX, centerY);
        this.ctx.lineTo(centerX + size * 0.2, centerY); // Minute hand
        this.ctx.stroke();
    }
}

export default WeirdThingsRenderer; 