Debug: struct
{
    isActive := false;
    c: DebugCursor;
    line: string;
    history: [..] string;
    cmdHistory: [..] string;
    cmdHistoryIndex := 0;

    font: Font;
    fontSize := 28.0;
    fontSpacing := 1.0;

    listCommands := false;
    commandList: [] string = .[
        "spawn [ENTITY]",
        "tp [X] [Y]",
        "dt",
        "speed [N]",
        "faster / slower / normal",
        "zoom [N]",
        "print player",
        "print [CELL]",
        "repop",
        "reset",
        "debug info (db) [0/1]",
        "freecam (fc) [0/1]"
    ];
    commandListPage := 0;

    showEntityInfo := false;
    freeCamera     := false;
    dtMultiplier   := 1.0;

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
    if !player.position.exists return;

    ss_player := to_screen_space(player.position.value);
    drawpos := ss_player + xy(30 * camera.zoom, 0);
    fx := formatFloat(player.position.value.x, trailing_width=1, zero_removal=.YES);
    fy := formatFloat(player.position.value.y, trailing_width=1, zero_removal=.YES);
    DrawText(to_c_string(tprint("pos: %, %", fx, fy)), xx drawpos.x, xx drawpos.y, 16, PINK);
    drawpos.y += 20.0 * camera.zoom;
    DrawText(to_c_string(tprint("ID:  %", player.id)), xx drawpos.x, xx drawpos.y, 16, PINK);

    DrawCircleLines(xx ss_player.x, xx ss_player.y, player.interactRange * camera.zoom, PINK);

    frame := Current_Frame(player.animation);
    modified_size := frame.size * camera.zoom;
    texture_drawpos := ss_player - modified_size/2;
    DrawRectangleLines(xx texture_drawpos.x, xx texture_drawpos.y, xx modified_size.x, xx modified_size.y, PINK);

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
    if !e.position.exists return;

    ss_entity := to_screen_space(e.position.value);
    drawpos := ss_entity + xy(30 * camera.zoom, 0);
    fx := formatFloat(e.position.value.x, trailing_width=1, zero_removal=.YES);
    fy := formatFloat(e.position.value.y, trailing_width=1, zero_removal=.YES);
    DrawText(to_c_string(tprint("pos: %, %", fx, fy)), xx drawpos.x, xx drawpos.y, 16, PINK);
    drawpos.y += 20.0 * camera.zoom;
    DrawText(to_c_string(tprint("ID:  %", e.id)), xx drawpos.x, xx drawpos.y, 16, PINK);
    drawpos.y += 20.0 * camera.zoom;

    frame := Current_Frame(e.animation);
    modified_size := frame.size * camera.zoom;
    texture_drawpos := ss_entity - modified_size/2;
    DrawRectangleLines(xx texture_drawpos.x, xx texture_drawpos.y, xx modified_size.x, xx modified_size.y, PINK);

    if e.collider.type == {
        case .CIRCLE;
            DrawCircleLines(xx ss_entity.x, xx ss_entity.y, e.collider.radius * camera.zoom, YELLOW);
        case .RECT;
            collider_base_size := xy(e.collider.rect.x, e.collider.rect.y);
            collider_modified_size := collider_base_size * camera.zoom;
            collider_drawpos := ss_entity - collider_modified_size/2 + e.collider.offset;
            DrawRectangleLines(xx collider_drawpos.x, xx collider_drawpos.y, xx collider_modified_size.x, xx collider_modified_size.y, YELLOW);
    }
}

debug_grid_info :: ()
{
    using Game;
    for grid.loadedChunks
    {
        for it.cells
        {
            if it.type != .AIR
            {
                drawpos := to_screen_space(grid_to_world(it), .{4, 4});
                str := tprint("%, %", it.x, it.y);
                DrawText(to_c_string(str), xx drawpos.x, xx drawpos.y, 14, PINK);
            }

            pos := to_screen_space(grid_to_world(it));
            size := cast(s32) (grid.cellSize * camera.zoom);
            DrawRectangleLines(xx pos.x, xx pos.y, size, size, PINK);
        }
    }

}

