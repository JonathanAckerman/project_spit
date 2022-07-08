Resource :: struct 
{
    position: Vector2;
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

Item :: struct
{
    id: Item_ID;
    capacity: int;
    count: int;
    contents: [..] Any;
}

Item_ID :: enum
{
    BASKET;
    CHEST;
}