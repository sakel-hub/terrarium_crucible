-- tc_elements: Node definitions, physical reagent entities, node timers, and Crucible Flora
local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/api.lua")
dofile(modpath .. "/entities.lua")

local S = tc_elements.S
local P = tc_assets.PALETTE

-- Mapgen aliases
core.register_alias("mapgen_stone", "tc_elements:substrate")
core.register_alias("mapgen_water_source", "tc_elements:water_source")
core.register_alias("mapgen_river_water_source", "tc_elements:water_source")

-- ========================================================
-- STRUCTURAL & DIORAMA NODES (Terrarium & Workshop)
-- ========================================================

-- Enchanted Crucible Glass (Indestructible container boundary)
core.register_node("tc_elements:flask_glass", {
    description = tc_assets.format_description({
        title = S("Terrarium Glass Wall"),
        category = S("Glass Room Wall"),
        summary = S("Thick brass-framed glass walls surrounding your tiny garden."),
        effect = S("Keeps everything safely inside and opens outward when you finish a level!"),
        usage = S("Peer through the glass to see the wizard's giant wooden desk, candles, and open spellbook."),
        accent = P.aqua,
    }),
    short_description = S("Terrarium Glass Wall"),
    drawtype = "glasslike_framed_optional",
    tiles = {"tc_flask_glass.png", "tc_flask_glass_detail.png"},
    paramtype = "light",
    sunlight_propagates = true,
    use_texture_alpha = "clip",
    is_ground_content = false,
    walkable = true,
    pointable = true,
    diggable = false,
    sounds = tc_assets.node_sound_glass_defaults(),
})

-- Crucible Collar Rim (Engraved brass collar crowning open-top glass walls)
core.register_node("tc_elements:flask_rim", {
    description = tc_assets.format_description({
        title = S("Brass Terrarium Rim"),
        category = S("Glass Room Wall"),
        summary = S("Carved brass trim along the open top of the glass walls."),
        effect = S("Frames the open ceiling where the wizard drops blocks in from above."),
        accent = P.gold,
    }),
    short_description = S("Brass Terrarium Rim"),
    tiles = {"tc_flask_rim.png"},
    is_ground_content = false,
    groups = {cracky = 1},
    diggable = false,
    sounds = tc_assets.node_sound_stone_defaults(),
})

-- Giant Mahogany Workbench
core.register_node("tc_elements:desk_wood", {
    description = tc_assets.format_description({
        title = S("Wizard's Wooden Desk"),
        category = S("Outside Scenery"),
        summary = S("Giant polished wooden desk planks underneath the glass terrarium."),
        accent = P.amber,
    }),
    short_description = S("Wizard's Wooden Desk"),
    tiles = {"tc_desk_wood.png"},
    is_ground_content = false,
    groups = {choppy = 1},
    diggable = false,
    sounds = tc_assets.node_sound_wood_defaults(),
})

-- Giant Spellbook Parchment
core.register_node("tc_elements:parchment", {
    description = tc_assets.format_description({
        title = S("Wizard's Open Spellbook"),
        category = S("Outside Scenery"),
        summary = S("Giant glowing spellbook pages lying open on the desk outside the glass."),
        accent = P.gold,
    }),
    short_description = S("Wizard's Open Spellbook"),
    tiles = {"tc_parchment.png"},
    is_ground_content = false,
    light_source = 5,
    groups = {snappy = 1},
    diggable = false,
    sounds = tc_assets.node_sound_dirt_defaults(),
})

-- Beeswax Candle Pillar
core.register_node("tc_elements:candle_wax", {
    description = tc_assets.format_description({
        title = S("Giant Beeswax Candle"),
        category = S("Outside Scenery"),
        summary = S("A towering beeswax candle warming the wizard's desk outside the glass."),
        accent = P.gold,
    }),
    short_description = S("Giant Beeswax Candle"),
    tiles = {"tc_candle_wax.png"},
    is_ground_content = false,
    light_source = 4,
    groups = {crumbly = 2},
    diggable = false,
    sounds = tc_assets.node_sound_dirt_defaults(),
})

