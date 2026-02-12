-- src/ui/dice_results.lua
-- Display risultati dadi con interpretazione

local DiceResults = {}

local COLORS = {
    panel = {0.1, 0.08, 0.06, 0.9},
    text = {0.95, 0.90, 0.80},
    stain = {0.8, 0.2, 0.2},
    fill = {0.3, 0.7, 0.4},
    golden = {0.95, 0.8, 0.3},
}

local DIE_DISPLAY = {
    [1] = {color = COLORS.stain, label = "STAIN!"},
    [2] = {color = COLORS.fill, label = "+1 slot"},
    [3] = {color = COLORS.fill, label = "+1 slot"},
    [4] = {color = COLORS.fill, label = "+1 slot"},
    [5] = {color = COLORS.fill, label = "+1 slot"},
    [6] = {color = COLORS.golden, label = "GOLD!"},
}

--- Disegna pannello risultati dadi
---@param results table Array di {value, interpretation}
---@param x number Posizione X
---@param y number Posizione Y
function DiceResults.draw(results, x, y)
    if not results or #results == 0 then return end
    
    local die_size = 50
    local spacing = 10
    local w = (#results * (die_size + spacing)) + spacing
    local h = die_size + 40
    
    -- Background
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    
    -- Disegna ogni dado
    for i, result in ipairs(results) do
        local dx = x + spacing + (i-1) * (die_size + spacing)
        local dy = y + spacing
        DiceResults.drawDie(result.value, dx, dy, die_size)
    end
end

--- Disegna singolo dado stilizzato
function DiceResults.drawDie(value, x, y, size)
    local display = DIE_DISPLAY[value] or {color = COLORS.text, label = "?"}
    
    -- Background dado
    love.graphics.setColor(0.9, 0.85, 0.75)
    love.graphics.rectangle("fill", x, y, size, size, 4, 4)
    
    -- Bordo colorato per tipo
    love.graphics.setColor(display.color)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, size, size, 4, 4)
    love.graphics.setLineWidth(1)
    
    -- Valore
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.printf(tostring(value), x, y + size/2 - 10, size, "center")
    
    -- Label sotto
    love.graphics.setColor(display.color)
    love.graphics.printf(display.label, x - 10, y + size + 2, size + 20, "center")
end

return DiceResults
