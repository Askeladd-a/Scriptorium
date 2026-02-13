local AudioManager = require("src.core.audio_manager")
local ResolutionManager = require("src.core.resolution_manager")
local DiceFaces = require("src.core.dice_faces")

local Helpers = require("src.features.scriptorium.helpers")
local point_in_rect = Helpers.point_in_rect

local Actions = {}

local function random_int(min_v, max_v)
    local rnd = (love and love.math and love.math.random) or math.random
    return rnd(min_v, max_v)
end

local function normalize_face_for_pigment(value)
    local numeric = tonumber(value) or 1
    numeric = math.floor(numeric)
    if numeric < 1 then
        numeric = 1
    end
    return ((numeric - 1) % 6) + 1
end

local TURN_D8_COLOR_TABLE = {
    "ROSSO",
    "VERDE",
    "GIALLO",
    "BLU",
    "MARRONE",
    "NERO",
    "VIOLA",
    "BIANCO",
}

local function list_contains(list, value)
    if not list then
        return false
    end
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

local function clamp_int(v, min_v, max_v)
    local n = tonumber(v) or min_v
    n = math.floor(n)
    if n < min_v then
        return min_v
    end
    if n > max_v then
        return max_v
    end
    return n
end

local function pick_turn_palette_colors(folio, count)
    local target = clamp_int(count or 3, 1, #TURN_D8_COLOR_TABLE)
    if folio and folio.drawTurnPalette then
        local drawn = folio:drawTurnPalette(target)
        if type(drawn) == "table" and #drawn > 0 then
            return drawn
        end
    end

    local selected = {}
    while #selected < target do
        local face = random_int(1, #TURN_D8_COLOR_TABLE)
        local color = TURN_D8_COLOR_TABLE[face]
        if color and (not list_contains(selected, color)) then
            selected[#selected + 1] = color
        end
        if #selected >= #TURN_D8_COLOR_TABLE then
            break
        end
    end
    return selected
end

function Actions.clearTurnPalette(self)
    self.turn_palette = nil
    self.palette_picker = nil
end

function Actions.getTurnPalette(self)
    if type(self.turn_palette) ~= "table" then
        return {}
    end
    return self.turn_palette
end

function Actions.ensureTurnPalette(self)
    if type(self.turn_palette) == "table" and #self.turn_palette > 0 then
        return self.turn_palette
    end
    local folio = self.run and self.run.current_folio or nil
    self.turn_palette = pick_turn_palette_colors(folio, 3)
    if folio and folio.markTurnStarted then
        folio:markTurnStarted(self.turn_palette)
    end
    return self.turn_palette
end

function Actions.getLegalPaletteColorsForPlacement(self, element, row, col, die_value)
    local folio = self.run and self.run.current_folio
    if not folio then
        return {}
    end
    local value = clamp_int(die_value, 1, 8)
    local legal = {}
    local palette = self:getTurnPalette()
    for _, color in ipairs(palette) do
        local ok = folio:canPlaceDie(element, row, col, value, color)
        if ok then
            legal[#legal + 1] = color
        end
    end
    return legal
end

function Actions.getRerollIndices(self)
    local indices = {}
    if not self.dice_results then
        return indices
    end
    local seen = {}
    for i, die in ipairs(self.dice_results) do
        if die and not die.used then
            local idx = tonumber(die.index) or i
            idx = math.floor(idx)
            if idx > 0 and not seen[idx] then
                indices[#indices + 1] = idx
                seen[idx] = true
            end
        end
    end
    table.sort(indices)
    return indices
end

local function count_any_legal_placements(folio, value, palette)
    local total = 0
    for _, color in ipairs(palette) do
        local all_valid = folio:getAllValidPlacements(value, color)
        for _, placements in pairs(all_valid) do
            total = total + #placements
            if total > 0 then
                return total
            end
        end
    end
    return total
end

function Actions.requestRoll(self, max_dice)
    if self.state == "rolling" then
        return
    end

    self.palette_picker = nil
    if self.state == "placing" and (type(self.turn_palette) ~= "table" or #self.turn_palette <= 0) then
        self:ensureTurnPalette()
    end

    local roll_indices = nil
    if self.state == "placing" and self.dice_results and #self.dice_results > 0 then
        roll_indices = self:getRerollIndices()
        if #roll_indices <= 0 then
            self:showMessage("No dice left", "All dice already in wet buffer", 1.4)
            self.state = "placing"
            return
        end
    end

    -- Keep this state until the physics callback settles dice to avoid double-roll races.
    self.state = "rolling"

    if self.onRollRequest then
        self.onRollRequest(max_dice, roll_indices)
    else
        self.state = "waiting"
    end
end

function Actions.getSelectedDie(self)
    if not self.dice_results then
        return nil, nil
    end
    if type(self.selected_die) ~= "number" then
        return nil, nil
    end
    local die = self.dice_results[self.selected_die]
    if not die then
        return nil, nil
    end
    return die, self.selected_die
end

function Actions.setSelectedDie(self, index)
    if type(index) ~= "number" or not self.dice_results then
        self.selected_die = nil
        return false
    end
    local die = self.dice_results[index]
    if not die or die.used then
        return false
    end
    self.selected_die = index
    return true
end

function Actions.refreshDiceLegality(self)
    local folio = self.run and self.run.current_folio
    if not folio or not self.dice_results then
        return
    end

    local palette = self:getTurnPalette()
    for _, die in ipairs(self.dice_results) do
        if die and not die.used then
            local legal_count = 0
            local seen = {}
            for _, color in ipairs(palette) do
                local all_valid = folio:getAllValidPlacements(die.value, color)
                for element, placements in pairs(all_valid) do
                    for _, placement in ipairs(placements) do
                        local key = tostring(element) .. ":" .. tostring(placement.row) .. ":" .. tostring(placement.col)
                        if not seen[key] then
                            seen[key] = true
                            legal_count = legal_count + 1
                        end
                    end
                end
            end
            die.legal_count = legal_count
            die.unusable = legal_count <= 0
        elseif die then
            die.legal_count = 0
            die.unusable = false
        end
    end
end

function Actions.autoSelectPlayableDie(self)
    if not self.dice_results then
        self.selected_die = nil
        return nil
    end

    local current_die, current_index = self:getSelectedDie()
    if current_die and not current_die.used and not current_die.unusable then
        return current_index
    end

    for i, die in ipairs(self.dice_results) do
        if die and not die.used and not die.unusable then
            self.selected_die = i
            return i
        end
    end

    for i, die in ipairs(self.dice_results) do
        if die and not die.used then
            self.selected_die = i
            return i
        end
    end

    self.selected_die = nil
    return nil
end

function Actions.performPushAll(self)
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return
    end
    local has_placed_in_current_roll = false
    for _, die in ipairs(self.dice_results or {}) do
        if die and die.used then
            has_placed_in_current_roll = true
            break
        end
    end
    if not has_placed_in_current_roll then
        self:showMessage("Place 1 die first", "Choose at least one die before reroll", 1.6)
        AudioManager.play_ui("back")
        return
    end
    self.run.current_folio:registerPush("all")
    self.selected_die = nil
    AudioManager.play_ui("confirm")
    self:requestRoll(nil)
end

function Actions.performPushOne(self)
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return
    end
    local has_placed_in_current_roll = false
    for _, die in ipairs(self.dice_results or {}) do
        if die and die.used then
            has_placed_in_current_roll = true
            break
        end
    end
    if not has_placed_in_current_roll then
        self:showMessage("Place 1 die first", "Choose at least one die before reroll", 1.6)
        AudioManager.play_ui("back")
        return
    end
    self.run.current_folio:registerPush("all")
    self.selected_die = nil
    AudioManager.play_ui("confirm")
    self:requestRoll(nil)
end

function Actions.performStop(self)
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return
    end
    AudioManager.play_ui("confirm")
    local commit_result = self.run.current_folio:commitWetBuffer()
    self.dice_results = {}
    self.selected_die = nil
    self.palette_picker = nil
    self.turn_palette = nil
    if self.run.current_folio.completed then
        local stats = self.run.current_folio.getCompletionStats and self.run.current_folio:getCompletionStats() or nil
        if stats then
            self:showMessage(
                "Completed!",
                string.format("Turns: %d  Busts: %d  Stains: %d", stats.turns or 0, stats.busts or 0, stats.stains or 0),
                2.6
            )
        else
            self:showMessage("Completed!", "Folio completed successfully.")
        end
    elseif commit_result and commit_result.still_wet and commit_result.still_wet > 0 then
        self:showMessage("Humid parchment", tostring(commit_result.still_wet) .. " die remains wet", 2.0)
    elseif commit_result and commit_result.stains_added and commit_result.stains_added > 0 then
        self:showMessage("Ink still wet", "+" .. tostring(commit_result.stains_added) .. " stain(s) from risk", 2.0)
    end
    self.state = "waiting"
end

function Actions.performRestart(self)
    AudioManager.play_ui("toggle")
    self:enter(self.run and self.run.folio_set or "BIFOLIO")
end

function Actions.consumeUnusableDie(self)
    if not self.dice_results then
        return nil
    end
    for _, die in ipairs(self.dice_results) do
        if die and die.unusable and not die.burned and not die.used then
            die.burned = true
            die.used = true
            return die
        end
    end
    return nil
end

function Actions.performPreparation(self, mode)
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return
    end
    local folio = self.run.current_folio
    if not (folio.canUsePreparation and folio:canUsePreparation()) then
        return
    end
    if not self:_consumeUnusableDie() then
        return
    end
    local ok = folio:applyPreparation(mode)
    if ok then
        AudioManager.play_ui("move")
    end
end

function Actions.performSealReroll(self)
    local folio = self.run and self.run.current_folio
    if self.state ~= "placing" or not folio or not (folio.canSpendSeal and folio:canSpendSeal()) then
        return
    end
    local die = self:getSelectedDie()
    if not die or die.used then
        self:autoSelectPlayableDie()
        die = self:getSelectedDie()
        if not die or die.used then
            return
        end
    end
    if not folio:spendSeal() then
        return
    end

    local sides = math.max(2, math.floor((die and die.sides) or 6))
    die.value = random_int(1, sides)
    die.color_key = nil
    die.unusable = false
    die.burned = false
    AudioManager.play_ui("confirm")
    self:refreshDiceLegality()
    self:autoSelectPlayableDie()
    self:showMessage("Sigillo", "Reroll 1 die", 1.2)
end

function Actions.performSealAdjust(self, delta)
    local folio = self.run and self.run.current_folio
    if self.state ~= "placing" or not folio or not (folio.canSpendSeal and folio:canSpendSeal()) then
        return
    end
    local die = self:getSelectedDie()
    if not die or die.used then
        self:autoSelectPlayableDie()
        die = self:getSelectedDie()
        if not die or die.used then
            return
        end
    end
    local sides = math.max(2, math.floor((die and die.sides) or 6))
    local next_value = (die.value or 1) + (delta or 0)
    if next_value < 1 or next_value > sides then
        return
    end
    if not folio:spendSeal() then
        return
    end

    die.value = next_value
    die.color_key = nil
    die.unusable = false
    die.burned = false
    AudioManager.play_ui("confirm")
    self:refreshDiceLegality()
    self:autoSelectPlayableDie()
    self:showMessage("Sigillo", "Adjusted die to " .. tostring(die.value), 1.2)
end

function Actions.placeSelectedDieAt(self, element, row, col, chosen_color)
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return false
    end
    local die = self:getSelectedDie()
    if not die or die.used then
        return false
    end

    local folio = self.run.current_folio
    local legal_colors = self:getLegalPaletteColorsForPlacement(element, row, col, die.value)
    if #legal_colors <= 0 then
        self:showMessage("Placement blocked", "No palette color fits this cell", 1.4)
        AudioManager.play_ui("back")
        self:refreshDiceLegality()
        return false
    end

    local color_key = chosen_color
    if not color_key or not list_contains(legal_colors, color_key) then
        color_key = legal_colors[1]
    end

    local pigment_face = normalize_face_for_pigment(die.value)
    local fallback_pigment = (DiceFaces.DiceFaces[pigment_face] and DiceFaces.DiceFaces[pigment_face].fallback) or "OCRA_GIALLA"
    local ok, reason, _, events = folio:addWetDie(element, row, col, die.value, color_key, fallback_pigment)
    if not ok then
        self:showMessage("Placement blocked", reason or "Cannot place die", 1.6)
        AudioManager.play_ui("back")
        self:refreshDiceLegality()
        return false
    end

    die.used = true
    die.color_key = color_key
    die.unusable = false
    die.legal_count = 0
    die.burned = false
    self.selected_cell = {element = element, row = row, col = col}
    AudioManager.play_ui("move")

    if events and events.double_awarded then
        self:showMessage("Doppia!", "+1 Sigillo", 1.8)
    end

    self:refreshDiceLegality()
    self:autoSelectPlayableDie()

    if folio.completed then
        self:showMessage("COMPLETED!", "Folio completed successfully.")
    end

    return true
end

function Actions.autoPlaceDie(self, value)
    if not self.run or not self.run.current_folio then
        return false
    end

    local folio = self.run.current_folio
    local palette = self:getTurnPalette()
    local function try_place_value(candidate_value)
        for _, color_key in ipairs(palette) do
            for _, element in ipairs(folio.ELEMENTS) do
                local valid_cells = folio:getValidPlacements(element, candidate_value, color_key)
                if #valid_cells > 0 then
                    local target_cell = valid_cells[1]
                    local normalized_candidate = normalize_face_for_pigment(candidate_value)
                    local fallback_pigment = (DiceFaces.DiceFaces[candidate_value] and DiceFaces.DiceFaces[candidate_value].fallback)
                        or (DiceFaces.DiceFaces[normalized_candidate] and DiceFaces.DiceFaces[normalized_candidate].fallback)
                        or "OCRA_GIALLA"
                    local placed_successfully =
                        folio:addWetDie(element, target_cell.row, target_cell.col, candidate_value, color_key, fallback_pigment)
                    if placed_successfully then
                        return true
                    end
                end
            end
        end
        return false
    end

    if try_place_value(value) then
        return true
    end

    if value > 1 and folio.canUseTool and folio:canUseTool("knife") then
        local corrected_value = value - 1
        if try_place_value(corrected_value) then
            folio:consumeToolUse("knife")
            return true
        end
    end

    return false
end

function Actions.onDiceSettled(self, values)
    if not self.run or not values or #values == 0 then
        self.state = "waiting"
        return
    end

    local folio = self.run.current_folio
    if not folio then
        self.state = "waiting"
        return
    end

    local normalized_roll = {}
    local placement_roll = {}
    for _, item in ipairs(values) do
        local value = item
        local sides = 6
        local kind = "d6"
        local index = nil
        if type(item) == "table" then
            value = item.value
            sides = item.sides or sides
            kind = item.kind or kind
            index = item.index
        end
        value = tonumber(value) or 1
        value = math.max(1, math.floor(value))
        sides = math.max(2, math.floor(tonumber(sides) or 6))
        local normalized_item = {
            value = value,
            sides = sides,
            kind = kind,
            index = tonumber(index) and math.floor(tonumber(index)) or nil,
        }
        normalized_roll[#normalized_roll + 1] = normalized_item
        if kind == "d6" or sides == 6 then
            placement_roll[#placement_roll + 1] = normalized_item
        end
    end

    if #placement_roll == 0 then
        placement_roll = normalized_roll
    end

    local palette = self:getTurnPalette()
    if #palette <= 0 then
        palette = self:ensureTurnPalette()
    end

    local has_any_legal = false
    if folio.hasAnyMove then
        has_any_legal = folio:hasAnyMove(placement_roll, palette)
    else
        for _, item in ipairs(placement_roll) do
            if count_any_legal_placements(folio, item.value, palette) > 0 then
                has_any_legal = true
                break
            end
        end
    end

    if not has_any_legal then
        local lost_wet = folio.discardWetBuffer and folio:discardWetBuffer() or 0
        local bust_reached = folio.addStain and folio:addStain(1) or false
        folio.bust_count = (folio.bust_count or 0) + 1
        if self.run then
            self.run.reputation = math.max(0, (self.run.reputation or 0) - 1)
        end
        local bust_text = bust_reached and "BUST! Folio ruined" or "Bust!"
        self:showMessage(bust_text, string.format("Wet lost: %d | +1 stain", lost_wet), 2.4)
        self.dice_results = {}
        self.selected_die = nil
        self.palette_picker = nil
        self.turn_palette = nil
        self.state = "waiting"
        return
    end

    self.dice_results = {}
    for _, item in ipairs(placement_roll) do
        self.dice_results[#self.dice_results + 1] = {
            value = item.value,
            sides = item.sides,
            kind = item.kind,
            index = item.index,
            color_key = nil,
            used = false,
            unusable = false,
            burned = false,
            legal_count = 0,
        }
    end

    self.selected_cell = nil
    self.palette_picker = nil
    self:refreshDiceLegality()
    self:autoSelectPlayableDie()

    if folio.busted then
        self:showMessage("BUST!", "The folio is ruined. Reputation lost.")
        self.state = "waiting"
    elseif folio.completed then
        self:showMessage("COMPLETED!", "Folio completed successfully.")
        self.state = "waiting"
    else
        self.state = "placing"
    end
end

function Actions.showMessage(self, text, subtext, duration)
    self.message = {
        text = text,
        subtext = subtext,
    }
    self.message_timer = duration or 2.2
end

function Actions.getInstructions(self)
    if self.show_run_setup then
        return "Mouse: read rules and click start run"
    end
    if self.message then
        return "Click to close the message"
    end
    if self.state == "waiting" then
        return "Mouse: click roll to roll the dice"
    end
    if self.state == "rolling" then
        return "Dice are moving..."
    end
    if self.state == "placing" then
        local folio = self.run and self.run.current_folio
        local die = self:getSelectedDie()
        if folio and die then
            return string.format(
                "Flow: choose die -> cell -> palette color -> dry/reroll | Die:%d Wet:%d Stains:%d",
                die.value,
                folio:getWetCount(),
                folio.stain_count or 0
            )
        end
        if folio then
            return string.format(
                "Mouse: select die, place, pick color, then dry/reroll | Wet:%d Stains:%d",
                folio:getWetCount(),
                folio.stain_count or 0
            )
        end
        return "Mouse: select die, place, then stop/reroll"
    end
    return "Mouse-only mode"
end

function Actions.keypressed(self, _key)
end

function Actions.mousepressed(self, x, y, button)
    if button ~= 1 then
        return
    end

    local ui_x, ui_y = ResolutionManager.to_virtual(x, y)

    if self.message then
        self.message = nil
        self.message_timer = 0
        return
    end

    if self.show_run_setup then
        -- Setup overlay has priority: clicks here must not trigger gameplay controls below.
        if point_in_rect(ui_x, ui_y, self.ui_hit.setup_start_button) then
            self.show_run_setup = false
            AudioManager.play_ui("confirm")
        end
        return
    end

    if point_in_rect(ui_x, ui_y, self.ui_hit.menu_button) then
        AudioManager.play_ui("back")
        if _G.set_module then
            _G.set_module("main_menu")
        end
        return
    end

    if self.state == "placing" then
        if self.palette_picker and self.ui_hit.palette_color_buttons then
            for _, pick in ipairs(self.ui_hit.palette_color_buttons) do
                if point_in_rect(ui_x, ui_y, pick.rect) then
                    local p = self.palette_picker
                    if p and self:placeSelectedDieAt(p.element, p.row, p.col, pick.color) then
                        self.palette_picker = nil
                        return
                    end
                end
            end
            -- Click outside color picker closes it.
            self.palette_picker = nil
        end

        if self.ui_hit.dice_chips then
            for _, chip in ipairs(self.ui_hit.dice_chips) do
                if point_in_rect(ui_x, ui_y, chip.rect) then
                    if self:setSelectedDie(chip.index) then
                        AudioManager.play_ui("toggle")
                    end
                    return
                end
            end
        end

        if point_in_rect(ui_x, ui_y, self.ui_hit.seal_reroll_button) then
            self:performSealReroll()
            return
        end
        if point_in_rect(ui_x, ui_y, self.ui_hit.seal_plus_button) then
            self:performSealAdjust(1)
            return
        end
        if point_in_rect(ui_x, ui_y, self.ui_hit.seal_minus_button) then
            self:performSealAdjust(-1)
            return
        end

        if self.ui_hit.placement_cells then
            for _, hit in ipairs(self.ui_hit.placement_cells) do
                if point_in_rect(ui_x, ui_y, hit.rect) then
                    local options = hit.palette_options
                    if type(options) ~= "table" or #options == 0 then
                        local die = self:getSelectedDie()
                        local value = die and die.value or 1
                        options = self:getLegalPaletteColorsForPlacement(hit.element, hit.row, hit.col, value)
                    end
                    if #options == 1 then
                        if self:placeSelectedDieAt(hit.element, hit.row, hit.col, options[1]) then
                            return
                        end
                    elseif #options > 1 then
                        self.palette_picker = {
                            die_index = self.selected_die,
                            element = hit.element,
                            row = hit.row,
                            col = hit.col,
                            options = options,
                            anchor_x = hit.rect.x + hit.rect.w * 0.5,
                            anchor_y = hit.rect.y - 2,
                        }
                        AudioManager.play_ui("toggle")
                        return
                    end
                end
            end
        end

        if point_in_rect(ui_x, ui_y, self.ui_hit.stop_button) then
            self:performStop()
            return
        end
        if point_in_rect(ui_x, ui_y, self.ui_hit.push_all_button) then
            self:performPushAll()
            return
        end
        if point_in_rect(ui_x, ui_y, self.ui_hit.push_one_button) then
            self:performPushOne()
            return
        end
        if point_in_rect(ui_x, ui_y, self.ui_hit.prepare_risk_button) then
            self:performPreparation("risk")
            return
        end
        if point_in_rect(ui_x, ui_y, self.ui_hit.prepare_guard_button) then
            self:performPreparation("guard")
            return
        end
    else
        if point_in_rect(ui_x, ui_y, self.ui_hit.restart_button) then
            self:performRestart()
            return
        end
        if point_in_rect(ui_x, ui_y, self.ui_hit.roll_button) then
            AudioManager.play_ui("confirm")
            self:requestRoll()
            return
        end
    end
end

function Actions.mousemoved(self, x, y, dx, dy)
    local ui_x, ui_y = ResolutionManager.to_virtual(x, y)
    self.mouse_x = ui_x
    self.mouse_y = ui_y
    self.hovered_lock = nil
    if self.lock_badges then
        for _, badge in ipairs(self.lock_badges) do
            if point_in_rect(ui_x, ui_y, badge.rect) then
                self.hovered_lock = badge
                break
            end
        end
    end
end

function Actions.wheelmoved(self, x, y)
end

return Actions
