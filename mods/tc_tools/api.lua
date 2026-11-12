---@class TcToolsAPI
---@field S fun(str: string, ...: any): string Mod translator function
---@field check_cooldown fun(player: ObjectRef, key: string, cooldown_sec: number): boolean
---@field send_hint fun(player: ObjectRef, key: string, message: string, icon?: string)
---@field get_level_charge_bonus fun(): integer
---@field get_max_bellows_charges fun(): integer
---@field get_bellows_charges fun(itemstack: ItemStack): integer
---@field set_bellows_charges fun(itemstack: ItemStack, charges: integer): ItemStack
---@field fill_bellows fun(): ItemStack
---@field consume_bellows_charge fun(itemstack: ItemStack): ItemStack
---@field get_max_flask_charges fun(): integer
---@field get_flask_charges fun(itemstack: ItemStack): integer
---@field set_flask_charges fun(itemstack: ItemStack, charges: integer): ItemStack
---@field fill_flask fun(): ItemStack
---@field consume_flask_charge fun(itemstack: ItemStack): ItemStack
---@field get_max_pestle_charges fun(): integer
---@field get_pestle_charges fun(itemstack: ItemStack): integer
---@field set_pestle_charges fun(itemstack: ItemStack, charges: integer): ItemStack
---@field fill_pestle fun(): ItemStack
---@field consume_pestle_charge fun(itemstack: ItemStack): ItemStack
---@field refill_player_tools fun(player: ObjectRef)
---@field try_emergency_prime fun(player: ObjectRef, kind: string, itemstack: ItemStack): ItemStack, boolean
---@field get_trowel_cargo fun(itemstack: ItemStack): string
---@field set_trowel_cargo fun(itemstack: ItemStack, reagent_name?: string): ItemStack
---@field sync_player_trowel_cargo_inv fun(player: ObjectRef, cargo_name?: string)
---@field handle_trowel_on_reagent fun(st: ItemStack, u: ObjectRef, pos: table, nm: string): ItemStack, boolean
---@field clear_player_trowels fun(player: ObjectRef)
---@field count_carried_hazards fun(): integer, string|nil
---@field spawn_bellows_particles fun(pos: table, dir: table)
---@field spawn_pestle_particles fun(center: table, radius: number)
---@field spawn_elixir_particles fun(pos: table, texture: string)
---@field spawn_water_splash_particles fun(pos: table, with_steam?: boolean)
tc_tools = {
    S = core.get_translator("tc_tools"),
}

local S = tc_tools.S
local P = tc_assets.PALETTE

-- Per-player microsecond timestamps: player_cooldowns[player_name][key] = last_us
local player_cooldowns = {}

local HINT_ICON_BY_KEY = {
    empty_bellows = "tc_tool_bellows_empty.png",
    bellows_full = "tc_tool_bellows.png",
    bellows_whiff = "tc_tool_bellows.png",
    bellows_brim = "tc_tool_bellows.png",
    ["midair_tc_elements:cryo_ice"] = "tc_tool_bellows.png",
    empty_flask = "tc_tool_flask_empty.png",
    flask_targets = "tc_tool_flask_water.png",
    sprout_full = "tc_tool_flask_water.png",
    ["midair_tc_elements:brimstone"] = "tc_tool_flask_water.png",
    ["midair_tc_elements:alkaline_chalk"] = "tc_tool_flask_water.png",
    empty_pestle = "tc_tool_pestle_empty.png",
    pestle_full = "tc_tool_pestle.png",
    pestle_whiff = "tc_tool_pestle.png",
    pestle_chalk = "tc_tool_pestle.png",
    ["midair_tc_elements:acid_slime"] = "tc_tool_pestle.png",
    trowel_empty = "tc_tool_trowel.png",
    trowel_prot = "tc_tool_trowel.png",
    trowel_floor = "tc_tool_trowel.png",
    trowel_busy = "tc_tool_trowel.png",
    midair_geode = "tc_tool_trowel.png",
    falling_bonk = "tc_heart.png",
}

core.register_on_leaveplayer(function(player)
    player_cooldowns[player:get_player_name()] = nil
end)

