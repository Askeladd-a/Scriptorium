-- src/game/scriptorium.lua
-- Scena principale: lo scriptorium con leggio, pergamena e dadi
-- Consolidato: usa src.ui e src.game.folio (con Run integrato)

local Folio = require("src.game.folio")
local UI = require("src.ui")

local Scriptorium = {
    run = nil,
    dice_results = {},
    state = "waiting",  -- waiting, rolling, placing, resolved
    message = nil,
    message_timer = 0,
    selected_cell = nil,  -- {element, row, col} per piazzamento
    selected_die = nil,   -- indice del dado selezionato
}

--- Entra nella scena
function Scriptorium:enter(fascicolo_type, seed)
    -- Usa Folio.Run (Run integrato in folio.lua)
    self.run = Folio.Run.new(fascicolo_type or "BIFOLIO", seed)
    self.dice_results = {}
    self.state = "waiting"
    self.message = nil
    self.message_timer = 0
    
    log("[Scriptorium] Nuova run iniziata: " .. self.run.fascicolo)
end

--- Esce dalla scena
function Scriptorium:exit()
    self.run = nil
end

--- Update
function Scriptorium:update(dt)
    -- Timer messaggi
    if self.message_timer > 0 then
        self.message_timer = self.message_timer - dt
        if self.message_timer <= 0 then
            self.message = nil
            -- Procedi dopo messaggio
            if self.run.current_folio.busted or self.run.current_folio.completed then
                local success, result = self.run:nextFolio()
                if result == "victory" then
                    self:showMessage("VITTORIA!", 5)
                elseif result == "game_over" then
                    self:showMessage("GAME OVER", 5)
                end
            end
        end
    end
end

--- Draw
function Scriptorium:draw()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    
    -- Background scriptorium (placeholder)
    love.graphics.setColor(0.15, 0.12, 0.10)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    -- Disegna leggio/pergamena (più alta per 5 pattern)
    local parch_w = 320
    local parch_h = 480
    self:drawLectern(w/2 - parch_w/2, 30, parch_w, parch_h)
    
    if self.run then
        -- HUD run (top-left) - usa modulo UI consolidato
        UI.drawRunHUD(self.run, 10, 10)
        
        -- Folio display (right side) - usa modulo UI consolidato
        UI.drawFolio(self.run.current_folio, w - 220, 10, 210, 320)
        
        -- Risultati dadi (bottom center) - usa modulo UI consolidato
        if #self.dice_results > 0 then
            local results_w = #self.dice_results * 60 + 20
            UI.drawDiceResults(self.dice_results, w/2 - results_w/2, h - 120)
        end
        
        -- Istruzioni
        love.graphics.setColor(0.7, 0.65, 0.55)
        love.graphics.printf(
            self:getInstructions(),
            0, h - 30, w, "center"
        )
    end
    
    -- Messaggio centrale
    if self.message then
        UI.drawCenterMessage(self.message.text, self.message.subtext)
    end
end

