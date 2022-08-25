//
// Base Concept type
//
Concept :: struct
{
    tag: Entity_Type;
    data: *void;
}

//
// Anything the player can hold in their arms (held slot)
//
Holdable :: struct {
    tag: Entity_Type;
    union {
        #as item: *Item;
        #as container: *Container;
        #as equipment: *Equipment;
    }
}
as_holdable :: (item: *Item) -> Holdable {
    holdable: Holdable;
    holdable.item = item;
    holdable.tag  = .ITEM;
    return holdable;
}
as_holdable :: (container: *Container) -> Holdable {
    holdable: Holdable;
    holdable.container = container;
    holdable.tag       = .CONTAINER;
    return holdable;
}
as_holdable :: (equipment: *Equipment) -> Holdable {
    holdable: Holdable;
    holdable.equipment = equipment;
    holdable.tag       = .EQUIPMENT;
    return holdable;
}
as_holdable :: (concept: Concept) -> Holdable {
    holdable: Holdable;
    holdable.tag = concept.tag;
    if concept.tag == {
        case .ITEM;
            holdable.item = cast(*Item) concept.data;
        case .CONTAINER;
            holdable.container = cast(*Container) concept.data;
        case .EQUIPMENT;
            holdable.equipment = cast(*Equipment) concept.data;
    }
    return holdable;
}
get_holdable_entity :: (holdable: Holdable) -> *Entity
{
    if holdable.tag ==
    {
        case .ITEM;
            return holdable.item;
        case .CONTAINER;
            return holdable.container;
        case .EQUIPMENT;
            return holdable.equipment;
    }
    return null;
}

//
// Anything fungible between player and shops
//
Sellable :: struct {
    tag: Entity_Type;
    union {
        #as item:      *Item;
        #as container: *Container;
        #as equipment: *Equipment; 
    }
    position: Vector3;
}
as_sellable :: (item: *Item) -> Sellable {
    concept: Sellable;
    concept.item     = item;
    concept.tag      = .ITEM;
    concept.position = item.position.value;
    return concept;
}
as_sellable :: (container: *Container) -> Sellable {
    concept: Sellable;
    concept.container = container;
    concept.tag       = .CONTAINER;
    concept.position  = container.position.value;
    return concept;
}
as_sellable :: (equipment: *Equipment) -> Sellable {
    concept: Sellable;
    concept.equipment = equipment;
    concept.tag       = .EQUIPMENT;
    concept.position  = equipment.position.value;
    return concept;
}

//
// Anything a container might hold
//
Containable :: struct {
    tag: Entity_Type;
    union {
        #as item:      *Item;
        #as equipment: *Equipment; 
    }
    position: Vector3;
}
as_containable :: (item: *Item) -> Containable {
    concept: Containable;
    concept.item     = item;
    concept.tag      = .ITEM;
    concept.position = item.position.value;
    return concept;
}
as_containable :: (equipment: *Equipment) -> Containable {
    concept: Containable;
    concept.equipment = equipment;
    concept.tag       = .EQUIPMENT;
    concept.position  = equipment.position.value;
    return concept;
}

as_concept :: (sellable: Sellable) -> Concept
{
    concept: Concept;
    concept.tag = sellable.tag;
    if sellable.tag ==
    {
        case .ITEM;
            concept.data = sellable.item;
        case .CONTAINER;
            concept.data = sellable.container;
        case .EQUIPMENT;
            concept.data = sellable.equipment;
    }
    return concept;
}