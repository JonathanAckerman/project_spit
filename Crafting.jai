BlueprintData :: struct
{
    blueprint_type: Blueprint_Type;
    slots: [] *BlueprintSlot;
}
Blueprint_Type :: enum
{
    BOXES;
    CURVES;
    GRID;
}

BlueprintSlot :: struct
{
    index: int;
    offset: Vector2;
    rotation: float;
    item: Maybe(*Item);
    slotType: Slot_Type;
}
Slot_Type :: enum
{
    INVALID;
    SPAN;
    HALF_SPAN;
    JOINT;
    CURVE;
}

CraftTarget :: struct
{
    blueprint: *Item;
    slot: *BlueprintSlot;
}

Recipe :: struct
{
    blueprint_type: Blueprint_Type;
    result_tag: Entity_Type;
    result_type: union {
        #as item_type: Item_Type;
        #as container_type: Container_Type;
        #as equipment_type: Equipment_Type;
    };

    definition_info :: struct { item_type: Item_Type; index: int; }
    definition: [] definition_info;
}
Recipes := Recipe.[
    /* Crate: */ .{.BOXES, .CONTAINER, .{container_type=.CRATE}, .[
        .{.NAILS, 0}, .{.PLANK, 1}, .{.NAILS, 2}, 
        .{.PLANK, 7},               .{.PLANK, 3}, 
        .{.NAILS, 6}, .{.PLANK, 5}, .{.NAILS, 4}
    ]},
    /* Basket: */ .{.BOXES, .CONTAINER, .{container_type=.BASKET}, .[
                      .{.FIBER, 1},
        .{.FIBER, 7},               .{.FIBER, 3}, 
                      .{.FIBER, 5},
    ]},
    /* Chest: */ .{.BOXES, .CONTAINER, .{container_type=.CHEST}, .[
        .{.HINGE, 0}, .{.WOOD_LOG, 1}, .{.HINGE, 2},
        .{.PLANK, 7},                  .{.PLANK, 3}, 
        .{.NAILS, 6}, .{.PLANK, 5},    .{.NAILS, 4}
    ]},
    /* Pier: */ .{.GRID, .ITEM, .{item_type=.SILVER_NUGGET}, .[
            .{.NAILS, 0},                .{.NAILS, 2},
            .{.NAILS, 3},                .{.NAILS, 5},
            .{.NAILS, 6},                .{.NAILS, 8},
            .{.PLANK, 9}, .{.PLANK, 10}, .{.PLANK, 11},
        .{.WOOD_LOG, 12},                .{.WOOD_LOG, 14},
    ]},
];
#run { for Recipes bubble_sort(it.definition, (a, b) => a.index - b.index); };

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
        case .CURVES;
            array_resize(*bp.slots, 9);
            bp.slots[0] = slot(.{0.5, 0.0}, 0.0,  .HALF_SPAN);
            bp.slots[1] = slot(.{1.0, 0.0}, 90.0, .CURVE);
            bp.slots[2] = slot(.{1.0, 0.5}, 0.0,  .HALF_SPAN);
            bp.slots[3] = slot(.{1.0, 1.0}, 0.0,  .CURVE);
            bp.slots[4] = slot(.{0.5, 1.0}, 0.0,  .HALF_SPAN);
            bp.slots[5] = slot(.{0.0, 1.0}, 90.0, .CURVE);
            bp.slots[6] = slot(.{0.0, 0.5}, 0.0,  .HALF_SPAN);
            bp.slots[7] = slot(.{0.0, 0.0}, 0.0,  .CURVE);
            bp.slots[8] = slot(.{0.5, 0.5}, 0.0,  .JOINT);
        case .GRID;
            array_resize(*bp.slots, 15);
            bp.slots[0]  = slot(.{0.0, 0.0}, 0.0,   .JOINT);
            bp.slots[1]  = slot(.{0.5, 0.0}, 0.0,   .JOINT);
            bp.slots[2]  = slot(.{1.0, 0.0}, 0.0,   .JOINT);
            bp.slots[3]  = slot(.{0.0, 0.5}, 0.0,   .JOINT);
            bp.slots[4]  = slot(.{0.5, 0.5}, 0.0,   .JOINT);
            bp.slots[5]  = slot(.{1.0, 0.5}, 0.0,   .JOINT);
            bp.slots[6]  = slot(.{0.0, 1.0}, 0.0,   .JOINT);
            bp.slots[7]  = slot(.{0.5, 1.0}, 0.0,   .JOINT);
            bp.slots[8]  = slot(.{1.0, 1.0}, 0.0,   .JOINT);
            bp.slots[9]  = slot(.{0.5, 0.0}, 90.0,  .SPAN);
            bp.slots[10] = slot(.{0.5, 0.5}, 90.0,  .SPAN);
            bp.slots[11] = slot(.{0.5, 1.0}, 90.0,  .SPAN);
            bp.slots[12] = slot(.{0.0, 0.5}, 0.0,   .SPAN);
            bp.slots[13] = slot(.{0.5, 0.5}, 0.0,   .SPAN);
            bp.slots[14] = slot(.{1.0, 0.5}, 0.0,   .SPAN);
    }
    for bp.slots it.index = it_index;
    return bp;
}

// @Note: it is the caller's responsibility to make sure the slot index is valid
get_blueprint_slot_draw_info :: (bp: Item, item_size: Vector2, slot_index: int) -> Vector2, float, float
{
    using Game;
    slot := bp.blueprintData.value.slots[slot_index];
    bp_base_pos := bp.position.value - bp.textureInfo.size/2;
    scale := 0.4;
    offsetFromTexture: Vector2;
    if slot.rotation == 90.0
    {
        if slot.offset.x == 0.0 then offsetFromTexture.x =  item_size.y/2;
        if slot.offset.x == 1.0 then offsetFromTexture.x = -item_size.y/2;
        if slot.offset.y == 0.0 then offsetFromTexture.y =  item_size.x/2;
        if slot.offset.y == 1.0 then offsetFromTexture.y = -item_size.x/2;
    }
    else if slot.rotation == 270.0
    {
        if slot.offset.x == 0.0 then offsetFromTexture.x = -item_size.y/2;
        if slot.offset.x == 1.0 then offsetFromTexture.x =  item_size.y/2;
        if slot.offset.y == 0.0 then offsetFromTexture.y =  item_size.x/2;
        if slot.offset.y == 1.0 then offsetFromTexture.y = -item_size.x/2;
    }
    else
    {
        if slot.offset.x == 0.0 then offsetFromTexture.x =  item_size.x/2;
        if slot.offset.x == 1.0 then offsetFromTexture.x = -item_size.x/2;
        if slot.offset.y == 0.0 then offsetFromTexture.y =  item_size.y/2;
        if slot.offset.y == 1.0 then offsetFromTexture.y = -item_size.y/2;
    }
    pos := bp_base_pos + bp.textureInfo.size * slot.offset + offsetFromTexture * scale;
    return pos, scale, slot.rotation;
}

get_byproduct_slot_type :: (type: Item_Type) -> Slot_Type
{
    if type == {
        case .HALF_PLANK;
            return .HALF_SPAN;

        case .FIBER; #through;
        case .PLANK; #through;
        case .WOOD_LOG;
            return .SPAN;

        case .NAILS; #through;
        case .HINGE;
            return .JOINT;

        case;
            return .INVALID;
    }
}