-- src/ui/folio_display.lua
-- Renderizza lo stato del Folio corrente (checklist, macchie, progresso)

local FolioDisplay = {}

local COLORS = {
    background = {0.12, 0.10, 0.08, 0.9},
    parchment = {0.95, 0.90, 0.80},
    text = {0.15, 0.10, 0.05},
    stain = {0.6, 0.1, 0.1},
    gold = {0.9, 0.75, 0.3},
    locked = {0.5, 0.5, 0.5, 0.5},
    progress_bg = {0.3, 0.25, 0.2},
    progress_fill = {0.4, 0.6, 0.3},
    completed = {0.2, 0.7, 0.3},
}

local ELEMENT_ICONS = {
    TEXT = "T",
    DROPCAPS = "D",
    BORDERS = "B",
    CORNERS = "C",
    MINIATURE = "M",
}

--- Disegna il display del folio
---@param folio table Istanza Folio
---@param x number Posizione X
---@param y number Posizione Y
---@param w number Larghezza
---@param h number Altezza
function FolioDisplay.draw(folio, x, y, w, h)
    if not folio then return end
    
    local padding = 10
    local element_height = 40
    
    -- Background pannello
    love.graphics.setColor(COLORS.background)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    
    -- Titolo
    love.graphics.setColor(COLORS.parchment)
    love.graphics.printf("FOLIO", x, y + padding, w, "center")
    
    -- Indicatore macchie
    local stain_y = y + padding + 25
    FolioDisplay.drawStainMeter(folio, x + padding, stain_y, w - padding*2, 20)
    
    -- Checklist elementi
    local list_y = stain_y + 35
    for i, elem_name in ipairs(folio.ELEMENTS) do
        local elem = folio.elements[elem_name]
        FolioDisplay.drawElement(elem_name, elem, x + padding, list_y, w - padding*2, element_height)
        list_y = list_y + element_height + 5
    end
    
    -- Shield indicator
    if folio.shield > 0 then
        love.graphics.setColor(COLORS.gold)
        love.graphics.printf("🛡 " .. folio.shield, x, list_y + 5, w, "center")
    end
end

--- Disegna meter macchie
function FolioDisplay.drawStainMeter(folio, x, y, w, h)
    local ratio = folio.stain_count / folio.stain_threshold
    
    -- Background
    love.graphics.setColor(COLORS.progress_bg)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    
    -- Fill (diventa rosso quando alto)
    local r = 0.3 + ratio * 0.5
    local g = 0.5 - ratio * 0.4
    love.graphics.setColor(r, g, 0.2)
    love.graphics.rectangle("fill", x, y, w * ratio, h, 4, 4)
    
    -- Bordo
    love.graphics.setColor(COLORS.stain)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
    
    -- Testo
    love.graphics.setColor(COLORS.parchment)
    love.graphics.printf(
        string.format("Stain: %d/%d", folio.stain_count, folio.stain_threshold),
        x, y + 3, w, "center"
    )
end

--- Disegna singolo elemento checklist
function FolioDisplay.drawElement(name, elem, x, y, w, h)
    local icon = ELEMENT_ICONS[name] or "?"
    local is_active = elem.unlocked and not elem.completed
    
    -- Background elemento
    if elem.completed then
        love.graphics.setColor(COLORS.completed[1], COLORS.completed[2], COLORS.completed[3], 0.3)
    elseif elem.unlocked then
        love.graphics.setColor(COLORS.parchment[1], COLORS.parchment[2], COLORS.parchment[3], 0.2)
    else
        love.graphics.setColor(COLORS.locked)
    end
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    
    -- Icona
    local icon_size = h - 8
    if elem.unlocked then
        love.graphics.setColor(is_active and COLORS.gold or COLORS.completed)
    else
        love.graphics.setColor(COLORS.locked)
    end
    love.graphics.rectangle("fill", x + 4, y + 4, icon_size, icon_size, 2, 2)
    love.graphics.setColor(COLORS.text)
    love.graphics.printf(icon, x + 4, y + 8, icon_size, "center")
    
    -- Nome
    local text_x = x + icon_size + 12
    love.graphics.setColor(elem.unlocked and COLORS.text or COLORS.locked)
    love.graphics.print(name, text_x, y + 5)
    
    -- Progress bar
    if elem.unlocked then
        local bar_w = w - icon_size - 80
        local bar_h = 12
        local bar_x = text_x
        local bar_y = y + h - bar_h - 6
        
        -- Background bar
        love.graphics.setColor(COLORS.progress_bg)
        love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 2, 2)
        
        -- Fill bar
        local fill_ratio = elem.cells_filled / elem.cells_total
        if fill_ratio > 0 then
            love.graphics.setColor(elem.completed and COLORS.completed or COLORS.progress_fill)
            love.graphics.rectangle("fill", bar_x, bar_y, bar_w * fill_ratio, bar_h, 2, 2)
        end
        
        -- Slot text
        love.graphics.setColor(COLORS.parchment)
        love.graphics.printf(
            string.format("%d/%d", elem.cells_filled, elem.cells_total),
            bar_x + bar_w + 5, bar_y - 1, 40, "left"
        )
    end
    
    -- Bordo se attivo
    if is_active then
        love.graphics.setColor(COLORS.gold)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, w, h, 4, 4)
        love.graphics.setLineWidth(1)
    end
end

return FolioDisplay
