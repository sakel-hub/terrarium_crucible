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
---@field retries? integer Level retries used in this run (0 = flawless run)
---@field neutralized integer Total hazards neutralized in best run
---@field best_time integer Run time in seconds

---@class TcBlessingDef
---@field id string Unique Next-Level Garden Blessing identifier
---@field title string Display title
---@field icon string Itemstring rendered on the Blessing card badge
---@field accent string AA-accessible hex accent color
---@field summary string Concise 1-level gameplay effect description for Victory draft cards
---@field active_summary string Concise active-level effect description for Garden Controls

---@class TcEffectDef
---@field title string UI display title
---@field hud_label string Compact label rendered inside the 192px hudbar
---@field bar_tex string 2x16 progress bar texture filename
---@field icon_tex string 24x24 badge icon texture filename
---@field speed? number Optional player_monoids speed multiplier
---@field jump? number Optional player_monoids jump multiplier
---@field gravity? number Optional player_monoids gravity multiplier

---@class TcWavePreview
---@field wave_num integer Upcoming 1-based wave index
---@field level integer Level for which this preview was rolled
---@field kind "normal"|"trial"|"geode"|"surge" Wave classification
---@field trial_id integer Trial archetype index (1..4 when kind == "trial", else 0)
---@field items string[] Ordered itemstrings scheduled to drop in this wave

---@class TcHudEventSpec
---@field priority? integer Preemption priority (1 = ambient, 2 = milestone, 3 = critical)
---@field icon string Texture filename for the 24x24 toast icon
---@field title string Concise primary toast headline
---@field detail? string Supporting counterplay or status subtitle
---@field color? integer 24-bit RGB hex integer for headline text
---@field accent_hex? string "#RRGGBB" tint applied to the left accent strip
---@field ttl? number Toast visibility duration in seconds

---@class TcHudActionSpec
---@field kind? "action"|"hint" Pill mode ("action" coalesces Bloom gains; "hint" shows counterplay guidance)
---@field icon string Texture filename for the pill's leading 20-24px icon
---@field bloom? number Optional Bloom percentage gained from this action
---@field label? string Action summary suffix when kind == "action"
---@field text? string Hint text when kind == "hint"
---@field color? integer 24-bit RGB hex integer for pill text
---@field accent_hex? string "#RRGGBB" tint for optional accent styling
---@field ttl? number Pill visibility duration in seconds

---@class TcHudLayout
---@field tier "compact"|"standard"|"wide" Viewport density tier
---@field lw number Logical viewport width in HUD pixels
---@field lh number Logical viewport height in HUD pixels
---@field icon_px integer Rendered reagent/tool icon edge length in logical pixels (20 or 24)
---@field icon_scale number Scale factor applied to 32x32 item textures (0.625 or 0.75)
---@field banner_w integer Native pixel width of the top-center alchemical banner plaque
---@field banner_max integer Max UTF-8 characters per top-center banner line
---@field card_w integer Width of top-right next-drop plaque in logical pixels
---@field card_h integer Height of top-right next-drop plaque in logical pixels
---@field card_max integer Max UTF-8 characters inside top-right drop plaque lines
---@field toast_w integer Width of bottom-left priority event toast plaque in logical pixels
---@field toast_h integer Height of bottom-left priority event toast plaque in logical pixels
---@field toast_max integer Max UTF-8 characters inside event toast lines
---@field pill_max integer Max UTF-8 characters inside bottom-center action pill
---@field drop_ox integer Top-right drop plaque X offset from right screen edge (negative pixels)
---@field drop_oy integer Top-right drop plaque Y offset from top screen edge in logical pixels
---@field hb_ox integer Right-edge hudbars X offset from right screen edge (negative pixels)
---@field hb_start_y integer Right-edge first hudbar Y offset from top screen edge (guaranteed below drop card)
---@field hb_vmargin integer Vertical pixel pitch between stacked right-edge hudbars
---@field toast_ox integer Bottom-left event toast X offset from left screen edge
---@field toast_oy integer Bottom-left event toast Y offset from bottom screen edge (negative pixels)

---@class TcCoreAPI
---@field S fun(str: string, ...: any): string Mod translator function
---@field INTERVALS table<string, number>
---@field OPPOSITE_PAIRS string[][]
---@field EFFECT_DEFS table<string, TcEffectDef>
---@field EFFECT_ORDER string[]
---@field BLESSING_ORDER string[]
---@field BLESSING_DEFS table<string, TcBlessingDef>
---@field player_stats table<string, {neutralized: integer, downed_until: integer, run_id?: integer}>
---@field state table
---@field clamp fun(val: number, min_v: number, max_v: number): number
---@field next_random fun(min_v: integer, max_v: integer): integer
---@field get_wave_drop_count fun(level: integer, player_count?: integer): integer
---@field get_next_wave_interval fun(level?: integer, player_count?: integer): number
---@field roll_next_wave fun(player_count?: integer): TcWavePreview
---@field ensure_next_wave fun(player_count?: integer): TcWavePreview
---@field is_in_harmony fun(): boolean
---@field has_blessing fun(blessing_id: string): boolean
---@field select_blessing fun(blessing_id?: string, immediate?: boolean)
---@field roll_offered_blessings fun(): string[]
---@field get_potion_cap fun(item_name: string): integer
---@field count_player_item fun(player: ObjectRef, item_name: string): integer
---@field grant_potion fun(player: ObjectRef, item_name: string, count?: integer): integer, integer, number
---@field sanitize_player_inventory fun(player: ObjectRef)
---@field sync_joining_player fun(player: ObjectRef)
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
---@field apply_effect fun(player: ObjectRef, effect_id: string, duration: number, defer_hud?: boolean)
---@field remove_effect fun(player: ObjectRef, effect_id: string, defer_hud?: boolean)
---@field has_effect fun(player: ObjectRef, effect_id: string): boolean
---@field get_effect_state fun(player: ObjectRef, effect_id: string): number, number
---@field clear_player_effects fun(player: ObjectRef, instant_fov?: boolean)
---@field init_player_fov fun(player: ObjectRef)
---@field set_player_sprinting fun(player: ObjectRef, sprinting: boolean)
---@field sync_player_atmosphere fun(player: ObjectRef)
---@field step_player_effects fun(dt: number)
---@field damage_player fun(player: ObjectRef, amount: integer, source?: string): boolean
---@field step_player_hazards fun(in_harmony: boolean)
---@field record_neutralization fun(player: ObjectRef, count?: integer)
---@field record_neutralization_by_name fun(player_name: string, count?: integer)
---@field revive_sprout_at fun(pos: table, user?: ObjectRef, amount?: number): boolean
---@field activate_aegis_ward fun(user: ObjectRef, duration?: number)
---@field activate_chronos_stasis fun(user: ObjectRef, duration: number)
---@field record_player_score fun(
---    name: string, lvl: integer, clr: integer, bloom: number, neut: integer, sec: integer, retries?: integer)
---@field record_all_players fun(level_cleared: boolean)
---@field get_top10 fun(): LeaderboardEntry[]
---@field build_top10_table_formspec fun(x: number, y: number, w: number, h: number): string
---@field build_run_receipt fun(player?: ObjectRef): string
---@field start_level fun(level: integer, preserve_fertile?: boolean, is_retry?: boolean)
---@field retry_level fun()
---@field reset_crucible fun()
---@field trigger_defeat fun(reason: string, defeat_kind?: string)
---@field on_player_died fun(player: ObjectRef)
---@field on_player_respawned fun(player: ObjectRef)
---@field get_hud_layout fun(player_name: string): TcHudLayout
---@field resolve_player_text fun(player_name: string, str: string): string
---@field clamp_hud_text fun(str: string, max_chars: integer): string
---@field push_hud_event fun(spec: TcHudEventSpec)
---@field push_hud_event_player fun(player: ObjectRef, spec: TcHudEventSpec)
---@field push_action_feedback fun(player: ObjectRef, spec: TcHudActionSpec)
---@field push_action_feedback_all fun(spec: TcHudActionSpec)
---@field step_hud_timers fun(player: ObjectRef, dt: number)
---@field sync_player_drop_hud fun(player: ObjectRef)
---@field sync_player_cargo_hud fun(player: ObjectRef)
---@field clear_player_hud_transients fun(player: ObjectRef)
---@field init_player_hud fun(player: ObjectRef)
---@field update_player_hud fun(player: ObjectRef)
---@field sync_player_effect_hudbars fun(player: ObjectRef)
---@field clear_all_waypoints fun()
---@field ping_chamber fun(player: ObjectRef)
---@field show_guide_dialog fun(player: ObjectRef, tab_idx?: integer)
---@field show_garden_dialog fun(player: ObjectRef)
---@field show_leaderboard_dialog fun(player: ObjectRef)
---@field show_victory_dialog fun(player: ObjectRef)
---@field show_defeat_dialog fun(player: ObjectRef)
tc_core = {
    S = core.get_translator("tc_core"),
}

