local FolioTurn = require("src.gameplay.folio.turn")
local WindowPatterns = require("src.gameplay.folio.window_patterns")

local Folio = {}
Folio.__index = Folio

Folio.ELEMENTS = {"TEXT"}

Folio.BONUS = {
    TEXT = {coins = 20, reputation = 1},
}

local GRID_ROWS = 4
local GRID_COLS = 5

local VALUE_TO_COLOR = {
    [1] = "MARRONE",
    [2] = "VERDE",
    [3] = "NERO",
    [4] = "ROSSO",
    [5] = "BLU",
    [6] = "GIALLO",
}

local COLOR_ALIASES = {
    RED = "ROSSO",
    BLUE = "BLU",
    GREEN = "VERDE",
    YELLOW = "GIALLO",
    PURPLE = "VIOLA",
    BLACK = "NERO",
    BROWN = "MARRONE",
    WHITE = "BIANCO",
}

local function random_int(min_v, max_v)
    local rnd = (love and love.math and love.math.random) or math.random
    return rnd(min_v, max_v)
end

local function row_col_to_index(pattern, row, col)
    return (row - 1) * pattern.cols + col
end

local function index_to_row_col(pattern, index)
    local row = math.floor((index - 1) / pattern.cols) + 1
    local col = ((index - 1) % pattern.cols) + 1
    return row, col
end

local function shallow_copy_array(values)
    local out = {}
    for i = 1, #values do
        out[i] = values[i]
    end
    return out
end

local function normalize_color_key(color)
    if type(color) ~= "string" then
        return nil
    end
    local key = color:upper()
    return COLOR_ALIASES[key] or key
end

local function normalize_constraint(constraint)
    local numeric = tonumber(constraint)
    if numeric then
        numeric = math.floor(numeric)
        if numeric >= 1 and numeric <= 6 then
            return numeric
        end
        return nil
    end
    return normalize_color_key(constraint)
end

