-- tc_core/ui.lua: Unified formspec_version[8] AA-accessible dialogs & interactive player onboarding

local P = tc_assets.PALETTE
local ui = tc_assets.ui

local TAB_DEFS = {
    {label = "1. How to Play",      tip = "Your goal, how plants grow, and how to keep the room comfortable."},
    {label = "2. Blocks & Tools",   tip = "Picture guide showing every falling block and the tool that clears it."},
    {label = "3. Combos & Potions", tip = "Combine opposite blocks, build green speed paths, and use potions."},
    {label = "4. Healing & Co-op",  tip = "How to revive wilted plants, avoid overcrowding, and play with friends."},
    {label = "5. Top 10 Scores",    tip = "See the highest levels reached and best runs saved on this world."},
}

local function build_guide_tab_1()
    local markup = table.concat({
        "<style color=" .. P.gold .. " size=16><b>WELCOME TO THE WIZARD'S GLASS TERRARIUM!</b></style>\n",
        "You have been shrunk down inside an open-top glass box on a wizard's wooden desk. ",
        "Glowing rings appear on the soil before fire, ice, acid, or chalk blocks drop in from above — ",
        "clear them on the floor with Tools <b>[1–4]</b>, or catch them in mid-air for <b>extra plant growth</b>!\n\n",
        "<style color=" .. P.emerald .. " size=15><b>✦ YOUR GOAL: GROW EVERY PLANT TO 100% BLOOM</b></style>\n",
        "• <b>Level 1</b> starts in <b>1 cozy glass room</b> caring for <b>1 magical Sprout</b>.\n",
        "• Reach <style color=" .. P.gold .. "><b>100% Bloom</b></style> with all plants awake to finish the level, ",
        "pick <b>1 of 3 permanent upgrades</b>, and open a brand-new connected room with another plant!\n\n",
        "<style color=" .. P.aqua .. " size=15><b>✦ KEEP HEAT &amp; SOIL COMFORTABLE</b></style>\n",
        "• <style color=" .. P.amber .. "><b>Heat [40°C – 60°C]</b></style>: ",
        "Fiery Brimstone makes it hotter; blue Ice makes it colder.\n",
        "• <style color=" .. P.violet .. "><b>Soil pH [5.6 – 8.4]</b></style>: ",
        "Green Acid makes soil too sour; Chalk makes soil too dry.\n",
        "• Keep leftover floor hazards low so the garden stays <b>Balanced</b> — plants heal themselves, ",
        "wilted plants revive after <b>6s</b>, and <b>8s</b> of balance gives everyone a ",
        "<style color=" .. P.aqua .. "><b>Harmony Boost</b></style>!",
    })

    return table.concat({
        ui.card(0.45, 2.30, 12.50, 1.38, P.emerald, P.bg_card),
        ui.item_badge(0.65, 2.48, 1.00, "tc_elements:crucible_sprout_1", nil, P.emerald),
        ui.item_badge(1.80, 2.48, 1.00, "tc_elements:crucible_sprout_2", nil, P.emerald),
        ui.item_badge(2.95, 2.48, 1.00, "tc_elements:crucible_sprout_3", nil, P.violet),
        ui.item_badge(4.10, 2.48, 1.00, "tc_elements:crucible_sprout_4", nil, P.gold),
        ui.item_badge(5.45, 2.48, 1.00, "tc_elements:altar_stone", nil, P.gold),
        ui.hypertext(
            6.65, 2.44, 6.10, 1.14, "",
            "<style color=" .. P.gold .. " size=14><b>POINT AT ANY PICTURE TO READ WHAT IT DOES!</b></style>\n" ..
            "<style color=" .. P.text_secondary .. " size=13>" ..
            "<b>[1–4]</b> Tools · <b>[5]</b> Guidebook · <b>[I]</b> Quick Guide · " ..
            "<b>[Z]</b> Call Room · <b>[E+W]</b> Sprint." ..
            "</style>",
            13
        ),
        ui.card(0.45, 3.84, 12.50, 5.06, P.gold, P.bg_card),
        ui.hypertext(0.70, 4.02, 12.00, 4.74, "ht_guide_1", markup, 14),
    })
end

