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
}

make_block :: (type: Block_Type, orientation: float) -> Block
{
    block: Block;
    block.type = type;
    block.orientation = orientation;
    info: TextureInfo;
    info.tint = WHITE;
    info.size = xy(Game.grid.cellSize, Game.grid.cellSize);
    block.textureInfo = info;
    return block;
}