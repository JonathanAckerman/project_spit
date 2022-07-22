debug_player_position :: ()
{
    using Game;
    camera_vector := .{WINDOW_WIDTH/2, WINDOW_HEIGHT/2} - player.position;
    ss_player := player.position + camera_vector;
    DrawText(to_c_string(tprint("%", player.position)), xx (ss_player.x + 30.0), xx ss_player.y, 16, PINK);
}

debug_console :: (dt: float)
{
    using Debug;
    // draw background
    DrawRectangleV(.{10.0, WINDOW_HEIGHT - 250.0}, .{WINDOW_WIDTH - 20, 240}, .{0, 0, 0, 230});

    // draw cursor
    if c.blink_state
    {
        DrawRectangleV(c.curPos + .{0, 5}, c.size, WHITE);
    }

    c.blink_timer -= dt;
    if c.blink_timer <= 0.0
    {
        c.blink_state = !c.blink_state;
        c.blink_timer = 0.5;
    }

    // draw history
    if line_number < 5
    {
        historyPos := c.basePos;
        for history
        {
            DrawTextEx(font, to_c_string(it), historyPos, font_size, font_spacing, WHITE);
            historyPos += xy(0, font_size * 1.5);
        }
    }
    else
    {
        historyPos := c.basePos;
        for i: (line_number - 5)..(line_number - 1)
        {
            DrawTextEx(font, to_c_string(history[i]), historyPos, font_size, font_spacing, WHITE);
            historyPos += xy(0, font_size * 1.5);
        }
    }

    // draw current line
    if line
    {
        DrawTextEx(font, to_c_string(line), xy(c.basePos.x, c.curPos.y), font_size, font_spacing, WHITE);
    }
}

debug_is_command_valid :: (cmd: string)
{
    // for i: 0..c_style_strlen(to_c_string(cmd)) - 1
    // {
        
    // }

    // @TEMP: for now just match a string, later maybe have lexical parsing
    // @THOUGHT: maybe use a proc shared with game state for creating objects
    if cmd == "SPAWN BASKET"
    {
        basket: Entity;
        basket.id = .BASKET;
        basket.position = Game.player.position + Game.player.forward * 50;
        basket.container.capacity = 100;
        array_add(*Game.items_on_ground, basket); 
    }
    if cmd == "SPAWN CHEST"
    {
        basket: Entity;
        basket.id = .CHEST;
        basket.position = Game.player.position + Game.player.forward * 50;
        basket.container.capacity = 300;
        array_add(*Game.items_on_ground, basket); 
    }
    if cmd == "FILL POCKETS"
    {
        for *Game.player.pockets.contents
        {
            <<it = 10;
        }
    }
}

DebugCursor :: struct
{
    curPos : Vector2 = .{20.0, WINDOW_HEIGHT - 250.0};
    basePos : Vector2 = .{20.0, WINDOW_HEIGHT - 250.0};
    size: Vector2;
    blink_state := true;
    blink_timer := 0.5;
}