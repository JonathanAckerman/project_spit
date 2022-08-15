Grid :: struct
{
    gridWidth :: 5;
    worldHeight :: 6;
    chunkWidth :: 20;
    cellSize :: 100;

    currentChunk := 0;
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
    z: int;
    type: Cell_Type;
}

Cell_Type :: enum
{
    AIR;
    BEDROCK;
    DIRT;
    WATER;
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
    if pos.x >= right && (grid.currentChunk + 1) % grid.gridWidth != 0 then grid.currentChunk += 1;
    if pos.y < top && grid.currentChunk >= grid.gridWidth then grid.currentChunk -= grid.gridWidth;
    if pos.y >= bottom && grid.currentChunk < grid.gridWidth * (grid.gridWidth - 1) then grid.currentChunk += grid.gridWidth;
}

is_in_current_chunk :: (world: Vector3) -> bool
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

grid_to_world :: (x: int, y: int, z: int, shouldGetCenter: bool = false) -> Vector3
{
    world: Vector3;
    if shouldGetCenter
    {
        world.x = x * Game.grid.cellSize + Game.grid.cellSize / 2.0;
        world.y = y * Game.grid.cellSize + Game.grid.cellSize / 2.0;
        world.z = xx z;
    }
    else
    {
        world = xyz(xx x, xx y, xx z) * Game.grid.cellSize;
        world.z = xx z;
    }
    return world;
}

grid_to_world :: (g: GridCell, shouldGetCenter: bool = false) -> Vector3
{
    return grid_to_world(g.x, g.y, g.z, shouldGetCenter);
}

grid_to_world :: (c: int, shouldGetCenter: bool = false) -> float
{
    if shouldGetCenter
        return cast(float)(c * Game.grid.cellSize + Game.grid.cellSize / 2.0);
    else
        return cast(float)(c * Game.grid.cellSize);
}

world_to_grid :: (p: Vector3) -> GridCell
{
    x := cast(int) round(p.x);
    y := cast(int) round(p.y);
    z := cast(int) round(p.z);
    // get coordinates of top-left corner of grid cell
    x -= x % 100;
    y -= y % 100;
    // normalize grid coords
    x /= 100;
    y /= 100;
    
    chunk_x := x / Game.grid.chunkWidth;
    chunk_y := y / Game.grid.chunkWidth;
    chunk_index := chunk_y * Game.grid.gridWidth + chunk_x;

    layer := z * Game.grid.chunkWidth * Game.grid.chunkWidth;
    row := (y % Game.grid.chunkWidth) * Game.grid.chunkWidth;
    col := x % Game.grid.chunkWidth;

    return Game.grid.chunks[chunk_index].cells[layer + row + col];
}

to_screen_space :: (pos: Vector2, offset: Vector2 = .{0, 0}, scale: float = 1.0) -> Vector2
{
    to_ss_vector := WINDOW_CENTER - Game.camera.position.xy * Game.camera.zoom;
    return (pos + offset) * scale * Game.camera.zoom + to_ss_vector;
}

get_cell :: (x: int, y: int, z: int) -> GridCell
{
    using Game;

    chunk_x := x / grid.chunkWidth;
    chunk_y := y / grid.chunkWidth;
    chunk_index := chunk_y * grid.gridWidth + chunk_x;

    layer := z * grid.chunkWidth * grid.chunkWidth;
    row := (y % grid.chunkWidth) * grid.chunkWidth;
    col := x % grid.chunkWidth;
    return grid.chunks[chunk_index].cells[layer + row + col];
}

get_grid_punch :: (x: int, y: int) -> [..] GridCell
{
    using Game;
    result: [..] GridCell;
    for z: 0..grid.worldHeight - 1
    {
        cell := get_cell(x, y, z);
        array_add(*result, cell);
    }
    return result;
}

get_grid_punch :: (gc: GridCell) -> [..] GridCell
{
    return get_grid_punch(gc.x, gc.y);
}