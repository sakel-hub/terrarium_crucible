-- tc_tools: Alchemist's toolkit (Trowel Tongs, Multi-Charge Flask, Bellows, Pestle, Grimoire) & Elixirs
local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/api.lua")

local P = tc_assets.PALETTE

-- ========================================================
-- STARTING ALCHEMIST TOOLKIT (Hotbar Slots 1..5)
-- ========================================================

-- Slot 1: Alchemist's Trowel (Fast Excavation + Right-Click 1-Slot Tongs Scoop & Place)
local function trowel_secondary(itemstack, user, pointed_thing)
    if not user or not user:is_player() or not pointed_thing or pointed_thing.type ~= "node" then
        return itemstack
    end

    local under = pointed_thing.under
    local above = pointed_thing.above
    local u_node = core.get_node(under)
    local u_name = u_node.name

    -- Delegate right-clicks on interactive nodes (Altar & Sprouts) unless targeting Geodes/Reagents
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
    if not tc_tools.check_cooldown(user, "trowel_tongs", 0.20) then
        return itemstack
    end

    -- Right-clicking a Prismatic Aether Geode resonates it immediately
    if u_name == "tc_elements:aether_geode" then
        x_player_api.trigger_player_action(user, "attack_thrust", 0.35)
        tc_elements.resonate_geode_at(under, user)
        return itemstack
    end

    local carried = tc_tools.get_trowel_cargo(itemstack)
    if carried == "" then
        if tc_elements.REAGENT_BY_NAME[u_name] then
            core.remove_node(under)
            core.sound_play("tc_trowel_scoop", {pos = under, gain = 0.8, max_hear_distance = 16}, true)
            x_player_api.trigger_player_action(user, "attack_thrust", 0.35)
            local updated = tc_tools.set_trowel_cargo(itemstack, u_name)
            x_player_api.update_wield_item(user, true, updated)
            return updated
        end
        tc_tools.send_hint(
            user, "trowel_empty",
            "Right-Click a hazard block (Brimstone, Ice, Acid, or Chalk) to pick it up onto your Trowel!"
        )
        return itemstack
    end

    -- Carrying a reagent: place it on valid floor space and trigger immediate reaction!
    if above and above.y >= 1 and above.y <= 2 then
        if tc_world.is_protected_pos(above, tc_core.state.level) then
            tc_tools.send_hint(
                user, "trowel_prot",
                "Please leave a little room around your plants and the Control Altar!"
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
            x_player_api.update_wield_item(user, true, itemstack)
            tc_core.try_react_at(above)
            return itemstack
        end
    end

    tc_tools.send_hint(
        user, "trowel_floor",
        "Right-Click an empty spot on the garden floor next to an opposite block to combine them!"
    )
    return itemstack
end

core.register_tool("tc_tools:trowel", {
    description = tc_assets.format_description({
        title = "Alchemist's Trowel",
        category = "Tool [1] · Move & Combine Blocks",
        summary = "A sturdy gardening trowel that safely picks up hazard blocks and opens bonus crystals.",
        effect = "Combine Brimstone + Ice or Acid + Chalk right next to each other for big plant growth!",
        usage = "Right-Click a block to pick it up, then Right-Click the floor to set it down! " ..
            "Left-Click or Right-Click shimmering Prismatic Geodes to crack them open.",
        accent = P.aqua,
    }),
    short_description = "Trowel [1] — Right-Click to Move & Combine Blocks",
    inventory_image = "tc_tool_trowel.png",
    wield_image = "tc_tool_trowel.png",
    tool_capabilities = {
        full_punch_interval = 0.7,
        max_drop_level = 3,
        groupcaps = {
            reagent = {times = {[1] = 0.90, [2] = 0.65, [3] = 0.40}, uses = 0, maxlevel = 3},
        },
        damage_groups = {fleshy = 2},
    },
    on_place = trowel_secondary,
    on_secondary_use = trowel_secondary,
    sound = {breaks = "tc_tool_breaks"},
})

-- Slot 2: Thermal Bellows (Melt cryo-ice, evaporate water, scales with Dragonlung Bellows & Overdrive)
local BELLOWS_TARGETS = {"tc_elements:cryo_ice", "tc_elements:water_source", "tc_elements:water_flowing"}

core.register_tool("tc_tools:bellows", {
    description = tc_assets.format_description({
        title = "Thermal Bellows",
        category = "Tool [2] · Melts Ice",
        summary = "A warm leather air-puffer that blows cozy heat onto cold blocks.",
        effect = "Melts blue Ice Shards into fresh Water and rising Steam while helping your plants grow!",
        usage = "Left-Click blue Ice Shards to melt them (then Left-Click the Water with Flask [3] to refill!).",
        accent = P.amber,
    }),
    short_description = "Thermal Bellows [2] — Left-Click to Melt Ice",
    inventory_image = "tc_tool_bellows.png",
    wield_image = "tc_tool_bellows.png",
    liquids_pointable = true,
    on_use = function(itemstack, user, pointed_thing)
        if not tc_core.state.running or not tc_tools.check_cooldown(user, "bellows", 0.32) then
            return itemstack
        end
        local pos = user:get_pos()
        local dir = user:get_look_dir()

        x_player_api.trigger_player_action(user, "attack_thrust", 0.35)
        core.sound_play("tc_bellows", {pos = pos, gain = 0.65, max_hear_distance = 18}, true)
        tc_tools.spawn_bellows_particles(pos, dir)

        if pointed_thing.type == "node" then
            local under = pointed_thing.under
            local clicked_name = core.get_node(under).name
            if clicked_name == "tc_elements:brimstone" then
                tc_tools.send_hint(
                    user, "bellows_brim",
                    "Bellows [2] melts blue Ice! Use a filled Water Flask [3] to cool down hot Brimstone."
                )
                return itemstack
            end

            local radius = (tc_core.has_boon("dragonlung_bellows") and 1 or 0)
                + (tc_core.has_effect(user, "harmonic_overdrive") and 1 or 0)
            local minp = {x = under.x - radius, y = under.y - 1, z = under.z - radius}
            local maxp = {x = under.x + radius, y = under.y + 1, z = under.z + radius}
            local found = core.find_nodes_in_area(minp, maxp, BELLOWS_TARGETS, true)

            local ice_nodes = found["tc_elements:cryo_ice"] or {}
            local w_src = found["tc_elements:water_source"] or {}
            local w_flw = found["tc_elements:water_flowing"] or {}

            for i = 1, #ice_nodes do
                local p = ice_nodes[i]
                core.set_node(p, {name = "tc_elements:water_source"})
                local above = {x = p.x, y = p.y + 1, z = p.z}
                if core.get_node(above).name == "air" then
                    core.set_node(above, {name = "tc_elements:steam"})
                end
                tc_core.try_react_at(p)
            end

            for i = 1, #w_src do
                core.set_node(w_src[i], {name = "tc_elements:steam"})
            end
            for i = 1, #w_flw do
                core.set_node(w_flw[i], {name = "tc_elements:steam"})
            end

            local melted = #ice_nodes
            local evaporated = #w_src + #w_flw
            if melted > 0 or evaporated > 0 then
                core.sound_play("tc_steam", {pos = under, gain = 0.55, max_hear_distance = 16}, true)
                if melted > 0 then
                    local gain = tc_core.add_scaled_bloom(1.2 * melted, under)
                    tc_core.record_neutralization(user, melted)
                    core.chat_send_player(
                        user:get_player_name(),
                        tc_assets.chat_prefix("Garden", P.aqua) ..
                        core.colorize(
                            P.text_primary,
                            string.format(
                                "Melted %d Ice Shard(s) into fresh Water & Steam (+%.1f%% Bloom)!",
                                melted,
                                gain
                            )
                        )
                    )
                end
            end
        end

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

-- Slot 3a: Condenser Flask (Empty)
core.register_tool("tc_tools:condenser_flask", {
    description = tc_assets.format_description({
        title = "Water Flask (Empty)",
        category = "Tool [3] · Needs Refill",
        summary = "A glass watering flask that holds 3 splashes of water (5 with the Deep Retort upgrade).",
        effect = "Scoops up an entire Water puddle or Steam cloud to fill your flask all the way!",
        usage = "Left-Click any Water puddle or Steam cloud (melt blue Ice with Bellows [2] first if dry!).",
        accent = P.aqua,
    }),
    short_description = "Water Flask [3] — Empty (Left-Click Water to Fill)",
    inventory_image = "tc_tool_flask_empty.png",
    wield_image = "tc_tool_flask_empty.png",
    liquids_pointable = true,
    on_use = function(itemstack, user, pointed_thing)
        if not tc_core.state.running then
            return itemstack
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
                    or u_name == "tc_elements:crucible_sprout_withered" then
                tc_tools.send_hint(
                    user, "empty_flask",
                    "Your Water Flask is empty! Melt blue Ice with Bellows [2], " ..
                    "then Left-Click the Water or Steam to fill 3 splashes."
                )
            end
        end
        return itemstack
    end,
})

-- Slot 3b: Condenser Flask (Charged — Splash-Only Multi-Charge via native Luanti tool wear bar)
core.register_tool("tc_tools:condenser_flask_full", {
    description = tc_assets.format_description({
        title = "Water Flask (Filled)",
        category = "Tool [3] · Ready to Splash!",
        summary = "Filled with 3 splashes of cool water (5 with the Deep Retort upgrade).",
        effect = "Cools hot Brimstone into Steam, washes Chalk into green soil, and heals hurt or wilted plants!",
        usage = "Left-Click Brimstone, Chalk, or a hurt Plant to splash it " ..
            "(or Left-Click extra Water puddles to tidy them up!).",
        accent = P.aqua,
    }),
    short_description = "Water Flask [3] — 3/3 Splashes",
    inventory_image = "tc_tool_flask_water.png",
    wield_image = "tc_tool_flask_water.png",
    _wield_glow = 8,
    liquids_pointable = true,
    on_use = function(itemstack, user, pointed_thing)
        if not tc_core.state.running
                or not pointed_thing or pointed_thing.type ~= "node"
                or not user or not user:is_player() then
            return itemstack
        end

        local under = pointed_thing.under
        local node = core.get_node(under)
        local uname = user:get_player_name()

        if node.name == "tc_elements:brimstone" then
            x_player_api.trigger_player_action(user, "attack_slash", 0.35)
            core.set_node(under, {name = "tc_elements:steam"})
            core.sound_play("tc_sizzle", {pos = under, gain = 0.9, max_hear_distance = 16}, true)
            core.sound_play("tc_water_splash", {pos = under, gain = 0.55, max_hear_distance = 16}, true)
            tc_tools.spawn_water_splash_particles(under, true)
            local gain = tc_core.add_scaled_bloom(1.2, under)
            core.chat_send_player(
                uname,
                tc_assets.chat_prefix("Garden", P.aqua) ..
                core.colorize(
                    P.text_primary,
                    string.format("Cooled hot Brimstone into rising Steam (+%.1f%% Bloom)!", gain)
                )
            )
            tc_core.record_neutralization(user, 1)
            return tc_tools.consume_flask_charge(itemstack)
        elseif node.name == "tc_elements:alkaline_chalk" then
            x_player_api.trigger_player_action(user, "attack_slash", 0.35)
            core.remove_node(under)
            local enriched = tc_elements.enrich_soil_at(under)
            core.sound_play("tc_water_splash", {pos = under, gain = 0.75, max_hear_distance = 16}, true)
            tc_tools.spawn_water_splash_particles(under, false)
            local gain = tc_core.add_scaled_bloom(1.2, under)
            core.chat_send_player(
                uname,
                tc_assets.chat_prefix("Garden", P.emerald) ..
                core.colorize(
                    P.text_primary,
                    string.format(
                        "%s (+%.1f%% Bloom!)",
                        enriched and "Washed away Chalk and made glowing green Speed Soil"
                            or "Washed away Alkaline Chalk",
                        gain
                    )
                )
            )
            tc_core.record_neutralization(user, 1)
            return tc_tools.consume_flask_charge(itemstack)
        elseif core.get_item_group(node.name, "crucible_sprout") > 0
                or node.name == "tc_elements:crucible_sprout_withered" then
            if tc_core.revive_sprout_at(under, user, 50.0) then
                x_player_api.trigger_player_action(user, "attack_slash", 0.35)
                core.sound_play("tc_water_splash", {pos = under, gain = 0.7, max_hear_distance = 16}, true)
                tc_tools.spawn_water_splash_particles(under, false)
                return tc_tools.consume_flask_charge(itemstack)
            else
                tc_tools.send_hint(user, "sprout_full", "This plant is already happy and at full 100% health!")
            end
        elseif try_siphon_liquid(pointed_thing) then
            -- Always siphon & remove Water/Steam (even when already at max charges!) without pouring water
            x_player_api.trigger_player_action(user, "attack_slash", 0.35)
            return tc_tools.fill_flask()
        else
            tc_tools.send_hint(
                user,
                "flask_targets",
                "Left-Click hot Brimstone, dry Chalk, a hurt Plant, " ..
                "or falling blocks to splash water (or click Water puddles to scoop them up)!"
            )
        end

        return itemstack
    end,
})

-- Slot 4: Limestone Pestle (Alkaline dust AoE neutralizer, scales with Starlight Mortar & Overdrive)
core.register_tool("tc_tools:chalk_pestle", {
    description = tc_assets.format_description({
        title = "Limestone Pestle",
        category = "Tool [4] · Clears Green Acid",
        summary = "A smooth stone pestle that scatters gentle mineral powder over sour puddles.",
        effect = "Clears a wide patch of green Acid Slime at once and turns the floor into green Speed Soil!",
        usage = "Left-Click on or right near green Acid Slime puddles (or swat falling Acid in mid-air!).",
        accent = P.emerald,
    }),
    short_description = "Limestone Pestle [4] — Left-Click to Clear Green Acid",
    inventory_image = "tc_tool_pestle.png",
    wield_image = "tc_tool_pestle.png",
    _wield_glow = 6,
    on_use = function(itemstack, user, pointed_thing)
        if not tc_core.state.running or not tc_tools.check_cooldown(user, "pestle", 0.32) then
            return itemstack
        end
        x_player_api.trigger_player_action(user, "attack_slash", 0.35)
        local center = user:get_pos()
        if pointed_thing.type == "node" then
            center = pointed_thing.under
            if core.get_node(center).name == "tc_elements:alkaline_chalk" then
                tc_tools.send_hint(
                    user, "pestle_chalk",
                    "Pestle [4] clears green Acid Slime! " ..
                    "Use your filled Water Flask [3] to wash away Chalk."
                )
            end
        end

        local has_mortar = tc_core.has_boon("starlight_mortar")
        local radius = 1 + (has_mortar and 1 or 0) + (tc_core.has_effect(user, "harmonic_overdrive") and 1 or 0)
        core.sound_play("tc_pestle", {pos = center, gain = 0.85, max_hear_distance = 16}, true)
        tc_tools.spawn_pestle_particles(center, radius)

        local rc = vector.round(center)
        local minp = {x = rc.x - radius, y = rc.y - 1, z = rc.z - radius}
        local maxp = {x = rc.x + radius, y = rc.y + 1, z = rc.z + radius}
        local acid_nodes = core.find_nodes_in_area(minp, maxp, {"tc_elements:acid_slime"})

        local transmuted = #acid_nodes
        for i = 1, transmuted do
            local apos = acid_nodes[i]
            core.remove_node(apos)
            tc_elements.enrich_soil_at(apos)
        end

        if transmuted > 0 then
            local per_node = has_mortar and 1.6 or 1.2
            local gain = tc_core.add_scaled_bloom(per_node * transmuted, center)
            core.sound_play("tc_transmute", {pos = center, gain = 0.9, max_hear_distance = 16}, true)
            core.chat_send_player(
                user:get_player_name(),
                tc_assets.chat_prefix("Garden", P.emerald) ..
                core.colorize(
                    P.text_primary,
                    string.format(
                        "Cleared %d green Acid puddle(s) into glowing Speed Soil (+%.1f%% Bloom)!",
                        transmuted,
                        gain
                    )
                )
            )
            tc_core.record_neutralization(user, transmuted)
        end

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
        title = "Gardener's Guidebook",
        category = "Tool [5] · Illustrated How-to-Play",
        summary = "Your friendly picture guide to every block, tool, potion, plant tip, and Top 10 score.",
        effect = "Shows clear tips with hoverable item pictures—plus the Top 10 Leaderboard!",
        usage = "Left-Click or Right-Click anytime to read " ..
            "(press [Z] to call out a room; hold [E]+W to sprint!).",
        accent = P.gold,
    }),
    short_description = "Guidebook [5] — How to Play & Top 10",
    inventory_image = "tc_tool_guide.png",
    wield_image = "tc_tool_guide.png",
    _wield_glow = 5,
    on_use = open_guide,
    on_secondary_use = open_guide,
    on_place = open_guide,
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
        stack_max = 10,
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
    name = "tc_tools:elixir_quicksilver",
    title = "Quicksilver Potion",
    short_description = "Quicksilver Potion — Fast Run & High Jump (15s)",
    category = "Speed Potion · Earned Every 3 Hazards Cleared",
    summary = "A fizzy sky-blue potion that helps you zip quickly from room to room.",
    effect = "Lets you run much faster and jump higher for 15 seconds!",
    usage = "Left-Click or Right-Click to drink.",
    accent = P.aqua,
    image = "tc_elixir_quicksilver.png",
    particle_tex = tc_assets.PARTICLES.droplet,
    sound = "tc_elixir_drink",
    is_drink = true,
    wield_glow = 10,
    on_consume = function(user)
        tc_core.apply_effect(user, "quicksilver", 15.0)
        core.chat_send_player(
            user:get_player_name(),
            tc_assets.chat_prefix("Potion", P.aqua) ..
            core.colorize(P.text_primary, "Quicksilver Rush active! Running faster and jumping higher for 15s!")
        )
    end,
})

register_elixir({
    name = "tc_tools:elixir_aegis",
    title = "Aegis Potion",
    short_description = "Aegis Potion — Full Heal & Plant Shield (12s)",
    category = "Healing Potion · Earned Every 5 Hazards Cleared",
    summary = "A warm golden-green potion that heals you and protects your whole garden.",
    effect = "Refills your full health, revives all wilted plants, and shields every plant for 12s! " ..
        "(Also activates automatically to save you if you run out of health!)",
    usage = "Left-Click or Right-Click to drink anytime—or keep one in your bag as a lifesaver!",
    accent = P.gold,
    image = "tc_elixir_aegis.png",
    particle_tex = tc_assets.PARTICLES.bloom,
    sound = "tc_elixir_drink",
    is_drink = true,
    wield_glow = 11,
    on_consume = function(user)
        tc_core.activate_aegis_ward(user, 12.0)
    end,
})

register_elixir({
    name = "tc_tools:chronos_sandglass",
    title = "Chronos Hourglass",
    short_description = "Chronos Hourglass — Pause Falling Blocks (12s)",
    category = "Time Hourglass · Earned Every Level Cleared",
    summary = "A magical brass hourglass filled with sparkling violet sand.",
    effect = "Pauses new falling blocks for 12 seconds, clears 1 nearby hazard per plant, & speeds up the team!",
    usage = "Left-Click or Right-Click whenever your rooms get busy and you need breathing room!",
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

x_player_api.register_item_action("tc_tools:trowel", {action = "mine", alt_action = "attack_thrust"})
x_player_api.register_item_action("tc_tools:bellows", {action = "attack_thrust"})
x_player_api.register_item_action("tc_tools:condenser_flask", {action = "attack_slash"})
x_player_api.register_item_action("tc_tools:condenser_flask_full", {action = "attack_slash"})
x_player_api.register_item_action("tc_tools:chalk_pestle", {action = "attack_slash"})
x_player_api.register_item_action("tc_tools:chronos_sandglass", {action = "attack_slash", alt_action = "attack_slash"})

x_player_api.register_equip_sound("tc_tools:trowel", {sound = "tc_trowel_scoop", gain = 0.20})
x_player_api.register_equip_sound("tc_tools:bellows", {sound = "tc_bellows", gain = 0.16})
x_player_api.register_equip_sound("tc_tools:condenser_flask", {sound = "tc_glass", gain = 0.20})
x_player_api.register_equip_sound("tc_tools:condenser_flask_full", {sound = "tc_glass", gain = 0.22})
x_player_api.register_equip_sound("tc_tools:chalk_pestle", {sound = "tc_pestle", gain = 0.18})
x_player_api.register_equip_sound("tc_tools:guide_tome", {sound = "tc_book_page", gain = 0.22})
x_player_api.register_equip_sound("tc_tools:elixir_quicksilver", {sound = "tc_glass", gain = 0.20})
x_player_api.register_equip_sound("tc_tools:elixir_aegis", {sound = "tc_glass", gain = 0.20})
x_player_api.register_equip_sound("tc_tools:chronos_sandglass", {sound = "tc_geode_chime", gain = 0.18})
