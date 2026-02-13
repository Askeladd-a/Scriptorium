local AudioManager = require("src.core.audio_manager")
local ResolutionManager = require("src.core.resolution_manager")
local DiceFaces = require("src.core.dice_faces")

local Helpers = require("src.features.scriptorium.helpers")
local point_in_rect = Helpers.point_in_rect

local Actions = {}

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

function Actions.performPushAll(self)
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return
    end
    self.run.current_folio:registerPush("all")
    AudioManager.play_ui("confirm")
    self:requestRoll(nil)
end

function Actions.performPushOne(self)
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return
    end
    self.run.current_folio:registerPush("one")
    AudioManager.play_ui("confirm")
    self:requestRoll(1)
end

function Actions.performStop(self)
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return
    end
    AudioManager.play_ui("confirm")
    local commit_result = self.run.current_folio:commitWetBuffer()
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
        if die and die.unusable and not die.burned then
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

function Actions.autoPlaceDie(self, value)
    if not self.run or not self.run.current_folio then
        return false
    end

    local folio = self.run.current_folio
    local function try_place_value(candidate_value)
        local color_key = Helpers.get_die_color_key(candidate_value, self.value_to_color)
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

    self.dice_results = {}
    local folio = self.run.current_folio
    local roll_candidates = {}
    for _, value in ipairs(values) do
        roll_candidates[#roll_candidates + 1] = {
            value = value,
            color = Helpers.get_die_color_key(value, self.value_to_color),
        }
    end

    if not folio:hasAnyLegalPlacement(roll_candidates) then
        local wet_dice_lost = folio:discardWetBuffer()
        folio:addStain(1)
        if self.run then
            self.run.reputation = math.max(0, (self.run.reputation or 0) - 1)
        end
        self:showMessage("BUST!", string.format("No legal placement. Wet lost: %d", wet_dice_lost), 2.4)
        self.state = "waiting"
        return
    end

    for _, value in ipairs(values) do
        local color_key = Helpers.get_die_color_key(value, self.value_to_color)
        local was_placed = self:autoPlaceDie(value)
        self.dice_results[#self.dice_results + 1] = {
            value = value,
            color_key = color_key,
            used = was_placed,
            unusable = not was_placed,
        }
    end

    if folio.busted then
        self:showMessage("BUST!", "The folio is ruined. Reputation lost.")
    elseif folio.completed then
        self:showMessage("COMPLETED!", "Folio completed successfully.")
    elseif folio:getWetCount() > 0 then
        self.state = "placing"
        return
    end

    self.state = "waiting"
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
        if folio then
            return string.format("Mouse: STOP, PUSH ALL, PUSH 1, PREP | Wet:%d  Risk:%d", folio:getWetCount(), folio:getTurnRisk())
        end
        return "Mouse: STOP, PUSH ALL, PUSH 1, PREP"
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