-- Magical Candle Flame Wick (Light source)
core.register_node("tc_elements:candle_wick", {
    description = tc_assets.format_description({
        title = S("Dancing Candle Flame"),
        category = S("Outside Scenery"),
        summary = S("A warm flickering flame shining atop the giant desk candles."),
        effect = S("Lights up the workshop with a cozy golden glow."),
        accent = P.amber,
    }),
    short_description = S("Dancing Candle Flame"),
    drawtype = "plantlike",
    tiles = {tc_assets.vertical_tile("tc_candle_wick_anim.png", 1.2)},
    inventory_image = "tc_candle_wick.png",
    wield_image = "tc_candle_wick.png",
    paramtype = "light",
    sunlight_propagates = true,
    is_ground_content = false,
    light_source = 14,
    walkable = false,
    diggable = false,
})

-- Base Obsidian Substrate
core.register_node("tc_elements:substrate", {
    description = tc_assets.format_description({
        title = S("Terrarium Base Stone"),
        category = S("Garden Floor"),
        summary = S("Solid dark stone foundation underneath the garden soil."),
        accent = P.violet,
    }),
    short_description = S("Terrarium Base Stone"),
    tiles = {"tc_substrate.png"},
    is_ground_content = false,
    groups = {cracky = 1},
    diggable = false,
    sounds = tc_assets.node_sound_stone_defaults(),
})

-- Alchemical Loam (Indestructible terrarium ground)
core.register_node("tc_elements:loam", {
    description = tc_assets.format_description({
        title = S("Garden Soil"),
        category = S("Garden Floor"),
        summary = S("Soft brown earth covering the floor of every glass room."),
        effect = S("Can be upgraded into glowing green Fertile Soil that speeds up you and your plants!"),
        usage = S("Clear green Acid Slime with Pestle [4] or splash Chalk " ..
            "with Water Flask [3] on top of this soil."),
        accent = P.amber,
    }),
    short_description = S("Garden Soil"),
    tiles = {"tc_loam.png"},
    is_ground_content = false,
    groups = {soil = 1, alchem_loam = 1},
    diggable = false,
    sounds = tc_assets.node_sound_dirt_defaults(),
})

-- Transmuted Fertile Catalyst Soil (Beneficial nutrient soil + speed boost highway)
core.register_node("tc_elements:fertile_loam", {
    description = tc_assets.format_description({
        title = S("Fertile Soil"),
        category = S("Rich Green Soil · Speed Boost"),
        summary = S("Glowing green soil created whenever you clean up Acid, Chalk, or a Prismatic Geode."),
        effect = S("Helps nearby plants bloom faster AND lets you run much quicker when you walk on it!"),
        usage = S("Create green paths from room to room so you can dash across your garden with ease."),
        accent = P.emerald,
    }),
    short_description = S("Fertile Soil (Faster Running & Plant Growth)"),
    tiles = {tc_assets.vertical_tile("tc_fertile_loam_anim.png", 3.0)},
    is_ground_content = false,
    light_source = 5,
    groups = {soil = 1, fertile = 1},
    diggable = false,
    sounds = tc_assets.node_sound_dirt_defaults(),
    on_construct = function(pos)
        core.get_meta(pos):set_string("infotext", tc_assets.format_infotext(
            S("Fertile Soil"),
            S("Faster Plant Growth · Faster Running"),
            S("Walk on this glowing green soil to run much faster!")
        ))
    end,
})

-- ========================================================
-- VOLATILE ALCHEMICAL REAGENTS & NODE TIMERS
-- ========================================================

local function place_reagent_on_floor(itemstack, placer, pointed_thing)
    if pointed_thing.type ~= "node" or not pointed_thing.above then
        return itemstack
    end
    local above = pointed_thing.above
    if above.y > 2 or above.y < 1 then
        if placer and placer:is_player() then
            tc_tools.send_hint(
                placer,
                "trowel_floor",
                S("Blocks can only be placed down on the garden floor!"),
                "tc_tool_trowel.png"
            )
        end
        return itemstack
    end
    local lvl = tc_core.state.level
    if tc_world.is_protected_pos(above, lvl) then
        if placer and placer:is_player() then
            tc_tools.send_hint(
                placer,
                "trowel_prot",
                S("Please leave a little room around your plants!"),
                "tc_tool_trowel.png"
            )
        end
        return itemstack
    end
    return core.item_place(itemstack, placer, pointed_thing)
