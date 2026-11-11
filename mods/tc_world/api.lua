---@class CellInfo
---@field index integer Level/Cell index (1..N)
---@field gx integer Grid X coordinate
---@field gz integer Grid Z coordinate
---@field center {x: integer, y: integer, z: integer} Center sprout position
---@field min_x integer Interior minimum X
---@field max_x integer Interior maximum X
---@field min_z integer Interior minimum Z
---@field max_z integer Interior maximum Z

---@class TcWorldAPI
---@field CELL_SIZE integer Interior width/depth/height of each cubic terrarium chamber (11)
---@field WALL_HEIGHT integer Height of the glass walls + brass rim (11)
---@field ALTAR_POS {x: integer, y: integer, z: integer} Position of the Crucible Control Altar
---@field SPAWN_POS {x: number, y: number, z: number} Safe player spawn position inside Chamber 1
---@field is_ready boolean Whether initial map emerge & world construction has completed
---@field get_cell_grid_coords fun(cell_idx: integer): integer, integer
---@field get_cell_info fun(cell_idx: integer): CellInfo
---@field get_active_cells fun(level: integer): CellInfo[]
---@field get_max_built_level fun(): integer
---@field get_bounding_box fun(level: integer): {min_x: integer, max_x: integer, min_z: integer, max_z: integer}
---@field is_protected_pos fun(pos: {x: integer, y: integer, z: integer}, level: integer): boolean
---@field build_level fun(level?: integer, preserve_fertile?: boolean)
---@field emerge_initial_area fun(on_ready: fun())
---@field rebuild fun()
tc_world = {
    CELL_SIZE = 11,
    WALL_HEIGHT = 11,
    ALTAR_POS = {x = 0, y = 1, z = -4},
    SPAWN_POS = tc_init.SPAWN_POS,
    is_ready = false,
}

local HALF_CELL = 5 -- (11 - 1) / 2
local WORKSHOP_PAD = 12
local storage = core.get_mod_storage()
local max_built_level = math.max(1, storage:get_int("max_built_level"))
local data_buf = {}

-- Memoized deterministic spiral geometry caches (zero per-tick allocations)
local cell_info_cache = {}
local active_cells_cache = {}
local bbox_cache = {}

-- Cached Content IDs (static after node registration in tc_elements)
local c_sub     = core.get_content_id("tc_elements:substrate")
local c_loam    = core.get_content_id("tc_elements:loam")
local c_fertile = core.get_content_id("tc_elements:fertile_loam")
local c_glass   = core.get_content_id("tc_elements:flask_glass")
local c_rim     = core.get_content_id("tc_elements:flask_rim")
local c_desk    = core.get_content_id("tc_elements:desk_wood")
local c_parch   = core.get_content_id("tc_elements:parchment")
local c_wax     = core.get_content_id("tc_elements:candle_wax")
local c_wick    = core.get_content_id("tc_elements:candle_wick")
local c_sprout1 = core.get_content_id("tc_elements:crucible_sprout_1")
local c_altar   = core.get_content_id("tc_elements:altar_stone")

---Returns the highest level ever constructed in this world (persisted in mod_storage).
---@return integer
function tc_world.get_max_built_level()
    return max_built_level
end

---Computes 2D outward grid spiral coordinates (gx, gz) for a 1-based cell index.
---Cell 1 = (0,0), Cell 2 = (1,0), Cell 3 = (1,1), Cell 4 = (0,1), Cell 5 = (-1,1), etc.
---@param cell_idx integer 1-based index of the terrarium cube
---@return integer gx
---@return integer gz
function tc_world.get_cell_grid_coords(cell_idx)
    if cell_idx <= 1 then
        return 0, 0
    end

    local gx, gz = 0, 0
    local dx, dz = 1, 0
    local segment_length = 1
    local segment_passed = 0
    local turns = 0

    for _ = 2, cell_idx do
        gx = gx + dx
        gz = gz + dz
        segment_passed = segment_passed + 1
        if segment_passed == segment_length then
            segment_passed = 0
            local tmp = dx
            dx = -dz
            dz = tmp
            turns = turns + 1
            if turns % 2 == 0 then
                segment_length = segment_length + 1
            end
        end
    end

    return gx, gz
end

---Returns the cached geometric bounds and sprout center for a 1-based cell index on the spiral.
---@param cell_idx integer 1-based cell index
---@return CellInfo
function tc_world.get_cell_info(cell_idx)
    local idx = math.max(1, math.floor(cell_idx or 1))
    local cached = cell_info_cache[idx]
    if cached then
        return cached
    end
    local gx, gz = tc_world.get_cell_grid_coords(idx)
    local cx = gx * tc_world.CELL_SIZE
    local cz = gz * tc_world.CELL_SIZE
    cached = {
        index = idx,
        gx = gx,
        gz = gz,
        center = {x = cx, y = 1, z = cz},
        min_x = cx - HALF_CELL,
        max_x = cx + HALF_CELL,
        min_z = cz - HALF_CELL,
        max_z = cz + HALF_CELL,
    }
    cell_info_cache[idx] = cached
    return cached
