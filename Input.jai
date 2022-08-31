Input: struct
{
    harvest := false;
    trade := false;
    pickup := false;
    drop := false;
    equipSlot := -1;
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

        // harvesting
        if IsKeyPressed(xx KeyboardKey.SPACE)
        {
            harvest = true;
        }
        else
        {
            harvest = false; 
        }

        // trading
        if IsKeyPressed(xx KeyboardKey.T)
        {
            trade = true;
        }
        else
        {
            trade = false; 
        }

        if IsKeyPressed(xx KeyboardKey.Y)
        {
            holdables := get_holdables_in_range(Game.player.interactRange);
            if holdables.count > 0
                pickup = true;
            else if Game.player.held.exists
                drop = true;
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