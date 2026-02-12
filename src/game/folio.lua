-- src/game/folio.lua
-- Sistema Folio: la singola pagina del manoscritto
-- Ogni elemento ha un pattern (griglia con vincoli) e celle dove piazzare dadi

local Patterns = require("src.content.patterns")

local Folio = {}
Folio.__index = Folio

-- Elementi della checklist (ordine di unlock)
Folio.ELEMENTS = {"TEXT", "DROPCAPS", "BORDERS", "CORNERS", "MINIATURE"}

-- Bonus completamento elemento
Folio.BONUS = {
    TEXT = {coins = 5},
    DROPCAPS = {coins = 3},
    BORDERS = {reputation = 1},
    CORNERS = {shield = 1},  -- Assorbe 1 macchia
    MINIATURE = {coins = 10, reputation = 2},
}

--- Crea un nuovo Folio
---@param fascicolo_type string Tipo fascicolo (BIFOLIO, DUERNO, etc.)
---@param seed? number Seed per selezione pattern riproducibile
---@return table Folio instance
function Folio.new(fascicolo_type, seed)
    local self = setmetatable({}, Folio)
    
    self.fascicolo = fascicolo_type or "BIFOLIO"
    self.seed = seed or os.time()
    
    -- Seleziona pattern per ogni elemento
    local patternSet = Patterns.getRandomPatternSet(self.seed)
    
    -- Stato degli elementi
    self.elements = {}
    for _, elem in ipairs(Folio.ELEMENTS) do
        local pattern = patternSet[elem]
        local totalCells = pattern.rows * pattern.cols
        
        self.elements[elem] = {
            pattern = pattern,                    -- Pattern con vincoli
            placed = {},                          -- Celle piazzate: {[index] = {value, color, pigment}}
            cells_filled = 0,
            cells_total = totalCells,
            unlocked = (elem == "TEXT"),          -- Solo TEXT sbloccato all'inizio
            completed = false,
        }
        
        -- Inizializza griglia placed vuota
        for i = 1, totalCells do
            self.elements[elem].placed[i] = nil
        end
    end
    
    -- Sistema macchie
    self.stain_count = 0
    self.stain_threshold = self:getStainThreshold()
    self.shield = 0  -- Da CORNERS
    
    -- Stato generale
    self.busted = false
    self.completed = false
    
    return self
end

--- Threshold macchie per tipo fascicolo
function Folio:getStainThreshold()
    local thresholds = {
        BIFOLIO = 5,
        DUERNO = 6,
        TERNIONE = 6,
        QUATERNIONE = 7,
        QUINTERNO = 7,
        SESTERNO = 8,
    }
    return thresholds[self.fascicolo] or 7
end

--- Piazza un dado su una cella di un elemento
---@param element string Nome elemento (TEXT, DROPCAPS, etc.)
---@param row number Riga (1-based)
---@param col number Colonna (1-based)
---@param diceValue number Valore dado (1-6)
---@param diceColor string Colore dado ("ROSSO", "BLU", etc.)
---@param pigmentName? string Nome pigmento opzionale
---@return boolean success
---@return string message
function Folio:placeDie(element, row, col, diceValue, diceColor, pigmentName)
    local elem = self.elements[element]
    if not elem then
        return false, "Invalid element: " .. tostring(element)
    end
    
    if not elem.unlocked then
        return false, element .. " not unlocked yet"
    end
    
    if elem.completed then
        return false, element .. " already completed"
    end
    
    local pattern = elem.pattern
    
    -- Verifica bounds
    if row < 1 or row > pattern.rows or col < 1 or col > pattern.cols then
        return false, "Cell out of bounds"
    end
    
    -- Calcola indice
    local index = Patterns.rowColToIndex(pattern, row, col)
    
    -- Verifica cella non già occupata
    if elem.placed[index] then
        return false, "Cell already occupied"
    end
    
    -- Verifica vincolo pattern
    local canPlace, reason = Patterns.canPlace(pattern, row, col, diceValue, diceColor)
    if not canPlace then
        return false, reason
    end
    
    -- Piazza il dado
    elem.placed[index] = {
        value = diceValue,
        color = diceColor,
        pigment = pigmentName,
    }
    elem.cells_filled = elem.cells_filled + 1
    
    -- Check completamento
    if elem.cells_filled >= elem.cells_total then
        elem.completed = true
        self:onElementCompleted(element)
    end
    
    return true, string.format("%s: placed %s (%d) at [%d,%d]", 
        element, diceColor, diceValue, row, col)
