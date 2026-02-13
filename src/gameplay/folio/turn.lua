local FolioTurn = {}

local function entries_match(a, b)
    if not a or not b then
        return false
    end
    return a.element == b.element and a.index == b.index and a.row == b.row and a.col == b.col
end

function FolioTurn.registerPush(self, push_mode)
    self.turn_pushes = self.turn_pushes + 1
    local push_risk_always = self.rule_effects and self.rule_effects.push_risk_always or nil
    if push_risk_always and push_risk_always > 0 then
        self.turn_risk = self.turn_risk + push_risk_always
    end
    if self.push_risk_enabled and self.turn_pushes > 1 then
        self.turn_risk = self.turn_risk + 1
    end
    self.last_push_mode = push_mode or "all"
end

function FolioTurn.getWetCount(self)
    return #self.wet_buffer
end

function FolioTurn.getTurnRisk(self)
    return self.turn_risk
end

function FolioTurn.getPreparationGuard(self)
    return self.preparation_guard or 0
end

function FolioTurn.canUsePreparation(self)
    return not self.turn_flags.preparation_used
end

function FolioTurn.applyPreparation(self, mode)
    if self.turn_flags.preparation_used then
        return false, "Preparation already used this turn"
    end
    local preparation_mode = mode or "risk"
    if preparation_mode == "risk" then
        self.turn_risk = math.max(0, self.turn_risk - 1)
    else
        self.preparation_guard = (self.preparation_guard or 0) + 1
    end
    self.turn_flags.preparation_used = true
    return true, (preparation_mode == "risk") and "Risk reduced by 1" or "Stored 1 stain guard"
end

function FolioTurn.getRuleCards(self)
    return self.rule_cards or {}
end

function FolioTurn.getRuleEffects(self)
    return self.rule_effects or {}
end

function FolioTurn.getToolUsesLeft(self)
    return self.tool_uses_left or 0
end

function FolioTurn.getSeals(self)
    return self.seals or 0
end

function FolioTurn.canSpendSeal(self)
    return (self.seals or 0) > 0
end

function FolioTurn.spendSeal(self)
    if not self:canSpendSeal() then
        return false
    end
    self.seals = math.max(0, (self.seals or 0) - 1)
    return true
end

function FolioTurn.canUseTool(self, id)
    if not self.rule_cards or not self.rule_cards.tool then
        return false
    end
    if id and self.rule_cards.tool.id ~= id then
        return false
    end
    return (self.tool_uses_left or 0) > 0
end

function FolioTurn.consumeToolUse(self, id)
    if not self:canUseTool(id) then
        return false
    end
    self.tool_uses_left = math.max(0, (self.tool_uses_left or 0) - 1)
    return true
end

function FolioTurn.getWetSummary(self)
    local counts = {}
    for _, elem in ipairs(self.ELEMENTS) do
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

function FolioTurn.hasWetPair(self)
    local by_value = {}
    local by_color = {}
    for _, entry in ipairs(self.wet_buffer) do
        if entry.value then
            by_value[entry.value] = (by_value[entry.value] or 0) + 1
            if by_value[entry.value] >= 2 then
                return true
            end
        end
        if entry.color then
            by_color[entry.color] = (by_color[entry.color] or 0) + 1
            if by_color[entry.color] >= 2 then
                return true
            end
        end
    end
    return false
end

function FolioTurn.tryAwardDoubleSeal(self)
    self.turn_flags = self.turn_flags or {}
    if self.turn_flags.double_awarded then
        return false
    end
    if not self:hasWetPair() then
        return false
    end
    self.seals = (self.seals or 0) + 1
    self.turn_flags.double_awarded = true
    return true
end

function FolioTurn.discardWetBuffer(self)
    if #self.wet_buffer == 0 then
        self.turn_risk = 0
        self.turn_pushes = 0
        self.turn_flags.over_four = false
        self.turn_flags.preparation_used = false
        self.turn_flags.double_awarded = false
        return 0
    end

    local discarded_wet_count = 0
    for _, entry in ipairs(self.wet_buffer) do
        local elem = self.elements[entry.element]
        if elem and elem.wet[entry.index] then
            elem.wet[entry.index] = nil
            discarded_wet_count = discarded_wet_count + 1
        end
    end

    self.wet_buffer = {}
    self.turn_risk = 0
    self.turn_pushes = 0
    self.turn_flags.over_four = false
    self.turn_flags.preparation_used = false
    self.turn_flags.double_awarded = false
    self:_pruneBorderMotifPairs()
    return discarded_wet_count
