---@class TcReagentSpec
---@field id string Short identifier (e.g., "brimstone")
---@field name string Full registered node name (e.g., "tc_elements:brimstone")
---@field title string Display title
---@field short_description string Concise HUD wield label
---@field hud_short string Compact HUD Drop Forecast reagent label
---@field hud_counter string Compact HUD Drop Forecast counter-tool label
---@field tool_icon string Counter-tool icon texture filename
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
---@field S fun(str: string, ...: any): string Mod translator function
---@field REAGENTS TcReagentSpec[] Ordered list of the 4 falling volatile reagents
---@field REAGENT_BY_NAME table<string, TcReagentSpec> Lookup table by full node name
---@field CATALYST table Metadata definition for Level 2+ Prismatic Aether Geode
---@field RETICLE_TEXTURE_BY_ITEM table<string, string> Luanti 5.18 ^[colorizehsl: landing reticles by item
---@field SPROUT_STAGES TcSproutStageSpec[] Ordered list of the 4 Crucible Sprout growth stages
---@field get_sprout_stage fun(bloom: number): integer, string
---@field enrich_soil_at fun(pos: {x: integer, y: integer, z: integer}): boolean
---@field resonate_geode_at fun(pos: {x: integer, y: integer, z: integer}, user?: ObjectRef): integer
---@field spawn_falling_reagent fun(target_pos: {x: integer, y: integer, z: integer}, item_name: string)
---@field can_tool_catch_reagent fun(itemstack: ItemStack, item_name: string): boolean
---@field interact_falling_reagent fun(target: any, user: ObjectRef, itemstack?: ItemStack): ItemStack, boolean, boolean
---@field find_interceptable_reagent fun(user: ObjectRef, pointed_thing?: table, itemstack?: ItemStack): table|nil
---@field count_falling_hazards fun(): integer, string|nil
---@field node_sound_stone_defaults fun(tbl?: table): table
---@field node_sound_dirt_defaults fun(tbl?: table): table
---@field node_sound_wood_defaults fun(tbl?: table): table
---@field node_sound_glass_defaults fun(tbl?: table): table
---@field node_sound_ice_defaults fun(tbl?: table): table
---@field node_sound_water_defaults fun(tbl?: table): table
---@field node_sound_crystal_defaults fun(tbl?: table): table
tc_elements = {
    S                           = core.get_translator("tc_elements"),
    node_sound_stone_defaults   = tc_assets.node_sound_stone_defaults,
    node_sound_dirt_defaults    = tc_assets.node_sound_dirt_defaults,
    node_sound_wood_defaults    = tc_assets.node_sound_wood_defaults,
    node_sound_glass_defaults   = tc_assets.node_sound_glass_defaults,
    node_sound_ice_defaults     = tc_assets.node_sound_ice_defaults,
    node_sound_water_defaults   = tc_assets.node_sound_water_defaults,
    node_sound_crystal_defaults = tc_assets.node_sound_crystal_defaults,
}

local S = tc_elements.S
local P = tc_assets.PALETTE

tc_elements.REAGENTS = {
    {
        id = "brimstone",
        name = "tc_elements:brimstone",
        title = S("Scorching Brimstone"),
        short_description = S("Scorching Brimstone (Hot Block — Splash Water [3])"),
        hud_short = S("Brimstone"),
        hud_counter = S("Flask [3]"),
        tool_icon = "tc_tool_flask_water.png",
        texture = "tc_brimstone.png",
        anim_texture = "tc_brimstone_anim.png",
        anim_length = 2.2,
        accent = P.amber,
        summary = S("A glowing-hot lava stone dropped in from above by the wizard."),
        effect = S("Raises heat, burns your boots (2 HP/s) if stood on, bonks on impact, & scorches green soil."),
        usage = S("Splash with Flask [3], siphon with low Bellows [2] to refill all Puffs, " ..
            "or pair with Ice via Trowel [1]!"),
        infotext_hint = S("Splash with Flask [3] · Siphon with low Bellows [2] · Pair with Ice [1]"),
        tool_item = "tc_tools:condenser_flask_full",
        pair_item = "tc_elements:cryo_ice",
        voice = S("Dropping Scorching Brimstone! Splash it with Water Flask [3] or hit it mid-air for bonus growth!"),
    },
    {
        id = "cryo_ice",
        name = "tc_elements:cryo_ice",
        title = S("Glacial Ice Shard"),
        short_description = S("Glacial Ice Shard (Cold Block — Melt with Bellows [2])"),
        hud_short = S("Ice"),
        hud_counter = S("Bellows [2]"),
        tool_icon = "tc_tool_bellows.png",
        texture = "tc_cryo_ice.png",
        accent = P.aqua,
        summary = S("A freezing blue ice crystal that cools down the glass room."),
        effect = S("Makes the room colder, makes the floor slippery, and chills nearby green soil."),
        usage = S("Left-Click with Thermal Bellows [2] to melt into fresh Water (then refill your Water Flask [3]!)."),
        infotext_hint = S("Left-Click with Bellows [2] to melt, then scoop Water with Flask [3]"),
        tool_item = "tc_tools:bellows",
        pair_item = "tc_elements:brimstone",
        voice = S("Dropping a Glacial Ice Shard! Melt it with Bellows [2] (or catch it mid-air for bonus growth)!"),
    },
    {
        id = "acid_slime",
        name = "tc_elements:acid_slime",
        title = S("Vitriol Acid Slime"),
        short_description = S("Vitriol Acid Slime (Sour Puddle — Clear with Pestle [4])"),
        hud_short = S("Acid"),
        hud_counter = S("Pestle [4]"),
        tool_icon = "tc_tool_pestle.png",
        texture = "tc_acid_slime.png",
        anim_texture = "tc_acid_slime_anim.png",
        anim_length = 2.0,
        accent = P.emerald,
        summary = S("A bubbling green puddle that sours the soil and sticks to your boots."),
        effect = S("Sours soil, slows & stings your feet (2 HP/s), stops jumping inside it, & spoils green soil."),
        usage = S("Left-Click on or near it with Limestone Pestle [4] (or place Chalk beside it) " ..
            "to turn the floor into fast green Fertile Soil!"),
        infotext_hint = S("Left-Click with Pestle [4] · Place Chalk beside it for green Speed Soil"),
        tool_item = "tc_tools:chalk_pestle",
        pair_item = "tc_elements:alkaline_chalk",
        voice = S("Pouring green Acid Slime! Dust it with Pestle [4] to turn the floor into green Speed Soil!"),
    },
    {
        id = "alkaline_chalk",
        name = "tc_elements:alkaline_chalk",
        title = S("Alkaline Chalk"),
        short_description = S("Alkaline Chalk (Dry Block — Splash Water [3])"),
        hud_short = S("Chalk"),
        hud_counter = S("Flask [3]"),
        tool_icon = "tc_tool_flask_water.png",
        texture = "tc_alkaline_chalk.png",
        accent = P.violet,
        summary = S("A dry, chalky crystal block that throws off soil balance."),
        effect = S("Makes soil too chalky (alkaline); melts away on its own if flowing water touches it."),
        usage = S("Wash with Flask [3], grind with low Pestle [4] to refill all Sweeps, " ..
            "or pair with Acid via Trowel [1]!"),
        infotext_hint = S("Wash with Flask [3] · Grind with low Pestle [4] · Pair with Acid [1]"),
        tool_item = "tc_tools:condenser_flask_full",
        pair_item = "tc_elements:acid_slime",
        voice = S("Dropping Alkaline Chalk! Splash it with Water Flask [3] or pair it beside green Acid Slime!"),
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
    title = S("Prismatic Geode"),
    short_description = S("Prismatic Geode (Bonus Crystal — Hit with Trowel [1]!)"),
    hud_short = S("Geode"),
    hud_counter = S("Trowel [1]"),
    tool_icon = "tc_tool_trowel.png",
    texture = "tc_aether_geode.png",
    anim_texture = "tc_aether_geode_anim.png",
    anim_length = 1.8,
    accent = P.gold,
    summary = S("A shimmering rainbow crystal that drops in starting from Level 2."),
    effect = S("Clears nearby hazards, makes Speed Soil, refills all Tools [2–4], & rewards +1 Aegis Potion!"),
    usage = S("Left-Click or Right-Click it with your Trowel [1] (or set any block beside it) before time runs out!"),
    voice = S("A shimmering Prismatic Geode is falling! Hit it with Trowel [1] within 22s " ..
        "for +1 Aegis Potion, green Speed Soil, & bonus Bloom!"),
}

tc_elements.SPROUT_STAGES = {
    {
        stage = 1,
        name = "tc_elements:crucible_sprout_1",
        title = S("Crucible Seedling (Stage 1/4)"),
        min_bloom = 0.0,
        light = 6,
        scale = 1.0,
    },
    {
        stage = 2,
        name = "tc_elements:crucible_sprout_2",
        title = S("Crucible Vines (Stage 2/4)"),
        min_bloom = 25.0,
        light = 9,
        scale = 1.05,
    },
    {
        stage = 3,
        name = "tc_elements:crucible_sprout_3",
        title = S("Crucible Astral Rose (Stage 3/4)"),
        min_bloom = 55.0,
        light = 12,
        scale = 1.12,
    },
    {
        stage = 4,
        name = "tc_elements:crucible_sprout_4",
        title = S("Philosopher's Lotus (Stage 4/4 · Full Bloom)"),
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
            S("Fertile Soil"),
            S("Faster Plant Growth · Faster Running"),
            S("Walk on this glowing green soil to run much faster!")
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

    local all_players = core.get_connected_players()
    for i = 1, #all_players do
        tc_tools.refill_player_tools(all_players[i])
    end

    local gain = tc_core.add_scaled_bloom(4.5 + (0.5 * purged), pos)
    local recipient = (user and user:is_player()) and user or nil
    if not recipient then
        local best_d2 = math.huge
        for i = 1, #all_players do
            local pl = all_players[i]
            local pp = pl:get_pos()
            local dx, dz = pp.x - pos.x, pp.z - pos.z
            local d2 = (dx * dx) + (dz * dz)
            if d2 < best_d2 then
                best_d2 = d2
                recipient = pl
            end
        end
    end

    local detail_str = S("Tools [2–4] Refilled")
    if recipient then
        tc_core.record_neutralization(recipient, 1 + purged)
        local added_a, over_a, over_gain = tc_core.grant_potion(recipient, "tc_tools:elixir_aegis", 1)
        if added_a > 0 then
            detail_str = S("Tools [2–4] Refilled · +1 Aegis!")
        elseif over_a > 0 then
            gain = gain + over_gain
            detail_str = S("Tools [2–4] Refilled · Belt Full Bonus!")
        end
    end

    tc_core.push_hud_event({
        priority = 2,
        icon = "tc_aether_geode.png",
        title = S("✦ Geode Cracked! (+@1% Bloom)", string.format("%.1f", gain)),
        detail = detail_str,
        color = P.hud_gold,
        accent_hex = P.gold,
        ttl = 3.8,
    })
    return purged
end

local TRAIL_PARTICLE_BY_ITEM = {
    ["tc_elements:brimstone"]      = tc_assets.PARTICLES.ember,
    ["tc_elements:cryo_ice"]       = tc_assets.PARTICLES.droplet,
    ["tc_elements:acid_slime"]     = tc_assets.PARTICLES.pollen,
    ["tc_elements:alkaline_chalk"] = tc_assets.PARTICLES.pollen,
    ["tc_elements:aether_geode"]   = tc_assets.PARTICLES.bloom,
}

-- Luanti 5.18 ^[colorizehsl:<hue>:<sat>:<lightness> alpha-preserving landing reticles
tc_elements.RETICLE_TEXTURE_BY_ITEM = {
    ["tc_elements:brimstone"]      = "tc_drop_reticle.png^[colorizehsl:-28:90:5",
    ["tc_elements:cryo_ice"]       = "tc_drop_reticle.png^[colorizehsl:148:85:10",
    ["tc_elements:acid_slime"]     = "tc_drop_reticle.png^[colorizehsl:88:85:5",
    ["tc_elements:alkaline_chalk"] = "tc_drop_reticle.png^[colorizehsl:-115:65:12",
    ["tc_elements:aether_geode"]   = "tc_drop_reticle.png^[colorizehsl:8:95:14",
}

---Spawns a ground landing reticle telegraph and launches a physical 3D falling_reagent entity from above.
---@param target_pos {x: integer, y: integer, z: integer}
---@param item_name string
function tc_elements.spawn_falling_reagent(target_pos, item_name)
    local trail_sheet = TRAIL_PARTICLE_BY_ITEM[item_name] or tc_assets.PARTICLES.pollen
    local reticle_tex = tc_elements.RETICLE_TEXTURE_BY_ITEM[item_name] or "tc_drop_reticle.png"

    -- Ground-level runic target reticle pulsing throughout descent (~2.65s base, ~3.5s with Featherfall Winds)
    local ret_min = {x = target_pos.x - 0.35, y = target_pos.y - 0.42, z = target_pos.z - 0.35}
    local ret_max = {x = target_pos.x + 0.35, y = target_pos.y - 0.32, z = target_pos.z + 0.35}
    local zero_v = {x = 0, y = 0.15, z = 0}
    local ret_time = tc_core.has_blessing("featherfall_canopy") and 3.50 or 2.65
    core.add_particlespawner({
        amount = 24,
        time = ret_time,
        pos = {min = ret_min, max = ret_max},
        vel = {min = zero_v, max = {x = 0, y = 0.45, z = 0}},
        exptime = {min = 0.55, max = 0.90},
        size = {min = 2.4, max = 3.8},
        texpool = {
            {name = reticle_tex, blend = "add", scale_tween = {3.2, 1.4}, alpha_tween = {0.95, 0.1}},
        },
        minpos = ret_min,
        maxpos = ret_max,
        minvel = zero_v,
        maxvel = {x = 0, y = 0.45, z = 0},
        minexptime = 0.55,
        maxexptime = 0.90,
        minsize = 2.4,
        maxsize = 3.8,
        texture = reticle_tex,
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
