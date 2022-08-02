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

    entityList:         [..]* [..] *Entity;
    resourceList:       [..] *Entity;
    itemsOnGround:      [..] *Entity;
    containersOnGround: [..] *Entity;
    equipmentOnGround:  [..] *Entity;
    npcs:               [..] *Entity;
    shops:              [..] *Shop;

    // ui state
    // highlightedItem: *Entity = ---;
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

        player.position += player.person.velocity;
        if length(player.person.velocity) != 0 then player.person.forward = unit_vector(player.person.velocity);
        player.person.velocity = .{};

        camera.position = player.position;
        camera_vector = WINDOW_CENTER - camera.position * camera.zoom;

        equipItem :: ()
        {
            player := *Game.player.person;
            belt_inventory := ifx Input.equipSlot < 3 then *Game.player.person.toolBelt else *Game.player.person.weaponBelt;
            slot := ifx Input.equipSlot < 3 then Input.equipSlot else Input.equipSlot - 3;

            if belt_inventory.exists && belt_inventory.value.contents.count > 0
            {
                if player.held.exists
                {
                    if player.held.value.tag ==
                    {
                        case .ITEM;
                            sheath_inv: *Equipment;
                            if is_tool(player.held.value.item.type) then sheath_inv = *player.toolBelt.value;
                            else if is_weapon(player.held.value.item.type) then sheath_inv = *player.weaponBelt.value;
                            // @Note: there might be other item types later

                            if sheath_inv.contents.count == sheath_inv.capacity
                            {
                                if sheath_inv == *belt_inventory.value
                                {
                                    temp := player.held.value;
                                    player.held.value = *belt_inventory.value.contents[slot];
                                    belt_inventory.value.contents[slot] = temp;
                                }
                                else
                                {
                                    array_add(*Game.itemsOnGround, player.held.value);
                                    player.held.value = *belt_inventory.value.contents[slot];
                                }
                            }
                            else // there is space for held item
                            {
                                array_add(*sheath_inv.contents, <<player.held.value);
                                player.held.value = *belt_inventory.value.contents[slot];
                            }

                        case .CONTAINER;
                            array_add(*Game.containersOnGround, player.held.value);
                            player.held.value = *belt_inventory.value.contents[slot];
                    }
                    // Swap(*belt_inventory.value.contents[slot], *belt_inventory.value.contents[belt_inventory.value.contents.count - 1]);
                    // newHeld := pop(*belt_inventory.value.contents);
                    // player.held.value = *newHeld;
                    array_unordered_remove_by_index(*belt_inventory.value.contents, slot);
                }
                else
                {
                    player.held.value = *belt_inventory.value.contents[slot];
                    player.held.exists = true;
                    array_unordered_remove_by_index(*belt_inventory.value.contents, slot);
                }
            }

            Input.equipSlot = -1; // reset input state
        }
        if Input.equipSlot != -1 then equipItem();

        drop_held :: ()
        {
            using Game;
            
            if !player.person.held.exists return;

            player.person.held.value.position = player.position + player.person.forward;
            if player.person.held.value.tag ==
            {
                case .CONTAINER;
                    array_add(*containersOnGround, player.person.held.value);
                case .ITEM;
                    array_add(*itemsOnGround, player.person.held.value);
                case .EQUIPMENT;
                    array_add(*equipmentOnGround, player.person.held.value);
            }
            player.person.held.exists = false;
            Input.drop = false;
        }
        if Input.drop then drop_held();

        try_pickup :: ()
        {
            using Game;
            closest_item, index := get_nearest_holdable_in_range(100);
            was_picked_up := false;
            if closest_item.exists
            {
                if closest_item.value.tag ==
                {
                    case .EQUIPMENT;
                        equipment := closest_item.value.equipment;
                        e := NewMaybe(equipment);
                        if equipment.type ==
                        {
                            case .TOOL_BELT;
                                player.person.toolBelt = e;
                                was_picked_up = true;
                            case .WEAPON_BELT;
                                player.person.weaponBelt = e;
                                was_picked_up = true;
                        }

                    case .ITEM;
                        item := closest_item.value.item;
                        if !player.person.held.exists
                        {
                            player.person.held.value = closest_item.value;
                            player.person.held.exists = true;
                            was_picked_up = true;
                        }
                        else
                        {
                            dest_inv: *Equipment;
                            if is_tool(item.type) then dest_inv = *player.person.toolBelt.value;
                            else if is_weapon(item.type) then dest_inv = *player.person.weaponBelt.value;
                            // @Note: there might be other item types later

                            if dest_inv.contents.count < dest_inv.capacity
                            {
                                array_add(*dest_inv.contents, <<closest_item.value);
                                was_picked_up = true;
                            }
                            else
                            {
                                // Here we don't mark was_picked_up since we want to leave the held item on the ground
                                temp := player.person.held.value;
                                player.person.held.value = closest_item.value;
                                <<closest_item.value = <<temp;
                            }
                        }

                    case .CONTAINER;
                        newHeld: = NewMaybe(closest_item.value);
                        player.person.held = newHeld;
                        was_picked_up = true;
                }

                if was_picked_up
                {
                    if closest_item.value.tag ==
                    {
                        case .CONTAINER;
                            array_unordered_remove_by_index(*containersOnGround, index);
                        case .ITEM;
                            array_unordered_remove_by_index(*itemsOnGround, index);
                        case .EQUIPMENT;
                            array_unordered_remove_by_index(*equipmentOnGround, index);
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
            resource_info :: struct { entity: *Entity; direction: Vector2; }
            sorted_resources: [..] resource_info;
            for resourceList
            {
                player_to_resource : Vector2 = it.position - player.position;
                if length(player_to_resource) < player.interactRange // @TODO: Make this take tool range into account
                {
                    info: resource_info;
                    info.entity = resourceList[it_index];
                    info.direction = player_to_resource;
                    array_add(*sorted_resources, info);
                }
            }

            less_than :: (a, b) => cast(s64) (length(a.direction) - length(b.direction));
            bubble_sort(sorted_resources, less_than);

            // find the first resource we are able to harvest
            resource_to_harvest: Maybe(resource_info);
            for sorted_resources
            {
                if it.entity.resource.type ==
                {
                    // trees require the lumber axe equipped
                    case .TREE;
                        if player.person.held.exists && player.person.held.value.tag == .ITEM
                        {
                            if player.person.held.value.item.type == .LUMBER_AXE
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
                by_product := NewItem(.WOOD_LOG, Collider.{type = .CIRCLE, radius = 10}, resource_to_harvest.value.entity.position + unit_vector(resource_to_harvest.value.direction) * 15);
                array_add(*itemsOnGround, by_product);
                swap_and_pop(*resourceList, *resource_to_harvest.value.entity); 
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
                player_grid_cell := world_to_grid(player.position);
                for s.area if it == player_grid_cell
                {
                    shop.value = s;
                    shop.exists = true;
                }
            }

            if !shop.exists || shop.value.deals.count == 0 then return;

            // get the nearest deal to the player
            nearest_deal := shop.value.deals[0];
            nearest_deal_dist := length(nearest_deal.ware.position - player.position);
            for shop.value.deals
            {
                dist := length(it.ware.position - player.position);
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
                // //@@@: ugh now the concept of currency goes out the window
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
                //     if !player.person.held.exists 
                //     {
                //         newHeld := NewMaybe(*item);
                //         player.person.held = newHeld;
                //     }
                //     else // drop the item nearby
                //     {
                //         // @TODO: make size (world or ui) a lookup rather than state on the object
                //         item.position = nearest_shop.position + .{0, -100};
                //         array_add(*itemsOnGround, item);
                //     }
                // }
            }
        }
        if Input.trade then buyFromShop();

        talkToNearestNPC :: ()
        {
            using Game;
            nearest_index := 0;
            min_dist := length(npcs[0].position - player.position);
            for npcs
            {
                dist := length(it.position - player.position);
                if dist < min_dist
                {
                    min_dist = dist;
                    nearest_index = it_index;
                }
            }
            nearest := npcs[nearest_index];
            if min_dist <= 150
            {
                nearest.person.ai.value.isSpeaking = true;
                nearest.person.ai.value.speakTimer = nearest.person.ai.value.speakDuration;
            }
        }
        if Input.trade then talkToNearestNPC();

        // npc ai
        {
            for npc: npcs
            {
                if !npc.person.ai.value.hasGoal && npc.person.ai.value.goalResetTimer <= 0.0
                {
                    x := random_get_within_range(npc.position.x - 200, npc.position.x + 200);
                    y := random_get_within_range(-npc.position.y - 200, npc.position.y + 200);
                    // check_collision := true;
                    // while check_collision
                    // {
                    //     collided := false;
                    //     for bldg: Game.buildings
                    //     {
                    //         if x > bldg.position.x - bldg.collider.rect.x/2 &&
                    //         x < bldg.position.x + bldg.collider.rect.x/2 &&
                    //         y > bldg.position.y - bldg.collider.rect.y/2 && 
                    //         y < bldg.position.y + bldg.collider.rect.y/2
                    //         {
                    //             // try again with new position
                    //             x = random_get_within_range(npc.position.x - 200, npc.position.x + 200);
                    //             y = random_get_within_range(-npc.position.y - 200, npc.position.y + 200);
                    //             collided = true;
                    //             break;
                    //         }
                    //     }
                    //     if !collided then check_collision = false;
                    // }
                    npc.person.ai.value.goalPosition = xy(x, y);
                    npc.person.ai.value.goalResetTimer = 0.0;
                    npc.person.ai.value.goalResetDuration = 0.0;
                    npc.person.ai.value.hasGoal = true;
                }
                else if npc.person.ai.value.hasGoal
                {
                    direction := npc.person.ai.value.goalPosition - npc.position;
                    npc.person.velocity = unit_vector(direction) * npc.person.speed;
                    if length(npc.person.velocity) != 0 then npc.person.forward = unit_vector(npc.person.velocity);

                    if length(direction) < 1.0
                    {
                        npc.person.ai.value.hasGoal = false;
                        // goal reached, reset timer
                        if npc.person.ai.value.goalResetDuration <= 0.0
                        {
                            npc.person.ai.value.goalResetDuration = random_get_within_range(3.0, 7.5); 
                            npc.person.ai.value.goalResetTimer = npc.person.ai.value.goalResetDuration;
                        }
                    }
                }
                else // goalResetTimer > 0.0
                {
                    npc.person.ai.value.goalResetTimer -= dt;
                    npc.person.velocity = .{};
                    npc.person.ai.value.hasGoal = false;
                }

                // interrupt goal and turn towards the player when they get close
                npc_to_player := player.position - npc.position;
                dist := length(npc_to_player);
                if dist < 150
                {
                    npc.person.forward = unit_vector(npc_to_player);
                    npc.person.velocity = .{};

                    // only draw text when player is close enough
                    if npc.person.ai.value.isSpeaking
                    {
                        pos := npc.position + camera_vector;
                        if npc.person.ai.value.speakTimer > 0.0
                        {
                            npc.person.ai.value.speakTimer -= dt;
                            DrawText("HI", xx (pos.x + 30), xx (pos.y - 10), 20, BLACK);
                        }
                    }
                }
                npc.position += npc.person.velocity;
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

        // draw resources
        {
            for resourceList
            {
                ss_resource := it.position * camera.zoom + camera_vector;
                draw_entity(it, ss_resource);
            }
        }

        // draw buildings
        {
            // for buildings
            // {
            //     drawpos := (it.position - xy(it.collider.rect.x/2.0, it.collider.rect.y/2.0)) * camera.zoom;
            //     DrawRectangleV(drawpos + camera_vector, xy(xx it.collider.rect.x, xx it.collider.rect.y) * camera.zoom, BLACK);

            //     if it.building.type ==
            //     {
            //         case .SHOP;
            //             collider := Collider.{type = .RECT, rect = .{20, 20}};
            //             pos := (it.position - xy(collider.rect.x/2.5, it.collider.rect.y/4)) * camera.zoom + camera_vector;
                        
            //     }
            // }

            // nearest, dist := get_closest_bldg_to_player();
            // ss_bldg := nearest.position * camera.zoom + camera_vector;
            // interact_range := compute_interact_range(nearest);
            // if dist < interact_range
            //     DrawCircleLines(xx ss_bldg.x, xx ss_bldg.y, interact_range * camera.zoom, BLACK);
        }

        // draw items in world
        {
            for itemsOnGround
            {
                draw_entity(it, it.position * camera.zoom + camera_vector);
            }

            for containersOnGround
            {
                pos := (it.position - xy(it.collider.rect.x/2.0, it.collider.rect.x/2.0)) * camera.zoom + camera_vector;
                draw_entity(it, pos);
            }

            for equipmentOnGround
            {
                pos := (it.position - xy(it.collider.rect.x/2.0, it.collider.rect.y/2.0)) * camera.zoom + camera_vector;
                draw_entity(it, pos);
            }
        }

        // draw npcs
        for npcs
        {
            ss_npc := it.position * camera.zoom + camera_vector;
            DrawCircle(xx ss_npc.x, xx ss_npc.y, xx it.collider.radius * camera.zoom, it.person.color);
            front := ss_npc + it.person.forward * cast(float) it.collider.radius * camera.zoom;
            DrawLineEx(xx ss_npc, xx front, 2.0, WHITE);
        }

        // draw player
        {
            ss_player := player.position * camera.zoom + camera_vector;
            DrawCircle(xx ss_player.x, xx ss_player.y, xx player.collider.radius * camera.zoom, player.person.color);
            front := ss_player + player.person.forward * cast(float) player.collider.radius * camera.zoom;
            DrawLineEx(xx ss_player, xx front, 2.0, WHITE);
        }

        // draw ui
        {
            // draw pockets
            // resource_names := enum_names(Resource_Type);
            // DrawText(xx "Resources:", 20, 20, 20, BLACK);
            // for r, r_index: enum_values_as_s64(Resource_Type)
            // {
            //     y_pos := 20 + 20 * (r_index + 1);
            //     line := tprint("%: %", resource_names[r_index], player.person.pockets.contents[r]);
            //     DrawText(to_c_string(line), 20, xx y_pos, 20, BLACK);
            // }

            // draw held
            // @Cleanup
            xpos := 20.0;
            DrawText(xx "Held:", 20, WINDOW_HEIGHT - 100, 20, BLACK);
            DrawRectangleLines(xx xpos, WINDOW_HEIGHT - 80, 60, 60, BLACK);
            if player.person.held.exists 
            {
                if player.person.held.value.tag ==
                {
                    case .CONTAINER;
                        if player.person.held.value.container.type ==
                        {
                            case .BASKET;
                                draw_entity(player.person.held.value, xy(xpos + 20.0, WINDOW_HEIGHT - 65));
                                // for r, r_index: player.person.held.value.container.contents
                                // {
                                //     y_pos := (WINDOW_HEIGHT - 80) - 20 * (r_index + 2);
                                //     line := tprint("%: %", resource_names[r_index], r);
                                //     DrawText(to_c_string(line), 20, xx y_pos, 20, BLACK);
                                // }
                                xpos += 80.0;
                            case .CHEST;
                                draw_entity(player.person.held.value, xy(xpos + 20.0, WINDOW_HEIGHT - 55));
                                xpos += 80.0;
                        }
                    case .ITEM;
                        if player.person.held.value.item.type ==
                        {
                            case;
                                draw_entity(player.person.held.value, xy(xpos + 30.0, WINDOW_HEIGHT - 50));
                                xpos += 80.0;
                        }
                }
            }
            // draw tool belt
            xpos = 90;
            DrawRectangleLines(xx xpos, WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw item slot
            if player.person.toolBelt.exists
            {
                DrawRectangleV(xy(xpos + 10, WINDOW_HEIGHT - 80 + 35), xy(40, 10), GREEN); //draw ui representation

                xpos = WINDOW_WIDTH/2 - 230;
                for i: 0..player.person.toolBelt.value.capacity - 1
                {
                    DrawRectangleLines(xx (xpos + i * 70), WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw inv boxes
                    if i < player.person.toolBelt.value.contents.count
                    {
                        item := player.person.toolBelt.value.contents[i];
                        draw_entity(item, xy(xpos + i * 70 + 30, WINDOW_HEIGHT - 50)); //draw inv
                    }
                }
            }
            // draw weapon belt
            xpos = 160;
            DrawRectangleLines(xx xpos, WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw item slot
            if player.person.weaponBelt.exists
            {
                DrawRectangleV(xy(xpos + 10, WINDOW_HEIGHT - 80 + 35), xy(40, 10), RED); //draw ui representation
                xpos = WINDOW_WIDTH/2 + 30;
                for i: 0..player.person.weaponBelt.value.capacity - 1
                {
                    DrawRectangleLines(xx (xpos + i * 70), WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw inv
                    if i < player.person.weaponBelt.value.contents.count
                    {
                        item := player.person.weaponBelt.value.contents[i];
                        draw_entity(item, xy(xpos + i * 70 + 30, WINDOW_HEIGHT - 50)); //draw inv
                    }
                }
            }

            // draw nearby inventory
            nearest_entity := get_nearest_holdable_in_range(player.interactRange);
            if nearest_entity.exists
            {
                drawPos := nearest_entity.value.position * camera.zoom + camera_vector;
                if nearest_entity.value.tag == .CONTAINER then drawPos += .{30, -110};
                type: Any;
                if nearest_entity.value.tag ==
                {
                    case .CONTAINER;
                        type = nearest_entity.value.container.type;
                    case .ITEM;
                        type = nearest_entity.value.item.type;
                    case .EQUIPMENT;
                        type = nearest_entity.value.equipment.type;
                }
                DrawText(to_c_string(tprint("%", type)), xx drawPos.x, xx drawPos.y, 20, BLACK);

                // if nearest_entity.value.tag == .CONTAINER
                // {
                //     drawPos += .{0, 20};
                //     for r, r_index: nearest_entity.value.container.contents
                //     {
                //         line := tprint("%: %", resource_names[r_index], r);
                //         DrawText(to_c_string(line), xx drawPos.x, xx drawPos.y, 20, BLACK);
                //         drawPos.y += 20;
                //     }
                // }
            }
        }

        // debug
        {
            if Debug.showEntityInfo
            {
                debug_player_position();
                for entityList
                {
                    for <<it
                    {
                        debug_entity_info(it);
                    }
                }
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

    noAI: Maybe(AI);
    Game.player.entity = NewPerson(.{200, 200}, noAI);

    // init entityList
    array_add(*Game.entityList, *Game.resourceList);
    array_add(*Game.entityList, *Game.itemsOnGround);
    array_add(*Game.entityList, *Game.containersOnGround);
    array_add(*Game.entityList, *Game.equipmentOnGround);
    array_add(*Game.entityList, *Game.npcs);

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
        // check_collision := true;
        // while check_collision
        // {
        //     collided := false;
        //     for Game.buildings
        //     {
        //         if x > it.position.x &&
        //         x < it.position.x + it.collider.rect.x &&
        //         y > it.position.y && 
        //         y < it.position.y + it.collider.rect.y
        //         {
        //             // try again with new position
        //             x = random_get_within_range(xx Game.grid.left(), xx Game.grid.right());
        //             y = random_get_within_range(xx Game.grid.top(), xx Game.grid.bottom());
        //             collided = true;
        //             break;
        //         }
        //     }
        //     if !collided then check_collision = false;
        // }
        ai: AI;
        npc := NewPerson(xy(x, y), NewMaybe(ai));
        npc.person.speed = 0.5;
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
        pos := Game.player.position + .{100, -100};
        collider := Collider.{type = .CIRCLE, radius = 10};
        lumberaxe := NewItem(.LUMBER_AXE, collider, pos);
        array_add(*Game.itemsOnGround, lumberaxe);

        pos = Game.player.position + .{200, -100};
        sword := NewItem(.SWORD, collider, pos);
        array_add(*Game.itemsOnGround, sword);
    }
    // init equipment on ground
    {
        pos := Game.player.position + .{0, -100};
        collider := Collider.{type = .RECT, rect = .{60, 15}};
        toolbelt := NewEquipment(.TOOL_BELT, collider, pos);
        array_add(*Game.equipmentOnGround, toolbelt);

        pos = Game.player.position + .{0, -200};
        weaponbelt := NewEquipment(.WEAPON_BELT, collider, pos);
        array_add(*Game.equipmentOnGround, weaponbelt);
    }
}

get_nearest_shop_to_player :: () -> *Shop, float
{
    // using Game;
    // nearest_index := 0;
    // min_dist := length(buildings[0].position - player.position);
    // for buildings
    // {
    //     dist := length(it.position - player.position);
    //     if dist < min_dist
    //     {
    //         min_dist = dist;
    //         nearest_index = it_index;
    //     }
    // }
    // return *buildings[nearest_index], min_dist;
    return null, 0.0;
}

// @Bug: What if you are nearer to an entity that can't be picked up, but *also* in range of one that can? it should pick up the nearest that can
get_nearest_holdable_in_range :: (range: float) -> Maybe(*Entity), int
{
    using Game;

    result: Maybe(*Entity);
    nearest_index := 0;
    min_dist := FLOAT64_MAX;

    nearest_source := itemsOnGround;
    Get_Nearest_To_Player(itemsOnGround);
    Get_Nearest_To_Player(containersOnGround);
    Get_Nearest_To_Player(equipmentOnGround);

    if min_dist < range
    {
        result.exists = true;
        result.value = nearest_source[nearest_index];
    }

    return result, nearest_index;
}

get_nearby_containers :: () -> [..] *Container
{
    using Game;
    result: [..] *Container;
    array_add(*result, *player.person.pockets);

    if player.person.held.exists && player.person.held.value.tag == .CONTAINER
    {
        basket := player.person.held.value.container;
        if basket.type == .BASKET
            array_add(*result, *basket);
    }

    for containersOnGround
    {
        if length(player.position - it.position) < 50.0
            array_add(*result, *it.container);
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
        dist := length(Game.player.position - it.position);
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
        x := random_get_within_range(-1000, 1000);
        y := random_get_within_range(-1000, 1000);
        type := random_get() % xx (enum_highest_value(Resource_Type) + 1);
        quantity := max(random_get() % 20, 10);

        collider: Collider;
        collider.type = .CIRCLE;
        collider.radius = xx quantity;
        r := NewEntityBase(xy(x, y), collider, .RESOURCE);
        r.resource.type = xx type;
        r.resource.quantity = xx quantity;

        array_add(*Game.resourceList, r);
    }
}