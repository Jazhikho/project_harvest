class WeirdThingsModel {
    constructor() {
        this.weirdThings = [];
        this.weirdFindings = 0;
    }
    
    placeWeirdThings(gridWidth, gridHeight, playerX, playerY) {
        // Clear existing weird things
        this.weirdThings = [];
        
        // Add some weird things to find
        const numWeirdThings = 5 + Math.floor(Math.random() * 5); // 5-10 weird things
        
        for (let i = 0; i < numWeirdThings; i++) {
            let x, y;
            
            // Find a valid location (not where the player is and not where another weird thing is)
            do {
                x = 1 + Math.floor(Math.random() * (gridWidth - 2));
                y = 1 + Math.floor(Math.random() * (gridHeight - 2));
            } while ((x === playerX && y === playerY) || this.weirdThingAt(x, y));
            
            // Create a weird thing
            this.weirdThings.push({
                x: x,
                y: y,
                type: Math.floor(Math.random() * 5), // Different types of weird things
                found: false
            });
        }
    }
    
    weirdThingAt(x, y) {
        return this.weirdThings.some(thing => thing.x === x && thing.y === y);
    }
    
    getWeirdThingAt(x, y) {
        return this.weirdThings.find(thing => thing.x === x && thing.y === y);
    }
    
    getWeirdMessage(type) {
        const messages = [
            "You found an old doll with missing eyes. It whispers something you can't quite hear.",
            "A small music box plays a haunting melody that seems to come from everywhere at once.",
            "A mirror shows your reflection, but it doesn't move when you do.",
            "You found ancient symbols carved into the wall. They seem to shift when you look away.",
            "A pocket watch ticks backwards. The temperature around you drops noticeably."
        ];
        
        return messages[type % messages.length];
    }
    
    findWeirdThing(x, y) {
        const weirdThing = this.getWeirdThingAt(x, y);
        
        if (weirdThing && !weirdThing.found) {
            weirdThing.found = true;
            this.weirdFindings++;
            return {
                found: true,
                type: weirdThing.type,
                message: this.getWeirdMessage(weirdThing.type)
            };
        }
        
        return { found: false };
    }
    
    getWeirdFindings() {
        return this.weirdFindings;
    }
}

export default WeirdThingsModel; 