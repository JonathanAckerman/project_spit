FRAME_RATE :: 60.0;

// draw_texture_centered :: (info: AnimationFrame, center: Vector2, forward: Vector2, size: Vector2, scale: float)
// {
//     x := forward.x;
//     y := ifx RAYLIB then -forward.y else forward.y;
//     rot := atan2(y, x);
//     drawpos: Vector2;
//     if RAYLIB {
//         reverse_ray_bullshit_vector := rotate_vector(size/2, atan2(forward.y, forward.x));
//         drawpos = center - reverse_ray_bullshit_vector;
//     } else {
//         drawpos = center - size/2;
//     }

//     // for some reason 'size' & 'scale' need to be separate concepts, thanks ray
//     DrawTextureEx(info.texture, drawpos, -rad2deg(rot), scale, info.tint);
// }

// Since raylib is such a pain in the ass to work with I need all these methods to fix it "easily"
// draw_orthagonal_texture_centered :: (frame: AnimationFrame, center: Vector2, rotation: float, scale: float)
// {
//     drawpos := to_screen_space(center);
//     if rotation == 0.0   then drawpos -= frame.size/2 * scale;
//     if rotation == 90.0  then drawpos += xy(frame.size.y, -frame.size.x)/2 * scale;
//     if rotation == 180.0 then drawpos += frame.size/2 * scale;
//     if rotation == 270.0 then drawpos -= xy(frame.size.y, -frame.size.x)/2 * scale;
//     DrawTextureEx(frame.texture, drawpos, rotation, scale, frame.tint);
// }

UI_Representation :: struct
{
    position: Vector2;
    rotation: float;
    scale: float;
    frame: AnimationFrame;
    isHUD := true;
}

draw_ui_representation  :: (rep: UI_Representation)
{
    draw_ui_representation(rep.position, rep.scale, rep.frame, rep.rotation);
}
draw_ui_representation  :: (pos: Vector2, scale: float, frame: AnimationFrame, rotation: float = 0.0)
{
    DrawTextureEx(frame.texture, pos, rotation, scale, frame.tint);
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
            scale: float;
            rotation: float;
            position, scale, rotation = get_blueprint_slot_draw_info(item, it_index);
            
            base_size := xy(xx frame.width, xx frame.height);
            modified_size := base_size * scale * Game.camera.zoom;
            ss_position := to_screen_space(position);
            drawpos: Vector2;
            if rotation == 90.0 || rotation == 270.0 
            {
                modified_size = xy(-modified_size.y, modified_size.x);
                drawpos = ss_position - modified_size / 2;
            }
            else drawpos = ss_position - modified_size / 2;
            DrawTextureEx(frame.texture, drawpos, rotation, Game.camera.zoom * scale, frame.tint);
        }
    }
    else
    {
        if !item.onSlot.exists then draw_entity(item);
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
    if !hasStarted then return;
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