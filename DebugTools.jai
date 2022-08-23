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
        "SPAWN BUCKET",
        "SPAWN AXE",
        "SPAWN PICK",
        "SPAWN SAW",
        "SPAWN HAMMER",
        "SPAWN SWORD",
        "SPAWN WHIP",
        "SPAWN TOOLBELT",
        "SPAWN WEAPONBELT",
        "TP",
        "GOTTAGOFAST",
        "DT",
        "SPEED",
        "PRINT PLAYER",
        "REPOP RESOURCES",
        "RESET",
        "DEBUG INFO 0",
        "DEBUG INFO 1"
    ];
    showEntityInfo := false;
    dtMultiplier := 1.0;

    debugRectangles : [..] DebugRectangle;
    debugCircles :    [..] DebugCircle;
    debugLines :      [..] DebugLine;
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

DebugRectangle :: struct
{
    pos: Vector2;
    size: Vector2;
    color: Color;
}
make_debug_rectangle :: (pos: Vector2, size: Vector2, c: Color) -> DebugRectangle { return make_debug_rectangle(pos.x, pos.y, size.x, size.y, c); }
make_debug_rectangle :: (x: float, y: float, w: float, h: float, c: Color) -> DebugRectangle
{
    dbr: DebugRectangle;
    dbr.pos.x = x;
    dbr.pos.y = y;
    dbr.size.x = w;
    dbr.size.y = h;
    dbr.color = c;
    return dbr;
}
defer_draw_rect :: (dbr: DebugRectangle) { array_add(*Debug.debugRectangles, dbr); }


DebugCircle :: struct
{
    pos: Vector2;
    radius: float;
    color: Color;
}
make_debug_circle :: (pos: Vector2, r: float, c: Color) -> DebugCircle { return make_debug_circle(pos.x, pos.y, r, c); }
make_debug_circle :: (x: float, y: float, r: float, c: Color) -> DebugCircle
{
    dbc: DebugCircle;
    dbc.pos.x = x;
    dbc.pos.y = y;
    dbc.radius = r;
    dbc.color = c;
    return dbc;
}
defer_draw_circle :: (dbc: DebugCircle) { array_add(*Debug.debugCircles, dbc); }

DebugLine :: struct
{
    x0: float;
    y0: float;
    x1: float;
    y1: float;
    color: Color;
}
make_debug_line :: (start: Vector2, stop: Vector2, c: Color) -> DebugLine { return make_debug_line(start.x, start.y, stop.x, stop.y, c); }
make_debug_line :: (x0: float, y0: float, x1: float, y1: float, c: Color) -> DebugLine
{
    dbl: DebugLine;
    dbl.x0 = x0;
    dbl.y0 = y0;
    dbl.x1 = x1;
    dbl.y1 = y1;
    dbl.color = c;
    return dbl;
}
defer_draw_line :: (dbl: DebugLine) { array_add(*Debug.debugLines, dbl); }

debug_deferred_draw_rectancles :: ()
{
    for Debug.debugRectangles 
    {
        DrawRectangleLines(xx it.pos.x, xx it.pos.y, xx it.size.x, xx it.size.y, it.color);
        remove it;
    }

}

debug_deferred_draw_circles :: ()
{
    for Debug.debugCircles 
    {
        DrawCircleLines(xx it.pos.x, xx it.pos.y, xx it.radius, it.color);
        remove it;
    }

}

debug_deferred_draw_lines :: ()
{
    for Debug.debugLines
    {
        DrawLine(xx it.x0, xx it.y0, xx it.x1, xx it.y1, it.color);
        remove it;
    }
}

