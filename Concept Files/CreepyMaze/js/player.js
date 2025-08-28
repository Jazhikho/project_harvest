// Player movement and state
export class Player {
    constructor() {
        this.x = 1;
        this.y = 1;
    }

    move(key, maze) {
        let newX = this.x;
        let newY = this.y;
        switch (key) {
            case 'ArrowUp': if (!maze[this.y][this.x].walls.top) newY--; break;
            case 'ArrowRight': if (!maze[this.y][this.x].walls.right) newX++; break;
            case 'ArrowDown': if (!maze[this.y][this.x].walls.bottom) newY++; break;
            case 'ArrowLeft': if (!maze[this.y][this.x].walls.left) newX--; break;
        }
        if (newX !== this.x || newY !== this.y) {
            this.x = newX;
            this.y = newY;
            return true;
        }
        return false;
    }
} 