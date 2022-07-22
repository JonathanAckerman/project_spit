Building :: struct
{
    position: Vector2;
    size: int;
    bldgType: BldgType;

    BldgType :: enum
    {
        TRADER;
        SHOP;
    }

    union
    {
        using trader: struct
        {
            want: Resource_ID;
            have: Resource_ID;
        }

        using shop: struct
        {
            resource: Resource_ID;
            amount: int;
            item: Entity;
        }
    }
}

Person :: struct
{
    position: Vector2 = .{200, 200};
    forward: Vector2 = .{1, 0};
    radius: int = 20;
    color: Color = BLACK;
    speed: float = 6.0;

    velocity: Vector2;

    pockets: Container;
    held: Maybe(Entity);
    toolBelt: Maybe(Equipment);
    weaponBelt: Maybe(Equipment);
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