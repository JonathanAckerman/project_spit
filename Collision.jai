NewCollider :: (rect: Vector2, offset: Vector2 = .{0, 0}) -> *Collider
{
    c := New(Collider);
    c.type = .RECT;
    c.rect = rect;
    c.offset = offset;
    return c;
}

NewCollider :: (radius: float, offset: Vector2 = .{0, 0}) -> *Collider
{
    c := New(Collider);
    c.type = .CIRCLE;
    c.radius = radius;
    c.offset = offset;
    return c;
}

NewCollider :: (other: Collider) -> *Collider
{
    c := New(Collider);
    c.type = other.type;
    if other.type == .CIRCLE then c.radius = other.radius;
    if other.type == .RECT then c.rect = other.rect;
    c.offset = other.offset;
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
    offset: Vector2;
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
            water_speed :: 200;
            entity.velocity += cell.forward * water_speed * dt;
        }
    }
    if cell.block.exists
    {
        if cell.block.value.type == .FULL_WALL 
        {
            circle_gridcell(entity, cell, shouldResolve=true);
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
        color := BLUE;
        if gjksm2D(`entity, `it) 
        {
            print("%, %\n", `entity.position.value, `it.position.value);
            color = WHITE;
        }
        dbc := make_debug_circle(xy(WINDOW_WIDTH/2, WINDOW_HEIGHT/2), 2.0, color);
        defer_draw_circle(dbc);
        // if `it.collider.type == .CIRCLE then circle_circle(`entity, *`it.entity);
        // else circle_rect(`entity, *`it.entity, shouldResolve=true);
    }

    // bound to grid...again because collision with an object might have pushed us OOB
    if position.value.x < grid_to_world(Grid.left(grid))       then position.value.x = grid_to_world(Grid.left(grid));
    if position.value.y < grid_to_world(Grid.top(grid))        then position.value.y = grid_to_world(Grid.top(grid));
    if position.value.x > grid_to_world(Grid.right(grid)) - 1  then position.value.x = grid_to_world(Grid.right(grid)) - 1;
    if position.value.y > grid_to_world(Grid.bottom(grid)) - 1 then position.value.y = grid_to_world(Grid.bottom(grid)) - 1;
}

circle_circle :: (c1: *Entity, c2: *Entity) -> bool
{
    displacement := c1.position.value - c2.position.value;
    dist := length(displacement);
    if dist < c1.collider.radius + c2.collider.radius
    {
        overlap_scalar := dist - (c1.collider.radius + c2.collider.radius);
        if c1.rigidBody.value.mass < c2.rigidBody.value.mass
        {
            c1.position.value += unit_vector(displacement) * -overlap_scalar;
            return true;
        }
        else if c1.rigidBody.value.mass > c2.rigidBody.value.mass
        {
            c2.position.value += unit_vector(displacement) * overlap_scalar;
            return true;
        }
        else
        {
            c1.position.value += unit_vector(displacement) * -overlap_scalar/2;
            c2.position.value += unit_vector(displacement) * overlap_scalar/2;
            return true;
        }
    }
    return false;
}
circle_circle :: (c1: Entity, c2: Entity) -> bool
{
    displacement := c1.position.value - c2.position.value;
    dist := length(displacement);
    if dist < c1.collider.radius + c2.collider.radius return true;
    else return false;
}

