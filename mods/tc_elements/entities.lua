-- tc_elements/entities.lua: Native physical falling reagent entity with mid-air counter skill-shots

local P = tc_assets.PALETTE

local COUNTER_HINT_BY_ITEM = {
    ["tc_elements:brimstone"]      = "Left-Click mid-air with a filled Water Flask [3] for bonus plant growth!",
    ["tc_elements:cryo_ice"]       = "Left-Click mid-air with Thermal Bellows [2] for bonus plant growth!",
    ["tc_elements:acid_slime"]     = "Left-Click mid-air with Limestone Pestle [4] for bonus plant growth!",
    ["tc_elements:alkaline_chalk"] = "Left-Click mid-air with a filled Water Flask [3] for bonus plant growth!",
    ["tc_elements:aether_geode"]   = "Left-Click with Trowel [1] (or let it land first) to crack open the crystal!",
}

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

core.register_entity("tc_elements:falling_reagent", {
    initial_properties = {
        physical = true,
        collide_with_objects = false,
        collisionbox = {-0.42, -0.42, -0.42, 0.42, 0.42, 0.42},
        selectionbox = {-0.48, -0.48, -0.48, 0.48, 0.48, 0.48},
        pointable = true,
        visual = "wielditem",
        visual_size = {x = 0.65, y = 0.65},
        wield_item = "tc_elements:brimstone",
        automatic_rotate = 1.4,
        glow = 11,
        static_save = false,
    },

    item_name = "tc_elements:brimstone",
    age = 0.0,
    epoch = 0,

    on_activate = function(self, staticdata)
        if not tc_core.state.running then
            self.object:remove()
            return
        end
        local item_name = (staticdata and staticdata ~= "") and staticdata or "tc_elements:brimstone"
        self.item_name = item_name
        self.age = 0.0
        self.epoch = tc_core.state.epoch or 0

        local spec = tc_elements.REAGENT_BY_NAME[item_name] or tc_elements.CATALYST
        local title = spec and spec.title or "Falling Block"
        local hint = COUNTER_HINT_BY_ITEM[item_name] or "Hit mid-air with the matching tool!"

        self.object:set_properties({
            wield_item = item_name,
            infotext = tc_assets.format_infotext("Falling " .. title, "Dropping from above", hint),
        })
        self.object:set_velocity({x = 0, y = -1.4, z = 0})
        self.object:set_acceleration({x = 0, y = -2.4, z = 0})
    end,

    on_punch = function(self, puncher)
        if not puncher or not puncher:is_player() then
            return true
        end
        local wield = puncher:get_wielded_item()
        local wname = wield:get_name()
        local pos = self.object:get_pos()
        if not pos then
            return true
        end
        local iname = self.item_name

        -- Mid-air Prismatic Geode resonance with Trowel
        if iname == "tc_elements:aether_geode" then
            if wname == "tc_tools:trowel" then
                local rpos = vector.round(pos)
                self.object:remove()
                x_player_api.trigger_player_action(puncher, "attack_thrust", 0.35)
                tc_elements.resonate_geode_at({x = rpos.x, y = 1, z = rpos.z}, puncher)
                return true
            end
            tc_tools.send_hint(puncher, "midair_geode", COUNTER_HINT_BY_ITEM[iname])
            return true
        end

        local matched = false
        local floor_pos = {x = math.floor(pos.x + 0.5), y = 1, z = math.floor(pos.z + 0.5)}

        if (iname == "tc_elements:brimstone" or iname == "tc_elements:alkaline_chalk")
                and wname == "tc_tools:condenser_flask_full" then
            local new_stack = tc_tools.consume_flask_charge(wield)
            puncher:set_wielded_item(new_stack)
            x_player_api.trigger_player_action(puncher, "attack_slash", 0.35)
            x_player_api.update_wield_item(puncher, true, new_stack)
            core.sound_play("tc_water_splash", {pos = pos, gain = 0.85, max_hear_distance = 20}, true)
            if iname == "tc_elements:alkaline_chalk" then
                tc_elements.enrich_soil_at(floor_pos)
            elseif core.get_node(floor_pos).name == "air" then
                core.set_node(floor_pos, {name = "tc_elements:steam"})
            end
            matched = true
        elseif iname == "tc_elements:cryo_ice" and wname == "tc_tools:bellows" then
            x_player_api.trigger_player_action(puncher, "attack_thrust", 0.35)
            core.sound_play("tc_bellows", {pos = pos, gain = 0.85, max_hear_distance = 20}, true)
            if not tc_world.is_protected_pos(floor_pos, tc_core.state.level)
                    and core.get_node(floor_pos).name == "air" then
                core.set_node(floor_pos, {name = "tc_elements:water_source"})
            end
            matched = true
        elseif iname == "tc_elements:acid_slime" and wname == "tc_tools:chalk_pestle" then
            x_player_api.trigger_player_action(puncher, "attack_slash", 0.35)
            core.sound_play("tc_pestle", {pos = pos, gain = 0.85, max_hear_distance = 20}, true)
            tc_elements.enrich_soil_at(floor_pos)
            matched = true
        end

        if matched then
            local spec = tc_elements.REAGENT_BY_NAME[iname]
            spawn_intercept_burst(pos, iname)
            core.sound_play("tc_geode_chime", {pos = pos, gain = 0.8, max_hear_distance = 24}, true)
            local gain = tc_core.add_scaled_bloom(2.2, floor_pos)
            tc_core.record_neutralization(puncher, 1)
            core.chat_send_player(
                puncher:get_player_name(),
                tc_assets.chat_prefix("Nice Catch!", P.gold) ..
                core.colorize(
                    P.text_primary,
                    string.format(
                        "Caught %s in mid-air! (+%.1f%% Bonus Bloom!)",
                        spec and spec.title or "Block",
                        gain
                    )
                )
            )
            self.object:remove()
            return true
        end

        tc_tools.send_hint(puncher, "midair_" .. iname, COUNTER_HINT_BY_ITEM[iname] or "Use the matching tool!")
        return true
    end,

    on_step = function(self, dtime, moveresult)
        if not tc_core.state.running or self.epoch ~= (tc_core.state.epoch or 0) then
            self.object:remove()
            return
        end
        self.age = self.age + dtime
        if self.age > 12.0 then
            self.object:remove()
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

            -- Step upward if landing space is already occupied by a solid reagent
            for _ = 1, 6 do
                local cname = core.get_node(land_pos).name
                if cname == "air" or cname == "tc_elements:steam"
                        or cname == "tc_elements:water_flowing" then
                    break
                end
                land_pos.y = land_pos.y + 1
            end

            if tc_world.is_protected_pos(land_pos, tc_core.state.level) then
                land_pos.x = land_pos.x + 2
                land_pos.z = land_pos.z + 2
            end

            local iname = self.item_name
            self.object:remove()

            if land_pos.y <= 9 then
                local cname = core.get_node(land_pos).name
                if cname == "air" or cname == "tc_elements:steam"
                        or cname == "tc_elements:water_flowing" then
                    core.set_node(land_pos, {name = iname})
                    local snd = (iname == "tc_elements:aether_geode") and "tc_geode_chime" or "tc_place_node_hard"
                    core.sound_play(snd, {pos = land_pos, gain = 0.85, max_hear_distance = 24}, true)
                    tc_core.try_react_at(land_pos)
                end
            end
        end
    end,
})
