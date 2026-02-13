local Overlays = {}

function Overlays.new(deps)
    local RuntimeUI = deps.RuntimeUI
    local ui_dimensions = deps.ui_dimensions
    local get_font = deps.get_font
    local draw_text_center = deps.draw_text_center
    local point_in_rect = deps.point_in_rect
    local clamp = deps.clamp

    local methods = {}

    function methods.drawMessageOverlay(self)
        if not self.message then
            return
        end

        local w, h = ui_dimensions()
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", 0, 0, w, h)

        local box_w = math.min(RuntimeUI.sized(560), w * 0.82)
        local box_h = RuntimeUI.sized(170)
        local box_x = (w - box_w) * 0.5
        local box_y = (h - box_h) * 0.5

        love.graphics.setColor(0.20, 0.14, 0.10, 0.95)
        love.graphics.rectangle("fill", box_x, box_y, box_w, box_h, 10, 10)
        love.graphics.setColor(0.82, 0.65, 0.42, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", box_x, box_y, box_w, box_h, 10, 10)
        love.graphics.setLineWidth(1)

        draw_text_center(self.message.text or "", {
            x = box_x,
            y = box_y + RuntimeUI.sized(28),
            w = box_w,
            h = RuntimeUI.sized(52),
        }, get_font(36, true), {0.95, 0.84, 0.54, 1})

        if self.message.subtext then
            draw_text_center(self.message.subtext, {
                x = box_x + RuntimeUI.sized(20),
                y = box_y + RuntimeUI.sized(96),
                w = box_w - RuntimeUI.sized(40),
                h = RuntimeUI.sized(40),
            }, get_font(18, false), {0.95, 0.90, 0.82, 1})
        end
    end

    function methods.drawRunSetupOverlay(self)
        if not self.show_run_setup then
            self.ui_hit.setup_start_button = nil
            return
        end

        local w, h = ui_dimensions()
        local folio = self.run and self.run.current_folio or nil
        local pattern_name = folio and folio.getPatternName and folio:getPatternName() or "Window"

        love.graphics.setColor(0, 0, 0, 0.70)
        love.graphics.rectangle("fill", 0, 0, w, h)

        local box_w = math.min(RuntimeUI.sized(980), w * 0.88)
        local box_h = math.min(RuntimeUI.sized(560), h * 0.84)
        local box_x = (w - box_w) * 0.5
        local box_y = (h - box_h) * 0.5

        love.graphics.setColor(0.20, 0.14, 0.10, 0.96)
        love.graphics.rectangle("fill", box_x, box_y, box_w, box_h, 10, 10)
        love.graphics.setColor(0.82, 0.65, 0.42, 0.86)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", box_x, box_y, box_w, box_h, 10, 10)
        love.graphics.setLineWidth(1)

        draw_text_center("Run Setup", {
            x = box_x,
            y = box_y + RuntimeUI.sized(18),
            w = box_w,
            h = RuntimeUI.sized(36),
        }, get_font(34, false), {0.96, 0.86, 0.60, 1})

        draw_text_center("These rules stay active for all folios in the run.", {
            x = box_x + RuntimeUI.sized(20),
            y = box_y + RuntimeUI.sized(60),
            w = box_w - RuntimeUI.sized(40),
            h = RuntimeUI.sized(24),
        }, get_font(14, false), {0.93, 0.90, 0.84, 1})

        local notes = {
            "Single folio: one 4x5 Sagrada-style window.",
            "Turn = 6d6 values + 3 unique colors (fixed this turn).",
            "Reroll affects only unplaced dice.",
            "Bust: if no legal move exists, wet buffer is lost +1 stain.",
            "Window loaded: " .. tostring(pattern_name),
        }
        local panel_x = box_x + RuntimeUI.sized(20)
        local panel_y = box_y + RuntimeUI.sized(96)
        local panel_w = box_w - RuntimeUI.sized(40)
        local panel_h = box_h - RuntimeUI.sized(184)
        love.graphics.setColor(0.30, 0.21, 0.13, 0.90)
        love.graphics.rectangle("fill", panel_x, panel_y, panel_w, panel_h, 8, 8)
        love.graphics.setColor(0.72, 0.55, 0.35, 0.60)
        love.graphics.rectangle("line", panel_x, panel_y, panel_w, panel_h, 8, 8)
        local line_h = RuntimeUI.sized(32)
        for i, text in ipairs(notes) do
            draw_text_center(text, {
                x = panel_x + RuntimeUI.sized(12),
                y = panel_y + RuntimeUI.sized(16) + (i - 1) * line_h,
                w = panel_w - RuntimeUI.sized(24),
                h = RuntimeUI.sized(24),
            }, get_font(15, false), {0.96, 0.92, 0.84, 1})
        end

        draw_text_center("Start when ready.", {
            x = box_x + RuntimeUI.sized(20),
            y = box_y + box_h - RuntimeUI.sized(84),
            w = box_w - RuntimeUI.sized(40),
            h = RuntimeUI.sized(22),
        }, get_font(14, false), {0.95, 0.86, 0.70, 1})

        local button_w = RuntimeUI.sized(260)
        local button_h = RuntimeUI.sized(42)
        local button_rect = {
            x = box_x + (box_w - button_w) * 0.5,
            y = box_y + box_h - RuntimeUI.sized(54),
            w = button_w,
            h = button_h,
        }
        self.ui_hit.setup_start_button = button_rect
        local hover = point_in_rect(self.mouse_x, self.mouse_y, button_rect)
        local alpha = hover and 0.96 or 0.88

        love.graphics.setColor(0.22, 0.45, 0.24, alpha)
        love.graphics.rectangle("fill", button_rect.x, button_rect.y, button_rect.w, button_rect.h, 6, 6)
        love.graphics.setColor(0.70, 0.88, 0.64, alpha)
        love.graphics.rectangle("line", button_rect.x, button_rect.y, button_rect.w, button_rect.h, 6, 6)
        draw_text_center("START RUN", {
            x = button_rect.x,
            y = button_rect.y + RuntimeUI.sized(10),
            w = button_rect.w,
            h = RuntimeUI.sized(22),
        }, get_font(18, true), {0.98, 0.94, 0.86, 1})
    end

    function methods.drawHoveredLockTooltip(self)
        ---@type {text:string}|nil
        local hovered = self.hovered_lock
        if not hovered then
            return
        end
        local text = hovered.text
        if text == "" then
            return
        end

        local font = get_font(13, false)
        love.graphics.setFont(font)
        local padding = RuntimeUI.sized(8)
        local tw = font:getWidth(text)
        local th = font:getHeight()
        local w, h = ui_dimensions()
        local x = clamp(self.mouse_x + RuntimeUI.sized(14), RuntimeUI.sized(8), w - tw - padding * 2 - RuntimeUI.sized(8))
        local y = clamp(self.mouse_y + RuntimeUI.sized(10), RuntimeUI.sized(8), h - th - padding * 2 - RuntimeUI.sized(8))

        love.graphics.setColor(0.14, 0.10, 0.07, 0.94)
        love.graphics.rectangle("fill", x, y, tw + padding * 2, th + padding * 2, 5, 5)
        love.graphics.setColor(0.78, 0.60, 0.40, 0.72)
        love.graphics.rectangle("line", x, y, tw + padding * 2, th + padding * 2, 5, 5)
        love.graphics.setColor(0.96, 0.90, 0.82, 1)
        love.graphics.print(text, x + padding, y + padding)
    end

    return methods
end

return Overlays
