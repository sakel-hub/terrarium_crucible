-- tc_elements/entities.lua: Native physical falling reagent entity with mid-air counter skill-shots

local S = tc_elements.S
local P = tc_assets.PALETTE

local COUNTER_HINT_BY_ITEM = {
    ["tc_elements:brimstone"]      = S("Catch mid-air with filled Flask [3] (or low Bellows [2] to refill)!"),
    ["tc_elements:cryo_ice"]       = S("Catch mid-air with charged Bellows [2] for bonus Bloom!"),
    ["tc_elements:acid_slime"]     = S("Catch mid-air with charged Pestle [4] for bonus Bloom!"),
    ["tc_elements:alkaline_chalk"] = S("Catch mid-air with filled Flask [3] (or low Pestle [4] to refill)!"),
    ["tc_elements:aether_geode"]   = S("Click with Trowel [1] (or let it land) to crack open the crystal!"),
}

-- Snaps crystal facet orientation immediately using Luanti 5.18 set_rotation(rot, false) (no interpolation slerp)
local function snap_crystal_rotation(obj, pos, jolt_offset)
    local px = pos and pos.x or 0
    local pz = pos and pos.z or 0
    local py = pos and pos.y or 0
    local step = jolt_offset or 0
    local seed = math.abs(math.floor((px * 13 + pz * 29 + py * 7 + step * 37) * 10))
    local yaw = ((seed % 36) / 36.0) * (math.pi * 2.0)
    local pitch = (((seed % 7) - 3) * 0.08) + (step > 0 and 0.28 or 0.0)
    local roll = ((((math.floor(seed / 7)) % 7) - 3) * 0.08) - (step > 0 and 0.22 or 0.0)
    obj:set_rotation({x = pitch, y = yaw, z = roll}, false)
end

local INTERCEPT_SHEET_BY_ITEM = {
    ["tc_elements:brimstone"]      = tc_assets.PARTICLES.steam,
    ["tc_elements:cryo_ice"]       = tc_assets.PARTICLES.droplet,
    ["tc_elements:acid_slime"]     = tc_assets.PARTICLES.pollen,
    ["tc_elements:alkaline_chalk"] = tc_assets.PARTICLES.droplet,
}

local function spawn_intercept_burst(pos, item_name)
    local primary = INTERCEPT_SHEET_BY_ITEM[item_name] or tc_assets.PARTICLES.pollen
    local primary_blend = (primary == tc_assets.PARTICLES.steam or primary == tc_assets.PARTICLES.droplet)
        and "alpha" or "add"
    tc_assets.spawn_sheet_particles({
        amount = 24,
        time = 0.2,
        minpos = {x = pos.x - 0.5, y = pos.y - 0.4, z = pos.z - 0.5},
        maxpos = {x = pos.x + 0.5, y = pos.y + 0.5, z = pos.z + 0.5},
        minvel = {x = -2.8, y = 0.8, z = -2.8},
        maxvel = {x = 2.8, y = 3.6, z = 2.8},
        drag = {x = 0.6, y = 0.3, z = 0.6},
        minexptime = 0.45,
        maxexptime = 0.95,
        minsize = 1.5,
        maxsize = 3.2,
        glow = 13,
        texpool = {
            tc_assets.make_sheet_tex_entry(primary, {blend = primary_blend, scale_tween = {1.3, 0.5}}),
            tc_assets.make_sheet_tex_entry(tc_assets.PARTICLES.bloom, {scale_tween = {1.2, 0.4}}),
        },
    })
end

-- Active falling_reagent Lua entity instances for zero-allocation look-ray & landing-ring catch assist
local active_falling = {}

local function is_entity_live(ent, cur_epoch)
    if not ent or ent._removed or ent.epoch ~= cur_epoch then
        return false
    end
    local obj = ent.object
    if not obj then
        return false
    end
    if obj.is_valid and not obj:is_valid() then
        return false
    end
    return obj:get_pos() ~= nil
end