end

--- Verifica se un dado può essere piazzato (senza piazzarlo)
---@param element string
---@param row number
---@param col number
---@param diceValue number
---@param diceColor string
---@return boolean canPlace
---@return string|nil reason
function Folio:canPlaceDie(element, row, col, diceValue, diceColor)
    local elem = self.elements[element]
    if not elem then
        return false, "Invalid element"
    end
    
    if not elem.unlocked then
        return false, "Locked"
    end
    
    if elem.completed then
        return false, "Already completed"
    end
    
    local pattern = elem.pattern
    
    -- Bounds
    if row < 1 or row > pattern.rows or col < 1 or col > pattern.cols then
        return false, "Out of bounds"
    end
    
    -- Già occupata
    local index = Patterns.rowColToIndex(pattern, row, col)
    if elem.placed[index] then
        return false, "Occupied"
    end
    
    -- Vincolo pattern
    return Patterns.canPlace(pattern, row, col, diceValue, diceColor)
end

--- Ottiene lo stato di una cella
---@param element string
---@param row number
---@param col number
---@return table|nil {constraint, placed, canPlace...}
function Folio:getCellState(element, row, col)
    local elem = self.elements[element]
    if not elem then return nil end
    
    local pattern = elem.pattern
    local index = Patterns.rowColToIndex(pattern, row, col)
    local constraint = Patterns.getConstraint(pattern, row, col)
    
    return {
        row = row,
        col = col,
        constraint = constraint,
        placed = elem.placed[index],
        unlocked = elem.unlocked,
    }
end

--- Ottiene tutte le celle di un elemento
---@param element string
---@return table[] Lista di stati cella
function Folio:getAllCells(element)
    local elem = self.elements[element]
    if not elem then return {} end
    
    local cells = {}
    for row = 1, elem.pattern.rows do
        for col = 1, elem.pattern.cols do
            table.insert(cells, self:getCellState(element, row, col))
        end
    end
    return cells
end

--- Trova celle valide per un dado in un elemento
---@param element string
---@param diceValue number
---@param diceColor string
---@return table[] Lista di {row, col} valide
function Folio:getValidPlacements(element, diceValue, diceColor)
    local elem = self.elements[element]
    if not elem or not elem.unlocked or elem.completed then
        return {}
    end
    
    local valid = {}
    for row = 1, elem.pattern.rows do
        for col = 1, elem.pattern.cols do
            local canPlace = self:canPlaceDie(element, row, col, diceValue, diceColor)
            if canPlace then
                table.insert(valid, {row = row, col = col})
            end
        end
    end
    return valid
end

--- Trova tutti gli elementi dove un dado può essere piazzato
---@param diceValue number
---@param diceColor string
---@return table {element = {{row,col}, ...}, ...}
function Folio:getAllValidPlacements(diceValue, diceColor)
    local result = {}
    for _, elem in ipairs(Folio.ELEMENTS) do
        local placements = self:getValidPlacements(elem, diceValue, diceColor)
        if #placements > 0 then
            result[elem] = placements
        end
    end
    return result
end

