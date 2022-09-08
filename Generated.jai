#insert #run generate();
generate :: () -> string
{
    // walk the textures directory and collect file name data into 'data'
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

    meta_builder: String_Builder;
    print_to_builder(*meta_builder, generate_entity_types(data));
    print_to_builder(*meta_builder, generate_categorizations(data));
    print_to_builder(*meta_builder, generate_texture_info_getters(data));
    print_to_builder(*meta_builder, generate_instancers(data));

    return builder_to_string(*meta_builder);
}

//
// @Generated: Item_Type ::
//
generate_entity_types :: (data: [..][..] string) -> string
{
    builder: String_Builder; defer reset(*builder);
    item_type_preamble :: "Item_Type :: enum {\n";
    print_to_builder(*builder, item_type_preamble);
    for d, d_index: data[0]
    {
        for t, t_index: data[d_index + 1]
        {
            if begins_with(d, "Items")
            {
                print_to_builder(*builder, tprint("\t%;\n", to_upper_copy(t)));
            }
        }
    }
    postamble :: "}\n\n";
    print_to_builder(*builder, postamble);

    resource_type_preamble :: "Resource_Type :: enum {\n";
    print_to_builder(*builder, resource_type_preamble);
    for d, d_index: data[0]
    {
        for t, t_index: data[d_index + 1]
        {
            if begins_with(d, "Resources")
            {
                print_to_builder(*builder, tprint("\t%;\n", to_upper_copy(t)));
            }
        }
    }
    print_to_builder(*builder, postamble);

    container_type_preamble :: "Container_Type :: enum {\n";
    print_to_builder(*builder, container_type_preamble);
    for d, d_index: data[0]
    {
        for t, t_index: data[d_index + 1]
        {
            if begins_with(d, "Containers")
            {
                print_to_builder(*builder, tprint("\t%;\n", to_upper_copy(t)));
            }
        }
    }
    print_to_builder(*builder, postamble);

    equipment_type_preamble :: "Equipment_Type :: enum {\n";
    print_to_builder(*builder, equipment_type_preamble);
    for d, d_index: data[0]
    {
        for t, t_index: data[d_index + 1]
        {
            if begins_with(d, "Equipments")
            {
                print_to_builder(*builder, tprint("\t%;\n", to_upper_copy(t)));
            }
        }
    }
    print_to_builder(*builder, postamble);

    return builder_to_string(*builder);
}

//
// @Generated: is_tool ::, is_weapon ::, is_byproduct ::, ...
//
generate_categorizations :: (data: [..][..] string) -> string
{
    builder: String_Builder; defer reset(*builder);
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
                    print_to_builder(*builder, tprint("is_% :: (type: Item_Type) -> bool {\n", name));
                    print_to_builder(*builder, "\treturn ");
                }
                print_to_builder(*builder, tprint("type == .%", to_upper_copy(t)));

                if t_index != data[d_index + 1].count - 1
                {
                    print_to_builder(*builder, "\n\t\t|| ");
                }
                else
                {
                    print_to_builder(*builder, ";\n}\n\n");
                }
            }
        }
    }
    return builder_to_string(*builder);
}

//
// @Generated: get_texture_info ::
//
generate_texture_info_getters :: (data: [..][..] string) -> string
{
    builder: String_Builder; defer reset(*builder);
    get_info_preamble :: "get_texture_info :: (type: $T) -> TextureInfo {\n\tinfo: TextureInfo;\n";
    print_to_builder(*builder, get_info_preamble);
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
            print_to_builder(*builder, tprint("\t#if T == %_Type {\n\t\tif type == {\n", name));
            is_first = false;
        }

        catergoryHeader := "";
        for t, t_index: data[d_index + 1]
        {
            if right != catergoryHeader {
                print_to_builder(*builder, tprint("\t\t\t// %\n", right));
                catergoryHeader = right;
            }

            print_to_builder(*builder, tprint("\t\t\tcase .%;\n", to_upper_copy(t)));
            print_to_builder(*builder, tprint("\t\t\t\tinfo.texture = table_find_pointer(*Textures.table, \"%\");\n", t));
        }

        if is_last
        {
            print_to_builder(*builder, "\t\t}\n");
            print_to_builder(*builder, "\t}\n");
            is_first = true;
        }
    }
    print_to_builder(*builder, "\tif info.texture == null then info.texture = *ERROR_TEXTURE;\n");
    print_to_builder(*builder, "\tinfo.size = xy(xx info.texture.width, xx info.texture.height);\n");
    print_to_builder(*builder, "\treturn info;\n");
    print_to_builder(*builder, "}\n");
    return builder_to_string(*builder);
}