local function build_guide_tab_2()
    local parts = {}
    for i = 1, #tc_elements.REAGENTS do
        local r = tc_elements.REAGENTS[i]
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local cx = 0.45 + col * 6.32
        local cy = 2.30 + row * 3.34

        local body = string.format(
            "<style color=%s size=15><b>%s</b></style>\n" ..
            "<style color=%s size=13><b>What it does:</b> %s</style>\n" ..
            "<style color=%s size=13><b>How to clear:</b> %s</style>",
            r.accent, ui.ht_escape(r.title),
            P.text_primary, ui.ht_escape(r.effect),
            P.emerald, ui.ht_escape(r.usage)
        )

        parts[#parts + 1] = ui.card(cx, cy, 6.18, 3.16, r.accent, P.bg_card)
        parts[#parts + 1] = ui.item_badge(cx + 0.18, cy + 0.22, 0.96, r.name, nil, r.accent)
        parts[#parts + 1] = ui.item_badge(cx + 0.18, cy + 1.28, 0.96, r.tool_item, nil, P.gold)
        parts[#parts + 1] = ui.item_badge(cx + 0.18, cy + 2.12, 0.88, r.pair_item, nil, P.border_arcane)
        parts[#parts + 1] = ui.hypertext(cx + 1.28, cy + 0.20, 4.74, 2.82, "", body, 13)
    end
    return table.concat(parts)
end

local function build_guide_tab_3()
    local rx_markup = table.concat({
        "<style color=" .. P.aqua .. " size=15><b>✦ HELPFUL COMBOS &amp; BONUS CRYSTALS</b></style>\n\n",
        "• <style color=" .. P.amber .. "><b>Combine Hot + Cold with Trowel [1]</b></style>\n",
        "  <b>Right-Click</b> Brimstone or Ice with <b>Trowel [1]</b> to pick it up, then <b>Right-Click</b> ",
        "next to its opposite so both turn into fresh Water &amp; Steam!\n\n",
        "• <style color=" .. P.emerald .. "><b>Make Green Speed Soil (Acid + Chalk)</b></style>\n",
        "  Clear green Acid with <b>Pestle [4]</b> (or set Chalk next to Acid) to turn brown dirt into ",
        "glowing <b>Fertile Soil</b> that boosts plant growth and running speed!\n\n",
        "• <style color=" .. P.gold .. "><b>Prismatic Geodes (Level 2+ Bonus Crystal)</b></style>\n",
        "  Hit with <b>Trowel [1]</b> within 22s to clear nearby hazards and create green Speed Soil!\n\n",
        "• <style color=" .. P.aqua .. "><b>Refilling Water Flask [3] &amp; Steam Jumps</b></style>: ",
        "Left-Click any Water or Steam to fill 3 splashes; walk into Steam to jump high!",
    })

    local elix_markup = table.concat({
        "<style color=" .. P.gold .. " size=15><b>✦ HELPFUL POTIONS &amp; UPGRADES</b></style>\n",
        "<style color=" .. P.text_secondary .. " size=13>" ..
        "Left/Right-Click to use Potions; pick 1 Upgrade after every level:" ..
        "</style>\n\n",
        "<style color=" .. P.aqua .. "><b>Quicksilver Potion</b></style> <i>(Every 3 Hazards Cleared)</i>\n",
        "Run much faster and jump higher for 15 seconds.\n\n",
        "<style color=" .. P.gold .. "><b>Aegis Potion</b></style> <i>(Every 5 Hazards Cleared)</i>\n",
        "Refills full health, revives all wilted plants, &amp; shields plants for 12s " ..
        "(also saves you automatically if you run out of health!).\n\n",
        "<style color=" .. P.violet .. "><b>Chronos Hourglass</b></style> <i>(Every Level Finished)</i>\n",
        "Pauses falling blocks for 12s, clears nearby hazards, &amp; speeds up everyone!",
    })

    return table.concat({
        ui.card(0.45, 2.30, 6.35, 6.60, P.aqua, P.bg_card),
        ui.item_badge(0.65, 2.50, 0.94, "tc_tools:trowel", nil, P.aqua),
        ui.item_badge(1.70, 2.50, 0.94, "tc_elements:aether_geode", nil, P.gold),
        ui.item_badge(2.75, 2.50, 0.94, "tc_elements:fertile_loam", nil, P.emerald),
        ui.item_badge(3.80, 2.50, 0.94, "tc_elements:steam", nil, P.aqua),
        ui.hypertext(0.65, 3.58, 5.95, 5.18, "", rx_markup, 13),

        ui.card(6.95, 2.30, 6.00, 6.60, P.gold, P.bg_card),
        ui.item_badge(7.15, 2.50, 0.94, "tc_tools:elixir_quicksilver", nil, P.aqua),
        ui.item_badge(8.20, 2.50, 0.94, "tc_tools:elixir_aegis", nil, P.gold),
        ui.item_badge(9.25, 2.50, 0.94, "tc_tools:chronos_sandglass", nil, P.violet),
        ui.hypertext(7.15, 3.58, 5.60, 5.18, "", elix_markup, 13),
    })
end

local function build_guide_tab_4()
    local revive_markup = table.concat({
        "<style color=" .. P.emerald .. " size=15><b>✦ PLANT HEALTH &amp; HOW TO REVIVE</b></style>\n\n",
        "Each room's plant has its own <b>Plant Health (0% – 100%)</b> and natural growth pace:\n",
        "• Extreme heat/cold, sour/chalky soil, or hazards left right next to a plant ",
        "slowly lower that plant's health.\n",
        "• At 0% health, a plant <style color=" .. P.coral .. "><b>WILTS</b></style> and shows a bright red ",
        "warning marker on screen so you can find it right away—even through walls!\n\n",
        "<style color=" .. P.gold .. " size=14><b>3 EASY WAYS TO REVIVE A WILTED PLANT:</b></style>\n",
        "1. <b>Water Flask [3]</b>: Left-Click right on the wilted plant (uses 1 splash).\n",
        "2. <b>Aegis Potion</b>: Drink one anywhere to revive every wilted plant at once!\n",
        "3. <b>Calm Balance</b>: Keep Heat &amp; Soil comfortable for <b>6s</b> (<b>4s</b> with Roots)!",
    })

    local defeat_markup = table.concat({
        "<style color=" .. P.coral .. " size=15><b>✦ HOW A RUN CAN END (&amp; HOW TO STAY SAFE)</b></style>\n\n",
        "1. <style color=" .. P.coral .. "><b>Every Plant Wilts at Once</b></style>\n",
        "   Keep at least 1 plant healthy while you water any wilted ones!\n\n",
        "2. <style color=" .. P.amber .. "><b>Too Many Uncleared Blocks (8-Second Warning)</b></style>\n",
        "   If too many blocks pile up on the floor, an <b>8s warning</b> counts down — ",
        "clear a few blocks before time runs out to stay safe!\n\n",
        "3. <style color=" .. P.violet .. "><b>Running Out of Health &amp; Playing Co-op</b></style>\n",
        "   • Solo: running out of health brings you back at the Altar (-30% plant health). ",
        "Co-op only ends if everyone falls together. Press <b>[Z]</b> to call out a room!",
    })

    return table.concat({
        ui.card(0.45, 2.30, 6.35, 6.60, P.emerald, P.bg_card),
        ui.item_badge(0.65, 2.50, 0.94, "tc_elements:crucible_sprout_withered", nil, P.coral),
        ui.item_badge(1.70, 2.50, 0.94, "tc_tools:condenser_flask_full", nil, P.aqua),
        ui.item_badge(2.75, 2.50, 0.94, "tc_tools:elixir_aegis", nil, P.gold),
        ui.hypertext(0.65, 3.58, 5.95, 5.18, "", revive_markup, 13),

        ui.card(6.95, 2.30, 6.00, 6.60, P.coral, P.bg_card),
        ui.hypertext(7.15, 2.54, 5.60, 6.20, "", defeat_markup, 13),
    })
end

local function build_guide_tab_5()
    return table.concat({
        ui.card(0.45, 2.30, 12.50, 6.60, P.gold, P.bg_card),
        ui.hypertext(
            0.70, 2.46, 12.00, 0.70, "",
            "<style color=" .. P.gold .. " size=15><b>★ TOP 10 TERRARIUM GARDENERS</b></style>  " ..
            "<style color=" .. P.text_secondary .. " size=13>" ..
            "Ranked by Levels Won → Highest Level → Best Bloom → Hazards Cleared → Fastest Time." ..
            "</style>",
            13
        ),
        tc_core.build_top10_table_formspec(0.70, 3.12, 12.00, 5.56),
    })
end

---Displays the 5-tab illustrated Grimoire of Equilibrium in formspec_version[8].
---@param player ObjectRef
---@param tab_idx? integer Selected tab index (1..5)
function tc_core.show_guide_dialog(player, tab_idx)
    if not player or not player:is_player() then
        return
    end
    tab_idx = tc_core.clamp(math.floor(tab_idx or 1), 1, 5)

    local tab_buttons = {}
    local tab_w = 2.42
    for i = 1, #TAB_DEFS do
        local td = TAB_DEFS[i]
        local tx = 0.45 + (i - 1) * 2.52
        local variant = (i == tab_idx) and "active" or "default"
        tab_buttons[#tab_buttons + 1] = ui.button(
            tx, 1.44, tab_w, 0.72,
            "btn_gtab_" .. i, td.label, variant, td.tip
        )
    end

    local tab_content
    if tab_idx == 1 then
        tab_content = build_guide_tab_1()
    elseif tab_idx == 2 then
        tab_content = build_guide_tab_2()
    elseif tab_idx == 3 then
        tab_content = build_guide_tab_3()
    elseif tab_idx == 4 then
        tab_content = build_guide_tab_4()
    else
        tab_content = build_guide_tab_5()
    end

    local body = table.concat({
        table.concat(tab_buttons),
        tab_content,
        ui.button(
            3.35, 9.10, 3.20, 0.78,
            "btn_guide_altar", "Garden Status & Pace", "gold",
            "Check each plant's health, see your upgrades, or change the game pace."
        ),
        ui.button(
            6.85, 9.10, 3.20, 0.78,
            "btn_close", "Back to Game", "primary",
            "Close the Guidebook and return to your garden.", true
        ),
    })

    local form = ui.window({
        w = 13.40,
        h = 10.20,
        title = "THE GARDENER'S GUIDEBOOK",
        subtitle = "Illustrated How-to-Play · Point at any block, tool, or potion picture to read its full tip",
        accent = P.gold,
        body = body,
    })

    core.show_formspec(player:get_player_name(), "tc_core:guide", form)
end

---Displays the Crucible Control Altar dialog with live multi-chamber status and active difficulty highlight.
---@param player ObjectRef
function tc_core.show_altar_dialog(player)
    if not player or not player:is_player() then
        return
    end
    local name = player:get_player_name()
    local s = tc_core.state
    local pstat = tc_core.player_stats[name] or {neutralized = 0}
    local ph_val = (s.ph / 100.0) * 14.0
    local in_harmony = tc_core.is_in_harmony()

    local status_str, status_col
    if s.victory then
        status_str, status_col = "★ LEVEL COMPLETE ★", P.gold
    elseif s.defeat then
        status_str, status_col = "✖ RUN ENDED ✖", P.coral
    elseif (s.overload_timer or 0) > 0 then
        status_str, status_col = string.format("✖ OVERCROWDED (%ds)", math.max(1, 8 - s.overload_timer)), P.coral
    elseif s.aegis_timer > 0 then
        status_str, status_col = string.format("Plant Shield (%ds)", math.ceil(s.aegis_timer)), P.gold
    elseif in_harmony then
        status_str, status_col = string.format("Balanced (%ds)", s.harmony_streak), P.emerald
    elseif s.turbulent then
        status_str, status_col = "Floor Cluttered!", P.amber
    else
        status_str, status_col = "Off Balance!", P.amber
    end

    local stage_num = tc_elements.get_sprout_stage(s.bloom)

    -- Build per-chamber Sprout Bloom & Vitality + Guild Boon summary
    local plant_chips = {}
    for i = 1, #s.plants do
        local p = s.plants[i]
        local pb = p.bloom or s.bloom
        if p.withered then
            plant_chips[#plant_chips + 1] = string.format(
                "<style color=%s><b>#%d: WILTED (%.0f%% Bloom)</b></style>", P.coral, p.index, pb
            )
        else
            local pc = (p.vitality >= 70 and P.emerald) or (p.vitality >= 35 and P.amber) or P.coral
            plant_chips[#plant_chips + 1] = string.format(
                "<style color=%s>#%d: %.0f%% Bloom (%.0f%% HP)</style>", pc, p.index, pb, p.vitality
            )
        end
    end
    local plant_summary = (#plant_chips > 0) and table.concat(plant_chips, "   ·   ") or "Starting..."

    local boon_chips = {}
    for i = 1, #tc_core.BOON_ORDER do
        local bid = tc_core.BOON_ORDER[i]
        if s.boons[bid] then
            local bd = tc_core.BOON_DEFS[bid]
            boon_chips[#boon_chips + 1] = string.format(
                "<style color=%s><b>[%s]</b></style>", bd.accent, ui.ht_escape(bd.title)
            )
        end
    end
    local boon_line = (#boon_chips > 0)
        and table.concat(boon_chips, "  ")
        or ("<style color=" .. P.text_secondary .. ">None yet (Finish a level to pick 1 of 3 upgrades!)</style>")

    local iv = tc_core.INTERVALS
    local d_cas = (s.difficulty == "casual")
    local d_nrm = (s.difficulty == "normal")
    local d_pnc = (s.difficulty == "panic")

    local close_btn
    if s.victory then
        close_btn = ui.button(
            6.05, 8.22, 5.30, 0.80, "btn_open_victory",
            "★ Pick Upgrade & Next Room! ★", "primary",
            "Open the Level Complete screen to pick your upgrade and unlock the next room."
        )
    else
        close_btn = ui.button(
            6.05, 8.22, 5.30, 0.80, "btn_close",
            "Back to Game", "primary",
            "Close this menu and keep caring for your plants.", true
        )
    end

    local body = table.concat({
        ui.stat_box(
            0.45, 1.48, 3.52, 1.08,
            "Garden Condition", status_str, status_col,
            "Keep Heat (40–60°C) and Soil pH (5.6–8.4) comfortable so your plants thrive."
        ),
        ui.stat_box(
            4.14, 1.48, 3.52, 1.08,
            "Plant Growth (Goal: 100%)",
            string.format("%.1f%%  (Stage %d/4)", s.bloom, stage_num),
            P.emerald,
            "Grow your plants to 100% Bloom with all plants awake to finish the level!"
        ),
        ui.stat_box(
            7.83, 1.48, 3.52, 1.08,
            "Plants Awake & Health",
            string.format("%d / %d  (%.0f%% Avg)", s.living_plants, #s.plants, s.avg_vitality),
            (s.living_plants == #s.plants) and P.emerald or P.coral,
            "Heal hurt or wilted plants with Water Flask [3], Aegis Potion, or 6s of Balance."
        ),

        ui.stat_box(
            0.45, 2.70, 3.52, 1.08,
            "Heat [40–60°C] · Soil [5.6–8.4]",
            string.format("%.0f°C  |  %.1f pH", s.temperature, ph_val),
            in_harmony and P.aqua or P.amber,
            "Comfort Zone: 40–60°C Heat and 5.6–8.4 Soil pH."
        ),
        ui.stat_box(
            4.14, 2.70, 3.52, 1.08,
            "Floor Hazard Limit",
            string.format("%d / %d Max Blocks", s.active_reagents, s.max_reagents),
            ((s.overload_timer or 0) > 0 or s.active_reagents >= s.max_reagents - 2) and P.coral or P.violet,
            "Going over the max starts an 8-second warning — clear a few blocks in time to stay safe!"
        ),
        ui.stat_box(
            7.83, 2.70, 3.52, 1.08,
            "Hazards Cleared & Time",
            string.format("%d Cleared  (%ds)", pstat.neutralized or 0, s.run_seconds),
            P.gold,
            "Every 3 hazards cleared gives a Quicksilver Potion; every 5 gives an Aegis Potion!"
        ),

        -- Per-chamber vitality & Guild Boons strip
        ui.card(0.45, 3.94, 10.90, 1.32, P.border_arcane, P.bg_card),
        ui.hypertext(
            0.65, 4.04, 10.50, 1.14, "",
            "<style color=" .. P.text_secondary .. " size=13><b>PLANTS BY ROOM:</b></style>  " ..
            plant_summary .. "\n" ..
            "<style color=" .. P.gold .. " size=13><b>ACTIVE UPGRADES:</b></style>  " ..
            boon_line,
            13
        ),

        -- Drop Pace selector with active state highlight
        ui.card(0.45, 5.42, 10.90, 1.56, P.aqua, P.bg_card),
        ui.hypertext(
            0.65, 5.54, 10.50, 0.48, "",
            "<style color=" .. P.aqua .. " size=14><b>GAME PACE (HOW FAST BLOCKS FALL)</b></style>  " ..
            "<style color=" .. P.text_secondary .. " size=13>(Change anytime — active choice highlighted):</style>",
            13
        ),
        ui.button(
            0.65, 6.06, 3.35, 0.74, "btn_diff_casual",
            string.format("%sCasual (%.0fs)", d_cas and "✓ " or "", iv.casual),
            d_cas and "active" or "default",
            "Relaxed, unhurried pace — great for learning tools and enjoying your garden."
        ),
        ui.button(
            4.22, 6.06, 3.35, 0.74, "btn_diff_normal",
            string.format("%sNormal (%.0fs)", d_nrm and "✓ " or "", iv.normal),
            d_nrm and "active" or "default",
            "Comfortable, balanced pace — recommended for most players."
        ),
        ui.button(
            7.80, 6.06, 3.35, 0.74, "btn_diff_panic",
            string.format("%sPanic (%.0fs)", d_pnc and "✓ " or "", iv.panic),
            d_pnc and "active" or "default",
            "Fast falling blocks — build green Speed Soil paths and use potions to keep up!"
        ),

        -- Navigation & Reset actions
        ui.button(
            0.45, 7.22, 5.30, 0.80, "btn_guide",
            "Open Guidebook", "gold",
            "Read the 5-tab picture guide to every block, tool, potion, and plant tip."
        ),
        ui.button(
            6.05, 7.22, 5.30, 0.80, "btn_top10",
            "★ Top 10 Scores ★", "default",
            "View the Top 10 best runs saved on this world."
        ),
        ui.button(
            0.45, 8.22, 5.30, 0.80, "btn_reset",
            "Start Over at Level 1", "danger",
            "Save your current score and begin a brand-new Level 1 garden."
        ),
        close_btn,
    })

    local form = ui.window({
        w = 11.80,
        h = 9.40,
        title = string.format(
            "CONTROL ALTAR — LEVEL %d (%d %s)",
            s.level, s.level, s.level == 1 and "ROOM" or "ROOMS"
        ),
        subtitle = "Check Plant Health, Active Upgrades, Game Pace, Guidebook & Top 10 Scores",
        accent = P.aqua,
        body = body,
    })

    core.show_formspec(name, "tc_core:altar", form)
end

---Displays the standalone Top 10 Leaderboard Formspec v8 dialog.
---@param player ObjectRef
function tc_core.show_leaderboard_dialog(player)
    if not player or not player:is_player() then
        return
    end

    local body = table.concat({
        ui.card(0.45, 1.48, 12.10, 6.42, P.gold, P.bg_card),
        tc_core.build_top10_table_formspec(0.68, 1.70, 11.64, 5.96),
        ui.button(
            1.45, 8.14, 3.20, 0.78, "btn_back_altar",
            "Garden Status", "active",
            "Open live plant health and Game Pace controls."
        ),
        ui.button(
            4.90, 8.14, 3.20, 0.78, "btn_open_guide",
            "Open Guidebook", "gold",
            "Open the illustrated Gardener's Guidebook."
        ),
        ui.button(
            8.35, 8.14, 3.20, 0.78, "btn_close",
            "Close", "primary",
            "Return to your garden.", true
        ),
    })

    local form = ui.window({
        w = 13.00,
        h = 9.30,
        title = "★ TOP 10 TERRARIUM GARDENERS ★",
        subtitle = "Best Runs Saved on This World — Levels Won, Best Bloom & Hazards Cleared",
        accent = P.gold,
        body = body,
    })

    core.show_formspec(player:get_player_name(), "tc_core:leaderboard", form)
end

---Displays the Level Complete / Guild Attunement Boon Picker & Expansion dialog in formspec_version[8].
---@param player ObjectRef
function tc_core.show_victory_dialog(player)
    if not player or not player:is_player() then
        return
    end
    local s = tc_core.state
    local next_lvl = s.level + 1
    local next_drops = tc_core.get_wave_drop_count(next_lvl, #core.get_connected_players())
    local offered = tc_core.roll_offered_boons()

    local summary_markup = string.format(
        "<style color=%s size=15><b>ALL %d PLANT(S) BLOOMED IN %ds! PICK 1 PERMANENT UPGRADE:</b></style>\n" ..
        "• <style color=%s><b>Next Up (Level %d):</b></style> Opens Glass Room #%d with Plant #%d " ..
        "(%d falling block(s) per wave — your green Speed Soil paths stay!).\n" ..
        "• <style color=%s><b>Bonus Supplies:</b></style> +1 Quicksilver Potion, +1 Aegis Potion, " ..
        "&amp; +1 Chronos Hourglass!",
        P.gold, #s.plants, s.seconds_elapsed,
        P.aqua, next_lvl, next_lvl, next_lvl, next_drops,
        P.emerald
    )

    local boon_cards = {}
    for i = 1, #offered do
        local bid = offered[i]
        local bdef = tc_core.BOON_DEFS[bid]
        local owned = s.boons[bid] == true
        local cx = 0.45 + (i - 1) * 4.10
        local cy = 3.54
        local card_markup = string.format(
            "<style color=%s size=14><b>%s</b></style>\n<style color=%s size=12>%s</style>",
            bdef.accent, ui.ht_escape(bdef.title),
            P.text_primary, ui.ht_escape(bdef.summary)
        )
        local btn_lbl = owned
            and string.format("✓ %s → Level %d", bdef.title, next_lvl)
            or string.format("Pick: %s → Lvl %d", bdef.title, next_lvl)
        local btn_tip = string.format(
            "Choose '%s' (%s) and open Room #%d!",
            bdef.title, bdef.summary, next_lvl
        )

        boon_cards[#boon_cards + 1] = ui.card(cx, cy, 3.90, 2.66, bdef.accent, P.bg_card)
        boon_cards[#boon_cards + 1] = ui.item_badge(cx + 0.14, cy + 0.16, 0.90, bdef.icon, nil, bdef.accent)
        boon_cards[#boon_cards + 1] = ui.hypertext(cx + 1.14, cy + 0.14, 2.62, 1.54, "", card_markup, 12)
        boon_cards[#boon_cards + 1] = ui.button(
            cx + 0.14, cy + 1.78, 3.62, 0.74,
            "btn_boon_" .. i, btn_lbl, owned and "active" or "primary", btn_tip
        )
    end

    local body = table.concat({
        ui.card(0.45, 1.44, 12.10, 1.96, P.gold, P.bg_card),
        ui.item_badge(0.68, 1.56, 0.86, "tc_elements:crucible_sprout_4", nil, P.gold),
        ui.item_badge(1.62, 1.56, 0.86, "tc_tools:elixir_quicksilver", nil, P.aqua),
        ui.item_badge(0.68, 2.46, 0.86, "tc_tools:elixir_aegis", nil, P.gold),
        ui.item_badge(1.62, 2.46, 0.86, "tc_tools:chronos_sandglass", nil, P.violet),
        ui.hypertext(2.64, 1.54, 9.70, 1.78, "", summary_markup, 13),

        table.concat(boon_cards),

        ui.card(0.45, 6.34, 12.10, 2.94, P.border_arcane, P.bg_card),
        ui.hypertext(
            0.68, 6.44, 11.64, 0.44, "",
            "<style color=" .. P.gold .. " size=13><b>TOP 10 SCORES:</b></style>",
            12
        ),
        tc_core.build_top10_table_formspec(0.68, 6.86, 11.64, 2.28),

        ui.button(
            2.45, 9.46, 3.90, 0.80, "btn_restart",
            "Start Fresh at Level 1", "default",
            "Reset upgrades and begin a brand-new single-room Level 1 garden."
        ),
        ui.button(
            6.65, 9.46, 3.90, 0.80, "btn_continue",
            "Look Around First", "gold",
            "Close this window to admire your blooming plants (right-click the Altar when ready!).", true
        ),
    })

    local form = ui.window({
        w = 13.00,
        h = 10.65,
        title = string.format("★ LEVEL %d COMPLETE — PICK YOUR UPGRADE! ★", s.level),
        subtitle = "Choose 1 permanent upgrade below to open Glass Room #" .. next_lvl,
        accent = P.gold,
        body = body,
    })

    core.show_formspec(player:get_player_name(), "tc_core:victory", form)
end

---Selects tailored recovery advice and counter badges matching the failure cause.
---@param reason string
---@return string advice, string item1, string item2
local function get_recovery_advice(reason)
    local lower = string.lower(reason or "")
    if string.find(lower, "uncleared", 1, true) or string.find(lower, "overload", 1, true) then
        return "Clear hazards steadily with Bellows [2], Water Flask [3], & Pestle [4], " ..
            "or use a Chronos Hourglass to pause falling blocks!",
            "tc_tools:chalk_pestle", "tc_tools:chronos_sandglass"
    elseif string.find(lower, "wilt", 1, true) or string.find(lower, "wither", 1, true) then
        return "Heal hurt or wilted plants anytime by Left-Clicking them with a filled Water Flask [3] " ..
            "or drinking an Aegis Potion!",
            "tc_tools:condenser_flask_full", "tc_tools:elixir_aegis"
    else
        return "Step around fiery Brimstone and green Acid Slime so they don't burn your feet—and " ..
            "drink an Aegis Potion whenever you need a full heal!",
            "tc_tools:trowel", "tc_tools:elixir_aegis"
    end
end

---Displays the Defeat dialog with tailored recovery coaching and Top 10 Leaderboard in formspec_version[8].
---@param player ObjectRef
function tc_core.show_defeat_dialog(player)
    if not player or not player:is_player() then
        return
    end
    local s = tc_core.state
    local advice, badge1, badge2 = get_recovery_advice(s.defeat_reason)

    local summary_markup = string.format(
        "<style color=%s size=15><b>WHAT HAPPENED: %s</b></style>\n" ..
        "• <b>Your Run:</b> Reached Level %d (%d %s)  ·  Best Bloom on Level %d: %.1f%%  ·  Time: %ds\n" ..
        "• <style color=%s><b>Helpful Tip for Next Time:</b></style> %s",
        P.coral, ui.ht_escape(s.defeat_reason),
        s.level, s.level, s.level == 1 and "Room" or "Rooms", s.level, s.bloom, s.run_seconds,
        P.emerald, ui.ht_escape(advice)
    )

    local body = table.concat({
        ui.card(0.45, 1.48, 12.10, 2.24, P.coral, P.bg_card),
        ui.item_badge(0.68, 1.84, 1.10, badge1, nil, P.aqua),
        ui.item_badge(1.90, 1.84, 1.10, badge2, nil, P.gold),
        ui.hypertext(3.18, 1.64, 9.16, 1.96, "", summary_markup, 13),

        ui.card(0.45, 3.88, 12.10, 4.52, P.border_arcane, P.bg_card),
        ui.hypertext(
            0.68, 4.00, 11.64, 0.48, "",
            "<style color=" .. P.gold .. " size=14><b>TOP 10 SCORES:</b></style>",
            13
        ),
        tc_core.build_top10_table_formspec(0.68, 4.46, 11.64, 3.76),

        ui.button(
            0.95, 8.64, 4.50, 0.84, "btn_restart",
            "Play Again (Start Level 1)", "primary",
            "Tidy up the terrarium and start a fresh Level 1 garden!"
        ),
        ui.button(
            5.70, 8.64, 3.30, 0.84, "btn_defeat_guide",
            "Open Guidebook", "gold",
            "Read picture tips on tools, combos, and healing plants."
        ),
        ui.button(
            9.25, 8.64, 2.80, 0.84, "btn_close",
            "Look Around", "default",
            "Close this window to look around (right-click the Altar to start again).", true
        ),
    })

    local form = ui.window({
        w = 13.00,
        h = 9.85,
        title = string.format("✖ GARDEN RUN ENDED ON LEVEL %d ✖", s.level),
        subtitle = "No worries — you can switch to Casual pace anytime at the Control Altar!",
        accent = P.coral,
        body = body,
    })

    core.show_formspec(player:get_player_name(), "tc_core:defeat", form)
end

-- Formspec submission handler
core.register_on_player_receive_fields(function(player, formname, fields)
    if not player or not player:is_player() then
        return
    end
    local pname = player:get_player_name()

    if formname == "tc_core:guide" then
        for i = 1, #TAB_DEFS do
            if fields["btn_gtab_" .. i] then
                core.sound_play("tc_book_page", {to_player = pname, gain = 0.75}, true)
                tc_core.show_guide_dialog(player, i)
                return
            end
        end
        if fields.btn_guide_altar then
            tc_core.show_altar_dialog(player)
        end
    elseif formname == "tc_core:altar" then
        local iv = tc_core.INTERVALS
        if fields.btn_diff_casual then
            tc_core.state.difficulty = "casual"
            core.chat_send_player(
                pname,
                tc_assets.chat_prefix("Game Pace", P.aqua) ..
                core.colorize(
                    P.text_primary,
                    string.format("Switched to CASUAL pace (about %.0fs between falling blocks).", iv.casual)
                )
            )
            tc_core.show_altar_dialog(player)
        elseif fields.btn_diff_normal then
            tc_core.state.difficulty = "normal"
            core.chat_send_player(
                pname,
                tc_assets.chat_prefix("Game Pace", P.aqua) ..
                core.colorize(
                    P.text_primary,
                    string.format("Switched to NORMAL pace (about %.0fs between falling blocks).", iv.normal)
                )
            )
            tc_core.show_altar_dialog(player)
        elseif fields.btn_diff_panic then
            tc_core.state.difficulty = "panic"
            core.chat_send_player(
                pname,
                tc_assets.chat_prefix("Game Pace", P.amber) ..
                core.colorize(
                    P.text_primary,
                    string.format("Switched to PANIC pace (about %.0fs between falling blocks)!", iv.panic)
                )
            )
            tc_core.show_altar_dialog(player)
        elseif fields.btn_open_victory then
            tc_core.show_victory_dialog(player)
        elseif fields.btn_top10 then
            tc_core.show_leaderboard_dialog(player)
        elseif fields.btn_guide then
            core.sound_play("tc_book_page", {to_player = pname, gain = 0.75}, true)
            tc_core.show_guide_dialog(player, 1)
        elseif fields.btn_reset then
            if tc_core.state.running then
                tc_core.record_all_players(false)
            end
            tc_core.reset_crucible()
            core.chat_send_all(
                tc_assets.chat_prefix("Garden Reset", P.aqua) ..
                core.colorize(P.text_primary, "Started a fresh Level 1 garden (1 Room, 1 Plant)!")
            )
        end
    elseif formname == "tc_core:leaderboard" then
        if fields.btn_back_altar then
            tc_core.show_altar_dialog(player)
        elseif fields.btn_open_guide then
            core.sound_play("tc_book_page", {to_player = pname, gain = 0.75}, true)
            tc_core.show_guide_dialog(player, 1)
        end
    elseif formname == "tc_core:victory" then
        for i = 1, 3 do
            if fields["btn_boon_" .. i] then
                if not tc_core.state.victory then
                    core.close_formspec(pname, "tc_core:victory")
                    return
                end
                local offered = tc_core.roll_offered_boons()
                local chosen_id = offered[i] or tc_core.BOON_ORDER[1]
                local bdef = tc_core.BOON_DEFS[chosen_id]
                tc_core.grant_boon(chosen_id)
                core.sound_play("tc_transmute", {gain = 0.9}, true)
                if bdef then
                    core.chat_send_all(
                        tc_assets.chat_prefix("Upgrade Picked", bdef.accent) ..
                        core.colorize(
                            P.text_primary,
                            string.format("%s chose [%s] — %s", pname, bdef.title, bdef.summary)
                        )
                    )
                end
                local next_lvl = tc_core.state.level + 1
                tc_core.start_level(next_lvl, true)
                local all_p = core.get_connected_players()
                for p_i = 1, #all_p do
                    x_player_api.play_emote(all_p[p_i], "cheer", 2.2)
                    core.close_formspec(all_p[p_i]:get_player_name(), "tc_core:victory")
                end
                return
            end
        end
        if fields.btn_restart then
            tc_core.reset_crucible()
        end
    elseif formname == "tc_core:defeat" then
        if fields.btn_restart then
            tc_core.reset_crucible()
        elseif fields.btn_defeat_guide then
            tc_core.show_guide_dialog(player, 1)
        end
    end
end)
