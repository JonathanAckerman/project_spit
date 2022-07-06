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

    mine_nearest_resource :: ()
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
            array_unordered_remove_by_index(*resource_list, closest_index);
    }
    if player.try_harvest then mine_nearest_resource();

    // draw
    {
        BeginDrawing();
        ClearBackground(LIGHTGRAY);
        
        // map
        {
            for i: 0..15
            {
                for j: 0..9
                {
                    ss_rect := xy(i * 100.0, j * 100.0) + camera_vector;
                    DrawRectangleLines(xx ss_rect.x, xx ss_rect.y, 100, 100, BLACK);
                }
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
                        DrawCircle(xx ss_resource.x, xx ss_resource.y, 10, BLUE);
                    case .IRON;
                        DrawCircle(xx ss_resource.x, xx ss_resource.y, 20, RED);
                    case .COPPER;
                        DrawCircle(xx ss_resource.x, xx ss_resource.y, 20, GREEN);
                }
            }
        }

        // player
        ss_player := player.position + camera_vector;
        DrawCircle(xx ss_player.x, xx ss_player.y, xx player.radius, player.color);
        front := ss_player + player.forward * cast(float) player.radius;
        DrawLineEx(xx ss_player, xx front, 2.0, WHITE);

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
}

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

        r : Resource;
        r.position = xy(x, y);
        r.id = cast(Resource_ID) id;

        array_add(*Game.resource_list, r);
    }
}