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
    if c.blinkState
    {
        DrawRectangleV(c.curPos + .{0, 5}, c.size, WHITE);
    }

    c.blinkTimer -= dt;
    if c.blinkTimer <= 0.0
    {
        c.blinkState = !c.blinkState;
        c.blinkTimer = 0.5;
    }

    // draw history
    if lineNumber < 5
    {
        historyPos := c.basePos;
        for history
        {
            DrawTextEx(font, to_c_string(it), historyPos, fontSize, fontSpacing, WHITE);
            historyPos += xy(0, fontSize * 1.5);
        }
    }
    else
    {
        historyPos := c.basePos;
        for i: (lineNumber - 5)..(lineNumber - 1)
        {
            DrawTextEx(font, to_c_string(history[i]), historyPos, fontSize, fontSpacing, WHITE);
            historyPos += xy(0, fontSize * 1.5);
        }
    }

    // draw current line
    if line
    {
        DrawTextEx(font, to_c_string(line), xy(c.basePos.x, c.curPos.y), fontSize, fontSpacing, WHITE);
    }
}

debug_is_command_valid :: (cmd: string)
{
    // @TEMP: for now just match a string, later maybe have lexical parsing
    // Containers
    if cmd == "SPAWN BASKET"
    {
        pos := Game.player.position + Game.player.forward * 50;
        container := NewContainer(.BASKET, pos);
        array_add(*Game.containersOnGround, container); 
    }
    if cmd == "SPAWN CHEST"
    {
        pos := Game.player.position + Game.player.forward * 50;
        container := NewContainer(.CHEST, pos);
        array_add(*Game.containersOnGround, container);
    }

    // Items
    if cmd == "SPAWN AXE"
    {
        pos := Game.player.position + Game.player.forward * 50;
        item := NewItem(.LUMBER_AXE, pos, Collider.{type = .CIRCLE, radius = 10});
        array_add(*Game.itemsOnGround, item);
    }

    // Equipment
    if cmd == "SPAWN TOOLBELT"
    {
        pos := Game.player.position + Game.player.forward * 50;
        equipment := NewEquipment(.TOOL_BELT, pos, Collider.{type = .RECT, rect = .{60, 15}});
        array_add(*Game.equipmentOnGround, equipment);
    }
    if cmd == "SPAWN WEAPONBELT"
    {
        pos := Game.player.position + Game.player.forward * 50;
        equipment := NewEquipment(.WEAPON_BELT, pos, Collider.{type = .RECT, rect = .{60, 15}});
        array_add(*Game.equipmentOnGround, equipment);
    }

    if cmd == "FILL POCKETS"
    {
        for *Game.player.pockets.contents
        {
            <<it = 10;
        }
    }
    if cmd == "TP"
    {
        Game.player.position = .{-1000, -1000};
    }
    if cmd == "GOTTAGOFAST"
    {
        Game.player.speed = 50;
    }
}

DebugCursor :: struct
{
    curPos : Vector2 = .{20.0, WINDOW_HEIGHT - 250.0};
    basePos : Vector2 = .{20.0, WINDOW_HEIGHT - 250.0};
    size: Vector2;
    blinkState := true;
    blinkTimer := 0.5;
}