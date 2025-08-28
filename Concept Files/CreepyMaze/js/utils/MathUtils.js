class MathUtils {
    /**
     * Get a random integer between min (inclusive) and max (inclusive)
     */
    static getRandomInt(min, max) {
        min = Math.ceil(min);
        max = Math.floor(max);
        return Math.floor(Math.random() * (max - min + 1)) + min;
    }
    
    /**
     * Calculate distance between two points
     */
    static distance(x1, y1, x2, y2) {
        return Math.sqrt(Math.pow(x2 - x1, 2) + Math.pow(y2 - y1, 2));
    }
    
    /**
     * Clamp a value between min and max
     */
    static clamp(value, min, max) {
        return Math.min(Math.max(value, min), max);
    }
    
    /**
     * Linear interpolation between two values
     */
    static lerp(start, end, amt) {
        return (1 - amt) * start + amt * end;
    }
}

export default MathUtils; 