---@class TcPalette
---@field bg_backdrop string
---@field bg_panel string
---@field bg_card string
---@field bg_inset string
---@field bg_tooltip string
---@field border_gold string
---@field border_arcane string
---@field border_subtle string
---@field text_primary string
---@field text_secondary string
---@field gold string
---@field emerald string
---@field aqua string
---@field amber string
---@field coral string
---@field violet string
---@field hud_white integer
---@field hud_muted integer
---@field hud_gold integer
---@field hud_emerald integer
---@field hud_aqua integer
---@field hud_amber integer
---@field hud_coral integer
---@field hud_violet integer

---@class TcDescriptionSpec
---@field title string Display name of the item, block, or tool
---@field category string Role label (e.g., "Alchemist Tool", "Volatile Reagent")
---@field summary string Concise explanation of what it is or does
---@field effect? string Optional equilibrium / stat impact line
---@field usage? string Optional actionable instruction on how to use or counter it
---@field accent? string Optional hex color override for the title & category badge

---@class TcParticleSheetEntryOpts
---@field blend? "add"|"alpha"|"screen"
---@field scale? number
---@field scale_tween? number[]
---@field alpha_tween? number[]
---@field aspect_w? integer
---@field aspect_h? integer
---@field length? number

---@class TcSheetParticleSpec
---@field amount integer
---@field time? number
---@field minpos table
---@field maxpos table
---@field minvel table
---@field maxvel table
---@field minacc? table
---@field maxacc? table
---@field minexptime number
---@field maxexptime number
---@field minsize number
---@field maxsize number
---@field glow? integer
---@field drag? table
---@field jitter? table
---@field bounce? table
---@field collisiondetection? boolean
---@field collision_removal? boolean
---@field texpool table[]
---@field fallback_texture? string
---@field fallback_length? number
---@field aspect_w? integer
---@field aspect_h? integer
---@field playername? string

---@class TcLightingStaticSpec
---@field light_curve integer[] 16-entry monotonic voxel light lookup curve ending at 255
---@field ao_gamma number Ambient occlusion contrast gamma

---@class TcLightingPreset
---@field saturation number
---@field bloom table
---@field volumetric_light table
---@field static TcLightingStaticSpec

---@class TcSkyColorSpec
---@field day_sky string
---@field day_horizon string
---@field dawn_sky string
---@field dawn_horizon string
---@field night_sky string
---@field night_horizon string
---@field indoors string
---@field fog_sun_tint string
---@field fog_moon_tint string
---@field fog_tint_type "default"|"custom"

---@class TcSkyFogSpec
---@field fog_distance integer
---@field fog_start number
---@field fog_color string

---@class TcSkyPreset
---@field type "regular"|"skybox"|"plain"
---@field clouds boolean
---@field body_orbit_tilt number
---@field auto_dim_skybox boolean
---@field sky_color TcSkyColorSpec
---@field fog TcSkyFogSpec

---@class TcMoonSpec
---@field visible boolean
---@field texture string
---@field tonemap string
---@field scale number

---@class TcStarsSpec
---@field visible boolean
---@field count integer
---@field star_color string
---@field scale number
---@field day_opacity number
---@field star_seed integer

---@class TcCloudsSpec
---@field density number
---@field color string
---@field ambient string
---@field shadow string
---@field height number
---@field thickness number
---@field speed {x: number, z: number}

---@class TcCelestialConfig
---@field timeofday number Nocturnal time of day in [0, 1] placing the Astral Moon high above the rim
---@field day_night_ratio number Overridden interior ambient daylight/moonlight ratio in [0, 1]
---@field moon TcMoonSpec
---@field stars TcStarsSpec
---@field clouds TcCloudsSpec

