local Helpers = {}

function Helpers.clamp(v, min_v, max_v)
    if v < min_v then
        return min_v
    end
    if v > max_v then
        return max_v
    end
    return v
end

function Helpers.point_in_rect(x, y, rect)
    if not rect then
        return false
    end
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

function Helpers.point_in_ring(x, y, outer, inner)
    if not Helpers.point_in_rect(x, y, outer) then
        return false
    end
    if inner and Helpers.point_in_rect(x, y, inner) then
        return false
    end
    return true
end

function Helpers.project_rect(bg, rx, ry, rw, rh)
    return {
        x = bg.x + rx * bg.sx,
        y = bg.y + ry * bg.sy,
        w = rw * bg.sx,
        h = rh * bg.sy,
    }
end

function Helpers.get_panels_bounds(panels)
    if not panels or #panels == 0 then
        return nil
    end
    local min_x = math.huge
    local min_y = math.huge
    local max_x = -math.huge
    local max_y = -math.huge
    for _, panel in ipairs(panels) do
        local x = panel.x
        local y = panel.y
        local w = panel.w
        local h = panel.h
        if x < min_x then
            min_x = x
        end
        if y < min_y then
            min_y = y
        end
        if x + w > max_x then
            max_x = x + w
        end
        if y + h > max_y then
            max_y = y + h
        end
    end
    if min_x == math.huge then
        return nil
    end
    return {
        x = min_x,
        y = min_y,
        w = max_x - min_x,
        h = max_y - min_y,
    }
end

function Helpers.get_section_progress(elem)
    local committed = elem.cells_filled or 0
    local wet = 0
    if elem.wet then
        for _, placed in pairs(elem.wet) do
            if placed then
                wet = wet + 1
            end
        end
    end
    local total = elem.cells_total or 1
    local filled = committed + wet
    if filled > total then
        filled = total
    end
    return filled, total
end

function Helpers.find_panel_by_element(panels, element)
    if not panels then
        return nil
    end
    for _, panel in ipairs(panels) do
        if panel.element == element then
            return panel
        end
    end
    return nil
end

function Helpers.get_element_display_name(element)
    if element == "TEXT" then
        return "Text"
    end
    if element == "DROPCAPS" then
        return "Dropcaps/Corners"
    end
    if element == "BORDERS" then
        return "Borders"
    end
    if element == "MINIATURE" then
        return "Miniature"
    end
    return tostring(element)
end

function Helpers.get_unlock_tooltip(folio, element)
    local idx = nil
    for i, e in ipairs(folio.ELEMENTS) do
        if e == element then
            idx = i
            break
        end
    end
    if not idx or idx <= 1 then
        return "Locked section"
    end
    local prev = folio.ELEMENTS[idx - 1]
    return "Locked: complete " .. Helpers.get_element_display_name(prev)
end

function Helpers.draw_text_center(text, rect, font, color)
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.printf(text, rect.x + 1, rect.y + 1, rect.w, "center")
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.printf(text, rect.x, rect.y, rect.w, "center")
end

function Helpers.get_remaining_dice_count(results)
    if not results then
        return 0
    end
    local count = 0
    for _, d in ipairs(results) do
        if d and not d.used then
            count = count + 1
        end
    end
    return count
end

function Helpers.get_unusable_dice_count(results)
    if not results then
        return 0
    end
    local count = 0
    for _, d in ipairs(results) do
        if d and d.unusable and not d.burned then
            count = count + 1
        end
    end
    return count
end

function Helpers.get_die_color_key(value, value_to_color)
    return value_to_color[value] or "MARRONE"
end

return Helpers
