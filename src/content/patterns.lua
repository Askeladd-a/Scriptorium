
local TilePatternGenerator = require("src.content.tile_pattern_generator")

local Patterns = {}

Patterns.USE_TILE_GENERATOR = true
Patterns.TILE_ROWS = 4
Patterns.TILE_COLS = 5
Patterns.TILE_GENERATOR_SEED_MODE = "seeded"
Patterns.TILE_GENERATOR_VARIATIONS = true

function Patterns.setTileSeedMode(mode)
    if mode == "seeded" or mode == "random" then
        Patterns.TILE_GENERATOR_SEED_MODE = mode
    end
end

function Patterns.setTileVariationsEnabled(enabled)
    Patterns.TILE_GENERATOR_VARIATIONS = enabled and true or false
end


Patterns.ELEMENT_CONFIG = {
    TEXT = { rows = 4, cols = 4, cells = 16 },
    DROPCAPS = { rows = 2, cols = 3, cells = 6 },
    BORDERS = { rows = 3, cols = 4, cells = 12 },
    MINIATURE = { rows = 2, cols = 4, cells = 8 },
    CORNERS = { rows = 2, cols = 3, cells = 6 },
}


Patterns.library = {

    {
        id = 1,
        element = "TEXT",
        name = "Scriptura Simplex",
        difficulty = 3,
        rows = 2, cols = 3,
        grid = {
            nil,     nil,     nil,
            nil,     nil,     nil,
        }
    },
    {
        id = 2,
        element = "TEXT",
        name = "Scriptura Aurea",
        difficulty = 4,
        rows = 2, cols = 3,
        grid = {
            "GIALLO", nil,    nil,
            nil,      nil,    "GIALLO",
        }
    },
    {
        id = 3,
        element = "TEXT",
        name = "Scriptura Regalis",
        difficulty = 4,
        rows = 2, cols = 3,
        grid = {
            "BLU",   nil,     "ROSSO",
            nil,     nil,     nil,
        }
    },
    {
        id = 4,
        element = "TEXT",
        name = "Scriptura Ordinata",
        difficulty = 5,
        rows = 2, cols = 3,
        grid = {
            1,       2,       3,
            4,       5,       6,
        }
    },
    {
        id = 5,
        element = "TEXT",
        name = "Scriptura Cromatica",
        difficulty = 5,
        rows = 2, cols = 3,
        grid = {
            "ROSSO", "VERDE", "BLU",
            nil,     nil,     nil,
        }
    },
    {
        id = 6,
        element = "TEXT",
        name = "Scriptura Sacra",
        difficulty = 6,
        rows = 2, cols = 3,
        grid = {
            "VIOLA", 3,       "GIALLO",
            1,       "BLU",   5,
        }
    },

    {
        id = 7,
        element = "DROPCAPS",
        name = "Capolettera Libero",
        difficulty = 3,
        rows = 1, cols = 2,
        grid = {
            nil, nil,
        }
    },
    {
        id = 8,
        element = "DROPCAPS",
        name = "Capolettera Dorato",
        difficulty = 4,
        rows = 1, cols = 2,
        grid = {
            "GIALLO", nil,
        }
    },
    {
        id = 9,
        element = "DROPCAPS",
        name = "Capolettera Imperiale",
        difficulty = 5,
        rows = 1, cols = 2,
        grid = {
            "VIOLA", "GIALLO",
        }
    },
    {
        id = 10,
        element = "DROPCAPS",
        name = "Capolettera Numerato",
        difficulty = 5,
        rows = 1, cols = 2,
        grid = {
            6, 1,
        }
    },

    {
        id = 11,
        element = "BORDERS",
        name = "Cornice Semplice",
        difficulty = 3,
        rows = 2, cols = 2,
        grid = {
            nil, nil,
            nil, nil,
        }
    },
    {
        id = 12,
        element = "BORDERS",
        name = "Cornice Vegetale",
        difficulty = 4,
        rows = 2, cols = 2,
        grid = {
            "VERDE", nil,
            nil,     "VERDE",
        }
    },
    {
        id = 13,
        element = "BORDERS",
        name = "Cornice Reale",
        difficulty = 4,
        rows = 2, cols = 2,
        grid = {
            "BLU",   "GIALLO",
            nil,     nil,
        }
    },
    {
        id = 14,
        element = "BORDERS",
        name = "Cornice Geometrica",
        difficulty = 5,
        rows = 2, cols = 2,
        grid = {
            1, 3,
            2, 4,
        }
    },
    {
        id = 15,
        element = "BORDERS",
        name = "Cornice Bizantina",
        difficulty = 6,
        rows = 2, cols = 2,
        grid = {
            "GIALLO", "ROSSO",
            "BLU",    "VERDE",
        }
    },

    {
        id = 16,
        element = "CORNERS",
        name = "Angolo Aperto",
        difficulty = 3,
        rows = 2, cols = 2,
        grid = {
            nil, nil,
            nil, nil,
        }
    },
    {
        id = 17,
        element = "CORNERS",
        name = "Angolo Floreale",
        difficulty = 4,
        rows = 2, cols = 2,
        grid = {
            "ROSSO", nil,
            nil,     "VERDE",
        }
    },
    {
        id = 18,
        element = "CORNERS",
        name = "Angolo Celeste",
        difficulty = 4,
        rows = 2, cols = 2,
        grid = {
            "BLU", nil,
            nil,   "BLU",
        }
    },
    {
        id = 19,
        element = "CORNERS",
        name = "Angolo Simmetrico",
        difficulty = 5,
        rows = 2, cols = 2,
        grid = {
            2, 5,
            5, 2,
        }
    },
    {
        id = 20,
        element = "CORNERS",
        name = "Angolo Araldico",
        difficulty = 6,
        rows = 2, cols = 2,
        grid = {
            "GIALLO", 6,
            1,        "ROSSO",
        }
    },

    {
        id = 21,
        element = "MINIATURE",
        name = "Miniatura Base",
        difficulty = 3,
        rows = 1, cols = 3,
        grid = {
            nil, nil, nil,
        }
    },
    {
        id = 22,
        element = "MINIATURE",
        name = "Miniatura Naturale",
        difficulty = 4,
        rows = 1, cols = 3,
        grid = {
            "VERDE", nil, "MARRONE",
        }
    },
    {
        id = 23,
        element = "MINIATURE",
        name = "Miniatura Sacra",
        difficulty = 5,
        rows = 1, cols = 3,
        grid = {
            "GIALLO", "BLU", "ROSSO",
        }
    },
    {
        id = 24,
        element = "MINIATURE",
        name = "Miniatura Magistrale",
        difficulty = 6,
        rows = 1, cols = 3,
        grid = {
            6, "VIOLA", 1,
        }
    },
}