end

local function on_reagent_placed(pos, placer)
    if placer and placer:is_player() then
        core.get_meta(pos):set_string("placer", placer:get_player_name())
    end
    tc_core.try_react_at(pos)
end

local function degrade_fertile_below(pos, sound_name)
    if not tc_core.state.running or tc_core.state.aegis_timer > 0 then
        return true
    end
    local floor_pos = {x = pos.x, y = 0, z = pos.z}
    if core.get_node(floor_pos).name == "tc_elements:fertile_loam" then
        core.swap_node(floor_pos, {name = "tc_elements:loam"})
        core.get_meta(floor_pos):set_string("infotext", "")
        core.sound_play(sound_name, {pos = pos, gain = 0.45, max_hear_distance = 16}, true)
    end
    return true
end

-- DRY helper for registering the 4 falling volatile reagent blocks
local function register_reagent_node(node_name, category_label, extra)
    local rspec = tc_elements.REAGENT_BY_NAME[node_name]
    local info_text = tc_assets.format_infotext(rspec.title, rspec.effect, rspec.infotext_hint)
    local timer_sec = extra.soil_degrade_sec
    local place_snd = extra.place_sound
    local tile_def = rspec.anim_texture
        and tc_assets.vertical_tile(rspec.anim_texture, rspec.anim_length or 2.0)
        or rspec.texture

    local def = {
        description = tc_assets.format_description({
            title = rspec.title,
            category = category_label,
            summary = rspec.summary,
            effect = rspec.effect,
            usage = rspec.usage,
            accent = rspec.accent,
        }),
        short_description = rspec.short_description,
        tiles = {tile_def},
        paramtype = "light",
        is_ground_content = false,
        light_source = extra.light_source,
        _wield_glow = extra._wield_glow,
        drawtype = extra.drawtype,
        node_box = extra.node_box,
        selection_box = extra.selection_box,
        walkable = extra.walkable,
        move_resistance = extra.move_resistance,
        sunlight_propagates = extra.sunlight_propagates,
        use_texture_alpha = extra.use_texture_alpha,
        floodable = extra.floodable,
        on_flood = extra.on_flood,
        groups = extra.groups,
        diggable = false,
        drop = "",
        sounds = extra.sounds,
        on_construct = function(pos)
            core.get_meta(pos):set_string("infotext", info_text)
            if timer_sec then
                core.get_node_timer(pos):start(timer_sec)
            end
        end,
        on_punch = function(pos, _, puncher)
            if not tc_core.state.running or not puncher or not puncher:is_player() then
                return
            end
            local wield = puncher:get_wielded_item()
            local wname = wield:get_name()
            if wname == "tc_tools:trowel" then
                local updated, changed = tc_tools.handle_trowel_on_reagent(wield, puncher, pos, node_name)
                if changed then
                    puncher:set_wielded_item(updated)
                end
            else
                tc_tools.send_hint(puncher, "punch_" .. rspec.id, rspec.infotext_hint)
            end
        end,
        on_timer = timer_sec and function(pos)
            return degrade_fertile_below(pos, extra.degrade_sound)
        end or nil,
        on_place = place_reagent_on_floor,
        after_place_node = place_snd and function(pos, placer)
            core.sound_play(place_snd, {pos = pos, gain = 0.7, max_hear_distance = 16}, true)
            on_reagent_placed(pos, placer)
        end or on_reagent_placed,
    }
    core.register_node(node_name, def)
end

-- Scorching Brimstone (+13°C Thermal, Igneous; 10s Node Timer scorches neglected Fertile Soil)
register_reagent_node("tc_elements:brimstone", S("Hot Block · Raises Heat"), {
    light_source = 12,
    _wield_glow = 10,
    groups = {brimstone = 1, reagent = 1, igniter = 1},
    sounds = tc_assets.node_sound_stone_defaults(),
    soil_degrade_sec = 10.0,
    degrade_sound = "tc_sizzle",
    place_sound = "tc_sizzle",
})

