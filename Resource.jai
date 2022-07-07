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
    }
}