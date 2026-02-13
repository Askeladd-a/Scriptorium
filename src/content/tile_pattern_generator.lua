
local Generator = {}

local DEFAULT_ROWS = 4
local DEFAULT_COLS = 5

local TILE_DIR = "resources/tiles"
local DEFAULT_TILE_IDS = {"1", "2", "3", "4", "5", "6", "O", "w"}

local VALUE_TO_COLOR = {
    [1] = "MARRONE",
    [2] = "VERDE",
    [3] = "NERO",
    [4] = "ROSSO",
    [5] = "BLU",
    [6] = "GIALLO",
}

local ELEMENT_META = {
    TEXT = {name = "Text"},
    DROPCAPS = {name = "Dropcaps"},
    BORDERS = {name = "Borders"},
    CORNERS = {name = "Corners"},
    MINIATURE = {name = "Miniature"},
}

Generator.SEED_MODE_SEEDED = "seeded"
Generator.SEED_MODE_RANDOM = "random"
Generator.seed_mode = Generator.SEED_MODE_SEEDED
Generator.enable_variations = true

local runtime_counter = 0
local cached_tile_ids = nil

local function clamp(v, min_v, max_v)
    if v < min_v then return min_v end
    if v > max_v then return max_v end
    return v
end

local function shallow_copy_array(arr)
    local out = {}
    for i = 1, #arr do
        out[i] = arr[i]
    end
    return out
end

local function make_rng(seed)
    local state = math.floor(tonumber(seed) or os.time()) % 2147483647
    if state <= 0 then
        state = 1357911
    end

    local function next_raw()
        state = (state * 48271) % 2147483647
        return state
    end

    local function next_float()
        return next_raw() / 2147483647
    end

    local function next_int(min_v, max_v)
        local min_n = math.floor(min_v)
        local max_n = math.floor(max_v)
        if max_n <= min_n then
            return min_n
        end
        local span = max_n - min_n + 1
        return min_n + (next_raw() % span)
    end

    return {
        float = next_float,
        int = next_int,
    }
end

local function is_png(name)
    return type(name) == "string" and name:sub(-4):lower() == ".png"
end

local function basename_without_extension(name)
    if type(name) ~= "string" then
        return nil
    end
    return name:gsub("%.[^%.]+$", "")
end

local function unique_sorted(ids)
    local seen = {}
    local out = {}
    for _, id in ipairs(ids) do
        if id and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end

    table.sort(out, function(a, b)
        local na = tonumber(a)
        local nb = tonumber(b)
        if na and nb then return na < nb end
        if na then return true end
        if nb then return false end
        return tostring(a) < tostring(b)
    end)
    return out
end

