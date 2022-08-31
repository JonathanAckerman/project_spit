Grid :: struct
{
    gridWidth :: 5;
    worldHeight :: 6;
    chunkWidth :: 20;
    cellSize :: 100;

    currentChunk := 0;
    loadedChunks: [..] *GridChunk;
    chunks: [gridWidth * gridWidth] GridChunk;

    left   :: inline (grid: Grid) -> int {return grid.chunks[0].cells[0].x; };
    top    :: inline (grid: Grid) -> int {return grid.chunks[0].cells[0].y; };
    right  :: inline (grid: Grid) -> int {return grid.chunks[grid.gridWidth * grid.gridWidth - 1].cells[(grid.chunkWidth * grid.chunkWidth) - 1].x + 1; };
    bottom :: inline (grid: Grid) -> int {return grid.chunks[grid.gridWidth * grid.gridWidth - 1].cells[(grid.chunkWidth * grid.chunkWidth) - 1].y + 1; };
}

GridChunk :: struct
{
    left   :: inline (chunk: GridChunk) -> int {return chunk.cells[0].x; };
    top    :: inline (chunk: GridChunk) -> int {return chunk.cells[0].y; };
    right  :: inline (chunk: GridChunk) -> int {return chunk.cells[(Game.grid.chunkWidth * Game.grid.chunkWidth) - 1].x + 1; };
    bottom :: inline (chunk: GridChunk) -> int {return chunk.cells[(Game.grid.chunkWidth * Game.grid.chunkWidth) - 1].y + 1; };

    cells: [Game.grid.chunkWidth * Game.grid.chunkWidth * Game.grid.worldHeight] GridCell;
}

GridCell :: struct
{
    x: int;
    y: int;
    type: Terrain_Type;
    forward: Vector2 = .{0, -1};
    block: Maybe(Block);
}

Terrain_Type :: enum
{
    AIR;
    BEDROCK;
    DIRT;
    WATER;
    BLOCK;
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
    if pos.x >= right && (grid.currentChunk + 1) % grid.gridWidth != 0 then grid.currentChunk += 1;
    if pos.y < top && grid.currentChunk >= grid.gridWidth then grid.currentChunk -= grid.gridWidth;
    if pos.y >= bottom && grid.currentChunk < grid.gridWidth * (grid.gridWidth - 1) then grid.currentChunk += grid.gridWidth;

    array_reset_keeping_memory(*grid.loadedChunks);
    chunk_neighbor_offsets := valid_neighboring_offsets(grid.currentChunk, grid.gridWidth);
    for chunk_neighbor_offsets { array_add(*grid.loadedChunks, *grid.chunks[grid.currentChunk + it]); }
}

grid_to_world :: (x: int, y: int, shouldGetCenter: bool = false) -> Vector2
{
    world: Vector2;
    if shouldGetCenter
    {
        world.x = x * Game.grid.cellSize + Game.grid.cellSize / 2.0;
        world.y = y * Game.grid.cellSize + Game.grid.cellSize / 2.0;
    }
    else
    {
        world = xy(xx x, xx y) * Game.grid.cellSize;
    }
    return world;
}

grid_to_world :: (g: GridCell, shouldGetCenter: bool = false) -> Vector2
{
    return grid_to_world(g.x, g.y, shouldGetCenter);
}

grid_to_world :: (c: int, shouldGetCenter: bool = false) -> float
{
    if shouldGetCenter
        return cast(float)(c * Game.grid.cellSize + Game.grid.cellSize / 2.0);
    else
        return cast(float)(c * Game.grid.cellSize);
}

world_to_grid :: (f: float) -> int
{
    x := cast(int) round(f);
    // get coordinates of top-left corner of grid cell
    x -= x % 100;
    // normalize grid coords
    x /= 100;
    return x;
}

world_to_grid :: (p: Vector2) -> *GridCell
{
    using Game;

    x := world_to_grid(p.x);
    y := world_to_grid(p.y);

    // if x < 0 || x >= grid.chunkWidth * grid.gridWidth ||
    //    y < 0 || y >= grid.chunkWidth * grid.gridWidth
    //    then return null;
    
    chunk_x := x / grid.chunkWidth;
    chunk_y := y / grid.chunkWidth;
    chunk_index := chunk_y * grid.gridWidth + chunk_x;

    row := (y % grid.chunkWidth) * grid.chunkWidth;
    col := x % grid.chunkWidth;

    return *Game.grid.chunks[chunk_index].cells[row + col];
}

to_screen_space :: (pos: Vector2, offset: Vector2 = .{0, 0}, scale: float = 1.0) -> Vector2
{
    to_ss_vector := WINDOW_CENTER - Game.camera.position * Game.camera.zoom;
    return (pos + offset) * scale * Game.camera.zoom + to_ss_vector;
}

// Given an absolute (x,y) grid coordinate, return a pointer to the cell corresponding to that coordinate in the grid
get_cell :: (x: int, y: int) -> *GridCell
{
    using Game;

    if x < 0 || x >= grid.chunkWidth * grid.gridWidth ||
       y < 0 || y >= grid.chunkWidth * grid.gridWidth
       then return null;

    chunk_x := x / grid.chunkWidth; // @@@: should this be: (x % chunkWidth) ?
    chunk_y := y / grid.chunkWidth;
    chunk_index := chunk_y * grid.gridWidth + chunk_x;

    row := (y % grid.chunkWidth) * grid.chunkWidth;
    col := x % grid.chunkWidth;
    return *grid.chunks[chunk_index].cells[row + col];
}

is_in_current_chunk :: (world: Vector2) -> bool
{
    coord := world_to_grid(world);
    current_chunk := Game.grid.chunks[Game.grid.currentChunk];
    if coord.x >= GridChunk.left(current_chunk) && coord.x < GridChunk.right(current_chunk) &&
       coord.y >= GridChunk.top(current_chunk) && coord.y < GridChunk.bottom(current_chunk)
    {
        return true;
    }
    return false;
}

is_in_loaded_chunk :: (entity: Entity) -> bool
{
    if !entity.position.exists return false;

    pos := entity.position.value;

    x := cast(int) round(pos.x);
    y := cast(int) round(pos.y);

    x -= x % 100;
    y -= y % 100;

    x /= 100;
    y /= 100;
    
    chunk_x := x / Game.grid.chunkWidth;
    chunk_y := y / Game.grid.chunkWidth;
    chunk_index := chunk_y * Game.grid.gridWidth + chunk_x;

    for Game.grid.loadedChunks 
    {
        if *Game.grid.chunks[chunk_index] == it then return true;
    }
    return false;
}

is_in_loaded_chunk :: (cell: GridCell) -> bool
{
    chunk_x := cell.x / Game.grid.chunkWidth;
    chunk_y := cell.y / Game.grid.chunkWidth;
    chunk_index := chunk_y * Game.grid.gridWidth + chunk_x;

    for Game.grid.loadedChunks 
    {
        if *Game.grid.chunks[chunk_index] == it then return true;
    }
    return false;
}

// Given a cell, compute the index it's at for its chunk
global_to_relative_grid_index :: (global_index: int) -> int
{
    x := global_index % Game.grid.chunkWidth;
    y := (global_index / (Game.grid.chunkWidth * Game.grid.gridWidth)) % Game.grid.chunkWidth;
    return y * Game.grid.chunkWidth + x;
}

get_chunk_index :: (cell_x: int, cell_y: int) -> int
{
    x := cell_x / Game.grid.chunkWidth;
    y := cell_y / Game.grid.chunkWidth;
    return y * Game.grid.gridWidth + x;
}