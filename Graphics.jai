FRAME_RATE :: 60.0;

UI_Representation :: struct
{
    position: Vector2;
    rotation: float;
    frame: AnimationFrame;
    isHUD := true;
}

draw_ui_representation  :: (rep: UI_Representation)
{
    draw_ui_representation(rep.position, rep.frame, rep.rotation);
}
draw_ui_representation  :: (pos: Vector2, frame: AnimationFrame, rotation: float = 0.0)
{
    DrawTextureEx(frame.texture, pos, rotation, 1.0, frame.tint);
}

draw_entity :: (entity: Entity)
{
    if !entity.position.exists return;

    center_pos := to_screen_space(entity.position.value);
    rotation := rad2deg(atan2(-entity.forward.y, entity.forward.x)) - 90.0;
    frame := Current_Frame(entity.animation);
    draw_texture_centered_with_rotation(frame, center_pos, rotation);
}

draw_item :: (item: Item)
{
    if item.blueprintData.exists
    {
        draw_entity(item);
        for item.blueprintData.value.slots if it.item.exists
        {
            frame := Current_Frame(*it.item.value.animation);
            position: Vector2;
            rotation: float;
            position, rotation = get_blueprint_slot_draw_info(item, it_index);
            
            base_size := xy(xx frame.width, xx frame.height);
            modified_size := base_size * Game.camera.zoom;
            ss_position := to_screen_space(position);
            drawpos: Vector2;
            if rotation == 90.0 || rotation == 270.0 
            {
                modified_size = xy(-modified_size.y, modified_size.x);
                drawpos = ss_position - modified_size / 2;
            }
            else drawpos = ss_position - modified_size / 2;
            DrawTextureEx(frame.texture, drawpos, rotation, Game.camera.zoom, frame.tint);
        }
    }
    else
    {
        if !item.onSlot.exists then draw_entity(item);
    }
}

draw_shop :: (shop : *Shop)
{
    for shop.area
    {
        ss_cell := to_screen_space(grid_to_world(it) + .{5, 5});
        size := xy(90, 90) * Game.camera.zoom;
        drawpos_offset_from_size := size - size;
        ss_cell += drawpos_offset_from_size / 2;
        DrawRectangleV(ss_cell, size, LIGHTGRAY);
    }
}

draw_texture_centered_with_rotation :: (frame: AnimationFrame, pos: Vector2, rotation: float)
{
    pos_to_center := frame.size/2 * Game.camera.zoom;
    rotated_pos_to_center := rotate_vector(pos_to_center, deg2rad(-rotation));
    drawpos := pos - rotated_pos_to_center;
    scale := frame.size.x / frame.texture.width;
    DrawTextureEx(frame.texture, drawpos, -rotation, scale * Game.camera.zoom, frame.tint);
}

draw_cell :: (cell: GridCell)
{
    center_pos := to_screen_space(grid_to_world(cell.x, cell.y, shouldGetCenter=true));
    frame := Current_Frame(cell.animation);
    if cell.type == {
        case .BEDROCK;
            draw_texture_centered_with_rotation(frame, center_pos, 0.0);
        case .DIRT;
            draw_texture_centered_with_rotation(frame, center_pos, 0.0);
        case .WATER;
            BeginShaderMode(Shaders.waterShader);
            Shaders.displacementOffset += xy(Game.dt, Game.dt);
            SetShaderValue(Shaders.waterShader, Shaders.displacementOffsetLoc, *Shaders.displacementOffset, cast(s32) ShaderUniformDataType.SHADER_UNIFORM_VEC2);
            SetShaderValueTexture(Shaders.waterShader, Shaders.displacementTexLoc, Shaders.displacementMapTexture);
            draw_texture_centered_with_rotation(frame, center_pos, 0.0);
            EndShaderMode();
    }

    if cell.block.exists
    {
        block_anim := cell.block.value.animation;
        block_frame := Current_Frame(block_anim);
        block_rotation := rad2deg(atan2(cell.block.value.forward.y, cell.block.value.forward.x));
        draw_texture_centered_with_rotation(block_frame, center_pos, block_rotation);
    }
}

update_animations :: ()
{
    using Game;
    for items       if is_in_loaded_chunk(it) { update_animation(*it.animation); }
    for containers  if is_in_loaded_chunk(it) { update_animation(*it.animation); }
    for equipment   if is_in_loaded_chunk(it) { update_animation(*it.animation); }
    for npcs        if is_in_loaded_chunk(it) { update_animation(*it.animation); }
    for resources   if is_in_loaded_chunk(it) { update_animation(*it.animation); }
}

update_animation :: (using anim: *Animation)
{
    if !shouldLoop && hasFinished then return;

    if frameTimer <= 0.0 {
        frameTimer = duration/frames.count;
        currentFrame += 1;
    }
    else frameTimer -= Game.dt;

    if currentFrame >= frames.count {
        if shouldLoop then currentFrame = 0;
        else currentFrame = frames.count - 1;
    }

    // maybe stuff about the texture size/tint?
}

Current_Frame :: (using anim: Animation) -> *AnimationFrame #expand {
    return *frames[currentFrame];
}

Animation_Key :: (type: $T, anim: string) -> string {
    name := to_lower_copy(enum_names(T)[type]);
    return tprint("%/%", name, anim);
}