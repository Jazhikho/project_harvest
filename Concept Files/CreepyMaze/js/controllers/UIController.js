class UIController {
    constructor(counterElement, messageOverlay, messageContent, jumpscareFace) {
        this.counterElement = counterElement;
        this.messageOverlay = messageOverlay;
        this.messageContent = messageContent;
        this.jumpscareFace = jumpscareFace;
        this.canvas = document.getElementById('gameCanvas');
        this.cursor = document.getElementById('cursor');
        this.gameContainer = document.getElementById('game-container');
        this.jumpscare = document.getElementById('jumpscare-overlay');
    }
    
    showMessage(message) {
        this.messageContent.textContent = message;
        this.messageOverlay.style.opacity = '1';
        this.messageOverlay.classList.add('pulse');
        
        setTimeout(() => {
            this.messageOverlay.style.opacity = '0';
            this.messageOverlay.classList.remove('pulse');
        }, 3000);
    }
    
    isMessageShowing() {
        return parseFloat(this.messageOverlay.style.opacity || 0) > 0;
    }
    
    updateCounter(count) {
        this.counterElement.textContent = count;
    }
    
    handleMouseMove(event) {
        const rect = this.canvas.getBoundingClientRect();
        const x = event.clientX - rect.left;
        const y = event.clientY - rect.top;
        
        this.cursor.style.left = `${x}px`;
        this.cursor.style.top = `${y}px`;
    }
    
    triggerJumpscare() {
        // Play a sound (if available)
        const jumpscareSound = new Audio('data:audio/wav;base64,UklGRjIAAABXQVZFZm10IBIAAAABAAEAQB8AAEAfAAABAAgAAABMYXZmNTkuMzIuMTAzAAAAAAAAAAAAAA==');
        
        // Flash the jumpscare
        this.jumpscare.style.opacity = '1';
        
        // Try to play sound
        try {
            jumpscareSound.play();
        } catch (e) {
            console.log("Sound couldn't play, continuing without sound");
        }
        
        // Shake the screen
        this.gameContainer.style.animation = 'shake 0.5s';
        
        // Apply fast flashing
        this.canvas.style.animation = 'flash 0.1s infinite';
        
        // Stop the animations and keep showing the jumpscare
        setTimeout(() => {
            this.gameContainer.style.animation = '';
            this.canvas.style.animation = '';
            // Keep the jumpscare visible
        }, 1000);
    }
    
    showGameOver() {
        this.jumpscare.style.opacity = '1';
    }
    
    applyFlickerEffect() {
        this.canvas.classList.add('flicker');
        setTimeout(() => {
            this.canvas.classList.remove('flicker');
        }, 5000);
    }
    
    applyDistortionEffect() {
        this.canvas.style.filter = 'contrast(1.2) brightness(0.8) hue-rotate(30deg)';
        setTimeout(() => {
            this.canvas.style.filter = 'contrast(1.1) brightness(0.9)';
        }, 5000);
    }
}

export default UIController; 