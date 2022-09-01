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

bound_to_grid :: (using entity: *Entity)
{
    using Game;
    if position.value.x < grid_to_world(Grid.left(grid))   then position.value.x = grid_to_world(Grid.left(grid));
    if position.value.y < grid_to_world(Grid.top(grid))    then position.value.y = grid_to_world(Grid.top(grid));
    if position.value.x > grid_to_world(Grid.right(grid)) - 1  then position.value.x = grid_to_world(Grid.right(grid)) - 1;
    if position.value.y > grid_to_world(Grid.bottom(grid)) - 1 then position.value.y = grid_to_world(Grid.bottom(grid)) - 1;
}

handle_collision :: (using entity: *Entity)
{
    using Game;
    if !position.exists return;

    // water pushes things
    cell := world_to_grid(entity.position.value);
    if cell.type == .WATER
    {
        if entity.collider.type == .CIRCLE && circle_gridcell(entity, cell, shouldResolve=false)
        {
            water_speed :: 300;
            entity.velocity += cell.forward * water_speed * dt;
        }
    }

    if !rigidBody.exists return;

    for resources   if it.position.exists && it.rigidBody.exists check_and_resolve();
    for items       if it.position.exists && it.rigidBody.exists check_and_resolve();
    for containers  if it.position.exists && it.rigidBody.exists check_and_resolve();
    for equipment   if it.position.exists && it.rigidBody.exists check_and_resolve();
    for npcs        if it.position.exists && it.rigidBody.exists check_and_resolve();

    check_and_resolve :: () #expand
    {
        if `it.collider.type == .CIRCLE then circle_circle(`entity, *`it.entity, shouldResolve=true);
        else circle_rect(`entity, *`it.entity, shouldResolve=true);
    }

    circle_circle :: (c1: *Entity, c2: *Entity, shouldResolve: bool) -> bool
    {
        displacement := c1.position.value - c2.position.value;
        dist := length(displacement);
        if dist < c1.collider.radius + c2.collider.radius
        {
            overlap_scalar := dist - (c1.collider.radius + c2.collider.radius);
            if c1.rigidBody.value.mass < c2.rigidBody.value.mass
            {
                if shouldResolve then c1.position.value += unit_vector(displacement) * -overlap_scalar;
                return true;
            }
            else if c1.rigidBody.value.mass > c2.rigidBody.value.mass
            {
                if shouldResolve then c2.position.value += unit_vector(displacement) * overlap_scalar;
                return true;
            }
            else
            {
                if shouldResolve
                {
                    c1.position.value += unit_vector(displacement) * -overlap_scalar/2;
                    c2.position.value += unit_vector(displacement) * overlap_scalar/2;
                }
                return true;
            }
        }
        return false;
    }

    circle_rect :: (c: *Entity, r: *Entity, shouldResolve: bool) -> bool
    {
        rect_modified_size := (r.collider.rect * 0.5)/2;
        displacement := c.position.value - r.position.value;
        closest_x := r.position.value.x + clamp(displacement.x, -rect_modified_size.x, rect_modified_size.x);
        closest_y := r.position.value.y + clamp(displacement.y, -rect_modified_size.y, rect_modified_size.y);

        circle_to_closest := c.position.value - xy(closest_x, closest_y);
        if length(circle_to_closest) < c.collider.radius
        {
            overlap_scalar := c.collider.radius - length(circle_to_closest);
            if c.rigidBody.value.mass < r.rigidBody.value.mass
            {
                if shouldResolve then c.position.value += unit_vector(circle_to_closest) * overlap_scalar;
                return true;
            }
        }
        return false;
    }

    circle_gridcell :: (c: *Entity, g: *GridCell, shouldResolve: bool) -> bool
    {
        gpos := grid_to_world(g, true);

        half_size := xy(Game.grid.cellSize/2, Game.grid.cellSize/2);
        displacement := c.position.value - gpos;
        closest_x := gpos.x + clamp(displacement.x, -half_size.x, half_size.x);
        closest_y := gpos.y + clamp(displacement.y, -half_size.y, half_size.y);

        circle_to_closest := c.position.value - xy(closest_x, closest_y);
        if length(circle_to_closest) < c.collider.radius
        {
            overlap_scalar := c.collider.radius - length(circle_to_closest);
            if shouldResolve then c.position.value += unit_vector(circle_to_closest) * overlap_scalar;
            return true;
        }
        return false;
    }

    // bound to grid...again because collision with an object might have pushed us OOB
    if position.value.x < grid_to_world(Grid.left(grid))   then position.value.x = grid_to_world(Grid.left(grid));
    if position.value.y < grid_to_world(Grid.top(grid))    then position.value.y = grid_to_world(Grid.top(grid));
    if position.value.x > grid_to_world(Grid.right(grid)) - 1  then position.value.x = grid_to_world(Grid.right(grid)) - 1;
    if position.value.y > grid_to_world(Grid.bottom(grid)) - 1 then position.value.y = grid_to_world(Grid.bottom(grid)) - 1;
}