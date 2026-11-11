---@class TcReagentSpec
---@field id string Short identifier (e.g., "brimstone")
---@field name string Full registered node name (e.g., "tc_elements:brimstone")
---@field title string Display title
---@field short_description string Concise HUD wield label
---@field texture string Primary static 32x32 tile/icon texture
---@field anim_texture? string Optional 32x256 vertical_frames animated node sheet texture
---@field anim_length? number Optional animation cycle duration in seconds
---@field accent string AA-accessible hex color token
---@field summary string Brief role description
---@field effect string Equilibrium & player hazard impact
---@field usage string Actionable counterplay instructions
---@field infotext_hint string Concise 3D crosshair hint when looking at the block
---@field tool_item string Primary counter tool itemstring
---@field pair_item string Opposing reagent itemstring for cancellation/transmutation
---@field voice string Wizard announcement line when dropped

---@class TcSproutStageSpec
---@field stage integer 1..4
---@field name string Registered node name
---@field title string Stage display title
---@field min_bloom number Minimum bloom threshold for this stage
---@field light integer Light source emission (0..14)
---@field scale number Visual plantlike scale

---@class TcElementsAPI
---@field REAGENTS TcReagentSpec[] Ordered list of the 4 falling volatile reagents
---@field REAGENT_BY_NAME table<string, TcReagentSpec> Lookup table by full node name
---@field CATALYST table Metadata definition for Level 2+ Prismatic Aether Geode
---@field SPROUT_STAGES TcSproutStageSpec[] Ordered list of the 4 Crucible Sprout growth stages
---@field get_sprout_stage fun(bloom: number): integer, string
---@field enrich_soil_at fun(pos: {x: integer, y: integer, z: integer}): boolean
---@field resonate_geode_at fun(pos: {x: integer, y: integer, z: integer}, user?: ObjectRef): integer
---@field spawn_falling_reagent fun(target_pos: {x: integer, y: integer, z: integer}, item_name: string)
---@field node_sound_stone_defaults fun(tbl?: table): table
---@field node_sound_dirt_defaults fun(tbl?: table): table
---@field node_sound_wood_defaults fun(tbl?: table): table
---@field node_sound_glass_defaults fun(tbl?: table): table
---@field node_sound_ice_defaults fun(tbl?: table): table
---@field node_sound_water_defaults fun(tbl?: table): table
---@field node_sound_crystal_defaults fun(tbl?: table): table
tc_elements = {
    node_sound_stone_defaults   = tc_assets.node_sound_stone_defaults,
    node_sound_dirt_defaults    = tc_assets.node_sound_dirt_defaults,
    node_sound_wood_defaults    = tc_assets.node_sound_wood_defaults,
    node_sound_glass_defaults   = tc_assets.node_sound_glass_defaults,
    node_sound_ice_defaults     = tc_assets.node_sound_ice_defaults,
    node_sound_water_defaults   = tc_assets.node_sound_water_defaults,
    node_sound_crystal_defaults = tc_assets.node_sound_crystal_defaults,
}

local P = tc_assets.PALETTE