local function build_ink_bag(pattern)
    local set = {}
    local bag = {}
    local common = WindowPatterns.getCommonColors()

    for _, c in ipairs(pattern.grid or {}) do
        if type(c) == "string" then
            local key = normalize_color_key(c)
            if key and not set[key] then
                set[key] = true
                bag[#bag + 1] = key
            end
        end
    end

    for _, c in ipairs(common) do
        if #bag >= 3 then
            break
        end
        if not set[c] then
            set[c] = true
            bag[#bag + 1] = c
        end
    end

    return bag
end

local function get_pattern_from_windows(seed)
    local picked = WindowPatterns.pick(seed)
    picked.rows = GRID_ROWS
    picked.cols = GRID_COLS
    for i = 1, GRID_ROWS * GRID_COLS do
        picked.grid[i] = normalize_constraint(picked.grid[i])
    end
    return picked
end

---@param folio_set_type string
---@param seed? number
---@param run_setup? table
---@return table
function Folio.new(folio_set_type, seed, run_setup)
    local self = setmetatable({}, Folio)

    self.folio_set = folio_set_type or "BIFOLIO"
    self.seed = tonumber(seed) or os.time()
    self.run_setup = run_setup or {cards = {}, effects = {}}
    self.rule_cards = self.run_setup.cards or {}
    self.rule_effects = self.run_setup.effects or {}

    self.objective = {
        kind = "fill_cells",
        target = 15,
    }

    local pattern = get_pattern_from_windows(self.seed)
    local total_cells = (pattern.rows or GRID_ROWS) * (pattern.cols or GRID_COLS)

    self.elements = {
        TEXT = {
            pattern = pattern,
            placed = {},
            wet = {},
            stained = {},
            cells_filled = 0,
            cells_total = total_cells,
            unlocked = true,
            completed = false,
        },
    }

    for i = 1, total_cells do
        self.elements.TEXT.placed[i] = nil
        self.elements.TEXT.wet[i] = nil
        self.elements.TEXT.stained[i] = nil
    end

    self.active_element = "TEXT"
    self.ink_bag = build_ink_bag(pattern)

    self.stain_count = 0
    self.stain_threshold = self:getStainThreshold()
    self.busted = false

    self.wet_buffer = {}
    self.turn_risk = 0
    self.turn_pushes = 0
    self.turn_flags = {}
    self.turn_count = 0
    self.bust_count = 0
    self.turn_palette = nil

    self.quality = 0
    self.completed = false

    self.shield = 0
    self.preparation_guard = 0
    self.tool_uses_left = 0
    self.seals = 0

    return self
end

function Folio:getStainThreshold()
    local thresholds = {
        BIFOLIO = 5,
        DUERNO = 6,
        TERNIONE = 6,
        QUATERNIONE = 7,
        QUINTERNO = 7,
        SESTERNO = 8,
    }
    return thresholds[self.folio_set] or 6
end

function Folio:getPatternName()
    local elem = self.elements[self.active_element]
    return elem and elem.pattern and elem.pattern.name or "Window"
end

function Folio:getPatternToken()
    local elem = self.elements[self.active_element]
    return elem and elem.pattern and (elem.pattern.token or 0) or 0
end

function Folio:getObjectiveProgress()
    local elem = self.elements[self.active_element]
    local filled = elem and (elem.cells_filled or 0) or 0
    local target = self.objective and self.objective.target or 15
    return filled, target
end

function Folio:_resolveElement(element)
    local key = element or self.active_element
    local elem = self.elements[key]
    return key, elem
end

function Folio:_normalizePlacementColor(dice_value, dice_color)
    local color = normalize_color_key(dice_color)
    if color then
        return color
    end
    return VALUE_TO_COLOR[dice_value]
end

function Folio:_canPlaceInBounds(pattern, row, col)
    if row < 1 or col < 1 then
        return false
    end
    if row > (pattern.rows or GRID_ROWS) or col > (pattern.cols or GRID_COLS) then
        return false
    end
    return true
end

function Folio:_matchesConstraint(constraint, dice_value, dice_color)
    if constraint == nil then
        return true, nil
    end
    if type(constraint) == "number" then
        if dice_value == constraint then
            return true, nil
        end
        return false, string.format("Requires value %d", constraint)
    end
    if type(constraint) == "string" then
        if dice_color == constraint then
            return true, nil
        end
        return false, "Requires color " .. tostring(constraint)
    end
    return false, "Invalid constraint"
end

function Folio:_hasCommittedOrthogonalValue(elem, row, col, dice_value)
    local pattern = elem.pattern
    local neighbors = {
        {row - 1, col},
        {row + 1, col},
        {row, col - 1},
        {row, col + 1},
    }
    for _, cell in ipairs(neighbors) do
        local r = cell[1]
        local c = cell[2]
        if self:_canPlaceInBounds(pattern, r, c) then
            local idx = row_col_to_index(pattern, r, c)
            local placed = elem.placed[idx]
            if placed and placed.value == dice_value then
                return true
            end
        end
    end
    return false
end

function Folio:_canPlaceWithMeta(element, row, col, dice_value, dice_color)
    local key, elem = self:_resolveElement(element)
    if not elem then
        return false, "Invalid element", nil
    end
    if self.completed then
        return false, "Folio completed", nil
    end
    if self.busted then
        return false, "Folio busted", nil
    end
    if not elem.unlocked then
        return false, "Locked", nil
    end

    local value = tonumber(dice_value)
    if not value then
        return false, "Invalid die value", nil
    end
    value = math.floor(value)
    if value < 1 or value > 6 then
        return false, "Invalid die value", nil
    end

    local color = self:_normalizePlacementColor(value, dice_color)
    if not color then
        return false, "Invalid die color", nil
    end

    local pattern = elem.pattern
    if not self:_canPlaceInBounds(pattern, row, col) then
        return false, "Out of bounds", nil
    end

    local index = row_col_to_index(pattern, row, col)
    if elem.stained and elem.stained[index] then
        return false, "Cell is stained", nil
    end
    if elem.placed[index] or elem.wet[index] then
        return false, "Occupied", nil
    end

    local constraint = pattern.grid and pattern.grid[index] or nil
    local ok_constraint, reason = self:_matchesConstraint(constraint, value, color)
    if not ok_constraint then
        return false, reason, nil
    end

    if self:_hasCommittedOrthogonalValue(elem, row, col, value) then
        return false, "Adjacent committed value conflict", nil
    end

    return true, nil, {
        element = key,
        row = row,
        col = col,
        index = index,
        value = value,
        color = color,
    }
end

function Folio:canPlaceDie(element, row, col, dice_value, dice_color)
    local ok, reason = self:_canPlaceWithMeta(element, row, col, dice_value, dice_color)
    return ok, reason
end

function Folio:_applyCommittedPlacement(entry)
    local key, elem = self:_resolveElement(entry.element)
    if not elem then
        return false
    end
    local placement = {
        element = key,
        row = entry.row,
        col = entry.col,
        index = entry.index,
        value = entry.value,
        color = entry.color,
        pigment = entry.pigment,
        wet = false,
    }
    if elem.placed[placement.index] then
        return false
    end
    elem.placed[placement.index] = placement
    elem.cells_filled = (elem.cells_filled or 0) + 1
    return true
end

function Folio:_updateCompletionState()
    local elem = self.elements[self.active_element]
    local filled = elem and (elem.cells_filled or 0) or 0
    local target = self.objective and self.objective.target or 15
    if filled >= target then
        elem.completed = true
        self.completed = true
    end
    self.quality = self:calculateQuality()
end

function Folio:placeDie(element, row, col, dice_value, dice_color, pigment_name)
    local ok, reason, meta = self:_canPlaceWithMeta(element, row, col, dice_value, dice_color)
    if not ok or not meta then
        return false, reason or "Cannot place die"
    end

    local entry = {
        element = meta.element,
        row = meta.row,
        col = meta.col,
        index = meta.index,
        value = meta.value,
        color = meta.color,
        pigment = pigment_name,
        wet = false,
    }

    self:_applyCommittedPlacement(entry)
    self:_updateCompletionState()
    return true, "Placed"
end

function Folio:addWetDie(element, row, col, dice_value, dice_color, pigment_name)
    local ok, reason, meta = self:_canPlaceWithMeta(element, row, col, dice_value, dice_color)
    if not ok or not meta then
        return false, reason or "Cannot queue die", nil
    end

    local _, elem = self:_resolveElement(meta.element)
    local placement = {
        element = meta.element,
        row = meta.row,
        col = meta.col,
        index = meta.index,
        value = meta.value,
        color = meta.color,
        pigment = pigment_name,
        wet = true,
    }

    elem.wet[placement.index] = placement
    self.wet_buffer[#self.wet_buffer + 1] = placement

    return true, "Queued in wet buffer", placement, {}
end

function Folio:getCellState(element, row, col)
    local key, elem = self:_resolveElement(element)
    if not elem then
        return nil
    end

    local pattern = elem.pattern
    if not self:_canPlaceInBounds(pattern, row, col) then
        return nil
    end

    local index = row_col_to_index(pattern, row, col)
    local placed = elem.wet[index] or elem.placed[index]
    return {
        element = key,
        row = row,
        col = col,
        constraint = pattern.grid and pattern.grid[index] or nil,
        placed = placed,
        wet = placed and placed.wet or false,
        stained = elem.stained and elem.stained[index] or false,
        unlocked = elem.unlocked,
    }
end

function Folio:getAllCells(element)
    local _, elem = self:_resolveElement(element)
    if not elem then
        return {}
    end

    local out = {}
    for row = 1, elem.pattern.rows do
        for col = 1, elem.pattern.cols do
            out[#out + 1] = self:getCellState(element, row, col)
        end
    end
    return out
end

function Folio:getValidPlacements(element, dice_value, dice_color)
    local key, elem = self:_resolveElement(element)
    if not elem or not elem.unlocked or self.completed or self.busted then
        return {}
    end

    local valid = {}
    for row = 1, elem.pattern.rows do
        for col = 1, elem.pattern.cols do
            local ok = self:canPlaceDie(key, row, col, dice_value, dice_color)
            if ok then
                valid[#valid + 1] = {row = row, col = col}
            end
        end
    end
    return valid
end

function Folio:getAllValidPlacements(dice_value, dice_color)
    local out = {}
    for _, element in ipairs(Folio.ELEMENTS) do
        local placements = self:getValidPlacements(element, dice_value, dice_color)
        if #placements > 0 then
            out[element] = placements
        end
    end
    return out
end

function Folio:getPlacementDecisionPreview(element, row, col, dice_value, dice_color)
    local ok, reason = self:_canPlaceWithMeta(element, row, col, dice_value, dice_color)
    if not ok then
        return {
            can_place = false,
            reason = reason,
            quality_gain = 0,
            risk_gain = 0,
            projected_risk = 0,
            score = 0,
        }
    end

    return {
        can_place = true,
        quality_gain = 1,
        risk_gain = 0,
        projected_risk = 0,
        score = 1,
    }
end

function Folio:pickBestWetPlacement()
    local best = self.wet_buffer[1]
    if not best then
        return nil
    end
    return {
        element = best.element,
        row = best.row,
        col = best.col,
        index = best.index,
        value = best.value,
        color = best.color,
        score = 1,
        quality_gain = 1,
        risk_gain = 0,
    }
end

function Folio:drawTurnPalette(count)
    local target = math.max(1, math.floor(tonumber(count) or 3))
    local bag = self.ink_bag or {}
    local selected = {}
    local seen = {}
    local safety = 128

    while #selected < target and #bag > 0 and safety > 0 do
        local idx = random_int(1, #bag)
        local color = bag[idx]
        if color and not seen[color] then
            seen[color] = true
            selected[#selected + 1] = color
        end
        safety = safety - 1
    end

    if #selected < target then
        local common = WindowPatterns.getCommonColors()
        for _, color in ipairs(common) do
            if #selected >= target then
                break
            end
            if color and not seen[color] then
                seen[color] = true
                selected[#selected + 1] = color
            end
        end
    end

    self.turn_palette = shallow_copy_array(selected)
    return selected
end

function Folio:markTurnStarted(palette)
    self.turn_count = (self.turn_count or 0) + 1
    self.turn_palette = palette and shallow_copy_array(palette) or self.turn_palette
end

function Folio:_blockRandomEmptyCell()
    local elem = self.elements[self.active_element]
    if not elem then
        return nil
    end

    local candidates = {}
    for index = 1, elem.cells_total do
        if (not elem.placed[index]) and (not elem.wet[index]) and (not elem.stained[index]) then
            candidates[#candidates + 1] = index
        end
    end

    if #candidates == 0 then
        return nil
    end

    local picked = candidates[random_int(1, #candidates)]
    elem.stained[picked] = true
    local row, col = index_to_row_col(elem.pattern, picked)
    return {element = self.active_element, row = row, col = col, index = picked}
end

function Folio:addStain(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 1))
    for _ = 1, amount do
        self.stain_count = self.stain_count + 1
        self:_blockRandomEmptyCell()
    end
    if self.stain_count >= self.stain_threshold then
        self.busted = true
        return true
    end
    return false
end

function Folio:removeStain(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 1))
    if amount <= 0 then
        return
    end

    local elem = self.elements[self.active_element]
    if elem then
        local stained_indexes = {}
        for index = 1, elem.cells_total do
            if elem.stained[index] then
                stained_indexes[#stained_indexes + 1] = index
            end
        end
        while amount > 0 and #stained_indexes > 0 do
            local pick = random_int(1, #stained_indexes)
            local idx = stained_indexes[pick]
            elem.stained[idx] = nil
            table.remove(stained_indexes, pick)
            amount = amount - 1
            self.stain_count = math.max(0, self.stain_count - 1)
        end
    end

    if self.stain_count < self.stain_threshold then
        self.busted = false
    end
end

function Folio:hasAnyLegalPlacement(dice_values, palette)
    local list = dice_values or {}
    local colors = palette or self.turn_palette or {}
    if #colors == 0 then
        colors = self:drawTurnPalette(3)
    end

    for _, die in ipairs(list) do
        local value = (type(die) == "table") and die.value or die
        value = tonumber(value)
        if value then
            value = math.floor(value)
            for _, color in ipairs(colors) do
                local placements = self:getValidPlacements(self.active_element, value, color)
                if #placements > 0 then
                    return true
                end
            end
        end
    end
    return false
end

function Folio:hasAnyMove(dice_values, palette)
    return self:hasAnyLegalPlacement(dice_values, palette)
end

function Folio:onElementCompleted(element)
    local _, elem = self:_resolveElement(element)
    if elem then
        elem.completed = true
    end
    self.completed = true
end

function Folio:calculateQuality()
    local elem = self.elements[self.active_element]
    if not elem then
        return 0
    end
    local committed = elem.cells_filled or 0
    return math.max(0, committed * 2 - self.stain_count)
end

function Folio:getCompletionStats()
    return {
        turns = self.turn_count or 0,
        busts = self.bust_count or 0,
        stains = self.stain_count or 0,
    }
end

function Folio:getStatus()
    local elem = self.elements[self.active_element]
    local filled, target = self:getObjectiveProgress()
    return {
        folio_set = self.folio_set,
        stains = string.format("%d/%d", self.stain_count, self.stain_threshold),
        quality = self.quality,
        wet = #self.wet_buffer,
        completed = self.completed,
        busted = self.busted,
        objective = string.format("%d/%d", filled, target),
        pattern = elem and elem.pattern and elem.pattern.name or "Window",
        token = elem and elem.pattern and elem.pattern.token or 0,
    }
end

function Folio:debugPrint()
    if not _G.log then
        return
    end
    local filled, target = self:getObjectiveProgress()
    _G.log(string.format(
        "[Folio] %s | Pattern=%s | Objective=%d/%d | Stains=%d/%d | Wet=%d | Busted=%s | Completed=%s",
        tostring(self.folio_set),
        tostring(self:getPatternName()),
        filled,
        target,
        self.stain_count,
        self.stain_threshold,
        #self.wet_buffer,
        tostring(self.busted),
        tostring(self.completed)
    ))
end

Folio.registerPush = FolioTurn.registerPush
Folio.getWetCount = FolioTurn.getWetCount
Folio.getTurnRisk = FolioTurn.getTurnRisk
Folio.getPreparationGuard = FolioTurn.getPreparationGuard
Folio.canUsePreparation = FolioTurn.canUsePreparation
Folio.applyPreparation = FolioTurn.applyPreparation
Folio.getRuleCards = FolioTurn.getRuleCards
Folio.getRuleEffects = FolioTurn.getRuleEffects
Folio.getToolUsesLeft = FolioTurn.getToolUsesLeft
Folio.getSeals = FolioTurn.getSeals
Folio.canSpendSeal = FolioTurn.canSpendSeal
Folio.spendSeal = FolioTurn.spendSeal
Folio.canUseTool = FolioTurn.canUseTool
Folio.consumeToolUse = FolioTurn.consumeToolUse
Folio.getWetSummary = FolioTurn.getWetSummary
Folio.hasWetPair = FolioTurn.hasWetPair
Folio.tryAwardDoubleSeal = FolioTurn.tryAwardDoubleSeal
Folio.discardWetBuffer = FolioTurn.discardWetBuffer
Folio.salvageWetBufferOnBust = FolioTurn.salvageWetBufferOnBust
Folio.commitWetBuffer = FolioTurn.commitWetBuffer

return Folio
