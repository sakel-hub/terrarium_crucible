-- tc_tools: Alchemist's toolkit (Trowel Tongs, Multi-Charge Flask, Bellows, Pestle, Grimoire) & Elixirs
local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/api.lua")

local S = tc_tools.S
local P = tc_assets.PALETTE

-- Prevent accidentally throwing away core hotbar tools [1–5] with the Drop [Q] key
local function keep_core_tool(itemstack)
    return itemstack
end

local TOOL_RANGE = 6.0

-- ========================================================
-- STARTING ALCHEMIST TOOLKIT (Hotbar Slots 1..5)
-- ========================================================

-- Slot 1: Alchemist's Trowel (Fast Excavation + Right-Click 1-Slot Tongs Scoop & Place)
local function trowel_secondary(itemstack, user, pointed_thing)
    if not user or not user:is_player() or not pointed_thing then
        return itemstack
    end

    if pointed_thing.type == "object" and pointed_thing.ref then
        local updated, handled = tc_elements.interact_falling_reagent(pointed_thing.ref, user, itemstack)
        if handled then
            return updated
        end
    end

    if pointed_thing.type ~= "node" then
        local fall_ent = tc_elements.find_interceptable_reagent(user, pointed_thing, itemstack)
        if fall_ent then
            local updated = tc_elements.interact_falling_reagent(fall_ent, user, itemstack)
            return updated
        end
        return itemstack
    end

    local under = pointed_thing.under
    local above = pointed_thing.above
    local u_node = core.get_node(under)
    local u_name = u_node.name

    -- Delegate right-clicks on interactive nodes (Sprouts) unless targeting Geodes/Reagents
    if u_name ~= "tc_elements:aether_geode" and not tc_elements.REAGENT_BY_NAME[u_name] then
        local u_def = core.registered_nodes[u_name]
        local ctrl = user:get_player_control()
        if u_def and u_def.on_rightclick and not (ctrl and ctrl.sneak) then
            return u_def.on_rightclick(under, u_node, user, itemstack, pointed_thing) or itemstack
        end
    end

    if not tc_core.state.running then
        return itemstack
    end

    -- Right-clicking a Prismatic Aether Geode resonates it immediately (and consumes any carried block for bonus!)
    if u_name == "tc_elements:aether_geode" then
        if not tc_tools.check_cooldown(user, "trowel_tongs", 0.20) then
            return itemstack
        end
        if tc_tools.get_trowel_cargo(itemstack) ~= "" then
            tc_tools.set_trowel_cargo(itemstack, nil)
            tc_tools.sync_player_trowel_cargo_inv(user, "")
            x_player_api.update_wield_item(user, true, itemstack)
            tc_core.add_scaled_bloom(0.5, under)
            tc_core.record_neutralization(user, 1)
        end
        x_player_api.trigger_player_action(user, "attack_thrust", 0.35)
        tc_elements.resonate_geode_at(under, user)
        return itemstack
    end

    -- Right-clicking a floor reagent either scoops it (when empty) or executes an instant direct combo!
    if tc_elements.REAGENT_BY_NAME[u_name] then
        local updated = tc_tools.handle_trowel_on_reagent(itemstack, user, under, u_name)
        return updated
    end

    local carried = tc_tools.get_trowel_cargo(itemstack)
    if carried == "" then
        local fall_ent = tc_elements.find_interceptable_reagent(user, pointed_thing, itemstack)
        if fall_ent then
            local updated = tc_elements.interact_falling_reagent(fall_ent, user, itemstack)
            return updated
        end
        tc_tools.send_hint(
            user, "trowel_empty",
            S(
                "Left-Click or Right-Click a hazard block " ..
                "(Brimstone, Ice, Acid, or Chalk) to pick it up onto your Trowel!"
            )
        )
        return itemstack
    end

    if not tc_tools.check_cooldown(user, "trowel_tongs", 0.20) then
        return itemstack
    end

    -- Carrying a reagent: place it on valid floor space and trigger immediate reaction!
    if above and above.y >= 1 and above.y <= 2 then
        if tc_world.is_protected_pos(above, tc_core.state.level) then
            tc_tools.send_hint(
                user, "trowel_prot",
                S("Please leave a little room around your plants!")
            )
            return itemstack
        end
        local a_name = core.get_node(above).name
        if a_name == "air" or a_name == "tc_elements:steam" then
            core.set_node(above, {name = carried})
            core.get_meta(above):set_string("placer", user:get_player_name())
            core.sound_play("tc_trowel_scoop", {pos = above, gain = 0.85, max_hear_distance = 16}, true)
            x_player_api.trigger_player_action(user, "attack_thrust", 0.35)
            tc_tools.set_trowel_cargo(itemstack, nil)
            tc_tools.sync_player_trowel_cargo_inv(user, "")
            x_player_api.update_wield_item(user, true, itemstack)
            tc_core.try_react_at(above)
            return itemstack
        end
    end

    tc_tools.send_hint(
        user, "trowel_floor",
        S("Click directly on the opposite block to combine, or Right-Click an empty spot on the garden floor!")
    )
    return itemstack
end