local function remove_falling_entity(ent)
    if ent.object then
        ent.object:remove()
    end
    local cur_epoch = tc_core.state.epoch or 0
    local write_i = 1
    for i = 1, #active_falling do
        local cand = active_falling[i]
        if cand ~= ent and is_entity_live(cand, cur_epoch) then
            active_falling[write_i] = cand
            write_i = write_i + 1
        end
    end
    for i = #active_falling, write_i, -1 do
        active_falling[i] = nil
    end
end

---Returns true when the given tool stack can actively catch or siphon/grind the specified falling item.
---@param itemstack ItemStack
---@param item_name string
---@return boolean
function tc_elements.can_tool_catch_reagent(itemstack, item_name)
    if not itemstack or itemstack:is_empty() then
        return false
    end
    local wname = itemstack:get_name()
    if item_name == "tc_elements:aether_geode" then
        return wname == "tc_tools:trowel"
    elseif item_name == "tc_elements:brimstone" then
        if wname == "tc_tools:condenser_flask_full" or wname == "tc_tools:bellows_empty" then
            return true
        end
        if wname == "tc_tools:bellows" then
            return tc_tools.get_bellows_charges(itemstack) < tc_tools.get_max_bellows_charges()
        end
    elseif item_name == "tc_elements:alkaline_chalk" then
        if wname == "tc_tools:condenser_flask_full" or wname == "tc_tools:chalk_pestle_empty" then
            return true
        end
        if wname == "tc_tools:chalk_pestle" then
            return tc_tools.get_pestle_charges(itemstack) < tc_tools.get_max_pestle_charges()
        end
    elseif item_name == "tc_elements:cryo_ice" then
        return wname == "tc_tools:bellows"
    elseif item_name == "tc_elements:acid_slime" then
        return wname == "tc_tools:chalk_pestle"
    end
    return false
end

