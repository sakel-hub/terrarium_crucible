-- tc_core: Multi-level equilibrium engine, reagent drops, chemical reactions, and global tick loop
local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/api.lua")
dofile(modpath .. "/hud.lua")
dofile(modpath .. "/ui.lua")

local P = tc_assets.PALETTE
local S = tc_core.S

-- Emerge initial arena mapblocks asynchronously after startup and initialize Level 1
core.after(0, function()
    tc_world.emerge_initial_area(function()
        if #tc_core.state.plants == 0 then
            tc_core.start_level(1, false)
        end
    end)
end)

-- ========================================================
-- PLAYER JOIN ONBOARDING
-- ========================================================

core.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    tc_core.init_player_fov(player)

    if #tc_core.state.plants == 0 and tc_world.is_ready then
        tc_core.start_level(1, false)
    end
    tc_core.sync_joining_player(player)

    tc_core.init_player_hud(player)

    tc_core.push_hud_event_player(player, {
        priority = 1,
        icon = "tc_crucible_sprout_2.png",
        title = S("✦ Welcome to the Garden!"),
        detail = S("[1–4] Tools · [5] Guide · [I] Bag"),
        color = P.hud_gold,
        accent_hex = P.gold,
        ttl = 4.8,
    })

    core.after(0.2, function()
        local joined = core.get_player_by_name(name)
        if joined and joined:is_player() then
            x_player_api.play_emote(joined, "wave", 2.2)
        end
    end)
end)

-- ========================================================
-- MULTI-CHAMBER PHYSICAL REAGENT DROP MECHANIC
-- ========================================================

local wave_cell_cursor = 0

local function drop_item_in_cell(cell, level, item_name)
    local target_x = tc_core.next_random(cell.min_x + 1, cell.max_x - 1)
    local target_z = tc_core.next_random(cell.min_z + 1, cell.max_z - 1)

    if tc_world.is_protected_pos({x = target_x, y = 1, z = target_z}, level) then
        target_x = cell.center.x + 2
        target_z = cell.center.z + 2
    end

    local land_y = 1
    for y = 9, 1, -1 do
        local n_name = core.get_node({x = target_x, y = y, z = target_z}).name
        if n_name ~= "air" and n_name ~= "tc_elements:steam" then
            land_y = y + 1
            break
        end
    end

    tc_elements.spawn_falling_reagent({x = target_x, y = land_y, z = target_z}, item_name)
end

local TRIAL_HUD_SPECS = {
    {
        icon = "tc_tool_trowel.png",
        title = S("★ Trial: Twin Opposites!"),
        detail = S("Pair Hot+Cold or Acid+Chalk [1]!"),
    },
    {
        icon = "tc_tool_flask_water.png",
        title = S("★ Trial: Ember Shower!"),
        detail = S("Quench Brimstone with Flask [3]!"),
    },
    {
        icon = "tc_tool_bellows.png",
        title = S("★ Trial: Frost Squall!"),
        detail = S("Melt blue Ice with Bellows [2]!"),
    },
    {
        icon = "tc_tool_pestle.png",
        title = S("★ Trial: Sour Drizzle!"),
        detail = S("Sweep green Acid with Pestle [4]!"),
    },
}