-- Glacial Cryo-Shard (-13°C Thermal, Slippery; 12s Node Timer chills neglected Fertile Soil)
register_reagent_node("tc_elements:cryo_ice", S("Cold Block · Lowers Heat"), {
    sunlight_propagates = true,
    use_texture_alpha = "blend",
    light_source = 5,
    groups = {cryo_ice = 1, reagent = 2, slippery = 3},
    sounds = tc_assets.node_sound_ice_defaults(),
    soil_degrade_sec = 12.0,
    degrade_sound = "tc_ice_dig",
})

-- Vitriol Acid Slime (-12 internal pH / Acidic, Walkable-In Sticky Mire & Caustic Puddle)
register_reagent_node("tc_elements:acid_slime", S("Sour Puddle · Sours Soil"), {
    drawtype = "nodebox",
    walkable = false,
    move_resistance = 4,
    node_box = {
        type = "fixed",
        fixed = {-0.5, -0.5, -0.5, 0.5, -0.1875, 0.5},
    },
    selection_box = {
        type = "fixed",
        fixed = {-0.5, -0.5, -0.5, 0.5, -0.1875, 0.5},
    },
    sunlight_propagates = true,
    use_texture_alpha = "blend",
    light_source = 6,
    groups = {acid = 1, reagent = 3, disable_jump = 1},
    sounds = tc_assets.node_sound_dirt_defaults(),
})

-- Alkaline Chalk Crystal (+12 internal pH / Alkaline; native floodable + on_flood dissolution)
register_reagent_node("tc_elements:alkaline_chalk", S("Dry Block · Dries Soil"), {
    light_source = 3,
    floodable = true,
    groups = {chalk = 1, reagent = 2},
    sounds = tc_assets.node_sound_dirt_defaults(),
    on_flood = function(pos)
        local placer = core.get_meta(pos):get_string("placer")
        if placer and placer ~= "" then
            tc_core.record_neutralization_by_name(placer, 1)
        end
        if tc_core.state.running then
            tc_core.add_scaled_bloom(1.2, pos)
        end
        tc_elements.enrich_soil_at(pos)
        core.sound_play("tc_water_splash", {pos = pos, gain = 0.65, max_hear_distance = 16}, true)
        tc_assets.spawn_sheet_particles({
            amount = 14,
            time = 0.15,
            minpos = {x = pos.x - 0.35, y = pos.y - 0.3, z = pos.z - 0.35},
            maxpos = {x = pos.x + 0.35, y = pos.y + 0.4, z = pos.z + 0.35},
            minvel = {x = -1.2, y = 0.8, z = -1.2},
            maxvel = {x = 1.2, y = 2.6, z = 1.2},
            minacc = {x = 0, y = -2.5, z = 0},
            maxacc = {x = 0, y = -1.0, z = 0},
            minexptime = 0.45,
            maxexptime = 0.90,
            minsize = 1.4,
            maxsize = 2.8,
            glow = 12,
            texpool = {
                tc_assets.make_sheet_tex_entry(tc_assets.PARTICLES.droplet, {blend = "alpha"}),
                tc_assets.make_sheet_tex_entry(tc_assets.PARTICLES.pollen),
            },
        })
        return false
    end,
})

-- ========================================================
-- PRISMATIC AETHER GEODE (Level 2+ Risk/Reward Catalyst)
-- ========================================================

local cat = tc_elements.CATALYST
local GEODE_SPLIT_DIRS = {
    {x = 1, y = 0, z = 0},
    {x = -1, y = 0, z = 0},
    {x = 0, y = 0, z = 1},
    {x = 0, y = 0, z = -1},
}

