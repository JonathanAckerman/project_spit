Resource :: struct 
{
    position: Vector2 = ---;
    id: Resource_ID;
    quantity: int; 
}


Resource_ID :: enum
{
    COPPER;
    IRON;
    WATER;
    WOOD;
    FIBER;
}

get_resource_color :: (r: Resource_ID) -> Color
{
    if #complete r ==
    {
        case .IRON;
            return RED;
        case .COPPER;
            return GREEN;
        case .WATER;
            return BLUE;
        case .WOOD;
            return DARKGREEN;
        case .FIBER;
            return BEIGE;
    }
}

Entity :: struct
{
    position: Vector2;
    size: Vector2;
    id: Item_ID;
    
    union
    {
        container: Container;
        equipment: Equipment;
    }
}

Container :: struct
{
    capacity: int;
    contents: [#run enum_highest_value(Resource_ID) + 1] int;
}

Equipment :: struct
{
    using inventory: Inventory;
}

Inventory :: struct
{
    capacity: int;
    contents: [] Entity;
}

Item_ID :: enum
{
    BASKET;
    CHEST;
    TOOL_BELT;
    WEAPON_BELT;
    CARPENTERS_HAMMER;
    LUMBER_AXE;
    SWORD;
    WHIP;
}

draw_item_basket :: (pos: Vector2, size: float)
{
    DrawRectangleV(pos, xy(size, size), BEIGE);
    DrawCircleV(pos + xy(size/2.0, size), size/2.0, BEIGE);
}

draw_item_chest :: (pos: Vector2, size: float)
{
    DrawRectangleV(pos, xy(size, size), DARKGREEN);
    DrawCircleV(pos + xy(size/2.0, 0), size/2.0, DARKGREEN);
}

draw_item :: (pos: Vector2, item: Entity)
{
    if item.id ==
    {
        case .LUMBER_AXE;
            DrawCircleV(pos, item.size.x, GRAY);
    }
}