Shop :: struct
{
    owner: *Entity;
    area: [] GridCell;
    deals: [] Deal;
}

Deal :: struct
{
    price: Price;
    ware: Entity;
}

Price :: struct
{
    amount: int;
    using entityStandIn: struct
    {
        tag: Entity_Type;

        union
        {
            item: Item_Type;
            container: Container_Type;
            equipment: Equipment_Type;
        }
    }
}

NewShop :: (area: [] GridCell, deals: [] Deal, owner: *Entity) -> *Shop
{
    shop := New(Shop);
    shop.area = area;
    shop.deals = deals;
    shop.owner = owner;
    return shop;
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

NewPerson :: (pos: Vector2, ai: Maybe(AI)) -> *Entity
{
    collider := Collider.{type = .CIRCLE, radius = 20.0};
    e := NewEntityBase(pos, collider, .PERSON, ai.exists);
    e.person.ai = ai;
    e.person.color = ifx ai.exists then BROWN else BLACK;
    e.person.speed = 6.0;
    e.person.forward = .{0, -1};
    return  e;
}

Player :: struct
{
    interactRange := 100.0;
    #as entity: *Entity;
}

Collider :: struct
{
    type: Collider_Type;

    union
    {
        rect: Vector2;
        radius: float;
    }

}

Collider_Type :: enum
{
    RECT;
    CIRCLE;
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