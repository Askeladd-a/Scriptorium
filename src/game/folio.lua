-- src/game/folio.lua
-- Sistema Folio: la singola pagina del manoscritto
-- Ogni elemento ha un pattern (griglia con vincoli) e celle dove piazzare dadi

local Patterns = require("src.content.patterns")
local MVPDecks = require("src.content.mvp_decks")

local Folio = {}
Folio.__index = Folio

-- Elementi della checklist (ordine di unlock).
-- CORNERS is merged into DROPCAPS for the 4-grid gameplay layout.
Folio.ELEMENTS = {"TEXT", "DROPCAPS", "BORDERS", "MINIATURE"}

-- Bonus completamento elemento
Folio.BONUS = {
    TEXT = {coins = 5},
    DROPCAPS = {coins = 3, shield = 1},
    BORDERS = {reputation = 1},
    MINIATURE = {coins = 10, reputation = 2},
}

local TEXT_ALLOWED_COLORS = {
    NERO = true,
    MARRONE = true,
    ROSSO = true,
}

local BORDER_COLOR_PAIRS = {
    {"ROSSO", "BLU"},
    {"VERDE", "BLU"},
    {"MARRONE", "VERDE"},
    {"NERO", "ROSSO"},
}

local VALUE_TO_COLOR = {
    [1] = "MARRONE",
    [2] = "VERDE",
    [3] = "NERO",
    [4] = "ROSSO",
    [5] = "BLU",
    [6] = "GIALLO",
}

local function get_border_parity(seed)
    local n = math.floor(tonumber(seed) or os.time())
    if (n % 2) == 0 then
        return "EVEN"
    end
    return "ODD"
end

--- Crea un nuovo Folio
---@param fascicolo_type string Tipo fascicolo (BIFOLIO, DUERNO, etc.)
---@param seed? number Seed per selezione pattern riproducibile
---@param run_setup? table Setup carte/effetti della run
---@return table Folio instance
function Folio.new(fascicolo_type, seed, run_setup)
    local self = setmetatable({}, Folio)
    
    self.fascicolo = fascicolo_type or "BIFOLIO"
    self.seed = seed or os.time()

    run_setup = run_setup or MVPDecks.draw_run_setup(self.seed + 77)
    self.run_setup = run_setup
    self.rule_cards = run_setup.cards or {}
    self.rule_effects = run_setup.effects or {}
    self.border_parity = self.rule_effects.force_borders_parity or get_border_parity(self.seed)
    
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
            wet = {},                             -- Celle piazzate nel turno corrente (non confermate)
            cells_filled = 0,
            cells_total = totalCells,
            unlocked = (elem == "TEXT"),          -- Solo TEXT sbloccato all'inizio
            completed = false,
            motif_pairs = (elem == "BORDERS") and {} or nil, -- Coppie colore scelte per motivo
        }
        
        -- Inizializza griglia placed vuota
        for i = 1, totalCells do
            self.elements[elem].placed[i] = nil
        end
    end
    
    -- Sistema macchie
    self.stain_count = 0
    self.stain_threshold = self:getStainThreshold()
    self.shield = 0  -- From DROPCAPS completion bonus

    -- Stato turno (wet buffer + rischio)
    self.wet_buffer = {}
    self.turn_risk = 0
    self.turn_pushes = 0
    self.turn_flags = {
        over_four = false,
        preparation_used = false,
    }
    self.push_risk_enabled = false -- opzionale: +1 rischio per ogni PUSH oltre il primo
    self.preparation_guard = (self.rule_effects.tool_bonus_guard or 0)
    self.first_stop_done = false
    self.tool_uses_left = (self.rule_cards.tool and self.rule_cards.tool.uses_per_folio) or 0

    -- Punteggio qualità complessivo del folio
    self.quality = 0
    self.section_stains = {}
    for _, elem in ipairs(Folio.ELEMENTS) do
        self.section_stains[elem] = 0
    end
    
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

function Folio:_getEffectivePlacement(elem, index)
    if elem.wet and elem.wet[index] then
        return elem.wet[index]
    end
    return elem.placed[index]
end

function Folio:_countEffectiveFilledInRow(elem, row)
    local count = 0
    for col = 1, elem.pattern.cols do
        local index = Patterns.rowColToIndex(elem.pattern, row, col)
        if self:_getEffectivePlacement(elem, index) then
            count = count + 1
        end
    end
    return count
