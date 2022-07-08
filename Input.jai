handle_input :: inline () {
    mouse_position := GetMousePosition();

    // movement
    new_velocity: Vector2;
    if IsKeyDown(xx KeyboardKey.W) 
    {
        new_velocity.y = -1.0;
    }
    if IsKeyDown(xx KeyboardKey.A) 
    {
        new_velocity.x = -1.0;
    }
    if IsKeyDown(xx KeyboardKey.S) 
    {
        new_velocity.y = 1.0;
    }
    if IsKeyDown(xx KeyboardKey.D) 
    {
        new_velocity.x = 1.0;
    }
    Game.player.velocity = unit_vector(new_velocity) * Game.player.speed;

    // harvesting
    if IsKeyPressed(xx KeyboardKey.SPACE)
    {
        Game.player.try_harvest = true;
    }
    else
    {
       Game.player.try_harvest = false; 
    }

    // trading
    if IsKeyPressed(xx KeyboardKey.T)
    {
        Game.player.try_trade = true;
    }
    else
    {
       Game.player.try_trade = false; 
    }

    // debug
    if IsKeyPressed(xx KeyboardKey.BACKSLASH)
    {
        Game.debug = !Game.debug;
    }
}