---Processes a direct mid-air tool interaction against a `tc_elements:falling_reagent` ObjectRef or Luaentity.
---Returns `(updated_stack, handled, matched)` so `on_use` callers preserve modified charges/wear.
---@param target any ObjectRef or falling_reagent luaentity table
---@param user ObjectRef
---@param itemstack? ItemStack
---@return ItemStack updated_stack
---@return boolean handled
---@return boolean matched
function tc_elements.interact_falling_reagent(target, user, itemstack)
    local fallback = itemstack or (user and user:is_player() and user:get_wielded_item()) or ItemStack("")
    local ent = nil
    if type(target) == "table" and target._is_falling_reagent then
        ent = target
    elseif target and target.get_luaentity then
        local luaent = target:get_luaentity()
        if luaent and luaent._is_falling_reagent then
            ent = luaent
        end
    end
    if not ent then
        return fallback, false, false
    end
    if not tc_core.state.running or not user or not user:is_player() then
        return fallback, true, false
    end

    local wield = itemstack or user:get_wielded_item()
    local wname = wield:get_name()
    local pos = ent.object and ent.object:get_pos() or nil
    if not pos then
        return wield, false, false
    end
    local iname = ent.item_name
    ent.jolt_count = (ent.jolt_count or 0) + 1

    -- Mid-air Prismatic Geode resonance with Trowel
    if iname == "tc_elements:aether_geode" then
        if wname == "tc_tools:trowel" then
            local rpos = vector.round(pos)
            local geode_floor = {x = rpos.x, y = 1, z = rpos.z}
            if tc_tools.get_trowel_cargo(wield) ~= "" then
                wield = tc_tools.set_trowel_cargo(wield, nil)
                tc_tools.sync_player_trowel_cargo_inv(user, "")
                x_player_api.update_wield_item(user, true, wield)
                tc_core.add_scaled_bloom(0.5, geode_floor)
                tc_core.record_neutralization(user, 1)
            end
            remove_falling_entity(ent)
            x_player_api.trigger_player_action(user, "attack_thrust", 0.35)
            tc_elements.resonate_geode_at(geode_floor, user)
            return wield, true, true
        end
        snap_crystal_rotation(ent.object, pos, ent.jolt_count)
        tc_tools.send_hint(user, "midair_geode", COUNTER_HINT_BY_ITEM[iname])
        return wield, true, false
    end

    local matched = false
    local new_stack = wield
    local refill_label = nil
    local floor_pos = {x = math.floor(pos.x + 0.5), y = 1, z = math.floor(pos.z + 0.5)}

    if (iname == "tc_elements:brimstone" or iname == "tc_elements:alkaline_chalk")
            and wname == "tc_tools:condenser_flask_full" then
        new_stack = tc_tools.consume_flask_charge(wield)
        x_player_api.trigger_player_action(user, "attack_slash", 0.35)
        x_player_api.update_wield_item(user, true, new_stack)
        core.sound_play("tc_water_splash", {pos = pos, gain = 0.85, max_hear_distance = 20}, true)
        if iname == "tc_elements:alkaline_chalk" then
            tc_elements.enrich_soil_at(floor_pos)
        elseif core.get_node(floor_pos).name == "air" then
            core.set_node(floor_pos, {name = "tc_elements:steam"})
        else
            local above_pos = {x = floor_pos.x, y = 2, z = floor_pos.z}
            if core.get_node(above_pos).name == "air" then
                core.set_node(above_pos, {name = "tc_elements:steam"})
            end
        end
        matched = true
    elseif (iname == "tc_elements:brimstone" or iname == "tc_elements:alkaline_chalk")
            and wname == "tc_tools:condenser_flask" then
        snap_crystal_rotation(ent.object, pos, ent.jolt_count)
        tc_tools.send_hint(
            user,
            "empty_flask",
            S("Flask empty! Click Water/Steam to fill, or click air to condense +1.")
        )
        return wield, true, false
    elseif iname == "tc_elements:brimstone"
            and (wname == "tc_tools:bellows_empty" or wname == "tc_tools:bellows") then
        if wname == "tc_tools:bellows_empty"
                or tc_tools.get_bellows_charges(wield) < tc_tools.get_max_bellows_charges() then
            new_stack = tc_tools.fill_bellows()
            x_player_api.trigger_player_action(user, "attack_thrust", 0.35)
            x_player_api.update_wield_item(user, true, new_stack)
            core.sound_play("tc_sizzle", {pos = pos, gain = 0.80, max_hear_distance = 20}, true)
            core.sound_play("tc_bellows", {pos = pos, gain = 0.70, max_hear_distance = 20}, true)
            refill_label = S("Mid-Air Siphon → Bellows Full!")
            matched = true
        else
            snap_crystal_rotation(ent.object, pos, ent.jolt_count)
            tc_tools.send_hint(
                user,
                "bellows_full",
                S("Bellows [2] is full! Splash Brimstone [3] or pair Ice [1].")
            )
            return wield, true, false
        end
    elseif iname == "tc_elements:alkaline_chalk"
            and (wname == "tc_tools:chalk_pestle_empty" or wname == "tc_tools:chalk_pestle") then
        if wname == "tc_tools:chalk_pestle_empty"
                or tc_tools.get_pestle_charges(wield) < tc_tools.get_max_pestle_charges() then
            new_stack = tc_tools.fill_pestle()
            x_player_api.trigger_player_action(user, "attack_slash", 0.35)
            x_player_api.update_wield_item(user, true, new_stack)
            core.sound_play("tc_pestle", {pos = pos, gain = 0.85, max_hear_distance = 20}, true)
            tc_elements.enrich_soil_at(floor_pos)
            refill_label = S("Mid-Air Grind → Pestle Full!")
            matched = true
        else
            snap_crystal_rotation(ent.object, pos, ent.jolt_count)
            tc_tools.send_hint(
                user,
                "pestle_full",
                S("Pestle [4] is full! Wash Chalk [3] or pair Acid [1].")
            )
            return wield, true, false
        end
    elseif iname == "tc_elements:cryo_ice" and wname == "tc_tools:bellows" then
        new_stack = tc_tools.consume_bellows_charge(wield)
        x_player_api.trigger_player_action(user, "attack_thrust", 0.35)
        x_player_api.update_wield_item(user, true, new_stack)
        core.sound_play("tc_bellows", {pos = pos, gain = 0.85, max_hear_distance = 20}, true)
        if not tc_world.is_protected_pos(floor_pos, tc_core.state.level)
                and core.get_node(floor_pos).name == "air" then
            core.set_node(floor_pos, {name = "tc_elements:water_source"})
            core.get_meta(floor_pos):set_string("placer", user:get_player_name())
            tc_core.try_react_at(floor_pos)
        end
        matched = true
    elseif iname == "tc_elements:cryo_ice" and wname == "tc_tools:bellows_empty" then
        snap_crystal_rotation(ent.object, pos, ent.jolt_count)
        tc_tools.send_hint(
            user,
            "empty_bellows",
            S("Bellows empty! Click Brimstone to refill, or click air to pump +1.")
        )
        return wield, true, false
    elseif iname == "tc_elements:acid_slime" and wname == "tc_tools:chalk_pestle" then
        new_stack = tc_tools.consume_pestle_charge(wield)
        x_player_api.trigger_player_action(user, "attack_slash", 0.35)
        x_player_api.update_wield_item(user, true, new_stack)
        core.sound_play("tc_pestle", {pos = pos, gain = 0.85, max_hear_distance = 20}, true)
        tc_elements.enrich_soil_at(floor_pos)
        matched = true
    elseif iname == "tc_elements:acid_slime" and wname == "tc_tools:chalk_pestle_empty" then
        snap_crystal_rotation(ent.object, pos, ent.jolt_count)
        tc_tools.send_hint(
            user,
            "empty_pestle",
            S("Pestle empty! Click Chalk to refill, or click air to scrape +1.")
        )
        return wield, true, false
    end

    if matched then
        local spec = tc_elements.REAGENT_BY_NAME[iname]
        spawn_intercept_burst(pos, iname)
        core.sound_play("tc_geode_chime", {pos = pos, gain = 0.8, max_hear_distance = 24}, true)
        local pvel = user:get_velocity()
        local aerial = (pvel ~= nil and (pvel.y or 0) > 0.2)
            or tc_core.has_effect(user, "steam_updraft")
        local midair_bloom = (tc_core.has_blessing("featherfall_canopy") and 3.0 or 2.2)
            + (aerial and 0.6 or 0.0)
        local gain = tc_core.add_scaled_bloom(midair_bloom, floor_pos)
        tc_core.record_neutralization(user, 1)
        local catch_tag = aerial and S("★ Aerial Catch!") or S("★ Mid-Air Catch!")
        tc_core.push_action_feedback(user, {
            kind = "action",
            icon = spec and spec.texture or "tc_aether_geode.png",
            bloom = gain,
            label = refill_label or catch_tag,
            color = P.hud_gold,
            accent_hex = P.gold,
        })
        remove_falling_entity(ent)
        return new_stack, true, true
    end

    snap_crystal_rotation(ent.object, pos, ent.jolt_count)
    tc_tools.send_hint(user, "midair_" .. iname, COUNTER_HINT_BY_ITEM[iname] or S("Use the matching tool!"))
    return wield, true, false
