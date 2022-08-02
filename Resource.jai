get_resource_color :: (r: Resource_Type) -> Color
{
    if #complete r ==
    {
        case .COPPER_VEIN;
            return GREEN;
        case .IRON_VEIN;
            return RED;
        case .WATER;
            return BLUE;
        case .TREE;
            return DARKGREEN;
        case .BUSH;
            return BEIGE;
    }
}

_Entity_ID: u64 = 0;

Entity :: struct
{
    position: Maybe(Vector2);
    collider: Collider;
    tag: Entity_Type;
    id: u64;

    union
    {
        #as resource: Resource;
        #as item: Item;
        #as container: Container;
        #as equipment: Equipment;
        #as person: Person;
    }
}

Entity_Type :: enum
{
    RESOURCE;
    ITEM;
    CONTAINER;
    EQUIPMENT;
    PERSON;
}

Resource :: struct 
{
    type: Resource_Type;
    quantity: int;
    harvestRequirement: Item;
}
Resource_Type :: enum
{
    COPPER_VEIN;
    IRON_VEIN;
    WATER;
    TREE;
    BUSH;
}

Item :: struct
{
    type: Item_Type;
}
Item_Type :: enum
{
    // tools
    CARPENTERS_HAMMER;
    LUMBER_AXE;
    HEWING_SAW;
    // weapons
    SWORD;
    WHIP;
    // byproducts
    COPPER_NUGGET;
    IRON_NUGGET;
    WATER;
    WOOD_LOG;
    FIBER;
}

is_tool :: (type: Item_Type) -> bool
{
    return type == .CARPENTERS_HAMMER || type == .LUMBER_AXE || type == .HEWING_SAW;
}
is_weapon :: (type: Item_Type) -> bool
{
    return type == .SWORD || type == .WHIP;
}

Container :: struct
{
    type: Container_Type;
    using #as inventory: Inventory;
}
Container_Type :: enum
{
    BASKET;
    CHEST;
}

Equipment :: struct
{
    type: Equipment_Type;
    using #as inventory: Inventory;
}
Equipment_Type :: enum
{
    TOOL_BELT;
    WEAPON_BELT;
}

// @Note: Inventory does not have an entity
Inventory :: struct
{
    capacity: int;
    contents: [..] *Entity;
}

NewEntityBase :: (pos: Vector2, collider: Collider, tag: Entity_Type, is_npc: bool = true) -> *Entity
{
    e := New(Entity);
    e.position.value = pos;
    e.position.exists = true;
    e.collider = collider;
    e.tag = tag;
    e.id = _Entity_ID;
    _Entity_ID += 1;
    
    array: *[..] *Entity;
    if tag ==
    {
        case .CONTAINER;
            array = *Game.containers;
        case .ITEM;
            array = *Game.items;
        case .EQUIPMENT;
            array = *Game.equipment;
        case .RESOURCE;
            array = *Game.resources;
        case .PERSON;
            array = *Game.npcs;
    }
    if is_npc then array_add(array, e);

    return e;
}

NewContainer :: (type: Container_Type, collider: Collider, pos: Vector2 = .{0, 0}) -> *Entity
{
    e := NewEntityBase(pos, collider, .CONTAINER);
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

NewItem :: (type: Item_Type, collider: Collider, pos: Vector2 = .{0, 0}) -> *Entity
{
    e := NewEntityBase(pos, collider, .ITEM);
    e.item.type = type;
    return e;
}

NewEquipment :: (type: Equipment_Type, collider: Collider, pos: Vector2 = .{0, 0}) -> *Entity
{
    e := NewEntityBase(pos, collider, .EQUIPMENT);
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
            case .HEWING_SAW;
                DrawCircleV(pos, e.collider.radius * scale, DARKGRAY);
            case .SWORD;
                DrawCircleV(pos, e.collider.radius * scale, BLACK);
            case .WOOD_LOG;
                DrawCircleV(pos, e.collider.radius * scale, BROWN);
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