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

    // drop item
    if IsKeyPressed(xx KeyboardKey.Y)
    {
        // @TODO: not a fan of how game logic is also in this file
        if Game.player.held.exists
            Drop_Held_Item();
        else    
            Try_Pickup_Nearest_Item();
    }

    // shifting resources around
    if IsKeyPressed(xx KeyboardKey.ONE)
    {
        if Game.player.held.exists 
        {
            if Game.player.held.value.id == .BASKET
            {
                if IsKeyDown(xx KeyboardKey.LEFT_SHIFT)
                {
                    Game.player.held.value.contents[0] += 1;    
                    Game.player.pockets[0] -= 1;
                }
                else
                {
                    Game.player.held.value.contents[0] -= 1;
                    Game.player.pockets[0] += 1;
                }
            }
        }
        else
        {
            
        }
    }


    // debug
    if IsKeyPressed(xx KeyboardKey.BACKSLASH)
    {
        Game.debug = !Game.debug;
    }
}