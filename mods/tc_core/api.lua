---@class PlantState
---@field index integer 1-based chamber/plant index
---@field pos {x: integer, y: integer, z: integer} World position of the sprout
---@field bloom number Individual botanical bloom percentage (0.0 to 100.0)
---@field stage integer Current visual growth stage (1..4)
---@field growth_tempo number Organic per-plant growth rate multiplier (mean 1.0 across chambers)
---@field fertile_near integer Count of fertile_loam nodes inside this plant's chamber
---@field vitality number Health percentage (0.0 to 100.0)
---@field withered boolean Whether the plant is currently withered (0% vitality)
---@field hazards_near integer Count of hazardous reagents within 2 nodes
---@field local_stress? boolean Whether local chamber thermal/purity imbalance >= 2 holds
---@field last_infotext? string Cached world hover string to avoid redundant metadata sync

---@class LeaderboardEntry
---@field name string Player name
---@field highest_level integer Highest level reached
---@field levels_cleared integer Highest level fully completed (100% bloom)
---@field max_bloom number Best bloom percentage on highest_level
---@field neutralized integer Total hazards neutralized in best run
---@field best_time integer Run time in seconds

---@class TcBoonDef
---@field id string Unique Guild Attunement identifier
---@field title string Display title
---@field icon string Itemstring rendered on the Boon badge
---@field accent string AA-accessible hex accent color
---@field summary string Concise gameplay effect description

---@class TcCoreAPI
---@field INTERVALS table<string, number>
---@field EFFECT_DEFS table<string, table>
---@field EFFECT_ORDER string[]
---@field BOON_ORDER string[]
---@field BOON_DEFS table<string, TcBoonDef>
---@field player_stats table<string, {neutralized: integer, downed_until: integer}>
---@field state table
---@field clamp fun(val: number, min_v: number, max_v: number): number
---@field get_wave_drop_count fun(level: integer, player_count?: integer): integer
---@field is_in_harmony fun(): boolean
---@field has_boon fun(boon_id: string): boolean
---@field grant_boon fun(boon_id: string)
---@field roll_offered_boons fun(): string[]
---@field sync_external_bloom fun()
---@field recalc_mean_bloom fun(): number
---@field add_bloom fun(amount: number, focus_pos?: table): number
---@field add_scaled_bloom fun(base_amount: number, focus_pos?: table): number
---@field credit_reagent_placer fun(pos_a: table, pos_b?: table, count?: integer)
---@field exec_melt_cancel fun(pos_ice: table, pos_brim: table)
---@field exec_acid_base fun(pos_acid: table, pos_chalk: table)
---@field exec_water_quench fun(pos_brim: table, pos_water: table)
---@field exec_water_dissolve_chalk fun(pos_chalk: table, pos_water: table): boolean
---@field try_react_at fun(pos: {x: integer, y: integer, z: integer}): boolean
---@field apply_effect fun(player: ObjectRef, effect_id: string, duration: number)
---@field remove_effect fun(player: ObjectRef, effect_id: string)
---@field has_effect fun(player: ObjectRef, effect_id: string): boolean
---@field clear_player_effects fun(player: ObjectRef, instant_fov?: boolean)
---@field init_player_fov fun(player: ObjectRef)
---@field set_player_sprinting fun(player: ObjectRef, sprinting: boolean)
---@field sync_player_atmosphere fun(player: ObjectRef)
---@field step_player_effects fun(dt: number)
---@field get_active_effects_text fun(player: ObjectRef): string
---@field record_neutralization fun(player: ObjectRef, count?: integer)
---@field record_neutralization_by_name fun(player_name: string, count?: integer)
---@field revive_sprout_at fun(pos: table, user?: ObjectRef, amount?: number): boolean
---@field activate_aegis_ward fun(user: ObjectRef, duration: number)
---@field activate_chronos_stasis fun(user: ObjectRef, duration: number)
---@field record_player_score fun(name: string, lvl: integer, clr: integer, bloom: number, neut: integer, sec: integer)
---@field record_all_players fun(level_cleared: boolean)
---@field get_top10 fun(): LeaderboardEntry[]
---@field build_top10_table_formspec fun(x: number, y: number, w: number, h: number): string
---@field start_level fun(level: integer, preserve_fertile?: boolean)
---@field reset_crucible fun()
---@field trigger_defeat fun(reason: string)
---@field on_player_died fun(player: ObjectRef)
---@field on_player_respawned fun(player: ObjectRef)
---@field init_player_hud fun(player: ObjectRef)
---@field update_player_hud fun(player: ObjectRef)
---@field clear_all_waypoints fun()
---@field ping_chamber fun(player: ObjectRef)
---@field show_guide_dialog fun(player: ObjectRef, tab_idx?: integer)
---@field show_altar_dialog fun(player: ObjectRef)
---@field show_leaderboard_dialog fun(player: ObjectRef)
---@field show_victory_dialog fun(player: ObjectRef)
---@field show_defeat_dialog fun(player: ObjectRef)
tc_core = {}

local P = tc_assets.PALETTE
local storage = core.get_mod_storage()

-- Read user-configured settings from settingtypes.txt and engine configuration
local cfg_normal = tonumber(core.settings:get("tc_drop_interval")) or 12.0
cfg_normal = math.max(5.0, math.min(60.0, cfg_normal))

local cfg_diff = core.settings:get("tc_difficulty") or "normal"
if cfg_diff ~= "casual" and cfg_diff ~= "normal" and cfg_diff ~= "panic" then
    cfg_diff = "normal"
end

-- Drop interval configuration per difficulty
tc_core.INTERVALS = {
    casual = math.min(60.0, math.floor(cfg_normal * 1.4 + 0.5)),
    normal = cfg_normal,
    panic  = math.max(5.0, math.floor(cfg_normal * 0.65 + 0.5)),
}

-- Ordered array of effect identifiers for LuaJIT trace-friendly iteration (no pairs())
tc_core.EFFECT_ORDER = {
    "fertile_stride",
    "steam_updraft",
    "harmonic_overdrive",
    "quicksilver",
    "aegis_ward",
    "chronos_surge",
    "reconstitution",
}

-- Effect definitions backed by player_monoids
tc_core.EFFECT_DEFS = {
    fertile_stride = {
        title = "Green Soil Speed",
        speed = 1.45,
    },
    steam_updraft = {
        title = "Steam High Jump",
        jump = 1.50,
        gravity = 0.50,
    },
    harmonic_overdrive = {
        title = "Harmony Boost",
        speed = 1.30,
    },
    quicksilver = {
        title = "Quicksilver Speed",
        speed = 1.75,
        jump = 1.35,
    },
    aegis_ward = {
        title = "Aegis Shield",
        speed = 1.20,
    },
    chronos_surge = {
        title = "Time Freeze Speed",
        speed = 1.40,
    },
    reconstitution = {
        title = "Recovering",
        speed = 0.65,
    },
}

-- Ordered Guild Attunements (permanent run upgrades chosen between levels)
tc_core.BOON_ORDER = {
    "deep_retort",
    "dragonlung_bellows",
    "starlight_mortar",
    "leyline_roots",
    "hermetic_boots",
}

