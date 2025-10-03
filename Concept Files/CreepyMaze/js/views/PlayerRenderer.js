class PlayerRenderer {
    constructor(ctx, cellSize) {
        this.ctx = ctx;
        this.cellSize = cellSize;
    }
    
    drawPlayer(position) {
        const centerX = position.x * this.cellSize + this.cellSize / 2;
        const centerY = position.y * this.cellSize + this.cellSize / 2;
        const radius = this.cellSize / 3;
        
        // Draw player circle
        this.ctx.beginPath();
        this.ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
        this.ctx.fillStyle = '#aaa';
        this.ctx.fill();
        this.ctx.strokeStyle = '#555';
        this.ctx.lineWidth = 1;
        this.ctx.stroke();
        
        // Draw eyes
        const eyeOffset = radius * 0.4;
        const eyeRadius = radius * 0.2;
        
        this.ctx.beginPath();
        this.ctx.arc(centerX - eyeOffset, centerY - eyeOffset, eyeRadius, 0, Math.PI * 2);
        this.ctx.arc(centerX + eyeOffset, centerY - eyeOffset, eyeRadius, 0, Math.PI * 2);
        this.ctx.fillStyle = '#000';
        this.ctx.fill();
    }
}

export default PlayerRenderer; 