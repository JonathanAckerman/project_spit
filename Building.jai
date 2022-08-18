Block :: struct
{
    type: Block_Type;
    orientation: Vector2;
    textureInfo: TextureInfo;
    // location: (within the cell)
}

Block_Type :: enum
{
    FULL_WALL;
    STAIRS;
}

make_block :: (type: Block_Type, orientation: Vector2) -> Block
{
    block: Block;
    block.type = type;
    block.orientation = orientation;
    info: TextureInfo;
    if type == .STAIRS then info.texture = table_find_pointer(*Textures.table, "stairs");
    info.tint = WHITE;
    info.size = xy(Game.grid.cellSize, Game.grid.cellSize);
    block.textureInfo = info;
    return block;
}

// @TODO: for now this will only be responsible for drawing blocks, not cells in general, eventually it'll do both
draw_cell :: (cell: GridCell)
{
    layer_size_modifier := 1.0 - (cell.z - (cast(int) Game.camera.position.z + 1)) * 0.1;
    // @TEMP: for now make resizing preserve aspect ratio
    resize_ratio := cell.block.value.textureInfo.size.x / cell.block.value.textureInfo.width;
    base_size := xy(xx cell.block.value.textureInfo.width, xx cell.block.value.textureInfo.height);
    modified_size := base_size * resize_ratio * Game.camera.zoom * layer_size_modifier;
    ss_block := to_screen_space(grid_to_world(cell.x, cell.y, cell.z, true).xy);
    drawpos := ss_block - modified_size / 2;
    tint := cell.block.value.textureInfo.tint;
    tint.r = xx (tint.r * layer_size_modifier);
    tint.g = xx (tint.g * layer_size_modifier);
    tint.b = xx (tint.b * layer_size_modifier);
    rot: float = 0;
    if cell.block.value.orientation == .{0, 1} 
    {
        rot = 90.0;
        drawpos += .{Game.grid.cellSize, 0};
    }
    if cell.block.value.orientation == .{-1, 0} 
    {
        rot = 180.0;
        drawpos += .{Game.grid.cellSize, Game.grid.cellSize};
    }
    if cell.block.value.orientation == .{0, -1} 
    {
        rot = 270.0;
        drawpos += .{0, Game.grid.cellSize};
    }
    DrawTextureEx(cell.block.value.textureInfo.texture, xx drawpos, rot, resize_ratio * Game.camera.zoom * layer_size_modifier, tint);
}