---Checks and updates a per-player cooldown timer to prevent multiplayer click-spam lag.
---@param player ObjectRef
---@param key string Action identifier
---@param cooldown_sec number Minimum interval in seconds
---@return boolean ready True if the action may proceed
function tc_tools.check_cooldown(player, key, cooldown_sec)
    if not player or not player:is_player() then
        return false
    end
    local name = player:get_player_name()
    local now_us = core.get_us_time()
    local pmap = player_cooldowns[name]
    if not pmap then
        pmap = {}
        player_cooldowns[name] = pmap
    end
    local prev_us = pmap[key] or 0
    if (now_us - prev_us) < (cooldown_sec * 1000000) then
        return false
    end
    pmap[key] = now_us
    return true
end

---Sends a throttled contextual tip to the bottom-center HUD pill without polluting chat.
---@param player ObjectRef
---@param key string Hint throttle key
---@param message string Guidance text
---@param icon? string Optional 32x32 icon texture override
function tc_tools.send_hint(player, key, message, icon)
    if tc_tools.check_cooldown(player, "hint_" .. key, 2.2) then
        tc_core.push_action_feedback(player, {
            kind = "hint",
            icon = icon or HINT_ICON_BY_KEY[key] or "tc_tool_guide.png",
            text = message,
            color = P.hud_aqua,
            accent_hex = P.aqua,
            ttl = 2.8,
        })
    end
end

---Returns the permanent every-2-levels tool capacity bonus (+0 on L1-2, +1 on L3-4, +2 on L5-6, +3 on L7+).
---@return integer
function tc_tools.get_level_charge_bonus()
    local lvl = math.max(1, tc_core.state.level or 1)
    return math.min(3, math.floor((lvl - 1) / 2))
end

local function read_tool_charges(itemstack, full_name, max_c)
    if itemstack:get_name() ~= full_name then
        return 0
    end
    local stored = itemstack:get_meta():get_int("charges")
    if stored <= 0 then
        return max_c
    end
    return math.min(max_c, stored)
end

local function write_tool_charges(itemstack, charges, full_name, empty_name, max_c, label_fn)
    if charges <= 0 then
        return ItemStack(empty_name)
    end
    local clamped = math.min(max_c, math.floor(charges))
    if itemstack:get_name() ~= full_name then
        itemstack = ItemStack(full_name)
    end
    local wear = 0
    if clamped < max_c then
        wear = math.floor(65535 * (max_c - clamped) / max_c)
    end
    itemstack:set_wear(wear)
    local meta = itemstack:get_meta()
    meta:set_int("charges", clamped)
    meta:set_string("short_description", label_fn(clamped, max_c))
    return itemstack
end

local TOOL_SPECS = {
    bellows = {
        base = 4,
        blessing = "dragonlung_bellows",
        full_name = "tc_tools:bellows",
        empty_name = "tc_tools:bellows_empty",
        label_fn = function(c, m) return S("Thermal Bellows [2] — @1/@2 Puffs", c, m) end,
        prime_anim = "attack_thrust",
        prime_sound = "tc_bellows",
        prime_gain = 0.42,
        prime_icon = "tc_tool_bellows.png",
        prime_color = P.hud_amber,
        prime_accent = P.amber,
        prime_text_fn = function() return S("Hand-Pumped +1 Puff — Brimstone fills all!") end,
    },
    flask = {
        base = 3,
        blessing = "deep_retort",
        full_name = "tc_tools:condenser_flask_full",
        empty_name = "tc_tools:condenser_flask",
        label_fn = function(c, m) return S("Water Flask [3] — @1/@2 Splashes", c, m) end,
        prime_anim = "attack_slash",
        prime_sound = "tc_glass",
        prime_gain = 0.45,
        prime_icon = "tc_tool_flask_water.png",
        prime_color = P.hud_aqua,
        prime_accent = P.aqua,
        prime_text_fn = function() return S("Condensed +1 Splash — Water fills all!") end,
    },
    pestle = {
        base = 4,
        blessing = "starlight_mortar",
        full_name = "tc_tools:chalk_pestle",
        empty_name = "tc_tools:chalk_pestle_empty",
        label_fn = function(c, m) return S("Limestone Pestle [4] — @1/@2 Sweeps", c, m) end,
        prime_anim = "attack_slash",
        prime_sound = "tc_pestle",
        prime_gain = 0.45,
        prime_icon = "tc_tool_pestle.png",
        prime_color = P.hud_emerald,
        prime_accent = P.emerald,
        prime_text_fn = function() return S("Scraped +1 Sweep — Chalk fills all!") end,
    },
}

