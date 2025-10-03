# Creepy Maze Game

A modular implementation of the Creepy Maze game using ES6 modules.

## Running the Game

Due to browser security restrictions, ES6 modules cannot be loaded directly from the file system. You need to run a local web server to use this application.

### Option 1: Using Python (Recommended)

If you have Python installed, you can start a simple HTTP server:

1. Open Command Prompt or PowerShell
2. Navigate to the game directory:
   ```
   cd D:\Game Creation\CreepyMaze
   ```
3. Start a Python HTTP server:
   ```
   python -m http.server 8000
   ```
4. Open your browser and go to:
   ```
   http://localhost:8000/
   ```

### Option 2: Using Node.js

If you have Node.js installed:

1. Install `http-server` globally:
   ```
   npm install -g http-server
   ```
2. Navigate to the game directory and run:
   ```
   http-server
   ```
3. Open your browser to the URL shown in the terminal (typically http://localhost:8080)

### Option 3: Using VSCode Live Server

If you're using Visual Studio Code:

1. Install the "Live Server" extension
2. Right-click on `index.html` and select "Open with Live Server"

## Debug Options

- `simple-game.html`: A simplified version of the game that runs without modules
- `debug.html`: A debugging tool to test individual modules
- `test.html`: Automated testing of all modules
- `simple-test.html`: Minimal test of a single module

## Troubleshooting

If you're experiencing issues:

1. Check the browser console for error messages (F12 to open developer tools)
2. Try the `debug.html` file to test individual modules
3. Ensure all JS files are in the correct directories
4. Make sure you're using a modern browser (Chrome, Firefox, Edge)

## File Structure

- `index.html`: Main game entry point
- `styles.css`: Game styles
- `js/`: Directory containing all JavaScript modules:
  - `gameLogic.js`: Main game logic and coordination
  - `mazeGenerator.js`: Maze generation algorithms
  - `player.js`: Player movement handling
  - `renderer.js`: Drawing functions for the canvas
  - `utils.js`: Utility functions
  - `weirdThings.js`: Manages the "weird things" in the maze 