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

_Entity_ID: u64 = 0;

Entity :: struct
{
    position: Vector2;
    collider: Collider;
    tag: Entity_Type;
    id: u64;

    union
    {
        #as resource: Resource;
        #as item: Item;
        #as container: Container;
        #as equipment: Equipment;
        #as building: Building;
    }
}
Entity_Type :: enum
{
    RESOURCE;
    ITEM;
    CONTAINER;
    EQUIPMENT;
    BUILDING;
}

Resource :: struct 
{
    type: Resource_Type;
    quantity: int;
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

NewEntityBase :: (pos: Vector2, collider: Collider, tag: Entity_Type) -> Entity
{
    e: Entity;
    e.position = pos;
    e.collider = collider;
    e.tag = tag;
    e.id = _Entity_ID;
    _Entity_ID += 1;
    return e;
}

// @Note: I might not need to pass in type since traders and shops have their own functions, or try to combine the functs
// Traders
NewBuilding :: (type: Bldg_Type, pos: Vector2, want: Resource_Type, have: Resource_Type) -> Entity
{
    collider := Collider.{type = .RECT, rect = .{100, 100}};
    e: Entity = NewEntityBase(pos, collider, .BUILDING);
    e.building.type = .TRADER;
    e.building.want = want;
    e.building.have = have;
    return e;
}
// Shops
NewBuilding :: (type: Bldg_Type, pos: Vector2, resource: Resource_Type, amount: int, selling: Container_Type) -> Entity
{
    collider := Collider.{type = .RECT, rect = .{50, 50}};
    e: Entity = NewEntityBase(pos, collider, .BUILDING);
    e.building.type = .SHOP;
    e.building.resource = resource;
    e.building.amount = amount;
    e.building.itemType = selling;
    return e;
}

NewContainer :: (type: Container_Type, collider: Collider, pos: Vector2 = .{0, 0}) -> Entity
{
    e: Entity = NewEntityBase(pos, collider, .CONTAINER);
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

NewItem :: (type: Item_Type, collider: Collider, pos: Vector2 = .{0, 0}) -> Entity
{
    e: Entity = NewEntityBase(pos, collider, .ITEM);
    e.item.type = type;
    return e;
}

NewEquipment :: (type: Equipment_Type, collider: Collider, pos: Vector2 = .{0, 0}) -> Entity
{
    e: Entity = NewEntityBase(pos, collider, .EQUIPMENT);
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
    return e;
}

Resource_Type :: enum
{
    COPPER;
    IRON;
    WATER;
    WOOD;
    FIBER;
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

// @TODO: handle buildings and people
draw_entity :: (e: Entity, pos: Vector2, scale: float = 1.0)
{
    scale *= Game.camera.zoom;
    if e.tag ==
    {
        case .RESOURCE;
            resource_color := get_resource_color(e.resource.type);
            DrawCircleV(pos, xx e.resource.quantity * scale, resource_color);
        case .ITEM; if e.item.type ==
        {
            case .LUMBER_AXE;
                DrawCircleV(pos, e.collider.radius * scale, GRAY);
            case .SWORD;
                DrawCircleV(pos, e.collider.radius * scale, BLACK);
        }
        case .CONTAINER; if e.container.type ==
        {
            case .BASKET;
                DrawRectangleV(pos, e.collider.rect * scale, BEIGE);
                DrawCircleV(pos + xy(e.collider.rect.x/2.0, e.collider.rect.y), (e.collider.rect.x/2.0) * scale, BEIGE);
            case .CHEST;
                DrawRectangleV(pos, e.collider.rect * scale, DARKGREEN);
                DrawCircleV(pos + xy(e.collider.rect.x/2.0, 0), (e.collider.rect.x/2.0) * scale, DARKGREEN);
        }
        case .EQUIPMENT; if e.equipment.type ==
        {
            case .TOOL_BELT;
                DrawRectangleV(pos, e.collider.rect * scale, GREEN);
            case .WEAPON_BELT;
                DrawRectangleV(pos, e.collider.rect * scale, RED);
        }
    }
}

// @TODO: handle camera zoom 
draw_ui_representation :: (pos: Vector2, collider: Collider, scale: float, type: Container_Type)
{
    scale *= Game.camera.zoom;
    if type ==
    {
        case .BASKET;
            DrawRectangleV(pos, collider.rect * scale, BEIGE);
            DrawCircleV(pos + xy(collider.rect.x/2.0 - 2, collider.rect.y - 2), (collider.rect.x/2.0) * scale, BEIGE);
        case .CHEST;
            DrawRectangleV(pos + .{0, 8}, collider.rect * scale, DARKGREEN);
            DrawCircleV(pos + xy(collider.rect.x/2.0 - 2, 6), (collider.rect.x/2.0) * scale, DARKGREEN);
    }
}