_Entity_ID: u64 = 0;

Entity :: struct
{
    position: Maybe(Vector3);
    velocity: Vector3;
    forward: Vector3 = .{0, -1, 0};

    collider: *Collider;
    rigidBody: Maybe(RigidBody);

    id: u64;
    texture: Maybe(*Texture2D);
    owner: Maybe(*Person);
}

Entity_Type :: enum
{
    RESOURCE;
    ITEM;
    CONTAINER;
    EQUIPMENT;
    PERSON;
}

init_entity_data :: (pos: Vector3, collider: *Collider, owner: *Person = null, mass: int = 0) -> Entity
{
    e: Entity;
    e.position.value = pos;
    e.position.exists = true;
    e.collider = collider;
    rb: RigidBody;
    rb.mass = mass;
    if mass > 0 then e.rigidBody = NewMaybe(rb);
    if owner != null then e.owner = NewMaybe(owner);
    else e.owner = Nothing(*Person);
    e.id = _Entity_ID;
    _Entity_ID += 1;
    return e;
}