end

---Returns a cached list of all active cubic chambers for the specified level.
---@param level integer Current game level (number of cubes & plants)
---@return CellInfo[]
function tc_world.get_active_cells(level)
    local count = math.max(1, math.floor(level or 1))
    local cached = active_cells_cache[count]
    if cached then
        return cached
    end
    local cells = {}
    for i = 1, count do
        cells[i] = tc_world.get_cell_info(i)
    end
    active_cells_cache[count] = cells
    return cells
end

---Returns the cached outer horizontal bounding box across all active cells for a given level.
---@param level integer Current game level
---@return {min_x: integer, max_x: integer, min_z: integer, max_z: integer}
function tc_world.get_bounding_box(level)
    local count = math.max(1, math.floor(level or 1))
    local cached = bbox_cache[count]
    if cached then
        return cached
    end
    local cells = tc_world.get_active_cells(count)
    local min_x, max_x = cells[1].min_x, cells[1].max_x
    local min_z, max_z = cells[1].min_z, cells[1].max_z

    for i = 2, #cells do
        local c = cells[i]
        if c.min_x < min_x then min_x = c.min_x end
        if c.max_x > max_x then max_x = c.max_x end
        if c.min_z < min_z then min_z = c.min_z end
        if c.max_z > max_z then max_z = c.max_z end
    end

    cached = {
        min_x = min_x,
        max_x = max_x,
        min_z = min_z,
        max_z = max_z,
    }
    bbox_cache[count] = cached
    return cached
end

---Checks whether a coordinate is reserved for a Crucible Sprout or the Control Altar.
---@param pos {x: integer, y: integer, z: integer}
---@param level integer
---@return boolean
function tc_world.is_protected_pos(pos, level)
    if pos.x == tc_world.ALTAR_POS.x and pos.z == tc_world.ALTAR_POS.z and pos.y >= 1 and pos.y <= 3 then
        return true
    end
    local cells = tc_world.get_active_cells(level)
    for i = 1, #cells do
        local c = cells[i].center
        if pos.x == c.x and pos.z == c.z and pos.y >= 1 and pos.y <= 3 then
            return true
        end
    end
    return false
end

local function stamp_candle(data, area, cx, cz, height)
    for y = 0, height - 1 do
        for z = cz - 1, cz + 1 do
            for x = cx - 1, cx + 1 do
                data[area:index(x, y, z)] = c_wax
            end
        end
    end
    data[area:index(cx, height, cz)] = c_wick
end