end

---Finds a matching active falling_reagent along the player's look ray or descending low above a clicked landing tile,
---compensating for client/server motion interpolation during high-speed descent.
---@param user ObjectRef
---@param pointed_thing? table
---@param itemstack? ItemStack
---@return table|nil luaentity
function tc_elements.find_interceptable_reagent(user, pointed_thing, itemstack)
    if not tc_core.state.running or not user or not user:is_player() or #active_falling == 0 then
        return nil
    end
    local stack = itemstack or user:get_wielded_item()
    if not stack or stack:is_empty() then
        return nil
    end
    local ppos = user:get_pos()
    if not ppos then
        return nil
    end

    local props = user:get_properties()
    local eye_h = (props and props.eye_height) or 1.47
    local ex, ey, ez = ppos.x, ppos.y + eye_h, ppos.z
    local dir = user:get_look_dir()
    local dx = dir and dir.x or 0
    local dy = dir and dir.y or 0
    local dz = dir and dir.z or 1
    local under = (pointed_thing and pointed_thing.type == "node") and pointed_thing.under or nil
    local cur_epoch = tc_core.state.epoch or 0

    local best_ent = nil
    local best_score = math.huge
    local write_i = 1

    for i = 1, #active_falling do
        local ent = active_falling[i]
        if is_entity_live(ent, cur_epoch) then
            active_falling[write_i] = ent
            write_i = write_i + 1
            if tc_elements.can_tool_catch_reagent(stack, ent.item_name) then
                local epos = ent.object:get_pos()
                local vx = epos.x - ex
                local vy = epos.y - ey
                local vz = epos.z - ez
                local dist_sq = (vx * vx) + (vy * vy) + (vz * vz)

                -- Check aim-ray cylinder (generous vertical tolerance for downward fall speed)
                local proj = (vx * dx) + (vy * dy) + (vz * dz)
                if proj >= -0.25 and proj <= 6.2 then
                    local rx = vx - (proj * dx)
                    local ry = (vy - (proj * dy)) * 0.75
                    local rz = vz - (proj * dz)
                    local perp_sq = (rx * rx) + (ry * ry) + (rz * rz)
                    if perp_sq <= (0.95 * 0.95) and perp_sq < best_score then
                        best_score = perp_sq
                        best_ent = ent
                    end
                end

                -- Check low-altitude landing column when clicking the glowing floor ring right before touchdown
                if under and epos.y <= 4.5 and dist_sq <= (6.5 * 6.5) then
                    local ux = math.abs(epos.x - under.x)
                    local uz = math.abs(epos.z - under.z)
                    if ux <= 1.05 and uz <= 1.05 then
                        local land_score = 1.0 + (ux * ux) + (uz * uz)
                        if land_score < best_score then
                            best_score = land_score
                            best_ent = ent
                        end
                    end
                end
            end
        end
    end

    for i = #active_falling, write_i, -1 do
        active_falling[i] = nil
    end

    return best_ent
