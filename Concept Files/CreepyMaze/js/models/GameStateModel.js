class GameStateModel {
    constructor() {
        this.gameOver = false;
        this.storyProgress = 0;
        this.lastTimestamp = Date.now();
    }
    
    isGameOver() {
        return this.gameOver;
    }
    
    setGameOver() {
        this.gameOver = true;
    }
    
    getStoryProgress() {
        return this.storyProgress;
    }
    
    updateStoryProgress(progress) {
        if (progress > this.storyProgress) {
            this.storyProgress = progress;
            return true;
        }
        return false;
    }
    
    progressStoryBasedOnFindings(weirdFindings) {
        let changed = false;
        
        if (weirdFindings === 3 && this.storyProgress === 0) {
            this.storyProgress = 1;
            changed = true;
        } else if (weirdFindings >= 5 && this.storyProgress === 1) {
            this.storyProgress = 2;
            changed = true;
        }
        
        return {
            changed,
            storyProgress: this.storyProgress
        };
    }
    
    getNarrativeMessage() {
        if (this.storyProgress === 1) {
            return "The objects seem connected somehow. Your head begins to ache as whispers grow louder...";
        } else if (this.storyProgress === 2) {
            return "Something's following you. Don't look back. Find the exit BEFORE it finds you.";
        }
        return "";
    }
    
    getRandomNarrativeMoment() {
        if (this.storyProgress >= 1 && Math.random() < 0.01) {
            const narrativeMessages = [
                "Was that shadow there before?",
                "The air feels colder here.",
                "You hear faint scratching sounds from the walls.",
                "Something whispers your name from behind you.",
                "The walls seem to breathe."
            ];
            
            return narrativeMessages[Math.floor(Math.random() * narrativeMessages.length)];
        }
        
        return null;
    }
}

export default GameStateModel; 