tc_core.BOON_DEFS = {
    deep_retort = {
        id = "deep_retort",
        title = "Deep Retort",
        icon = "tc_tools:condenser_flask_full",
        accent = P.aqua,
        summary = "Water Flask [3] holds 5 splashes per refill instead of 3.",
    },
    dragonlung_bellows = {
        id = "dragonlung_bellows",
        title = "Dragonlung Bellows",
        icon = "tc_tools:bellows",
        accent = P.amber,
        summary = "Thermal Bellows [2] melts a wide patch of Ice all at once!",
    },
    starlight_mortar = {
        id = "starlight_mortar",
        title = "Starlight Mortar",
        icon = "tc_tools:chalk_pestle",
        accent = P.violet,
        summary = "Limestone Pestle [4] clears a wider patch of Acid & gives extra growth.",
    },
    leyline_roots = {
        id = "leyline_roots",
        title = "Ley-Line Roots",
        icon = "tc_elements:crucible_sprout_3",
        accent = P.emerald,
        summary = "Plants heal faster when balanced & wilted plants revive in 4s (was 6s).",
    },
    hermetic_boots = {
        id = "hermetic_boots",
        title = "Hermetic Boots",
        icon = "tc_elements:fertile_loam",
        accent = P.gold,
        summary = "Run even faster on green Fertile Soil & take half damage from hazards.",
    },
}

-- Active timed effects per player: player_effects[player_name][effect_id] = remaining_seconds
local player_effects = {}
local player_sprint_active = {}
local player_fov_cache = {}
local player_join_us = {}
local player_fov_change_us = {}
local player_light_cache = {}
local boon_rng = PcgRandom(os.time() + 1337)

-- Camera FOV timing guards: avoid transition interpolation during initial client camera warmup
-- or across same-frame back-to-back packets where Luanti's m_curr_fov_degrees has not yet stepped.
local FOV_LOGIN_WARMUP_US = 2500000
local FOV_COALESCE_US = 60000
local FOV_TRANSITION_SEC = 0.20

-- Pre-allocated coordinate vectors for zero-allocation terrain sampling in step_player_effects
local sample_foot_pos = {x = 0, y = 0, z = 0}
local sample_body_pos = {x = 0, y = 0, z = 0}

-- 6-direction neighbor offsets for 0ms immediate reactions
local REACT_DIRS = {
    {x = 1, y = 0, z = 0},
    {x = -1, y = 0, z = 0},
    {x = 0, y = 0, z = 1},
    {x = 0, y = 0, z = -1},
    {x = 0, y = 1, z = 0},
    {x = 0, y = -1, z = 0},
}

-- Per-player run stats: player_stats[player_name] = {neutralized = 0, downed_until = 0}
tc_core.player_stats = {}

-- Game state data structure
tc_core.state = {
    running = true,
    epoch = 1,
    level = 1,
    temperature = 50.0,
    ph = 50.0,
    bloom = 0.0,
    _synced_bloom = 0.0,
    plants = {},
    living_plants = 1,
    avg_vitality = 100.0,
    active_reagents = 0,
    max_reagents = 11,
    overload_timer = 0,
    turbulent = false,
    wave = 0,
    drop_timer = 4.0,
    difficulty = cfg_diff,
    harmony_streak = 0,
    aegis_timer = 0.0,
    stasis_timer = 0.0,
    boons = {},
    offered_boons = {},
    victory = false,
    defeat = false,
    defeat_reason = "",
    seconds_elapsed = 0,
    run_seconds = 0,
    peak_harmony = 0,
    reagents_dropped = 0,
}

-- Clean up transient player effect state on disconnect
core.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    player_effects[name] = nil
    player_sprint_active[name] = nil
    player_fov_cache[name] = nil
    player_join_us[name] = nil
    player_fov_change_us[name] = nil
    player_light_cache[name] = nil
    if tc_core.player_stats[name] then
        tc_core.player_stats[name].downed_until = 0
    end
end)

---Clamps a numeric value between min_v and max_v.
---@param val number
---@param min_v number
---@param max_v number
---@return number
function tc_core.clamp(val, min_v, max_v)
    return math.max(min_v, math.min(max_v, val))
end

---Computes the sublinear falling-reagent drop count per wave for the given level and connected player count.
---@param level integer
---@param player_count? integer
---@return integer
function tc_core.get_wave_drop_count(level, player_count)
    local lvl = math.max(1, math.floor(level or 1))
    local p_cnt = math.max(1, math.floor(player_count or 1))
    return math.ceil(lvl * 0.65) + math.ceil(math.max(0, p_cnt - 1) * 0.60)
end

---Returns true when Thermal (40-60C), Purity (40-60 internal / 5.6-8.4 pH), and Calm (not turbulent) hold.
---@return boolean
function tc_core.is_in_harmony()
    local s = tc_core.state
    return (s.temperature >= 40.0 and s.temperature <= 60.0)
        and (s.ph >= 40.0 and s.ph <= 60.0)
        and not s.turbulent
end

-- ========================================================
-- GUILD ATTUNEMENT BOONS & INSTANT REACTIONS
-- ========================================================

---Returns true if the Alchemical Guild currently holds the specified permanent run Boon.
---@param boon_id string
---@return boolean
function tc_core.has_boon(boon_id)
    return tc_core.state.boons[boon_id] == true
end

---Grants a permanent Guild Attunement Boon for the active run and applies immediate equipment upgrades.
---@param boon_id string
function tc_core.grant_boon(boon_id)
    if not tc_core.BOON_DEFS[boon_id] then
        return
    end
    tc_core.state.boons[boon_id] = true

    local players = core.get_connected_players()
    if boon_id == "deep_retort" then
        for i = 1, #players do
            local inv = players[i]:get_inventory()
            local list = inv:get_list("main")
            if list then
                for slot = 1, #list do
                    if list[slot]:get_name() == "tc_tools:condenser_flask_full" then
                        list[slot] = tc_tools.fill_flask()
                    end
                end
                inv:set_list("main", list)
            end
        end
    elseif boon_id == "hermetic_boots" then
        for i = 1, #players do
            local p = players[i]
            if tc_core.has_effect(p, "fertile_stride") then
                player_monoids.speed:add_change(p, 1.65, "tc_core:fertile_stride")
            end
        end
    end
end

