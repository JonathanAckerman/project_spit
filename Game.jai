Game: struct 
{
    resetting: bool;
    paused: bool;

    player: Player;
    craftIndex := 0;
    craftTarget: Maybe(CraftTarget);
    grid: Grid;
    camera: struct
    {
        zoom := 1.0;
        position: Vector2;
    }
    dt: float;

    resources:  [..] *Resource;
    items:      [..] *Item;
    containers: [..] *Container;
    equipment:  [..] *Equipment;
    npcs:       [..] *Person;
    shops:      [..] *Shop;

    ui: [..] UI_Representation;

    openContainerTarget: Maybe(*Container);
}

game_loop :: inline ()
{
    using Game;
    dt = GetFrameTime();
    dt *= Debug.dtMultiplier;

    // Input
    handle_input();

    npc_text_to_draw: [..] string;
    // Simulate
    {
        handle_collision(*player.entity);
        if player.position.exists then player.position.value += player.velocity;
        bound_to_grid(*player.entity);
        player.velocity = .{};

        update_current_chunk();

        if !Debug.freeCamera
        {
            camera.position = player.position.value;
        }

        equipItem :: ()
        {
            player := Game.player;
            held := *Game.player.held;
            belt_inventory := ifx Input.equipSlot < 3 then *Game.player.toolBelt else *Game.player.weaponBelt;
            slot := ifx Input.equipSlot < 3 then Input.equipSlot else Input.equipSlot - 3;

            if belt_inventory.exists && belt_inventory.value.contents.count > 0
            {
                if held.exists
                {
                    if held.value.tag ==
                    {
                        case .ITEM;
                            sheath_inv: *Equipment = null;
                            if is_tool(held.value.item.type) && player.toolBelt.exists then sheath_inv = player.toolBelt.value;
                            else if is_weapon(held.value.item.type) && player.weaponBelt.exists then sheath_inv = player.weaponBelt.value;

                            if sheath_inv == null // drop on ground
                            {
                                held.value.item.position.value = player.position.value + player.forward;
                                held.value.item.position.exists = true;
                                belt_inventory.value.contents[slot].exists = false;
                                held.value = as_holdable(belt_inventory.value.contents[slot].value);
                            }
                            else
                            {
                                if !belt_inventory.value.contents[slot].exists
                                {
                                    Input.equipSlot = -1;
                                    return;
                                }

                                if sheath_inv == belt_inventory.value
                                {
                                    temp := held.value;
                                    held.value = as_holdable(belt_inventory.value.contents[slot].value);
                                    belt_inventory.value.contents[slot] = maybe(temp.item);
                                    Input.equipSlot = -1;
                                    return;
                                }
                                else
                                {
                                    has_sheathed := false;
                                    for sheath_inv.contents // look for first available slot
                                    {
                                        if !it.exists
                                        {
                                            sheath_inv.contents[it_index].value = held.value.item;
                                            sheath_inv.contents[it_index].exists = true;
                                            has_sheathed = true;
                                            belt_inventory.value.contents[slot].exists = false;
                                            held.value = as_holdable(belt_inventory.value.contents[slot].value);
                                            break;
                                        }
                                    }

                                    if !has_sheathed // there was no available slot, drop on the ground
                                    {
                                        held.value.item.position.value = player.position.value + player.forward;
                                        held.value.item.position.exists = true;
                                        belt_inventory.value.contents[slot].exists = false;
                                        held.value = as_holdable(belt_inventory.value.contents[slot].value);
                                    }
                                }
                            }

                        case .CONTAINER;
                            held.value.container.position.value = player.position.value + player.forward;
                            held.value.container.position.exists = true;
                            belt_inventory.value.contents[slot].exists = false;
                            held.value = as_holdable(belt_inventory.value.contents[slot].value);
                    }
                    belt_inventory.value.contents[slot].exists = false;
                }
                else
                {
                    held.value = as_holdable(belt_inventory.value.contents[slot].value);
                    held.exists = true;
                    belt_inventory.value.contents[slot].exists = false;
                }
            }

            Input.equipSlot = -1; // reset input state
        }
        if Input.equipSlot != -1 then equipItem();

        drop_held :: ()
        {
            using Game;
            
            if !player.held.exists return;

            held := player.held.value;
            if held.tag ==
            {
                case .ITEM;
                    if openContainerTarget.exists
                    {
                        if openContainerTarget.value.contents.count < openContainerTarget.value.capacity
                        {
                            array_add(*openContainerTarget.value.contents, as_containable(held.item));
                            print("added item to: %_%\n", openContainerTarget.value.type, openContainerTarget.value.id);
                            print("%\n", openContainerTarget.value.contents);
                        }
                        else print("NO SPACE!\n");
                    }
                    else
                    {
                        held.item.position.exists = true;
                        held.item.forward = player.forward;
                        if held.item.blueprintData.exists
                        {
                            held.item.position.value = grid_to_world(world_to_grid(player.position.value), shouldGetCenter=true);
                            held.item.animation = NewAnimation(Animation_Key(held.item.type, "unroll"));
                        }
                        else
                        {
                            held.item.position.value = player.position.value + player.forward;
                        }
                    }
                case .CONTAINER;
                    held.container.position.exists = true;
                    held.container.position.value = player.position.value + player.forward;
                case .EQUIPMENT;
                    held.equipment.position.exists = true;
                    held.equipment.position.value = player.position.value + player.forward;
            }

            player.held.exists = false;
            Input.drop = false;
        }
        if Input.drop then drop_held();

        try_pickup :: ()
        {
            using Game;
            for get_interactible_holdables() if it.tag == {
                case .EQUIPMENT;
                    if it.equipment.type ==
                    {
                        case .TOOL_BELT;
                            if !player.toolBelt.exists // @TODO: Eventually swap between belts if the player is already wearing one?
                            {
                                it.equipment.position.exists = false;
                                m := maybe(it.equipment);
                                player.toolBelt = m;
                                break;
                            }
                        case .WEAPON_BELT;
                            if !player.weaponBelt.exists
                            {
                                it.equipment.position.exists = false;
                                m := maybe(it.equipment);
                                player.weaponBelt = m;
                                break;
                            }
                    }

                case .ITEM;
                    if it.item.blueprintData.exists
                    {
                        for slot: it.item.blueprintData.value.slots if slot.item.exists
                        {
                            continue it;
                        }

                        it.item.animation = NewAnimation(Animation_Key(it.item.type, "rollup"));
                    }

                    if !player.held.exists
                    {
                        if it.item.onSlot.exists
                        {
                            craftIndex = it.item.onSlot.value.index;
                            it.item.onSlot.value.item.exists = false;
                            it.item.onSlot.exists = false;
                        }

                        player.held.value = it;
                        player.held.exists = true;
                        player.held.value.item.position.exists = false;
                        break;
                    }
                    else // player is already holding an item
                    {
                        if it.item.onSlot.exists return;

                        held := player.held.value;
                        dest_inv: *Equipment = null;
                        if is_tool(it.item.type) && player.toolBelt.exists then dest_inv = player.toolBelt.value;
                        else if is_weapon(it.item.type) && player.weaponBelt.exists then dest_inv = player.weaponBelt.value;
                        if dest_inv == null // item on ground has no place to go but held
                        {
                            if held.tag ==
                            {
                                case .ITEM;
                                    sheath_inv : *Equipment = null;
                                    if is_tool(held.item.type) && player.toolBelt.exists then sheath_inv = player.toolBelt.value;
                                    else if is_weapon(held.item.type) && player.weaponBelt.exists then sheath_inv = player.weaponBelt.value;

                                    if sheath_inv != null
                                    {
                                        has_sheathed := false;
                                        for sheath_inv.contents // look for the first available slot
                                        {
                                            if !it.exists
                                            {
                                                sheath_inv.contents[it_index].value = held.item;
                                                sheath_inv.contents[it_index].exists = true;
                                                has_sheathed = true;
                                                break;
                                            }
                                        }

                                        if !has_sheathed
                                        {
                                            held.item.position.value = it.item.position.value;
                                            held.item.position.exists = true;
                                        }
                                    }
                                    else // swap with item on ground
                                    {
                                        held.item.position.value = it.item.position.value;
                                        held.item.position.exists = true;
                                    }
                                case .CONTAINER;
                                    held.container.position.value = it.item.position.value;
                                    held.container.position.exists = true;
                                case .EQUIPMENT;
                                    held.equipment.position.value = it.item.position.value;
                                    held.equipment.position.exists = true;
                            }
                            it.item.position.exists = false;
                            player.held.value = it;
                            break;
                        }
                        else
                        {
                            has_sheathed := false;
                            if dest_inv.contents.count < dest_inv.capacity
                            {
                                dest_inv.contents[dest_inv.contents.count] = maybe(it.item);
                            }
                            else
                            {
                                for slot, slot_index : dest_inv.contents // look for first available slot
                                {
                                    if !slot.exists
                                    {
                                        dest_inv.contents[slot_index].value = it.item;
                                        dest_inv.contents[slot_index].exists = true;
                                        has_sheathed = true;
                                        break;
                                    }
                                }
                            }

                            if !has_sheathed // there was no available slot, drop held on the ground
                            {
                                if held.tag ==
                                {
                                    case .ITEM;
                                        held.item.position.value = it.item.position.value;
                                        held.item.position.exists = true;
                                    case .CONTAINER;
                                        held.container.position.value = it.item.position.value;
                                        held.container.position.exists = true;
                                    case .EQUIPMENT;
                                        held.equipment.position.value = it.item.position.value;
                                        held.equipment.position.exists = true;
                                }
                            }

                            it.item.position.exists = false;
                            break;
                        }
                    }

                case .CONTAINER;
                    if !player.held.exists
                    {
                        it.container.position.exists = false;
                        newHeld: = maybe(it);
                        player.held = newHeld;
                        break;
                    }
                    else
                    {
                        found, index := array_find(containers, it.container);
                        if found
                        {
                            held := player.held.value;
                            if held.tag ==
                            {
                                case .ITEM;
                                    sheath_inv : *Equipment = null;
                                    if is_tool(held.item.type) && player.toolBelt.exists then sheath_inv = player.toolBelt.value;
                                    else if is_weapon(held.item.type) && player.weaponBelt.exists then sheath_inv = player.weaponBelt.value;

                                    if sheath_inv != null
                                    {
                                        has_sheathed := false;
                                        for sheath_inv.contents // look for the first available slot
                                        {
                                            if !it.exists
                                            {
                                                sheath_inv.contents[it_index].value = held.item;
                                                sheath_inv.contents[it_index].exists = true;
                                                has_sheathed = true;
                                                break;
                                            }
                                        }

                                        if !has_sheathed
                                        {
                                            held.item.position.value = it.container.position.value;
                                            held.item.position.exists = true;
                                        }
                                    }
                                    else // swap with item on ground
                                    {
                                        held.item.position.value = it.item.position.value;
                                        held.item.position.exists = true;
                                    }

                                case .CONTAINER;
                                    held.container.position.exists = true;
                                    held.container.position.value = containers[index].position.value;
                                case .EQUIPMENT;
                                    held.equipment.position.exists = true;
                                    held.equipment.position.value = containers[index].position.value;
                            }

                            it.container.position.exists = false;
                            player.held.value = it;
                            break;
                        }
                    }
            }
            Input.pickup = false;
        }
        if Input.pickup then try_pickup();

        //
        // Highlight the active crafting slot
        //
        {
            interactible_blueprints := get_interactibles(items);
            for interactible_blueprints if it.blueprintData.exists
            {
                if player.held.exists && 
                player.held.value.tag == .ITEM && is_byproduct(player.held.value.item.type)
                {
                    player.canCraft = true;
                    numSlots := it.blueprintData.value.slots.count;
                    // loop indices
                    if craftIndex == -1 then craftIndex = numSlots - 1;
                    if craftIndex == numSlots then craftIndex = 0;
                    slot := it.blueprintData.value.slots[craftIndex];
                    // the slot is taken or of the wrong type so we need to find the next valid
                    if slot.item.exists || slot.slotType != get_byproduct_slot_type(player.held.value.item.type)
                    {
                        rotatedIndices: [] int;
                        if Input.craftIndexDirection == 1
                        {
                            craftIndex += 1;
                            if craftIndex == numSlots then craftIndex = 0;

                            array_resize(*rotatedIndices, numSlots);
                            for 0..numSlots - 1 { rotatedIndices[it] = it; }
                            array_rotate(*rotatedIndices[0], *rotatedIndices[craftIndex], *rotatedIndices[numSlots - 1] + 1);
                            array_resize(*rotatedIndices, numSlots + 1);
                            rotatedIndices[numSlots] = -1;
                        }
                        else if Input.craftIndexDirection == -1
                        {
                            craftIndex -= 1;
                            if craftIndex == -1 then craftIndex = numSlots - 1;

                            array_resize(*rotatedIndices, numSlots);
                            maxIndex := numSlots - 1;
                            for < maxIndex..0 { rotatedIndices[maxIndex - it] = it; }
                            array_rotate(*rotatedIndices[0], *rotatedIndices[maxIndex - craftIndex], *rotatedIndices[maxIndex] + 1);
                            array_resize(*rotatedIndices, numSlots + 1);
                            rotatedIndices[numSlots] = -1;
                        }

                        for i: rotatedIndices
                        {
                            if i == -1 { craftTarget.exists = false; break; }
                            slot = it.blueprintData.value.slots[i];
                            if !slot.item.exists && slot.slotType == get_byproduct_slot_type(player.held.value.item.type)
                            {
                                craftIndex = i;
                                ct: CraftTarget;
                                ct.blueprint = it;
                                ct.slot = slot;
                                craftTarget.value = ct;
                                craftTarget.exists = true;
                                break;
                            }
                        }
                    }
                    if !slot.item.exists && slot.slotType == get_byproduct_slot_type(player.held.value.item.type)
                    {
                        ct: CraftTarget;
                        ct.blueprint = it;
                        ct.slot = slot;
                        craftTarget.value = ct;
                        craftTarget.exists = true;
                    }

                    if craftTarget.exists // craftTarget needs to hold onto position
                    {
                        ui_rep: UI_Representation;
                        animInfo := NewAnimation(Animation_Key(player.held.value.item.type, "idle"));
                        ui_rep.frame = Current_Frame(animInfo);
                        ui_rep.position, ui_rep.scale, ui_rep.rotation = get_blueprint_slot_draw_info(it, craftIndex);
                        ui_rep.frame.tint.a = 200;
                        ui_rep.isHUD = false;
                        array_add(*ui, ui_rep);
                    }
                }
                else 
                {
                    player.canCraft = false;
                    craftIndex = 0;
                }
            }

            if interactible_blueprints.count == 0
            {
                player.canCraft = false;
                craftIndex = 0;
            }
        }

        try_add_item_to_blueprint :: ()
        {
            using Game;
            if craftTarget.exists
            {
                craftTarget.value.slot.item = maybe(player.held.value.item);
                player.held.exists = false;
                
                position: Vector2;
                scale: float;
                rotation: float;
                position, scale, rotation = get_blueprint_slot_draw_info(craftTarget.value.blueprint, craftIndex);
                forward := xy(cos(deg2rad(rotation)), sin(deg2rad(rotation)));

                craftTarget.value.slot.item.value.position.exists = true;
                craftTarget.value.slot.item.value.position.value = position;
                craftTarget.value.slot.item.value.onSlot = maybe(craftTarget.value.slot); // the item needs to know which slot it belongs to so we can break that bond if we pick it up later
                craftTarget.value.slot.item.value.forward = forward; // @Jay: ugh, why does this have a forward, i think it's used for drawing or something

                craftTarget.exists = false;
                player.canCraft = false;
            }
            Input.craft = false;
        }
        if Input.craft then try_add_item_to_blueprint();

        harvest_resource :: ()
        {
            using Game;
            for get_interactibles(resources) if !it.owner.exists || it.owner.value == *player.person
            {
                harvestRequirement := get_harvest_requirement(it.type);
                if harvestRequirement.exists
                {
                    if !player.held.exists || player.held.value.item.type != harvestRequirement.value 
                        continue;
                }

                // Drop by-product of harvest on the ground. Some resources like water will instead be loaded directly into an inventory
                byproduct := get_resource_byproduct(it.type);
                if byproduct {
                    direction_offset := unit_vector(it.position.value - player.position.value) * 15;
                    byproduct.position.value = it.position.value + direction_offset;
                    DeleteEntity(*resources, it);
                    array_add(*items, byproduct);
                    break;
                }
            }
        }
        if Input.interact then harvest_resource();

        process_byproduct :: ()
        {
            using Game;
            // compile list of resources in range, sort by distance to player
            byproduct_info :: struct { item: *Item; direction: Vector2; index: int; }
            sorted_byproducts: [..] byproduct_info;

            for get_interactibles(items) if !it.owner.exists || it.owner.value == *player.person
            {
                can_process, tool_type := get_item_processing_tool(it.type);
                if can_process
                   && !it.onSlot.exists
                   && player.held.exists && player.held.value.item.type == tool_type
                {
                    new_byproducts := get_item_byproducts(it.type);
                    for product, product_index: new_byproducts
                    {
                        random_offset := xy(random_get_within_range(-15, 15), random_get_within_range(-15, 15));
                        direction_offset := unit_vector(it.position.value - player.position.value) * 15;
                        product.position.value = it.position.value + direction_offset + random_offset;
                        DeleteEntity(*items, it);
                        array_add(*items, product);
                        if product_index == new_byproducts.count - 1 then break;
                    }
                }
            }
        }
        if Input.interact then process_byproduct(); // @Note: For now these are mutually exclusive so I can just check both

        try_craft :: ()
        {
            using Game;
            for get_interactibles(items) if it.blueprintData.exists
            {
                bp := it.blueprintData.value;
                for recipe: Recipes
                {
                    if recipe.blueprint_type == bp.blueprint_type
                    {
                        for recipe.definition
                        {
                            slot := bp.slots[it.index];
                            if slot.item.exists && slot.item.value.type == it.item_type
                                then continue;
                            else continue recipe;
                        }
                        
                        for bp.slots if it.item.exists then DeleteEntity(*items, it.item.value);
                        pos := it.position.value;
                        DeleteEntity(*items, it);
                        if recipe.result_tag == {
                            case .ITEM;
                                array_add(*items, NewItem(recipe.result_type, NewCollider(.{100.0, 100.0}), pos, *player)); // @Jay: there should be a way to just say NewItem(.CRATE and have all the defaults
                            case .CONTAINER;
                                array_add(*containers, NewContainer(recipe.result_type, NewCollider(.{100.0, 100.0}), pos, *player));
                            case .BLOCK;
                                cell := world_to_grid(pos);
                                rotation := rad2deg(atan2(-it.forward.y, it.forward.x)) - 90.0;
                                cell.block = maybe(NewBlock(recipe.result_type, rotation, NewCollider(.{100.0, 100.0}), cell, *player));
                        }
                    }
                }
            }
            Input.interact = false;
        }
        if Input.interact then try_craft();

        try_open_container :: ()
        {
            using Game;

            if !openContainerTarget.exists
            {
                interactible_containers := get_interactibles(containers);
                if interactible_containers.count > 0
                {
                    container := interactible_containers[0];
                    openContainerTarget = maybe(container);
                    print("opening: %_%\n", container.type, container.id);
                }
            }
            else 
            {
                print("closing: %_%\n", openContainerTarget.value.type, openContainerTarget.value.id);
                openContainerTarget.exists = false;
            }
        }
        if Input.interact then try_open_container();
        if openContainerTarget.exists
        {
            if length(openContainerTarget.value.position.value - player.position.value) > player.interactRange
            {
                print("closing: %_%\n", openContainerTarget.value.type, openContainerTarget.value.id);
                openContainerTarget.exists = false;
            }
        }

        buyFromShop :: ()
        {
            using Game;

            // check if the player is in a shop area
            shop: Maybe(*Shop);
            for s, s_index: shops
            {
                player_grid_cell := world_to_grid(player.position.value);
                for s.area if it == player_grid_cell
                {
                    shop.value = s;
                    shop.exists = true;
                    break s;
                }
            }

            if !shop.exists || shop.value.deals.count == 0 then return;

            // get the nearest deal to the player
            for get_interactibles(shop.value.deals, (deal) => deal.ware.item.entity)
            {
                payment_buffer : [..] *Item;

                if player.held.exists
                {
                    // player is holding some of the payment
                    if player.held.value.tag == .ITEM && player.held.value.item.type == it.price.itemType
                    {
                        array_add(*payment_buffer, player.held.value.item);
                    }
                    // player is holding a basket...
                    if player.held.value.tag == .CONTAINER && player.held.value.container.type == .BASKET
                    {
                        // ...which could contain some of the payment
                        basket := player.held.value.container;
                        for in_basket: basket.contents if in_basket.tag == .ITEM && in_basket.item.type == it.price.itemType
                        {
                            array_add(*payment_buffer, in_basket.item);
                        }
                    }
                }
                // any items inside the shop
                for item: items if item.position.exists && 
                             item.type == it.price.itemType && 
                             (!item.owner.exists || item.owner.exists && item.owner.value == *player)
                {
                    item_cell := world_to_grid(item.position.value);
                    for shop_cell: shop.value.area
                    {
                        if shop_cell == <<item_cell 
                        {
                            array_add(*payment_buffer, item);
                            break;
                        }
                    }
                }
                // any items in containers inside the shop
                for container: containers if container.position.exists && container.owner.exists && container.owner.value == *player
                {
                    container_cell := world_to_grid(container.position.value);
                    for shop_cell: shop.value.area if shop_cell == <<container_cell
                    {
                        for in_container: container.contents if in_container.tag == .ITEM && in_container.item.type == it.price.itemType
                        {
                            array_add(*payment_buffer, in_container.item);
                        }
                        break;
                    }
                }

                if payment_buffer.count >= it.price.amount
                {
                    // remove those items from the game
                    for i: 0..it.price.amount - 1
                    {
                        DeleteEntity(*items, payment_buffer[i]);
                    }

                    if player.held.exists 
                    {
                        held := player.held.value;

                        if held.tag != .ITEM then drop_held();
                        else
                        {
                            sheath_inv: *Equipment = null;
                            if is_tool(held.item.type) && player.toolBelt.exists then sheath_inv = player.toolBelt.value;
                            else if is_weapon(held.item.type) && player.weaponBelt.exists then sheath_inv = player.weaponBelt.value;
                            
                            if sheath_inv == null then drop_held();
                            else
                            {
                                has_sheathed := false;
                                for sheath_inv.contents // look for the first available slot
                                {
                                    if !it.exists
                                    {
                                        sheath_inv.contents[it_index].value = held.item;
                                        sheath_inv.contents[it_index].exists = true;
                                        player.held.exists = false;
                                        has_sheathed = true;
                                        break;
                                    }
                                }

                                if !has_sheathed then drop_held();
                            }
                        }
                    }

                    player.held.value = as_holdable(as_concept(it.ware));
                    player.held.exists = true;

                    held := get_holdable_entity(player.held.value);
                    held.owner.value = *player;
                    held.owner.exists = true;
                    held.position.exists = false;
                }

            }
        }
        if Input.trade then buyFromShop();

        talkToNearestNPC :: ()
        {
            for get_interactibles(Game.npcs)
            {
                if !it.ai.value.isSpeaking
                {
                    it.ai.value.isSpeaking = true;
                    it.ai.value.speakTimer = it.ai.value.speakDuration;
                    break;
                }
            }
        }
        if Input.trade then talkToNearestNPC();

        // npc ai
        {
            for npc: npcs
            {
                if !npc.ai.value.hasGoal && npc.ai.value.goalResetTimer <= 0.0
                {
                    left_bound   := cast(float) Grid.left(grid) * grid.cellSize;
                    top_bound    := cast(float) Grid.top(grid) * grid.cellSize;
                    right_bound  := cast(float) Grid.right(grid) * grid.cellSize;
                    bottom_bound := cast(float) Grid.bottom(grid) * grid.cellSize;

                    x := random_get_within_range(left_bound, right_bound);
                    y := random_get_within_range(top_bound, bottom_bound);
                    npc.ai.value.goalPosition = xy(x, y);
                    npc.ai.value.goalResetTimer = 0.0;
                    npc.ai.value.goalResetDuration = 0.0;
                    npc.ai.value.hasGoal = true;
                }
                else if npc.ai.value.hasGoal
                {
                    direction := npc.ai.value.goalPosition - npc.position.value;
                    npc.velocity = unit_vector(direction) * npc.speed;
                    if length(npc.velocity) != 0 then npc.forward = unit_vector(npc.velocity);

                    if length(direction) < 1.0
                    {
                        npc.ai.value.hasGoal = false;
                        // goal reached, reset timer
                        if npc.ai.value.goalResetDuration <= 0.0
                        {
                            npc.ai.value.goalResetDuration = random_get_within_range(3.0, 7.5); 
                            npc.ai.value.goalResetTimer = npc.ai.value.goalResetDuration;
                        }
                    }
                }
                else // goalResetTimer > 0.0
                {
                    npc.ai.value.goalResetTimer -= dt;
                    npc.velocity = .{};
                    npc.ai.value.hasGoal = false;
                }

                // interrupt goal and turn towards the player when they get close
                npc_to_player := player.position.value - npc.position.value;
                dist := length(npc_to_player);
                if dist < 150
                {
                    npc.forward = unit_vector(npc_to_player);
                    npc.velocity = .{};
                }
                handle_collision(*npc.entity);
                npc.position.value += npc.velocity;
                bound_to_grid(*npc.entity);
            }
        }
    }

    // Draw
    {
        BeginDrawing();
        ClearBackground(WHITE);

        // draw grid
        w := cast(float) WINDOW_WIDTH / 2.0;
        h := cast(float) WINDOW_HEIGHT / 2.0;
        left  := clamp(world_to_grid(camera.position.x - w / camera.zoom), 0, grid.chunkWidth * grid.gridWidth);
        right := clamp(world_to_grid(camera.position.x + w / camera.zoom), 0, grid.chunkWidth * grid.gridWidth);
        top   := clamp(world_to_grid(camera.position.y - h / camera.zoom), 0, grid.chunkWidth * grid.gridWidth);
        bot   := clamp(world_to_grid(camera.position.y + h / camera.zoom), 0, grid.chunkWidth * grid.gridWidth);
        for y: top..bot
        {
            for x: left..right
            {
                cell := get_cell(x, y);
                if cell != null draw_cell(cell);
            }
        }

        for shop: shops for shop.area { if is_in_loaded_chunk(it) then draw_shop(shop); }
        for resources  if it.position.exists && is_in_loaded_chunk(it) { draw_entity(it); }
        for items      if it.position.exists && is_in_loaded_chunk(it) { draw_item(it); }
        for containers if it.position.exists && is_in_loaded_chunk(it) { draw_entity(it); }
        for equipment  if it.position.exists && is_in_loaded_chunk(it) { draw_entity(it); }
        for npcs       if it.position.exists && is_in_loaded_chunk(it) { draw_entity(it); }
        if is_in_loaded_chunk(player) then draw_entity(player); 

        // draw ui
        {
            for *ui
            {
                if !it.isHUD then it.scale *= camera.zoom;
                draw_texture_centered_with_rotation(it.frame, it.position, it.rotation);
                remove it;
            }

            // draw held
            xpos := 20.0;
            ypos := WINDOW_HEIGHT - 80;
            DrawText(xx "Held:", 20, xx (ypos - 20), 20, BLACK);
            DrawRectangleLines(xx xpos, xx ypos, 60, 60, BLACK);
            if player.held.exists 
            {
                if player.held.value.tag ==
                {
                    case .CONTAINER;
                        frame := Current_Frame(player.held.value.container.animation);
                        if player.held.value.container.type ==
                        {
                            case .BASKET;
                                draw_ui_representation(xy(xpos + 15.0, ypos + 12.0), 0.2, frame);
                                xpos += 80.0;
                            case .BUCKET;
                                draw_ui_representation(xy(xpos + 15.0, ypos + 12.0), 0.2, frame);
                                xpos += 80.0;
                            case .CHEST;
                                draw_ui_representation(xy(xpos + 13.0, ypos + 15.0), 0.15, frame);
                                xpos += 80.0;
                        }
                    case .ITEM;
                        frame := Current_Frame(player.held.value.item.animation);
                        if player.held.value.item.type ==
                        {
                            case;
                                draw_ui_representation(xy(xx xpos, xx ypos), 0.3, frame);
                                xpos += 80.0;
                        }
                }
            }
            // draw tool belt
            xpos = 90;
            DrawRectangleLines(xx xpos, xx ypos, 60, 60, BLACK); //draw item slot
            if player.toolBelt.exists
            {
                pos := xy(xpos + 55.0, ypos + 35.0);
                frame := Current_Frame(player.toolBelt.value.animation);
                pos -= frame.size / 2;
                draw_ui_representation(pos, 0.1, frame);

                xpos = WINDOW_WIDTH/2 - 230;
                for player.toolBelt.value.contents
                {
                    DrawRectangleLines(xx (xpos + it_index * 70), xx ypos, 60, 60, BLACK); //draw inv boxes
                    if it.exists
                    {
                        frame = Current_Frame(it.value.animation);
                        draw_ui_representation(xy(xpos + it_index * 70, xx ypos), 0.3, frame); //draw inv items
                    }
                }
            }
            // draw weapon belt
            xpos = 160;
            DrawRectangleLines(xx xpos, xx ypos, 60, 60, BLACK); //draw item slot
            if player.weaponBelt.exists
            {
                pos := xy(xpos + 55.0, ypos + 45.0);
                frame := Current_Frame(player.weaponBelt.value.animation);
                pos -= frame.size / 2;
                draw_ui_representation(pos, 0.1, frame);
                xpos = WINDOW_WIDTH/2 + 30;
                for player.weaponBelt.value.contents
                {
                    DrawRectangleLines(xx (xpos + it_index * 70), xx ypos, 60, 60, BLACK); //draw inv boxes
                    if it.exists
                    {
                        frame = Current_Frame(it.value.animation);
                        draw_ui_representation(xy(xpos + it_index * 70, xx ypos), 0.3, frame); //draw inv items
                    }
                }
            }

            // draw npc dialog
            for npc: npcs if npc.ai.value.isSpeaking
            {
                npc.ai.value.speakTimer -= dt;
                
                npc_to_player := player.position.value - npc.position.value;
                dist := length(npc_to_player);
                if dist < 150 
                {
                    pos := to_screen_space(npc.position.value, .{30, -10});
                    if npc.ai.value.speakTimer > 0.0
                    {
                        DrawText("HI", xx pos.x, xx pos.y, 20, BLACK);
                    }
                }
            }
        }

        // debug
        {
            if Debug.showEntityInfo
            {
                debug_player_info();
                for items       if is_in_loaded_chunk(it) { debug_entity_info(<<it); }
                for containers  if is_in_loaded_chunk(it) { debug_entity_info(<<it); }
                for equipment   if is_in_loaded_chunk(it) { debug_entity_info(<<it); }
                for npcs        if is_in_loaded_chunk(it) { debug_entity_info(<<it); }
                for resources   if is_in_loaded_chunk(it) { debug_entity_info(<<it); }
                debug_grid_info();
            }

            if Debug.isActive
            {
                debug_console(dt);
            }

            debug_deferred_draw_rectancles();
            debug_deferred_draw_circles();
            debug_deferred_draw_lines();
        }

        update_animations();
        EndDrawing();
    }

    reset_temporary_storage();
}

