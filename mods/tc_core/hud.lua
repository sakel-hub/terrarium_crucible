-- tc_core/hud.lua: Custom hudbars configuration and packet-deduplicated Mentor Telemetry HUD

local P = tc_assets.PALETTE

-- Override hudbars settings via its public hb table so mods/hudbars stays unmodified
hb.settings.bar_type = "progress_bar"
hb.settings.alignment_pattern = "stack_down"
hb.settings.pos_left = {x = 1, y = 0.24}
hb.settings.pos_right = {x = 1, y = 0.24}
hb.settings.start_offset_left = {x = -182, y = 0}
hb.settings.start_offset_right = {x = -182, y = 0}
hb.settings.vmargin = 26
hb.settings.forceload_default_hudbars = false
hb.settings.sorting = {}
hb.settings.sorting_reverse = {}
hb.registered_slots = {}

hb.register_hudbar(
    "bloom",
    P.hud_white,
    "Bloom",
    {bar = "tc_bar_bloom.png"},
    0,
    100,
    false,
    "@1: @2%",
    {order = {"label", "value"}, format_value = "%.1f"}
)

hb.register_hudbar(
    "vitality",
    P.hud_white,
    "Plant HP",
    {bar = "tc_bar_vitality.png"},
    100,
    100,
    false,
    "@1: @2%",
    {order = {"label", "value"}, format_value = "%d"}
)

hb.register_hudbar(
    "temperature",
    P.hud_white,
    "Heat",
    {bar = "tc_bar_temperature.png"},
    50,
    100,
    false,
    "@1: @2°C",
    {order = {"label", "value"}, format_value = "%d"}
)

hb.register_hudbar(
    "ph",
    P.hud_white,
    "Soil pH",
    {bar = "tc_bar_ph.png"},
    7,
    14,
    false,
    "@1: @2/@3",
    {order = {"label", "value", "max_value"}, format_value = "%.1f", format_max_value = "%d"}
)

-- Per-player HUD IDs and last-sent state to avoid redundant HUD network packets
local hud_cache = {}

core.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    hud_cache[name] = nil
    hb.players[name] = nil
end)

---Computes the contextual onboarding / counterplay prompt and AA color for the current crucible state.
---@return string text
---@return integer color_hex_int
local function compute_mentor_prompt()
    local s = tc_core.state

    if s.victory then
        return "▸ LEVEL COMPLETE! Pick an upgrade on screen or right-click the Control Altar!", P.hud_gold
    end
    if s.defeat then
        return "▸ RUN ENDED: Right-click the Control Altar anytime to start a fresh Level 1 garden.", P.hud_coral
    end

    if (s.overload_timer or 0) > 0 then
        local rem = math.max(1, 8 - s.overload_timer)
        local excess = math.max(1, s.active_reagents - s.max_reagents)
        return string.format(
            "▸ ✖ TOO MANY BLOCKS (%ds LEFT)! Clear %d hazard(s) now with Tools [1–4] or Chronos Hourglass!",
            rem, excess
        ), P.hud_coral
    end

    if s.living_plants < #s.plants then
        local rev_s = tc_core.has_boon("leyline_roots") and 4 or 6
        return string.format(
            "▸ PLANT WILTED! Follow the red marker & use Water Flask [3], Aegis Potion, or %ds Balance!",
            rev_s
        ), P.hud_coral
    end

    if s.active_reagents >= (s.max_reagents - 2) then
        return string.format(
            "▸ FLOOR GETTING FULL (%d/%d): Clear hazard blocks soon with Tools [1–4]!",
            s.active_reagents, s.max_reagents
        ), P.hud_coral
    end

    if s.temperature > 60.0 then
        return "▸ TOO HOT (>60°C): Splash Brimstone with Water Flask [3] or Right-Click with Trowel [1]!", P.hud_amber
    end
    if s.temperature < 40.0 then
        return "▸ TOO COLD (<40°C): Melt blue Ice with Bellows [2], then scoop the Water with Flask [3]!",
            P.hud_aqua
    end
    if s.ph < 40.0 then
        return "▸ SOIL TOO SOUR (<5.6 pH): Left-Click green Acid Slime with Pestle [4] for Speed Soil!",
            P.hud_emerald
    end
    if s.ph > 60.0 then
        return "▸ SOIL TOO CHALKY (>8.4 pH): Splash Chalk with Water Flask [3] or place beside Acid [1]!",
            P.hud_violet
    end

    if s.turbulent then
        return string.format(
            "▸ ROOM CLUTTERED (%d Hazards > %d Calm Limit): Combine with Trowel [1] or clear with [2–4]!",
            s.active_reagents, s.level
        ), P.hud_amber
    end

    if s.active_reagents > 0 then
        return "▸ BALANCED: Combine blocks with Trowel [1] or clear with [2–4] for extra Bloom! [Z] Call Room",
            P.hud_gold
    end

    return "▸ HAPPY GARDEN: Plants blooming! [I] Quick Tool Guide · [5] Guidebook · [Z] Call Room", P.hud_emerald
