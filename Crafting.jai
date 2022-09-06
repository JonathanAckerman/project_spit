BlueprintData :: struct
{
    blueprint_type: Blueprint_Type;
    slots: [] *BlueprintSlot;
}
Blueprint_Type :: enum
{
    BOXES;
}

BlueprintSlot :: struct
{
    offset: Vector2;
    rotation: float;
    item: Maybe(*Item);
    slotType: Slot_Type;
}
Slot_Type :: enum
{
    SPAN;
    JOINT;
    INVALID;
}

CraftTarget :: struct
{
    blueprint: *Item;
    slot: *BlueprintSlot;
}

NewBlueprintData :: (type: Blueprint_Type) -> *BlueprintData
{
    bp := New(BlueprintData);
    bp.blueprint_type = type;

    slot :: (v: Vector2, r: float, t: Slot_Type) -> *BlueprintSlot #expand {
        slot := New(BlueprintSlot);
        slot.offset = v;
        slot.rotation = r;
        slot.item = Nothing(*Item);
        slot.slotType = t;
        return slot;
    }

    if #complete type == {
        case .BOXES;
            array_resize(*bp.slots, 8);
            bp.slots[0] = slot(.{0.0, 0.0}, 0.0,  .JOINT);
            bp.slots[1] = slot(.{0.5, 0.0}, 90.0, .SPAN);
            bp.slots[2] = slot(.{1.0, 0.0}, 0.0,  .JOINT);
            bp.slots[3] = slot(.{1.0, 0.5}, 0.0,  .SPAN);
            bp.slots[4] = slot(.{1.0, 1.0}, 0.0,  .JOINT);
            bp.slots[5] = slot(.{0.5, 1.0}, 90.0, .SPAN);
            bp.slots[6] = slot(.{0.0, 1.0}, 0.0,  .JOINT);
            bp.slots[7] = slot(.{0.0, 0.5}, 0.0,  .SPAN);
    }
    return bp;
}

// @Note: it is the caller's responsibility to make sure the slot index is valid
get_blueprint_slot_draw_info :: (bp: Item, slotIndex: int, isScreenSpace: bool = true) -> TextureInfo, Vector2, float, float
{
    using Game;
    slot := bp.blueprintData.value.slots[slotIndex];
    bp_base_pos: Vector2;
    if isScreenSpace then bp_base_pos = to_screen_space(bp.position.value - bp.textureInfo.size/2);
    else bp_base_pos = bp.position.value - bp.textureInfo.size/2;
    texInfo := get_texture_info(player.held.value.item.type);
    scale := 0.4;
    offsetFromTexture: Vector2;
    if slot.rotation == 90.0
    {
        if slot.offset.x == 0.0 then offsetFromTexture.x =  texInfo.size.y/2;
        if slot.offset.x == 1.0 then offsetFromTexture.x = -texInfo.size.y/2;
        if slot.offset.y == 0.0 then offsetFromTexture.y =  texInfo.size.x/2;
        if slot.offset.y == 1.0 then offsetFromTexture.y = -texInfo.size.x/2;
    }
    else if slot.rotation == 270.0
    {
        if slot.offset.x == 0.0 then offsetFromTexture.x = -texInfo.size.y/2;
        if slot.offset.x == 1.0 then offsetFromTexture.x =  texInfo.size.y/2;
        if slot.offset.y == 0.0 then offsetFromTexture.y =  texInfo.size.x/2;
        if slot.offset.y == 1.0 then offsetFromTexture.y = -texInfo.size.x/2;
    }
    else
    {
        if slot.offset.x == 0.0 then offsetFromTexture.x =  texInfo.size.x/2;
        if slot.offset.x == 1.0 then offsetFromTexture.x = -texInfo.size.x/2;
        if slot.offset.y == 0.0 then offsetFromTexture.y =  texInfo.size.y/2;
        if slot.offset.y == 1.0 then offsetFromTexture.y = -texInfo.size.y/2;
    }
    pos := bp_base_pos + bp.textureInfo.size * slot.offset + offsetFromTexture * scale;
    return texInfo, pos, scale, slot.rotation;
}