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

Person :: struct
{
    position: Vector2 = .{200, 200};
    collider: Collider = Collider.{type = .CIRCLE, radius = 20};
    forward: Vector2 = .{1, 0};
    color: Color = BLACK;
    speed: float = 6.0;

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