-- tc_core/hud.lua: Responsive, packet-deduplicated 4-zone Alchemical Telemetry & Forecast HUD

local P = tc_assets.PALETTE
local S = tc_core.S
local function N(s)
    return s
end

-- Configure enlarged, padded 192x24 HUD progress bars with centered text and 24x24 effect icons
hb.settings.bar_type = "progress_bar"
hb.settings.alignment_pattern = "stack_down"
hb.settings.max_bar_length = 192
hb.settings.bar_height = 24
hb.settings.bar_bg_texture = "tc_bar_background.png"
hb.settings.text_offset_x = 8
hb.settings.text_offset_y = 0
hb.settings.text_valign = 0
hb.settings.icon_gap = 6
hb.settings.icon_valign = 0
hb.settings.pos_left = {x = 1, y = 0}
hb.settings.pos_right = {x = 1, y = 0}
hb.settings.start_offset_left = {x = -204, y = 112}
hb.settings.start_offset_right = {x = -204, y = 112}
hb.settings.vmargin = 34
hb.settings.forceload_default_hudbars = false
hb.settings.sorting = {}
hb.settings.sorting_reverse = {}
hb.registered_slots = {}

hb.register_hudbar(
    "bloom",
    P.hud_white,
    S("Bloom"),
    {bar = "tc_bar_bloom.png"},
    0,
    100,
    false,
    N("@1: @2%"),
    {order = {"label", "value"}, format_value = "%.1f", textdomain = "tc_core"}
)

hb.register_hudbar(
    "vitality",
    P.hud_white,
    S("Plant HP"),
    {bar = "tc_bar_vitality.png"},
    100,
    100,
    false,
    N("@1: @2%"),
    {order = {"label", "value"}, format_value = "%d", textdomain = "tc_core"}
)

hb.register_hudbar(
    "temperature",
    P.hud_white,
    S("Heat"),
    {bar = "tc_bar_temperature.png"},
    50,
    100,
    false,
    N("@1: @2°C"),
    {order = {"label", "value"}, format_value = "%d", textdomain = "tc_core"}
)

hb.register_hudbar(
    "ph",
    P.hud_white,
    S("Soil pH"),
    {bar = "tc_bar_ph.png"},
    7,
    14,
    false,
    N("@1: @2/@3"),
    {order = {"label", "value", "max_value"}, format_value = "%.1f", format_max_value = "%d", textdomain = "tc_core"}
)

-- Register pooled temporary-effect slots beneath Soil pH so active boosts pack with zero vertical gaps
local EFFECT_SLOT_COUNT = #tc_core.EFFECT_ORDER
local EFFECT_SLOT_IDS = {}
local ALL_HUDBAR_IDS = {"bloom", "vitality", "temperature", "ph"}
for i = 1, EFFECT_SLOT_COUNT do
    local slot_id = "effect_" .. i
    EFFECT_SLOT_IDS[i] = slot_id
    ALL_HUDBAR_IDS[4 + i] = slot_id
    hb.register_hudbar(
        slot_id,
        P.hud_white,
        S("Boost"),
        {
            bar = "tc_bar_effect_soil.png",
            icon = "tc_icon_effect_soil.png",
        },
        0,
        10,
        true,
        N("@1: @2s"),
        {order = {"label", "value"}, format_value = "%.1f", textdomain = "tc_core"}
    )
end

-- Per-player HUD IDs and last-sent state to avoid redundant HUD network packets
local hud_cache = {}

core.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    hud_cache[name] = nil
    hb.players[name] = nil
end)

---Counts UTF-8 codepoints in `str`.
---@param str string
---@return integer
local function utf8_codepoint_len(str)
    if not str or str == "" then
        return 0
    end
    local count = 0
    local i = 1
    local n = #str
    while i <= n do
        local b = string.byte(str, i)
        if b >= 240 then
            i = i + 4
        elseif b >= 224 then
            i = i + 3
        elseif b >= 192 then
            i = i + 2
        else
            i = i + 1
        end
        count = count + 1
    end
    return count
end

---Resolves any server-side translation escape sequences into plain UTF-8 for a player's language.
---Used before codepoint clamping or copyable plain-text fields so `\27` wrappers are never split or exposed.
---@param player_name string
---@param str string
---@return string
function tc_core.resolve_player_text(player_name, str)
    if not str or str == "" or string.find(str, "\27", 1, true) == nil then
        return str or ""
    end
    local lang = "en"
    if player_name and player_name ~= "" then
        local info = core.get_player_information(player_name)
        if info and info.lang_code and info.lang_code ~= "" then
            lang = info.lang_code
        end
    end
    return core.get_translated_string(lang, str)
end

---Clamps a UTF-8 string to at most `max_chars` codepoints without splitting multi-byte UTF-8 glyphs.
---@param str string
---@param max_chars integer
---@return string
function tc_core.clamp_hud_text(str, max_chars)
    if not str or str == "" or max_chars <= 0 then
        return ""
    end
    if #str <= max_chars then
        return str
    end
    local count = 0
    local cut_end = 0
    local truncated = false
    local i = 1
    local n = #str
    while i <= n do
        local b = string.byte(str, i)
        local c_len = 1
        if b >= 240 then
            c_len = 4
        elseif b >= 224 then
            c_len = 3
        elseif b >= 192 then
            c_len = 2
        end
        count = count + 1
        if count == max_chars then
            if i + c_len <= n then
                truncated = true
                break
            else
                return str
            end
        end
        cut_end = i + c_len - 1
        i = i + c_len
    end
    if truncated then
        return string.sub(str, 1, cut_end) .. "…"
    end
    return str
end