end

function FolioTurn.salvageWetBufferOnBust(self, preferred_entry)
    local touched_sections = {}
    local saved_entry = nil
    local discarded = 0
    local save_slot = nil

    for i, entry in ipairs(self.wet_buffer) do
        if preferred_entry and entries_match(entry, preferred_entry) then
            save_slot = i
            break
        end
    end
    if not save_slot and #self.wet_buffer > 0 then
        save_slot = #self.wet_buffer
    end

    for i, entry in ipairs(self.wet_buffer) do
        local elem = self.elements[entry.element]
        if elem and elem.wet[entry.index] then
            elem.wet[entry.index] = nil
            if i == save_slot then
                entry.wet = false
                elem.placed[entry.index] = entry
                elem.cells_filled = elem.cells_filled + 1
                touched_sections[entry.element] = true
                saved_entry = entry
            else
                discarded = discarded + 1
            end
        end
    end

    self.wet_buffer = {}
    self.turn_risk = 0
    self.turn_pushes = 0
    self.turn_flags.over_four = false
    self.turn_flags.preparation_used = false
    self.turn_flags.double_awarded = false

    for element, _ in pairs(touched_sections) do
        local elem = self.elements[element]
        if elem and (not elem.completed) and elem.cells_filled >= elem.cells_total then
            elem.completed = true
            self:onElementCompleted(element)
        end
    end

    self:_pruneBorderMotifPairs()
    local busted = self:addStain(2)
    self.quality = self:calculateQuality()

    return {
        saved = saved_entry,
        discarded = discarded,
        stains_added = 2,
        busted = busted,
    }
end

function FolioTurn.commitWetBuffer(self)
    if #self.wet_buffer == 0 then
        return {
            committed = 0,
            stains_added = 0,
            wettest_section = nil,
            still_wet = 0,
        }
    end

    local committed_by_section = {}
    local touched_sections = {}
    local committed = 0
    local committed_entries = {}

    for _, entry in ipairs(self.wet_buffer) do
        local elem = self.elements[entry.element]
        if elem and elem.wet[entry.index] then
            elem.wet[entry.index] = nil
            entry.wet = false
            elem.placed[entry.index] = entry
            elem.cells_filled = elem.cells_filled + 1
            touched_sections[entry.element] = true
            committed_by_section[entry.element] = (committed_by_section[entry.element] or 0) + 1
            committed = committed + 1
            committed_entries[#committed_entries + 1] = entry
        end
    end

    self.wet_buffer = {}

    local carried_wet_count = 0
    local first_stop_wet_left = self.rule_effects and self.rule_effects.first_stop_wet_left or 0
    if (not self.first_stop_done) and first_stop_wet_left and first_stop_wet_left > 0 then
        -- This rule creates an intentional "rough parchment" feel: first STOP is never fully safe.
        carried_wet_count = math.min(first_stop_wet_left, #committed_entries)
        self.first_stop_done = true
        for _ = 1, carried_wet_count do
            local entry = table.remove(committed_entries)
            if entry then
                local elem = self.elements[entry.element]
                if elem and elem.placed[entry.index] then
                    elem.placed[entry.index] = nil
                    elem.wet[entry.index] = entry
                    entry.wet = true
                    elem.cells_filled = math.max(0, elem.cells_filled - 1)
                    self.wet_buffer[#self.wet_buffer + 1] = entry
                    committed_by_section[entry.element] = math.max(0, (committed_by_section[entry.element] or 0) - 1)
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
    self.turn_flags.double_awarded = false

    for element, _ in pairs(touched_sections) do
        local elem = self.elements[element]
        if elem and (not elem.completed) and elem.cells_filled >= elem.cells_total then
            elem.completed = true
            self:onElementCompleted(element)
        end
    end

    local wettest_section = nil
    local wettest_count = -1
    for _, elem in ipairs(self.ELEMENTS) do
        local section_committed_count = committed_by_section[elem] or 0
        if section_committed_count > wettest_count then
            wettest_count = section_committed_count
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
        still_wet = carried_wet_count,
    }
end

return FolioTurn
