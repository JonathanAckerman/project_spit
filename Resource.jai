Resource :: struct 
{
    using #as entity: Entity;
    type: Resource_Type;
    quantity: int;
    harvestRequirement: Maybe(Item_Type);
}

Item :: struct
{
    using #as entity: Entity;
    type: Item_Type;
    blueprintData: Maybe(*BlueprintData);
    onSlot: Maybe(*BlueprintSlot);
}

get_byproduct_slot_type :: (type: Item_Type) -> Slot_Type
{
    if type == 
    {
        case .FIBER; #through;
        case .WOOD_LOG;
            return .SPAN;
        case .NAILS;
            return .JOINT;
        case;
            return .INVALID;
    }
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