Shop :: struct
{
    owner: *Entity;
    area: [..] GridCell;
    deals: [..] Deal;
}

Deal :: struct
{
    price: Price;
    ware: Any;
    ware_tag: Entity_Type;
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
    for area array_add(*shop.area, it);
    for deals array_add(*shop.deals, it);
    shop.owner = owner;
    return shop;
}

draw_shop :: (shop : *Shop)
{
    for shop.area
    {
        ss_cell := to_screen_space(grid_to_world(it).xy + .{5, 5});
        size := xy(90, 90) * Game.camera.zoom;
        size_modifier := 1.0 - (it.z - cast(int) Game.camera.position.z) * 0.1;
        drawpos_offset_from_size := size - size * size_modifier;
        ss_cell += drawpos_offset_from_size / 2;
        DrawRectangleV(ss_cell, size * size_modifier, LIGHTGRAY);
    }
}

Person :: struct
{
    using #as entity: Entity;

    forward: Vector3 = .{1, 0, 0};
    speed: float = 6.0;
    velocity: Vector3;

    held: Maybe(Holdable); // to cast between them I need held to be a *Holdable since you cant cast to structs, otherwise I have to construct a new Holdable everytime I want to hold a new item/container/equipment/etc.
    toolBelt: Maybe(*Equipment);
    weaponBelt: Maybe(*Equipment);
    ai: Maybe(AI);
}

NewPerson :: (pos: Vector3, ai: Maybe(AI)) -> *Person
{
    person := New(Person);
    collider := Collider.{type = .CIRCLE, radius = 20.0};
    person.entity = init_entity_data(pos, collider);
    person.forward = .{0, -1, 0};
    person.speed = 6.0;
    person.ai = ai;
    return person;
}

draw_person :: (person: Person)
{
    ss_person := to_screen_space(person.position.value.xy);
    size_modifier := 1.0 - (person.position.value.z - cast(int) Game.camera.position.z) * 0.1;
    color := ifx person.ai.exists then ORANGE else BLACK;
    DrawCircle(xx ss_person.x, xx ss_person.y, xx person.collider.radius * Game.camera.zoom * size_modifier, color);
    front := ss_person + person.forward.xy * cast(float) person.collider.radius * Game.camera.zoom * size_modifier;
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
    
    goalPosition: Vector3;
    hasGoal := false;
    goalResetTimer: float;
    goalResetDuration: float;
}