// Utility functions
export function updateVisibility(player, maze, visibleCells) {
    visibleCells[`${player.x},${player.y}`] = true;
    if (!maze[player.y][player.x].walls.top) visibleCells[`${player.x},${player.y-1}`] = true;
    if (!maze[player.y][player.x].walls.right) visibleCells[`${player.x+1},${player.y}`] = true;
    if (!maze[player.y][player.x].walls.bottom) visibleCells[`${player.x},${player.y+1}`] = true;
    if (!maze[player.y][player.x].walls.left) visibleCells[`${player.x-1},${player.y}`] = true;
}