---Rolls up to 3 Guild Attunement choices for the Level Complete screen (preferring unowned Boons).
---@return string[]
function tc_core.roll_offered_boons()
    local s = tc_core.state
    if #s.offered_boons >= 3 then
        return s.offered_boons
    end

    local pool = {}
    local fallback = {}
    for i = 1, #tc_core.BOON_ORDER do
        local bid = tc_core.BOON_ORDER[i]
        if not s.boons[bid] then
            pool[#pool + 1] = bid
        else
            fallback[#fallback + 1] = bid
        end
    end

    for i = #pool, 2, -1 do
        local j = boon_rng:next(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local picked = {}
    for i = 1, math.min(3, #pool) do
        picked[#picked + 1] = pool[i]
    end
    for i = 1, #fallback do
        if #picked >= 3 then
            break
        end
        picked[#picked + 1] = fallback[i]
    end

    s.offered_boons = picked
    return picked
end

---Propagates direct external assignments to `tc_core.state.bloom` onto individual plant bloom values.
function tc_core.sync_external_bloom()
    local s = tc_core.state
    local n = #s.plants
    if n == 0 then
        s._synced_bloom = s.bloom
        return
    end
    if math.abs(s.bloom - (s._synced_bloom or 0.0)) > 0.001 then
        local target = tc_core.clamp(s.bloom, 0.0, 100.0)
        for i = 1, n do
            local p = s.plants[i]
            p.bloom = tc_core.clamp(target, 0.0, p.withered and 99.0 or 100.0)
        end
        tc_core.recalc_mean_bloom()
    end
end

---Recalculates overall `tc_core.state.bloom` as the mean of individual plant bloom percentages,
---clamped below 100% while any plant is withered.
---@return number bloom
function tc_core.recalc_mean_bloom()
    local s = tc_core.state
    local n = #s.plants
    if n == 0 then
        s._synced_bloom = s.bloom
        return s.bloom
    end
    local sum_b = 0.0
    local living_cnt = 0
    for i = 1, n do
        local p = s.plants[i]
        local max_p = p.withered and 99.0 or 100.0
        p.bloom = tc_core.clamp(p.bloom or 0.0, 0.0, max_p)
        sum_b = sum_b + p.bloom
        if not p.withered then
            living_cnt = living_cnt + 1
        end
    end
    local max_b = (living_cnt == n) and 100.0 or 99.0
    s.bloom = tc_core.clamp(sum_b / n, 0.0, max_b)
    s._synced_bloom = s.bloom
    return s.bloom
end

---Adds bonus Bloom percentage distributed across living plants (weighted by individual growth_tempo
---and optional local chamber focus_pos, with overflow redistributed so zero earned Bloom is wasted).
---@param amount number Mean Bloom percentage to add across the crucible
---@param focus_pos? table Optional world position of the reaction to favor the nearest chamber's sprout
---@return number added Actual mean Bloom percentage added
function tc_core.add_bloom(amount, focus_pos)
    local s = tc_core.state
    if not s.running or amount <= 0 then
        return 0.0
    end
    local n = #s.plants
    if n == 0 then
        local prev = s.bloom
        s.bloom = tc_core.clamp(prev + amount, 0.0, 100.0)
        s._synced_bloom = s.bloom
        return s.bloom - prev
    end

    tc_core.sync_external_bloom()
    local prev = s.bloom
    local pool = amount * n

    local focus_idx = 0
    if focus_pos and n > 1 then
        local best_d2 = math.huge
        for i = 1, n do
            local c = s.plants[i].pos
            local dx = focus_pos.x - c.x
            local dz = focus_pos.z - c.z
            local d2 = (dx * dx) + (dz * dz)
            if d2 < best_d2 then
                best_d2 = d2
                focus_idx = i
            end
        end
    end

    for _ = 1, n do
        if pool <= 0.0001 then
            break
        end
        local w_sum = 0.0
        for i = 1, n do
            local p = s.plants[i]
            if not p.withered and (p.bloom or 0.0) < 100.0 then
                local w = (p.growth_tempo or 1.0) * (i == focus_idx and 1.35 or 1.0)
                w_sum = w_sum + w
            end
        end
        if w_sum <= 0.0 then
            break
        end

        local used = 0.0
        for i = 1, n do
            local p = s.plants[i]
            local cur = p.bloom or 0.0
            if not p.withered and cur < 100.0 then
                local w = (p.growth_tempo or 1.0) * (i == focus_idx and 1.35 or 1.0)
                local share = pool * (w / w_sum)
                local next_b = math.min(100.0, cur + share)
                used = used + (next_b - cur)
                p.bloom = next_b
            end
        end
        if used <= 0.0001 then
            break
        end
        pool = pool - used
    end

    tc_core.recalc_mean_bloom()
    return s.bloom - prev
end

---Adds bonus Bloom normalized by `1 / sqrt(level)` so multi-chamber drop rates stay evenly paced.
---@param base_amount number Base Bloom bonus on Level 1
---@param focus_pos? table Optional world position of the reaction to favor the nearest chamber's sprout
---@return number added Actual Bloom percentage added
function tc_core.add_scaled_bloom(base_amount, focus_pos)
    local lvl = math.max(1, tc_core.state.level or 1)
    local scaled = base_amount / math.sqrt(lvl)
    return tc_core.add_bloom(scaled, focus_pos)
end

---Credits neutralization to the player who placed either reacting block via Alchemist's Trowel.
---@param pos_a table
---@param pos_b? table
---@param count? integer
function tc_core.credit_reagent_placer(pos_a, pos_b, count)
    local placer = core.get_meta(pos_a):get_string("placer")
    if (not placer or placer == "") and pos_b then
        placer = core.get_meta(pos_b):get_string("placer")
    end
    if placer and placer ~= "" then
        tc_core.record_neutralization_by_name(placer, count or 1)
    end
end

local function spawn_reaction_particles(pos, mode)
    local PT = tc_assets.PARTICLES
    if mode == "thermal_cancel" then
        tc_assets.spawn_sheet_particles({
            amount = 24,
            time = 0.25,
            minpos = {x = pos.x - 0.5, y = pos.y - 0.2, z = pos.z - 0.5},
            maxpos = {x = pos.x + 0.5, y = pos.y + 0.8, z = pos.z + 0.5},
            minvel = {x = -1.4, y = 1.0, z = -1.4},
            maxvel = {x = 1.4, y = 3.2, z = 1.4},
            drag = {x = 0.6, y = 0.3, z = 0.6},
            minexptime = 0.55,
            maxexptime = 1.15,
            minsize = 1.6,
            maxsize = 3.4,
            glow = 13,
            texpool = {
                tc_assets.make_sheet_tex_entry(PT.steam, {
                    blend = "alpha",
                    scale_tween = {0.9, 2.2},
                    alpha_tween = {0.9, 0.0},
                }),
                tc_assets.make_sheet_tex_entry(PT.droplet, {blend = "alpha", scale_tween = {1.2, 1.5}}),
                tc_assets.make_sheet_tex_entry(PT.ember, {scale_tween = {1.3, 0.4}}),
            },
        })
    elseif mode == "acid_base" then
        tc_assets.spawn_sheet_particles({
            amount = 26,
            time = 0.25,
            minpos = {x = pos.x - 0.6, y = pos.y - 0.2, z = pos.z - 0.6},
            maxpos = {x = pos.x + 0.6, y = pos.y + 0.8, z = pos.z + 0.6},
            minvel = {x = -1.6, y = 1.0, z = -1.6},
            maxvel = {x = 1.6, y = 3.4, z = 1.6},
            drag = {x = 0.6, y = 0.4, z = 0.6},
            minexptime = 0.60,
            maxexptime = 1.25,
            minsize = 1.6,
            maxsize = 3.4,
            glow = 14,
            texpool = {
                tc_assets.make_sheet_tex_entry(PT.bloom, {scale_tween = {1.3, 0.55}}),
                tc_assets.make_sheet_tex_entry(PT.pollen, {scale_tween = {1.4, 0.4}}),
            },
        })
    elseif mode == "quench" then
        tc_assets.spawn_sheet_particles({
            amount = 18,
            time = 0.20,
            minpos = {x = pos.x - 0.4, y = pos.y - 0.1, z = pos.z - 0.4},
            maxpos = {x = pos.x + 0.4, y = pos.y + 0.6, z = pos.z + 0.4},
            minvel = {x = -0.9, y = 1.0, z = -0.9},
            maxvel = {x = 0.9, y = 2.8, z = 0.9},
            minexptime = 0.50,
            maxexptime = 1.05,
            minsize = 1.5,
            maxsize = 3.2,
            glow = 12,
            texpool = {
                tc_assets.make_sheet_tex_entry(PT.steam, {
                    blend = "alpha",
                    scale_tween = {0.85, 2.1},
                    alpha_tween = {0.9, 0.0},
                }),
                tc_assets.make_sheet_tex_entry(PT.ember, {scale_tween = {1.2, 0.35}}),
            },
        })
    elseif mode == "dissolve" then
        tc_assets.spawn_sheet_particles({
            amount = 16,
            time = 0.20,
            minpos = {x = pos.x - 0.4, y = pos.y - 0.2, z = pos.z - 0.4},
            maxpos = {x = pos.x + 0.4, y = pos.y + 0.5, z = pos.z + 0.4},
            minvel = {x = -1.2, y = 0.8, z = -1.2},
            maxvel = {x = 1.2, y = 2.4, z = 1.2},
            minexptime = 0.45,
            maxexptime = 0.95,
            minsize = 1.4,
            maxsize = 2.8,
            glow = 12,
            texpool = {
                tc_assets.make_sheet_tex_entry(PT.droplet, {blend = "alpha", scale_tween = {1.15, 1.55}}),
                tc_assets.make_sheet_tex_entry(PT.pollen, {scale_tween = {1.25, 0.4}}),
            },
        })
    end
end

---Executes a Brimstone + Cryo-Ice Thermal Cancellation (+3.0% scaled Bloom, Water + Steam).
---@param pos_ice table
---@param pos_brim table
function tc_core.exec_melt_cancel(pos_ice, pos_brim)
    tc_core.credit_reagent_placer(pos_brim, pos_ice, 2)
    core.set_node(pos_ice, {name = "tc_elements:water_source"})
    core.set_node(pos_brim, {name = "tc_elements:steam"})
    local above = {x = pos_ice.x, y = pos_ice.y + 1, z = pos_ice.z}
    if core.get_node(above).name == "air" then
        core.set_node(above, {name = "tc_elements:steam"})
    end
    core.sound_play("tc_steam", {pos = pos_ice, gain = 0.65, max_hear_distance = 22}, true)
    spawn_reaction_particles(pos_ice, "thermal_cancel")
    local gain = tc_core.add_scaled_bloom(3.0, pos_ice)
    core.chat_send_all(
        tc_assets.chat_prefix("Nice Combo!", P.aqua) ..
        core.colorize(
            P.text_primary,
            string.format("Hot Brimstone & Cold Ice canceled each other out (+%.1f%% Bloom)!", gain)
        )
    )
end

---Executes an Acid Slime + Alkaline Chalk Transmutation (+3.5% scaled Bloom, Fertile Speed Soil).
---@param pos_acid table
---@param pos_chalk table
function tc_core.exec_acid_base(pos_acid, pos_chalk)
    tc_core.credit_reagent_placer(pos_acid, pos_chalk, 2)
    core.set_node(pos_acid, {name = "tc_elements:steam"})
    core.remove_node(pos_chalk)
    tc_elements.enrich_soil_at(pos_acid)
    tc_elements.enrich_soil_at(pos_chalk)
    core.sound_play("tc_transmute", {pos = pos_acid, gain = 0.8, max_hear_distance = 22}, true)
    spawn_reaction_particles(pos_acid, "acid_base")
    local gain = tc_core.add_scaled_bloom(3.5, pos_acid)
    core.chat_send_all(
        tc_assets.chat_prefix("Nice Combo!", P.emerald) ..
        core.colorize(
            P.text_primary,
            string.format("Acid & Chalk combined into glowing green Speed Soil (+%.1f%% Bloom)!", gain)
        )
    )
end

---Quenches Scorching Brimstone with adjacent Alchemical Water (+1.2% scaled Bloom, Steam).
---@param pos_brim table
---@param pos_water table
function tc_core.exec_water_quench(pos_brim, pos_water)
    tc_core.credit_reagent_placer(pos_brim, pos_water, 1)
    core.remove_node(pos_water)
    core.set_node(pos_brim, {name = "tc_elements:steam"})
    core.sound_play("tc_sizzle", {pos = pos_brim, gain = 0.6, max_hear_distance = 20}, true)
    spawn_reaction_particles(pos_brim, "quench")
    tc_core.add_scaled_bloom(1.2, pos_brim)
end

---Dissolves Alkaline Chalk with adjacent Alchemical Water (+1.2% scaled Bloom, Fertile Speed Soil).
---@param pos_chalk table
---@param pos_water table
---@return boolean enriched True if underlying loam became fertile_loam
function tc_core.exec_water_dissolve_chalk(pos_chalk, pos_water)
    tc_core.credit_reagent_placer(pos_chalk, pos_water, 1)
    core.remove_node(pos_water)
    core.remove_node(pos_chalk)
    local enriched = tc_elements.enrich_soil_at(pos_chalk)
    core.sound_play("tc_steam", {pos = pos_chalk, gain = 0.55, max_hear_distance = 18}, true)
    spawn_reaction_particles(pos_chalk, "dissolve")
    tc_core.add_scaled_bloom(1.2, pos_chalk)
    return enriched
end

---Checks for and executes an immediate 0ms chemical or catalyst reaction at `pos`.
---@param pos {x: integer, y: integer, z: integer}
---@return boolean reacted
function tc_core.try_react_at(pos)
    if not tc_core.state.running then
        return false
    end
    local cname = core.get_node(pos).name
    if cname == "air" then
        return false
    end

    local is_reagent = tc_elements.REAGENT_BY_NAME[cname] ~= nil
    for i = 1, #REACT_DIRS do
        local d = REACT_DIRS[i]
        local npos = {x = pos.x + d.x, y = pos.y + d.y, z = pos.z + d.z}
        local nname = core.get_node(npos).name

        if cname == "tc_elements:aether_geode" and tc_elements.REAGENT_BY_NAME[nname] then
            local p_str = core.get_meta(npos):get_string("placer")
            local p_obj = (p_str ~= "") and core.get_player_by_name(p_str) or nil
            tc_elements.resonate_geode_at(pos, p_obj)
            return true
        elseif is_reagent and nname == "tc_elements:aether_geode" then
            local p_str = core.get_meta(pos):get_string("placer")
            local p_obj = (p_str ~= "") and core.get_player_by_name(p_str) or nil
            tc_elements.resonate_geode_at(npos, p_obj)
            return true
        elseif cname == "tc_elements:brimstone" then
            if nname == "tc_elements:cryo_ice" then
                tc_core.exec_melt_cancel(npos, pos)
                return true
            elseif nname == "tc_elements:water_source" or nname == "tc_elements:water_flowing" then
                tc_core.exec_water_quench(pos, npos)
                return true
            end
        elseif cname == "tc_elements:cryo_ice" and nname == "tc_elements:brimstone" then
            tc_core.exec_melt_cancel(pos, npos)
            return true
        elseif cname == "tc_elements:acid_slime" and nname == "tc_elements:alkaline_chalk" then
            tc_core.exec_acid_base(pos, npos)
            return true
        elseif cname == "tc_elements:alkaline_chalk" then
            if nname == "tc_elements:acid_slime" then
                tc_core.exec_acid_base(npos, pos)
                return true
            elseif nname == "tc_elements:water_source" or nname == "tc_elements:water_flowing" then
                tc_core.exec_water_dissolve_chalk(pos, npos)
                return true
            end
        elseif cname == "tc_elements:water_source" or cname == "tc_elements:water_flowing" then
            if nname == "tc_elements:brimstone" then
                tc_core.exec_water_quench(npos, pos)
                return true
            elseif nname == "tc_elements:alkaline_chalk" then
                tc_core.exec_water_dissolve_chalk(npos, pos)
                return true
            end
        end
    end
    return false
end

-- ========================================================
-- PLAYER MONOIDS TIMED BOOST ENGINE (Packet-Deduplicated)
-- ========================================================

local function sync_player_fov(player, force_instant)
    local name = player:get_player_name()
    local effs = player_effects[name]
    local reconstituting = effs ~= nil and (effs.reconstitution or 0) > 0
    local desired = 0
    if effs and not reconstituting then
        if (effs.quicksilver or 0) > 0 then
            desired = 1.12
        elseif (effs.fertile_stride or 0) > 0
                or (effs.harmonic_overdrive or 0) > 0
                or (effs.chronos_surge or 0) > 0 then
            desired = 1.08
        end
    end
    if desired == 0 and not reconstituting and player_sprint_active[name] == true then
        desired = 1.05
    end

    local prev = player_fov_cache[name] or 0
    local cur_fov, cur_is_mult = player:get_fov()
    cur_fov = cur_fov or 0

    if desired == 0 then
        if prev == 0 and cur_fov == 0 then
            player_fov_cache[name] = 0
            return
        end
    elseif math.abs(prev - desired) < 0.001
            and cur_is_mult == true
            and math.abs(cur_fov - desired) < 0.001 then
        player_fov_cache[name] = desired
        return
    end

    local now_us = core.get_us_time()
    local join_us = player_join_us[name] or now_us
    local last_us = player_fov_change_us[name] or 0
    local trans = 0
    if not force_instant
            and (now_us - join_us) >= FOV_LOGIN_WARMUP_US
            and (now_us - last_us) >= FOV_COALESCE_US then
        trans = FOV_TRANSITION_SEC
    end

    player_fov_cache[name] = desired
    player_fov_change_us[name] = now_us
    player:set_fov(desired, desired > 0, trans)
end

---Initializes per-player FOV state on login without sending any transition packet unless clearing stale FOV.
---@param player ObjectRef
function tc_core.init_player_fov(player)
    if not player or not player:is_player() then
        return
    end
    local name = player:get_player_name()
    player_join_us[name] = core.get_us_time()
    player_fov_change_us[name] = 0
    player_sprint_active[name] = false
    player_fov_cache[name] = 0

    local cur_fov = player:get_fov()
    if cur_fov and cur_fov ~= 0 then
        player:set_fov(0, false, 0)
    end
end

---Synchronizes x_player_api sprint locomotion with a 1.25x player_monoids speed boost and subtle FOV surge.
---@param player ObjectRef
---@param sprinting boolean
function tc_core.set_player_sprinting(player, sprinting)
    if not player or not player:is_player() then
        return
    end
    local name = player:get_player_name()
    local active = (sprinting == true) and tc_core.state.running == true
    local prev = (player_sprint_active[name] == true)
    if prev == active then
        return
    end
    player_sprint_active[name] = active
    if active then
        player_monoids.speed:add_change(player, 1.25, "tc_core:sprint")
    else
        player_monoids.speed:del_change(player, "tc_core:sprint")
    end
    sync_player_fov(player)
end

---Updates Luanti 5.18 post-processing lighting (Stasis desaturation & Overdrive bloom) only on transition.
---@param player ObjectRef
function tc_core.sync_player_atmosphere(player)
    local name = player:get_player_name()
    local mode = "normal"
    if tc_core.state.stasis_timer > 0 then
        mode = "stasis"
    elseif tc_core.has_effect(player, "harmonic_overdrive") then
        mode = "overdrive"
    end

    if player_light_cache[name] == mode then
        return
    end
    player_light_cache[name] = mode

    if mode == "stasis" then
        player:set_lighting({
            bloom = {intensity = 0.09, strength_factor = 1.0, radius = 1.0},
            volumetric_light = {strength = 0.18},
            saturation = 0.65,
        })
    elseif mode == "overdrive" then
        player:set_lighting({
            bloom = {intensity = 0.12, strength_factor = 1.1, radius = 1.1},
            volumetric_light = {strength = 0.22},
            saturation = 1.15,
        })
    else
        player:set_lighting({
            bloom = {intensity = 0.06, strength_factor = 1.0, radius = 1.0},
            volumetric_light = {strength = 0.15},
            saturation = 1.05,
        })
    end
end

---Applies or refreshes a timed boost effect on a player using player_monoids.
---Only invokes monoid add_change on activation transition to prevent redundant physics packets.
---@param player ObjectRef
---@param effect_id string
---@param duration number Duration in seconds
function tc_core.apply_effect(player, effect_id, duration)
    if not player or not player:is_player() then
        return
    end
    local def = tc_core.EFFECT_DEFS[effect_id]
    if not def then
        return
    end

    local name = player:get_player_name()
    local effs = player_effects[name]
    if not effs then
        effs = {}
        player_effects[name] = effs
    end

    local existing = effs[effect_id] or 0
    effs[effect_id] = math.max(existing, duration)

    if existing <= 0 then
        local monoid_key = "tc_core:" .. effect_id
        local spd = def.speed
        if effect_id == "fertile_stride" and tc_core.has_boon("hermetic_boots") then
            spd = 1.65
        end
        if spd then
            player_monoids.speed:add_change(player, spd, monoid_key)
        end
        if def.jump then
            player_monoids.jump:add_change(player, def.jump, monoid_key)
        end
        if def.gravity then
            player_monoids.gravity:add_change(player, def.gravity, monoid_key)
        end
        sync_player_fov(player)
    end
end

---Removes a timed boost effect from a player and restores their monoid branch.
---@param player ObjectRef
---@param effect_id string
function tc_core.remove_effect(player, effect_id)
    if not player or not player:is_player() then
        return
    end
    local def = tc_core.EFFECT_DEFS[effect_id]
    if not def then
        return
    end

    local name = player:get_player_name()
    local effs = player_effects[name]
    local was_active = effs and (effs[effect_id] or 0) > 0
    if effs then
        effs[effect_id] = nil
    end

    if was_active then
        local monoid_key = "tc_core:" .. effect_id
        if def.speed then
            player_monoids.speed:del_change(player, monoid_key)
        end
        if def.jump then
            player_monoids.jump:del_change(player, monoid_key)
        end
        if def.gravity then
            player_monoids.gravity:del_change(player, monoid_key)
        end
        sync_player_fov(player)
    end
end

---Checks whether a player currently has an active boost effect.
---@param player ObjectRef
---@param effect_id string
---@return boolean
function tc_core.has_effect(player, effect_id)
    if not player or not player:is_player() then
        return false
    end
    local effs = player_effects[player:get_player_name()]
    return (effs ~= nil and (effs[effect_id] or 0) > 0)
end

---Clears all active boost effects from a player and synchronizes FOV in a single coalesced update.
---@param player ObjectRef
---@param instant_fov? boolean When true, resets any active FOV override instantaneously (transition_time = 0)
function tc_core.clear_player_effects(player, instant_fov)
    if not player or not player:is_player() then
        return
    end
    local effs = player_effects[player:get_player_name()]
    if not effs then
        sync_player_fov(player, instant_fov == true)
        return
    end
    local had_any = false
    for i = 1, #tc_core.EFFECT_ORDER do
        local eff_id = tc_core.EFFECT_ORDER[i]
        if (effs[eff_id] or 0) > 0 then
            effs[eff_id] = nil
            local def = tc_core.EFFECT_DEFS[eff_id]
            local monoid_key = "tc_core:" .. eff_id
            if def.speed then
                player_monoids.speed:del_change(player, monoid_key)
            end
            if def.jump then
                player_monoids.jump:del_change(player, monoid_key)
            end
            if def.gravity then
                player_monoids.gravity:del_change(player, monoid_key)
            end
            had_any = true
        end
    end
    if had_any or instant_fov then
        sync_player_fov(player, instant_fov == true)
    end
end

---Ticks all player timed effects and checks environmental boost conditions (Fertile Loam & Steam).
---@param dt number Elapsed step time
function tc_core.step_player_effects(dt)
    local players = core.get_connected_players()
    if #players == 0 then
        return
    end

    local is_running = tc_core.state.running
    for i = 1, #players do
        local player = players[i]
        local name = player:get_player_name()
        local effs = player_effects[name]
        if effs then
            for j = 1, #tc_core.EFFECT_ORDER do
                local eff_id = tc_core.EFFECT_ORDER[j]
                local rem = effs[eff_id]
                if rem and rem > 0 then
                    local new_rem = rem - dt
                    if new_rem <= 0 then
                        tc_core.remove_effect(player, eff_id)
                    else
                        effs[eff_id] = new_rem
                    end
                end
            end
        end

        if is_running then
            local ppos = player:get_pos()
            sample_foot_pos.x = math.floor(ppos.x + 0.5)
            sample_foot_pos.y = math.floor(ppos.y - 0.1)
            sample_foot_pos.z = math.floor(ppos.z + 0.5)

            sample_body_pos.x = sample_foot_pos.x
            sample_body_pos.y = math.floor(ppos.y + 0.5)
            sample_body_pos.z = sample_foot_pos.z

            local foot_node = core.get_node(sample_foot_pos).name
            local body_node = core.get_node(sample_body_pos).name

            if foot_node == "tc_elements:fertile_loam" then
                tc_core.apply_effect(player, "fertile_stride", 3.5)
            end
            if body_node == "tc_elements:steam" or foot_node == "tc_elements:steam" then
                tc_core.apply_effect(player, "steam_updraft", 5.0)
            end
        end

        tc_core.sync_player_atmosphere(player)
    end
end

---Formats active player boosts for the live HUD banner.
---@param player ObjectRef
---@return string
function tc_core.get_active_effects_text(player)
    local effs = player_effects[player:get_player_name()]
    if not effs then
        return "Boosts: None (Walk on green soil or drink Potions)"
    end

    local parts = {}
    for i = 1, #tc_core.EFFECT_ORDER do
        local eff_id = tc_core.EFFECT_ORDER[i]
        local rem = effs[eff_id]
        if rem and rem > 0 then
            local def = tc_core.EFFECT_DEFS[eff_id]
            parts[#parts + 1] = string.format("[%s %ds]", def.title, math.ceil(rem))
        end
    end

    if #parts == 0 then
        return "Boosts: None (Walk on green soil or drink Potions)"
    end
    return "Boosts: " .. table.concat(parts, " ")
end

-- ========================================================
-- ELIXIR REWARDS & SPECIAL ABILITIES
-- ========================================================

---Records hazard neutralizations by a player and rewards boost elixirs at milestones.
---@param player ObjectRef
---@param count? integer Number of hazards neutralized
function tc_core.record_neutralization(player, count)
    if not player or not player:is_player() then
        return
    end
    count = math.max(1, math.floor(count or 1))
    local name = player:get_player_name()
    local pstat = tc_core.player_stats[name]
    if not pstat then
        pstat = {neutralized = 0, downed_until = 0}
        tc_core.player_stats[name] = pstat
    end

    local prev = pstat.neutralized
    local curr = prev + count
    pstat.neutralized = curr

    local inv = player:get_inventory()
    if math.floor(curr / 3) > math.floor(prev / 3) then
        inv:add_item("main", "tc_tools:elixir_quicksilver")
        core.chat_send_player(
            name,
            tc_assets.chat_prefix("Bonus Potion", P.aqua) ..
            core.colorize(
                P.text_primary,
                "You earned a Quicksilver Potion (Fast Run & High Jump) for clearing 3 hazards!"
            )
        )
    end
    if math.floor(curr / 5) > math.floor(prev / 5) then
        inv:add_item("main", "tc_tools:elixir_aegis")
        core.chat_send_player(
            name,
            tc_assets.chat_prefix("Bonus Potion", P.gold) ..
            core.colorize(
                P.text_primary,
                "You earned an Aegis Potion (Full Heal & Plant Shield) for clearing 5 hazards!"
            )
        )
    end
end

---Credits hazard neutralizations to a player by name if connected (used for Trowel reagent pairings).
---@param player_name string
---@param count? integer
function tc_core.record_neutralization_by_name(player_name, count)
    if not player_name or player_name == "" then
        return
    end
    local player = core.get_player_by_name(player_name)
    if player then
        tc_core.record_neutralization(player, count)
    end
end

---Revives or heals a Crucible Sprout at or near the target position.
---@param pos table Target position
---@param user? ObjectRef Optional player reviving the sprout
---@param amount? number Vitality restored (defaults to 50.0)
---@return boolean revived True if a sprout was healed/revived
function tc_core.revive_sprout_at(pos, user, amount)
    amount = amount or 50.0
    local s = tc_core.state
    for i = 1, #s.plants do
        local p = s.plants[i]
        local dx = pos.x - p.pos.x
        local dy = pos.y - p.pos.y
        local dz = pos.z - p.pos.z
        if (dx * dx + dy * dy + dz * dz) <= 6.25 and (p.withered or p.vitality < 100.0) then
            local was_withered = p.withered
            p.withered = false
            p.vitality = tc_core.clamp(p.vitality + amount, 40.0, 100.0)
            p.last_infotext = nil

            local p_stage, stage_node = tc_elements.get_sprout_stage(p.bloom or s.bloom)
            p.stage = p_stage
            core.swap_node(p.pos, {name = stage_node})
            core.sound_play("tc_transmute", {pos = p.pos, gain = 0.9, max_hear_distance = 20}, true)
            tc_assets.spawn_sheet_particles({
                amount = 20,
                time = 0.30,
                minpos = {x = p.pos.x - 0.45, y = p.pos.y - 0.1, z = p.pos.z - 0.45},
                maxpos = {x = p.pos.x + 0.45, y = p.pos.y + 0.9, z = p.pos.z + 0.45},
                minvel = {x = -0.9, y = 0.8, z = -0.9},
                maxvel = {x = 0.9, y = 2.5, z = 0.9},
                minexptime = 0.55,
                maxexptime = 1.15,
                minsize = 1.5,
                maxsize = 3.1,
                glow = 14,
                texpool = {
                    tc_assets.make_sheet_tex_entry(tc_assets.PARTICLES.bloom, {scale_tween = {1.35, 0.55}}),
                    tc_assets.make_sheet_tex_entry(tc_assets.PARTICLES.pollen, {scale_tween = {1.25, 0.4}}),
                },
            })

            local liv = 0
            for k = 1, #s.plants do
                if not s.plants[k].withered then
                    liv = liv + 1
                end
            end
            s.living_plants = liv
            tc_core.recalc_mean_bloom()

            local who = (user and user:is_player()) and user:get_player_name() or "Calm Balance"
            local verb = was_withered and "revived" or "watered"
            core.chat_send_all(
                tc_assets.chat_prefix("Plant Healed", P.emerald) ..
                core.colorize(
                    P.text_primary,
                    string.format("%s %s Sprout #%d! (%.0f%% Health)", who, verb, p.index, p.vitality)
                )
            )
            return true
        end
    end
    return false
end

---Activates the Aegis Ward Tincture (heals user, revives withered sprouts, shields plant vitality for duration).
---@param user ObjectRef
---@param duration number
function tc_core.activate_aegis_ward(user, duration)
    local s = tc_core.state
    s.aegis_timer = math.max(s.aegis_timer, duration)
    user:set_hp(20)
    tc_core.apply_effect(user, "aegis_ward", duration)

    for i = 1, #s.plants do
        local p = s.plants[i]
        if p.withered then
            tc_core.revive_sprout_at(p.pos, user, 50.0)
        else
            p.vitality = math.min(100.0, p.vitality + 25.0)
        end
    end

    core.chat_send_all(
        tc_assets.chat_prefix("Aegis Potion", P.gold) ..
        core.colorize(
            P.text_primary,
            string.format(
                "%s drank an Aegis Potion! Full health restored and all plants are shielded for %ds!",
                user:get_player_name(), math.ceil(duration)
            )
        )
    )
end

---Activates the Chronos Sandglass (freezes drop timer, clears 1 hazard per plant, buffs team speed).
---@param user ObjectRef
---@param duration number
function tc_core.activate_chronos_stasis(user, duration)
    local s = tc_core.state
    s.stasis_timer = math.max(s.stasis_timer, duration)

    local players = core.get_connected_players()
    for i = 1, #players do
        tc_core.apply_effect(players[i], "chronos_surge", duration)
    end

    local cleared = 0
    for i = 1, #s.plants do
        local c = s.plants[i].pos
        local p_min = {x = c.x - 2, y = c.y - 1, z = c.z - 2}
        local p_max = {x = c.x + 2, y = c.y + 2, z = c.z + 2}
        local hazards = core.find_nodes_in_area(p_min, p_max, {"group:reagent"})
        if #hazards > 0 then
            core.remove_node(hazards[1])
            cleared = cleared + 1
        end
    end

    core.chat_send_all(
        tc_assets.chat_prefix("Time Frozen", P.violet) ..
        core.colorize(
            P.text_primary,
            string.format(
                "%s used a Chronos Hourglass! Falling blocks paused for %ds (and %d nearby hazard(s) cleared)!",
                user:get_player_name(), math.ceil(duration), cleared
            )
        )
    )
end

-- ========================================================
-- PERSISTENT TOP 10 LEADERBOARD (In-Memory Cached + mod_storage)
-- ========================================================

local cached_leaderboard = nil

local function sort_leaderboard(entries)
    table.sort(entries, function(a, b)
        local ca = a.levels_cleared or 0
        local cb = b.levels_cleared or 0
        if ca ~= cb then
            return ca > cb
        end
        if a.highest_level ~= b.highest_level then
            return a.highest_level > b.highest_level
        end
        if math.abs((a.max_bloom or 0) - (b.max_bloom or 0)) > 0.05 then
            return (a.max_bloom or 0) > (b.max_bloom or 0)
        end
        if (a.neutralized or 0) ~= (b.neutralized or 0) then
            return (a.neutralized or 0) > (b.neutralized or 0)
        end
        return (a.best_time or 999999) < (b.best_time or 999999)
    end)
end

local function get_leaderboard_entries()
    if cached_leaderboard then
        return cached_leaderboard
    end
    local raw = storage:get_string("leaderboard")
    if raw and raw ~= "" then
        local tbl = core.deserialize(raw)
        if type(tbl) == "table" then
            sort_leaderboard(tbl)
            cached_leaderboard = tbl
            return cached_leaderboard
        end
    end
    cached_leaderboard = {}
    return cached_leaderboard
end

local function save_leaderboard(entries)
    sort_leaderboard(entries)
    cached_leaderboard = entries
    storage:set_string("leaderboard", core.serialize(entries))
end

---Records or updates a player's best achievement in persistent mod storage.
---@param player_name string
---@param level_reached integer
---@param levels_cleared integer
---@param bloom_pct number
---@param neutralized integer
---@param seconds integer
function tc_core.record_player_score(player_name, level_reached, levels_cleared, bloom_pct, neutralized, seconds)
    if not player_name or player_name == "" then
        return
    end
    local entries = get_leaderboard_entries()
    local found = nil
    for i = 1, #entries do
        if entries[i].name == player_name then
            found = entries[i]
            break
        end
    end

    if not found then
        found = {
            name = player_name,
            highest_level = level_reached,
            levels_cleared = levels_cleared,
            max_bloom = bloom_pct,
            neutralized = neutralized,
            best_time = math.max(1, seconds),
        }
        entries[#entries + 1] = found
    else
        local is_better = false
        if levels_cleared > (found.levels_cleared or 0) then
            is_better = true
        elseif levels_cleared == (found.levels_cleared or 0) and level_reached > found.highest_level then
            is_better = true
        elseif level_reached == found.highest_level and bloom_pct > (found.max_bloom or 0) then
            is_better = true
        elseif level_reached == found.highest_level
                and math.abs(bloom_pct - (found.max_bloom or 0)) <= 0.1
                and neutralized > (found.neutralized or 0) then
            is_better = true
        end

        if is_better then
            found.highest_level = math.max(found.highest_level, level_reached)
            found.levels_cleared = math.max(found.levels_cleared or 0, levels_cleared)
            found.max_bloom = bloom_pct
            found.neutralized = math.max(found.neutralized or 0, neutralized)
            found.best_time = math.max(1, seconds)
        else
            found.neutralized = math.max(found.neutralized or 0, neutralized)
        end
    end

    save_leaderboard(entries)
end

---Records current progress for all connected players.
---@param level_cleared boolean Whether the current level was just completed (100% bloom)
function tc_core.record_all_players(level_cleared)
    local s = tc_core.state
    local cleared_cnt = level_cleared and s.level or math.max(0, s.level - 1)
    local reached_lvl = level_cleared and (s.level + 1) or s.level
    local bloom_to_save = level_cleared and 100.0 or s.bloom

    local players = core.get_connected_players()
    for i = 1, #players do
        local pname = players[i]:get_player_name()
        local pstat = tc_core.player_stats[pname] or {neutralized = 0}
        tc_core.record_player_score(
            pname,
            reached_lvl,
            cleared_cnt,
            bloom_to_save,
            pstat.neutralized or 0,
            s.run_seconds
        )
    end
end

---Returns the sorted Top 10 Leaderboard entries.
---@return LeaderboardEntry[]
function tc_core.get_top10()
    local entries = get_leaderboard_entries()
    local top = {}
    for i = 1, math.min(10, #entries) do
        top[i] = entries[i]
    end
    return top
end

---Builds a WCAG AA-accessible Formspec v8 table displaying the Top 10 Alchemists.
---@param x number Formspec X position
---@param y number Formspec Y position
---@param w number Formspec width
---@param h number Formspec height
---@return string
function tc_core.build_top10_table_formspec(x, y, w, h)
    local top = tc_core.get_top10()
    local rows = {
        P.gold .. ",Rank,Player,Highest Level,Levels Won,Best Bloom,Cleared,Time",
    }

    if #top == 0 then
        rows[#rows + 1] = P.text_secondary .. ",-,(No scores saved yet — finish or reset a level to record!),-,-,-,-,-"
    else
        for i = 1, #top do
            local e = top[i]
            local color = (i == 1 and P.gold)
                or (i == 2 and P.aqua)
                or (i == 3 and P.amber)
                or P.text_primary
            local hl = e.highest_level or 1
            rows[#rows + 1] = string.format(
                "%s,#%d,%s,Level %d (%d %s),%d,%.0f%%,%d,%ds",
                color,
                i,
                core.formspec_escape(e.name),
                hl,
                hl,
                hl == 1 and "Room" or "Rooms",
                e.levels_cleared or 0,
                e.max_bloom or 0,
                e.neutralized or 0,
                e.best_time or 0
            )
        end
    end

    local opts = "tableoptions[background=" .. P.bg_inset .. ";highlight=#352854;border=true]"
    local cols = "tablecolumns[color;text,align=center;text,align=left;text,align=center;" ..
        "text,align=center;text,align=center;text,align=center;text,align=right]"
    return string.format(
        "%s%stable[%.2f,%.2f;%.2f,%.2f;tbl_top10;%s;1]",
        opts, cols, x, y, w, h, table.concat(rows, ",")
    )
end

-- ========================================================
-- LEVEL MANAGEMENT & RESET
-- ========================================================

---Starts or expands the terrarium to the target level (`level` cubes, `level` plants).
---@param level integer Target level (1..N)
---@param preserve_fertile? boolean Preserve existing fertile_loam speed highways
function tc_core.start_level(level, preserve_fertile)
    level = math.max(1, math.floor(level or 1))
    local s = tc_core.state

    s.running = true
    s.epoch = (s.epoch or 0) + 1
    s.victory = false
    s.defeat = false
    s.defeat_reason = ""
    s.level = level
    s.bloom = 0.0
    s._synced_bloom = 0.0
    s.temperature = 50.0
    s.ph = 50.0
    s.seconds_elapsed = 0
    s.offered_boons = {}
    if level == 1 then
        s.run_seconds = 0
        s.reagents_dropped = 0
        s.peak_harmony = 0
        s.boons = {}
        tc_core.player_stats = {}
    end
    s.wave = 0
    s.drop_timer = (level == 1) and 4.0 or 5.5
    s.harmony_streak = 0
    s.aegis_timer = 0.0
    s.stasis_timer = 0.0
    s.active_reagents = 0
    s.max_reagents = 6 + (5 * level)
    s.overload_timer = 0
    s.turbulent = false

    tc_core.clear_all_waypoints()

    -- Build or expand the open-top cubic terrarium & workshop diorama
    tc_world.build_level(level, preserve_fertile)

    -- Initialize per-plant vitality & asynchronous growth tempo across all `level` cubes
    local cells = tc_world.get_active_cells(level)
    local n_cells = #cells
    local tempos = {}
    if n_cells <= 1 then
        tempos[1] = 1.0
    else
        local sum_t = 0.0
        for i = 1, n_cells do
            local frac = (i - 1) / (n_cells - 1)
            local base = 0.84 + (0.32 * frac)
            local jitter = boon_rng:next(-25, 25) / 1000.0
            tempos[i] = tc_core.clamp(base + jitter, 0.80, 1.22)
        end
        for i = n_cells, 2, -1 do
            local j = boon_rng:next(1, i)
            tempos[i], tempos[j] = tempos[j], tempos[i]
        end
        for i = 1, n_cells do
            sum_t = sum_t + tempos[i]
        end
        local inv_mean = n_cells / sum_t
        for i = 1, n_cells do
            tempos[i] = tempos[i] * inv_mean
        end
    end

    s.plants = {}
    for i = 1, n_cells do
        s.plants[i] = {
            index = i,
            pos = {x = cells[i].center.x, y = cells[i].center.y, z = cells[i].center.z},
            bloom = 0.0,
            stage = 1,
            growth_tempo = tempos[i],
            fertile_near = 0,
            vitality = 100.0,
            withered = false,
            hazards_near = 0,
            local_stress = false,
            last_infotext = nil,
        }
    end
    s.living_plants = #s.plants
    s.avg_vitality = 100.0

    -- Equip & reward connected players
    local players = core.get_connected_players()
    for i = 1, #players do
        local p = players[i]
        local pname = p:get_player_name()
        tc_core.player_stats[pname] = tc_core.player_stats[pname] or {neutralized = 0, downed_until = 0}
        tc_core.player_stats[pname].downed_until = 0

        if level == 1 then
            x_player_api.stop_emote(p)
            tc_core.set_player_sprinting(p, false)
            tc_core.clear_player_effects(p, true)
            tc_init.equip_player(p, true)
            p:set_pos(tc_init.SPAWN_POS)
        else
            tc_tools.clear_player_trowels(p)
            tc_init.equip_player(p, false)
            local inv = p:get_inventory()
            inv:add_item("main", "tc_tools:elixir_quicksilver")
            inv:add_item("main", "tc_tools:elixir_aegis")
            inv:add_item("main", "tc_tools:chronos_sandglass")
            tc_core.apply_effect(p, "quicksilver", 10.0)
        end
    end

    if level > 1 then
        local wave_drops = tc_core.get_wave_drop_count(level, #players)
        core.chat_send_all(core.colorize(P.aqua, "=================================================="))
        core.chat_send_all(core.colorize(
            P.gold,
            string.format(
                "★ LEVEL %d BEGINS! (%d Glass Rooms · %d Plants · %d Block(s)/Wave) ★",
                level, level, level, wave_drops
            )
        ))
        core.chat_send_all(
            tc_assets.chat_prefix("Bonus Supplies", P.emerald) ..
            core.colorize(P.text_primary, "Received +1 Quicksilver Potion, +1 Aegis Potion, and +1 Chronos Hourglass!")
        )
        core.chat_send_all(core.colorize(P.aqua, "=================================================="))
    end
end

---Resets the entire game back to Level 1 and closes any open end-of-run dialogs across connected players.
function tc_core.reset_crucible()
    tc_core.start_level(1, false)
    local players = core.get_connected_players()
    for i = 1, #players do
        local pname = players[i]:get_player_name()
        core.close_formspec(pname, "tc_core:victory")
        core.close_formspec(pname, "tc_core:defeat")
        core.close_formspec(pname, "tc_core:altar")
    end
end

---Triggers Defeat with a specific failure reason, records scores, and shows the Defeat dialog.
---@param reason string Explanation of why the run was lost
function tc_core.trigger_defeat(reason)
    local s = tc_core.state
    if s.defeat or s.victory then
        return
    end
    s.defeat = true
    s.running = false
    s.defeat_reason = reason or "The garden lost its balance!"

    tc_core.record_all_players(false)

    core.sound_play("tc_defeat", {gain = 1.0}, true)
    core.chat_send_all(core.colorize(P.coral, "=================================================="))
    core.chat_send_all(core.colorize(P.coral, "✖ GARDEN RUN ENDED ON LEVEL " .. s.level .. " ✖"))
    core.chat_send_all(
        tc_assets.chat_prefix("What Happened", P.amber) ..
        core.colorize(P.text_primary, s.defeat_reason)
    )
    core.chat_send_all(core.colorize(P.coral, "=================================================="))

    local players = core.get_connected_players()
    for i = 1, #players do
        local pl = players[i]
        tc_core.set_player_sprinting(pl, false)
        tc_core.clear_player_effects(pl, false)
        x_player_api.play_emote(pl, "bow", 3.0)
        tc_core.show_defeat_dialog(pl)
    end
end

---Handles player death for solo Defeat or co-op multiplayer team wipe check.
---@param player ObjectRef
function tc_core.on_player_died(player)
    if not player or not player:is_player() then
        return
    end
    tc_core.set_player_sprinting(player, false)
    tc_core.clear_player_effects(player, true)
    local s = tc_core.state
    if not s.running then
        return
    end

    local players = core.get_connected_players()
    local pname = player:get_player_name()
    tc_core.player_stats[pname] = tc_core.player_stats[pname] or {neutralized = 0, downed_until = 0}
    tc_core.player_stats[pname].downed_until = s.run_seconds + 5

    if #players <= 1 then
        local survivors = 0
        local tot_v = 0.0
        for i = 1, #s.plants do
            local p = s.plants[i]
            if not p.withered then
                p.vitality = tc_core.clamp(p.vitality - 30.0, 0.0, 100.0)
                p.last_infotext = nil
                if p.vitality <= 0.0 then
                    p.withered = true
                    core.swap_node(p.pos, {name = "tc_elements:crucible_sprout_withered"})
                else
                    survivors = survivors + 1
                    tot_v = tot_v + p.vitality
                end
            end
        end
        s.living_plants = survivors
        s.avg_vitality = (#s.plants > 0) and (tot_v / #s.plants) or 0.0
        tc_core.recalc_mean_bloom()

        if survivors <= 0 then
            tc_core.trigger_defeat(
                "You ran out of health, and the shockwave wilted the last remaining plant!"
            )
        else
            core.sound_play("tc_wither", {gain = 0.85}, true)
            core.chat_send_all(
                tc_assets.chat_prefix("Second Chance", P.coral) ..
                core.colorize(
                    P.text_primary,
                    "You ran out of health! Brought back at the Altar (plants lost 30% health—water them soon!)."
                )
            )
        end
        return
    end

    local all_down = true
    for i = 1, #players do
        local other_name = players[i]:get_player_name()
        local st = tc_core.player_stats[other_name]
        if other_name ~= pname and players[i]:get_hp() > 0 and (not st or (st.downed_until or 0) <= s.run_seconds) then
            all_down = false
            break
        end
    end

    if all_down then
        tc_core.trigger_defeat("Everyone on the team ran out of health at the same time!")
    else
        core.chat_send_all(
            tc_assets.chat_prefix("Team Alert", P.amber) ..
            core.colorize(
                P.text_primary,
                string.format("%s was knocked down! Teammates: stay safe for 5 seconds while they recover!", pname)
            )
        )
    end
end

---Applies brief reconstitution penalty when a player respawns in co-op mode.
---@param player ObjectRef
function tc_core.on_player_respawned(player)
    tc_core.set_player_sprinting(player, false)
    if tc_core.state.running then
        tc_core.apply_effect(player, "reconstitution", 5.0)
    else
        sync_player_fov(player, true)
    end
end
