Game: struct 
{
    resetting: bool;
    paused: bool;

    player: Player;
    grid: Grid;
    camera: struct
    {
        zoom := 1.0;
        position: Vector2;
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

to_screen_space :: (pos: Vector2, offset: Vector2 = .{0, 0}, scale: float = 1.0) -> Vector2
{
    to_ss_vector := WINDOW_CENTER - Game.camera.position * Game.camera.zoom;
    return (pos + offset) * scale * Game.camera.zoom + to_ss_vector;
}

game_loop :: inline ()
{
    using Game;
    dt := GetFrameTime();

    // Input
    handle_input();

    camera_vector: Vector2;
    // Simulate
    {
        // collision
        {
            
        }

        if player.position.exists then player.position.value += player.velocity;
        player.velocity = .{};

        camera.position = player.position.value;
        camera_vector = WINDOW_CENTER - camera.position * camera.zoom;

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
                    case .WATER;
                        if player.held.exists && player.held.value.tag == .CONTAINER
                        {
                            if player.held.value.container.type == .BUCKET // this should be can_carry_water(), or a flag, or smth.
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
                    case .WATER;
                        by_product = NewItem(.WATER, Collider.{type = .CIRCLE, radius = 10}, resource_to_harvest.value.resource.position.value + unit_vector(resource_to_harvest.value.direction) * 15);
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
            nearest_deal := shop.value.deals[0];
            nearest_deal_dist := length(nearest_deal.ware.position.value - player.position.value);
            for shop.value.deals
            {
                dist := length(it.ware.position.value - player.position.value);
                if dist < nearest_deal_dist
                {
                    nearest_deal = it;
                    nearest_deal_dist = dist;
                }
            }

            if nearest_deal_dist < player.interactRange
            {
                // nearby_containers := get_nearby_containers();

                // cost := nearest_deal.price.amount;
                // total_available := 0;
                // //: ugh now the concept of currency goes out the window
                // for nearby_containers { total_available += it.contents[nearest_shop.building.resource]; }
                // if total_available >= cost // we can afford it
                // {
                //     // pay the cost
                //     paid := 0;
                //     for nearby_containers
                //     {
                //         if paid < cost
                //         {
                //             containerAmount := *it.contents[nearest_shop.building.resource];
                //             if <<containerAmount >= cost - paid
                //             {
                //                 <<containerAmount -= cost - paid;
                //                 break;
                //             }
                //             else
                //             {
                //                 paid += <<containerAmount;
                //                 <<containerAmount = 0;
                //             }
                //         }
                //     }

                //     item := NewContainer(nearest_shop.building.itemType, Collider.{type = .RECT, rect = .{20, 20}});
                //     if !player.held.exists 
                //     {
                //         newHeld := NewMaybe(*item);
                //         player.held = newHeld;
                //     }
                //     else // drop the item nearby
                //     {
                //         // @TODO: make size (world or ui) a lookup rather than state on the object
                //         item.position.value = nearest_shop.position.value + .{0, -100};
                //         array_add(*items, item);
                //     }
                // }
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

                    // only draw text when player is close enough
                    if npc.ai.value.isSpeaking
                    {
                        pos := to_screen_space(npc.position.value, .{30, -10});
                        if npc.ai.value.speakTimer > 0.0
                        {
                            npc.ai.value.speakTimer -= dt;
                            DrawText("HI", xx pos.x, xx pos.y, 20, BLACK);
                        }
                    }
                }
                npc.position.value += npc.velocity;
            }
        }
    }

    // Draw
    {
        BeginDrawing();
        BeginDrawing();
        ClearBackground(WHITE);
        
        // draw grid
        for i: 0..19
        {
            for j: 0..19
            {
                gc: GridCell;
                gc.x = j;
                gc.y = i;
                grid.cells[i][j] = gc;
                drawpos := grid_to_world(i, j) * camera.zoom + camera_vector;
                DrawRectangleLines(xx drawpos.x, xx drawpos.y, xx (grid.cellSize * camera.zoom), xx (grid.cellSize * camera.zoom), LIGHTGRAY);
            }
        }

        for resources { draw_resource(it); }
        for items if it.position.exists { draw_item(it); }
        for containers if it.position.exists { draw_container(it); }
        for equipment if it.position.exists { draw_equipment(it); }
        for npcs { draw_person(it); }
        draw_person(player);

        // draw ui
        {
            // draw held
            xpos := 20.0;
            DrawText(xx "Held:", 20, WINDOW_HEIGHT - 100, 20, BLACK);
            DrawRectangleLines(xx xpos, WINDOW_HEIGHT - 80, 60, 60, BLACK);
            if player.held.exists 
            {
                if player.held.value.tag ==
                {
                    case .CONTAINER;
                        if player.held.value.container.type ==
                        {
                            case .BASKET;
                                draw_container_ui(xy(xpos + 20.0, WINDOW_HEIGHT - 65), player.held.value.container.collider, 1.0, .BASKET);
                                xpos += 80.0;
                            case .BUCKET;
                                draw_container_ui(xy(xpos + 20.0, WINDOW_HEIGHT - 65), player.held.value.container.collider, 1.0, .BUCKET);
                                xpos += 80.0;
                            case .CHEST;
                                draw_container_ui(xy(xpos + 20.0, WINDOW_HEIGHT - 55), player.held.value.container.collider, 1.0, .CHEST);
                                xpos += 80.0;
                        }
                    case .ITEM;
                        if player.held.value.item.type ==
                        {
                            case;
                                draw_item_ui(xy(xpos + 30.0, WINDOW_HEIGHT - 50), player.held.value.item.collider, 1.0, player.held.value.item.type);
                                xpos += 80.0;
                        }
                }
            }
            // draw tool belt
            xpos = 90;
            DrawRectangleLines(xx xpos, WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw item slot
            if player.toolBelt.exists
            {
                DrawRectangleV(xy(xpos + 10, WINDOW_HEIGHT - 80 + 35), xy(40, 10), GREEN); //draw ui representation

                xpos = WINDOW_WIDTH/2 - 230;
                for player.toolBelt.value.contents
                {
                    DrawRectangleLines(xx (xpos + it_index * 70), WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw inv boxes
                    if it.exists
                    {
                        draw_item_ui(xy(xpos + it_index * 70 + 30, WINDOW_HEIGHT - 50), it.value.collider, 1.0, it.value.type); //draw inv items
                    }
                }
            }
            // draw weapon belt
            xpos = 160;
            DrawRectangleLines(xx xpos, WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw item slot
            if player.weaponBelt.exists
            {
                DrawRectangleV(xy(xpos + 10, WINDOW_HEIGHT - 80 + 35), xy(40, 10), RED); //draw ui representation
                xpos = WINDOW_WIDTH/2 + 30;
                for player.weaponBelt.value.contents
                {
                    DrawRectangleLines(xx (xpos + it_index * 70), WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw inv boxes
                    if it.exists
                    {
                        draw_item_ui(xy(xpos + it_index * 70 + 30, WINDOW_HEIGHT - 50), it.value.collider, 1.0, it.value.type); //draw inv items
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
    Game = .{};
    Input = .{};

    // init player
    noAI: Maybe(AI);
    Game.player.person = NewPerson(.{200, 200}, noAI);

    seed := random_get();
    if seed % 2 == 0 then seed += 1;
    random_seed(seed);

    //init resources
    populate_resources();

    // init npcs
    for 1..7
    {
        x := random_get_within_range(xx Game.grid.left(), xx Game.grid.right());
        y := random_get_within_range(xx Game.grid.top(), xx Game.grid.bottom());
        ai: AI;
        npcAI := NewMaybe(ai);
        npc := NewPerson(xy(x, y), npcAI);
        npc.speed = 0.5;
        array_add(*Game.npcs, npc);
    }

    // init shops
    {
        area := GridCell.[
            .{0, 0}, .{1, 0}, .{2, 0},
            .{1, 0}, .{1, 1}, .{1, 2},
        ];

        pos := grid_to_world(area[0], true);
        collider := Collider.{type = .RECT, rect = .{20, 20}};
        ware := NewContainer(.BASKET, collider, pos);
        price := Price.{amount = 10, entityStandIn = .{tag = .ITEM, item = .FIBER}};
        basket_deal: Deal;
        basket_deal.price = price;
        basket_deal.ware = ware;

        deals: [1] Deal;
        deals[0] = basket_deal;

        basket_shop := NewShop(area, deals, Game.npcs[0]);
    }

    // init items on ground
    {
        pos := Game.player.position.value + .{100, -100};
        collider := Collider.{type = .CIRCLE, radius = 10};
        lumberaxe := NewItem(.LUMBER_AXE, collider, pos);
        array_add(*Game.items, lumberaxe);

        pos = Game.player.position.value + .{200, -100};
        sword := NewItem(.SWORD, collider, pos);
        array_add(*Game.items, sword);
    }
    // init equipment on ground
    {
        pos := Game.player.position.value + .{0, -100};
        collider := Collider.{type = .RECT, rect = .{60, 15}};
        toolbelt := NewEquipment(.TOOL_BELT, collider, pos);
        array_add(*Game.equipment, toolbelt);

        pos = Game.player.position.value + .{0, -200};
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

    for containers if it.position.exists 
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
    for items if it.position.exists 
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
    for equipment if it.position.exists 
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
    for i: 1..20
    {
        x := random_get_within_range(0, 2000);
        y := random_get_within_range(0, 2000);
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
        r := NewResource(type, collider, xy(x, y), xx quantity, req);
        array_add(*Game.resources, r);
    }
}