//
// @Generated: NewItem ::
//
generate_instancers :: (data: [..][..] string) -> string
{
    builder: String_Builder; defer reset(*builder);
    
    //
    // Items
    //
    {
        // @Jay: for some dumb reason multiline strings are adding extra newlines, so I'll do it by hand
        new_item_preamble1 :: "\nNewItem :: (type: Item_Type, collider: *Collider, pos: Vector2 = .{0, 0}, owner: *Person = null) -> *Item {\n";
        new_item_preamble2 :: "\titem := New(Item);\n";
        new_item_preamble3 :: "\titem.entity = init_entity_data(pos, collider, owner, 0);\n";
        new_item_preamble4 :: "\titem.type = type;\n";
        new_item_preamble5 :: "\titem.entityType = .ITEM;\n";
        new_item_preamble6 :: "\tresize_ratio := 0.5;\n";
        new_item_preamble7 :: "\tif type == {\n";
        print_to_builder(*builder, new_item_preamble1);
        print_to_builder(*builder, new_item_preamble2);
        print_to_builder(*builder, new_item_preamble3);
        print_to_builder(*builder, new_item_preamble4);
        print_to_builder(*builder, new_item_preamble5);
        print_to_builder(*builder, new_item_preamble6);
        print_to_builder(*builder, new_item_preamble7);

        catergoryHeader := "";
        for d, d_index: data[0]
        {
            for t, t_index: data[d_index + 1]
            {
                if begins_with(d, "Items")
                {
                    dummy, left, right := split_from_left(d, #char "/");
                    if right != catergoryHeader {
                        print_to_builder(*builder, tprint("\t\t// %\n", right));
                        catergoryHeader = right;
                    }

                    name := to_upper_copy(t);
                    print_to_builder(*builder, tprint("\t\tcase .%;\n", name));
                    print_to_builder(*builder, tprint("\t\t\titem.textureInfo.texture = table_find_pointer(*Textures.table, \"%\");\n", t));
                    // @Jay: These will go away once texture sizes/format are standardized
                    if t == "whip"      print_to_builder(*builder, "\t\t\tresize_ratio = 0.3;\n");
                    if t == "pick_axe"  print_to_builder(*builder, "\t\t\tresize_ratio = 0.4;\n");
                    if t == "blueprint" print_to_builder(*builder, "\t\t\tresize_ratio = 0.6;\n");
                }
            }
        }
        print_to_builder(*builder, "\t\tcase;\n");
        print_to_builder(*builder, "\t\t\titem.textureInfo.texture = *ERROR_TEXTURE;\n");
        print_to_builder(*builder, "\t}\n");
        print_to_builder(*builder, "\titem.textureInfo.size = xy(xx item.textureInfo.texture.width, xx item.textureInfo.texture.height) * resize_ratio;\n");
        print_to_builder(*builder, "\treturn item;\n");
        print_to_builder(*builder, "}\n");
    }

    //
    // Containers
    //
    {
        new_container_preamble1 :: "\nNewContainer :: (type: Container_Type, collider: *Collider, pos: Vector2 = .{0, 0}, owner: *Person = null) -> *Container {\n";
        new_container_preamble2 :: "\tcontainer := New(Container);\n";
        new_container_preamble3 :: "\tcontainer.entity = init_entity_data(pos, collider, owner, 0);\n";
        new_container_preamble4 :: "\tcontainer.type = type;\n";
        new_container_preamble5 :: "\tcontainer.entityType = .CONTAINER;\n";
        new_container_preamble6 :: "\tcap: int;\n";
        new_container_preamble7 :: "\tif type == {\n";
        print_to_builder(*builder, new_container_preamble1);
        print_to_builder(*builder, new_container_preamble2);
        print_to_builder(*builder, new_container_preamble3);
        print_to_builder(*builder, new_container_preamble4);
        print_to_builder(*builder, new_container_preamble5);
        print_to_builder(*builder, new_container_preamble6);
        print_to_builder(*builder, new_container_preamble7);

        catergoryHeader := "";
        for d, d_index: data[0]
        {
            for t, t_index: data[d_index + 1]
            {
                if begins_with(d, "Containers")
                {
                    dummy, left, right := split_from_left(d, #char "/");
                    if right != catergoryHeader {
                        print_to_builder(*builder, tprint("\t\t// %\n", right));
                        catergoryHeader = right;
                    }

                    name := to_upper_copy(t);
                    print_to_builder(*builder, tprint("\t\tcase .%;\n", name));
                    print_to_builder(*builder, tprint("\t\t\tcontainer.textureInfo.texture = table_find_pointer(*Textures.table, \"%\");\n", t));
                    // @Jay: These will go away once texture sizes/format are standardized
                    if t == "basket" print_to_builder(*builder, "\t\t\tcontainer.textureInfo.tint = BEIGE;\n\t\t\tcap = 100;\n");
                    if t == "chest"  print_to_builder(*builder, "\t\t\tcontainer.textureInfo.tint = BROWN;\n\t\t\tcap = 300;\n");
                    if t == "bucket" print_to_builder(*builder, "\t\t\tcontainer.textureInfo.tint = LIGHTGRAY;\n\t\t\tcap = 100;\n");
                }
            }
        }
        print_to_builder(*builder, "\t\tcase;\n");
        print_to_builder(*builder, "\t\t\tcontainer.textureInfo.texture = *ERROR_TEXTURE;\n");
        print_to_builder(*builder, "\t}\n");
        print_to_builder(*builder, "\tresize_ratio := 0.3;\n");
        print_to_builder(*builder, "\tcontainer.capacity = cap;\n");
        print_to_builder(*builder, "\tcontainer.textureInfo.size = xy(xx container.textureInfo.texture.width, xx container.textureInfo.texture.height) * resize_ratio;\n");
        print_to_builder(*builder, "\treturn container;\n");
        print_to_builder(*builder, "}\n");
    }

    //
    // Equipments
    //
    {
        new_equipment_preamble1 :: "\nNewEquipment :: (type: Equipment_Type, collider: *Collider, pos: Vector2 = .{0, 0}, owner: *Person = null) -> *Equipment {\n";
        new_equipment_preamble2 :: "\tequipment := New(Equipment);\n";
        new_equipment_preamble3 :: "\tequipment.entity = init_entity_data(pos, collider, owner, 0);\n";
        new_equipment_preamble4 :: "\tequipment.type = type;\n";
        new_equipment_preamble5 :: "\tequipment.entityType = .EQUIPMENT;\n";
        new_equipment_preamble6 :: "\tif type == {\n";
        print_to_builder(*builder, new_equipment_preamble1);
        print_to_builder(*builder, new_equipment_preamble2);
        print_to_builder(*builder, new_equipment_preamble3);
        print_to_builder(*builder, new_equipment_preamble4);
        print_to_builder(*builder, new_equipment_preamble5);
        print_to_builder(*builder, new_equipment_preamble6);

        catergoryHeader := "";
        for d, d_index: data[0]
        {
            for t, t_index: data[d_index + 1]
            {
                if begins_with(d, "Equipments")
                {
                    dummy, left, right := split_from_left(d, #char "/");
                    if right != catergoryHeader {
                        print_to_builder(*builder, tprint("\t\t// %\n", right));
                        catergoryHeader = right;
                    }

                    name := to_upper_copy(t);
                    print_to_builder(*builder, tprint("\t\tcase .%;\n", name));
                    print_to_builder(*builder, tprint("\t\t\tequipment.textureInfo.texture = table_find_pointer(*Textures.table, \"%\");\n", t));
                    // @Jay: These will go away once texture sizes/format are standardized
                    if t == "tool_belt"   print_to_builder(*builder, "\t\t\tequipment.textureInfo.tint = BEIGE;\n");
                    if t == "weapon_belt" print_to_builder(*builder, "\t\t\tequipment.textureInfo.tint = BROWN;\n");
                }
            }
        }
        print_to_builder(*builder, "\t\tcase;\n");
        print_to_builder(*builder, "\t\t\tequipment.textureInfo.texture = *ERROR_TEXTURE;\n");
        print_to_builder(*builder, "\t}\n");
        print_to_builder(*builder, "\tresize_ratio := 0.2;\n");
        print_to_builder(*builder, "\tequipment.capacity = 3;\n");
        print_to_builder(*builder, "\tequipment.textureInfo.size = xy(xx equipment.textureInfo.texture.width, xx equipment.textureInfo.texture.height) * resize_ratio;\n");
        print_to_builder(*builder, "\treturn equipment;\n");
        print_to_builder(*builder, "}\n");
    }

    //
    // Resources
    //
    {
        new_resource_preamble1 :: "\nNewResource :: (type: Resource_Type, pos: Vector2, quantity: int) -> *Resource {\n";
        new_resource_preamble2 :: "\tresource := New(Resource);\n";
        new_resource_preamble3 :: "\tmass := ifx type == .BUSH then 0 else 999;\n";
        new_resource_preamble4 :: "\tresource.entity = init_entity_data(pos, null, null, mass);\n";
        new_resource_preamble5 :: "\tresource.type = type;\n";
        new_resource_preamble6 :: "\tresource.entityType = .RESOURCE;\n";
        new_resource_preamble7 :: "\tresource.quantity = quantity;\n";
        new_resource_preamble8 :: "\tif type == {\n";
        print_to_builder(*builder, new_resource_preamble1);
        print_to_builder(*builder, new_resource_preamble2);
        print_to_builder(*builder, new_resource_preamble3);
        print_to_builder(*builder, new_resource_preamble4);
        print_to_builder(*builder, new_resource_preamble5);
        print_to_builder(*builder, new_resource_preamble6);
        print_to_builder(*builder, new_resource_preamble7);
        print_to_builder(*builder, new_resource_preamble8);

        catergoryHeader := "";
        for d, d_index: data[0]
        {
            for t, t_index: data[d_index + 1]
            {
                if begins_with(d, "Resources")
                {
                    dummy, left, right := split_from_left(d, #char "/");
                    if right != catergoryHeader {
                        print_to_builder(*builder, tprint("\t\t// %\n", right));
                        catergoryHeader = right;
                    }

                    name := to_upper_copy(t);
                    print_to_builder(*builder, tprint("\t\tcase .%;\n", name));
                    print_to_builder(*builder, tprint("\t\t\tresource.textureInfo.texture = table_find_pointer(*Textures.table, \"%\");\n", t));
                    harvestRequirement := ""; // @Jay: maybe this indicates a category for Resources?
                    if t == "copper_vein" then harvestRequirement = "PICK_AXE";
                    if t == "iron_vein"   then harvestRequirement = "PICK_AXE";
                    if t == "bush"        then harvestRequirement = "SWORD";
                    if t == "tree"        then harvestRequirement = "LUMBER_AXE";
                    if harvestRequirement != "" then print_to_builder(*builder, tprint("\t\t\tresource.harvestRequirement = NewMaybe(Item_Type.%);\n", harvestRequirement));
                }
            }
        }
        print_to_builder(*builder, "\t\tcase;\n");
        print_to_builder(*builder, "\t\t\tresource.textureInfo.texture = *ERROR_TEXTURE;\n");
        print_to_builder(*builder, "\t}\n");
        print_to_builder(*builder, "\tresize_ratio := 0.5;\n");
        print_to_builder(*builder, "\tbase_size := xy(xx resource.textureInfo.texture.width, xx resource.textureInfo.texture.height);\n");
        print_to_builder(*builder, "\tresource.textureInfo.size = base_size * resize_ratio;\n");
        print_to_builder(*builder, "\tresource.collider = NewCollider(base_size);\n"); // @Jay: this is going to change
        print_to_builder(*builder, "\treturn resource;\n");
        print_to_builder(*builder, "}\n");
    }

    return builder_to_string(*builder);
}