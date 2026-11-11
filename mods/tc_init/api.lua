---@class TcInitAPI
---@field SPAWN_POS {x: number, y: number, z: number} Canonical Chamber 1 player spawn coordinates
---@field DEFAULT_SKIN string Default Botanical Guild Alchemist character texture
---@field STARTING_TOOLS string[] Ordered hotbar starter toolkit
---@field apply_player_skin fun(player: ObjectRef)
---@field equip_player fun(player: ObjectRef, reset_inv?: boolean)
---@field configure_environment fun(player: ObjectRef)
---@field get_hotbar_bg fun(x: number, y: number): string
---@field build_satchel_formspec fun(player: ObjectRef): string
tc_init = {
    SPAWN_POS = {x = 0, y = 1.5, z = -2.8},
    DEFAULT_SKIN = "tc_alchemist_skin.png",
    STARTING_TOOLS = {
        "tc_tools:trowel",
        "tc_tools:bellows",
        "tc_tools:condenser_flask",
        "tc_tools:chalk_pestle",
        "tc_tools:guide_tome",
    },
}

local P = tc_assets.PALETTE
local ui = tc_assets.ui

---Returns formspec_version[8] image elements for an 8-slot hotbar row.
---@param x number
---@param y number
---@return string
function tc_init.get_hotbar_bg(x, y)
    return ui.inv_slots_bg(x, y, 8, 1)
end

---Equips a player with the standard alchemist toolkit and restores full health.
---@param player ObjectRef Player object reference
---@param reset_inv? boolean Whether to clear main & craft inventories before granting tools
function tc_init.equip_player(player, reset_inv)
    if not player or not player:is_player() then
        return
    end

    local inv = player:get_inventory()
    if reset_inv then
        inv:set_list("main", {})
        inv:set_list("craft", {})
    end

    for i = 1, #tc_init.STARTING_TOOLS do
        local item_name = tc_init.STARTING_TOOLS[i]
        if not inv:contains_item("main", item_name) then
            local has_full = (item_name == "tc_tools:condenser_flask")
                and inv:contains_item("main", "tc_tools:condenser_flask_full")
            if not has_full then
                inv:add_item("main", item_name)
            end
        end
    end

    player:set_hp(20)
    x_player_api.update_wield_item(player, true)
end

---Applies the Botanical Guild Alchemist character skin via x_player_api.
---@param player ObjectRef Player object reference
function tc_init.apply_player_skin(player)
    if not player or not player:is_player() then
        return
    end
    x_player_api.set_textures(player, {tc_init.DEFAULT_SKIN})
end

---Configures the visual skybox, AA formspec prepend, gilded hotbar, and baseline monoid physics.
---@param player ObjectRef Player object reference
function tc_init.configure_environment(player)
    if not player or not player:is_player() then
        return
    end

    tc_init.apply_player_skin(player)
    player:set_properties({zoom_fov = 0})
    player:set_formspec_prepend(ui.get_prepend())

    -- Set styled hotbar textures and slot count
    player:hud_set_hotbar_itemcount(8)
    player:hud_set_hotbar_image("tc_gui_hotbar.png")
    player:hud_set_hotbar_selected_image("tc_gui_hotbar_selected.png")

    player:set_sky({
        type = "regular",
        clouds = false,
        sky_color = {
            day_sky = "#141020",
            day_horizon = "#221834",
            dawn_sky = "#1C122A",
            dawn_horizon = "#2E1A40",
            night_sky = "#0B0814",
            night_horizon = "#160E24",
            indoors = "#141020",
        },
    })

    player:set_sun({visible = false, sunrise_visible = false})
    player:set_moon({visible = false})
    player:set_stars({visible = true, count = 1400, star_color = "#E8DCFF"})
    player:set_lighting({
        bloom = {intensity = 0.06, strength_factor = 1.0, radius = 1.0},
        volumetric_light = {strength = 0.15},
        saturation = 1.05,
    })

    player_monoids.speed:add_change(player, 1.0, "tc_init:base")
    player_monoids.jump:add_change(player, 1.0, "tc_init:base")
    player_monoids.gravity:add_change(player, 1.0, "tc_init:base")
