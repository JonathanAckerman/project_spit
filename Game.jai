Game: struct 
{
    resetting: bool;
    paused: bool;
    debug: bool;

    player: struct 
    {
        using person: Person;

        // @TODO: not a fan of this at all
        tryHarvest := false;
        tryTrade := false;
    }

    camera: struct
    {
        position: Vector2;
    }

    resourceList: [..] Resource;
    buildings: [..] Building;
    itemsOnGround: [..] Entity;
    npcs: [..] Npc;
}

Debug: struct
{
    c: DebugCursor;
    line: string;
    history: [..] string;
    lineNumber := 0;

    font: Font;
    fontSize := 28.0;
    fontSpacing := 1.0;
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
        camera.position = player.position;

        // collision
        {
            for buildings
            {
                if player.position.x + player.radius > it.position.x - it.size/2 &&
                player.position.x - player.radius < it.position.x + it.size/2 &&
                player.position.y + player.radius > it.position.y - it.size/2 &&
                player.position.y - player.radius < it.position.y + it.size/2
                {
                    player.position += unit_vector(player.position - it.position) * length(player.velocity);
                }
            }
        }

        player.position += player.velocity;  
        if length(player.velocity) != 0 then player.forward = unit_vector(player.velocity);

        player.velocity = .{};
        camera_vector = .{WINDOW_WIDTH/2, WINDOW_HEIGHT/2} - player.position;

        harvestNearestResource :: ()
        {
            using Game;
            closest_index := 0;
            min_dist := length(resourceList[0].position - player.position);
            for resourceList
            {
                dist := length(it.position - player.position);
                if dist < min_dist
                {
                    min_dist = dist;
                    closest_index = it_index;
                }
            }
            if min_dist < 100
            {
                resource := resourceList[closest_index];
                has_harvested := false;

                // try to fill held first
                if player.held.exists && player.held.value.id == .BASKET
                {
                    basket := *player.held.value.container;
                    basket_total_count := compute_container_weight(basket);
                    if basket_total_count < basket.capacity
                    {
                        // calculate the max that we can add to the basket
                        amount := ifx basket_total_count + resource.quantity > basket.capacity
                            then basket.capacity - basket_total_count
                            else resource.quantity;
                        basket.contents[resource.id] += amount;
                        array_unordered_remove_by_index(*resourceList, closest_index);
                        has_harvested = true;
                    }
                }

                // pockets can only hold 10 of each resource
                if !has_harvested && player.pockets.contents[resource.id] < 10
                {
                    player.pockets.contents[resource.id] += resource.quantity;
                    player.pockets.contents[resource.id] = min(player.pockets.contents[resource.id], 10);
                    array_unordered_remove_by_index(*resourceList, closest_index);
                }
            }
        }
        if player.tryHarvest then harvestNearestResource();

        tradeWithNearestTrader :: ()
        {
            using Game;
            // get nearest trader
            nearest, dist := get_closest_bldg_to_player(.TRADER);

            // check trade range
            trader_range := compute_interact_range(nearest);
            if dist < trader_range
            {
                containers := get_nearby_containers();
                from: *Container;
                // look in all nearby inventories for wanted resource
                for containers
                {
                    if it.contents[nearest.want] > 0
                    {
                        from = it;
                        break;
                    }
                }
                // look for a valid inventory to put it into
                if containers[0].contents[nearest.have] < 10
                {
                    from.contents[nearest.want] -= 1;
                    containers[0].contents[nearest.have] += 1;
                }
                else
                {
                    for containers
                    {
                        if it_index == 0 continue; // skip the player's pockets since it functions differently
                        if compute_container_weight(it) < it.capacity
                        {
                            from.contents[nearest.want] -= 1;
                            it.contents[nearest.have] += 1;
                            break;
                        }
                    }
                }
            }
        }
        if player.tryTrade then tradeWithNearestTrader();

        buyFromNearestShop :: ()
        {
            using Game;
            nearest_shop, dist := get_closest_bldg_to_player(.SHOP);
            // check shop range
            shop_range := compute_interact_range(nearest_shop);
            if dist < shop_range
            {
                nearby_containers := get_nearby_containers();

                cost := nearest_shop.amount;
                total_available := 0;
                for nearby_containers { total_available += it.contents[nearest_shop.resource]; }
                if total_available >= cost // we can afford it
                {
                    // pay the cost
                    paid := 0;
                    for nearby_containers
                    {
                        if paid < cost
                        {
                            containerAmount := *it.contents[nearest_shop.resource];
                            if <<containerAmount >= cost - paid
                            {
                                <<containerAmount -= cost - paid;
                                break;
                            }
                            else
                            {
                                paid += <<containerAmount;
                                <<containerAmount = 0;
                            }
                        }
                    }

                    item: Maybe(Entity);
                    item.value.id = nearest_shop.item.id;
                    if nearest_shop.item.id == .BASKET then item.value.container.capacity = 100; //@@@: this probably doesnt need to be state if all baskets are the same
                    else if nearest_shop.item.id == .CHEST then item.value.container.capacity = 300;
                    item.exists = true;

                    if !player.held.exists then player.held = item; // receive the item
                    else // drop the item nearby
                    {
                        // @TODO: make size (world or ui) a lookup rather than state on the object
                        item.value.position = nearest_shop.position + .{0, -100};
                        array_add(*itemsOnGround, item.value);
                    }
                }
            }
        }
        if player.tryTrade then buyFromNearestShop();

        if player.tryTrade
        {
            closest_index := 0;
            min_dist := length(npcs[0].position - player.position);
            for npcs
            {
                dist := length(it.position - player.position);
                if dist < min_dist
                {
                    min_dist = dist;
                    closest_index = it_index;
                }
            }
            nearest := npcs[closest_index];
            if min_dist <= 150
            {
                nearest.ai.isSpeaking = true;
                nearest.ai.speakTimer = nearest.ai.speakDuration;
            }
        }

        // npc ai
        {
            for* npc: npcs
            {
                if !npc.ai.hasGoal && npc.ai.goalResetTimer <= 0.0
                {
                    x := random_get_within_range(npc.position.x - 200, npc.position.x + 200);
                    y := random_get_within_range(-npc.position.y - 200, npc.position.y + 200);
                    check_collision := true;
                    while check_collision
                    {
                        collided := false;
                        for bldg: Game.buildings
                        {
                            if x > bldg.position.x - bldg.size/2 &&
                            x < bldg.position.x + bldg.size/2 &&
                            y > bldg.position.y - bldg.size/2 && 
                            y < bldg.position.y + bldg.size/2
                            {
                                // try again with new position
                                x = random_get_within_range(npc.position.x - 200, npc.position.x + 200);
                                y = random_get_within_range(-npc.position.y - 200, npc.position.y + 200);
                                collided = true;
                                break;
                            }
                        }
                        if !collided then check_collision = false;
                    }
                    npc.ai.goalPosition = xy(x, y);
                    npc.ai.goalResetTimer = 0.0;
                    npc.ai.goalResetDuration = 0.0;
                    npc.ai.hasGoal = true;
                }
                else if npc.ai.hasGoal
                {
                    direction := npc.ai.goalPosition - npc.position;
                    npc.velocity = unit_vector(direction) * npc.speed;
                    if length(npc.velocity) != 0 then npc.forward = unit_vector(npc.velocity);

                    if length(direction) < 1.0
                    {
                        npc.ai.hasGoal = false;
                        // goal reached, reset timer
                        if npc.ai.goalResetDuration <= 0.0
                        {
                            npc.ai.goalResetDuration = random_get_within_range(3.0, 7.5); 
                            npc.ai.goalResetTimer = npc.ai.goalResetDuration;
                        }
                    }
                }
                else // goalResetTimer > 0.0
                {
                    npc.ai.goalResetTimer -= dt;
                    npc.velocity = .{};
                    npc.ai.hasGoal = false;
                }

                // interrupt goal and turn towards the player when they get close
                npc_to_player := player.position - npc.position; 
                if length(npc_to_player) < 150
                {
                    npc.forward = unit_vector(npc_to_player);
                    npc.velocity = .{};

                    // only draw text when player is close enough
                    if npc.ai.isSpeaking
                    {
                        pos := npc.position + camera_vector;
                        if npc.ai.speakTimer > 0.0
                        {
                            npc.ai.speakTimer -= dt;
                            DrawText("HI", xx (pos.x + 30), xx (pos.y - 10), 20, BLACK);
                        }
                    }
                }
                npc.position += npc.velocity;
            }
        }
    }

    // Draw
    {
        BeginDrawing();
        ClearBackground(WHITE);
        
        // map
        {
            top := -1000.0;
            left := -1000.0;
            for row: 0..20
            {
                ss_rect := xy(left, -1000.0 + row * 100.0) + camera_vector;
                DrawLineV(xx ss_rect, xx ss_rect + xy(2000, 0), LIGHTGRAY);
            }
            for col: 0..20
            {
                ss_rect := xy(-1000.0 + col * 100.0, top) + camera_vector;
                DrawLineV(xx ss_rect, xx ss_rect + xy(0, 2000), LIGHTGRAY);
            }
        }

        // resources
        {
            for resourceList
            {
                ss_resource := it.position + camera_vector;
                resource_color := get_resource_color(it.id);
                DrawCircle(xx ss_resource.x, xx ss_resource.y, xx it.quantity, resource_color);
            }
        }

        // buildings
        {
            for buildings
            {
                drawpos := it.position - xy(it.size/2.0, it.size/2.0);
                DrawRectangleV(drawpos + camera_vector, xy(xx it.size, xx it.size), BLACK);

                if it.bldgType == .TRADER
                {
                    want_color := get_resource_color(it.want);
                    have_color := get_resource_color(it.have);
                    DrawRectangleV((it.position - .{16, 8}) + camera_vector, .{16, 16}, want_color);
                    DrawRectangleV((it.position + .{16, 8}) + camera_vector, .{16, 16}, have_color);
                }
                if it.bldgType == .SHOP
                {
                    if it.item.id == .BASKET
                        draw_item_basket((it.position - xy(it.size/8.0, it.size/8.0)) + camera_vector, it.size/4.0);
                    if it.item.id == .CHEST
                        draw_item_basket((it.position - xy(it.size/8.0, it.size/8.0)) + camera_vector, it.size/4.0);
                }
            }

            nearest, dist := get_closest_bldg_to_player();
            ss_bldg := nearest.position + camera_vector;
            interact_range := compute_interact_range(nearest);
            if dist < interact_range
                DrawCircleLines(xx ss_bldg.x, xx ss_bldg.y, interact_range, BLACK);
        }

        // items in world
        {
            for itemsOnGround
            {
                if it.id ==
                {
                    case .BASKET;
                        draw_item_basket(it.position + camera_vector, 20.0);
                    case .CHEST;
                        draw_item_basket(it.position + camera_vector, 20.0);
                    case .TOOL_BELT;
                        DrawRectangleV(it.position - xy(it.size.x/2.0, it.size.y/2.0) + camera_vector, it.size, GREEN);
                    case .WEAPON_BELT;
                        DrawRectangleV(it.position - xy(it.size.x/2.0, it.size.y/2.0) + camera_vector, it.size, RED);
                    case .LUMBER_AXE;
                        DrawCircleV(it.position + camera_vector, it.size.x, GRAY);
                }
            }
        }

        // npcs
        for npcs
        {
            ss_npc := it.position + camera_vector;
            DrawCircle(xx ss_npc.x, xx ss_npc.y, xx it.radius, it.color);
            front := ss_npc + it.forward * cast(float) it.radius;
            DrawLineEx(xx ss_npc, xx front, 2.0, WHITE);
        }


        // player
        {
            ss_player := player.position + camera_vector;
            DrawCircle(xx ss_player.x, xx ss_player.y, xx player.radius, player.color);
            front := ss_player + player.forward * cast(float) player.radius;
            DrawLineEx(xx ss_player, xx front, 2.0, WHITE);
        }

        // ui
        {
            // pockets
            resource_names := enum_names(Resource_ID);
            DrawText(xx "Resources:", 20, 20, 20, BLACK);
            for r, r_index: enum_values_as_s64(Resource_ID)
            {
                y_pos := 20 + 20 * (r_index + 1);
                line := tprint("%: %", resource_names[r_index], player.pockets.contents[r]);
                DrawText(to_c_string(line), 20, xx y_pos, 20, BLACK);
            }

            // held
            xpos := 20.0;
            DrawText(xx "Held:", 20, WINDOW_HEIGHT - 100, 20, BLACK);
            DrawRectangleLines(xx xpos, WINDOW_HEIGHT - 80, 60, 60, BLACK);
            if player.held.exists 
            {
                if player.held.value.id ==
                {
                    case .BASKET;
                        draw_item_basket(xy(xpos + 20.0, WINDOW_HEIGHT - 65), 20.0);
                        for r, r_index: player.held.value.container.contents
                        {
                            y_pos := (WINDOW_HEIGHT - 80) - 20 * (r_index + 2);
                            line := tprint("%: %", resource_names[r_index], r);
                            DrawText(to_c_string(line), 20, xx y_pos, 20, BLACK);
                        }
                        xpos += 80.0;
                    case .CHEST;
                        draw_item_basket(xy(xpos + 20.0, WINDOW_HEIGHT - 55), 20.0);
                        xpos += 80.0;
                }
            }
            // tool belt
            xpos = 90;
            DrawRectangleLines(xx xpos, WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw item slot
            if player.toolBelt.exists
            {
                DrawRectangleV(xy(xpos + 10, WINDOW_HEIGHT - 80 + 35), xy(40, 10), GREEN); //draw ui representation

                xpos = WINDOW_WIDTH/2 - 230;
                for i: 0..player.toolBelt.value.capacity - 1
                {
                    DrawRectangleLines(xx (xpos + i * 70), WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw inv boxes
                    if i < player.toolBelt.value.contents.count
                    {
                        item := player.toolBelt.value.contents[i];
                        draw_item(xy(xpos + i * 70 + 30, WINDOW_HEIGHT - 50), item); //draw inv
                    }
                }
            }
            // weapon belt
            xpos = 160;
            DrawRectangleLines(xx xpos, WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw item slot
            if player.weaponBelt.exists
            {
                DrawRectangleV(xy(xpos + 10, WINDOW_HEIGHT - 80 + 35), xy(40, 10), RED); //draw ui representation
                xpos = WINDOW_WIDTH/2 + 30;
                for i: 0..player.weaponBelt.value.capacity - 1
                {
                    DrawRectangleLines(xx (xpos + i * 70), WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw inv
                }
            }

            // nearby inventory
            // @Cleanup: handle all items, with and without inventories
            closest_inventory := get_closest_item_in_range(50);
            if closest_inventory.exists
            {
                drawpos := closest_inventory.value.position + camera_vector;
                if closest_inventory.value.id == .BASKET || closest_inventory.value.id == .CHEST
                    drawpos += .{30, -110};
                DrawText(to_c_string(tprint("%", closest_inventory.value.id)), xx drawpos.x, xx drawpos.y, 20, BLACK);
                if closest_inventory.value.id == .BASKET || closest_inventory.value.id == .CHEST
                    drawpos += .{0, 100};
                if closest_inventory.value.id == .BASKET || closest_inventory.value.id == .CHEST
                {
                    for r, r_index: closest_inventory.value.container.contents
                    {
                        line := tprint("%: %", resource_names[r_index], r);
                        DrawText(to_c_string(line), xx drawpos.x, xx drawpos.y, 20, BLACK);
                        drawpos.y -= 20;
                    }
                }
            }
        }

        // debug
        {
            if debug
            {
                debug_player_position();
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
    seed := random_get();
    if seed % 2 == 0 then seed += 1;
    random_seed(seed);

    //init resources
    for i: 1..20
    {
        x := random_get_within_range(-1000, 1000);
        y := random_get_within_range(-1000, 1000);
        id := random_get() % xx (enum_highest_value(Resource_ID) + 1);
        quantity := max(random_get() % 20, 10);

        r : Resource;
        r.position = xy(x, y);
        r.id = cast(Resource_ID) id;
        r.quantity = xx quantity;

        array_add(*Game.resourceList, r);
    }

    //init traders
    num_traders := clamp(random_get(), 3, 5);
    for 1..num_traders
    {
        // @TODO: check for overlapping
        x := random_get_within_range(-1000, 1000);
        y := random_get_within_range(-1000, 1000);
        want := random_get() % xx (enum_highest_value(Resource_ID) + 1);
        have := want;
        while have == want
        {
            have = random_get() % xx (enum_highest_value(Resource_ID) + 1);
        }
        size := clamp(random_get(), 50, 100);
        
        r : Building;
        r.position = xy(x, y);
        r.size = xx size;
        r.bldgType = .TRADER;
        r.want = cast(Resource_ID) want;
        r.have = cast(Resource_ID) have;

        array_add(*Game.buildings, r);
    }

    // init shops
    basket_shop : Building;
    basket_shop.position = xy(-1100, -1100);
    basket_shop.size = 50;
    basket_shop.bldgType = .SHOP;
    basket_shop.resource = .FIBER;
    basket_shop.amount = 10;
    basket_shop.item.id = .BASKET;
    basket_shop.item.container.capacity = 30;
    array_add(*Game.buildings, basket_shop);
    chest_shop : Building;
    chest_shop.position = xy(-900, -1100);
    chest_shop.size = 50;
    chest_shop.bldgType = .SHOP;
    chest_shop.resource = .WOOD;
    chest_shop.amount = 10;
    chest_shop.item.id = .CHEST;
    chest_shop.item.container.capacity = 30;
    array_add(*Game.buildings, chest_shop);

    // init npcs
    for 1..7
    {
        npc: Npc;
        x := random_get_within_range(-1000, 1000);
        y := random_get_within_range(-1000, 1000);
        check_collision := true;
        while check_collision
        {
            collided := false;
            for Game.buildings
            {
                if x > it.position.x &&
                x < it.position.x + it.size &&
                y > it.position.y && 
                y < it.position.y + it.size
                {
                    // try again with new position
                    x = random_get_within_range(-1000, 1000);
                    y = random_get_within_range(-1000, 1000);
                    collided = true;
                    break;
                }
            }
            if !collided then check_collision = false;
        }
        npc.position = xy(x, y);
        npc.color = BROWN;
        npc.speed = 0.5;
        array_add(*Game.npcs, npc);
    }

    // init items on ground
    {
        toolbelt: Entity;
        toolbelt.position = Game.player.position + .{0, -100};
        toolbelt.size = .{60, 15};
        toolbelt.id = .TOOL_BELT;
        toolbelt.equipment.capacity = 3;
        array_resize(*toolbelt.equipment.contents, 3);
        array_add(*Game.itemsOnGround, toolbelt);

        lumberaxe: Entity;
        lumberaxe.position = Game.player.position + .{100, -100};
        lumberaxe.size = .{10, 10};
        lumberaxe.id = .LUMBER_AXE;
        array_add(*Game.itemsOnGround, lumberaxe);
        
        weaponbelt: Entity;
        weaponbelt.position = Game.player.position + .{0, -200};
        weaponbelt.size = .{60, 15};
        weaponbelt.id = .WEAPON_BELT;
        weaponbelt.equipment.capacity = 3;
        array_resize(*weaponbelt.equipment.contents, 3);
        array_add(*Game.itemsOnGround, weaponbelt);
    }
}

compute_interact_range :: (b: Building) -> float
{
    bldg_half_width := b.size/2.0;
    bldg_center_to_corner_length := sqrt(2 * (bldg_half_width * bldg_half_width));
    return bldg_center_to_corner_length + Game.player.radius + 10.0;
}

get_closest_bldg_to_player :: () -> *Building, float
{
    using Game;
    closest_index := 0;
    min_dist := length(buildings[0].position - player.position);
    for buildings
    {
        dist := length(it.position - player.position);
        if dist < min_dist
        {
            min_dist = dist;
            closest_index = it_index;
        }
    }
    return *buildings[closest_index], min_dist;
}

get_closest_bldg_to_player :: (type: Building.BldgType) -> *Building, float
{
    using Game;
    closest_index := 0;
    min_dist := length(buildings[0].position - player.position);
    for buildings if it.bldgType == type
    {
        dist := length(it.position - player.position);
        if dist < min_dist
        {
            min_dist = dist;
            closest_index = it_index;
        }
    }
    return *buildings[closest_index], min_dist;
}

get_closest_item_in_range :: (range: float) -> Maybe(*Entity), int
{
    using Game;
    result: Maybe(*Entity);
    
    if itemsOnGround.count <= 0 return result, -1;

    min_dist :=  length(player.position - itemsOnGround[0].position);
    closest_index := 0;
    for itemsOnGround
    {
        dist := length(player.position - it.position);
        if dist < min_dist
        {
            min_dist = dist;
            closest_index = it_index;
        }
    }

    if min_dist < range
    {
        result.exists = true;
        result.value = *itemsOnGround[closest_index];
    }
    return result, closest_index;
}

get_nearby_containers :: () -> [..] *Container
{
    using Game;
    c: [..] *Container;
    array_add(*c, *player.pockets);

    if player.held.exists && player.held.value.id == .BASKET
        array_add(*c, *player.held.value.container);

    for *itemsOnGround if it.id == .BASKET || it.id == .CHEST
    {
        if length(player.position - it.position) < 50.0
            array_add(*c, *it.container);
    }
    return c;
}

compute_container_weight :: (c: Container) -> int
{
    total := 0;
    for c.contents { total += it; }
    return total;
}

drop_held_item :: ()
{
    using Game;
    player.held.value.position = player.position + player.forward;
    array_add(*itemsOnGround, player.held.value);
    player.held.exists = false;
}

try_pickup_nearest_item :: ()
{
    using Game;
    closest_item, index := get_closest_item_in_range(50);
    was_picked_up := false;
    if closest_item.exists
    {
        if closest_item.value.id ==
        {
            case .TOOL_BELT;
                e: Maybe(Equipment);
                e.exists = true;
                e.value = closest_item.value.equipment;
                player.toolBelt = e;
                was_picked_up = true;
            case .WEAPON_BELT;
                e: Maybe(Equipment);
                e.exists = true;
                e.value = closest_item.value.equipment;
                player.weaponBelt = e;
                was_picked_up = true;
            case .LUMBER_AXE;
                if player.toolBelt.exists
                {
                    toolbelt := *player.toolBelt.value;
                    toolbelt_contents := player.toolBelt.value.contents;
                    if toolbelt.contents.count < toolbelt.capacity
                    {
                        toolbelt_contents[toolbelt.contents.count] = closest_item.value;
                        toolbelt.contents.count += 1;
                        was_picked_up = true;
                    }
                }
            case;
                t: Maybe(Entity);
                t.exists = true;
                t.value = <<(closest_item.value);
                player.held = t;
                was_picked_up = true;
        }

        if was_picked_up
        {
            array_unordered_remove_by_index(*itemsOnGround, index);
        }
    }
}