-- tc_init: Player setup, gloved hand, HUD statbars, sfinv Satchel override, and item physics
local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/api.lua")
dofile(modpath .. "/item_entity.lua")

local S = tc_init.S
local P = tc_assets.PALETTE

-- Set the Botanical Guild Alchemist skin as default on both GLB & B3D player models
local DEFAULT_MODEL_NAMES = {"character.b3d", "character.glb"}
for i = 1, #DEFAULT_MODEL_NAMES do
    local mdef = x_player_api.registered_models[DEFAULT_MODEL_NAMES[i]]
    if mdef then
        mdef.textures = {tc_init.DEFAULT_SKIN}
    end
end

-- Override the built-in hand with tc_wieldhand.png and accessible tooltip
core.override_item("", {
    description = tc_assets.format_description({
        title = S("Gloved Hand"),
        category = S("Empty Hand"),
        summary = S("Your sturdy leather gardening glove."),
        usage = S("Press keys [1] to [5] on your keyboard (or scroll the mouse wheel) to use your tools!"),
        accent = P.violet,
    }),
    short_description = S("Gloved Hand — Press [1–5] for Tools"),
    wield_image = "tc_wieldhand.png",
    wield_scale = {x = 1, y = 1, z = 2.5},
    tool_capabilities = {
        full_punch_interval = 0.9,
        max_drop_level = 0,
        groupcaps = {
            dig_immediate = {times = {[2] = 0.50, [3] = 0.00}, uses = 0, maxlevel = 1},
        },
        damage_groups = {fleshy = 1},
    },
})

-- Replace built-in HUD statbar textures with faceted ruby heart and aether bubble
core.hud_replace_builtin("health", {
    type = "statbar",
    position = {x = 0.5, y = 1},
    text = "tc_heart.png",
    number = 20,
    direction = 0,
    size = {x = 24, y = 24},
    offset = {x = (-10 * 24) - 25, y = -(48 + 24 + 16)},
})

core.hud_replace_builtin("breath", {
    type = "statbar",
    position = {x = 0.5, y = 1},
    text = "tc_bubble.png",
    number = 20,
    direction = 0,
    size = {x = 24, y = 24},
    offset = {x = 25, y = -(48 + 24 + 16)},
})

-- Upgrade sfinv's default page into our formspec_version[12] Alchemist's Satchel & Field Guide
-- without modifying bundled mods/sfinv files
sfinv.override_page("sfinv:crafting", {
    title = S("Bag & Guide"),
    get = function(_, player)
        return tc_init.build_satchel_formspec(player)
    end,
    on_player_receive_fields = function(_, player, _, fields)
        if not player or not player:is_player() then
            return
        end
        if fields.btn_satchel_guide then
            tc_core.show_guide_dialog(player, 1)
        elseif fields.btn_satchel_garden then
            tc_core.show_garden_dialog(player)
        elseif fields.btn_satchel_top10 then
            tc_core.show_leaderboard_dialog(player)
        end
    end,
})

-- Enforce Aegis/Recovering immunity, Hermetic Boots 50% hazard armor, and Auto-Aegis Lifesaver
core.register_on_player_hpchange(function(player, hp_change)
    if hp_change < 0 and player and player:is_player() then
        if tc_core.has_effect(player, "aegis_ward") or tc_core.has_effect(player, "reconstitution") then
            return 0
        end
        if tc_core.has_blessing("hermetic_boots") then
            hp_change = math.min(-1, math.ceil(hp_change * 0.5))
        end
        if tc_core.state.running and (player:get_hp() + hp_change) <= 0 then
            local inv = player:get_inventory()
            if inv and inv:contains_item("main", "tc_tools:elixir_aegis") then
                inv:remove_item("main", "tc_tools:elixir_aegis")
                x_player_api.update_wield_item(player, true)
                local dur = tc_core.has_blessing("sunlit_dew") and 14.0 or 12.0
                tc_core.activate_aegis_ward(player, dur)
                x_player_api.trigger_eat(player, 1.2, "tc_tools:elixir_aegis")
                core.sound_play("tc_elixir_drink", {pos = player:get_pos(), gain = 0.9, max_hear_distance = 22}, true)
                tc_core.push_hud_event_player(player, {
                    priority = 3,
                    icon = "tc_elixir_aegis.png",
                    title = S("✦ Saved by Auto-Aegis!"),
                    detail = S("Health refilled & garden shielded (@1s)!", math.ceil(dur)),
                    color = P.hud_gold,
                    accent_hex = P.gold,
                    ttl = 4.2,
                })
                return 0
            end
        end
        core.sound_play("tc_player_damage", {to_player = player:get_player_name(), gain = 0.8}, true)
    end
    return hp_change
end, true)

-- Lock nocturnal celestial clock on startup (overrides stale env_meta.txt time_of_day in existing worlds)
core.register_on_mods_loaded(function()
    core.set_timeofday(tc_assets.CELESTIAL.timeofday)
end)

-- Configure player visual environment & spawn pose upon joining (run-aware inventory is synced by tc_core)
core.register_on_joinplayer(function(player)
    tc_init.configure_environment(player)
    player:set_pos(tc_init.SPAWN_POS)
    player:set_look_horizontal(0)
end)

-- Notify core engine on player death for solo defeat or co-op reconstitution
core.register_on_dieplayer(function(player)
    tc_core.on_player_died(player)
end)

core.register_on_respawnplayer(function(player)
    tc_init.apply_player_skin(player)
    tc_init.equip_player(player, false)
    player:set_pos(tc_init.SPAWN_POS)
    player:set_look_horizontal(0)
    tc_core.on_player_respawned(player)
    return true
end)
