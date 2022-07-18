Game: struct 
{
    resetting: bool;
    paused: bool;
    debug: bool;

    player: struct 
    {
        position: Vector2 = .{200, 200};
        forward: Vector2 = .{1, 0};
        radius: int = 20;
        color: Color = BLACK;
        speed: float = 6.0;
        try_harvest := false;
        try_trade := false;

        velocity: Vector2;

        pockets : [] int;
        held : Maybe(Item);
    }

    camera: struct
    {
        position: Vector2;
    }

    resource_list: [..] Resource;
    buildings: [..] Building;
    items_on_ground: [..] Item;
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
                if player.position.x + player.radius > it.position.x &&
                player.position.x - player.radius < it.position.x + it.size &&
                player.position.y + player.radius > it.position.y &&
                player.position.y - player.radius < it.position.y + it.size
                {
                    player.position += unit_vector(player.position - it.center) * length(player.velocity);
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
                    if player.held.value.count < player.held.value.capacity
                    {
                        // calculate the max that we can add to the basket
                        amount := ifx player.held.value.count + resource.quantity > player.held.value.capacity
                            then player.held.value.capacity - player.held.value.count
                            else resource.quantity;
                        player.held.value.count += amount;
                        player.held.value.contents[cast(int) resource.id] += amount;
                        array_unordered_remove_by_index(*resource_list, closest_index);
                        has_harvested = true;
                    }
                }

                // pockets can only hold 10 of each resource
                if !has_harvested && player.pockets[resource.id] < 10
                {
                    player.pockets[resource.id] += resource.quantity;
                    player.pockets[resource.id] = min(player.pockets[resource.id], 10);
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
                if player.pockets[nearest.want] > 0
                {
                    player.pockets[nearest.want] -= 1;
                    player.pockets[nearest.have] += 1;
                }
            }
        }
        if player.try_trade then trade_with_nearest_trader();

        buy_from_nearest_shop :: ()
        {
            using Game;
            nearest_shop, dist := get_closest_bldg_to_player(.SHOP);;
            // check shop range
            shop_range := compute_interact_range(nearest_shop);
            if dist < shop_range
            {
                total_resources := Get_Total_Resources_On_Person();
                if total_resources[nearest_shop.resource] >= nearest_shop.amount && !player.held.exists
                {
                    // pay the cost
                    player.pockets[nearest_shop.resource] -= nearest_shop.amount;
                    possible_deficit := player.pockets[nearest_shop.resource];
                    if possible_deficit < 0
                    {
                        player.pockets[nearest_shop.resource] = 0;
                        player.held.value.contents[nearest_shop.resource] -= possible_deficit;
                    }

                    // receive the item
                    if nearest_shop.item.id == 
                    {
                        case .BASKET;
                            item: Maybe(Item);
                            item.exists = true;
                            item.value.id = .BASKET;
                            item.value.capacity = 100;
                            array_resize(*item.value.contents, enum_highest_value(Resource_ID) + 1);
                            player.held = item;
                        case .CHEST;
                            item: Maybe(Item);
                            item.exists = true;
                            item.value.id = .CHEST;
                            item.value.capacity = 300;
                            array_resize(*item.value.contents, enum_highest_value(Resource_ID) + 1);
                            player.held = item;
                    }
                }
            }
        }
        if player.try_trade then buy_from_nearest_shop();
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
                DrawRectangleV(it.position + camera_vector, xy(xx it.size, xx it.size), BLACK);
                ss_bldg := it.center + camera_vector;

                if it.bldg_type == .TRADER
                {
                    want_color := get_resource_color(it.want);
                    have_color := get_resource_color(it.have);
                    DrawRectangleV((it.center - .{15.0, 0.0}) + camera_vector, .{15.0, 15.0}, want_color);
                    DrawRectangleV((it.center + .{15.0, 0.0}) + camera_vector, .{15.0, 15.0}, have_color);
                }
                if it.bldg_type == .SHOP
                {
                    if it.item.id == .BASKET
                        Draw_Item_Basket((it.center - xy(it.size/8.0, it.size/8.0)) + camera_vector, it.size/4.0);
                    if it.item.id == .CHEST
                        Draw_Item_Chest((it.center - xy(it.size/8.0, it.size/8.0)) + camera_vector, it.size/4.0);
                }
            }

            nearest, dist := get_closest_bldg_to_player();
            ss_bldg := nearest.center + camera_vector;
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
                }
            }
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
                line := tprint("%: %", resource_names[r_index], player.pockets[cast(int) r]);
                DrawText(to_c_string(line), 20, xx y_pos, 20, BLACK);
            }

            // held
            xpos := 20.0;
            DrawText(xx "Held Item:", 20, WINDOW_HEIGHT - 100, 20, BLACK);
            DrawRectangleLines(xx xpos, WINDOW_HEIGHT - 80, 60, 60, BLACK);
            if player.held.exists if player.held.value.id ==
            {
                case .BASKET;
                    Draw_Item_Basket(xy(xpos + 20.0, WINDOW_HEIGHT - 65), 20.0);
                    for r, r_index: player.held.value.contents
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

        // debug
        {
            if debug
            {
                debug_player_position();
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

    //init player pockets
    array_resize(*Game.player.pockets, enum_highest_value(Resource_ID) + 1);

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
        size := clamp(random_get(), 100, 300);
        
        r : Building;
        r.position = xy(x, y);
        r.size = xx size;
        r.center = r.position + xy(r.size/2.0, r.size/2.0); 
        r.bldg_type = .TRADER;
        r.want = cast(Resource_ID) want;
        r.have = cast(Resource_ID) have;

        array_add(*Game.buildings, r);
    }

    basket_shop : Building;
    basket_shop.position = xy(-1100, -1100);
    basket_shop.center = xy(-1075, -1075);
    basket_shop.size = 50;
    basket_shop.bldg_type = .SHOP;
    basket_shop.resource = .FIBER;
    basket_shop.amount = 10;
    basket_shop.item.id = .BASKET;
    basket_shop.item.capacity = 30;
    array_add(*Game.buildings, basket_shop);
    chest_shop : Building;
    chest_shop.position = xy(-900, -1100);
    chest_shop.center = xy(-875, -1075);
    chest_shop.size = 50;
    chest_shop.bldg_type = .SHOP;
    chest_shop.resource = .WOOD;
    chest_shop.amount = 10;
    chest_shop.item.id = .CHEST;
    chest_shop.item.capacity = 30;
    array_add(*Game.buildings, chest_shop);
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
    min_dist := length(buildings[0].center - player.position);
    for buildings
    {
        dist := length(it.center - player.position);
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
    min_dist := length(buildings[0].center - player.position);
    for buildings if it.bldg_type == type
    {
        dist := length(it.center - player.position);
        if dist < min_dist
        {
            min_dist = dist;
            closest_index = it_index;
        }
    }
    return *buildings[closest_index], min_dist;
}

get_closest_item_in_range :: (range: float) -> Maybe(Item), int
{
    using Game;
    result: Maybe(Item);
    
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
        result.value = items_on_ground[closest_index];
    }
    return result, closest_index;
}

Drop_Held_Item :: ()
{
    using Game;
    item: Item = player.held.value;
    item.position = player.position + player.forward;
    array_add(*items_on_ground, item);
    player.held.exists = false;
}

Try_Pickup_Nearest_Item :: ()
{
    using Game;
    closest_item, index := get_closest_item_in_range(50);
    if closest_item.exists
    {
        player.held = closest_item;
        last := items_on_ground[items_on_ground.count - 1];
        items_on_ground[index] = last;
        pop(*items_on_ground);
    }
}