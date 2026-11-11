-- Builtin item entity physics and igniter burn-up behavior
local builtin_item = core.registered_entities["__builtin:item"]

if not builtin_item or type(builtin_item.set_item) ~= "function" or type(builtin_item.on_step) ~= "function" then
    core.log("warning", "Builtin item entity does not look as expected, skipping overrides.")
    return
end

local item_rng = PcgRandom(os.time() + 7919)

local item = {
    set_item = function(self, itemstring, ...)
        builtin_item.set_item(self, itemstring, ...)

        local stack = ItemStack(itemstring)
        local fl = core.get_item_group(stack:get_name(), "flammable")
        self.flammable = (fl > 0) and fl or nil
    end,

    burn_up = function(self)
        local p = self.object:get_pos()
        self.object:remove()
        if not p then
            return
        end
        core.sound_play("tc_item_smoke", {
            pos = p,
            gain = 1.0,
            max_hear_distance = 8,
        }, true)
        local minp = vector.offset(p, -0.1, -0.1, -0.1)
        local maxp = vector.offset(p, 0.1, 0.1, 0.1)
        local minv = {x = 0, y = 2.5, z = 0}
        local maxv = {x = 0, y = 2.5, z = 0}
        local mina = {x = -0.15, y = -0.02, z = -0.15}
        local maxa = {x = 0.15, y = -0.01, z = 0.15}
        core.add_particlespawner({
            amount = 3,
            time = 0.1,
            pos = {min = minp, max = maxp},
            vel = {min = minv, max = maxv},
            acc = {min = mina, max = maxa},
            exptime = {min = 4, max = 6},
            size = {min = 5, max = 5},
            collisiondetection = true,
            texpool = {
                {name = "tc_item_smoke.png", blend = "alpha", scale_tween = {5.0, 2.0}, alpha_tween = {0.9, 0.0}},
            },
            minpos = minp,
            maxpos = maxp,
            minvel = minv,
            maxvel = maxv,
            minacc = mina,
            maxacc = maxa,
            minexptime = 4,
            maxexptime = 6,
            minsize = 5,
            maxsize = 5,
            texture = "tc_item_smoke.png",
        })
    end,

    on_step = function(self, dtime, ...)
        builtin_item.on_step(self, dtime, ...)

        if self.flammable then
            self.ignite_timer = (self.ignite_timer or 0) + dtime
            if self.ignite_timer > 10 then
                self.ignite_timer = 0

                local pos = self.object:get_pos()
                if pos == nil then
                    return
                end
                local node = core.get_node_or_nil(pos)
                if not node then
                    return
                end

                if core.get_item_group(node.name, "lava") > 0 then
                    self:burn_up()
                else
                    local burn_chance = self.flammable * core.get_item_group(node.name, "igniter")
                    if burn_chance > 0 and item_rng:next(0, burn_chance) ~= 0 then
                        self:burn_up()
                    end
                end
            end
        end
    end,
}

setmetatable(item, {__index = builtin_item})
core.register_entity(":__builtin:item", item)
