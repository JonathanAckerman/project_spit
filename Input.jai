handle_input :: inline () 
{
    if !Debug.isActive
    {
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
        Game.player.person.velocity = unit_vector(new_velocity) * Game.player.person.speed;

        // harvesting
        if IsKeyPressed(xx KeyboardKey.SPACE)
        {
            Game.tryHarvest = true;
        }
        else
        {
            Game.tryHarvest = false; 
        }

        // trading
        if IsKeyPressed(xx KeyboardKey.T)
        {
            Game.tryTrade = true;
        }
        else
        {
            Game.tryTrade = false; 
        }

        // drop item
        if IsKeyPressed(xx KeyboardKey.Y)
        {
            // @TODO: not a fan of how game logic is also in this file
            if Game.player.person.held.exists
                drop_held();
            else
                try_pickup();
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
                if !Game.player.person.held.exists
                {
                    // look for nearest container
                    nearest := get_nearest_holdable_in_range(50);
                    if nearest.exists && nearest.value.tag == .CONTAINER
                    {
                        container.value = *nearest.value.container;
                        container.exists = true;
                    }
                }
                else
                {
                    if Game.player.person.held.value.tag == .CONTAINER && Game.player.person.held.value.container.type == .BASKET
                    {
                        container.value = *Game.player.person.held.value.container;
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
                        if Game.player.person.pockets.contents[resource_index] > 0 && container_weight < container.value.capacity
                        {
                            container.value.contents[resource_index] += 1;    
                            Game.player.person.pockets.contents[resource_index] -= 1;
                        }
                    }
                    else
                    {
                        // shift into pockets
                        if container.value.contents[resource_index] > 0 && Game.player.person.pockets.contents[resource_index] < 10
                        {
                            container.value.contents[resource_index] -= 1;
                            Game.player.person.pockets.contents[resource_index] += 1;
                        }
                    }
                }
            }
        }
    }
    else // debug on
    {
        // write character
        key := GetKeyPressed();
        if key > 0 && key < 255 // sizeof u8
           && key != 92 // '\'
           && key != 45 // '-'
           && key != 61 // '='
        {

            if !Debug.line then Debug.line = sprint("%", to_string(*(cast(u8) key), 1));
            else Debug.line = sprint("%0%", Debug.line, to_string(*(cast(u8) key), 1));
            Debug.c.charNumber += 1;
        }

        // submit command
        if IsKeyPressed(xx KeyboardKey.ENTER)
        {
            // CR
            Debug.c.charNumber = 0;
            // LF
            Debug.c.lineNumber += 1;
            debug_is_command_valid(Debug.line);
            // add current line to history
            array_add(*Debug.history, Debug.line);
            // reset current line
            Debug.line = "";
        }

        // delete character
        if IsKeyPressed(xx KeyboardKey.BACKSPACE)
        {
            if Debug.line
            {
                Debug.line.count -= 1;
                Debug.c.charNumber -= 1;
                Debug.c.curPos.x -= (Debug.fontSize/2) + Debug.fontSpacing;
            }
        }

        // cycle through history
        if IsKeyPressed(xx KeyboardKey.KEY_UP)
        {
            if Debug.history.count > 0
            {
                Debug.historyIndex += 1;
                if Debug.historyIndex == Debug.history.count then Debug.historyIndex = 0;
                Debug.line = Debug.history[(Debug.history.count - 1) - Debug.historyIndex];
                Debug.c.charNumber = c_style_strlen(to_c_string(Debug.line));
            }
        }

        // clear line
        if IsKeyPressed(xx KeyboardKey.DELETE)
        {
            Debug.line = "";
            Debug.c.charNumber = 0;
        }

        // list commands
        if IsKeyPressed(xx KeyboardKey.KEY_RIGHT)
        {
            Debug.listCommands = true;
        }
        // hide commands
        if IsKeyPressed(xx KeyboardKey.KEY_LEFT)
        {
            Debug.listCommands = false;
        }

        // zoom in camera
        if IsKeyPressed(xx KeyboardKey.EQUAL)
        {
            Game.camera.zoom += 0.2;   
        }
        // zoom out camera
        if IsKeyPressed(xx KeyboardKey.MINUS)
        {
            Game.camera.zoom -= 0.2;   
        }
    }

    // debug
    if IsKeyPressed(xx KeyboardKey.BACKSLASH)
    {
        Debug.isActive = !Debug.isActive;
        if !Debug.showEntityInfo then Debug.showEntityInfo = true;
        Debug.c.size = xy(Debug.fontSize/2, Debug.fontSize * 0.66);
    }
}