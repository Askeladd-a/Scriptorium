local FolioTurn = {}

local function reset_turn_flags(self)
    self.turn_risk = 0
    self.turn_pushes = 0
    self.turn_flags = {}
end

function FolioTurn.registerPush(self, _push_mode)
    self.turn_pushes = (self.turn_pushes or 0) + 1
end

function FolioTurn.getWetCount(self)
    return #(self.wet_buffer or {})
end

function FolioTurn.getTurnRisk(self)
    return self.turn_risk or 0
end

function FolioTurn.getPreparationGuard(_self)
    return 0
end

function FolioTurn.canUsePreparation(_self)
    return false
end

function FolioTurn.applyPreparation(_self, _mode)
    return false, "Preparation disabled in MVP"
end

function FolioTurn.getRuleCards(self)
    return self.rule_cards or {}
end

function FolioTurn.getRuleEffects(self)
    return self.rule_effects or {}
end

function FolioTurn.getToolUsesLeft(_self)
    return 0
end

function FolioTurn.getSeals(_self)
    return 0
end

function FolioTurn.canSpendSeal(_self)
    return false
end

function FolioTurn.spendSeal(_self)
    return false
end

function FolioTurn.canUseTool(_self, _id)
    return false
end

function FolioTurn.consumeToolUse(_self, _id)
    return false
end

function FolioTurn.getWetSummary(self)
    local counts = {}
    for _, element in ipairs(self.ELEMENTS or {}) do
        counts[element] = 0
    end
    for _, entry in ipairs(self.wet_buffer or {}) do
        if entry and entry.element then
            counts[entry.element] = (counts[entry.element] or 0) + 1
        end
    end
    return {
        count = #(self.wet_buffer or {}),
        risk = self.turn_risk or 0,
        pushes = self.turn_pushes or 0,
        section_counts = counts,
    }
end

function FolioTurn.hasWetPair(_self)
    return false
end

function FolioTurn.tryAwardDoubleSeal(_self)
    return false
end

function FolioTurn.discardWetBuffer(self)
    if not self.wet_buffer or #self.wet_buffer == 0 then
        reset_turn_flags(self)
        return 0
    end

    local discarded = 0
    for _, entry in ipairs(self.wet_buffer) do
        if entry and entry.element and entry.index then
            local elem = self.elements and self.elements[entry.element] or nil
            if elem and elem.wet and elem.wet[entry.index] then
                elem.wet[entry.index] = nil
                discarded = discarded + 1
            end
        end
    end

    self.wet_buffer = {}
    reset_turn_flags(self)
    return discarded
end

function FolioTurn.salvageWetBufferOnBust(self, _preferred_entry)
    local discarded = self:discardWetBuffer()
    local busted = self:addStain(1)
    self.quality = self:calculateQuality()
    return {
        saved = nil,
        discarded = discarded,
        stains_added = 1,
        busted = busted,
    }
end

function FolioTurn.commitWetBuffer(self)
    if not self.wet_buffer or #self.wet_buffer == 0 then
        return {
            committed = 0,
            stains_added = 0,
            wettest_section = nil,
            still_wet = 0,
        }
    end

    local committed = 0
    for _, entry in ipairs(self.wet_buffer) do
        local elem = self.elements and self.elements[entry.element] or nil
        if elem and elem.wet and elem.wet[entry.index] then
            elem.wet[entry.index] = nil
            entry.wet = false
            if not elem.placed[entry.index] then
                elem.placed[entry.index] = {
                    element = entry.element,
                    row = entry.row,
                    col = entry.col,
                    index = entry.index,
                    value = entry.value,
                    color = entry.color,
                    pigment = entry.pigment,
                    wet = false,
                }
                elem.cells_filled = (elem.cells_filled or 0) + 1
                committed = committed + 1
            end
        end
    end

    self.wet_buffer = {}
    reset_turn_flags(self)
    if self._updateCompletionState then
        self:_updateCompletionState()
    else
        self.quality = self:calculateQuality()
    end

    return {
        committed = committed,
        stains_added = 0,
        wettest_section = self.active_element or "TEXT",
        still_wet = 0,
    }
end

return FolioTurn
