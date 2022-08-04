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
    using #as entity: Entity;
    color: Color = BLACK;

    forward: Vector2 = .{1, 0};
    speed: float = 6.0;
    velocity: Vector2;

    held: Maybe(Holdable); // to cast between them I need held to be a *Holdable since you cant cast to structs, otherwise I have to construct a new Holdable everytime I want to hold a new item/container/equipment/etc.
    toolBelt: Maybe(*Equipment);
    weaponBelt: Maybe(*Equipment);
    ai: Maybe(AI);
}

NewPerson :: (pos: Vector2, ai: Maybe(AI)) -> *Person
{
    person := New(Person);
    collider := Collider.{type = .CIRCLE, radius = 20.0};
    person.entity = init_entity_data(pos, collider);
    person.color = ifx ai.exists then BROWN else BLACK;
    person.forward = .{0, -1};
    person.speed = 6.0;
    person.ai = ai;
    return person;
}

draw_person :: (person: Person)
{
    ss_person := to_screen_space(person.position.value);
    DrawCircle(xx ss_person.x, xx ss_person.y, xx person.collider.radius * Game.camera.zoom, person.color);
    front := ss_person + person.forward * cast(float) person.collider.radius * Game.camera.zoom;
    DrawLineEx(xx ss_person, xx front, 2.0, WHITE);
}

Player :: struct
{
    interactRange := 100.0;
    using #as person: Person;
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