local function max_charges_for(spec)
    return spec.base + tc_tools.get_level_charge_bonus() + (tc_core.has_blessing(spec.blessing) and 2 or 0)
end

local function get_charges_for(spec, itemstack)
    return read_tool_charges(itemstack, spec.full_name, max_charges_for(spec))
end

local function set_charges_for(spec, itemstack, charges)
    return write_tool_charges(itemstack, charges, spec.full_name, spec.empty_name, max_charges_for(spec), spec.label_fn)
end

local function fill_tool_for(spec)
    return set_charges_for(spec, ItemStack(spec.full_name), max_charges_for(spec))
end

local function consume_charge_for(spec, itemstack)
    return set_charges_for(spec, itemstack, get_charges_for(spec, itemstack) - 1)
end

---Returns the current maximum Puffs per Thermal Bellows fill (4 base + level bonus + 2 with Dragonlung Bellows).
---@return integer
function tc_tools.get_max_bellows_charges()
    return max_charges_for(TOOL_SPECS.bellows)
end

---Reads remaining Puffs from a Thermal Bellows ItemStack.
---@param itemstack ItemStack
---@return integer
function tc_tools.get_bellows_charges(itemstack)
    return get_charges_for(TOOL_SPECS.bellows, itemstack)
end

---Updates a Thermal Bellows' charges, native Luanti wear bar, and wielded short_description.
---@param itemstack ItemStack
---@param charges integer
---@return ItemStack
function tc_tools.set_bellows_charges(itemstack, charges)
    return set_charges_for(TOOL_SPECS.bellows, itemstack, charges)
end

---Creates a freshly filled Thermal Bellows at maximum capacity.
---@return ItemStack
function tc_tools.fill_bellows()
    return fill_tool_for(TOOL_SPECS.bellows)
end

---Consumes 1 Puff from a Thermal Bellows, swapping to `tc_tools:bellows_empty` at 0 charges.
---@param itemstack ItemStack
---@return ItemStack
function tc_tools.consume_bellows_charge(itemstack)
    return consume_charge_for(TOOL_SPECS.bellows, itemstack)
end

---Returns the current maximum Aqueous Charges per Condenser Flask fill (3 base + level bonus + 2 with Deep Retort).
---@return integer
function tc_tools.get_max_flask_charges()
    return max_charges_for(TOOL_SPECS.flask)
end

---Reads remaining Aqueous Charges from a Charged Condenser Flask ItemStack.
---@param itemstack ItemStack
---@return integer
function tc_tools.get_flask_charges(itemstack)
    return get_charges_for(TOOL_SPECS.flask, itemstack)
end

---Updates a Charged Condenser Flask's charges, native Luanti tool wear bar, and wielded short_description.
---@param itemstack ItemStack
---@param charges integer
---@return ItemStack
function tc_tools.set_flask_charges(itemstack, charges)
    return set_charges_for(TOOL_SPECS.flask, itemstack, charges)
end

---Creates a freshly filled Charged Condenser Flask at maximum capacity.
---@return ItemStack
function tc_tools.fill_flask()
    return fill_tool_for(TOOL_SPECS.flask)
end

---Consumes 1 charge from a Charged Condenser Flask, reverting to empty at 0 charges.
---@param itemstack ItemStack
---@return ItemStack
function tc_tools.consume_flask_charge(itemstack)
    return consume_charge_for(TOOL_SPECS.flask, itemstack)
end

---Returns the current maximum Sweeps per Limestone Pestle fill (4 base + level bonus + 2 with Starlight Mortar).
---@return integer
function tc_tools.get_max_pestle_charges()
    return max_charges_for(TOOL_SPECS.pestle)