--- Callback completamento elemento
function Folio:onElementCompleted(element)
    log("[Folio] Completed: " .. element)
    
    -- Sblocca elemento successivo
    local idx = nil
    for i, elem in ipairs(Folio.ELEMENTS) do
        if elem == element then idx = i break end
    end
    if idx and idx < #Folio.ELEMENTS then
        local next_elem = Folio.ELEMENTS[idx + 1]
        self.elements[next_elem].unlocked = true
        log("[Folio] Unlocked: " .. next_elem)
    end
    
    -- Applica bonus
    local bonus = Folio.BONUS[element]
    if bonus and bonus.shield then
        self.shield = self.shield + bonus.shield
    end
    
    -- Check completamento folio (TEXT + MINIATURE obbligatori)
    if self.elements.TEXT.completed and self.elements.MINIATURE.completed then
        self.completed = true
        log("[Folio] FOLIO COMPLETED!")
    end
end

--- Aggiungi macchia
---@param amount number Numero di macchie (default 1)
---@return boolean busted Se il folio è andato in bust
function Folio:addStain(amount)
    amount = amount or 1
    
    -- Shield assorbe macchie
    if self.shield > 0 then
        local absorbed = math.min(self.shield, amount)
        self.shield = self.shield - absorbed
        amount = amount - absorbed
        if absorbed > 0 then
            log("[Folio] Shield absorbed " .. absorbed .. " stain(s)")
        end
    end
    
    self.stain_count = self.stain_count + amount
    log(string.format("[Folio] Stains: %d/%d", self.stain_count, self.stain_threshold))
    
    -- Check bust
    if self.stain_count >= self.stain_threshold then
        self.busted = true
        log("[Folio] BUST! Too many stains!")
        return true
    end
    
    return false
end

