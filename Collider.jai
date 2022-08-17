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

    for resources   if it.position.exists && it.rigidBody.exists check_and_resolve();
    for items       if it.position.exists && it.rigidBody.exists check_and_resolve();
    for containers  if it.position.exists && it.rigidBody.exists check_and_resolve();
    for equipment   if it.position.exists && it.rigidBody.exists check_and_resolve();
    for npcs        if it.position.exists && it.rigidBody.exists check_and_resolve();

    check_and_resolve :: () #expand
    {
        if `collider.type == .CIRCLE
        {
            if `it.collider.type == .CIRCLE then circle_circle(`entity, *`it.entity);
            else circle_rect(`entity, *`it.entity);
        }
        else
        {
            if `it.collider.type == .CIRCLE then circle_rect(*`it.entity, `entity);
            else rect_rect(`entity, *`it.entity);
        }
    }

    circle_circle :: (c1: *Entity, c2: *Entity)
    {
        displacement := c1.position.value - c2.position.value;
        dist := length(displacement);
        if dist < c1.collider.radius + c2.collider.radius
        {
            overlap_scalar := dist - (c1.collider.radius + c2.collider.radius);
            if c1.rigidBody.value.mass < c2.rigidBody.value.mass
            {
                c1.position.value += unit_vector(displacement) * -overlap_scalar;
            }
            else if c1.rigidBody.value.mass > c2.rigidBody.value.mass
            {
                c2.position.value += unit_vector(displacement) * overlap_scalar;
            }
            else
            {
                c1.position.value += unit_vector(displacement) * -overlap_scalar/2;
                c2.position.value += unit_vector(displacement) * overlap_scalar/2;
            }
        }
    }

    circle_rect :: (c: *Entity, r: *Entity)
    {
        size_modifier := 1.0 - (r.position.value.z - cast(int) Game.camera.position.z) * 0.1;
        rleft   := r.position.value.x - (r.collider.rect.x * Game.camera.zoom * size_modifier * 0.5)/2;
        rright  := r.position.value.x + (r.collider.rect.x * Game.camera.zoom * size_modifier * 0.5)/2;
        rtop    := r.position.value.y - (r.collider.rect.y * Game.camera.zoom * size_modifier * 0.5)/2;
        rbottom := r.position.value.y + (r.collider.rect.y * Game.camera.zoom * size_modifier * 0.5)/2;

        rect_modified_size := (r.collider.rect * Game.camera.zoom * size_modifier * 0.5)/2;
        displacement := c.position.value - r.position.value;
        closest_x := r.position.value.x + clamp(displacement.x, -rect_modified_size.x, rect_modified_size.x);
        closest_y := r.position.value.y + clamp(displacement.y, -rect_modified_size.y, rect_modified_size.y);

        circle_to_closest := c.position.value.xy - xy(closest_x, closest_y); 
        if length(circle_to_closest) < c.collider.radius
        {
            overlap_scalar := c.collider.radius - length(circle_to_closest);
            if c.rigidBody.value.mass < r.rigidBody.value.mass
            {
                c.position.value.xy += unit_vector(circle_to_closest) * overlap_scalar;
            }
            else if c.rigidBody.value.mass > r.rigidBody.value.mass
            {
                r.position.value.xy += unit_vector(circle_to_closest) * -overlap_scalar;
            }
            else
            {
                c.position.value.xy += unit_vector(circle_to_closest) * overlap_scalar/2;
                r.position.value.xy += unit_vector(circle_to_closest) * -overlap_scalar/2;
            }
        }
    }

    rect_rect :: (r1: *Entity, r2: *Entity)
    {
        size_modifier := 1.0 - (r1.position.value.z - cast(int) Game.camera.position.z) * 0.1;
        r1_left   := r1.position.value.x - (r1.collider.rect.x * Game.camera.zoom * size_modifier * 0.5)/2;
        r1_right  := r1.position.value.x + (r1.collider.rect.x * Game.camera.zoom * size_modifier * 0.5)/2;
        r1_top    := r1.position.value.y - (r1.collider.rect.y * Game.camera.zoom * size_modifier * 0.5)/2;
        r1_bottom := r1.position.value.y + (r1.collider.rect.y * Game.camera.zoom * size_modifier * 0.5)/2;

        r2_left   := r2.position.value.x - (r2.collider.rect.x * Game.camera.zoom * size_modifier * 0.5)/2;
        r2_right  := r2.position.value.x + (r2.collider.rect.x * Game.camera.zoom * size_modifier * 0.5)/2;
        r2_top    := r2.position.value.y - (r2.collider.rect.y * Game.camera.zoom * size_modifier * 0.5)/2;
        r2_bottom := r2.position.value.y + (r2.collider.rect.y * Game.camera.zoom * size_modifier * 0.5)/2;

        left  := r1_left > r2_right;
        right := r1_right < r2_left;
        above := r1_bottom < r2_top;
        below := r1_top > r2_bottom;

        if !(left || right || above || below)
        {
        }
    }
}