end

---Reads remaining Sweeps from a Limestone Pestle ItemStack.
---@param itemstack ItemStack
---@return integer
function tc_tools.get_pestle_charges(itemstack)
    return get_charges_for(TOOL_SPECS.pestle, itemstack)
end

---Updates a Limestone Pestle's charges, native Luanti wear bar, and wielded short_description.
---@param itemstack ItemStack
---@param charges integer
---@return ItemStack
function tc_tools.set_pestle_charges(itemstack, charges)
    return set_charges_for(TOOL_SPECS.pestle, itemstack, charges)
end

---Creates a freshly coated Limestone Pestle at maximum capacity.
---@return ItemStack
function tc_tools.fill_pestle()
    return fill_tool_for(TOOL_SPECS.pestle)
end

---Consumes 1 Sweep from a Limestone Pestle, swapping to `tc_tools:chalk_pestle_empty` at 0 charges.
---@param itemstack ItemStack
---@return ItemStack
function tc_tools.consume_pestle_charge(itemstack)
    return consume_charge_for(TOOL_SPECS.pestle, itemstack)
end

---Refills Bellows [2], Water Flask [3], and Limestone Pestle [4] to current maximum capacity in a player's inventory.
---@param player ObjectRef
function tc_tools.refill_player_tools(player)
    if not player or not player:is_player() then
        return
    end
    local inv = player:get_inventory()
    local list = inv:get_list("main")
    if not list then
        return
    end
    local changed = false
    for i = 1, #list do
        local sname = list[i]:get_name()
        for _, spec in pairs(TOOL_SPECS) do
            if sname == spec.full_name or sname == spec.empty_name then
                list[i] = fill_tool_for(spec)
                changed = true
                break
            end
        end
    end
    if changed then
        inv:set_list("main", list)
        x_player_api.update_wield_item(player, true)
    end
end

---Performs a slow 1.8s manual +1 emergency prime on a 0-charge tool (0 Bloom) to guarantee zero soft-locks.
---@param player ObjectRef
---@param kind string "bellows" | "flask" | "pestle"
---@param itemstack ItemStack
---@return ItemStack updated_stack
---@return boolean primed
function tc_tools.try_emergency_prime(player, kind, itemstack)
    local spec = TOOL_SPECS[kind]
    if not spec or not tc_core.state.running or not player or not player:is_player() then
        return itemstack, false
    end
    if not tc_tools.check_cooldown(player, "emergency_prime", 1.8) then
        return itemstack, false
    end

    local updated = set_charges_for(spec, itemstack, 1)
    x_player_api.trigger_player_action(player, spec.prime_anim, 0.30)
    core.sound_play(spec.prime_sound, {pos = player:get_pos(), gain = spec.prime_gain, max_hear_distance = 12}, true)
    tc_core.push_action_feedback(player, {
        kind = "hint",
        icon = spec.prime_icon,
        text = spec.prime_text_fn(),
        color = spec.prime_color,
        accent_hex = spec.prime_accent,
        ttl = 2.4,
    })
    return updated, true
end

---Returns the reagent itemstring currently carried on the Alchemist's Trowel tongs (or "").
---@param itemstack ItemStack
---@return string
function tc_tools.get_trowel_cargo(itemstack)
    return itemstack:get_meta():get_string("carried_reagent")
end

