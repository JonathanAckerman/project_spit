handle_physics :: (dt: float)
{
    using Game;
    
    apply_gravity(*player.person.entity, dt);
    for npcs { apply_gravity(*it.entity, dt); }
    for items { apply_gravity(*it.entity, dt); }
    for equipment { apply_gravity(*it.entity, dt); }
    for containers { apply_gravity(*it.entity, dt); }

    for < grid.chunks[grid.currentChunk].cells { apply_gravity(it_index, dt); }
}

apply_gravity :: (entity: *Entity, dt: float)
{
    using Game;
    if !entity.position.exists return;

    punch := get_grid_punch(world_to_grid(entity.position.value));
    above_bedrock := entity.position.value.z < grid.worldHeight - 1;
    if above_bedrock
    {
        no_terrain_below := punch[cast(int)entity.position.value.z + 1].type == .AIR;
        if no_terrain_below then entity.position.value.z += dt;
        else 
        {
            cell := world_to_grid(entity.position.value);
            if entity.position.value.z < cast(float) cell.z then entity.position.value.z += dt;
            else entity.position.value.z = cast(float) cell.z;
        }
    }
}

apply_gravity :: (cell_index: int, dt: float)
{
    using Game;
    cell := *grid.chunks[grid.currentChunk].cells[cell_index];
    punch := get_grid_punch(cell);
    above_bedrock := cell.z < grid.worldHeight - 1;

    if above_bedrock
    {
        no_terrain_below := punch[cell.z + 1].type == .AIR;
        if cell.type != .AIR && no_terrain_below
        {
            punch[cell.z + 1].type = cell.type;
            cell.type = .AIR;
        }
    }
}