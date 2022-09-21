FRAME_RATE :: 60.0;

DrawBufferItem :: struct
{
    position: Vector2;
    rotation: float;
    frame: AnimationFrame;
    traunch: Draw_Traunch;
    shaderType: Shader_Type;
}

// @TEMP
Shader_Type :: enum
{
    DEFAULT;
    WATER_SHADER;
}

// @TEMP
Draw_Traunch :: enum
{
    CELL;
    SHOP_RUG;
    ENTITY;
    BLUEPRINT_ITEMS;
    NPC;
    PLAYER;
    WORLD_UI;
    SCREEN_UI;
    DEBUG;
}

draw_texture_centered_with_rotation :: (frame: AnimationFrame, pos: Vector2, rotation: float, isScreenSpace: bool = false)
{
    scale := frame.size.x / frame.texture.width;
    pos_to_center := frame.size/2;
    if !isScreenSpace {
        pos_to_center *= Game.camera.zoom;
        scale *= Game.camera.zoom;
    }
    rotated_pos_to_center := rotate_vector(pos_to_center, deg2rad(-rotation));
    drawpos := pos - rotated_pos_to_center;
    DrawTextureEx(frame.texture, drawpos, -rotation, scale, frame.tint);
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

/* draw_everything_defered :: () {
    debug_entity_info       (pos, frame, rot)           // for drawing debug stuff
    debug_console           ()                          // drawing console
    debug_deferred_draw_... ()                          // drawing dbls, dbrs
    DrawRectangleLines      ()                          // inventory cells
}

*/

add_to_draw_buffer :: (entity: Entity, traunch: Draw_Traunch, shader_type: Shader_Type = .DEFAULT)
{
    buffered: DrawBufferItem;
    buffered.frame = Current_Frame(entity.animation);
    buffered.position = entity.position.value;
    buffered.rotation = atan2(-entity.forward.y, entity.forward.x) - PI/2; // @@@: in radians
    buffered.traunch = traunch;
    buffered.shaderType = shader_type;
    array_add(*Game.drawBuffer, buffered);
}
add_to_draw_buffer :: (frame: AnimationFrame, position: Vector2, traunch: Draw_Traunch, forward: Vector2 = .{0, -1}, shader_type: Shader_Type = .DEFAULT, scale: float = 1.0)
{
    buffered: DrawBufferItem;
    buffered.frame = frame;
    buffered.frame.size *= scale;
    buffered.position = position;
    buffered.rotation = atan2(-forward.y, forward.x) - PI/2; // @@@: in radians
    buffered.traunch = traunch;
    buffered.shaderType = shader_type;
    array_add(*Game.drawBuffer, buffered);
}