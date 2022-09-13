Block :: struct
{
    using #as entity: Entity;
    type: Block_Type;
    // location: (within the cell)
}

Block_Type :: enum
{
    FULL_WALL;
    PIER;
    DOOR;
}