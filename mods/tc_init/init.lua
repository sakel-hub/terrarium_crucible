-- tc_init: Player setup, gloved hand, HUD statbars, sfinv Satchel override, and item physics
local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/api.lua")
dofile(modpath .. "/item_entity.lua")

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
        title = "Gloved Hand",
        category = "Empty Hand",
        summary = "Your sturdy leather gardening glove.",
        usage = "Press keys [1] to [5] on your keyboard (or scroll the mouse wheel) to use your tools!",
        accent = P.violet,
    }),
    short_description = "Gloved Hand — Press [1–5] for Tools",
    wield_image = "tc_wieldhand.png",
    wield_scale = {x = 1, y = 1, z = 2.5},
    tool_capabilities = {
        full_punch_interval = 0.9,
        max_drop_level = 0,
        groupcaps = {
            reagent = {times = {[1] = 2.80, [2] = 2.00, [3] = 1.20}, uses = 0, maxlevel = 1},
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

-- Upgrade sfinv's default page into our formspec_version[8] Alchemist's Satchel & Field Guide
-- without modifying bundled mods/sfinv files
sfinv.override_page("sfinv:crafting", {
    title = "Bag & Guide",
    get = function(_, player)
        return tc_init.build_satchel_formspec(player)
    end,
    on_player_receive_fields = function(_, player, _, fields)
        if not player or not player:is_player() then
            return
        end
        if fields.btn_satchel_guide then
            tc_core.show_guide_dialog(player, 1)
        elseif fields.btn_satchel_altar then
            tc_core.show_altar_dialog(player)
        elseif fields.btn_satchel_top10 then
            tc_core.show_leaderboard_dialog(player)
        end
    end,
})

-- Play tc_player_damage sound, apply Hermetic Boots 50% hazard armor, and trigger Auto-Aegis Lifesaver
core.register_on_player_hpchange(function(player, hp_change)
    if hp_change < 0 and player and player:is_player() then
        if tc_core.has_boon("hermetic_boots") then
            hp_change = math.min(-1, math.ceil(hp_change * 0.5))
        end
        if tc_core.state.running and (player:get_hp() + hp_change) <= 0 then
            local inv = player:get_inventory()
            if inv and inv:contains_item("main", "tc_tools:elixir_aegis") then
                inv:remove_item("main", "tc_tools:elixir_aegis")
                tc_core.activate_aegis_ward(player, 12.0)
                x_player_api.trigger_eat(player, 1.2, "tc_tools:elixir_aegis")
                core.sound_play("tc_elixir_drink", {pos = player:get_pos(), gain = 0.9, max_hear_distance = 22}, true)
                core.chat_send_player(
                    player:get_player_name(),
                    tc_assets.chat_prefix("Saved!", P.gold) ..
                    core.colorize(
                        P.text_primary,
                        "Your Aegis Potion activated automatically to refill your health and shield your plants!"
                    )
                )
                return 0
            end
        end
        core.sound_play("tc_player_damage", {to_player = player:get_player_name(), gain = 0.8}, true)
    end
    return hp_change
end, true)

-- Configure player environment & starter equipment upon joining
core.register_on_joinplayer(function(player)
    tc_init.configure_environment(player)
    tc_init.equip_player(player, false)

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
