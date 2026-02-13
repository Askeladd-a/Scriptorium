local AudioManager = require("src.core.audio_manager")
local ResolutionManager = require("src.core.resolution_manager")
local DiceFaces = require("src.core.dice_faces")

local Helpers = require("src.features.scriptorium.helpers")
local point_in_rect = Helpers.point_in_rect
local get_die_color_key = Helpers.get_die_color_key

local Actions = {}

local function random_int(min_v, max_v)
    local rnd = (love and love.math and love.math.random) or math.random
    return rnd(min_v, max_v)
end

function Actions.requestRoll(self, max_dice)
    if self.state == "rolling" then
        return
    end

    -- Keep this state until the physics callback settles dice to avoid double-roll races.
    self.state = "rolling"

    if self.onRollRequest then
        self.onRollRequest(max_dice)
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

    for _, die in ipairs(self.dice_results) do
        if die and not die.used then
            die.color_key = get_die_color_key(die.value, self.value_to_color)
            local all_valid = folio:getAllValidPlacements(die.value, die.color_key)
            local legal_count = 0
            for _, placements in pairs(all_valid) do
                legal_count = legal_count + #placements
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
    self.run.current_folio:registerPush("all")
    self.selected_die = nil
    AudioManager.play_ui("confirm")
    self:requestRoll(nil)
end

function Actions.performPushOne(self)
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return
    end
    self.run.current_folio:registerPush("one")
    self.selected_die = nil
    AudioManager.play_ui("confirm")
    self:requestRoll(1)
end

function Actions.performStop(self)
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return
    end
    AudioManager.play_ui("confirm")
    local commit_result = self.run.current_folio:commitWetBuffer()
    self.dice_results = {}
    self.selected_die = nil
    if self.run.current_folio.completed then
        self:showMessage("COMPLETED!", "Folio completed successfully.")
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

    die.value = random_int(1, 6)
    die.color_key = get_die_color_key(die.value, self.value_to_color)
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
    local next_value = (die.value or 1) + (delta or 0)
    if next_value < 1 or next_value > 6 then
        return
    end
    if not folio:spendSeal() then
        return
    end

    die.value = next_value
    die.color_key = get_die_color_key(die.value, self.value_to_color)
    die.unusable = false
    die.burned = false
    AudioManager.play_ui("confirm")
    self:refreshDiceLegality()
    self:autoSelectPlayableDie()
    self:showMessage("Sigillo", "Adjusted die to " .. tostring(die.value), 1.2)
end

function Actions.placeSelectedDieAt(self, element, row, col)
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return false
    end
    local die = self:getSelectedDie()
    if not die or die.used then
        return false
    end

    local folio = self.run.current_folio
    local color_key = get_die_color_key(die.value, self.value_to_color)
    local fallback_pigment = (DiceFaces.DiceFaces[die.value] and DiceFaces.DiceFaces[die.value].fallback) or "OCRA_GIALLA"
    local ok, reason, _, events = folio:addWetDie(element, row, col, die.value, color_key, fallback_pigment)
    if not ok then
        self:showMessage("Placement blocked", reason or "Cannot place die", 1.6)
        AudioManager.play_ui("back")
        self:refreshDiceLegality()
        return false
    end

    die.used = true
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
    local function try_place_value(candidate_value)
        local color_key = get_die_color_key(candidate_value, self.value_to_color)
        for _, element in ipairs(folio.ELEMENTS) do
            local valid_cells = folio:getValidPlacements(element, candidate_value, color_key)
            if #valid_cells > 0 then
                local target_cell = valid_cells[1]
                local fallback_pigment = (DiceFaces.DiceFaces[candidate_value] and DiceFaces.DiceFaces[candidate_value].fallback)
                    or "OCRA_GIALLA"
                local placed_successfully =
                    folio:addWetDie(element, target_cell.row, target_cell.col, candidate_value, color_key, fallback_pigment)
                if placed_successfully then
                    return true
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
    local roll_candidates = {}
    for _, value in ipairs(values) do
        roll_candidates[#roll_candidates + 1] = {
            value = value,
            color = get_die_color_key(value, self.value_to_color),
        }
    end

    if not folio:hasAnyLegalPlacement(roll_candidates) then
        local preferred = folio.pickBestWetPlacement and folio:pickBestWetPlacement() or nil
        local bust_outcome = folio.salvageWetBufferOnBust and folio:salvageWetBufferOnBust(preferred)
            or {saved = nil, stains_added = 2}
        if self.run then
            self.run.reputation = math.max(0, (self.run.reputation or 0) - 1)
        end
        local saved_text = "none"
        if bust_outcome and bust_outcome.saved then
            saved_text = tostring(bust_outcome.saved.element or "cell")
        end
        self:showMessage("BUST!", string.format("Saved: %s | +%d stains", saved_text, bust_outcome.stains_added or 2), 2.6)
        self.dice_results = {}
        self.selected_die = nil
        self.state = "waiting"
        return
    end

    self.dice_results = {}
    for _, value in ipairs(values) do
        self.dice_results[#self.dice_results + 1] = {
            value = value,
            color_key = get_die_color_key(value, self.value_to_color),
            used = false,
            unusable = false,
            burned = false,
            legal_count = 0,
        }
    end

    self.selected_cell = nil
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
        return "Mouse: read cards and click START RUN"
    end
    if self.message then
        return "Click to close the message"
    end
    if self.state == "waiting" then
        return "Mouse: click ROLL to roll the dice"
    end
    if self.state == "rolling" then
        return "Dice are moving..."
    end
    if self.state == "placing" then
        local folio = self.run and self.run.current_folio
        local die = self:getSelectedDie()
        if folio and die then
            return string.format(
                "Flow: choose die -> legal cells -> STOP/PUSH | Die:%d Wet:%d Risk:%d Sigilli:%d",
                die.value,
                folio:getWetCount(),
                folio:getTurnRisk(),
                folio.getSeals and folio:getSeals() or 0
            )
        end
        if folio then
            return string.format(
                "Mouse: select die, place, STOP/PUSH | Wet:%d Risk:%d Sigilli:%d",
                folio:getWetCount(),
                folio:getTurnRisk(),
                folio.getSeals and folio:getSeals() or 0
            )
        end
        return "Mouse: select die, place, STOP/PUSH"
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
                    if self:placeSelectedDieAt(hit.element, hit.row, hit.col) then
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
