-- src/ui.lua
-- Componenti UI consolidati per Scriptorium Alchimico

local RuntimeUI = require("src.core.runtime_ui")

local UI = {}

local font_cache = {}

local function get_font(px)
    local size = RuntimeUI.sized(px)
    if not font_cache[size] then
        local ok, font = pcall(function()
            return love.graphics.newFont(size)
        end)
        font_cache[size] = ok and font or love.graphics.getFont()
    end
    return font_cache[size]
end

-- ══════════════════════════════════════════════════════════════════
-- COLORI CONDIVISI
-- ══════════════════════════════════════════════════════════════════

UI.COLORS = {
    panel = {0.08, 0.06, 0.04, 0.85},
    background = {0.12, 0.10, 0.08, 0.9},
    parchment = {0.95, 0.90, 0.80},
    text = {0.15, 0.10, 0.05},
    text_light = {0.95, 0.90, 0.80},
    stain = {0.6, 0.1, 0.1},
    gold = {0.9, 0.75, 0.3},
    locked = {0.5, 0.5, 0.5, 0.5},
    progress_bg = {0.3, 0.25, 0.2},
    progress_fill = {0.4, 0.6, 0.3},
    completed = {0.2, 0.7, 0.3},
    reputation = {0.8, 0.3, 0.3},
}

-- Colori per vincoli pattern (corrispondono a DiceFaces)
UI.CONSTRAINT_COLORS = {
    MARRONE = {0.55, 0.35, 0.20},
    VERDE   = {0.25, 0.55, 0.30},
    NERO    = {0.15, 0.12, 0.10},
    ROSSO   = {0.70, 0.20, 0.15},
    BLU     = {0.20, 0.35, 0.65},
    GIALLO  = {0.85, 0.70, 0.25},
    VIOLA   = {0.50, 0.25, 0.55},
    BIANCO  = {0.95, 0.93, 0.88},
}

local ELEMENT_ICONS = {
    TEXT = "T",
    DROPCAPS = "D",
    BORDERS = "B",
    CORNERS = "C",
    MINIATURE = "M",
}

-- ══════════════════════════════════════════════════════════════════
-- RUN HUD
-- ══════════════════════════════════════════════════════════════════

--- Disegna HUD run
---@param run table Istanza Run
---@param x number Posizione X
---@param y number Posizione Y  
function UI.drawRunHUD(run, x, y)
    if not run then return end
    
    local high_contrast = RuntimeUI.high_contrast()
    local previous_font = love.graphics.getFont()
    local hud_font = get_font(16)
    love.graphics.setFont(hud_font)

    local status = run:getStatus()
    local padding = RuntimeUI.sized(10)
    local line_height = RuntimeUI.sized(22)
    local w = RuntimeUI.sized(196)
    local h = padding * 2 + line_height * 4
    
    -- Background
    love.graphics.setColor(UI.COLORS.panel[1], UI.COLORS.panel[2], UI.COLORS.panel[3], high_contrast and 0.95 or UI.COLORS.panel[4])
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    
    local text_x = x + padding
    local text_y = y + padding
    
    -- Fascicolo
    love.graphics.setColor(high_contrast and 1.0 or UI.COLORS.text_light[1], high_contrast and 0.96 or UI.COLORS.text_light[2], high_contrast and 0.88 or UI.COLORS.text_light[3], 1)
    love.graphics.print(status.fascicolo, text_x, text_y)
    text_y = text_y + line_height
    
    -- Folio progress
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Folio: " .. status.folio, text_x, text_y)
    text_y = text_y + line_height
    
    -- Reputation
    love.graphics.setColor(UI.COLORS.reputation)
    love.graphics.print("♥ " .. status.reputation, text_x, text_y)
    
    -- Coins
    love.graphics.setColor(UI.COLORS.gold)
    love.graphics.print("⚜ " .. status.coins, text_x + RuntimeUI.sized(74), text_y)
    love.graphics.setFont(previous_font)
end

