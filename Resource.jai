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

Item :: struct(T: Type = Any)
{
    position: Vector2;
    size: Vector2;
    id: Item_ID;

    using inventory: struct
    {
        capacity: int;
        count: int;
        contents: [] T;
    }
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

Draw_Item_Basket :: (pos: Vector2, size: float)
{
    DrawRectangleV(pos, xy(size, size), BEIGE);
    DrawCircleV(pos + xy(size/2.0, size), size/2.0, BEIGE);
}

Draw_Item_Chest :: (pos: Vector2, size: float)
{
    DrawRectangleV(pos, xy(size, size), DARKGREEN);
    DrawCircleV(pos + xy(size/2.0, 0), size/2.0, DARKGREEN);
}

Draw_Item :: (pos: Vector2, item: Item)
{
    // print("%\n", pos);
    if item.id ==
    {
        case .LUMBER_AXE;
            DrawCircleV(pos, item.size.x, GRAY);
    }
}

Get_Total_Resources_On_Person :: () -> [] int
{
    using Game;
    resource_totals: [] int;
    array_resize(*resource_totals, enum_highest_value(Resource_ID) + 1);
    for player.pockets
    {
        resource_totals[it_index] += it;
    }
    if player.held.exists
    {
        for cast([] int) player.held.value.contents
        {
            resource_totals[it_index] += it;
        }
    }
    return resource_totals;
}