---Updates or clears the carried reagent on an Alchemist's Trowel using native ItemStackMetaRef overlays.
---@param itemstack ItemStack
---@param reagent_name? string
---@return ItemStack
function tc_tools.set_trowel_cargo(itemstack, reagent_name)
    local meta = itemstack:get_meta()
    local spec = reagent_name and tc_elements.REAGENT_BY_NAME[reagent_name] or nil
    if not spec then
        meta:set_string("carried_reagent", "")
        meta:set_string("inventory_overlay", "")
        meta:set_string("wield_overlay", "")
        meta:set_string("short_description", "")
        meta:set_string("description", "")
        return itemstack
    end

    local pair_spec = tc_elements.REAGENT_BY_NAME[spec.pair_item]
    local pair_title = pair_spec and pair_spec.title or S("its opposite block")
    local overlay = spec.texture .. "^[resize:16x16"

    meta:set_string("carried_reagent", reagent_name)
    meta:set_string("inventory_overlay", overlay)
    meta:set_string("wield_overlay", overlay)
    meta:set_string(
        "short_description",
        S("Trowel [1] — Carrying @1 (Click @2 or Floor)", spec.title, pair_title)
    )
    meta:set_string("description", tc_assets.format_description({
        title = S("Alchemist's Trowel — Carrying @1", spec.title),
        category = S("Tool [1] · Holding 1 Block"),
        summary = S("Safely holding @1 on your trowel.", spec.title),
        effect = S("Combine it with @1 so both cancel out and boost plant growth!", pair_title),
        usage = S("Click directly on @1 (or Right-Click empty floor beside it) to combine!", pair_title),
        accent = spec.accent,
    }))
    return itemstack
end

---Syncs a player's 1-slot `trowel_cargo` inventory list and dynamic Luanti 5.18 `text2` HUD socket.
---@param player ObjectRef
---@param cargo_name? string Carried reagent node name, or `""` / `nil` when empty
function tc_tools.sync_player_trowel_cargo_inv(player, cargo_name)
    if not player or not player:is_player() then
        return
    end
    local inv = player:get_inventory()
    inv:set_size("trowel_cargo", 1)
    inv:set_stack("trowel_cargo", 1, ItemStack(cargo_name or ""))
    tc_core.sync_player_cargo_hud(player)
end

---Handles Left-Click (`on_punch`) or Right-Click (`on_place`) with Alchemist's Trowel on a floor reagent node.
---@param itemstack ItemStack
---@param user ObjectRef
---@param pos {x: integer, y: integer, z: integer}
---@param node_name string
---@return ItemStack updated_stack
---@return boolean changed
function tc_tools.handle_trowel_on_reagent(itemstack, user, pos, node_name)
    if not tc_core.state.running or not user or not user:is_player() then
        return itemstack, false
    end
    if core.get_node(pos).name ~= node_name then
        return itemstack, false
    end
    if not tc_tools.check_cooldown(user, "trowel_tongs", 0.20) then
        return itemstack, false
    end

    local carried = tc_tools.get_trowel_cargo(itemstack)
    if carried == "" then
        core.remove_node(pos)
        core.sound_play("tc_trowel_scoop", {pos = pos, gain = 0.8, max_hear_distance = 16}, true)
        x_player_api.trigger_player_action(user, "attack_thrust", 0.35)
        local updated = tc_tools.set_trowel_cargo(itemstack, node_name)
        tc_tools.sync_player_trowel_cargo_inv(user, node_name)
        x_player_api.update_wield_item(user, true, updated)
        return updated, true
    end

    local c_spec = tc_elements.REAGENT_BY_NAME[carried]
    if c_spec and c_spec.pair_item == node_name then
        core.get_meta(pos):set_string("placer", user:get_player_name())
        x_player_api.trigger_player_action(user, "attack_thrust", 0.35)
        local updated = tc_tools.set_trowel_cargo(itemstack, nil)
        tc_tools.sync_player_trowel_cargo_inv(user, "")
        x_player_api.update_wield_item(user, true, updated)
        if carried == "tc_elements:brimstone" or node_name == "tc_elements:brimstone" then
            tc_core.exec_melt_cancel(pos, pos)
        else
            tc_core.exec_acid_base(pos, pos)
        end
        return updated, true
    end

    local pair_spec = c_spec and tc_elements.REAGENT_BY_NAME[c_spec.pair_item] or nil
    local pair_title = pair_spec and pair_spec.title or S("its opposite block")
    tc_tools.send_hint(
        user, "trowel_busy",
        S(
            "Carrying @1! Click directly on @2 to combine, or Right-Click an empty floor tile to set it down.",
            c_spec and c_spec.title or S("a block"),
            pair_title
        )
    )
    return itemstack, false
end

