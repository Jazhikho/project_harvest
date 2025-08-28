class PlayerModel {
    constructor() {
        this.x = 1;
        this.y = 1;
    }
    
    moveUp(maze) {
        if (!maze[this.y][this.x].walls.top) {
            this.y--;
            return true;
        }
        return false;
    }
    
    moveRight(maze) {
        if (!maze[this.y][this.x].walls.right) {
            this.x++;
            return true;
        }
        return false;
    }
    
    moveDown(maze) {
        if (!maze[this.y][this.x].walls.bottom) {
            this.y++;
            return true;
        }
        return false;
    }
    
    moveLeft(maze) {
        if (!maze[this.y][this.x].walls.left) {
            this.x--;
            return true;
        }
        return false;
    }
    
    setPosition(x, y) {
        this.x = x;
        this.y = y;
    }
    
    getPosition() {
        return { x: this.x, y: this.y };
    }
    
    isAtPosition(x, y) {
        return this.x === x && this.y === y;
    }
}

export default PlayerModel; 