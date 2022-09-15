Shop :: struct
{
    owner:      *Entity;
    area:  [..] *GridCell;
    deals: [..]  Deal;
}

Deal :: struct
{
    price: struct 
    {
        amount: int;
        itemType: Item_Type;
    }
    ware: Sellable;
}

NewShop :: (area: [] *GridCell, deals: [] Deal, owner: *Entity) -> *Shop
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
        ss_cell := to_screen_space(grid_to_world(it) + .{5, 5});
        size := xy(90, 90) * Game.camera.zoom;
        drawpos_offset_from_size := size - size;
        ss_cell += drawpos_offset_from_size / 2;
        DrawRectangleV(ss_cell, size, LIGHTGRAY);
    }
}

Person :: struct
{
    using #as entity: Entity;
    speed: float = 400.0;

    held: Maybe(Holdable);
    toolBelt: Maybe(*Equipment);
    weaponBelt: Maybe(*Equipment);
    ai: Maybe(AI);
    canCraft := false;
}

NewPerson :: (pos: Vector2, ai: Maybe(AI)) -> *Person
{
    person := New(Person);
    collider := NewCollider(20.0);
    person.entity = init_entity_data(pos, collider, null, 100);
    person.ai = ai;
    if ai.exists {
        person.animation = NewAnimation("npc/idle");
        for *person.animation.frames { it.tint = ORANGE; }
    } 
    else {
        person.animation = NewAnimation("player/idle");
    }
    return person;
}

Player :: struct
{
    interactRange := 100.0;
    using #as person: Person;
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