---Computes the responsive HUD layout profile for a player's current window dimensions & HiDPI HUD scale.
---Anchors Next Block Drop in the Top-Right above stacked `hudbars`, keeping Top-Left 100% clear for builtin chat.
---@param player_name string
---@return TcHudLayout
function tc_core.get_hud_layout(player_name)
    local win = core.get_player_window_information(player_name)
    local px_w = (win and win.size and win.size.x and win.size.x > 0) and win.size.x or 1280
    local px_h = (win and win.size and win.size.y and win.size.y > 0) and win.size.y or 720
    local scale = (win and win.real_hud_scaling and win.real_hud_scaling > 0) and win.real_hud_scaling or 1.0
    local lw = px_w / scale
    local lh = px_h / scale

    if lw < 1060 or lh < 620 then
        local drop_ox = -196
        local max_banner_w = math.max(240, math.floor(lw - 2 * (-drop_ox + 12)))
        local banner_w = math.min(384, max_banner_w)
        local banner_max = math.min(46, math.max(26, math.floor((banner_w - 28) / 7.5)))
        return {
            tier = "compact",
            lw = lw,
            lh = lh,
            icon_px = 20,
            icon_scale = 0.625,
            banner_w = banner_w,
            banner_max = banner_max,
            card_w = 188,
            card_h = 72,
            card_max = 26,
            toast_w = 188,
            toast_h = 52,
            toast_max = 26,
            pill_max = 38,
            drop_ox = drop_ox,
            drop_oy = 6,
            hb_ox = -200,
            hb_start_y = 94,
            hb_vmargin = 30,
            toast_ox = 8,
            toast_oy = -114,
        }
    elseif lw < 1440 then
        return {
            tier = "standard",
            lw = lw,
            lh = lh,
            icon_px = 24,
            icon_scale = 0.75,
            banner_w = 544,
            banner_max = 66,
            card_w = 224,
            card_h = 78,
            card_max = 31,
            toast_w = 244,
            toast_h = 56,
            toast_max = 34,
            pill_max = 54,
            drop_ox = -236,
            drop_oy = 10,
            hb_ox = -204,
            hb_start_y = 112,
            hb_vmargin = 34,
            toast_ox = 12,
            toast_oy = -124,
        }
    end

    local hb_start_y = math.max(120, math.min(168, math.floor(lh * 0.14)))
    return {
        tier = "wide",
        lw = lw,
        lh = lh,
        icon_px = 24,
        icon_scale = 0.75,
        banner_w = 640,
        banner_max = 80,
        card_w = 252,
        card_h = 80,
        card_max = 36,
        toast_w = 244,
        toast_h = 56,
        toast_max = 36,
        pill_max = 66,
        drop_ox = -268,
        drop_oy = 12,
        hb_ox = -208,
        hb_start_y = hb_start_y,
        hb_vmargin = 34,
        toast_ox = 16,
        toast_oy = -134,
    }
end

---Dynamically positions a player's stacked right-edge `hudbars` (`bloom`..`effect_6`) below the Top-Right Drop Card.
---Emits HUD offset packets strictly when the player's viewport layout changes.
---@param player ObjectRef
---@param cache table
---@param layout TcHudLayout
local function sync_hudbars_layout(player, cache, layout)
    if cache.hb_ox == layout.hb_ox
        and cache.hb_start_y == layout.hb_start_y
        and cache.hb_vmargin == layout.hb_vmargin then
        return
    end
    cache.hb_ox = layout.hb_ox
    cache.hb_start_y = layout.hb_start_y
    cache.hb_vmargin = layout.hb_vmargin

    local pname = player:get_player_name()
    local ox = layout.hb_ox
    local start_y = layout.hb_start_y
    local vmargin = layout.hb_vmargin
    local half_h = math.floor((hb.settings.bar_height or 24) / 2)
    local text_ox = hb.settings.text_offset_x or 8
    local icon_gap = hb.settings.icon_gap or 6

    for idx = 1, #ALL_HUDBAR_IDS do
        local htable = hb.get_hudtable(ALL_HUDBAR_IDS[idx])
        local ids = htable and htable.hudids and htable.hudids[pname]
        if ids then
            local row_y = start_y + vmargin * (idx - 1)
            if ids.bg then
                player:hud_change(ids.bg, "offset", {x = ox - 1, y = row_y - 1})
            end
            if ids.bar then
                player:hud_change(ids.bar, "offset", {x = ox, y = row_y})
            end
            if ids.text then
                player:hud_change(ids.text, "offset", {x = ox + text_ox, y = row_y + half_h})
            end
            if ids.icon then
                player:hud_change(ids.icon, "offset", {x = ox - icon_gap, y = row_y + half_h})
            end
        end
    end
end

---Computes the exact GPU quad scale factor so 16x16, 24x24, and 32x32 textures all render at `icon_px`.
---@param tex string
---@param icon_px integer
---@return number
local function get_icon_scale(tex, icon_px)
    if not tex or tex == "" then
        return 0
    end
    if tex == "tc_heart.png" or tex == "tc_bubble.png" or tex == "tc_item_smoke.png" then
        return icon_px / 16.0
    elseif string.find(tex, "^tc_icon_effect_") ~= nil then
        return icon_px / 24.0
    end
    return icon_px / 32.0
end

---Creates a tracked text HUD element and returns its deduplication state record.
---@param player ObjectRef
---@param pos {x: number, y: number}
---@param align {x: number, y: number}
---@param ox integer
---@param oy integer
---@param text string
---@param color integer
---@param style? integer
---@param z_index? integer
---@return table
local function add_tracked_text(player, pos, align, ox, oy, text, color, style, z_index)
    local id = player:hud_add({
        type = "text",
        position = pos,
        offset = {x = ox, y = oy},
        alignment = align,
        text = text,
        number = color,
        style = style or 0,
        z_index = z_index or 10,
    })
    return {
        id = id,
        text = text,
        number = color,
        ox = ox,
        oy = oy,
    }
end

---Creates a tracked image HUD element and returns its deduplication state record.
---@param player ObjectRef
---@param pos {x: number, y: number}
---@param align {x: number, y: number}
---@param ox integer
---@param oy integer
---@param tex string
---@param sx number
---@param sy number
---@param z_index? integer
---@return table
local function add_tracked_image(player, pos, align, ox, oy, tex, sx, sy, z_index)
    local id = player:hud_add({
        type = "image",
        position = pos,
        offset = {x = ox, y = oy},
        alignment = align,
        scale = {x = sx, y = sy},
        text = tex,
        z_index = z_index or 10,
    })
    return {
        id = id,
        text = tex,
        sx = sx,
        sy = sy,
        ox = ox,
        oy = oy,
    }
end

---Updates a tracked text HUD element, sending packets strictly for changed properties.
---@param player ObjectRef
---@param elem table
---@param text string
---@param color integer
---@param ox integer
---@param oy integer
local function sync_text_elem(player, elem, text, color, ox, oy)
    if elem.text ~= text then
        elem.text = text
        player:hud_change(elem.id, "text", text)
    end
    if text ~= "" then
        if elem.number ~= color then
            elem.number = color
            player:hud_change(elem.id, "number", color)
        end
        if elem.ox ~= ox or elem.oy ~= oy then
            elem.ox = ox
            elem.oy = oy
            player:hud_change(elem.id, "offset", {x = ox, y = oy})
        end
    end
end

---Updates a tracked image HUD element, sending packets strictly for changed properties.
---@param player ObjectRef
---@param elem table
---@param tex string
---@param sx number
---@param sy number
---@param ox integer
---@param oy integer
local function sync_image_elem(player, elem, tex, sx, sy, ox, oy)
    if elem.text ~= tex then
        elem.text = tex
        player:hud_change(elem.id, "text", tex)
    end
    if elem.sx ~= sx or elem.sy ~= sy then
        elem.sx = sx
        elem.sy = sy
        player:hud_change(elem.id, "scale", {x = sx, y = sy})
    end
    if sx > 0 and (elem.ox ~= ox or elem.oy ~= oy) then
        elem.ox = ox
        elem.oy = oy
        player:hud_change(elem.id, "offset", {x = ox, y = oy})
    end