core.register_tool("tc_tools:trowel", {
    description = tc_assets.format_description({
        title = S("Alchemist's Trowel"),
        category = S("Tool [1] · Move & Combine Blocks"),
        summary = S("A sturdy gardening trowel that safely picks up hazard blocks and opens bonus crystals."),
        effect = S("Combine Brimstone + Ice or Acid + Chalk together for big plant growth!"),
        usage = S("Click any hazard block to pick it up, then click directly on its opposite " ..
            "(or Right-Click empty floor beside it)! Also cracks open Prismatic Geodes."),
        accent = P.aqua,
    }),
    short_description = S("Trowel [1] — Click to Move & Combine Blocks"),
    inventory_image = "tc_tool_trowel.png",
    wield_image = "tc_tool_trowel.png",
    range = TOOL_RANGE,
    tool_capabilities = {
        full_punch_interval = 0.7,
        max_drop_level = 0,
        groupcaps = {},
        damage_groups = {fleshy = 2},
    },
    on_place = trowel_secondary,
    on_secondary_use = trowel_secondary,
    on_drop = keep_core_tool,
    sound = {breaks = "tc_tool_breaks"},
})

-- Slot 2: Thermal Bellows (Melt cryo-ice, evaporate water, siphon Brimstone when low; scales with Dragonlung & level)
local BELLOWS_TARGETS = {"tc_elements:cryo_ice", "tc_elements:water_source", "tc_elements:water_flowing"}

local function is_safe_prime_target(pointed_thing)
    if not pointed_thing then
        return true
    end
    if pointed_thing.type == "object" then
        return false
    end
    if pointed_thing.type ~= "node" or not pointed_thing.under then
        return true
    end
    local u_name = core.get_node(pointed_thing.under).name
    if tc_elements.REAGENT_BY_NAME[u_name]
            or u_name == "tc_elements:aether_geode"
            or u_name == "tc_elements:water_source"
            or u_name == "tc_elements:water_flowing"
            or u_name == "tc_elements:steam"
            or u_name == "tc_elements:crucible_sprout_withered"
            or core.get_item_group(u_name, "crucible_sprout") > 0 then
        return false
    end
    return true
end

local function siphon_brimstone_at(under, user)
    x_player_api.trigger_player_action(user, "attack_thrust", 0.35)
    core.remove_node(under)
    core.sound_play("tc_sizzle", {pos = under, gain = 0.80, max_hear_distance = 18}, true)
    core.sound_play("tc_bellows", {pos = under, gain = 0.70, max_hear_distance = 18}, true)
    tc_tools.spawn_bellows_particles(
        {x = under.x, y = under.y - 0.8, z = under.z},
        {x = 0, y = 0.45, z = 0}
    )
    local gain = tc_core.add_scaled_bloom(1.2, under)
    tc_core.record_neutralization(user, 1)
    tc_core.push_action_feedback(user, {
        kind = "action",
        icon = "tc_tool_bellows.png",
        bloom = gain,
        label = S("Brimstone Siphoned → Bellows Full!"),
        color = P.hud_amber,
        accent_hex = P.amber,
    })
    return tc_tools.fill_bellows()
end

local function grind_chalk_at(under, user)
    x_player_api.trigger_player_action(user, "attack_slash", 0.35)
    core.remove_node(under)
    tc_elements.enrich_soil_at(under)
    core.sound_play("tc_pestle", {pos = under, gain = 0.85, max_hear_distance = 18}, true)
    core.sound_play("tc_transmute", {pos = under, gain = 0.75, max_hear_distance = 18}, true)
    tc_tools.spawn_pestle_particles(under, 0.5)
    local gain = tc_core.add_scaled_bloom(1.2, under)
    tc_core.record_neutralization(user, 1)
    tc_core.push_action_feedback(user, {
        kind = "action",
        icon = "tc_tool_pestle.png",
        bloom = gain,
        label = S("Chalk Ground → Pestle Full!"),
        color = P.hud_emerald,
        accent_hex = P.emerald,
    })
    return tc_tools.fill_pestle()
end

-- Slot 2a: Thermal Bellows (Depleted — Siphons Brimstone to full, or 1.8s air-click pumps +1 Puff)
core.register_tool("tc_tools:bellows_empty", {
    description = tc_assets.format_description({
        title = S("Thermal Bellows (Empty)"),
        category = S("Tool [2] · Needs Heat Refill"),
        summary = S("A cooled leather air-puffer out of warm puffs (holds 4+ Puffs when refilled)."),
        effect = S("Siphons hot Brimstone right off the floor (or mid-air) to refill all Puffs & boost Bloom!"),
        usage = S(
            "Left-Click hot Brimstone to refill completely, or Left-Click empty air (1.8s) to hand-pump +1 Puff."
        ),
        accent = P.amber,
    }),
    short_description = S("Thermal Bellows [2] — Empty (Click Brimstone or Air)"),
    inventory_image = "tc_tool_bellows_empty.png",
    wield_image = "tc_tool_bellows_empty.png",
    range = TOOL_RANGE,
    liquids_pointable = true,
    on_drop = keep_core_tool,
    on_use = function(itemstack, user, pointed_thing)
        if not tc_core.state.running or not user or not user:is_player() then
            return itemstack
        end
        if pointed_thing and pointed_thing.type == "object" and pointed_thing.ref then
            local updated, handled = tc_elements.interact_falling_reagent(pointed_thing.ref, user, itemstack)
            if handled then
                return updated
            end
        end
        if pointed_thing and pointed_thing.type == "node" and pointed_thing.under then
            local under = pointed_thing.under
            local clicked_name = core.get_node(under).name
            if clicked_name == "tc_elements:brimstone" then
                if not tc_tools.check_cooldown(user, "bellows", 0.32) then
                    return itemstack
                end
                return siphon_brimstone_at(under, user)
            elseif clicked_name == "tc_elements:cryo_ice"
                    or clicked_name == "tc_elements:water_source"
                    or clicked_name == "tc_elements:water_flowing" then
                tc_tools.send_hint(
                    user,
                    "empty_bellows",
                    S("Bellows empty! Click Brimstone to refill, or click air to pump +1.")
                )
                return itemstack
            end
        end
        local fall_ent = tc_elements.find_interceptable_reagent(user, pointed_thing, itemstack)
        if fall_ent then
            local updated = tc_elements.interact_falling_reagent(fall_ent, user, itemstack)
            return updated
        end
        if is_safe_prime_target(pointed_thing) then
            local updated = tc_tools.try_emergency_prime(user, "bellows", itemstack)
            return updated
        end
        tc_tools.send_hint(
            user,
            "empty_bellows",
            S("Bellows empty! Click Brimstone to refill, or click air to pump +1.")
        )
        return itemstack
    end,
})