local function trigger_reagent_drop()
    local s = tc_core.state
    local cells = tc_world.get_active_cells(s.level)
    local p_list = core.get_connected_players()
    local p_cnt = math.max(1, #p_list)
    local preview = tc_core.ensure_next_wave(p_cnt)
    local items = preview.items
    local total_drops = #items

    s.wave = preview.wave_num
    s.reagents_dropped = s.reagents_dropped + total_drops
    if preview.kind == "trial" and preview.trial_id > 0 then
        s.trial_cursor = preview.trial_id
    end

    local wave_epoch = s.epoch
    local wave_lvl = s.level

    for d = 1, total_drops do
        wave_cell_cursor = (wave_cell_cursor % #cells) + 1
        local cell = cells[wave_cell_cursor]
        local item_to_drop = items[d]

        if d == 1 then
            drop_item_in_cell(cell, wave_lvl, item_to_drop)
        else
            local delay = (d - 1) * 0.70
            core.after(delay, function()
                if tc_core.state.running and not tc_core.state.cleanup_phase
                        and tc_core.state.epoch == wave_epoch then
                    core.sound_play(
                        "tc_drop_warning",
                        {pos = cell.center, gain = 0.55, max_hear_distance = 24},
                        true
                    )
                    drop_item_in_cell(cell, wave_lvl, item_to_drop)
                end
            end)
        end
    end

    s.active_drop = {
        wave_num = preview.wave_num,
        level = wave_lvl,
        kind = preview.kind,
        trial_id = preview.trial_id,
        items = items,
        ttl = math.max(2.6, 1.9 + ((total_drops - 1) * 0.70)),
    }
    tc_core.roll_next_wave(p_cnt)

    for i = 1, #p_list do
        tc_core.sync_player_drop_hud(p_list[i])
    end

    if preview.kind == "trial" then
        local tspec = TRIAL_HUD_SPECS[preview.trial_id] or TRIAL_HUD_SPECS[1]
        tc_core.push_hud_event({
            priority = 2,
            icon = tspec.icon,
            title = tspec.title,
            detail = tspec.detail,
            color = P.hud_violet,
            accent_hex = P.violet,
            ttl = 4.2,
        })
    elseif preview.kind == "geode" then
        tc_core.push_hud_event({
            priority = 2,
            icon = "tc_aether_geode.png",
            title = S("✦ Bonus Geode Falling!"),
            detail = S("Crack with Trowel [1] within 22s!"),
            color = P.hud_aqua,
            accent_hex = P.aqua,
            ttl = 4.2,
        })
    end

    core.sound_play("tc_drop_warning", {gain = 0.8}, true)
end

-- ========================================================
-- EQUILIBRIUM, MULTI-PLANT VITALITY & REACTION ENGINE
-- ========================================================

local chime_timer = 0
local CARDINAL_DIRS = {
    {x = 1, y = 0, z = 0},
    {x = -1, y = 0, z = 0},
    {x = 0, y = 0, z = 1},
    {x = 0, y = 0, z = -1},
}

local TARGET_NODES = {
    "tc_elements:brimstone",
    "tc_elements:cryo_ice",
    "tc_elements:acid_slime",
    "tc_elements:alkaline_chalk",
    "tc_elements:water_source",
    "tc_elements:fertile_loam",
    "tc_elements:steam",
}

-- Pre-allocated scan vectors to prevent per-step allocations
local scan_minp = {x = 0, y = 0, z = 0}
local scan_maxp = {x = 0, y = 7, z = 0}
local probe_pos = {x = 0, y = 0, z = 0}

local function spawn_plant_particles(pos, mode)
    local PT = tc_assets.PARTICLES
    if mode == "harmony" then
        tc_assets.spawn_sheet_particles({
            amount = 7,
            time = 0.85,
            minpos = {x = pos.x - 0.38, y = pos.y - 0.05, z = pos.z - 0.38},
            maxpos = {x = pos.x + 0.38, y = pos.y + 0.85, z = pos.z + 0.38},
            minvel = {x = -0.22, y = 0.45, z = -0.22},
            maxvel = {x = 0.22, y = 1.15, z = 0.22},
            jitter = {min = {x = -0.1, y = -0.05, z = -0.1}, max = {x = 0.1, y = 0.1, z = 0.1}},
            minexptime = 0.65,
            maxexptime = 1.35,
            minsize = 1.2,
            maxsize = 2.5,
            glow = 13,
            texpool = {
                tc_assets.make_sheet_tex_entry(PT.pollen, {scale_tween = {1.25, 0.45}}),
                tc_assets.make_sheet_tex_entry(PT.bloom, {scale_tween = {1.15, 0.55}}),
            },
        })
    else
        tc_assets.spawn_sheet_particles({
            amount = 6,
            time = 0.80,
            minpos = {x = pos.x - 0.32, y = pos.y + 0.05, z = pos.z - 0.32},
            maxpos = {x = pos.x + 0.32, y = pos.y + 0.75, z = pos.z + 0.32},
            minvel = {x = -0.18, y = 0.55, z = -0.18},
            maxvel = {x = 0.18, y = 1.25, z = 0.18},
            minexptime = 0.55,
            maxexptime = 1.15,
            minsize = 1.3,
            maxsize = 2.6,
            glow = (mode == "withered") and 2 or 5,
            texpool = {
                tc_assets.make_sheet_tex_entry(PT.steam, {
                    blend = "alpha",
                    scale_tween = {0.85, 1.9},
                    alpha_tween = {0.8, 0.0},
                }),
            },
        })
    end
end

local function spawn_stage_blossom_particles(pos)
    local PT = tc_assets.PARTICLES
    tc_assets.spawn_sheet_particles({
        amount = 24,
        time = 0.35,
        minpos = {x = pos.x - 0.5, y = pos.y - 0.1, z = pos.z - 0.5},
        maxpos = {x = pos.x + 0.5, y = pos.y + 1.0, z = pos.z + 0.5},
        minvel = {x = -1.3, y = 1.0, z = -1.3},
        maxvel = {x = 1.3, y = 3.0, z = 1.3},
        drag = {x = 0.5, y = 0.3, z = 0.5},
        minexptime = 0.70,
        maxexptime = 1.45,
        minsize = 1.6,
        maxsize = 3.4,
        glow = 14,
        texpool = {
            tc_assets.make_sheet_tex_entry(PT.bloom, {scale_tween = {1.35, 0.55}}),
            tc_assets.make_sheet_tex_entry(PT.pollen, {scale_tween = {1.3, 0.4}}),
        },
    })
end

local function spawn_brimstone_ambient(pos)
    local PT = tc_assets.PARTICLES
    tc_assets.spawn_sheet_particles({
        amount = 5,
        time = 0.9,
        minpos = {x = pos.x - 0.35, y = pos.y + 0.35, z = pos.z - 0.35},
        maxpos = {x = pos.x + 0.35, y = pos.y + 0.60, z = pos.z + 0.35},
        minvel = {x = -0.25, y = 0.65, z = -0.25},
        maxvel = {x = 0.25, y = 1.55, z = 0.25},
        jitter = {min = {x = -0.12, y = 0.0, z = -0.12}, max = {x = 0.12, y = 0.15, z = 0.12}},
        minexptime = 0.45,
        maxexptime = 0.95,
        minsize = 1.0,
        maxsize = 2.1,
        glow = 13,
        texpool = {
            tc_assets.make_sheet_tex_entry(PT.ember, {scale_tween = {1.25, 0.35}}),
            tc_assets.make_sheet_tex_entry(PT.steam, {
                blend = "alpha",
                scale_tween = {0.75, 1.6},
                alpha_tween = {0.55, 0.0},
            }),
        },
    })
end

---Analyzes unconsumed reagents, fertile soil, and warm steam inside a sprout's chamber without extra C++ scans.
---@param ppos {x: integer, y: integer, z: integer}
---@param cell CellInfo
---@param consumed table<integer, boolean>
---@param l_brim table[]
---@param l_cryo table[]
---@param l_acid table[]
---@param l_chalk table[]
---@param l_fertile table[]
---@param l_steam table[]
---@return integer near_hazards, boolean local_stress, integer fertile_in_cell, boolean near_steam
local function analyze_plant_chamber(ppos, cell, consumed, l_brim, l_cryo, l_acid, l_chalk, l_fertile, l_steam)
    local px, py, pz = ppos.x, ppos.y, ppos.z
    local near = 0
    local counts = {0, 0, 0, 0}
    local lists = {l_brim, l_cryo, l_acid, l_chalk}

    for li = 1, 4 do
        local list = lists[li]
        local c_in_cell = 0
        for j = 1, #list do
            local rpos = list[j]
            if not consumed[core.hash_node_position(rpos)] then
                if math.abs(rpos.x - px) <= 2
                        and math.abs(rpos.z - pz) <= 2
                        and rpos.y >= (py - 1)
                        and rpos.y <= (py + 2) then
                    near = near + 1
                end
                if cell and rpos.x >= cell.min_x and rpos.x <= cell.max_x
                        and rpos.z >= cell.min_z and rpos.z <= cell.max_z then
                    c_in_cell = c_in_cell + 1
                end
            end
        end
        counts[li] = c_in_cell
    end

    local fertile_in_cell = 0
    if cell and l_fertile then
        for j = 1, #l_fertile do
            local fpos = l_fertile[j]
            if not consumed[core.hash_node_position(fpos)]
                    and fpos.x >= cell.min_x and fpos.x <= cell.max_x
                    and fpos.z >= cell.min_z and fpos.z <= cell.max_z then
                fertile_in_cell = fertile_in_cell + 1
            end
        end
    end

    local near_steam = false
    if l_steam then
        for j = 1, #l_steam do
            local spos = l_steam[j]
            if math.abs(spos.x - px) <= 2
                    and math.abs(spos.z - pz) <= 2
                    and spos.y >= (py - 1)
                    and spos.y <= (py + 2) then
                near_steam = true
                break
            end
        end
    end

    local local_stress = (math.abs(counts[1] - counts[2]) >= 2)
        or (math.abs(counts[4] - counts[3]) >= 2)
    return near, local_stress, fertile_in_cell, near_steam
end

local function simulation_step()
    local s = tc_core.state
    local players = core.get_connected_players()
    if #players == 0 then
        return
    end

    if not s.running then
        for i = 1, #players do
            tc_core.update_player_hud(players[i])
        end
        return
    end

    local center = core.get_node({x = 0, y = 1, z = 0})
    if center.name == "ignore" then
        return
    end

    if #s.plants == 0 then
        tc_core.start_level(s.level, false)
    end
    tc_core.sync_external_bloom()

    s.seconds_elapsed = s.seconds_elapsed + 1
    s.run_seconds = s.run_seconds + 1

    if s.aegis_timer > 0 then
        s.aegis_timer = math.max(0.0, s.aegis_timer - 1.0)
    end
    if s.stasis_timer > 0 then
        s.stasis_timer = math.max(0.0, s.stasis_timer - 1.0)
    end

    -- Single C++ spatial scan across the active crucible bounding box
    local bbox = tc_world.get_bounding_box(s.level)
    scan_minp.x, scan_minp.y, scan_minp.z = bbox.min_x, 0, bbox.min_z
    scan_maxp.x, scan_maxp.y, scan_maxp.z = bbox.max_x, 7, bbox.max_z

    local node_positions = core.find_nodes_in_area(scan_minp, scan_maxp, TARGET_NODES, true)

    local brim_list    = node_positions["tc_elements:brimstone"] or {}
    local cryo_list    = node_positions["tc_elements:cryo_ice"] or {}
    local acid_list    = node_positions["tc_elements:acid_slime"] or {}
    local chalk_list   = node_positions["tc_elements:alkaline_chalk"] or {}
    local w_src_list   = node_positions["tc_elements:water_source"] or {}
    local fertile_list = node_positions["tc_elements:fertile_loam"] or {}
    local steam_list   = node_positions["tc_elements:steam"] or {}

    local brimstone_cnt = #brim_list
    local cryo_cnt      = #cryo_list
    local acid_cnt      = #acid_list
    local chalk_cnt     = #chalk_list
    local water_cnt     = #w_src_list
    local reactions_to_execute = {}

    -- Discover adjacent thermal & acid-base reactions
    for i = 1, #brim_list do
        local pos = brim_list[i]
        for d = 1, 4 do
            local dir = CARDINAL_DIRS[d]
            probe_pos.x, probe_pos.y, probe_pos.z = pos.x + dir.x, pos.y + dir.y, pos.z + dir.z
            local adj_n = core.get_node(probe_pos).name
            if adj_n == "tc_elements:cryo_ice" then
                reactions_to_execute[#reactions_to_execute + 1] = {
                    type = "melt_cancel",
                    pos_ice = {x = probe_pos.x, y = probe_pos.y, z = probe_pos.z},
                    pos_brim = pos,
                }
            elseif adj_n == "tc_elements:water_source" or adj_n == "tc_elements:water_flowing" then
                reactions_to_execute[#reactions_to_execute + 1] = {
                    type = "steam",
                    pos_water = {x = probe_pos.x, y = probe_pos.y, z = probe_pos.z},
                    pos_brim = pos,
                }
            end
        end
    end

    for i = 1, #acid_list do
        local pos = acid_list[i]
        for d = 1, 4 do
            local dir = CARDINAL_DIRS[d]
            probe_pos.x, probe_pos.y, probe_pos.z = pos.x + dir.x, pos.y + dir.y, pos.z + dir.z
            if core.get_node(probe_pos).name == "tc_elements:alkaline_chalk" then
                reactions_to_execute[#reactions_to_execute + 1] = {
                    type = "neutralize",
                    pos_acid = pos,
                    pos_chalk = {x = probe_pos.x, y = probe_pos.y, z = probe_pos.z},
                }
            end
        end
        probe_pos.x, probe_pos.y, probe_pos.z = pos.x, pos.y - 1, pos.z
        if core.get_node(probe_pos).name == "tc_elements:fertile_loam" then
            reactions_to_execute[#reactions_to_execute + 1] = {
                type = "corrode_soil",
                pos_acid = pos,
                pos_soil = {x = probe_pos.x, y = probe_pos.y, z = probe_pos.z},
            }
        end
    end

    for i = 1, #chalk_list do
        local pos = chalk_list[i]
        for d = 1, 4 do
            local dir = CARDINAL_DIRS[d]
            probe_pos.x, probe_pos.y, probe_pos.z = pos.x + dir.x, pos.y + dir.y, pos.z + dir.z
            local adj_w = core.get_node(probe_pos).name
            if adj_w == "tc_elements:water_source" or adj_w == "tc_elements:water_flowing" then
                reactions_to_execute[#reactions_to_execute + 1] = {
                    type = "dissolve_chalk",
                    pos_chalk = pos,
                    pos_water = {x = probe_pos.x, y = probe_pos.y, z = probe_pos.z},
                }
            end
        end
    end

    -- Execute reactions safely with position hash deduplication
    local consumed = {}
    local executed_cnt = 0
    local max_rx = 2 * s.level

    for i = 1, #reactions_to_execute do
        if executed_cnt >= max_rx then
            break
        end
        local r = reactions_to_execute[i]
        if r.type == "melt_cancel" then
            local h_ice = core.hash_node_position(r.pos_ice)
            local h_brim = core.hash_node_position(r.pos_brim)
            if not consumed[h_ice] and not consumed[h_brim] then
                consumed[h_ice] = true
                consumed[h_brim] = true
                executed_cnt = executed_cnt + 1

                tc_core.exec_melt_cancel(r.pos_ice, r.pos_brim)
                brimstone_cnt = math.max(0, brimstone_cnt - 1)
                cryo_cnt = math.max(0, cryo_cnt - 1)
                water_cnt = water_cnt + 1
            end
        elseif r.type == "neutralize" then
            local h_acid = core.hash_node_position(r.pos_acid)
            local h_chalk = core.hash_node_position(r.pos_chalk)
            if not consumed[h_acid] and not consumed[h_chalk] then
                consumed[h_acid] = true
                consumed[h_chalk] = true
                executed_cnt = executed_cnt + 1

                local floor_a = {x = r.pos_acid.x, y = 0, z = r.pos_acid.z}
                local floor_c = {x = r.pos_chalk.x, y = 0, z = r.pos_chalk.z}
                local was_loam_a = core.get_node(floor_a).name == "tc_elements:loam"
                local was_loam_c = core.get_node(floor_c).name == "tc_elements:loam"
                tc_core.exec_acid_base(r.pos_acid, r.pos_chalk)
                if was_loam_a then
                    fertile_list[#fertile_list + 1] = floor_a
                end
                if was_loam_c then
                    fertile_list[#fertile_list + 1] = floor_c
                end
                acid_cnt = math.max(0, acid_cnt - 1)
                chalk_cnt = math.max(0, chalk_cnt - 1)
            end
        elseif r.type == "steam" then
            local h_water = core.hash_node_position(r.pos_water)
            local h_brim = core.hash_node_position(r.pos_brim)
            if not consumed[h_water] and not consumed[h_brim] then
                consumed[h_water] = true
                consumed[h_brim] = true
                executed_cnt = executed_cnt + 1

                tc_core.exec_water_quench(r.pos_brim, r.pos_water)
                brimstone_cnt = math.max(0, brimstone_cnt - 1)
                water_cnt = math.max(0, water_cnt - 1)
            end
        elseif r.type == "dissolve_chalk" then
            local h_chalk = core.hash_node_position(r.pos_chalk)
            local h_water = core.hash_node_position(r.pos_water)
            if not consumed[h_chalk] and not consumed[h_water] then
                consumed[h_chalk] = true
                consumed[h_water] = true
                executed_cnt = executed_cnt + 1

                if tc_core.exec_water_dissolve_chalk(r.pos_chalk, r.pos_water) then
                    fertile_list[#fertile_list + 1] = {x = r.pos_chalk.x, y = 0, z = r.pos_chalk.z}
                end
                chalk_cnt = math.max(0, chalk_cnt - 1)
                water_cnt = math.max(0, water_cnt - 1)
            end
        elseif r.type == "corrode_soil" then
            local h_acid = core.hash_node_position(r.pos_acid)
            local h_soil = core.hash_node_position(r.pos_soil)
            if not consumed[h_acid] and not consumed[h_soil] then
                consumed[h_soil] = true
                executed_cnt = executed_cnt + 1

                core.swap_node(r.pos_soil, {name = "tc_elements:loam"})
                core.get_meta(r.pos_soil):set_string("infotext", "")
            end
        end
    end

    -- Track post-reaction un-neutralized hazard blocks for 8s Crucible Overload Meltdown & Final Sweep checks
    s.active_reagents = brimstone_cnt + cryo_cnt + acid_cnt + chalk_cnt
    s.max_reagents = 6 + (5 * s.level)

    local fall_cnt, first_fall = tc_elements.count_falling_hazards()
    local carry_cnt, first_carry = tc_tools.count_carried_hazards()
    s.falling_hazards = fall_cnt
    s.carried_hazards = carry_cnt
    s.remaining_hazards = s.active_reagents + fall_cnt + carry_cnt

    local icons = s.cleanup_icons
    local ic_n = 0
    if brimstone_cnt > 0 and ic_n < 4 then
        ic_n = ic_n + 1
        icons[ic_n] = "tc_elements:brimstone"
    end
    if cryo_cnt > 0 and ic_n < 4 then
        ic_n = ic_n + 1
        icons[ic_n] = "tc_elements:cryo_ice"
    end
    if acid_cnt > 0 and ic_n < 4 then
        ic_n = ic_n + 1
        icons[ic_n] = "tc_elements:acid_slime"
    end
    if chalk_cnt > 0 and ic_n < 4 then
        ic_n = ic_n + 1
        icons[ic_n] = "tc_elements:alkaline_chalk"
    end
    if ic_n == 0 and first_carry then
        ic_n = ic_n + 1
        icons[ic_n] = first_carry
    end
    if ic_n == 0 and first_fall then
        ic_n = ic_n + 1
        icons[ic_n] = first_fall
    end
    for k = #icons, ic_n + 1, -1 do
        icons[k] = nil
    end

    if s.active_reagents > s.max_reagents then
        s.overload_timer = (s.overload_timer or 0) + 1
        if s.overload_timer >= 8 then
            tc_core.trigger_defeat(
                S(
                    "Too many uncleared hazards (@1/@2 blocks piled up for 8 seconds and cracked the glass!)",
                    s.active_reagents, s.max_reagents
                ),
                "overload"
            )
            return
        elseif s.overload_timer == 1 or s.overload_timer == 5 then
            local rem = 8 - s.overload_timer
            local excess = s.active_reagents - s.max_reagents
            core.sound_play("tc_wither", {gain = 0.85}, true)
            tc_core.push_hud_event({
                priority = 3,
                icon = "tc_brimstone.png",
                title = S("✖ Too Many Hazards (@1/@2)!", s.active_reagents, s.max_reagents),
                detail = S("Clear @1 block(s) within @2s!", excess, rem),
                color = P.hud_coral,
                accent_hex = P.coral,
                ttl = 3.8,
            })
        end
    elseif (s.overload_timer or 0) > 0 then
        s.overload_timer = 0
        core.sound_play("tc_harmony_chime", {gain = 0.6}, true)
        tc_core.push_hud_event({
            priority = 2,
            icon = "tc_crucible_sprout_2.png",
            title = S("✦ Room Safe Again!"),
            detail = S("Overcrowding cleared — glass saved!"),
            color = P.hud_emerald,
            accent_hex = P.emerald,
            ttl = 3.2,
        })
    end

    -- Compute dynamic Temperature & pH normalized across chamber scale
    local scale_div = math.sqrt(s.level)
    local target_temp = 50.0 + ((brimstone_cnt * 13.0) - (cryo_cnt * 13.0) - (water_cnt * 1.5)) / scale_div
    local target_ph   = 50.0 + ((chalk_cnt * 12.0) - (acid_cnt * 12.0)) / scale_div

    s.temperature = tc_core.clamp(s.temperature + (target_temp - s.temperature) * 0.4, 0, 100)
    s.ph          = tc_core.clamp(s.ph + (target_ph - s.ph) * 0.4, 0, 100)

    local temp_extreme = (s.temperature > 75 or s.temperature < 25)
    local ph_extreme   = (s.ph < 25 or s.ph > 75)
    s.turbulent        = (s.active_reagents > s.level)
    local full_harmony = tc_core.is_in_harmony()

    local has_leyline = tc_core.has_blessing("leyline_roots")
    local revive_req = has_leyline and 4 or 6
    local harmony_regen = has_leyline and 3.5 or 2.0

    if full_harmony then
        s.harmony_streak = s.harmony_streak + 1
        s.peak_harmony = s.peak_harmony + 1

        -- Auto-revive 1 withered plant per 6s (4s with Ley-Line Roots) of sustained Perfect Harmony
        if s.harmony_streak >= revive_req then
            for i = 1, #s.plants do
                if s.plants[i].withered then
                    if tc_core.revive_sprout_at(s.plants[i].pos, nil, 50.0) then
                        s.harmony_streak = math.max(0, s.harmony_streak - revive_req)
                    end
                    break
                end
            end
        end

        -- Trigger Harmonic Overdrive boost at 8+ consecutive seconds of Harmony
        if s.harmony_streak >= 8 then
            for i = 1, #players do
                tc_core.apply_effect(players[i], "harmonic_overdrive", 2.5)
            end
        end
    else
        s.harmony_streak = 0
    end

    -- Evaluate 1.0s standing/wading hazard contact damage (Brimstone & Acid Slime) and Calm Balance player regen
    tc_core.step_player_hazards(full_harmony)

    -- Emit subtle ambient magma ember sparks from up to 2 unconsumed Brimstone hazards
    if #brim_list > 0 and (s.seconds_elapsed % 2 == 0) then
        local b_total = #brim_list
        local emit_b = math.min(2, b_total)
        for k = 1, emit_b do
            local bpos = brim_list[((s.seconds_elapsed + k) % b_total) + 1]
            if bpos and not consumed[core.hash_node_position(bpos)] then
                spawn_brimstone_ambient(bpos)
            end
        end
    end

    -- Update each plant's individual Vitality, Micro-Climate & Withered status without extra C++ queries
    local cells = tc_world.get_active_cells(s.level)
    local n_plants = #s.plants
    local living = 0
    local total_vit = 0.0

    for i = 1, n_plants do
        local p = s.plants[i]
        local near_hazards, local_stress, fertile_in_cell, near_steam = analyze_plant_chamber(
            p.pos, cells[i], consumed, brim_list, cryo_list, acid_list, chalk_list, fertile_list, steam_list
        )
        p.hazards_near = near_hazards
        p.local_stress = local_stress
        p.fertile_near = fertile_in_cell
        local vit_delta = 0.0
        local emit_ambient = ((s.seconds_elapsed + p.index) % 2 == 0)

        if not p.withered then
            if s.aegis_timer > 0 then
                vit_delta = 3.0
            else
                if temp_extreme then
                    vit_delta = vit_delta - 2.5
                end
                if ph_extreme then
                    vit_delta = vit_delta - 2.5
                end
                if near_hazards > 0 then
                    vit_delta = vit_delta - (near_hazards * 2.5)
                end
                if local_stress then
                    vit_delta = vit_delta - 1.5
                end
                if vit_delta < -6.5 then
                    vit_delta = -6.5
                end
                if full_harmony and near_hazards == 0 and not local_stress then
                    vit_delta = vit_delta + harmony_regen
                end
                if not temp_extreme and not ph_extreme and near_steam and p.vitality < 100.0 then
                    vit_delta = vit_delta + 0.6
                end
            end

            p.vitality = tc_core.clamp(p.vitality + vit_delta, 0.0, 100.0)
            if p.vitality <= 0.0 then
                p.withered = true
                p.vitality = 0.0
                p.last_infotext = nil
                core.swap_node(p.pos, {name = "tc_elements:crucible_sprout_withered"})
                core.sound_play("tc_wither", {pos = p.pos, gain = 0.9, max_hear_distance = 24}, true)
                tc_core.push_hud_event({
                    priority = 3,
                    icon = "tc_crucible_sprout_withered.png",
                    title = S("✖ Sprout #@1 WILTED!", p.index),
                    detail = S("Splash with Flask [3] or Aegis!"),
                    color = P.hud_coral,
                    accent_hex = P.coral,
                    ttl = 4.5,
                })
            end
        end

        if p.withered then
            if emit_ambient then
                spawn_plant_particles(p.pos, "withered")
            end
        else
            living = living + 1
            total_vit = total_vit + p.vitality
            if emit_ambient then
                if full_harmony and near_hazards == 0 and not local_stress then
                    spawn_plant_particles(p.pos, "harmony")
                elseif vit_delta < 0 then
                    spawn_plant_particles(p.pos, "distress")
                end
            end
        end
    end

    s.living_plants = living
    s.avg_vitality = (n_plants > 0) and (total_vit / n_plants) or 0.0

    -- Defeat Condition 1: All plants withered simultaneously
    if s.living_plants == 0 then
        tc_core.trigger_defeat(S("All @1 plant(s) wilted at the same time!", n_plants), "wilt")
        return
    end

    if full_harmony then
        chime_timer = chime_timer + 1
        if chime_timer >= 6 then
            core.sound_play("tc_harmony_chime", {gain = 0.5}, true)
            chime_timer = 0
        end
    end

    -- Asynchronous per-plant botanical growth (locked at 100% once Final Sweep begins)
    if s.cleanup_phase or (s.bloom >= 100.0 and s.living_plants == n_plants) then
        for i = 1, n_plants do
            s.plants[i].bloom = 100.0
        end
    else
        for i = 1, n_plants do
            local p = s.plants[i]
            local cur_b = p.bloom or 0.0
            local tempo = p.growth_tempo or 1.0

            if p.withered then
                if temp_extreme or ph_extreme then
                    p.bloom = tc_core.clamp(cur_b - 0.35, 0.0, 99.0)
                else
                    p.bloom = tc_core.clamp(cur_b, 0.0, 99.0)
                end
            else
                local plant_growth
                if full_harmony then
                    local base_harmony = 0.85 / (1.0 + 0.08 * (s.level - 1))
                    local soil_bonus = math.min(0.55, (p.fertile_near or 0) * 0.11)
                    local cond_mult = 1.0
                    if n_plants > 1 then
                        cond_mult = ((p.hazards_near > 0 or p.local_stress) and 0.75 or 1.0)
                            * (0.94 + 0.06 * (p.vitality / 100.0))
                    end
                    plant_growth = (base_harmony + soil_bonus) * tempo * cond_mult
                elseif temp_extreme or ph_extreme then
                    plant_growth = -0.55 * (2.0 - tempo)
                else
                    local drift_mult = (n_plants > 1 and (p.hazards_near > 0 or p.local_stress)) and 0.75 or 1.0
                    plant_growth = 0.20 * tempo * drift_mult
                end
                p.bloom = tc_core.clamp(cur_b + plant_growth, 0.0, 100.0)
            end
        end
    end

    tc_core.recalc_mean_bloom()

    -- Update each living Sprout's visual stage independently & deduplicate world infotext
    for i = 1, n_plants do
        local p = s.plants[i]
        local new_info
        if not p.withered then
            local prev_stage = p.stage or 1
            local desired_stage, expected_name = tc_elements.get_sprout_stage(p.bloom or 0.0)
            local stage_title = tc_elements.SPROUT_STAGES[desired_stage].title
            p.stage = desired_stage

            if core.get_node(p.pos).name ~= expected_name then
                core.swap_node(p.pos, {name = expected_name})
                if desired_stage > prev_stage then
                    core.sound_play("tc_transmute", {pos = p.pos, gain = 0.8, max_hear_distance = 24}, true)
                    spawn_stage_blossom_particles(p.pos)
                    local pb_str = string.format("%.0f", p.bloom)
                    local blossom_title = (n_plants == 1)
                        and S("✦ Grew into @1!", stage_title)
                        or S("✦ Sprout #@1 → @2!", p.index, stage_title)
                    tc_core.push_hud_event({
                        priority = 1,
                        icon = "tc_crucible_sprout_" .. desired_stage .. ".png",
                        title = blossom_title,
                        detail = S("@1% Bloom reached", pb_str),
                        color = P.hud_gold,
                        accent_hex = P.gold,
                        ttl = 3.2,
                    })
                end
            end
            local stress_tag = p.local_stress and (" · " .. S("[Clear extra hazards in this room!]")) or ""
            new_info = tc_assets.format_infotext(
                S("Sprout #@1 · @2", p.index, stage_title),
                S(
                    "Bloom: @1% · Plant Health: @2% · Nearby Hazards: @3@4",
                    string.format("%.0f", p.bloom or 0.0),
                    string.format("%.0f", p.vitality),
                    p.hazards_near,
                    stress_tag
                ),
                S("Right-Click for Garden Controls · Left-Click with Water Flask [3] to heal")
            )
        else
            new_info = tc_assets.format_infotext(
                S("Sprout #@1 [WILTED · Needs Water!]", p.index),
                S("Growth paused at @1% until revived!", string.format("%.0f", p.bloom or 0.0)),
                S("Left-Click with Water Flask [3], drink Aegis Potion, or keep @1s Balance", revive_req)
            )
        end

        if p.last_infotext ~= new_info then
            p.last_infotext = new_info
            core.get_meta(p.pos):set_string("infotext", new_info)
        end
    end

    -- 85% Final Bloom Surge on Level 3+: one-time telegraphed climax with a bonus Geode + matched opposite pair
    if s.running and not s.victory and not s.cleanup_phase and s.level >= 3 and not s.climax_triggered
            and s.bloom >= 85.0 and s.bloom < 100.0 then
        s.climax_triggered = true
        s.drop_timer = math.max(s.drop_timer, 5.5) + 2.5
        s.reagents_dropped = s.reagents_dropped + 3

        local surge_epoch = s.epoch
        local surge_lvl = s.level
        local geode_cell = cells[(s.wave % #cells) + 1]
        local pair = tc_core.OPPOSITE_PAIRS[(s.level % 2) + 1]
        drop_item_in_cell(geode_cell, surge_lvl, "tc_elements:aether_geode")

        for k = 1, 2 do
            local target_cell = cells[((s.wave + k) % #cells) + 1]
            local pair_item = pair[k]
            core.after(k * 0.55, function()
                if tc_core.state.running and not tc_core.state.cleanup_phase
                        and tc_core.state.epoch == surge_epoch then
                    drop_item_in_cell(target_cell, surge_lvl, pair_item)
                end
            end)
        end

        s.active_drop = {
            wave_num = s.wave,
            level = surge_lvl,
            kind = "surge",
            trial_id = 0,
            items = {"tc_elements:aether_geode", pair[1], pair[2]},
            ttl = 3.6,
        }
        core.sound_play("tc_geode_chime", {gain = 0.9}, true)
        core.sound_play("tc_drop_warning", {gain = 0.8}, true)
        tc_core.push_hud_event({
            priority = 3,
            icon = "tc_aether_geode.png",
            title = S("★ 85% Final Bloom Surge!"),
            detail = S("Crack Geode or Pair [1] for 100%!"),
            color = P.hud_gold,
            accent_hex = P.gold,
            ttl = 4.6,
        })
    end

    -- Two-Phase Level Completion Check (100% Bloom -> Final Sweep -> 0 Hazards Victory)
    local ready_for_victory = false
    if not s.victory then
        if not s.cleanup_phase then
            if s.bloom >= 100.0 and s.living_plants == n_plants then
                if s.remaining_hazards == 0 then
                    ready_for_victory = true
                else
                    s.cleanup_phase = true
                    s.active_drop = nil
                    core.sound_play("tc_harmony_chime", {gain = 0.95}, true)
                    tc_core.push_hud_event({
                        priority = 3,
                        icon = "tc_crucible_sprout_4.png",
                        title = S("★ 100% Bloom — Final Sweep!"),
                        detail = S("Skies clear! Clear @1 hazard(s) to win!", s.remaining_hazards),
                        color = P.hud_gold,
                        accent_hex = P.gold,
                        ttl = 4.8,
                    })
                end
            end
        elseif s.remaining_hazards == 0 and s.living_plants == n_plants then
            ready_for_victory = true
        end
    end

    if ready_for_victory then
        s.victory = true
        s.cleanup_phase = false
        s.running = false
        s.active_drop = nil
        s.prev_blessing = s.active_blessing
        s.offered_blessings = {}
        tc_core.record_all_players(true)

        core.sound_play("tc_victory", {gain = 1.0}, true)
        tc_core.push_hud_event({
            priority = 3,
            icon = "tc_crucible_sprout_4.png",
            title = S("★ Level @1 Complete!", s.level),
            detail = S("Pick a Blessing for Room #@1!", s.level + 1),
            color = P.hud_gold,
            accent_hex = P.gold,
            ttl = 5.0,
        })

        local PT = tc_assets.PARTICLES
        for i = 1, n_plants do
            local p = s.plants[i]
            tc_assets.spawn_sheet_particles({
                amount = 48,
                time = 3.0,
                minpos = {x = p.pos.x - 1.0, y = p.pos.y + 0.5, z = p.pos.z - 1.0},
                maxpos = {x = p.pos.x + 1.0, y = p.pos.y + 1.5, z = p.pos.z + 1.0},
                minvel = {x = -3.0, y = 5.0, z = -3.0},
                maxvel = {x = 3.0, y = 11.0, z = 3.0},
                minacc = {x = 0, y = -2.2, z = 0},
                maxacc = {x = 0, y = -0.6, z = 0},
                minexptime = 1.2,
                maxexptime = 2.4,
                minsize = 2.0,
                maxsize = 4.2,
                glow = 14,
                texpool = {
                    tc_assets.make_sheet_tex_entry(PT.bloom, {scale_tween = {1.5, 0.6}}),
                    tc_assets.make_sheet_tex_entry(PT.pollen, {scale_tween = {1.4, 0.5}}),
                },
            })
        end

        for i = 1, #players do
            local pl = players[i]
            tc_core.set_player_sprinting(pl, false)
            tc_core.clear_player_effects(pl, false)
            x_player_api.play_emote(pl, "cheer", 5.0)
            tc_core.show_victory_dialog(pl)
        end
    end

    -- Reagent Drop Timer countdown (paused during Chronos Sandglass stasis or Final Sweep)
    if s.running and not s.cleanup_phase and s.stasis_timer <= 0 then
        s.drop_timer = s.drop_timer - 1.0
        if s.drop_timer <= 0 then
            s.drop_timer = tc_core.get_next_wave_interval(s.level, #players)
            trigger_reagent_drop()
        end
    end

    -- Update all connected players' atmospheres and HUDs (packet-deduplicated)
    for i = 1, #players do
        tc_core.sync_player_atmosphere(players[i])
        tc_core.update_player_hud(players[i])
    end
end

-- ========================================================
-- x_player_api LOCOMOTION SPRINT & ZERO-POLLING CHAMBER PING
-- ========================================================

x_player_api.register_on_state_change(function(player, state)
    tc_core.set_player_sprinting(player, state.sprinting == true)
end)

x_player_api.register_on_press(function(player, key)
    if key == "zoom" then
        if tc_tools.check_cooldown(player, "ping", 3.0) then
            tc_core.ping_chamber(player)
        end
    elseif key == "aux1" then
        local ctrl = player:get_player_control()
        if not (ctrl and ctrl.up) and tc_tools.check_cooldown(player, "ping", 3.0) then
            tc_core.ping_chamber(player)
        end
    end
end)

-- ========================================================
-- THROTTLED GLOBALSTEP WITH IDLE SERVER SKIPPING
-- ========================================================

local effect_timer = 0.0
local sim_timer = 0.0

core.register_globalstep(function(dtime)
    local players = core.get_connected_players()
    if #players == 0 then
        return
    end

    effect_timer = effect_timer + dtime
    if effect_timer >= 0.25 then
        tc_core.step_player_effects(effect_timer)
        effect_timer = 0.0
    end

    sim_timer = sim_timer + dtime
    if sim_timer >= 1.0 then
        sim_timer = sim_timer - 1.0
        if sim_timer > 1.0 then
            sim_timer = 0.0
        end
        simulation_step()
    end
end)

-- ========================================================
-- CHAT COMMANDS (DRY Handlers)
-- ========================================================

local function cmd_open_leaderboard(name)
    local player = core.get_player_by_name(name)
    if player then
        tc_core.show_leaderboard_dialog(player)
        return true, S("Opened Top 10 Scores.")
    end
    return false, S("Player must be connected.")
end

local function cmd_open_guide(name)
    local player = core.get_player_by_name(name)
    if player then
        tc_core.show_guide_dialog(player, 1)
        return true, S("Opened Gardener's Guidebook.")
    end
    return false, S("Player must be connected.")
end

local function cmd_open_garden(name)
    local player = core.get_player_by_name(name)
    if player then
        tc_core.show_garden_dialog(player)
        return true, S("Opened Garden Controls.")
    end
    return false, S("Player must be connected.")
end

local function cmd_ping_chamber(name)
    local player = core.get_player_by_name(name)
    if player then
        if tc_tools.check_cooldown(player, "ping", 3.0) then
            tc_core.ping_chamber(player)
            return true, S("Marked the room for everyone.")
        end
        return false, S("Please wait a moment before pinging again.")
    end
    return false, S("Player must be connected.")
end

core.register_chatcommand("leaderboard", {
    description = S("Open the Top 10 Terrarium Crucible scores"),
    func = cmd_open_leaderboard,
})

core.register_chatcommand("tc_top10", {
    description = S("Open the Top 10 Terrarium Crucible scores"),
    func = cmd_open_leaderboard,
})

core.register_chatcommand("guide", {
    description = S("Open the illustrated Gardener's Guidebook"),
    func = cmd_open_guide,
})

core.register_chatcommand("crucible", {
    description = S("Open Garden Controls and Game Pace settings"),
    func = cmd_open_garden,
})

core.register_chatcommand("ping", {
    description = S("Place a 4-second marker above the room you are facing"),
    func = cmd_ping_chamber,
})
