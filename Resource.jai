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
    blueprintData: Maybe(*BlueprintData);
    onSlot: Maybe(*BlueprintSlot);
}

#insert -> string
{
    get_data :: (info: *File_Visit_Info, data: *[..] string) 
    {
        if info.is_directory
        {
            folder_name_size := info.full_name.count - TEXTURES_PATH.count;
            folder_name := slice(info.full_name, TEXTURES_PATH.count + 1, folder_name_size);

            hasSlash, left, right := split_from_left(folder_name, #char "/");
            if hasSlash
            {
                found, index := array_find(data[0], left);
                if found then array_ordered_remove_by_index(*data[0], index);
            }
            
            array_add(data, copy_string(folder_name));
        }
        else
        {
            s := copy_string(info.short_name);
            s.count -= 4;
            array_add(data, s);
        }
    }

    data: [..][..] string; // [0]: directory names, [1]: first dir textures, ...
    array_resize(*data, 1);
    visit_files(TEXTURES_PATH, true, *data[0], get_data, false, true);
    
    for 1..data[0].count
    {
        arr: [..] string;
        array_add(*data, arr);
    }

    for data[0]
    {
        sb: String_Builder;
        print_to_builder(*sb, TEXTURES_PATH);
        print_to_builder(*sb, "/");
        s: string = copy_string(it);
        print_to_builder(*sb, s);
        path := builder_to_string(*sb);
        visit_files(path, false, *data[it_index + 1], get_data, true, true);
    }

    //
    // @Generated: Item_Type ::
    //
    item_type_builder: String_Builder; defer reset(*item_type_builder);
    item_type_preamble :: "Item_Type :: enum {\n";
    print_to_builder(*item_type_builder, item_type_preamble);
    for d, d_index: data[0]
    {
        for t, t_index: data[d_index + 1]
        {
            if begins_with(d, "Items")
            {
                print_to_builder(*item_type_builder, tprint("\t%;\n", to_upper_copy(t)));
            }
        }
    }
    postamble :: "}\n\n";
    print_to_builder(*item_type_builder, postamble);

    //
    // @Generated: is_tool ::, is_weapon ::, is_byproduct ::, ...
    //
    is_a_builder: String_Builder; defer reset(*is_a_builder);
    for d, d_index: data[0]
    {
        for t, t_index: data[d_index + 1]
        {
            if begins_with(d, "Items")
            {
                if t_index == 0 
                {
                    success, left, right := split_from_left(d, #char "/");
                    name := to_lower_copy(right);
                    name.count -= 1; // make the noun singular
                    print_to_builder(*is_a_builder, tprint("is_% :: (type: Item_Type) -> bool {\n", name));
                    print_to_builder(*is_a_builder, "\treturn ");
                }
                print_to_builder(*is_a_builder, tprint("type == .%", to_upper_copy(t)));

                if t_index != data[d_index + 1].count - 1
                {
                    print_to_builder(*is_a_builder, "\n\t\t|| ");
                }
                else
                {
                    print_to_builder(*is_a_builder, ";\n}\n\n");
                }
            }
        }
    }

    //
    // @Generated: get_texture_info ::
    //
    get_info_builder: String_Builder; defer reset(*get_info_builder);
    get_info_preamble :: "get_texture_info :: (type: $T) -> TextureInfo {\n\tinfo: TextureInfo;\n";
    print_to_builder(*get_info_builder, get_info_preamble);
    //count the number of subfolders for later
    num_sub_folders: Table(string, int);
    for d, d_index: data[0]
    {
        name := d;
        success, left, right := split_from_left(d, "/");
        if success then name = left;
        if ends_with(name, "s") then name.count -= 1; // make the noun singular

        value := table_find_pointer(*num_sub_folders, name);
        if value == null then table_add(*num_sub_folders, key=name, value=1);
        else <<value += 1;
    }
    //continue building the string
    is_first := true;
    is_last := false;
    for d, d_index: data[0]
    {
        name := d;
        success, left, right := split_from_left(d, "/");
        if success then name = left;
        if ends_with(name, "s") then name.count -= 1; // make the noun singular

        if name == "Person" continue;

        value := table_find_pointer(*num_sub_folders, name);
        <<value -= 1;
        if <<value == 0 then is_last = true;
        else is_last = false;

        if is_first
        {
            print_to_builder(*get_info_builder, tprint("\t#if T == %_Type {\n\t\tif type == {\n", name));
            is_first = false;
        }

        catergoryHeader := "";
        for t, t_index: data[d_index + 1]
        {
            if right != catergoryHeader {
                print_to_builder(*get_info_builder, tprint("\t\t\t// %\n", right));
                catergoryHeader = right;
            }

            print_to_builder(*get_info_builder, tprint("\t\t\tcase .%;\n", to_upper_copy(t)));
            print_to_builder(*get_info_builder, tprint("\t\t\t\tinfo.texture = table_find_pointer(*Textures.table, \"%\");\n", t));
        }

        if is_last
        {
            print_to_builder(*get_info_builder, "\t\t}\n");
            print_to_builder(*get_info_builder, "\t}\n");
            is_first = true;
        }
    }
    print_to_builder(*get_info_builder, "\tif info.texture == null then info.texture = *ERROR_TEXTURE;\n");
    print_to_builder(*get_info_builder, "\tinfo.size = xy(xx info.texture.width, xx info.texture.height);\n");
    print_to_builder(*get_info_builder, "\treturn info;\n");
    print_to_builder(*get_info_builder, "}\n");

    //
    // @Generated: NewItem ::
    //
    new_item_builder: String_Builder; defer reset(*new_item_builder);
    // @Jay: for some dumb reason multiline strings are adding extra newlines, so I'll do it by hand
    new_item_preamble1 :: "\nNewItem :: (type: Item_Type, collider: *Collider, pos: Vector2 = .{0, 0}, owner: *Person = null) -> *Item {\n";
    new_item_preamble2 :: "\titem := New(Item);\n";
    new_item_preamble3 :: "\titem.entity = init_entity_data(pos, collider, owner, 0);\n";
    new_item_preamble4 :: "\titem.type = type;\n";
    new_item_preamble5 :: "\titem.entityType = .ITEM;\n";
    new_item_preamble6 :: "\tresize_ratio := 0.5;\n";
    new_item_preamble7 :: "\tif type == {\n";
    print_to_builder(*new_item_builder, new_item_preamble1);
    print_to_builder(*new_item_builder, new_item_preamble2);
    print_to_builder(*new_item_builder, new_item_preamble3);
    print_to_builder(*new_item_builder, new_item_preamble4);
    print_to_builder(*new_item_builder, new_item_preamble5);
    print_to_builder(*new_item_builder, new_item_preamble6);
    print_to_builder(*new_item_builder, new_item_preamble7);

    catergoryHeader := "";
    for d, d_index: data[0]
    {
        for t, t_index: data[d_index + 1]
        {
            if begins_with(d, "Items")
            {
                dummy, left, right := split_from_left(d, #char "/");
                if right != catergoryHeader {
                    print_to_builder(*new_item_builder, tprint("\t\t// %\n", right));
                    catergoryHeader = right;
                }

                name := to_upper_copy(t);
                print_to_builder(*new_item_builder, tprint("\t\tcase .%;\n", name));
                print_to_builder(*new_item_builder, tprint("\t\t\titem.textureInfo.texture = table_find_pointer(*Textures.table, \"%\");\n", t));
                // @Jay: These will go away once texture sizes/format are standardized
                if t == "whip"      print_to_builder(*new_item_builder, "\t\t\tresize_ratio = 0.3;\n");
                if t == "pick_axe"  print_to_builder(*new_item_builder, "\t\t\tresize_ratio = 0.4;\n");
                if t == "blueprint" print_to_builder(*new_item_builder, "\t\t\tresize_ratio = 0.6;\n");
            }
        }
    }
    print_to_builder(*new_item_builder, "\t\tcase;\n");
    print_to_builder(*new_item_builder, "\t\t\titem.textureInfo.texture = *ERROR_TEXTURE;\n");
    print_to_builder(*new_item_builder, "\t}\n");
    print_to_builder(*new_item_builder, "\titem.textureInfo.size = xy(xx item.textureInfo.texture.width, xx item.textureInfo.texture.height) * resize_ratio;\n");
    print_to_builder(*new_item_builder, "\treturn item;\n");
    print_to_builder(*new_item_builder, "}\n");

    meta_builder: String_Builder;
    print_to_builder(*meta_builder, builder_to_string(*item_type_builder));
    print_to_builder(*meta_builder, builder_to_string(*is_a_builder));
    print_to_builder(*meta_builder, builder_to_string(*get_info_builder));
    print_to_builder(*meta_builder, builder_to_string(*new_item_builder));

    return builder_to_string(*meta_builder);
};

get_byproduct_slot_type :: (type: Item_Type) -> Slot_Type
{
    if type == 
    {
        case .FIBER; #through;
        case .WOOD_LOG;
            return .SPAN;
        case .NAILS;
            return .JOINT;
        case;
            return .INVALID;
    }
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