end

function Folio:_getTextCurrentRow(elem)
    local rows = elem.pattern.rows
    local cols = elem.pattern.cols
    local threshold = math.ceil(cols * 0.75)
    local current = 1

    for row = 1, rows - 1 do
        local filled = self:_countEffectiveFilledInRow(elem, row)
        if filled >= threshold then
            current = row + 1
        else
            break
        end
    end

    return current
end

function Folio:_getBorderMotifPos(pattern, row, col)
    if pattern.rows == 3 and pattern.cols == 4 then
        -- 4 motivi da 3 celle (colonne): 1-2-3 dall'alto verso il basso
        return col, row
    end

    local index = Patterns.rowColToIndex(pattern, row, col)
    local motif = math.floor((index - 1) / 3) + 1
    local pos = ((index - 1) % 3) + 1
    return motif, pos
end

function Folio:_getBorderPairForColor(color)
    for _, pair in ipairs(BORDER_COLOR_PAIRS) do
        if color == pair[1] or color == pair[2] then
            return {pair[1], pair[2]}
        end
    end
    local fallback = BORDER_COLOR_PAIRS[1]
    return {fallback[1], fallback[2]}
end

function Folio:_getBorderMotifColors(elem, motif, candidate_pos, candidate_color)
    local pattern = elem.pattern
    local colors = {nil, nil, nil}
    for row = 1, pattern.rows do
        for col = 1, pattern.cols do
            local m, pos = self:_getBorderMotifPos(pattern, row, col)
            if m == motif and pos >= 1 and pos <= 3 then
                local idx = Patterns.rowColToIndex(pattern, row, col)
                local placed = self:_getEffectivePlacement(elem, idx)
                if placed then
                    colors[pos] = placed.color
                end
            end
        end
    end
    if candidate_pos and candidate_pos >= 1 and candidate_pos <= 3 then
        colors[candidate_pos] = candidate_color
    end
    return colors
end

local function border_alternation_valid(pair, colors)
    local a = pair[1]
    local b = pair[2]
    local valid_aba = true
    local valid_bab = true

    for pos = 1, 3 do
        local c = colors[pos]
        if c and c ~= "GIALLO" then
            local expected_aba = (pos % 2 == 1) and a or b
            local expected_bab = (pos % 2 == 1) and b or a
            if c ~= expected_aba then valid_aba = false end
            if c ~= expected_bab then valid_bab = false end
        end
    end

    return valid_aba or valid_bab
end

function Folio:_validateSectionRules(element, row, col, diceValue, diceColor)
    local elem = self.elements[element]
    local meta = {
        border_break = false,
        border_motif = nil,
        border_pair = nil,
        is_gold = (diceColor == "GIALLO" or diceValue == 6),
    }

    if self.rule_effects and self.rule_effects.simple_sections then
        if element == "TEXT" then
            if diceValue < 1 or diceValue > 3 then
                return false, "Text accepts only 1-3", meta
            end
            return true, nil, meta
        end

        if element == "DROPCAPS" then
            if diceValue < 4 or diceValue > 6 then
                return false, "Dropcaps accepts only 4-6", meta
            end
            return true, nil, meta
        end

        if element == "BORDERS" then
            local parity_even = (self.border_parity == "EVEN")
            local is_even = (diceValue % 2) == 0
            if parity_even and not is_even then
                return false, "Borders accepts only even values in this folio", meta
            end
            if (not parity_even) and is_even then
                return false, "Borders accepts only odd values in this folio", meta
            end
            return true, nil, meta
        end

        -- MINIATURE accepts all values/colors in MVP mode.
        return true, nil, meta
    end

    if element == "TEXT" then
        if not TEXT_ALLOWED_COLORS[diceColor] then
            return false, "Text allows only Nero, Marrone, Rosso", meta
        end
        local current_row = self:_getTextCurrentRow(elem)
        if row ~= current_row then
            return false, string.format("Text row %d locked (current row: %d)", row, current_row), meta
        end
        return true, nil, meta
    end

    if element == "BORDERS" then
        local motif, pos = self:_getBorderMotifPos(elem.pattern, row, col)
        meta.border_motif = motif

        local pair = elem.motif_pairs[motif]
        if not pair then
            pair = self:_getBorderPairForColor(diceColor)
            meta.border_pair = {pair[1], pair[2]}
        end

        local colors = self:_getBorderMotifColors(elem, motif, pos, diceColor)
        if not border_alternation_valid(pair, colors) then
            meta.border_break = true
        end
        return true, nil, meta
    end

    if element == "MINIATURE" then
        if meta.is_gold then
            local gold_count = 0
            for i = 1, elem.cells_total do
                local placed = self:_getEffectivePlacement(elem, i)
                if placed and placed.color == "GIALLO" then
                    gold_count = gold_count + 1
                end
            end
            if gold_count >= 1 then
                return false, "Miniature allows only one gold die", meta
            end
        end
        return true, nil, meta
    end

    -- DROPCAPS: tutti i colori legali.
    return true, nil, meta
