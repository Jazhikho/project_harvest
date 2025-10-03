# Creepy Maze - SOLID Version

This is a refactored version of the original Creepy Maze game following SOLID principles. The game functionality remains the same, but the code has been restructured for better maintainability, scalability, and clarity.

## SOLID Principles Applied

### S - Single Responsibility Principle
Each class has a single responsibility:
- Models: Handle data and state
- Views/Renderers: Handle drawing and visualization
- Controllers: Handle user input and game logic
- Utils: Provide helper functions

### O - Open/Closed Principle
The code is open for extension but closed for modification. For example:
- New types of weird things can be added by extending the renderer without modifying existing code
- New effects can be added by implementing new methods in the appropriate classes

### L - Liskov Substitution Principle
While not directly applicable to many parts of the code, the system respects the principle where relevant. For instance, all renderers follow a consistent interface pattern.

### I - Interface Segregation Principle
Classes interact with others through specific interfaces rather than depending on large implementation details:
- The game controller doesn't need to know how weird things are drawn
- The UI controller doesn't need to know how the maze is generated

### D - Dependency Inversion Principle
High-level modules depend on abstractions, not concrete implementations:
- The game controller depends on models and renderers by their interfaces
- The main.js file creates and connects the components

## Project Structure

```
js/
├── models/           # Data models
│   ├── MazeModel.js         # Handles maze data and generation
│   ├── PlayerModel.js       # Handles player state
│   ├── WeirdThingsModel.js  # Handles weird findings data
│   └── GameStateModel.js    # Handles overall game state
│
├── views/            # Rendering components
│   ├── MazeRenderer.js      # Renders the maze
│   ├── PlayerRenderer.js    # Renders the player
│   └── WeirdThingsRenderer.js # Renders weird things
│
├── controllers/      # Game logic and input handling
│   ├── GameController.js    # Main game controller
│   └── UIController.js      # Handles UI interactions
│
├── utils/            # Helper utilities
│   └── MathUtils.js         # Math utility functions
│
└── main.js           # Entry point that initializes the game
```

## How to Run

1. Open `creepymaze-solid.html` in a web browser.
2. Use arrow keys to navigate the maze.
3. Find weird objects and reach the exit.

## Improvements from Original

- **Better Code Organization**: Logical separation of concerns
- **Enhanced Maintainability**: Each component can be modified independently
- **Improved Scalability**: New features can be added with minimal changes to existing code
- **Better Testing Potential**: Each component can be tested in isolation
- **Simplified Debugging**: Issues can be traced to specific components

The original game is still available in `creepymaze.html` for comparison.

## Game Instructions

- Use arrow keys to navigate through the maze.
- Collect weird findings to progress the narrative.
- Find the exit, but be careful - something may be waiting for you there...
- The maze changes over time, so keep exploring.