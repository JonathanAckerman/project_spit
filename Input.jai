Input: struct
{
    interact := false;
    craft    := false;
    trade    := false;
    pickup   := false;
    drop     := false;
    craftIndexDirection := 1;
    equipSlot := -1;

    backspaceTimer := 0.0;
    backspaceDelay := 0.1;
    backspaceSpeedBoostCounter := 5;
    backspaceSpeedBoostDelay := 5;
}

handle_input :: inline () 
{
    using Input;

    if !Debug.isActive
    {
        if !Debug.freeCamera 
        {
            // movement
            new_velocity: Vector2;
            new_forward: Vector2;
            if IsKeyDown(xx KeyboardKey.W) 
            {
                new_velocity.y = -1.0;
                new_forward += .{0, -1};
            }
            if IsKeyDown(xx KeyboardKey.A) 
            {
                new_velocity.x = -1.0;
                new_forward += .{-1, 0};
            }
            if IsKeyDown(xx KeyboardKey.S) 
            {
                new_velocity.y = 1.0;
                new_forward += .{0, 1};
            }
            if IsKeyDown(xx KeyboardKey.D) 
            {
                new_velocity.x = 1.0;
                new_forward += .{1, 0};
            }
            if length(new_forward) != 0 then Game.player.forward = unit_vector(new_forward);
            Game.player.velocity = unit_vector(new_velocity) * Game.player.speed;
        }
        else
        {
            camera_velocity: Vector2;
            if IsKeyDown(xx KeyboardKey.W) { camera_velocity += .{0, -1}; }
            if IsKeyDown(xx KeyboardKey.A) { camera_velocity += .{-1, 0}; }
            if IsKeyDown(xx KeyboardKey.S) { camera_velocity += .{0, 1}; }
            if IsKeyDown(xx KeyboardKey.D) { camera_velocity += .{1, 0}; }
            Game.camera.position += unit_vector(camera_velocity) * Game.player.speed;
        }

        // The Action Button
        if IsKeyPressed(xx KeyboardKey.SPACE)
        {
            interact = true;
        }
        else
        {
            interact = false;
        }

        // crafting
        if Game.player.canCraft
        {
            if IsKeyPressed(xx KeyboardKey.KEY_LEFT)
            {
                craftIndexDirection = -1;
                Game.craftIndex -= 1;
            }
            if IsKeyPressed(xx KeyboardKey.KEY_RIGHT)
            {
                craftIndexDirection = 1;
                Game.craftIndex += 1;
            }
        }
        else craftIndexDirection = 1;

        // trading
        if IsKeyPressed(xx KeyboardKey.T)
        {
            trade = true;
        }
        else
        {
            trade = false; 
        }

        // picking up / dropping items
        if IsKeyPressed(xx KeyboardKey.Y)
        {
            if Game.player.canCraft && Game.player.held.exists
            {
                craft = true;
            }
            else
            {
                holdables := get_holdables_in_range(Game.player.interactRange);
                if holdables.count > 0
                    pickup = true;
                else if Game.player.held.exists
                    drop = true;
            }
        }

        if IsKeyPressed(xx KeyboardKey.ONE) then equipSlot = 0;
        else if IsKeyPressed(xx KeyboardKey.TWO) then equipSlot = 1;
        else if IsKeyPressed(xx KeyboardKey.THREE) then equipSlot = 2;
        else if IsKeyPressed(xx KeyboardKey.FOUR) then equipSlot = 3;
        else if IsKeyPressed(xx KeyboardKey.FIVE) then equipSlot = 4;
        else if IsKeyPressed(xx KeyboardKey.SIX) then equipSlot = 5;
    }
    else // debug on
    {
        // write character
        key := GetCharPressed();
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
            // reset the historyindex to the most recent command
            Debug.historyIndex = Debug.history.count;
        }

        // delete character
        if IsKeyDown(xx KeyboardKey.BACKSPACE)
        {
            if backspaceTimer <= 0.0
            {
                if backspaceSpeedBoostCounter > 0
                {
                    backspaceSpeedBoostCounter -= 1;
                    backspaceTimer = backspaceDelay;
                }
                else backspaceTimer = backspaceDelay / 4.0;

                if Debug.line
                {
                    Debug.line.count -= 1;
                    Debug.c.charNumber -= 1;
                    Debug.c.curPos.x -= (Debug.fontSize/2) + Debug.fontSpacing;
                }
            }
            else backspaceTimer -= Game.dt;
        }
        else 
        {
            backspaceTimer = 0.0;
            backspaceSpeedBoostCounter = backspaceSpeedBoostDelay;
        }

        // cycle through history
        if IsKeyPressed(xx KeyboardKey.KEY_UP)
        {
            if Debug.history.count > 0
            {
                Debug.historyIndex -= 1;
                if Debug.historyIndex < 0 then Debug.historyIndex = Debug.history.count - 1;
                Debug.line = Debug.history[Debug.historyIndex];
                Debug.c.charNumber = c_style_strlen(to_c_string(Debug.line));
            }
        }
        if IsKeyPressed(xx KeyboardKey.KEY_DOWN)
        {
            if Debug.history.count > 0
            {
                Debug.historyIndex += 1;
                if Debug.historyIndex >= Debug.history.count then Debug.historyIndex = 0;
                Debug.line = Debug.history[Debug.historyIndex];
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
        if IsKeyDown(xx KeyboardKey.EQUAL)
        {
            Game.camera.zoom *= 1.02;   
        }
        // zoom out camera
        if IsKeyDown(xx KeyboardKey.MINUS)
        {
            Game.camera.zoom *= 0.98;   
        }
    }

    // debug
    if IsKeyPressed(xx KeyboardKey.BACKSLASH)
    {
        Debug.isActive = !Debug.isActive;
        Debug.c.size = xy(Debug.fontSize/2, Debug.fontSize * 0.66);
    }
}