debug_player_info :: ()
{
    using Game;
    ss_player := to_screen_space(player.position.value.xy);
    drawpos := ss_player + xy(30 * camera.zoom, 0);
    fx := formatFloat(player.position.value.x, trailing_width=1, zero_removal=.YES);
    fy := formatFloat(player.position.value.y, trailing_width=1, zero_removal=.YES);
    fz := formatFloat(player.position.value.z, trailing_width=1, zero_removal=.YES);
    DrawText(to_c_string(tprint("pos: %, %, %", fx, fy, fz)), xx drawpos.x, xx drawpos.y, 16, PINK);
    drawpos.y += 20.0 * camera.zoom;
    DrawText(to_c_string(tprint("ID:  %", player.id)), xx drawpos.x, xx drawpos.y, 16, PINK);

    DrawCircleLines(xx ss_player.x, xx ss_player.y, player.interactRange * camera.zoom, PINK);

    layer_size_modifier := 1.0 - (xx player.position.value.z - (camera.position.z + 1)) * 0.1;
    if player.textureInfo.texture != null
    {
        modified_size := player.textureInfo.size * camera.zoom;
        texture_drawpos := ss_player - modified_size/2;
        DrawRectangleLines(xx texture_drawpos.x, xx texture_drawpos.y, xx modified_size.x, xx modified_size.y, PINK);
    }

    if player.collider.type == {
        case .CIRCLE;
            DrawCircleLines(xx ss_player.x, xx ss_player.y, player.collider.radius * camera.zoom, YELLOW);
        case .RECT;
            base_size := xy(player.collider.rect.x, player.collider.rect.y) * 0.5;
            modified_size := base_size * camera.zoom;
            collider_drawpos := ss_player - modified_size/2;
            DrawRectangleLines(xx collider_drawpos.x, xx collider_drawpos.y, xx modified_size.x, xx modified_size.y, YELLOW);
    }
}

debug_entity_info :: (e: Entity)
{
    using Game;
    ss_entity := to_screen_space(e.position.value.xy);
    drawpos := ss_entity + xy(30 * camera.zoom, 0);
    fx := formatFloat(e.position.value.x, trailing_width=1, zero_removal=.YES);
    fy := formatFloat(e.position.value.y, trailing_width=1, zero_removal=.YES);
    fz := formatFloat(e.position.value.z, trailing_width=1, zero_removal=.YES);
    DrawText(to_c_string(tprint("pos: %, %, %", fx, fy, fz)), xx drawpos.x, xx drawpos.y, 16, PINK);
    drawpos.y += 20.0 * camera.zoom;
    DrawText(to_c_string(tprint("ID:  %", e.id)), xx drawpos.x, xx drawpos.y, 16, PINK);
    drawpos.y += 20.0 * camera.zoom;

    layer_size_modifier := 1.0 - (e.position.value.z - (camera.position.z + 1)) * 0.1;
    if e.textureInfo.texture != null
    {
        modified_size := e.textureInfo.size * camera.zoom;
        texture_drawpos := ss_entity - modified_size/2;
        DrawRectangleLines(xx texture_drawpos.x, xx texture_drawpos.y, xx modified_size.x, xx modified_size.y, PINK);
    }

    if e.collider.type == {
        case .CIRCLE;
            DrawCircleLines(xx ss_entity.x, xx ss_entity.y, e.collider.radius * camera.zoom, YELLOW);
        case .RECT;
            base_size := xy(e.collider.rect.x, e.collider.rect.y) * 0.5;
            modified_size := base_size * camera.zoom;
            collider_drawpos := ss_entity - modified_size/2;
            DrawRectangleLines(xx collider_drawpos.x, xx collider_drawpos.y, xx modified_size.x, xx modified_size.y, YELLOW);
    }
}

