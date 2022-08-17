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
        "SPEED",
        "PRINT PLAYER",
        "REPOP RESOURCES",
        "RESET",
        "DEBUG INFO 0",
        "DEBUG INFO 1"
    ];
    showEntityInfo := false;
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

debug_player_info :: ()
{
    ss_player := to_screen_space(Game.player.position.value.xy);
    drawpos := ss_player + xy(30 * Game.camera.zoom, 0);
    DrawText(to_c_string(tprint("pos: %", Game.player.position.value)), xx drawpos.x, xx drawpos.y, 16, PINK);
    drawpos.y += 20.0 * Game.camera.zoom;
    DrawText(to_c_string(tprint("ID:  %", Game.player.id)), xx drawpos.x, xx drawpos.y, 16, PINK);

    DrawCircleLines(xx ss_player.x, xx ss_player.y, Game.player.interactRange * Game.camera.zoom, PINK);
}

debug_entity_info :: (e: Entity)
{
    ss_entity := to_screen_space(e.position.value.xy);
    drawpos := ss_entity + xy(30 * Game.camera.zoom, 0);
    DrawText(to_c_string(tprint("pos: %", e.position.value)), xx drawpos.x, xx drawpos.y, 16, PINK);
    drawpos.y += 20.0 * Game.camera.zoom;
    DrawText(to_c_string(tprint("ID:  %", e.id)), xx drawpos.x, xx drawpos.y, 16, PINK);
    drawpos.y += 20.0 * Game.camera.zoom;

    layer_size_modifier := 1.0 - (e.position.value.z - cast(int) Game.camera.position.z) * 0.1;
    if e.textureInfo.texture != null
    {
        base_size := xy(xx e.textureInfo.width, xx e.textureInfo.height) * 0.5;
        modified_size := base_size * Game.camera.zoom * layer_size_modifier;
        texture_drawpos := ss_entity - modified_size/2;
        DrawRectangleLines(xx texture_drawpos.x, xx texture_drawpos.y, xx modified_size.x, xx modified_size.y, PINK);
    }

    if e.collider.type == {
        case .CIRCLE;
            DrawCircleLines(xx ss_entity.x, xx ss_entity.y, e.collider.radius * Game.camera.zoom * layer_size_modifier, YELLOW);
        case .RECT;
            base_size := xy(e.collider.rect.x, e.collider.rect.y) * 0.5;
            modified_size := base_size * Game.camera.zoom * layer_size_modifier;
            collider_drawpos := ss_entity - modified_size/2;
            DrawRectangleLines(xx collider_drawpos.x, xx collider_drawpos.y, xx modified_size.x, xx modified_size.y, YELLOW);
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
    if cmd == "DEBUG INFO 0" || "DB0"
    {
        Debug.showEntityInfo = false;
    }
    if cmd == "DEBUG INFO 1" || "DB1"
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