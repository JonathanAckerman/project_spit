Building :: struct
{
    type: Bldg_Type;

    union
    {
        using trader: struct
        {
            want: Resource_Type;
            have: Resource_Type;
        }

        using shop: struct
        {
            resource: Resource_Type;
            amount: int;
            itemType: Container_Type;
        }
    }
}

Bldg_Type :: enum
{
    TRADER;
    SHOP;
}

NewBuilding :: (type: Bldg_Type, pos: Vector2, want: Resource_Type, have: Resource_Type) -> Entity
{
    e: Entity;
    e.position = pos;
    e.collider = Collider.{type = .RECT, rect = .{100, 100}};
    e.tag = .BUILDING;
    e.building.type = .TRADER;
    e.building.want = want;
    e.building.have = have;
    return e;
}
NewBuilding :: (type: Bldg_Type, pos: Vector2, resource: Resource_Type, amount: int, selling: Container_Type) -> Entity
{
    e: Entity;
    e.position = pos;
    e.collider = Collider.{type = .RECT, rect = .{50, 50}};
    e.tag = .BUILDING;
    e.building.type = .SHOP;
    e.building.resource = resource;
    e.building.amount = amount;
    e.building.itemType = selling;
    return e;
}

Person :: struct
{
    position: Vector2 = .{200, 200};
    forward: Vector2 = .{1, 0};
    color: Color = BLACK;
    speed: float = 6.0;
    collider: Collider = Collider.{type = .CIRCLE, radius = 20};

    velocity: Vector2;

    pockets: Container;
    held: Maybe(Entity);
    toolBelt: Maybe(Equipment);
    weaponBelt: Maybe(Equipment);
}

Collider :: struct
{
    type: Collider_Type;

    union
    {
        rect: Vector2;
        radius: float;
    }

    Collider_Type :: enum
    {
        RECT;
        CIRCLE;
    }
}

Npc :: struct
{
    using person: Person;
    
    ai: struct
    {
        isSpeaking := false; // make this a state enum?
        speakDuration := 4.0;
        speakTimer := 0.0;
        
        goalPosition: Vector2;
        hasGoal := false;
        goalResetTimer: float;
        goalResetDuration: float;
    }
}