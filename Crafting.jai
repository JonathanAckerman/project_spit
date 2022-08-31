Blueprint :: struct
{
    using #as item: Item;
    blueprint_type: Blueprint_Type;
    slots: [] BlueprintSlot;
}

Blueprint_Type :: enum
{
    BOXES;
}

BlueprintSlot :: struct
{
    offset: Vector2;
    item: Maybe(*Item);
    slotType: Slot_Type;
}

Slot_Type :: enum
{
    SPAN;
    JOINT;
}

NewBlueprint :: (type: Blueprint_Type, pos: Maybe(Vector2)) -> Blueprint
{
    bp: Blueprint;
    bp.item = NewItem(.BLUEPRINT, NewCollider(50.0));
    bp.blueprint_type = type;

    slot :: (v: Vector2, t: Slot_Type) -> BlueprintSlot #expand {
        slot: BlueprintSlot;
        slot.offset = v;
        slot.item = Nothing(*Item);
        slot.slotType = t;
        return slot;
    }

    if #complete type == {
        case .BOXES;
            array_resize(*bp.slots, 8);
            bp.slots[0] = slot(.{0.0, 0.0}, .JOINT);
            bp.slots[1] = slot(.{0.5, 0.0}, .SPAN);
            bp.slots[2] = slot(.{1.0, 0.0}, .JOINT);
            bp.slots[3] = slot(.{1.0, 0.5}, .SPAN);
            bp.slots[4] = slot(.{1.0, 1.0}, .JOINT);
            bp.slots[5] = slot(.{0.5, 1.0}, .SPAN);
            bp.slots[6] = slot(.{0.0, 1.0}, .JOINT);
            bp.slots[7] = slot(.{0.0, 0.5}, .SPAN);
    }
    
    return bp;
}