debug_console :: ()
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

    c.blinkTimer -= Game.dt / dtMultiplier;
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
        x := (WINDOW_WIDTH / 2.0) + 230.0;
        base_y := c.basePos.y + 5.0;
        for i: 0..5
        {
            index := commandListPage * 6 + i;
            if index >= commandList.count then break;
            item := commandList[index];

            y := base_y + ((fontSize * 1.4) * i);

            DrawTextEx(font, to_c_string(item), xy(x, y), fontSize, fontSpacing, GREEN);
        }

        // draw a page indicator
        // @Fix: 240 is the magic number for console background height
        numPages := commandList.count / 6;
        indicator_height := 240.0 / (numPages + 1);
        indicator_height -= 5.0;
        y := base_y + indicator_height * commandListPage;
        DrawRectangleV(xy(x - 20, y), xy(3, indicator_height), GREEN);
    }
}

debug_is_command_valid :: (cmd: string)
{
    cmd_array := split(cmd, " ");
    for cmd_array to_lower_in_place(it);
    if cmd_array.count > 0
    {
        if begins_with(cmd, "spawn")
        {
            Nicknames :: struct {
                name: string;
                alt: string;
            }

            nicknames: [] Nicknames = .[
                .{name="lumber_axe", alt="axe"},
                .{name="carpenters_hammer", alt="hammer"},
                .{name="pick_axe", alt="pick"},
                .{name="hewing_saw", alt="saw"},
                .{name="wood_log", alt="log"},
            ];
            for nicknames if cmd_array[1] == it.alt then cmd_array[1] = it.name;

            type := entity_type_from_string(cmd_array[1]);
            pos := Game.player.position.value + Game.player.person.forward * 50;
            collider: *Collider;

            if type.exists if type.value == {
                case .CONTAINER;
                    collider = NewCollider(.{20, 30});
                    container := NewContainer(container_type_from_string(cmd_array[1]).value, collider, pos);
                    array_add(*Game.containers, container);
                case .ITEM;
                    bp := Nothing(*BlueprintData);
                    collider = NewCollider(10);
                    if cmd_array[1] == "blueprint"
                    {
                        collider = NewCollider(50);
                        bp = maybe(NewBlueprintData(.BOXES));
                    }
                    if cmd_array[1] == "blueprint_curves"
                    {
                        collider = NewCollider(50);
                        bp = maybe(NewBlueprintData(.CURVES));
                    }
                    if cmd_array[1] == "blueprint_grid"
                    {
                        collider = NewCollider(50);
                        bp = maybe(NewBlueprintData(.GRID));
                    }
                    item := NewItem(item_type_from_string(cmd_array[1]).value, collider, pos);
                    item.blueprintData = bp;
                    array_add(*Game.items, item);
                case .EQUIPMENT;
                    collider = NewCollider(.{60, 15});
                    equipment := NewEquipment(equipment_type_from_string(cmd_array[1]).value, collider, pos);
                    array_add(*Game.equipment, equipment);
                case .RESOURCE;
                    if cmd_array[1] == "tree" then collider = NewCollider(.{50.0, 80.0}, .{0.0, 60.0});
                    resource := NewResource(resource_type_from_string(cmd_array[1]).value, collider, pos, 10);
                    array_add(*Game.resources, resource);
                case .BLOCK;
                    block_type := block_type_from_string(cmd_array[1]);
                    if block_type.exists
                    {
                        collider = NewCollider(.{100, 100});
                        cell := world_to_grid(pos);
                        cell.block = maybe(NewBlock(block_type.value, 0.0, collider, cell, null));
                        cell.type = .BLOCK;
                    }
            }
        }

        if begins_with(cmd, "speed")
        {
            Game.player.speed = string_to_float(cmd_array[1]);
        }

        if begins_with(cmd, "zoom")
        {
            Game.camera.zoom = string_to_float(cmd_array[1]);
        }

        if begins_with(cmd, "print")
        {
            if cmd_array[1] == "player" then print("%\n", Game.player);
            else if cmd_array.count >= 3 
            {
                x := string_to_int(cmd_array[1]);
                y := string_to_int(cmd_array[2]);
                cell := get_cell(x, y);
                print("%\n", <<cell);
                if cell.block.exists
                {
                    print("\t%\n", <<cell.block.value);
                    print("\t\t%\n", <<cell.block.value.collider);
                }
            }
        }

        if begins_with(cmd, "tp")
        {
            for cmd_array
            {
                if it_index == 0 continue; // skip "TP" string
                Game.player.position.value.component[it_index - 1] = string_to_float(it);
            }
        }

        if begins_with(cmd, "dt")
        {
            for cmd_array
            {
                if it_index == 0 continue;
                Debug.dtMultiplier = string_to_float(it);
            }
        }
    }


    if cmd == "faster"
    {
        Game.player.person.speed *= 10.0;
    }
    if cmd == "slower"
    {
        Game.player.person.speed /= 10.0;
    }
    if cmd == "normal"
    {
        Game.player.person.speed = 400.0; // maybe there should be default data to reference and active state
    }
    if cmd == "repop"
    {
        array_reset(*Game.resources);
        populate_resources();
    }
    if cmd == "reset"
    {
        game_reset();
    }
    if cmd == "debug info 0" || cmd == "db0"
    {
        Debug.showEntityInfo = false;
    }
    if cmd == "debug info 1" || cmd == "db1"
    {
        Debug.showEntityInfo = true;
    }

    if cmd == "freecam 1" || cmd == "fc1"
    {
        Debug.freeCamera = true;
    }
    if cmd == "freecam 0" || cmd == "fc0"
    {
        Debug.freeCamera = false;
    }
}