core.register_node("tc_elements:aether_geode", {
    description = tc_assets.format_description({
        title = cat.title,
        category = S("Bonus Crystal · Level 2+"),
        summary = cat.summary,
        effect = cat.effect,
        usage = cat.usage,
        accent = cat.accent,
    }),
    short_description = cat.short_description,
    tiles = {tc_assets.vertical_tile(cat.anim_texture, cat.anim_length)},
    paramtype = "light",
    is_ground_content = false,
    light_source = 13,
    _wield_glow = 12,
    groups = {aether_geode = 1},
    diggable = false,
    sounds = tc_assets.node_sound_crystal_defaults(),
    on_construct = function(pos)
        local meta = core.get_meta(pos)
        meta:set_int("ttl", 22)
        meta:set_string("infotext", tc_assets.format_infotext(
            cat.title,
            S("Cracks into 2 hazards in 22s!"),
            S("Left-Click or Right-Click with Trowel [1] to clear nearby hazards!")
        ))
        core.get_node_timer(pos):start(1.0)
    end,
    on_punch = function(pos, _, puncher)
        if not tc_core.state.running or not puncher or not puncher:is_player() then
            return
        end
        local wield = puncher:get_wielded_item()
        if wield:get_name() == "tc_tools:trowel" then
            if tc_tools.get_trowel_cargo(wield) ~= "" then
                wield = tc_tools.set_trowel_cargo(wield, nil)
                puncher:set_wielded_item(wield)
                tc_tools.sync_player_trowel_cargo_inv(puncher, "")
                x_player_api.update_wield_item(puncher, true, wield)
                tc_core.add_scaled_bloom(0.5, pos)
                tc_core.record_neutralization(puncher, 1)
            end
            x_player_api.trigger_player_action(puncher, "attack_thrust", 0.35)
            tc_elements.resonate_geode_at(pos, puncher)
        else
            tc_tools.send_hint(
                puncher, "geode_tool",
                S("Switch to your Trowel [1] and Left-Click or Right-Click this Prismatic Geode to crack it open!")
            )
        end
    end,
    on_rightclick = function(pos, _, clicker, itemstack)
        if not tc_core.state.running or not clicker or not clicker:is_player() then
            return itemstack
        end
        if itemstack and itemstack:get_name() == "tc_tools:trowel" then
            tc_elements.resonate_geode_at(pos, clicker)
        else
            tc_tools.send_hint(
                clicker, "geode_tool",
                S("Switch to your Trowel [1] (or place any block beside this Geode) to crack it open!")
            )
        end
        return itemstack
    end,
    on_timer = function(pos)
        if not tc_core.state.running then
            return true
        end
        local meta = core.get_meta(pos)
        local ttl = meta:get_int("ttl") - 1
        if ttl > 0 then
            meta:set_int("ttl", ttl)
            meta:set_string("infotext", tc_assets.format_infotext(
                cat.title,
                S("Cracks into 2 hazards in @1s!", ttl),
                S("Left-Click or Right-Click with Trowel [1] to clear nearby hazards!")
            ))
            return true
        end

        -- Neglected for 22s: splits into 2 volatile hazards!
        core.remove_node(pos)
        core.sound_play("tc_defeat", {pos = pos, gain = 0.75, max_hear_distance = 24}, true)
        local spawned = 0
        local r_count = #tc_elements.REAGENTS
        for i = 1, #GEODE_SPLIT_DIRS do
            if spawned >= 2 then
                break
            end
            local d = GEODE_SPLIT_DIRS[i]
            local sp = {x = pos.x + d.x, y = pos.y, z = pos.z + d.z}
            if not tc_world.is_protected_pos(sp, tc_core.state.level)
                    and core.get_node(sp).name == "air" then
                local rspec = tc_elements.REAGENTS[((pos.x + pos.z + i) % r_count) + 1]
                core.set_node(sp, {name = rspec.name})
                spawned = spawned + 1
            end
        end
        tc_core.push_hud_event({
            priority = 2,
            icon = "tc_aether_geode.png",
            title = S("✖ Unopened Geode Shattered!"),
            detail = S("Split into 2 floor hazards!"),
            color = P.hud_coral,
            accent_hex = P.coral,
            ttl = 3.8,
        })
        return false
    end,
})

-- ========================================================
-- LIQUIDS & VAPORS
-- ========================================================