---Constructs or expands the open-top spiral cubic terrarium and surrounding Wizard's Workshop diorama.
---@param level? integer Level number (defaults to 1)
---@param preserve_fertile? boolean Whether to preserve existing fertile_loam floor tiles when expanding
function tc_world.build_level(level, preserve_fertile)
    level = math.max(1, math.floor(level or 1))
    local cells = tc_world.get_active_cells(level)
    if level > max_built_level then
        max_built_level = level
        storage:set_int("max_built_level", max_built_level)
    end

    local clear_bbox = tc_world.get_bounding_box(max_built_level)
    local active_bbox = tc_world.get_bounding_box(level)

    local minp = {
        x = clear_bbox.min_x - WORKSHOP_PAD,
        y = -3,
        z = clear_bbox.min_z - WORKSHOP_PAD,
    }
    local maxp = {
        x = clear_bbox.max_x + WORKSHOP_PAD,
        y = tc_world.WALL_HEIGHT + 6,
        z = clear_bbox.max_z + WORKSHOP_PAD,
    }

    local vm = core.get_voxel_manip(minp, maxp)
    local emin, emax = vm:read_from_map(minp, maxp)
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data(data_buf)
    local ystride = area.ystride

    if not preserve_fertile then
        for i = 1, #data do
            data[i] = core.CONTENT_AIR
        end
    end

    -- Track interior floor coordinates for O(1) lookup
    local interior_map = {}

    -- Stamp interior floor, substrate, workbench base, and clear chamber air
    for i = 1, #cells do
        local cell = cells[i]
        for z = cell.min_z, cell.max_z do
            for x = cell.min_x, cell.max_x do
                interior_map[(z + 2048) * 4096 + (x + 2048)] = true
                local vi = area:index(x, -3, z)
                data[vi] = c_desk
                vi = vi + ystride
                data[vi] = c_desk
                vi = vi + ystride
                data[vi] = c_sub
                vi = vi + ystride
                if not (preserve_fertile and data[vi] == c_fertile) then
                    data[vi] = c_loam
                end
                for _ = 1, maxp.y do
                    vi = vi + ystride
                    data[vi] = core.CONTENT_AIR
                end
            end
        end
    end

    -- Stamp Giant Mahogany Workbench surface around the terrarium & clear old outer walls/props
    local desk_min_x = active_bbox.min_x - WORKSHOP_PAD
    local desk_max_x = active_bbox.max_x + WORKSHOP_PAD
    local desk_min_z = active_bbox.min_z - WORKSHOP_PAD
    local desk_max_z = active_bbox.max_z + WORKSHOP_PAD

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            if not interior_map[(z + 2048) * 4096 + (x + 2048)] then
                local in_desk = (x >= desk_min_x and x <= desk_max_x and z >= desk_min_z and z <= desk_max_z)
                local vi = area:index(x, -3, z)
                data[vi] = in_desk and c_desk or core.CONTENT_AIR
                vi = vi + ystride
                data[vi] = in_desk and c_desk or core.CONTENT_AIR
                vi = vi + ystride
                data[vi] = in_desk and c_desk or core.CONTENT_AIR
                for _ = 0, maxp.y do
                    vi = vi + ystride
                    data[vi] = core.CONTENT_AIR
                end
            end
        end
    end

    -- Stamp Enchanted Crucible Glass walls + Brass Collar Rim along the top perimeter
    for i = 1, #cells do
        local cell = cells[i]
        for z = cell.min_z - 1, cell.max_z + 1 do
            for x = cell.min_x - 1, cell.max_x + 1 do
                if not interior_map[(z + 2048) * 4096 + (x + 2048)] then
                    local vi_y0 = area:index(x, 0, z)
                    data[vi_y0 - ystride] = c_sub
                    data[vi_y0] = c_sub
                    local vi = vi_y0
                    for _ = 1, tc_world.WALL_HEIGHT - 1 do
                        vi = vi + ystride
                        data[vi] = c_glass
                    end
                    vi = vi + ystride
                    data[vi] = c_rim
                end
            end
        end
    end

    -- Stamp Workshop Diorama Props outside the active terrarium perimeter:
    -- Giant Beeswax Candles casting warm light across the glass
    stamp_candle(data, area, active_bbox.max_x + 6, 0, 9)
    stamp_candle(data, area, active_bbox.min_x - 6, active_bbox.max_z + 5, 7)

    -- Open Wizard's Grimoire folio resting on the West workbench
    local book_cx = active_bbox.min_x - 7
    for z = -3, 3 do
        for x = book_cx - 3, book_cx + 3 do
            local arch = math.floor(math.abs(x - book_cx) * 0.55)
            data[area:index(x, arch, z)] = c_desk
            data[area:index(x, arch + 1, z)] = c_parch
        end
    end

    -- Place Crucible Sprout (Stage 1) at the center of each active cube
    for i = 1, #cells do
        local c = cells[i].center
        data[area:index(c.x, c.y, c.z)] = c_sprout1
    end

    -- Place Crucible Control Altar inside Chamber 1
    data[area:index(tc_world.ALTAR_POS.x, tc_world.ALTAR_POS.y, tc_world.ALTAR_POS.z)] = c_altar

    vm:set_data(data)
    vm:calc_lighting()
    vm:write_to_map(true)

    local sprout_title = tc_elements.SPROUT_STAGES[1].title
    for i = 1, #cells do
        local c = cells[i].center
        core.get_meta(c):set_string("infotext", tc_assets.format_infotext(
            string.format("Sprout #%d · %s", i, sprout_title),
            "Plant Health: 100% · Nearby Hazards: 0",
            "Right-Click to view Garden Status · Left-Click with Water Flask [3] to heal"
        ))
    end
    core.get_meta(tc_world.ALTAR_POS):set_string("infotext", tc_assets.format_infotext(
        "Control Altar",
        "Check Plant Health · Change Game Pace · Guidebook · Top 10 Scores",
        "Right-Click to open Garden Controls"
    ))

    tc_world.is_ready = true
end

---Emerges the active terrarium bounding box once on startup and invokes `on_ready`.
---@param on_ready fun()
function tc_world.emerge_initial_area(on_ready)
    local bbox = tc_world.get_bounding_box(tc_world.get_max_built_level())
    local minp = {x = bbox.min_x - 14, y = -4, z = bbox.min_z - 14}
    local maxp = {x = bbox.max_x + 14, y = tc_world.WALL_HEIGHT + 8, z = bbox.max_z + 14}

    core.emerge_area(minp, maxp, function(_, _, calls_remaining)
        if calls_remaining == 0 and not tc_world.is_ready then
            on_ready()
        end
    end)
end

---Rebuilds the world back to Level 1.
function tc_world.rebuild()
    tc_world.build_level(1, false)
end
