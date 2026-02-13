-- src/content/patterns.lua
-- Pattern per elementi del Folio in Scriptorium Alchimico
-- Ogni elemento ha la propria griglia con vincoli colore/valore
--
-- Elementi e dimensioni gameplay correnti:
--   TEXT      = 4x4 (16 celle)
--   BORDERS   = 3x4 (12 celle)
--   MINIATURE = 2x4 (8 celle)
--   DROPCAPS  = 2x3 (6 celle, "Dropcaps/Corners")
--
-- Vincoli:
--   nil      = nessun vincolo (cella libera)
--   "ROSSO"  = richiede pigmento rosso
--   "BLU"    = richiede pigmento blu
--   "VERDE"  = richiede pigmento verde
--   "GIALLO" = richiede pigmento giallo/oro
--   "VIOLA"  = richiede pigmento viola
--   "NERO"   = richiede pigmento nero
--   "MARRONE"= richiede pigmento marrone
--   1-6      = richiede dado con quel valore

local TilePatternGenerator = require("src.content.tile_pattern_generator")

local M = {}

M.USE_TILE_GENERATOR = true
M.TILE_ROWS = 4
M.TILE_COLS = 5
M.TILE_GENERATOR_SEED_MODE = "seeded" -- "seeded" | "random"
M.TILE_GENERATOR_VARIATIONS = true

function M.setTileSeedMode(mode)
    if mode == "seeded" or mode == "random" then
        M.TILE_GENERATOR_SEED_MODE = mode
    end
end

function M.setTileVariationsEnabled(enabled)
    M.TILE_GENERATOR_VARIATIONS = enabled and true or false
end

-- ══════════════════════════════════════════════════════════════════
-- CONFIGURAZIONE ELEMENTI
-- ══════════════════════════════════════════════════════════════════

M.ELEMENT_CONFIG = {
    TEXT = { rows = 4, cols = 4, cells = 16 },
    DROPCAPS = { rows = 2, cols = 3, cells = 6 },
    BORDERS = { rows = 3, cols = 4, cells = 12 },
    MINIATURE = { rows = 2, cols = 4, cells = 8 },
    -- Kept for backward compatibility in tooling/debug paths.
    CORNERS = { rows = 2, cols = 3, cells = 6 },
}

-- ══════════════════════════════════════════════════════════════════
-- PATTERN PER ELEMENTO
-- ══════════════════════════════════════════════════════════════════

