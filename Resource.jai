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
    id: u64;
    texture: Maybe(Texture2D);
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
    using #as entity: Entity;
    type: Resource_Type;
    quantity: int;
    harvestRequirement: Maybe(Item_Type);
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
    using #as entity: Entity;
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
    using #as entity: Entity;
    type: Container_Type;
    capacity: int;
    contents: [..] Holdable;
}
Container_Type :: enum
{
    BASKET;
    CHEST;
}

Equipment :: struct
{
    using #as entity: Entity;
    type: Equipment_Type;
    capacity: int;
    contents: [] Maybe(*Item);
}
Equipment_Type :: enum
{
    TOOL_BELT;
    WEAPON_BELT;
}

Holdable :: struct
{
    tag: Entity_Type;
    union
    {
        #as item: *Item;
        #as container: *Container;
        #as equipment: *Equipment;
    }
}

as_holdable :: (item: *Item) -> Holdable
{
    h: Holdable;
    h.item = item;
    h.tag = .ITEM;
    return h;
}

as_holdable :: (container: *Container) -> Holdable
{
    h: Holdable;
    h.container = container;
    h.tag = .CONTAINER;
    return h;
}

as_holdable :: (equipment: *Equipment) -> Holdable
{
    h: Holdable;
    h.equipment = equipment;
    h.tag = .EQUIPMENT;
    return h;
}

init_entity_data :: (pos: Vector2, collider: Collider) -> Entity
{
    e: Entity;
    e.position.value = pos;
    e.position.exists = true;
    e.collider = collider;
    e.id = _Entity_ID;
    _Entity_ID += 1;
    return e;
}

NewContainer :: (type: Container_Type, collider: Collider, pos: Vector2 = .{0, 0}) -> *Container
{
    container := New(Container);
    container.entity = init_entity_data(pos, collider);
    container.type = type;
    cap: int;
    if type ==
    {
        case .BASKET;
            cap = 100;
        case .CHEST;
            cap = 300;
    }
    container.capacity = cap;
    return container;
}

NewItem :: (type: Item_Type, collider: Collider, pos: Vector2 = .{0, 0}) -> *Item
{
    item := New(Item);
    item.entity = init_entity_data(pos, collider);
    item.type = type;
    if type == .WOOD_LOG then item.texture.value = LoadTexture("./assets/textures/wood_log.png"); item.texture.exists = true;
    return item;
}

NewEquipment :: (type: Equipment_Type, collider: Collider, pos: Vector2 = .{0, 0}) -> *Equipment
{
    equipment := New(Equipment);
    equipment.entity = init_entity_data(pos, collider);
    equipment.type = type;
    cap: int;
    if type ==
    {
        case .TOOL_BELT;
            cap = 3;
        case .WEAPON_BELT;
            cap = 3;
    }
    equipment.capacity = cap;
    array_resize(*equipment.contents, equipment.capacity);
    return equipment;
}

NewResource :: (type: Resource_Type, collider: Collider, pos: Vector2, quantity: int, req: Maybe(Item_Type)) -> *Resource
{
    resource := New(Resource);
    resource.entity = init_entity_data(pos, collider);
    resource.type = type;
    resource.quantity = quantity;
    resource.harvestRequirement = req;
    return resource;
}

draw_item :: (item: Item)
{
    if !item.position.exists return;

    scale := 1.0;
    scale *= Game.camera.zoom;
    pos := to_screen_space(item.position.value);
    if item.type == 
    {
        case .LUMBER_AXE;
            DrawCircleV(pos, item.collider.radius * scale, GRAY);
        case .HEWING_SAW;
            DrawCircleV(pos, item.collider.radius * scale, DARKGRAY);
        case .SWORD;
            DrawCircleV(pos, item.collider.radius * scale, BLACK);
        case .WOOD_LOG;
            drawpos := pos;
            drawpos.x -= (item.texture.value.width * scale) / 2;
            drawpos.y -= (item.texture.value.height * scale) - (10 * scale);
            DrawTextureEx(item.texture.value, xx drawpos, 0.0, scale, WHITE);
            DrawRectangleLines(xx drawpos.x, xx drawpos.y, xx (item.texture.value.width * scale), xx (item.texture.value.height * scale), PINK);
            DrawCircleV(pos, item.collider.radius * scale, BROWN);
    }
}