end

---Computes the 3 banner lines and colors for a player.
---@param player ObjectRef
---@return string l1, integer c1, string l2, integer c2, string l3, integer c3
local function build_banner_lines(player)
    local s = tc_core.state
    local drop_str
    if s.victory then
        drop_str = "★ 100% BLOOM ★"
    elseif s.defeat then
        drop_str = "✖ PAUSED ✖"
    elseif s.stasis_timer > 0 then
        drop_str = string.format("PAUSED: %ds", math.ceil(s.stasis_timer))
    else
        drop_str = string.format("Next Block: %ds", math.max(0, math.ceil(s.drop_timer)))
    end

    local l1 = string.format(
        "LEVEL %d (%d %s)  ·  Plants Awake: %d/%d  ·  Hazards: %d/%d  ·  %s",
        s.level, s.level, s.level == 1 and "Room" or "Rooms",
        s.living_plants, math.max(1, #s.plants),
        s.active_reagents, s.max_reagents,
        drop_str
    )
    local c1 = ((s.overload_timer or 0) > 0 or s.active_reagents >= s.max_reagents - 2)
        and P.hud_coral or P.hud_gold

    local ph_real = (s.ph / 100.0) * 14.0
    local in_harmony = tc_core.is_in_harmony()

    local eq_prefix
    local c2
    if (s.overload_timer or 0) > 0 then
        eq_prefix = string.format("✖ OVERCROWDED (%ds)", math.max(1, 8 - s.overload_timer))
        c2 = P.hud_coral
    elseif s.aegis_timer > 0 then
        eq_prefix = string.format("✦ PLANT SHIELD (%ds)", math.ceil(s.aegis_timer))
        c2 = P.hud_gold
    elseif in_harmony then
        eq_prefix = string.format("✦ BALANCED (%ds)", s.harmony_streak)
        c2 = (s.harmony_streak >= 8) and P.hud_aqua or P.hud_emerald
    elseif s.turbulent then
        eq_prefix = string.format("⚠ CLUTTERED (%d>%d Blocks)", s.active_reagents, s.level)
        c2 = P.hud_amber
    else
        eq_prefix = "⚠ OFF BALANCE — Aim for 40–60°C & 5.6–8.4 pH"
        c2 = P.hud_amber
    end

    local l2 = string.format(
        "%s  ·  %.0f°C | %.1f pH  ·  %s",
        eq_prefix, s.temperature, ph_real, tc_core.get_active_effects_text(player)
    )

    local l3, c3 = compute_mentor_prompt()
    return l1, c1, l2, c2, l3, c3
end

---Computes rounded HUD bar display values from the live crucible state.
---@param s table
---@return number bloom_v, number vit_v, number temp_v, number ph_v
local function compute_hudbar_values(s)
    local bloom_v = tc_core.clamp(math.floor(s.bloom * 10 + 0.5) / 10, 0, 100)
    local vit_v   = tc_core.clamp(math.floor(s.avg_vitality + 0.5), 0, 100)
    local temp_v  = tc_core.clamp(math.floor(s.temperature + 0.5), 0, 100)
    local ph_v    = tc_core.clamp(math.floor(((s.ph / 100.0) * 14.0) * 10 + 0.5) / 10, 0, 14)
    return bloom_v, vit_v, temp_v, ph_v
end

---Initializes custom hudbars and the top-center 3-line Mentor Telemetry HUD for a joining player.
---@param player ObjectRef
function tc_core.init_player_hud(player)
    if not player or not player:is_player() then
        return
    end
    local name = player:get_player_name()
    if hud_cache[name] then
        tc_core.update_player_hud(player)
        return
    end
    local s = tc_core.state

    hb.hide_hudbar(player, "health")
    hb.hide_hudbar(player, "breath")
    hb.players[name] = nil
    player:hud_set_flags({healthbar = true, breathbar = true})

    local bloom_v, vit_v, temp_v, ph_v = compute_hudbar_values(s)

    hb.init_hudbar(player, "bloom", bloom_v, 100, false)
    hb.init_hudbar(player, "vitality", vit_v, 100, false)
    hb.init_hudbar(player, "temperature", temp_v, 100, false)
    hb.init_hudbar(player, "ph", ph_v, 14, false)

    local l1, c1, l2, c2, l3, c3 = build_banner_lines(player)

    local id1 = player:hud_add({
        type = "text",
        position = {x = 0.5, y = 0.0},
        offset = {x = 0, y = 10},
        alignment = {x = 0, y = 1},
        text = l1,
        number = c1,
        style = 1,
        z_index = 10,
    })
    local id2 = player:hud_add({
        type = "text",
        position = {x = 0.5, y = 0.0},
        offset = {x = 0, y = 30},
        alignment = {x = 0, y = 1},
        text = l2,
        number = c2,
        z_index = 10,
    })
    local id3 = player:hud_add({
        type = "text",
        position = {x = 0.5, y = 0.0},
        offset = {x = 0, y = 49},
        alignment = {x = 0, y = 1},
        text = l3,
        number = c3,
        z_index = 10,
    })

    hud_cache[name] = {
        id1 = id1, l1 = l1, c1 = c1,
        id2 = id2, l2 = l2, c2 = c2,
        id3 = id3, l3 = l3, c3 = c3,
        bloom = bloom_v,
        vit = vit_v,
        temp = temp_v,
        ph = ph_v,
        waypoints = {},
        max_wp_idx = 0,
        ping_wp_id = nil,
        ping_token = 0,
    }
end

---Synchronizes 3D spatial distress waypoints for low-Vitality (<45%) or Withered Sprouts.
---@param player ObjectRef
---@param cache table
local function sync_distress_waypoints(player, cache)
    local s = tc_core.state
    local plants = s.plants
    local prev_max = cache.max_wp_idx or 0
    cache.max_wp_idx = math.max(prev_max, #plants)

    for i = 1, #plants do
        local p = plants[i]
        local show = s.running and (p.withered or p.vitality < 45.0)
        local wp = cache.waypoints[i]
        if show then
            local label = p.withered
                and string.format("✖ Sprout #%d WILTED!", p.index)
                or string.format("⚠ Sprout #%d (%.0f%%)", p.index, p.vitality)
            local col = p.withered and P.hud_coral or P.hud_amber
            if not wp then
                local wid = player:hud_add({
                    type = "waypoint",
                    name = label,
                    text = " m",
                    precision = 0,
                    number = col,
                    world_pos = {x = p.pos.x, y = p.pos.y + 0.85, z = p.pos.z},
                })
                cache.waypoints[i] = {id = wid, label = label, color = col}
            else
                if wp.label ~= label then
                    wp.label = label
                    player:hud_change(wp.id, "name", label)
                end
                if wp.color ~= col then
                    wp.color = col
                    player:hud_change(wp.id, "number", col)
                end
            end
        elseif wp then
            player:hud_remove(wp.id)
            cache.waypoints[i] = nil
        end
    end

    for i = #plants + 1, cache.max_wp_idx do
        if cache.waypoints[i] then
            player:hud_remove(cache.waypoints[i].id)
            cache.waypoints[i] = nil
        end
    end
end

---Removes all active 3D distress and ping waypoints across connected players on level transitions.
function tc_core.clear_all_waypoints()
    local players = core.get_connected_players()
    for p_i = 1, #players do
        local pl = players[p_i]
        local cache = hud_cache[pl:get_player_name()]
        if cache then
            for i = 1, (cache.max_wp_idx or 0) do
                if cache.waypoints[i] then
                    pl:hud_remove(cache.waypoints[i].id)
                    cache.waypoints[i] = nil
                end
            end
            cache.max_wp_idx = 0
            if cache.ping_wp_id then
                pl:hud_remove(cache.ping_wp_id)
                cache.ping_wp_id = nil
            end
        end
    end
end

---Broadcasts a 4s 3D Guild Ping waypoint on the chamber the player is facing or standing in.
---@param player ObjectRef
function tc_core.ping_chamber(player)
    if not player or not player:is_player() then
        return
    end
    local s = tc_core.state
    if #s.plants == 0 then
        return
    end

    local ppos = player:get_pos()
    local dir = player:get_look_dir()
    local focus_x = ppos.x + (dir and dir.x or 0) * 4.0
    local focus_z = ppos.z + (dir and dir.z or 0) * 4.0

    local best_idx = 1
    local best_d2 = math.huge
    for i = 1, #s.plants do
        local c = s.plants[i].pos
        local dx = focus_x - c.x
        local dz = focus_z - c.z
        local d2 = dx * dx + dz * dz
        if d2 < best_d2 then
            best_d2 = d2
            best_idx = i
        end
    end

    local target = s.plants[best_idx]
    local pname = player:get_player_name()
    local status = target.withered
        and string.format("WILTED · %.0f%% Bloom", target.bloom or 0.0)
        or string.format("%.0f%% Bloom · %.0f%% Health", target.bloom or 0.0, target.vitality)

    x_player_api.play_emote(player, "point", 1.8)
    tc_assets.spawn_sheet_particles({
        amount = 18,
        time = 0.6,
        minpos = {x = target.pos.x - 0.3, y = target.pos.y + 0.2, z = target.pos.z - 0.3},
        maxpos = {x = target.pos.x + 0.3, y = target.pos.y + 1.8, z = target.pos.z + 0.3},
        minvel = {x = -0.35, y = 0.8, z = -0.35},
        maxvel = {x = 0.35, y = 2.2, z = 0.35},
        minexptime = 0.6,
        maxexptime = 1.2,
        minsize = 1.6,
        maxsize = 3.2,
        glow = 14,
        texpool = {
            tc_assets.make_sheet_tex_entry(tc_assets.PARTICLES.pollen, {scale_tween = {1.4, 0.45}}),
        },
    })
    core.chat_send_all(
        tc_assets.chat_prefix("Room Marker", P.gold) ..
        core.colorize(
            P.text_primary,
            string.format(
                "%s marked Room #%d (%s · %d Nearby Hazards)!",
                pname, target.index, status, target.hazards_near
            )
        )
    )

    local wp_label = string.format("✦ Room #%d [%s]", target.index, pname)
    local wp_pos = {x = target.pos.x, y = target.pos.y + 1.4, z = target.pos.z}
    local players = core.get_connected_players()
    for i = 1, #players do
        local pl = players[i]
        local pl_name = pl:get_player_name()
        core.sound_play("tc_ping", {to_player = pl_name, gain = 0.85}, true)
        local cache = hud_cache[pl_name]
        if cache then
            if cache.ping_wp_id then
                pl:hud_remove(cache.ping_wp_id)
            end
            local token = (cache.ping_token or 0) + 1
            cache.ping_token = token
            cache.ping_wp_id = pl:hud_add({
                type = "waypoint",
                name = wp_label,
                text = " m",
                precision = 0,
                number = P.hud_gold,
                world_pos = wp_pos,
            })
            core.after(4.0, function()
                local later_pl = core.get_player_by_name(pl_name)
                local later_cache = hud_cache[pl_name]
                if later_pl and later_pl:is_player() and later_cache and later_cache.ping_token == token then
                    if later_cache.ping_wp_id then
                        later_pl:hud_remove(later_cache.ping_wp_id)
                        later_cache.ping_wp_id = nil
                    end
                end
            end)
        end
    end
end

---Updates hudbars and top-center telemetry HUD for a player, sending packets only when values change.
---@param player ObjectRef
function tc_core.update_player_hud(player)
    if not player or not player:is_player() then
        return
    end
    local name = player:get_player_name()
    local cache = hud_cache[name]
    if not cache then
        tc_core.init_player_hud(player)
        return
    end

    local bloom_v, vit_v, temp_v, ph_v = compute_hudbar_values(tc_core.state)

    if cache.bloom ~= bloom_v then
        cache.bloom = bloom_v
        hb.change_hudbar(player, "bloom", bloom_v, 100)
    end
    if cache.vit ~= vit_v then
        cache.vit = vit_v
        hb.change_hudbar(player, "vitality", vit_v, 100)
    end
    if cache.temp ~= temp_v then
        cache.temp = temp_v
        hb.change_hudbar(player, "temperature", temp_v, 100)
    end
    if cache.ph ~= ph_v then
        cache.ph = ph_v
        hb.change_hudbar(player, "ph", ph_v, 14)
    end

    local l1, c1, l2, c2, l3, c3 = build_banner_lines(player)

    if cache.l1 ~= l1 then
        cache.l1 = l1
        player:hud_change(cache.id1, "text", l1)
    end
    if cache.c1 ~= c1 then
        cache.c1 = c1
        player:hud_change(cache.id1, "number", c1)
    end

    if cache.l2 ~= l2 then
        cache.l2 = l2
        player:hud_change(cache.id2, "text", l2)
    end
    if cache.c2 ~= c2 then
        cache.c2 = c2
        player:hud_change(cache.id2, "number", c2)
    end

    if cache.l3 ~= l3 then
        cache.l3 = l3
        player:hud_change(cache.id3, "text", l3)
    end
    if cache.c3 ~= c3 then
        cache.c3 = c3
        player:hud_change(cache.id3, "number", c3)
    end

    sync_distress_waypoints(player, cache)
end