---Clears any carried volatile reagent from all Alchemist's Trowels in a player's main inventory.
---@param player ObjectRef
function tc_tools.clear_player_trowels(player)
    if not player or not player:is_player() then
        return
    end
    local inv = player:get_inventory()
    local list = inv:get_list("main")
    if not list then
        return
    end
    local changed = false
    for i = 1, #list do
        local st = list[i]
        if st:get_name() == "tc_tools:trowel" and tc_tools.get_trowel_cargo(st) ~= "" then
            list[i] = tc_tools.set_trowel_cargo(st, nil)
            changed = true
        end
    end
    if changed then
        inv:set_list("main", list)
        x_player_api.update_wield_item(player, true)
    end
    tc_tools.sync_player_trowel_cargo_inv(player, "")
end

---Counts volatile hazards currently carried on connected players' Alchemist's Trowels.
---@return integer count
---@return string|nil first_item_name
function tc_tools.count_carried_hazards()
    local players = core.get_connected_players()
    local count = 0
    local first_item = nil
    for i = 1, #players do
        local p = players[i]
        if p and p:is_player() then
            local found = nil
            local inv = p:get_inventory()
            if inv and inv:get_size("trowel_cargo") >= 1 then
                local cname = inv:get_stack("trowel_cargo", 1):get_name()
                if cname ~= "" and tc_elements.REAGENT_BY_NAME[cname] ~= nil then
                    found = cname
                end
            end
            if not found then
                local wst = p:get_wielded_item()
                if wst and wst:get_name() == "tc_tools:trowel" then
                    local wc = tc_tools.get_trowel_cargo(wst)
                    if wc ~= "" and tc_elements.REAGENT_BY_NAME[wc] ~= nil then
                        found = wc
                    end
                end
            end
            if not found and inv then
                local list = inv:get_list("main")
                if list then
                    for slot = 1, #list do
                        local st = list[slot]
                        if st:get_name() == "tc_tools:trowel" then
                            local sc = tc_tools.get_trowel_cargo(st)
                            if sc ~= "" and tc_elements.REAGENT_BY_NAME[sc] ~= nil then
                                found = sc
                                break
                            end
                        end
                    end
                end
            end
            if found then
                count = count + 1
                if not first_item then
                    first_item = found
                end
            end
        end
    end
    return count, first_item
end

---Spawns a directional cone of heated ember & vapor particles from the Thermal Bellows.
---@param pos table Origin position vector
---@param dir table Look direction vector
function tc_tools.spawn_bellows_particles(pos, dir)
    local PT = tc_assets.PARTICLES
    tc_assets.spawn_sheet_particles({
        amount = 20,
        time = 0.2,
        minpos = {x = pos.x, y = pos.y + 1.2, z = pos.z},
        maxpos = {x = pos.x, y = pos.y + 1.4, z = pos.z},
        minvel = vector.multiply(dir, 4),
        maxvel = vector.multiply(dir, 8),
        minacc = {x = -0.5, y = 0.5, z = -0.5},
        maxacc = {x = 0.5, y = 1.5, z = 0.5},
        minexptime = 0.35,
        maxexptime = 0.70,
        minsize = 1.2,
        maxsize = 2.9,
        jitter = {min = {x = -0.2, y = -0.2, z = -0.2}, max = {x = 0.2, y = 0.2, z = 0.2}},
        drag = {x = 0.5, y = 0.5, z = 0.5},
        glow = 13,
        texpool = {
            tc_assets.make_sheet_tex_entry(PT.ember, {scale_tween = {1.35, 0.45}}),
            tc_assets.make_sheet_tex_entry(PT.steam, {
                blend = "alpha",
                scale_tween = {0.9, 1.8},
                alpha_tween = {0.75, 0.0},
            }),
        },
    })
end

