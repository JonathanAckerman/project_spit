_Entity_ID: u64 = 0;

Entity :: struct
{
    position: Maybe(Vector2);
    velocity: Vector2;
    forward: Vector2 = .{0, -1};

    collider: *Collider;
    rigidBody: Maybe(RigidBody);

    id: u64;
    textureInfo: TextureInfo;
    owner: Maybe(*Person);
    entityType: Entity_Type;
}

Entity_Type :: enum
{
    RESOURCE;
    ITEM;
    CONTAINER;
    EQUIPMENT;
    PERSON;
}

init_entity_data :: (pos: Vector2, collider: *Collider, owner: *Person = null, mass: int = 0) -> Entity
{
    e: Entity;
    e.position.value = pos;
    e.position.exists = true;
    e.collider = collider;
    rb: RigidBody;
    rb.mass = mass;
    if mass > 0 then e.rigidBody  = maybe(rb);
    if owner != null then e.owner = maybe(owner);
    else e.owner = Nothing(*Person);
    e.id = _Entity_ID;
    _Entity_ID += 1;
    return e;
}