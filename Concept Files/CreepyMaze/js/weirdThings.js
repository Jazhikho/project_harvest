// Weird things management
export class WeirdThings {
    constructor() {
        this.items = [];
    }

    placeWeirdThings(maze, player) {
        this.items = [];
        const numWeirdThings = 5 + Math.floor(Math.random() * 5);
        for (let i = 0; i < numWeirdThings; i++) {
            let x, y;
            do {
                x = 1 + Math.floor(Math.random() * 18);
                y = 1 + Math.floor(Math.random() * 18);
            } while ((x === player.x && y === player.y) || this.weirdThingAt(x, y));
            this.items.push({ x, y, type: Math.floor(Math.random() * 5), found: false });
        }
    }

    weirdThingAt(x, y) {
        return this.items.some(thing => thing.x === x && thing.y === y);
    }

    getWeirdThingAt(x, y) {
        return this.items.find(thing => thing.x === x && thing.y === y);
    }
}

// Get a weird message based on the type
function getWeirdMessage(type) {
    const messages = [
        "You found an old doll with missing eyes. It whispers something you can't quite hear.",
        "A small music box plays a haunting melody that seems to come from everywhere at once.",
        "A mirror shows your reflection, but it doesn't move when you do.",
        "You found ancient symbols carved into the wall. They seem to shift when you look away.",
        "A pocket watch ticks backwards. The temperature around you drops noticeably."
    ];
    
    return messages[type % messages.length];
}

// Apply a weird effect based on the type
function applyWeirdEffect(type, canvas, changeMazePart, fogOfWarRef) {
    if (!canvas || !fogOfWarRef) {
        console.error('Required parameters missing in applyWeirdEffect');
        return;
    }
    
    switch (type) {
        case 0: // Brief flicker
            canvas.classList.add('flicker');
            setTimeout(() => {
                canvas.classList.remove('flicker');
            }, 5000);
            break;
        case 1: // Maze slightly changes
            if (typeof changeMazePart === 'function') changeMazePart();
            break;
        case 2: // Fog of war temporarily removed
            const fogBackup = fogOfWarRef.value;
            fogOfWarRef.value = false;
            setTimeout(() => {
                fogOfWarRef.value = fogBackup;
            }, 3000);
            break;
        case 3: // Distorted view
            canvas.style.filter = 'contrast(1.2) brightness(0.8) hue-rotate(30deg)';
            setTimeout(() => {
                canvas.style.filter = 'contrast(1.1) brightness(0.9)';
            }, 5000);
            break;
        case 4: // Something follows you
            // This will be handled in the game loop
            break;
    }
}

export { getWeirdMessage, applyWeirdEffect }; 