-- Slot 2b: Thermal Bellows (Charged — Whiff-Safe Multi-Puff via native Luanti tool wear bar)
core.register_tool("tc_tools:bellows", {
    description = tc_assets.format_description({
        title = S("Thermal Bellows (Charged)"),
        category = S("Tool [2] · Melts Ice · Siphons Brimstone"),
        summary = S("Filled with 4 warm Puffs (+1 every 2 levels, +2 with Dragonlung Bellows)."),
        effect = S("Melts blue Ice Shards into Water & Steam! Siphons hot Brimstone when below max Puffs."),
        usage = S("Left-Click blue Ice to melt (1 Puff), or Left-Click Brimstone when low to refill all Puffs!"),
        accent = P.amber,
    }),
    short_description = S("Thermal Bellows [2] — 4/4 Puffs"),
    inventory_image = "tc_tool_bellows.png",
    wield_image = "tc_tool_bellows.png",
    range = TOOL_RANGE,
    _wield_glow = 6,
    liquids_pointable = true,
    on_drop = keep_core_tool,
    on_use = function(itemstack, user, pointed_thing)
        if not tc_core.state.running or not user or not user:is_player() then
            return itemstack
        end

        if pointed_thing and pointed_thing.type == "object" and pointed_thing.ref then
            local updated, handled = tc_elements.interact_falling_reagent(pointed_thing.ref, user, itemstack)
            if handled then
                return updated
            end
        end

        if pointed_thing and pointed_thing.type == "node" and pointed_thing.under then
            local under = pointed_thing.under
            local clicked_name = core.get_node(under).name
            if clicked_name == "tc_elements:brimstone" then
                if tc_tools.get_bellows_charges(itemstack) < tc_tools.get_max_bellows_charges() then
                    if not tc_tools.check_cooldown(user, "bellows", 0.32) then
                        return itemstack
                    end
                    return siphon_brimstone_at(under, user)
                end
                tc_tools.send_hint(
                    user,
                    "bellows_full",
                    S("Bellows [2] is full! Splash Brimstone [3] or pair Ice [1].")
                )
                return itemstack
            end

            local has_dragon = tc_core.has_blessing("dragonlung_bellows")
            local radius = math.min(
                1,
                (has_dragon and 1 or 0) + (tc_core.has_effect(user, "harmonic_overdrive") and 1 or 0)
            )
            local minp = {x = under.x - radius, y = under.y - 1, z = under.z - radius}
            local maxp = {x = under.x + radius, y = under.y + 1, z = under.z + radius}
            local found = core.find_nodes_in_area(minp, maxp, BELLOWS_TARGETS, true)

            local ice_nodes = found["tc_elements:cryo_ice"] or {}
            local w_src = found["tc_elements:water_source"] or {}
            local w_flw = found["tc_elements:water_flowing"] or {}
            local melted = #ice_nodes
            local evap_count = (melted == 0) and (#w_src + #w_flw) or 0

            if melted > 0 or evap_count > 0 then
                if not tc_tools.check_cooldown(user, "bellows", 0.32) then
                    return itemstack
                end
                local uname = user:get_player_name()
                for i = 1, melted do
                    local p = ice_nodes[i]
                    core.set_node(p, {name = "tc_elements:water_source"})
                    core.get_meta(p):set_string("placer", uname)
                    local above = {x = p.x, y = p.y + 1, z = p.z}
                    if core.get_node(above).name == "air" then
                        core.set_node(above, {name = "tc_elements:steam"})
                    end
                    tc_core.try_react_at(p)
                end

                -- Only evaporate water into Steam when puffing water directly (never delete water while melting Ice!)
                if melted == 0 then
                    for i = 1, #w_src do
                        core.set_node(w_src[i], {name = "tc_elements:steam"})
                    end
                    for i = 1, #w_flw do
                        core.set_node(w_flw[i], {name = "tc_elements:steam"})
                    end
                end

                local pos = user:get_pos()
                local dir = user:get_look_dir()
                x_player_api.trigger_player_action(user, "attack_thrust", 0.35)
                core.sound_play("tc_bellows", {pos = pos, gain = 0.65, max_hear_distance = 18}, true)
                core.sound_play("tc_steam", {pos = under, gain = 0.55, max_hear_distance = 16}, true)
                tc_tools.spawn_bellows_particles(pos, dir)
                if melted > 0 then
                    local per_ice = has_dragon and 1.5 or 1.2
                    local gain = tc_core.add_scaled_bloom(per_ice * melted, under)
                    tc_core.record_neutralization(user, melted)
                    tc_core.push_action_feedback(user, {
                        kind = "action",
                        icon = "tc_tool_bellows.png",
                        bloom = gain,
                        label = melted == 1 and S("Melted Ice → Water!")
                            or S("Melted @1 Ice → Water!", melted),
                        color = P.hud_aqua,
                        accent_hex = P.aqua,
                    })
                else
                    tc_core.push_action_feedback(user, {
                        kind = "hint",
                        icon = "tc_steam.png",
                        text = S("Puffed Water into rising Steam!"),
                        color = P.hud_aqua,
                        accent_hex = P.aqua,
                        ttl = 2.0,
                    })
                end
                return tc_tools.consume_bellows_charge(itemstack)
            end
        end

        local fall_ent = tc_elements.find_interceptable_reagent(user, pointed_thing, itemstack)
        if fall_ent then
            local updated = tc_elements.interact_falling_reagent(fall_ent, user, itemstack)
            return updated
        end

        tc_tools.send_hint(
            user,
            "bellows_whiff",
            S("Click Ice to melt, or Brimstone when low to refill!")
        )
        return itemstack
    end,
})

-- Helper to siphon Water or Steam at pointed_thing (resolving water_flowing to its nearest water_source)
local SIPHON_MINP = {x = 0, y = 0, z = 0}
local SIPHON_MAXP = {x = 0, y = 0, z = 0}

local function clear_orphaned_flowing_near(pos)
    SIPHON_MINP.x, SIPHON_MINP.y, SIPHON_MINP.z = pos.x - 3, pos.y - 1, pos.z - 3
    SIPHON_MAXP.x, SIPHON_MAXP.y, SIPHON_MAXP.z = pos.x + 3, pos.y + 2, pos.z + 3
    local remaining = core.find_nodes_in_area(SIPHON_MINP, SIPHON_MAXP, {"tc_elements:water_source"})
    if #remaining == 0 then
        local flowing = core.find_nodes_in_area(SIPHON_MINP, SIPHON_MAXP, {"tc_elements:water_flowing"})
        for i = 1, #flowing do
            core.remove_node(flowing[i])
        end
    end
end

local function try_siphon_liquid(pointed_thing)
    if not pointed_thing or pointed_thing.type ~= "node" then
        return false
    end
    local candidates = {pointed_thing.under, pointed_thing.above}
    for i = 1, #candidates do
        local pos = candidates[i]
        if pos then
            local n_name = core.get_node(pos).name
            if n_name == "tc_elements:water_source" then
                core.remove_node(pos)
                clear_orphaned_flowing_near(pos)
                core.sound_play("tc_water_splash", {pos = pos, gain = 0.75, max_hear_distance = 16}, true)
                tc_tools.spawn_water_splash_particles(pos, false)
                return true
            elseif n_name == "tc_elements:water_flowing" then
                SIPHON_MINP.x, SIPHON_MINP.y, SIPHON_MINP.z = pos.x - 3, pos.y - 1, pos.z - 3
                SIPHON_MAXP.x, SIPHON_MAXP.y, SIPHON_MAXP.z = pos.x + 3, pos.y + 2, pos.z + 3
                local sources = core.find_nodes_in_area(SIPHON_MINP, SIPHON_MAXP, {"tc_elements:water_source"})
                if #sources > 0 then
                    local best = sources[1]
                    local best_d2 = math.huge
                    for j = 1, #sources do
                        local s = sources[j]
                        local dx, dy, dz = s.x - pos.x, s.y - pos.y, s.z - pos.z
                        local d2 = (dx * dx) + (dy * dy) + (dz * dz)
                        if d2 < best_d2 then
                            best_d2 = d2
                            best = s
                        end
                    end
                    core.remove_node(best)
                    clear_orphaned_flowing_near(best)
                end
                if core.get_node(pos).name == "tc_elements:water_flowing" then
                    core.remove_node(pos)
                end
                core.sound_play("tc_water_splash", {pos = pos, gain = 0.75, max_hear_distance = 16}, true)
                tc_tools.spawn_water_splash_particles(pos, false)
                return true
            elseif n_name == "tc_elements:steam" then
                core.remove_node(pos)
                core.sound_play("tc_water_splash", {pos = pos, gain = 0.75, max_hear_distance = 16}, true)
                tc_tools.spawn_water_splash_particles(pos, true)
                return true
            end
        end
    end
    return false
end

local FLASK_POINTABILITIES = {
    nodes = {
        ["group:steam"] = true,
        ["group:water"] = true,
    },
}

-- Slot 3a: Condenser Flask (Empty — Scoops Water/Steam to full, or 1.8s air-click condenses +1 Splash)
core.register_tool("tc_tools:condenser_flask", {
    description = tc_assets.format_description({
        title = S("Water Flask (Empty)"),
        category = S("Tool [3] · Needs Refill"),
        summary = S("A glass watering flask out of cool splashes (holds 3+ Splashes when refilled)."),
        effect = S("Scoops up an entire Water puddle or Steam cloud to fill your flask all the way!"),
        usage = S("Left-Click Water/Steam to refill completely, or Left-Click empty air (1.8s) to condense +1 Splash."),
        accent = P.aqua,
    }),
    short_description = S("Water Flask [3] — Empty (Click Water/Steam or Air)"),
    inventory_image = "tc_tool_flask_empty.png",
    wield_image = "tc_tool_flask_empty.png",
    range = TOOL_RANGE,
    liquids_pointable = true,
    pointabilities = FLASK_POINTABILITIES,
    on_drop = keep_core_tool,
    on_use = function(itemstack, user, pointed_thing)
        if not tc_core.state.running then
            return itemstack
        end
        if user and user:is_player() and pointed_thing and pointed_thing.type == "object" and pointed_thing.ref then
            local updated, handled = tc_elements.interact_falling_reagent(pointed_thing.ref, user, itemstack)
            if handled then
                return updated
            end
        end
        if try_siphon_liquid(pointed_thing) then
            if user and user:is_player() then
                x_player_api.trigger_player_action(user, "attack_slash", 0.35)
            end
            return tc_tools.fill_flask()
        end
        if user and user:is_player() and pointed_thing and pointed_thing.type == "node" and pointed_thing.under then
            local u_name = core.get_node(pointed_thing.under).name
            if u_name == "tc_elements:brimstone" or u_name == "tc_elements:alkaline_chalk"
                    or u_name == "tc_elements:crucible_sprout_withered"
                    or core.get_item_group(u_name, "crucible_sprout") > 0 then
                tc_tools.send_hint(
                    user,
                    "empty_flask",
                    S("Flask empty! Click Water/Steam to fill, or click air to condense +1.")
                )
                return itemstack
            end
        end
        if user and user:is_player() and is_safe_prime_target(pointed_thing) then
            local updated = tc_tools.try_emergency_prime(user, "flask", itemstack)
            return updated
        end
        if user and user:is_player() then
            tc_tools.send_hint(
                user,
                "empty_flask",
                S("Flask empty! Click Water/Steam to fill, or click air to condense +1.")
            )
        end
        return itemstack
    end,
})

-- Slot 3b: Condenser Flask (Charged — Splash-Only Multi-Charge via native Luanti tool wear bar)
core.register_tool("tc_tools:condenser_flask_full", {
    description = tc_assets.format_description({
        title = S("Water Flask (Filled)"),
        category = S("Tool [3] · Ready to Splash!"),
        summary = S("Filled with 3 cool Splashes (+1 every 2 levels, +2 with Deep Retort)."),
        effect = S("Cools hot Brimstone into Steam, washes Chalk into green soil, and heals hurt or wilted plants!"),
        usage = S("Left-Click Brimstone, Chalk, or a hurt Plant to splash it " ..
            "(or Left-Click extra Water puddles to tidy them up!)."),
        accent = P.aqua,
    }),
    short_description = S("Water Flask [3] — 3/3 Splashes"),
    inventory_image = "tc_tool_flask_water.png",
    wield_image = "tc_tool_flask_water.png",
    range = TOOL_RANGE,
    _wield_glow = 8,
    liquids_pointable = true,
    pointabilities = FLASK_POINTABILITIES,
    on_drop = keep_core_tool,
    on_use = function(itemstack, user, pointed_thing)
        if not tc_core.state.running or not user or not user:is_player() then
            return itemstack
        end

        if pointed_thing and pointed_thing.type == "object" and pointed_thing.ref then
            local updated, handled = tc_elements.interact_falling_reagent(pointed_thing.ref, user, itemstack)
            if handled then
                return updated
            end
        end

        if pointed_thing and pointed_thing.type == "node" and pointed_thing.under then
            local under = pointed_thing.under
            local node = core.get_node(under)

            if node.name == "tc_elements:brimstone" then
                x_player_api.trigger_player_action(user, "attack_slash", 0.35)
                core.set_node(under, {name = "tc_elements:steam"})
                core.sound_play("tc_sizzle", {pos = under, gain = 0.9, max_hear_distance = 16}, true)
                core.sound_play("tc_water_splash", {pos = under, gain = 0.55, max_hear_distance = 16}, true)
                tc_tools.spawn_water_splash_particles(under, true)
                local gain = tc_core.add_scaled_bloom(1.2, under)
                tc_core.push_action_feedback(user, {
                    kind = "action",
                    icon = "tc_tool_flask_water.png",
                    bloom = gain,
                    label = S("Quenched Brimstone → Steam!"),
                    color = P.hud_aqua,
                    accent_hex = P.aqua,
                })
                tc_core.record_neutralization(user, 1)
                return tc_tools.consume_flask_charge(itemstack)
            elseif node.name == "tc_elements:alkaline_chalk" then
                x_player_api.trigger_player_action(user, "attack_slash", 0.35)
                core.remove_node(under)
                local enriched = tc_elements.enrich_soil_at(under)
                core.sound_play("tc_water_splash", {pos = under, gain = 0.75, max_hear_distance = 16}, true)
                tc_tools.spawn_water_splash_particles(under, false)
                local gain = tc_core.add_scaled_bloom(1.2, under)
                tc_core.push_action_feedback(user, {
                    kind = "action",
                    icon = "tc_tool_flask_water.png",
                    bloom = gain,
                    label = enriched and S("Washed Chalk → Speed Soil!") or S("Washed Chalk!"),
                    color = P.hud_emerald,
                    accent_hex = P.emerald,
                })
                tc_core.record_neutralization(user, 1)
                return tc_tools.consume_flask_charge(itemstack)
            elseif core.get_item_group(node.name, "crucible_sprout") > 0
                    or node.name == "tc_elements:crucible_sprout_withered" then
                if tc_core.revive_sprout_at(under, user, 50.0) then
                    x_player_api.trigger_player_action(user, "attack_slash", 0.35)
                    core.sound_play("tc_water_splash", {pos = under, gain = 0.7, max_hear_distance = 16}, true)
                    tc_tools.spawn_water_splash_particles(under, false)
                    return tc_tools.consume_flask_charge(itemstack)
                end
                tc_tools.send_hint(user, "sprout_full", S("This plant is already happy and at full 100% health!"))
                return itemstack
            elseif try_siphon_liquid(pointed_thing) then
                -- Always siphon & remove Water/Steam (even when already at max charges!) without pouring water
                x_player_api.trigger_player_action(user, "attack_slash", 0.35)
                return tc_tools.fill_flask()
            end
        end

        local fall_ent = tc_elements.find_interceptable_reagent(user, pointed_thing, itemstack)
        if fall_ent then
            local updated = tc_elements.interact_falling_reagent(fall_ent, user, itemstack)
            return updated
        end

        tc_tools.send_hint(
            user,
            "flask_targets",
            S("Click Brimstone, Chalk, or a hurt Plant to splash (or click Water to scoop)!")
        )
        return itemstack
    end,
})

-- Slot 4a: Limestone Pestle (Depleted — Grinds Alkaline Chalk to full, or 1.8s air-click scrapes +1 Sweep)
core.register_tool("tc_tools:chalk_pestle_empty", {
    description = tc_assets.format_description({
        title = S("Limestone Pestle (Empty)"),
        category = S("Tool [4] · Needs Chalk Refill"),
        summary = S("A bare stone pestle out of mineral powder (holds 4+ Sweeps when refilled)."),
        effect = S("Grinds dry Alkaline Chalk right off the floor (or mid-air) into Speed Soil & refills all Sweeps!"),
        usage = S("Left-Click Alkaline Chalk to refill completely, or Left-Click empty air (1.8s) to scrape +1 Sweep."),
        accent = P.emerald,
    }),
    short_description = S("Limestone Pestle [4] — Empty (Click Chalk or Air)"),
    inventory_image = "tc_tool_pestle_empty.png",
    wield_image = "tc_tool_pestle_empty.png",
    range = TOOL_RANGE,
    on_drop = keep_core_tool,
    on_use = function(itemstack, user, pointed_thing)
        if not tc_core.state.running or not user or not user:is_player() then
            return itemstack
        end
        if pointed_thing and pointed_thing.type == "object" and pointed_thing.ref then
            local updated, handled = tc_elements.interact_falling_reagent(pointed_thing.ref, user, itemstack)
            if handled then
                return updated
            end
        end
        if pointed_thing and pointed_thing.type == "node" and pointed_thing.under then
            local under = pointed_thing.under
            local clicked_name = core.get_node(under).name
            if clicked_name == "tc_elements:alkaline_chalk" then
                if not tc_tools.check_cooldown(user, "pestle", 0.32) then
                    return itemstack
                end
                return grind_chalk_at(under, user)
            elseif clicked_name == "tc_elements:acid_slime" then
                tc_tools.send_hint(
                    user,
                    "empty_pestle",
                    S("Pestle empty! Click Chalk to refill, or click air to scrape +1.")
                )
                return itemstack
            end
        end
        local fall_ent = tc_elements.find_interceptable_reagent(user, pointed_thing, itemstack)
        if fall_ent then
            local updated = tc_elements.interact_falling_reagent(fall_ent, user, itemstack)
            return updated
        end
        if is_safe_prime_target(pointed_thing) then
            local updated = tc_tools.try_emergency_prime(user, "pestle", itemstack)
            return updated
        end
        tc_tools.send_hint(
            user,
            "empty_pestle",
            S("Pestle empty! Click Chalk to refill, or click air to scrape +1.")
        )
        return itemstack
    end,
})

-- Slot 4b: Limestone Pestle (Charged — Whiff-Safe AoE Acid Neutralizer & Chalk Grinder)
core.register_tool("tc_tools:chalk_pestle", {
    description = tc_assets.format_description({
        title = S("Limestone Pestle (Charged)"),
        category = S("Tool [4] · Clears Acid · Grinds Chalk"),
        summary = S("Coated with 4 mineral Sweeps (+1 every 2 levels, +2 with Starlight Mortar)."),
        effect = S("Clears a wide patch of green Acid Slime into Speed Soil! Grinds Chalk when below max Sweeps."),
        usage = S("Left-Click on or near Acid Slime (1 Sweep), or Left-Click Chalk when low to refill all Sweeps!"),
        accent = P.emerald,
    }),
    short_description = S("Limestone Pestle [4] — 4/4 Sweeps"),
    inventory_image = "tc_tool_pestle.png",
    wield_image = "tc_tool_pestle.png",
    range = TOOL_RANGE,
    _wield_glow = 6,
    on_drop = keep_core_tool,
    on_use = function(itemstack, user, pointed_thing)
        if not tc_core.state.running or not user or not user:is_player() then
            return itemstack
        end

        if pointed_thing and pointed_thing.type == "object" and pointed_thing.ref then
            local updated, handled = tc_elements.interact_falling_reagent(pointed_thing.ref, user, itemstack)
            if handled then
                return updated
            end
        end

        local is_node_target = pointed_thing and pointed_thing.type == "node" and pointed_thing.under ~= nil
        if not is_node_target then
            local air_ent = tc_elements.find_interceptable_reagent(user, pointed_thing, itemstack)
            if air_ent then
                local updated = tc_elements.interact_falling_reagent(air_ent, user, itemstack)
                return updated
            end
        end

        local center = user:get_pos()
        if is_node_target then
            center = pointed_thing.under
            if core.get_node(center).name == "tc_elements:alkaline_chalk" then
                if tc_tools.get_pestle_charges(itemstack) < tc_tools.get_max_pestle_charges() then
                    if not tc_tools.check_cooldown(user, "pestle", 0.32) then
                        return itemstack
                    end
                    return grind_chalk_at(center, user)
                end
                tc_tools.send_hint(
                    user,
                    "pestle_full",
                    S("Pestle [4] is full! Wash Chalk [3] or pair Acid [1].")
                )
                return itemstack
            end
        end

        local has_mortar = tc_core.has_blessing("starlight_mortar")
        local radius = math.min(
            2,
            1 + (has_mortar and 1 or 0) + (tc_core.has_effect(user, "harmonic_overdrive") and 1 or 0)
        )
        local rc = vector.round(center)
        local minp = {x = rc.x - radius, y = rc.y - 1, z = rc.z - radius}
        local maxp = {x = rc.x + radius, y = rc.y + 1, z = rc.z + radius}
        local acid_nodes = core.find_nodes_in_area(minp, maxp, {"tc_elements:acid_slime"})

        local transmuted = #acid_nodes
        if transmuted > 0 then
            if not tc_tools.check_cooldown(user, "pestle", 0.32) then
                return itemstack
            end
            for i = 1, transmuted do
                local apos = acid_nodes[i]
                core.remove_node(apos)
                tc_elements.enrich_soil_at(apos)
            end

            x_player_api.trigger_player_action(user, "attack_slash", 0.35)
            core.sound_play("tc_pestle", {pos = center, gain = 0.85, max_hear_distance = 16}, true)
            core.sound_play("tc_transmute", {pos = center, gain = 0.9, max_hear_distance = 16}, true)
            tc_tools.spawn_pestle_particles(center, radius)

            local per_node = has_mortar and 1.6 or 1.2
            local gain = tc_core.add_scaled_bloom(per_node * transmuted, center)
            tc_core.push_action_feedback(user, {
                kind = "action",
                icon = "tc_tool_pestle.png",
                bloom = gain,
                label = transmuted == 1 and S("Cleared Acid → Speed Soil!")
                    or S("Cleared @1 Acid → Speed Soil!", transmuted),
                color = P.hud_emerald,
                accent_hex = P.emerald,
            })
            tc_core.record_neutralization(user, transmuted)
            return tc_tools.consume_pestle_charge(itemstack)
        end

        if is_node_target then
            local fall_ent = tc_elements.find_interceptable_reagent(user, pointed_thing, itemstack)
            if fall_ent then
                local updated = tc_elements.interact_falling_reagent(fall_ent, user, itemstack)
                return updated
            end
        end

        tc_tools.send_hint(
            user,
            "pestle_whiff",
            S("Click near Acid Slime, or Chalk when low to refill!")
        )
        return itemstack
    end,
})

-- Slot 5: Grimoire of Equilibrium (Interactive Visual Field Manual & Leaderboard)
local function open_guide(itemstack, user)
    if user and user:is_player() then
        core.sound_play("tc_book_page", {to_player = user:get_player_name(), gain = 0.75}, true)
        tc_core.show_guide_dialog(user, 1)
    end
    return itemstack
end

core.register_tool("tc_tools:guide_tome", {
    description = tc_assets.format_description({
        title = S("Gardener's Guidebook"),
        category = S("Tool [5] · Illustrated How-to-Play"),
        summary = S("Your friendly picture guide to every block, tool, potion, plant tip, and Top 10 score."),
        effect = S("Shows clear tips with hoverable item pictures—plus the Top 10 Leaderboard!"),
        usage = S("Left-Click or Right-Click anytime to read " ..
            "(press [Z] to call out a room; hold [E]+W to sprint!)."),
        accent = P.gold,
    }),
    short_description = S("Guidebook [5] — How to Play & Top 10"),
    inventory_image = "tc_tool_guide.png",
    wield_image = "tc_tool_guide.png",
    _wield_glow = 5,
    on_use = open_guide,
    on_secondary_use = open_guide,
    on_place = open_guide,
    on_drop = keep_core_tool,
})

-- ========================================================
-- CONSUMABLE ALCHEMICAL BOOST ELIXIRS (DRY Registration)
-- ========================================================

---@class TcElixirDef
---@field name string
---@field title string
---@field short_description string
---@field category string
---@field summary string
---@field effect string
---@field usage string
---@field accent string
---@field image string
---@field particle_tex string
---@field sound string
---@field is_drink? boolean
---@field wield_glow? integer
---@field on_consume fun(user: ObjectRef)

---@param def TcElixirDef
local function register_elixir(def)
    local function consume(itemstack, user)
        if not tc_core.state.running or not user or not user:is_player() then
            return itemstack
        end
        def.on_consume(user)
        if def.is_drink then
            x_player_api.trigger_eat(user, 1.2, def.name)
        else
            x_player_api.trigger_player_action(user, "attack_slash", 0.45)
        end
        tc_tools.spawn_elixir_particles(user:get_pos(), def.particle_tex)
        core.sound_play(def.sound, {pos = user:get_pos(), gain = 0.85, max_hear_distance = 22}, true)
        itemstack:take_item(1)
        return itemstack
    end

    local function consume_on_place(itemstack, placer, pointed_thing)
        if placer and placer:is_player() and pointed_thing and pointed_thing.type == "node" and pointed_thing.under then
            local u_node = core.get_node(pointed_thing.under)
            local u_def = core.registered_nodes[u_node.name]
            local ctrl = placer:get_player_control()
            if u_def and u_def.on_rightclick and not (ctrl and ctrl.sneak) then
                return u_def.on_rightclick(pointed_thing.under, u_node, placer, itemstack, pointed_thing) or itemstack
            end
        end
        return consume(itemstack, placer)
    end

    core.register_craftitem(def.name, {
        description = tc_assets.format_description({
            title = def.title,
            category = def.category,
            summary = def.summary,
            effect = def.effect,
            usage = def.usage,
            accent = def.accent,
        }),
        short_description = def.short_description,
        inventory_image = def.image,
        wield_image = def.image,
        _wield_glow = def.wield_glow or 10,
        groups = def.is_drink and {drink = 1} or nil,
        stack_max = def.stack_max or 2,
        on_use = consume,
        on_secondary_use = consume,
        on_place = consume_on_place,
    })

    if def.is_drink then
        x_player_api.register_consumable(def.name, {
            action = "eat",
            duration = 1.2,
            particle_type = "liquid_drops",
        })
    end
end

register_elixir({
    name = "tc_tools:elixir_aegis",
    title = S("Aegis Potion"),
    short_description = S("Aegis Potion — Full Heal & Garden Shield (12s)"),
    category = S("Lifesaver Potion · From Geodes & Level Clears"),
    summary = S("A rare golden-green elixir that heals you and shields both you and your whole garden."),
    effect = S("Refills your full health, revives all wilted plants, & shields you + every plant for 12s " ..
        "(14s with Sunlit Dew)! Also triggers automatically if you run out of health!"),
    usage = S("Left-Click or Right-Click to drink—or keep one in your bag as an automatic lifesaver!"),
    accent = P.gold,
    image = "tc_elixir_aegis.png",
    particle_tex = tc_assets.PARTICLES.bloom,
    sound = "tc_elixir_drink",
    is_drink = true,
    stack_max = 3,
    wield_glow = 11,
    on_consume = function(user)
        tc_core.activate_aegis_ward(user, tc_core.has_blessing("sunlit_dew") and 14.0 or 12.0)
    end,
})

register_elixir({
    name = "tc_tools:chronos_sandglass",
    title = S("Chronos Hourglass"),
    short_description = S("Chronos Hourglass — Pause Falling Blocks (12s)"),
    category = S("Time Hourglass · Earned Every Level Cleared"),
    summary = S("A magical brass hourglass filled with sparkling violet sand."),
    effect = S("Pauses new falling blocks for 12 seconds, clears 1 nearby hazard per plant, & speeds up the team!"),
    usage = S("Left-Click or Right-Click whenever your rooms get busy and you need breathing room!"),
    accent = P.violet,
    image = "tc_chronos_sandglass.png",
    particle_tex = tc_assets.PARTICLES.pollen,
    sound = "tc_stasis",
    is_drink = false,
    wield_glow = 12,
    on_consume = function(user)
        tc_core.activate_chronos_stasis(user, 12.0)
    end,
})

-- ========================================================
-- x_player_api MULTI-TRACK ACTIONS & EQUIP SOUNDS
-- ========================================================

x_player_api.register_item_action("tc_tools:trowel", {action = "attack_thrust", alt_action = "attack_thrust"})
x_player_api.register_item_action("tc_tools:bellows", {action = "attack_thrust"})
x_player_api.register_item_action("tc_tools:bellows_empty", {action = "attack_thrust"})
x_player_api.register_item_action("tc_tools:condenser_flask", {action = "attack_slash"})
x_player_api.register_item_action("tc_tools:condenser_flask_full", {action = "attack_slash"})
x_player_api.register_item_action("tc_tools:chalk_pestle", {action = "attack_slash"})
x_player_api.register_item_action("tc_tools:chalk_pestle_empty", {action = "attack_slash"})
x_player_api.register_item_action("tc_tools:chronos_sandglass", {action = "attack_slash", alt_action = "attack_slash"})

x_player_api.register_equip_sound("tc_tools:trowel", {sound = "tc_trowel_scoop", gain = 0.20})
x_player_api.register_equip_sound("tc_tools:bellows", {sound = "tc_bellows", gain = 0.16})
x_player_api.register_equip_sound("tc_tools:bellows_empty", {sound = "tc_bellows", gain = 0.12})
x_player_api.register_equip_sound("tc_tools:condenser_flask", {sound = "tc_glass", gain = 0.20})
x_player_api.register_equip_sound("tc_tools:condenser_flask_full", {sound = "tc_glass", gain = 0.22})
x_player_api.register_equip_sound("tc_tools:chalk_pestle", {sound = "tc_pestle", gain = 0.18})
x_player_api.register_equip_sound("tc_tools:chalk_pestle_empty", {sound = "tc_pestle", gain = 0.14})
x_player_api.register_equip_sound("tc_tools:guide_tome", {sound = "tc_book_page", gain = 0.22})
x_player_api.register_equip_sound("tc_tools:elixir_aegis", {sound = "tc_glass", gain = 0.20})
x_player_api.register_equip_sound("tc_tools:chronos_sandglass", {sound = "tc_geode_chime", gain = 0.18})