M.patterns = {

    -- ══════════════════════════════════════════════════════════════
    -- TEXT (2×3 = 6 celle)
    -- ══════════════════════════════════════════════════════════════
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

    -- ══════════════════════════════════════════════════════════════
    -- DROPCAPS (1×2 = 2 celle)
    -- ══════════════════════════════════════════════════════════════
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

    -- ══════════════════════════════════════════════════════════════
    -- BORDERS (2×2 = 4 celle)
    -- ══════════════════════════════════════════════════════════════
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

    -- ══════════════════════════════════════════════════════════════
    -- CORNERS (2×2 = 4 celle)
    -- ══════════════════════════════════════════════════════════════
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

    -- ══════════════════════════════════════════════════════════════
    -- MINIATURE (1×3 = 3 celle)
    -- ══════════════════════════════════════════════════════════════
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

-- ══════════════════════════════════════════════════════════════════
-- FUNZIONI HELPER
-- ══════════════════════════════════════════════════════════════════

--- Token favore iniziali per un pattern
---@param pattern table
---@return number
function M.getInitialTokens(pattern)
    return math.max(0, 6 - pattern.difficulty)
end

--- Ottiene pattern per ID
---@param id number
---@return table|nil
function M.getById(id)
    for _, p in ipairs(M.patterns) do
        if p.id == id then
            return p
        end
    end
    return nil
end

--- Ottiene tutti i pattern per un elemento
---@param element string "TEXT", "DROPCAPS", etc.
---@return table[]
function M.getByElement(element)
    local result = {}
    for _, p in ipairs(M.patterns) do
        if p.element == element then
            table.insert(result, p)
        end
    end
    return result
end

--- Ottiene pattern per elemento e difficoltà
---@param element string
---@param difficulty number
---@return table[]
function M.getByElementAndDifficulty(element, difficulty)
    local result = {}
    for _, p in ipairs(M.patterns) do
        if p.element == element and p.difficulty == difficulty then
            table.insert(result, p)
        end
    end
    return result
end

--- Seleziona pattern casuale per un elemento
---@param element string
---@param seed? number opzionale
---@return table|nil
function M.getRandomForElement(element, seed)
    if seed then
        math.randomseed(seed)
    end
    
    local available = M.getByElement(element)
    if #available == 0 then
        return nil
    end
    
    return available[math.random(1, #available)]
end

--- Seleziona set completo di pattern per tutti gli elementi
---@param seed? number opzionale
---@return table {TEXT=pattern, DROPCAPS=pattern, ...}
function M.getRandomPatternSet(seed)
    local elements = {"TEXT", "DROPCAPS", "BORDERS", "MINIATURE"}

    if M.USE_TILE_GENERATOR then
        local element_options = {}
        for _, elem in ipairs(elements) do
            local cfg = M.ELEMENT_CONFIG[elem]
            if cfg then
                element_options[elem] = { rows = cfg.rows, cols = cfg.cols }
            end
        end
        local generated = TilePatternGenerator.generate_set(seed, elements, {
            rows = M.TILE_ROWS,
            cols = M.TILE_COLS,
            element_options = element_options,
            seed_mode = M.TILE_GENERATOR_SEED_MODE,
            variations = M.TILE_GENERATOR_VARIATIONS,
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
        -- Seed diverso per ogni elemento ma riproducibile
        local elemSeed = seed and (seed + i * 1000) or nil
        fallback[elem] = M.getRandomForElement(elem, elemSeed)
    end

    return fallback
end

--- Converte indice lineare a coordinate riga,colonna
---@param pattern table
---@param index number
---@return number row, number col
function M.indexToRowCol(pattern, index)
    local cols = pattern.cols
    local row = math.ceil(index / cols)
    local col = ((index - 1) % cols) + 1
    return row, col
end

--- Converte coordinate a indice lineare
---@param pattern table
---@param row number
---@param col number
---@return number index
function M.rowColToIndex(pattern, row, col)
    return (row - 1) * pattern.cols + col
end

--- Ottiene vincolo di una cella
---@param pattern table
---@param row number
---@param col number
---@return string|number|nil vincolo
function M.getConstraint(pattern, row, col)
    local index = M.rowColToIndex(pattern, row, col)
    return pattern.grid[index]
end

--- Verifica se un dado può essere piazzato in una cella
---@param pattern table
---@param row number
---@param col number
---@param diceValue number 1-6
---@param diceColor string colore del dado ("ROSSO", "BLU", etc.)
---@return boolean canPlace
---@return string|nil reason
function M.canPlace(pattern, row, col, diceValue, diceColor)
    -- Verifica bounds
    if row < 1 or row > pattern.rows or col < 1 or col > pattern.cols then
        return false, "Out of bounds"
    end
    
    local constraint = M.getConstraint(pattern, row, col)
    
    if constraint == nil then
        return true, nil  -- nessun vincolo
    elseif type(constraint) == "number" then
        if diceValue == constraint then
            return true, nil
        else
            return false, string.format("Richiede valore %d", constraint)
        end
    elseif type(constraint) == "string" then
        if diceColor == constraint then
            return true, nil
        else
            return false, string.format("Richiede colore %s", constraint)
        end
    end
    
    return false, "Unknown constraint"
end

--- Conta celle vuote (senza vincolo) in un pattern
---@param pattern table
---@return number
function M.countFreeCells(pattern)
    local count = 0
    for _, cell in ipairs(pattern.grid) do
        if cell == nil then
            count = count + 1
        end
    end
    return count
end

--- Conta celle con vincolo in un pattern
---@param pattern table
---@return number colorConstraints, number valueConstraints
function M.countConstraints(pattern)
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

--- Ottiene configurazione elemento
---@param element string
---@return table|nil {rows, cols, cells}
function M.getElementConfig(element)
    return M.ELEMENT_CONFIG[element]
end

--- Stampa pattern per debug
---@param pattern table
function M.debugPrint(pattern)
    log(string.format("=== %s [%s] (diff: %d, tokens: %d) ===",
        pattern.name, pattern.element, pattern.difficulty, M.getInitialTokens(pattern)))
    log(string.format("    Griglia: %dx%d", pattern.rows, pattern.cols))
    
    for row = 1, pattern.rows do
        local line = "    "
        for col = 1, pattern.cols do
            local c = M.getConstraint(pattern, row, col)
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

--- Stampa tutti i pattern raggruppati per elemento
function M.debugPrintAll()
    local elements = {"TEXT", "DROPCAPS", "BORDERS", "CORNERS", "MINIATURE"}
    for _, elem in ipairs(elements) do
        log("\n" .. string.rep("═", 50))
        log("ELEMENTO: " .. elem)
        log(string.rep("═", 50))
        for _, p in ipairs(M.getByElement(elem)) do
            M.debugPrint(p)
            log("")
        end
    end
end

return M
