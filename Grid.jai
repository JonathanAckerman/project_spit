Grid :: struct
{
    gridWidth :: 3;
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

    cells: [Game.grid.chunkWidth * Game.grid.chunkWidth] GridCell;
}

GridCell :: struct
{
    x: int;
    y: int;
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
    return a.x == b.x && a.y == b.y;
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

grid_to_world :: (x: int, y: int, shouldGetCenter: bool = false) -> Vector2
{
    world: Vector2;
    if !shouldGetCenter
        world = xy(xx x, xx y) * Game.grid.cellSize;
    else
    {
        world.x = x * Game.grid.cellSize + Game.grid.cellSize / 2.0;
        world.y = y * Game.grid.cellSize + Game.grid.cellSize / 2.0;
    }
    return world;
}

grid_to_world :: (g: GridCell, shouldGetCenter: bool = false) -> Vector2
{
    return grid_to_world(g.x, g.y, shouldGetCenter);
}

world_to_grid :: (p: Vector2) -> GridCell
{
    g: GridCell;
    g.x = cast(int) round(p.x);
    g.y = cast(int) round(p.y);
    // get coordinates of top-left corner of grid cell
    g.x -= g.x % 100;
    g.y -= g.y % 100;
    // normalize grid coords
    g.x /= 100;
    g.y /= 100;
    return g;
}