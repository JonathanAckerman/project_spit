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
    position: Maybe(Vector3);
    collider: Collider;
    id: u64;
    texture: Maybe(*Texture2D);
    owner: Maybe(*Person);
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
    PICK_AXE;
    // weapons
    SWORD;
    WHIP;
    // byproducts
    COPPER_NUGGET;
    IRON_NUGGET;
    WATER; // this might work differently
    WOOD_LOG;
    FIBER;
}

is_tool :: (type: Item_Type) -> bool
{
    return type == .CARPENTERS_HAMMER || type == .LUMBER_AXE || type == .HEWING_SAW || type == .PICK_AXE;
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
    BUCKET;
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

init_entity_data :: (pos: Vector3, collider: Collider, owner: *Person = null) -> Entity
{
    e: Entity;
    e.position.value = pos;
    e.position.exists = true;
    e.collider = collider;
    if owner != null then e.owner = NewMaybe(owner);
    else e.owner = Nothing(*Person);
    e.id = _Entity_ID;
    _Entity_ID += 1;
    return e;
}

NewContainer :: (type: Container_Type, collider: Collider, pos: Vector3 = .{0, 0, 0}, owner: *Person = null) -> *Container
{
    container := New(Container);
    container.entity = init_entity_data(pos, collider, owner);
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

NewItem :: (type: Item_Type, collider: Collider, pos: Vector3 = .{0, 0, 0}, owner: *Person = null) -> *Item
{
    item := New(Item);
    item.entity = init_entity_data(pos, collider, owner);
    item.type = type;
    if type == 
    {
        case .WOOD_LOG;
            item.texture.value = table_find_pointer(*Textures.table, "wood_log");
        case .SWORD;
            item.texture.value = table_find_pointer(*Textures.table, "sword");
        case .LUMBER_AXE;
            item.texture.value = table_find_pointer(*Textures.table, "lumber_axe");
        case .PICK_AXE;
            item.texture.value = table_find_pointer(*Textures.table, "pick_axe");
        case .HEWING_SAW;
            item.texture.value = table_find_pointer(*Textures.table, "hewing_saw");
    }
    if item.texture.value == null then item.texture.value = *ERROR_TEXTURE;
    item.texture.exists = true;
    return item;
}

NewEquipment :: (type: Equipment_Type, collider: Collider, pos: Vector3 = .{0, 0, 0}, owner: *Person = null) -> *Equipment
{
    equipment := New(Equipment);
    equipment.entity = init_entity_data(pos, collider, owner);
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

NewResource :: (type: Resource_Type, collider: Collider, pos: Vector3, quantity: int, req: Maybe(Item_Type)) -> *Resource
{
    resource := New(Resource);
    resource.entity = init_entity_data(pos, collider);
    resource.type = type;
    resource.quantity = quantity;
    resource.harvestRequirement = req;
    if resource.type == 
    {
        case .COPPER_VEIN;
            resource.texture.value = table_find_pointer(*Textures.table, "copper_vein");
        case .IRON_VEIN;
            resource.texture.value = table_find_pointer(*Textures.table, "iron_vein");
        case .BUSH;
            resource.texture.value = table_find_pointer(*Textures.table, "bush");
        case .TREE;
            resource.texture.value = table_find_pointer(*Textures.table, "tree");
    }
    if resource.texture.value == null then resource.texture.value = *ERROR_TEXTURE;
    resource.texture.exists = true;
    return resource;
}

draw_item :: (item: Item)
{
    if !item.position.exists return;

    layer_size_modifier := 1.0 - (item.position.value.z - cast(int) Game.camera.position.z) * 0.1;
    base_size := xy(xx item.texture.value.width, xx item.texture.value.height) * 0.5;
    modified_size := base_size * Game.camera.zoom * layer_size_modifier;
    center_pos := to_screen_space(item.position.value.xy);
    drawpos := center_pos - modified_size / 2;
    tint := Color.{255, 255, 255, 255};
    tint.r = xx (tint.r * layer_size_modifier);
    tint.g = xx (tint.g * layer_size_modifier);
    tint.b = xx (tint.b * layer_size_modifier);
    DrawTextureEx(item.texture.value, xx drawpos, 0.0, Game.camera.zoom * layer_size_modifier * 0.5, tint);
    DrawRectangleLines(xx drawpos.x, xx drawpos.y, xx modified_size.x, xx modified_size.y, PINK);
}

get_item_texture :: (type: Item_Type) -> Maybe(*Texture2D)
{
    texture: Maybe(*Texture2D);
    if type == 
    {
        case .WOOD_LOG;
            texture.value = table_find_pointer(*Textures.table, "wood_log");
        case .SWORD;
            texture.value = table_find_pointer(*Textures.table, "sword");
        case .LUMBER_AXE;
            texture.value = table_find_pointer(*Textures.table, "lumber_axe");
        case .PICK_AXE;
            texture.value = table_find_pointer(*Textures.table, "pick_axe");
        case .HEWING_SAW;
            texture.value = table_find_pointer(*Textures.table, "hewing_saw");
    }
    if texture.value == null then texture.value = *ERROR_TEXTURE;
    texture.exists = true;
    return texture;
}

draw_item_ui :: (pos: Vector2, collider: Collider, scale: float, type: Item_Type)
{
    drawpos := pos;
    texture := get_item_texture(type);
    DrawTextureEx(texture.value, xx drawpos, 0.0, scale, WHITE);
    DrawRectangleLines(xx drawpos.x, xx drawpos.y, xx (texture.value.width * scale), xx (texture.value.height * scale), PINK);
}

draw_container :: (container: Container)
{
    if !container.position.exists return;

    scale := 1.0;
    scale *= Game.camera.zoom;
    pos := to_screen_space(container.position.value.xy);
    if container.type ==
    {
        case .BASKET;
            DrawRectangleV(pos, container.collider.rect * scale, BEIGE);
            DrawCircleV(pos + xy(container.collider.rect.x/2.0, container.collider.rect.y) * scale, (container.collider.rect.x/2.0) * scale, BEIGE);
        case .CHEST;
            DrawRectangleV(pos, container.collider.rect * scale, DARKGREEN);
            DrawCircleV(pos + xy(container.collider.rect.x/2.0, 0) * scale, (container.collider.rect.x/2.0) * scale, DARKGREEN);
        case .BUCKET;
            DrawRectangleV(pos, container.collider.rect * scale, LIGHTGRAY);
            DrawCircleV(pos + xy(container.collider.rect.x/2.0, container.collider.rect.y) * scale, (container.collider.rect.x/2.0) * scale, LIGHTGRAY);
    }
}

draw_container_ui :: (pos: Vector2, collider: Collider, scale: float, type: Container_Type)
{
    drawpos := pos;
    if type ==
    {
        case .BASKET;
            DrawRectangleV(drawpos, collider.rect * scale, BEIGE);
            DrawCircleV(drawpos + xy(collider.rect.x/2.0, collider.rect.y - 2), (collider.rect.x/2.0) * scale, BEIGE);
        case .BUCKET;
            DrawRectangleV(drawpos, collider.rect * scale, LIGHTGRAY);
            DrawCircleV(drawpos + xy(collider.rect.x/2.0, collider.rect.y - 2), (collider.rect.x/2.0) * scale, LIGHTGRAY);
        case .CHEST;
            DrawRectangleV(drawpos + .{0, -8}, collider.rect * scale, DARKGREEN);
            DrawCircleV(drawpos + xy(collider.rect.x/2.0, -6), (collider.rect.x/2.0) * scale, DARKGREEN);
    }
}

draw_equipment :: (equipment: Equipment)
{
    if !equipment.position.exists return;

    scale := 1.0;
    scale *= Game.camera.zoom;
    pos := to_screen_space(equipment.position.value.xy);

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

    layer_size_modifier := 1.0 - (resource.position.value.z - cast(int) Game.camera.position.z) * 0.1;
    base_size := xy(xx resource.texture.value.width, xx resource.texture.value.height) * 0.5;
    modified_size := base_size * Game.camera.zoom * layer_size_modifier;
    center_pos := to_screen_space(resource.position.value.xy);
    if resource.texture.exists 
    {
        drawpos := center_pos - modified_size / 2;
        tint := Color.{255, 255, 255, 255};
        tint.r = xx (tint.r * layer_size_modifier);
        tint.g = xx (tint.g * layer_size_modifier);
        tint.b = xx (tint.b * layer_size_modifier);
        DrawTextureEx(resource.texture.value, xx drawpos, 0.0, Game.camera.zoom * layer_size_modifier * 0.5, tint);
        DrawRectangleLines(xx drawpos.x, xx drawpos.y, xx modified_size.x, xx modified_size.y, PINK);
        resource_color := get_resource_color(resource.type);
        EndShaderMode();
        DrawCircleV(center_pos, xx resource.quantity * Game.camera.zoom * layer_size_modifier, resource_color);
    }
    else
    {
        resource_color := get_resource_color(resource.type);
        DrawCircleV(center_pos, xx resource.quantity * Game.camera.zoom * layer_size_modifier, resource_color);
    }
}