Game: struct 
{
    resetting: bool;
    paused: bool;
    debug: bool;

    player: struct 
    {
        using person: Person;

        // @TODO: not a fan of this at all
        try_harvest := false;
        try_trade := false;
    }

    camera: struct
    {
        position: Vector2;
    }

    resource_list: [..] Resource;
    buildings: [..] Building;
    items_on_ground: [..] Entity;
    npcs: [..] Npc;
}

Debug: struct
{
    c: DebugCursor;
    line: string;
    history: [..] string;
    line_number := 0;

    font: Font;
    font_size := 28.0;
    font_spacing := 1.0;
}

game_loop :: inline () 
{
    dt := GetFrameTime();
    using Game;

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
                //@@@
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
        player_coords := map_get_coords();

        player.velocity = .{};
        camera_vector = .{WINDOW_WIDTH/2, WINDOW_HEIGHT/2} - player.position;

        harvest_nearest_resource :: ()
        {
            using Game;
            closest_index := 0;
            min_dist := length(resource_list[0].position - player.position);
            for resource_list
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
                resource := resource_list[closest_index];
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
                        array_unordered_remove_by_index(*resource_list, closest_index);
                        has_harvested = true;
                    }
                }

                // pockets can only hold 10 of each resource
                if !has_harvested && player.pockets.contents[resource.id] < 10
                {
                    player.pockets.contents[resource.id] += resource.quantity;
                    player.pockets.contents[resource.id] = min(player.pockets.contents[resource.id], 10);
                    array_unordered_remove_by_index(*resource_list, closest_index);
                }
            }
        }
        if player.try_harvest then harvest_nearest_resource();

        trade_with_nearest_trader :: ()
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
        if player.try_trade then trade_with_nearest_trader();

        buy_from_nearest_shop :: ()
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
                        array_add(*items_on_ground, item.value);
                    }
                }
            }
        }
        if player.try_trade then buy_from_nearest_shop();

        if player.try_trade
        {
            nearest, dist := get_nearest_npc_to_player();
            if dist <= 150
            {
                nearest.ai.is_speaking = true;
                nearest.ai.speak_timer = nearest.ai.speak_duration;
            }
        }

        // npc ai
        {
            for* npc: npcs
            {
                if !npc.ai.has_goal && npc.ai.goal_reset_timer <= 0.0
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
                    npc.ai.goal_position = xy(x, y);
                    npc.ai.goal_reset_timer = 0.0;
                    npc.ai.goal_reset_duration = 0.0;
                    npc.ai.has_goal = true;
                }
                else if npc.ai.has_goal
                {
                    direction := npc.ai.goal_position - npc.position;
                    npc.velocity = unit_vector(direction) * npc.speed;
                    if length(npc.velocity) != 0 then npc.forward = unit_vector(npc.velocity);

                    if length(direction) < 1.0
                    {
                        npc.ai.has_goal = false;
                        // goal reached, reset timer
                        if npc.ai.goal_reset_duration <= 0.0
                        {
                            npc.ai.goal_reset_duration = random_get_within_range(3.0, 7.5); 
                            npc.ai.goal_reset_timer = npc.ai.goal_reset_duration;
                        }
                    }
                }
                else // goal_reset_timer > 0.0
                {
                    npc.ai.goal_reset_timer -= dt;
                    npc.velocity = .{};
                    npc.ai.has_goal = false;
                }

                // interrupt goal and turn towards the player when they get close
                npc_to_player := player.position - npc.position; 
                if length(npc_to_player) < 150
                {
                    npc.forward = unit_vector(npc_to_player);
                    npc.velocity = .{};

                    // only draw text when player is close enough
                    if npc.ai.is_speaking
                    {
                        pos := npc.position + camera_vector;
                        if npc.ai.speak_timer > 0.0
                        {
                            npc.ai.speak_timer -= dt;
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
            for resource_list
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

                if it.bldg_type == .TRADER
                {
                    want_color := get_resource_color(it.want);
                    have_color := get_resource_color(it.have);
                    DrawRectangleV((it.position - .{16, 8}) + camera_vector, .{16, 16}, want_color);
                    DrawRectangleV((it.position + .{16, 8}) + camera_vector, .{16, 16}, have_color);
                }
                if it.bldg_type == .SHOP
                {
                    if it.item.id == .BASKET
                        Draw_Item_Basket((it.position - xy(it.size/8.0, it.size/8.0)) + camera_vector, it.size/4.0);
                    if it.item.id == .CHEST
                        Draw_Item_Chest((it.position - xy(it.size/8.0, it.size/8.0)) + camera_vector, it.size/4.0);
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
            for items_on_ground
            {
                if it.id ==
                {
                    case .BASKET;
                        Draw_Item_Basket(it.position + camera_vector, 20.0);
                    case .CHEST;
                        Draw_Item_Chest(it.position + camera_vector, 20.0);
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
                        Draw_Item_Basket(xy(xpos + 20.0, WINDOW_HEIGHT - 65), 20.0);
                        for r, r_index: player.held.value.container.contents
                        {
                            y_pos := (WINDOW_HEIGHT - 80) - 20 * (r_index + 2);
                            line := tprint("%: %", resource_names[r_index], r);
                            DrawText(to_c_string(line), 20, xx y_pos, 20, BLACK);
                        }
                        xpos += 80.0;
                    case .CHEST;
                        Draw_Item_Chest(xy(xpos + 20.0, WINDOW_HEIGHT - 55), 20.0);
                        xpos += 80.0;
                }
            }
            // tool belt
            xpos = 90;
            DrawRectangleLines(xx xpos, WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw item slot
            if player.tool_belt.exists
            {
                DrawRectangleV(xy(xpos + 10, WINDOW_HEIGHT - 80 + 35), xy(40, 10), GREEN); //draw ui representation

                xpos = WINDOW_WIDTH/2 - 230;
                for i: 0..player.tool_belt.value.capacity - 1
                {
                    DrawRectangleLines(xx (xpos + i * 70), WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw inv boxes
                    if i < player.tool_belt.value.contents.count
                    {
                        item := player.tool_belt.value.contents[i];
                        Draw_Item(xy(xpos + i * 70 + 30, WINDOW_HEIGHT - 50), item); //draw inv
                    }
                }
            }
            // weapon belt
            xpos = 160;
            DrawRectangleLines(xx xpos, WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw item slot
            if player.weapon_belt.exists
            {
                DrawRectangleV(xy(xpos + 10, WINDOW_HEIGHT - 80 + 35), xy(40, 10), RED); //draw ui representation
                xpos = WINDOW_WIDTH/2 + 30;
                for i: 0..player.weapon_belt.value.capacity - 1
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

        array_add(*Game.resource_list, r);
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
        r.bldg_type = .TRADER;
        r.want = cast(Resource_ID) want;
        r.have = cast(Resource_ID) have;

        array_add(*Game.buildings, r);
    }

    // init shops
    basket_shop : Building;
    basket_shop.position = xy(-1100, -1100);
    basket_shop.size = 50;
    basket_shop.bldg_type = .SHOP;
    basket_shop.resource = .FIBER;
    basket_shop.amount = 10;
    basket_shop.item.id = .BASKET;
    basket_shop.item.container.capacity = 30;
    array_add(*Game.buildings, basket_shop);
    chest_shop : Building;
    chest_shop.position = xy(-900, -1100);
    chest_shop.size = 50;
    chest_shop.bldg_type = .SHOP;
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
        array_add(*Game.items_on_ground, toolbelt);

        lumberaxe: Entity;
        lumberaxe.position = Game.player.position + .{100, -100};
        lumberaxe.size = .{10, 10};
        lumberaxe.id = .LUMBER_AXE;
        array_add(*Game.items_on_ground, lumberaxe);
        
        weaponbelt: Entity;
        weaponbelt.position = Game.player.position + .{0, -200};
        weaponbelt.size = .{60, 15};
        weaponbelt.id = .WEAPON_BELT;
        weaponbelt.equipment.capacity = 3;
        array_resize(*weaponbelt.equipment.contents, 3);
        array_add(*Game.items_on_ground, weaponbelt);
    }
}

// @TODO: handle negatives
map_get_coords :: () -> Vector2 
{
    coord := Game.player.position;
    // find offset from grid
    // @TODO: magic number
    coord.x -= xx coord.x % 100;
    coord.y -= xx coord.y % 100;
    // get coordinates of top-left corner of grid cell
    coord.x = floor(coord.x);
    coord.y = floor(coord.y);
    // normalize grid coords
    return coord / 100;
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

get_closest_bldg_to_player :: (type: Building.Bldg_Type) -> *Building, float
{
    using Game;
    closest_index := 0;
    min_dist := length(buildings[0].position - player.position);
    for buildings if it.bldg_type == type
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

get_nearest_npc_to_player :: () -> *Npc, float
{
    using Game;
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
    return *npcs[closest_index], min_dist;
}

get_closest_item_in_range :: (range: float) -> Maybe(*Entity), int
{
    using Game;
    result: Maybe(*Entity);
    
    if items_on_ground.count <= 0 return result, -1;

    min_dist :=  length(player.position - items_on_ground[0].position);
    closest_index := 0;
    for items_on_ground
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
        result.value = *items_on_ground[closest_index];
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

    for *items_on_ground if it.id == .BASKET || it.id == .CHEST
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

Drop_Held_Item :: ()
{
    using Game;
    player.held.value.position = player.position + player.forward;
    array_add(*items_on_ground, player.held.value);
    player.held.exists = false;
}

Try_Pickup_Nearest_Item :: ()
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
                player.tool_belt = e;
                was_picked_up = true;
            case .WEAPON_BELT;
                e: Maybe(Equipment);
                e.exists = true;
                e.value = closest_item.value.equipment;
                player.weapon_belt = e;
                was_picked_up = true;
            case .LUMBER_AXE;
                if player.tool_belt.exists
                {
                    toolbelt := *player.tool_belt.value;
                    toolbelt_contents := player.tool_belt.value.contents;
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
            array_unordered_remove_by_index(*items_on_ground, index);
        }
    }
}