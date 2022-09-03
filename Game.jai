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
}

game_loop :: inline ()
{
    using Game;
    dt = GetFrameTime();
    if Debug.isActive then dt *= Debug.dtMultiplier;

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
                                    return; // @FIX: not a fan of this
                                }

                                if sheath_inv == belt_inventory.value
                                {
                                    temp := held.value;
                                    held.value = as_holdable(belt_inventory.value.contents[slot].value);
                                    belt_inventory.value.contents[slot] = NewMaybe(temp.item);
                                    Input.equipSlot = -1;
                                    return; // @FIX: not a fan of this
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
                    held.item.position.exists = true;
                    if held.item.type == .BLUEPRINT
                    {
                        held.item.position.value = grid_to_world(world_to_grid(player.position.value), shouldGetCenter=true);
                    }
                    else
                    {
                        held.item.position.value = player.position.value + player.forward;
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
            holdables := get_holdables_in_range(player.interactRange);
            for holdables
            {
                if it.tag ==
                {
                    case .EQUIPMENT;
                        if it.equipment.type ==
                        {
                            case .TOOL_BELT;
                                if !player.toolBelt.exists // @TODO: Eventually swap between belts if the player is already wearing one?
                                {
                                    it.equipment.position.exists = false;
                                    m := NewMaybe(it.equipment);
                                    player.toolBelt = m;
                                    break;
                                }
                            case .WEAPON_BELT;
                                if !player.weaponBelt.exists
                                {
                                    it.equipment.position.exists = false;
                                    m := NewMaybe(it.equipment);
                                    player.weaponBelt = m;
                                    break;
                                }
                        }

                    case .ITEM; // @@@: this doesnt account for picking up byproducts
                        if !player.held.exists
                        {
                            player.held.value = it;
                            player.held.exists = true;
                            player.held.value.item.position.exists = false;
                            break;
                        }
                        else
                        {
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
                            newHeld: = NewMaybe(it);
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
            }
            Input.pickup = false;
        }
        if Input.pickup then try_pickup();

        if player.held.exists && 
           player.held.value.tag == .ITEM &&
           is_byproduct(player.held.value.item.type)
        {
            blueprint_and_distance :: struct { blueprint: *Item; distance: float; }
            blueprints_in_range: [..] blueprint_and_distance;
            for items if it.blueprintData.exists && it.position.exists
            {
                dist := length(it.position.value - player.position.value);
                if dist < player.interactRange
                {
                    info: blueprint_and_distance;
                    info.blueprint = it;
                    info.distance = dist;
                    array_add(*blueprints_in_range, info);
                }
            }
            nearer :: (a, b) => cast(s64) (a.distance < b.distance);
            bubble_sort(blueprints_in_range, nearer);

            // highlight the active crafting slot
            if blueprints_in_range.count > 0
            {
                player.canCraft = true;
                bp := blueprints_in_range[0].blueprint;
                numSlots := bp.blueprintData.value.slots.count;
                // loop indices
                if craftIndex == -1 then craftIndex = numSlots - 1;
                if craftIndex == numSlots then craftIndex = 0;
                slot := bp.blueprintData.value.slots[craftIndex];
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
                        for < (numSlots - 1)..0 { rotatedIndices[it] = it; }
                        array_rotate(*rotatedIndices[0], *rotatedIndices[craftIndex], *rotatedIndices[numSlots - 1] + 1);
                        array_resize(*rotatedIndices, numSlots + 1);
                        rotatedIndices[numSlots] = -1;
                    }

                    for rotatedIndices
                    {
                        if it == -1 { craftTarget.exists = false; break; }
                        slot = bp.blueprintData.value.slots[it];
                        if !slot.item.exists && slot.slotType == get_byproduct_slot_type(player.held.value.item.type)
                        {
                            craftIndex = it;
                            craftTarget.exists = true;
                            ct: CraftTarget;
                            ct.blueprint = bp;
                            ct.slot = *slot;
                            craftTarget.value = ct;
                            break;
                        }
                    }
                }

                if craftTarget.exists // craftTarget needs to hold onto position
                {
                    ui_rep: UI_Representation;
                    ui_rep.info, ui_rep.position, ui_rep.scale, ui_rep.rotation = get_blueprint_slot_draw_info(bp, craftIndex);
                    ui_rep.info.tint.a = 200;
                    ui_rep.isHUD = false;
                    array_add(*ui, ui_rep);
                }
            }
            else player.canCraft = false;
        }
        if !player.canCraft then craftIndex = 0;

        try_add_item_to_blueprint :: ()
        {
            using Game;
            if craftTarget.exists
            {
                craftTarget.value.slot.item = NewMaybe(player.held.value.item);
                player.held.exists = false;
                
                texInfo: TextureInfo;
                position: Vector2;
                scale: float;
                rotation: float;
                texInfo, position, scale, rotation = get_blueprint_slot_draw_info(craftTarget.value.blueprint, craftIndex);
                forward := xy(cos(rotation), sin(rotation));

                craftTarget.value.slot.item.value.position.exists = true;
                craftTarget.value.slot.item.value.position.value = position;
                craftTarget.value.slot.item.value.forward = forward;

                craftTarget.exists = false;
            }
            Input.craft = false;
        }
        if Input.craft then try_add_item_to_blueprint();

        harvestResource :: ()
        {
            using Game;

            // compile list of resources in range, sort by distance to player
            resource_info :: struct { resource: *Resource; direction: Vector2; index: int; }
            sorted_resources: [..] resource_info;
            for resources
            {
                player_to_resource : Vector2 = it.position.value - player.position.value;
                if length(player_to_resource) < player.interactRange // @TODO: Make this take tool range into account
                {
                    info: resource_info;
                    info.resource = resources[it_index];
                    info.direction = player_to_resource;
                    info.index = it_index;
                    array_add(*sorted_resources, info);
                }
            }

            less_than :: (a, b) => cast(s64) (length(a.direction) - length(b.direction));
            bubble_sort(sorted_resources, less_than);

            // find the first resource we are able to harvest
            resource_to_harvest: Maybe(resource_info);
            for sorted_resources
            {
                if it.resource.harvestRequirement.exists
                {
                    if !player.held.exists || player.held.value.item.type != it.resource.harvestRequirement.value
                    {
                        continue;
                    }
                }

                if it.resource.type ==
                {
                    // trees require the lumber axe equipped
                    case .TREE;
                        if player.held.exists && player.held.value.tag == .ITEM
                        {
                            if player.held.value.item.type == .LUMBER_AXE
                            {
                                resource_to_harvest.value = it;
                                resource_to_harvest.exists = true;
                                break;
                            }
                        }
                    case;
                        resource_to_harvest.value = it;
                        resource_to_harvest.exists = true;
                        break;
                }
            }

            // Drop by-product of harvest on the ground. Some resources like water will instead be loaded directly into an inventory
            if resource_to_harvest.exists
            {
                by_product: *Item = null;
                resource_pos := resource_to_harvest.value.resource.position.value;
                direction_offset := unit_vector(resource_to_harvest.value.direction) * 15;
                by_product_pos := resource_pos + direction_offset;
                if resource_to_harvest.value.resource.type ==
                {
                    case .COPPER_VEIN;
                        by_product = NewItem(.COPPER_NUGGET, NewCollider(10.0), by_product_pos);
                    case .IRON_VEIN;
                        by_product = NewItem(.IRON_NUGGET, NewCollider(10.0), by_product_pos);
                    case .TREE;
                        by_product = NewItem(.WOOD_LOG, NewCollider(.{10, 10}), by_product_pos);
                    case .BUSH;
                        by_product = NewItem(.FIBER, NewCollider(10.0), by_product_pos);
                }

                array_add(*items, by_product);
                array_unordered_remove_by_index(*resources, resource_to_harvest.value.index);
            }
        }
        if Input.harvest then harvestResource();

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
            nearest_deal := shop.value.deals[0];
            nearest_deal_dist := length(nearest_deal.ware.position - player.position.value);
            for shop.value.deals
            {
                dist := length(it.ware.position - player.position.value);
                if dist < nearest_deal_dist
                {
                    nearest_deal = it;
                    nearest_deal_dist = dist;
                }
            }

            if nearest_deal_dist < player.interactRange
            {
                price_amount := nearest_deal.price.amount;
                price_type   := nearest_deal.price.item;
                payment_buffer : [..] *Item;

                if player.held.exists
                {
                    // player is holding some of the payment
                    if player.held.value.tag == .ITEM && player.held.value.item.type == price_type
                    {
                        array_add(*payment_buffer, player.held.value.item);
                    }
                    // player is holding a basket...
                    if player.held.value.tag == .CONTAINER && player.held.value.container.type == .BASKET
                    {
                        // ...which could contain some of the payment
                        basket := player.held.value.container;
                        for basket.contents if it.tag == .ITEM && it.item.type == price_type
                        {
                            array_add(*payment_buffer, it.item);
                        }
                    }
                }
                // any items inside the shop
                for items if it.position.exists && 
                             it.type == price_type && 
                             (!it.owner.exists ||
                             it.owner.exists && 
                             it.owner.value == *player)
                {
                    item_cell := world_to_grid(it.position.value);
                    for shop_cell: shop.value.area
                    {
                        if shop_cell == <<item_cell 
                        {
                            array_add(*payment_buffer, it); 
                            break;
                        }
                    }
                }
                // any items in containers inside the shop
                for c: containers if c.position.exists && c.owner.exists && c.owner.value == *player
                {
                    container_cell := world_to_grid(c.position.value);
                    for shop_cell: shop.value.area if shop_cell == <<container_cell
                    {
                        for c.contents if it.tag == .ITEM && it.item.type == price_type
                        {
                            array_add(*payment_buffer, it.item);
                        }
                        break;
                    }
                }

                if payment_buffer.count >= price_amount
                {
                    // remove those items from the game
                    for i: 0..price_amount - 1
                    {
                        // Maybe make a method for removing items from the game
                        free(payment_buffer[i]);
                        array_unordered_remove_by_value(*items, payment_buffer[i]); // @Note: I might end up leaving someone else's pointers to the item hanging
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

                    ware := as_concept(nearest_deal.ware);
                    player.held.value = as_holdable(ware);
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
            using Game;
            nearest_index := 0;
            min_dist := length(npcs[0].position.value - player.position.value);
            for npcs
            {
                dist := length(it.position.value - player.position.value);
                if dist < min_dist
                {
                    min_dist = dist;
                    nearest_index = it_index;
                }
            }
            nearest := npcs[nearest_index];
            if min_dist <= player.interactRange
            {
                nearest.ai.value.isSpeaking = true;
                nearest.ai.value.speakTimer = nearest.ai.value.speakDuration;
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
        for items      if it.position.exists && is_in_loaded_chunk(it) { draw_entity(it); }
        for containers if it.position.exists && is_in_loaded_chunk(it) { draw_entity(it); }
        for equipment  if it.position.exists && is_in_loaded_chunk(it) { draw_entity(it); }
        for npcs       if it.position.exists && is_in_loaded_chunk(it) { draw_person(it); }
        if is_in_loaded_chunk(player) then draw_person(player); 

        // draw ui
        {
            for *ui
            {
                // if !it.isHUD 
                // {
                //     it.scale *= camera.zoom;
                //     it.info.size *= camera.zoom;
                //     // @@@: position still gets messed up by zooming
                // }
                draw_orthagonal_texture_centered(it.info, it.position, it.rotation, it.scale);
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
                        if player.held.value.container.type ==
                        {
                            case .BASKET;
                                draw_ui_representation(xy(xpos + 15.0, ypos + 12.0), 0.2, player.held.value.container.textureInfo);
                                xpos += 80.0;
                            case .BUCKET;
                                draw_ui_representation(xy(xpos + 15.0, ypos + 12.0), 0.2, player.held.value.container.textureInfo);
                                xpos += 80.0;
                            case .CHEST;
                                draw_ui_representation(xy(xpos + 13.0, ypos + 15.0), 0.15, player.held.value.container.textureInfo);
                                xpos += 80.0;
                        }
                    case .ITEM;
                        if player.held.value.item.type ==
                        {
                            case;
                                draw_ui_representation(xy(xx xpos, xx ypos), 0.3, player.held.value.item.textureInfo);
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
                pos -= player.toolBelt.value.textureInfo.size / 2;
                draw_ui_representation(pos, 0.1, player.toolBelt.value.textureInfo);

                xpos = WINDOW_WIDTH/2 - 230;
                for player.toolBelt.value.contents
                {
                    DrawRectangleLines(xx (xpos + it_index * 70), xx ypos, 60, 60, BLACK); //draw inv boxes
                    if it.exists
                    {
                        draw_ui_representation(xy(xpos + it_index * 70, xx ypos), 0.3, it.value.textureInfo); //draw inv items
                    }
                }
            }
            // draw weapon belt
            xpos = 160;
            DrawRectangleLines(xx xpos, xx ypos, 60, 60, BLACK); //draw item slot
            if player.weaponBelt.exists
            {
                pos := xy(xpos + 55.0, ypos + 45.0);
                pos -= player.weaponBelt.value.textureInfo.size / 2;
                draw_ui_representation(pos, 0.1, player.weaponBelt.value.textureInfo);
                xpos = WINDOW_WIDTH/2 + 30;
                for player.weaponBelt.value.contents
                {
                    DrawRectangleLines(xx (xpos + it_index * 70), xx ypos, 60, 60, BLACK); //draw inv boxes
                    if it.exists
                    {
                        draw_ui_representation(xy(xpos + it_index * 70, xx ypos), 0.3, it.value.textureInfo); //draw inv items
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

        EndDrawing();
    }

    reset_temporary_storage();
}

game_reset :: () 
{
    using Game;
    log("RESETTING GAME");
    load_all_textures();

    Game  = .{};
    Input = .{};

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

                    cell.block = Nothing(Block);
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
        npcAI := NewMaybe(ai);
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

get_holdables_in_range :: (range: float) -> [..] Holdable
{
    using Game;

    dist_info :: struct { holdable: Holdable; dist: float; }
    info_list: [..] dist_info;

    for containers if it.position.exists && 
                      (!it.owner.exists || it.owner.value == *player.person)
    { 
        dist := length(Game.player.position.value - it.position.value);
        if dist < range
        {
            info: dist_info;
            info.holdable.container = it;
            info.holdable.tag = .CONTAINER;
            info.dist = dist;
            array_add(*info_list, info);
        }
    }
    for items if it.position.exists && 
                 (!it.owner.exists || it.owner.value == *player.person)
    {
        dist := length(Game.player.position.value - it.position.value);
        if dist < range
        {
            info: dist_info;
            info.holdable.item = it;
            info.holdable.tag = .ITEM;
            info.dist = dist;
            array_add(*info_list, info);
        }
    }
    for equipment if it.position.exists && 
                     (!it.owner.exists || it.owner.value == *player.person)
    {
        dist := length(Game.player.position.value - it.position.value);
        if dist < range
        {
            info: dist_info;
            info.holdable.equipment = it;
            info.holdable.tag = .EQUIPMENT;
            info.dist = dist;
            array_add(*info_list, info);
        }
    }

    less_than :: (a, b) => cast(s64) (a.dist - b.dist);
    bubble_sort(info_list, less_than);

    result: [..] Holdable;
    for info_list array_add(*result, it.holdable);
    return result;
}

get_nearby_containers :: () -> [..] *Container
{
    using Game;
    result: [..] *Container;

    if player.held.exists && player.held.value.tag == .CONTAINER
    {
        basket := player.held.value.container;
        if basket.type == .BASKET
            array_add(*result, basket);
    }

    for containers
    {
        if length(player.position.value - it.position.value) < 50.0
            array_add(*result, it);
    }
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
                    r := NewResource(type, xy(x, y), xx quantity);
                    array_add(*Game.resources, r);
                }
            }
        }
    }
}