--- Disegna messaggio centrale (es. "BUST!", "COMPLETATO!")
function UI.drawCenterMessage(message, subtext)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local high_contrast = RuntimeUI.high_contrast()
    local previous_font = love.graphics.getFont()
    
    -- Overlay scuro
    love.graphics.setColor(0, 0, 0, high_contrast and 0.80 or 0.70)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    -- Messaggio principale
    love.graphics.setFont(get_font(48))
    love.graphics.setColor(UI.COLORS.gold)
    love.graphics.printf(message, 0, h / 2 - RuntimeUI.sized(54), w, "center")
    
    -- Sottotesto
    if subtext then
        love.graphics.setFont(get_font(24))
        love.graphics.setColor(high_contrast and 1.0 or UI.COLORS.text_light[1], high_contrast and 0.96 or UI.COLORS.text_light[2], high_contrast and 0.88 or UI.COLORS.text_light[3], 1)
        love.graphics.printf(subtext, 0, h / 2 + RuntimeUI.sized(12), w, "center")
    end
    love.graphics.setFont(previous_font)
end

-- ══════════════════════════════════════════════════════════════════
-- FOLIO DISPLAY
-- ══════════════════════════════════════════════════════════════════

--- Disegna il display del folio
---@param folio table Istanza Folio
---@param x number Posizione X
---@param y number Posizione Y
---@param w number Larghezza
---@param h number Altezza
function UI.drawFolio(folio, x, y, w, h)
    if not folio then return end
    local high_contrast = RuntimeUI.high_contrast()
    local previous_font = love.graphics.getFont()
    
    local padding = RuntimeUI.sized(10)
    local element_height = RuntimeUI.sized(40)
    love.graphics.setFont(get_font(16))
    
    -- Background pannello
    love.graphics.setColor(UI.COLORS.background[1], UI.COLORS.background[2], UI.COLORS.background[3], high_contrast and 0.96 or UI.COLORS.background[4])
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    
    -- Titolo
    love.graphics.setFont(get_font(20))
    love.graphics.setColor(high_contrast and 1.0 or UI.COLORS.parchment[1], high_contrast and 0.95 or UI.COLORS.parchment[2], high_contrast and 0.85 or UI.COLORS.parchment[3], 1)
    love.graphics.printf("FOLIO", x, y + padding, w, "center")
    
    -- Indicatore macchie
    local stain_y = y + padding + RuntimeUI.sized(28)
    UI.drawStainMeter(folio, x + padding, stain_y, w - padding * 2, RuntimeUI.sized(20))
    
    -- Checklist elementi
    local list_y = stain_y + RuntimeUI.sized(35)
    for i, elem_name in ipairs(folio.ELEMENTS) do
        local elem = folio.elements[elem_name]
        UI.drawElement(elem_name, elem, x + padding, list_y, w - padding * 2, element_height)
        list_y = list_y + element_height + 5
    end
    
    -- Shield indicator
    if folio.shield > 0 then
        love.graphics.setFont(get_font(16))
        love.graphics.setColor(UI.COLORS.gold)
        love.graphics.printf("🛡 " .. folio.shield, x, list_y + 5, w, "center")
    end
    love.graphics.setFont(previous_font)
end

--- Disegna meter macchie
function UI.drawStainMeter(folio, x, y, w, h)
    local high_contrast = RuntimeUI.high_contrast()
    local ratio = folio.stain_count / folio.stain_threshold
    if ratio < 0 then ratio = 0 end
    if ratio > 1 then ratio = 1 end
    
    -- Background
    love.graphics.setColor(UI.COLORS.progress_bg)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    
    -- Fill (diventa rosso quando alto)
    local r = 0.3 + ratio * 0.5
    local g = 0.5 - ratio * 0.4
    love.graphics.setColor(r, g, 0.2)
    love.graphics.rectangle("fill", x, y, w * ratio, h, 4, 4)
    
    -- Bordo
    love.graphics.setColor(UI.COLORS.stain)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
    
    -- Testo
    love.graphics.setColor(high_contrast and 1.0 or UI.COLORS.parchment[1], high_contrast and 0.96 or UI.COLORS.parchment[2], high_contrast and 0.86 or UI.COLORS.parchment[3], 1)
    love.graphics.setFont(get_font(14))
    love.graphics.printf(
        string.format("Stain: %d/%d", folio.stain_count, folio.stain_threshold),
        x, y + RuntimeUI.sized(3), w, "center"
    )
