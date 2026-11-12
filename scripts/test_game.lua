-- Headless runtime, gameplay mechanics, audio & WCAG AA verification harness for Terrarium Crucible
local script_src = debug.getinfo(1, "S").source:gsub("^@", "")
local script_dir = script_src:match("^(.*)[/\\][^/\\]+$") or "."
local game_dir = script_dir .. "/.."
_G.unpack = _G.unpack or table.unpack

local registered_nodes = {}
local registered_tools = {}
local registered_craftitems = {}
local registered_items = {}
local overridden_items = {}
local chatcommands = {}
local node_world = {}
local meta_world = {}
local shown_formspecs = {}
local globalsteps = {}
local join_cbs = {}
local leave_cbs = {}
local mods_loaded_cbs = {}
local hpchange_cbs = {}
local field_cbs = {}
local spawned_entities = {}
local current_mod = ""
local mock_timeofday = 18375 / 24000
local mock_us_time = 10000000
local mock_us_step = 5000000
local mock_windows = {}
local mock_player_langs = {}
local mock_escape_translate_mode = false
local po_cache = {}

local function pos_key(p)
    return string.format("%d,%d,%d", math.floor(p.x + 0.5), math.floor(p.y + 0.5), math.floor(p.z + 0.5))
end

vector = {
    new = function(x, y, z) return {x = x or 0, y = y or 0, z = z or 0} end,
    zero = function() return {x = 0, y = 0, z = 0} end,
    add = function(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end,
    subtract = function(a, b) return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z} end,
    multiply = function(a, s) return {x = a.x * s, y = a.y * s, z = a.z * s} end,
    offset = function(p, dx, dy, dz) return {x = p.x + dx, y = p.y + dy, z = p.z + dz} end,
    round = function(p) return {x = math.floor(p.x + 0.5), y = math.floor(p.y + 0.5), z = math.floor(p.z + 0.5)} end,
    distance = function(a, b)
        local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
        return math.sqrt(dx * dx + dy * dy + dz * dz)
    end,
    length = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end,
    normalize = function(v)
        local len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        if len == 0 then return {x = 0, y = 0, z = 0} end
        return {x = v.x / len, y = v.y / len, z = v.z / len}
    end,
}

table.copy = function(t)
    local out = {}
    for k, v in pairs(t) do
        out[k] = (type(v) == "table" and not v._is_itemstack) and table.copy(v) or v
    end
    return out
end

function ItemStack(spec)
    if type(spec) == "table" and spec._is_itemstack then
        local cp = ItemStack(spec.name)
        cp.count = spec.count
        cp.wear = spec.wear
        for k, v in pairs(spec._meta) do cp._meta[k] = v end
        return cp
    end
    local raw = tostring(spec or "")
    local name = ""
    local cnt = 0
    if raw ~= "" then
        -- Luanti 5.18 strict itemstring parser: reject leading/trailing whitespace or malformed tokens
        local only_name = raw:match("^([:%w_%.%-]+)$")
        if only_name then
            name = only_name
            cnt = 1
        else
            local parsed_name, parsed_cnt = raw:match("^([:%w_%.%-]+)%s+(%d+)$")
            if parsed_name and parsed_cnt then
                cnt = tonumber(parsed_cnt) or 0
                name = (cnt > 0) and parsed_name or ""
            else
                -- Malformed itemstring rejected as empty stack in Luanti 5.18
                name = ""
                cnt = 0
            end
        end
    end
    local st = {
        _is_itemstack = true,
        name = name,
        count = cnt,
        wear = 0,
        _meta = {},
    }
    function st:get_name() return self.name end
    function st:get_count() return self.count end
    function st:set_count(c)
        self.count = math.max(0, math.floor(tonumber(c) or 0))
        if self.count == 0 then self.name = "" end
    end
    function st:is_empty() return self.count <= 0 or self.name == "" end
    function st:set_wear(w) self.wear = w end
    function st:get_wear() return self.wear end
    function st:take_item(n)
        self.count = math.max(0, self.count - (n or 1))
        if self.count == 0 then self.name = "" end
        return self
    end
    function st:get_meta()
        local m = self._meta
        return {
            set_string = function(_, k, v) m[k] = tostring(v or "") end,
            get_string = function(_, k) return tostring(m[k] or "") end,
            set_int = function(_, k, v) m[k] = math.floor(tonumber(v) or 0) end,
            get_int = function(_, k) return math.floor(tonumber(m[k]) or 0) end,
        }
    end
    return st
end

function PcgRandom(seed)
    math.randomseed(seed or 12345)
    local rng = {}
    function rng:next(min_v, max_v)
        return math.random(min_v, max_v)
    end
    return rng
end

VoxelArea = {}
function VoxelArea:new(o)
    local minp, maxp = o.MinEdge, o.MaxEdge
    local sx = (maxp.x - minp.x + 1)
    local sy = (maxp.y - minp.y + 1)
    local va = {
        MinEdge = minp,
        MaxEdge = maxp,
        ystride = sx,
        zstride = sx * sy,
    }
    function va:index(x, y, z)
        return (z - minp.z) * self.zstride + (y - minp.y) * self.ystride + (x - minp.x) + 1
    end
    return va
end

local content_ids = {air = 0}
local id_to_name = {[0] = "air"}
local next_cid = 1

local mock_players = {}

