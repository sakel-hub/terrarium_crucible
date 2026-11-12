---@class TcWindowSpec
---@field w number Window width in real formspec units
---@field h number Window height in real formspec units
---@field title string Uppercase or prominent window heading
---@field subtitle? string Optional readable subtitle / guidance line
---@field accent? string Optional header rule accent color
---@field body string Inner formspec elements

---@class TcAssetsUI
---@field get_prepend fun(): string
---@field ht_escape fun(text: string): string
---@field hypertext fun(x: number, y: number, w: number, h: number, name: string, txt: string, sz?: integer): string
---@field card fun(x: number, y: number, w: number, h: number, accent_hex?: string, bg_hex?: string): string
---@field tooltip_elem fun(elem_name: string, text: string): string
---@field tooltip_rect fun(x: number, y: number, w: number, h: number, text: string): string
---@field button function
---@field item_badge fun(x: number, y: number, size: number, item: string, tip?: string, accent?: string): string
---@field stat_box function
---@field readonly_field function
---@field spine_label fun(x: number, y: number, text: string, color_hex?: string): string
---@field inv_slots_bg fun(x: number, y: number, cols: integer, rows: integer): string
---@field window fun(spec: TcWindowSpec): string
local ui = {}

local P = tc_assets.PALETTE

local VARIANT_STYLES = {
    default = {bg = "#2A2142", hover = "#3A2E5C", press = "#1F1832", border = "#7A62B8", text = P.text_primary},
    primary = {bg = "#1D4735", hover = "#276149", press = "#153628", border = "#52CC8A", text = "#F2FFF7"},
    active  = {bg = "#27435E", hover = "#32577A", press = "#1D3347", border = "#7CE8FF", text = "#F2FCFF"},
    gold    = {bg = "#4A3819", hover = "#634B22", press = "#362811", border = "#E5B84B", text = "#FFF8E6"},
    danger  = {bg = "#4F1E29", hover = "#692837", press = "#3B151E", border = "#FF8585", text = "#FFF0F2"},
}

---Returns global formspec prepend styling applied to all player formspecs.
---@return string
function ui.get_prepend()
    return table.concat({
        "bgcolor[" .. P.bg_backdrop .. ";true]",
        "background9[0,0;1,1;tc_gui_formbg.png;true;10]",
        "listcolors[#181228D9;#3A2E5C;#7A62B8;" .. P.bg_tooltip .. ";" .. P.text_primary .. "]",
        "listimages[tc_gui_hb_bg.png;tc_gui_slot_hover.png]",
        "style_type[label;textcolor=" .. P.text_primary .. ";font_size=*1.02]",
        "style_type[button,button_exit;bgcolor=#2A2142;bgcolor_hovered=#3A2E5C;" ..
            "bgcolor_pressed=#1F1832;textcolor=" .. P.text_primary .. ";font=bold]",
        "style_type[tabheader;bgcolor=#1E1830;textcolor=" .. P.text_secondary ..
            ";bgcolor_hovered=#2E254A;bgcolor_pressed=#3A2E5C]",
        "style_type[table;textcolor=" .. P.text_primary .. "]",
    })
end

