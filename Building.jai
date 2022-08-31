Block :: struct
{
    type: Block_Type;
    orientation: float;
    textureInfo: TextureInfo;
    // location: (within the cell)
}

Block_Type :: enum
{
    FULL_WALL;
    STAIR_TOP;
    STAIR_BOTTOM;
}

make_block :: (type: Block_Type, orientation: float) -> Block
{
    block: Block;
    block.type = type;
    block.orientation = orientation;
    info: TextureInfo;
    if type == .STAIR_BOTTOM then info.texture = table_find_pointer(*Textures.table, "stairs");
    info.tint = WHITE;
    info.size = xy(Game.grid.cellSize, Game.grid.cellSize);
    block.textureInfo = info;
    return block;
}