-- Alchemical Water Source
core.register_node("tc_elements:water_source", {
    description = tc_assets.format_description({
        title = S("Fresh Water"),
        category = S("Refills Your Water Flask"),
        summary = S("Clean, cool water left behind whenever you melt blue Ice Shards."),
        effect = S("Gently cools the room and washes away nearby Brimstone or Chalk."),
        usage = S("Left-Click this water with your Water Flask [3] to scoop up the puddle and fill 3 splashes!"),
        accent = P.aqua,
    }),
    short_description = S("Fresh Water (Left-Click with Flask [3])"),
    drawtype = "liquid",
    tiles = {
        tc_assets.vertical_tile("tc_water_source_anim.png", 2.4, 32, 32, {backface_culling = false}),
        tc_assets.vertical_tile("tc_water_source_anim.png", 2.4, 32, 32, {backface_culling = true}),
    },
    special_tiles = {
        tc_assets.vertical_tile("tc_water_source_anim.png", 2.4, 32, 32, {backface_culling = false}),
        tc_assets.vertical_tile("tc_water_source_anim.png", 2.4, 32, 32, {backface_culling = true}),
    },
    inventory_image = "tc_water.png",
    wield_image = "tc_water.png",
    use_texture_alpha = "blend",
    paramtype = "light",
    walkable = false,
    pointable = false,
    diggable = false,
    buildable_to = true,
    is_ground_content = false,
    drop = "",
    drowning = 1,
    liquidtype = "source",
    liquid_alternative_flowing = "tc_elements:water_flowing",
    liquid_alternative_source = "tc_elements:water_source",
    liquid_viscosity = 1,
    liquid_renewable = false,
    liquid_range = 3,
    post_effect_color = {a = 115, r = 36, g = 132, b = 218},
    groups = {water = 3, liquid = 3, cools_lava = 1},
    sounds = tc_assets.node_sound_water_defaults(),
})

-- Flowing Alchemical Water
core.register_node("tc_elements:water_flowing", {
    description = tc_assets.format_description({
        title = S("Flowing Water"),
        category = S("Refills Your Water Flask"),
        summary = S("Spreading ripples of cool water."),
        effect = S("Melts Chalk on contact and cools hot Brimstone into Steam."),
        usage = S("Left-Click anywhere on the puddle with your Water Flask [3] to scoop it up and refill!"),
        accent = P.aqua,
    }),
    short_description = S("Flowing Water"),
    drawtype = "flowingliquid",
    tiles = {"tc_water.png"},
    special_tiles = {
        tc_assets.vertical_tile("tc_water_flowing_anim.png", 1.0, 32, 32, {backface_culling = false}),
        tc_assets.vertical_tile("tc_water_flowing_anim.png", 1.0, 32, 32, {backface_culling = true}),
    },
    use_texture_alpha = "blend",
    paramtype = "light",
    paramtype2 = "flowingliquid",
    walkable = false,
    pointable = false,
    diggable = false,
    buildable_to = true,
    is_ground_content = false,
    drop = "",
    drowning = 1,
    liquidtype = "flowing",
    liquid_alternative_flowing = "tc_elements:water_flowing",
    liquid_alternative_source = "tc_elements:water_source",
    liquid_viscosity = 1,
    liquid_renewable = false,
    liquid_range = 3,
    post_effect_color = {a = 115, r = 36, g = 132, b = 218},
    groups = {water = 3, liquid = 3, not_in_creative_inventory = 1},
    sounds = tc_assets.node_sound_water_defaults(),
})

-- Alchemical Steam Vapor (Dissipates via node timer & grants Steam Updraft jump boost)
core.register_node("tc_elements:steam", {
    description = tc_assets.format_description({
        title = S("Rising Steam"),
        category = S("Warm Mist · High Jump"),
        summary = S("Soft, warm mist created when water cools down hot Brimstone or Ice melts."),
        effect = S("Step through it to float lightly and jump much higher for 5 seconds!"),
        usage = S("Walk into rising steam to leap high, or Left-Click it with your Water Flask [3] to refill."),
        accent = P.aqua,
    }),
    short_description = S("Rising Steam (Walk In for High Jump)"),
    drawtype = "plantlike",
    tiles = {tc_assets.vertical_tile("tc_steam_anim.png", 1.8)},
    inventory_image = "tc_steam.png",
    wield_image = "tc_steam.png",
    paramtype = "light",
    sunlight_propagates = true,
    use_texture_alpha = "blend",
    is_ground_content = false,
    light_source = 4,
    walkable = false,
    pointable = false,
    diggable = false,
    buildable_to = true,
    groups = {steam = 1},
    on_construct = function(pos)
        core.get_node_timer(pos):start(10)
    end,
    on_timer = function(pos)
        core.remove_node(pos)
        return false
    end,
})