local function discover_tiles_from_folder()
    local ids = {}
    if love and love.filesystem and love.filesystem.getDirectoryItems then
        local ok, items = pcall(function()
            return love.filesystem.getDirectoryItems(TILE_DIR)
        end)
        if ok and type(items) == "table" then
            for _, name in ipairs(items) do
                if is_png(name) then
                    local id = basename_without_extension(name)
                    if id then
                        ids[#ids + 1] = id
                    end
                end
            end
        end
    end

    if #ids == 0 then
        ids = shallow_copy_array(DEFAULT_TILE_IDS)
    end

    return unique_sorted(ids)
end

local function has_tile(tile_lookup, id)
    return tile_lookup and tile_lookup[id] == true
end

local function resolve_seed(seed, mode)
    local requested_mode = mode or Generator.seed_mode
    local seeded = requested_mode ~= Generator.SEED_MODE_RANDOM
    if seeded then
        return math.floor(tonumber(seed) or os.time()), true
    end

    runtime_counter = runtime_counter + 1
    local timer_part = 0
    if love and love.timer and love.timer.getTime then
        timer_part = math.floor(love.timer.getTime() * 1000000)
    end
    local extra = math.random(1, 999999)
    return os.time() + timer_part + extra + runtime_counter * 8191, false
end

local function build_tile_profile(tile_ids)
    local lookup = {}
    local numeric = {}
    for _, id in ipairs(tile_ids) do
        lookup[id] = true
        local n = tonumber(id)
        if n and n >= 1 and n <= 6 then
            numeric[#numeric + 1] = id
        end
    end

    table.sort(numeric, function(a, b)
        return tonumber(a) < tonumber(b)
    end)

    if #numeric == 0 then
        numeric = {"1", "2", "3", "4", "5", "6"}
        for _, id in ipairs(numeric) do
            lookup[id] = true
        end
    end

    local blank = has_tile(lookup, "w") and "w" or numeric[1]
    local marker = has_tile(lookup, "O") and "O" or nil

    return {
        lookup = lookup,
        numeric = numeric,
        blank = blank,
        marker = marker,
    }
end

local function pick_unique_indices(rng, total, count)
    local pool = {}
    for i = 1, total do
        pool[i] = i
    end
    local out = {}
    local limit = clamp(math.floor(count), 0, total)
    for _ = 1, limit do
        local at = rng.int(1, #pool)
        out[#out + 1] = pool[at]
        table.remove(pool, at)
    end
    return out
end

local function pick_constraint_for_numeric_id(id, rng)
    local n = tonumber(id) or 1
    n = clamp(math.floor(n), 1, 6)
    if rng.float() < 0.55 then
        return n
    end
    return VALUE_TO_COLOR[n]
end

local function rotate_rows(grid, rows, cols, shift)
    if shift == 0 then
        return grid
    end
    local out = {}
    for row = 1, rows do
        for col = 1, cols do
            local src_col = ((col - 1 - shift) % cols) + 1
            local dst = (row - 1) * cols + col
            local src = (row - 1) * cols + src_col
            out[dst] = grid[src]
        end
    end
    return out
end

local function rotate_columns(grid, rows, cols, shift)
    if shift == 0 then
        return grid
    end
    local out = {}
    for row = 1, rows do
        for col = 1, cols do
            local src_row = ((row - 1 - shift) % rows) + 1
            local dst = (row - 1) * cols + col
            local src = (src_row - 1) * cols + col
            out[dst] = grid[src]
        end
    end
    return out
end

local function maybe_apply_variations(grid, rows, cols, rng, enabled)
    if not enabled then
        return grid
    end
    local out = shallow_copy_array(grid)
    if rng.float() < 0.5 then
        out = rotate_rows(out, rows, cols, rng.int(1, cols - 1))
    end
    if rng.float() < 0.4 then
        out = rotate_columns(out, rows, cols, rng.int(1, rows - 1))
    end
    return out
end

local function build_pattern_grid(rows, cols, rng, profile, options)
    local total = rows * cols
    local grid = {}
    local tile_keys = {}

    for i = 1, total do
        grid[i] = nil
        tile_keys[i] = profile.blank
    end

    local density = tonumber(options.constraint_density)
    if not density then
        density = 0.20 + rng.float() * 0.22
    end
    density = clamp(density, 0.08, 0.55)
    local constraint_count = clamp(math.floor(total * density + 0.5), 3, total - 1)

    local selected = pick_unique_indices(rng, total, constraint_count)
    for _, index in ipairs(selected) do
        local numeric_id = profile.numeric[rng.int(1, #profile.numeric)]
        tile_keys[index] = numeric_id
        grid[index] = pick_constraint_for_numeric_id(numeric_id, rng)
    end

    local markers = {}
    if profile.marker and #selected > 0 then
        local marker_count = tonumber(options.marker_count) or rng.int(3, 6)
        marker_count = clamp(marker_count, 1, #selected)
        local marker_indices = pick_unique_indices(rng, #selected, marker_count)
        for _, marker_pick in ipairs(marker_indices) do
            local grid_index = selected[marker_pick]
            markers[grid_index] = profile.marker
        end
    end

    return grid, tile_keys, markers, constraint_count
end

function Generator.listTileIds(force_refresh)
    if not force_refresh and cached_tile_ids then
        return shallow_copy_array(cached_tile_ids)
    end
    cached_tile_ids = discover_tiles_from_folder()
    return shallow_copy_array(cached_tile_ids)
end

function Generator.setSeedMode(mode)
    if mode == Generator.SEED_MODE_RANDOM or mode == Generator.SEED_MODE_SEEDED then
        Generator.seed_mode = mode
    end
end

---@param element string
---@param seed number|nil
---@param options table|nil
---@return table
function Generator.generatePattern(element, seed, options)
    options = options or {}
    local mode = options.seed_mode or Generator.seed_mode
    local resolved_seed, seeded = resolve_seed(seed, mode)
    local rng = make_rng(resolved_seed)

    local rows = math.max(1, math.floor(options.rows or DEFAULT_ROWS))
    local cols = math.max(1, math.floor(options.cols or DEFAULT_COLS))
    local tile_ids = Generator.listTileIds(false)
    local profile = build_tile_profile(tile_ids)

    local grid, tile_keys, tile_markers, constraint_count = build_pattern_grid(rows, cols, rng, profile, options)
    grid = maybe_apply_variations(
        grid,
        rows,
        cols,
        rng,
        (options.variations ~= nil) and options.variations or Generator.enable_variations
    )

    local meta = ELEMENT_META[element] or {name = tostring(element)}
    local total = rows * cols
    local difficulty = clamp(2 + math.floor((constraint_count / total) * 6 + 0.5), 2, 7)
    local id = tonumber(options.id) or (1000 + rng.int(1, 8999))

    return {
        id = id,
        source_id = id,
        element = element,
        name = string.format("%s Tile Matrix", meta.name),
        difficulty = difficulty,
        rows = rows,
        cols = cols,
        grid = grid,
        tile_keys = tile_keys,
        tile_markers = tile_markers,
        generated = true,
        seeded = seeded,
        seed = resolved_seed,
    }
end

---@param seed number|nil
---@param elements string[]|nil
---@param options table|nil
---@return table
function Generator.generateSet(seed, elements, options)
    options = options or {}
    local mode = options.seed_mode or Generator.seed_mode
    local base_seed = resolve_seed(seed, mode)

    local target_elements = elements or {"TEXT", "DROPCAPS", "BORDERS", "CORNERS", "MINIATURE"}
    local out = {}
    for i, element in ipairs(target_elements) do
        local per_element = (type(options.element_options) == "table" and options.element_options[element]) or {}
        out[element] = Generator.generatePattern(element, base_seed + i * 997, {
            rows = per_element.rows or options.rows or DEFAULT_ROWS,
            cols = per_element.cols or options.cols or DEFAULT_COLS,
            seed_mode = mode,
            variations = (options.variations ~= nil) and options.variations or Generator.enable_variations,
            marker_count = per_element.marker_count or options.marker_count,
            constraint_density = per_element.constraint_density or options.constraint_density,
            id = 1000 + i,
        })
    end

    return out
end

Generator.DEFAULT_ROWS = DEFAULT_ROWS
Generator.DEFAULT_COLS = DEFAULT_COLS
Generator.TILE_DIR = TILE_DIR
Generator.VALUE_TO_COLOR = VALUE_TO_COLOR

return Generator
