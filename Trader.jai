Building :: struct
{
    position: Vector2;
    size: int;
    bldg_type: Bldg_Type;

    Bldg_Type :: enum
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
            item: Item;
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

    pockets: [] int;
    held: Maybe(Item);
    tool_belt: Maybe(Item);
    weapon_belt: Maybe(Item);
}

Npc :: struct
{
    using person: Person;
    
    ai: struct
    {
        is_speaking := false; // make this a state enum?
        speak_duration := 4.0;
        speak_timer := 0.0;
        
        goal_position: Vector2;
        has_goal := false;
        goal_reset_timer: float;
        goal_reset_duration: float;
    }
}