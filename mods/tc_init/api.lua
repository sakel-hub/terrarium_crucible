---@class TcInitAPI
---@field S fun(str: string, ...: any): string Mod translator function
---@field SPAWN_POS {x: number, y: number, z: number} Canonical Chamber 1 player spawn coordinates
---@field DEFAULT_SKIN string Default Botanical Guild Alchemist character texture
---@field STARTING_TOOLS string[] Ordered hotbar starter toolkit
---@field apply_player_skin fun(player: ObjectRef)
---@field equip_player fun(player: ObjectRef, reset_inv?: boolean)
---@field configure_environment fun(player: ObjectRef)
---@field get_hotbar_bg fun(x: number, y: number): string
---@field build_satchel_formspec fun(player: ObjectRef): string
tc_init = {
    S = core.get_translator("tc_init"),
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

local S = tc_init.S
local P = tc_assets.PALETTE
local ui = tc_assets.ui

---Returns formspec_version[12] image elements for an 8-slot hotbar row.
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
    inv:set_size("trowel_cargo", 1)
    if reset_inv then
        inv:set_list("main", {})
        inv:set_list("craft", {})
        inv:set_stack("trowel_cargo", 1, ItemStack(""))
    end

    for i = 1, #tc_init.STARTING_TOOLS do
        local item_name = tc_init.STARTING_TOOLS[i]
        if item_name == "tc_tools:bellows" then
            if not inv:contains_item("main", "tc_tools:bellows")
                    and not inv:contains_item("main", "tc_tools:bellows_empty") then
                inv:add_item("main", tc_tools.fill_bellows())
            end
        elseif item_name == "tc_tools:condenser_flask" then
            if not inv:contains_item("main", "tc_tools:condenser_flask")
                    and not inv:contains_item("main", "tc_tools:condenser_flask_full") then
                inv:add_item("main", tc_tools.fill_flask())
            end
        elseif item_name == "tc_tools:chalk_pestle" then
            if not inv:contains_item("main", "tc_tools:chalk_pestle")
                    and not inv:contains_item("main", "tc_tools:chalk_pestle_empty") then
                inv:add_item("main", tc_tools.fill_pestle())
            end
        elseif not inv:contains_item("main", item_name) then
            inv:add_item("main", item_name)
        end
    end

    if not reset_inv then
        local cargo_name = ""
        local list = inv:get_list("main") or {}
        for i = 1, #list do
            local st = list[i]
            if st:get_name() == "tc_tools:trowel" then
                cargo_name = tc_tools.get_trowel_cargo(st)
                break
            end
        end
        inv:set_stack("trowel_cargo", 1, ItemStack(cargo_name))
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

    local celestial = tc_assets.CELESTIAL
    local cur_tod = core.get_timeofday()
    if not cur_tod or math.abs(cur_tod - celestial.timeofday) > 0.001 then
        core.set_timeofday(celestial.timeofday)
    end

    player:override_day_night_ratio(celestial.day_night_ratio)
    player:set_sky(tc_assets.SKY_PRESETS.normal)
    player:set_sun({visible = false, sunrise_visible = false})
    player:set_moon(celestial.moon)
    player:set_stars(celestial.stars)
    player:set_clouds(celestial.clouds)
    player:set_lighting(tc_assets.LIGHTING_PRESETS.normal)

    player_monoids.speed:add_change(player, 1.0, "tc_init:base")
    player_monoids.jump:add_change(player, 1.0, "tc_init:base")
    player_monoids.gravity:add_change(player, 1.0, "tc_init:base")
end

---Builds the formspec_version[12] Alchemist's Satchel & Field Cheat-Sheet shown on pressing [I].
---@param player ObjectRef|nil
---@return string
function tc_init.build_satchel_formspec(player)
    local lang = "en"
    if player and player:is_player() then
        local info = core.get_player_information(player:get_player_name())
        if info and type(info.lang_code) == "string" and info.lang_code ~= "" then
            lang = info.lang_code
        end
    end
    local cheat_rows = {
        {
            reagent = "tc_elements:brimstone",
            tool = "tc_tools:condenser_flask_full",
            accent = P.amber,
            title = S("Scorching Brimstone (Hot)"),
            desc = S("Splash with Flask [3], siphon with low Bellows [2] to refill, or pair with Ice [1]."),
        },
        {
            reagent = "tc_elements:cryo_ice",
            tool = "tc_tools:bellows",
            accent = P.aqua,
            title = S("Glacial Ice Shard (Cold)"),
            desc = S("Melt with Bellows [2] into Water, then scoop Water with Flask [3] to refill!"),
        },
        {
            reagent = "tc_elements:acid_slime",
            tool = "tc_tools:chalk_pestle",
            accent = P.emerald,
            title = S("Vitriol Acid Slime (Sour)"),
            desc = S("Sweep with Pestle [4] (or pair Chalk [1] on it) to make green Speed Soil!"),
        },
        {
            reagent = "tc_elements:alkaline_chalk",
            tool = "tc_tools:condenser_flask_full",
            accent = P.violet,
            title = S("Alkaline Chalk (Dry)"),
            desc = S("Wash with Flask [3], grind with low Pestle [4] to refill, or pair with Acid [1]."),
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
                r.accent, ui.ht_escape(core.get_translated_string(lang, r.title)),
                P.text_secondary, ui.ht_escape(core.get_translated_string(lang, r.desc))
            ),
            12
        )
    end

    local body = table.concat({
        table.concat(cards),
        ui.button(
            0.45, 4.36, 3.15, 0.72,
            "btn_satchel_guide", S("Open Guidebook"), "gold",
            S("Read the illustrated 5-tab Guidebook to learn every tool, block, potion, and blessing.")
        ),
        ui.button(
            3.75, 4.36, 3.15, 0.72,
            "btn_satchel_garden", S("Garden Status"), "active",
            S("Check each plant's health, see this level's blessing, or change the game pace anytime.")
        ),
        ui.button(
            7.05, 4.36, 3.35, 0.72,
            "btn_satchel_top10", S("Top 10 Scores"), "primary",
            S("See the Top 10 best runs saved on this world.")
        ),

        -- Hotbar (top row) + Satchel Storage (3 rows) using Luanti 5.18 native listimages[] slot frames
        ui.card(0.35, 5.24, 10.20, 5.38, P.border_arcane, P.bg_inset),
        ui.spine_label(0.16, 5.55, S("SATCHEL"), P.gold),
        "list[current_player;main;0.58,5.42;8,1;]",
        "list[current_player;main;0.58,6.84;8,3;8]",
    })

    return ui.window({
        w = 10.90,
        h = 10.90,
        title = S("YOUR BAG & QUICK TOOL GUIDE"),
        subtitle = S("Keep Heat (40–60°C) & Soil pH (5.6–8.4) comfortable until every plant reaches 100% Bloom!"),
        accent = P.gold,
        body = body,
    })
end