end

--- Disegna singolo elemento checklist
function UI.drawElement(name, elem, x, y, w, h)
    local high_contrast = RuntimeUI.high_contrast()
    local icon = ELEMENT_ICONS[name] or "?"
    local is_active = elem.unlocked and not elem.completed
    
    -- Background elemento
    if elem.completed then
        love.graphics.setColor(UI.COLORS.completed[1], UI.COLORS.completed[2], UI.COLORS.completed[3], 0.3)
    elseif elem.unlocked then
        love.graphics.setColor(UI.COLORS.parchment[1], UI.COLORS.parchment[2], UI.COLORS.parchment[3], 0.2)
    else
        love.graphics.setColor(UI.COLORS.locked)
    end
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    
    -- Icona
    local icon_size = h - RuntimeUI.sized(8)
    if elem.unlocked then
        love.graphics.setColor(is_active and UI.COLORS.gold or UI.COLORS.completed)
    else
        love.graphics.setColor(UI.COLORS.locked)
    end
    love.graphics.rectangle("fill", x + RuntimeUI.sized(4), y + RuntimeUI.sized(4), icon_size, icon_size, 2, 2)
    love.graphics.setFont(get_font(14))
    love.graphics.setColor(high_contrast and 0.08 or UI.COLORS.text[1], high_contrast and 0.06 or UI.COLORS.text[2], high_contrast and 0.04 or UI.COLORS.text[3], 1)
    love.graphics.printf(icon, x + RuntimeUI.sized(4), y + RuntimeUI.sized(8), icon_size, "center")
    
    -- Nome
    local text_x = x + icon_size + RuntimeUI.sized(12)
    love.graphics.setFont(get_font(14))
    love.graphics.setColor(elem.unlocked and UI.COLORS.text or UI.COLORS.locked)
    love.graphics.print(name, text_x, y + RuntimeUI.sized(5))
    
    -- Progress bar
    if elem.unlocked then
        local bar_w = w - icon_size - RuntimeUI.sized(86)
        local bar_h = RuntimeUI.sized(12)
        local bar_x = text_x
        local bar_y = y + h - bar_h - RuntimeUI.sized(6)
        
        -- Background bar
        love.graphics.setColor(UI.COLORS.progress_bg)
        love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 2, 2)
        
        -- Fill bar
        local fill_ratio = elem.cells_filled / elem.cells_total
        if fill_ratio > 0 then
            love.graphics.setColor(elem.completed and UI.COLORS.completed or UI.COLORS.progress_fill)
            love.graphics.rectangle("fill", bar_x, bar_y, bar_w * fill_ratio, bar_h, 2, 2)
        end
        
        -- Slot text
        love.graphics.setFont(get_font(12))
        love.graphics.setColor(UI.COLORS.parchment)
        love.graphics.printf(
            string.format("%d/%d", elem.cells_filled, elem.cells_total),
            bar_x + bar_w + RuntimeUI.sized(5), bar_y - RuntimeUI.sized(1), RuntimeUI.sized(40), "left"
        )
    end
    
    -- Bordo se attivo
    if is_active then
        love.graphics.setColor(UI.COLORS.gold)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, w, h, 4, 4)
        love.graphics.setLineWidth(1)
    end
end

-- ══════════════════════════════════════════════════════════════════
-- DICE RESULTS
-- ══════════════════════════════════════════════════════════════════

local DIE_DISPLAY = {
    [1] = {color = UI.COLORS.stain, label = "STAIN!"},
    [2] = {color = UI.COLORS.progress_fill, label = "+1 slot"},
    [3] = {color = UI.COLORS.progress_fill, label = "+1 slot"},
    [4] = {color = UI.COLORS.progress_fill, label = "+1 slot"},
    [5] = {color = UI.COLORS.progress_fill, label = "+1 slot"},
    [6] = {color = UI.COLORS.gold, label = "GOLD!"},
}

