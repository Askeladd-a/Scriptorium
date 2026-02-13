local Layout = {}

function Layout.new(deps)
    local RuntimeUI = deps.RuntimeUI
    local ResolutionManager = deps.ResolutionManager
    local ui_dimensions = deps.ui_dimensions
    local clamp = deps.clamp

    local methods = {}

    local function get_controls_dock_height()
        return RuntimeUI.sized(132)
    end

    function methods.getControlsDockHeight(self)
        return get_controls_dock_height()
    end

    function methods._getTrayRect(self)
        if type(_G.get_dice_tray_rect) == "function" then
            local ok, rect = pcall(_G.get_dice_tray_rect)
            if ok and rect and rect.w and rect.h then
                local x1, y1 = ResolutionManager.to_virtual(rect.x, rect.y)
                local x2, y2 = ResolutionManager.to_virtual(rect.x + rect.w, rect.y + rect.h)
                return {
                    x = x1,
                    y = y1,
                    w = x2 - x1,
                    h = y2 - y1,
                }
            end
        end
        local w, h = ui_dimensions()
        local tray_w = math.max(RuntimeUI.sized(680), w * 0.70)
        local tray_h = math.max(RuntimeUI.sized(250), h * 0.32)
        return {
            x = (w - tray_w) * 0.5,
            y = h - tray_h + RuntimeUI.sized(16),
            w = tray_w,
            h = tray_h,
        }
    end

    function methods.getUnifiedPagePanel(self, screen_w, screen_h)
        local side = clamp(screen_w * 0.03, RuntimeUI.sized(24), RuntimeUI.sized(48))
        local top = RuntimeUI.sized(82)
        local tray = self:_getTrayRect()
        local dock_h = self:getControlsDockHeight()
        local gap_page_dock = RuntimeUI.sized(12)
        local gap_dock_tray = RuntimeUI.sized(14)
        local bottom_limit = tray.y - dock_h - gap_page_dock - gap_dock_tray
        local page_h = clamp(bottom_limit - top, RuntimeUI.sized(500), RuntimeUI.sized(860))
        local page_w = clamp(screen_w - side * 2, RuntimeUI.sized(980), screen_w - RuntimeUI.sized(36))

        return {
            x = math.floor((screen_w - page_w) * 0.5),
            y = top,
            w = page_w,
            h = page_h,
        }
    end

    function methods.getUnifiedZones(self, page)
        local x = page.x
        local y = page.y
        local w = page.w
        local h = page.h

        local main = {
            element = "TEXT",
            title = "Folio",
            rect = {
                x = x + w * 0.12,
                y = y + h * 0.16,
                w = w * 0.76,
                h = h * 0.70,
            }
        }

        return {
            main = main,
            ordered = {main},
        }
    end

    return methods
end

return Layout