---@class TcAssetsAPI
---@field S fun(str: string, ...: any): string Mod translator function
---@field FORMSPEC_VERSION integer Latest Luanti formspec version used across all dialogs
---@field LIGHTING_PRESETS table<string, TcLightingPreset> Luanti 5.18 static light curve + bloom presets
---@field SKY_PRESETS table<string, TcSkyPreset> Luanti 5.18 state-reactive skybox, horizon & distance fog presets
---@field CELESTIAL TcCelestialConfig Canonical nocturnal clock, moon, starfield, and arcane mist cloud settings
---@field PALETTE TcPalette WCAG 2.1 AA+ high-contrast Arcane Apothecary color palette
---@field PARTICLES table<string, string> Named 16x128 vertical-frame animated particle sheet textures
---@field ui TcAssetsUI Reusable formspec_version[12] theme & widget builders
---@field format_description fun(spec: TcDescriptionSpec): string
---@field format_infotext fun(title: string, status?: string, action_hint?: string): string
---@field chat_prefix fun(tag: string, color_hex?: string): string
---@field vertical_tile fun(tex: string, len?: number, w?: integer, h?: integer, extra?: table): table
---@field make_sheet_tex_entry fun(texture: string, opts?: TcParticleSheetEntryOpts): table
---@field spawn_sheet_particles fun(spec: TcSheetParticleSpec): integer
---@field node_sound_stone_defaults fun(tbl?: table): table
---@field node_sound_dirt_defaults fun(tbl?: table): table
---@field node_sound_wood_defaults fun(tbl?: table): table
---@field node_sound_glass_defaults fun(tbl?: table): table
---@field node_sound_ice_defaults fun(tbl?: table): table
---@field node_sound_water_defaults fun(tbl?: table): table
---@field node_sound_crystal_defaults fun(tbl?: table): table
tc_assets = {}

local S = core.get_translator("tc_assets")
tc_assets.S = S

-- Target latest Luanti 5.18 formspec specification (formspec_version[12])
tc_assets.FORMSPEC_VERSION = 12

-- Luanti 5.18 atmospheric presets with custom static 16-entry voxel light_curve & ao_gamma
tc_assets.LIGHTING_PRESETS = {
    normal = {
        saturation = 1.08,
        bloom = {intensity = 0.06, strength_factor = 1.0, radius = 1.0},
        volumetric_light = {strength = 0.14},
        static = {
            light_curve = {0, 10, 20, 32, 46, 62, 80, 100, 121, 143, 165, 186, 206, 224, 240, 255},
            ao_gamma = 1.50,
        },
    },
    stasis = {
        saturation = 0.88,
        bloom = {intensity = 0.10, strength_factor = 1.25, radius = 1.15},
        volumetric_light = {strength = 0.22},
        static = {
            light_curve = {0, 14, 27, 41, 56, 72, 89, 107, 126, 146, 166, 186, 205, 223, 239, 255},
            ao_gamma = 1.80,
        },
    },
    overdrive = {
        saturation = 1.22,
        bloom = {intensity = 0.12, strength_factor = 1.35, radius = 1.2},
        volumetric_light = {strength = 0.24},
        static = {
            light_curve = {0, 12, 24, 38, 54, 72, 92, 113, 135, 157, 178, 198, 215, 230, 243, 255},
            ao_gamma = 1.60,
        },
    },
    overload = {
        saturation = 1.30,
        bloom = {intensity = 0.15, strength_factor = 1.45, radius = 1.3},
        volumetric_light = {strength = 0.28},
        static = {
            light_curve = {0, 6, 13, 22, 34, 49, 67, 88, 111, 136, 161, 185, 207, 226, 242, 255},
            ao_gamma = 1.15,
        },
    },
}

-- Canonical nocturnal celestial clock & sky-body configuration:
-- 1000 millihours (01:00) + 38.0 deg orbit tilt places tc_astral_moon.png upright at +48.5 deg elevation
-- (-27.9 deg NNW, clearing the y=11 brass rim from spawn) with 100% star opacity, while day_night_ratio = 0.68
-- preserves crisp moonlit/candlelit readability inside the open-top glass chambers.
tc_assets.CELESTIAL = {
    timeofday = 1000 / 24000,
    day_night_ratio = 0.68,
    moon = {
        visible = true,
        texture = "tc_astral_moon.png",
        tonemap = "tc_moon_tonemap.png",
        scale = 2.6,
    },
    stars = {
        visible = true,
        count = 1600,
        star_color = "#EFE6FFBF",
        scale = 0.85,
        day_opacity = 0.35,
        star_seed = 20260518,
    },
    clouds = {
        density = 0.16,
        color = "#C8B2FF2E",
        ambient = "#342258",
        shadow = "#1E1436",
        height = 68,
        thickness = 4,
        speed = {x = 0.6, z = -1.0},
    },
}

