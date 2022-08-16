NewCollider :: (rect: Vector2) -> *Collider
{
    c := New(Collider);
    c.type = .RECT;
    c.rect = rect;
    return c;
}

NewCollider :: (radius: float) -> *Collider
{
    c := New(Collider);
    c.type = .CIRCLE;
    c.radius = radius;
    return c;
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

RigidBody :: struct
{
    mass: int;
}

handle_collision :: (using entity: *Entity)
{
    using Game;
    if !position.exists return;

    // bound to grid
    if position.value.x < grid_to_world(Grid.left(grid)) then position.value.x = grid_to_world(Grid.left(grid));
    if position.value.y < grid_to_world(Grid.top(grid)) then position.value.y = grid_to_world(Grid.top(grid));
    if position.value.x > grid_to_world(Grid.right(grid)) then position.value.x = grid_to_world(Grid.right(grid)) - 1;
    if position.value.y > grid_to_world(Grid.bottom(grid)) then position.value.y = grid_to_world(Grid.bottom(grid)) - 1;

    if !rigidBody.exists return;

    for resources   if it.rigidBody.exists check_and_resolve();
    for items       if it.rigidBody.exists check_and_resolve();
    for containers  if it.rigidBody.exists check_and_resolve();
    for equipment   if it.rigidBody.exists check_and_resolve();
    for npcs        if it.rigidBody.exists check_and_resolve();

    check_and_resolve :: () #expand
    {
        if `collider.type == .CIRCLE
        {
            if `it.collider.type == .CIRCLE then circle_circle(`entity, `it.entity);
            else circle_rect(`entity, `it.entity);
        }
        else
        {
            if `it.collider.type == .CIRCLE then circle_rect(`it.entity, `entity);
            else rect_rect(`entity, `it.entity);
        }
    }

    circle_circle :: (c1: Entity, c2: Entity)
    {
        dist := length(c1.position.value - c2.position.value);
        if dist < c1.collider.radius + c2.collider.radius
        {
            // resolve
            print("COLLIDING CIRCLE CIRCLE");
        }
    }

    circle_rect :: (c: Entity, r: Entity) // @TEMP: just pretend circle is a rect
    {
        cleft   := c.position.value.x - c.collider.radius;
        cright  := c.position.value.x + c.collider.radius;
        ctop    := c.position.value.y - c.collider.radius;
        cbottom := c.position.value.y + c.collider.radius;

        rleft   := r.position.value.x - r.collider.rect.x/2;
        rright  := r.position.value.x + r.collider.rect.x/2;
        rtop    := r.position.value.y - r.collider.rect.y/2;
        rbottom := r.position.value.y + r.collider.rect.y/2;

        left  := cleft > rright;
        right := cright < rleft;
        above := cbottom < rtop;
        below := ctop > rbottom;

        if !(left || right || above || below)
        {
            // resolve
            print("COLLIDING CIRCLE RECT");
        }
    }

    rect_rect :: (r1: Entity, r2: Entity)
    {
        r1_left   := r2.position.value.x - r2.collider.rect.x/2;
        r1_right  := r2.position.value.x + r2.collider.rect.x/2;
        r1_top    := r2.position.value.y - r2.collider.rect.y/2;
        r1_bottom := r2.position.value.y + r2.collider.rect.y/2;

        r2_left   := r2.position.value.x - r2.collider.rect.x/2;
        r2_right  := r2.position.value.x + r2.collider.rect.x/2;
        r2_top    := r2.position.value.y - r2.collider.rect.y/2;
        r2_bottom := r2.position.value.y + r2.collider.rect.y/2;

        left  := r1_left > r2_right;
        right := r1_right < r2_left;
        above := r1_bottom < r2_top;
        below := r1_top > r2_bottom;

        if !(left || right || above || below)
        {
            // resolve
            print("COLLIDING RECT RECT");
        }
    }
}