tc_elements.REAGENTS = {
    {
        id = "brimstone",
        name = "tc_elements:brimstone",
        title = "Scorching Brimstone",
        short_description = "Scorching Brimstone (Hot Block — Splash Water [3])",
        texture = "tc_brimstone.png",
        anim_texture = "tc_brimstone_anim.png",
        anim_length = 2.2,
        accent = P.amber,
        summary = "A glowing-hot lava stone dropped in from above by the wizard.",
        effect = "Makes the room hotter, burns your feet if you stand on it, and dries out nearby green soil.",
        usage = "Left-Click with a filled Water Flask [3], or Right-Click with Trowel [1] " ..
            "and place it beside Ice to cancel both out!",
        infotext_hint = "Left-Click with Water Flask [3] · Right-Click with Trowel [1] to move",
        tool_item = "tc_tools:condenser_flask_full",
        pair_item = "tc_elements:cryo_ice",
        voice = "Dropping Scorching Brimstone! Splash it with Water Flask [3] or hit it mid-air for bonus growth!",
    },
    {
        id = "cryo_ice",
        name = "tc_elements:cryo_ice",
        title = "Glacial Ice Shard",
        short_description = "Glacial Ice Shard (Cold Block — Melt with Bellows [2])",
        texture = "tc_cryo_ice.png",
        accent = P.aqua,
        summary = "A freezing blue ice crystal that cools down the glass room.",
        effect = "Makes the room colder, makes the floor slippery, and chills nearby green soil.",
        usage = "Left-Click with Thermal Bellows [2] to melt into fresh Water (then refill your Water Flask [3]!).",
        infotext_hint = "Left-Click with Bellows [2] to melt, then scoop Water with Flask [3]",
        tool_item = "tc_tools:bellows",
        pair_item = "tc_elements:brimstone",
        voice = "Dropping a Glacial Ice Shard! Melt it with Bellows [2] (or catch it mid-air for bonus growth)!",
    },
    {
        id = "acid_slime",
        name = "tc_elements:acid_slime",
        title = "Vitriol Acid Slime",
        short_description = "Vitriol Acid Slime (Sour Puddle — Clear with Pestle [4])",
        texture = "tc_acid_slime.png",
        anim_texture = "tc_acid_slime_anim.png",
        anim_length = 2.0,
        accent = P.emerald,
        summary = "A bubbling green puddle that sours the soil and sticks to your boots.",
        effect = "Makes soil too sour, stings your feet, stops jumping while inside it, and spoils green soil.",
        usage = "Left-Click on or near it with Limestone Pestle [4] (or place Chalk beside it) " ..
            "to turn the floor into fast green Fertile Soil!",
        infotext_hint = "Left-Click with Pestle [4] · Place Chalk beside it for green Speed Soil",
        tool_item = "tc_tools:chalk_pestle",
        pair_item = "tc_elements:alkaline_chalk",
        voice = "Pouring green Acid Slime! Dust it with Pestle [4] to turn the floor into green Speed Soil!",
    },
    {
        id = "alkaline_chalk",
        name = "tc_elements:alkaline_chalk",
        title = "Alkaline Chalk",
        short_description = "Alkaline Chalk (Dry Block — Splash Water [3])",
        texture = "tc_alkaline_chalk.png",
        accent = P.violet,
        summary = "A dry, chalky crystal block that throws off soil balance.",
        effect = "Makes soil too chalky (alkaline); melts away on its own if flowing water touches it.",
        usage = "Left-Click with a filled Water Flask [3], " ..
            "or Right-Click with Trowel [1] and place it beside green Acid Slime!",
        infotext_hint = "Left-Click with Water Flask [3] · Right-Click with Trowel [1] to pair with Acid",
        tool_item = "tc_tools:condenser_flask_full",
        pair_item = "tc_elements:acid_slime",
        voice = "Dropping Alkaline Chalk! Splash it with Water Flask [3] or pair it beside green Acid Slime!",
    },
}

tc_elements.REAGENT_BY_NAME = {}
for i = 1, #tc_elements.REAGENTS do
    local r = tc_elements.REAGENTS[i]
    tc_elements.REAGENT_BY_NAME[r.name] = r
end

tc_elements.CATALYST = {
    id = "aether_geode",
    name = "tc_elements:aether_geode",
    title = "Prismatic Geode",
    short_description = "Prismatic Geode (Bonus Crystal — Hit with Trowel [1]!)",
    texture = "tc_aether_geode.png",
    anim_texture = "tc_aether_geode_anim.png",
    anim_length = 1.8,
    accent = P.gold,
    summary = "A shimmering rainbow crystal that drops in starting from Level 2.",
    effect = "Clears nearby hazards and turns the floor into green Speed Soil—or cracks into 2 hazards after 22s!",
    usage = "Left-Click or Right-Click it with your Trowel [1] (or set any block beside it) before time runs out!",
    voice = "A shimmering Prismatic Geode is falling! Hit it with Trowel [1] within 22s " ..
        "to clear nearby hazards and boost plant growth!",
}