end

core.register_entity("tc_elements:falling_reagent", {
    initial_properties = {
        physical = true,
        collide_with_objects = false,
        collisionbox = {-0.42, -0.42, -0.42, 0.42, 0.42, 0.42},
        selectionbox = {-0.52, -0.58, -0.52, 0.52, 0.68, 0.52},
        pointable = true,
        visual = "wielditem",
        visual_size = {x = 0.65, y = 0.65},
        wield_item = "tc_elements:brimstone",
        automatic_rotate = 1.4,
        glow = 11,
        static_save = false,
    },

    _is_falling_reagent = true,
    item_name = "tc_elements:brimstone",
    age = 0.0,
    epoch = 0,

    on_activate = function(self, staticdata)
        if not tc_core.state.running then
            self.object:remove()
            return
        end
        local item_name = (staticdata and staticdata ~= "") and staticdata or "tc_elements:brimstone"
        local cur_epoch = tc_core.state.epoch or 0
        self.item_name = item_name
        self.age = 0.0
        self.epoch = cur_epoch

        local write_i = 1
        for i = 1, #active_falling do
            local cand = active_falling[i]
            if is_entity_live(cand, cur_epoch) then
                active_falling[write_i] = cand
                write_i = write_i + 1
            end
        end
        for i = #active_falling, write_i, -1 do
            active_falling[i] = nil
        end
        active_falling[#active_falling + 1] = self

        local spec = tc_elements.REAGENT_BY_NAME[item_name] or tc_elements.CATALYST
        local title = spec and spec.title or S("Falling Block")
        local hint = COUNTER_HINT_BY_ITEM[item_name] or S("Hit mid-air with the matching tool!")

        self.object:set_properties({
            wield_item = item_name,
            infotext = tc_assets.format_infotext(S("Falling @1", title), S("Dropping from above"), hint),
        })
        snap_crystal_rotation(self.object, self.object:get_pos(), 0)
        local slow = tc_core.has_blessing("featherfall_canopy")
        self.object:set_velocity({x = 0, y = slow and -1.0 or -1.4, z = 0})
        self.object:set_acceleration({x = 0, y = slow and -1.5 or -2.4, z = 0})
    end,

    on_punch = function(self, puncher)
        if not puncher or not puncher:is_player() then
            return true
        end
        local wield = puncher:get_wielded_item()
        local updated, _, matched = tc_elements.interact_falling_reagent(self, puncher, wield)
        if matched then
            puncher:set_wielded_item(updated)
        end
        return true
    end,

    on_rightclick = function(self, clicker)
        if not clicker or not clicker:is_player() then
            return
        end
        local wield = clicker:get_wielded_item()
        local wname = wield:get_name()
        if wname ~= "tc_tools:trowel" then
            local wdef = core.registered_items[wname]
            if wdef and wdef.on_secondary_use then
                local next_st = wdef.on_secondary_use(wield, clicker, {type = "object", ref = self.object})
                if next_st then
                    clicker:set_wielded_item(next_st)
                end
                return
            end
        end
        local updated, _, matched = tc_elements.interact_falling_reagent(self, clicker, wield)
        if matched then
            clicker:set_wielded_item(updated)
        end
    end,

    on_step = function(self, dtime, moveresult)
        if not tc_core.state.running or self.epoch ~= (tc_core.state.epoch or 0) then
            remove_falling_entity(self)
            return
        end
        self.age = self.age + dtime
        if self.age > 12.0 then
            remove_falling_entity(self)
            return
        end

        local pos = self.object:get_pos()
        if not pos then
            return
        end

        local landed = (moveresult and moveresult.touching_ground) or (pos.y <= 1.05)
        if not landed then
            local below = {x = math.floor(pos.x + 0.5), y = math.floor(pos.y - 0.48), z = math.floor(pos.z + 0.5)}
            local bname = core.get_node(below).name
            if bname ~= "air" and bname ~= "tc_elements:steam" then
                landed = true
            end
        end

        if landed then
            local land_pos = {
                x = math.floor(pos.x + 0.5),
                y = math.max(1, math.floor(pos.y + 0.5)),
                z = math.floor(pos.z + 0.5),
            }

            tc_world.resolve_safe_floor_pos(land_pos, tc_core.state.level)

            -- Step upward if landing space is already occupied by a solid reagent
            for _ = 1, 6 do
                local cname = core.get_node(land_pos).name
                if cname == "air" or cname == "tc_elements:steam"
                        or cname == "tc_elements:water_flowing" then
                    break
                end
                land_pos.y = land_pos.y + 1
            end

            local iname = self.item_name
            local is_hazard = tc_elements.REAGENT_BY_NAME[iname] ~= nil
            remove_falling_entity(self)

            if land_pos.y <= 9 then
                local cname = core.get_node(land_pos).name
                if cname == "air" or cname == "tc_elements:steam"
                        or cname == "tc_elements:water_flowing" then
                    core.set_node(land_pos, {name = iname})
                    local snd = (iname == "tc_elements:aether_geode") and "tc_geode_chime" or "tc_place_node_hard"
                    core.sound_play(snd, {pos = land_pos, gain = 0.85, max_hear_distance = 24}, true)

                    if is_hazard then
                        local ndef = core.registered_nodes[iname]
                        local solid = (ndef == nil) or (ndef.walkable ~= false)
                        local players = core.get_connected_players()
                        for i = 1, #players do
                            local pl = players[i]
                            local ppos = pl:get_pos()
                            local dx = ppos.x - land_pos.x
                            local dz = ppos.z - land_pos.z
                            if (dx * dx + dz * dz) <= 0.85 and math.abs(ppos.y - land_pos.y) <= 1.8 then
                                if solid and ppos.y < (land_pos.y + 0.5) then
                                    pl:set_pos({x = ppos.x, y = land_pos.y + 0.55, z = ppos.z})
                                end
                                if tc_core.damage_player(pl, 3, "falling_block") then
                                    tc_tools.send_hint(
                                        pl,
                                        "falling_bonk",
                                        S("Ouch! Step outside glowing floor rings before falling blocks land " ..
                                            "(or swat them mid-air)!")
                                    )
                                end
                            end
                        end
                    end

                    tc_core.try_react_at(land_pos)
                end
            end
        end
    end,
})