---Spawns a neutralizing alkaline starlight dust cloud around the target center.
---@param center table Center position vector
---@param radius number Horizontal radius of the dust cloud
function tc_tools.spawn_pestle_particles(center, radius)
    local r = radius + 0.5
    local PT = tc_assets.PARTICLES
    tc_assets.spawn_sheet_particles({
        amount = 26,
        time = 0.25,
        minpos = {x = center.x - r, y = center.y + 0.2, z = center.z - r},
        maxpos = {x = center.x + r, y = center.y + 1.4, z = center.z + r},
        minvel = {x = -0.6, y = 0.2, z = -0.6},
        maxvel = {x = 0.6, y = 1.1, z = 0.6},
        minexptime = 0.5,
        maxexptime = 1.0,
        minsize = 1.2,
        maxsize = 2.8,
        jitter = {min = {x = -0.3, y = -0.1, z = -0.3}, max = {x = 0.3, y = 0.3, z = 0.3}},
        drag = {x = 0.8, y = 0.8, z = 0.8},
        glow = 11,
        texpool = {
            tc_assets.make_sheet_tex_entry(PT.pollen, {scale_tween = {1.3, 0.45}}),
            tc_assets.make_sheet_tex_entry(PT.steam, {
                blend = "alpha",
                scale_tween = {0.8, 1.9},
                alpha_tween = {0.85, 0.0},
            }),
        },
    })
end

---Spawns an alchemical aura burst around a player consuming an elixir.
---@param pos table Player position vector
---@param texture string Particle sheet texture name
function tc_tools.spawn_elixir_particles(pos, texture)
    local sheet = (texture and texture ~= "") and texture or tc_assets.PARTICLES.bloom
    local primary_blend = (sheet == tc_assets.PARTICLES.droplet) and "alpha" or "add"
    tc_assets.spawn_sheet_particles({
        amount = 24,
        time = 0.35,
        minpos = {x = pos.x - 0.6, y = pos.y + 0.2, z = pos.z - 0.6},
        maxpos = {x = pos.x + 0.6, y = pos.y + 1.6, z = pos.z + 0.6},
        minvel = {x = -1.2, y = 0.8, z = -1.2},
        maxvel = {x = 1.2, y = 2.4, z = 1.2},
        minexptime = 0.6,
        maxexptime = 1.15,
        minsize = 1.5,
        maxsize = 3.2,
        jitter = {min = {x = -0.2, y = -0.2, z = -0.2}, max = {x = 0.2, y = 0.2, z = 0.2}},
        glow = 13,
        texpool = {
            tc_assets.make_sheet_tex_entry(sheet, {blend = primary_blend, scale_tween = {1.35, 0.5}}),
            tc_assets.make_sheet_tex_entry(tc_assets.PARTICLES.pollen, {scale_tween = {1.2, 0.4}}),
        },
    })
end

---Spawns an animated aqueous droplet splash (with optional rising steam puffs for hot quenches).
---@param pos table Target node position
---@param with_steam? boolean Whether to mix rising steam vapor puffs
function tc_tools.spawn_water_splash_particles(pos, with_steam)
    local PT = tc_assets.PARTICLES
    local pool = {
        tc_assets.make_sheet_tex_entry(PT.droplet, {
            blend = "alpha",
            scale_tween = {1.15, 1.55},
            alpha_tween = {1.0, 0.0},
        }),
    }
    if with_steam then
        pool[#pool + 1] = tc_assets.make_sheet_tex_entry(PT.steam, {
            blend = "alpha",
            scale_tween = {0.85, 2.1},
            alpha_tween = {0.9, 0.0},
        })
    end
    tc_assets.spawn_sheet_particles({
        amount = with_steam and 22 or 16,
        time = 0.2,
        minpos = {x = pos.x - 0.35, y = pos.y - 0.15, z = pos.z - 0.35},
        maxpos = {x = pos.x + 0.35, y = pos.y + 0.45, z = pos.z + 0.35},
        minvel = {x = -1.4, y = 0.9, z = -1.4},
        maxvel = {x = 1.4, y = with_steam and 3.2 or 2.4, z = 1.4},
        minacc = {x = 0, y = with_steam and -0.4 or -3.2, z = 0},
        maxacc = {x = 0, y = with_steam and 1.2 or -1.2, z = 0},
        minexptime = 0.45,
        maxexptime = 0.95,
        minsize = 1.4,
        maxsize = 2.9,
        glow = 11,
        texpool = pool,
    })
end