end

function Folio:_canPlaceWithMeta(element, row, col, diceValue, diceColor)
    local elem = self.elements[element]
    if not elem then
        return false, "Invalid element", nil
    end

    local color = diceColor or VALUE_TO_COLOR[diceValue]
    if not color then
        return false, "Invalid die color", nil
    end

    local forbidden = self.rule_effects and self.rule_effects.forbid_colors or nil
    if forbidden and forbidden[color] then
        return false, string.format("%s is forbidden in this commission", tostring(color)), nil
    end

    if not elem.unlocked then
        return false, "Locked", nil
    end

    if elem.completed then
        return false, "Already completed", nil
    end

    local pattern = elem.pattern
    if row < 1 or row > pattern.rows or col < 1 or col > pattern.cols then
        return false, "Out of bounds", nil
    end

    local index = Patterns.rowColToIndex(pattern, row, col)
    if elem.placed[index] or elem.wet[index] then
        return false, "Occupied", nil
    end

    if not (self.rule_effects and self.rule_effects.ignore_pattern_constraints) then
        local can_place_pattern, pattern_reason = Patterns.canPlace(pattern, row, col, diceValue, color)
        if not can_place_pattern then
            return false, pattern_reason, nil
        end
    end

    local can_place_section, section_reason, meta = self:_validateSectionRules(element, row, col, diceValue, color)
    if not can_place_section then
        return false, section_reason, meta
    end

    meta = meta or {}
    meta.index = index
    meta.color = color
    return true, nil, meta
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
    local ok, reason = self:_canPlaceWithMeta(element, row, col, diceValue, diceColor)
    return ok, reason
end

--- Piazza un dado direttamente in permanente (legacy path).
---@param element string
---@param row number
---@param col number
---@param diceValue number
---@param diceColor string
---@param pigmentName? string
---@return boolean success
---@return string message
function Folio:placeDie(element, row, col, diceValue, diceColor, pigmentName)
    local ok, reason, meta = self:_canPlaceWithMeta(element, row, col, diceValue, diceColor)
    if not ok or not meta then
        return false, reason or "Cannot place die"
    end

    local color = meta.color or diceColor or VALUE_TO_COLOR[diceValue]

    local elem = self.elements[element]
    if element == "BORDERS" and meta and meta.border_motif and meta.border_pair and not elem.motif_pairs[meta.border_motif] then
        elem.motif_pairs[meta.border_motif] = {meta.border_pair[1], meta.border_pair[2]}
    end

    elem.placed[meta.index] = {
        value = diceValue,
        color = color,
        pigment = pigmentName,
        wet = false,
    }
    elem.cells_filled = elem.cells_filled + 1
    if elem.cells_filled >= elem.cells_total and not elem.completed then
        elem.completed = true
        self:onElementCompleted(element)
    end

    self.quality = self:calculateQuality()
    return true, string.format("%s: placed %s (%d) at [%d,%d]", element, color, diceValue, row, col)
end