debug_grid_info :: ()
{
    using Game;
    for grid.loadedChunks
    {
        for it.cells
        {
            if it.z == 1 break;

            punch := get_grid_punch(it.x, it.y);
            for punch if it.type != .AIR
            {
                drawpos := to_screen_space(grid_to_world(it).xy, .{4, 4});
                str := tprint("%, %, %", it.x, it.y, it.z);
                DrawText(to_c_string(str), xx drawpos.x, xx drawpos.y, 14, PINK);
                break;
            }
        }
    }

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
    cmd_array := split(cmd, " ");
    if cmd_array.count > 0
    {
        if begins_with(cmd, "SPAWN")
        {
            pos := Game.player.position.value + Game.player.person.forward * 50;
            collider: *Collider;

            // Containers
            if cmd_array[1] == "BASKET" || cmd_array[1] == "CHEST" || cmd_array[1] == "BUCKET"
            {
                collider = NewCollider(.{20, 30});
                container := NewContainer(container_type_from_string(cmd_array[1]).value, collider, pos);
                array_add(*Game.containers, container);
            }

            // Items
            if cmd_array[1] == "AXE" || cmd_array[1] == "SAW" || cmd_array[1] == "HAMMER" || cmd_array[1] == "SWORD" || cmd_array[1] == "WHIP" || cmd_array[1] == "PICK"
            {
                if cmd_array[1] == "AXE" then cmd_array[1] = "LUMBER_AXE";
                if cmd_array[1] == "PICK" then cmd_array[1] = "PICK_AXE";
                if cmd_array[1] == "SAW" then cmd_array[1] = "HEWING_SAW";
                if cmd_array[1] == "HAMMER" then cmd_array[1] = "CARPENTERS_HAMMER";
                
                collider = NewCollider(10);
                item := NewItem(item_type_from_string(cmd_array[1]).value, collider, pos);
                array_add(*Game.items, item);
            }

            // Equipment
            if cmd_array[1] == "TOOLBELT" || cmd_array[1] == "WEAPONBELT"
            {
                if cmd_array[1] == "TOOLBELT" then cmd_array[1] = "TOOL_BELT";
                if cmd_array[1] == "WEAPONBELT" then cmd_array[1] = "WEAPON_BELT";

                collider = NewCollider(.{60, 15});
                equipment := NewEquipment(equipment_type_from_string(cmd_array[1]).value, collider, pos);
                array_add(*Game.equipment, equipment);
            }
        }

        if begins_with(cmd, "SPEED")
        {
            Game.player.speed = string_to_float(cmd_array[1]);
        }

        if begins_with(cmd, "PRINT")
        {
            if cmd_array[1] == "PLAYER" then print("%\n", Game.player);
        }

        if begins_with(cmd, "TP")
        {
            for cmd_array
            {
                if it_index == 0 continue; // skip "TP" string
                Game.player.position.value.component[it_index - 1] = string_to_float(it);
            }
        }

        if begins_with(cmd, "DT")
        {
            for cmd_array
            {
                if it_index == 0 continue;
                Debug.dtMultiplier = string_to_float(it);
            }
        }
    }


    if cmd == "GOTTAGOFAST"
    {
        Game.player.person.speed = 50;
    }
    if cmd == "REPOP RESOURCES"
    {
        array_reset(*Game.resources);
        populate_resources();
    }
    if cmd == "RESET"
    {
        game_reset();
    }
    if cmd == "DEBUG INFO 0" || cmd == "DB0"
    {
        Debug.showEntityInfo = false;
    }
    if cmd == "DEBUG INFO 1" || cmd == "DB1"
    {
        Debug.showEntityInfo = true;
    }
}

item_type_from_string :: (s: string) -> Maybe(Item_Type)
{
    for enum_names(Item_Type)
    {
        if s == it
        {
            m := NewMaybe(cast(Item_Type) enum_values_as_s64(Item_Type)[it_index]);
            return m;
        }
    }
    return Nothing(Item_Type);
}

container_type_from_string :: (s: string) -> Maybe(Container_Type)
{
    for enum_names(Container_Type)
    {
        if s == it
        {
            m := NewMaybe(cast(Container_Type) enum_values_as_s64(Container_Type)[it_index]);
            return m;
        }
    }
    return Nothing(Container_Type);
}

equipment_type_from_string :: (s: string) -> Maybe(Equipment_Type)
{
    for enum_names(Equipment_Type)
    {
        if s == it
        {
            m := NewMaybe(cast(Equipment_Type) enum_values_as_s64(Equipment_Type)[it_index]);
            return m;
        }
    }
    return Nothing(Equipment_Type);
}