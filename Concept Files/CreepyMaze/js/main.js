import GameController from './controllers/GameController.js';

// Initialize the game when the window loads
window.onload = () => {
    // Get DOM elements
    const canvas = document.getElementById('gameCanvas');
    const counterElement = document.getElementById('counter');
    const messageOverlay = document.getElementById('message-overlay');
    const messageContent = document.getElementById('message-content');
    const jumpscareFace = document.getElementById('jumpscare-face');
    
    // Create and initialize the game
    const gameController = new GameController(
        canvas,
        counterElement,
        messageOverlay,
        messageContent,
        jumpscareFace
    );
    
    gameController.initGame();
}; 