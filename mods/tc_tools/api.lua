---@class TcToolsAPI
---@field check_cooldown fun(player: ObjectRef, key: string, cooldown_sec: number): boolean
---@field send_hint fun(player: ObjectRef, key: string, message: string)
---@field get_max_flask_charges fun(): integer
---@field get_flask_charges fun(itemstack: ItemStack): integer
---@field set_flask_charges fun(itemstack: ItemStack, charges: integer): ItemStack
---@field fill_flask fun(): ItemStack
---@field consume_flask_charge fun(itemstack: ItemStack): ItemStack
---@field get_trowel_cargo fun(itemstack: ItemStack): string
---@field set_trowel_cargo fun(itemstack: ItemStack, reagent_name?: string): ItemStack
---@field clear_player_trowels fun(player: ObjectRef)
---@field spawn_bellows_particles fun(pos: table, dir: table)
---@field spawn_pestle_particles fun(center: table, radius: number)
---@field spawn_elixir_particles fun(pos: table, texture: string)
---@field spawn_water_splash_particles fun(pos: table, with_steam?: boolean)
tc_tools = {}

local P = tc_assets.PALETTE

-- Per-player microsecond timestamps: player_cooldowns[player_name][key] = last_us
local player_cooldowns = {}

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

---Sends a throttled contextual tip when a player uses the wrong tool on a hazard.
---@param player ObjectRef
---@param key string Hint throttle key
---@param message string Guidance text
function tc_tools.send_hint(player, key, message)
    if tc_tools.check_cooldown(player, "hint_" .. key, 2.5) then
        core.chat_send_player(
            player:get_player_name(),
            tc_assets.chat_prefix("Helpful Tip", P.aqua) ..
            core.colorize(P.text_primary, message)
        )
    end
end

---Returns the current maximum Aqueous Charges per Condenser Flask fill (3 base, 5 with Deep Retort boon).
---@return integer
function tc_tools.get_max_flask_charges()
    return tc_core.has_boon("deep_retort") and 5 or 3
end

---Reads remaining Aqueous Charges from a Charged Condenser Flask ItemStack.
---@param itemstack ItemStack
---@return integer
function tc_tools.get_flask_charges(itemstack)
    if itemstack:get_name() ~= "tc_tools:condenser_flask_full" then
        return 0
    end
    local max_c = tc_tools.get_max_flask_charges()
    local meta = itemstack:get_meta()
    local stored = meta:get_int("charges")
    if stored <= 0 then
        return max_c
    end
    return math.min(max_c, stored)
end

---Updates a Charged Condenser Flask's charges, native Luanti tool wear bar, and wielded short_description.
---@param itemstack ItemStack
---@param charges integer
---@return ItemStack
function tc_tools.set_flask_charges(itemstack, charges)
    if charges <= 0 then
        return ItemStack("tc_tools:condenser_flask")
    end
    local max_c = tc_tools.get_max_flask_charges()
    local clamped = math.min(max_c, math.floor(charges))
    if itemstack:get_name() ~= "tc_tools:condenser_flask_full" then
        itemstack = ItemStack("tc_tools:condenser_flask_full")
    end
    local wear = 0
    if clamped < max_c then
        wear = math.floor(65535 * (max_c - clamped) / max_c)
    end
    itemstack:set_wear(wear)
    local meta = itemstack:get_meta()
    meta:set_int("charges", clamped)
    meta:set_string("short_description", string.format("Water Flask [3] — %d/%d Splashes", clamped, max_c))
    return itemstack
end

---Creates a freshly filled Charged Condenser Flask at maximum capacity.
---@return ItemStack
function tc_tools.fill_flask()
    local st = ItemStack("tc_tools:condenser_flask_full")
    return tc_tools.set_flask_charges(st, tc_tools.get_max_flask_charges())
end

---Consumes 1 charge from a Charged Condenser Flask, reverting to empty at 0 charges.
---@param itemstack ItemStack
---@return ItemStack
function tc_tools.consume_flask_charge(itemstack)
    local curr = tc_tools.get_flask_charges(itemstack)
    return tc_tools.set_flask_charges(itemstack, curr - 1)
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
    local pair_title = pair_spec and pair_spec.title or "its opposite block"
    local overlay = spec.texture .. "^[resize:16x16"

    meta:set_string("carried_reagent", reagent_name)
    meta:set_string("inventory_overlay", overlay)
    meta:set_string("wield_overlay", overlay)
    meta:set_string(
        "short_description",
        string.format("Trowel [1] — Carrying %s (Right-Click Floor)", spec.title)
    )
    meta:set_string("description", tc_assets.format_description({
        title = "Alchemist's Trowel — Carrying " .. spec.title,
        category = "Tool [1] · Holding 1 Block",
        summary = "Safely holding " .. spec.title .. " on your trowel.",
        effect = "Place it right next to " .. pair_title .. " so both cancel out and boost plant growth!",
        usage = "Right-Click on an empty floor spot beside " .. pair_title .. " to combine them!",
        accent = spec.accent,
    }))
    return itemstack
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
