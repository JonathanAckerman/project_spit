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
        size_modifier := 1.0 - (xx it.z - (Game.camera.position.z + 1)) * 0.1;
        drawpos_offset_from_size := size - size * size_modifier;
        ss_cell += drawpos_offset_from_size / 2;
        DrawRectangleV(ss_cell, size * size_modifier, LIGHTGRAY);
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

NewPerson :: (pos: Vector3, ai: Maybe(AI)) -> *Person
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

    center_pos := to_screen_space(person.position.value.xy);
    size_modifier := 1.0 - (xx person.position.value.z - (Game.camera.position.z + 1)) * 0.1;
    base_size := xy(xx person.textureInfo.width, xx person.textureInfo.height) * 0.2;
    modified_size := base_size * Game.camera.zoom * size_modifier;
    rot := atan2(-person.forward.y, person.forward.x);
    reverse_ray_bullshit_vector := rotate_vector(modified_size/2, atan2(person.forward.y, person.forward.x));
    drawpos := center_pos - reverse_ray_bullshit_vector;

    tint := person.textureInfo.tint;
    tint.r = xx (tint.r * size_modifier);
    tint.g = xx (tint.g * size_modifier);
    tint.b = xx (tint.b * size_modifier);
    // DrawTextureEx(person.textureInfo.texture, drawpos, -rad2deg(rot), Game.camera.zoom * size_modifier * 0.2, tint);
    draw_texture_centered(person.textureInfo, center_pos, person.forward.xy, modified_size, Game.camera.zoom * size_modifier * 0.2);
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
    
    goalPosition: Vector3;
    hasGoal := false;
    goalResetTimer: float;
    goalResetDuration: float;
}