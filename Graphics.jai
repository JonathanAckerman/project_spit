draw_texture_centered :: (info: TextureInfo, center: Vector2, forward: Vector2, size: Vector2, scale: float)
{
    x := forward.x;
    y := ifx RAYLIB then -forward.y else forward.y;
    rot := atan2(y, x);
    drawpos: Vector2;
    if RAYLIB {
        reverse_ray_bullshit_vector := rotate_vector(size/2, atan2(forward.y, forward.x));
        drawpos = center - reverse_ray_bullshit_vector;
    } else {
        drawpos = center - size/2;
    }

    // for some reason 'size' & 'scale' need to be separate concepts, thanks ray
    DrawTextureEx(info.texture, drawpos, -rad2deg(rot), scale, info.tint);
}

// @JAY: is there a way to make this generic for any texture lookup? polymorph?
// @JAY: can I generate this during the textureload step?
get_texture_info :: (type: Item_Type) -> TextureInfo
{
    info: TextureInfo;
    if type == 
    {
        // weapons
        case .SWORD;
            info.texture = table_find_pointer(*Textures.table, "sword");
        case .WHIP;
            info.texture = table_find_pointer(*Textures.table, "whip");
        // tools
        case .LUMBER_AXE;
            info.texture = table_find_pointer(*Textures.table, "lumber_axe");
        case .PICK_AXE;
            info.texture = table_find_pointer(*Textures.table, "pick_axe");
        case .HEWING_SAW;
            info.texture = table_find_pointer(*Textures.table, "hewing_saw");
        case .CARPENTERS_HAMMER;
            info.texture = table_find_pointer(*Textures.table, "carpenters_hammer");
        // by-products
        case .WOOD_LOG;
            info.texture = table_find_pointer(*Textures.table, "wood_log");
        case .COPPER_NUGGET;
            info.texture = table_find_pointer(*Textures.table, "copper_nugget");
        case .IRON_NUGGET;
            info.texture = table_find_pointer(*Textures.table, "iron_nugget");
        case .FIBER;
            info.texture = table_find_pointer(*Textures.table, "fiber");
        case;
            info.texture = *ERROR_TEXTURE;
    }
    return info;
}
get_texture_info :: (type: Equipment_Type) -> TextureInfo
{
    info: TextureInfo;
    if type == 
    {
        case .TOOL_BELT;
            info.texture = table_find_pointer(*Textures.table, "tool_belt");
            info.tint = BEIGE;
        case .WEAPON_BELT;
            info.texture = table_find_pointer(*Textures.table, "weapon_belt");
            info.tint = BROWN;
        case;
            info.texture = *ERROR_TEXTURE;
    }
    return info;
}
get_texture_info :: (type: Container_Type) -> TextureInfo
{
    info: TextureInfo;
    if type == 
    {
        case .BASKET;
            info.texture = table_find_pointer(*Textures.table, "basket");
            info.tint = BEIGE;
        case .CHEST;
            info.texture = table_find_pointer(*Textures.table, "chest");
            info.tint = BROWN;
        case .BUCKET;
            info.texture = table_find_pointer(*Textures.table, "bucket");
            info.tint = LIGHTGRAY;
    }
    return info;
}
get_texture_info :: (type: Terrain_Type) -> TextureInfo
{
    info: TextureInfo;
    if type == {
        case .BEDROCK;
            info.texture = table_find_pointer(*Textures.table, "bedrock");
            info.size = .{100, 100};
        case .DIRT;
            info.texture = table_find_pointer(*Textures.table, "dirt");
            info.size = .{100, 100};
        case .WATER;
            info.texture = table_find_pointer(*Textures.table, "water");
    }
    return info;
}

draw_ui_representation  :: (pos: Vector2, scale: float, info: TextureInfo)
{
    drawpos := pos;
    DrawTextureEx(info.texture, xx drawpos, 0.0, scale, info.tint);
}

draw_entity :: (entity: Entity)
{
    if !entity.position.exists return;

    scale := entity.textureInfo.size.x / entity.textureInfo.texture.width;
    layer_size_modifier := 1.0 - (xx entity.position.value.z - (Game.camera.position.z + 1)) * 0.1;
    layer_size_modifier = clamp(layer_size_modifier, 0.0, 1.0);
    base_size := xy(xx entity.textureInfo.width, xx entity.textureInfo.height) * scale;
    modified_size := base_size * Game.camera.zoom * layer_size_modifier;
    center_pos := to_screen_space(entity.position.value.xy);
    drawpos := center_pos - modified_size / 2;
    tint := entity.textureInfo.tint;
    tint.r = xx (tint.r * layer_size_modifier);
    tint.g = xx (tint.g * layer_size_modifier);
    tint.b = xx (tint.b * layer_size_modifier);
    DrawTextureEx(entity.textureInfo.texture, xx drawpos, 0.0, Game.camera.zoom * layer_size_modifier * scale, tint);
}