end

---Computes the contextual onboarding / counterplay prompt and AA color for the current crucible state.
---@param tier string
---@return string text
---@return integer color_hex_int
local function compute_mentor_prompt(tier)
    local s = tc_core.state

    if s.victory then
        return S("▸ LEVEL COMPLETE! Pick a Blessing on screen or right-click a Plant!"),
            P.hud_gold
    end
    if s.defeat then
        return S("▸ RUN ENDED: Right-click a Plant or press [I] to restart Level 1."),
            P.hud_coral
    end

    if (s.overload_timer or 0) > 0 then
        local rem = math.max(1, 8 - s.overload_timer)
        local excess = math.max(1, s.active_reagents - s.max_reagents)
        return S("▸ ✖ OVERCROWDED (@1s)! Clear @2 hazard(s) with [1–4]!", rem, excess),
            P.hud_coral
    end

    if s.living_plants < #s.plants then
        local rev_s = tc_core.has_blessing("leyline_roots") and 4 or 6
        return S("▸ PLANT WILTED! Splash with Flask [3], Aegis, or @1s Balance!", rev_s),
            P.hud_coral
    end

    if s.active_reagents >= (s.max_reagents - 2) then
        return S("▸ FLOOR FULL (@1/@2): Clear hazards now with Tools [1–4]!", s.active_reagents, s.max_reagents),
            P.hud_coral
    end

    if s.temperature > 60.0 then
        return S("▸ TOO HOT (>60°C): Splash Brimstone [3] or pair with Ice [1]!"), P.hud_amber
    end
    if s.temperature < 40.0 then
        return S("▸ TOO COLD (<40°C): Melt blue Ice [2] & scoop Water [3]!"), P.hud_aqua
    end
    if s.ph < 40.0 then
        return S("▸ TOO SOUR (<5.6 pH): Sweep green Acid with Pestle [4]!"), P.hud_emerald
    end
    if s.ph > 60.0 then
        return S("▸ TOO CHALKY (>8.4 pH): Wash Chalk [3] or pair with Acid [1]!"), P.hud_violet
    end

    if s.turbulent then
        return S("▸ CLUTTERED (@1>@2): Combine [1] or clear hazards [2–4]!", s.active_reagents, s.level),
            P.hud_amber
    end

    if tier == "compact" then
        return "", P.hud_emerald
    end

    if s.active_reagents > 0 then
        return S("▸ BALANCED: Combine blocks [1] or clear [2–4] for Bloom! [Z] Ping"),
            P.hud_gold
    end

    return S("▸ HAPPY GARDEN: [I] Tool Guide · [5] Guidebook · [Z] Call Room"), P.hud_emerald
end

