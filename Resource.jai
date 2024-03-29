Resource :: struct 
{
    using #as entity: Entity;
    type: Resource_Type;
    quantity: int;
}

Item :: struct
{
    using #as entity: Entity;
    type: Item_Type;
    blueprintData: Maybe(*BlueprintData);
    onSlot: Maybe(*BlueprintSlot);
}

Container :: struct
{
    using #as entity: Entity;
    type: Container_Type;
    capacity: int;
    contents: [..] Containable;
}

Equipment :: struct
{
    using #as entity: Entity;
    type: Equipment_Type;
    capacity: int;
    contents: [] Maybe(*Item);
}

get_resource_byproduct :: (type: Resource_Type) -> *Item
{
    if type ==
    {
        case .COPPER_VEIN;
            return NewItem(.COPPER_NUGGET, NewCollider(10.0));
        case .IRON_VEIN;
            return NewItem(.IRON_NUGGET, NewCollider(10.0));
        case .SILVER_VEIN;
            return NewItem(.SILVER_NUGGET, NewCollider(10.0));
        case .TREE;
            return NewItem(.WOOD_LOG, NewCollider(.{10, 10}));
        case .BUSH;
            return NewItem(.FIBER, NewCollider(10.0));
        case;
            return null;
    }
}

// @Jay: do all the work to make the item, and add it to Game.items here
get_item_byproducts :: (type: Item_Type) -> [] *Item
{
    result: [..] *Item;
    if type ==
    {
        case .WOOD_LOG;
            array_add(*result, NewItem(.PLANK, NewCollider(10.0)));
        case .PLANK;
            array_add(*result, NewItem(.HALF_PLANK, NewCollider(10.0)));
            array_add(*result, NewItem(.HALF_PLANK, NewCollider(10.0)));
    }
    return result;
}

get_item_processing_tool :: (type: Item_Type) -> bool, Item_Type
{
    if type == {
        case .WOOD_LOG;
            return true, .HEWING_SAW;
        case .PLANK;
            return true, .HEWING_SAW;
    }
    dummy: Item_Type;
    return false, dummy;
}

get_harvest_requirement :: (type: Resource_Type) -> Maybe(Item_Type)
{
    if type == {
        case .TREE;
            return maybe(Item_Type.LUMBER_AXE);
        case .BUSH;
            return maybe(Item_Type.SWORD);
        case .IRON_VEIN;   #through;
        case .COPPER_VEIN; #through;
        case .SILVER_VEIN;
            return maybe(Item_Type.PICK_AXE);
    }
    return Nothing(Item_Type);
}