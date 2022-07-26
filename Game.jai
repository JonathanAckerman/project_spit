Game: struct 
{
    resetting: bool;
    paused: bool;
    debug: bool;

    player: struct 
    {
        using person: Person;

        // @TODO: not a fan of this at all
        tryHarvest := false;
        tryTrade := false;
    }

    camera: struct
    {
        position: Vector2;
    }

    resourceList:       [..] Resource;
    buildings:          [..] Entity;
    itemsOnGround:      [..] Entity;
    containersOnGround: [..] Entity;
    equipmentOnGround:  [..] Entity;
    npcs:               [..] Npc;
}

Debug: struct
{
    c: DebugCursor;
    line: string;
    history: [..] string;
    historyIndex := -1;

    font: Font;
    fontSize := 28.0;
    fontSpacing := 1.0;

    listCommands := false;
    commandList: [] string = .[
        "SPAWN BASKET",
        "SPAWN CHEST",
        "SPAWN AXE",
        "SPAWN TOOLBELT",
        "SPAWN WEAPONBELT",
        "FILL POCKETS",
        "MUSK",
        "TP",
        "GOTTAGOFAST",
        "REPOP RESOURCES",
        "RESET"
    ];
}

game_loop :: inline ()
{
    using Game;
    dt := GetFrameTime();

    // Input
    handle_input();

    camera_vector: Vector2;
    // Simulate
    {
        camera.position = player.position;

        // collision
        {
            for buildings
            {
                if player.position.x + player.collider.radius > it.position.x - it.collider.rect.x/2 &&
                player.position.x - player.collider.radius < it.position.x + it.collider.rect.x/2 &&
                player.position.y + player.collider.radius > it.position.y - it.collider.rect.y/2 &&
                player.position.y - player.collider.radius < it.position.y + it.collider.rect.y/2
                {
                    player.position += unit_vector(player.position - it.position) * length(player.velocity);
                }
            }
        }

        player.position += player.velocity;  
        if length(player.velocity) != 0 then player.forward = unit_vector(player.velocity);

        player.velocity = .{};
        camera_vector = .{WINDOW_WIDTH/2, WINDOW_HEIGHT/2} - player.position;

        harvestNearestResource :: ()
        {
            using Game;
            nearest_index := 0;
            min_dist := length(resourceList[0].position - player.position);
            for resourceList
            {
                dist := length(it.position - player.position);
                if dist < min_dist
                {
                    min_dist = dist;
                    nearest_index = it_index;
                }
            }
            if min_dist < 100
            {
                resource := resourceList[nearest_index];

                if resource.type == .WOOD
                {
                    if player.toolBelt.exists
                    {
                        has_axe := false;
                        for player.toolBelt.value.contents
                        {
                            if it.item.type == .LUMBER_AXE then has_axe = true;
                        }
                        if !has_axe return;
                    }
                    else return;
                }

                has_harvested := false;
                // try to fill held first
                if player.held.exists && player.held.value.tag == .CONTAINER
                {
                    basket := *player.held.value.container;
                    if basket.type == .BASKET
                    {
                        basket_weight := compute_container_weight(basket);
                        if basket_weight < basket.capacity
                        {
                            // calculate the max that we can add to the basket
                            amount := ifx basket_weight + resource.quantity > basket.capacity
                                then basket.capacity - basket_weight
                                else resource.quantity;
                            basket.contents[resource.type] += amount;
                            array_unordered_remove_by_index(*resourceList, nearest_index);
                            has_harvested = true;
                        }
                    }
                }

                // pockets can only hold 10 of each resource
                if !has_harvested && player.pockets.contents[resource.type] < 10
                {
                    player.pockets.contents[resource.type] += resource.quantity;
                    player.pockets.contents[resource.type] = min(player.pockets.contents[resource.type], 10);
                    array_unordered_remove_by_index(*resourceList, nearest_index);
                }
            }
        }
        if player.tryHarvest then harvestNearestResource();

        tradeWithNearestTrader :: ()
        {
            using Game;
            // get nearest trader
            nearest, dist := get_closest_bldg_to_player(.TRADER);

            // check trade range
            trader_range := compute_interact_range(nearest);
            if dist < trader_range
            {
                containers := get_nearby_containers();
                from: *Container;
                // look in all nearby inventories for wanted resource
                found_wanted_resource := false;
                for containers
                {
                    if it.contents[nearest.building.want] > 0
                    {
                        from = it;
                        found_wanted_resource = true;
                        break;
                    }
                }

                if !found_wanted_resource return;

                // look for a valid inventory to put it into
                if containers[0].contents[nearest.building.have] < 10
                {
                    from.contents[nearest.building.want] -= 1;
                    containers[0].contents[nearest.building.have] += 1;
                }
                else
                {
                    for containers
                    {
                        if it_index == 0 continue; // skip the player's pockets since it functions differently
                        if compute_container_weight(it) < it.capacity
                        {
                            from.contents[nearest.building.want] -= 1;
                            it.contents[nearest.building.have] += 1;
                            break;
                        }
                    }
                }
            }
        }
        if player.tryTrade then tradeWithNearestTrader();

        buyFromNearestShop :: ()
        {
            using Game;
            nearest_shop, dist := get_closest_bldg_to_player(.SHOP);
            // check shop range
            shop_range := compute_interact_range(nearest_shop);
            if dist < shop_range
            {
                nearby_containers := get_nearby_containers();

                cost := nearest_shop.building.amount;
                total_available := 0;
                for nearby_containers { total_available += it.contents[nearest_shop.building.resource]; }
                if total_available >= cost // we can afford it
                {
                    // pay the cost
                    paid := 0;
                    for nearby_containers
                    {
                        if paid < cost
                        {
                            containerAmount := *it.contents[nearest_shop.building.resource];
                            if <<containerAmount >= cost - paid
                            {
                                <<containerAmount -= cost - paid;
                                break;
                            }
                            else
                            {
                                paid += <<containerAmount;
                                <<containerAmount = 0;
                            }
                        }
                    }

                    item := NewContainer(nearest_shop.building.itemType, Collider.{type = .RECT, rect = .{20, 30}});
                    if !player.held.exists 
                    {
                        newHeld: Maybe(Entity);
                        newHeld.exists = true;
                        newHeld.value = item;
                        player.held = newHeld;
                    }
                    else // drop the item nearby
                    {
                        // @TODO: make size (world or ui) a lookup rather than state on the object
                        item.position = nearest_shop.position + .{0, -100};
                        array_add(*itemsOnGround, item);
                    }
                }
            }
        }
        if player.tryTrade then buyFromNearestShop();

        talkToNearestNPC :: ()
        {
            using Game;
            nearest_index := 0;
            min_dist := length(npcs[0].position - player.position);
            for npcs
            {
                dist := length(it.position - player.position);
                if dist < min_dist
                {
                    min_dist = dist;
                    nearest_index = it_index;
                }
            }
            nearest := *npcs[nearest_index];
            if min_dist <= 150
            {
                nearest.ai.isSpeaking = true;
                nearest.ai.speakTimer = nearest.ai.speakDuration;
            }
        }
        if player.tryTrade then talkToNearestNPC();

        // npc ai
        {
            for* npc: npcs
            {
                if !npc.ai.hasGoal && npc.ai.goalResetTimer <= 0.0
                {
                    x := random_get_within_range(npc.position.x - 200, npc.position.x + 200);
                    y := random_get_within_range(-npc.position.y - 200, npc.position.y + 200);
                    check_collision := true;
                    while check_collision
                    {
                        collided := false;
                        for bldg: Game.buildings
                        {
                            if x > bldg.position.x - bldg.collider.rect.x/2 &&
                            x < bldg.position.x + bldg.collider.rect.x/2 &&
                            y > bldg.position.y - bldg.collider.rect.y/2 && 
                            y < bldg.position.y + bldg.collider.rect.y/2
                            {
                                // try again with new position
                                x = random_get_within_range(npc.position.x - 200, npc.position.x + 200);
                                y = random_get_within_range(-npc.position.y - 200, npc.position.y + 200);
                                collided = true;
                                break;
                            }
                        }
                        if !collided then check_collision = false;
                    }
                    npc.ai.goalPosition = xy(x, y);
                    npc.ai.goalResetTimer = 0.0;
                    npc.ai.goalResetDuration = 0.0;
                    npc.ai.hasGoal = true;
                }
                else if npc.ai.hasGoal
                {
                    direction := npc.ai.goalPosition - npc.position;
                    npc.velocity = unit_vector(direction) * npc.speed;
                    if length(npc.velocity) != 0 then npc.forward = unit_vector(npc.velocity);

                    if length(direction) < 1.0
                    {
                        npc.ai.hasGoal = false;
                        // goal reached, reset timer
                        if npc.ai.goalResetDuration <= 0.0
                        {
                            npc.ai.goalResetDuration = random_get_within_range(3.0, 7.5); 
                            npc.ai.goalResetTimer = npc.ai.goalResetDuration;
                        }
                    }
                }
                else // goalResetTimer > 0.0
                {
                    npc.ai.goalResetTimer -= dt;
                    npc.velocity = .{};
                    npc.ai.hasGoal = false;
                }

                // interrupt goal and turn towards the player when they get close
                npc_to_player := player.position - npc.position;
                dist := length(npc_to_player);
                if dist < 150
                {
                    npc.forward = unit_vector(npc_to_player);
                    npc.velocity = .{};

                    // only draw text when player is close enough
                    if npc.ai.isSpeaking
                    {
                        pos := npc.position + camera_vector;
                        if npc.ai.speakTimer > 0.0
                        {
                            npc.ai.speakTimer -= dt;
                            DrawText("HI", xx (pos.x + 30), xx (pos.y - 10), 20, BLACK);
                        }
                    }
                }
                npc.position += npc.velocity;
            }
        }
    }

    // Draw
    {
        BeginDrawing();
        ClearBackground(WHITE);
        
        // draw map
        {
            top := -1000.0;
            left := -1000.0;
            for row: 0..20
            {
                ss_rect := xy(left, -1000.0 + row * 100.0) + camera_vector;
                DrawLineV(xx ss_rect, xx ss_rect + xy(2000, 0), LIGHTGRAY);
            }
            for col: 0..20
            {
                ss_rect := xy(-1000.0 + col * 100.0, top) + camera_vector;
                DrawLineV(xx ss_rect, xx ss_rect + xy(0, 2000), LIGHTGRAY);
            }
        }

        // draw resources
        {
            for resourceList
            {
                ss_resource := it.position + camera_vector;
                resource_color := get_resource_color(it.type);
                DrawCircle(xx ss_resource.x, xx ss_resource.y, xx it.quantity, resource_color);
            }
        }

        // draw buildings
        {
            for buildings
            {
                drawpos := it.position - xy(it.collider.rect.x/2.0, it.collider.rect.y/2.0);
                DrawRectangleV(drawpos + camera_vector, xy(xx it.collider.rect.x, xx it.collider.rect.y), BLACK);

                if it.building.type ==
                {
                    case .TRADER;
                        want_color := get_resource_color(it.building.want);
                        have_color := get_resource_color(it.building.have);
                        DrawRectangleV((it.position - .{16, 8}) + camera_vector, .{16, 16}, want_color);
                        DrawRectangleV((it.position + .{16, 8}) + camera_vector, .{16, 16}, have_color);
                    case .SHOP;
                        if it.building.itemType == .BASKET
                            draw_item_basket((it.position - xy(it.collider.rect.x/8.0, it.collider.rect.y/8.0)) + camera_vector, it.collider.rect.x/4.0);
                        if it.building.itemType == .CHEST
                            draw_item_chest((it.position - xy(it.collider.rect.x/8.0, it.collider.rect.y/8.0)) + camera_vector, it.collider.rect.x/4.0);
                }
            }

            nearest, dist := get_closest_bldg_to_player();
            ss_bldg := nearest.position + camera_vector;
            interact_range := compute_interact_range(nearest);
            if dist < interact_range
                DrawCircleLines(xx ss_bldg.x, xx ss_bldg.y, interact_range, BLACK);
        }

        // draw items in world
        {
            for itemsOnGround if it.item.type ==
            {
                case .LUMBER_AXE;
                    DrawCircleV(it.position + camera_vector, it.collider.radius, GRAY);
            }

            for containersOnGround if it.container.type ==
            {
                case .BASKET;
                    draw_item_basket(it.position + camera_vector, 20.0);
                case .CHEST;
                    draw_item_chest(it.position + camera_vector, 20.0);
            }

            for equipmentOnGround if it.equipment.type ==
            {
                case .TOOL_BELT;
                    DrawRectangleV(it.position - xy(it.collider.rect.x/2.0, it.collider.rect.y/2.0) + camera_vector, it.collider.rect, GREEN);
                case .WEAPON_BELT;
                    DrawRectangleV(it.position - xy(it.collider.rect.x/2.0, it.collider.rect.y/2.0) + camera_vector, it.collider.rect, RED);
            }
        }

        // draw npcs
        for npcs
        {
            ss_npc := it.position + camera_vector;
            DrawCircle(xx ss_npc.x, xx ss_npc.y, xx it.collider.radius, it.color);
            front := ss_npc + it.forward * cast(float) it.collider.radius;
            DrawLineEx(xx ss_npc, xx front, 2.0, WHITE);
        }

        // draw player
        {
            ss_player := player.position + camera_vector;
            DrawCircle(xx ss_player.x, xx ss_player.y, xx player.collider.radius, player.color);
            front := ss_player + player.forward * cast(float) player.collider.radius;
            DrawLineEx(xx ss_player, xx front, 2.0, WHITE);
        }

        // draw ui
        {
            // draw pockets
            resource_names := enum_names(Resource_Type);
            DrawText(xx "Resources:", 20, 20, 20, BLACK);
            for r, r_index: enum_values_as_s64(Resource_Type)
            {
                y_pos := 20 + 20 * (r_index + 1);
                line := tprint("%: %", resource_names[r_index], player.pockets.contents[r]);
                DrawText(to_c_string(line), 20, xx y_pos, 20, BLACK);
            }

            // draw held
            xpos := 20.0;
            DrawText(xx "Held:", 20, WINDOW_HEIGHT - 100, 20, BLACK);
            DrawRectangleLines(xx xpos, WINDOW_HEIGHT - 80, 60, 60, BLACK);
            if player.held.exists 
            {
                if player.held.value.tag == .CONTAINER if player.held.value.container.type ==
                {
                    case .BASKET;
                        draw_item_basket(xy(xpos + 20.0, WINDOW_HEIGHT - 65), 20.0);
                        for r, r_index: player.held.value.container.contents
                        {
                            y_pos := (WINDOW_HEIGHT - 80) - 20 * (r_index + 2);
                            line := tprint("%: %", resource_names[r_index], r);
                            DrawText(to_c_string(line), 20, xx y_pos, 20, BLACK);
                        }
                        xpos += 80.0;
                    case .CHEST;
                        draw_item_chest(xy(xpos + 20.0, WINDOW_HEIGHT - 55), 20.0);
                        xpos += 80.0;
                }
            }
            // draw tool belt
            xpos = 90;
            DrawRectangleLines(xx xpos, WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw item slot
            if player.toolBelt.exists
            {
                DrawRectangleV(xy(xpos + 10, WINDOW_HEIGHT - 80 + 35), xy(40, 10), GREEN); //draw ui representation

                xpos = WINDOW_WIDTH/2 - 230;
                for i: 0..player.toolBelt.value.capacity - 1
                {
                    DrawRectangleLines(xx (xpos + i * 70), WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw inv boxes
                    if i < player.toolBelt.value.contents.count
                    {
                        item := player.toolBelt.value.contents[i];
                        draw_item(xy(xpos + i * 70 + 30, WINDOW_HEIGHT - 50), item); //draw inv
                    }
                }
            }
            // draw weapon belt
            xpos = 160;
            DrawRectangleLines(xx xpos, WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw item slot
            if player.weaponBelt.exists
            {
                DrawRectangleV(xy(xpos + 10, WINDOW_HEIGHT - 80 + 35), xy(40, 10), RED); //draw ui representation
                xpos = WINDOW_WIDTH/2 + 30;
                for i: 0..player.weaponBelt.value.capacity - 1
                {
                    DrawRectangleLines(xx (xpos + i * 70), WINDOW_HEIGHT - 80, 60, 60, BLACK); //draw inv
                }
            }

            // draw nearby inventory
            nearest_entity := get_nearest_holdable_in_range(50);
            if nearest_entity.exists
            {
                drawPos := nearest_entity.value.position + camera_vector;
                if nearest_entity.value.tag == .CONTAINER then drawPos += .{30, -110};
                type: Any;
                if nearest_entity.value.tag ==
                {
                    case .CONTAINER;
                        type = nearest_entity.value.container.type;
                    case .ITEM;
                        type = nearest_entity.value.item.type;
                    case .EQUIPMENT;
                        type = nearest_entity.value.equipment.type;
                }
                DrawText(to_c_string(tprint("%", type)), xx drawPos.x, xx drawPos.y, 20, BLACK);

                if nearest_entity.value.tag == .CONTAINER
                {
                    drawPos += .{0, 20};
                    for r, r_index: nearest_entity.value.container.contents
                    {
                        line := tprint("%: %", resource_names[r_index], r);
                        DrawText(to_c_string(line), xx drawPos.x, xx drawPos.y, 20, BLACK);
                        drawPos.y += 20;
                    }
                }
            }
        }

        // debug
        {
            if debug
            {
                debug_player_position();
                debug_console(dt);
            }
        }

        EndDrawing();
    }

    reset_temporary_storage();
}

game_reset :: () 
{
    log("RESETTING GAME");
    Game = .{};
    seed := random_get();
    if seed % 2 == 0 then seed += 1;
    random_seed(seed);

    //init resources
    populate_resources();

    //init traders
    num_traders := clamp(random_get(), 3, 5);
    for 1..num_traders
    {
        // @TODO: check for overlapping
        x := random_get_within_range(-1000, 1000);
        y := random_get_within_range(-1000, 1000);
        want := random_get() % xx (enum_highest_value(Resource_Type) + 1);
        have := want;
        while have == want
            have = random_get() % xx (enum_highest_value(Resource_Type) + 1);
        e: Entity = NewBuilding(.TRADER, xy(x, y), xx want, xx have);
        array_add(*Game.buildings, e);
    }

    // init shops
    basket_shop: Entity = NewBuilding(.SHOP, xy(-1100, -1100), .FIBER, 10, .BASKET);
    array_add(*Game.buildings, basket_shop);
    chest_shop: Entity = NewBuilding(.SHOP, xy(-900, -1100), .WOOD, 10, .CHEST);
    array_add(*Game.buildings, chest_shop);

    // init npcs
    for 1..7
    {
        npc: Npc;
        x := random_get_within_range(-1000, 1000);
        y := random_get_within_range(-1000, 1000);
        check_collision := true;
        while check_collision
        {
            collided := false;
            for Game.buildings
            {
                if x > it.position.x &&
                x < it.position.x + it.collider.rect.x &&
                y > it.position.y && 
                y < it.position.y + it.collider.rect.y
                {
                    // try again with new position
                    x = random_get_within_range(-1000, 1000);
                    y = random_get_within_range(-1000, 1000);
                    collided = true;
                    break;
                }
            }
            if !collided then check_collision = false;
        }
        npc.position = xy(x, y);
        npc.color = BROWN;
        npc.speed = 0.5;
        array_add(*Game.npcs, npc);
    }

    // init items on ground
    {
        pos := Game.player.position + .{100, -100};
        collider := Collider.{type = .CIRCLE, radius = 10};
        lumberaxe: Entity = NewItem(.LUMBER_AXE, collider, pos);
        array_add(*Game.itemsOnGround, lumberaxe);
    }
    // init equipment on ground
    {
        pos := Game.player.position + .{0, -100};
        collider := Collider.{type = .RECT, rect = .{60, 15}};
        toolbelt: Entity = NewEquipment(.TOOL_BELT, collider, pos);
        array_add(*Game.equipmentOnGround, toolbelt);

        pos = Game.player.position + .{0, -200};
        weaponbelt: Entity = NewEquipment(.WEAPON_BELT, collider, pos);
        array_add(*Game.equipmentOnGround, weaponbelt);
    }
}

compute_interact_range :: (building: Entity) -> float
{
    bldg_half_width := building.collider.rect.x/2.0;
    bldg_center_to_corner_length := sqrt(2 * (bldg_half_width * bldg_half_width));
    return bldg_center_to_corner_length + Game.player.collider.radius + 10.0;
}

get_closest_bldg_to_player :: () -> *Entity, float
{
    using Game;
    nearest_index := 0;
    min_dist := length(buildings[0].position - player.position);
    for buildings
    {
        dist := length(it.position - player.position);
        if dist < min_dist
        {
            min_dist = dist;
            nearest_index = it_index;
        }
    }
    return *buildings[nearest_index], min_dist;
}

get_closest_bldg_to_player :: (type: Bldg_Type) -> *Entity, float
{
    using Game;
    nearest_index := 0;
    min_dist := length(buildings[0].position - player.position);
    for buildings if it.building.type == type
    {
        dist := length(it.position - player.position);
        if dist < min_dist
        {
            min_dist = dist;
            nearest_index = it_index;
        }
    }
    return *buildings[nearest_index], min_dist;
}

// @Bug: What if you are nearer to an entity that can't be picked up, but *also* in range of one that can? it should pick up the nearest that can
get_nearest_holdable_in_range :: (range: float) -> Maybe(*Entity), int
{
    using Game;

    result: Maybe(*Entity);
    nearest_index := 0;
    min_dist := FLOAT64_MAX;

    nearest_source := itemsOnGround;
    Get_Nearest_To_Player(itemsOnGround);
    Get_Nearest_To_Player(containersOnGround);
    Get_Nearest_To_Player(equipmentOnGround);

    if min_dist < range
    {
        result.exists = true;
        result.value = *nearest_source[nearest_index];
    }

    return result, nearest_index;
}

get_nearby_containers :: () -> [..] *Container
{
    using Game;
    result: [..] *Container;
    array_add(*result, *player.pockets);

    if player.held.exists && player.held.value.tag == .CONTAINER
    {
        basket := player.held.value.container;
        if basket.type == .BASKET
            array_add(*result, *basket);
    }

    for containersOnGround
    {
        if length(player.position - it.position) < 50.0
            array_add(*result, *it.container);
    }
    return result;
}

compute_container_weight :: (c: Container) -> int
{
    total := 0;
    for c.contents { total += it; }
    return total;
}

drop_held :: ()
{
    using Game;
    
    if !player.held.exists return;

    player.held.value.position = player.position + player.forward;
    if player.held.value.tag ==
    {
        case .CONTAINER;
            array_add(*containersOnGround, player.held.value);
        case .ITEM;
            array_add(*itemsOnGround, player.held.value);
        case .EQUIPMENT;
            array_add(*equipmentOnGround, player.held.value);
    }
    player.held.exists = false;
}

try_pickup :: ()
{
    using Game;
    closest_item, index := get_nearest_holdable_in_range(100);
    was_picked_up := false;
    if closest_item.exists
    {
        if closest_item.value.tag ==
        {
            case .EQUIPMENT;
                equipment := closest_item.value.equipment;
                e := NewMaybe(equipment);
                if equipment.type ==
                {
                    case .TOOL_BELT;
                        player.toolBelt = e;
                        was_picked_up = true;
                    case .WEAPON_BELT;
                        player.weaponBelt = e;
                        was_picked_up = true;
                }
            case .ITEM;
                item := closest_item.value.item;
                if item.type ==
                {
                    case .LUMBER_AXE;
                        if player.toolBelt.exists
                        {
                            toolbelt := *player.toolBelt.value;
                            if toolbelt.contents.count < toolbelt.capacity
                            {
                                array_add(*toolbelt.contents, closest_item.value);
                                was_picked_up = true;
                            }
                        }
                }
            case .CONTAINER;
                newHeld: Maybe(Entity);
                newHeld.exists = true;
                newHeld.value = <<closest_item.value;
                player.held = newHeld;
                was_picked_up = true;
        }

        if was_picked_up
        {
            if closest_item.value.tag ==
            {
                case .CONTAINER;
                    array_unordered_remove_by_index(*containersOnGround, index);
                case .ITEM;
                    array_unordered_remove_by_index(*itemsOnGround, index);
                case .EQUIPMENT;
                    array_unordered_remove_by_index(*equipmentOnGround, index);
            }
        }
    }

}

Get_Nearest_To_Player :: (arr: [..] Entity) #expand
{
    for arr
    {
        dist := length(Game.player.position - it.position);
        if dist < `min_dist
        {
            `min_dist = dist;
            `nearest_index = it_index;
            `nearest_source = arr;
        }
    }
}

populate_resources :: ()
{
    for i: 1..20
    {
        x := random_get_within_range(-1000, 1000);
        y := random_get_within_range(-1000, 1000);
        type := random_get() % xx (enum_highest_value(Resource_Type) + 1);
        quantity := max(random_get() % 20, 10);

        r : Resource;
        r.position = xy(x, y);
        r.type = cast(Resource_Type) type;
        r.quantity = xx quantity;

        array_add(*Game.resourceList, r);
    }
}