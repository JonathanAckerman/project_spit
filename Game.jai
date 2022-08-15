Game: struct 
{
    resetting: bool;
    paused: bool;

    player: Player;
    grid: Grid;
    camera: struct
    {
        zoom := 1.0;
        position: Vector3;
    }

    resources:  [..] *Resource;
    items:      [..] *Item;
    containers: [..] *Container;
    equipment:  [..] *Equipment;
    npcs:       [..] *Person;
    shops:      [..] *Shop;

    // ui state
    // highlightedItem: *Entity = ---;
}

game_loop :: inline ()
{
    using Game;
    dt := GetFrameTime();

    // Input
    handle_input();

    npc_text_to_draw: [..] string;
    // Simulate
    {
        if player.position.exists then player.position.value += player.velocity;
        handle_collision();
        player.velocity = .{};

        update_current_chunk();

        camera.position.xy = player.position.value.xy;

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
                    held.item.position.value = player.position.value + player.forward;
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
                                if !player.toolBelt.exists // @Temporary: Eventually swap between belts if the player is already wearing one?
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

                    case .ITEM;
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

        harvestResource :: ()
        {
            using Game;

            // compile list of resources in range, sort by distance to player
            resource_info :: struct { resource: *Resource; direction: Vector3; index: int; }
            sorted_resources: [..] resource_info;
            for resources
            {
                player_to_resource : Vector3 = it.position.value - player.position.value;
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
                if resource_to_harvest.value.resource.type ==
                {
                    case .COPPER_VEIN;
                        by_product = NewItem(.COPPER_NUGGET, Collider.{type = .CIRCLE, radius = 10}, resource_to_harvest.value.resource.position.value + unit_vector(resource_to_harvest.value.direction) * 15);
                    case .IRON_VEIN;
                        by_product = NewItem(.IRON_NUGGET, Collider.{type = .CIRCLE, radius = 10}, resource_to_harvest.value.resource.position.value + unit_vector(resource_to_harvest.value.direction) * 15);
                    case .TREE;
                        by_product = NewItem(.WOOD_LOG, Collider.{type = .CIRCLE, radius = 10}, resource_to_harvest.value.resource.position.value + unit_vector(resource_to_harvest.value.direction) * 15);
                    case .BUSH;
                        by_product = NewItem(.FIBER, Collider.{type = .CIRCLE, radius = 10}, resource_to_harvest.value.resource.position.value + unit_vector(resource_to_harvest.value.direction) * 15);
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
                }
            }

            if !shop.exists || shop.value.deals.count == 0 then return;

            // get the nearest deal to the player
            get_pos :: inline (deal: Deal) -> Vector3
            {
                if deal.ware_tag ==
                {
                    case .ITEM;
                        return (cast(*Item) deal.ware.value_pointer).position.value;
                    case .CONTAINER;
                        return (cast(*Container) deal.ware.value_pointer).position.value;
                    case .EQUIPMENT;
                        return (cast(*Equipment) deal.ware.value_pointer).position.value;
                }
                return .{0, 0, 0};
            }
            nearest_deal := shop.value.deals[0];
            nearest_deal_dist := length(get_pos(nearest_deal) - player.position.value);
            for shop.value.deals
            {
                dist := length(get_pos(it) - player.position.value);
                if dist < nearest_deal_dist
                {
                    nearest_deal = it;
                    nearest_deal_dist = dist;
                }
            }

            if nearest_deal_dist < player.interactRange
            {
                //either the player is holding the payment (or part of payment)
                //or the payment must be "inside" the shop
                    // maybe rather than having this array of grid cells, I could just make it a rect collider, that way the payment (center point) doesnt have to be inside a cell, its just a normal collision
                
                price_amount := nearest_deal.price.amount;
                price_tag    := nearest_deal.price.tag;
                price_type   : Any;
                if price_tag == 
                {
                    case .ITEM;
                        price_type = nearest_deal.price.item;
                    case .CONTAINER;
                        price_type = nearest_deal.price.container;
                    case .EQUIPMENT;
                        price_type = nearest_deal.price.equipment;
                }

                // build a "wallet" for the player
                payment_buffer : [..] Any;
                if player.held.exists
                {
                    // holding some of the payment
                    if player.held.value.tag == price_tag
                    {
                        // switch based on the tag
                            // if the type == type
                                // add to wallet
                    }
                    // holding a basket...
                    if player.held.value.tag == .CONTAINER && player.held.value.container.type == .BASKET
                    {
                        // ...which could contain some of the payment
                        basket := player.held.value.container;


                    }
                }
                    // what they are holding
                    //     if it's a basket then anything inside
                    // any items inside the shop
                    // any items in containers inside the shop
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
                    x := random_get_within_range(npc.position.value.x - 200, npc.position.value.x + 200);
                    y := random_get_within_range(-npc.position.value.y - 200, npc.position.value.y + 200);
                    npc.ai.value.goalPosition = xyz(x, y, 3);
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
                npc.position.value += npc.velocity;
            }
        }

        Textures.outlineSize += GetMouseWheelMove();
        if (Textures.outlineSize < 1.0) Textures.outlineSize = 1.0;
        SetShaderValue(Textures.outlineShader, Textures.outlineSizeLoc, *Textures.outlineSize, cast(s32) ShaderUniformDataType.SHADER_UNIFORM_FLOAT);
    }

    // Draw
    {
        BeginDrawing();
        ClearBackground(WHITE);

        // draw grid
        layer_index := cast(int) camera.position.z * grid.chunkWidth * grid.chunkWidth;
        chunks_to_draw: [..] *GridChunk;
        array_add(*chunks_to_draw, *grid.chunks[grid.currentChunk]);
        for chunk: chunks_to_draw
        {
            cells_below_camera := array_view(chunk.cells, layer_index);
            drawn_flags : [grid.chunkWidth * grid.chunkWidth] bool;
            for cell: cells_below_camera
            {
                if cell.type == .AIR continue;

                offset_from_layer := (cell.y % grid.chunkWidth) * grid.chunkWidth + (cell.x % grid.chunkWidth);
                if !drawn_flags[offset_from_layer]
                {
                    drawpos := to_screen_space(grid_to_world(cell.x, cell.y, 0).xy);
                    size := xy(grid.cellSize * camera.zoom, grid.cellSize * camera.zoom);
                    size_modifier := 1.0 - (cell.z - cast(int) camera.position.z) * 0.1;
                    drawpos_offset_from_size := size - size * size_modifier;
                    size *= size_modifier;
                    tint :: (c: Color, modifier: float) -> Color { 
                        color: Color = c;
                        color.r = xx (color.r * modifier);
                        color.g = xx (color.g * modifier);
                        color.b = xx (color.b * modifier);
                        return color;
                    }
                    if cell.type == {
                        case .BEDROCK;
                            DrawRectangleV(drawpos + drawpos_offset_from_size / 2, size, tint(DARKGRAY, size_modifier));
                        case .DIRT;
                            DrawRectangleV(drawpos + drawpos_offset_from_size / 2, size, tint(BROWN, size_modifier));
                        case .WATER;
                            DrawRectangleV(drawpos + drawpos_offset_from_size / 2, size, tint(BLUE, size_modifier));
                    }
                    DrawRectangleLines(xx drawpos.x, xx drawpos.y, xx (grid.cellSize * camera.zoom), xx (grid.cellSize * camera.zoom), LIGHTGRAY);
                    drawn_flags[offset_from_layer] = true;
                }
            }
        }

        BeginShaderMode(Textures.outlineShader);
        for resources 
            if it.position.exists && is_in_current_chunk(it.position.value) && it.position.value.z >= camera.position.z { 
                textureSize : [2] float;
                textureSize[0] = xx it.texture.value.width; 
                textureSize[1] = xx it.texture.value.height;
                textureSizeLoc := GetShaderLocation(Textures.outlineShader, "textureSize");
                SetShaderValue(Textures.outlineShader, Textures.textureSizeLoc, *textureSize, cast(s32) ShaderUniformDataType.SHADER_UNIFORM_VEC2);
                draw_resource(it);
        }
        EndShaderMode();
        for shops if is_in_current_chunk(xyz(xx it.area[0].x, xx it.area[0].y, xx it.area[0].z)) && xx it.area[0].z >= camera.position.z { draw_shop(it); }
        for items
            if it.position.exists && is_in_current_chunk(it.position.value) && it.position.value.z >= camera.position.z { draw_item(it); }
        for containers 
            if it.position.exists && is_in_current_chunk(it.position.value) && it.position.value.z >= camera.position.z { draw_container(it); }
        for equipment 
            if it.position.exists && is_in_current_chunk(it.position.value) && it.position.value.z >= camera.position.z { draw_equipment(it); }
        for npcs 
            if it.position.exists && is_in_current_chunk(it.position.value) && it.position.value.z >= camera.position.z { draw_person(it); }
        if is_in_current_chunk(player.position.value) && player.position.value.z >= camera.position.z
        {
            draw_person(player);
        }

        // draw ui
        {
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
                                draw_container_ui(xy(xpos + 20.0, ypos + 15.0), player.held.value.container.collider, 1.0, .BASKET);
                                xpos += 80.0;
                            case .BUCKET;
                                draw_container_ui(xy(xpos + 20.0, ypos + 15.0), player.held.value.container.collider, 1.0, .BUCKET);
                                xpos += 80.0;
                            case .CHEST;
                                draw_container_ui(xy(xpos + 20.0, ypos + 25.0), player.held.value.container.collider, 1.0, .CHEST);
                                xpos += 80.0;
                        }
                    case .ITEM;
                        if player.held.value.item.type ==
                        {
                            case;
                                draw_item_ui(xy(xx xpos, xx ypos), player.held.value.item.collider, 0.3, player.held.value.item.type);
                                xpos += 80.0;
                        }
                }
            }
            // draw tool belt
            xpos = 90;
            DrawRectangleLines(xx xpos, xx ypos, 60, 60, BLACK); //draw item slot
            if player.toolBelt.exists
            {
                DrawRectangleV(xy(xpos + 10.0, ypos + 35.0), xy(40, 10), GREEN); //draw ui representation

                xpos = WINDOW_WIDTH/2 - 230;
                for player.toolBelt.value.contents
                {
                    DrawRectangleLines(xx (xpos + it_index * 70), xx ypos, 60, 60, BLACK); //draw inv boxes
                    if it.exists
                    {
                        draw_item_ui(xy(xpos + it_index * 70, xx ypos), it.value.collider, 0.3, it.value.type); //draw inv items
                    }
                }
            }
            // draw weapon belt
            xpos = 160;
            DrawRectangleLines(xx xpos, xx ypos, 60, 60, BLACK); //draw item slot
            if player.weaponBelt.exists
            {
                DrawRectangleV(xy(xpos + 10.0, ypos + 35.0), xy(40, 10), RED); //draw ui representation
                xpos = WINDOW_WIDTH/2 + 30;
                for player.weaponBelt.value.contents
                {
                    DrawRectangleLines(xx (xpos + it_index * 70), xx ypos, 60, 60, BLACK); //draw inv boxes
                    if it.exists
                    {
                        draw_item_ui(xy(xpos + it_index * 70, xx ypos), it.value.collider, 0.3, it.value.type); //draw inv items
                    }
                }
            }

            // draw npc dialog
            for npc: npcs
            {
                npc_to_player := player.position.value - npc.position.value;
                dist := length(npc_to_player);
                if dist < 150 && npc.ai.value.isSpeaking
                {
                    pos := to_screen_space(npc.position.value.xy, .{30, -10});
                    if npc.ai.value.speakTimer > 0.0
                    {
                        npc.ai.value.speakTimer -= dt;
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
                for items { debug_entity_info(<<it); }
                for containers { debug_entity_info(<<it); }
                for equipment { debug_entity_info(<<it); }
                for npcs { debug_entity_info(<<it); }
                for resources { debug_entity_info(<<it); }
            }

            if Debug.isActive
            {
                debug_console(dt);
            }
        }

        EndDrawing();
    }

    reset_temporary_storage();
}