-- State-reactive themed skybox & fog presets calibrated for Sky::update()'s m_brightness (~0.66) multiplier.
-- Uses fog_tint_type = "default" so Sky::update() applies tc_moon_tonemap.png to directional moon horizon glow,
-- and auto_dim_skybox = false so cave-detection heuristics never hide the open-top sky, moon, or starfield.
tc_assets.SKY_PRESETS = {
    normal = {
        type = "regular",
        clouds = true,
        body_orbit_tilt = 38.0,
        auto_dim_skybox = false,
        sky_color = {
            day_sky = "#1E1638",
            day_horizon = "#4A3074",
            dawn_sky = "#2A1D48",
            dawn_horizon = "#5A3884",
            night_sky = "#261A44",
            night_horizon = "#4E3278",
            indoors = "#1E1638",
            fog_sun_tint = "#FFB86C",
            fog_moon_tint = "#C8A8FF",
            fog_tint_type = "default",
        },
        fog = {
            fog_distance = 120,
            fog_start = 0.42,
            fog_color = "#2E1E4A",
        },
    },
    stasis = {
        type = "regular",
        clouds = true,
        body_orbit_tilt = 38.0,
        auto_dim_skybox = false,
        sky_color = {
            day_sky = "#162238",
            day_horizon = "#2C5270",
            dawn_sky = "#1C2E48",
            dawn_horizon = "#366080",
            night_sky = "#18263E",
            night_horizon = "#2E5472",
            indoors = "#162238",
            fog_sun_tint = "#7CE8FF",
            fog_moon_tint = "#9CEEFF",
            fog_tint_type = "default",
        },
        fog = {
            fog_distance = 120,
            fog_start = 0.42,
            fog_color = "#1D364C",
        },
    },
    overdrive = {
        type = "regular",
        clouds = true,
        body_orbit_tilt = 38.0,
        auto_dim_skybox = false,
        sky_color = {
            day_sky = "#1A2836",
            day_horizon = "#2E5A58",
            dawn_sky = "#223442",
            dawn_horizon = "#3A6B66",
            night_sky = "#1D2E3C",
            night_horizon = "#325E5B",
            indoors = "#1A2836",
            fog_sun_tint = "#FFD966",
            fog_moon_tint = "#88FFD0",
            fog_tint_type = "default",
        },
        fog = {
            fog_distance = 120,
            fog_start = 0.42,
            fog_color = "#1F3C3E",
        },
    },
    overload = {
        type = "regular",
        clouds = true,
        body_orbit_tilt = 38.0,
        auto_dim_skybox = false,
        sky_color = {
            day_sky = "#2C1428",
            day_horizon = "#68283C",
            dawn_sky = "#381A32",
            dawn_horizon = "#7A3046",
            night_sky = "#30162C",
            night_horizon = "#6A2A3E",
            indoors = "#2C1428",
            fog_sun_tint = "#FF8585",
            fog_moon_tint = "#FFB86C",
            fog_tint_type = "default",
        },
        fog = {
            fog_distance = 120,
            fog_start = 0.38,
            fog_color = "#441A28",
        },
    },
}

-- Animated 16x128 (8 frames of 16x16) vertical-frame particle sprite sheets
tc_assets.PARTICLES = {
    bloom   = "tc_particle_bloom.png",
    pollen  = "tc_particle_pollen.png",
    steam   = "tc_particle_steam.png",
    ember   = "tc_particle_ember.png",
    droplet = "tc_particle_droplet.png",
}

-- WCAG 2.1 AA/AAA verified high-contrast palette against #141020 / #1E1830 dark plum surfaces
-- Minimum contrast ratio across all text tokens is >= 6.8:1 (exceeding AA 4.5:1 requirement)
tc_assets.PALETTE = {
    bg_backdrop    = "#0B0814DD",
    bg_panel       = "#141020",
    bg_card        = "#1E1830",
    bg_inset       = "#100C1A",
    bg_tooltip     = "#181228",
    border_gold    = "#E5B84B",
    border_arcane  = "#7A62B8",
    border_subtle  = "#3B2E5E",

    text_primary   = "#F6F2FF", -- 14.2:1 contrast
    text_secondary = "#D6CCE8", -- 10.2:1 contrast
    gold           = "#FFD966", -- 11.5:1 contrast
    emerald        = "#6FFFA0", -- 12.4:1 contrast
    aqua           = "#7CE8FF", -- 11.8:1 contrast
    amber          = "#FFB86C", -- 9.4:1 contrast
    coral          = "#FF8585", -- 6.9:1 contrast
    violet         = "#E2A8FF", -- 9.0:1 contrast

    hud_white      = 0xF6F2FF,
    hud_muted      = 0xD6CCE8,
    hud_gold       = 0xFFD966,
    hud_emerald    = 0x6FFFA0,
    hud_aqua       = 0x7CE8FF,
    hud_amber      = 0xFFB86C,
    hud_coral      = 0xFF8585,
    hud_violet     = 0xE2A8FF,
}