function Patterns.getInitialTokens(pattern)
    return math.max(0, 6 - pattern.difficulty)
end

function Patterns.getById(id)
    for _, p in ipairs(Patterns.library) do
        if p.id == id then
            return p
        end
    end
    return nil
end

function Patterns.getByElement(element)
    local result = {}
    for _, p in ipairs(Patterns.library) do
        if p.element == element then
            table.insert(result, p)
        end
    end
    return result
end

function Patterns.getByElementAndDifficulty(element, difficulty)
    local result = {}
    for _, p in ipairs(Patterns.library) do
        if p.element == element and p.difficulty == difficulty then
            table.insert(result, p)
        end
    end
    return result
end

function Patterns.getRandomForElement(element, seed)
    if seed then
        math.randomseed(seed)
    end
    
    local available = Patterns.getByElement(element)
    if #available == 0 then
        return nil
    end
    
    return available[math.random(1, #available)]
end

function Patterns.getRandomPatternSet(seed)
    local elements = {"TEXT", "DROPCAPS", "BORDERS", "MINIATURE"}

    if Patterns.USE_TILE_GENERATOR then
        local element_options = {}
        for _, elem in ipairs(elements) do
            local cfg = Patterns.ELEMENT_CONFIG[elem]
            if cfg then
                element_options[elem] = { rows = cfg.rows, cols = cfg.cols }
            end
        end
        local generated = TilePatternGenerator.generateSet(seed, elements, {
            rows = Patterns.TILE_ROWS,
            cols = Patterns.TILE_COLS,
            element_options = element_options,
            seed_mode = Patterns.TILE_GENERATOR_SEED_MODE,
            variations = Patterns.TILE_GENERATOR_VARIATIONS,
        })
        local complete = true
        for _, elem in ipairs(elements) do
            if not generated[elem] then
                complete = false
                break
            end
        end
        if complete then
            return generated
        end
    end

    local fallback = {}
    for i, elem in ipairs(elements) do
        local element_seed = seed and (seed + i * 1000) or nil
        fallback[elem] = Patterns.getRandomForElement(elem, element_seed)
    end

    return fallback
end

function Patterns.indexToRowCol(pattern, index)
    local cols = pattern.cols
    local row = math.ceil(index / cols)
    local col = ((index - 1) % cols) + 1
    return row, col
end

function Patterns.rowColToIndex(pattern, row, col)
    return (row - 1) * pattern.cols + col
end

function Patterns.getConstraint(pattern, row, col)
    local index = Patterns.rowColToIndex(pattern, row, col)
    return pattern.grid[index]
end

function Patterns.canPlace(pattern, row, col, dice_value, dice_color)
    if row < 1 or row > pattern.rows or col < 1 or col > pattern.cols then
        return false, "Out of bounds"
    end
    
    local constraint = Patterns.getConstraint(pattern, row, col)
    
    if constraint == nil then
        return true, nil
    elseif type(constraint) == "number" then
        if dice_value == constraint then
            return true, nil
        else
            return false, string.format("Requires value %d", constraint)
        end
    elseif type(constraint) == "string" then
        if dice_color == constraint then
            return true, nil
        else
            return false, string.format("Requires color %s", constraint)
        end
    end
    
    return false, "Unknown constraint"
end

function Patterns.countFreeCells(pattern)
    local count = 0
    for _, cell in ipairs(pattern.grid) do
        if cell == nil then
            count = count + 1
        end
    end
    return count
end

function Patterns.countConstraints(pattern)
    local colors, values = 0, 0
    for _, cell in ipairs(pattern.grid) do
        if type(cell) == "string" then
            colors = colors + 1
        elseif type(cell) == "number" then
            values = values + 1
        end
    end
    return colors, values
end

function Patterns.getElementConfig(element)
    return Patterns.ELEMENT_CONFIG[element]
end

function Patterns.debugPrint(pattern)
    log(string.format("=== %s [%s] (diff: %d, tokens: %d) ===",
        pattern.name, pattern.element, pattern.difficulty, Patterns.getInitialTokens(pattern)))
    log(string.format("    Grid: %dx%d", pattern.rows, pattern.cols))
    
    for row = 1, pattern.rows do
        local line = "    "
        for col = 1, pattern.cols do
            local c = Patterns.getConstraint(pattern, row, col)
            if c == nil then
                line = line .. "[   ] "
            elseif type(c) == "number" then
                line = line .. string.format("[ %d ] ", c)
            else
                line = line .. string.format("[%s] ", c:sub(1,3):upper())
            end
        end
        log(line)
    end
end

function Patterns.debugPrintAll()
    local elements = {"TEXT", "DROPCAPS", "BORDERS", "CORNERS", "MINIATURE"}
    for _, elem in ipairs(elements) do
        log("\n" .. string.rep("═", 50))
        log("ELEMENT: " .. elem)
        log(string.rep("═", 50))
        for _, p in ipairs(Patterns.getByElement(elem)) do
            Patterns.debugPrint(p)
            log("")
        end
    end
end

return Patterns