--- Disegna pannello risultati dadi
---@param results table Array di {value, used}
---@param x number Posizione X
---@param y number Posizione Y
function UI.drawDiceResults(results, x, y)
    if not results or #results == 0 then return end
    
    local die_size = RuntimeUI.sized(50)
    local spacing = RuntimeUI.sized(10)
    local w = (#results * (die_size + spacing)) + spacing
    local h = die_size + RuntimeUI.sized(40)
    
    -- Background
    love.graphics.setColor(UI.COLORS.panel[1], UI.COLORS.panel[2], UI.COLORS.panel[3], RuntimeUI.high_contrast() and 0.94 or UI.COLORS.panel[4])
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    
    -- Disegna ogni dado
    for i, result in ipairs(results) do
        local dx = x + spacing + (i-1) * (die_size + spacing)
        local dy = y + spacing
        UI.drawDie(result.value, dx, dy, die_size, result.used)
    end
end

--- Disegna singolo dado stilizzato
function UI.drawDie(value, x, y, size, used)
    local previous_font = love.graphics.getFont()
    local display = DIE_DISPLAY[value] or {color = UI.COLORS.text_light, label = "?"}
    
    -- Background dado
    if used then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
    else
        love.graphics.setColor(0.9, 0.85, 0.75)
    end
    love.graphics.rectangle("fill", x, y, size, size, 4, 4)
    
    -- Bordo colorato per tipo
    love.graphics.setColor(display.color)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, size, size, 4, 4)
    love.graphics.setLineWidth(1)
    
    -- Valore
    love.graphics.setFont(get_font(math.floor(size * 0.45)))
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.printf(tostring(value), x, y + size / 2 - RuntimeUI.sized(10), size, "center")
    
    -- Label sotto
    if not used then
        love.graphics.setFont(get_font(14))
        love.graphics.setColor(display.color)
        love.graphics.printf(display.label, x - RuntimeUI.sized(10), y + size + RuntimeUI.sized(2), size + RuntimeUI.sized(20), "center")
    end
    love.graphics.setFont(previous_font)
end

-- ══════════════════════════════════════════════════════════════════
-- PATTERN GRID (visualizzazione griglia elementi)
-- ══════════════════════════════════════════════════════════════════

--- Disegna la griglia pattern di un elemento
---@param folio table Istanza Folio
---@param element_name string Nome elemento (TEXT, DROPCAPS, etc.)
---@param x number Posizione X (top-left)
---@param y number Posizione Y (top-left)
---@param cell_size number Dimensione cella in pixel
---@param selected_cell table|nil {row, col} cella selezionata (opzionale)
---@param highlight_cells table|nil {row, col} celle piazzabili evidenziate
function UI.drawPatternGrid(folio, element_name, x, y, cell_size, selected_cell, highlight_cells)
    if not folio then return end
    local high_contrast = RuntimeUI.high_contrast()
    local elem = folio.elements[element_name]
    if not elem then return end
    local previous_font = love.graphics.getFont()
    local pattern = elem.pattern
    local spacing = 4
    local total_w = pattern.cols * (cell_size + spacing) - spacing
    local total_h = pattern.rows * (cell_size + spacing) - spacing
    -- Titolo pattern
    love.graphics.setFont(get_font(14))
    love.graphics.setColor(high_contrast and 0.08 or UI.COLORS.text[1], high_contrast and 0.06 or UI.COLORS.text[2], high_contrast and 0.04 or UI.COLORS.text[3], 1)
    love.graphics.printf(pattern.name, x, y - 25, total_w, "center")
    -- Prepara lookup highlight
    local highlight_lookup = {}
    if highlight_cells then
        for _, cell in ipairs(highlight_cells) do
            highlight_lookup[cell.row .. ":" .. cell.col] = true
        end
    end
    -- Disegna ogni cella
    for row = 1, pattern.rows do
        for col = 1, pattern.cols do
            local cx = x + (col - 1) * (cell_size + spacing)
            local cy = y + (row - 1) * (cell_size + spacing)
            local index = (row - 1) * pattern.cols + col
            local constraint = pattern.grid[index]
            local placed = elem.placed[index]
            local is_selected = selected_cell and selected_cell.row == row and selected_cell.col == col
            local is_highlight = highlight_lookup[row .. ":" .. col] == true
            UI.drawPatternCell(cx, cy, cell_size, constraint, placed, is_selected, is_highlight)
        end
    end
    -- Progress sotto la griglia
    love.graphics.setFont(get_font(12))
    love.graphics.setColor(high_contrast and 0.08 or UI.COLORS.text[1], high_contrast and 0.06 or UI.COLORS.text[2], high_contrast and 0.04 or UI.COLORS.text[3], 1)
    love.graphics.printf(
        string.format("%d/%d", elem.cells_filled, elem.cells_total),
        x, y + total_h + 8, total_w, "center"
    )
    love.graphics.setFont(previous_font)
    return total_w, total_h
