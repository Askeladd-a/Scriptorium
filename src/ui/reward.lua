-- src/ui/reward.lua
-- UI per la selezione della ricompensa (tool)

local RewardUI = {}

local COLORS = {
    panel = {0.12, 0.10, 0.08, 0.95},
    border = {0.9, 0.75, 0.3},
    text = {0.95, 0.90, 0.80},
    selected = {0.2, 0.7, 0.3},
    icon = {0.95, 0.85, 0.3},
}

--- Disegna la schermata di reward
---@param tools table Lista di 3 tool
---@param selected integer Indice selezionato (1-3)
function RewardUI.draw(tools, selected)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local panel_w, panel_h = 600, 320
    local x, y = (w - panel_w) / 2, (h - panel_h) / 2

    -- Background panel
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", x, y, panel_w, panel_h, 16, 16)
    love.graphics.setColor(COLORS.border)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", x, y, panel_w, panel_h, 16, 16)
    love.graphics.setLineWidth(1)

    -- Titolo
    love.graphics.setColor(COLORS.text)
    love.graphics.printf("Scegli una ricompensa", x, y + 18, panel_w, "center")

    -- Tool cards
    local card_w, card_h = 160, 200
    local gap = 40
    for i, tool in ipairs(tools) do
        local cx = x + 40 + (i-1)*(card_w+gap)
        local cy = y + 60
        -- Card bg
        love.graphics.setColor(i == selected and COLORS.selected or COLORS.panel)
        love.graphics.rectangle("fill", cx, cy, card_w, card_h, 10, 10)
        love.graphics.setColor(COLORS.border)
        love.graphics.rectangle("line", cx, cy, card_w, card_h, 10, 10)
        -- Icona
        love.graphics.setColor(COLORS.icon)
        love.graphics.printf(tool.icon or "?", cx, cy+18, card_w, "center")
        -- Nome
        love.graphics.setColor(COLORS.text)
        love.graphics.printf(tool.name, cx, cy+60, card_w, "center")
        -- Descrizione
        love.graphics.setColor(COLORS.text)
        love.graphics.printf(tool.description, cx+10, cy+90, card_w-20, "left")
        -- Uses
        love.graphics.setColor(COLORS.icon)
        love.graphics.printf("Usi: "..tostring(tool.uses), cx, cy+card_h-30, card_w, "center")
    end
end

return RewardUI