--- Aggiunge un piazzamento al wet buffer del turno corrente.
---@return boolean success
---@return string message
---@return table|nil placement
function Folio:addWetDie(element, row, col, diceValue, diceColor, pigmentName)
    local ok, reason, meta = self:_canPlaceWithMeta(element, row, col, diceValue, diceColor)
    if not ok or not meta then
        return false, reason or "Cannot queue die", nil
    end

    local color = meta.color or diceColor or VALUE_TO_COLOR[diceValue]

    local elem = self.elements[element]
    if element == "BORDERS" and meta and meta.border_motif and meta.border_pair and not elem.motif_pairs[meta.border_motif] then
        elem.motif_pairs[meta.border_motif] = {meta.border_pair[1], meta.border_pair[2]}
    end

    local placement = {
        element = element,
        row = row,
        col = col,
        index = meta.index,
        value = diceValue,
        color = color,
        pigment = pigmentName,
        wet = true,
        border_break = (meta and meta.border_break) and true or false,
        is_gold = (meta and meta.is_gold) and true or false,
        rubric = (element == "TEXT" and color == "ROSSO"),
    }

    elem.wet[placement.index] = placement
    self.wet_buffer[#self.wet_buffer + 1] = placement

    if placement.is_gold then
        self.turn_risk = self.turn_risk + 1
    end
    if placement.border_break then
        self.turn_risk = self.turn_risk + 1
    end
    local risk_on_color = self.rule_effects and self.rule_effects.risk_on_color or nil
    local risk_on_value = self.rule_effects and self.rule_effects.risk_on_value or nil
    local risk_on_section = self.rule_effects and self.rule_effects.risk_on_section or nil
    if risk_on_color and risk_on_color[placement.color] then
        self.turn_risk = self.turn_risk + (risk_on_color[placement.color] or 0)
    end
    if risk_on_value and risk_on_value[placement.value] then
        self.turn_risk = self.turn_risk + (risk_on_value[placement.value] or 0)
    end
    if risk_on_section and risk_on_section[placement.element] then
        self.turn_risk = self.turn_risk + (risk_on_section[placement.element] or 0)
    end
    local wet_threshold = 4 + (self.rule_effects and self.rule_effects.safe_wet_threshold_bonus or 0)
    if (not self.turn_flags.over_four) and #self.wet_buffer > wet_threshold then
        self.turn_flags.over_four = true
        self.turn_risk = self.turn_risk + 1
    end

    return true, "Queued in wet buffer", placement
end

function Folio:registerPush(mode)
    self.turn_pushes = self.turn_pushes + 1
    local push_risk_always = self.rule_effects and self.rule_effects.push_risk_always or nil
    if push_risk_always and push_risk_always > 0 then
        self.turn_risk = self.turn_risk + push_risk_always
    end
    if self.push_risk_enabled and self.turn_pushes > 1 then
        self.turn_risk = self.turn_risk + 1
    end
    self.last_push_mode = mode or "all"
end

function Folio:getWetCount()
    return #self.wet_buffer
end

function Folio:getTurnRisk()
    return self.turn_risk
end

function Folio:getPreparationGuard()
    return self.preparation_guard or 0
end

function Folio:canUsePreparation()
    return not self.turn_flags.preparation_used
end

function Folio:applyPreparation(mode)
    if self.turn_flags.preparation_used then
        return false, "Preparation already used this turn"
    end
    local m = mode or "risk"
    if m == "risk" then
        self.turn_risk = math.max(0, self.turn_risk - 1)
    else
        self.preparation_guard = (self.preparation_guard or 0) + 1
    end
    self.turn_flags.preparation_used = true
    return true, (m == "risk") and "Risk reduced by 1" or "Stored 1 stain guard"
end

function Folio:getRuleCards()
    return self.rule_cards or {}
end

function Folio:getRuleEffects()
    return self.rule_effects or {}
end

function Folio:getToolUsesLeft()
    return self.tool_uses_left or 0
end

function Folio:canUseTool(id)
    if not self.rule_cards or not self.rule_cards.tool then
        return false
    end
    if id and self.rule_cards.tool.id ~= id then
        return false
    end
    return (self.tool_uses_left or 0) > 0
end

function Folio:consumeToolUse(id)
    if not self:canUseTool(id) then
        return false
    end
    self.tool_uses_left = math.max(0, (self.tool_uses_left or 0) - 1)
    return true
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
    local placed = self:_getEffectivePlacement(elem, index)
    
    return {
        row = row,
        col = col,
        constraint = constraint,
        placed = placed,
        wet = placed and placed.wet or false,
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

function Folio:_borderMotifHasPermanent(elem, motif)
    local pattern = elem.pattern
    for row = 1, pattern.rows do
        for col = 1, pattern.cols do
            local m = self:_getBorderMotifPos(pattern, row, col)
            if m == motif then
                local idx = Patterns.rowColToIndex(pattern, row, col)
                if elem.placed[idx] then
                    return true
                end
            end
        end
    end
    return false
end

function Folio:_borderMotifHasWet(elem, motif)
    local pattern = elem.pattern
    for row = 1, pattern.rows do
        for col = 1, pattern.cols do
            local m = self:_getBorderMotifPos(pattern, row, col)
            if m == motif then
                local idx = Patterns.rowColToIndex(pattern, row, col)
                if elem.wet[idx] then
                    return true
                end
            end
        end
    end
    return false
end

function Folio:_pruneBorderMotifPairs()
    local elem = self.elements.BORDERS
    if not elem or not elem.motif_pairs then
        return
    end
    for motif, _ in pairs(elem.motif_pairs) do
        local keep = self:_borderMotifHasPermanent(elem, motif) or self:_borderMotifHasWet(elem, motif)
        if not keep then
            elem.motif_pairs[motif] = nil
        end
    end
end

function Folio:hasAnyLegalPlacement(dice_values)
    if not dice_values then
        return false
    end
    for _, die in ipairs(dice_values) do
        local value = (type(die) == "table") and die.value or die
        local color = (type(die) == "table") and die.color or VALUE_TO_COLOR[value]
        if value and color then
            local all = self:getAllValidPlacements(value, color)
            if next(all) ~= nil then
                return true
            end
        end
    end
    return false
end

function Folio:getWetSummary()
    local counts = {}
    for _, elem in ipairs(Folio.ELEMENTS) do
        counts[elem] = 0
    end
    for _, entry in ipairs(self.wet_buffer) do
        counts[entry.element] = (counts[entry.element] or 0) + 1
    end
    return {
        count = #self.wet_buffer,
        risk = self.turn_risk,
        pushes = self.turn_pushes,
        section_counts = counts,
    }
end

function Folio:discardWetBuffer()
    if #self.wet_buffer == 0 then
        self.turn_risk = 0
        self.turn_pushes = 0
        self.turn_flags.over_four = false
        self.turn_flags.preparation_used = false
        return 0
    end

    local removed = 0
    for _, entry in ipairs(self.wet_buffer) do
        local elem = self.elements[entry.element]
        if elem and elem.wet[entry.index] then
            elem.wet[entry.index] = nil
            removed = removed + 1
        end
    end

    self.wet_buffer = {}
    self.turn_risk = 0
    self.turn_pushes = 0
    self.turn_flags.over_four = false
    self.turn_flags.preparation_used = false
    self:_pruneBorderMotifPairs()
    return removed
end

function Folio:commitWetBuffer()
    if #self.wet_buffer == 0 then
        return {
            committed = 0,
            stains_added = 0,
            wettest_section = nil,
            still_wet = 0,
        }
    end

    local section_counts = {}
    local touched = {}
    local committed = 0
    local committed_entries = {}

    for _, entry in ipairs(self.wet_buffer) do
        local elem = self.elements[entry.element]
        if elem and elem.wet[entry.index] then
            elem.wet[entry.index] = nil
            entry.wet = false
            elem.placed[entry.index] = entry
            elem.cells_filled = elem.cells_filled + 1
            touched[entry.element] = true
            section_counts[entry.element] = (section_counts[entry.element] or 0) + 1
            committed = committed + 1
            committed_entries[#committed_entries + 1] = entry
        end
    end

    self.wet_buffer = {}

    local keep_wet = 0
    local first_stop_wet_left = self.rule_effects and self.rule_effects.first_stop_wet_left or 0
    if (not self.first_stop_done) and first_stop_wet_left and first_stop_wet_left > 0 then
        keep_wet = math.min(first_stop_wet_left, #committed_entries)
        self.first_stop_done = true
        for _ = 1, keep_wet do
            local entry = table.remove(committed_entries)
            if entry then
                local elem = self.elements[entry.element]
                if elem and elem.placed[entry.index] then
                    elem.placed[entry.index] = nil
                    elem.wet[entry.index] = entry
                    entry.wet = true
                    elem.cells_filled = math.max(0, elem.cells_filled - 1)
                    self.wet_buffer[#self.wet_buffer + 1] = entry
                    section_counts[entry.element] = math.max(0, (section_counts[entry.element] or 0) - 1)
                    committed = math.max(0, committed - 1)
                end
            end
        end
    end

    local effective_risk = self.turn_risk
    local stop_risk_reduction = self.rule_effects and self.rule_effects.stop_risk_reduction or 0
    if stop_risk_reduction > 0 and effective_risk > 0 then
        effective_risk = math.max(0, effective_risk - stop_risk_reduction)
    end
    local tool_stop_reduction = self.rule_effects and self.rule_effects.tool_stop_risk_reduction or 0
    if tool_stop_reduction > 0 and effective_risk > 0 and (self.tool_uses_left or 0) > 0 then
        local reduction = math.min(tool_stop_reduction, effective_risk)
        effective_risk = effective_risk - reduction
        self.tool_uses_left = math.max(0, (self.tool_uses_left or 0) - 1)
    end

    local stains_added = math.floor(effective_risk / 2)
    self.turn_risk = 0
    self.turn_pushes = 0
    self.turn_flags.over_four = false
    self.turn_flags.preparation_used = false

    for element, _ in pairs(touched) do
        local elem = self.elements[element]
        if elem and (not elem.completed) and elem.cells_filled >= elem.cells_total then
            elem.completed = true
            self:onElementCompleted(element)
        end
    end

    local wettest_section = nil
    local wettest_count = -1
    for _, elem in ipairs(Folio.ELEMENTS) do
        local c = section_counts[elem] or 0
        if c > wettest_count then
            wettest_count = c
            wettest_section = elem
        end
    end
    if wettest_count <= 0 then
        wettest_section = nil
    end

    self:_pruneBorderMotifPairs()

    if stains_added > 0 then
        self:addStain(stains_added)
        if wettest_section then
            self.section_stains[wettest_section] = (self.section_stains[wettest_section] or 0) + stains_added
        end
    end

    self.quality = self:calculateQuality()

    return {
        committed = committed,
        stains_added = stains_added,
        wettest_section = wettest_section,
        still_wet = keep_wet,
    }
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

    -- Preparation guard ignores future stains (anti-frustration valve).
    if amount > 0 and (self.preparation_guard or 0) > 0 then
        local blocked = math.min(amount, self.preparation_guard)
        self.preparation_guard = self.preparation_guard - blocked
        amount = amount - blocked
        if blocked > 0 then
            log("[Folio] Preparation guard ignored " .. blocked .. " stain(s)")
        end
    end
    if amount <= 0 then
        return false
    end
    
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

function Folio:calculateQuality()
    local quality = 0

    -- TEXT: Nero +2, Marrone +1, Rosso = rubriche; bonus rubriche >=2 e zero macchie sezione
    do
        local elem = self.elements.TEXT
        if elem then
            local rubriche = 0
            for i = 1, elem.cells_total do
                local placed = elem.placed[i]
                if placed then
                    if placed.color == "NERO" then
                        quality = quality + 2
                    elseif placed.color == "MARRONE" then
                        quality = quality + 1
                    elseif placed.color == "ROSSO" then
                        rubriche = rubriche + 1
                    end
                end
            end
            if rubriche >= 2 and (self.section_stains.TEXT or 0) == 0 then
                quality = quality + 3
            end
        end
    end

    -- BORDERS: Oro jolly vale +1 qualità.
    do
        local elem = self.elements.BORDERS
        if elem then
            for i = 1, elem.cells_total do
                local placed = elem.placed[i]
                if placed and placed.color == "GIALLO" then
                    quality = quality + 1
                end
            end
        end
    end

    -- MINIATURE: varietà colori +1 (max +4), adiacenze uguali -1, oro singolo +3 se completa.
    do
        local elem = self.elements.MINIATURE
        if elem then
            local colors = {}
            local has_gold = false
            for i = 1, elem.cells_total do
                local placed = elem.placed[i]
                if placed and placed.color then
                    colors[placed.color] = true
                    if placed.color == "GIALLO" then
                        has_gold = true
                    end
                end
            end

            local distinct = 0
            for _, present in pairs(colors) do
                if present then
                    distinct = distinct + 1
                end
            end
            quality = quality + math.min(4, distinct)

            local rows = elem.pattern.rows
            local cols = elem.pattern.cols
            local mud = 0
            for row = 1, rows do
                for col = 1, cols do
                    local idx = Patterns.rowColToIndex(elem.pattern, row, col)
                    local a = elem.placed[idx]
                    if a and a.color then
                        if col < cols then
                            local right = elem.placed[Patterns.rowColToIndex(elem.pattern, row, col + 1)]
                            if right and right.color == a.color then
                                mud = mud + 1
                            end
                        end
                        if row < rows then
                            local down = elem.placed[Patterns.rowColToIndex(elem.pattern, row + 1, col)]
                            if down and down.color == a.color then
                                mud = mud + 1
                            end
                        end
                    end
                end
            end
            quality = quality - mud

            if has_gold and elem.completed then
                quality = quality + 3
            end
        end
    end

    -- DROPCAPS/CORNERS: Rosso/Blu +2, Oro +3, bonus coppia Rosso+Blu +2.
    do
        local elem = self.elements.DROPCAPS
        if elem then
            local has_red = false
            local has_blue = false
            for i = 1, elem.cells_total do
                local placed = elem.placed[i]
                if placed and placed.color then
                    if placed.color == "ROSSO" then
                        quality = quality + 2
                        has_red = true
                    elseif placed.color == "BLU" then
                        quality = quality + 2
                        has_blue = true
                    elseif placed.color == "GIALLO" then
                        quality = quality + 3
                    end
                end
            end
            if has_red and has_blue then
                quality = quality + 2
            end
        end
    end

    -- Dynamic card modifiers (commission/parchment/tool).
    do
        local quality_per_color = self.rule_effects and self.rule_effects.quality_per_color or nil
        local quality_per_section = self.rule_effects and self.rule_effects.quality_per_section or nil
        if quality_per_color or quality_per_section then
            for _, elem_name in ipairs(Folio.ELEMENTS) do
                local elem = self.elements[elem_name]
                if elem then
                    for i = 1, elem.cells_total do
                        local placed = elem.placed[i]
                        if placed then
                            if quality_per_color and placed.color and quality_per_color[placed.color] then
                                quality = quality + (quality_per_color[placed.color] or 0)
                            end
                            if quality_per_section and quality_per_section[elem_name] then
                                quality = quality + (quality_per_section[elem_name] or 0)
                            end
                        end
                    end
                end
            end
        end
    end

    return quality
end

--- Stato debug
function Folio:getStatus()
    local cards = self:getRuleCards()
    local status = {
        fascicolo = self.fascicolo,
        stains = string.format("%d/%d", self.stain_count, self.stain_threshold),
        shield = self.shield,
        quality = self.quality,
        wet = #self.wet_buffer,
        risk = self.turn_risk,
        busted = self.busted,
        completed = self.completed,
        border_parity = self.border_parity,
        preparation_guard = self.preparation_guard or 0,
        tool_uses_left = self.tool_uses_left or 0,
        cards = {
            commission = cards.commission and cards.commission.name or nil,
            parchment = cards.parchment and cards.parchment.name or nil,
            tool = cards.tool and cards.tool.name or nil,
        },
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
    log(string.format("Stains: %d/%d | Shield: %d | Quality: %d | Wet: %d | Risk: %d | Busted: %s | Completed: %s",
        self.stain_count, self.stain_threshold, self.shield, self.quality,
        #self.wet_buffer, self.turn_risk, tostring(self.busted), tostring(self.completed)))
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
                    local placed = state and state.placed or nil
                    local constraint = state and state.constraint or nil
                    if placed and placed.color and placed.value then
                        line = line .. string.format("[%s%s]",
                            tostring(placed.color):sub(1,1), tostring(placed.value))
                    elseif constraint then
                        if type(constraint) == "number" then
                            line = line .. string.format("( %d )", constraint)
                        else
                            line = line .. string.format("(%s)", tostring(constraint):sub(1,3))
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
    self.rule_setup = MVPDecks.draw_run_setup(self.seed + 101)
    
    -- Stato run
    self.current_folio_index = 1
    self.current_folio = Folio.new(self.fascicolo, self.seed + 1, self.rule_setup)
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
        self.current_folio = Folio.new(self.fascicolo, self.seed + self.current_folio_index, self.rule_setup)
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
        self.current_folio = Folio.new(self.fascicolo, self.seed + self.current_folio_index + 1000, self.rule_setup)
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
    local cards = self.rule_setup and self.rule_setup.cards or {}
    return {
        fascicolo = self.fascicolo,
        folio = string.format("%d/%d", self.current_folio_index, self.total_folii),
        reputation = self.reputation,
        coins = self.coins,
        seed = self.seed,
        game_over = self.game_over,
        victory = self.victory,
        cards = {
            commission = cards.commission and cards.commission.name or nil,
            parchment = cards.parchment and cards.parchment.name or nil,
            tool = cards.tool and cards.tool.name or nil,
        },
    }
end

-- Esporta sia Folio che Run
return {
    Folio = Folio,
    Run = Run,
}