end

--- Disegna singola cella del pattern
---@param x number Posizione X
---@param y number Posizione Y
---@param size number Dimensione cella
---@param constraint any Vincolo (nil, string colore, number valore)
---@param placed table|nil Dado piazzato {value, color, pigment}
---@param selected boolean Se la cella è selezionata
---@param highlight boolean Se la cella è piazzabile e evidenziata
function UI.drawPatternCell(x, y, size, constraint, placed, selected, highlight)
    local high_contrast = RuntimeUI.high_contrast()
    local previous_font = love.graphics.getFont()
    -- Background cella
    if placed then
        -- Cella con dado piazzato
        local color = UI.CONSTRAINT_COLORS[placed.color] or {0.5, 0.5, 0.5}
        love.graphics.setColor(color[1], color[2], color[3], 0.9)
        love.graphics.rectangle("fill", x, y, size, size, 4, 4)
        -- Valore dado
        love.graphics.setFont(get_font(math.floor(size * 0.45)))
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(tostring(placed.value), x, y + size/2 - 10, size, "center")
    elseif constraint then
        -- Cella con vincolo
        if type(constraint) == "number" then
            -- Vincolo numerico
            love.graphics.setColor(0.85, 0.80, 0.70)
            love.graphics.rectangle("fill", x, y, size, size, 4, 4)
            love.graphics.setFont(get_font(math.floor(size * 0.42)))
            love.graphics.setColor(UI.COLORS.text)
            love.graphics.printf(tostring(constraint), x, y + size/2 - 10, size, "center")
        else
            -- Vincolo colore
            local color = UI.CONSTRAINT_COLORS[constraint] or {0.5, 0.5, 0.5}
            love.graphics.setColor(color[1], color[2], color[3], 0.4)
            love.graphics.rectangle("fill", x, y, size, size, 4, 4)
            -- Bordo colorato
            love.graphics.setColor(color[1], color[2], color[3], 0.9)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, y, size, size, 4, 4)
            love.graphics.setLineWidth(1)
        end
    else
        -- Cella libera
        love.graphics.setColor(0.90, 0.87, 0.80)
        love.graphics.rectangle("fill", x, y, size, size, 4, 4)
    end
    -- Bordo highlight piazzabile
    if highlight then
        if high_contrast then
            love.graphics.setColor(0.05, 0.45, 1.0, 0.92)
        else
            love.graphics.setColor(0.2, 0.5, 1.0, 0.7) -- bright blue
        end
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 5, 5)
        love.graphics.setLineWidth(1)
    end
    -- Bordo selezione
    if selected then
        love.graphics.setColor(UI.COLORS.gold)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 5, 5)
        love.graphics.setLineWidth(1)
    end
    -- Bordo base (se non piazzato)
    if not placed and not selected then
        love.graphics.setColor(0.6, 0.55, 0.45, 0.5)
        love.graphics.rectangle("line", x, y, size, size, 4, 4)
    end
    love.graphics.setFont(previous_font)
end

