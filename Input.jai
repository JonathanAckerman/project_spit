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
    {
        key_to_resource_index :: (key: KeyboardKey) -> int
        {
            if key >= 49 && key <= 53
                return xx key - 49;
            else return -1;
        }
        resource_index := key_to_resource_index(xx GetKeyPressed());
        if resource_index != -1 // if we got an input for shifting resources
        {
            container: Maybe(*Container);
            if !Game.player.held.exists
            {
                // look for nearest container
                closest := get_closest_item_in_range(50);
                if closest.exists && (closest.value.id == .BASKET || closest.value.id == .CHEST)
                {
                    container.value = *closest.value.container;
                    container.exists = true;
                }
            }
            else
            {
                if Game.player.held.value.id == .BASKET 
                {
                    container.value = *Game.player.held.value.container;
                    container.exists = true;
                }
            }

            if container.exists
            {
                if IsKeyDown(xx KeyboardKey.LEFT_SHIFT)
                {
                    // shift out of pockets
                    container_weight := 0;
                    for container.value.contents { container_weight += it; } 
                    if Game.player.pockets.contents[resource_index] > 0 && container_weight < container.value.capacity
                    {
                        container.value.contents[resource_index] += 1;    
                        Game.player.pockets.contents[resource_index] -= 1;
                    }
                }
                else
                {
                    // shift into pockets
                    if container.value.contents[resource_index] > 0 && Game.player.pockets.contents[resource_index] < 10
                    {
                        container.value.contents[resource_index] -= 1;
                        Game.player.pockets.contents[resource_index] += 1;
                    }
                }
            }
        }
    }


    // debug
    if IsKeyPressed(xx KeyboardKey.BACKSLASH)
    {
        Game.debug = !Game.debug;
    }
}