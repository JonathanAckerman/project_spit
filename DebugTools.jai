Debug: struct
{
    isActive := false;
    c: DebugCursor;
    line: string;
    history: [..] string;
    historyIndex := -1;

    font: Font;
    fontSize := 28.0;
    fontSpacing := 1.0;

    listCommands := false;
    commandList: [] string = .[
        "SPAWN BASKET",
        "SPAWN CHEST",
        "SPAWN AXE",
        "SPAWN SAW",
        "SPAWN TOOLBELT",
        "SPAWN WEAPONBELT",
        "TP",
        "GOTTAGOFAST",
        "REPOP RESOURCES",
        "RESET",
        "DEBUG INFO 0",
        "DEBUG INFO 1"
    ];
    showEntityInfo := false;
}

debug_player_position :: ()
{
    using Game;
    camera_vector := WINDOW_CENTER - camera.position * camera.zoom;
    ss_player := player.position * camera.zoom + camera_vector;
    drawpos := ss_player + xy(30 * camera.zoom, 0);
    DrawText(to_c_string(tprint("pos: %", player.position)), xx drawpos.x, xx drawpos.y, 16, PINK);
    drawpos.y += 20.0 * camera.zoom;
    DrawText(to_c_string(tprint("ID:  %", player.id)), xx drawpos.x, xx drawpos.y, 16, PINK);
}

debug_entity_info :: (e: Entity)
{
    using Game;
    camera_vector := WINDOW_CENTER - camera.position * camera.zoom;
    ss_entity := e.position * camera.zoom + camera_vector;
    drawpos := ss_entity + xy(30 * camera.zoom, 0);
    DrawText(to_c_string(tprint("pos: %", e.position)), xx drawpos.x, xx drawpos.y, 16, PINK);
    drawpos.y += 20.0 * camera.zoom;
    DrawText(to_c_string(tprint("ID:  %", e.id)), xx drawpos.x, xx drawpos.y, 16, PINK);
    drawpos.y += 20.0 * camera.zoom;
    DrawText(to_c_string(tprint("Ent_Type:  %", e.tag)), xx drawpos.x, xx drawpos.y, 16, PINK);
}

debug_console :: (dt: float)
{
    using Debug;
    // draw background
    DrawRectangleV(.{10, WINDOW_HEIGHT - 250}, .{WINDOW_WIDTH - 20, 240}, .{0, 0, 0, 230});

    // update cursor
    xpos := c.basePos.x + ((Debug.fontSize/2) + Debug.fontSpacing) * c.charNumber;
    ypos := c.basePos.y + (Debug.fontSize * 1.5) * c.lineNumber;
    ypos = clamp(ypos, c.basePos.y, WINDOW_HEIGHT - 40);
    c.curPos = xy(xpos, ypos);

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
    if c.lineNumber < 5
    {
        historyPos := c.basePos;
        for history
        {
            DrawTextEx(font, to_c_string(it), historyPos, fontSize, fontSpacing, GRAY);
            historyPos += xy(0, fontSize * 1.5);
        }
    }
    else
    {
        historyPos := c.basePos;
        for i: (c.lineNumber - 5)..(c.lineNumber - 1)
        {
            DrawTextEx(font, to_c_string(history[i]), historyPos, fontSize, fontSpacing, GRAY);
            historyPos += xy(0, fontSize * 1.5);
        }
    }

    // draw current line
    if line
    {
        DrawTextEx(font, to_c_string(line), xy(c.basePos.x, c.curPos.y), fontSize, fontSpacing, WHITE);
    }

    if listCommands
    {
        base_x := WINDOW_WIDTH / 2.0;
        base_y := c.basePos.y + 5.0;
        for Debug.commandList
        {
            x := base_x + (230 * (it_index / 6));
            y := base_y + ((fontSize * 1.5) * (it_index % 6));
            DrawTextEx(font, to_c_string(it), xy(x, y), fontSize - 6, fontSpacing, GREEN);
        }
    }
}

debug_is_command_valid :: (cmd: string)
{
    // @TEMP: for now just match a string, later maybe have lexical parsing
    // Containers
    if cmd == "SPAWN BASKET"
    {
        pos := Game.player.position + Game.player.person.forward * 50;
        collider := Collider.{type = .RECT, rect = .{20, 30}};
        container := NewContainer(.BASKET, collider, pos);
        array_add(*Game.containersOnGround, container); 
    }

    if cmd == "SPAWN CHEST"
    {
        pos := Game.player.position + Game.player.person.forward * 50;
        collider := Collider.{type = .RECT, rect = .{20, 30}};
        container := NewContainer(.CHEST, collider, pos);
        array_add(*Game.containersOnGround, container);
    }

    // Items
    if cmd == "SPAWN AXE"
    {
        pos := Game.player.position + Game.player.person.forward * 50;
        collider := Collider.{type = .CIRCLE, radius = 10};
        item := NewItem(.LUMBER_AXE, collider, pos);
        array_add(*Game.itemsOnGround, item);
    }
    if cmd == "SPAWN SAW"
    {
        pos := Game.player.position + Game.player.person.forward * 50;
        collider := Collider.{type = .CIRCLE, radius = 10};
        item := NewItem(.HEWING_SAW, collider, pos);
        array_add(*Game.itemsOnGround, item);
    }

    // Equipment
    if cmd == "SPAWN TOOLBELT"
    {
        pos := Game.player.position + Game.player.person.forward * 50;
        collider := Collider.{type = .RECT, rect = .{60, 15}};
        equipment := NewEquipment(.TOOL_BELT, collider, pos);
        array_add(*Game.equipmentOnGround, equipment);
    }
    if cmd == "SPAWN WEAPONBELT"
    {
        pos := Game.player.position + Game.player.person.forward * 50;
        collider := Collider.{type = .RECT, rect = .{60, 15}};
        equipment := NewEquipment(.WEAPON_BELT, collider, pos);
        array_add(*Game.equipmentOnGround, equipment);
    }

    if cmd == "TP"
    {
        Game.player.position = .{-1000, -1000};
    }
    if cmd == "GOTTAGOFAST"
    {
        Game.player.person.speed = 50;
    }
    if cmd == "REPOP RESOURCES"
    {
        array_reset(*Game.resourceList);
        populate_resources();
    }
    if cmd == "RESET"
    {
        game_reset();
    }
    if cmd == "DEBUG INFO 0"
    {
        Debug.showEntityInfo = false;
    }
    if cmd == "DEBUG INFO 1"
    {
        Debug.showEntityInfo = true;
    }
}

DebugCursor :: struct
{
    curPos : Vector2 = .{20.0, WINDOW_HEIGHT - 250.0};
    basePos : Vector2 = .{20.0, WINDOW_HEIGHT - 250.0};
    charNumber := 0;
    lineNumber := 0;
    size: Vector2;
    blinkState := true;
    blinkTimer := 0.5;
}