--- Disegna tutte le griglie degli elementi sbloccati
---@param folio table Istanza Folio
---@param x number Posizione X iniziale
---@param y number Posizione Y iniziale
---@param cell_size number Dimensione celle
---@param active_element string|nil Elemento attivo (evidenziato)
function UI.drawAllPatternGrids(folio, x, y, cell_size, active_element)
    if not folio then return end
    
    local curr_x = x
    local spacing_between = 30
    local max_height = 0
    
    for _, elem_name in ipairs(folio.ELEMENTS) do
        local elem = folio.elements[elem_name]
        if elem.unlocked then
            local pattern = elem.pattern
            local grid_w = pattern.cols * (cell_size + 4) - 4
            local grid_h = pattern.rows * (cell_size + 4) - 4
            
            -- Evidenzia elemento attivo
            if elem_name == active_element then
                love.graphics.setColor(UI.COLORS.gold[1], UI.COLORS.gold[2], UI.COLORS.gold[3], 0.2)
                love.graphics.rectangle("fill", curr_x - 5, y - 30, grid_w + 10, grid_h + 60, 6, 6)
            end
            
            -- Disegna griglia
            UI.drawPatternGrid(folio, elem_name, curr_x, y, cell_size, nil, {{"row", 1}, {"col", 1}})
            
            curr_x = curr_x + grid_w + spacing_between
            max_height = math.max(max_height, grid_h)
        end
    end
    
    return curr_x - x - spacing_between, max_height
end

--- Ottiene l'elemento attivo (primo sbloccato non completato)
function UI.getActiveElement(folio)
    if not folio then return nil end
    for _, elem_name in ipairs(folio.ELEMENTS) do
        local elem = folio.elements[elem_name]
        if elem.unlocked and not elem.completed then
            return elem_name
        end
    end
    return nil
end

-- ══════════════════════════════════════════════════════════════════
-- BOTTONI PUSH/STOP
-- ══════════════════════════════════════════════════════════════════

UI.PUSHSTOP_BUTTONS = {
    push = { label = "✒️ Push", icon = "✒️", x = 0, y = 0, w = 110, h = 38, active = true },
    stop = { label = "✋ Stop", icon = "✋", x = 0, y = 0, w = 110, h = 38, active = true },
}

--- Disegna i bottoni Push/Stop nell'area bottoni
-- @param x number posizione X centro area bottoni
-- @param y number posizione Y top area bottoni
-- @param spacing number spazio tra i bottoni
-- @param state table {push_active, stop_active}
function UI.drawPushStopButtons(x, y, spacing, state)
    local btn_push = UI.PUSHSTOP_BUTTONS.push
    local btn_stop = UI.PUSHSTOP_BUTTONS.stop
    btn_push.x = x - btn_push.w - spacing/2
    btn_push.y = y
    btn_stop.x = x + spacing/2
    btn_stop.y = y
    -- Push
    love.graphics.setColor(0.85, 0.80, 0.70, state.push_active and 1 or 0.6)
    love.graphics.rectangle("fill", btn_push.x, btn_push.y, btn_push.w, btn_push.h, 7, 7)
    love.graphics.setColor(state.push_active and UI.COLORS.gold or {0.6,0.6,0.6})
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", btn_push.x, btn_push.y, btn_push.w, btn_push.h, 7, 7)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.2,0.15,0.1)
    love.graphics.printf(btn_push.label, btn_push.x, btn_push.y+8, btn_push.w, "center")
    -- Stop
    love.graphics.setColor(0.85, 0.80, 0.70, state.stop_active and 1 or 0.6)
    love.graphics.rectangle("fill", btn_stop.x, btn_stop.y, btn_stop.w, btn_stop.h, 7, 7)
    love.graphics.setColor(state.stop_active and UI.COLORS.gold or {0.6,0.6,0.6})
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", btn_stop.x, btn_stop.y, btn_stop.w, btn_stop.h, 7, 7)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.2,0.15,0.1)
    love.graphics.printf(btn_stop.label, btn_stop.x, btn_stop.y+8, btn_stop.w, "center")
end

return UI