local S = tc_core.S
local P = tc_assets.PALETTE
local storage = core.get_mod_storage()

-- Read user-configured settings from settingtypes.txt and engine configuration
local cfg_normal = tonumber(core.settings:get("tc_drop_interval")) or 11.5
cfg_normal = math.max(5.0, math.min(60.0, cfg_normal))

local cfg_diff = core.settings:get("tc_difficulty") or "normal"
if cfg_diff ~= "casual" and cfg_diff ~= "normal" and cfg_diff ~= "panic" then
    cfg_diff = "normal"
end

-- Drop interval configuration per difficulty (16.5s Casual, 11.5s Normal, 7.5s Panic by default)
tc_core.INTERVALS = {
    casual = math.min(60.0, math.floor(cfg_normal * 1.435 * 2.0 + 0.5) * 0.5),
    normal = cfg_normal,
    panic  = math.max(5.0, math.floor(cfg_normal * 0.652 * 2.0 + 0.5) * 0.5),
}

-- Priority-ordered array of effect identifiers for LuaJIT trace-friendly iteration & hudbars packing
tc_core.EFFECT_ORDER = {
    "aegis_ward",
    "chronos_surge",
    "harmonic_overdrive",
    "fertile_stride",
    "steam_updraft",
    "reconstitution",
}

-- Effect definitions backed by player_monoids and dynamic hudbars slots
tc_core.EFFECT_DEFS = {
    aegis_ward = {
        title = S("Aegis Shield"),
        hud_label = S("Aegis Shield"),
        bar_tex = "tc_bar_effect_aegis.png",
        icon_tex = "tc_icon_effect_aegis.png",
        speed = 1.15,
    },
    chronos_surge = {
        title = S("Time Freeze Speed"),
        hud_label = S("Time Freeze"),
        bar_tex = "tc_bar_effect_chronos.png",
        icon_tex = "tc_icon_effect_chronos.png",
        speed = 1.35,
    },
    harmonic_overdrive = {
        title = S("Harmony Boost"),
        hud_label = S("Harmony Boost"),
        bar_tex = "tc_bar_effect_harmony.png",
        icon_tex = "tc_icon_effect_harmony.png",
        speed = 1.25,
    },
    fertile_stride = {
        title = S("Green Soil Speed"),
        hud_label = S("Soil Speed"),
        bar_tex = "tc_bar_effect_soil.png",
        icon_tex = "tc_icon_effect_soil.png",
        speed = 1.50,
    },
    steam_updraft = {
        title = S("Steam High Jump"),
        hud_label = S("Steam Jump"),
        bar_tex = "tc_bar_effect_steam.png",
        icon_tex = "tc_icon_effect_steam.png",
        jump = 1.50,
        gravity = 0.50,
    },
    reconstitution = {
        title = S("Recovering"),
        hud_label = S("Recovering"),
        bar_tex = "tc_bar_effect_debuff.png",
        icon_tex = "tc_icon_effect_debuff.png",
        speed = 0.65,
    },
}

-- Ordered Next-Level Garden Blessings (1 temporary blessing active per level, drafted fresh each victory)
tc_core.BLESSING_ORDER = {
    "deep_retort",
    "dragonlung_bellows",
    "starlight_mortar",
    "leyline_roots",
    "hermetic_boots",
    "featherfall_canopy",
    "prismatic_catalyst",
    "sunlit_dew",
}

tc_core.BLESSING_DEFS = {
    deep_retort = {
        id = "deep_retort",
        title = S("Deep Retort"),
        icon = "tc_tools:condenser_flask_full",
        accent = P.aqua,
        summary = S("Next Level: Water Flask [3] holds +2 extra Splashes & refills immediately."),
        active_summary = S("Water Flask [3] holds +2 extra Splashes & refills immediately."),
    },
    dragonlung_bellows = {
        id = "dragonlung_bellows",
        title = S("Dragonlung Bellows"),
        icon = "tc_tools:bellows",
        accent = P.amber,
        summary = S("Next Level: Bellows [2] holds +2 extra Puffs, melts 3x3 Ice & gives extra growth."),
        active_summary = S("Bellows [2] holds +2 extra Puffs, melts 3x3 Ice & gives extra growth."),
    },
    starlight_mortar = {
        id = "starlight_mortar",
        title = S("Starlight Mortar"),
        icon = "tc_tools:chalk_pestle",
        accent = P.violet,
        summary = S("Next Level: Pestle [4] holds +2 extra Sweeps, clears 5x5 Acid & gives extra growth."),
        active_summary = S("Pestle [4] holds +2 extra Sweeps, clears 5x5 Acid & gives extra growth."),
    },
    leyline_roots = {
        id = "leyline_roots",
        title = S("Ley-Line Roots"),
        icon = "tc_elements:crucible_sprout_3",
        accent = P.emerald,
        summary = S("Next Level: Plants heal faster when balanced & revive in 4s (was 6s)."),
        active_summary = S("Plants heal faster when balanced & revive in 4s (was 6s)."),
    },
    hermetic_boots = {
        id = "hermetic_boots",
        title = S("Hermetic Boots"),
        icon = "tc_elements:fertile_loam",
        accent = P.gold,
        summary = S("Next Level: Run faster on green Soil & take half damage from hazards."),
        active_summary = S("Run faster on green Soil & take half damage from hazards."),
    },
    featherfall_canopy = {
        id = "featherfall_canopy",
        title = S("Featherfall Winds"),
        icon = "tc_tools:chronos_sandglass",
        accent = P.aqua,
        summary = S("Next Level: Blocks fall slower (+1.5s waves) & mid-air catches give extra Bloom."),
        active_summary = S("Blocks fall slower (+1.5s waves) & mid-air catches give extra Bloom."),
    },
    prismatic_catalyst = {
        id = "prismatic_catalyst",
        title = S("Crystal Resonance"),
        icon = "tc_elements:aether_geode",
        accent = P.gold,
        summary = S("Next Level: Bonus Geodes drop twice as often & Trowel [1] combos give +25% Bloom."),
        active_summary = S("Bonus Geodes drop twice as often & Trowel [1] combos give +25% Bloom."),
    },
    sunlit_dew = {
        id = "sunlit_dew",
        title = S("Sunlit Dew"),
        icon = "tc_tools:elixir_aegis",
        accent = P.emerald,
        summary = S("Next Level: Start with +1 extra Aegis Potion (14s shield), & Balance heals 1 Heart/3s!"),
        active_summary = S("Start with +1 extra Aegis Potion (14s shield), & Balance heals 1 Heart/3s!"),
    },
}

-- Active timed effects per player: player_effects[player_name][effect_id] = remaining_seconds
local player_effects = {}
local player_effect_max = {}
local player_boost_spd_cache = {}
local player_harmony_heal_ticks = {}
local player_sprint_active = {}
local player_fov_cache = {}
local player_join_us = {}
local player_fov_change_us = {}
local player_light_cache = {}
local blessing_rng = PcgRandom(os.time() + 1337)

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
    run_id = 1,
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
    active_blessing = nil,
    prev_blessing = nil,
    pending_blessing = nil,
    blessing_chooser = nil,
    offered_blessings = {},
    next_wave = nil,
    active_drop = nil,
    climax_triggered = false,
    cleanup_phase = false,
    falling_hazards = 0,
    carried_hazards = 0,
    remaining_hazards = 0,
    cleanup_icons = {},
    retries = 0,
    level_checkpoint = nil,
    trial_cursor = 0,
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
    player_effect_max[name] = nil
    player_boost_spd_cache[name] = nil
    player_harmony_heal_ticks[name] = nil
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

---Computes the monotonically tightening wave interval (in seconds) for the given level and player count.
---@param level? integer
---@param player_count? integer
---@return number
function tc_core.get_next_wave_interval(level, player_count)
    local s = tc_core.state
    local lvl = math.max(1, math.floor(level or s.level or 1))
    local drops = tc_core.get_wave_drop_count(lvl, player_count)
    local base_iv = tc_core.INTERVALS[s.difficulty] or tc_core.INTERVALS.normal
    local canopy_pad = tc_core.has_blessing("featherfall_canopy") and 1.5 or 0.0
    local iv = base_iv
        - math.min(3.6, (lvl - 1) * 0.55)
        + math.min(1.6, (drops - 1) * 0.40)
        + canopy_pad
    return tc_core.clamp(iv, 6.0, 60.0)
end

-- High-entropy PCG random generator + 8-card shuffled bag (2x per reagent) for deterministic wave previews
local wave_rng = PcgRandom(os.time() + (core.get_us_time() % 1000000))
local reagent_bag = {}

tc_core.OPPOSITE_PAIRS = {
    {"tc_elements:brimstone", "tc_elements:cryo_ice"},
    {"tc_elements:acid_slime", "tc_elements:alkaline_chalk"},
}