local function make_mock_player(name)
    local hud_elems = {}
    local next_hud_id = 0
    local inv_lists = {main = {}, craft = {}}
    local inv_sizes = {main = 8, craft = 9}
    local p = {
        _name = name,
        _hp = 20,
        _pos = {x = 0, y = 1.5, z = -2.8},
        _vel = {x = 0, y = 0, z = 0},
        _wield = ItemStack(""),
        _wield_idx = 1,
        _ctrl = {aux1 = false, up = false, zoom = false},
        _props = {
            hp_max = 20,
            breath_max = 10,
            eye_height = 1.47,
            visual_size = {x = 1, y = 1, z = 1},
            collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
        },
        _anim = {x = 0, y = 0},
        _physics_calls = 0,
        _fov = 0,
        _fov_is_mult = false,
        _fov_trans = 0,
        _fov_calls = 0,
        _fov_history = {},
        _light_calls = 0,
        _lighting = nil,
        _sky_calls = 0,
        _sky = nil,
        _sun = nil,
        _moon = nil,
        _stars = nil,
        _clouds = nil,
        _dn_ratio = nil,
        _prepend = "",
        _hud_changes = 0,
        _hud_elems = hud_elems,
    }
    function p:is_player() return true end
    function p:is_valid() return true end
    function p:get_player_name() return self._name end
    function p:get_hp() return self._hp end
    function p:set_hp(v, reason)
        v = math.max(0, math.min(20, math.floor(tonumber(v) or 0)))
        if reason and not self._in_hpchange and v ~= self._hp then
            local oldhp = self._hp
            local delta = v - oldhp
            self._in_hpchange = true
            for _, fn in ipairs(hpchange_cbs) do
                local res = fn(self, delta, reason)
                if res ~= nil then
                    delta = res
                end
            end
            self._in_hpchange = false
            if delta == 0 then
                return
            end
            self._hp = math.max(0, math.min(20, oldhp + delta))
            return
        end
        self._hp = v
    end
    function p:get_breath() return 10 end
    function p:get_pos() return self._pos end
    function p:set_pos(pos) self._pos = table.copy(pos) end
    function p:get_velocity() return self._vel end
    function p:get_attach() return nil end
    function p:set_detach() end
    function p:get_children() return {} end
    function p:get_look_dir() return {x = 0, y = 0, z = 1} end
    function p:get_look_horizontal() return 0 end
    function p:get_look_vertical() return 0 end
    function p:set_look_horizontal(_) end
    function p:get_player_control() return self._ctrl end
    function p:get_player_control_bits() return 0 end
    function p:get_wielded_item() return self._wield end
    function p:set_wielded_item(st) self._wield = ItemStack(st) end
    function p:get_wield_index() return self._wield_idx end
    function p:get_properties() return self._props end
    function p:set_properties(pr)
        for k, v in pairs(pr or {}) do self._props[k] = v end
    end
    function p:set_animation(rng, spd, blend, loop) self._anim = {rng = rng, spd = spd, blend = blend, loop = loop} end
    function p:get_animation() return self._anim.rng or {x = 0, y = 0}, self._anim.spd or 30, 0, true end
    function p:set_local_animation(_, _, _, _) end
    function p:get_local_animation() return {x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, 30 end
    function p:set_eye_offset(_, _) end
    function p:set_bone_override(_, _) end
    function p:set_bone_position(_, _, _) end
    function p:set_formspec_prepend(s) self._prepend = tostring(s or "") end
    function p:get_formspec_prepend() return self._prepend end
    function p:hud_set_hotbar_itemcount(_) end
    function p:hud_set_hotbar_image(_) end
    function p:hud_set_hotbar_selected_image(_) end
    function p:hud_set_flags(_) end
    function p:hud_get_flags() return {healthbar = true, breathbar = true} end
    function p:set_sky(def)
        self._sky_calls = self._sky_calls + 1
        self._sky = table.copy(def or {})
    end
    function p:get_sky(_) return self._sky end
    function p:set_sun(def) self._sun = table.copy(def or {}) end
    function p:get_sun() return self._sun end
    function p:set_moon(def) self._moon = table.copy(def or {}) end
    function p:get_moon() return self._moon end
    function p:set_stars(def) self._stars = table.copy(def or {}) end
    function p:get_stars() return self._stars end
    function p:set_clouds(def) self._clouds = table.copy(def or {}) end
    function p:get_clouds() return self._clouds end
    function p:override_day_night_ratio(r) self._dn_ratio = r end
    function p:get_day_night_ratio() return self._dn_ratio end
    function p:set_fov(fov, is_mult, trans)
        self._fov_calls = self._fov_calls + 1
        self._fov = fov or 0
        self._fov_is_mult = (is_mult == true)
        self._fov_trans = trans or 0
        table.insert(self._fov_history, {fov = self._fov, is_mult = self._fov_is_mult, trans = self._fov_trans})
    end
    function p:get_fov() return self._fov, self._fov_is_mult, self._fov_trans end
    function p:set_lighting(def)
        if def and def.static then
            assert(type(def.static.light_curve) == "table" and #def.static.light_curve == 16,
                "Luanti 5.18 set_lighting static.light_curve must have 16 entries")
            for idx = 1, 16 do
                local lv = def.static.light_curve[idx]
                assert(type(lv) == "number" and lv >= 0 and lv <= 255 and math.floor(lv) == lv,
                    "static.light_curve entry must be uint8 in 0..255")
            end
            assert(def.static.light_curve[16] == 255,
                "Luanti 5.18 static.light_curve[16] (full light) must equal 255")
            assert(type(def.static.ao_gamma) == "number" and def.static.ao_gamma > 0,
                "Luanti 5.18 static.ao_gamma must be positive number")
        end
        self._light_calls = self._light_calls + 1
        self._lighting = table.copy(def or {})
    end
    function p:get_lighting() return self._lighting end
    function p:set_physics_override(_) self._physics_calls = self._physics_calls + 1 end
    function p:hud_add(def)
        next_hud_id = next_hud_id + 1
        hud_elems[next_hud_id] = table.copy(def)
        return next_hud_id
    end
    function p:hud_change(id, stat, val)
        self._hud_changes = self._hud_changes + 1
        if hud_elems[id] then hud_elems[id][stat] = val end
    end
    function p:hud_remove(id)
        hud_elems[id] = nil
    end
    function p:get_inventory()
        return {
            set_size = function(_, listname, sz)
                inv_sizes[listname] = sz
                inv_lists[listname] = inv_lists[listname] or {}
                for i = 1, sz do
                    inv_lists[listname][i] = inv_lists[listname][i] or ItemStack("")
                end
                for i = #inv_lists[listname], sz + 1, -1 do
                    inv_lists[listname][i] = nil
                end
            end,
            get_size = function(_, listname)
                return inv_sizes[listname] or #(inv_lists[listname] or {})
            end,
            set_stack = function(_, listname, idx, st)
                inv_lists[listname] = inv_lists[listname] or {}
                inv_lists[listname][idx] = ItemStack(st)
            end,
            get_stack = function(_, listname, idx)
                local l = inv_lists[listname]
                return (l and l[idx]) and ItemStack(l[idx]) or ItemStack("")
            end,
            get_list = function(_, listname) return inv_lists[listname] or {} end,
            set_list = function(_, listname, tbl)
                local out = {}
                for i, v in ipairs(tbl or {}) do out[i] = ItemStack(v) end
                inv_lists[listname] = out
            end,
            contains_item = function(_, listname, item)
                local target = type(item) == "string" and item or item:get_name()
                for _, v in ipairs(inv_lists[listname] or {}) do
                    if v:get_name() == target and not v:is_empty() then return true end
                end
                return false
            end,
            add_item = function(_, listname, item)
                inv_lists[listname] = inv_lists[listname] or {}
                table.insert(inv_lists[listname], ItemStack(item))
            end,
            remove_item = function(_, listname, item)
                local target = type(item) == "string" and item or item:get_name()
                for _, v in ipairs(inv_lists[listname] or {}) do
                    if v:get_name() == target and not v:is_empty() then
                        v:take_item(1)
                        return ItemStack(target)
                    end
                end
                return ItemStack("")
            end,
        }
    end
    return p
end

local function unescape_po_str(s)
    return (s:gsub("\\(.)", function(c)
        if c == "n" then return "\n"
        elseif c == "t" then return "\t"
        elseif c == "r" then return "\r"
        elseif c == '"' then return '"'
        elseif c == "\\" then return "\\"
        end
        return c
    end))
end

local function load_po_catalog(domain, lang)
    local key = tostring(domain) .. "::" .. tostring(lang)
    if po_cache[key] ~= nil then
        return po_cache[key]
    end
    local path = string.format("%s/mods/%s/locale/%s.%s.po", game_dir, tostring(domain), tostring(domain), tostring(lang))
    local f = io.open(path, "rb")
    if not f then
        po_cache[key] = false
        return false
    end
    local dict = {}
    local cur_id = nil
    local cur_str = nil
    local mode = nil
    for raw_line in f:lines() do
        local line = raw_line:gsub("\r$", "")
        if line:match("^%s*#") or line:match("^%s*$") then
            if cur_id and cur_str and cur_id ~= "" then
                dict[cur_id] = cur_str
            end
            cur_id, cur_str, mode = nil, nil, nil
        else
            local id_part = line:match('^msgid%s+"(.*)"%s*$')
            local str_part = line:match('^msgstr%s+"(.*)"%s*$')
            local cont_part = line:match('^"(.*)"%s*$')
            if id_part ~= nil then
                if cur_id and cur_str and cur_id ~= "" then
                    dict[cur_id] = cur_str
                end
                cur_id = unescape_po_str(id_part)
                cur_str = nil
                mode = "id"
            elseif str_part ~= nil then
                cur_str = unescape_po_str(str_part)
                mode = "str"
            elseif cont_part ~= nil then
                if mode == "id" and cur_id ~= nil then
                    cur_id = cur_id .. unescape_po_str(cont_part)
                elseif mode == "str" and cur_str ~= nil then
                    cur_str = cur_str .. unescape_po_str(cont_part)
                end
            end
        end
    end
    if cur_id and cur_str and cur_id ~= "" then
        dict[cur_id] = cur_str
    end
    f:close()
    po_cache[key] = dict
    return dict
end

local function luanti_translate(textdomain, str, ...)
    assert(type(str) == "string", "translate() template must be string")
    if str:find("\27", 1, true) ~= nil then
        error("Escape character in translate() template: " .. tostring(str), 2)
    end
    local args = {...}
    local seen = {}
    local max_n = 0
    local cleaned = str:gsub("@@", "")
    for d in cleaned:gmatch("@(%d+)") do
        local idx = tonumber(d)
        assert(idx and idx >= 1 and idx <= 9, "Placeholder @" .. tostring(d) .. " out of range 1..9 in: " .. str)
        assert(not seen[idx], "Duplicate placeholder @" .. tostring(idx) .. " in: " .. str)
        seen[idx] = true
        if idx > max_n then max_n = idx end
    end
    for k = 1, max_n do
        assert(seen[k], "Missing sequential placeholder @" .. tostring(k) .. " in: " .. str)
    end

    if not mock_escape_translate_mode then
        return (str:gsub("@(.)", function(c)
            if c == "@" then
                return "@"
            elseif c:match("^%d$") then
                return tostring(args[tonumber(c)] or "")
            end
            return "@" .. c
        end))
    end

    local body = str:gsub("@(.)", function(c)
        if c == "@" then
            return "@@"
        elseif c:match("^%d$") then
            local val = tostring(args[tonumber(c)] or "")
            return "\27F" .. val .. "\27E"
        end
        return "@" .. c
    end)
    return "\27(T@" .. tostring(textdomain or "") .. ")" .. body .. "\27E"
end

local function luanti_get_translated_string(lang_code, s)
    if type(s) ~= "string" or s == "" or s:find("\27", 1, true) == nil then
        return tostring(s or "")
    end
    local lang = (lang_code and lang_code ~= "") and lang_code or "en"
    local i = 1
    local n = #s

    local function parse_segment(stop_on_esc_e)
        local out = {}
        while i <= n do
            if s:sub(i, i + 3) == "\27(T@" then
                local close_p = s:find(")", i + 4, true)
                if not close_p then
                    out[#out + 1] = s:sub(i, i)
                    i = i + 1
                else
                    local domain = s:sub(i + 4, close_p - 1)
                    i = close_p + 1
                    local tmpl_parts = {}
                    local f_args = {}
                    while i <= n do
                        if s:sub(i, i + 1) == "\27F" then
                            i = i + 2
                            f_args[#f_args + 1] = parse_segment(true)
                            tmpl_parts[#tmpl_parts + 1] = "@" .. tostring(#f_args)
                        elseif s:sub(i, i + 1) == "\27E" then
                            i = i + 2
                            break
                        else
                            local next_esc = s:find("\27", i, true)
                            if next_esc then
                                tmpl_parts[#tmpl_parts + 1] = s:sub(i, next_esc - 1)
                                i = next_esc
                            else
                                tmpl_parts[#tmpl_parts + 1] = s:sub(i)
                                i = n + 1
                            end
                        end
                    end
                    local raw_msgid = table.concat(tmpl_parts):gsub("@@", "@")
                    local catalog = load_po_catalog(domain, lang)
                    local translated = (catalog and catalog[raw_msgid] and catalog[raw_msgid] ~= "")
                        and catalog[raw_msgid]
                        or raw_msgid
                    out[#out + 1] = (translated:gsub("@(.)", function(c)
                        if c == "@" then
                            return "@"
                        elseif c:match("^%d$") then
                            return tostring(f_args[tonumber(c)] or "")
                        end
                        return "@" .. c
                    end))
                end
            elseif stop_on_esc_e and s:sub(i, i + 1) == "\27E" then
                i = i + 2
                break
            else
                local next_esc = s:find("\27", i, true)
                if next_esc and next_esc > i then
                    out[#out + 1] = s:sub(i, next_esc - 1)
                    i = next_esc
                else
                    out[#out + 1] = s:sub(i, i)
                    i = i + 1
                end
            end
        end
        return table.concat(out)
    end

    return parse_segment(false)
end

core = {
    CONTENT_AIR = 0,
    LIGHT_MAX = 14,
    registered_nodes = registered_nodes,
    registered_items = registered_items,
    registered_aliases = {},
    registered_chatcommands = chatcommands,
    chatcommands = chatcommands,
    registered_entities = {
        ["__builtin:item"] = {
            initial_properties = {},
            set_item = function() end,
            on_step = function() end,
            on_punch = function() end,
        },
    },
    settings = {
        get = function(_, key)
            if key == "tc_drop_interval" then return "11.5" end
            if key == "tc_difficulty" then return "normal" end
            if key == "x_player_api.model_format" then return "glb" end
            return nil
        end,
        get_bool = function(_, key, default)
            if key and key:find("^x_player_api%.") then
                return default ~= false
            end
            return false
        end,
    },
    get_version = function()
        return {project = "Luanti", string = "5.18.0", major = 5, minor = 18, patch = 0}
    end,
    translate = luanti_translate,
    get_translated_string = luanti_get_translated_string,
    get_translator = function(domain)
        local dom = domain or current_mod
        return function(str, ...)
            return luanti_translate(dom, str, ...)
        end
    end,
    get_player_information = function(pname)
        return {
            protocol_version = 46,
            version_string = "5.18.0",
            lang_code = mock_player_langs[pname] or "en",
        }
    end,
    get_player_window_information = function(pname)
        return mock_windows[pname] or {size = {x = 1280, y = 720}, real_hud_scaling = 1.0}
    end,
    get_current_modname = function() return current_mod end,
    get_modpath = function(m)
        local p = game_dir .. "/mods/" .. m
        local f = io.open(p .. "/mod.conf", "rb")
        if f then f:close() return p end
        return nil
    end,
    get_us_time = function()
        mock_us_time = mock_us_time + mock_us_step
        return mock_us_time
    end,
    log = function(lvl, msg)
        if lvl == "error" then
            error("Unexpected core.log error: " .. tostring(msg))
        end
    end,
    colorize = function(col, txt) return "\27(c@" .. col .. ")" .. txt .. "\27(c@#ffffff)" end,
    formspec_escape = function(s) return tostring(s or ""):gsub("\\", "\\\\"):gsub("%[", "\\["):gsub("%]", "\\]") end,
    hypertext_escape = function(s) return tostring(s or ""):gsub("\\", "\\\\"):gsub("<", "\\<"):gsub(">", "\\>") end,
    serialize = function(_) return "{}" end,
    deserialize = function(_) return {} end,
    get_mod_storage = function()
        local kv = {}
        return {
            get_int = function(_, k) return tonumber(kv[k]) or 0 end,
            set_int = function(_, k, v) kv[k] = v end,
            get_string = function(_, k) return kv[k] or "" end,
            set_string = function(_, k, v) kv[k] = v end,
        }
    end,
    register_alias = function() end,
    register_node = function(name, def)
        registered_nodes[name] = def
        registered_items[name] = def
        if not content_ids[name] then
            content_ids[name] = next_cid
            id_to_name[next_cid] = name
            next_cid = next_cid + 1
        end
    end,
    register_tool = function(name, def)
        registered_tools[name] = def
        registered_items[name] = def
    end,
    register_craftitem = function(name, def)
        registered_craftitems[name] = def
        registered_items[name] = def
    end,
    register_entity = function(name, def) core.registered_entities[name] = def end,
    add_entity = function(pos, name, staticdata)
        local def = core.registered_entities[name]
        assert(def, "Unknown entity " .. tostring(name))
        local ent = setmetatable({
            name = name,
            _pos = table.copy(pos),
            _vel = {x = 0, y = 0, z = 0},
            _acc = {x = 0, y = 0, z = 0},
            _removed = false,
            _props = {},
            _rot = {x = 0, y = 0, z = 0},
            _rot_calls = {},
        }, {__index = def})
        ent.object = {
            get_pos = function() return ent._removed and nil or ent._pos end,
            set_pos = function(_, np) ent._pos = table.copy(np) end,
            get_velocity = function() return ent._vel end,
            set_velocity = function(_, v) ent._vel = table.copy(v) end,
            set_acceleration = function(_, a) ent._acc = table.copy(a) end,
            get_rotation = function() return ent._rot end,
            set_rotation = function(_, r, interpolate)
                ent._rot = table.copy(r or {x = 0, y = 0, z = 0})
                table.insert(ent._rot_calls, {rot = ent._rot, interpolate = interpolate})
            end,
            get_properties = function() return ent._props end,
            set_properties = function(_, pr)
                for k, v in pairs(pr or {}) do ent._props[k] = v end
            end,
            set_armor_groups = function() end,
            set_attach = function() end,
            set_detach = function() end,
            get_attach = function() return nil end,
            get_children = function() return {} end,
            set_animation = function() end,
            set_bone_override = function() end,
            set_bone_position = function() end,
            set_observers = function() end,
            get_luaentity = function() return not ent._removed and ent or nil end,
            remove = function() ent._removed = true end,
            is_valid = function() return not ent._removed end,
        }
        if ent.on_activate then ent:on_activate(staticdata or "") end
        if name:find("^tc_elements:") then
            table.insert(spawned_entities, ent)
        end
        return ent.object
    end,
    override_item = function(name, def) overridden_items[name] = def end,
    hud_replace_builtin = function() end,
    get_content_id = function(name)
        if not content_ids[name] then
            content_ids[name] = next_cid
            id_to_name[next_cid] = name
            next_cid = next_cid + 1
        end
        return content_ids[name]
    end,
    get_item_group = function(name, grp)
        local d = registered_items[name]
        return (d and d.groups and d.groups[grp]) or 0
    end,
    hash_node_position = function(p)
        return (p.z + 32768) * 65536 * 65536 + (p.y + 32768) * 65536 + (p.x + 32768)
    end,
    get_node = function(p)
        return {name = node_world[pos_key(p)] or "air"}
    end,
    get_node_or_nil = function(p)
        return {name = node_world[pos_key(p)] or "air"}
    end,
    set_node = function(p, n)
        local k = pos_key(p)
        node_world[k] = n.name
        meta_world[k] = {}
        local def = registered_nodes[n.name]
        if def and def.on_construct then def.on_construct(p) end
    end,
    swap_node = function(p, n)
        node_world[pos_key(p)] = n.name
    end,
    remove_node = function(p)
        local k = pos_key(p)
        node_world[k] = "air"
        meta_world[k] = {}
    end,
    get_meta = function(p)
        local k = pos_key(p)
        meta_world[k] = meta_world[k] or {}
        return {
            set_string = function(_, mk, mv) meta_world[k][mk] = tostring(mv or "") end,
            get_string = function(_, mk) return tostring(meta_world[k][mk] or "") end,
            set_int = function(_, mk, mv) meta_world[k][mk] = math.floor(tonumber(mv) or 0) end,
            get_int = function(_, mk) return math.floor(tonumber(meta_world[k][mk]) or 0) end,
        }
    end,
    get_node_timer = function(_)
        return {start = function() end, stop = function() end}
    end,
    get_voxel_manip = function(minp, maxp)
        local last_data
        return {
            read_from_map = function() return minp, maxp end,
            get_data = function(_, buf)
                local va = VoxelArea:new({MinEdge = minp, MaxEdge = maxp})
                for z = minp.z, maxp.z do
                    for y = minp.y, maxp.y do
                        for x = minp.x, maxp.x do
                            local nm = node_world[pos_key({x = x, y = y, z = z})] or "air"
                            buf[va:index(x, y, z)] = content_ids[nm] or 0
                        end
                    end
                end
                return buf
            end,
            set_data = function(_, d) last_data = d end,
            calc_lighting = function() end,
            write_to_map = function()
                local va = VoxelArea:new({MinEdge = minp, MaxEdge = maxp})
                for z = minp.z, maxp.z do
                    for y = minp.y, maxp.y do
                        for x = minp.x, maxp.x do
                            local cid = last_data[va:index(x, y, z)] or 0
                            node_world[pos_key({x = x, y = y, z = z})] = id_to_name[cid] or "air"
                        end
                    end
                end
            end,
        }
    end,
    find_nodes_in_area = function(minp, maxp, names, grouped)
        local match_set = {}
        for _, nm in ipairs(names) do match_set[nm] = true end
        local res = {}
        for z = minp.z, maxp.z do
            for y = minp.y, maxp.y do
                for x = minp.x, maxp.x do
                    local nm = node_world[pos_key({x = x, y = y, z = z})] or "air"
                    local hit = match_set[nm]
                    if not hit and match_set["group:reagent"] and core.get_item_group(nm, "reagent") > 0 then
                        hit = true
                    end
                    if hit then
                        local pt = {x = x, y = y, z = z}
                        if grouped then
                            res[nm] = res[nm] or {}
                            table.insert(res[nm], pt)
                        else
                            table.insert(res, pt)
                        end
                    end
                end
            end
        end
        return res
    end,
    emerge_area = function(_, _, cb) cb(nil, nil, 0) end,
    after = function(_, fn) fn() end,
    sound_play = function() end,
    add_particlespawner = function(def)
        core._last_particlespawner = def
        core._particlespawners = core._particlespawners or {}
        table.insert(core._particlespawners, def)
        return #core._particlespawners
    end,
    chat_send_player = function() end,
    chat_send_all = function() end,
    show_formspec = function(_, formname, fs) shown_formspecs[formname] = fs end,
    close_formspec = function() end,
    get_connected_players = function() return mock_players end,
    get_player_by_name = function(n)
        for _, pl in ipairs(mock_players) do
            if pl:get_player_name() == n then return pl end
        end
        return nil
    end,
    set_timeofday = function(val)
        assert(type(val) == "number" and val >= 0 and val <= 1, "set_timeofday expects [0, 1]")
        mock_timeofday = val
    end,
    get_timeofday = function() return mock_timeofday end,
    register_on_mods_loaded = function(fn) table.insert(mods_loaded_cbs, fn) end,
    register_on_shutdown = function() end,
    register_on_dignode = function() end,
    register_on_placenode = function() end,
    register_on_joinplayer = function(fn) table.insert(join_cbs, fn) end,
    register_on_leaveplayer = function(fn) table.insert(leave_cbs, fn) end,
    register_on_dieplayer = function() end,
    register_on_respawnplayer = function() end,
    register_on_item_eat = function() end,
    register_on_punchnode = function() end,
    register_on_punchplayer = function() end,
    register_on_player_hpchange = function(fn) table.insert(hpchange_cbs, fn) end,
    register_on_player_receive_fields = function(fn) table.insert(field_cbs, fn) end,
    register_globalstep = function(fn) table.insert(globalsteps, fn) end,
    register_chatcommand = function(cmd, def) chatcommands[cmd] = def end,
}
minetest = core

local function make_monoid()
    local m = {_branches = {}}
    function m:add_change(pl, val, id)
        local n = pl:get_player_name()
        self._branches[n] = self._branches[n] or {}
        self._branches[n][id or "_"] = val
        pl:set_physics_override({})
    end
    function m:del_change(pl, id)
        local n = pl:get_player_name()
        if self._branches[n] then
            self._branches[n][id or "_"] = nil
        end
        pl:set_physics_override({})
    end
    function m:value(pl)
        local prod = 1.0
        for _, v in pairs(self._branches[pl:get_player_name()] or {}) do
            prod = prod * v
        end
        return prod
    end
    return m
end

player_monoids = {
    speed = make_monoid(),
    jump = make_monoid(),
    gravity = make_monoid(),
}

sfinv = {
    pages = {},
    override_page = function(name, def) sfinv.pages[name] = def end,
}

-- Load real bundled x_player_api + hudbars + all 6 custom tc_* mods in exact dependency order
local legacy_pa = io.open(game_dir .. "/mods/player_api/mod.conf", "rb")
assert(legacy_pa == nil, "Legacy mods/player_api directory must be removed!")
local load_order = {
    "x_player_api", "hudbars", "tc_assets", "tc_init", "tc_elements", "tc_tools", "tc_world", "tc_core",
}
for _, m in ipairs(load_order) do
    current_mod = m
    dofile(game_dir .. "/mods/" .. m .. "/init.lua")
end
for _, fn in ipairs(mods_loaded_cbs) do
    fn()
end

-- 1. Verify WCAG 2.1 AA contrast ratios (>= 4.5:1)
local function hex_to_lum(hex)
    local r = tonumber(hex:sub(2, 3), 16) / 255
    local g = tonumber(hex:sub(4, 5), 16) / 255
    local b = tonumber(hex:sub(6, 7), 16) / 255
    local function lin(c)
        return (c <= 0.03928) and (c / 12.92) or (((c + 0.055) / 1.055) ^ 2.4)
    end
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
end

local function contrast(hex1, hex2)
    local l1, l2 = hex_to_lum(hex1), hex_to_lum(hex2)
    if l1 < l2 then l1, l2 = l2, l1 end
    return (l1 + 0.05) / (l2 + 0.05)
end

local P = tc_assets.PALETTE
local surfaces = {P.bg_panel, P.bg_card, P.bg_inset, P.bg_tooltip}
local text_cols = {
    text_primary = P.text_primary,
    text_secondary = P.text_secondary,
    gold = P.gold,
    emerald = P.emerald,
    aqua = P.aqua,
    amber = P.amber,
    coral = P.coral,
    violet = P.violet,
}

local min_ratio = 999
for tname, thex in pairs(text_cols) do
    for _, bg in ipairs(surfaces) do
        local cr = contrast(thex, bg)
        if cr < min_ratio then min_ratio = cr end
        assert(cr >= 4.5, string.format("WCAG AA failure: %s (%s) on %s = %.2f:1", tname, thex, bg, cr))
    end
end
print(string.format("[OK] WCAG 2.1 AA+ verified across all surfaces (min contrast = %.2f:1 >= 4.5:1)", min_ratio))

-- 2. Verify all items, PNG textures, and OGG sound specs
local tex_dir = game_dir .. "/mods/tc_assets/textures/"
local snd_dir = game_dir .. "/mods/tc_assets/sounds/"
local function file_exists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end

local item_count = 0
for name, def in pairs(registered_items) do
    item_count = item_count + 1
    assert(def.description and def.description ~= "", "Missing description on " .. name)
    assert(def.short_description and def.short_description ~= "", "Missing short_description on " .. name)
    if def.inventory_image then
        assert(file_exists(tex_dir .. def.inventory_image), "Missing texture " .. def.inventory_image .. " on " .. name)
    end
    if def.tiles then
        for _, tile in ipairs(def.tiles) do
            local tname = type(tile) == "table" and tile.name or tile
            assert(file_exists(tex_dir .. tname), "Missing tile texture " .. tostring(tname) .. " on " .. name)
        end
    end
end
assert(file_exists(tex_dir .. "tc_drop_reticle.png"), "Missing tc_drop_reticle.png")
assert(file_exists(tex_dir .. "tc_aether_geode.png"), "Missing tc_aether_geode.png")
print(string.format("[OK] All %d registered nodes/tools/elixirs + hand have descriptions, short_descriptions & PNGs", item_count))

local required_sounds = {
    "tc_drop_warning", "tc_harmony_chime", "tc_transmute", "tc_victory",
    "tc_defeat", "tc_wither", "tc_ping", "tc_water_splash", "tc_bellows",
    "tc_pestle", "tc_elixir_drink", "tc_stasis", "tc_geode_chime",
    "tc_book_page", "tc_trowel_scoop", "tc_sizzle", "tc_steam", "tc_ice_dig",
    "tc_glass", "tc_player_damage", "tc_item_smoke", "tc_dig_cracky",
    "tc_dig_crumbly", "tc_dug_node", "tc_footstep_dirt", "tc_footstep_wood",
    "tc_place_node", "tc_place_node_hard", "tc_tool_breaks",
}
for _, sname in ipairs(required_sounds) do
    local ok = file_exists(snd_dir .. sname .. ".ogg") or file_exists(snd_dir .. sname .. ".1.ogg")
    assert(ok, "Missing .ogg audio file for sound spec: " .. sname)
end
print(string.format("[OK] All %d sound effect families verified on disk in mods/tc_assets/sounds/", #required_sounds))

-- 3. Join player & start Level 1 (verify ZERO login FOV packets so Luanti client camera never zooms to 1.0 deg!)
local p1 = make_mock_player("SaKeL")
table.insert(mock_players, p1)
for _, fn in ipairs(join_cbs) do fn(p1) end
tc_core.start_level(1, false)
for _, fn in ipairs(globalsteps) do fn(0.05) end
assert(#p1._fov_history == 0 and p1:get_fov() == 0,
    "Normal player login + initial globalstep must emit 0 set_fov packets, got " .. tostring(#p1._fov_history))
assert(p1._props.zoom_fov == 0, "Player zoom_fov must be 0 so [Z] Chamber Ping never triggers binocular zoom")
assert(#tc_core.state.plants == 1, "Level 1 must have 1 sprout")

-- 4. Test 3-Charge Condenser Flask & Deep Retort 5-Charge Blessing
local flask = tc_tools.fill_flask()
assert(tc_tools.get_flask_charges(flask) == 3, "Base flask must have 3 charges")
assert(flask:get_wear() == 0, "Full flask must have 0 wear")
flask = tc_tools.consume_flask_charge(flask)
assert(tc_tools.get_flask_charges(flask) == 2 and flask:get_wear() > 0, "2/3 flask must show wear bar")
flask = tc_tools.consume_flask_charge(flask)
assert(tc_tools.get_flask_charges(flask) == 1, "Expected 1/3 flask")
local empty_flask = tc_tools.consume_flask_charge(flask)
assert(empty_flask:get_name() == "tc_tools:condenser_flask", "0 charges must revert to empty flask")

p1:get_inventory():set_list("main", {tc_tools.fill_flask()})
tc_core.select_blessing("deep_retort", true)
assert(tc_tools.get_max_flask_charges() == 5, "Deep Retort must raise max charges to 5")
local upgraded_in_inv = p1:get_inventory():get_list("main")[1]
assert(tc_tools.get_flask_charges(upgraded_in_inv) == 5, "Deep Retort must immediately upgrade held flask to 5/5")

-- Verify splash-only flask (no raw floor pouring) & full-flask water_source/water_flowing siphoning
local flask_full_def = registered_tools["tc_tools:condenser_flask_full"]
local flask_empty_def = registered_tools["tc_tools:condenser_flask"]
core.set_node({x = -2, y = 0, z = -2}, {name = "tc_elements:loam"})
core.set_node({x = -2, y = 1, z = -2}, {name = "air"})
local full_st = tc_tools.fill_flask()
full_st = flask_full_def.on_use(full_st, p1, {type = "node", under = {x = -2, y = 0, z = -2}, above = {x = -2, y = 1, z = -2}})
assert(core.get_node({x = -2, y = 1, z = -2}).name == "air", "Charged Flask must never pour raw water_source onto empty floor")
assert(tc_tools.get_flask_charges(full_st) == 5, "Clicking empty floor with Charged Flask must not waste charges")

-- Clicking water_flowing must siphon its nearby water_source & sweep the puddle
core.set_node({x = 3, y = 1, z = -2}, {name = "tc_elements:water_source"})
core.set_node({x = 4, y = 1, z = -2}, {name = "tc_elements:water_flowing"})
core.set_node({x = 2, y = 1, z = -2}, {name = "tc_elements:water_flowing"})
local scooped_st = flask_empty_def.on_use(
    ItemStack("tc_tools:condenser_flask"), p1,
    {type = "node", under = {x = 4, y = 1, z = -2}, above = {x = 4, y = 2, z = -2}}
)
assert(tc_tools.get_flask_charges(scooped_st) == 5, "Scooping water_flowing must fill flask")
assert(core.get_node({x = 3, y = 1, z = -2}).name == "air", "Scooping water_flowing must remove feeding water_source")
assert(core.get_node({x = 2, y = 1, z = -2}).name == "air", "Scooping last water_source must sweep orphaned flowing water")

-- Clicking a second water_source when ALREADY full must still siphon it and never stack water at y=2!
core.set_node({x = -3, y = 1, z = 3}, {name = "tc_elements:water_source"})
core.set_node({x = -3, y = 2, z = 3}, {name = "air"})
scooped_st = flask_full_def.on_use(
    scooped_st, p1,
    {type = "node", under = {x = -3, y = 1, z = 3}, above = {x = -3, y = 2, z = 3}}
)
assert(core.get_node({x = -3, y = 1, z = 3}).name == "air", "Full flask must still siphon and remove water_source")
assert(core.get_node({x = -3, y = 2, z = 3}).name == "air", "Full flask must never stack water_source at y=2")
print("[OK] 3-Charge Condenser Flask wear bar, Deep Retort 5-Charge & Anti-Flood Siphoning verified")

-- 5. Test Trowel Right-Click Tongs Scoop & Place + 0ms Immediate Reaction (+3.0% Scaled Bloom)
tc_core.start_level(1, false)
local trowel_def = registered_tools["tc_tools:trowel"]
local trowel = ItemStack("tc_tools:trowel")
core.set_node({x = 2, y = 1, z = 2}, {name = "tc_elements:brimstone"})
core.set_node({x = 4, y = 1, z = 2}, {name = "tc_elements:cryo_ice"})

trowel = trowel_def.on_place(trowel, p1, {type = "node", under = {x = 2, y = 1, z = 2}, above = {x = 2, y = 2, z = 2}})
assert(tc_tools.get_trowel_cargo(trowel) == "tc_elements:brimstone", "Trowel must scoop brimstone")
assert(core.get_node({x = 2, y = 1, z = 2}).name == "air", "Scooped node must be removed from floor")

trowel = trowel_def.on_place(trowel, p1, {type = "node", under = {x = 3, y = 0, z = 2}, above = {x = 3, y = 1, z = 2}})
assert(tc_tools.get_trowel_cargo(trowel) == "", "Trowel cargo must empty on placement")
assert(math.abs(tc_core.state.bloom - 3.0) < 0.01, "0ms Thermal Cancellation must immediately add +3.0% Bloom")
assert(core.get_node({x = 4, y = 1, z = 2}).name == "tc_elements:water_source", "Cryo-Ice must melt into Water at 0ms")
print("[OK] Trowel Right-Click Tongs & 0ms Event-Driven Reaction Engine (+3.0% Bloom) verified")

-- 6. Test Physical Falling Reagent Entity Descent (~2.76s) & Mid-Air Skill-Shot (+2.2% Bonus Bloom)
local prev_bloom = tc_core.state.bloom
spawned_entities = {}
tc_elements.spawn_falling_reagent({x = -2, y = 1, z = 2}, "tc_elements:cryo_ice")
assert(#spawned_entities == 1, "spawn_falling_reagent must spawn 1 physical entity")
local ent = spawned_entities[1]
assert(math.abs(ent._pos.y - 14.0) < 0.01, "Falling reagent must spawn at y = 14.0")
assert(math.abs(ent._vel.y - (-1.4)) < 0.01 and math.abs(ent._acc.y - (-2.4)) < 0.01, "Gentle descent v0=-1.4, a=-2.4")
p1:set_wielded_item(ItemStack("tc_tools:bellows"))
ent:on_punch(p1)
assert(ent._removed, "Mid-air skill-shot must remove falling entity")
assert(math.abs(tc_core.state.bloom - (prev_bloom + 2.2)) < 0.01, "Mid-air skill-shot must grant +2.2% Bonus Bloom")
assert(core.get_node({x = -2, y = 1, z = 2}).name == "tc_elements:water_source", "Mid-air Cryo melt must drop Water")
print("[OK] Physical falling_reagent gentle descent (y=14, v0=-1.4, a=-2.4) & Mid-Air Skill-Shot (+2.2% Bloom) verified")

-- 7. Test Level 2+ Prismatic Aether Geode Resonance (+4.5% + 0.5%*purged Bloom & 3x3 Purge) & 22s Shatter Timer
local geode_def = registered_nodes["tc_elements:aether_geode"]
core.set_node({x = -2, y = 1, z = -2}, {name = "tc_elements:aether_geode"})
core.set_node({x = -1, y = 1, z = -2}, {name = "tc_elements:acid_slime"})
local b_before_geode = tc_core.state.bloom
p1:set_wielded_item(ItemStack("tc_tools:trowel"))
geode_def.on_punch({x = -2, y = 1, z = -2}, {name = "tc_elements:aether_geode"}, p1)
assert(core.get_node({x = -2, y = 1, z = -2}).name == "air", "Resonated geode must clear itself")
assert(core.get_node({x = -1, y = 1, z = -2}).name == "air", "Resonated geode must purge adjacent acid_slime")
assert(core.get_node({x = -2, y = 0, z = -2}).name == "tc_elements:fertile_loam", "Geode must enrich 3x3 soil")
assert(math.abs(tc_core.state.bloom - (b_before_geode + 5.0)) < 0.01, "Geode + 1 purge must add +5.0% Bloom on L1")

core.set_node({x = 2, y = 1, z = -2}, {name = "tc_elements:aether_geode"})
for _ = 1, 21 do
    geode_def.on_timer({x = 2, y = 1, z = -2})
end
assert(core.get_node({x = 2, y = 1, z = -2}).name == "tc_elements:aether_geode", "Geode must remain intact at 21s")
geode_def.on_timer({x = 2, y = 1, z = -2})
assert(core.get_node({x = 2, y = 1, z = -2}).name ~= "tc_elements:aether_geode", "Ignored geode must shatter at 22s")
print("[OK] Prismatic Aether Geode 3x3 Resonance (+4.5%+0.5%*purged Bloom) & 22s Node Timer shatter verified")

-- 8. Test Victory Next-Level Blessing Picker -> Level 2 Expansion, Cheer Emote, Turbulence, Micro-Climate & Waypoints
tc_core.state.bloom = 100.0
for _, fn in ipairs(globalsteps) do fn(1.0) end
assert(tc_core.state.victory, "100% Bloom must trigger Victory")
assert(shown_formspecs["tc_core:victory"]:find("btn_blessing_1"),
    "Victory dialog must render 3 Next-Level Blessing cards")
local win_pstate = x_player_api.controls.player_states["SaKeL"]
assert(win_pstate and win_pstate.active_emote == "cheer", "Level Complete Victory must play 'cheer' emote!")

for _, fn in ipairs(field_cbs) do
    fn(p1, "tc_core:victory", {btn_blessing_1 = "Pick"})
end
assert(tc_core.state.level == 2 and #tc_core.state.plants == 2,
    "Clicking Next-Level Blessing card must expand to Level 2")
assert(tc_core.state.active_blessing ~= nil, "Selected Next-Level Blessing must activate on Level 2")
assert(win_pstate.active_emote == "cheer", "Selecting a Next-Level Blessing must celebrate with 'cheer' emote!")

-- Place 2 Brimstones in Chamber 1 and 2 Cryo-Ices in Chamber 2 (global net = 0, active = 4 > L2 => Turbulent + Micro-Climate!)
local cells = tc_world.get_active_cells(2)
for k = 0, 1 do
    core.set_node({x = cells[1].min_x + 1 + k, y = 1, z = cells[1].max_z - 1}, {name = "tc_elements:brimstone"})
    core.set_node({x = cells[2].min_x + 1 + k, y = 1, z = cells[2].max_z - 1}, {name = "tc_elements:cryo_ice"})
end
tc_core.state.plants[2].vitality = 35.0
for _, fn in ipairs(globalsteps) do fn(1.0) end
assert(tc_core.state.turbulent == true, "4 hazards on Level 2 (>2) must trigger Elemental Turbulence")
assert(tc_core.state.plants[1].local_stress == true, "2 unopposed Brimstones in Chamber 1 must trigger Micro-Climate stress")
assert(tc_core.state.plants[1].vitality < 100.0, "Micro-Climate stress must drain Chamber 1 Sprout Vitality")

-- Verify 3D distress waypoint created for Sprout #2 (<45% Vitality) + /ping command
local has_distress_wp = false
for _, h in pairs(p1._hud_elems) do
    if h and h.type == "waypoint" and h.name:find("Sprout #2") then
        has_distress_wp = true
    end
end
assert(has_distress_wp, "Expected 3D distress waypoint for low-Vitality Sprout #2")

local ping_ok = chatcommands["ping"].func("SaKeL")
assert(ping_ok, "/ping command must succeed")
assert(win_pstate.active_emote == "point", "Pinging a chamber must play 'point' emote!")
print("[OK] Next-Level Blessing Picker, Emotes, Elemental Turbulence, Micro-Climate (>=2) & 3D Waypoints verified")

-- 9. Test Hermetic Boots 50% damage reduction + Auto-Aegis Lifesaver
tc_core.select_blessing("hermetic_boots", true)
p1:set_hp(20)
local dmg = -4
for _, fn in ipairs(hpchange_cbs) do
    local res = fn(p1, dmg)
    if res then dmg = res end
end
assert(dmg == -2, "Hermetic Boots must halve -4 hazard damage to -2, got " .. tostring(dmg))

p1:set_hp(2)
p1:get_inventory():set_list("main", {})
p1:get_inventory():add_item("main", "tc_tools:elixir_aegis")
local lethal = -10
for _, fn in ipairs(hpchange_cbs) do
    local res = fn(p1, lethal)
    if res then lethal = res end
end
assert(lethal == 0 and p1:get_hp() == 20, "Auto-Aegis Lifesaver must negate lethal hit & restore 20 HP")
assert(not p1:get_inventory():contains_item("main", "tc_tools:elixir_aegis"), "Auto-Aegis must consume 1 elixir_aegis")
assert(tc_core.state.aegis_timer >= 11.9, "Auto-Aegis must shield Sprouts for 12s")
print("[OK] Hermetic Boots 50% hazard armor & Auto-Aegis Lifesaver verified")

-- 10. Test 8s Overload Meltdown Grace/Recovery, <25C Cold Decay, Solo -30% Reconstitution & 0% AFK Level 1 Wins
tc_core.start_level(1, false)
assert(tc_core.state.max_reagents == 11, "Level 1 max_reagents must be 6 + 5*1 = 11")
local ov_pts = {}
for x = -4, 4 do
    core.set_node({x = x, y = 1, z = 3}, {name = "tc_elements:cryo_ice"})
    table.insert(ov_pts, {x = x, y = 1, z = 3})
end
for x = -3, -1 do
    core.set_node({x = x, y = 1, z = -3}, {name = "tc_elements:cryo_ice"})
    table.insert(ov_pts, {x = x, y = 1, z = -3})
end
assert(#ov_pts == 12, "Placed 12 cryo_ice (>11 cap) and <25C extreme cold")
tc_core.state.bloom = 50.0
for _ = 1, 5 do
    for _, fn in ipairs(globalsteps) do fn(1.0) end
end
assert(not tc_core.state.defeat and tc_core.state.overload_timer == 5, "5s into Overload must warn, NOT instant-defeat")
assert(tc_core.state.temperature < 25 and tc_core.state.bloom < 50.0, "Extreme cold (<25C) must decay Botanical Bloom")

-- Clear 2 blocks back to 10 (<= 11) -> Overload Meltdown must cancel!
core.remove_node(ov_pts[12])
core.remove_node(ov_pts[11])
for _, fn in ipairs(globalsteps) do fn(1.0) end
assert(tc_core.state.overload_timer == 0 and not tc_core.state.defeat, "Clearing back <= cap must cancel Overload Meltdown")

-- Re-exceed cap for full 8s -> must trigger Defeat at 8s!
core.set_node(ov_pts[11], {name = "tc_elements:cryo_ice"})
core.set_node(ov_pts[12], {name = "tc_elements:cryo_ice"})
tc_core.state.plants[1].vitality = 100.0
tc_core.state.aegis_timer = 15.0
for _ = 1, 8 do
    for _, fn in ipairs(globalsteps) do fn(1.0) end
end
assert(tc_core.state.defeat, "Sustaining >11 hazards for full 8s must trigger Overload Meltdown Defeat")

-- Test Solo Emergency Reconstitution (-30% Vitality shockwave survives at 100%, defeats at <=30%)
tc_core.start_level(1, false)
tc_core.on_player_died(p1)
assert(not tc_core.state.defeat and math.abs(tc_core.state.plants[1].vitality - 70.0) < 0.01,
    "Solo death at 100% Sprout Vitality must reconstitute at 70% Vitality without ending run")
tc_core.state.plants[1].vitality = 25.0
tc_core.on_player_died(p1)
assert(tc_core.state.defeat, "Solo death when Sprout has <=30% Vitality must end run via withered shockwave")

-- Monte Carlo AFK Level 1 Simulation (20 randomized runs with physical falling entities)
local afk_wins = 0
for seed = 1, 20 do
    math.randomseed(1000 + seed * 97)
    spawned_entities = {}
    tc_core.start_level(1, false)
    for _ = 1, 900 do -- 180s at 0.2s physics steps
        local dt = 0.2
        for i = #spawned_entities, 1, -1 do
            local e = spawned_entities[i]
            if not e._removed and e.on_step then
                e._vel.y = e._vel.y + e._acc.y * dt
                e._pos.y = e._pos.y + e._vel.y * dt
                e:on_step(dt, {touching_ground = (e._pos.y <= 1.05)})
            end
        end
        for _, fn in ipairs(globalsteps) do fn(dt) end
        if tc_core.state.victory then
            afk_wins = afk_wins + 1
            break
        elseif tc_core.state.defeat then
            break
        end
    end
end
assert(afk_wins == 0, "AFK Level 1 must NEVER win! Got " .. tostring(afk_wins) .. "/20 wins")
print("[OK] 8s Overload Grace/Recovery, <25C Cold Decay, Solo -30% Reconstitution & 0/20 AFK Level 1 Wins verified")

-- 11. Test x_player_api Consumables (Elixir Drinking), Equip Sounds, Sprint Monoid & Defeat Bow
tc_core.start_level(1, false)
assert(x_player_api.is_consumable("tc_tools:elixir_aegis"), "Aegis Potion must be registered consumable")
local ag_cdef = x_player_api.get_consumable_definition("tc_tools:elixir_aegis")
assert(ag_cdef.particle_type == "liquid_drops", "Aegis Potion must emit liquid_drops particles")
local ag_stack = ItemStack("tc_tools:elixir_aegis")
registered_craftitems["tc_tools:elixir_aegis"].on_use(ag_stack, p1)
assert(win_pstate.eat_action == "eat" and win_pstate.eat_item_name == "tc_tools:elixir_aegis",
    "Drinking Aegis Potion must trigger x_player_api eating/drinking animation!")

assert(x_player_api.get_equip_sound("tc_tools:trowel").sound == "tc_trowel_scoop", "Trowel equip sound mismatch")
assert(x_player_api.get_equip_sound("tc_tools:guide_tome").sound == "tc_book_page", "Grimoire equip sound mismatch")
assert(chatcommands["cheer"] ~= nil and chatcommands["wave"] ~= nil, "x_player_api emote chatcommands must exist")
assert(file_exists(tex_dir .. tc_init.DEFAULT_SKIN),
    "Missing custom player skin texture: " .. tostring(tc_init.DEFAULT_SKIN))
assert(x_player_api.registered_models["character.b3d"].textures[1] == tc_init.DEFAULT_SKIN,
    "character.b3d default skin must be " .. tostring(tc_init.DEFAULT_SKIN))
assert(x_player_api.registered_models["character.glb"].textures[1] == tc_init.DEFAULT_SKIN,
    "character.glb default skin must be " .. tostring(tc_init.DEFAULT_SKIN))
assert(x_player_api.get_textures(p1)[1] == tc_init.DEFAULT_SKIN,
    "Joined player must wear custom alchemist skin: " .. tostring(tc_init.DEFAULT_SKIN))

local phys_before_sprint = p1._physics_calls
tc_core.set_player_sprinting(p1, true)
assert(p1._physics_calls == phys_before_sprint + 1, "Sprinting must apply player_monoids speed boost")
tc_core.set_player_sprinting(p1, false)
assert(p1._physics_calls == phys_before_sprint + 2, "Stopping sprint must remove player_monoids speed boost")

tc_core.trigger_defeat("Verification test defeat")
assert(win_pstate.active_emote == "bow", "Defeat must trigger 'bow' posture emote!")
tc_core.reset_crucible()
assert(win_pstate.active_emote == nil, "Resetting to Level 1 must clear active emote!")
print("[OK] x_player_api GLB models, emotes (cheer/point/wave/bow), elixir drinking, equip sounds & sprint verified")

-- 12. Regression Suite: Level 1 Garden Controls UI, Trowel Sprout Right-Click, Cargo Reset, Water Quench & FOV
shown_formspecs["tc_core:garden"] = nil
tc_core.show_garden_dialog(p1)
assert(shown_formspecs["tc_core:garden"] and shown_formspecs["tc_core:garden"]:find("None yet"),
    "Level 1 Garden Controls dialog with no active blessing must render cleanly without nil palette error")

-- Right-click Plant while holding Trowel (running = true & running = false)
shown_formspecs["tc_core:garden"] = nil
local sprout_pos = {x = 0, y = 1, z = 0}
core.set_node(sprout_pos, {name = "tc_elements:crucible_sprout_1"})
local tr_item = ItemStack("tc_tools:trowel")
trowel_def.on_place(tr_item, p1, {type = "node", under = sprout_pos, above = {x = 0, y = 2, z = 0}})
assert(shown_formspecs["tc_core:garden"] ~= nil, "Right-clicking Plant with Trowel must open Garden Controls")

-- Scoop cargo onto Trowel in player inventory, then advance to Level 2 -> cargo must clear
local loaded_trowel = tc_tools.set_trowel_cargo(ItemStack("tc_tools:trowel"), "tc_elements:brimstone")
local p1_list = p1:get_inventory():get_list("main")
p1_list[1] = loaded_trowel
p1:get_inventory():set_list("main", p1_list)
assert(tc_tools.get_trowel_cargo(p1:get_inventory():get_list("main")[1]) == "tc_elements:brimstone", "Cargo set")
tc_core.start_level(2, true)
assert(tc_tools.get_trowel_cargo(p1:get_inventory():get_list("main")[1]) == "",
    "Advancing to Level 2 must clear leftover Trowel cargo")

-- Water quenching Brimstone in simulation_step must quench Brimstone into Steam AND grant +1.2% scaled Bloom
tc_core.start_level(1, false)
core.set_node({x = 2, y = 1, z = 2}, {name = "tc_elements:brimstone"})
core.set_node({x = 3, y = 1, z = 2}, {name = "tc_elements:water_source"})
for _, fn in ipairs(globalsteps) do fn(1.0) end
assert(core.get_node({x = 2, y = 1, z = 2}).name == "tc_elements:steam",
    "simulation_step Water + Brimstone must quench Brimstone into Steam")
assert(core.get_node({x = 3, y = 1, z = 2}).name == "air", "simulation_step Water + Brimstone must consume Water")
assert(tc_core.state.bloom >= 2.0, "Water quenching Brimstone + 1s Harmony must add >= 2.0% total Bloom")

-- Paused game (Inspect Arena): Potions must NOT be consumed, while Plant right-click with Trowel still works
tc_core.state.running = false
shown_formspecs["tc_core:garden"] = nil
core.set_node(sprout_pos, {name = "tc_elements:crucible_sprout_1"})
trowel_def.on_place(tr_item, p1, {type = "node", under = sprout_pos, above = {x = 0, y = 2, z = 0}})
assert(shown_formspecs["tc_core:garden"] ~= nil, "Right-clicking Plant with Trowel while paused must open Garden UI")
local paused_ag = ItemStack("tc_tools:elixir_aegis 2")
paused_ag = registered_craftitems["tc_tools:elixir_aegis"].on_use(paused_ag, p1)
assert(paused_ag:get_count() == 2, "Potions must not be wasted while crucible is paused")

-- Duplicate init_player_hud guard
local hud_cnt_before = 0
for _ in pairs(p1._hud_elems) do hud_cnt_before = hud_cnt_before + 1 end
tc_core.init_player_hud(p1)
local hud_cnt_after = 0
for _ in pairs(p1._hud_elems) do hud_cnt_after = hud_cnt_after + 1 end
assert(hud_cnt_after == hud_cnt_before, "Re-calling init_player_hud must not duplicate HUD elements")

-- Comprehensive FOV Lifecycle, Login Warmup, Coalescing & Priority Hierarchy Verification
tc_core.start_level(1, false)
mock_us_step = 0
mock_us_time = 50000000

-- Stale persisted server FOV on login must reset instantaneously (trans == 0, never trans > 0!)
local p_stale = make_mock_player("AlchemistTwo")
p_stale._fov = 1.10
p_stale._fov_is_mult = true
table.insert(mock_players, p_stale)
for _, fn in ipairs(join_cbs) do fn(p_stale) end
assert(#p_stale._fov_history == 1, "Joining with stale non-zero FOV must reset once")
assert(p_stale._fov_history[1].fov == 0 and p_stale._fov_history[1].trans == 0,
    "Stale login FOV reset must use instant transition_time = 0!")

-- Boost or sprint within 2.5s post-login warmup window must use instant transition_time = 0
mock_us_time = mock_us_time + 500000 -- +0.5s (< 2.5s warmup)
tc_core.set_player_sprinting(p_stale, true)
local warmup_ev = p_stale._fov_history[#p_stale._fov_history]
assert(math.abs(warmup_ev.fov - 1.05) < 0.001 and warmup_ev.is_mult and warmup_ev.trans == 0,
    "Early-join FOV change within 2.5s camera warmup must use transition_time = 0")

-- Post-warmup (>= 2.5s) priority ladder (1.05 < 1.08 < 1.10) with smooth 0.20s transitions
mock_us_time = mock_us_time + 3000000 -- +3.0s (>= 2.5s warmup & >= 60ms coalesce)
tc_core.apply_effect(p_stale, "fertile_stride", 4.0)
local fs_ev = p_stale._fov_history[#p_stale._fov_history]
assert(math.abs(fs_ev.fov - 1.08) < 0.001 and fs_ev.is_mult and math.abs(fs_ev.trans - 0.20) < 0.001,
    "Post-warmup Fertile Stride must smoothly transition to 1.08x over 0.20s")

mock_us_time = mock_us_time + 250000
tc_core.select_blessing("hermetic_boots", true)
local hb_ev = p_stale._fov_history[#p_stale._fov_history]
assert(math.abs(hb_ev.fov - 1.10) < 0.001 and hb_ev.is_mult and math.abs(hb_ev.trans - 0.20) < 0.001,
    "Hermetic Boots + Fertile Stride must widen 1.08x to 1.10x smoothly over 0.20s")

mock_us_time = mock_us_time + 250000
tc_core.select_blessing(nil, true)
assert(math.abs(p_stale:get_fov() - 1.08) < 0.001,
    "Clearing Hermetic Boots while Fertile Stride active must step back to 1.08x")

mock_us_time = mock_us_time + 250000
tc_core.remove_effect(p_stale, "fertile_stride")
assert(math.abs(p_stale:get_fov() - 1.05) < 0.001, "Expiring Fertile Stride while sprinting must step to 1.05x")

mock_us_time = mock_us_time + 250000
tc_core.set_player_sprinting(p_stale, false)
local reset_ev = p_stale._fov_history[#p_stale._fov_history]
assert(reset_ev.fov == 0 and reset_ev.is_mult == false and math.abs(reset_ev.trans - 0.20) < 0.001,
    "Stopping final boost after warmup must smoothly return to 0 over 0.20s")

-- Same-frame (< 60ms) back-to-back FOV toggle must coalesce with transition_time = 0
mock_us_time = mock_us_time + 250000
tc_core.set_player_sprinting(p_stale, true)
mock_us_time = mock_us_time + 10000 -- +10ms (< 60ms same-frame guard)
tc_core.set_player_sprinting(p_stale, false)
local fast_ev = p_stale._fov_history[#p_stale._fov_history]
assert(fast_ev.fov == 0 and fast_ev.trans == 0,
    "Back-to-back <60ms FOV cancellation must use transition_time = 0 to prevent m_fov_diff == 0 freeze")

-- Reconstitution (0.65x respawn penalty) must suppress sprint FOV widening and keep normal 0 FOV
mock_us_time = mock_us_time + 250000
tc_core.on_player_respawned(p_stale)
tc_core.set_player_sprinting(p_stale, true)
assert(p_stale:get_fov() == 0, "Reconstituting player must stay at normal 0 FOV without zoom or sprint surge")
tc_core.clear_player_effects(p_stale, true)
tc_core.set_player_sprinting(p_stale, false)

for _, fn in ipairs(leave_cbs) do fn(p_stale) end
table.remove(mock_players)
mock_us_step = 5000000
print("[OK] Regression suite (Garden Controls UI, Trowel delegation, cargo reset, Water quench & FOV) verified")

-- 13. Test Animated Sprite-Sheet Textures, Particle Spawners & Asynchronous Level 3 Multi-Plant Growth
local function read_png_size(path)
    local fh = io.open(path, "rb")
    assert(fh, "Missing PNG file: " .. tostring(path))
    local hdr = fh:read(24)
    fh:close()
    assert(hdr and #hdr == 24 and hdr:sub(1, 8) == "\137PNG\r\n\26\n", "Invalid PNG header: " .. tostring(path))
    local b1, b2, b3, b4 = hdr:byte(17, 20)
    local h1, h2, h3, h4 = hdr:byte(21, 24)
    local w = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
    local h = ((h1 * 256 + h2) * 256 + h3) * 256 + h4
    return w, h
end

local expected_sheets = {
    {"tc_brimstone_anim.png", 32, 256},
    {"tc_water_source_anim.png", 32, 256},
    {"tc_water_flowing_anim.png", 32, 512},
    {"tc_steam_anim.png", 32, 256},
    {"tc_acid_slime_anim.png", 32, 256},
    {"tc_fertile_loam_anim.png", 32, 256},
    {"tc_aether_geode_anim.png", 32, 256},
    {"tc_candle_wick_anim.png", 32, 256},
    {"tc_particle_bloom.png", 16, 128},
    {"tc_particle_pollen.png", 16, 128},
    {"tc_particle_steam.png", 16, 128},
    {"tc_particle_ember.png", 16, 128},
    {"tc_particle_droplet.png", 16, 128},
}
for i = 1, #expected_sheets do
    local entry = expected_sheets[i]
    local w, h = read_png_size(tex_dir .. entry[1])
    assert(w == entry[2] and h == entry[3],
        string.format("Sprite sheet %s expected %dx%d, got %dx%d", entry[1], entry[2], entry[3], w, h))
end

-- Verify animated vertical_frames node & liquid tile definitions
local anim_nodes = {
    "tc_elements:brimstone",
    "tc_elements:acid_slime",
    "tc_elements:fertile_loam",
    "tc_elements:aether_geode",
    "tc_elements:candle_wick",
    "tc_elements:steam",
    "tc_elements:water_source",
}
for i = 1, #anim_nodes do
    local nd = registered_nodes[anim_nodes[i]]
    assert(nd and type(nd.tiles[1]) == "table" and nd.tiles[1].animation,
        "Expected animated vertical_frames tile on " .. anim_nodes[i])
    assert(nd.tiles[1].animation.type == "vertical_frames"
        and nd.tiles[1].animation.aspect_w == 32
        and nd.tiles[1].animation.aspect_h == 32,
        "Invalid vertical_frames aspect on " .. anim_nodes[i])
end
local wf_def = registered_nodes["tc_elements:water_flowing"]
assert(wf_def and wf_def.special_tiles and wf_def.special_tiles[1].animation.type == "vertical_frames",
    "Flowing water must animate via special_tiles vertical_frames")

-- Verify Trowel cargo overlay still uses static 32x32 texture (not 32x256 anim sheet)
local cargo_st = tc_tools.set_trowel_cargo(ItemStack("tc_tools:trowel"), "tc_elements:brimstone")
assert(cargo_st:get_meta():get_string("wield_overlay") == "tc_brimstone.png^[resize:16x16",
    "Trowel cargo overlay must use square 32x32 base icon")

-- Verify tc_assets.spawn_sheet_particles emits both modern texpool (-1 lifetime anim) and legacy fallbacks
core._last_particlespawner = nil
tc_tools.spawn_water_splash_particles({x = 0, y = 1, z = 0}, true)
local sp = core._last_particlespawner
assert(sp and sp.texpool and #sp.texpool == 2, "Water+steam splash must include droplet & steam texpool entries")
assert(sp.texpool[1].animation and sp.texpool[1].animation.type == "vertical_frames"
    and sp.texpool[1].animation.length == -1, "Modern texpool entry must sync animation length = -1 to particle life")
assert(sp.pos and sp.minpos and sp.texture and sp.animation and sp.animation.length > 0,
    "Particle spawner must include legacy fallback fields alongside modern structured tables")

-- Verify Level 3 Asynchronous Multi-Plant Growth
tc_core.start_level(3, false)
assert(#tc_core.state.plants == 3, "Level 3 must initialize 3 plants")
local t_sum, t_min, t_max = 0.0, math.huge, -math.huge
local min_idx, max_idx = 1, 1
for i = 1, 3 do
    local gt = tc_core.state.plants[i].growth_tempo
    t_sum = t_sum + gt
    if gt < t_min then
        t_min = gt
        min_idx = i
    end
    if gt > t_max then
        t_max = gt
        max_idx = i
    end
end
assert(math.abs((t_sum / 3.0) - 1.0) < 0.001, "Mean growth_tempo across Level 3 plants must equal 1.00")
assert((t_max - t_min) >= 0.15, "Level 3 plants must have noticeably distinct growth_tempo values")

-- Step 31 seconds of pure Harmony without drops -> fastest plant reaches Stage 2 (>=25%) before slowest plant!
for step_n = 1, 31 do
    tc_core.state.drop_timer = 99.0
    for _, fn in ipairs(globalsteps) do fn(1.0) end
    if step_n == 31 then
        local fast_p = tc_core.state.plants[max_idx]
        local slow_p = tc_core.state.plants[min_idx]
        assert(fast_p.bloom > slow_p.bloom + 3.0,
            "Fastest plant must grow noticeably ahead of slowest plant in Harmony")
        assert(fast_p.stage >= 2 and core.get_node(fast_p.pos).name == "tc_elements:crucible_sprout_2",
            "Fastest plant must independently transition to Stage 2 (crucible_sprout_2)")
        assert(slow_p.stage == 1 and core.get_node(slow_p.pos).name == "tc_elements:crucible_sprout_1",
            "Slowest plant must still be in Stage 1 while fastest plant has already blossomed into Stage 2")
    end
end

-- Enrich 5 tiles of fertile_loam inside slowest plant's chamber -> verify local chamber soil acceleration!
local l3_cells = tc_world.get_active_cells(3)
local slow_cell = l3_cells[min_idx]
local enriched_cnt = 0
for x = slow_cell.min_x + 1, slow_cell.max_x - 1 do
    if enriched_cnt >= 5 then
        break
    end
    if tc_elements.enrich_soil_at({x = x, y = 0, z = slow_cell.min_z + 1}) then
        enriched_cnt = enriched_cnt + 1
    end
end
assert(enriched_cnt == 5, "Expected 5 fertile_loam tiles enriched in slowest chamber")
local slow_before = tc_core.state.plants[min_idx].bloom
tc_core.state.drop_timer = 99.0
for _, fn in ipairs(globalsteps) do fn(1.0) end
local slow_gain = tc_core.state.plants[min_idx].bloom - slow_before
assert(tc_core.state.plants[min_idx].fertile_near == 5, "Slowest chamber must detect 5 local fertile_loam tiles")
assert(slow_gain > ((0.85 / 1.16) * t_min) + 0.35,
    "Local chamber fertile_loam must accelerate that chamber's plant growth")

-- Verify zero-waste overflow redistribution when fastest plant hits 100% early
tc_core.state.plants[1].bloom = 99.0
tc_core.state.plants[2].bloom = 80.0
tc_core.state.plants[3].bloom = 85.0
tc_core.recalc_mean_bloom()
local mean_before = tc_core.state.bloom
local added = tc_core.add_bloom(4.0)
assert(math.abs(added - 4.0) < 0.01 and math.abs(tc_core.state.bloom - (mean_before + 4.0)) < 0.01,
    "Overflow Bloom past 100% on Plant #1 must redistribute cleanly to un-maxed plants with zero waste")
assert(math.abs(tc_core.state.plants[1].bloom - 100.0) < 0.001, "Plant #1 must clamp at 100.0%")
assert(not tc_core.state.victory, "Level must NOT complete while Plants #2 and #3 are still < 100% Bloom")

tc_core.add_bloom(20.0)
assert(math.abs(tc_core.state.bloom - 100.0) < 0.001, "All 3 plants reaching 100% must bring mean Bloom to 100%")
for _, fn in ipairs(globalsteps) do fn(1.0) end
assert(tc_core.state.victory, "All 3 plants reaching 100% Bloom must complete Level 3")
print("[OK] Animated sprite sheets (13 PNGs), vertical_frames tiles/particles & Level 3 asynchronous growth verified")

-- 14. Test 8 Next-Level Blessings: Single-Level Expiration (L1->L7), Anti-Repeat Draft, AoE Caps & 3 New Blessings
assert(#tc_core.BLESSING_ORDER == 8, "Expected 8 Garden Blessings in BLESSING_ORDER")
assert(rawget(tc_core, "BOON_ORDER") == nil and rawget(tc_core, "has_boon") == nil
    and rawget(tc_core, "grant_boon") == nil and tc_core.state.boons == nil,
    "Legacy permanent-upgrade APIs and state tables must be completely removed")

tc_core.start_level(1, false)
assert(tc_core.state.active_blessing == nil and tc_core.state.prev_blessing == nil,
    "Level 1 start must begin with no active or previous blessing")

-- Simulate completing Levels 1..6 into Level 7: verify single active blessing, expiration, and anti-repeat 3-card draft
for lvl = 1, 6 do
    assert(tc_core.state.level == lvl, "Expected active level " .. tostring(lvl))
    local prev_active = tc_core.state.active_blessing
    for i = 1, #tc_core.state.plants do
        tc_core.state.plants[i].bloom = 100.0
        tc_core.state.plants[i].vitality = 100.0
        tc_core.state.plants[i].withered = false
    end
    tc_core.recalc_mean_bloom()
    tc_core.state.drop_timer = 99.0
    for _, fn in ipairs(globalsteps) do fn(1.0) end
    assert(tc_core.state.victory, "Expected victory at 100% Bloom on Level " .. tostring(lvl))
    assert(tc_core.state.prev_blessing == prev_active, "Victory must record prev_blessing before rolling cards")

    local offered = tc_core.roll_offered_blessings()
    assert(#offered == 3, "Victory must always deal 3 Next-Level Blessing cards (even at Level 6+!)")
    assert(offered[1] ~= offered[2] and offered[2] ~= offered[3] and offered[1] ~= offered[3],
        "All 3 offered Next-Level Blessing cards must be distinct")
    for c_i = 1, 3 do
        assert(tc_core.BLESSING_DEFS[offered[c_i]] ~= nil, "Offered card must exist in BLESSING_DEFS")
        if prev_active then
            assert(offered[c_i] ~= prev_active,
                "Offered Next-Level Blessing cards must exclude the just-expired blessing: " .. tostring(prev_active))
        end
    end

    local picked_id = offered[1]
    for _, fn in ipairs(field_cbs) do
        fn(p1, "tc_core:victory", {btn_blessing_1 = "Pick"})
    end
    assert(tc_core.state.level == lvl + 1, "Picking card must advance to Level " .. tostring(lvl + 1))
    assert(tc_core.state.active_blessing == picked_id and tc_core.state.pending_blessing == nil,
        "Picked blessing must become the sole active_blessing for the new level")

    local active_cnt = 0
    for b_i = 1, #tc_core.BLESSING_ORDER do
        local bid = tc_core.BLESSING_ORDER[b_i]
        if tc_core.has_blessing(bid) then
            active_cnt = active_cnt + 1
            assert(bid == picked_id, "Unexpected active blessing: " .. tostring(bid))
        end
    end
    assert(active_cnt == 1, "Exactly 1 Next-Level Blessing may be active at any time (no multi-level stacking!)")
    if prev_active then
        assert(not tc_core.has_blessing(prev_active), "Previous level's blessing must expire when advancing!")
    end
end

-- Verify Deep Retort 5/5 flask clamps cleanly when expiring, and Level 3 grants +1 permanent capacity milestone
tc_core.start_level(1, false)
tc_core.select_blessing("deep_retort", false)
tc_core.start_level(2, true)
local l2_inv = p1:get_inventory():get_list("main")
local flask_slot_val = 0
for s_i = 1, #l2_inv do
    if l2_inv[s_i]:get_name() == "tc_tools:condenser_flask_full" then
        flask_slot_val = tc_tools.get_flask_charges(l2_inv[s_i])
    end
end
assert(flask_slot_val == 5, "Starting Level 2 with Deep Retort must fill player's Water Flask to 5/5")
tc_core.select_blessing(nil, true)
local l2_expired_inv = p1:get_inventory():get_list("main")
local l2_clamped_val = 0
for s_i = 1, #l2_expired_inv do
    if l2_expired_inv[s_i]:get_name() == "tc_tools:condenser_flask_full" then
        l2_clamped_val = tc_tools.get_flask_charges(l2_expired_inv[s_i])
    end
end
assert(l2_clamped_val == 3 and tc_tools.get_max_flask_charges() == 3,
    "Expiring Deep Retort on Level 2 must clamp held Water Flask back to 3/3")

tc_core.select_blessing("leyline_roots", false)
tc_core.start_level(3, true)
local l3_inv = p1:get_inventory():get_list("main")
local l3_flask_val = 0
for s_i = 1, #l3_inv do
    if l3_inv[s_i]:get_name() == "tc_tools:condenser_flask_full" then
        l3_flask_val = tc_tools.get_flask_charges(l3_inv[s_i])
    end
end
assert(l3_flask_val == 4 and tc_tools.get_max_flask_charges() == 4,
    "Advancing to Level 3 without Deep Retort must grant +1 milestone capacity (4/4 Splashes)")

-- Verify AoE Caps under Harmony Boost: Bellows <= 3x3 (radius 1) and Pestle <= 5x5 (radius 2)
tc_core.start_level(1, false)
tc_core.select_blessing("dragonlung_bellows", true)
tc_core.apply_effect(p1, "harmonic_overdrive", 10.0)
for dx = -2, 2 do
    for dz = -2, 2 do
        core.set_node({x = dx, y = 1, z = dz}, {name = "tc_elements:cryo_ice"})
    end
end
local bellows_def = registered_tools["tc_tools:bellows"]
bellows_def.on_use(
    ItemStack("tc_tools:bellows"), p1,
    {type = "node", under = {x = 0, y = 1, z = 0}, above = {x = 0, y = 2, z = 0}}
)
local rem_ice = core.find_nodes_in_area({x = -2, y = 1, z = -2}, {x = 2, y = 1, z = 2}, {"tc_elements:cryo_ice"})
assert(#rem_ice == 16,
    "Dragonlung Bellows + Harmony Boost must cap at 3x3 (9 melted, 16 outer 5x5 untouched), got rem=" .. #rem_ice)
assert(math.abs(tc_core.state.bloom - (9 * 1.5)) < 0.01,
    "Dragonlung Bellows must grant 1.5% Bloom per melted ice on L1")

tc_core.start_level(1, false)
tc_core.select_blessing("starlight_mortar", true)
tc_core.apply_effect(p1, "harmonic_overdrive", 10.0)
for dx = -3, 3 do
    for dz = -3, 3 do
        core.set_node({x = dx, y = 1, z = dz}, {name = "tc_elements:acid_slime"})
    end
end
local pestle_def = registered_tools["tc_tools:chalk_pestle"]
pestle_def.on_use(
    ItemStack("tc_tools:chalk_pestle"), p1,
    {type = "node", under = {x = 0, y = 1, z = 0}, above = {x = 0, y = 2, z = 0}}
)
local rem_acid = core.find_nodes_in_area({x = -3, y = 1, z = -3}, {x = 3, y = 1, z = 3}, {"tc_elements:acid_slime"})
assert(#rem_acid == 24,
    "Starlight Mortar + Harmony Boost must cap at 5x5 (25 cleared, 24 outer 7x7 untouched), got rem=" .. #rem_acid)

-- Verify Featherfall Winds (featherfall_canopy): 7.0s start delay, gentle descent (-1.0/-1.5), +3.0% mid-air Bloom
tc_core.select_blessing("featherfall_canopy", false)
tc_core.start_level(2, true)
assert(math.abs(tc_core.state.drop_timer - 7.0) < 0.01, "Featherfall Winds must start level with 7.0s drop_timer")
tc_core.start_level(1, false)
tc_core.select_blessing("featherfall_canopy", true)
spawned_entities = {}
tc_elements.spawn_falling_reagent({x = 2, y = 1, z = 2}, "tc_elements:cryo_ice")
local ff_ent = spawned_entities[1]
assert(math.abs(ff_ent._vel.y - (-1.0)) < 0.01 and math.abs(ff_ent._acc.y - (-1.5)) < 0.01,
    "Featherfall Winds must slow falling block descent to v0 = -1.0, a = -1.5")
p1:set_wielded_item(ItemStack("tc_tools:bellows"))
ff_ent:on_punch(p1)
assert(math.abs(tc_core.state.bloom - 3.0) < 0.01, "Featherfall Winds mid-air catch must grant +3.0% Bloom on L1")

-- Verify Crystal Resonance (prismatic_catalyst): +25% Trowel combo Bloom & Geode on Wave 2
tc_core.start_level(1, false)
tc_core.select_blessing("prismatic_catalyst", true)
core.set_node({x = 2, y = 1, z = 2}, {name = "tc_elements:brimstone"})
core.set_node({x = 3, y = 1, z = 2}, {name = "tc_elements:cryo_ice"})
tc_core.exec_melt_cancel({x = 3, y = 1, z = 2}, {x = 2, y = 1, z = 2})
assert(math.abs(tc_core.state.bloom - 3.75) < 0.01, "Crystal Resonance must boost Hot+Cold combo to +3.75% Bloom")
core.set_node({x = -2, y = 1, z = 2}, {name = "tc_elements:acid_slime"})
core.set_node({x = -3, y = 1, z = 2}, {name = "tc_elements:alkaline_chalk"})
tc_core.exec_acid_base({x = -2, y = 1, z = 2}, {x = -3, y = 1, z = 2})
assert(math.abs(tc_core.state.bloom - (3.75 + 4.375)) < 0.01,
    "Crystal Resonance must boost Acid+Chalk combo to +4.375% Bloom")

tc_core.select_blessing("prismatic_catalyst", false)
tc_core.start_level(2, true)
spawned_entities = {}
tc_core.state.wave = 1
tc_core.state.drop_timer = 1.0
for _, fn in ipairs(globalsteps) do fn(1.0) end
local found_wave2_geode = false
for e_i = 1, #spawned_entities do
    if spawned_entities[e_i].item_name == "tc_elements:aether_geode" then
        found_wave2_geode = true
    end
end
assert(found_wave2_geode, "Crystal Resonance must drop a Prismatic Geode on Wave 2 of Level 2+!")

-- Verify Sunlit Dew (sunlit_dew): +2 Aegis Potions on level start (cap 3), 14s shield & +2 HP / 3s Harmony heal
p1:get_inventory():set_list("main", {})
tc_core.player_stats["SaKeL"].neutralized = 0
tc_core.select_blessing("sunlit_dew", false)
tc_core.start_level(2, true)
local function count_inv_item(pl, item_name)
    local total = 0
    for _, st in ipairs(pl:get_inventory():get_list("main")) do
        if st:get_name() == item_name then
            total = total + st:get_count()
        end
    end
    return total
end
local ag_start = count_inv_item(p1, "tc_tools:elixir_aegis")
local ch_start = count_inv_item(p1, "tc_tools:chronos_sandglass")
assert(ag_start == 2 and ch_start == 1,
    "Sunlit Dew must grant 2 Aegis Potions & 1 Chronos Hourglass at the start of Level 2")
assert(tc_core.get_potion_cap("tc_tools:elixir_aegis") == 3, "Sunlit Dew must raise Aegis belt cap to 3")
local sd_ag = ItemStack("tc_tools:elixir_aegis")
registered_craftitems["tc_tools:elixir_aegis"].on_use(sd_ag, p1)
assert(tc_core.state.aegis_timer >= 13.9, "Sunlit Dew must extend Aegis Potion shield to 14s")
tc_core.clear_player_effects(p1, true)
p1:set_hp(14)
p1:set_pos({x = 0, y = 0.5, z = -2})
for _ = 1, 3 do
    tc_core.step_player_hazards(true)
end
assert(p1:get_hp() == 16, "Sunlit Dew must heal +2 HP (1 Heart) after 3s of Calm Balance")
print("[OK] All 8 Next-Level Blessings, single-level expiration (L1->L7), anti-repeat draft & 3x3/5x5 AoE caps verified")

-- 15. Gameplay Balance, Ergonomics & Progressive Challenge Suite
-- (a) Pre-filled 3/3 starting Water Flask on fresh Level 1, without free refill on empty-flask respawn
tc_core.start_level(1, false)
local l1_start_charges = 0
for _, st in ipairs(p1:get_inventory():get_list("main")) do
    if st:get_name() == "tc_tools:condenser_flask_full" then
        l1_start_charges = tc_tools.get_flask_charges(st)
    end
end
assert(l1_start_charges == 3, "Fresh Level 1 start must equip player with pre-filled 3/3 Water Flask")
p1:get_inventory():set_list("main", {ItemStack("tc_tools:condenser_flask")})
tc_init.equip_player(p1, false)
assert(not p1:get_inventory():contains_item("main", "tc_tools:condenser_flask_full"),
    "Respawn equip_player(_, false) while holding empty flask must NOT grant a free refill")

-- (b) Steam movement physics, direct Flask pointabilities, Aerial Catch (+2.8% Bloom) & Steam Mist Hydration
local steam_def = registered_nodes["tc_elements:steam"]
assert(not steam_def.climbable, "Steam must NOT set climbable=true (no sticky ladder movement!)")
assert(flask_empty_def.pointabilities and flask_empty_def.pointabilities.nodes["group:steam"] == true,
    "Empty Water Flask must directly raycast group:steam")
assert(flask_full_def.pointabilities and flask_full_def.pointabilities.nodes["group:steam"] == true,
    "Full Water Flask must directly raycast group:steam")

tc_core.start_level(1, false)
spawned_entities = {}
tc_elements.spawn_falling_reagent({x = 2, y = 1, z = 2}, "tc_elements:cryo_ice")
local aerial_ent = spawned_entities[1]
p1._vel = {x = 0, y = 2.5, z = 0}
p1:set_wielded_item(ItemStack("tc_tools:bellows"))
aerial_ent:on_punch(p1)
p1._vel = {x = 0, y = 0, z = 0}
assert(math.abs(tc_core.state.bloom - 2.8) < 0.01,
    "Airborne mid-air catch must award +2.8% Bloom (+0.6% Aerial Catch bonus over +2.2%)")

tc_core.start_level(1, false)
tc_core.state.plants[1].vitality = 80.0
core.set_node({x = 1, y = 1, z = 0}, {name = "tc_elements:steam"})
core.set_node({x = 3, y = 1, z = 3}, {name = "tc_elements:brimstone"})
core.set_node({x = -3, y = 1, z = -3}, {name = "tc_elements:cryo_ice"})
tc_core.state.drop_timer = 99.0
for _, fn in ipairs(globalsteps) do fn(1.0) end
assert(math.abs(tc_core.state.plants[1].vitality - 80.6) < 0.01,
    "Steam within 2 tiles of a hurt Sprout must hydrate +0.6% Vitality/s even when turbulent")

-- (c) Non-diggable reagents, Left-Click Trowel scoop, and Direct Opposite-Block Combos (Hot+Cold & Acid+Chalk)
for _, r in ipairs(tc_elements.REAGENTS) do
    local rdef = registered_nodes[r.name]
    assert(rdef.diggable == false and rdef.drop == "",
        "Reagent " .. r.name .. " must have diggable=false and drop=''")
end

tc_core.start_level(1, false)
core.set_node({x = 2, y = 1, z = 2}, {name = "tc_elements:brimstone"})
core.set_node({x = 4, y = 1, z = 2}, {name = "tc_elements:cryo_ice"})
p1:set_wielded_item(ItemStack("tc_tools:trowel"))
registered_nodes["tc_elements:brimstone"].on_punch({x = 2, y = 1, z = 2}, {name = "tc_elements:brimstone"}, p1)
assert(tc_tools.get_trowel_cargo(p1:get_wielded_item()) == "tc_elements:brimstone",
    "Left-Clicking Brimstone with Trowel must scoop it onto tongs")
assert(core.get_node({x = 2, y = 1, z = 2}).name == "air", "Left-Click scooped Brimstone must clear from floor")

-- Direct click onto opposite Cryo-Ice at (4, 1, 2)
registered_nodes["tc_elements:cryo_ice"].on_punch({x = 4, y = 1, z = 2}, {name = "tc_elements:cryo_ice"}, p1)
assert(tc_tools.get_trowel_cargo(p1:get_wielded_item()) == "", "Direct opposite click must consume Trowel cargo")
assert(core.get_node({x = 4, y = 1, z = 2}).name == "tc_elements:water_source",
    "Direct Hot+Cold Trowel click must leave water_source at target coordinate")
assert(core.get_node({x = 4, y = 2, z = 2}).name == "tc_elements:steam",
    "Direct Hot+Cold Trowel click must spawn rising steam above water_source")
assert(math.abs(tc_core.state.bloom - 3.0) < 0.01, "Direct Hot+Cold Trowel combo must grant +3.0% Bloom")

-- Direct Acid+Chalk click must enrich 2 fertile_loam floor tiles!
tc_core.start_level(1, false)
core.set_node({x = -2, y = 1, z = -2}, {name = "tc_elements:alkaline_chalk"})
core.set_node({x = -2, y = 1, z = 2}, {name = "tc_elements:acid_slime"})
p1:set_wielded_item(ItemStack("tc_tools:trowel"))
registered_nodes["tc_elements:alkaline_chalk"].on_punch(
    {x = -2, y = 1, z = -2}, {name = "tc_elements:alkaline_chalk"}, p1
)
registered_nodes["tc_elements:acid_slime"].on_punch(
    {x = -2, y = 1, z = 2}, {name = "tc_elements:acid_slime"}, p1
)
local direct_fertile = core.find_nodes_in_area(
    {x = -4, y = 0, z = 0}, {x = 0, y = 0, z = 4}, {"tc_elements:fertile_loam"}
)
assert(#direct_fertile == 2, "Direct Chalk+Acid Trowel combo must enrich 2 fertile_loam floor tiles!")
assert(math.abs(tc_core.state.bloom - 3.5) < 0.01, "Direct Chalk+Acid Trowel combo must grant +3.5% Bloom")

-- (d) Bellows [2] Water Preservation when melting Ice + placer credit on immediate chain-quench
tc_core.start_level(1, false)
tc_core.player_stats["SaKeL"].neutralized = 0
core.set_node({x = 2, y = 1, z = 2}, {name = "tc_elements:cryo_ice"})
core.set_node({x = 2, y = 1, z = 3}, {name = "tc_elements:water_source"})
core.set_node({x = 3, y = 1, z = 2}, {name = "tc_elements:brimstone"})
bellows_def.on_use(
    ItemStack("tc_tools:bellows"), p1,
    {type = "node", under = {x = 2, y = 1, z = 2}, above = {x = 2, y = 2, z = 2}}
)
assert(core.get_node({x = 2, y = 1, z = 3}).name == "tc_elements:water_source",
    "Bellows melting Ice must preserve existing adjacent water_source puddles")
assert(core.get_node({x = 3, y = 1, z = 2}).name == "tc_elements:steam",
    "Melted Ice adjacent to Brimstone must immediately chain-quench Brimstone into Steam")
assert(tc_core.player_stats["SaKeL"].neutralized == 2,
    "Bellows melting Ice + chain-quenching Brimstone must credit both clears to the player")

-- Standalone Water with 0 Ice nearby must still evaporate into Steam when puffed with Bellows
bellows_def.on_use(
    ItemStack("tc_tools:bellows"), p1,
    {type = "node", under = {x = 2, y = 1, z = 3}, above = {x = 2, y = 2, z = 3}}
)
assert(core.get_node({x = 2, y = 1, z = 3}).name == "tc_elements:steam",
    "Bellows puffing standalone water_source (with 0 Ice) must evaporate it into Steam")

-- (e) Scarce Potion Belt Caps (2/2), Zero Kill-Counter Spam & Zero-Waste Alchemical Overflow
assert(registered_craftitems["tc_tools:elixir_aegis"].stack_max == 3, "Aegis stack_max must be 3")
assert(registered_craftitems["tc_tools:chronos_sandglass"].stack_max == 2, "Chronos stack_max must be 2")
tc_core.start_level(1, false)
p1:get_inventory():set_list("main", {})
tc_core.player_stats["SaKeL"].neutralized = 0
tc_core.record_neutralization(p1, 20)
assert(tc_core.player_stats["SaKeL"].neutralized == 20, "record_neutralization must track cleared hazard count")
assert(count_inv_item(p1, "tc_tools:elixir_aegis") == 0
    and count_inv_item(p1, "tc_tools:chronos_sandglass") == 0,
    "Clearing floor hazards must never spam-grant potions")

-- Overflow conversion past cap 2 for Aegis
tc_core.grant_potion(p1, "tc_tools:elixir_aegis", 2)
assert(count_inv_item(p1, "tc_tools:elixir_aegis") == 2, "Aegis Belt must fill to cap 2")
local bloom_pre_ov = tc_core.state.bloom
p1:set_hp(12)
tc_core.state.plants[1].vitality = 75.0
tc_core.grant_potion(p1, "tc_tools:elixir_aegis", 1)
assert(count_inv_item(p1, "tc_tools:elixir_aegis") == 2, "Excess Aegis past cap 2 must not clutter inventory")
assert(math.abs(tc_core.state.bloom - (bloom_pre_ov + 1.5)) < 0.01,
    "Overflow Aegis must convert into +1.5% scaled Bloom")
assert(p1:get_hp() == 18 and math.abs(tc_core.state.plants[1].vitality - 90.0) < 0.01,
    "Overflow Aegis must restore +6 Player HP and +15% Plant Vitality")

-- (f) Monotonic Wave Intervals (L1..L8), Level 3+ Wizard's Trial Waves, 85% Final Surge & Glass Archways
tc_core.start_level(1, false)
local prev_iv = math.huge
for lvl = 1, 8 do
    local iv = tc_core.get_next_wave_interval(lvl, 1)
    assert(iv < prev_iv,
        string.format("Wave interval must tighten monotonically every level (L%d=%.2f >= prev=%.2f)", lvl, iv, prev_iv))
    prev_iv = iv
end
assert(tc_core.get_next_wave_interval(1, 1) >= tc_core.get_next_wave_interval(8, 1) + 1.99,
    "Level 8 wave interval must be >= 2.0s faster than Level 1")

-- Verify Level 2 Brass-Framed Glass Archway Corner Pillars (4 pillars, wide 9-block open doorway)
assert(#tc_world.get_archway_pillars(1) == 0, "Level 1 must have 0 archway pillars")
tc_core.start_level(2, false)
local l2_pillars = tc_world.get_archway_pillars(2)
assert(#l2_pillars == 4, "Level 2 (2 connected rooms) must have 4 corner archway pillars, got " .. #l2_pillars)
assert(core.get_node({x = 5, y = 1, z = -5}).name == "tc_elements:flask_rim"
    and core.get_node({x = 5, y = 2, z = -5}).name == "tc_elements:flask_glass",
    "Archway corner (5, -5) must be framed with flask_rim base and flask_glass column")
for z = -4, 4 do
    assert(core.get_node({x = 5, y = 1, z = z}).name == "air"
        and core.get_node({x = 6, y = 1, z = z}).name == "air",
        "9-block wide archway passage z = -4..4 between Room 1 and Room 2 must be completely open air!")
end

-- Verify Level 3+ Wave 3 Wizard's Trial Wave & 85% Final Bloom Surge
tc_core.start_level(3, false)
spawned_entities = {}
tc_core.state.wave = 2
tc_core.state.drop_timer = 1.0
for _, fn in ipairs(globalsteps) do fn(1.0) end
assert(tc_core.state.wave == 3 and tc_core.state.trial_cursor == 1,
    "Wave 3 on Level 3 must trigger Wizard's Trial Wave #1 (Twin Opposites)")

spawned_entities = {}
for i = 1, 3 do
    tc_core.state.plants[i].bloom = 86.0
end
tc_core.recalc_mean_bloom()
tc_core.state.drop_timer = 4.0
for _, fn in ipairs(globalsteps) do fn(1.0) end
assert(tc_core.state.climax_triggered == true, "Crossing 85% Bloom on Level 3+ must trigger Final Bloom Surge once")
local surge_geode = false
for e_i = 1, #spawned_entities do
    if spawned_entities[e_i].item_name == "tc_elements:aether_geode" then
        surge_geode = true
    end
end
assert(surge_geode, "85% Final Bloom Surge must drop a bonus Prismatic Geode!")
print("[OK] Pre-filled 3/3 Flask, Direct Trowel Combos, Potion Belt Overflow, Archways & L3+ Trials/Surge verified")

-- 16. Existing-World Login Reset, Same-Run Reconnect Sanitization & Core Tool [Q] Drop Guard
-- Simulate server startup on an existing world BEFORE player finishes connecting (#mock_players == 0)
for _, fn in ipairs(leave_cbs) do fn(p1) end
mock_players = {}
tc_core.start_level(1, false)

-- Populate p1's persisted players.sqlite inventory with stale items from a prior session (exact bug reproduction)
local legacy_speed_potion = "tc_tools:" .. "elixir_quicksilver"
local worn_flask = tc_tools.consume_flask_charge(tc_tools.fill_flask())
p1:get_inventory():set_list("main", {
    tc_tools.set_trowel_cargo(ItemStack("tc_tools:trowel"), "tc_elements:brimstone"),
    ItemStack("tc_tools:bellows"),
    worn_flask,
    ItemStack("tc_tools:chalk_pestle"),
    ItemStack("tc_tools:guide_tome"),
    ItemStack(legacy_speed_potion .. " 10"),
    ItemStack("tc_tools:elixir_aegis 6"),
    ItemStack("tc_tools:chronos_sandglass 2"),
    ItemStack("tc_elements:brimstone 2"),
    ItemStack("tc_elements:alkaline_chalk 1"),
})

-- Now player connects to the world after start_level(1) already ran
table.insert(mock_players, p1)
for _, fn in ipairs(join_cbs) do fn(p1) end

assert(count_inv_item(p1, legacy_speed_potion) == 0,
    "Connecting to a fresh Level 1 world session must clear removed legacy speed potion stacks")
assert(count_inv_item(p1, "tc_tools:elixir_aegis") == 0,
    "Connecting to a fresh Level 1 world session must clear stale Aegis stacks")
assert(count_inv_item(p1, "tc_tools:chronos_sandglass") == 0,
    "Connecting to a fresh Level 1 world session must clear stale Chronos stacks")
assert(count_inv_item(p1, "tc_elements:brimstone") == 0
    and count_inv_item(p1, "tc_elements:alkaline_chalk") == 0,
    "Connecting to world must strip legacy raw reagent blocks from player inventory")

local login_list = p1:get_inventory():get_list("main")
assert(#login_list == 5, "Clean Level 1 starter loadout must contain exactly the 5 core hotbar tools")
assert(login_list[1]:get_name() == "tc_tools:trowel" and tc_tools.get_trowel_cargo(login_list[1]) == "",
    "Slot [1] must be an empty Trowel")
assert(login_list[2]:get_name() == "tc_tools:bellows", "Slot [2] must be Thermal Bellows")
assert(login_list[3]:get_name() == "tc_tools:condenser_flask_full"
    and tc_tools.get_flask_charges(login_list[3]) == 3
    and login_list[3]:get_wear() == 0,
    "Slot [3] must be a fresh 3/3 filled Water Flask with 0 wear")
assert(login_list[4]:get_name() == "tc_tools:chalk_pestle", "Slot [4] must be Limestone Pestle")
assert(login_list[5]:get_name() == "tc_tools:guide_tome", "Slot [5] must be Gardener's Guidebook")

-- Simulate brief disconnect & reconnect during the SAME active multiplayer run:
-- earned potions stay (clamped to cap), while invalid or removed items are stripped
p1:get_inventory():add_item("main", "tc_tools:elixir_aegis 6")
p1:get_inventory():add_item("main", "tc_tools:chronos_sandglass 1")
p1:get_inventory():add_item("main", legacy_speed_potion .. " 10")
p1:get_inventory():add_item("main", "tc_elements:brimstone 2")
for _, fn in ipairs(leave_cbs) do fn(p1) end
for _, fn in ipairs(join_cbs) do fn(p1) end
assert(count_inv_item(p1, "tc_tools:chronos_sandglass") == 1,
    "Same-run reconnect must preserve legitimately earned potions from the current run")
assert(count_inv_item(p1, "tc_tools:elixir_aegis") == 2,
    "Same-run reconnect must clamp oversized Aegis stacks to belt cap (2)")
assert(count_inv_item(p1, legacy_speed_potion) == 0,
    "Same-run reconnect must strip removed legacy potion items")
assert(count_inv_item(p1, "tc_elements:brimstone") == 0,
    "Same-run reconnect must strip raw reagent blocks")

-- Verify core tools [1-5] cannot be accidentally thrown away with [Q] (on_drop)
local protected_tools = {
    "tc_tools:trowel",
    "tc_tools:bellows",
    "tc_tools:bellows_empty",
    "tc_tools:condenser_flask",
    "tc_tools:condenser_flask_full",
    "tc_tools:chalk_pestle",
    "tc_tools:chalk_pestle_empty",
    "tc_tools:guide_tome",
}
for _, tname in ipairs(protected_tools) do
    local tdef = registered_tools[tname]
    assert(tdef and type(tdef.on_drop) == "function", "Core tool " .. tname .. " must define on_drop guard")
    local kept = tdef.on_drop(ItemStack(tname), p1, p1:get_pos())
    assert(kept and kept:get_name() == tname and kept:get_count() == 1,
        "Pressing [Q] on " .. tname .. " must keep the tool in the player's hotbar")
end
print("[OK] Existing-world login inventory reset, same-run reconnect sanitization & core tool [Q] guard verified")

-- 17. Temporary Effect Countdown Bars (hudbars) & Top Banner Deduplication Suite
local function read_png_dims(path)
    local f = io.open(path, "rb")
    assert(f ~= nil, "Missing PNG file: " .. tostring(path))
    local hdr = f:read(24)
    f:close()
    assert(hdr and #hdr == 24 and hdr:sub(1, 8) == "\137PNG\13\10\26\10", "Invalid PNG header: " .. tostring(path))
    local b17, b18, b19, b20, b21, b22, b23, b24 = hdr:byte(17, 24)
    local w = b17 * 16777216 + b18 * 65536 + b19 * 256 + b20
    local h = b21 * 16777216 + b22 * 65536 + b23 * 256 + b24
    return w, h
end

local bg_w, bg_h = read_png_dims(tex_dir .. "tc_bar_background.png")
assert(bg_w == 194 and bg_h == 26,
    string.format("tc_bar_background.png must be 194x26 pixels (got %dx%d)", bg_w, bg_h))
for _, bar_tex in ipairs({"tc_bar_bloom.png", "tc_bar_vitality.png", "tc_bar_temperature.png", "tc_bar_ph.png"}) do
    local bw, bh = read_png_dims(tex_dir .. bar_tex)
    assert(bw == 2 and bh == 24,
        string.format("%s must be 2x24 pixels (got %dx%d)", bar_tex, bw, bh))
end

for _, eff_id in ipairs(tc_core.EFFECT_ORDER) do
    local edef = tc_core.EFFECT_DEFS[eff_id]
    assert(edef and edef.hud_label and edef.bar_tex and edef.icon_tex, "Incomplete EFFECT_DEFS for " .. eff_id)
    local bw, bh = read_png_dims(tex_dir .. edef.bar_tex)
    assert(bw == 2 and bh == 24,
        string.format("%s must be 2x24 pixels (got %dx%d)", edef.bar_tex, bw, bh))
    local iw, ih = read_png_dims(tex_dir .. edef.icon_tex)
    assert(iw == 24 and ih == 24,
        string.format("%s must be 24x24 pixels (got %dx%d)", edef.icon_tex, iw, ih))
end

-- Verify centered text & enlarged padding on permanent HUD gauges
local bloom_ids = hb.get_hudtable("bloom").hudids["SaKeL"]
assert(p1._hud_elems[bloom_ids.bg].text == "tc_bar_background.png", "HUD bar background must use tc_bar_background.png")
assert(p1._hud_elems[bloom_ids.text].alignment.y == 0, "HUD bar text must be vertically centered (alignment.y == 0)")

tc_core.start_level(1, false)
tc_core.clear_player_effects(p1, true)

-- (a) With 0 active effects, all 6 effect_1..effect_6 hudbars must be hidden and idle steps emit 0 HUD changes
for k = 1, 6 do
    local st = hb.get_hudbar_state(p1, "effect_" .. k)
    assert(st and st.hidden == true, "effect_" .. k .. " must start hidden when 0 effects are active")
end
p1:set_pos({x = 0, y = 1.5, z = -2.8})
tc_core.sync_player_atmosphere(p1)
local changes_before_idle = p1._hud_changes
tc_core.step_player_effects(0.25)
assert(p1._hud_changes == changes_before_idle,
    "Idle 0.25s step with 0 active effects must emit 0 HUD change packets")

-- (b) Applying multiple effects out of priority order packs them contiguously into effect_1..effect_3 with 0 gaps
tc_core.apply_effect(p1, "fertile_stride", 3.5)
tc_core.apply_effect(p1, "chronos_surge", 12.0)
tc_core.apply_effect(p1, "aegis_ward", 12.0)

local s1 = hb.get_hudbar_state(p1, "effect_1")
local s2 = hb.get_hudbar_state(p1, "effect_2")
local s3 = hb.get_hudbar_state(p1, "effect_3")
local s4 = hb.get_hudbar_state(p1, "effect_4")
assert(not s1.hidden and s1.text == "Aegis Shield: 12.0s" and s1.barlength == 192,
    "effect_1 must show full Aegis Shield: 12.0s (barlength 192), got " .. tostring(s1.text))
assert(not s2.hidden and s2.text == "Time Freeze: 12.0s" and s2.barlength == 192,
    "effect_2 must show full Time Freeze: 12.0s (barlength 192), got " .. tostring(s2.text))
assert(not s3.hidden and s3.text == "Soil Speed: 3.5s" and s3.barlength == 192,
    "effect_3 must show full Soil Speed: 3.5s (barlength 192), got " .. tostring(s3.text))
assert(s4.hidden == true, "effect_4 must stay hidden when 3 effects are active")

-- Verify actual client HUD bar & icon textures on effect_2
local e2_ids = hb.get_hudtable("effect_2").hudids["SaKeL"]
assert(p1._hud_elems[e2_ids.bar].text == "tc_bar_effect_chronos.png", "effect_2 bar texture mismatch")
assert(p1._hud_elems[e2_ids.icon].text == "tc_icon_effect_chronos.png", "effect_2 icon texture mismatch")

-- (c) Step 1.5s -> bars drain smoothly; removing middle effect (chronos_surge) compacts Soil Speed into effect_2!
for _ = 1, 6 do
    tc_core.step_player_effects(0.25)
end
local s2_drained = hb.get_hudbar_state(p1, "effect_2")
local s3_drained = hb.get_hudbar_state(p1, "effect_3")
assert(s2_drained.text == "Time Freeze: 10.5s" and s2_drained.barlength < 192 and s2_drained.barlength > 155,
    "Time Freeze bar must drain smoothly after 1.5s, got " .. tostring(s2_drained.text))
assert(s3_drained.text == "Soil Speed: 2.0s" and s3_drained.barlength < 130,
    "Soil Speed bar must drain to 2.0s after 1.5s, got " .. tostring(s3_drained.text))

tc_core.remove_effect(p1, "chronos_surge")
local s2_compacted = hb.get_hudbar_state(p1, "effect_2")
local s3_compacted = hb.get_hudbar_state(p1, "effect_3")
assert(not s2_compacted.hidden and s2_compacted.text == "Soil Speed: 2.0s",
    "Removing Time Freeze must compact Soil Speed up into effect_2 with zero gap, got " .. tostring(s2_compacted.text))
assert(p1._hud_elems[e2_ids.bar].text == "tc_bar_effect_soil.png"
    and p1._hud_elems[e2_ids.icon].text == "tc_icon_effect_soil.png",
    "Compacting Soil Speed into effect_2 must swap bar & icon textures to soil")
assert(s3_compacted.hidden == true, "effect_3 must hide immediately when 3rd effect compacts into effect_2")

-- (d) Zero-packet sustain while standing continuously on green Speed Soil (tc_elements:fertile_loam)
tc_core.clear_player_effects(p1, true)
core.set_node({x = 0, y = 0, z = 2}, {name = "tc_elements:fertile_loam"})
p1:set_pos({x = 0, y = 1.05, z = 2})
tc_core.step_player_effects(0.25)
assert(hb.get_hudbar_state(p1, "effect_1").text == "Soil Speed: 3.5s", "Standing on green soil must show Soil Speed")
local steady_changes = p1._hud_changes
tc_core.step_player_effects(0.25)
tc_core.step_player_effects(0.25)
assert(p1._hud_changes == steady_changes,
    "Sustained standing on green Speed Soil must emit 0 redundant HUD packets across ticks")
p1:set_pos({x = 0, y = 1.5, z = -2.8})

-- (e) Multiplayer per-player label isolation in shared hudtable.label across 0.25s ticks
tc_core.clear_player_effects(p1, true)
local p_mp = make_mock_player("CoopPartner")
table.insert(mock_players, p_mp)
for _, fn in ipairs(join_cbs) do fn(p_mp) end

tc_core.apply_effect(p1, "chronos_surge", 10.0)
tc_core.apply_effect(p_mp, "steam_updraft", 5.0)
for _ = 1, 4 do
    tc_core.step_player_effects(0.25)
end
local p1_e1_id = hb.get_hudtable("effect_1").hudids["SaKeL"].text
local mp_e1_id = hb.get_hudtable("effect_1").hudids["CoopPartner"].text
assert(p1._hud_elems[p1_e1_id].text == "Time Freeze: 9.0s",
    "Player 1 effect_1 label must stay isolated as Time Freeze: 9.0s, got " .. tostring(p1._hud_elems[p1_e1_id].text))
assert(p_mp._hud_elems[mp_e1_id].text == "Steam Jump: 4.0s",
    "Player 2 effect_1 label must stay isolated as Steam Jump: 4.0s, got " .. tostring(p_mp._hud_elems[mp_e1_id].text))

for _, fn in ipairs(leave_cbs) do fn(p_mp) end
table.remove(mock_players)

-- (f) Top-center Banner Line 2 deduplication & immediate hiding on clear_player_effects / Victory / Reset
tc_core.select_blessing("deep_retort", true)
tc_core.update_player_hud(p1)
local found_blessing_banner = false
for _, h in pairs(p1._hud_elems) do
    if h and h.type == "text" and type(h.text) == "string" then
        assert(not h.text:find("Boosts:"), "Top banner must deduplicate and omit legacy 'Boosts:' text: " .. h.text)
        if h.text:find("Blessing: Deep Retort") then
            found_blessing_banner = true
        end
    end
end
assert(found_blessing_banner, "Top banner Line 2 must display active level Blessing title")

tc_core.reset_crucible()
for k = 1, 6 do
    assert(hb.get_hudbar_state(p1, "effect_" .. k).hidden == true,
        "Resetting crucible must immediately hide effect_" .. k)
end
print("[OK] Padded 192x24 HUD bars, 24x24 icons, zero-gap effect packing, MP isolation & banner verified")

-- 18. Luanti Hypertext Escaping & Zero HTML Entity Regression Suite across All Dialogs & Item Copy
local function assert_no_html_entities(label, text)
    assert(type(text) == "string" and text ~= "", "Expected non-empty text for " .. label)
    local bad = text:match("&[a-zA-Z0-9#]+;")
    assert(bad == nil, string.format("Unformatted HTML entity '%s' leaked into %s!", tostring(bad), label))
end

-- Check all registered items' description & short_description
for name, def in pairs(registered_items) do
    assert_no_html_entities(name .. ".description", def.description)
    assert_no_html_entities(name .. ".short_description", def.short_description)
end

-- Verify ui.ht_escape preserves '&' literally while escaping '\', '<', '>' for Luanti hypertext[]
assert(tc_assets.ui.ht_escape("A & B <40°C> \\ok") == "A & B \\<40°C\\> \\\\ok",
    "ui.ht_escape must use Luanti backslash escaping and keep '&' literal!")

-- Render every formspec screen in the game (Satchel, Guide Tabs 1..5, Garden, Leaderboard, Victory, Defeat)
assert_no_html_entities("satchel[I]", tc_init.build_satchel_formspec(p1))
for tab = 1, 5 do
    shown_formspecs["tc_core:guide"] = nil
    tc_core.show_guide_dialog(p1, tab)
    assert_no_html_entities("tc_core:guide[tab=" .. tab .. "]", shown_formspecs["tc_core:guide"])
end

tc_core.select_blessing("sunlit_dew", true)
shown_formspecs["tc_core:garden"] = nil
tc_core.show_garden_dialog(p1)
assert_no_html_entities("tc_core:garden", shown_formspecs["tc_core:garden"])

shown_formspecs["tc_core:leaderboard"] = nil
tc_core.show_leaderboard_dialog(p1)
assert_no_html_entities("tc_core:leaderboard", shown_formspecs["tc_core:leaderboard"])

tc_core.state.victory = true
tc_core.state.offered_blessings = {"sunlit_dew", "hermetic_boots", "prismatic_catalyst"}
shown_formspecs["tc_core:victory"] = nil
tc_core.show_victory_dialog(p1)
assert_no_html_entities("tc_core:victory", shown_formspecs["tc_core:victory"])
assert(shown_formspecs["tc_core:victory"]:find("+1 Aegis Potion & +1 Chronos Hourglass!", 1, true) ~= nil,
    "Victory summary must render literal '&' without HTML entity corruption")

tc_core.trigger_defeat("Too many uncleared hazards (>11 blocks & cracked glass!)")
assert_no_html_entities("tc_core:defeat", shown_formspecs["tc_core:defeat"])
tc_core.reset_crucible()
print("[OK] Zero HTML entities (&amp;/&lt;/&gt;) & native Luanti hypertext_escape verified across all UI screens")

-- 19. Player Hazard Damage, Acid Slime Wading, Non-Stacking Speed Monoid & Altar/Quicksilver Removal Suite
assert(registered_nodes["tc_elements:altar_stone"] == nil, "Obsolete tc_elements:altar_stone must be removed")
assert(registered_items["tc_tools:elixir_quicksilver"] == nil, "Obsolete tc_tools:elixir_quicksilver must be removed")

local acid_def = registered_nodes["tc_elements:acid_slime"]
assert(acid_def and acid_def.walkable == false and acid_def.move_resistance == 4
    and acid_def.groups and acid_def.groups.disable_jump == 1,
    "Acid Slime must be non-walkable viscous caustic mire (move_resistance=4, disable_jump=1)")

-- Brimstone contact burns player for 2 HP (and halves to 1 HP with Swift Alchemist Boots)
tc_core.start_level(1, false)
tc_core.clear_player_effects(p1, true)
p1:set_hp(20)
core.set_node({x = 2, y = 1, z = 2}, {name = "tc_elements:brimstone"})
p1:set_pos({x = 2, y = 1.5, z = 2})
tc_core.step_player_hazards(false)
assert(p1:get_hp() == 18, "Standing atop Brimstone must deal 2 HP burn damage, got " .. tostring(p1:get_hp()))

tc_core.select_blessing("hermetic_boots", true)
tc_core.step_player_hazards(false)
assert(p1:get_hp() == 17, "Swift Alchemist Boots must halve 2 HP Brimstone burn to 1 HP, got " .. tostring(p1:get_hp()))
tc_core.select_blessing("deep_retort", true)
core.set_node({x = 2, y = 1, z = 2}, {name = "air"})

-- Acid Slime wading burns player for 2 HP, and Aegis Shield blocks 100% of player hazard damage
core.set_node({x = -2, y = 1, z = 2}, {name = "tc_elements:acid_slime"})
p1:set_pos({x = -2, y = 0.5, z = 2})
tc_core.step_player_hazards(false)
assert(p1:get_hp() == 15, "Wading in Acid Slime must deal 2 HP caustic damage, got " .. tostring(p1:get_hp()))

tc_core.apply_effect(p1, "aegis_ward", 12.0)
tc_core.step_player_hazards(false)
assert(p1:get_hp() == 15, "Active Aegis Shield must block 100% of player hazard damage")
tc_core.remove_effect(p1, "aegis_ward")

-- Auto-Aegis triggers when hazard damage would otherwise KO a player carrying an Aegis Potion
p1:get_inventory():set_list("main", {ItemStack("tc_tools:elixir_aegis 1")})
p1:set_hp(2)
tc_core.step_player_hazards(false)
assert(p1:get_hp() == 20, "Lethal hazard damage with Aegis Potion must trigger Auto-Aegis and restore 20 HP")
assert(not p1:get_inventory():contains_item("main", "tc_tools:elixir_aegis"),
    "Auto-Aegis must consume 1 Aegis Potion")
core.set_node({x = -2, y = 1, z = 2}, {name = "air"})

-- Falling reagent block impact deals 3 HP and nudges player atop landed block
tc_core.clear_player_effects(p1, true)
p1:set_hp(20)
p1:set_pos({x = 3, y = 1.0, z = -2})
local drop_ent = setmetatable({
    item_name = "tc_elements:alkaline_chalk",
    epoch = tc_core.state.epoch,
    age = 0,
}, {__index = core.registered_entities["tc_elements:falling_reagent"]})
drop_ent.object = {
    get_pos = function() return {x = 3, y = 1.1, z = -2} end,
    get_velocity = function() return {x = 0, y = 0, z = 0} end,
    set_velocity = function() end,
    get_rotation = function() return {x = 0, y = 0, z = 0} end,
    set_rotation = function() end,
    remove = function() end,
}
drop_ent:on_step(0.1, {touching_ground = true})
assert(p1:get_hp() == 17, "Uncaught falling block landing on player must deal 3 HP, got " .. tostring(p1:get_hp()))
assert(p1:get_pos().y >= 1.55, "Landing block must nudge player above y=1.55 so they do not suffocate")
core.set_node({x = 3, y = 1, z = -2}, {name = "air"})

-- Calm Balance regeneration heals +1 HP every 5 calm hazard steps
p1:set_pos({x = 0, y = 1.5, z = -2.8})
for _ = 1, 5 do
    tc_core.step_player_hazards(true)
end
assert(p1:get_hp() == 18, "5 seconds of Calm Balance must regenerate +1 HP, got " .. tostring(p1:get_hp()))

-- Cracking Prismatic Geode rewards +1 Aegis Potion (not removed Quicksilver)
p1:get_inventory():set_list("main", {})
core.set_node({x = 2, y = 1, z = -2}, {name = "tc_elements:aether_geode"})
tc_elements.resonate_geode_at({x = 2, y = 1, z = -2}, p1)
assert(p1:get_inventory():contains_item("main", "tc_tools:elixir_aegis"),
    "Cracking Prismatic Geode must grant +1 Aegis Potion")

-- Non-stacking consolidated speed monoid (math.max across Soil Speed 1.50x / 1.70x, Chronos 1.35x, Harmony 1.25x)
tc_core.apply_effect(p1, "fertile_stride", 3.5)
tc_core.apply_effect(p1, "chronos_surge", 12.0)
tc_core.apply_effect(p1, "harmonic_overdrive", 8.0)
assert(math.abs(player_monoids.speed:value(p1) - 1.50) < 0.001,
    "Speed buffs must take math.max (1.50x) rather than multiplying, got " .. tostring(player_monoids.speed:value(p1)))
tc_core.select_blessing("hermetic_boots", true)
assert(math.abs(player_monoids.speed:value(p1) - 1.70) < 0.001,
    "Swift Alchemist Boots on Fertile Soil must reach 1.70x without compounding Chronos/Harmony")
tc_core.reset_crucible()
print("[OK] Player hazard damage, Acid Slime mire, Auto-Aegis, Geode Aegis reward & non-stacking speed verified")

-- 20. minetest.conf & game.conf Engine Configuration Integrity Suite
local function parse_kv_conf(path)
    local f = io.open(path, "r")
    assert(f ~= nil, "Missing configuration file: " .. tostring(path))
    local out = {}
    for line in f:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
            local k, v = trimmed:match("^([^=%s]+)%s*=%s*(.-)%s*$")
            if k then
                out[k] = v
            end
        end
    end
    f:close()
    return out
end

local mt_conf = parse_kv_conf(game_dir .. "/minetest.conf")
local gm_conf = parse_kv_conf(game_dir .. "/game.conf")
assert(mt_conf["time_of_day"] == nil, "Invalid setting 'time_of_day' must not exist in minetest.conf")
assert(mt_conf["mg_name"] == "singlenode", "mg_name must be singlenode")
assert(mt_conf["enable_damage"] == "true", "enable_damage must be true")
assert(mt_conf["creative_mode"] == "false", "creative_mode must be false")
assert(mt_conf["enable_pvp"] == "false", "enable_pvp must be false for co-op play")
assert(mt_conf["time_speed"] == "0" and mt_conf["world_start_time"] == "1000",
    "world_start_time must be 1000 (nocturnal moon-high hour) with time_speed = 0")
assert(mt_conf["inventory_items_animations"] == "true", "inventory_items_animations must be true")
assert(mt_conf["connected_glass"] == "true", "connected_glass must be true for seamless flask_glass")
assert(mt_conf["enable_post_processing"] == "true" and mt_conf["enable_bloom"] == "true",
    "enable_post_processing and enable_bloom must be true")
assert(mt_conf["enable_minimap"] == "false", "enable_minimap must be false by default")
assert(mt_conf["tooltip_show_delay"] == "200", "tooltip_show_delay must be 200")
assert(mt_conf["show_wielded_item_y_offset"] == "108", "show_wielded_item_y_offset must be 108")
assert(mt_conf["dedicated_server_step"] == "0.05", "dedicated_server_step must be 0.05 (20 TPS)")
assert(mt_conf["liquid_update"] == "0.4", "liquid_update must be 0.4")
assert(mt_conf["anticheat_movement_tolerance"] == "2.0", "anticheat_movement_tolerance must be 2.0")
assert(mt_conf["x_player_api.enable_left_wield_first_person"] == "true",
    "x_player_api.enable_left_wield_first_person must be true")
assert(gm_conf["author"] == "SaKeL", "game.conf author must be SaKeL")
assert(gm_conf["disabled_settings"] and gm_conf["disabled_settings"]:find("!enable_damage", 1, true)
    and gm_conf["disabled_settings"]:find("creative_mode", 1, true),
    "game.conf disabled_settings must enforce !enable_damage and creative_mode")
print("[OK] minetest.conf & game.conf engine defaults (animations, glass, bloom, co-op PvP off & 20 TPS) verified")

-- 21. Top-Right Next Drop Plaque, Zero Chat Overlap, Right-Stack Hudbars Spacing & Pixel-Art HUD Suite

local expected_hud_pngs = {
    {"tc_hud_banner_wide.png", 640, 68},
    {"tc_hud_banner_wide_2l.png", 640, 50},
    {"tc_hud_banner_std.png", 544, 68},
    {"tc_hud_banner_std_2l.png", 544, 50},
    {"tc_hud_banner_compact.png", 384, 66},
    {"tc_hud_banner_compact_2l.png", 384, 48},
    {"tc_hud_drop_wide.png", 252, 80},
    {"tc_hud_drop_rim_wide.png", 252, 80},
    {"tc_hud_drop_std.png", 224, 78},
    {"tc_hud_drop_rim_std.png", 224, 78},
    {"tc_hud_drop_compact.png", 188, 72},
    {"tc_hud_drop_rim_compact.png", 188, 72},
    {"tc_hud_toast_std.png", 244, 56},
    {"tc_hud_toast_rim_std.png", 244, 56},
    {"tc_hud_toast_compact.png", 188, 52},
    {"tc_hud_toast_rim_compact.png", 188, 52},
    {"tc_hud_pill_l.png", 10, 30},
    {"tc_hud_pill_c.png", 1, 30},
    {"tc_hud_pill_r.png", 10, 30},
    {"tc_hud_pill_compact_l.png", 10, 26},
    {"tc_hud_pill_compact_c.png", 1, 26},
    {"tc_hud_pill_compact_r.png", 10, 26},
}
for i = 1, #expected_hud_pngs do
    local spec = expected_hud_pngs[i]
    local pw, ph = read_png_dims(tex_dir .. spec[1])
    assert(pw == spec[2] and ph == spec[3],
        string.format("HUD plaque %s expected %dx%d, got %dx%d", spec[1], spec[2], spec[3], pw, ph))
end

tc_core.start_level(2, false)
tc_core.apply_effect(p1, "aegis_ward", 12.0)
tc_core.apply_effect(p1, "chronos_surge", 12.0)
tc_core.apply_effect(p1, "harmonic_overdrive", 10.0)
tc_core.apply_effect(p1, "fertile_stride", 3.5)
tc_core.apply_effect(p1, "steam_updraft", 5.0)
tc_core.apply_effect(p1, "reconstitution", 6.0)
tc_core.push_hud_event_player(p1, {
    priority = 3,
    icon = "tc_aether_geode.png",
    title = "✦ Bonus Geode Incoming!",
    detail = "Crack for +4.5% Bloom & 3x3 Soil!",
    color = P.hud_aqua,
    accent_hex = P.aqua,
    ttl = 5.0,
})
tc_core.push_action_feedback(p1, {
    kind = "action",
    icon = "tc_tool_trowel.png",
    bloom = 3.5,
    label = "Acid + Chalk Enriched!",
    color = P.hud_emerald,
    ttl = 4.0,
})

local viewport_cases = {
    {label = "720x540 ultra-narrow", w = 720, h = 540, scale = 1.0, tier = "compact", drop_tex = "tc_hud_drop_compact.png"},
    {label = "800x600 compact", w = 800, h = 600, scale = 1.0, tier = "compact", drop_tex = "tc_hud_drop_compact.png"},
    {label = "1440x900 @ 1.75x HiDPI", w = 1440, h = 900, scale = 1.75, tier = "compact", drop_tex = "tc_hud_drop_compact.png"},
    {label = "1024x768 4:3", w = 1024, h = 768, scale = 1.0, tier = "compact", drop_tex = "tc_hud_drop_compact.png"},
    {label = "1280x720 standard", w = 1280, h = 720, scale = 1.0, tier = "standard", drop_tex = "tc_hud_drop_std.png"},
    {label = "1920x1080 wide", w = 1920, h = 1080, scale = 1.0, tier = "wide", drop_tex = "tc_hud_drop_wide.png"},
}

local all_hb_ids = {
    "bloom", "vitality", "temperature", "ph",
    "effect_1", "effect_2", "effect_3", "effect_4", "effect_5", "effect_6",
}

for v_i = 1, #viewport_cases do
    local vc = viewport_cases[v_i]
    mock_windows["SaKeL"] = {size = {x = vc.w, y = vc.h}, real_hud_scaling = vc.scale}
    local layout = tc_core.get_hud_layout("SaKeL")
    assert(layout.tier == vc.tier,
        string.format("%s expected tier %s, got %s", vc.label, vc.tier, tostring(layout.tier)))

    tc_core.update_player_hud(p1)
    tc_core.sync_player_drop_hud(p1)

    -- Verify horizontal clearance between Top-Middle Banner and Top-Right Next Drop Plaque
    local banner_right_x = (layout.lw * 0.5) + (layout.banner_w * 0.5)
    local drop_left_x = layout.lw + layout.drop_ox
    assert(drop_left_x - banner_right_x >= 10,
        string.format("%s horizontal overlap: banner_right=%.1f, drop_left=%.1f", vc.label, banner_right_x, drop_left_x))

    -- Verify Next Drop Plaque is anchored Top-Right with sculpted pixel-art texture
    local found_drop_plaque = false
    local found_banner_plaque = false
    local found_toast_plaque = false
    local found_pill_combine = false
    for _, h in pairs(p1._hud_elems) do
        if h and h.type ~= "waypoint" then
            local vis = true
            if (h.type == "image" or h.hud_elem_type == "image") and h.scale and (h.scale.x == 0 or h.scale.y == 0) then
                vis = false
            elseif (h.type == "text" or h.hud_elem_type == "text") and (not h.text or h.text == "") then
                vis = false
            elseif (h.type == "statbar" or h.hud_elem_type == "statbar") and (h.number or 0) <= 0 then
                vis = false
            end
            if vis and h.position and h.offset then
                local eff_x = (h.position.x * layout.lw + h.offset.x) / layout.lw
                local eff_y = (h.position.y * layout.lh + h.offset.y) / layout.lh
                -- Top-left builtin chat zone (x < 0.30, y < 0.35) must remain 100% free of visible HUD elements!
                assert(not (eff_x < 0.30 and eff_y < 0.35),
                    string.format("%s HUD element '%s' intrudes into top-left chat zone (eff_x=%.2f, eff_y=%.2f)",
                        vc.label, tostring(h.text), eff_x, eff_y))
            end
            if type(h.text) == "string" then
                if h.text == vc.drop_tex then
                    found_drop_plaque = true
                    assert(h.position.x == 1.0 and h.position.y == 0.0,
                        vc.label .. " Next Drop plaque must anchor to top-right {x=1, y=0}")
                elseif h.text:find("^tc_hud_banner_") then
                    found_banner_plaque = true
                elseif h.text:find("^tc_hud_toast_") then
                    found_toast_plaque = true
                    assert(h.position.x == 0.0 and h.position.y == 1.0,
                        vc.label .. " Event Toast plaque must anchor to bottom-left {x=0, y=1}")
                elseif h.text:find("^%[combine:") and h.text:find("tc_hud_pill_") then
                    found_pill_combine = true
                end
            end
        end
    end
    assert(found_drop_plaque, vc.label .. " missing top-right pixel-art drop plaque " .. vc.drop_tex)
    assert(found_banner_plaque, vc.label .. " missing top-middle pixel-art banner plaque")
    assert(found_toast_plaque, vc.label .. " missing bottom-left pixel-art toast plaque")
    assert(found_pill_combine, vc.label .. " missing 3-slice [combine pixel-art action pill")

    -- Verify vertical non-overlap between Top-Right Next Drop Plaque and all 10 stacked right-edge hudbars
    local drop_bottom_y = layout.drop_oy + layout.card_h
    local prev_bottom_y = drop_bottom_y
    for hb_i = 1, #all_hb_ids do
        local hids = hb.get_hudtable(all_hb_ids[hb_i]).hudids["SaKeL"]
        local bg_el = p1._hud_elems[hids.bg]
        assert(bg_el and bg_el.position.x == 1 and bg_el.position.y == 0,
            vc.label .. " hudbar " .. all_hb_ids[hb_i] .. " must anchor to top-right {x=1, y=0}")
        local bar_top_y = bg_el.offset.y
        local bar_bot_y = bar_top_y + 26
        if hb_i == 1 then
            assert(bar_top_y - drop_bottom_y >= 14,
                string.format("%s Bloom hudbar top (%d) too close to Next Drop bottom (%d)",
                    vc.label, bar_top_y, drop_bottom_y))
        else
            assert(bar_top_y - prev_bottom_y >= 4,
                string.format("%s hudbar %s overlaps previous bar (top=%d, prev_bot=%d)",
                    vc.label, all_hb_ids[hb_i], bar_top_y, prev_bottom_y))
        end
        assert(bar_bot_y <= layout.lh - 80,
            string.format("%s hudbar %s overflows bottom of screen (bot=%d, lh=%.1f)",
                vc.label, all_hb_ids[hb_i], bar_bot_y, layout.lh))
        prev_bottom_y = bar_bot_y
    end

    -- Verify steady-state update emits 0 redundant HUD change packets
    local pre_steady = p1._hud_changes
    tc_core.update_player_hud(p1)
    assert(p1._hud_changes == pre_steady,
        vc.label .. " unchanged update_player_hud must emit 0 HUD packets")
end

mock_windows["SaKeL"] = nil
tc_core.clear_player_hud_transients(p1)
tc_core.clear_player_effects(p1, true)
print("[OK] Top-Right Next Drop plaque, zero top-left chat overlap, right-stack hudbars spacing & 22 pixel-art HUD PNGs verified")

-- 22. Rechargeable Elemental Toolkit ([2] Bellows, [3] Flask, [4] Pestle), Cross-Hazard Siphoning & Zero-Deadlock Suite
local orig_chat_player = core.chat_send_player
local orig_chat_all = core.chat_send_all
local suite22_chat_calls = 0
core.chat_send_player = function(...)
    suite22_chat_calls = suite22_chat_calls + 1
    return orig_chat_player(...)
end
core.chat_send_all = function(...)
    suite22_chat_calls = suite22_chat_calls + 1
    return orig_chat_all(...)
end

-- (a) Verify 32x32 pixel-art PNG dimensions for depleted Bellows & Pestle textures
local bw_e, bh_e = read_png_dims(tex_dir .. "tc_tool_bellows_empty.png")
assert(bw_e == 32 and bh_e == 32, string.format("tc_tool_bellows_empty.png must be 32x32, got %dx%d", bw_e, bh_e))
local pw_e, ph_e = read_png_dims(tex_dir .. "tc_tool_pestle_empty.png")
assert(pw_e == 32 and ph_e == 32, string.format("tc_tool_pestle_empty.png must be 32x32, got %dx%d", pw_e, ph_e))

-- (b) Verify Bellows 4 -> 0 & Pestle 4 -> 0 wear bar progression + empty-variant swap
tc_core.start_level(1, false)
local bel = tc_tools.fill_bellows()
assert(bel:get_name() == "tc_tools:bellows" and tc_tools.get_bellows_charges(bel) == 4 and bel:get_wear() == 0,
    "Level 1 Bellows must start at 4/4 Puffs with 0 wear")
bel = tc_tools.consume_bellows_charge(bel)
assert(tc_tools.get_bellows_charges(bel) == 3 and bel:get_wear() > 0, "3/4 Bellows must show wear bar")
bel = tc_tools.consume_bellows_charge(tc_tools.consume_bellows_charge(bel))
assert(tc_tools.get_bellows_charges(bel) == 1, "Expected 1/4 Bellows")
bel = tc_tools.consume_bellows_charge(bel)
assert(bel:get_name() == "tc_tools:bellows_empty" and tc_tools.get_bellows_charges(bel) == 0,
    "0-charge Bellows must swap to tc_tools:bellows_empty")

local pst = tc_tools.fill_pestle()
assert(pst:get_name() == "tc_tools:chalk_pestle" and tc_tools.get_pestle_charges(pst) == 4 and pst:get_wear() == 0,
    "Level 1 Pestle must start at 4/4 Sweeps with 0 wear")
pst = tc_tools.consume_pestle_charge(pst)
assert(tc_tools.get_pestle_charges(pst) == 3 and pst:get_wear() > 0, "3/4 Pestle must show wear bar")
pst = tc_tools.consume_pestle_charge(tc_tools.consume_pestle_charge(tc_tools.consume_pestle_charge(pst)))
assert(pst:get_name() == "tc_tools:chalk_pestle_empty" and tc_tools.get_pestle_charges(pst) == 0,
    "0-charge Pestle must swap to tc_tools:chalk_pestle_empty")

-- (c) Whiff-Safe Consumption: clicking empty air or clean loam floor wastes 0 Puffs and 0 Sweeps
local bel_empty_def = registered_tools["tc_tools:bellows_empty"]
local pst_def = registered_tools["tc_tools:chalk_pestle"]
local pst_empty_def = registered_tools["tc_tools:chalk_pestle_empty"]

core.set_node({x = -2, y = 0, z = -2}, {name = "tc_elements:loam"})
core.set_node({x = -2, y = 1, z = -2}, {name = "air"})
local full_bel = tc_tools.fill_bellows()
full_bel = bellows_def.on_use(full_bel, p1, {type = "nothing"})
full_bel = bellows_def.on_use(full_bel, p1, {type = "node", under = {x = -2, y = 0, z = -2}, above = {x = -2, y = 1, z = -2}})
assert(tc_tools.get_bellows_charges(full_bel) == 4, "Whiffing Bellows on air or clean loam must spend 0 Puffs")

local full_pst = tc_tools.fill_pestle()
full_pst = pst_def.on_use(full_pst, p1, {type = "nothing"})
full_pst = pst_def.on_use(full_pst, p1, {type = "node", under = {x = -2, y = 0, z = -2}, above = {x = -2, y = 1, z = -2}})
assert(tc_tools.get_pestle_charges(full_pst) == 4, "Whiffing Pestle on air or clean loam must spend 0 Sweeps")

-- (d) Cross-Hazard Floor Fuel Siphoning (strictly when < max charges)
core.set_node({x = 2, y = 1, z = -2}, {name = "tc_elements:brimstone"})
full_bel = bellows_def.on_use(full_bel, p1, {type = "node", under = {x = 2, y = 1, z = -2}, above = {x = 2, y = 2, z = -2}})
assert(core.get_node({x = 2, y = 1, z = -2}).name == "tc_elements:brimstone",
    "Full Bellows [2] must NOT consume Brimstone when already at max Puffs")
assert(tc_tools.get_bellows_charges(full_bel) == 4, "Full Bellows clicking Brimstone must remain 4/4")

local low_bel = tc_tools.set_bellows_charges(ItemStack("tc_tools:bellows"), 2)
local pre_siphon_bloom = tc_core.state.bloom
low_bel = bellows_def.on_use(low_bel, p1, {type = "node", under = {x = 2, y = 1, z = -2}, above = {x = 2, y = 2, z = -2}})
assert(core.get_node({x = 2, y = 1, z = -2}).name == "air", "Low Bellows (2/4) must siphon and remove Brimstone")
assert(low_bel:get_name() == "tc_tools:bellows" and tc_tools.get_bellows_charges(low_bel) == 4 and low_bel:get_wear() == 0,
    "Siphoning Brimstone must refill Bellows to 4/4 with 0 wear")
assert(math.abs(tc_core.state.bloom - (pre_siphon_bloom + 1.2)) < 0.01,
    "Floor Brimstone siphon must grant +1.2% Bloom")

core.set_node({x = 2, y = 1, z = -2}, {name = "tc_elements:brimstone"})
local from_empty_bel = bel_empty_def.on_use(
    ItemStack("tc_tools:bellows_empty"), p1,
    {type = "node", under = {x = 2, y = 1, z = -2}, above = {x = 2, y = 2, z = -2}}
)
assert(from_empty_bel:get_name() == "tc_tools:bellows" and tc_tools.get_bellows_charges(from_empty_bel) == 4,
    "Depleted Bellows clicking Brimstone must refill to 4/4")

core.set_node({x = -2, y = 0, z = 2}, {name = "tc_elements:loam"})
core.set_node({x = -2, y = 1, z = 2}, {name = "tc_elements:alkaline_chalk"})
full_pst = pst_def.on_use(full_pst, p1, {type = "node", under = {x = -2, y = 1, z = 2}, above = {x = -2, y = 2, z = 2}})
assert(core.get_node({x = -2, y = 1, z = 2}).name == "tc_elements:alkaline_chalk",
    "Full Pestle [4] must NOT consume Alkaline Chalk when already at max Sweeps")

local from_empty_pst = pst_empty_def.on_use(
    ItemStack("tc_tools:chalk_pestle_empty"), p1,
    {type = "node", under = {x = -2, y = 1, z = 2}, above = {x = -2, y = 2, z = 2}}
)
assert(core.get_node({x = -2, y = 1, z = 2}).name == "air", "Depleted Pestle must grind and remove Alkaline Chalk")
assert(core.get_node({x = -2, y = 0, z = 2}).name == "tc_elements:fertile_loam",
    "Grinding Alkaline Chalk with Pestle must enrich underlying loam into fertile_loam")
assert(from_empty_pst:get_name() == "tc_tools:chalk_pestle" and tc_tools.get_pestle_charges(from_empty_pst) == 4,
    "Grinding Alkaline Chalk must refill Pestle to 4/4")

-- (e) Mid-Air Cross-Hazard Siphoning & Mid-Air Charge Consumption
local function make_falling_ent(iname, pos)
    local ent = setmetatable({
        item_name = iname,
        epoch = tc_core.state.epoch,
        age = 0,
        _removed = false,
    }, {__index = core.registered_entities["tc_elements:falling_reagent"]})
    ent.object = {
        get_pos = function() return pos end,
        get_rotation = function() return ent._rot or {x = 0, y = 0, z = 0} end,
        set_rotation = function(_, r, interpolate)
            ent._rot = table.copy(r or {x = 0, y = 0, z = 0})
            ent._last_interpolate = interpolate
        end,
        remove = function() ent._removed = true end,
    }
    return ent
end

p1:set_wielded_item(ItemStack("tc_tools:bellows_empty"))
local pre_mid_bloom = tc_core.state.bloom
local air_brim = make_falling_ent("tc_elements:brimstone", {x = 2, y = 4, z = 2})
air_brim:on_punch(p1)
assert(air_brim._removed == true, "Mid-air Brimstone siphon with depleted Bellows must catch the falling block")
assert(tc_tools.get_bellows_charges(p1:get_wielded_item()) == 4,
    "Mid-air Brimstone siphon must refill Bellows to 4/4")
assert(math.abs(tc_core.state.bloom - (pre_mid_bloom + 2.2)) < 0.01,
    "Mid-air Brimstone siphon must grant +2.2% Mid-Air Catch Bloom")

-- Full Bellows punching falling Brimstone must NOT catch it
local air_brim_full = make_falling_ent("tc_elements:brimstone", {x = 2, y = 4, z = 2})
air_brim_full:on_punch(p1)
assert(air_brim_full._removed == false, "Full Bellows must not catch falling Brimstone")

core.set_node({x = -3, y = 0, z = -2}, {name = "tc_elements:loam"})
p1:set_wielded_item(ItemStack("tc_tools:chalk_pestle_empty"))
local air_chalk = make_falling_ent("tc_elements:alkaline_chalk", {x = -3, y = 4, z = -2})
air_chalk:on_punch(p1)
assert(air_chalk._removed == true and tc_tools.get_pestle_charges(p1:get_wielded_item()) == 4,
    "Mid-air Chalk grind with depleted Pestle must catch block and refill Pestle to 4/4")
assert(core.get_node({x = -3, y = 0, z = -2}).name == "tc_elements:fertile_loam",
    "Mid-air Chalk grind must enrich floor tile below")

p1:set_wielded_item(tc_tools.fill_bellows())
local air_ice = make_falling_ent("tc_elements:cryo_ice", {x = 3, y = 4, z = 3})
air_ice:on_punch(p1)
assert(air_ice._removed == true and tc_tools.get_bellows_charges(p1:get_wielded_item()) == 3,
    "Mid-air Ice catch with Bellows must spend 1 Puff (4 -> 3)")

p1:set_wielded_item(tc_tools.fill_pestle())
local air_acid = make_falling_ent("tc_elements:acid_slime", {x = -3, y = 4, z = 3})
air_acid:on_punch(p1)
assert(air_acid._removed == true and tc_tools.get_pestle_charges(p1:get_wielded_item()) == 3,
    "Mid-air Acid catch with Pestle must spend 1 Sweep (4 -> 3)")

-- (f) Every-2-Levels Permanent Capacity Scaling & +2 Tool Blessings
local expected_caps = {
    {lvl = 1, b = 4, f = 3, p = 4},
    {lvl = 2, b = 4, f = 3, p = 4},
    {lvl = 3, b = 5, f = 4, p = 5},
    {lvl = 5, b = 6, f = 5, p = 6},
    {lvl = 7, b = 7, f = 6, p = 7},
    {lvl = 9, b = 7, f = 6, p = 7},
}
for c_i = 1, #expected_caps do
    local ec = expected_caps[c_i]
    tc_core.start_level(ec.lvl, false)
    assert(tc_tools.get_max_bellows_charges() == ec.b
        and tc_tools.get_max_flask_charges() == ec.f
        and tc_tools.get_max_pestle_charges() == ec.p,
        string.format("Level %d expected caps %d/%d/%d, got %d/%d/%d",
            ec.lvl, ec.b, ec.f, ec.p,
            tc_tools.get_max_bellows_charges(), tc_tools.get_max_flask_charges(), tc_tools.get_max_pestle_charges()))
end
tc_core.start_level(5, false)
tc_core.select_blessing("dragonlung_bellows", true)
assert(tc_tools.get_max_bellows_charges() == 8, "Level 5 + Dragonlung Bellows must grant 8 Puffs")
tc_core.select_blessing("deep_retort", true)
assert(tc_tools.get_max_flask_charges() == 7, "Level 5 + Deep Retort must grant 7 Splashes")
tc_core.select_blessing("starlight_mortar", true)
assert(tc_tools.get_max_pestle_charges() == 8, "Level 5 + Starlight Mortar must grant 8 Sweeps")
tc_core.select_blessing(nil, true)
assert(tc_tools.get_max_pestle_charges() == 6, "Expiring Starlight Mortar on Level 5 must clamp Pestle max back to 6")

-- (g) Zero-Deadlock Simulation (All 3 Tools at 0 Charges + 1.8s Emergency Prime Cooldown + Geode Full Refill)
tc_core.start_level(1, false)
local saved_us_step = mock_us_step
mock_us_step = 500000 -- 0.5s per get_us_time() call to test 1.8s emergency_prime cooldown

local zero_bel = ItemStack("tc_tools:bellows_empty")
local zero_flk = ItemStack("tc_tools:condenser_flask")
local zero_pst = ItemStack("tc_tools:chalk_pestle_empty")

-- Clicking directly on active hazards while at 0 charges must NOT prime or clear the hazard
core.set_node({x = 2, y = 1, z = 2}, {name = "tc_elements:cryo_ice"})
core.set_node({x = -2, y = 1, z = 2}, {name = "tc_elements:acid_slime"})
core.set_node({x = 2, y = 1, z = -2}, {name = "tc_elements:brimstone"})
zero_bel = bel_empty_def.on_use(zero_bel, p1, {type = "node", under = {x = 2, y = 1, z = 2}, above = {x = 2, y = 2, z = 2}})
assert(zero_bel:get_name() == "tc_tools:bellows_empty" and core.get_node({x = 2, y = 1, z = 2}).name == "tc_elements:cryo_ice",
    "Clicking Ice with 0-charge Bellows must not clear Ice or bypass air-prime")

-- 1st air-click primes Bellows to 1/4 (0 Bloom); immediate 0.5s follow-up air-click on empty Flask is gated by 1.8s cooldown!
local pre_prime_bloom = tc_core.state.bloom
zero_bel = bel_empty_def.on_use(zero_bel, p1, {type = "nothing"})
assert(zero_bel:get_name() == "tc_tools:bellows" and tc_tools.get_bellows_charges(zero_bel) == 1,
    "Air-click on 0-charge Bellows must prime +1 Puff")
assert(math.abs(tc_core.state.bloom - pre_prime_bloom) < 0.001, "Emergency +1 prime must grant 0 Bloom")

zero_flk = flask_empty_def.on_use(zero_flk, p1, {type = "nothing"})
assert(zero_flk:get_name() == "tc_tools:condenser_flask",
    "Emergency prime within 1.8s cooldown (0.5s elapsed) must be throttled")

mock_us_step = saved_us_step -- Restore 5.0s step so subsequent emergency primes proceed cleanly
zero_flk = flask_empty_def.on_use(zero_flk, p1, {type = "nothing"})
assert(zero_flk:get_name() == "tc_tools:condenser_flask_full" and tc_tools.get_flask_charges(zero_flk) == 1,
    "Air-click on 0-charge Flask after 1.8s must condense +1 Splash")
zero_pst = pst_empty_def.on_use(zero_pst, p1, {type = "node", under = {x = -2, y = 0, z = -2}, above = {x = -2, y = 1, z = -2}})
assert(zero_pst:get_name() == "tc_tools:chalk_pestle" and tc_tools.get_pestle_charges(zero_pst) == 1,
    "Safe loam click on 0-charge Pestle after 1.8s must scrape +1 Sweep")

-- Use the three +1 emergency charges to clear 100% of the pure Ice, pure Acid, and dry Brimstone hazards!
zero_bel = bellows_def.on_use(zero_bel, p1, {type = "node", under = {x = 2, y = 1, z = 2}, above = {x = 2, y = 2, z = 2}})
assert(core.get_node({x = 2, y = 1, z = 2}).name == "tc_elements:water_source" and zero_bel:get_name() == "tc_tools:bellows_empty",
    "Primed 1/4 Bellows must melt Ice into Water and return to bellows_empty")
zero_pst = pst_def.on_use(zero_pst, p1, {type = "node", under = {x = -2, y = 1, z = 2}, above = {x = -2, y = 2, z = 2}})
assert(core.get_node({x = -2, y = 1, z = 2}).name == "air" and zero_pst:get_name() == "tc_tools:chalk_pestle_empty",
    "Primed 1/4 Pestle must clear Acid Slime and return to chalk_pestle_empty")
zero_flk = flask_full_def.on_use(zero_flk, p1, {type = "node", under = {x = 2, y = 1, z = -2}, above = {x = 2, y = 2, z = -2}})
assert(core.get_node({x = 2, y = 1, z = -2}).name == "tc_elements:steam" and zero_flk:get_name() == "tc_tools:condenser_flask",
    "Primed 1/3 Flask must quench Brimstone into Steam and return to condenser_flask")

-- Verify Prismatic Geode resonance refills all depleted tools [2-4] simultaneously!
p1:get_inventory():set_list("main", {
    ItemStack("tc_tools:trowel"),
    ItemStack("tc_tools:bellows_empty"),
    ItemStack("tc_tools:condenser_flask"),
    ItemStack("tc_tools:chalk_pestle_empty"),
    ItemStack("tc_tools:guide_tome"),
})
core.set_node({x = 0, y = 1, z = 3}, {name = "tc_elements:aether_geode"})
tc_elements.resonate_geode_at({x = 0, y = 1, z = 3}, p1)
local post_geode_inv = p1:get_inventory():get_list("main")
assert(tc_tools.get_bellows_charges(post_geode_inv[2]) == 4
    and tc_tools.get_flask_charges(post_geode_inv[3]) == 3
    and tc_tools.get_pestle_charges(post_geode_inv[4]) == 4,
    "Cracking Prismatic Geode must refill all depleted tools [2-4] to maximum capacity!")

assert(suite22_chat_calls == 0,
    "Suite 22 tool actions, hints, siphons, primes & Geode cracks must emit 0 chat messages, got " .. tostring(suite22_chat_calls))
core.chat_send_player = orig_chat_player
core.chat_send_all = orig_chat_all
print("[OK] Rechargeable Toolkit ([2] Bellows, [3] Flask, [4] Pestle), Cross-Hazard Siphons & Zero-Deadlock Loop verified")

-- 23. Luanti 5.18 Capabilities, Strictness & Multi-Language Gettext Suite
;(function()
    -- (a) Verify new Luanti 5.18 PNG assets & exact dimensions
    local new_518_pngs = {
        {"tc_gui_slot_hover.png", 32, 32},
        {"tc_hud_tongs_slot.png", 64, 64},
        {"tc_astral_moon.png", 64, 64},
        {"tc_moon_tonemap.png", 512, 1},
    }
    for i = 1, #new_518_pngs do
        local spec = new_518_pngs[i]
        local w, h = read_png_dims(tex_dir .. spec[1])
        assert(w == spec[2] and h == spec[3],
            string.format("5.18 asset %s expected %dx%d, got %dx%d", spec[1], spec[2], spec[3], w, h))
    end

    -- (b) Strict Luanti 5.18 ItemStack itemstring parser hygiene
    assert(ItemStack(""):is_empty(), "Empty string ItemStack must be empty")
    assert(ItemStack("   "):is_empty(), "Whitespace-only itemstring must be rejected as empty in 5.18")
    assert(ItemStack("tc_tools:trowel badcount"):is_empty(), "Malformed count itemstring must be rejected in 5.18")
    assert(ItemStack("tc_tools:trowel 1 extra"):is_empty(), "Trailing token itemstring must be rejected in 5.18")
    assert(ItemStack("tc_tools:trowel"):get_name() == "tc_tools:trowel", "Valid itemstring must parse cleanly")

    -- (c) Verify Formspec v12, listimages[], colored vertlabel[], and editable=false copyable run receipt
    assert(tc_assets.FORMSPEC_VERSION == 12, "FORMSPEC_VERSION must be 12 for Luanti 5.18")
    local prepend = p1:get_formspec_prepend()
    assert(prepend:find("listimages[tc_gui_hb_bg.png;tc_gui_slot_hover.png]", 1, true) ~= nil,
        "Formspec prepend must configure Luanti 5.18 listimages[tc_gui_hb_bg.png;tc_gui_slot_hover.png]")

    local satchel_fs = tc_init.build_satchel_formspec(p1)
    assert(satchel_fs:find("^formspec_version%[12%]") ~= nil, "Satchel formspec must target formspec_version[12]")
    assert(satchel_fs:find(";tc_gui_hb_bg.png]", 1, true) == nil,
        "Satchel formspec must rely on native 5.18 listimages[] rather than manual image[] slot loops")
    assert(satchel_fs:find("style_type[vertlabel;textcolor=", 1, true) ~= nil
        and satchel_fs:find("vertlabel[", 1, true) ~= nil,
        "Satchel formspec must include colored 5.18 vertlabel[] book-spine title")

    shown_formspecs["tc_core:guide"] = nil
    tc_core.show_guide_dialog(p1, 1)
    local guide_fs = shown_formspecs["tc_core:guide"]
    assert(guide_fs:find("^formspec_version%[12%]") ~= nil
        and guide_fs:find("vertlabel[", 1, true) ~= nil,
        "Guidebook formspec must use formspec_version[12] and colored vertlabel[] spine ornament")

    tc_core.start_level(2, false)
    shown_formspecs["tc_core:leaderboard"] = nil
    tc_core.show_leaderboard_dialog(p1)
    assert(shown_formspecs["tc_core:leaderboard"]:find("style[fld_run_receipt;editable=false;", 1, true) ~= nil,
        "Leaderboard dialog must include Luanti 5.18 editable=false run summary field")

    tc_core.state.victory = true
    shown_formspecs["tc_core:victory"] = nil
    tc_core.show_victory_dialog(p1)
    assert(shown_formspecs["tc_core:victory"]:find("style[fld_run_receipt;editable=false;", 1, true) ~= nil,
        "Victory dialog must include Luanti 5.18 editable=false run summary field")

    tc_core.trigger_defeat("Too many uncleared hazards!", "overload")
    assert(shown_formspecs["tc_core:defeat"]:find("style[fld_run_receipt;editable=false;", 1, true) ~= nil,
        "Defeat dialog must include Luanti 5.18 editable=false run summary field")

    -- (d) Verify Moon tonemap, nocturnal skybox/stars/clouds visibility & 4-state sky/lighting presets
    local moon_cfg = p1:get_moon()
    assert(moon_cfg and moon_cfg.visible == true
        and moon_cfg.texture == "tc_astral_moon.png"
        and moon_cfg.tonemap == "tc_moon_tonemap.png"
        and math.abs(moon_cfg.scale - 2.6) < 0.01,
        "Player environment must configure Luanti 5.18 astral moon + moon_tonemap at scale 2.6")

    -- Verify stale persisted time_of_day (e.g. 18375 from old env_meta.txt) is overridden to nocturnal 01:00
    core.set_timeofday(18375 / 24000)
    tc_init.configure_environment(p1)
    local tod = core.get_timeofday()
    assert(math.abs(tod - (1000 / 24000)) < 0.0005,
        "configure_environment must lock world clock to 01:00 (1000/24000) so existing worlds show the moon")
    assert(math.abs((p1:get_day_night_ratio() or 0) - 0.68) < 0.01,
        "configure_environment must override day_night_ratio to 0.68 for readable moonlit chambers")

    -- Verify Luanti Sky::draw_moon & Sky::draw_stars math places moon > +45 deg above horizon & stars at 100% alpha
    local sky_cfg = p1:get_sky(true)
    assert(sky_cfg and sky_cfg.type == "regular"
        and sky_cfg.clouds == true
        and sky_cfg.auto_dim_skybox == false
        and math.abs(sky_cfg.body_orbit_tilt - 38.0) < 0.01
        and sky_cfg.fog and sky_cfg.fog.fog_distance == 120
        and sky_cfg.sky_color and sky_cfg.sky_color.fog_tint_type == "default",
        "Skybox must enable clouds, disable cave auto-dimming, set 38 deg orbit tilt, and configure fog")

    local wn = 0.415 / 2.0
    local wtod = (tod < 0.5) and (tod / wn * 0.25) or (1.0 - ((1.0 - tod) / wn * 0.25))
    local day_rad = math.rad(wtod * 360.0 - 90.0)
    local tilt_rad = math.rad(sky_cfg.body_orbit_tilt)
    -- After rotateXZBy(-90): (0,0,-1) -> (-1,0,0); rotateXYBy(day): (-cos, -sin, 0); rotateYZBy(tilt): y = -sin(day)*cos(tilt)
    local moon_y = -math.sin(day_rad) * math.cos(tilt_rad)
    local moon_elev_deg = math.deg(math.asin(moon_y))
    assert(moon_elev_deg > 45.0,
        string.format("Astral moon elevation must clear >45 deg above brass rim, got %.2f deg", moon_elev_deg))
    local star_alpha = math.min(1.0, math.max(0.0, (0.25 - math.abs(wtod)) * 20.0))
    assert(star_alpha >= 0.99, "Nocturnal clock must render starfield at 100% opacity")

    local star_cfg = p1:get_stars()
    assert(star_cfg and star_cfg.visible == true and star_cfg.count == 1600
        and star_cfg.day_opacity >= 0.30 and star_cfg.star_seed == 20260518,
        "Starfield must configure deterministic co-op star_seed and day_opacity fallback")

    local cloud_cfg = p1:get_clouds()
    assert(cloud_cfg and math.abs(cloud_cfg.density - 0.16) < 0.01
        and cloud_cfg.height == 68 and cloud_cfg.height < sky_cfg.fog.fog_distance,
        "Arcane mist clouds must sit below fog_distance so cloud_shader renders and fades them cleanly")

    tc_core.start_level(1, false)
    tc_core.clear_player_effects(p1, true)
    tc_core.sync_player_atmosphere(p1)
    local norm_light = p1:get_lighting()
    assert(norm_light and norm_light.static and norm_light.static.light_curve[16] == 255
        and math.abs(norm_light.static.ao_gamma - tc_assets.LIGHTING_PRESETS.normal.static.ao_gamma) < 0.01
        and p1:get_sky(true).fog.fog_color == tc_assets.SKY_PRESETS.normal.fog.fog_color,
        "Normal atmosphere must apply 16-entry static.light_curve, normal ao_gamma, and normal sky preset")
    local pre_idle_light = p1._light_calls
    local pre_idle_sky = p1._sky_calls
    tc_core.sync_player_atmosphere(p1)
    assert(p1._light_calls == pre_idle_light and p1._sky_calls == pre_idle_sky,
        "Unchanged atmosphere must emit 0 redundant set_lighting and set_sky packets")

    tc_core.state.stasis_timer = 10.0
    tc_core.sync_player_atmosphere(p1)
    assert(math.abs(p1:get_lighting().saturation - tc_assets.LIGHTING_PRESETS.stasis.saturation) < 0.01
        and math.abs(p1:get_lighting().static.ao_gamma - tc_assets.LIGHTING_PRESETS.stasis.static.ao_gamma) < 0.01
        and p1:get_sky(true).fog.fog_color == tc_assets.SKY_PRESETS.stasis.fog.fog_color,
        "Chronos Stasis must shift player sky & lighting to stasis preset")
    tc_core.state.stasis_timer = 0.0

    tc_core.apply_effect(p1, "harmonic_overdrive", 8.0)
    tc_core.sync_player_atmosphere(p1)
    assert(math.abs(p1:get_lighting().saturation - tc_assets.LIGHTING_PRESETS.overdrive.saturation) < 0.01
        and math.abs(p1:get_lighting().static.ao_gamma - tc_assets.LIGHTING_PRESETS.overdrive.static.ao_gamma) < 0.01
        and p1:get_sky(true).fog.fog_color == tc_assets.SKY_PRESETS.overdrive.fog.fog_color,
        "Harmonic Overdrive must shift player sky & lighting to overdrive preset")

    tc_core.state.overload_timer = 3
    tc_core.sync_player_atmosphere(p1)
    assert(math.abs(p1:get_lighting().saturation - tc_assets.LIGHTING_PRESETS.overload.saturation) < 0.01
        and math.abs(p1:get_lighting().static.ao_gamma - tc_assets.LIGHTING_PRESETS.overload.static.ao_gamma) < 0.01
        and p1:get_sky(true).fog.fog_color == tc_assets.SKY_PRESETS.overload.fog.fog_color,
        "Overload warning must preempt overdrive and shift sky & lighting to overload preset")
    tc_core.state.overload_timer = 0
    tc_core.clear_player_effects(p1, true)
    tc_core.sync_player_atmosphere(p1)

    -- (e) Verify Dynamic Option A inventory + text2 Trowel Tongs Cargo HUD across viewports & 0 idle packets
    local function find_cargo_hud(pl)
        for _, h in pairs(pl._hud_elems) do
            if h and h.type == "inventory" and h.text == "trowel_cargo" then
                return h
            end
        end
        return nil
    end

    tc_core.start_level(1, false)
    assert(p1:get_inventory():get_size("trowel_cargo") == 1, "trowel_cargo inventory list must have size 1")
    assert(find_cargo_hud(p1) == nil, "Option A cargo HUD must stay hidden when Trowel is empty")

    core.set_node({x = 2, y = 1, z = 2}, {name = "tc_elements:brimstone"})
    local tr_stack = ItemStack("tc_tools:trowel")
    tr_stack = registered_tools["tc_tools:trowel"].on_place(
        tr_stack, p1, {type = "node", under = {x = 2, y = 1, z = 2}, above = {x = 2, y = 2, z = 2}}
    )
    p1:get_inventory():set_stack("main", 1, tr_stack)
    assert(p1:get_inventory():get_stack("trowel_cargo", 1):get_name() == "tc_elements:brimstone",
        "Scooping Brimstone with Trowel must populate trowel_cargo[1]")
    local cargo_h = find_cargo_hud(p1)
    assert(cargo_h ~= nil and cargo_h.text2 == "tc_hud_tongs_slot.png" and cargo_h.number == 1,
        "Scooping reagent must dynamically mount Luanti 5.18 inventory HUD with text2 = tc_hud_tongs_slot.png")

    for v_i = 1, #viewport_cases do
        local vc = viewport_cases[v_i]
        mock_windows["SaKeL"] = {size = {x = vc.w, y = vc.h}, real_hud_scaling = vc.scale}
        local lay = tc_core.get_hud_layout("SaKeL")
        tc_core.update_player_hud(p1)
        local ch = find_cargo_hud(p1)
        assert(ch ~= nil, vc.label .. " must keep cargo HUD visible while Trowel holds Brimstone")
        local px_left = lay.lw * 0.5 + ch.offset.x
        assert(px_left >= 6 and (px_left + 60) <= (lay.lw * 0.5 - 240 + 4),
            string.format("%s cargo HUD x=%.1f must sit cleanly left of hotbar", vc.label, px_left))
        local steady_c = p1._hud_changes
        tc_core.update_player_hud(p1)
        assert(p1._hud_changes == steady_c, vc.label .. " steady cargo HUD must emit 0 redundant packets")
    end
    mock_windows["SaKeL"] = nil

    -- Direct combo onto Cryo Ice clears cargo and immediately removes the cargo HUD element
    core.set_node({x = -2, y = 1, z = 2}, {name = "tc_elements:cryo_ice"})
    tr_stack = registered_tools["tc_tools:trowel"].on_place(
        tr_stack, p1, {type = "node", under = {x = -2, y = 1, z = 2}, above = {x = -2, y = 2, z = 2}}
    )
    assert(p1:get_inventory():get_stack("trowel_cargo", 1):is_empty(),
        "Combining carried reagent must empty trowel_cargo[1]")
    assert(find_cargo_hud(p1) == nil,
        "Emptying Trowel cargo must immediately remove Option A cargo HUD element")

    -- (f) Verify ^[colorizehsl: landing reticles & ObjectRef:set_rotation(rot, false) instant crystal snap
    spawned_entities = {}
    core._particlespawners = {}
    tc_elements.spawn_falling_reagent({x = 2, y = 1, z = -2}, "tc_elements:aether_geode")
    local reticle_spawner = core._particlespawners[1]
    assert(reticle_spawner and type(reticle_spawner.texture) == "string"
        and reticle_spawner.texture:find("%^%[colorizehsl:", 1) ~= nil,
        "Landing telegraph reticle must use Luanti 5.18 ^[colorizehsl: modifier")
    local spawned_fall = spawned_entities[#spawned_entities]
    assert(spawned_fall and #spawned_fall._rot_calls >= 1
        and spawned_fall._rot_calls[1].interpolate == false,
        "Falling reagent on_activate must snap initial facet rotation via set_rotation(rot, false)")
    local rot_before_deflect = #spawned_fall._rot_calls
    p1:set_wielded_item(tc_tools.fill_bellows())
    spawned_fall:on_punch(p1)
    assert(#spawned_fall._rot_calls == rot_before_deflect + 1
        and spawned_fall._rot_calls[#spawned_fall._rot_calls].interpolate == false,
        "Non-matching tool punch on falling crystal must snap deflection via set_rotation(rot, false)")

    -- (g) Verify zero 'nil' substrings across all drop-card wave kinds (including Geode & Surge)
    local test_waves = {
        {kind = "normal", items = {"tc_elements:brimstone"}},
        {kind = "geode", items = {"tc_elements:aether_geode"}},
        {kind = "geode", items = {"tc_elements:cryo_ice", "tc_elements:aether_geode"}},
        {kind = "trial", items = {"tc_elements:acid_slime", "tc_elements:acid_slime"}},
        {kind = "surge", items = {"tc_elements:aether_geode", "tc_elements:brimstone", "tc_elements:cryo_ice"}},
    }
    for w_i = 1, #test_waves do
        tc_core.state.next_wave = test_waves[w_i]
        tc_core.sync_player_drop_hud(p1)
        for _, h in pairs(p1._hud_elems) do
            if h and h.type == "text" and type(h.text) == "string" then
                assert(not h.text:find("nil", 1, true),
                    "HUD text leaked literal 'nil' on wave #" .. w_i .. ": " .. h.text)
            end
        end
    end

    -- (h) Verify .pot + 9-language .po catalogs (including .en.po X-Source-Language: en) & live Spanish/Japanese HUD
    local all_tc_mods = {"tc_assets", "tc_init", "tc_elements", "tc_tools", "tc_world", "tc_core"}
    local all_langs = {"en", "es", "fr", "de", "pt_BR", "ru", "zh_CN", "ja", "sk"}
    for _, m in ipairs(all_tc_mods) do
        local pot_p = string.format("%s/mods/%s/locale/%s.pot", game_dir, m, m)
        assert(file_exists(pot_p), "Missing POT template: " .. pot_p)
        local en_po_p = string.format("%s/mods/%s/locale/%s.en.po", game_dir, m, m)
        local enf = io.open(en_po_p, "rb")
        assert(enf ~= nil, "Missing 5.18 server-side English catalog: " .. en_po_p)
        local en_raw = enf:read("*a")
        enf:close()
        assert(en_raw:find("X-Source-Language: en", 1, true) ~= nil,
            en_po_p .. " must declare Luanti 5.18 X-Source-Language: en header")
        for _, lg in ipairs(all_langs) do
            local cat = load_po_catalog(m, lg)
            assert(type(cat) == "table" and next(cat) ~= nil,
                string.format("Empty or missing %s.%s.po catalog", m, lg))
        end
    end

    mock_escape_translate_mode = true
    for _, test_lang in ipairs({"en", "es", "fr", "de", "pt_BR", "ru", "zh_CN", "ja", "sk"}) do
        mock_player_langs["SaKeL"] = test_lang
        tc_core.start_level(2, false)
        tc_core.push_hud_event_player(p1, {
            priority = 3,
            icon = "tc_aether_geode.png",
            title = tc_core.S("✦ Room #@1 Marked [@2]", 1, "SaKeL"),
            detail = tc_core.S("@1 · @2 Hazards", tc_core.S("WILTED · @1% Bloom", "42"), 2),
            ttl = 4.0,
        })
        tc_core.push_action_feedback(p1, {
            kind = "action",
            bloom = 2.5,
            label = tc_tools.S("Melted Ice → Water!"),
            ttl = 3.0,
        })
        tc_core.update_player_hud(p1)
        for _, h in pairs(p1._hud_elems) do
            if h and (h.type == "text" or h.type == "waypoint") then
                local txt = (h.type == "waypoint") and h.name or h.text
                if type(txt) == "string" and txt ~= "" then
                    assert(txt:find("\27", 1, true) == nil,
                        string.format("[%s] Raw \\27 escape leaked into HUD %s: %q", test_lang, h.type, txt))
                end
            end
        end
        local receipt = tc_core.build_run_receipt(p1)
        assert(receipt ~= "" and receipt:find("\27", 1, true) == nil,
            string.format("[%s] Copyable run receipt must contain zero \\27 escape bytes: %q", test_lang, receipt))
        if test_lang ~= "en" then
            local en_banner = core.get_translated_string("en", tc_core.S("THE GARDENER'S GUIDEBOOK"))
            local lg_banner = core.get_translated_string(test_lang, tc_core.S("THE GARDENER'S GUIDEBOOK"))
            assert(lg_banner ~= "" and lg_banner ~= en_banner,
                string.format("[%s] Expected localized Guidebook title distinct from English, got %q", test_lang, lg_banner))
        end
        shown_formspecs["tc_core:guide"] = nil
        tc_core.show_guide_dialog(p1, 2)
        assert_no_html_entities("tc_core:guide[" .. test_lang .. "]", shown_formspecs["tc_core:guide"])
    end
    mock_player_langs["SaKeL"] = nil
    mock_escape_translate_mode = false
    tc_core.reset_crucible()
end)()
print("[OK] Luanti 5.18 Capabilities (Formspec v12, listimages, editable=false, vertlabel, cargo HUD, static light_curve, moon_tonemap, colorizehsl, set_rotation & 9-language Gettext) verified")

-- 24. Global Zero-Chat-Spam & 1-for-1 Wave-Forecast Fidelity Audit
;(function()
    -- (a) Static scan: zero core.chat_send_player / core.chat_send_all calls across all tc_* mods
    local tc_mod_files = {
        "tc_assets/api.lua", "tc_assets/ui.lua", "tc_assets/init.lua",
        "tc_init/api.lua", "tc_init/item_entity.lua", "tc_init/init.lua",
        "tc_elements/api.lua", "tc_elements/entities.lua", "tc_elements/init.lua",
        "tc_tools/api.lua", "tc_tools/init.lua",
        "tc_world/api.lua", "tc_world/init.lua",
        "tc_core/api.lua", "tc_core/hud.lua", "tc_core/ui.lua", "tc_core/init.lua",
    }
    for i = 1, #tc_mod_files do
        local rel = tc_mod_files[i]
        local fp = io.open(game_dir .. "/mods/" .. rel, "rb")
        assert(fp ~= nil, "Expected mod source file: " .. rel)
        local src = fp:read("*a")
        fp:close()
        assert(src:find("chat_send_player", 1, true) == nil and src:find("chat_send_all", 1, true) == nil,
            "Forbidden chat_send_* call found in mods/" .. rel)
    end

    -- (b) Runtime hook across full end-to-end gameplay sequence
    local orig_send_player = core.chat_send_player
    local orig_send_all = core.chat_send_all
    local gameplay_chat_log = {}
    core.chat_send_player = function(name, msg)
        gameplay_chat_log[#gameplay_chat_log + 1] = "player(" .. tostring(name) .. "): " .. tostring(msg)
    end
    core.chat_send_all = function(msg)
        gameplay_chat_log[#gameplay_chat_log + 1] = "all: " .. tostring(msg)
    end

    local function step_sim_1s()
        for g_i = 1, #globalsteps do
            globalsteps[g_i](1.0)
        end
    end

    -- Player join onboarding (must push HUD welcome toast with 0 chat)
    local p_join = make_mock_player("CoopBuddy")
    table.insert(mock_players, p_join)
    for j_i = 1, #join_cbs do
        join_cbs[j_i](p_join)
    end
    for l_i = 1, #leave_cbs do
        leave_cbs[l_i](p_join)
    end
    table.remove(mock_players)

    -- Exact 1-for-1 Wave Forecast -> Physical Spawn Fidelity (Normal, Trial & Geode waves on Level 3)
    tc_core.start_level(3, false)
    local forecast_w1 = table.copy(tc_core.ensure_next_wave(1))
    assert(forecast_w1.wave_num == 1 and forecast_w1.kind == "normal", "Wave 1 on Level 3 must be normal")
    spawned_entities = {}
    tc_core.state.drop_timer = 1.0
    step_sim_1s()
    assert(#spawned_entities == #forecast_w1.items,
        string.format("Wave 1 spawned %d entities, expected %d", #spawned_entities, #forecast_w1.items))
    for d = 1, #forecast_w1.items do
        assert(spawned_entities[d].item_name == forecast_w1.items[d],
            string.format("Wave 1 drop #%d mismatch: spawned %s vs HUD forecast %s",
                d, tostring(spawned_entities[d].item_name), tostring(forecast_w1.items[d])))
    end
    assert(tc_core.state.active_drop ~= nil and tc_core.state.active_drop.kind == "normal",
        "Triggering Wave 1 must populate s.active_drop")
    assert(tc_core.state.next_wave and tc_core.state.next_wave.wave_num == 2,
        "Triggering Wave 1 must pre-roll Wave 2 into s.next_wave")

    -- Wave 2 -> Wave 3 (Trial wave on Level 3)
    tc_core.state.drop_timer = 1.0
    step_sim_1s()
    local forecast_trial = table.copy(tc_core.ensure_next_wave(1))
    assert(forecast_trial.wave_num == 3 and forecast_trial.kind == "trial",
        "Wave 3 on Level 3 must forecast a Trial wave")
    spawned_entities = {}
    tc_core.state.drop_timer = 1.0
    step_sim_1s()
    assert(#spawned_entities == #forecast_trial.items, "Trial wave entity count must match HUD forecast")
    for d = 1, #forecast_trial.items do
        assert(spawned_entities[d].item_name == forecast_trial.items[d],
            "Trial wave drop #" .. d .. " must match HUD forecast")
    end
    assert(tc_core.state.active_drop and tc_core.state.active_drop.kind == "trial",
        "Trial wave must set s.active_drop.kind == 'trial'")

    -- Wave 4 (Geode wave on Level 3)
    local forecast_geode = table.copy(tc_core.ensure_next_wave(1))
    assert(forecast_geode.wave_num == 4 and forecast_geode.kind == "geode",
        "Wave 4 on Level 3 must forecast a Bonus Geode wave")
    spawned_entities = {}
    tc_core.state.drop_timer = 1.0
    step_sim_1s()
    assert(spawned_entities[#spawned_entities].item_name == "tc_elements:aether_geode",
        "Geode wave final drop must spawn tc_elements:aether_geode")
    assert(tc_core.state.active_drop and tc_core.state.active_drop.kind == "geode",
        "Geode wave must set s.active_drop.kind == 'geode'")

    -- Direct reagent placement boundary hints & 22s unopened Geode shatter
    local brim_on_place = registered_nodes["tc_elements:brimstone"].on_place
    brim_on_place(
        ItemStack("tc_elements:brimstone"), p1,
        {type = "node", under = {x = 2, y = 4, z = 2}, above = {x = 2, y = 5, z = 2}}
    )
    brim_on_place(
        ItemStack("tc_elements:brimstone"), p1,
        {type = "node", under = {x = 0, y = 0, z = 0}, above = {x = 0, y = 1, z = 0}}
    )
    local shatter_pos = {x = 3, y = 1, z = -3}
    core.set_node(shatter_pos, {name = "tc_elements:aether_geode"})
    core.get_meta(shatter_pos):set_int("ttl", 1)
    registered_nodes["tc_elements:aether_geode"].on_timer(shatter_pos)
    assert(core.get_node(shatter_pos).name == "air", "22s Geode expiry must shatter the unopened Geode")

    -- Overload warning (1s) & Overload recovery on Level 1
    tc_core.start_level(1, false)
    local placed_haz = {}
    for hx = -4, 4, 2 do
        for hz = -4, 4, 2 do
            if not (math.abs(hx) <= 1 and math.abs(hz) <= 1) and #placed_haz < 12 then
                local hp_pos = {x = hx, y = 1, z = hz}
                core.set_node(hp_pos, {name = "tc_elements:alkaline_chalk"})
                placed_haz[#placed_haz + 1] = hp_pos
            end
        end
    end
    tc_core.state.drop_timer = 99.0
    step_sim_1s()
    assert(tc_core.state.overload_timer == 1, "12/11 floor hazards on Level 1 must start Overload timer")
    for r_i = 1, 4 do
        core.remove_node(placed_haz[r_i])
    end
    step_sim_1s()
    assert(tc_core.state.overload_timer == 0, "Clearing excess hazards must recover Overload timer to 0")

    -- Plant wilt, stage growth, 85% Final Bloom Surge & Level Complete + Blessing pick
    tc_core.start_level(3, false)
    tc_core.state.drop_timer = 99.0
    tc_core.state.temperature = 90.0
    core.set_node({x = 3, y = 1, z = 3}, {name = "tc_elements:brimstone"})
    core.set_node({x = -3, y = 1, z = 3}, {name = "tc_elements:brimstone"})
    tc_core.state.plants[1].vitality = 1.0
    step_sim_1s()
    assert(tc_core.state.plants[1].withered == true, "Sprout #1 must wilt under extreme heat at 1% HP")
    tc_core.revive_sprout_at(tc_core.state.plants[1].pos, p1, 80.0)
    core.remove_node({x = 3, y = 1, z = 3})
    core.remove_node({x = -3, y = 1, z = 3})
    tc_core.state.temperature = 50.0
    tc_core.state.ph = 50.0

    -- Stage growth (Stage 1 -> Stage 3) + 85% Final Bloom Surge
    for p_i = 1, #tc_core.state.plants do
        tc_core.state.plants[p_i].bloom = 86.0
    end
    tc_core.recalc_mean_bloom()
    step_sim_1s()
    assert(tc_core.state.climax_triggered == true and tc_core.state.active_drop
        and tc_core.state.active_drop.kind == "surge",
        "Reaching 85%+ Bloom on Level 3 must trigger Final Bloom Surge on Top-Right Drop HUD")

    -- 100% Bloom Level Complete + Next-Level Blessing selection
    for p_i = 1, #tc_core.state.plants do
        tc_core.state.plants[p_i].bloom = 100.0
        tc_core.state.plants[p_i].withered = false
    end
    tc_core.recalc_mean_bloom()
    step_sim_1s()
    assert(tc_core.state.victory == true, "100% Bloom across all plants must trigger Level Complete")
    for f_i = 1, #field_cbs do
        field_cbs[f_i](p1, "tc_core:victory", {btn_blessing_1 = "true"})
    end
    assert(tc_core.state.level == 4 and tc_core.state.running == true,
        "Picking Blessing #1 must advance cleanly to Level 4")

    -- Auto-Aegis Lifesaver, [Z] Chamber Ping & Garden Controls Pace/Reset UI buttons
    tc_core.clear_player_effects(p1, true)
    p1:set_hp(4)
    p1:get_inventory():add_item("main", "tc_tools:elixir_aegis")
    tc_core.damage_player(p1, 10, "brimstone")
    assert(p1:get_hp() == 20 and tc_core.has_effect(p1, "aegis_ward"),
        "Lethal hazard hit with Aegis Potion must trigger Auto-Aegis Lifesaver")

    tc_core.ping_chamber(p1)
    for f_i = 1, #field_cbs do
        field_cbs[f_i](p1, "tc_core:garden", {btn_diff_casual = "true"})
        field_cbs[f_i](p1, "tc_core:garden", {btn_diff_panic = "true"})
        field_cbs[f_i](p1, "tc_core:garden", {btn_diff_normal = "true"})
        field_cbs[f_i](p1, "tc_core:garden", {btn_reset = "true"})
    end

    core.chat_send_player = orig_send_player
    core.chat_send_all = orig_send_all
    assert(#gameplay_chat_log == 0,
        "Expected 0 gameplay chat messages across entire run, got " .. #gameplay_chat_log
        .. " (" .. tostring(gameplay_chat_log[1]) .. ")")
end)()
print("[OK] Global Zero-Chat-Spam Audit (0 chat messages across join, waves, trials, geodes, overload, wilt, surge, victory, Auto-Aegis & UI) verified")

-- Verify live engine tool on_use({type="object"}) mid-air interception, whiff-lockout immunity & landing-ring assist
;(function()
    tc_core.start_level(1, false)
    p1:set_pos({x = 0, y = 1.5, z = -1.5})
    p1._vel = {x = 0, y = 0, z = 0}

    local t_trowel = registered_tools["tc_tools:trowel"]
    local t_bel = registered_tools["tc_tools:bellows"]
    local t_bel_e = registered_tools["tc_tools:bellows_empty"]
    local t_flk = registered_tools["tc_tools:condenser_flask_full"]
    local t_flk_e = registered_tools["tc_tools:condenser_flask"]
    local t_pst = registered_tools["tc_tools:chalk_pestle"]
    local t_pst_e = registered_tools["tc_tools:chalk_pestle_empty"]

    assert(t_trowel.range == 6.0 and t_bel.range == 6.0 and t_flk.range == 6.0 and t_pst.range == 6.0,
        "Core garden tools [1-4] must have extended 6.0 reach for mid-air interception")

    local function spawn_fall_at(item_name, pos)
        spawned_entities = {}
        tc_elements.spawn_falling_reagent({x = pos.x, y = 1, z = pos.z}, item_name)
        local e = spawned_entities[#spawned_entities]
        e.object:set_pos(pos)
        return e
    end

    -- 1. Filled Water Flask [3] on_use catching Brimstone & Chalk via {type = "object"}
    core.set_node({x = 2, y = 0, z = 2}, {name = "tc_elements:loam"})
    core.set_node({x = 2, y = 1, z = 2}, {name = "air"})
    local flk_st = tc_tools.fill_flask()
    local b0 = tc_core.state.bloom
    local f_brim = spawn_fall_at("tc_elements:brimstone", {x = 2, y = 3.5, z = 2})
    flk_st = t_flk.on_use(flk_st, p1, {type = "object", ref = f_brim.object})
    assert(f_brim._removed == true, "Filled Flask [3] on_use must intercept falling Brimstone")
    assert(tc_tools.get_flask_charges(flk_st) == 2, "Mid-air Brimstone splash must spend 1 Splash (3 -> 2)")
    assert(core.get_node({x = 2, y = 1, z = 2}).name == "tc_elements:steam",
        "Mid-air Brimstone splash must spawn rising Steam on floor")
    assert(math.abs(tc_core.state.bloom - (b0 + 2.2)) < 0.01, "Mid-air Flask catch must grant +2.2% Bloom")

    core.set_node({x = -2, y = 0, z = 2}, {name = "tc_elements:loam"})
    core.set_node({x = -2, y = 1, z = 2}, {name = "air"})
    local f_chalk = spawn_fall_at("tc_elements:alkaline_chalk", {x = -2, y = 3.5, z = 2})
    flk_st = t_flk.on_use(flk_st, p1, {type = "object", ref = f_chalk.object})
    assert(f_chalk._removed == true and tc_tools.get_flask_charges(flk_st) == 1,
        "Filled Flask [3] on_use must intercept falling Chalk (2 -> 1)")
    assert(core.get_node({x = -2, y = 0, z = 2}).name == "tc_elements:fertile_loam",
        "Mid-air Chalk wash must enrich underlying soil")

    -- 2. Empty tools clicking non-siphonable falling blocks must NOT trigger emergency +1 air-prime
    local f_ice_guard = spawn_fall_at("tc_elements:cryo_ice", {x = 2, y = 3.5, z = -2})
    local guard_bel = t_bel_e.on_use(ItemStack("tc_tools:bellows_empty"), p1, {type = "object", ref = f_ice_guard.object})
    assert(guard_bel:get_name() == "tc_tools:bellows_empty" and not f_ice_guard._removed,
        "Clicking falling Ice with empty Bellows must show hint without emergency priming")

    local f_brim_guard = spawn_fall_at("tc_elements:brimstone", {x = 2, y = 3.5, z = -2})
    local guard_flk = t_flk_e.on_use(ItemStack("tc_tools:condenser_flask"), p1, {type = "object", ref = f_brim_guard.object})
    assert(guard_flk:get_name() == "tc_tools:condenser_flask" and not f_brim_guard._removed,
        "Clicking falling Brimstone with empty Flask must show hint without emergency priming")

    local f_acid_guard = spawn_fall_at("tc_elements:acid_slime", {x = -2, y = 3.5, z = -2})
    local guard_pst = t_pst_e.on_use(ItemStack("tc_tools:chalk_pestle_empty"), p1, {type = "object", ref = f_acid_guard.object})
    assert(guard_pst:get_name() == "tc_tools:chalk_pestle_empty" and not f_acid_guard._removed,
        "Clicking falling Acid with empty Pestle must show hint without emergency priming")

    -- 3. Empty Bellows & Pestle mid-air siphon/grind via on_use({type="object"})
    local refilled_bel = t_bel_e.on_use(ItemStack("tc_tools:bellows_empty"), p1, {type = "object", ref = f_brim_guard.object})
    assert(f_brim_guard._removed and tc_tools.get_bellows_charges(refilled_bel) == 4,
        "Empty Bellows on_use must siphon falling Brimstone to 4/4")

    local f_chalk_siphon = spawn_fall_at("tc_elements:alkaline_chalk", {x = -3, y = 3.5, z = -2})
    local refilled_pst = t_pst_e.on_use(ItemStack("tc_tools:chalk_pestle_empty"), p1, {type = "object", ref = f_chalk_siphon.object})
    assert(f_chalk_siphon._removed and tc_tools.get_pestle_charges(refilled_pst) == 4,
        "Empty Pestle on_use must grind falling Chalk to 4/4")

    -- 4. Whiff-then-immediate-catch (0.10s step) must NEVER lock out Bellows [2] or Pestle [4]
    local prev_step = mock_us_step
    mock_us_step = 100000 -- 0.10s per call (< 0.32s tool cooldown)
    refilled_bel = t_bel.on_use(refilled_bel, p1, {type = "nothing"})
    refilled_bel = t_bel.on_use(refilled_bel, p1, {type = "object", ref = f_ice_guard.object})
    assert(f_ice_guard._removed and tc_tools.get_bellows_charges(refilled_bel) == 3,
        "Whiffing air 0.10s before clicking falling Ice must NOT lock out Bellows [2] catch")

    refilled_pst = t_pst.on_use(refilled_pst, p1, {type = "nothing"})
    refilled_pst = t_pst.on_use(refilled_pst, p1, {type = "object", ref = f_acid_guard.object})
    assert(f_acid_guard._removed and tc_tools.get_pestle_charges(refilled_pst) == 3,
        "Whiffing air 0.10s before clicking falling Acid must NOT lock out Pestle [4] catch")
    mock_us_step = prev_step

    -- 5. Trowel [1] Right-Click on falling Prismatic Geode
    local f_geode = spawn_fall_at("tc_elements:aether_geode", {x = 0, y = 3.5, z = 2})
    local tr_st = ItemStack("tc_tools:trowel")
    t_trowel.on_place(tr_st, p1, {type = "object", ref = f_geode.object})
    assert(f_geode._removed, "Trowel [1] Right-Click must resonate falling Prismatic Geode mid-air")

    -- 6. Lag-tolerant Aim-Ray & Landing-Ring low-altitude catch assist
    core.set_node({x = 1, y = 0, z = 0}, {name = "tc_elements:loam"})
    core.set_node({x = 1, y = 1, z = 0}, {name = "air"})
    local f_low_brim = spawn_fall_at("tc_elements:brimstone", {x = 1, y = 3.2, z = 0})
    local assist_flk = tc_tools.fill_flask()
    assist_flk = t_flk.on_use(assist_flk, p1, {type = "node", under = {x = 1, y = 0, z = 0}, above = {x = 1, y = 1, z = 0}})
    assert(f_low_brim._removed and tc_tools.get_flask_charges(assist_flk) == 2,
        "Clicking glowing landing floor tile under low-altitude (y<=4.5) falling block must catch it")

    local f_ray_ice = spawn_fall_at("tc_elements:cryo_ice", {x = 0, y = 3.1, z = 1.5})
    local assist_bel = tc_tools.fill_bellows()
    assist_bel = t_bel.on_use(assist_bel, p1, {type = "nothing"})
    assert(f_ray_ice._removed and tc_tools.get_bellows_charges(assist_bel) == 3,
        "Clicking along look ray with interpolation offset must catch matching falling block")
end)()
print("[OK] Tool on_use mid-air entity interception, whiff-lockout immunity & aim-ray/landing-ring assist verified")

-- 26. Multiplayer Performance, Reconnect Anti-Refill, HUD Memory Cleanup & Safe Landing Audit
;(function()
    tc_core.reset_crucible()
    tc_core.start_level(2, false)
    tc_core.select_blessing("dragonlung_bellows", true)

    -- (a) Mid-run teammate join & same-run reconnect must NEVER refill depleted tools
    local p1_inv = p1:get_inventory()
    p1_inv:set_stack("main", 2, tc_tools.set_bellows_charges(ItemStack("tc_tools:bellows"), 1))
    assert(tc_tools.get_bellows_charges(p1_inv:get_stack("main", 2)) == 1, "Setup: P1 at 1/6 Bellows")

    local p_audit = make_mock_player("AuditPartner")
    table.insert(mock_players, p_audit)
    for _, fn in ipairs(join_cbs) do fn(p_audit) end

    assert(tc_tools.get_bellows_charges(p1_inv:get_stack("main", 2)) == 1,
        "Teammate joining mid-level must NOT refill P1's spent Bellows (1/6)")
    assert(tc_tools.get_bellows_charges(p_audit:get_inventory():get_stack("main", 2)) == 6,
        "Newly joined teammate must receive active blessing capacity (6/6)")

    -- Simulate P1 disconnecting and reconnecting on the same run_id
    for _, fn in ipairs(leave_cbs) do fn(p1) end
    for _, fn in ipairs(join_cbs) do fn(p1) end
    assert(tc_tools.get_bellows_charges(p1_inv:get_stack("main", 2)) == 1,
        "Same-run reconnect must NOT refill P1's spent Bellows (anti-reconnect-exploit)")

    -- (b) Zero HUD packet ping-pong when 2 players sustain different environmental effects in effect_1
    tc_core.clear_player_effects(p1, true)
    tc_core.clear_player_effects(p_audit, true)
    core.set_node({x = 0, y = 0, z = 2}, {name = "tc_elements:fertile_loam"})
    core.set_node({x = 11, y = 1, z = 2}, {name = "tc_elements:steam_cloud"})
    p1:set_pos({x = 0, y = 1.05, z = 2})
    p_audit:set_pos({x = 11, y = 1.5, z = 2})
    tc_core.step_player_effects(0.25)

    local p1_c0 = p1._hud_changes
    local p2_c0 = p_audit._hud_changes
    tc_core.step_player_effects(0.25)
    tc_core.step_player_effects(0.25)
    assert(p1._hud_changes == p1_c0 and p_audit._hud_changes == p2_c0,
        "2 players sustaining different effect_1 labels must emit 0 redundant hud_change packets")

    -- (c) Modern Luanti 5.18 HUD `type` field & `leaveplayer` state cleanup
    for _, h in pairs(p_audit._hud_elems) do
        assert(h.type ~= nil and h.hud_elem_type == nil,
            "All HUD definitions must use modern Luanti 5.18 `type` instead of deprecated `hud_elem_type`")
    end
    for _, fn in ipairs(leave_cbs) do fn(p_audit) end
    table.remove(mock_players)
    assert(hb.get_hudtable("effect_1").hudstate["AuditPartner"] == nil
        and hb.get_hudtable("effect_1").hudids["AuditPartner"] == nil,
        "hudbars must purge per-player hudstate and hudids on leaveplayer")

    -- (d) Safe chamber interior landing resolution (never outside glass walls or on archway pillars)
    for _, probe in ipairs({
        {x = 5, y = 1, z = 5},   -- Level 2 archway corner pillar
        {x = 0, y = 1, z = 0},   -- Chamber 1 center sprout
        {x = 25, y = 1, z = 25}, -- Far outside glass walls
    }) do
        local safe = tc_world.resolve_safe_floor_pos(probe, 2)
        assert(not tc_world.is_protected_pos(safe, 2),
            "resolve_safe_floor_pos must never return a protected tile")
        local in_c1 = (safe.x >= -4 and safe.x <= 4 and safe.z >= -4 and safe.z <= 4)
        local in_c2 = (safe.x >= 7 and safe.x <= 15 and safe.z >= -4 and safe.z <= 4)
        assert(in_c1 or in_c2,
            string.format("Landing pos (%d,%d,%d) escaped chamber glass walls!", safe.x, safe.y, safe.z))
    end

    -- (e) Stale-node guard on Trowel right-click
    core.set_node({x = -2, y = 1, z = -2}, {name = "air"})
    local tr_guard, handled = tc_tools.handle_trowel_on_reagent(
        ItemStack("tc_tools:trowel"), p1, {x = -2, y = 1, z = -2}, "tc_elements:brimstone"
    )
    assert(handled == false and tc_tools.get_trowel_cargo(tr_guard) == "",
        "handle_trowel_on_reagent must reject stale air positions without scooping phantom cargo")

    p1:set_pos({x = 0, y = 1.5, z = -2.8})
    tc_core.reset_crucible()
end)()
print("[OK] Multiplayer HUD packet deduplication, anti-refill join/reconnect, memory cleanup & safe landing verified")

for _, fn in ipairs(leave_cbs) do fn(p1) end
print("[OK] All Terrarium Crucible verification checks passed!")