--- Rimuovi macchia (es. da Tocco d'Oro)
function Folio:removeStain(amount)
    amount = amount or 1
    self.stain_count = math.max(0, self.stain_count - amount)
    log(string.format("[Folio] Stain removed. Now: %d/%d", self.stain_count, self.stain_threshold))
end

--- Stato debug
function Folio:getStatus()
    local status = {
        fascicolo = self.fascicolo,
        stains = string.format("%d/%d", self.stain_count, self.stain_threshold),
        shield = self.shield,
        busted = self.busted,
        completed = self.completed,
        elements = {},
    }
    for _, elem in ipairs(Folio.ELEMENTS) do
        local e = self.elements[elem]
        status.elements[elem] = {
            pattern = e.pattern.name,
            progress = string.format("%d/%d", e.cells_filled, e.cells_total),
            unlocked = e.unlocked,
            completed = e.completed,
        }
    end
    return status
end

--- Debug print
function Folio:debugPrint()
    log("\n" .. string.rep("═", 60))
    log("FOLIO: " .. self.fascicolo)
    log(string.format("Stains: %d/%d | Shield: %d | Busted: %s | Completed: %s",
        self.stain_count, self.stain_threshold, self.shield,
        tostring(self.busted), tostring(self.completed)))
    log(string.rep("─", 60))
    
    for _, elemName in ipairs(Folio.ELEMENTS) do
        local elem = self.elements[elemName]
        local lock = elem.unlocked and "🔓" or "🔒"
        local check = elem.completed and "✅" or ""
        print(string.format("%s %s: %s [%d/%d] %s",
            lock, elemName, elem.pattern.name, elem.cells_filled, elem.cells_total, check))
        
        -- Mostra griglia se sbloccato
        if elem.unlocked then
            for row = 1, elem.pattern.rows do
                local line = "    "
                for col = 1, elem.pattern.cols do
                    local state = self:getCellState(elemName, row, col)
                    if state.placed then
                        line = line .. string.format("[%s%d]", 
                            state.placed.color:sub(1,1), state.placed.value)
                    elseif state.constraint then
                        if type(state.constraint) == "number" then
                            line = line .. string.format("( %d )", state.constraint)
                        else
                            line = line .. string.format("(%s)", state.constraint:sub(1,3))
                        end
                    else
                        line = line .. "[   ]"
                    end
                    line = line .. " "
                end
                log(line)
            end
        end
    end
    log(string.rep("═", 60))
end


--------------------------------------------------------------------------------
-- RUN: Gestisce una run completa (fascicolo di N folii)
-- Integrato in folio.lua per consolidamento
--------------------------------------------------------------------------------

local Run = {}
Run.__index = Run

-- Tipi di fascicolo e numero di folii
Run.FASCICOLI = {
    BIFOLIO = 2,
    DUERNO = 4,
    TERNIONE = 6,
    QUATERNIONE = 8,
    QUINTERNO = 10,
    SESTERNO = 12,
}

--- Crea una nuova run
---@param fascicolo_type string Tipo di fascicolo
---@param seed number Seed per RNG riproducibile (opzionale)
function Run.new(fascicolo_type, seed)
    local self = setmetatable({}, Run)
    
    self.fascicolo = fascicolo_type or "BIFOLIO"
    self.total_folii = Run.FASCICOLI[self.fascicolo] or 2
    
    -- Seed riproducibile
    self.seed = seed or os.time()
    math.randomseed(self.seed)
    if love and love.math then
        love.math.setRandomSeed(self.seed)
    end
    log("[Run] Seed: " .. self.seed)
    
    -- Stato run
    self.current_folio_index = 1
    self.current_folio = Folio.new(self.fascicolo, self.seed + 1)
    self.completed_folii = {}
    
    -- Risorse player
    self.reputation = 20  -- HP della run
    self.coins = 0
    
    -- Inventario (pigmenti, leganti scelti)
    self.inventory = {
        pigments = {},
        binders = {},
    }
    
    -- Stato
    self.game_over = false
    self.victory = false
    
    return self
end

--- Avanza al folio successivo
function Run:nextFolio()
    if self.current_folio.completed then
        -- Calcola reward
        local reward = self:calculateFolioReward()
        self.coins = self.coins + reward.coins
        self.reputation = self.reputation + reward.reputation
        
        print(string.format("[Run] Folio %d completed! +%d coins, +%d rep", 
            self.current_folio_index, reward.coins, reward.reputation))
        
        table.insert(self.completed_folii, self.current_folio)
        self.current_folio_index = self.current_folio_index + 1
        
        -- Check vittoria
        if self.current_folio_index > self.total_folii then
            self.victory = true
            log("[Run] VICTORY! Folio set completed!")
            return true, "victory"
        end
        
        -- Nuovo folio
        self.current_folio = Folio.new(self.fascicolo, self.seed + self.current_folio_index)
        return true, "next"
        
    elseif self.current_folio.busted then
        -- Folio perso
        local rep_loss = 3
        self.reputation = self.reputation - rep_loss
        print(string.format("[Run] Folio BUST! -%d reputation (now: %d)", rep_loss, self.reputation))
        
        -- Check game over
        if self.reputation <= 0 then
            self.game_over = true
            log("[Run] GAME OVER! Reputation depleted!")
            return false, "game_over"
        end
        
        -- Nuovo folio (stessa posizione, si riprova)
        self.current_folio = Folio.new(self.fascicolo, self.seed + self.current_folio_index + 1000)
        return true, "retry"
    end
    
    return false, "in_progress"
end

--- Calcola reward per folio completato
function Run:calculateFolioReward()
    local reward = {coins = 30, reputation = 0}  -- Base
    
    local folio = self.current_folio
    for elem, bonus in pairs(Folio.BONUS) do
        if folio.elements[elem].completed then
            reward.coins = reward.coins + (bonus.coins or 0)
            reward.reputation = reward.reputation + (bonus.reputation or 0)
        end
    end
    
    -- Pardon: bonus se pochi stain e nessun peccato
    if folio.stain_count < 2 then
        reward.reputation = reward.reputation + 2
        log("[Run] Pardon! +2 reputation")
    end
    
    return reward
end

--- Stato per UI
function Run:getStatus()
    return {
        fascicolo = self.fascicolo,
        folio = string.format("%d/%d", self.current_folio_index, self.total_folii),
        reputation = self.reputation,
        coins = self.coins,
        seed = self.seed,
        game_over = self.game_over,
        victory = self.victory,
    }
end

-- Esporta sia Folio che Run
return {
    Folio = Folio,
    Run = Run,
}