circle_rect :: (c: *Entity, r: *Entity, shouldResolve: bool) -> bool
{
    rect_modified_size := (r.collider.rect)/2;
    displacement := c.position.value - (r.position.value + r.collider.offset);
    closest_x := r.position.value.x + r.collider.offset.x + clamp(displacement.x, -rect_modified_size.x, rect_modified_size.x);
    closest_y := r.position.value.y + r.collider.offset.y + clamp(displacement.y, -rect_modified_size.y, rect_modified_size.y);

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

gjksm2D :: (e1: Entity, e2: Entity) -> bool
{
    direction := e2.position.value - e1.position.value;
    simplex: [..] Vector2;
    first := support(direction, e1) - support(direction * -1, e2);
    array_add(*simplex, first);
    direction = simplex[0] * -1.0;
    for simplex
    {
        a := support(direction, e1) - support(direction * -1, e2);
        if dot(a, direction) < 0 return false;
        array_add(*simplex, a);
        if do_simplex_2D(*simplex, *direction) return true;
    }
    return false;

    support :: (direction: Vector2, e: Entity) -> Vector2
    {
        if e.collider.type == .CIRCLE
        {
            return e.position.value + unit_vector(direction) * e.collider.radius;
        }
        else // .RECT
        {
            w := e.collider.rect.x;
            h := e.collider.rect.y;
            convex_hull: [..] Vector2;
            array_add(*convex_hull, e.position.value + xy(-w, -h));
            array_add(*convex_hull, e.position.value + xy(w, -h));
            array_add(*convex_hull, e.position.value + xy(-w, h));
            array_add(*convex_hull, e.position.value + xy(w, h));

            max_elem := convex_hull[0];
            max_elem_index := 0;
            for convex_hull
            {
                if dot(direction, it) > dot(direction, max_elem)
                {
                    max_elem = it;
                    max_elem_index = it_index;
                }
            }
            return max_elem;
        }
    }

    do_simplex_2D :: (simplex: *[..] Vector2, direction: *Vector2) -> bool
    {
        assert((<<simplex).count == 2 || (<<simplex).count == 3);

        // Line case
        if (<<simplex).count == 2
        {
            ab := xyz((<<simplex)[0] - (<<simplex)[1], 1.0);
            aO := xyz((<<simplex)[1] * -1.0, 1.0);
            if Same_Direction(ab)
            {
                // simplex is ab
                <<direction = triple_product(ab, aO).xy;
                return false;
            }
            else
            {
                // simplex is a
                array_ordered_remove_by_index(simplex, 0);
                <<direction = aO.xy;
                return false;
            }
        }
        
        // Triangle case
        else // simplex.count == 3
        {
            aO := xyz((<<simplex)[2] * -1.0, 1.0);
            ab := xyz((<<simplex)[1] - (<<simplex)[2], 1.0);
            ac := xyz((<<simplex)[0] - (<<simplex)[2], 1.0);
            abc := cross(ab, ac);
            edge_ab := cross(ab, abc);
            edge_ac := cross(ac, abc);

            dbl_ab := make_debug_line((<<simplex)[0] + xy(WINDOW_WIDTH/2, WINDOW_HEIGHT/2), (<<simplex)[1] + xy(WINDOW_WIDTH/2, WINDOW_HEIGHT/2), YELLOW);
            dbl_ac := make_debug_line((<<simplex)[0] + xy(WINDOW_WIDTH/2, WINDOW_HEIGHT/2), (<<simplex)[2] + xy(WINDOW_WIDTH/2, WINDOW_HEIGHT/2), YELLOW);
            dbl_bc := make_debug_line((<<simplex)[1] + xy(WINDOW_WIDTH/2, WINDOW_HEIGHT/2), (<<simplex)[2] + xy(WINDOW_WIDTH/2, WINDOW_HEIGHT/2), YELLOW);
            defer_draw_line(dbl_ab);
            defer_draw_line(dbl_ac);
            defer_draw_line(dbl_bc);

            if Same_Direction(edge_ac)
            {
                if Same_Direction(ac)
                {
                    // simplex is ac
                    array_ordered_remove_by_index(simplex, 1);
                    <<direction = triple_product(ac, aO).xy;
                    return false;
                }
                else
                { // star case
                    if Same_Direction(ab)
                    {
                        // simplex is ab
                        array_ordered_remove_by_index(simplex, 0);
                        <<direction = triple_product(ab, aO).xy;
                        return false;
                    }
                    else
                    {
                        // simplex is a
                        array_ordered_remove_by_index(simplex, 0);
                        array_ordered_remove_by_index(simplex, 1);
                        <<direction = aO.xy;
                        return false;
                    }
                }
            }
            else
            {
                if Same_Direction(edge_ab)
                { // star case
                    if Same_Direction(ab)
                    {
                        // simplex is ab
                        array_ordered_remove_by_index(simplex, 0);
                        <<direction = triple_product(ab, aO).xy;
                        return false;
                    }
                    else
                    {
                        // simplex is a
                        array_ordered_remove_by_index(simplex, 0);
                        array_ordered_remove_by_index(simplex, 1);
                        <<direction = aO.xy;
                        return false;
                    }
                }
                else return true;
            }
        }

        Same_Direction :: (lhs: Vector3) -> bool #expand
        {
            return dot(lhs, `aO) > 0;
        }
    }
}