game_reset :: () 
{
    using Game;
    log("RESETTING GAME");
    // load_all_textures();
    load_all_animations();
    load_all_shaders();

    Game  = .{};
    Input = .{};
    Debug = .{};
    Debug.font = LoadFont("./assets/fonts/cour.ttf");

    // init grid
    chunk_neighbor_offsets := valid_neighboring_offsets(0, grid.chunkWidth);
    for chunk_index: 0..(grid.gridWidth * grid.gridWidth) - 1
    {
        chunk := *grid.chunks[chunk_index];
        for chunk_neighbor_offsets if chunk_index == it then array_add(*grid.loadedChunks, chunk);
        
        for layer: 0..grid.worldHeight - 1
        {
            for i: 0..grid.chunkWidth - 1
            {
                for j: 0..grid.chunkWidth - 1
                {
                    x := (chunk_index % grid.gridWidth) * grid.chunkWidth + j;
                    y := (chunk_index / grid.gridWidth) * grid.chunkWidth + i;

                    layer_offset := layer * grid.chunkWidth * grid.chunkWidth;
                    row_offset   := i * grid.chunkWidth;
                    cell := *chunk.cells[layer_offset + row_offset + j];
                    cell.x = x;
                    cell.y = y;

                    cell.type = .DIRT;

                    if cell.x == 5
                    {
                        cell.type = .WATER;
                        cell.forward = .{0, 1};
                    }
                    if cell.y == 10
                    {
                        cell.type = .WATER;
                        cell.forward = .{1, 0};
                    }
                    if cell.x == 5 && cell.y == 10 then cell.forward = .{1, 1};

                    cell.block = Nothing(*Block);

                    cell.animation = NewAnimation(Animation_Key(cell.type, "idle"));
                }
            }
        }
    }

    // init player
    noAI: Maybe(AI);
    player.person = NewPerson(.{200, 200}, noAI);

    seed := random_get();
    if seed % 2 == 0 then seed += 1;
    random_seed(seed);

    //init resources
    populate_resources();

    // init npcs
    chunk := grid.chunks[grid.currentChunk];
    for 1..7
    {
        x := random_get_within_range(xx GridChunk.left(chunk), xx GridChunk.right(chunk));
        y := random_get_within_range(xx GridChunk.top(chunk), xx GridChunk.bottom(chunk));
        pos := grid_to_world(cast(int) x, cast(int) y);
        ai: AI;
        npcAI := maybe(ai);
        npc := NewPerson(pos, npcAI);
        npc.speed = 0.5;
        array_add(*npcs, npc);
    }

    // init shops
    {
        no_block :: Maybe(Block).{};
        area: [..] *GridCell;
        array_add(*area, get_cell(0, 0)); array_add(*area, get_cell(1, 0)); array_add(*area, get_cell(2, 0));
        array_add(*area, get_cell(0, 1)); array_add(*area, get_cell(1, 1)); array_add(*area, get_cell(2, 1));
        owner := npcs[0];
        basket_pos := grid_to_world(area[0], shouldGetCenter = true);
        basket_collider := NewCollider(.{20, 20});
        basket_pos += xy(-basket_collider.rect.x/2, -basket_collider.rect.y/2);
        basket := NewContainer(.BASKET, basket_collider, basket_pos, owner);
        array_add(*containers, basket);
        basket_deal: Deal;
        basket_deal.price = .{3, .FIBER};
        basket_deal.ware = as_sellable(basket);

        chest_pos := grid_to_world(area[1], shouldGetCenter = true);
        chest_collider := NewCollider(.{20, 20});
        chest_pos += xy(-chest_collider.rect.x/2, -chest_collider.rect.y/2);
        chest := NewContainer(.CHEST, chest_collider, chest_pos, owner);
        array_add(*containers, chest);
        chest_deal: Deal;
        chest_deal.price = .{2, .WOOD_LOG};
        chest_deal.ware = as_sellable(chest);

        deals: [2] Deal;
        deals[0] = basket_deal;
        deals[1] = chest_deal;

        shop := NewShop(area, deals, owner);
        array_add(*shops, shop);
    }

    // init items on ground
    {
        pos := player.position.value + .{100, -100};
        collider := NewCollider(10.0);
        lumberaxe := NewItem(.LUMBER_AXE, collider, pos);
        array_add(*items, lumberaxe);

        pos = player.position.value + .{200, -100};
        sword := NewItem(.SWORD, collider, pos);
        array_add(*items, sword);

        pos = .{650, 650};
        hammer := NewItem(.CARPENTERS_HAMMER, NewCollider(.{100, 100}), pos);
        hammer.animation = NewAnimation(Animation_Key(hammer.type, "test"));
        hammer.animation.shouldLoop = true;
        array_add(*items, hammer);
    }
    // init equipment on ground
    {
        pos := player.position.value + .{0, -100};
        collider := NewCollider(.{60, 15});
        toolbelt := NewEquipment(.TOOL_BELT, collider, pos);
        array_add(*equipment, toolbelt);

        pos = player.position.value + .{0, -200};
        weaponbelt := NewEquipment(.WEAPON_BELT, collider, pos);
        array_add(*equipment, weaponbelt);
    }
}

