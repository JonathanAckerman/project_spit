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
    // other?
    BLUEPRINT;
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
    contents: [..] Containable;
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

NewContainer :: (type: Container_Type, collider: *Collider, pos: Vector2 = .{0, 0}, owner: *Person = null) -> *Container
{
    container := New(Container);
    mass := ifx type == .CHEST then 1 else 0;
    container.entity = init_entity_data(pos, collider, owner, mass);
    container.type = type;
    container.entityType = .CONTAINER;
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
    resize_ratio := 0.3;
    container.textureInfo.size = xy(xx container.textureInfo.texture.width, xx container.textureInfo.texture.height) * resize_ratio;
    return container;
}

NewItem :: (type: Item_Type, collider: *Collider, pos: Vector2 = .{0, 0}, owner: *Person = null) -> *Item
{
    item := New(Item);
    mass := ifx type == .WOOD_LOG then 1 else 0; // @Jay: why do logs have a mass of 1?
    item.entity = init_entity_data(pos, collider, owner, mass);
    item.type = type;
    item.entityType = .ITEM;
    resize_ratio := 0.5;
    if type == 
    {
        // weapons
        case .SWORD;
            item.textureInfo.texture = table_find_pointer(*Textures.table, "sword");
        case .WHIP;
            item.textureInfo.texture = table_find_pointer(*Textures.table, "whip");
            resize_ratio = 0.3;
        // tools
        case .LUMBER_AXE;
            item.textureInfo.texture = table_find_pointer(*Textures.table, "lumber_axe");
        case .PICK_AXE;
            item.textureInfo.texture = table_find_pointer(*Textures.table, "pick_axe");
            resize_ratio = 0.4;
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
        // other?
        case .BLUEPRINT;
            item.textureInfo.texture = table_find_pointer(*Textures.table, "blueprint");
            resize_ratio = 0.6;
        case;
            item.textureInfo.texture = *ERROR_TEXTURE;
    }
    item.textureInfo.size = xy(xx item.textureInfo.texture.width, xx item.textureInfo.texture.height) * resize_ratio;
    return item;
}

NewEquipment :: (type: Equipment_Type, collider: *Collider, pos: Vector2 = .{0, 0}, owner: *Person = null) -> *Equipment
{
    equipment := New(Equipment);
    equipment.entity = init_entity_data(pos, collider, owner);
    equipment.type = type;
    equipment.entityType = .EQUIPMENT;
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
    resize_ratio := 0.2;
    equipment.textureInfo.size = xy(xx equipment.textureInfo.texture.width, xx equipment.textureInfo.texture.height) * resize_ratio;
    return equipment;
}

NewResource :: (type: Resource_Type, pos: Vector2, quantity: int) -> *Resource
{
    resource := New(Resource);
    mass := ifx type == .BUSH then 0 else 999;
    resource.entity = init_entity_data(pos, null, null, mass);
    resource.type = type;
    resource.entityType = .RESOURCE;
    resource.quantity = quantity;
    // @TEMP: for now make resizing preserve aspect ratio
    if resource.type == 
    {
        case .COPPER_VEIN;
            resource.textureInfo.texture = table_find_pointer(*Textures.table, "copper_vein");
            resource.harvestRequirement = NewMaybe(Item_Type.PICK_AXE);
        case .IRON_VEIN;
            resource.textureInfo.texture = table_find_pointer(*Textures.table, "iron_vein");
            resource.harvestRequirement = NewMaybe(Item_Type.PICK_AXE);
        case .BUSH;
            resource.textureInfo.texture = table_find_pointer(*Textures.table, "bush");
            resource.harvestRequirement = NewMaybe(Item_Type.SWORD);
        case .TREE;
            resource.textureInfo.texture = table_find_pointer(*Textures.table, "tree");
            resource.harvestRequirement = NewMaybe(Item_Type.LUMBER_AXE);
        case;
            resource.textureInfo.texture = *ERROR_TEXTURE;
    }
    resize_ratio := 0.5;
    base_size := xy(xx resource.textureInfo.texture.width, xx resource.textureInfo.texture.height);
    resource.textureInfo.size = base_size * resize_ratio;
    resource.collider = NewCollider(base_size);
    return resource;
}