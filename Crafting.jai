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
        #as item_type:      Item_Type;
        #as container_type: Container_Type;
        #as equipment_type: Equipment_Type;
        #as block_type:     Block_Type;
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
    /* Pier: */ .{.GRID, .BLOCK, .{block_type=.PIER}, .[
            .{.NAILS, 0},                .{.NAILS, 2},
            .{.NAILS, 3},                .{.NAILS, 5},
            .{.NAILS, 6},                .{.NAILS, 8},
            .{.PLANK, 9}, .{.PLANK, 10}, .{.PLANK, 11},
        .{.WOOD_LOG, 12},                .{.WOOD_LOG, 14},
    ]},
    /* Fishing Net: */ .{.GRID, .ITEM, .{item_type=.FISHING_NET}, .[
            .{.FIBER, 9},  .{.FIBER, 10}, .{.FIBER, 11},
            .{.FIBER, 12}, .{.FIBER, 13}, .{.FIBER, 14},
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
            bp.slots[1] = slot(.{0.5, 0.0}, PI/2, .SPAN);
            bp.slots[2] = slot(.{1.0, 0.0}, 0.0,  .JOINT);
            bp.slots[3] = slot(.{1.0, 0.5}, 0.0,  .SPAN);
            bp.slots[4] = slot(.{1.0, 1.0}, 0.0,  .JOINT);
            bp.slots[5] = slot(.{0.5, 1.0}, PI/2, .SPAN);
            bp.slots[6] = slot(.{0.0, 1.0}, 0.0,  .JOINT);
            bp.slots[7] = slot(.{0.0, 0.5}, 0.0,  .SPAN);
        case .CURVES;
            array_resize(*bp.slots, 9);
            bp.slots[0] = slot(.{0.5, 0.0}, 0.0,  .HALF_SPAN);
            bp.slots[1] = slot(.{1.0, 0.0}, PI/2, .CURVE);
            bp.slots[2] = slot(.{1.0, 0.5}, 0.0,  .HALF_SPAN);
            bp.slots[3] = slot(.{1.0, 1.0}, 0.0,  .CURVE);
            bp.slots[4] = slot(.{0.5, 1.0}, 0.0,  .HALF_SPAN);
            bp.slots[5] = slot(.{0.0, 1.0}, PI/2, .CURVE);
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
            bp.slots[9]  = slot(.{0.5, 0.0}, PI/2,  .SPAN);
            bp.slots[10] = slot(.{0.5, 0.5}, PI/2,  .SPAN);
            bp.slots[11] = slot(.{0.5, 1.0}, PI/2,  .SPAN);
            bp.slots[12] = slot(.{0.0, 0.5}, 0.0,   .SPAN);
            bp.slots[13] = slot(.{0.5, 0.5}, 0.0,   .SPAN);
            bp.slots[14] = slot(.{1.0, 0.5}, 0.0,   .SPAN);
    }
    for bp.slots it.index = it_index;
    return bp;
}

// @Note: it is the caller's responsibility to make sure the slot index is valid
get_blueprint_slot_draw_info :: (bp: Item, slot_index: int) -> Vector2, Vector2
{
    using Game;
    slot := bp.blueprintData.value.slots[slot_index];
    bp_frame := Current_Frame(bp.animation);
    bp_base_pos := bp.position.value - bp_frame.size/2;
    offsetPixels: Vector2;
    if slot.rotation == PI/2
    {
        if slot.offset.x == 0.0 then offsetPixels.x =  15.0;
        if slot.offset.x == 1.0 then offsetPixels.x = -15.0;
        if slot.offset.y == 0.0 then offsetPixels.y =  15.0;
        if slot.offset.y == 1.0 then offsetPixels.y = -15.0;
    }
    else if slot.rotation == 3*PI/2
    {
        if slot.offset.x == 0.0 then offsetPixels.x = -15.0;
        if slot.offset.x == 1.0 then offsetPixels.x =  15.0;
        if slot.offset.y == 0.0 then offsetPixels.y =  15.0;
        if slot.offset.y == 1.0 then offsetPixels.y = -15.0;
    }
    else
    {
        if slot.offset.x == 0.0 then offsetPixels.x =  15.0;
        if slot.offset.x == 1.0 then offsetPixels.x = -15.0;
        if slot.offset.y == 0.0 then offsetPixels.y =  15.0;
        if slot.offset.y == 1.0 then offsetPixels.y = -15.0;
    }
    pos := bp_base_pos + bp_frame.size * slot.offset + offsetPixels;
    forward := xy(cos(slot.rotation - PI/2), sin(slot.rotation - PI/2));
    return pos, forward;
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