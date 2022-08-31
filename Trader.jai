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
        item: Item_Type;
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
    speed: float = 6.0;

    held: Maybe(Holdable);
    toolBelt: Maybe(*Equipment);
    weaponBelt: Maybe(*Equipment);
    ai: Maybe(AI);
}

NewPerson :: (pos: Vector2, ai: Maybe(AI)) -> *Person
{
    person := New(Person);
    collider := NewCollider(20.0);
    person.entity = init_entity_data(pos, collider, null, 100);
    person.ai = ai;
    person.textureInfo.texture = table_find_pointer(*Textures.table, "person");
    if !ai.exists then person.textureInfo.tint = WHITE;
    else person.textureInfo.tint = ORANGE;
    return person;
}

draw_person :: (person: Person)
{
    if !person.position.exists return;

    center_pos := to_screen_space(person.position.value);
    base_size := xy(xx person.textureInfo.width, xx person.textureInfo.height) * 0.2;
    modified_size := base_size * Game.camera.zoom;
    rot := atan2(-person.forward.y, person.forward.x);
    reverse_ray_bullshit_vector := rotate_vector(modified_size/2, atan2(person.forward.y, person.forward.x));
    drawpos := center_pos - reverse_ray_bullshit_vector;
    draw_texture_centered(person.textureInfo, center_pos, person.forward, modified_size, Game.camera.zoom * 0.2);
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