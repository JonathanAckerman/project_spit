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

handle_collision :: ()
{
    using Game;

    // bound player to grid
    if player.position.value.x < grid_to_world(Grid.left(grid)) then player.position.value.x = grid_to_world(Grid.left(grid));
    if player.position.value.y < grid_to_world(Grid.top(grid)) then player.position.value.y = grid_to_world(Grid.top(grid));
    if player.position.value.x > grid_to_world(Grid.right(grid)) then player.position.value.x = grid_to_world(Grid.right(grid)) - 1;
    if player.position.value.y > grid_to_world(Grid.bottom(grid)) then player.position.value.y = grid_to_world(Grid.bottom(grid)) - 1;
}