---Computes the 3 top-center banner lines and colors for the live crucible state and viewport layout.
---@param player_name string
---@param layout TcHudLayout
---@return string l1, integer c1, string l2, integer c2, string l3, integer c3
local function build_banner_lines(player_name, layout)
    local s = tc_core.state
    local tier = layout.tier
    local n_plants = math.max(1, #s.plants)

    local status_tail = ""
    if s.victory then
        status_tail = "  ·  " .. S("★ 100% BLOOM ★")
    elseif s.defeat then
        status_tail = "  ·  " .. S("✖ PAUSED ✖")
    end

    local l1
    if tier == "compact" then
        l1 = S(
            "LV@1 · Plants @2/@3 · Hazards @4/@5@6",
            s.level, s.living_plants, n_plants, s.active_reagents, s.max_reagents, status_tail
        )
    elseif s.level == 1 then
        l1 = S(
            "LEVEL @1 (1 Room)  ·  Plants: @2/@3  ·  Hazards: @4/@5@6",
            s.level, s.living_plants, n_plants, s.active_reagents, s.max_reagents, status_tail
        )
    else
        l1 = S(
            "LEVEL @1 (@2 Rooms)  ·  Plants: @3/@4  ·  Hazards: @5/@6@7",
            s.level, s.level, s.living_plants, n_plants, s.active_reagents, s.max_reagents, status_tail
        )
    end
    local c1 = ((s.overload_timer or 0) > 0 or s.active_reagents >= s.max_reagents - 2)
        and P.hud_coral or P.hud_gold

    local ph_real = (s.ph / 100.0) * 14.0
    local in_harmony = tc_core.is_in_harmony()

    local eq_prefix
    local c2
    if (s.overload_timer or 0) > 0 then
        eq_prefix = S("✖ OVERCROWDED (@1s)", math.max(1, 8 - s.overload_timer))
        c2 = P.hud_coral
    elseif s.aegis_timer > 0 then
        eq_prefix = S("✦ SHIELD (@1s)", math.ceil(s.aegis_timer))
        c2 = P.hud_gold
    elseif in_harmony then
        eq_prefix = S("✦ BALANCED (@1s)", s.harmony_streak)
        c2 = (s.harmony_streak >= 8) and P.hud_aqua or P.hud_emerald
    elseif s.turbulent then
        eq_prefix = S("⚠ CLUTTERED (@1>@2)", s.active_reagents, s.level)
        c2 = P.hud_amber
    else
        eq_prefix = (tier == "compact")
            and S("⚠ OFF BALANCE")
            or S("⚠ OFF BALANCE (40–60°C · 5.6–8.4 pH)")
        c2 = P.hud_amber
    end

    local temp_str = string.format("%.0f", s.temperature)
    local ph_str = string.format("%.1f", ph_real)
    local b_id = s.active_blessing
    local b_def = b_id and tc_core.BLESSING_DEFS[b_id] or nil
    local l2
    if b_def then
        if tier == "compact" then
            l2 = S("@1 · @2°C | @3pH · @4", eq_prefix, temp_str, ph_str, b_def.title)
        else
            l2 = S("@1  ·  @2°C | @3 pH  ·  Blessing: @4", eq_prefix, temp_str, ph_str, b_def.title)
        end
    else
        l2 = S("@1  ·  @2°C | @3 pH", eq_prefix, temp_str, ph_str)
    end

    local raw_l3, c3 = compute_mentor_prompt(tier)
    l1 = tc_core.clamp_hud_text(tc_core.resolve_player_text(player_name, l1), layout.banner_max)
    l2 = tc_core.clamp_hud_text(tc_core.resolve_player_text(player_name, l2), layout.banner_max)
    local l3 = (raw_l3 ~= "")
        and tc_core.clamp_hud_text(tc_core.resolve_player_text(player_name, raw_l3), layout.banner_max)
        or ""

    return l1, c1, l2, c2, l3, c3
end

---Summarizes the active or upcoming wave into header text, accent color, block icons, counter tool, and caption.
---@param player_name string
---@param layout TcHudLayout
---@return boolean visible
---@return string header
---@return integer header_col
---@return string accent_hex
---@return string[] icons
---@return string tool_icon
---@return string desc
local function compute_drop_card_model(player_name, layout)
    local s = tc_core.state
    if s.victory or s.defeat then
        return false, "", P.hud_gold, P.gold, {}, "", ""
    end

    local is_active = (s.active_drop ~= nil and (s.active_drop.ttl or 0) > 0)
    local wave_obj = is_active
        and s.active_drop
        or tc_core.ensure_next_wave(math.max(1, #core.get_connected_players()))

    local items = (wave_obj and wave_obj.items) or {}
    if #items == 0 then
        return false, "", P.hud_gold, P.gold, {}, "", ""
    end

    local extra_n = math.max(0, #items - 4)
    local extra_tag = (extra_n > 0) and string.format(" (+%d)", extra_n) or ""

    local header
    local header_col
    local accent_hex
    if is_active then
        if wave_obj.kind == "surge" then
            header = S("★ FINAL SURGE!") .. extra_tag
            header_col = P.hud_gold
            accent_hex = P.gold
        elseif wave_obj.kind == "geode" then
            header = S("▾ BONUS GEODE!") .. extra_tag
            header_col = P.hud_aqua
            accent_hex = P.aqua
        elseif wave_obj.kind == "trial" then
            header = S("▾ TRIAL FALLING!") .. extra_tag
            header_col = P.hud_violet
            accent_hex = P.violet
        else
            header = S("▾ FALLING NOW!") .. extra_tag
            header_col = P.hud_amber
            accent_hex = P.amber
        end
    else
        if s.stasis_timer > 0 then
            header = S("⏳ PAUSED · @1s@2", math.ceil(s.stasis_timer), extra_tag)
            header_col = P.hud_violet
            accent_hex = P.violet
        else
            local secs = math.max(0, math.ceil(s.drop_timer))
            if wave_obj.kind == "geode" then
                header = S("✦ GEODE IN @1s@2", secs, extra_tag)
                header_col = P.hud_aqua
                accent_hex = P.aqua
            elseif wave_obj.kind == "trial" then
                header = S("★ TRIAL IN @1s@2", secs, extra_tag)
                header_col = P.hud_violet
                accent_hex = P.violet
            else
                header = S("NEXT DROP · @1s@2", secs, extra_tag)
                header_col = (secs <= 3) and P.hud_amber or P.hud_gold
                accent_hex = (secs <= 3) and P.amber or P.gold
            end
        end
    end

    local icons = {}
    local shown_n = math.min(4, #items)
    local has_brim = false
    local has_ice = false
    local has_acid = false
    local has_chalk = false
    local all_same = true
    local first_name = items[1]

    for i = 1, #items do
        local iname = items[i]
        if iname ~= first_name then
            all_same = false
        end
        if iname == "tc_elements:brimstone" then
            has_brim = true
        elseif iname == "tc_elements:cryo_ice" then
            has_ice = true
        elseif iname == "tc_elements:acid_slime" then
            has_acid = true
        elseif iname == "tc_elements:alkaline_chalk" then
            has_chalk = true
        end
        if i <= shown_n then
            local spec = tc_elements.REAGENT_BY_NAME[iname]
            icons[i] = spec and spec.texture or "tc_aether_geode.png"
        end
    end

    local s1 = tc_elements.REAGENT_BY_NAME[first_name] or tc_elements.CATALYST
    local tool_icon = s1.tool_icon or "tc_tool_trowel.png"
    local desc
    if (has_brim and has_ice) or (has_acid and has_chalk) then
        tool_icon = "tc_tool_trowel.png"
        if wave_obj.kind == "surge" then
            desc = S("Crack Geode or Pair [1]!")
        else
            desc = S("Opposite Pair → Combine [1]!")
        end
    elseif #items == 1 then
        desc = S("@1 → @2", s1.hud_short, s1.hud_counter)
    elseif all_same then
        desc = S("@1x @2 → @3", #items, s1.hud_short, s1.hud_counter)
    elseif wave_obj.kind == "geode" then
        desc = S("@1 + Geode!", s1.hud_short)
    else
        local s2 = tc_elements.REAGENT_BY_NAME[items[2]] or s1
        desc = S("@1 · @2", s1.hud_counter, s2.hud_counter)
    end

    header = tc_core.clamp_hud_text(tc_core.resolve_player_text(player_name, header), layout.card_max)
    desc = tc_core.clamp_hud_text(tc_core.resolve_player_text(player_name, desc), layout.card_max)
    return true, header, header_col, accent_hex, icons, tool_icon, desc
end

---Synchronizes Zone 2 (Top-Right Incoming Drop Forecast & Active Wave Plaque) for a single player.
---@param player ObjectRef
---@param cache table
---@param layout TcHudLayout
local function sync_drop_card(player, cache, layout)
    local pname = player:get_player_name()
    local visible, header, header_col, accent_hex, icons, tool_icon, desc = compute_drop_card_model(pname, layout)
    if not visible then
        sync_image_elem(player, cache.drop_bg, "", 0, 0, 0, 0)
        sync_image_elem(player, cache.drop_accent, "", 0, 0, 0, 0)
        sync_text_elem(player, cache.drop_header, "", P.hud_gold, 0, 0)
        for k = 1, 4 do
            sync_image_elem(player, cache.drop_icons[k], "", 0, 0, 0, 0)
        end
        sync_text_elem(player, cache.drop_arrow, "", P.hud_muted, 0, 0)
        sync_image_elem(player, cache.drop_tool_icon, "", 0, 0, 0, 0)
        sync_text_elem(player, cache.drop_desc, "", P.hud_white, 0, 0)
        return
    end

    local tier = layout.tier
    local ox = layout.drop_ox
    local oy = layout.drop_oy
    local icon_px = layout.icon_px
    local shown_n = #icons

    local bg_tex
    local rim_base
    local hdr_x
    local hdr_y
    local tray_x
    local icon_y
    local step_x
    local desc_y
    if tier == "compact" then
        bg_tex = "tc_hud_drop_compact.png"
        rim_base = "tc_hud_drop_rim_compact.png"
        hdr_x = ox + 10
        hdr_y = oy + 4
        tray_x = ox + 13
        icon_y = oy + 27
        step_x = icon_px + 2
        desc_y = oy + 52
    elseif tier == "standard" then
        bg_tex = "tc_hud_drop_std.png"
        rim_base = "tc_hud_drop_rim_std.png"
        hdr_x = ox + 11
        hdr_y = oy + 5
        tray_x = ox + 14
        icon_y = oy + 28
        step_x = icon_px + 4
        desc_y = oy + 56
    else
        bg_tex = "tc_hud_drop_wide.png"
        rim_base = "tc_hud_drop_rim_wide.png"
        hdr_x = ox + 12
        hdr_y = oy + 5
        tray_x = ox + 15
        icon_y = oy + 29
        step_x = icon_px + 4
        desc_y = oy + 58
    end

    local acc_tex = rim_base .. "^[multiply:" .. accent_hex
    sync_image_elem(player, cache.drop_bg, bg_tex, 1, 1, ox, oy)
    sync_image_elem(player, cache.drop_accent, acc_tex, 1, 1, ox, oy)
    sync_text_elem(player, cache.drop_header, header, header_col, hdr_x, hdr_y)

    for k = 1, 4 do
        local itex = icons[k]
        if itex then
            local iscale = get_icon_scale(itex, icon_px)
            sync_image_elem(
                player,
                cache.drop_icons[k],
                itex,
                iscale,
                iscale,
                tray_x + (k - 1) * step_x,
                icon_y
            )
        else
            sync_image_elem(player, cache.drop_icons[k], "", 0, 0, 0, 0)
        end
    end

    local arrow_x = tray_x + shown_n * step_x + 2
    local arrow_y = icon_y + math.max(0, math.floor((icon_px - 16) / 2))
    sync_text_elem(player, cache.drop_arrow, "→", P.hud_muted, arrow_x, arrow_y)

    local tscale = get_icon_scale(tool_icon, icon_px)
    local tool_gap = (tier == "compact") and 15 or 17
    sync_image_elem(player, cache.drop_tool_icon, tool_icon, tscale, tscale, arrow_x + tool_gap, icon_y)
    sync_text_elem(player, cache.drop_desc, desc, P.hud_white, hdr_x, desc_y)
end

---Synchronizes Zone 3 (Bottom-Left Priority Event Toast Plaque, keeping Top-Left clear for chat).
---@param player ObjectRef
---@param cache table
---@param layout TcHudLayout
local function sync_event_toast(player, cache, layout)
    if (cache.ev_ttl or 0) <= 0 or not cache.ev_spec then
        sync_image_elem(player, cache.ev_bg, "", 0, 0, 0, 0)
        sync_image_elem(player, cache.ev_accent, "", 0, 0, 0, 0)
        sync_image_elem(player, cache.ev_icon, "", 0, 0, 0, 0)
        sync_text_elem(player, cache.ev_title, "", P.hud_gold, 0, 0)
        sync_text_elem(player, cache.ev_detail, "", P.hud_white, 0, 0)
        return
    end

    local spec = cache.ev_spec
    local is_compact = (layout.tier == "compact")
    local ox = layout.toast_ox
    local oy = layout.toast_oy
    local has_detail = (spec.detail ~= nil and spec.detail ~= "")
    local icon_px = layout.icon_px
    local accent_hex = spec.accent_hex or P.gold
    local text_x = ox + (is_compact and 41 or 46)
    local text_max = math.max(16, layout.toast_max - 4)

    local bg_tex = is_compact and "tc_hud_toast_compact.png" or "tc_hud_toast_std.png"
    local rim_base = is_compact and "tc_hud_toast_rim_compact.png" or "tc_hud_toast_rim_std.png"
    local acc_tex = rim_base .. "^[multiply:" .. accent_hex
    local iscale = get_icon_scale(spec.icon, icon_px)
    local icon_x = ox + (is_compact and 12 or 13)
    local icon_y = oy + 15

    sync_image_elem(player, cache.ev_bg, bg_tex, 1, 1, ox, oy)
    sync_image_elem(player, cache.ev_accent, acc_tex, 1, 1, ox, oy)
    sync_image_elem(player, cache.ev_icon, spec.icon, iscale, iscale, icon_x, icon_y)

    local pname = player:get_player_name()
    local clamped_title = tc_core.clamp_hud_text(tc_core.resolve_player_text(pname, spec.title), text_max)
    if has_detail then
        local clamped_detail = tc_core.clamp_hud_text(tc_core.resolve_player_text(pname, spec.detail or ""), text_max)
        local title_y = oy + (is_compact and 9 or 10)
        local detail_y = oy + (is_compact and 27 or 29)
        sync_text_elem(player, cache.ev_title, clamped_title, spec.color or P.hud_gold, text_x, title_y)
        sync_text_elem(player, cache.ev_detail, clamped_detail, P.hud_white, text_x, detail_y)
    else
        local single_y = oy + (is_compact and 18 or 20)
        sync_text_elem(player, cache.ev_title, clamped_title, spec.color or P.hud_gold, text_x, single_y)
        sync_text_elem(player, cache.ev_detail, "", P.hud_white, 0, 0)
    end
end

---Synchronizes Zone 4 (Bottom-Center 3-Slice Pixel-Art Action / Hint Pill) for a single player.
---@param player ObjectRef
---@param cache table
---@param layout TcHudLayout
local function sync_action_pill(player, cache, layout)
    if (cache.act_ttl or 0) <= 0 or cache.act_line == "" then
        sync_image_elem(player, cache.act_bg, "", 0, 0, 0, 0)
        sync_image_elem(player, cache.act_icon, "", 0, 0, 0, 0)
        sync_text_elem(player, cache.act_text, "", P.hud_white, 0, 0)
        return
    end

    local pname = player:get_player_name()
    local is_compact = (layout.tier == "compact")
    local line = tc_core.clamp_hud_text(tc_core.resolve_player_text(pname, cache.act_line), layout.pill_max)
    local cp_len = utf8_codepoint_len(line)
    local icon_px = layout.icon_px
    local max_w = is_compact
        and math.min(352, math.floor(layout.lw * 0.44))
        or math.min(440, math.floor(layout.lw * 0.48))
    local pill_w = math.floor(tc_core.clamp(32 + icon_px + cp_len * 7, 156, math.max(160, max_w)))
    local pill_h = is_compact and 26 or 30
    local pill_oy = is_compact and -128 or -136
    local left_x = -math.floor(pill_w / 2)

    local cap_l = is_compact and "tc_hud_pill_compact_l.png" or "tc_hud_pill_l.png"
    local mid_c = is_compact and "tc_hud_pill_compact_c.png" or "tc_hud_pill_c.png"
    local cap_r = is_compact and "tc_hud_pill_compact_r.png" or "tc_hud_pill_r.png"
    local mid_w = math.max(16, pill_w - 20)
    local bg_tex = string.format(
        "[combine:%dx%d:0,0=%s:10,0=(%s\\^[resize\\:%dx%d):%d,0=%s",
        pill_w, pill_h, cap_l, mid_c, mid_w, pill_h, pill_w - 10, cap_r
    )
    local iscale = get_icon_scale(cache.act_icon_tex, icon_px)

    sync_image_elem(player, cache.act_bg, bg_tex, 1, 1, 0, pill_oy)
    sync_image_elem(player, cache.act_icon, cache.act_icon_tex, iscale, iscale, left_x + 12, pill_oy)
    sync_text_elem(
        player,
        cache.act_text,
        line,
        cache.act_color or P.hud_white,
        left_x + 12 + icon_px + 6,
        pill_oy
    )
end

---Re-evaluates Zone 2 (Top-Right Drop Plaque) and right-side `hudbars` spacing for a player.
---@param player ObjectRef
function tc_core.sync_player_drop_hud(player)
    if not player or not player:is_player() then
        return
    end
    local name = player:get_player_name()
    local cache = hud_cache[name]
    if not cache then
        return
    end
    local layout = tc_core.get_hud_layout(name)
    cache.tier = layout.tier
    sync_hudbars_layout(player, cache, layout)
    sync_drop_card(player, cache, layout)
    if (cache.ev_ttl or 0) > 0 then
        sync_event_toast(player, cache, layout)
    end
end

---Pushes or preempts a Zone 3 Priority Event Toast for a single player.
---@param player ObjectRef
---@param spec TcHudEventSpec
function tc_core.push_hud_event_player(player, spec)
    if not player or not player:is_player() or not spec then
        return
    end
    local name = player:get_player_name()
    local cache = hud_cache[name]
    if not cache then
        return
    end

    local prio = spec.priority or 1
    if (cache.ev_ttl or 0) > 0 and prio < (cache.ev_prio or 0) then
        return
    end

    cache.ev_prio = prio
    cache.ev_ttl = spec.ttl or 3.5
    cache.ev_spec = {
        priority = prio,
        icon = spec.icon or "tc_tool_guide.png",
        title = spec.title or "",
        detail = spec.detail or "",
        color = spec.color or P.hud_gold,
        accent_hex = spec.accent_hex or P.gold,
    }

    local layout = tc_core.get_hud_layout(name)
    sync_event_toast(player, cache, layout)
end

---Broadcasts a Zone 3 Priority Event Toast across all connected players.
---@param spec TcHudEventSpec
function tc_core.push_hud_event(spec)
    local players = core.get_connected_players()
    for i = 1, #players do
        tc_core.push_hud_event_player(players[i], spec)
    end
end

---Updates Zone 4 (Bottom-Center Action / Hint Pill) for a single player, coalescing rapid Bloom gains.
---@param player ObjectRef
---@param spec TcHudActionSpec
function tc_core.push_action_feedback(player, spec)
    if not player or not player:is_player() or not spec then
        return
    end
    local name = player:get_player_name()
    local cache = hud_cache[name]
    if not cache then
        return
    end

    local is_action = (spec.kind == "action" or spec.bloom ~= nil)
    if is_action then
        local gain = spec.bloom or 0.0
        if cache.act_kind == "action" and (cache.act_ttl or 0) > 0.6 then
            cache.act_bloom = (cache.act_bloom or 0.0) + gain
        else
            cache.act_bloom = gain
        end
        cache.act_kind = "action"
        cache.act_ttl = spec.ttl or 2.4
        cache.act_icon_tex = spec.icon or "tc_tool_trowel.png"
        cache.act_color = spec.color or P.hud_emerald
        local lbl = spec.label or S("Action")
        if cache.act_bloom > 0.01 then
            cache.act_line = S("+@1% Bloom · @2", string.format("%.1f", cache.act_bloom), lbl)
        else
            cache.act_line = lbl
        end
    else
        cache.act_kind = "hint"
        cache.act_bloom = 0.0
        cache.act_ttl = spec.ttl or 2.6
        cache.act_icon_tex = spec.icon or "tc_tool_guide.png"
        cache.act_color = spec.color or P.hud_aqua
        cache.act_line = spec.text or spec.label or ""
    end

    local layout = tc_core.get_hud_layout(name)
    sync_action_pill(player, cache, layout)
end

---Broadcasts Zone 4 Action / Combo feedback across all connected players.
---@param spec TcHudActionSpec
function tc_core.push_action_feedback_all(spec)
    local players = core.get_connected_players()
    for i = 1, #players do
        tc_core.push_action_feedback(players[i], spec)
    end
end

---Immediately clears transient Zone 3 Event Toast and Zone 4 Action Pill timers for a player.
---@param player ObjectRef
function tc_core.clear_player_hud_transients(player)
    if not player or not player:is_player() then
        return
    end
    local name = player:get_player_name()
    local cache = hud_cache[name]
    if not cache then
        return
    end
    local had_ev = (cache.ev_ttl or 0) > 0
    local had_act = (cache.act_ttl or 0) > 0
    cache.ev_ttl = 0
    cache.ev_prio = 0
    cache.ev_spec = nil
    cache.act_ttl = 0
    cache.act_kind = nil
    cache.act_bloom = 0.0
    cache.act_line = ""
    if had_ev or had_act then
        local layout = tc_core.get_hud_layout(name)
        if had_ev then
            sync_event_toast(player, cache, layout)
        end
        if had_act then
            sync_action_pill(player, cache, layout)
        end
    end
end

---Steps Zone 3 and Zone 4 transient HUD timers, emitting HUD packets strictly on expiry transitions.
---@param player ObjectRef
---@param dt number
function tc_core.step_hud_timers(player, dt)
    if not player or not player:is_player() then
        return
    end
    local name = player:get_player_name()
    local cache = hud_cache[name]
    if not cache then
        return
    end

    local ev_expired = false
    if (cache.ev_ttl or 0) > 0 then
        local next_ev = cache.ev_ttl - dt
        if next_ev <= 0 then
            cache.ev_ttl = 0
            cache.ev_prio = 0
            cache.ev_spec = nil
            ev_expired = true
        else
            cache.ev_ttl = next_ev
        end
    end

    local act_expired = false
    if (cache.act_ttl or 0) > 0 then
        local next_act = cache.act_ttl - dt
        if next_act <= 0 then
            cache.act_ttl = 0
            cache.act_kind = nil
            cache.act_bloom = 0.0
            cache.act_line = ""
            act_expired = true
        else
            cache.act_ttl = next_act
        end
    end

    if ev_expired or act_expired then
        local layout = tc_core.get_hud_layout(name)
        if ev_expired then
            sync_event_toast(player, cache, layout)
        end
        if act_expired then
            sync_action_pill(player, cache, layout)
        end
    end
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

---Computes the responsive Top-Center pixel-art Banner plaque texture (1:1 crisp native on standard/wide/compact).
---@param layout TcHudLayout
---@param has_l3 boolean
---@return string
local function compute_top_bg_tex(layout, has_l3)
    local tier = layout.tier
    local base_tex
    local native_w
    local native_h
    if tier == "compact" then
        base_tex = has_l3 and "tc_hud_banner_compact.png" or "tc_hud_banner_compact_2l.png"
        native_w = 384
        native_h = has_l3 and 66 or 48
    elseif tier == "standard" then
        base_tex = has_l3 and "tc_hud_banner_std.png" or "tc_hud_banner_std_2l.png"
        native_w = 544
        native_h = has_l3 and 68 or 50
    else
        base_tex = has_l3 and "tc_hud_banner_wide.png" or "tc_hud_banner_wide_2l.png"
        native_w = 640
        native_h = has_l3 and 68 or 50
    end
    if layout.banner_w < native_w then
        return string.format("%s^[resize:%dx%d", base_tex, layout.banner_w, native_h)
    end
    return base_tex
end

---Initializes custom hudbars and the 4-zone responsive Alchemical HUD for a joining player.
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

    local effect_slots = {}
    for i = 1, EFFECT_SLOT_COUNT do
        hb.init_hudbar(player, EFFECT_SLOT_IDS[i], 0, 10, true)
        effect_slots[i] = {
            hidden = true,
            eff_id = nil,
            val_t = 0,
            max_t = 10,
        }
    end

    local layout = tc_core.get_hud_layout(name)
    local is_compact = (layout.tier == "compact")
    local l1, c1, l2, c2, l3, c3 = build_banner_lines(name, layout)
    local top_bg_tex = compute_top_bg_tex(layout, l3 ~= "")

    local top_pos = {x = 0.5, y = 0.0}
    local top_align = {x = 0, y = 1}
    local e1_y = is_compact and 9 or 10
    local e2_y = is_compact and 30 or 31
    local e3_y = is_compact and 50 or 51
    local top_bg = add_tracked_image(player, top_pos, top_align, 0, 4, top_bg_tex, 1, 1, 5)
    local e1 = add_tracked_text(player, top_pos, top_align, 0, e1_y, l1, c1, 1, 10)
    local e2 = add_tracked_text(player, top_pos, top_align, 0, e2_y, l2, c2, 0, 10)
    local e3 = add_tracked_text(player, top_pos, top_align, 0, e3_y, l3, c3, 0, 10)

    local right_pos = {x = 1.0, y = 0.0}
    local right_align = {x = 1, y = 1}
    local dox = layout.drop_ox
    local doy = layout.drop_oy
    local drop_bg = add_tracked_image(player, right_pos, right_align, dox, doy, "", 0, 0, 6)
    local drop_accent = add_tracked_image(player, right_pos, right_align, dox, doy, "", 0, 0, 7)
    local drop_header = add_tracked_text(player, right_pos, right_align, dox + 11, doy + 5, "", P.hud_gold, 1, 10)
    local drop_icons = {}
    for k = 1, 4 do
        drop_icons[k] = add_tracked_image(player, right_pos, right_align, dox + 14, doy + 28, "", 0, 0, 10)
    end
    local drop_arrow = add_tracked_text(player, right_pos, right_align, dox + 42, doy + 32, "", P.hud_muted, 0, 10)
    local drop_tool_icon = add_tracked_image(player, right_pos, right_align, dox + 58, doy + 28, "", 0, 0, 10)
    local drop_desc = add_tracked_text(player, right_pos, right_align, dox + 11, doy + 56, "", P.hud_white, 0, 10)

    local bot_left_pos = {x = 0.0, y = 1.0}
    local left_align = {x = 1, y = 1}
    local tox = layout.toast_ox
    local toy = layout.toast_oy
    local ev_bg = add_tracked_image(player, bot_left_pos, left_align, tox, toy, "", 0, 0, 6)
    local ev_accent = add_tracked_image(player, bot_left_pos, left_align, tox, toy, "", 0, 0, 7)
    local ev_icon = add_tracked_image(player, bot_left_pos, left_align, tox + 13, toy + 15, "", 0, 0, 10)
    local ev_title = add_tracked_text(player, bot_left_pos, left_align, tox + 46, toy + 10, "", P.hud_gold, 1, 10)
    local ev_detail = add_tracked_text(player, bot_left_pos, left_align, tox + 46, toy + 29, "", P.hud_white, 0, 10)

    local bot_pos = {x = 0.5, y = 1.0}
    local act_bg = add_tracked_image(player, bot_pos, {x = 0, y = 0}, 0, -136, "", 0, 0, 8)
    local act_icon = add_tracked_image(player, bot_pos, {x = 1, y = 0}, -80, -136, "", 0, 0, 10)
    local act_text = add_tracked_text(player, bot_pos, {x = 1, y = 0}, -50, -136, "", P.hud_white, 0, 10)

    local cache = {
        tier = layout.tier,
        banner_w = layout.banner_w,
        hb_ox = hb.settings.start_offset_left.x,
        hb_start_y = hb.settings.start_offset_left.y,
        hb_vmargin = hb.settings.vmargin,
        top_bg = top_bg,
        e1 = e1,
        e2 = e2,
        e3 = e3,
        drop_bg = drop_bg,
        drop_accent = drop_accent,
        drop_header = drop_header,
        drop_icons = drop_icons,
        drop_arrow = drop_arrow,
        drop_tool_icon = drop_tool_icon,
        drop_desc = drop_desc,
        ev_bg = ev_bg,
        ev_accent = ev_accent,
        ev_icon = ev_icon,
        ev_title = ev_title,
        ev_detail = ev_detail,
        ev_ttl = 0,
        ev_prio = 0,
        ev_spec = nil,
        act_bg = act_bg,
        act_icon = act_icon,
        act_text = act_text,
        act_ttl = 0,
        act_kind = nil,
        act_bloom = 0.0,
        act_icon_tex = "",
        act_color = P.hud_white,
        act_line = "",
        bloom = bloom_v,
        vit = vit_v,
        temp = temp_v,
        ph = ph_v,
        effect_slots = effect_slots,
        waypoints = {},
        max_wp_idx = 0,
        ping_wp_id = nil,
        ping_token = 0,
        cargo_hud_id = nil,
        cargo_ox = nil,
    }
    hud_cache[name] = cache

    sync_hudbars_layout(player, cache, layout)
    sync_drop_card(player, cache, layout)
    tc_core.sync_player_effect_hudbars(player)
    tc_core.sync_player_cargo_hud(player)
end

---Synchronizes the dynamic Luanti 5.18 `inventory` + `text2` Trowel Tongs Cargo HUD socket (Option A).
---Shown beside the hotbar strictly while the player's Trowel carries a scooped reagent; removed when empty.
---@param player ObjectRef
function tc_core.sync_player_cargo_hud(player)
    if not player or not player:is_player() then
        return
    end
    local name = player:get_player_name()
    local cache = hud_cache[name]
    if not cache then
        return
    end

    local inv = player:get_inventory()
    local st = inv and inv:get_stack("trowel_cargo", 1) or nil
    local has_cargo = (st ~= nil and not st:is_empty()) and tc_core.state.running

    if has_cargo then
        local layout = tc_core.get_hud_layout(name)
        local cargo_ox = math.max(-math.floor(layout.lw / 2) + 8, -308)
        local cargo_oy = -58
        if not cache.cargo_hud_id then
            cache.cargo_hud_id = player:hud_add({
                type = "inventory",
                position = {x = 0.5, y = 1.0},
                offset = {x = cargo_ox, y = cargo_oy},
                alignment = {x = 1, y = 1},
                direction = 0,
                number = 1,
                text = "trowel_cargo",
                text2 = "tc_hud_tongs_slot.png",
                z_index = 12,
            })
            cache.cargo_ox = cargo_ox
        elseif cache.cargo_ox ~= cargo_ox then
            cache.cargo_ox = cargo_ox
            player:hud_change(cache.cargo_hud_id, "offset", {x = cargo_ox, y = cargo_oy})
        end
    elseif cache.cargo_hud_id then
        player:hud_remove(cache.cargo_hud_id)
        cache.cargo_hud_id = nil
        cache.cargo_ox = nil
    end
end

---Synchronizes the pooled temporary-effect hudbars (`effect_1..effect_6`) for a player.
---Packs active effects contiguously with zero vertical gaps and deduplicates packets per slot.
---@param player ObjectRef
function tc_core.sync_player_effect_hudbars(player)
    if not player or not player:is_player() then
        return
    end
    local cache = hud_cache[player:get_player_name()]
    if not cache then
        return
    end

    local slots = cache.effect_slots
    local slot_idx = 0
    for i = 1, EFFECT_SLOT_COUNT do
        local eff_id = tc_core.EFFECT_ORDER[i]
        local rem, max_dur = tc_core.get_effect_state(player, eff_id)
        if rem > 0 then
            slot_idx = slot_idx + 1
            local slot = slots[slot_idx]
            local slot_id = EFFECT_SLOT_IDS[slot_idx]
            local def = tc_core.EFFECT_DEFS[eff_id]
            local val_t = math.max(1, math.floor(rem * 10 + 0.5))
            local max_t = math.max(val_t, math.floor(max_dur * 10 + 0.5))
            local disp_val = val_t / 10.0
            local disp_max = max_t / 10.0

            if slot.hidden then
                hb.change_hudbar(
                    player, slot_id, disp_val, disp_max,
                    def.icon_tex, nil, def.bar_tex, def.hud_label
                )
                hb.unhide_hudbar(player, slot_id)
                slot.hidden = false
                slot.eff_id = eff_id
                slot.val_t = val_t
                slot.max_t = max_t
            elseif slot.eff_id ~= eff_id then
                hb.change_hudbar(
                    player, slot_id, disp_val, disp_max,
                    def.icon_tex, nil, def.bar_tex, def.hud_label
                )
                slot.eff_id = eff_id
                slot.val_t = val_t
                slot.max_t = max_t
            elseif slot.val_t ~= val_t or slot.max_t ~= max_t then
                hb.change_hudbar(player, slot_id, disp_val, disp_max)
                slot.val_t = val_t
                slot.max_t = max_t
            end
        end
    end

    for k = slot_idx + 1, EFFECT_SLOT_COUNT do
        local slot = slots[k]
        if not slot.hidden then
            local slot_id = EFFECT_SLOT_IDS[k]
            hb.change_hudbar(player, slot_id, 0, 10)
            hb.hide_hudbar(player, slot_id)
            slot.hidden = true
            slot.eff_id = nil
            slot.val_t = 0
            slot.max_t = 10
        end
    end
end

---Synchronizes 3D spatial distress waypoints for low-Vitality (<45%) or Withered Sprouts.
---@param player ObjectRef
---@param cache table
local function sync_distress_waypoints(player, cache)
    local pname = player:get_player_name()
    local s = tc_core.state
    local plants = s.plants
    local prev_max = cache.max_wp_idx or 0
    cache.max_wp_idx = math.max(prev_max, #plants)

    for i = 1, #plants do
        local p = plants[i]
        local show = s.running and (p.withered or p.vitality < 45.0)
        local wp = cache.waypoints[i]
        if show then
            local raw_label = p.withered
                and S("✖ Sprout #@1 WILTED!", p.index)
                or S("⚠ Sprout #@1 (@2%)", p.index, string.format("%.0f", p.vitality))
            local label = tc_core.resolve_player_text(pname, raw_label)
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
    local bloom_str = string.format("%.0f", target.bloom or 0.0)
    local vit_str = string.format("%.0f", target.vitality)
    local status = target.withered
        and S("WILTED · @1% Bloom", bloom_str)
        or S("@1% Bloom · @2% HP", bloom_str, vit_str)

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

    local sprout_tex = target.withered
        and "tc_crucible_sprout_withered.png"
        or string.format("tc_crucible_sprout_%d.png", target.stage or 1)
    tc_core.push_hud_event({
        priority = 2,
        icon = sprout_tex,
        title = S("✦ Room #@1 Marked [@2]", target.index, pname),
        detail = S("@1 · @2 Hazards", status, target.hazards_near),
        color = P.hud_gold,
        accent_hex = P.gold,
        ttl = 3.6,
    })

    local raw_wp_label = S("✦ Room #@1 [@2]", target.index, pname)
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
                name = tc_core.resolve_player_text(pl_name, raw_wp_label),
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

---Updates hudbars, Top-Center Banner, and Top-Right Drop Plaque for a player, deduplicating all packets.
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

    local layout = tc_core.get_hud_layout(name)
    local is_compact = (layout.tier == "compact")
    local geom_changed = (cache.tier ~= layout.tier or cache.banner_w ~= layout.banner_w)
    cache.tier = layout.tier
    cache.banner_w = layout.banner_w

    sync_hudbars_layout(player, cache, layout)

    local l1, c1, l2, c2, l3, c3 = build_banner_lines(name, layout)
    local top_bg_tex = compute_top_bg_tex(layout, l3 ~= "")

    sync_image_elem(player, cache.top_bg, top_bg_tex, 1, 1, 0, 4)
    sync_text_elem(player, cache.e1, l1, c1, 0, is_compact and 9 or 10)
    sync_text_elem(player, cache.e2, l2, c2, 0, is_compact and 30 or 31)
    sync_text_elem(player, cache.e3, l3, c3, 0, is_compact and 50 or 51)

    sync_drop_card(player, cache, layout)
    if geom_changed then
        if (cache.ev_ttl or 0) > 0 then
            sync_event_toast(player, cache, layout)
        end
        if (cache.act_ttl or 0) > 0 then
            sync_action_pill(player, cache, layout)
        end
    end

    tc_core.sync_player_effect_hudbars(player)
    sync_distress_waypoints(player, cache)
    tc_core.sync_player_cargo_hud(player)
end
