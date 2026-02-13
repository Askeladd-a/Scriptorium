local Json = require("src.core.json")

local WindowPatterns = {}

local WINDOWS_JSON_PATH = "resources/tiles/Windows.json"
local GRID_ROWS = 4
local GRID_COLS = 5

local COLOR_MAP = {
    RED = "ROSSO",
    BLUE = "BLU",
    GREEN = "VERDE",
    YELLOW = "GIALLO",
    PURPLE = "VIOLA",
    BROWN = "MARRONE",
    BLACK = "NERO",
    WHITE = "BIANCO",
}

local COMMON_COLORS = {
    "BLU",
    "VERDE",
    "ROSSO",
    "GIALLO",
    "MARRONE",
    "NERO",
    "VIOLA",
    "BIANCO",
}

local cached_patterns = nil

local function read_file(path)
    if love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(path) then
        local ok, content = pcall(function()
            return love.filesystem.read(path)
        end)
        if ok and type(content) == "string" then
            return content
        end
    end

    local file = io.open(path, "rb")
    if not file then
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

local function normalize_constraint(raw)
    if raw == nil then
        return nil
    end
    local numeric = tonumber(raw)
    if numeric then
        numeric = math.floor(numeric)
        if numeric >= 1 and numeric <= 6 then
            return numeric
        end
        return nil
    end
    if type(raw) ~= "string" then
        return nil
    end
    local key = raw:upper()
    return COLOR_MAP[key] or key
end

local function empty_grid(rows, cols)
    local grid = {}
    for i = 1, rows * cols do
        grid[i] = nil
    end
    return grid
end

local function copy_array_with_size(values, size)
    local out = {}
    local count = math.max(0, math.floor(tonumber(size) or #values))
    for i = 1, count do
        out[i] = values[i]
    end
    return out
end

local function deep_copy_pattern(src)
    if not src then
        return nil
    end
    return {
        id = src.id,
        name = src.name,
        token = src.token,
        source_card_id = src.source_card_id,
        rows = src.rows,
        cols = src.cols,
        grid = copy_array_with_size(src.grid, (src.rows or GRID_ROWS) * (src.cols or GRID_COLS)),
        tile_keys = src.tile_keys and copy_array_with_size(src.tile_keys, (src.rows or GRID_ROWS) * (src.cols or GRID_COLS)) or nil,
        tile_markers = src.tile_markers and copy_array_with_size(src.tile_markers, (src.rows or GRID_ROWS) * (src.cols or GRID_COLS)) or nil,
    }
end

local function get_fallback_pattern()
    local grid = empty_grid(GRID_ROWS, GRID_COLS)
    return {
        id = "fallback_window",
        name = "Fallback Window",
        token = 0,
        source_card_id = -1,
        rows = GRID_ROWS,
        cols = GRID_COLS,
        grid = grid,
        tile_keys = nil,
        tile_markers = nil,
    }
end

local function parse_windows(decoded)
    if type(decoded) ~= "table" then
        return {}
    end

    local out = {}
    for _, card in ipairs(decoded) do
        local card_id = card and card.card_id or nil
        local windows = card and card.windows or nil
        if type(windows) == "table" then
            for _, window in ipairs(windows) do
                local grid = empty_grid(GRID_ROWS, GRID_COLS)
                local panes = window and (window.panes or window.cells) or nil
                if type(panes) == "table" then
                    for _, pane in ipairs(panes) do
                        local x = tonumber(pane and pane.x)
                        local y = tonumber(pane and pane.y)
                        if x and y then
                            local col = math.floor(x) + 1
                            local row = math.floor(y) + 1
                            if row >= 1 and row <= GRID_ROWS and col >= 1 and col <= GRID_COLS then
                                local idx = (row - 1) * GRID_COLS + col
                                grid[idx] = normalize_constraint(pane.constraint)
                            end
                        end
                    end
                end

                out[#out + 1] = {
                    id = tostring(window and window.name or ("window_" .. tostring(#out + 1))),
                    name = tostring(window and window.name or "Unnamed Window"),
                    token = tonumber(window and window.token) or 0,
                    source_card_id = card_id,
                    rows = GRID_ROWS,
                    cols = GRID_COLS,
                    grid = grid,
                    tile_keys = nil,
                    tile_markers = nil,
                }
            end
        end
    end

    return out
end

function WindowPatterns.load(path)
    local content = read_file(path or WINDOWS_JSON_PATH)
    if type(content) ~= "string" or content == "" then
        if _G.log then
            _G.log("[WindowPatterns] Windows.json not found, using fallback pattern")
        end
        return {get_fallback_pattern()}
    end

    local ok, decoded = pcall(Json.decode, content)
    if not ok then
        if _G.log then
            _G.log("[WindowPatterns] JSON decode failed: " .. tostring(decoded))
        end
        return {get_fallback_pattern()}
    end

    local patterns = parse_windows(decoded)
    if #patterns == 0 then
        if _G.log then
            _G.log("[WindowPatterns] No windows found in JSON, using fallback pattern")
        end
        return {get_fallback_pattern()}
    end
    return patterns
end

function WindowPatterns.getAll()
    if not cached_patterns then
        cached_patterns = WindowPatterns.load()
    end
    return cached_patterns
end

function WindowPatterns.pick(seed)
    local all = WindowPatterns.getAll()
    if #all == 0 then
        return get_fallback_pattern()
    end
    local n = math.floor(tonumber(seed) or os.time())
    local idx = (math.abs(n) % #all) + 1
    return deep_copy_pattern(all[idx])
end

function WindowPatterns.getCommonColors()
    return copy_array_with_size(COMMON_COLORS, #COMMON_COLORS)
end

return WindowPatterns