// Given a list of ptrs to game objects return a sorted list which are in the player's interact range in the forward halfplane
get_interactibles :: (array: [..] $T) -> [..] T { return get_interactibles(array, (T) => T.entity); }
get_interactibles :: (array: [..] $T, get_entity: (T) -> Entity) -> [..] T
{
    using Game;
    result: [..] T;
    result_distances: [..] float;
    for array
    {
        entity := get_entity(it);
        if entity.position.exists
        {
            displacement := entity.position.value - player.position.value;
            dist := length(displacement);
            if (dist < player.interactRange && dot_product(displacement, player.forward) / dist > -0.5)
                || circle_circle(player.entity, entity)
            {
                assert(result.count == result_distances.count);
                inserted := false;
                for i: 0..result.count - 1
                {
                    if dist < result_distances[i]
                    {
                        array_insert_at(*result, it, i);
                        array_insert_at(*result_distances, dist, i);
                        inserted = true;
                        break i;
                    }
                }

                if !inserted
                {
                    array_add(*result, it);
                    array_add(*result_distances, dist);
                }
            }
        }
    }
    return result;
}

get_interactible_holdables :: () -> [..] Holdable
{
    using Game;
    dist_info :: struct { holdable: Holdable; dist: float; }
    info_list: [..] dist_info;

    for get_interactibles(containers) if !it.owner.exists || it.owner.value == *player.person
    {
        info: dist_info;
        info.holdable.container = it;
        info.holdable.tag = .CONTAINER;
        info.dist = length(it.position.value - player.position.value);
        array_add(*info_list, info);
    }
    for get_interactibles(items) if !it.owner.exists || it.owner.value == *player.person
    {
        if it.blueprintData.exists {
            for slot: it.blueprintData.value.slots {
                if slot.item.exists continue;
            }
        }

        info: dist_info;
        info.holdable.item = it;
        info.holdable.tag = .ITEM;
        info.dist = length(it.position.value - player.position.value);
        array_add(*info_list, info);
    }
    for get_interactibles(equipment) if !it.owner.exists || it.owner.value == *player.person
    {
        info: dist_info;
        info.holdable.equipment = it;
        info.holdable.tag = .EQUIPMENT;
        info.dist = length(it.position.value - player.position.value);
        array_add(*info_list, info);
    }

    less_than :: (a, b) => cast(s64) (a.dist - b.dist);
    bubble_sort(info_list, less_than);

    result: [..] Holdable;
    for info_list array_add(*result, it.holdable);
    return result;
}