---Returns a deterministic random integer in `[min_v, max_v]` using the shared crucible wave RNG.
---@param min_v integer
---@param max_v integer
---@return integer
function tc_core.next_random(min_v, max_v)
    return wave_rng:next(min_v, max_v)
end

local function next_reagent_name()
    local reagents = tc_elements.REAGENTS
    if #reagent_bag == 0 then
        for _ = 1, 2 do
            for i = 1, #reagents do
                reagent_bag[#reagent_bag + 1] = i
            end
        end
        for i = #reagent_bag, 2, -1 do
            local j = wave_rng:next(1, i)
            reagent_bag[i], reagent_bag[j] = reagent_bag[j], reagent_bag[i]
        end
    end
    local idx = table.remove(reagent_bag)
    return reagents[idx].name
end

local function pick_trial_reagent(trial_id, drop_idx, total_drops, wave_num)
    if trial_id == 1 then
        local pair_idx = (drop_idx <= 2) and ((wave_num % 2) + 1) or (((wave_num + 1) % 2) + 1)
        return tc_core.OPPOSITE_PAIRS[pair_idx][((drop_idx - 1) % 2) + 1]
    elseif trial_id == 2 then
        if total_drops >= 3 and drop_idx == total_drops then
            return "tc_elements:cryo_ice"
        end
        return "tc_elements:brimstone"
    elseif trial_id == 3 then
        return "tc_elements:cryo_ice"
    end
    return "tc_elements:acid_slime"
end

---Pre-rolls the upcoming falling-reagent wave so the Top-Right Drop Forecast HUD shows exact upcoming blocks.
---@param player_count? integer
---@return TcWavePreview
function tc_core.roll_next_wave(player_count)
    local s = tc_core.state
    local p_cnt = player_count or math.max(1, #core.get_connected_players())
    local next_w = (s.wave or 0) + 1
    local lvl = math.max(1, s.level or 1)
    local total_drops = tc_core.get_wave_drop_count(lvl, p_cnt)

    local geode_mod = tc_core.has_blessing("prismatic_catalyst") and 2 or 4
    local spawn_geode = (lvl >= 2) and (next_w % geode_mod == 0)
    local is_trial = (lvl >= 3) and (next_w % 3 == 0) and not spawn_geode
    local trial_id = is_trial and (((s.trial_cursor or 0) % 4) + 1) or 0

    local items = {}
    for d = 1, total_drops do
        if spawn_geode and d == total_drops then
            items[d] = "tc_elements:aether_geode"
        elseif is_trial then
            items[d] = pick_trial_reagent(trial_id, d, total_drops, next_w)
        else
            items[d] = next_reagent_name()
        end
    end

    local kind = spawn_geode and "geode" or (is_trial and "trial" or "normal")
    s.next_wave = {
        wave_num = next_w,
        level = lvl,
        kind = kind,
        trial_id = trial_id,
        items = items,
    }
    return s.next_wave
end

---Ensures `tc_core.state.next_wave` matches the upcoming wave index, blessing state, and active player count.
---@param player_count? integer
---@return TcWavePreview
function tc_core.ensure_next_wave(player_count)
    local s = tc_core.state
    local p_cnt = player_count or math.max(1, #core.get_connected_players())
    local expected_w = (s.wave or 0) + 1
    local lvl = math.max(1, s.level or 1)
    local nw = s.next_wave

    if not nw or nw.wave_num ~= expected_w or nw.level ~= lvl then
        return tc_core.roll_next_wave(p_cnt)
    end

    local geode_mod = tc_core.has_blessing("prismatic_catalyst") and 2 or 4
    local want_geode = (lvl >= 2) and (expected_w % geode_mod == 0)
    if (nw.kind == "geode") ~= want_geode then
        return tc_core.roll_next_wave(p_cnt)
    end

    local total_drops = tc_core.get_wave_drop_count(lvl, p_cnt)
    local items = nw.items
    if #items ~= total_drops then
        if nw.kind == "trial" then
            local rebuilt = {}
            for d = 1, total_drops do
                rebuilt[d] = pick_trial_reagent(nw.trial_id, d, total_drops, expected_w)
            end
            nw.items = rebuilt
        elseif nw.kind == "geode" then
            if items[#items] == "tc_elements:aether_geode" then
                items[#items] = nil
            end
            local prefix_target = math.max(0, total_drops - 1)
            while #items < prefix_target do
                items[#items + 1] = next_reagent_name()
            end
            while #items > prefix_target do
                items[#items] = nil
            end
            items[#items + 1] = "tc_elements:aether_geode"
        else
            while #items < total_drops do
                items[#items + 1] = next_reagent_name()
            end
            while #items > total_drops do
                items[#items] = nil
            end
        end
    end

    return nw
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
-- NEXT-LEVEL GARDEN BLESSINGS & INSTANT REACTIONS
-- ========================================================

local sync_player_boost_speed
local sync_player_fov

local function sync_blessing_equipment(target_player, allow_refill)
    local players = target_player and {target_player} or core.get_connected_players()
    local refill = (allow_refill ~= false)
    local has_dragon = refill and tc_core.has_blessing("dragonlung_bellows")
    local has_retort = refill and tc_core.has_blessing("deep_retort")
    local has_mortar = refill and tc_core.has_blessing("starlight_mortar")
    local max_bellows = tc_tools.get_max_bellows_charges()
    local max_flask = tc_tools.get_max_flask_charges()
    local max_pestle = tc_tools.get_max_pestle_charges()

    for i = 1, #players do
        local p = players[i]
        local inv = p:get_inventory()
        local list = inv:get_list("main")
        if list then
            local changed = false
            for slot = 1, #list do
                local st = list[slot]
                local sname = st:get_name()
                if has_dragon and (sname == "tc_tools:bellows" or sname == "tc_tools:bellows_empty") then
                    list[slot] = tc_tools.fill_bellows()
                    changed = true
                elseif not has_dragon and sname == "tc_tools:bellows" then
                    local clamped = math.min(max_bellows, tc_tools.get_bellows_charges(st))
                    list[slot] = tc_tools.set_bellows_charges(st, clamped)
                    changed = true
                elseif has_retort and (sname == "tc_tools:condenser_flask_full"
                        or sname == "tc_tools:condenser_flask") then
                    list[slot] = tc_tools.fill_flask()
                    changed = true
                elseif not has_retort and sname == "tc_tools:condenser_flask_full" then
                    local clamped = math.min(max_flask, tc_tools.get_flask_charges(st))
                    list[slot] = tc_tools.set_flask_charges(st, clamped)
                    changed = true
                elseif has_mortar and (sname == "tc_tools:chalk_pestle"
                        or sname == "tc_tools:chalk_pestle_empty") then
                    list[slot] = tc_tools.fill_pestle()
                    changed = true
                elseif not has_mortar and sname == "tc_tools:chalk_pestle" then
                    local clamped = math.min(max_pestle, tc_tools.get_pestle_charges(st))
                    list[slot] = tc_tools.set_pestle_charges(st, clamped)
                    changed = true
                end
            end
            if changed then
                inv:set_list("main", list)
                x_player_api.update_wield_item(p, true)
            end
        end
        sync_player_boost_speed(p)
        sync_player_fov(p)
    end
end

---Returns true if the specified temporary Garden Blessing is active on the current level.
---@param blessing_id string
---@return boolean
function tc_core.has_blessing(blessing_id)
    return tc_core.state.active_blessing == blessing_id
end

---Queues a 1-level Garden Blessing for the next level, or activates it immediately when `immediate == true`.
---@param blessing_id? string
---@param immediate? boolean
function tc_core.select_blessing(blessing_id, immediate)
    local s = tc_core.state
    if blessing_id ~= nil and not tc_core.BLESSING_DEFS[blessing_id] then
        return
    end
    if immediate then
        s.active_blessing = blessing_id
        s.pending_blessing = nil
        sync_blessing_equipment()
        tc_core.ensure_next_wave(#core.get_connected_players())
    else
        s.pending_blessing = blessing_id
    end
end

---Rolls 3 distinct Next-Level Garden Blessing choices (excluding the just-completed level's blessing).
---@return string[]
function tc_core.roll_offered_blessings()
    local s = tc_core.state
    if #s.offered_blessings >= 3 then
        return s.offered_blessings
    end

    local pool = {}
    for i = 1, #tc_core.BLESSING_ORDER do
        local bid = tc_core.BLESSING_ORDER[i]
        if bid ~= s.prev_blessing then
            pool[#pool + 1] = bid
        end
    end

    for i = #pool, 2, -1 do
        local j = blessing_rng:next(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local picked = {}
    for i = 1, math.min(3, #pool) do
        picked[#picked + 1] = pool[i]
    end

    s.offered_blessings = picked
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
    if s.cleanup_phase then
        for i = 1, n do
            s.plants[i].bloom = 100.0
        end
        s.bloom = 100.0
        s._synced_bloom = 100.0
        return 100.0
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
                local w = (p.growth_tempo or 1.0) * (i == focus_idx and 1.65 or 1.0)
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
                local w = (p.growth_tempo or 1.0) * (i == focus_idx and 1.65 or 1.0)
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

---Adds bonus Bloom normalized by `1 / (level ^ 0.35)` so active skill stays impactful on higher levels.
---@param base_amount number Base Bloom bonus on Level 1
---@param focus_pos? table Optional world position of the reaction to favor the nearest chamber's sprout
---@return number added Actual Bloom percentage added
function tc_core.add_scaled_bloom(base_amount, focus_pos)
    local lvl = math.max(1, tc_core.state.level or 1)
    local scaled = base_amount / (lvl ^ 0.35)
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
    if pos_brim.x ~= pos_ice.x or pos_brim.y ~= pos_ice.y or pos_brim.z ~= pos_ice.z then
        core.set_node(pos_brim, {name = "tc_elements:steam"})
    end
    local above = {x = pos_ice.x, y = pos_ice.y + 1, z = pos_ice.z}
    if core.get_node(above).name == "air" then
        core.set_node(above, {name = "tc_elements:steam"})
    end
    core.sound_play("tc_steam", {pos = pos_ice, gain = 0.65, max_hear_distance = 22}, true)
    spawn_reaction_particles(pos_ice, "thermal_cancel")
    local base_b = tc_core.has_blessing("prismatic_catalyst") and 3.75 or 3.0
    local gain = tc_core.add_scaled_bloom(base_b, pos_ice)
    tc_core.push_action_feedback_all({
        kind = "action",
        icon = "tc_steam.png",
        bloom = gain,
        label = S("★ Nice Combo! Brimstone + Ice"),
        color = P.hud_aqua,
        accent_hex = P.aqua,
        ttl = 2.6,
    })
end

---Executes an Acid Slime + Alkaline Chalk Transmutation (+3.5% scaled Bloom, 2 Fertile Speed Soil tiles).
---@param pos_acid table
---@param pos_chalk table
function tc_core.exec_acid_base(pos_acid, pos_chalk)
    tc_core.credit_reagent_placer(pos_acid, pos_chalk, 2)
    if pos_chalk.x ~= pos_acid.x or pos_chalk.y ~= pos_acid.y or pos_chalk.z ~= pos_acid.z then
        core.remove_node(pos_chalk)
    end
    core.set_node(pos_acid, {name = "tc_elements:steam"})
    tc_elements.enrich_soil_at(pos_acid)
    if pos_acid.x == pos_chalk.x and pos_acid.z == pos_chalk.z then
        for i = 1, 4 do
            local d = REACT_DIRS[i]
            if tc_elements.enrich_soil_at({x = pos_acid.x + d.x, y = 0, z = pos_acid.z + d.z}) then
                break
            end
        end
    else
        tc_elements.enrich_soil_at(pos_chalk)
    end
    core.sound_play("tc_transmute", {pos = pos_acid, gain = 0.8, max_hear_distance = 22}, true)
    spawn_reaction_particles(pos_acid, "acid_base")
    local base_b = tc_core.has_blessing("prismatic_catalyst") and 4.375 or 3.5
    local gain = tc_core.add_scaled_bloom(base_b, pos_acid)
    tc_core.push_action_feedback_all({
        kind = "action",
        icon = "tc_fertile_loam.png",
        bloom = gain,
        label = S("★ Nice Combo! Acid + Chalk"),
        color = P.hud_emerald,
        accent_hex = P.emerald,
        ttl = 2.6,
    })
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

-- Consolidates active timed speed effects into a single non-stacking `tc_core:boost_speed` branch
-- so green Fertile Soil highways stay controllable and never multiply with other timed buffs.
sync_player_boost_speed = function(player)
    local name = player:get_player_name()
    local effs = player_effects[name]
    local desired = 1.0
    if effs then
        if (effs.reconstitution or 0) > 0 then
            desired = 0.65
        else
            local has_boots = tc_core.has_blessing("hermetic_boots")
            for i = 1, #tc_core.EFFECT_ORDER do
                local eff_id = tc_core.EFFECT_ORDER[i]
                if (effs[eff_id] or 0) > 0 then
                    local spd = tc_core.EFFECT_DEFS[eff_id].speed
                    if eff_id == "fertile_stride" and has_boots then
                        spd = 1.70
                    end
                    if spd and spd > desired then
                        desired = spd
                    end
                end
            end
        end
    end

    local prev = player_boost_spd_cache[name] or 1.0
    if desired == 1.0 then
        if prev ~= 1.0 then
            player_boost_spd_cache[name] = 1.0
            player_monoids.speed:del_change(player, "tc_core:boost_speed")
        end
    elseif math.abs(prev - desired) > 0.001 then
        player_boost_spd_cache[name] = desired
        player_monoids.speed:add_change(player, desired, "tc_core:boost_speed")
    end
end

sync_player_fov = function(player, force_instant)
    local name = player:get_player_name()
    local effs = player_effects[name]
    local reconstituting = effs ~= nil and (effs.reconstitution or 0) > 0
    local desired = 0
    if effs and not reconstituting then
        if (effs.fertile_stride or 0) > 0 and tc_core.has_blessing("hermetic_boots") then
            desired = 1.10
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

---Updates Luanti 5.18 atmospheric presets (skybox, static light_curve, ao_gamma & bloom) on state transition.
---@param player ObjectRef
function tc_core.sync_player_atmosphere(player)
    local name = player:get_player_name()
    local s = tc_core.state
    local mode = "normal"
    if (s.overload_timer or 0) > 0 then
        mode = "overload"
    elseif s.stasis_timer > 0 then
        mode = "stasis"
    elseif tc_core.has_effect(player, "harmonic_overdrive") then
        mode = "overdrive"
    end

    if player_light_cache[name] == mode then
        return
    end
    player_light_cache[name] = mode
    player:set_sky(tc_assets.SKY_PRESETS[mode] or tc_assets.SKY_PRESETS.normal)
    player:set_lighting(tc_assets.LIGHTING_PRESETS[mode] or tc_assets.LIGHTING_PRESETS.normal)
end

---Applies or refreshes a timed boost effect on a player using player_monoids.
---Only invokes monoid add_change on activation transition to prevent redundant physics packets.
---@param player ObjectRef
---@param effect_id string
---@param duration number Duration in seconds
---@param defer_hud? boolean When true, skips immediate hudbar sync (used for coalesced step ticks)
function tc_core.apply_effect(player, effect_id, duration, defer_hud)
    if not player or not player:is_player() or duration <= 0 then
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
    local maxs = player_effect_max[name]
    if not maxs then
        maxs = {}
        player_effect_max[name] = maxs
    end

    local existing = effs[effect_id] or 0
    local new_rem = math.max(existing, duration)
    effs[effect_id] = new_rem
    if existing <= 0 or new_rem > (maxs[effect_id] or 0) then
        maxs[effect_id] = new_rem
    end

    if existing <= 0 then
        local monoid_key = "tc_core:" .. effect_id
        if def.speed then
            sync_player_boost_speed(player)
        end
        if def.jump then
            player_monoids.jump:add_change(player, def.jump, monoid_key)
        end
        if def.gravity then
            player_monoids.gravity:add_change(player, def.gravity, monoid_key)
        end
        sync_player_fov(player)
    end

    if not defer_hud then
        tc_core.sync_player_effect_hudbars(player)
    end
end

---Removes a timed boost effect from a player and restores their monoid branch.
---@param player ObjectRef
---@param effect_id string
---@param defer_hud? boolean When true, skips immediate hudbar sync (used for coalesced step ticks)
function tc_core.remove_effect(player, effect_id, defer_hud)
    if not player or not player:is_player() then
        return
    end
    local def = tc_core.EFFECT_DEFS[effect_id]
    if not def then
        return
    end

    local name = player:get_player_name()
    local effs = player_effects[name]
    local maxs = player_effect_max[name]
    local was_active = effs and (effs[effect_id] or 0) > 0
    if effs then
        effs[effect_id] = nil
    end
    if maxs then
        maxs[effect_id] = nil
    end

    if was_active then
        local monoid_key = "tc_core:" .. effect_id
        if def.speed then
            sync_player_boost_speed(player)
        end
        if def.jump then
            player_monoids.jump:del_change(player, monoid_key)
        end
        if def.gravity then
            player_monoids.gravity:del_change(player, monoid_key)
        end
        sync_player_fov(player)
        if not defer_hud then
            tc_core.sync_player_effect_hudbars(player)
        end
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

---Returns the remaining seconds and peak duration for a player's boost effect without heap allocations.
---@param player ObjectRef
---@param effect_id string
---@return number rem, number max_dur
function tc_core.get_effect_state(player, effect_id)
    if not player or not player:is_player() then
        return 0, 0
    end
    local name = player:get_player_name()
    local effs = player_effects[name]
    local rem = effs and effs[effect_id] or 0
    if rem <= 0 then
        return 0, 0
    end
    local maxs = player_effect_max[name]
    local max_dur = maxs and maxs[effect_id] or rem
    if max_dur < rem then
        max_dur = rem
    end
    return rem, max_dur
end

---Clears all active boost effects from a player and synchronizes FOV and hudbars in a single coalesced update.
---@param player ObjectRef
---@param instant_fov? boolean When true, resets any active FOV override instantaneously (transition_time = 0)
function tc_core.clear_player_effects(player, instant_fov)
    if not player or not player:is_player() then
        return
    end
    local name = player:get_player_name()
    local effs = player_effects[name]
    local maxs = player_effect_max[name]
    if not effs then
        sync_player_boost_speed(player)
        sync_player_fov(player, instant_fov == true)
        tc_core.sync_player_effect_hudbars(player)
        if instant_fov then
            tc_core.clear_player_hud_transients(player)
        end
        return
    end
    local had_any = false
    for i = 1, #tc_core.EFFECT_ORDER do
        local eff_id = tc_core.EFFECT_ORDER[i]
        if (effs[eff_id] or 0) > 0 then
            effs[eff_id] = nil
            if maxs then
                maxs[eff_id] = nil
            end
            local def = tc_core.EFFECT_DEFS[eff_id]
            local monoid_key = "tc_core:" .. eff_id
            if def.jump then
                player_monoids.jump:del_change(player, monoid_key)
            end
            if def.gravity then
                player_monoids.gravity:del_change(player, monoid_key)
            end
            had_any = true
        end
    end
    sync_player_boost_speed(player)
    if had_any or instant_fov then
        sync_player_fov(player, instant_fov == true)
    end
    tc_core.sync_player_effect_hudbars(player)
    if instant_fov then
        tc_core.clear_player_hud_transients(player)
    end
end

local function sample_player_nodes(ppos)
    sample_foot_pos.x = math.floor(ppos.x + 0.5)
    sample_foot_pos.y = math.floor(ppos.y - 0.1)
    sample_foot_pos.z = math.floor(ppos.z + 0.5)

    sample_body_pos.x = sample_foot_pos.x
    sample_body_pos.y = math.floor(ppos.y + 0.5)
    sample_body_pos.z = sample_foot_pos.z

    return core.get_node(sample_foot_pos).name, core.get_node(sample_body_pos).name
end

---Ticks all player timed effects, checks environmental boost pads, and syncs live effect hudbars & HUD timers.
---@param dt number Elapsed step time
function tc_core.step_player_effects(dt)
    local s = tc_core.state
    local drop_expired = false
    if s.active_drop then
        s.active_drop.ttl = s.active_drop.ttl - dt
        if s.active_drop.ttl <= 0 then
            s.active_drop = nil
            drop_expired = true
        end
    end

    local players = core.get_connected_players()
    if #players == 0 then
        return
    end

    local is_running = s.running
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
                        tc_core.remove_effect(player, eff_id, true)
                    else
                        effs[eff_id] = new_rem
                    end
                end
            end
        end

        if is_running then
            local foot_node, body_node = sample_player_nodes(player:get_pos())
            if foot_node == "tc_elements:fertile_loam" then
                tc_core.apply_effect(player, "fertile_stride", 3.5, true)
            end
            if body_node == "tc_elements:steam" or foot_node == "tc_elements:steam" then
                tc_core.apply_effect(player, "steam_updraft", 5.0, true)
            end
        end

        tc_core.sync_player_atmosphere(player)
        tc_core.sync_player_effect_hudbars(player)
        if drop_expired then
            tc_core.sync_player_drop_hud(player)
        end
        tc_core.step_hud_timers(player, dt)
    end
end

---Deals garden hazard damage to a player unless protected by Aegis Shield or post-respawn Recovering grace.
---@param player ObjectRef
---@param amount integer Raw damage in HP points
---@param source? string Optional hazard identifier ("brimstone", "acid_slime", "falling_block")
---@return boolean dealt True when damage was applied (or absorbed by Auto-Aegis)
function tc_core.damage_player(player, amount, source)
    if not tc_core.state.running or not player or not player:is_player() or amount <= 0 then
        return false
    end
    local hp = player:get_hp()
    if hp <= 0 or tc_core.has_effect(player, "aegis_ward") or tc_core.has_effect(player, "reconstitution") then
        return false
    end
    player:set_hp(math.max(0, hp - amount), {type = "set_hp", tc_hazard = source or "hazard"})
    return true
end

---Evaluates 1.0s standing/wading hazard contact damage (Brimstone & Acid Slime) and Calm Balance player regen.
---@param in_harmony boolean Whether the terrarium is currently in full Equilibrium Harmony
function tc_core.step_player_hazards(in_harmony)
    if not tc_core.state.running then
        return
    end
    local players = core.get_connected_players()
    if #players == 0 then
        return
    end

    local PT = tc_assets.PARTICLES
    local heal_period = tc_core.has_blessing("sunlit_dew") and 3 or 5
    local heal_amt = tc_core.has_blessing("sunlit_dew") and 2 or 1

    for i = 1, #players do
        local player = players[i]
        local hp = player:get_hp()
        if hp > 0 then
            local pname = player:get_player_name()
            local ppos = player:get_pos()
            local foot_node, body_node = sample_player_nodes(ppos)

            if foot_node == "tc_elements:brimstone" then
                player_harmony_heal_ticks[pname] = 0
                if tc_core.damage_player(player, 2, "brimstone") then
                    core.sound_play("tc_sizzle", {pos = ppos, gain = 0.55, max_hear_distance = 14}, true)
                    tc_assets.spawn_sheet_particles({
                        amount = 8,
                        time = 0.15,
                        minpos = {x = ppos.x - 0.25, y = ppos.y - 0.05, z = ppos.z - 0.25},
                        maxpos = {x = ppos.x + 0.25, y = ppos.y + 0.35, z = ppos.z + 0.25},
                        minvel = {x = -0.7, y = 0.8, z = -0.7},
                        maxvel = {x = 0.7, y = 2.0, z = 0.7},
                        minexptime = 0.30,
                        maxexptime = 0.65,
                        minsize = 1.1,
                        maxsize = 2.2,
                        glow = 13,
                        texpool = {
                            tc_assets.make_sheet_tex_entry(PT.ember, {scale_tween = {1.2, 0.35}}),
                        },
                    })
                    tc_tools.send_hint(
                        player,
                        "hazard_brimstone",
                        S("Hot Brimstone! Step off & splash with Flask [3]."),
                        "tc_tool_flask_water.png"
                    )
                end
            elseif body_node == "tc_elements:acid_slime" or foot_node == "tc_elements:acid_slime" then
                player_harmony_heal_ticks[pname] = 0
                if tc_core.damage_player(player, 2, "acid_slime") then
                    core.sound_play("tc_water_splash", {pos = ppos, gain = 0.45, max_hear_distance = 14}, true)
                    tc_assets.spawn_sheet_particles({
                        amount = 8,
                        time = 0.15,
                        minpos = {x = ppos.x - 0.28, y = ppos.y - 0.05, z = ppos.z - 0.28},
                        maxpos = {x = ppos.x + 0.28, y = ppos.y + 0.35, z = ppos.z + 0.28},
                        minvel = {x = -0.6, y = 0.6, z = -0.6},
                        maxvel = {x = 0.6, y = 1.6, z = 0.6},
                        minexptime = 0.30,
                        maxexptime = 0.65,
                        minsize = 1.1,
                        maxsize = 2.1,
                        glow = 12,
                        texpool = {
                            tc_assets.make_sheet_tex_entry(PT.pollen, {scale_tween = {1.2, 0.4}}),
                        },
                    })
                    tc_tools.send_hint(
                        player,
                        "hazard_acid",
                        S("Stinging Acid! Step out & sweep with Pestle [4]."),
                        "tc_tool_pestle.png"
                    )
                end
            elseif in_harmony and hp < 20 then
                local ticks = (player_harmony_heal_ticks[pname] or 0) + 1
                if ticks >= heal_period then
                    player_harmony_heal_ticks[pname] = 0
                    player:set_hp(math.min(20, hp + heal_amt), {type = "set_hp", tc_regen = true})
                else
                    player_harmony_heal_ticks[pname] = ticks
                end
            else
                player_harmony_heal_ticks[pname] = 0
            end
        end
    end
end

-- ========================================================
-- POTION BELT CAPS, ALCHEMICAL OVERFLOW & SPECIAL ABILITIES
-- ========================================================

---Returns the Hotbar [6-7] Potion Belt carry cap for the given consumable itemstring.
---@param item_name string
---@return integer
function tc_core.get_potion_cap(item_name)
    if item_name == "tc_tools:elixir_aegis" then
        return tc_core.has_blessing("sunlit_dew") and 3 or 2
    elseif item_name == "tc_tools:chronos_sandglass" then
        return 2
    end
    return 2
end

---Counts total items matching `item_name` across a player's `main` inventory list.
---@param player ObjectRef
---@param item_name string
---@return integer
function tc_core.count_player_item(player, item_name)
    if not player or not player:is_player() then
        return 0
    end
    local inv = player:get_inventory()
    local list = inv and inv:get_list("main") or nil
    if not list then
        return 0
    end
    local total = 0
    for i = 1, #list do
        local st = list[i]
        if st:get_name() == item_name then
            total = total + st:get_count()
        end
    end
    return total
end

---Grants up to the Hotbar [6-7] Potion Belt cap for `item_name`, converting any excess into
---Zero-Waste Alchemical Overflow (+1.5% scaled Bloom, +6 Player HP, & +15% Plant HP per overflow item).
---@param player ObjectRef
---@param item_name string
---@param count? integer
---@return integer added_count, integer overflow_count, number overflow_bloom
function tc_core.grant_potion(player, item_name, count)
    if not player or not player:is_player() then
        return 0, 0, 0.0
    end
    count = math.max(1, math.floor(count or 1))
    local cap = tc_core.get_potion_cap(item_name)
    local held = tc_core.count_player_item(player, item_name)
    local to_add = math.max(0, math.min(count, cap - held))
    local overflow = count - to_add

    local inv = player:get_inventory()
    for _ = 1, to_add do
        inv:add_item("main", item_name)
    end

    local overflow_bloom = 0.0
    if overflow > 0 and tc_core.state.running then
        overflow_bloom = tc_core.add_scaled_bloom(1.5 * overflow, player:get_pos())
        local hp = player:get_hp()
        if hp > 0 and hp < 20 then
            player:set_hp(math.min(20, hp + 6 * overflow), {type = "set_hp", tc_overflow = true})
        end
        local plants = tc_core.state.plants
        for i = 1, #plants do
            local p = plants[i]
            if not p.withered and p.vitality < 100.0 then
                p.vitality = math.min(100.0, p.vitality + 15.0 * overflow)
            end
        end
    end

    return to_add, overflow, overflow_bloom
end

local UNIQUE_CORE_TOOLS = {
    ["tc_tools:trowel"] = "trowel",
    ["tc_tools:bellows"] = "bellows",
    ["tc_tools:bellows_empty"] = "bellows",
    ["tc_tools:condenser_flask"] = "flask",
    ["tc_tools:condenser_flask_full"] = "flask",
    ["tc_tools:chalk_pestle"] = "pestle",
    ["tc_tools:chalk_pestle_empty"] = "pestle",
    ["tc_tools:guide_tome"] = "guide",
}

local POTION_ITEMS = {
    ["tc_tools:elixir_aegis"] = true,
    ["tc_tools:chronos_sandglass"] = true,
}

---Sanitizes a reconnecting player's inventory by stripping invalid/legacy items and clamping stacks to current caps.
---@param player ObjectRef
function tc_core.sanitize_player_inventory(player)
    if not player or not player:is_player() then
        return
    end
    local inv = player:get_inventory()
    inv:set_list("craft", {})
    local list = inv:get_list("main")
    if list then
        local seen_tools = {}
        local potion_totals = {}
        local max_bellows = tc_tools.get_max_bellows_charges()
        local max_flask = tc_tools.get_max_flask_charges()
        local max_pestle = tc_tools.get_max_pestle_charges()
        for slot = 1, #list do
            local st = list[slot]
            local sname = st:get_name()
            local tkey = UNIQUE_CORE_TOOLS[sname]
            if sname == "" or st:is_empty() then
                list[slot] = ItemStack("")
            elseif tkey then
                if seen_tools[tkey] then
                    list[slot] = ItemStack("")
                else
                    seen_tools[tkey] = true
                    if sname == "tc_tools:bellows" then
                        local clamped = math.min(max_bellows, tc_tools.get_bellows_charges(st))
                        list[slot] = tc_tools.set_bellows_charges(st, clamped)
                    elseif sname == "tc_tools:condenser_flask_full" then
                        local clamped = math.min(max_flask, tc_tools.get_flask_charges(st))
                        list[slot] = tc_tools.set_flask_charges(st, clamped)
                    elseif sname == "tc_tools:chalk_pestle" then
                        local clamped = math.min(max_pestle, tc_tools.get_pestle_charges(st))
                        list[slot] = tc_tools.set_pestle_charges(st, clamped)
                    elseif sname == "tc_tools:trowel" and not tc_core.state.running then
                        list[slot] = tc_tools.set_trowel_cargo(st, "")
                    end
                end
            elseif POTION_ITEMS[sname] then
                local cap = tc_core.get_potion_cap(sname)
                local used = potion_totals[sname] or 0
                local keep = math.min(st:get_count(), math.max(0, cap - used), 3)
                if keep <= 0 then
                    list[slot] = ItemStack("")
                else
                    st:set_count(keep)
                    list[slot] = st
                    potion_totals[sname] = used + keep
                end
            else
                list[slot] = ItemStack("")
            end
        end
        inv:set_list("main", list)
    end
    tc_init.equip_player(player, false)
end

---Equips or sanitizes a connecting player's inventory so stale items from prior sessions/runs never leak into a run.
---@param player ObjectRef
function tc_core.sync_joining_player(player)
    if not player or not player:is_player() then
        return
    end
    local s = tc_core.state
    local name = player:get_player_name()
    local pstat = tc_core.player_stats[name]

    if not pstat or pstat.run_id ~= s.run_id or s.defeat then
        tc_core.player_stats[name] = {
            neutralized = 0,
            downed_until = 0,
            run_id = s.run_id,
        }
        tc_init.equip_player(player, true)
        if s.level > 1 and not s.defeat then
            local has_dew = tc_core.has_blessing("sunlit_dew")
            tc_core.grant_potion(player, "tc_tools:elixir_aegis", has_dew and 2 or 1)
            tc_core.grant_potion(player, "tc_tools:chronos_sandglass", 1)
        end
        sync_blessing_equipment(player, true)
    else
        pstat.downed_until = 0
        tc_core.sanitize_player_inventory(player)
        sync_blessing_equipment(player, false)
    end
end

---Records hazard neutralizations by a player for run statistics and Top 10 leaderboard rankings.
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
    pstat.neutralized = pstat.neutralized + count
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

            local who = (user and user:is_player()) and user:get_player_name() or S("Calm Balance")
            if was_withered then
                tc_core.push_hud_event({
                    priority = 2,
                    icon = string.format("tc_crucible_sprout_%d.png", p.stage or 1),
                    title = S("✦ Sprout #@1 Revived!", p.index),
                    detail = S("@1 restored @2% Plant HP", who, string.format("%.0f", p.vitality)),
                    color = P.hud_emerald,
                    accent_hex = P.emerald,
                    ttl = 3.2,
                })
            elseif user and user:is_player() then
                tc_core.push_action_feedback(user, {
                    kind = "hint",
                    icon = "tc_tool_flask_water.png",
                    text = S("Watered Sprout #@1 (@2% HP)", p.index, string.format("%.0f", p.vitality)),
                    color = P.hud_emerald,
                    accent_hex = P.emerald,
                    ttl = 2.2,
                })
            end
            return true
        end
    end
    return false
end

---Activates the Aegis Ward Tincture (heals user, revives withered sprouts, shields user & plants for duration).
---@param user ObjectRef
---@param duration? number
function tc_core.activate_aegis_ward(user, duration)
    local dur = duration or (tc_core.has_blessing("sunlit_dew") and 14.0 or 12.0)
    local s = tc_core.state
    s.aegis_timer = math.max(s.aegis_timer, dur)
    user:set_hp(20, {type = "set_hp", tc_aegis = true})
    tc_core.apply_effect(user, "aegis_ward", dur)

    for i = 1, #s.plants do
        local p = s.plants[i]
        if p.withered then
            tc_core.revive_sprout_at(p.pos, user, 50.0)
        else
            p.vitality = math.min(100.0, p.vitality + 25.0)
        end
    end

    tc_core.push_hud_event({
        priority = 2,
        icon = "tc_elixir_aegis.png",
        title = S("✦ Aegis Shield (@1s)!", math.ceil(dur)),
        detail = S("@1 healed & shielded all plants!", user:get_player_name()),
        color = P.hud_gold,
        accent_hex = P.gold,
        ttl = 3.8,
    })
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
            local hpos = hazards[1]
            core.remove_node(hpos)
            spawn_reaction_particles(hpos, "acid_base")
            cleared = cleared + 1
        end
    end

    local who = (user and user:is_player()) and user:get_player_name() or S("Alchemist")
    tc_core.push_hud_event({
        priority = 2,
        icon = "tc_chronos_sandglass.png",
        title = S("✦ Time Frozen (@1s)!", math.ceil(duration)),
        detail = S("@1 paused drops · @2 cleared", who, cleared),
        color = P.hud_violet,
        accent_hex = P.violet,
        ttl = 3.8,
    })
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
        local ra = a.retries or 0
        local rb = b.retries or 0
        if ra ~= rb then
            return ra < rb
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
---@param retries? integer
function tc_core.record_player_score(
    player_name, level_reached, levels_cleared, bloom_pct, neutralized, seconds, retries
)
    if not player_name or player_name == "" then
        return
    end
    local ret_cnt = math.max(0, math.floor(retries or 0))
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
            retries = ret_cnt,
            neutralized = neutralized,
            best_time = math.max(1, seconds),
        }
        entries[#entries + 1] = found
    else
        local prev_clr = found.levels_cleared or 0
        local prev_lvl = found.highest_level or 1
        local prev_bloom = found.max_bloom or 0
        local prev_ret = found.retries or 0
        local prev_neut = found.neutralized or 0
        local prev_time = found.best_time or 999999
        local clamped_sec = math.max(1, seconds)

        local is_better = false
        if levels_cleared > prev_clr then
            is_better = true
        elseif levels_cleared == prev_clr then
            if level_reached > prev_lvl then
                is_better = true
            elseif level_reached == prev_lvl then
                if bloom_pct > prev_bloom + 0.05 then
                    is_better = true
                elseif math.abs(bloom_pct - prev_bloom) <= 0.05 then
                    if ret_cnt < prev_ret then
                        is_better = true
                    elseif ret_cnt == prev_ret then
                        if neutralized > prev_neut then
                            is_better = true
                        elseif neutralized == prev_neut and clamped_sec < prev_time then
                            is_better = true
                        end
                    end
                end
            end
        end

        if is_better then
            found.highest_level = level_reached
            found.levels_cleared = levels_cleared
            found.max_bloom = bloom_pct
            found.retries = ret_cnt
            found.neutralized = neutralized
            found.best_time = clamped_sec
        elseif levels_cleared == prev_clr
                and level_reached == prev_lvl
                and ret_cnt == prev_ret
                and neutralized > prev_neut then
            found.neutralized = neutralized
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
            s.run_seconds,
            s.retries or 0
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

---Builds a WCAG AA-accessible Formspec v12 table displaying the Top 10 Alchemists.
---@param x number Formspec X position
---@param y number Formspec Y position
---@param w number Formspec width
---@param h number Formspec height
---@return string
function tc_core.build_top10_table_formspec(x, y, w, h)
    local top = tc_core.get_top10()
    local esc = core.formspec_escape
    local rows = {
        table.concat({
            P.gold,
            esc(S("Rank")),
            esc(S("Player")),
            esc(S("Highest Level")),
            esc(S("Levels Won")),
            esc(S("Best Bloom")),
            esc(S("Retries")),
            esc(S("Cleared")),
            esc(S("Time")),
        }, ","),
    }

    if #top == 0 then
        rows[#rows + 1] = table.concat({
            P.text_secondary,
            "-",
            esc(S("(No scores saved yet — finish or reset a level to record!)")),
            "-", "-", "-", "-", "-", "-",
        }, ",")
    else
        for i = 1, #top do
            local e = top[i]
            local color = (i == 1 and P.gold)
                or (i == 2 and P.aqua)
                or (i == 3 and P.amber)
                or P.text_primary
            local hl = e.highest_level or 1
            local lvl_cell = (hl == 1)
                and S("Level @1 (@2 Room)", hl, hl)
                or S("Level @1 (@2 Rooms)", hl, hl)
            rows[#rows + 1] = string.format(
                "%s,#%d,%s,%s,%d,%.0f%%,%d,%d,%s",
                color,
                i,
                esc(e.name),
                esc(lvl_cell),
                e.levels_cleared or 0,
                e.max_bloom or 0,
                e.retries or 0,
                e.neutralized or 0,
                esc(S("@1s", e.best_time or 0))
            )
        end
    end

    local opts = "tableoptions[background=" .. P.bg_inset .. ";highlight=#352854;border=true]"
    local cols = "tablecolumns[color;text,align=center;text,align=left;text,align=center;" ..
        "text,align=center;text,align=center;text,align=center;text,align=center;text,align=right]"
    return string.format(
        "%s%stable[%.2f,%.2f;%.2f,%.2f;tbl_top10;%s;1]",
        opts, cols, x, y, w, h, table.concat(rows, ",")
    )
end

---Builds a concise 1-line copyable run summary string for Luanti 5.18 `editable=false` formspec fields.
---@param player? ObjectRef
---@return string
function tc_core.build_run_receipt(player)
    local s = tc_core.state
    local pname = (player and player:is_player()) and player:get_player_name() or ""
    local pstat = (pname ~= "" and tc_core.player_stats[pname]) or {neutralized = 0}
    local diff_label = (s.difficulty == "casual" and S("Casual"))
        or (s.difficulty == "panic" and S("Panic"))
        or S("Normal")

    local cleared_lvls = s.victory and s.level or math.max(0, (s.level or 1) - 1)
    local bloom_str = string.format("%.1f", s.victory and 100.0 or (s.bloom or 0.0))
    local who = (pname ~= "") and pname or S("Alchemist")
    local raw = S(
        "Terrarium Crucible · @1 · Lv@2 (@3 Won) · @4% Bloom · @5 Retries · @6 Cleared · @7s [@8]",
        who,
        s.level or 1,
        cleared_lvls,
        bloom_str,
        s.retries or 0,
        pstat.neutralized or 0,
        s.run_seconds or 0,
        diff_label
    )
    return tc_core.resolve_player_text(pname, raw)
end

-- ========================================================
-- LEVEL MANAGEMENT & RESET
-- ========================================================

---Starts or expands the terrarium to the target level (`level` cubes, `level` plants).
---@param level integer Target level (1..N)
---@param preserve_fertile? boolean Preserve existing fertile_loam speed highways
---@param is_retry? boolean Whether this call restores the Level-Start checkpoint for `level`
function tc_core.start_level(level, preserve_fertile, is_retry)
    level = math.max(1, math.floor(level or 1))
    local s = tc_core.state
    local cp = (is_retry and level > 1 and s.level_checkpoint and s.level_checkpoint.level == level)
        and s.level_checkpoint
        or nil

    s.running = true
    s.epoch = (s.epoch or 0) + 1
    s.victory = false
    s.defeat = false
    s.defeat_reason = ""
    s.defeat_kind = nil
    s.level = level
    s.bloom = 0.0
    s._synced_bloom = 0.0
    s.temperature = 50.0
    s.ph = 50.0
    s.seconds_elapsed = 0
    s.offered_blessings = {}
    s.next_wave = nil
    s.active_drop = nil
    s.climax_triggered = false
    s.cleanup_phase = false
    s.falling_hazards = 0
    s.carried_hazards = 0
    s.remaining_hazards = 0
    s.cleanup_icons = {}
    if level == 1 then
        s.run_id = (s.run_id or 0) + 1
        s.run_seconds = 0
        s.retries = 0
        s.level_checkpoint = nil
        s.reagents_dropped = 0
        s.peak_harmony = 0
        s.trial_cursor = 0
        s.active_blessing = nil
        s.prev_blessing = nil
        s.pending_blessing = nil
        s.blessing_chooser = nil
        reagent_bag = {}
        tc_core.player_stats = {}
    elseif cp then
        s.active_blessing = cp.active_blessing
        s.prev_blessing = cp.prev_blessing
        s.pending_blessing = nil
        s.blessing_chooser = nil
        s.trial_cursor = cp.trial_cursor or 0
        s.reagents_dropped = cp.reagents_dropped or 0
        s.peak_harmony = cp.peak_harmony or 0
        reagent_bag = {}
    else
        if s.pending_blessing ~= nil then
            if s.active_blessing ~= nil then
                s.prev_blessing = s.active_blessing
            end
            s.active_blessing = s.pending_blessing
            s.pending_blessing = nil
        else
            s.prev_blessing = s.active_blessing
            s.active_blessing = nil
        end
    end
    s.wave = 0
    s.drop_timer = (level == 1) and 4.0 or (tc_core.has_blessing("featherfall_canopy") and 7.0 or 5.5)
    s.harmony_streak = 0
    s.aegis_timer = 0.0
    s.stasis_timer = 0.0
    s.active_reagents = 0
    s.max_reagents = 6 + (5 * level)
    s.overload_timer = 0
    s.turbulent = false

    tc_core.clear_all_waypoints()

    -- Build or expand the open-top cubic terrarium & workshop diorama
    tc_world.build_level(level, (not is_retry) and preserve_fertile or false)
    if cp and cp.fertile_coords then
        local fcoords = cp.fertile_coords
        for i = 1, #fcoords do
            local fp = fcoords[i]
            if core.get_node(fp).name == "tc_elements:loam" then
                core.swap_node(fp, {name = "tc_elements:fertile_loam"})
            end
        end
    end

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
            local jitter = blessing_rng:next(-25, 25) / 1000.0
            tempos[i] = tc_core.clamp(base + jitter, 0.80, 1.22)
        end
        for i = n_cells, 2, -1 do
            local j = blessing_rng:next(1, i)
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
    local has_dew = tc_core.has_blessing("sunlit_dew")
    local players = core.get_connected_players()
    for i = 1, #players do
        local p = players[i]
        local pname = p:get_player_name()
        tc_core.player_stats[pname] = tc_core.player_stats[pname] or {neutralized = 0, downed_until = 0}
        tc_core.player_stats[pname].downed_until = 0
        tc_core.player_stats[pname].run_id = s.run_id
        player_harmony_heal_ticks[pname] = 0

        if level == 1 then
            x_player_api.stop_emote(p)
            tc_core.set_player_sprinting(p, false)
            tc_core.clear_player_effects(p, true)
            tc_init.equip_player(p, true)
            p:set_pos(tc_init.SPAWN_POS)
        elseif is_retry then
            local cp_p = cp and cp.players and cp.players[pname] or nil
            if cp_p then
                tc_core.player_stats[pname].neutralized = cp_p.neutralized or 0
            end
            x_player_api.stop_emote(p)
            tc_core.set_player_sprinting(p, false)
            tc_core.clear_player_effects(p, true)
            tc_init.equip_player(p, true)
            local aegis_cnt = cp_p and cp_p.aegis or (has_dew and 2 or 1)
            local chronos_cnt = cp_p and cp_p.chronos or 1
            local max_aegis = tc_core.get_potion_cap("tc_tools:elixir_aegis")
            local max_chronos = tc_core.get_potion_cap("tc_tools:chronos_sandglass")
            aegis_cnt = math.min(aegis_cnt, max_aegis)
            chronos_cnt = math.min(chronos_cnt, max_chronos)
            if aegis_cnt > 0 then
                tc_core.grant_potion(p, "tc_tools:elixir_aegis", aegis_cnt)
            end
            if chronos_cnt > 0 then
                tc_core.grant_potion(p, "tc_tools:chronos_sandglass", chronos_cnt)
            end
            p:set_pos(tc_init.SPAWN_POS)
        else
            tc_tools.clear_player_trowels(p)
            tc_init.equip_player(p, false)
            tc_tools.refill_player_tools(p)
            tc_core.grant_potion(p, "tc_tools:elixir_aegis", has_dew and 2 or 1)
            tc_core.grant_potion(p, "tc_tools:chronos_sandglass", 1)
        end
    end
    sync_blessing_equipment()

    if level > 1 and not is_retry then
        local bbox = tc_world.get_bounding_box(level)
        local fertile_positions = core.find_nodes_in_area(
            {x = bbox.min_x, y = 0, z = bbox.min_z},
            {x = bbox.max_x, y = 0, z = bbox.max_z},
            {"tc_elements:fertile_loam"}
        )
        local cp_fertile = {}
        for i = 1, #fertile_positions do
            local fp = fertile_positions[i]
            cp_fertile[i] = {x = fp.x, y = fp.y, z = fp.z}
        end
        local cp_players = {}
        for pname, pstat in pairs(tc_core.player_stats) do
            cp_players[pname] = {
                neutralized = pstat.neutralized or 0,
                aegis = has_dew and 2 or 1,
                chronos = 1,
            }
        end
        for i = 1, #players do
            local p = players[i]
            local pname = p:get_player_name()
            local pstat = tc_core.player_stats[pname]
            cp_players[pname] = {
                neutralized = pstat and pstat.neutralized or 0,
                aegis = tc_core.count_player_item(p, "tc_tools:elixir_aegis"),
                chronos = tc_core.count_player_item(p, "tc_tools:chronos_sandglass"),
            }
        end
        s.level_checkpoint = {
            level = level,
            active_blessing = s.active_blessing,
            prev_blessing = s.prev_blessing,
            trial_cursor = s.trial_cursor,
            reagents_dropped = s.reagents_dropped,
            peak_harmony = s.peak_harmony,
            fertile_coords = cp_fertile,
            players = cp_players,
        }
    end

    tc_core.roll_next_wave(#players)

    if level > 1 then
        local b_def = s.active_blessing and tc_core.BLESSING_DEFS[s.active_blessing] or nil
        if is_retry then
            s.blessing_chooser = nil
            local retry_detail = b_def
                and S("Blessing: @1 · Tools & Potions Restored!", b_def.title)
                or S("Garden Reset · Tools & Potions Restored!")
            tc_core.push_hud_event({
                priority = 2,
                icon = "tc_crucible_sprout_2.png",
                title = S("↻ Level @1 Retry #@2!", level, s.retries or 1),
                detail = retry_detail,
                color = P.hud_aqua,
                accent_hex = b_def and b_def.accent or P.aqua,
                ttl = 4.2,
            })
        else
            local chooser = s.blessing_chooser
            s.blessing_chooser = nil
            local has_cap_bonus = (level == 3 or level == 5 or level == 7)
            local supply_tag
            if has_dew and has_cap_bonus then
                supply_tag = S("+2 Aegis · +1 Hourglass · +1 Tool Cap!")
            elseif has_dew then
                supply_tag = S("+2 Aegis · +1 Hourglass")
            elseif has_cap_bonus then
                supply_tag = S("+1 Aegis · +1 Hourglass · +1 Tool Cap!")
            else
                supply_tag = S("+1 Aegis · +1 Hourglass")
            end
            local detail_str
            if b_def then
                if chooser and chooser ~= "" then
                    detail_str = S("@1 [@2] · @3", b_def.title, chooser, supply_tag)
                else
                    detail_str = S("Blessing: @1 · @2", b_def.title, supply_tag)
                end
            else
                detail_str = supply_tag
            end
            tc_core.push_hud_event({
                priority = 2,
                icon = "tc_crucible_sprout_2.png",
                title = S("★ LEVEL @1 BEGINS (@2 Rooms)", level, level),
                detail = detail_str,
                color = P.hud_gold,
                accent_hex = b_def and b_def.accent or P.gold,
                ttl = 4.5,
            })
        end
    end

    for i = 1, #players do
        tc_core.sync_player_atmosphere(players[i])
        tc_core.update_player_hud(players[i])
    end
end

---Retries the current level from its Level-Start checkpoint (or starts fresh if on Level 1),
---incrementing `state.retries` on Level 2+ and closing any open end-of-run dialogs.
function tc_core.retry_level()
    local s = tc_core.state
    local lvl = math.max(1, math.floor(s.level or 1))
    if lvl <= 1 then
        tc_core.reset_crucible()
        return
    end
    s.retries = (s.retries or 0) + 1
    tc_core.start_level(lvl, false, true)
    local players = core.get_connected_players()
    for i = 1, #players do
        local pname = players[i]:get_player_name()
        core.close_formspec(pname, "tc_core:victory")
        core.close_formspec(pname, "tc_core:defeat")
        core.close_formspec(pname, "tc_core:garden")
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
        core.close_formspec(pname, "tc_core:garden")
    end
end

---Triggers Defeat with a specific failure reason, records scores, and shows the Defeat dialog.
---@param reason string Explanation of why the run was lost
---@param defeat_kind? string Optional structured failure category ("overload" | "wilt" | "damage")
function tc_core.trigger_defeat(reason, defeat_kind)
    local s = tc_core.state
    if s.defeat or s.victory then
        return
    end
    s.defeat = true
    s.running = false
    s.overload_timer = 0
    s.active_drop = nil
    s.defeat_kind = defeat_kind
    s.defeat_reason = reason or S("The garden lost its balance!")

    tc_core.record_all_players(false)

    core.sound_play("tc_defeat", {gain = 1.0}, true)

    local players = core.get_connected_players()
    for i = 1, #players do
        local pl = players[i]
        tc_core.set_player_sprinting(pl, false)
        tc_core.clear_player_effects(pl, false)
        tc_core.sync_player_atmosphere(pl)
        tc_core.update_player_hud(pl)
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
                S("You ran out of health, and the shockwave wilted the last remaining plant!"),
                "damage"
            )
        else
            core.sound_play("tc_wither", {gain = 0.85}, true)
            tc_core.push_hud_event({
                priority = 3,
                icon = "tc_heart.png",
                title = S("✖ Second Chance!"),
                detail = S("Plants lost 30% HP — water them with Flask [3]!"),
                color = P.hud_coral,
                accent_hex = P.coral,
                ttl = 4.5,
            })
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
        tc_core.trigger_defeat(S("Everyone on the team ran out of health at the same time!"), "damage")
    else
        tc_core.push_hud_event({
            priority = 3,
            icon = "tc_icon_effect_debuff.png",
            title = S("⚠ @1 Knocked Down!", pname),
            detail = S("Teammates: stay safe for 5s while they recover!"),
            color = P.hud_amber,
            accent_hex = P.amber,
            ttl = 4.5,
        })
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