tc_elements.SPROUT_STAGES = {
    {
        stage = 1,
        name = "tc_elements:crucible_sprout_1",
        title = "Crucible Seedling (Stage 1/4)",
        min_bloom = 0.0,
        light = 6,
        scale = 1.0,
    },
    {
        stage = 2,
        name = "tc_elements:crucible_sprout_2",
        title = "Crucible Vines (Stage 2/4)",
        min_bloom = 25.0,
        light = 9,
        scale = 1.05,
    },
    {
        stage = 3,
        name = "tc_elements:crucible_sprout_3",
        title = "Crucible Astral Rose (Stage 3/4)",
        min_bloom = 55.0,
        light = 12,
        scale = 1.12,
    },
    {
        stage = 4,
        name = "tc_elements:crucible_sprout_4",
        title = "Philosopher's Lotus (Stage 4/4 · Full Bloom)",
        min_bloom = 85.0,
        light = 14,
        scale = 1.28,
    },
}

---Returns the visual growth stage (1..4) and node name corresponding to the current Bloom %.
---@param bloom number Current bloom percentage (0..100)
---@return integer stage
---@return string node_name
function tc_elements.get_sprout_stage(bloom)
    for i = #tc_elements.SPROUT_STAGES, 1, -1 do
        local st = tc_elements.SPROUT_STAGES[i]
        if bloom >= st.min_bloom then
            return st.stage, st.name
        end
    end
    return 1, "tc_elements:crucible_sprout_1"
end

---Transmutes standard Alchemical Loam at (pos.x, 0, pos.z) into glowing Fertile Catalyst Soil.
---@param pos {x: integer, y: integer, z: integer}
---@return boolean transmuted True if loam was upgraded to fertile_loam
function tc_elements.enrich_soil_at(pos)
    local floor_pos = {x = pos.x, y = 0, z = pos.z}
    if core.get_node(floor_pos).name == "tc_elements:loam" then
        core.swap_node(floor_pos, {name = "tc_elements:fertile_loam"})
        local meta = core.get_meta(floor_pos)
        meta:set_string("infotext", tc_assets.format_infotext(
            "Fertile Soil",
            "Faster Plant Growth · Faster Running",
            "Walk on this glowing green soil to run much faster!"
        ))
        return true
    end
    return false
end

---Detonates a Prismatic Aether Geode into a 3x3 hazard purge, enriching soil & adding +4.5% (+0.5%/purge) scaled Bloom.
---@param pos {x: integer, y: integer, z: integer}
---@param user? ObjectRef
---@return integer purged_count
function tc_elements.resonate_geode_at(pos, user)
    if core.get_node(pos).name == "tc_elements:aether_geode" then
        core.remove_node(pos)
    end

    local minp = {x = pos.x - 1, y = 0, z = pos.z - 1}
    local maxp = {x = pos.x + 1, y = 3, z = pos.z + 1}
    local hazards = core.find_nodes_in_area(minp, maxp, {"group:reagent"})
    local purged = #hazards

    for i = 1, purged do
        core.remove_node(hazards[i])
    end

    for dz = -1, 1 do
        for dx = -1, 1 do
            tc_elements.enrich_soil_at({x = pos.x + dx, y = 0, z = pos.z + dz})
        end
    end

    core.sound_play("tc_geode_chime", {pos = pos, gain = 0.95, max_hear_distance = 28}, true)
    local PT = tc_assets.PARTICLES
    tc_assets.spawn_sheet_particles({
        amount = 32,
        time = 0.35,
        minpos = {x = pos.x - 1.2, y = pos.y, z = pos.z - 1.2},
        maxpos = {x = pos.x + 1.2, y = pos.y + 1.4, z = pos.z + 1.2},
        minvel = {x = -2.5, y = 1.5, z = -2.5},
        maxvel = {x = 2.5, y = 5.0, z = 2.5},
        minacc = {x = 0, y = -1.2, z = 0},
        maxacc = {x = 0, y = 0.4, z = 0},
        drag = {x = 0.6, y = 0.3, z = 0.6},
        jitter = {min = {x = -0.25, y = -0.1, z = -0.25}, max = {x = 0.25, y = 0.25, z = 0.25}},
        minexptime = 0.65,
        maxexptime = 1.35,
        minsize = 1.8,
        maxsize = 3.8,
        glow = 14,
        texpool = {
            tc_assets.make_sheet_tex_entry(PT.bloom, {scale_tween = {1.3, 0.55}}),
            tc_assets.make_sheet_tex_entry(PT.pollen, {scale_tween = {1.5, 0.4}}),
        },
    })

    local gain = tc_core.add_scaled_bloom(4.5 + (0.5 * purged), pos)
    if user and user:is_player() then
        tc_core.record_neutralization(user, 1 + purged)
    end

    local msg = string.format(
        "Prismatic Geode cracked open! Cleared %d nearby hazard(s), made green Speed Soil & +%.1f%% Bloom!",
        purged,
        gain
    )
    core.chat_send_all(
        tc_assets.chat_prefix("Bonus Crystal", P.gold) ..
        core.colorize(P.text_primary, msg)
    )
    return purged
