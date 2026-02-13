local Hud = {}

function Hud.new(deps)
    local RuntimeUI = deps.RuntimeUI
    local PROTOTYPE_NO_BACKGROUND = deps.PROTOTYPE_NO_BACKGROUND
    local project_rect = deps.project_rect
    local clamp = deps.clamp
    local point_in_rect = deps.point_in_rect
    local draw_text_center = deps.draw_text_center
    local get_font = deps.get_font
    local get_remaining_dice_count = deps.get_remaining_dice_count
    local get_unusable_dice_count = deps.get_unusable_dice_count
    local ui_dimensions = deps.ui_dimensions

    local methods = {}

    function methods.drawStatusBar(self, bg, high_contrast, anchor_page)
        if not self.run or not self.run.current_folio then
            return
        end

        local stats_rect
        if PROTOTYPE_NO_BACKGROUND then
            local screen_w = select(1, ui_dimensions())
            local margin = RuntimeUI.sized(18)
            local base_w = anchor_page and anchor_page.w or (screen_w * 0.56)
            local stats_w = clamp(math.floor(base_w * 0.64), RuntimeUI.sized(520), RuntimeUI.sized(820))
            local stats_h = RuntimeUI.sized(62)
            local x
            local y
            if anchor_page then
                x = math.floor(anchor_page.x + (anchor_page.w - stats_w) * 0.5)
                y = math.max(margin, math.floor(anchor_page.y - stats_h - RuntimeUI.sized(14)))
            else
                x = math.floor((screen_w - stats_w) * 0.5)
                y = margin
            end
            stats_rect = {
                x = x,
                y = y,
                w = stats_w,
                h = stats_h,
            }
        else
            stats_rect = project_rect(bg, 30, 20, 470, 58)
        end
        love.graphics.setColor(0.33, 0.23, 0.15, high_contrast and 0.94 or 0.82)
        love.graphics.rectangle("fill", stats_rect.x, stats_rect.y, stats_rect.w, stats_rect.h, 7, 7)
        love.graphics.setColor(0.80, 0.64, 0.45, 0.66)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", stats_rect.x, stats_rect.y, stats_rect.w, stats_rect.h, 7, 7)
        love.graphics.setLineWidth(1)

        local folio = self.run.current_folio
        local values = {
            {"Folio", tostring(self.run.current_folio_index)},
            {"Reputation", tostring(self.run.reputation)},
            {"Stains", tostring(folio.stain_count)},
            {"Quality", tostring(folio.quality or 0)},
        }

        local col_w = stats_rect.w / #values
        local label_font = get_font(12, false)
        local value_font = get_font(20, true)
        local label_h = label_font:getHeight()
        local value_h = value_font:getHeight()
        local row_gap = RuntimeUI.sized(4)
        local stack_h = label_h + row_gap + value_h
        local stack_top = stats_rect.y + math.max(RuntimeUI.sized(4), math.floor((stats_rect.h - stack_h) * 0.5))

        for i, pair in ipairs(values) do
            local cx = stats_rect.x + (i - 1) * col_w
            if i > 1 then
                love.graphics.setColor(0.80, 0.64, 0.45, 0.28)
                love.graphics.line(cx, stats_rect.y + RuntimeUI.sized(7), cx, stats_rect.y + stats_rect.h - RuntimeUI.sized(7))
            end
            local label_rect = {x = cx, y = stack_top, w = col_w, h = label_h}
            draw_text_center(pair[1], label_rect, label_font, {0.95, 0.86, 0.72, 1})

            local color = {0.94, 0.88, 0.74, 1}
            if i == 2 then
                color = {0.40, 0.95, 0.58, 1}
            end
            if i == 3 then
                color = {0.95, 0.40, 0.40, 1}
            end
            if i == 4 then
                color = {0.95, 0.82, 0.50, 1}
            end
            local value_rect = {x = cx, y = stack_top + label_h + row_gap, w = col_w, h = value_h}
            draw_text_center(pair[2], value_rect, value_font, color)
        end
    end

    function methods.drawMarginNotes(self, page, high_contrast)
        if not self.run or not self.run.current_folio or not page then
            return
        end
        local folio = self.run.current_folio

        local note = {
            x = page.x + page.w * 0.74,
            y = page.y + page.h * 0.54,
            w = page.w * 0.21,
            h = page.h * 0.40,
        }
        love.graphics.setColor(0.92, 0.85, 0.72, high_contrast and 0.88 or 0.74)
        love.graphics.rectangle("fill", note.x, note.y, note.w, note.h, 7, 7)
        love.graphics.setColor(0.66, 0.49, 0.31, 0.62)
        love.graphics.rectangle("line", note.x, note.y, note.w, note.h, 7, 7)

        local y = note.y + RuntimeUI.sized(8)
        draw_text_center("Brief", {
            x = note.x,
            y = y,
            w = note.w,
            h = RuntimeUI.sized(20),
        }, get_font(16, false), {0.95, 0.86, 0.68, 1})

        local body_top = y + RuntimeUI.sized(24)
        local status = self.run.getStatus and self.run:getStatus() or {}
        local cards = status.cards or {}
        local lines = {
            "Complete Text + Miniature",
            string.format("Stains room: %d", math.max(0, folio.stain_threshold - folio.stain_count)),
            string.format("Folio %d", self.run.current_folio_index or 1),
            "Borders: " .. tostring((folio.border_parity == "EVEN") and "even" or "odd"),
            "Commission: " .. tostring(cards.commission or "-"),
            "Parchment: " .. tostring(cards.parchment or "-"),
            "Tool: " .. tostring(cards.tool or "-"),
        }
        local footer_h = RuntimeUI.sized(36)
        local divider_y = note.y + note.h - footer_h - RuntimeUI.sized(14)
        local available_h = math.max(RuntimeUI.sized(84), divider_y - body_top - RuntimeUI.sized(4))
        local target_px = clamp(math.floor(available_h / #lines) - RuntimeUI.sized(4), 9, 12)
        local body_font = get_font(target_px, false)
        local line_h = math.max(body_font:getHeight() + RuntimeUI.sized(2), clamp(math.floor(available_h / #lines), RuntimeUI.sized(13), RuntimeUI.sized(20)))
        love.graphics.setFont(body_font)
        y = body_top
        for _, line in ipairs(lines) do
            if y + line_h > divider_y then
                break
            end
            love.graphics.setColor(0.34, 0.25, 0.17, 1)
            love.graphics.print("• " .. line, note.x + RuntimeUI.sized(10), y)
            y = y + line_h
        end

        love.graphics.setColor(0.64, 0.47, 0.30, 0.36)
        love.graphics.line(note.x + RuntimeUI.sized(10), divider_y, note.x + note.w - RuntimeUI.sized(10), divider_y)
        y = divider_y + RuntimeUI.sized(8)

        local icons = {
            { short = "S", value = tostring(folio.shield or 0), color = {0.82, 0.68, 0.40, 1}},
            { short = "R", value = tostring(folio:getTurnRisk()), color = {0.85, 0.36, 0.32, 1}},
            { short = "P", value = tostring(folio.getPreparationGuard and folio:getPreparationGuard() or 0), color = {0.50, 0.74, 0.88, 1}},
            { short = "T", value = tostring(folio.getToolUsesLeft and folio:getToolUsesLeft() or 0), color = {0.64, 0.88, 0.62, 1}},
        }
        local icon_r = RuntimeUI.sized(8)
        local slot_w = (note.w - RuntimeUI.sized(24)) / #icons
        local start_x = note.x + RuntimeUI.sized(10)
        local icon_font = get_font(9, false)
        love.graphics.setFont(icon_font)
        local icon_text_h = icon_font:getHeight()
        for i, icon in ipairs(icons) do
            local ix = start_x + (i - 1) * slot_w
            love.graphics.setColor(icon.color[1], icon.color[2], icon.color[3], 0.95)
            love.graphics.circle("fill", ix, y + icon_r, icon_r)
            love.graphics.setColor(0.23, 0.16, 0.10, 1)
            love.graphics.circle("line", ix, y + icon_r, icon_r)
            love.graphics.setColor(0.34, 0.25, 0.17, 1)
            local text_y = y + math.floor((icon_r * 2 - icon_text_h) * 0.5)
            love.graphics.print(icon.short .. ":" .. icon.value, ix + RuntimeUI.sized(11), text_y)
        end
    end

    function methods.drawStopPushControls(self, high_contrast)
        local folio = self.run and self.run.current_folio
        if not folio then
            return
        end

        local page = self.page_rect
        local tray = self:_getTrayRect()

        local dock_h = self:getControlsDockHeight()
        local dock_x
        local dock_w
        local dock_y
        if page then
            dock_x = page.x
            dock_w = page.w
            dock_y = page.y + page.h + RuntimeUI.sized(12)
        else
            dock_w = math.min(tray.w, RuntimeUI.sized(980))
            dock_x = tray.x + (tray.w - dock_w) * 0.5
            dock_y = tray.y - dock_h - RuntimeUI.sized(12)
        end
        local max_y = tray.y - dock_h - RuntimeUI.sized(10)
        if dock_y > max_y then
            dock_y = max_y
        end

        love.graphics.setColor(0.24, 0.16, 0.10, high_contrast and 0.96 or 0.90)
        love.graphics.rectangle("fill", dock_x, dock_y, dock_w, dock_h, 8, 8)
        love.graphics.setColor(0.70, 0.52, 0.33, 0.56)
        love.graphics.rectangle("line", dock_x, dock_y, dock_w, dock_h, 8, 8)

        local pad = RuntimeUI.sized(12)
        local gap = RuntimeUI.sized(10)
        local left_w = dock_w * 0.20
        local mid_w = dock_w * 0.26
        local right_w = dock_w - left_w - mid_w - gap * 2 - pad * 2
        local left = {x = dock_x + pad, y = dock_y + pad, w = left_w, h = dock_h - pad * 2}
        local mid = {x = left.x + left.w + gap, y = dock_y + pad, w = mid_w, h = dock_h - pad * 2}
        local right = {x = mid.x + mid.w + gap, y = dock_y + pad, w = right_w, h = dock_h - pad * 2}

        love.graphics.setColor(0.31, 0.22, 0.14, 0.88)
        love.graphics.rectangle("fill", left.x, left.y, left.w, left.h, 6, 6)
        love.graphics.rectangle("fill", mid.x, mid.y, mid.w, mid.h, 6, 6)
        love.graphics.setColor(0.70, 0.52, 0.33, 0.42)
        love.graphics.rectangle("line", left.x, left.y, left.w, left.h, 6, 6)
        love.graphics.rectangle("line", mid.x, mid.y, mid.w, mid.h, 6, 6)

        local remaining = get_remaining_dice_count(self.dice_results)
        local left_label_font = get_font(13, false)
        local left_value_font = get_font(24, true)
        local left_label_h = left_label_font:getHeight()
        local left_value_h = left_value_font:getHeight()
        local left_gap = RuntimeUI.sized(4)
        local left_stack_h = left_label_h + left_gap + left_value_h
        local left_top = left.y + math.max(RuntimeUI.sized(6), math.floor((left.h - left_stack_h) * 0.5))
        draw_text_center("Dice left", {
            x = left.x,
            y = left_top,
            w = left.w,
            h = left_label_h,
        }, left_label_font, {0.95, 0.90, 0.82, 1})
        draw_text_center(tostring(remaining), {
            x = left.x,
            y = left_top + left_label_h + left_gap,
            w = left.w,
            h = left_value_h,
        }, left_value_font, {0.95, 0.82, 0.50, 1})

        local wet_text = string.format("Wet buffer: %d", folio:getWetCount())
        local risk_text = string.format("Stain risk: %d", folio:getTurnRisk())
        local state_text = "State: " .. tostring(self.state or "waiting")
        local wet_font = get_font(14, false)
        local risk_font = get_font(14, false)
        local state_font = get_font(12, false)
        local wet_h = wet_font:getHeight()
        local risk_h = risk_font:getHeight()
        local state_h = state_font:getHeight()
        local mid_gap = RuntimeUI.sized(4)
        local mid_stack_h = wet_h + risk_h + state_h + mid_gap * 2
        local mid_top = mid.y + math.max(RuntimeUI.sized(6), math.floor((mid.h - mid_stack_h) * 0.5))
        draw_text_center(wet_text, {
            x = mid.x,
            y = mid_top,
            w = mid.w,
            h = wet_h,
        }, wet_font, {0.95, 0.90, 0.82, 1})
        draw_text_center(risk_text, {
            x = mid.x,
            y = mid_top + wet_h + mid_gap,
            w = mid.w,
            h = risk_h,
        }, risk_font, {0.95, 0.68, 0.52, 1})
        draw_text_center(state_text, {
            x = mid.x,
            y = mid_top + wet_h + risk_h + mid_gap * 2,
            w = mid.w,
            h = state_h,
        }, state_font, {0.88, 0.78, 0.64, 1})

        local menu_rect = {
            x = dock_x + dock_w - RuntimeUI.sized(122),
            y = dock_y + RuntimeUI.sized(7),
            w = RuntimeUI.sized(112),
            h = RuntimeUI.sized(24),
        }
        self.ui_hit.menu_button = menu_rect
        local menu_hover = point_in_rect(self.mouse_x, self.mouse_y, menu_rect)
        local menu_alpha = menu_hover and 0.94 or 0.82
        love.graphics.setColor(0.28, 0.19, 0.12, menu_alpha)
        love.graphics.rectangle("fill", menu_rect.x, menu_rect.y, menu_rect.w, menu_rect.h, 5, 5)
        love.graphics.setColor(0.78, 0.60, 0.38, menu_alpha)
        love.graphics.rectangle("line", menu_rect.x, menu_rect.y, menu_rect.w, menu_rect.h, 5, 5)
        draw_text_center("MENU", {
            x = menu_rect.x,
            y = menu_rect.y,
            w = menu_rect.w,
            h = menu_rect.h,
        }, get_font(13, true), {0.97, 0.92, 0.84, 1})

        local button_gap = RuntimeUI.sized(8)
        local placing_mode = (self.state == "placing")

        if placing_mode then
            local min_prep_h = RuntimeUI.sized(34)
            local top_h = math.floor(right.h * 0.60)
            if (right.h - top_h - button_gap) < min_prep_h then
                top_h = right.h - button_gap - min_prep_h
            end
            top_h = math.max(RuntimeUI.sized(48), top_h)
            local prep_h = right.h - top_h - button_gap
            local third_w = (right.w - button_gap * 2) / 3
            local stop_rect = {x = right.x, y = right.y, w = third_w, h = top_h}
            local push_all_rect = {x = right.x + third_w + button_gap, y = right.y, w = third_w, h = top_h}
            local push_one_rect = {x = right.x + (third_w + button_gap) * 2, y = right.y, w = third_w, h = top_h}
            local prep_w = (right.w - button_gap) * 0.5
            local prep_risk_rect = {x = right.x, y = right.y + top_h + button_gap, w = prep_w, h = prep_h}
            local prep_guard_rect = {x = right.x + prep_w + button_gap, y = right.y + top_h + button_gap, w = prep_w, h = prep_h}

            local can_prepare = get_unusable_dice_count(self.dice_results) > 0 and folio.canUsePreparation and folio:canUsePreparation()

            self.ui_hit.stop_button = stop_rect
            self.ui_hit.push_all_button = push_all_rect
            self.ui_hit.push_one_button = push_one_rect
            self.ui_hit.prepare_risk_button = can_prepare and prep_risk_rect or nil
            self.ui_hit.prepare_guard_button = can_prepare and prep_guard_rect or nil
            self.ui_hit.restart_button = nil
            self.ui_hit.roll_button = nil

            local function fit_font(target_px, decorative, max_h)
                local px = target_px
                local f = get_font(px, decorative)
                while px > 8 and f:getHeight() > max_h do
                    px = px - 1
                    f = get_font(px, decorative)
                end
                return f
            end

            local function draw_action(rect, title, subtitle, base_color, line_color, enabled, title_px, subtitle_px)
                local hover = point_in_rect(self.mouse_x, self.mouse_y, rect)
                local alpha = enabled and (hover and 0.96 or 0.88) or 0.40
                love.graphics.setColor(base_color[1], base_color[2], base_color[3], alpha)
                love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
                love.graphics.setColor(line_color[1], line_color[2], line_color[3], alpha)
                love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 6, 6)
                local max_title_h = math.max(RuntimeUI.sized(12), math.floor(rect.h * 0.50))
                local max_subtitle_h = math.max(RuntimeUI.sized(10), math.floor(rect.h * 0.32))
                local title_font = fit_font(title_px or 15, true, max_title_h)
                local subtitle_font = fit_font(subtitle_px or 10, false, max_subtitle_h)
                local title_h = title_font:getHeight()
                local subtitle_h = subtitle_font:getHeight()
                local spacing = RuntimeUI.sized(2)
                local content_h = title_h + subtitle_h + spacing
                local text_top = rect.y + math.max(RuntimeUI.sized(4), math.floor((rect.h - content_h) * 0.5))
                draw_text_center(title, {
                    x = rect.x,
                    y = text_top,
                    w = rect.w,
                    h = title_h,
                }, title_font, {0.98, 0.93, 0.84, enabled and 1 or 0.55})
                draw_text_center(subtitle, {
                    x = rect.x,
                    y = text_top + title_h + spacing,
                    w = rect.w,
                    h = subtitle_h,
                }, subtitle_font, {0.98, 0.93, 0.84, enabled and 0.95 or 0.45})
            end

            draw_action(stop_rect, "STOP", "dry", {0.56, 0.23, 0.16}, {0.86, 0.62, 0.46}, true, 16, 11)
            draw_action(push_all_rect, "PUSH ALL", "reroll all", {0.22, 0.45, 0.24}, {0.70, 0.88, 0.64}, true, 16, 11)
            draw_action(push_one_rect, "PUSH 1", "reroll one die", {0.20, 0.36, 0.46}, {0.62, 0.84, 0.92}, true, 16, 11)
            draw_action(prep_risk_rect, "PREP", "-1 risk", {0.30, 0.25, 0.15}, {0.86, 0.72, 0.44}, can_prepare, 13, 10)
            draw_action(prep_guard_rect, "PREP", "+1 guard", {0.18, 0.29, 0.38}, {0.56, 0.78, 0.94}, can_prepare, 13, 10)
        else
            local button_w = (right.w - button_gap) * 0.5
            local button_h = right.h
            local primary_rect = {x = right.x, y = right.y, w = button_w, h = button_h}
            local secondary_rect = {x = right.x + button_w + button_gap, y = right.y, w = button_w, h = button_h}
            local primary_hover = point_in_rect(self.mouse_x, self.mouse_y, primary_rect)
            local secondary_hover = point_in_rect(self.mouse_x, self.mouse_y, secondary_rect)

            local can_restart = (self.state ~= "rolling")
            local can_roll = (self.state == "waiting")
            self.ui_hit.stop_button = nil
            self.ui_hit.push_all_button = nil
            self.ui_hit.push_one_button = nil
            self.ui_hit.prepare_risk_button = nil
            self.ui_hit.prepare_guard_button = nil
            self.ui_hit.restart_button = can_restart and primary_rect or nil
            self.ui_hit.roll_button = can_roll and secondary_rect or nil

            local primary_alpha = can_restart and (primary_hover and 0.96 or 0.88) or 0.42
            local secondary_alpha = can_roll and (secondary_hover and 0.96 or 0.88) or 0.42
            local function fit_idle_font(target_px, decorative, max_h)
                local px = target_px
                local f = get_font(px, decorative)
                while px > 8 and f:getHeight() > max_h do
                    px = px - 1
                    f = get_font(px, decorative)
                end
                return f
            end
            local max_title_h = math.max(RuntimeUI.sized(14), math.floor(primary_rect.h * 0.48))
            local max_subtitle_h = math.max(RuntimeUI.sized(10), math.floor(primary_rect.h * 0.30))
            local title_font = fit_idle_font(20, true, max_title_h)
            local subtitle_font = fit_idle_font(11, false, max_subtitle_h)
            local spacing = RuntimeUI.sized(4)
            local content_h = title_font:getHeight() + subtitle_font:getHeight() + spacing
            local text_top = primary_rect.y + math.max(RuntimeUI.sized(6), math.floor((primary_rect.h - content_h) * 0.5))

            love.graphics.setColor(0.36, 0.24, 0.14, primary_alpha)
            love.graphics.rectangle("fill", primary_rect.x, primary_rect.y, primary_rect.w, primary_rect.h, 6, 6)
            love.graphics.setColor(0.84, 0.66, 0.46, primary_alpha)
            love.graphics.rectangle("line", primary_rect.x, primary_rect.y, primary_rect.w, primary_rect.h, 6, 6)
            draw_text_center("NEW", {
                x = primary_rect.x,
                y = text_top,
                w = primary_rect.w,
                h = title_font:getHeight(),
            }, title_font, {0.98, 0.93, 0.84, can_restart and 1 or 0.55})
            draw_text_center("(reset folio)", {
                x = primary_rect.x,
                y = text_top + title_font:getHeight() + spacing,
                w = primary_rect.w,
                h = subtitle_font:getHeight(),
            }, subtitle_font, {0.98, 0.93, 0.84, can_restart and 0.95 or 0.45})

            love.graphics.setColor(0.22, 0.45, 0.24, secondary_alpha)
            love.graphics.rectangle("fill", secondary_rect.x, secondary_rect.y, secondary_rect.w, secondary_rect.h, 6, 6)
            love.graphics.setColor(0.70, 0.88, 0.64, secondary_alpha)
            love.graphics.rectangle("line", secondary_rect.x, secondary_rect.y, secondary_rect.w, secondary_rect.h, 6, 6)
            draw_text_center(can_roll and "ROLL" or "ROLLING", {
                x = secondary_rect.x,
                y = text_top,
                w = secondary_rect.w,
                h = title_font:getHeight(),
            }, title_font, {0.98, 0.93, 0.84, can_roll and 1 or 0.55})
            draw_text_center(can_roll and "(roll dice)" or "(wait)", {
                x = secondary_rect.x,
                y = text_top + title_font:getHeight() + spacing,
                w = secondary_rect.w,
                h = subtitle_font:getHeight(),
            }, subtitle_font, {0.98, 0.93, 0.84, can_roll and 0.95 or 0.45})
        end
    end

    return methods
end

return Hud