end

---Builds the formspec_version[8] Alchemist's Satchel & Field Cheat-Sheet shown on pressing [I].
---@param _ ObjectRef
---@return string
function tc_init.build_satchel_formspec(_)
    local cheat_rows = {
        {
            reagent = "tc_elements:brimstone",
            tool = "tc_tools:condenser_flask_full",
            accent = P.amber,
            title = "Scorching Brimstone (Hot)",
            desc = "Splash with Water Flask [3], or Right-Click with Trowel [1] & place beside Ice.",
        },
        {
            reagent = "tc_elements:cryo_ice",
            tool = "tc_tools:bellows",
            accent = P.aqua,
            title = "Glacial Ice Shard (Cold)",
            desc = "Left-Click with Bellows [2] to melt into Water, then refill your Water Flask [3]!",
        },
        {
            reagent = "tc_elements:acid_slime",
            tool = "tc_tools:chalk_pestle",
            accent = P.emerald,
            title = "Vitriol Acid Slime (Sour)",
            desc = "Left-Click with Pestle [4] (or place Chalk beside it) to make green Speed Soil!",
        },
        {
            reagent = "tc_elements:alkaline_chalk",
            tool = "tc_tools:condenser_flask_full",
            accent = P.violet,
            title = "Alkaline Chalk (Dry)",
            desc = "Splash with Water Flask [3], or Right-Click with Trowel [1] & place beside Acid.",
        },
    }

    local cards = {}
    for i = 1, #cheat_rows do
        local r = cheat_rows[i]
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local cx = 0.45 + col * 5.05
        local cy = 1.48 + row * 1.38
        cards[#cards + 1] = ui.card(cx, cy, 4.90, 1.24, r.accent, P.bg_card)
        cards[#cards + 1] = ui.item_badge(cx + 0.12, cy + 0.16, 0.92, r.reagent, nil, r.accent)
        cards[#cards + 1] = ui.item_badge(cx + 1.10, cy + 0.16, 0.92, r.tool, nil, P.gold)
        cards[#cards + 1] = ui.hypertext(
            cx + 2.12, cy + 0.12, 2.68, 1.06, "",
            string.format(
                "<style color=%s size=13><b>%s</b></style>\n<style color=%s size=12>%s</style>",
                r.accent, ui.ht_escape(r.title),
                P.text_secondary, ui.ht_escape(r.desc)
            ),
            12
        )
    end

    local body = table.concat({
        table.concat(cards),
        ui.button(
            0.45, 4.36, 3.15, 0.72,
            "btn_satchel_guide", "Open Guidebook", "gold",
            "Read the illustrated 5-tab Guidebook to learn every tool, block, potion, and upgrade."
        ),
        ui.button(
            3.75, 4.36, 3.15, 0.72,
            "btn_satchel_altar", "Garden Status", "active",
            "Check each plant's health, see your upgrades, or change the game pace anytime."
        ),
        ui.button(
            7.05, 4.36, 3.35, 0.72,
            "btn_satchel_top10", "Top 10 Scores", "primary",
            "See the Top 10 best runs saved on this world."
        ),

        -- Hotbar (top row) + Satchel Storage (3 rows) aligned at 1.25 real-coordinate pitch
        ui.card(0.35, 5.24, 10.20, 5.38, P.border_arcane, P.bg_inset),
        ui.inv_slots_bg(0.58, 5.42, 8, 1),
        "list[current_player;main;0.58,5.42;8,1;]",
        ui.inv_slots_bg(0.58, 6.84, 8, 3),
        "list[current_player;main;0.58,6.84;8,3;8]",
    })

    return ui.window({
        w = 10.90,
        h = 10.90,
        title = "YOUR BAG & QUICK TOOL GUIDE",
        subtitle = "Keep Heat (40–60°C) & Soil pH (5.6–8.4) comfortable until every plant reaches 100% Bloom!",
        accent = P.gold,
        body = body,
    })
end
