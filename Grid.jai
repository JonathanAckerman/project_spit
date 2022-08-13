Grid :: struct
{
    gridWidth :: 3;
    worldHeight :: 5;
    chunkWidth :: 20;
    cellSize :: 100;

    currentChunk := 0;
    chunks: [gridWidth * gridWidth] GridChunk;
}

GridChunk :: struct
{
    left   :: inline (chunk: GridChunk) -> int {return chunk.cells[0].x; };
    top    :: inline (chunk: GridChunk) -> int {return chunk.cells[0].y; };
    right  :: inline (chunk: GridChunk) -> int {return chunk.cells[(Game.grid.chunkWidth * Game.grid.chunkWidth) - 1].x; };
    bottom :: inline (chunk: GridChunk) -> int {return chunk.cells[(Game.grid.chunkWidth * Game.grid.chunkWidth) - 1].y; };

    cells: [Game.grid.chunkWidth * Game.grid.chunkWidth * Game.grid.worldHeight] GridCell;
}

GridCell :: struct
{
    x: int;
    y: int;
    z: int;
    type: Cell_Type;
}

Cell_Type :: enum
{
    BEDROCK;
    DIRT;
    WATER;
    AIR;
}

operator == :: (a: GridCell, b: GridCell) -> bool
{
    return a.x == b.x && a.y == b.y && a.z == b.z;
}

update_current_chunk :: ()
{
    using Game;
    if !player.position.exists return;

    pos     := world_to_grid(player.position.value);
    current := grid.chunks[grid.currentChunk];
    left    := GridChunk.left(current);
    right   := GridChunk.right(current);
    top     := GridChunk.top(current);
    bottom  := GridChunk.bottom(current);

    if pos.x < left && grid.currentChunk % grid.gridWidth != 0 then grid.currentChunk -= 1;
    if pos.x > right && (grid.currentChunk + 1) % grid.gridWidth != 0 then grid.currentChunk += 1;
    if pos.y < top && grid.currentChunk >= grid.gridWidth then grid.currentChunk -= grid.gridWidth;
    if pos.y > bottom && grid.currentChunk < grid.gridWidth * (grid.gridWidth - 1) then grid.currentChunk += grid.gridWidth;
}

grid_to_world :: (x: int, y: int, z: int, shouldGetCenter: bool = false) -> Vector3
{
    world: Vector3;
    if !shouldGetCenter
    {
        world = xyz(xx x, xx y, xx z) * Game.grid.cellSize;
        world.z = xx z;
    }
    else
    {
        world.x = x * Game.grid.cellSize + Game.grid.cellSize / 2.0;
        world.y = y * Game.grid.cellSize + Game.grid.cellSize / 2.0;
        world.z = xx z;
    }
    return world;
}

grid_to_world :: (g: GridCell, shouldGetCenter: bool = false) -> Vector3
{
    return grid_to_world(g.x, g.y, g.z, shouldGetCenter);
}

world_to_grid :: (p: Vector3) -> GridCell
{
    g: GridCell;
    g.x = cast(int) round(p.x);
    g.y = cast(int) round(p.y);
    g.z = cast(int) round(p.z);
    // get coordinates of top-left corner of grid cell
    g.x -= g.x % 100;
    g.y -= g.y % 100;
    g.z -= g.z % 100;
    // normalize grid coords
    g.x /= 100;
    g.y /= 100;
    g.z /= 100;
    return g;
}

to_screen_space :: (pos: Vector2, offset: Vector2 = .{0, 0}, scale: float = 1.0) -> Vector2
{
    to_ss_vector := WINDOW_CENTER - Game.camera.position.xy * Game.camera.zoom;
    return (pos + offset) * scale * Game.camera.zoom + to_ss_vector;
}