item_type_from_string :: (s: string) -> Maybe(Item_Type)
{
    str := to_upper_copy(s);
    for enum_names(Item_Type)
    {
        if str == it
        {
            m := maybe(cast(Item_Type) enum_values_as_s64(Item_Type)[it_index]);
            return m;
        }
    }
    return Nothing(Item_Type);
}

container_type_from_string :: (s: string) -> Maybe(Container_Type)
{
    str := to_upper_copy(s);
    for enum_names(Container_Type)
    {
        if str == it
        {
            m := maybe(cast(Container_Type) enum_values_as_s64(Container_Type)[it_index]);
            return m;
        }
    }
    return Nothing(Container_Type);
}

equipment_type_from_string :: (s: string) -> Maybe(Equipment_Type)
{
    str := to_upper_copy(s);
    for enum_names(Equipment_Type)
    {
        if str == it
        {
            m := maybe(cast(Equipment_Type) enum_values_as_s64(Equipment_Type)[it_index]);
            return m;
        }
    }
    return Nothing(Equipment_Type);
}

resource_type_from_string :: (s: string) -> Maybe(Resource_Type)
{
    str := to_upper_copy(s);
    for enum_names(Resource_Type)
    {
        if str == it
        {
            m := maybe(cast(Resource_Type) enum_values_as_s64(Resource_Type)[it_index]);
            return m;
        }
    }
    return Nothing(Resource_Type);
}

block_type_from_string :: (s: string) -> Maybe(Block_Type)
{
    str := to_upper_copy(s);
    for enum_names(Block_Type)
    {
        if str == it
        {
            m := maybe(cast(Block_Type) enum_values_as_s64(Block_Type)[it_index]);
            return m;
        }
    }
    return Nothing(Block_Type);
}

entity_type_from_string :: (s: string) -> Maybe(Entity_Type)
{
    str := to_upper_copy(s);
    for enum_names(Item_Type)      if str == it then return maybe(Entity_Type.ITEM);
    for enum_names(Container_Type) if str == it then return maybe(Entity_Type.CONTAINER);
    for enum_names(Equipment_Type) if str == it then return maybe(Entity_Type.EQUIPMENT);
    for enum_names(Resource_Type)  if str == it then return maybe(Entity_Type.RESOURCE);
    for enum_names(Block_Type)     if str == it then return maybe(Entity_Type.BLOCK);
    return Nothing(Entity_Type);
}