game_reset :: () 
{
    log("RESETTING GAME");
    Game  = .{};
    Input = .{};

    // init grid
    for chunk_index: 0..(Game.grid.gridWidth * Game.grid.gridWidth) - 1
    {
        chunk := *Game.grid.chunks[chunk_index];
        for layer: 0..Game.grid.worldHeight - 1
        {
            for i: 0..Game.grid.chunkWidth - 1
            {
                for j: 0..Game.grid.chunkWidth - 1
                {
                    x := (chunk_index % Game.grid.gridWidth) * Game.grid.chunkWidth + j;
                    y := (chunk_index / Game.grid.gridWidth) * Game.grid.chunkWidth + i;

                    layer_offset := layer * Game.grid.chunkWidth * Game.grid.chunkWidth;
                    row_offset   := i * Game.grid.chunkWidth;
                    cell := *chunk.cells[layer_offset + row_offset + j];
                    cell.x = x;
                    cell.y = y;
                    cell.z = layer;

                    if layer == Game.grid.worldHeight - 1 then cell.type = .BEDROCK;
                    else if layer == Game.grid.worldHeight - 2 then cell.type = .DIRT;
                    else if layer == Game.grid.worldHeight - 3
                    {
                        if (x == 4 && y >= 15) || (x == 16 && y <= 15) || (y == 15 && x <= 15 && x > 4)
                            cell.type = .WATER;
                        // else if 
                        else cell.type = .DIRT;
                    }
                }
            }
        }
    }

    // init player
    noAI: Maybe(AI);
    Game.player.person = NewPerson(.{200, 200, 3}, noAI);

    seed := random_get();
    if seed % 2 == 0 then seed += 1;
    random_seed(seed);

    //init resources
    populate_resources();

    // init npcs
    chunk := Game.grid.chunks[Game.grid.currentChunk];
    for 1..7
    {
        x := random_get_within_range(xx GridChunk.left(chunk), xx GridChunk.right(chunk));
        y := random_get_within_range(xx GridChunk.top(chunk), xx GridChunk.bottom(chunk));
        pos := grid_to_world(cast(int) x, cast(int) y, 3);
        ai: AI;
        npcAI := NewMaybe(ai);
        npc := NewPerson(pos, npcAI);
        npc.speed = 0.5;
        array_add(*Game.npcs, npc);
    }

    // init shops
    {
        area := GridCell.[
            .{0, 0, 3, .AIR}, .{1, 0, 3, .AIR}, .{2, 0, 3, .AIR},
            .{0, 1, 3, .AIR}, .{1, 1, 3, .AIR}, .{2, 1, 3, .AIR},
        ];

        basket_pos := grid_to_world(area[0], shouldGetCenter = true);
        basket_collider := Collider.{type = .RECT, rect = .{20, 20}};
        basket_pos += xyz(-basket_collider.rect.x/2, -basket_collider.rect.y/2, 0);
        owner := Game.npcs[0];
        ware := NewContainer(.BASKET, basket_collider, basket_pos, owner);
        array_add(*Game.containers, ware);
        price := Price.{amount = 10, entityStandIn = .{tag = .ITEM, item = .FIBER}};
        basket_deal: Deal;
        basket_deal.price = price;
        basket_deal.ware.type = type_info(*Container);
        basket_deal.ware.value_pointer = ware;
        basket_deal.ware_tag = .CONTAINER;

        deals: [1] Deal;
        deals[0] = basket_deal;

        basket_shop := NewShop(area, deals, owner);
        array_add(*Game.shops, basket_shop);
    }

    // init items on ground
    {
        pos := Game.player.position.value + .{100, -100, 0};
        collider := Collider.{type = .CIRCLE, radius = 10};
        lumberaxe := NewItem(.LUMBER_AXE, collider, pos);
        array_add(*Game.items, lumberaxe);

        pos = Game.player.position.value + .{200, -100, 0};
        sword := NewItem(.SWORD, collider, pos);
        array_add(*Game.items, sword);
    }
    // init equipment on ground
    {
        pos := Game.player.position.value + .{0, -100, 0};
        collider := Collider.{type = .RECT, rect = .{60, 15}};
        toolbelt := NewEquipment(.TOOL_BELT, collider, pos);
        array_add(*Game.equipment, toolbelt);

        pos = Game.player.position.value + .{0, -200, 0};
        weaponbelt := NewEquipment(.WEAPON_BELT, collider, pos);
        array_add(*Game.equipment, weaponbelt);
    }
}

