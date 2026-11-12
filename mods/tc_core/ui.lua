-- tc_core/ui.lua: Unified formspec_version[12] AA-accessible dialogs & interactive player onboarding

local P = tc_assets.PALETTE
local ui = tc_assets.ui
local S = tc_core.S

---Resolves a localized string for `pname` and escapes `\`, `<`, and `>` for safe `hypertext[]` rendering.
---@param pname string
---@param text string
---@return string
local function ht_tr(pname, text)
    return ui.ht_escape(tc_core.resolve_player_text(pname, text))
end

local TAB_DEFS = {
    {
        label = S("1. How to Play"),
        tip = S("Your goal, how plants grow, and how to keep the room comfortable."),
    },
    {
        label = S("2. Blocks & Tools"),
        tip = S("Picture guide showing every falling block and the tool that clears it."),
    },
    {
        label = S("3. Combos & Potions"),
        tip = S("Combine opposite blocks, build green speed paths, and use potions."),
    },
    {
        label = S("4. Healing & Co-op"),
        tip = S("How to revive wilted plants, avoid overcrowding, and play with friends."),
    },
    {
        label = S("5. Top 10 Scores"),
        tip = S("See the highest levels reached and best runs saved on this world."),
    },
}

local function build_guide_tab_1(pname)
    local markup = table.concat({
        "<style color=" .. P.gold .. " size=16><b>" ..
            ht_tr(pname, S("WELCOME TO THE WIZARD'S GLASS TERRARIUM!")) .. "</b></style>\n",
        ht_tr(
            pname,
            S("You have been shrunk down inside an open-top glass box on a wizard's wooden desk.")
        ) .. " ",
        ht_tr(
            pname,
            S(
                "Glowing rings appear on the soil before fire, ice, acid, or chalk blocks drop in from above — " ..
                "clear them on the floor with Tools [1–4], or catch them in mid-air for extra plant growth!"
            )
        ) .. "\n\n",
        "<style color=" .. P.emerald .. " size=15><b>" ..
            ht_tr(pname, S("✦ YOUR GOAL: GROW EVERY PLANT TO 100% BLOOM")) .. "</b></style>\n",
        "• " .. ht_tr(
            pname,
            S(
                "Level 1 starts in 1 cozy glass room with charged Tools [2–4] " ..
                "(4 Puffs · 3 Splashes · 4 Sweeps, gaining +1 cap every 2 levels!)."
            )
        ) .. "\n",
        "• " .. ht_tr(
            pname,
            S(
                "Reach 100% Bloom (skies clear!) and sweep any remaining hazards with all plants awake to win, " ..
                "pick 1 of 3 Next-Level Blessings, or Retry your current level if a higher room gets hectic!"
            )
        ) .. "\n\n",
        "<style color=" .. P.aqua .. " size=15><b>" ..
            ht_tr(pname, S("✦ KEEP HEAT & SOIL COMFORTABLE")) .. "</b></style>\n",
        "• <style color=" .. P.amber .. "><b>" .. ht_tr(pname, S("Heat [40°C – 60°C]")) .. "</b></style>: " ..
            ht_tr(pname, S("Fiery Brimstone makes it hotter; blue Ice makes it colder.")) .. "\n",
        "• <style color=" .. P.violet .. "><b>" .. ht_tr(pname, S("Soil pH [5.6 – 8.4]")) .. "</b></style>: " ..
            ht_tr(pname, S("Green Acid makes soil too sour; Chalk makes soil too dry.")) .. "\n",
        "• " .. ht_tr(
            pname,
            S(
                "Keep leftover floor hazards low so the garden stays Balanced — plants heal themselves, " ..
                "wilted plants revive after 6s, and 8s of balance gives everyone a Harmony Boost!"
            )
        ),
    })

    return table.concat({
        ui.card(0.45, 2.30, 12.50, 1.38, P.emerald, P.bg_card),
        ui.item_badge(0.65, 2.48, 1.00, "tc_elements:crucible_sprout_1", nil, P.emerald),
        ui.item_badge(1.80, 2.48, 1.00, "tc_elements:crucible_sprout_2", nil, P.emerald),
        ui.item_badge(2.95, 2.48, 1.00, "tc_elements:crucible_sprout_3", nil, P.violet),
        ui.item_badge(4.10, 2.48, 1.00, "tc_elements:crucible_sprout_4", nil, P.gold),
        ui.item_badge(5.45, 2.48, 1.00, "tc_elements:fertile_loam", nil, P.emerald),
        ui.hypertext(
            6.65, 2.44, 6.10, 1.14, "",
            "<style color=" .. P.gold .. " size=14><b>" ..
            ht_tr(pname, S("POINT AT ANY PICTURE · RIGHT-CLICK ANY PLANT!")) .. "</b></style>\n" ..
            "<style color=" .. P.text_secondary .. " size=13>" ..
            ht_tr(pname, S("[1–4] Tools · [5] Guidebook · [I] Quick Guide · [Z] Call Room · [E+W] Sprint.")) ..
            "</style>",
            13
        ),
        ui.card(0.45, 3.84, 12.50, 5.06, P.gold, P.bg_card),
        ui.hypertext(0.70, 4.02, 12.00, 4.74, "ht_guide_1", markup, 14),
    })
end

local function build_guide_tab_2(pname)
    local parts = {}
    for i = 1, #tc_elements.REAGENTS do
        local r = tc_elements.REAGENTS[i]
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local cx = 0.45 + col * 6.32
        local cy = 2.30 + row * 3.34

        local body = string.format(
            "<style color=%s size=15><b>%s</b></style>\n" ..
            "<style color=%s size=13><b>%s</b> %s</style>\n" ..
            "<style color=%s size=13><b>%s</b> %s</style>",
            r.accent, ht_tr(pname, r.title),
            P.text_primary, ht_tr(pname, S("What it does:")), ht_tr(pname, r.effect),
            P.emerald, ht_tr(pname, S("How to clear:")), ht_tr(pname, r.usage)
        )

        parts[#parts + 1] = ui.card(cx, cy, 6.18, 3.16, r.accent, P.bg_card)
        parts[#parts + 1] = ui.item_badge(cx + 0.18, cy + 0.22, 0.96, r.name, nil, r.accent)
        parts[#parts + 1] = ui.item_badge(cx + 0.18, cy + 1.28, 0.96, r.tool_item, nil, P.gold)
        parts[#parts + 1] = ui.item_badge(cx + 0.18, cy + 2.12, 0.88, r.pair_item, nil, P.border_arcane)
        parts[#parts + 1] = ui.hypertext(cx + 1.28, cy + 0.20, 4.74, 2.82, "", body, 13)
    end
    return table.concat(parts)
end

local function build_guide_tab_3(pname)
    local rx_markup = table.concat({
        "<style color=" .. P.aqua .. " size=15><b>" ..
            ht_tr(pname, S("✦ HELPFUL COMBOS & BONUS CRYSTALS")) .. "</b></style>\n\n",
        "• <style color=" .. P.amber .. "><b>" ..
            ht_tr(pname, S("Combine Hot + Cold with Trowel [1]")) .. "</b></style>\n  " ..
            ht_tr(
                pname,
                S(
                    "Click Brimstone or Ice with Trowel [1] to scoop it up, then click right onto " ..
                    "(or beside) its opposite so both burst into fresh Water & Steam!"
                )
            ) .. "\n\n",
        "• <style color=" .. P.emerald .. "><b>" ..
            ht_tr(pname, S("Make Green Speed Soil (Acid + Chalk)")) .. "</b></style>\n  " ..
            ht_tr(
                pname,
                S(
                    "Clear green Acid with Pestle [4] (or click Chalk onto Acid) to turn brown dirt into " ..
                    "glowing Fertile Soil that boosts plant growth and running speed!"
                )
            ) .. "\n\n",
        "• <style color=" .. P.gold .. "><b>" ..
            ht_tr(pname, S("Prismatic Geodes & 85% Final Surge")) .. "</b></style>\n  " ..
            ht_tr(
                pname,
                S("Click with Trowel [1] within 22s to clear nearby hazards & refill all Tools [2–4]!")
            ) .. "\n\n",
        "• <style color=" .. P.aqua .. "><b>" ..
            ht_tr(pname, S("Refilling Tools [2–4] & Emergency Prime:")) .. "</b></style> " ..
            ht_tr(
                pname,
                S(
                    "Siphon Brimstone → Bellows [2], Water/Steam → Flask [3], Chalk → Pestle [4] " ..
                    "(or click empty air when empty for +1 emergency charge!)."
                )
            ),
    })

    local elix_markup = table.concat({
        "<style color=" .. P.gold .. " size=15><b>" ..
            ht_tr(pname, S("✦ SPEED SOIL & RARE ELIXIRS [6–7]")) .. "</b></style>\n",
        "<style color=" .. P.text_secondary .. " size=13>" ..
            ht_tr(pname, S("Extra potions past your belt cap auto-convert into bonus Bloom & healing!")) ..
            "</style>\n\n",
        "<style color=" .. P.emerald .. "><b>" ..
            ht_tr(pname, S("Fertile Speed Soil")) .. "</b></style> <i>" ..
            ht_tr(pname, S("(Pave Your Own Green Paths!)")) .. "</i>\n" ..
            ht_tr(
                pname,
                S("Wash Chalk or dust Acid to pave glowing green paths that make you run much faster!")
            ) .. "\n\n",
        "<style color=" .. P.gold .. "><b>" ..
            ht_tr(pname, S("Aegis Potion [6]")) .. "</b></style> <i>" ..
            ht_tr(pname, S("(Geodes & Level Clears · Cap 2)")) .. "</i>\n" ..
            ht_tr(
                pname,
                S(
                    "Refills full health, revives all wilted plants, & shields you + plants for 12s " ..
                    "(triggers automatically if you run out of health!)."
                )
            ) .. "\n\n",
        "<style color=" .. P.violet .. "><b>" ..
            ht_tr(pname, S("Chronos Hourglass [7]")) .. "</b></style> <i>" ..
            ht_tr(pname, S("(Every Level · Cap 2)")) .. "</i>\n" ..
            ht_tr(
                pname,
                S("Pauses falling blocks for 12s, clears nearby hazards, & speeds up everyone!")
            ),
    })

    return table.concat({
        ui.card(0.45, 2.30, 6.35, 6.60, P.aqua, P.bg_card),
        ui.item_badge(0.65, 2.50, 0.94, "tc_tools:trowel", nil, P.aqua),
        ui.item_badge(1.70, 2.50, 0.94, "tc_elements:aether_geode", nil, P.gold),
        ui.item_badge(2.75, 2.50, 0.94, "tc_elements:fertile_loam", nil, P.emerald),
        ui.item_badge(3.80, 2.50, 0.94, "tc_elements:steam", nil, P.aqua),
        ui.hypertext(0.65, 3.58, 5.95, 5.18, "", rx_markup, 13),

        ui.card(6.95, 2.30, 6.00, 6.60, P.gold, P.bg_card),
        ui.item_badge(7.15, 2.50, 0.94, "tc_elements:fertile_loam", nil, P.emerald),
        ui.item_badge(8.20, 2.50, 0.94, "tc_tools:elixir_aegis", nil, P.gold),
        ui.item_badge(9.25, 2.50, 0.94, "tc_tools:chronos_sandglass", nil, P.violet),
        ui.hypertext(7.15, 3.58, 5.60, 5.18, "", elix_markup, 13),
    })
end

local function build_guide_tab_4(pname)
    local revive_markup = table.concat({
        "<style color=" .. P.emerald .. " size=15><b>" ..
            ht_tr(pname, S("✦ PLANT HEALTH & HOW TO REVIVE")) .. "</b></style>\n\n",
        ht_tr(
            pname,
            S("Each room's plant has its own Plant Health (0% – 100%) and natural growth pace:")
        ) .. "\n",
        "• " .. ht_tr(
            pname,
            S(
                "Extreme heat/cold, sour/chalky soil, or hazards left right next to a plant " ..
                "slowly lower that plant's health."
            )
        ) .. "\n",
        "• " .. ht_tr(
            pname,
            S(
                "At 0% health, a plant WILTS and shows a bright red warning marker on screen " ..
                "so you can find it right away—even through walls!"
            )
        ) .. "\n\n",
        "<style color=" .. P.gold .. " size=14><b>" ..
            ht_tr(pname, S("3 EASY WAYS TO REVIVE A WILTED PLANT:")) .. "</b></style>\n",
        "1. " .. ht_tr(
            pname,
            S("Water Flask [3]: Left-Click right on the wilted plant (uses 1 splash).")
        ) .. "\n",
        "2. " .. ht_tr(
            pname,
            S("Aegis Potion: Drink one anywhere to revive every wilted plant at once!")
        ) .. "\n",
        "3. " .. ht_tr(
            pname,
            S("Calm Balance: Keep Heat & Soil comfortable for 6s (4s with Roots)!")
        ),
    })

    local defeat_markup = table.concat({
        "<style color=" .. P.coral .. " size=15><b>" ..
            ht_tr(pname, S("✦ HOW A RUN CAN END (& HOW TO STAY SAFE)")) .. "</b></style>\n\n",
        "1. <style color=" .. P.coral .. "><b>" ..
            ht_tr(pname, S("Every Plant Wilts at Once")) .. "</b></style>\n   " ..
            ht_tr(pname, S("Keep at least 1 plant healthy while you water any wilted ones!")) .. "\n\n",
        "2. <style color=" .. P.amber .. "><b>" ..
            ht_tr(pname, S("Too Many Uncleared Blocks (8-Second Warning)")) .. "</b></style>\n   " ..
            ht_tr(
                pname,
                S(
                    "If too many blocks pile up on the floor, an 8s warning counts down — " ..
                    "clear a few blocks before time runs out to stay safe!"
                )
            ) .. "\n\n",
        "3. <style color=" .. P.violet .. "><b>" ..
            ht_tr(pname, S("Hazard Burns, Stings & Co-op")) .. "</b></style>\n   • " ..
            ht_tr(
                pname,
                S("Standing on Brimstone, wading in Acid Slime, or standing under falling blocks hurts!")
            ) .. "\n   • " ..
            ht_tr(
                pname,
                S("Solo: 0 HP brings you back in Room 1 (-30% plant HP). Press [Z] to call rooms!")
            ),
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

local function build_guide_tab_5(player, pname)
    local receipt = tc_core.build_run_receipt(player)
    return table.concat({
        ui.card(0.45, 2.30, 12.50, 6.60, P.gold, P.bg_card),
        ui.hypertext(
            0.70, 2.46, 12.00, 0.70, "",
            "<style color=" .. P.gold .. " size=15><b>" ..
            ht_tr(pname, S("★ TOP 10 TERRARIUM GARDENERS")) .. "</b></style>  " ..
            "<style color=" .. P.text_secondary .. " size=13>" ..
            ht_tr(
                pname,
                S(
                    "Ranked by Levels Won → Highest Level → Best Bloom → " ..
                    "Fewest Retries → Hazards Cleared → Fastest Time."
                )
            ) ..
            "</style>",
            13
        ),
        tc_core.build_top10_table_formspec(0.70, 3.12, 12.00, 4.68),
        ui.readonly_field(
            0.70, 8.20, 12.00, 0.54,
            "fld_run_receipt",
            S("Shareable Run Summary (Select & Copy):"),
            receipt,
            S("Select and copy your run summary to share with friends or on Jam threads!")
        ),
    })
end

---Displays the 5-tab illustrated Grimoire of Equilibrium in formspec_version[12].
---@param player ObjectRef
---@param tab_idx? integer Selected tab index (1..5)
function tc_core.show_guide_dialog(player, tab_idx)
    if not player or not player:is_player() then
        return
    end
    local pname = player:get_player_name()
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
        tab_content = build_guide_tab_1(pname)
    elseif tab_idx == 2 then
        tab_content = build_guide_tab_2(pname)
    elseif tab_idx == 3 then
        tab_content = build_guide_tab_3(pname)
    elseif tab_idx == 4 then
        tab_content = build_guide_tab_4(pname)
    else
        tab_content = build_guide_tab_5(player, pname)
    end

    local body = table.concat({
        ui.spine_label(0.18, 5.45, S("GRIMOIRE"), P.gold),
        table.concat(tab_buttons),
        tab_content,
        ui.button(
            3.35, 9.10, 3.20, 0.78,
            "btn_guide_garden", S("Garden Status & Pace"), "gold",
            S("Check each plant's health, see this level's blessing, or change the game pace.")
        ),
        ui.button(
            6.85, 9.10, 3.20, 0.78,
            "btn_close", S("Back to Game"), "primary",
            S("Close the Guidebook and return to your garden."), true
        ),
    })

    local form = ui.window({
        w = 13.40,
        h = 10.20,
        title = tc_core.resolve_player_text(pname, S("THE GARDENER'S GUIDEBOOK")),
        subtitle = tc_core.resolve_player_text(
            pname,
            S("Illustrated How-to-Play · Point at any block, tool, or potion picture to read its full tip")
        ),
        accent = P.gold,
        body = body,
    })

    core.show_formspec(pname, "tc_core:guide", form)
end

---Displays the Garden Controls dialog with live multi-chamber status and active difficulty highlight.
---@param player ObjectRef
function tc_core.show_garden_dialog(player)
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
        status_str, status_col = S("★ LEVEL COMPLETE ★"), P.gold
    elseif s.defeat then
        status_str, status_col = S("✖ RUN ENDED ✖"), P.coral
    elseif (s.overload_timer or 0) > 0 then
        status_str, status_col = S("✖ OVERCROWDED (@1s)", math.max(1, 8 - s.overload_timer)), P.coral
    elseif s.cleanup_phase then
        status_str, status_col = S("★ Final Sweep (@1 left)", math.max(0, s.remaining_hazards or 0)), P.gold
    elseif s.aegis_timer > 0 then
        status_str, status_col = S("Plant Shield (@1s)", math.ceil(s.aegis_timer)), P.gold
    elseif in_harmony then
        status_str, status_col = S("Balanced (@1s)", s.harmony_streak), P.emerald
    elseif s.turbulent then
        status_str, status_col = S("Floor Cluttered!"), P.amber
    else
        status_str, status_col = S("Off Balance!"), P.amber
    end

    local stage_num = tc_elements.get_sprout_stage(s.bloom)

    -- Build per-chamber Sprout Bloom & Vitality + active Garden Blessing summary
    local plant_chips = {}
    for i = 1, #s.plants do
        local p = s.plants[i]
        local pb_str = string.format("%.0f", p.bloom or s.bloom)
        if p.withered then
            plant_chips[#plant_chips + 1] = string.format(
                "<style color=%s><b>%s</b></style>",
                P.coral,
                ht_tr(name, S("#@1: WILTED (@2% Bloom)", p.index, pb_str))
            )
        else
            local pc = (p.vitality >= 70 and P.emerald) or (p.vitality >= 35 and P.amber) or P.coral
            local pv_str = string.format("%.0f", p.vitality)
            plant_chips[#plant_chips + 1] = string.format(
                "<style color=%s>%s</style>",
                pc,
                ht_tr(name, S("#@1: @2% Bloom (@3% HP)", p.index, pb_str, pv_str))
            )
        end
    end
    local plant_summary = (#plant_chips > 0)
        and table.concat(plant_chips, "   ·   ")
        or ht_tr(name, S("Starting..."))

    local b_def = s.active_blessing and tc_core.BLESSING_DEFS[s.active_blessing] or nil
    local blessing_line = b_def
        and string.format(
            "<style color=%s><b>[%s]</b></style> <style color=%s>— %s</style>",
            b_def.accent, ht_tr(name, b_def.title),
            P.text_primary, ht_tr(name, b_def.active_summary)
        )
        or ("<style color=" .. P.text_secondary .. ">" ..
            ht_tr(name, S("None yet (Finish a level to pick 1 of 3 Next-Level Blessings!)")) .. "</style>")

    local iv = tc_core.INTERVALS
    local d_cas = (s.difficulty == "casual")
    local d_nrm = (s.difficulty == "normal")
    local d_pnc = (s.difficulty == "panic")

    local close_btn
    if s.victory then
        close_btn = ui.button(
            6.05, 8.22, 5.30, 0.80, "btn_open_victory",
            S("★ Pick Blessing & Next Room! ★"), "primary",
            S("Open the Level Complete screen to pick your Next-Level Blessing and unlock the next room.")
        )
    elseif s.defeat and (s.level or 1) >= 2 then
        close_btn = ui.button(
            6.05, 8.22, 5.30, 0.80, "btn_retry_level",
            S("↻ Retry Level @1", s.level), "primary",
            S(
                "Retry Level @1 with your Blessing, green Speed Soil paths, " ..
                "and restored tools & potions (+1 Retry).",
                s.level
            )
        )
    else
        close_btn = ui.button(
            6.05, 8.22, 5.30, 0.80, "btn_close",
            S("Back to Game"), "primary",
            S("Close this menu and keep caring for your plants."), true
        )
    end

    local cas_lbl = S("Casual (@1s)", string.format("%.0f", iv.casual))
    local nrm_lbl = S("Normal (@1s)", string.format("%.0f", iv.normal))
    local pnc_lbl = S("Panic (@1s)", string.format("%.0f", iv.panic))

    local tr = function(str)
        return tc_core.resolve_player_text(name, str)
    end

    local body = table.concat({
        ui.stat_box(
            0.45, 1.48, 3.52, 1.08,
            tr(S("Garden Condition")), tr(status_str), status_col,
            S("Keep Heat (40–60°C) and Soil pH (5.6–8.4) comfortable so your plants thrive.")
        ),
        ui.stat_box(
            4.14, 1.48, 3.52, 1.08,
            tr(S("Plant Growth (Goal: 100%)")),
            tr(S("@1%  (Stage @2/4)", string.format("%.1f", s.bloom), stage_num)),
            P.emerald,
            S("Reach 100% Bloom, then clear any remaining hazards with all plants awake to finish the level!")
        ),
        ui.stat_box(
            7.83, 1.48, 3.52, 1.08,
            tr(S("Plants Awake & Health")),
            tr(S("@1 / @2  (@3% Avg)", s.living_plants, #s.plants, string.format("%.0f", s.avg_vitality))),
            (s.living_plants == #s.plants) and P.emerald or P.coral,
            S("Heal hurt or wilted plants with Water Flask [3], Aegis Potion, or 6s of Balance.")
        ),

        ui.stat_box(
            0.45, 2.70, 3.52, 1.08,
            tr(S("Heat [40–60°C] · Soil [5.6–8.4]")),
            tr(S("@1°C  |  @2 pH", string.format("%.0f", s.temperature), string.format("%.1f", ph_val))),
            in_harmony and P.aqua or P.amber,
            S("Comfort Zone: 40–60°C Heat and 5.6–8.4 Soil pH.")
        ),
        ui.stat_box(
            4.14, 2.70, 3.52, 1.08,
            tr(S("Floor Hazard Limit")),
            tr(S("@1 / @2 Max Blocks", s.active_reagents, s.max_reagents)),
            ((s.overload_timer or 0) > 0 or s.active_reagents >= s.max_reagents - 2) and P.coral or P.violet,
            S("Going over the max starts an 8-second warning — clear a few blocks in time to stay safe!")
        ),
        ui.stat_box(
            7.83, 2.70, 3.52, 1.08,
            tr(S("Hazards Cleared & Time")),
            tr(S("@1 Cleared  (@2s)", pstat.neutralized or 0, s.run_seconds)),
            P.gold,
            S("Crack Prismatic Geodes & finish levels to earn rare Aegis Potions & Chronos Hourglasses!")
        ),

        -- Per-chamber vitality & active Garden Blessing strip
        ui.card(0.45, 3.94, 10.90, 1.32, P.border_arcane, P.bg_card),
        ui.hypertext(
            0.65, 4.04, 10.50, 1.14, "",
            "<style color=" .. P.text_secondary .. " size=13><b>" ..
            ht_tr(name, S("PLANTS BY ROOM:")) .. "</b></style>  " ..
            plant_summary .. "\n" ..
            "<style color=" .. P.gold .. " size=13><b>" ..
            ht_tr(name, S("THIS LEVEL'S BLESSING:")) .. "</b></style>  " ..
            blessing_line,
            13
        ),

        -- Drop Pace selector with active state highlight
        ui.card(0.45, 5.42, 10.90, 1.56, P.aqua, P.bg_card),
        ui.hypertext(
            0.65, 5.54, 10.50, 0.48, "",
            "<style color=" .. P.aqua .. " size=14><b>" ..
            ht_tr(name, S("GAME PACE (HOW FAST BLOCKS FALL)")) .. "</b></style>  " ..
            "<style color=" .. P.text_secondary .. " size=13>" ..
            ht_tr(name, S("(Change anytime — active choice highlighted):")) .. "</style>",
            13
        ),
        ui.button(
            0.65, 6.06, 3.35, 0.74, "btn_diff_casual",
            (d_cas and "✓ " or "") .. cas_lbl,
            d_cas and "active" or "default",
            S("Relaxed, unhurried pace — great for learning tools and enjoying your garden.")
        ),
        ui.button(
            4.22, 6.06, 3.35, 0.74, "btn_diff_normal",
            (d_nrm and "✓ " or "") .. nrm_lbl,
            d_nrm and "active" or "default",
            S("Comfortable, balanced pace — recommended for most players.")
        ),
        ui.button(
            7.80, 6.06, 3.35, 0.74, "btn_diff_panic",
            (d_pnc and "✓ " or "") .. pnc_lbl,
            d_pnc and "active" or "default",
            S("Fast falling blocks — build green Speed Soil paths and use potions to keep up!")
        ),

        -- Navigation & Reset actions
        ui.button(
            0.45, 7.22, 5.30, 0.80, "btn_guide",
            S("Open Guidebook"), "gold",
            S("Read the 5-tab picture guide to every block, tool, potion, and plant tip.")
        ),
        ui.button(
            6.05, 7.22, 5.30, 0.80, "btn_top10",
            S("★ Top 10 Scores ★"), "default",
            S("View the Top 10 best runs saved on this world.")
        ),
        ui.button(
            0.45, 8.22, 5.30, 0.80, "btn_reset",
            S("Start Over at Level 1"), "danger",
            S("Save your current score and begin a brand-new Level 1 garden.")
        ),
        close_btn,
    })

    local win_title = (s.level == 1)
        and S("GARDEN CONTROLS — LEVEL @1 (1 ROOM)", s.level)
        or S("GARDEN CONTROLS — LEVEL @1 (@2 ROOMS)", s.level, s.level)

    local form = ui.window({
        w = 11.80,
        h = 9.40,
        title = tr(win_title),
        subtitle = tr(S("Check Plant Health, Active Blessing, Game Pace, Guidebook & Top 10 Scores")),
        accent = P.aqua,
        body = body,
    })

    core.show_formspec(name, "tc_core:garden", form)
end

---Displays the standalone Top 10 Leaderboard Formspec v12 dialog.
---@param player ObjectRef
function tc_core.show_leaderboard_dialog(player)
    if not player or not player:is_player() then
        return
    end
    local pname = player:get_player_name()
    local receipt = tc_core.build_run_receipt(player)

    local body = table.concat({
        ui.card(0.45, 1.48, 12.10, 6.42, P.gold, P.bg_card),
        tc_core.build_top10_table_formspec(0.68, 1.70, 11.64, 5.10),
        ui.readonly_field(
            0.68, 7.22, 11.64, 0.54,
            "fld_run_receipt",
            S("Shareable Run Summary (Select & Copy):"),
            receipt,
            S("Select and copy your run summary to share with friends or on Jam threads!")
        ),
        ui.button(
            1.45, 8.14, 3.20, 0.78, "btn_back_garden",
            S("Garden Status"), "active",
            S("Open live plant health and Game Pace controls.")
        ),
        ui.button(
            4.90, 8.14, 3.20, 0.78, "btn_open_guide",
            S("Open Guidebook"), "gold",
            S("Open the illustrated Gardener's Guidebook.")
        ),
        ui.button(
            8.35, 8.14, 3.20, 0.78, "btn_close",
            S("Close"), "primary",
            S("Return to your garden."), true
        ),
    })

    local form = ui.window({
        w = 13.00,
        h = 9.30,
        title = tc_core.resolve_player_text(pname, S("★ TOP 10 TERRARIUM GARDENERS ★")),
        subtitle = tc_core.resolve_player_text(
            pname,
            S("Best Runs Saved on This World — Levels Won, Best Bloom & Hazards Cleared")
        ),
        accent = P.gold,
        body = body,
    })

    core.show_formspec(pname, "tc_core:leaderboard", form)
end

---Displays the Level Complete / Next-Level Garden Blessing Picker & Expansion dialog in formspec_version[12].
---@param player ObjectRef
function tc_core.show_victory_dialog(player)
    if not player or not player:is_player() then
        return
    end
    local pname = player:get_player_name()
    local s = tc_core.state
    local next_lvl = s.level + 1
    local next_drops = tc_core.get_wave_drop_count(next_lvl, #core.get_connected_players())
    local offered = tc_core.roll_offered_blessings()
    local receipt = tc_core.build_run_receipt(player)

    local heading_line = S(
        "ALL @1 PLANT(S) BLOOMED IN @2s! PICK 1 BLESSING FOR LEVEL @3:",
        #s.plants, s.seconds_elapsed, next_lvl
    )
    local next_up_lbl = S("Next Up (Level @1):", next_lvl)
    local next_up_body = S(
        "Opens Glass Room #@1 with Plant #@2 (@3 falling block(s) per wave — your green Speed Soil paths stay!).",
        next_lvl, next_lvl, next_drops
    )
    local fresh_lbl = S("Fresh Every Level:")
    local fresh_body = S(
        "Your Blessing lasts all of Level @1, plus +1 Aegis Potion & +1 Chronos Hourglass!",
        next_lvl
    )

    local summary_markup = string.format(
        "<style color=%s size=15><b>%s</b></style>\n" ..
        "• <style color=%s><b>%s</b></style> %s\n" ..
        "• <style color=%s><b>%s</b></style> %s",
        P.gold, ht_tr(pname, heading_line),
        P.aqua, ht_tr(pname, next_up_lbl), ht_tr(pname, next_up_body),
        P.emerald, ht_tr(pname, fresh_lbl), ht_tr(pname, fresh_body)
    )

    local blessing_cards = {}
    for i = 1, #offered do
        local bid = offered[i]
        local bdef = tc_core.BLESSING_DEFS[bid]
        local cx = 0.45 + (i - 1) * 4.10
        local cy = 3.54
        local card_markup = string.format(
            "<style color=%s size=14><b>%s</b></style>\n<style color=%s size=12>%s</style>",
            bdef.accent, ht_tr(pname, bdef.title),
            P.text_primary, ht_tr(pname, bdef.summary)
        )
        local btn_lbl = S("Pick: @1 → Lvl @2", bdef.title, next_lvl)
        local btn_tip = S(
            "Choose '@1' (@2) for Level @3 and open Room #@4!",
            bdef.title, bdef.summary, next_lvl, next_lvl
        )

        blessing_cards[#blessing_cards + 1] = ui.card(cx, cy, 3.90, 2.66, bdef.accent, P.bg_card)
        blessing_cards[#blessing_cards + 1] = ui.item_badge(cx + 0.14, cy + 0.16, 0.90, bdef.icon, nil, bdef.accent)
        blessing_cards[#blessing_cards + 1] = ui.hypertext(cx + 1.14, cy + 0.14, 2.62, 1.54, "", card_markup, 12)
        blessing_cards[#blessing_cards + 1] = ui.button(
            cx + 0.14, cy + 1.78, 3.62, 0.74,
            "btn_blessing_" .. i, btn_lbl, "primary", btn_tip
        )
    end

    local body = table.concat({
        ui.card(0.45, 1.44, 12.10, 1.96, P.gold, P.bg_card),
        ui.item_badge(0.68, 1.56, 0.86, "tc_elements:crucible_sprout_4", nil, P.gold),
        ui.item_badge(1.62, 1.56, 0.86, "tc_elements:fertile_loam", nil, P.emerald),
        ui.item_badge(0.68, 2.46, 0.86, "tc_tools:elixir_aegis", nil, P.gold),
        ui.item_badge(1.62, 2.46, 0.86, "tc_tools:chronos_sandglass", nil, P.violet),
        ui.hypertext(2.64, 1.54, 9.70, 1.78, "", summary_markup, 13),

        table.concat(blessing_cards),

        ui.card(0.45, 6.34, 12.10, 3.54, P.border_arcane, P.bg_card),
        ui.hypertext(
            0.68, 6.42, 11.64, 0.44, "",
            "<style color=" .. P.gold .. " size=13><b>" ..
            ht_tr(pname, S("TOP 10 SCORES:")) .. "</b></style>",
            12
        ),
        tc_core.build_top10_table_formspec(0.68, 6.82, 11.64, 1.90),
        ui.readonly_field(
            0.68, 9.22, 11.64, 0.54,
            "fld_run_receipt",
            S("Shareable Run Summary (Select & Copy):"),
            receipt,
            S("Select and copy your run summary to share with friends or on Jam threads!")
        ),

        ui.button(
            2.45, 10.06, 3.90, 0.80, "btn_restart",
            S("Start Fresh at Level 1"), "default",
            S("Start a brand-new single-room Level 1 garden.")
        ),
        ui.button(
            6.65, 10.06, 3.90, 0.80, "btn_continue",
            S("Look Around First"), "gold",
            S("Close this window to admire your blooming plants (right-click any Plant when ready!)."), true
        ),
    })

    local form = ui.window({
        w = 13.00,
        h = 11.25,
        title = tc_core.resolve_player_text(
            pname,
            S("★ LEVEL @1 COMPLETE — PICK YOUR NEXT-LEVEL BLESSING! ★", s.level)
        ),
        subtitle = tc_core.resolve_player_text(
            pname,
            S("Choose 1 Blessing for Level @1 (lasts the whole next level, then pick a fresh one!)", next_lvl)
        ),
        accent = P.gold,
        body = body,
    })

    core.show_formspec(pname, "tc_core:victory", form)
end

---Selects tailored recovery advice and counter badges matching the failure cause.
---@param reason string
---@return string advice, string item1, string item2
local function get_recovery_advice(reason)
    local kind = tc_core.state.defeat_kind
    local lower = string.lower(reason or "")
    if kind == "overload" or string.find(lower, "uncleared", 1, true) or string.find(lower, "overload", 1, true) then
        return S(
            "Clear hazards steadily with Bellows [2], Water Flask [3], & Pestle [4], " ..
            "or use a Chronos Hourglass to pause falling blocks!"
        ), "tc_tools:chalk_pestle", "tc_tools:chronos_sandglass"
    elseif kind == "wilt" or string.find(lower, "wilt", 1, true) or string.find(lower, "wither", 1, true) then
        return S(
            "Heal hurt or wilted plants anytime by Left-Clicking them with a filled Water Flask [3] " ..
            "or drinking an Aegis Potion!"
        ), "tc_tools:condenser_flask_full", "tc_tools:elixir_aegis"
    else
        return S(
            "Step around fiery Brimstone and green Acid Slime so they don't burn your feet—and " ..
            "drink an Aegis Potion whenever you need a full heal!"
        ), "tc_tools:trowel", "tc_tools:elixir_aegis"
    end
end

---Displays the Defeat dialog with tailored recovery coaching and Top 10 Leaderboard in formspec_version[12].
---@param player ObjectRef
function tc_core.show_defeat_dialog(player)
    if not player or not player:is_player() then
        return
    end
    local pname = player:get_player_name()
    local s = tc_core.state
    local advice, badge1, badge2 = get_recovery_advice(s.defeat_reason)
    local receipt = tc_core.build_run_receipt(player)

    local bloom_str = string.format("%.1f", s.bloom)
    local run_stats_line
    if s.level == 1 then
        run_stats_line = S(
            "Reached Level @1 (1 Room)  ·  Best Bloom on Level @2: @3%  ·  Time: @4s",
            s.level, s.level, bloom_str, s.run_seconds
        )
    else
        run_stats_line = S(
            "Reached Level @1 (@2 Rooms)  ·  Best Bloom on Level @3: @4%  ·  Retries: @5  ·  Time: @6s",
            s.level, s.level, s.level, bloom_str, s.retries or 0, s.run_seconds
        )
    end

    local summary_markup = string.format(
        "<style color=%s size=15><b>%s</b></style>\n" ..
        "• <b>%s</b> %s\n" ..
        "• <style color=%s><b>%s</b></style> %s",
        P.coral, ht_tr(pname, S("WHAT HAPPENED: @1", s.defeat_reason)),
        ht_tr(pname, S("Your Run:")), ht_tr(pname, run_stats_line),
        P.emerald, ht_tr(pname, S("Helpful Tip for Next Time:")), ht_tr(pname, advice)
    )

    local action_buttons
    if (s.level or 1) >= 2 then
        action_buttons = table.concat({
            ui.button(
                0.45, 9.24, 3.44, 0.84, "btn_retry_level",
                S("↻ Retry Level @1", s.level), "primary",
                S(
                    "Retry Level @1 with your Blessing, green Speed Soil paths, " ..
                    "and restored tools & potions (+1 Retry).",
                    s.level
                )
            ),
            ui.button(
                4.11, 9.24, 2.94, 0.84, "btn_restart",
                S("Start Level 1"), "default",
                S("Start a fresh 0-retry run from Level 1.")
            ),
            ui.button(
                7.27, 9.24, 2.64, 0.84, "btn_defeat_guide",
                S("Guidebook"), "gold",
                S("Read picture tips on tools, combos, and healing plants.")
            ),
            ui.button(
                10.13, 9.24, 2.42, 0.84, "btn_close",
                S("Look Around"), "default",
                S("Close this window to look around (right-click any Plant to retry or switch Pace)."), true
            ),
        })
    else
        action_buttons = table.concat({
            ui.button(
                0.95, 9.24, 4.50, 0.84, "btn_restart",
                S("Play Again (Start Level 1)"), "primary",
                S("Tidy up the terrarium and start a fresh Level 1 garden!")
            ),
            ui.button(
                5.70, 9.24, 3.30, 0.84, "btn_defeat_guide",
                S("Open Guidebook"), "gold",
                S("Read picture tips on tools, combos, and healing plants.")
            ),
            ui.button(
                9.25, 9.24, 2.80, 0.84, "btn_close",
                S("Look Around"), "default",
                S("Close this window to look around (right-click any Plant to start again)."), true
            ),
        })
    end

    local body = table.concat({
        ui.card(0.45, 1.48, 12.10, 2.24, P.coral, P.bg_card),
        ui.item_badge(0.68, 1.84, 1.10, badge1, nil, P.aqua),
        ui.item_badge(1.90, 1.84, 1.10, badge2, nil, P.gold),
        ui.hypertext(3.18, 1.64, 9.16, 1.96, "", summary_markup, 13),

        ui.card(0.45, 3.88, 12.10, 5.12, P.border_arcane, P.bg_card),
        ui.hypertext(
            0.68, 3.98, 11.64, 0.48, "",
            "<style color=" .. P.gold .. " size=14><b>" ..
            ht_tr(pname, S("TOP 10 SCORES:")) .. "</b></style>",
            13
        ),
        tc_core.build_top10_table_formspec(0.68, 4.42, 11.64, 3.38),
        ui.readonly_field(
            0.68, 8.32, 11.64, 0.54,
            "fld_run_receipt",
            S("Shareable Run Summary (Select & Copy):"),
            receipt,
            S("Select and copy your run summary to share with friends or on Jam threads!")
        ),

        action_buttons,
    })

    local form = ui.window({
        w = 13.00,
        h = 10.45,
        title = tc_core.resolve_player_text(pname, S("✖ GARDEN RUN ENDED ON LEVEL @1 ✖", s.level)),
        subtitle = tc_core.resolve_player_text(
            pname,
            S("No worries — right-click any Plant or press [I] to switch to Casual pace anytime!")
        ),
        accent = P.coral,
        body = body,
    })

    core.show_formspec(pname, "tc_core:defeat", form)
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
        if fields.btn_guide_garden then
            tc_core.show_garden_dialog(player)
        end
    elseif formname == "tc_core:garden" then
        local iv = tc_core.INTERVALS
        local sel_diff = fields.btn_diff_casual and "casual"
            or (fields.btn_diff_normal and "normal")
            or (fields.btn_diff_panic and "panic")
        if sel_diff then
            tc_core.state.difficulty = sel_diff
            local is_panic = (sel_diff == "panic")
            local text = sel_diff == "casual" and S("Pace: Casual (~@1s waves)", string.format("%.0f", iv.casual))
                or (is_panic and S("Pace: Panic (~@1s waves)!", string.format("%.0f", iv.panic)))
                or S("Pace: Normal (~@1s waves)", string.format("%.0f", iv.normal))
            tc_core.push_action_feedback(player, {
                kind = "hint",
                icon = "tc_chronos_sandglass.png",
                text = text,
                color = is_panic and P.hud_amber or P.hud_aqua,
                accent_hex = is_panic and P.amber or P.aqua,
                ttl = 2.8,
            })
            tc_core.sync_player_drop_hud(player)
            tc_core.show_garden_dialog(player)
        elseif fields.btn_open_victory then
            tc_core.show_victory_dialog(player)
        elseif fields.btn_retry_level then
            if tc_core.state.defeat then
                tc_core.retry_level()
            end
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
            tc_core.push_hud_event({
                priority = 2,
                icon = "tc_crucible_sprout_1.png",
                title = S("✦ Garden Reset — Level 1"),
                detail = S("Started a fresh Level 1 garden!"),
                color = P.hud_aqua,
                accent_hex = P.aqua,
                ttl = 3.5,
            })
        end
    elseif formname == "tc_core:leaderboard" then
        if fields.btn_back_garden then
            tc_core.show_garden_dialog(player)
        elseif fields.btn_open_guide then
            core.sound_play("tc_book_page", {to_player = pname, gain = 0.75}, true)
            tc_core.show_guide_dialog(player, 1)
        end
    elseif formname == "tc_core:victory" then
        for i = 1, 3 do
            if fields["btn_blessing_" .. i] then
                if not tc_core.state.victory then
                    core.close_formspec(pname, "tc_core:victory")
                    return
                end
                local offered = tc_core.roll_offered_blessings()
                local chosen_id = offered[i] or tc_core.BLESSING_ORDER[1]
                tc_core.select_blessing(chosen_id)
                tc_core.state.blessing_chooser = pname
                core.sound_play("tc_transmute", {gain = 0.9}, true)
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
        if fields.btn_retry_level then
            if tc_core.state.defeat then
                tc_core.retry_level()
            end
        elseif fields.btn_restart then
            tc_core.reset_crucible()
        elseif fields.btn_defeat_guide then
            tc_core.show_guide_dialog(player, 1)
        end
    end
end)
