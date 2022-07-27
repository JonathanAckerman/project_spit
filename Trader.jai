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
    color: Color = BLACK;

    forward: Vector2 = .{1, 0};
    speed: float = 6.0;
    velocity: Vector2;

    pockets: Container;
    held: Maybe(*Entity);
    toolBelt: Maybe(Equipment);
    weaponBelt: Maybe(Equipment);
    ai: Maybe(AI);
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

AI :: struct
{
    isSpeaking := false; // make this a state enum?
    speakDuration := 4.0;
    speakTimer := 0.0;
    
    goalPosition: Vector2;
    hasGoal := false;
    goalResetTimer: float;
    goalResetDuration: float;
}