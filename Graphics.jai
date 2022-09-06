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

// Since raylib is such a pain in the ass to work with I need all these methods to fix it "easily"
draw_orthagonal_texture_centered :: (info: TextureInfo, center: Vector2, rotation: float, scale: float)
{
    drawpos := to_screen_space(center);
    if rotation == 0.0   then drawpos -= info.size/2 * scale;
    if rotation == 90.0  then drawpos -= xy(info.size.y, -info.size.x)/2 * scale;
    if rotation == 180.0 then drawpos += info.size/2 * scale;
    if rotation == 270.0 then drawpos += xy(info.size.y, -info.size.x)/2 * scale;
    DrawTextureEx(info.texture, drawpos, -rotation, scale, info.tint);
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
        // others
        case .BLUEPRINT;
            info.texture = table_find_pointer(*Textures.table, "blueprint");
        case;
            info.texture = *ERROR_TEXTURE;
    }
    info.size = xy(xx info.texture.width, xx info.texture.height);
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

UI_Representation :: struct
{
    position: Vector2;
    rotation: float;
    scale: float;
    info: TextureInfo;
    isHUD := true;
}

draw_ui_representation  :: (rep: UI_Representation)
{
    draw_ui_representation(rep.position, rep.scale, rep.info, rep.rotation);
}
draw_ui_representation  :: (pos: Vector2, scale: float, info: TextureInfo, rotation: float = 0.0)
{
    DrawTextureEx(info.texture, pos, rotation, scale, info.tint);
}

draw_entity :: (entity: Entity)
{
    if !entity.position.exists return;

    scale := entity.textureInfo.size.x / entity.textureInfo.texture.width;
    base_size := xy(xx entity.textureInfo.width, xx entity.textureInfo.height) * scale;
    modified_size := base_size * Game.camera.zoom;
    center_pos := to_screen_space(entity.position.value);
    drawpos := center_pos - modified_size / 2;
    DrawTextureEx(entity.textureInfo.texture, xx drawpos, 0.0, Game.camera.zoom * scale, entity.textureInfo.tint);
}

draw_item :: (item: Item)
{
    if item.blueprintData.exists
    {
        draw_entity(item);
        for item.blueprintData.value.slots if it.item.exists
        {
            texInfo: TextureInfo;
            position: Vector2;
            scale: float;
            rotation: float;
            texInfo, position, scale, rotation = get_blueprint_slot_draw_info(item, it_index, false);
            
            base_size := xy(xx texInfo.width, xx texInfo.height);
            modified_size := base_size * scale * Game.camera.zoom;
            ss_position := to_screen_space(position);
            drawpos: Vector2;
            if rotation == 90.0 || rotation == 270.0 
            {
                modified_size = xy(-modified_size.y, modified_size.x);
                drawpos = ss_position - modified_size / 2;
            }
            else drawpos = ss_position - modified_size / 2;
            DrawTextureEx(texInfo.texture, drawpos, rotation, Game.camera.zoom * scale, texInfo.tint);
        }
    }
    else
    {
        if !item.onSlot.exists then draw_entity(item);
    }
}

draw_cell :: (cell: GridCell)
{
    if cell.block.exists
    {
        if cell.block.value.type == .STAIR_TOP return;

        // @TEMP: for now make resizing preserve aspect ratio
        resize_ratio := cell.block.value.textureInfo.size.x / cell.block.value.textureInfo.width;
        base_size := xy(xx cell.block.value.textureInfo.width, xx cell.block.value.textureInfo.height);
        modified_size := base_size * resize_ratio * Game.camera.zoom;
        ss_block := to_screen_space(grid_to_world(cell.x, cell.y, true));
        drawpos := ss_block - modified_size / 2;
        tint := cell.block.value.textureInfo.tint;
        if cell.block.value.orientation == 90.0  then drawpos += xy(0, 1) * Game.grid.cellSize;
        if cell.block.value.orientation == 180.0 then drawpos += xy(1, 1) * Game.grid.cellSize;
        if cell.block.value.orientation == 270.0 then drawpos += xy(1, 0) * Game.grid.cellSize;
        DrawTextureEx(cell.block.value.textureInfo.texture, xx drawpos, -cell.block.value.orientation, resize_ratio * Game.camera.zoom, tint);
    }
    else
    {
        ss_cell := to_screen_space(grid_to_world(cell.x, cell.y));
        size := xy(Game.grid.cellSize * Game.camera.zoom, Game.grid.cellSize * Game.camera.zoom);
        if cell.type == {
            case .BEDROCK;
                info := get_texture_info(cell.type);
                scale := size.x / info.texture.width;
                draw_texture_centered(info, ss_cell + size/2, .{0, -1}, size, scale);
            case .DIRT;
                info := get_texture_info(cell.type);
                scale := size.x / info.texture.width;
                draw_texture_centered(info, ss_cell + size/2, .{0, -1}, size, scale);
            case .WATER;
                BeginShaderMode(Textures.waterShader);
                info := get_texture_info(cell.type);
                displacementTex := table_find_pointer(*Textures.table, "displacement_map");
                scale := size.x / info.texture.width;
                Textures.displacementOffset += xy(Game.dt, Game.dt);
                SetShaderValue(Textures.waterShader, Textures.displacementOffsetLoc, *Textures.displacementOffset, cast(s32) ShaderUniformDataType.SHADER_UNIFORM_VEC2);
                SetShaderValueTexture(Textures.waterShader, Textures.displacementTexLoc, <<displacementTex);
                draw_texture_centered(info, ss_cell + size/2, .{0, -1}, size, scale);
                EndShaderMode();
        }
    }
}