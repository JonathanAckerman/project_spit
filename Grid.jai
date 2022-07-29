Grid :: struct
{
    chunkSize :: 20;
    cellSize :: 100;
    cells: [chunkSize][chunkSize] GridCell;

    left := () => 0;
    right := () => chunkSize * cellSize;
    top := () => 0;
    bottom := () => chunkSize * cellSize;
}

GridCell :: struct
{
    x: int;
    y: int;
}

operator == :: (a: GridCell, b: GridCell) -> bool
{
    return a.x == b.x && a.y == b.y;
}

grid_to_world :: (x: int, y: int, shouldGetCenter: bool = false) -> Vector2
{
    world: Vector2;
    if shouldGetCenter
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
    return grid_to_world(g.x, g.y);
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