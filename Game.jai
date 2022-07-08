Game: struct 
{
    resetting: bool;
    paused: bool;

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

        inventory : [] int;
    }

    camera: struct
    {
        position: Vector2;
    }

    resource_list: [..] Resource;
    traders: [..] Trader;
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
            for traders
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
                player.inventory[resource.id] += resource.quantity;
                array_unordered_remove_by_index(*resource_list, closest_index);
            }
        }
        if player.try_harvest then harvest_nearest_resource();

        trade_with_nearest_trader :: ()
        {
            using Game;
            closest_index := 0;
            min_dist := length(traders[0].center - player.position);
            for traders
            {
                dist := length(it.center - player.position);
                if dist < min_dist
                {
                    min_dist = dist;
                    closest_index = it_index;
                } 
            }

            trader_range := compute_trader_range(traders[closest_index]);
            if min_dist < trader_range
            {
                trader_wants := traders[closest_index].want; 
                trader_has := traders[closest_index].have; 
                if player.inventory[trader_wants] > 0
                {
                    player.inventory[trader_wants] -= 1;
                    player.inventory[trader_has] += 1;
                }
            }
        }
        if player.try_trade then trade_with_nearest_trader();
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

        // traders
        {
            for traders
            {
                Draw_Trader(it, camera_vector);
            }
        }

        // player
        ss_player := player.position + camera_vector;
        DrawCircle(xx ss_player.x, xx ss_player.y, xx player.radius, player.color);
        front := ss_player + player.forward * cast(float) player.radius;
        DrawLineEx(xx ss_player, xx front, 2.0, WHITE);

        // ui
        {
            resource_names := enum_names(Resource_ID);
            for enum_values_as_s64(Resource_ID)
            {
                y_pos := 20 + 20 * (it_index + 1);
                DrawText(to_c_string(tprint("%: %", resource_names[it_index], player.inventory[cast(int) it])), 20, xx y_pos, 20, BLACK);
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
    populate_resources();

    //init player inventory
    array_resize(*Game.player.inventory, enum_highest_value(Resource_ID) + 1);

    //init traders
    // @Note: I'm intentially making this inconsistent with populate_resources so I can compare style later
    num_traders := clamp(random_get(), 3, 5);
    for 1..num_traders
    {
        populate_traders();
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

populate_traders :: ()
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
    
    
    r : Trader;
    r.position = xy(x, y);
    r.want = cast(Resource_ID) want;
    r.have = cast(Resource_ID) have;
    r.size = xx size;
    r.center = r.position + xy(r.size/2.0, r.size/2.0); 

    array_add(*Game.traders, r);
}

populate_resources :: ()
{
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
}

compute_trader_range :: (t: Trader) -> float
{
    trader_half_width := t.size/2.0;
    trader_center_to_corner_length := sqrt(2 * (trader_half_width * trader_half_width));
    return trader_center_to_corner_length + Game.player.radius + 10.0;
}

Draw_Trader :: (t: Trader, camera_vector: Vector2)
{
    DrawRectangleV(t.position + camera_vector, xy(xx t.size, xx t.size), BLACK);
    ss_trader := t.center + camera_vector;
    trader_range := compute_trader_range(t);
    if length(Game.player.position - t.center) < trader_range
        DrawCircleLines(xx ss_trader.x, xx ss_trader.y, trader_range, BLACK);

    want_color := get_resource_color(t.want);
    have_color := get_resource_color(t.have);
    DrawRectangleV((t.center - .{15.0, 0.0}) + camera_vector, .{15.0, 15.0}, want_color);
    DrawRectangleV((t.center + .{15.0, 0.0}) + camera_vector, .{15.0, 15.0}, have_color);
}