---Escapes `\`, `<`, and `>` for safe inclusion inside Luanti `hypertext[]` markup (`&` is literal, never HTML).
---@param text string
---@return string
function ui.ht_escape(text)
    return core.hypertext_escape(tostring(text or ""))
end

---Creates an AA-accessible hypertext block with readable base font size and colors.
---@param x number
---@param y number
---@param w number
---@param h number
---@param name string
---@param markup string Markup string using Luanti hypertext tags
---@param font_size? integer Base font size (defaults to 15)
---@return string
function ui.hypertext(x, y, w, h, name, markup, font_size)
    local global_tag = string.format(
        "<global color=%s size=%d font=regular>",
        P.text_primary,
        font_size or 15
    )
    return string.format(
        "hypertext[%.2f,%.2f;%.2f,%.2f;%s;%s]",
        x, y, w, h, name, core.formspec_escape(global_tag .. markup)
    )
end

---Creates a dark obsidian-plum card container with an optional top accent border.
---@param x number
---@param y number
---@param w number
---@param h number
---@param accent_hex? string Optional top rule color
---@param bg_hex? string Optional card background color
---@return string
function ui.card(x, y, w, h, accent_hex, bg_hex)
    local parts = {
        string.format("box[%.2f,%.2f;%.2f,%.2f;%s]", x, y, w, h, bg_hex or P.bg_card),
    }
    if accent_hex then
        parts[#parts + 1] = string.format("box[%.2f,%.2f;%.2f,0.05;%s]", x, y, w, accent_hex)
    end
    return table.concat(parts)
end

---Builds an AA-accessible tooltip bound to a named formspec element.
---@param elem_name string
---@param text string
---@return string
function ui.tooltip_elem(elem_name, text)
    if not text or text == "" then
        return ""
    end
    return string.format(
        "tooltip[%s;%s;%s;%s]",
        elem_name, core.formspec_escape(text), P.bg_tooltip, P.text_primary
    )
end

---Builds an AA-accessible area tooltip over a rectangular region.
---@param x number
---@param y number
---@param w number
---@param h number
---@param text string
---@return string
function ui.tooltip_rect(x, y, w, h, text)
    if not text or text == "" then
        return ""
    end
    return string.format(
        "tooltip[%.2f,%.2f;%.2f,%.2f;%s;%s;%s]",
        x, y, w, h, core.formspec_escape(text), P.bg_tooltip, P.text_primary
    )
end

---Builds a themed button (or button_exit) with custom variant styling and hover tooltip.
---@param x number
---@param y number
---@param w number
---@param h number
---@param name string Element identifier
---@param label string Button text
---@param variant? string "default" | "primary" | "active" | "gold" | "danger"
---@param tip? string Optional hover tooltip explanation
---@param is_exit? boolean True to emit button_exit
---@return string
function ui.button(x, y, w, h, name, label, variant, tip, is_exit)
    local v = VARIANT_STYLES[variant or "default"] or VARIANT_STYLES.default
    local tag = is_exit and "button_exit" or "button"
    local parts = {
        string.format(
            "style[%s;bgcolor=%s;bgcolor_hovered=%s;bgcolor_pressed=%s;textcolor=%s;font=bold]",
            name, v.bg, v.hover, v.press, v.text
        ),
        -- Subtle bottom accent bar under button for visual affordance
        string.format("box[%.2f,%.2f;%.2f,0.05;%s]", x, y + h - 0.05, w, v.border),
        string.format("%s[%.2f,%.2f;%.2f,%.2f;%s;%s]", tag, x, y, w, h, name, core.formspec_escape(label)),
    }
    if tip and tip ~= "" then
        parts[#parts + 1] = ui.tooltip_elem(name, tip)
    end
    return table.concat(parts)
end

---Renders a framed item icon badge with an interactive hover tooltip.
---@param x number
---@param y number
---@param size number Badge width & height
---@param itemname string Registered itemstring (e.g. "tc_elements:brimstone")
---@param tip? string Custom hover tooltip (falls back to the item's registered description)
---@param accent_hex? string Optional frame accent color
---@return string
function ui.item_badge(x, y, size, itemname, tip, accent_hex)
    local tooltip_text = tip
    if not tooltip_text or tooltip_text == "" then
        local def = core.registered_items[itemname]
        tooltip_text = def and def.description or itemname
    end
    local pad = size * 0.1
    local parts = {
        string.format("box[%.2f,%.2f;%.2f,%.2f;%s]", x, y, size, size, P.bg_inset),
        string.format("box[%.2f,%.2f;%.2f,0.04;%s]", x, y, size, accent_hex or P.border_arcane),
        string.format(
            "item_image[%.2f,%.2f;%.2f,%.2f;%s]",
            x + pad, y + pad, size - pad * 2, size - pad * 2, itemname
        ),
        ui.tooltip_rect(x, y, size, size, tooltip_text),
    }
    return table.concat(parts)
end

---Renders a clean AA-accessible stat readout card with hover tooltip explaining the metric.
---@param x number
---@param y number
---@param w number
---@param h number
---@param label string Upper small caption
---@param value string Main bold metric value
---@param accent_hex? string Value & top rule accent color
---@param tip? string Hover explanation of this metric
---@return string
function ui.stat_box(x, y, w, h, label, value, accent_hex, tip)
    local col = accent_hex or P.gold
    local markup = string.format(
        "<style color=%s size=13>%s</style>\n<style color=%s size=16><b>%s</b></style>",
        P.text_secondary, ui.ht_escape(label),
        col, ui.ht_escape(value)
    )
    local parts = {
        ui.card(x, y, w, h, col, P.bg_inset),
        ui.hypertext(x + 0.18, y + 0.12, w - 0.30, h - 0.16, "", markup, 14),
    }
    if tip and tip ~= "" then
        parts[#parts + 1] = ui.tooltip_rect(x, y, w, h, tip)
    end
    return table.concat(parts)
end

---Renders a Luanti 5.18 formspec_version[12] read-only (`editable=false`) copyable text field.
---@param x number
---@param y number
---@param w number
---@param h number
---@param name string
---@param label string
---@param value string
---@param tip? string
---@return string
function ui.readonly_field(x, y, w, h, name, label, value, tip)
    local parts = {
        string.format(
            "style[%s;editable=false;bgcolor=%s;textcolor=%s;border=true]",
            name, P.bg_inset, P.gold
        ),
        string.format(
            "field[%.2f,%.2f;%.2f,%.2f;%s;%s;%s]",
            x, y, w, h, name,
            core.formspec_escape(label or ""),
            core.formspec_escape(value or "")
        ),
    }
    if tip and tip ~= "" then
        parts[#parts + 1] = ui.tooltip_elem(name, tip)
    end
    return table.concat(parts)
end

---Renders a vertical book-spine ornament label using Luanti 5.18's `vertlabel` `textcolor` support.
---@param x number
---@param y number
---@param text string
---@param color_hex? string
---@return string
function ui.spine_label(x, y, text, color_hex)
    local col = color_hex or P.gold
    return table.concat({
        string.format("style_type[vertlabel;textcolor=%s;font=bold]", col),
        string.format("vertlabel[%.2f,%.2f;%s]", x, y, core.formspec_escape(text or "")),
        string.format("style_type[vertlabel;textcolor=%s;font=regular]", P.text_primary),
    })
end

---Renders slot background frames aligned with formspec_version[12] `list[...]` (1.25 real-unit step).
---@param x number
---@param y number
---@param cols integer
---@param rows integer
---@return string
function ui.inv_slots_bg(x, y, cols, rows)
    local out = {}
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            out[#out + 1] = string.format(
                "image[%.2f,%.2f;1,1;tc_gui_hb_bg.png]",
                x + c * 1.25, y + r * 1.25
            )
        end
    end
    return table.concat(out)
end

---Builds a complete formspec_version[12] window using the unified Terrarium Crucible theme.
---@param spec TcWindowSpec
---@return string
function ui.window(spec)
    local accent = spec.accent or P.border_gold
    local has_sub = spec.subtitle and spec.subtitle ~= ""
    local rule_y = has_sub and 1.26 or 0.92

    local header = {
        string.format("formspec_version[%d]", tc_assets.FORMSPEC_VERSION),
        string.format("size[%.2f,%.2f]", spec.w, spec.h),
        ui.get_prepend(),
        string.format("box[0.35,0.30;%.2f,%.2f;%s]", spec.w - 0.70, rule_y - 0.24, P.bg_inset),
        ui.hypertext(
            0.55, 0.36, spec.w - 1.10, has_sub and 0.88 or 0.52,
            "",
            string.format(
                "<style color=%s size=18><b>%s</b></style>%s",
                accent,
                ui.ht_escape(spec.title),
                has_sub and ("\n<style color=" .. P.text_secondary .. " size=13>" ..
                    ui.ht_escape(spec.subtitle) .. "</style>") or ""
            ),
            15
        ),
        string.format("box[0.35,%.2f;%.2f,0.05;%s]", rule_y, spec.w - 0.70, accent),
        spec.body or "",
    }
    return table.concat(header)
end

tc_assets.ui = ui
