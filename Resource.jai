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
    tag: EntityType;

    EntityType :: enum
    {
        ITEM;
        CONTAINER;
        EQUIPMENT;
    }

    union
    {
        #as item: Item;
        #as container: Container;
        #as equipment: Equipment;
    }
}

Item :: struct
{
    id: Item_ID;
}
Container :: struct
{
    id: Container_ID;
    capacity: int;
    contents: [#run enum_highest_value(Resource_ID) + 1] int;
}
Equipment :: struct
{
    id: Equipment_ID;
    using #as inventory: Inventory;
}


// @Note: Inventory does not have an entity
Inventory :: struct
{
    capacity: int;
    contents: [..] Entity;
}

// @Note: I'm trusting that this will only be passed valid Container Entity_ID's atm
NewContainer :: (id: Container_ID, pos: Vector2 = .{0, 0}) -> Entity
{
    c: Entity;
    c.position = pos;
    c.tag = .CONTAINER;
    cap: int;
    if id ==
    {
        case .BASKET;
            cap = 100;
        case .CHEST;
            cap = 300;
    }
    c.container.capacity = cap;
    c.container.id = id;
    return c;
}

Container_ID :: enum
{
    BASKET;
    CHEST;
}
Equipment_ID :: enum
{
    TOOL_BELT;
    WEAPON_BELT;
}
Item_ID :: enum
{
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

draw_item :: (pos: Vector2, e: Entity)
{
    if e.tag ==
    {
        case .ITEM;
            if e.item.id ==
            {
                case .LUMBER_AXE;
                    DrawCircleV(pos, e.size.x, GRAY);
            }
    }
}