-- ========================================================
-- CRUCIBLE SPROUT (The Living Heart — Stages 1..4 & Withered)
-- ========================================================

for i = 1, #tc_elements.SPROUT_STAGES do
    local st = tc_elements.SPROUT_STAGES[i]
    core.register_node(st.name, {
        description = tc_assets.format_description({
            title = st.title,
            category = S("Magical Plant · Protect & Grow!"),
            summary = S("The living heart of each glass room—grow all plants to 100% Bloom to finish the level!"),
            effect = S("Blooms steadily when Heat (40–60°C) and Soil pH (5.6–8.4) stay comfortable and calm."),
            usage = S("Right-Click to check Garden Status; Left-Click with a filled Water Flask [3] to heal it!"),
            accent = P.emerald,
        }),
        short_description = st.title,
        drawtype = "plantlike",
        visual_scale = st.scale,
        tiles = {"tc_crucible_sprout_" .. st.stage .. ".png"},
        paramtype = "light",
        sunlight_propagates = true,
        is_ground_content = false,
        light_source = st.light,
        walkable = false,
        pointable = true,
        diggable = false,
        groups = {crucible_sprout = st.stage},
        selection_box = {
            type = "fixed",
            fixed = {-0.32, -0.5, -0.32, 0.32, 0.5, 0.32},
        },
        on_construct = function(pos)
            core.get_meta(pos):set_string("infotext", tc_assets.format_infotext(
                st.title,
                S("Keep Heat (40–60°C) & Soil pH (5.6–8.4) comfortable"),
                S("Right-Click for Garden Controls · Left-Click with Water Flask [3] to heal")
            ))
        end,
        on_rightclick = function(_, _, clicker)
            if clicker and clicker:is_player() then
                tc_core.show_garden_dialog(clicker)
            end
        end,
    })
end

-- Withered Sprout (0% Vitality state — Dedicated texture & urgent revival instructions)
core.register_node("tc_elements:crucible_sprout_withered", {
    description = tc_assets.format_description({
        title = S("Wilted Sprout (Needs Water!)"),
        category = S("Magical Plant · Needs Revival!"),
        summary = S("A tired, wilted sprout whose growth is paused until you revive it."),
        effect = S("If EVERY sprout in your garden wilts at the same time, the run ends!"),
        usage = S("Left-Click with a filled Water Flask [3], drink an Aegis Potion, " ..
            "or keep the room balanced for 6s to revive it!"),
        accent = P.coral,
    }),
    short_description = S("Wilted Sprout (Splash Water [3] to Revive!)"),
    drawtype = "plantlike",
    visual_scale = 0.98,
    tiles = {"tc_crucible_sprout_withered.png"},
    paramtype = "light",
    sunlight_propagates = true,
    is_ground_content = false,
    light_source = 3,
    walkable = false,
    pointable = true,
    diggable = false,
    groups = {crucible_sprout = 0, withered_sprout = 1},
    selection_box = {
        type = "fixed",
        fixed = {-0.32, -0.5, -0.32, 0.32, 0.45, 0.32},
    },
    on_construct = function(pos)
        core.get_meta(pos):set_string("infotext", tc_assets.format_infotext(
            S("Wilted Sprout [Needs Revival!]"),
            S("Growth paused for this plant until revived!"),
            S("Left-Click with Water Flask [3], drink Aegis Potion, or keep 6s Balance")
        ))
    end,
    on_rightclick = function(_, _, clicker)
        if clicker and clicker:is_player() then
            tc_core.show_garden_dialog(clicker)
        end
    end,
})
