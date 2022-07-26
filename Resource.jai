Resource :: struct 
{
    position: Vector2 = ---;
    type: Resource_Type;
    quantity: int; 
}


Resource_Type :: enum
{
    COPPER;
    IRON;
    WATER;
    WOOD;
    FIBER;
}

get_resource_color :: (r: Resource_Type) -> Color
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
    collider: Collider;
    tag: Entity_Type;

    union
    {
        #as item: Item;
        #as container: Container;
        #as equipment: Equipment;
        #as building: Building;
    }
}
Entity_Type :: enum
{
    ITEM;
    CONTAINER;
    EQUIPMENT;
    BUILDING;
}

Item :: struct
{
    type: Item_Type;
}
Container :: struct
{
    type: Container_Type;
    capacity: int;
    contents: [#run enum_highest_value(Resource_Type) + 1] int;
}
Equipment :: struct
{
    type: Equipment_Type;
    using #as inventory: Inventory;
}


// @Note: Inventory does not have an entity
Inventory :: struct
{
    capacity: int;
    contents: [..] Entity;
}

NewContainer :: (type: Container_Type, pos: Vector2 = .{0, 0}) -> Entity
{
    e: Entity;
    e.position = pos;
    e.tag = .CONTAINER;
    cap: int;
    if type ==
    {
        case .BASKET;
            cap = 100;
        case .CHEST;
            cap = 300;
    }
    e.container.capacity = cap;
    e.container.type = type;
    return e;
}

NewItem :: (type: Item_Type, pos: Vector2 = .{0, 0}, coll: Collider) -> Entity
{
    e: Entity;
    e.position = pos;
    e.tag = .ITEM;
    e.item.type = type;
    e.collider = coll;
    return e;
}

NewEquipment :: (type: Equipment_Type, pos: Vector2 = .{0, 0}, coll: Collider) -> Entity
{
    e: Entity;
    e.position = pos;
    e.tag = .EQUIPMENT;
    e.equipment.type = type;
    cap: int;
    if type ==
    {
        case .TOOL_BELT;
            cap = 3;
        case .WEAPON_BELT;
            cap = 3;
    }
    e.equipment.capacity = cap;
    e.collider = coll;
    return e;
}

Container_Type :: enum
{
    BASKET;
    CHEST;
}
Equipment_Type :: enum
{
    TOOL_BELT;
    WEAPON_BELT;
}
Item_Type :: enum
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
            if e.item.type ==
            {
                case .LUMBER_AXE;
                    DrawCircleV(pos, e.collider.radius, GRAY);
            }
    }
}