--- Disegna il leggio con pergamena
function Scriptorium:drawLectern(x, y, w, h)
    -- Leggio (legno)
    love.graphics.setColor(0.35, 0.22, 0.12)
    love.graphics.rectangle("fill", x - 20, y + h - 40, w + 40, 60, 4, 4)
    
    -- Supporto
    love.graphics.setColor(0.30, 0.18, 0.10)
    love.graphics.polygon("fill", 
        x + w/2 - 30, y + h + 20,
        x + w/2 + 30, y + h + 20,
        x + w/2 + 50, y + h + 120,
        x + w/2 - 50, y + h + 120
    )
    
    -- Pergamena
    love.graphics.setColor(0.95, 0.90, 0.78)
    love.graphics.rectangle("fill", x, y, w, h, 2, 2)
    
    -- Bordo pergamena
    love.graphics.setColor(0.7, 0.60, 0.45)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 2, 2)
    love.graphics.setLineWidth(1)
    
    -- Contenuto pergamena: tutti i 5 pattern
    if self.run then
        local folio = self.run.current_folio
        
        -- Titolo folio
        love.graphics.setColor(0.2, 0.15, 0.1)
        love.graphics.printf("Folio " .. self.run.current_folio_index, x, y + 8, w, "center")
        
        -- Layout: disponi tutti i 5 elementi sulla pergamena
        local cell_size = 28
        local spacing = 4
        local margin_x = 15
        local curr_y = y + 35
        
        -- Elemento attivo (per evidenziare)
        local active_elem = UI.getActiveElement(folio)
        
        for _, elem_name in ipairs(folio.ELEMENTS) do
            local elem = folio.elements[elem_name]
            local pattern = elem.pattern
            local grid_w = pattern.cols * (cell_size + spacing) - spacing
            local grid_h = pattern.rows * (cell_size + spacing) - spacing
            
            -- Centra orizzontalmente
            local grid_x = x + (w - grid_w) / 2
            
            -- Sfondo evidenziato se attivo
            if elem_name == active_elem then
                love.graphics.setColor(0.9, 0.75, 0.3, 0.15)
                love.graphics.rectangle("fill", x + 5, curr_y - 18, w - 10, grid_h + 38, 4, 4)
            end
            
            -- Nome elemento e pattern (con lock se non sbloccato)
            if elem.unlocked then
                love.graphics.setColor(0.2, 0.15, 0.1)
            else
                love.graphics.setColor(0.5, 0.45, 0.4)
            end
            local lock_icon = elem.unlocked and "" or "🔒 "
            local status = elem.completed and " ✓" or ""
            love.graphics.printf(lock_icon .. elem_name .. ": " .. pattern.name .. status, 
                x + margin_x, curr_y - 15, w - margin_x * 2, "left")
            
            -- Griglia pattern
            UI.drawPatternGrid(folio, elem_name, grid_x, curr_y + 5, cell_size, 
                elem_name == active_elem and self.selected_cell or nil)
            
            -- Overlay scuro se locked
            if not elem.unlocked then
                love.graphics.setColor(0.5, 0.45, 0.4, 0.5)
                love.graphics.rectangle("fill", grid_x - 2, curr_y + 3, grid_w + 4, grid_h + 4, 3, 3)
            end
            
            curr_y = curr_y + grid_h + 35
        end
    end
end

--- Gestisce click
function Scriptorium:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.message then return end  -- Ignora input durante messaggi
    
    -- Il click viene gestito dal main.lua per i dadi
    -- Qui gestiamo solo UI specifiche della scena
end

--- Gestisce tasti
function Scriptorium:keypressed(key)
    if self.message then
        -- Qualsiasi tasto chiude il messaggio
        self.message = nil
        self.message_timer = 0
        return
    end
    
    if key == "space" and self.state == "waiting" then
        -- Lancia dadi (delegato al main.lua tramite callback)
        if self.onRollRequest then
            self.onRollRequest()
        end
    elseif key == "escape" then
        -- Torna al menu (futuro)
        log("[Scriptorium] ESC pressed - menu not implemented yet")
    elseif key == "r" then
        -- Restart run (debug)
        self:enter(self.run and self.run.fascicolo or "BIFOLIO")
    end
end

--- Callback quando i dadi si fermano
---@param values table Array di valori dadi {1-6, 1-6, ...}
function Scriptorium:onDiceSettled(values)
    if not self.run or not values or #values == 0 then return end
    
    self.dice_results = {}
    local folio = self.run.current_folio
    
    -- I dadi ora mostrano valore + colore
    -- Il piazzamento sarà interattivo (seleziona dado → clicca cella)
    -- Per ora: mostra solo i risultati
    for i, value in ipairs(values) do
        table.insert(self.dice_results, {
            value = value,
            used = false,
        })
    end
    
    -- Check stato folio
    if folio.busted then
        self:showMessage("BUST!", "La pergamena è rovinata! -3 Reputazione")
    elseif folio.completed then
        self:showMessage("COMPLETATO!", "Folio terminato con successo!")
    end
    
    self.state = "placing"  -- Nuovo stato: in attesa di piazzamento
end

--- Mostra messaggio centrale
function Scriptorium:showMessage(text, subtext, duration)
    self.message = {text = text, subtext = subtext}
    self.message_timer = duration or 2
end

--- Testo istruzioni
function Scriptorium:getInstructions()
    if self.state == "waiting" then
        return "[SPACE] Lancia dadi  |  [R] Restart  |  [ESC] Menu"
    elseif self.state == "rolling" then
        return "Dadi in volo..."
    elseif self.state == "placing" then
        return "Seleziona dado e piazza sul folio  |  [SPACE] Passa turno"
    else
        return "[SPACE] Continua"
    end
end

--- Wheel per zoom (delegato al 3D)
function Scriptorium:wheelmoved(x, y)
    -- Gestito dal sistema 3D nel main.lua
end

return Scriptorium