get_nearest_shop_to_player :: () -> *Shop, float
{
    // using Game;
    // nearest_index := 0;
    // min_dist := length(buildings[0].position.value - player.position.value);
    // for buildings
    // {
    //     dist := length(it.position.value - player.position.value);
    //     if dist < min_dist
    //     {
    //         min_dist = dist;
    //         nearest_index = it_index;
    //     }
    // }
    // return *buildings[nearest_index], min_dist;
    return null, 0.0;
}

get_holdables_in_range :: (range: float) -> [..] Holdable
{
    using Game;

    dist_info :: struct { holdable: Holdable; dist: float; }
    info_list: [..] dist_info;

    for containers if it.position.exists && (!it.owner.exists || it.owner.value == *player.person)
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
    for items if it.position.exists && (!it.owner.exists || it.owner.value == *player.person)
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
    for equipment if it.position.exists && (!it.owner.exists || it.owner.value == *player.person)
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

Get_Nearest_To_Player :: (arr: [..] *Entity) #expand
{
    for arr
    {
        dist := length(Game.player.position.value - it.position.value);
        if dist < `min_dist
        {
            `min_dist = dist;
            `nearest_index = it_index;
            `nearest_source = arr;
        }
    }
}

populate_resources :: ()
{
    for chunk: Game.grid.chunks
    {
        resources_per_chunk :: 20;
        for 0..resources_per_chunk
        {
            x := random_get_within_range(xx GridChunk.left(chunk), xx GridChunk.right(chunk));
            y := random_get_within_range(xx GridChunk.top(chunk), xx GridChunk.bottom(chunk));
            pos := grid_to_world(cast(int) x, cast(int) y, 3);
            type := cast(Resource_Type)(random_get() % xx (enum_highest_value(Resource_Type) + 1));
            quantity := max(random_get() % 20, 10);
            req: Maybe(Item_Type);
            if type == 
            {
                case .TREE;
                    req = NewMaybe(Item_Type.LUMBER_AXE);
                case .BUSH;
                    req = NewMaybe(Item_Type.SWORD); // Maybe make property flags on items like "sharp" or "bladed"
                case .IRON_VEIN; 
                    #through;
                case .COPPER_VEIN;
                    req = NewMaybe(Item_Type.PICK_AXE);

            }
            collider: Collider;
            collider.type = .CIRCLE;
            collider.radius = xx quantity;
            r := NewResource(type, collider, pos, xx quantity, req);
            array_add(*Game.resources, r);
        }
    }
}