end

local TRAIL_PARTICLE_BY_ITEM = {
    ["tc_elements:brimstone"]      = tc_assets.PARTICLES.ember,
    ["tc_elements:cryo_ice"]       = tc_assets.PARTICLES.droplet,
    ["tc_elements:acid_slime"]     = tc_assets.PARTICLES.pollen,
    ["tc_elements:alkaline_chalk"] = tc_assets.PARTICLES.pollen,
    ["tc_elements:aether_geode"]   = tc_assets.PARTICLES.bloom,
}

---Spawns a ground landing reticle telegraph and launches a physical 3D falling_reagent entity from above.
---@param target_pos {x: integer, y: integer, z: integer}
---@param item_name string
function tc_elements.spawn_falling_reagent(target_pos, item_name)
    local trail_sheet = TRAIL_PARTICLE_BY_ITEM[item_name] or tc_assets.PARTICLES.pollen

    -- Ground-level runic target reticle pulsing throughout the ~2.76s descent
    local ret_min = {x = target_pos.x - 0.35, y = target_pos.y - 0.42, z = target_pos.z - 0.35}
    local ret_max = {x = target_pos.x + 0.35, y = target_pos.y - 0.32, z = target_pos.z + 0.35}
    local zero_v = {x = 0, y = 0.15, z = 0}
    core.add_particlespawner({
        amount = 24,
        time = 2.65,
        pos = {min = ret_min, max = ret_max},
        vel = {min = zero_v, max = {x = 0, y = 0.45, z = 0}},
        exptime = {min = 0.55, max = 0.90},
        size = {min = 2.4, max = 3.8},
        texpool = {
            {name = "tc_drop_reticle.png", blend = "add", scale_tween = {3.2, 1.4}, alpha_tween = {0.95, 0.1}},
        },
        minpos = ret_min,
        maxpos = ret_max,
        minvel = zero_v,
        maxvel = {x = 0, y = 0.45, z = 0},
        minexptime = 0.55,
        maxexptime = 0.90,
        minsize = 2.4,
        maxsize = 3.8,
        texture = "tc_drop_reticle.png",
        glow = 13,
    })

    -- Upper animated particle trail shimmer guiding the eye down into the chamber
    tc_assets.spawn_sheet_particles({
        amount = 20,
        time = 1.4,
        minpos = {x = target_pos.x - 0.18, y = 13.5, z = target_pos.z - 0.18},
        maxpos = {x = target_pos.x + 0.18, y = 14.5, z = target_pos.z + 0.18},
        minvel = {x = -0.15, y = -4.5, z = -0.15},
        maxvel = {x = 0.15, y = -6.5, z = 0.15},
        minexptime = 0.7,
        maxexptime = 1.2,
        minsize = 1.6,
        maxsize = 3.0,
        glow = 12,
        texpool = {
            tc_assets.make_sheet_tex_entry(trail_sheet, {scale_tween = {1.3, 0.55}, alpha_tween = {0.95, 0.1}}),
        },
    })

    local spawn_pos = {x = target_pos.x, y = 14.0, z = target_pos.z}
    core.add_entity(spawn_pos, "tc_elements:falling_reagent", item_name)
end