draw_item_ui :: (pos: Vector2, collider: Collider, scale: float, type: Item_Type)
{
    drawpos := pos;
    if type == 
    {
        case .LUMBER_AXE;
            DrawCircleV(drawpos, collider.radius * scale, GRAY);
        case .HEWING_SAW;
            DrawCircleV(drawpos, collider.radius * scale, DARKGRAY);
        case .SWORD;
            DrawCircleV(drawpos, collider.radius * scale, BLACK);
        case .WOOD_LOG;
            DrawCircleV(drawpos, collider.radius * scale, BROWN);
    }
}

draw_container :: (container: Container)
{
    if !container.position.exists return;

    scale := 1.0;
    scale *= Game.camera.zoom;
    pos := to_screen_space(container.position.value);
    if container.type ==
    {
        case .BASKET;
            DrawRectangleV(pos, container.collider.rect * scale, BEIGE);
            DrawCircleV(pos + xy(container.collider.rect.x/2.0, container.collider.rect.y) * scale, (container.collider.rect.x/2.0) * scale, BEIGE);
        case .CHEST;
            DrawRectangleV(pos, container.collider.rect * scale, DARKGREEN);
            DrawCircleV(pos + xy(container.collider.rect.x/2.0, 0) * scale, (container.collider.rect.x/2.0) * scale, DARKGREEN);
    }
}

draw_container_ui :: (pos: Vector2, collider: Collider, scale: float, type: Container_Type)
{
    drawpos := pos;
    if type ==
    {
        case .BASKET;
            DrawRectangleV(drawpos, collider.rect * scale, BEIGE);
            DrawCircleV(drawpos + xy(collider.rect.x/2.0 - 2, collider.rect.y - 2), (collider.rect.x/2.0) * scale, BEIGE);
        case .CHEST;
            DrawRectangleV(drawpos + .{0, 8}, collider.rect * scale, DARKGREEN);
            DrawCircleV(drawpos + xy(collider.rect.x/2.0 - 2, 6), (collider.rect.x/2.0) * scale, DARKGREEN);
    }
}

draw_equipment :: (equipment: Equipment)
{
    if !equipment.position.exists return;

    scale := 1.0;
    scale *= Game.camera.zoom;
    pos := to_screen_space(equipment.position.value);

    if equipment.type ==
    {
        case .TOOL_BELT;
            DrawRectangleV(pos, equipment.collider.rect * scale, GREEN);
        case .WEAPON_BELT;
            DrawRectangleV(pos, equipment.collider.rect * scale, RED);
    }
}

draw_equipment_ui :: (pos: Vector2, collider: Collider, scale: float, type: Equipment_Type)
{
    drawpos := pos;

    if type ==
    {
        case .TOOL_BELT;
            DrawRectangleV(drawpos, collider.rect * scale, GREEN);
        case .WEAPON_BELT;
            DrawRectangleV(drawpos, collider.rect * scale, RED);
    }
}

draw_resource :: (resource: Resource)
{
    if !resource.position.exists return;

    scale := 1.0;
    scale *= Game.camera.zoom;
    pos := to_screen_space(resource.position.value);
    if resource.texture.exists 
    {
        drawpos := pos;
        drawpos.x -= (resource.texture.value.width * scale) / 2;
        drawpos.y -= (resource.texture.value.height * scale) - (resource.quantity * scale);
        DrawTextureEx(resource.texture.value, xx drawpos, 0.0, scale, WHITE);
        DrawRectangleLines(xx drawpos.x, xx drawpos.y, xx (resource.texture.value.width * scale), xx (resource.texture.value.height * scale), PINK);
        resource_color := get_resource_color(resource.type);
        DrawCircleV(pos, xx resource.quantity * scale, resource_color);
    }
    else
    {
        resource_color := get_resource_color(resource.type);
        DrawCircleV(pos, xx resource.quantity * scale, resource_color);
    }
}