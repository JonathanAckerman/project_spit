get_resource_color :: (r: Resource_Type) -> Color
{
    if #complete r ==
    {
        case .COPPER_VEIN;
            return GREEN;
        case .IRON_VEIN;
            return RED;
        case .TREE;
            return DARKGREEN;
        case .BUSH;
            return BEIGE;
    }
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

NewContainer :: (type: Container_Type, collider: *Collider, pos: Vector3 = .{0, 0, 0}, owner: *Person = null) -> *Container
{
    container := New(Container);
    mass := ifx type == .CHEST then 1 else 0;
    container.entity = init_entity_data(pos, collider, owner, mass);
    container.type = type;
    cap: int;
    if type ==
    {
        case .BASKET;
            container.textureInfo.texture = table_find_pointer(*Textures.table, "basket");
            container.textureInfo.tint = BEIGE;
            cap = 100;
        case .CHEST;
            container.textureInfo.texture = table_find_pointer(*Textures.table, "chest");
            container.textureInfo.tint = BROWN;
            cap = 300;
        case .BUCKET;
            container.textureInfo.texture = table_find_pointer(*Textures.table, "bucket");
            container.textureInfo.tint = LIGHTGRAY;
            cap = 100;
    }
    container.capacity = cap;
    return container;
}

NewItem :: (type: Item_Type, collider: *Collider, pos: Vector3 = .{0, 0, 0}, owner: *Person = null) -> *Item
{
    item := New(Item);
    mass := ifx type == .WOOD_LOG then 1 else 0;
    item.entity = init_entity_data(pos, collider, owner, mass);
    item.type = type;
    if type == 
    {
        // weapons
        case .SWORD;
            item.textureInfo.texture = table_find_pointer(*Textures.table, "sword");
        case .WHIP;
            item.textureInfo.texture = table_find_pointer(*Textures.table, "whip");
        // tools
        case .LUMBER_AXE;
            item.textureInfo.texture = table_find_pointer(*Textures.table, "lumber_axe");
        case .PICK_AXE;
            item.textureInfo.texture = table_find_pointer(*Textures.table, "pick_axe");
        case .HEWING_SAW;
            item.textureInfo.texture = table_find_pointer(*Textures.table, "hewing_saw");
        case .CARPENTERS_HAMMER;
            item.textureInfo.texture = table_find_pointer(*Textures.table, "carpenters_hammer");
        // by-products
        case .WOOD_LOG;
            item.textureInfo.texture = table_find_pointer(*Textures.table, "wood_log");
        case .COPPER_NUGGET;
            item.textureInfo.texture = table_find_pointer(*Textures.table, "copper_nugget");
        case .IRON_NUGGET;
            item.textureInfo.texture = table_find_pointer(*Textures.table, "iron_nugget");
        case .FIBER;
            item.textureInfo.texture = table_find_pointer(*Textures.table, "fiber");
        case;
            item.textureInfo.texture = *ERROR_TEXTURE;
    }
    return item;
}

NewEquipment :: (type: Equipment_Type, collider: *Collider, pos: Vector3 = .{0, 0, 0}, owner: *Person = null) -> *Equipment
{
    equipment := New(Equipment);
    equipment.entity = init_entity_data(pos, collider, owner);
    equipment.type = type;
    if type ==
    {
        case .TOOL_BELT;
            equipment.textureInfo.texture = table_find_pointer(*Textures.table, "tool_belt");
            equipment.textureInfo.tint = BEIGE;
        case .WEAPON_BELT;
            equipment.textureInfo.texture = table_find_pointer(*Textures.table, "weapon_belt");
            equipment.textureInfo.tint = BROWN;
        case;
            equipment.textureInfo.texture = *ERROR_TEXTURE;
    }
    equipment.capacity = 3;
    array_resize(*equipment.contents, equipment.capacity);
    return equipment;
}

NewResource :: (type: Resource_Type, pos: Vector3, quantity: int, req: Maybe(Item_Type)) -> *Resource
{
    resource := New(Resource);
    mass := ifx type == .BUSH then 0 else 999;
    resource.entity = init_entity_data(pos, null, null, mass);
    resource.type = type;
    resource.quantity = quantity;
    resource.harvestRequirement = req;
    if resource.type == 
    {
        case .COPPER_VEIN;
            resource.textureInfo.texture = table_find_pointer(*Textures.table, "copper_vein");
        case .IRON_VEIN;
            resource.textureInfo.texture = table_find_pointer(*Textures.table, "iron_vein");
        case .BUSH;
            resource.textureInfo.texture = table_find_pointer(*Textures.table, "bush");
        case .TREE;
            resource.textureInfo.texture = table_find_pointer(*Textures.table, "tree");
        case;
            resource.textureInfo.texture = *ERROR_TEXTURE;
    }
    size := xy(xx resource.textureInfo.texture.width, xx resource.textureInfo.texture.height);
    resource.collider = NewCollider(size);
    return resource;
}

draw_item :: (item: Item)
{
    if !item.position.exists return;

    layer_size_modifier := 1.0 - (xx item.position.value.z - (Game.camera.position.z + 1)) * 0.1;
    base_size := xy(xx item.textureInfo.width, xx item.textureInfo.height) * 0.5;
    modified_size := base_size * Game.camera.zoom * layer_size_modifier;
    center_pos := to_screen_space(item.position.value.xy);
    drawpos := center_pos - modified_size / 2;
    tint := item.textureInfo.tint;
    tint.r = xx (tint.r * layer_size_modifier);
    tint.g = xx (tint.g * layer_size_modifier);
    tint.b = xx (tint.b * layer_size_modifier);
    DrawTextureEx(item.textureInfo.texture, xx drawpos, 0.0, Game.camera.zoom * layer_size_modifier * 0.5, tint);
}

// @JAY: is there a way to make this generic for any texture lookup? polymorph?
// @JAY: can I generate this during the textureload step?
get_item_texture_info :: (type: Item_Type) -> TextureInfo
{
    info: TextureInfo;
    if type == 
    {
        // weapons
        case .SWORD;
            info.texture = table_find_pointer(*Textures.table, "sword");
        case .WHIP;
            info.texture = table_find_pointer(*Textures.table, "whip");
        // tools
        case .LUMBER_AXE;
            info.texture = table_find_pointer(*Textures.table, "lumber_axe");
        case .PICK_AXE;
            info.texture = table_find_pointer(*Textures.table, "pick_axe");
        case .HEWING_SAW;
            info.texture = table_find_pointer(*Textures.table, "hewing_saw");
        case .CARPENTERS_HAMMER;
            info.texture = table_find_pointer(*Textures.table, "carpenters_hammer");
        // by-products
        case .WOOD_LOG;
            info.texture = table_find_pointer(*Textures.table, "wood_log");
        case .COPPER_NUGGET;
            info.texture = table_find_pointer(*Textures.table, "copper_nugget");
        case .IRON_NUGGET;
            info.texture = table_find_pointer(*Textures.table, "iron_nugget");
        case .FIBER;
            info.texture = table_find_pointer(*Textures.table, "fiber");
        case;
            info.texture = *ERROR_TEXTURE;
    }
    return info;
}
get_equipment_texture_info :: (type: Equipment_Type) -> TextureInfo
{
    info: TextureInfo;
    if type == 
    {
        case .TOOL_BELT;
            info.texture = table_find_pointer(*Textures.table, "tool_belt");
            info.tint = BEIGE;
        case .WEAPON_BELT;
            info.texture = table_find_pointer(*Textures.table, "weapon_belt");
            info.tint = BROWN;
        case;
            info.texture = *ERROR_TEXTURE;
    }
    return info;
}
get_container_texture_info :: (type: Container_Type) -> TextureInfo
{
    info: TextureInfo;
    if type == 
    {
        case .BASKET;
            info.texture = table_find_pointer(*Textures.table, "basket");
            info.tint = BEIGE;
        case .CHEST;
            info.texture = table_find_pointer(*Textures.table, "chest");
            info.tint = BROWN;
        case .BUCKET;
            info.texture = table_find_pointer(*Textures.table, "bucket");
            info.tint = LIGHTGRAY;
    }
    return info;
}

draw_item_ui :: (pos: Vector2, scale: float, type: Item_Type)
{
    drawpos := pos;
    info := get_item_texture_info(type);
    DrawTextureEx(info.texture, xx drawpos, 0.0, scale, info.tint);
}

draw_container :: (container: Container)
{
    if !container.position.exists return;

    layer_size_modifier := 1.0 - (xx container.position.value.z - (Game.camera.position.z + 1)) * 0.1;
    base_size := xy(xx container.textureInfo.width, xx container.textureInfo.height) * 0.3;
    modified_size := base_size * Game.camera.zoom * layer_size_modifier;
    center_pos := to_screen_space(container.position.value.xy);
    drawpos := center_pos - modified_size / 2;
    tint := container.textureInfo.tint;
    tint.r = xx (tint.r * layer_size_modifier);
    tint.g = xx (tint.g * layer_size_modifier);
    tint.b = xx (tint.b * layer_size_modifier);
    DrawTextureEx(container.textureInfo.texture, xx drawpos, 0.0, Game.camera.zoom * layer_size_modifier * 0.3, tint);
    
}

draw_container_ui :: (pos: Vector2, scale: float, type: Container_Type)
{
    drawpos := pos;
    info := get_container_texture_info(type);
    DrawTextureEx(info.texture, xx drawpos, 0.0, scale, info.tint);
}

draw_equipment :: (equipment: Equipment)
{
    if !equipment.position.exists return;

    layer_size_modifier := 1.0 - (xx equipment.position.value.z - (Game.camera.position.z + 1)) * 0.1;
    base_size := xy(xx equipment.textureInfo.width, xx equipment.textureInfo.height) * 0.2;
    modified_size := base_size * Game.camera.zoom * layer_size_modifier;
    center_pos := to_screen_space(equipment.position.value.xy);
    drawpos := center_pos - modified_size / 2;
    tint := equipment.textureInfo.tint;
    tint.r = xx (tint.r * layer_size_modifier);
    tint.g = xx (tint.g * layer_size_modifier);
    tint.b = xx (tint.b * layer_size_modifier);
    DrawTextureEx(equipment.textureInfo.texture, xx drawpos, 0.0, Game.camera.zoom * layer_size_modifier * 0.2, tint);
}

draw_equipment_ui :: (pos: Vector2, scale: float, type: Equipment_Type)
{
    info := get_equipment_texture_info(type);
    size := xy(xx info.texture.width, xx info.texture.height) * scale;
    drawpos := pos - size / 2;
    DrawTextureEx(info.texture, xx drawpos, 0.0, scale, info.tint);
}

draw_resource :: (resource: Resource)
{
    if !resource.position.exists return;

    layer_size_modifier := 1.0 - (xx resource.position.value.z - (Game.camera.position.z + 1)) * 0.1;
    base_size := xy(xx resource.textureInfo.width, xx resource.textureInfo.height) * 0.5;
    modified_size := base_size * Game.camera.zoom * layer_size_modifier;
    center_pos := to_screen_space(resource.position.value.xy);
    drawpos := center_pos - modified_size / 2;
    tint := resource.textureInfo.tint;
    tint.r = xx (tint.r * layer_size_modifier);
    tint.g = xx (tint.g * layer_size_modifier);
    tint.b = xx (tint.b * layer_size_modifier);
    DrawTextureEx(resource.textureInfo.texture, xx drawpos, 0.0, Game.camera.zoom * layer_size_modifier * 0.5, tint);
}