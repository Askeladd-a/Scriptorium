
local Patterns = require("src.content.patterns")
local MVPDecks = require("src.content.mvp_decks")
local FolioTurn = require("src.domain.folio.turn")

local Folio = {}
Folio.__index = Folio

Folio.ELEMENTS = {"TEXT", "DROPCAPS", "BORDERS", "MINIATURE"}

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

---@param folio_set_type string Folio set type (BIFOLIO, DUERNO, etc.)
---@param seed? number Seed for reproducible pattern selection
---@param run_setup? table Run card/effect setup
---@return table Folio instance
function Folio.new(folio_set_type, seed, run_setup)
    local self = setmetatable({}, Folio)
    
    self.folio_set = folio_set_type or "BIFOLIO"
    self.seed = seed or os.time()

    run_setup = run_setup or MVPDecks.drawRunSetup(self.seed + 77)
    self.run_setup = run_setup
    self.rule_cards = run_setup.cards or {}
    self.rule_effects = run_setup.effects or {}
    self.border_parity = self.rule_effects.force_borders_parity or get_border_parity(self.seed)
    
    local pattern_set = Patterns.getRandomPatternSet(self.seed)
    
    self.elements = {}
    for _, elem in ipairs(Folio.ELEMENTS) do
        local pattern = pattern_set[elem]
        local total_cells = pattern.rows * pattern.cols
        
        self.elements[elem] = {
            pattern = pattern,
            placed = {},
            wet = {},
            cells_filled = 0,
            cells_total = total_cells,
            unlocked = (elem == "TEXT"),
            completed = false,
            motif_pairs = (elem == "BORDERS") and {} or nil,
        }
        
        for i = 1, total_cells do
            self.elements[elem].placed[i] = nil
        end
    end
    
    self.stain_count = 0
    self.stain_threshold = self:getStainThreshold()
    self.shield = 0

    self.wet_buffer = {}
    self.turn_risk = 0
    self.turn_pushes = 0
    self.turn_flags = {
        over_four = false,
        preparation_used = false,
    }
    self.push_risk_enabled = false
    self.preparation_guard = (self.rule_effects.tool_bonus_guard or 0)
    self.first_stop_done = false
    self.tool_uses_left = (self.rule_cards.tool and self.rule_cards.tool.uses_per_folio) or 0

    self.quality = 0
    self.section_stains = {}
    for _, elem in ipairs(Folio.ELEMENTS) do
        self.section_stains[elem] = 0
    end
    
    self.busted = false
    self.completed = false
    
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
    return thresholds[self.folio_set] or 7
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

function Folio:_validateSectionRules(element, row, col, dice_value, dice_color)
    local elem = self.elements[element]
    local meta = {
        border_break = false,
        border_motif = nil,
        border_pair = nil,
        is_gold = (dice_color == "GIALLO" or dice_value == 6),
    }

    if self.rule_effects and self.rule_effects.simple_sections then
        if element == "TEXT" then
            if dice_value < 1 or dice_value > 3 then
                return false, "Text accepts only 1-3", meta
            end
            return true, nil, meta
        end

        if element == "DROPCAPS" then
            if dice_value < 4 or dice_value > 6 then
                return false, "Dropcaps accepts only 4-6", meta
            end
            return true, nil, meta
        end

        if element == "BORDERS" then
            local parity_even = (self.border_parity == "EVEN")
            local is_even = (dice_value % 2) == 0
            if parity_even and not is_even then
                return false, "Borders accepts only even values in this folio", meta
            end
            if (not parity_even) and is_even then
                return false, "Borders accepts only odd values in this folio", meta
            end
            return true, nil, meta
        end

        return true, nil, meta
    end

    if element == "TEXT" then
        if not TEXT_ALLOWED_COLORS[dice_color] then
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
            pair = self:_getBorderPairForColor(dice_color)
            meta.border_pair = {pair[1], pair[2]}
        end

        local colors = self:_getBorderMotifColors(elem, motif, pos, dice_color)
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

    return true, nil, meta
end

function Folio:_canPlaceWithMeta(element, row, col, dice_value, dice_color)
    local elem = self.elements[element]
    if not elem then
        return false, "Invalid element", nil
    end

    local color = dice_color or VALUE_TO_COLOR[dice_value]
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
        local can_place_pattern, pattern_reason = Patterns.canPlace(pattern, row, col, dice_value, color)
        if not can_place_pattern then
            return false, pattern_reason, nil
        end
    end

    local can_place_section, section_reason, meta = self:_validateSectionRules(element, row, col, dice_value, color)
    if not can_place_section then
        return false, section_reason, meta
    end

    meta = meta or {}
    meta.index = index
    meta.color = color
    return true, nil, meta
end

---@param element string
---@param row number
---@param col number
---@param dice_value number
---@param dice_color string
---@return boolean canPlace
---@return string|nil reason
function Folio:canPlaceDie(element, row, col, dice_value, dice_color)
    local ok, reason = self:_canPlaceWithMeta(element, row, col, dice_value, dice_color)
    return ok, reason
end

