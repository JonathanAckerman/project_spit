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

        velocity: Vector2;

        inventory : [] int;
    }

    camera: struct
    {
        position: Vector2;
    }

    resource_list: [..] Resource;
}

game_loop :: inline () 
{
    dt := GetFrameTime();
    using Game;

    // input
    handle_input();

    // simulate
    camera.position = player.position;

    player.position = player.position + player.velocity;
    if length(player.velocity) != 0 then player.forward = unit_vector(player.velocity);
    player_coords := map_get_coords();

    player.velocity = .{};
    camera_vector : Vector2 = .{WINDOW_WIDTH/2, WINDOW_HEIGHT/2} - player.position;

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
                if #complete it.id ==
                {
                    case .WATER;
                        DrawCircle(xx ss_resource.x, xx ss_resource.y, xx it.quantity, BLUE);
                    case .IRON;
                        DrawCircle(xx ss_resource.x, xx ss_resource.y, xx it.quantity, RED);
                    case .COPPER;
                        DrawCircle(xx ss_resource.x, xx ss_resource.y, xx it.quantity, GREEN);
                }
            }
        }

        // player
        ss_player := player.position + camera_vector;
        DrawCircle(xx ss_player.x, xx ss_player.y, xx player.radius, player.color);
        front := ss_player + player.forward * cast(float) player.radius;
        DrawLineEx(xx ss_player, xx front, 2.0, WHITE);

        // ui
        {
            DrawText(to_c_string(tprint("Iron: %", player.inventory[cast(int) Resource_ID.IRON])), 20, 20, 20, BLACK);
            DrawText(to_c_string(tprint("Copper: %", player.inventory[cast(int) Resource_ID.COPPER])), 20, 40, 20, BLACK);
            DrawText(to_c_string(tprint("Water: %", player.inventory[cast(int) Resource_ID.WATER])), 20, 60, 20, BLACK);
        }

        EndDrawing();
    }

    reset_temporary_storage();
}

game_reset :: () 
{
    log("RESETTING GAME");
    Game = .{};
    populate_resources();
    seed := random_get();
    if seed % 2 == 0 then seed += 1;
    random_seed(seed);

    //init player inventory
    array_resize(*Game.player.inventory, enum_highest_value(Resource_ID) + 1);
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