compute_container_weight :: (c: Container) -> int
{
    total := 0;
    for c.contents { total += 1; }
    return total;
}

populate_resources :: ()
{
    for chunk: Game.grid.chunks
    {
        // choose how many resource types we want in this chunk
        max_resource_types_per_chunk :: 2;
        num_resource_types := cast(int) random_get_within_range(0, max_resource_types_per_chunk);
        if num_resource_types == 0 continue;
        resource_types: [] Resource_Type;
        array_resize(*resource_types, num_resource_types);
        for type_index: 0..num_resource_types - 1
        {
            // select what those resources will be
            type := cast(Resource_Type)(random_get() % xx (enum_highest_value(Resource_Type) + 1));
            while array_find(resource_types, type) {
                type = cast(Resource_Type)(random_get() % xx (enum_highest_value(Resource_Type) + 1));
            }
            resource_types[type_index] = type;

            max_hotspots_per_resource_type :: 2;
            num_hotspots := cast(int) random_get_within_range(1, max_hotspots_per_resource_type);
            for 0..num_hotspots - 1
            {
                hotspot_x := random_get_within_range(xx GridChunk.left(chunk), xx GridChunk.right(chunk));
                hotspot_y := random_get_within_range(xx GridChunk.top(chunk), xx GridChunk.bottom(chunk));
                hotspot_world_pos := grid_to_world(cast(int) hotspot_x, cast(int) hotspot_y);

                max_resources_per_hotspot :: 20;
                num_resources := cast(int) random_get_within_range(0, max_resources_per_hotspot);
                for 0..num_resources - 1
                {
                    hotspot_radius :: 500;
                    x := random_get_within_range(hotspot_world_pos.x - hotspot_radius, hotspot_world_pos.x + hotspot_radius);
                    y := random_get_within_range(hotspot_world_pos.y - hotspot_radius, hotspot_world_pos.y + hotspot_radius);
                    x = clamp(x, Game.grid.cellSize * cast(float) Grid.left(Game.grid), Game.grid.cellSize * cast(float) Grid.right(Game.grid) - 1);
                    y = clamp(y, Game.grid.cellSize * cast(float) Grid.top(Game.grid),  Game.grid.cellSize * cast(float) Grid.bottom(Game.grid) - 1);
                    quantity := max(random_get() % 20, 10);
                    collider: *Collider;
                    if type == .TREE then collider = NewCollider(.{50.0, 80.0}, .{0, 60});
                    r := NewResource(type, collider, xy(x, y), xx quantity);
                    array_add(*Game.resources, r);
                }
            }
        }
    }
}