---@param element string
---@param row number
---@param col number
---@param dice_value number
---@param dice_color string
---@param pigment_name? string
---@return boolean success
---@return string message
function Folio:placeDie(element, row, col, dice_value, dice_color, pigment_name)
    local ok, reason, meta = self:_canPlaceWithMeta(element, row, col, dice_value, dice_color)
    if not ok or not meta then
        return false, reason or "Cannot place die"
    end

    local color = meta.color or dice_color or VALUE_TO_COLOR[dice_value]

    local elem = self.elements[element]
    if element == "BORDERS" and meta and meta.border_motif and meta.border_pair and not elem.motif_pairs[meta.border_motif] then
        elem.motif_pairs[meta.border_motif] = {meta.border_pair[1], meta.border_pair[2]}
    end

    elem.placed[meta.index] = {
        value = dice_value,
        color = color,
        pigment = pigment_name,
        wet = false,
    }
    elem.cells_filled = elem.cells_filled + 1
    if elem.cells_filled >= elem.cells_total and not elem.completed then
        elem.completed = true
        self:onElementCompleted(element)
    end

    self.quality = self:calculateQuality()
    return true, string.format("%s: placed %s (%d) at [%d,%d]", element, color, dice_value, row, col)
end

---@return boolean success
---@return string message
---@return table|nil placement
function Folio:addWetDie(element, row, col, dice_value, dice_color, pigment_name)
    local ok, reason, meta = self:_canPlaceWithMeta(element, row, col, dice_value, dice_color)
    if not ok or not meta then
        return false, reason or "Cannot queue die", nil
    end

    local color = meta.color or dice_color or VALUE_TO_COLOR[dice_value]

    local elem = self.elements[element]
    if element == "BORDERS" and meta and meta.border_motif and meta.border_pair and not elem.motif_pairs[meta.border_motif] then
        elem.motif_pairs[meta.border_motif] = {meta.border_pair[1], meta.border_pair[2]}
    end

    local placement = {
        element = element,
        row = row,
        col = col,
        index = meta.index,
        value = dice_value,
        color = color,
        pigment = pigment_name,
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

---@param element string
---@return table[] Cell state list
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

---@param element string
---@param dice_value number
---@param dice_color string
---@return table[] Valid {row, col} positions
function Folio:getValidPlacements(element, dice_value, dice_color)
    local elem = self.elements[element]
    if not elem or not elem.unlocked or elem.completed then
        return {}
    end
    
    local valid = {}
    for row = 1, elem.pattern.rows do
        for col = 1, elem.pattern.cols do
            local can_place = self:canPlaceDie(element, row, col, dice_value, dice_color)
            if can_place then
                table.insert(valid, {row = row, col = col})
            end
        end
    end
    return valid
end

---@param dice_value number
---@param dice_color string
---@return table {element = {{row,col}, ...}, ...}
function Folio:getAllValidPlacements(dice_value, dice_color)
    local result = {}
    for _, elem in ipairs(Folio.ELEMENTS) do
        local placements = self:getValidPlacements(elem, dice_value, dice_color)
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

function Folio:onElementCompleted(element)
    log("[Folio] Completed: " .. element)
    
    local idx = nil
    for i, elem in ipairs(Folio.ELEMENTS) do
        if elem == element then idx = i break end
    end
    if idx and idx < #Folio.ELEMENTS then
        local next_elem = Folio.ELEMENTS[idx + 1]
        self.elements[next_elem].unlocked = true
        log("[Folio] Unlocked: " .. next_elem)
    end
    
    local bonus = Folio.BONUS[element]
    if bonus and bonus.shield then
        self.shield = self.shield + bonus.shield
    end
    
    if self.elements.TEXT.completed and self.elements.MINIATURE.completed then
        self.completed = true
        log("[Folio] FOLIO COMPLETED!")
    end
end

---@param amount number Number of stains (default 1)
---@return boolean busted True when stain threshold is reached
function Folio:addStain(amount)
    amount = amount or 1

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
    
    if self.stain_count >= self.stain_threshold then
        self.busted = true
        log("[Folio] BUST! Too many stains!")
        return true
    end
    
    return false
end

function Folio:removeStain(amount)
    amount = amount or 1
    self.stain_count = math.max(0, self.stain_count - amount)
    log(string.format("[Folio] Stain removed. Now: %d/%d", self.stain_count, self.stain_threshold))
end

function Folio:calculateQuality()
    local quality = 0

    do
        local elem = self.elements.TEXT
        if elem then
            local rubrics = 0
            for i = 1, elem.cells_total do
                local placed = elem.placed[i]
                if placed then
                    if placed.color == "NERO" then
                        quality = quality + 2
                    elseif placed.color == "MARRONE" then
                        quality = quality + 1
                    elseif placed.color == "ROSSO" then
                        rubrics = rubrics + 1
                    end
                end
            end
            if rubrics >= 2 and (self.section_stains.TEXT or 0) == 0 then
                quality = quality + 3
            end
        end
    end

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

function Folio:getStatus()
    local cards = self:getRuleCards()
    local status = {
        folio_set = self.folio_set,
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

function Folio:debugPrint()
    log("\n" .. string.rep("═", 60))
    log("FOLIO: " .. tostring(self.folio_set))
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

Folio.registerPush = FolioTurn.registerPush
Folio.getWetCount = FolioTurn.getWetCount
Folio.getTurnRisk = FolioTurn.getTurnRisk
Folio.getPreparationGuard = FolioTurn.getPreparationGuard
Folio.canUsePreparation = FolioTurn.canUsePreparation
Folio.applyPreparation = FolioTurn.applyPreparation
Folio.getRuleCards = FolioTurn.getRuleCards
Folio.getRuleEffects = FolioTurn.getRuleEffects
Folio.getToolUsesLeft = FolioTurn.getToolUsesLeft
Folio.canUseTool = FolioTurn.canUseTool
Folio.consumeToolUse = FolioTurn.consumeToolUse
Folio.getWetSummary = FolioTurn.getWetSummary
Folio.discardWetBuffer = FolioTurn.discardWetBuffer
Folio.commitWetBuffer = FolioTurn.commitWetBuffer

return Folio

