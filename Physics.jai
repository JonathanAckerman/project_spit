handle_physics :: (dt: float)
{
    using Game;
    
    apply_gravity(*player.person.entity, dt);

    for npc: npcs
    {
        apply_gravity(*npc.entity, dt);
    }

    for item: items
    {
        apply_gravity(*item.entity, dt);
    }
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