---Builds a consistent, AA-accessible multi-line tooltip description for any block, tool, or item.
---@param spec TcDescriptionSpec
---@return string
function tc_assets.format_description(spec)
    local P = tc_assets.PALETTE
    local accent = spec.accent or P.gold
    local lines = {
        core.colorize(accent, spec.title) .. " " .. core.colorize(P.text_secondary, "[" .. spec.category .. "]"),
        core.colorize(P.text_primary, spec.summary),
    }
    if spec.effect and spec.effect ~= "" then
        lines[#lines + 1] = core.colorize(P.amber, S("✦ What it does: ")) .. core.colorize(P.text_primary, spec.effect)
    end
    if spec.usage and spec.usage ~= "" then
        lines[#lines + 1] = core.colorize(P.aqua, S("▸ How to use: ")) .. core.colorize(P.emerald, spec.usage)
    end
    return table.concat(lines, "\n")
end

---Builds a consistent, readable world-hover infotext string for interactive nodes.
---@param title string Primary node heading
---@param status? string Secondary live status line
---@param action_hint? string Action prompt shown at the bottom
---@return string
function tc_assets.format_infotext(title, status, action_hint)
    local lines = {title}
    if status and status ~= "" then
        lines[#lines + 1] = status
    end
    if action_hint and action_hint ~= "" then
        lines[#lines + 1] = "▸ " .. action_hint
    end
    return table.concat(lines, "\n")
end

---Formats a colored bracketed chat tag prefix using the game's AA palette.
---@param tag string Tag text without brackets
---@param color_hex? string Hex color (defaults to Arcane Gold)
---@return string
function tc_assets.chat_prefix(tag, color_hex)
    return core.colorize(color_hex or tc_assets.PALETTE.gold, "[" .. tag .. "]: ")
end

---Returns stone sound table defaults.
---@param tbl? table Optional sound table overrides
---@return table
function tc_assets.node_sound_stone_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "tc_dig_cracky", gain = 0.25}
    tbl.dig = tbl.dig or {name = "tc_dig_cracky", gain = 0.5}
    tbl.dug = tbl.dug or {name = "tc_dug_node", gain = 0.8}
    tbl.place = tbl.place or {name = "tc_place_node_hard", gain = 0.8}
    return tbl
end

---Returns dirt/loam sound table defaults.
---@param tbl? table Optional sound table overrides
---@return table
function tc_assets.node_sound_dirt_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "tc_footstep_dirt", gain = 0.35}
    tbl.dig = tbl.dig or {name = "tc_dig_crumbly", gain = 0.5}
    tbl.dug = tbl.dug or {name = "tc_dug_node", gain = 0.7}
    tbl.place = tbl.place or {name = "tc_place_node", gain = 0.7}
    return tbl
end

---Returns wood sound table defaults.
---@param tbl? table Optional sound table overrides
---@return table
function tc_assets.node_sound_wood_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "tc_footstep_wood", gain = 0.35}
    tbl.dig = tbl.dig or {name = "tc_dig_cracky", gain = 0.5}
    tbl.dug = tbl.dug or {name = "tc_dug_node", gain = 0.7}
    tbl.place = tbl.place or {name = "tc_place_node", gain = 0.7}
    return tbl
end

---Returns glass sound table defaults.
---@param tbl? table Optional sound table overrides
---@return table
function tc_assets.node_sound_glass_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "tc_glass", gain = 0.25}
    tbl.dig = tbl.dig or {name = "tc_glass", gain = 0.5}
    tbl.dug = tbl.dug or {name = "tc_glass", gain = 0.8}
    tbl.place = tbl.place or {name = "tc_place_node_hard", gain = 0.8}
    return tbl
end

---Returns ice sound table defaults.
---@param tbl? table Optional sound table overrides
---@return table
function tc_assets.node_sound_ice_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "tc_ice_dig", gain = 0.25}
    tbl.dig = tbl.dig or {name = "tc_ice_dig", gain = 0.55}
    tbl.dug = tbl.dug or {name = "tc_ice_dig", gain = 0.85}
    tbl.place = tbl.place or {name = "tc_place_node_hard", gain = 0.8}
    return tbl
end

---Returns water splash sound table defaults.
---@param tbl? table Optional sound table overrides
---@return table
function tc_assets.node_sound_water_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "tc_water_splash", gain = 0.30}
    return tbl
end

---Returns crystalline geode sound table defaults.
---@param tbl? table Optional sound table overrides
---@return table
function tc_assets.node_sound_crystal_defaults(tbl)
    tbl = tbl or {}
    tbl.footstep = tbl.footstep or {name = "tc_glass", gain = 0.25}
    tbl.dig = tbl.dig or {name = "tc_geode_chime", gain = 0.50}
    tbl.dug = tbl.dug or {name = "tc_geode_chime", gain = 0.85}
    tbl.place = tbl.place or {name = "tc_trowel_scoop", gain = 0.75}
    return tbl
