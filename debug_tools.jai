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
    DrawRectangleV(xy(c.basePos.x, c.basePos.y), .{WINDOW_WIDTH - 20, 240}, .{0, 0, 0, 230});

    // draw cursor
    if c.blink_state
    {
        DrawRectangleV(c.curPos, c.size, WHITE);
    }

    c.blink_timer -= dt;
    if c.blink_timer <= 0.0
    {
        c.blink_state = !c.blink_state;
        c.blink_timer = 0.5;
    }

    // if history.count > 0
    // {
    //     //print history
    // }

    // draw current line
    if line
    {
        DrawTextEx(font, to_c_string(line), c.basePos, font_size, font_spacing, WHITE);
    }
}

DebugCursor :: struct
{
    curPos : Vector2 = .{10.0, WINDOW_HEIGHT - 250.0};
    basePos : Vector2 = .{10.0, WINDOW_HEIGHT - 250.0};
    size: Vector2;
    blink_state := true;
    blink_timer := 0.5;
}