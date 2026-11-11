-- Headless runtime, gameplay mechanics, audio & WCAG AA verification harness for Terrarium Crucible
local script_src = debug.getinfo(1, "S").source:gsub("^@", "")
local script_dir = script_src:match("^(.*)[/\\][^/\\]+$") or "."
local game_dir = script_dir .. "/.."

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
local hpchange_cbs = {}
local field_cbs = {}
local spawned_entities = {}
local current_mod = ""
local mock_us_time = 10000000
local mock_us_step = 5000000

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
    local parsed_name, parsed_cnt = raw:match("^(%S+)%s+(%d+)$")
    local name = parsed_name or raw
    local cnt = parsed_cnt and tonumber(parsed_cnt) or ((name ~= "") and 1 or 0)
    local st = {
        _is_itemstack = true,
        name = name,
        count = cnt,
        wear = 0,
        _meta = {},
    }
    function st:get_name() return self.name end
    function st:get_count() return self.count end
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
    local inv_lists = {main = {}, craft = {}}
    local p = {
        _name = name,
        _hp = 20,
        _pos = {x = 0, y = 1.5, z = -2.8},
        _vel = {x = 0, y = 0, z = 0},
        _wield = ItemStack(""),
        _wield_idx = 1,
        _ctrl = {aux1 = false, up = false, zoom = false},
        _props = {eye_height = 1.47, visual_size = {x = 1, y = 1, z = 1}, collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}},
        _anim = {x = 0, y = 0},
        _physics_calls = 0,
        _fov = 0,
        _fov_is_mult = false,
        _fov_trans = 0,
        _fov_calls = 0,
        _fov_history = {},
        _light_calls = 0,
        _hud_elems = hud_elems,
    }
    function p:is_player() return true end
    function p:is_valid() return true end
    function p:get_player_name() return self._name end
    function p:get_hp() return self._hp end
    function p:set_hp(v) self._hp = v end
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
    function p:set_formspec_prepend(_) end
    function p:hud_set_hotbar_itemcount(_) end
    function p:hud_set_hotbar_image(_) end
    function p:hud_set_hotbar_selected_image(_) end
    function p:hud_set_flags(_) end
    function p:set_sky(_) end
    function p:set_sun(_) end
    function p:set_moon(_) end
    function p:set_stars(_) end
    function p:set_fov(fov, is_mult, trans)
        self._fov_calls = self._fov_calls + 1
        self._fov = fov or 0
        self._fov_is_mult = (is_mult == true)
        self._fov_trans = trans or 0
        table.insert(self._fov_history, {fov = self._fov, is_mult = self._fov_is_mult, trans = self._fov_trans})
    end
    function p:get_fov() return self._fov, self._fov_is_mult, self._fov_trans end
    function p:set_lighting(_) self._light_calls = self._light_calls + 1 end
    function p:set_physics_override(_) self._physics_calls = self._physics_calls + 1 end
    function p:hud_add(def)
        hud_elems[#hud_elems + 1] = table.copy(def)
        return #hud_elems
    end
    function p:hud_change(id, stat, val)
        if hud_elems[id] then hud_elems[id][stat] = val end
    end
    function p:hud_remove(id)
        hud_elems[id] = nil
    end
    function p:get_inventory()
        return {
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
            if key == "tc_drop_interval" then return "12.0" end
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
    get_translator = function(_)
        return function(str, ...)
            local args = {...}
            return (tostring(str or ""):gsub("@(%d+)", function(d)
                return tostring(args[tonumber(d)] or "")
            end))
        end
    end,
    get_player_information = function(_)
        return {protocol_version = 46, version_string = "5.18.0"}
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
    colorize = function(col, txt) return "\27(c@" .. col .. ")" .. txt .. "\27(c@#ffffff)" end,
    formspec_escape = function(s) return tostring(s or ""):gsub("%[", "\\["):gsub("%]", "\\]") end,
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
        }, {__index = def})
        ent.object = {
            get_pos = function() return ent._removed and nil or ent._pos end,
            set_pos = function(_, np) ent._pos = table.copy(np) end,
            get_velocity = function() return ent._vel end,
            set_velocity = function(_, v) ent._vel = table.copy(v) end,
            set_acceleration = function(_, a) ent._acc = table.copy(a) end,
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
        return 1
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
    register_on_mods_loaded = function() end,
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
    local m = {}
    function m:add_change(pl, _, _) pl:set_physics_override({}) end
    function m:del_change(pl, _) pl:set_physics_override({}) end
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

hb = {
    settings = {},
    registered_slots = {},
    players = {},
    register_hudbar = function() end,
    init_hudbar = function() end,
    change_hudbar = function() end,
    hide_hudbar = function() end,
}

-- Load real bundled x_player_api + all 6 custom tc_* mods in exact dependency order
local legacy_pa = io.open(game_dir .. "/mods/player_api/mod.conf", "rb")
assert(legacy_pa == nil, "Legacy mods/player_api directory must be removed!")
local load_order = {"x_player_api", "tc_assets", "tc_init", "tc_elements", "tc_tools", "tc_world", "tc_core"}
for _, m in ipairs(load_order) do
    current_mod = m
    dofile(game_dir .. "/mods/" .. m .. "/init.lua")
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

-- 4. Test 3-Charge Condenser Flask & Deep Retort 5-Charge Boon
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
tc_core.grant_boon("deep_retort")
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

-- 8. Test Victory Guild Boon Picker -> Level 2 Expansion, Cheer Emote, Turbulence, Micro-Climate (>=2) & 3D Waypoints
tc_core.state.bloom = 100.0
for _, fn in ipairs(globalsteps) do fn(1.0) end
assert(tc_core.state.victory, "100% Bloom must trigger Victory")
assert(shown_formspecs["tc_core:victory"]:find("btn_boon_1"), "Victory dialog must render 3 Guild Boon cards")
local win_pstate = x_player_api.controls.player_states["SaKeL"]
assert(win_pstate and win_pstate.active_emote == "cheer", "Level Complete Victory must play 'cheer' emote!")

for _, fn in ipairs(field_cbs) do
    fn(p1, "tc_core:victory", {btn_boon_1 = "Attune"})
end
assert(tc_core.state.level == 2 and #tc_core.state.plants == 2, "Clicking Guild Boon card must expand to Level 2")
assert(win_pstate.active_emote == "cheer", "Selecting a Guild Boon must celebrate with 'cheer' emote!")

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
print("[OK] Guild Boon Picker, Cheer/Point Emotes, Elemental Turbulence, Micro-Climate (>=2) & 3D Waypoints verified")

-- 9. Test Hermetic Boots 50% damage reduction + Auto-Aegis Lifesaver
tc_core.grant_boon("hermetic_boots")
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
assert(x_player_api.is_consumable("tc_tools:elixir_quicksilver"), "Quicksilver Elixir must be registered consumable")
assert(x_player_api.is_consumable("tc_tools:elixir_aegis"), "Aegis Ward must be registered consumable")
local qs_cdef = x_player_api.get_consumable_definition("tc_tools:elixir_quicksilver")
assert(qs_cdef.particle_type == "liquid_drops", "Elixir must emit liquid_drops particles")
local qs_stack = ItemStack("tc_tools:elixir_quicksilver")
registered_craftitems["tc_tools:elixir_quicksilver"].on_use(qs_stack, p1)
assert(win_pstate.eat_action == "eat" and win_pstate.eat_item_name == "tc_tools:elixir_quicksilver",
    "Drinking Quicksilver Elixir must trigger x_player_api eating/drinking animation!")

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

-- 12. Regression Suite: Level 1 Altar UI (0 Boons), Trowel Altar Right-Click, Cargo Reset, Water Quench & Paused Guards
shown_formspecs["tc_core:altar"] = nil
tc_core.show_altar_dialog(p1)
assert(shown_formspecs["tc_core:altar"] and shown_formspecs["tc_core:altar"]:find("None yet"),
    "Level 1 Altar dialog with 0 Boons must render cleanly without nil palette error")

-- Right-click Altar while holding Trowel (running = true & running = false)
shown_formspecs["tc_core:altar"] = nil
local altar_pos = {x = 0, y = 1, z = -3}
core.set_node(altar_pos, {name = "tc_elements:altar_stone"})
local tr_item = ItemStack("tc_tools:trowel")
trowel_def.on_place(tr_item, p1, {type = "node", under = altar_pos, above = {x = 0, y = 2, z = -3}})
assert(shown_formspecs["tc_core:altar"] ~= nil, "Right-clicking Altar with Trowel must open Crucible Control Altar")

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

-- Paused game (Inspect Arena): Elixirs must NOT be consumed, while Altar right-click with Trowel still works
tc_core.state.running = false
shown_formspecs["tc_core:altar"] = nil
core.set_node(altar_pos, {name = "tc_elements:altar_stone"})
trowel_def.on_place(tr_item, p1, {type = "node", under = altar_pos, above = {x = 0, y = 2, z = -3}})
assert(shown_formspecs["tc_core:altar"] ~= nil, "Right-clicking Altar with Trowel while paused must still open Altar")
local paused_qs = ItemStack("tc_tools:elixir_quicksilver 2")
paused_qs = registered_craftitems["tc_tools:elixir_quicksilver"].on_use(paused_qs, p1)
assert(paused_qs:get_count() == 2, "Elixirs must not be wasted while crucible is paused")

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
p_stale._fov = 1.12
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

-- Post-warmup (>= 2.5s) priority ladder (1.05 < 1.08 < 1.12) with smooth 0.20s transitions
mock_us_time = mock_us_time + 3000000 -- +3.0s (>= 2.5s warmup & >= 60ms coalesce)
tc_core.apply_effect(p_stale, "fertile_stride", 4.0)
local fs_ev = p_stale._fov_history[#p_stale._fov_history]
assert(math.abs(fs_ev.fov - 1.08) < 0.001 and fs_ev.is_mult and math.abs(fs_ev.trans - 0.20) < 0.001,
    "Post-warmup Fertile Stride must smoothly transition to 1.08x over 0.20s")

mock_us_time = mock_us_time + 250000
tc_core.apply_effect(p_stale, "quicksilver", 6.0)
local qs_ev = p_stale._fov_history[#p_stale._fov_history]
assert(math.abs(qs_ev.fov - 1.12) < 0.001 and qs_ev.is_mult and math.abs(qs_ev.trans - 0.20) < 0.001,
    "Quicksilver must override 1.08x to 1.12x smoothly over 0.20s")

mock_us_time = mock_us_time + 250000
tc_core.remove_effect(p_stale, "quicksilver")
assert(math.abs(p_stale:get_fov() - 1.08) < 0.001, "Expiring Quicksilver while Fertile Stride active must step to 1.08x")

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
print("[OK] Regression suite (Altar 0-boon UI, Trowel delegation, cargo reset, Water quench & FOV lifecycle) verified")

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

-- Step 26 seconds of pure Harmony without drops -> fastest plant reaches Stage 2 (>=25%) before slowest plant!
for step_n = 1, 26 do
    tc_core.state.drop_timer = 99.0
    for _, fn in ipairs(globalsteps) do fn(1.0) end
    if step_n == 26 then
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
assert(slow_gain > (0.85 * t_min) + 0.35, "Local chamber fertile_loam must accelerate that chamber's plant growth")

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

for _, fn in ipairs(leave_cbs) do fn(p1) end
print("[OK] All Terrarium Crucible verification checks passed!")