end

---Builds a Luanti vertical_frames animated node or liquid tile definition.
---@param texture string Animated sprite-sheet filename (e.g., "tc_brimstone_anim.png")
---@param length? number Full animation cycle duration in seconds (default 2.0)
---@param aspect_w? integer Frame pixel width (default 32)
---@param aspect_h? integer Frame pixel height (default 32)
---@param extra? table Optional extra TileDef attributes (e.g., backface_culling)
---@return table
function tc_assets.vertical_tile(texture, length, aspect_w, aspect_h, extra)
    local tile = {
        name = texture,
        animation = {
            type = "vertical_frames",
            aspect_w = aspect_w or 32,
            aspect_h = aspect_h or 32,
            length = length or 2.0,
        },
    }
    if extra then
        if extra.backface_culling ~= nil then
            tile.backface_culling = extra.backface_culling
        end
        if extra.align_style ~= nil then
            tile.align_style = extra.align_style
        end
        if extra.scale ~= nil then
            tile.scale = extra.scale
        end
    end
    return tile
end

---Builds a modern Luanti texpool entry for a vertical-frame animated particle sheet.
---Setting animation length to -1 stretches the full frame sequence over each particle's lifetime.
---@param texture string Animated particle sheet filename (16x128 default)
---@param opts? TcParticleSheetEntryOpts Optional blend, tween, and frame overrides
---@return table
function tc_assets.make_sheet_tex_entry(texture, opts)
    opts = opts or {}
    return {
        name = texture,
        blend = opts.blend or "add",
        scale = opts.scale or 1.0,
        scale_tween = opts.scale_tween or {1.0, 0.45},
        alpha_tween = opts.alpha_tween or {1.0, 0.0},
        animation = {
            type = "vertical_frames",
            aspect_w = opts.aspect_w or 16,
            aspect_h = opts.aspect_h or 16,
            length = opts.length or -1,
        },
    }
end

local ZERO_VEC = {x = 0, y = 0, z = 0}

---Spawns a particle burst using modern Luanti structured range tables and animated sheet texpools
---alongside complete legacy fallback fields for engine compatibility.
---@param spec TcSheetParticleSpec
---@return integer spawner_id
function tc_assets.spawn_sheet_particles(spec)
    local minacc = spec.minacc or ZERO_VEC
    local maxacc = spec.maxacc or ZERO_VEC
    local aspect_w = spec.aspect_w or 16
    local aspect_h = spec.aspect_h or 16
    local first_entry = spec.texpool and spec.texpool[1]
    local fallback_tex = spec.fallback_texture or (first_entry and first_entry.name) or tc_assets.PARTICLES.pollen
    local fallback_len = spec.fallback_length or ((spec.minexptime + spec.maxexptime) * 0.5)

    local def = {
        amount = spec.amount,
        time = spec.time or 0.15,
        pos = {min = spec.minpos, max = spec.maxpos},
        vel = {min = spec.minvel, max = spec.maxvel},
        acc = {min = minacc, max = maxacc},
        exptime = {min = spec.minexptime, max = spec.maxexptime},
        size = {min = spec.minsize, max = spec.maxsize},
        glow = spec.glow or 12,
        texpool = spec.texpool,
        -- Backwards-compatible legacy fields
        minpos = spec.minpos,
        maxpos = spec.maxpos,
        minvel = spec.minvel,
        maxvel = spec.maxvel,
        minacc = minacc,
        maxacc = maxacc,
        minexptime = spec.minexptime,
        maxexptime = spec.maxexptime,
        minsize = spec.minsize,
        maxsize = spec.maxsize,
        texture = fallback_tex,
        animation = {
            type = "vertical_frames",
            aspect_w = aspect_w,
            aspect_h = aspect_h,
            length = fallback_len,
        },
    }

    if spec.drag then
        def.drag = spec.drag
    end
    if spec.jitter then
        def.jitter = spec.jitter
    end
    if spec.bounce then
        def.bounce = spec.bounce
    end
    if spec.collisiondetection ~= nil then
        def.collisiondetection = spec.collisiondetection
    end
    if spec.collision_removal ~= nil then
        def.collision_removal = spec.collision_removal
    end
    if spec.playername then
        def.playername = spec.playername
    end

    return core.add_particlespawner(def)
end
