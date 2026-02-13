-- src/game/run.lua
-- Gestisce una run completa (fascicolo di N folii)

local FolioModule = require("src.game.folio")
local Folio = FolioModule.Folio or FolioModule
local RuntimeUI = require("src.core.runtime_ui")
local MVPDecks = require("src.content.mvp_decks")

local Run = {}
Run.__index = Run

-- Tipi di fascicolo e numero di folii
Run.FASCICOLI = {
    BIFOLIO = 2,
    DUERNO = 4,
    TERNIONE = 6,
    QUATERNIONE = 8,
    QUINTERNO = 10,
    SESTERNO = 12,
}

--- Crea una nuova run
---@param fascicolo_type string Tipo di fascicolo
---@param seed number Seed per RNG riproducibile (opzionale)
function Run.new(fascicolo_type, seed)
    local self = setmetatable({}, Run)
    
    self.fascicolo = fascicolo_type or "BIFOLIO"
    self.total_folii = Run.FASCICOLI[self.fascicolo] or 2
    
    -- Seed riproducibile
    self.seed = seed or os.time()
    math.randomseed(self.seed)
    if love and love.math then
        love.math.setRandomSeed(self.seed)
    end
    log("[Run] Seed: " .. self.seed)
    self.rule_setup = MVPDecks.draw_run_setup(self.seed + 101)
    
    -- Stato run
    self.current_folio_index = 1
    self.current_folio = Folio.new(self.fascicolo, self.seed + 1, self.rule_setup)
    self.completed_folii = {}
    
    -- Risorse player
    self.reputation = 20  -- HP della run
    self.coins = 0
    
    -- Inventario (pigmenti, leganti scelti)
    self.inventory = {
        pigments = {},
        binders = {},
    }
    
    -- Stato
    self.game_over = false
    self.victory = false
    
    return self
end

--- Avanza al folio successivo
function Run:nextFolio()
    if self.current_folio.completed then
        -- Calcola reward
        local reward = self:calculateFolioReward()
        self.coins = self.coins + reward.coins
        self.reputation = self.reputation + reward.reputation
        
        log(string.format("[Run] Folio %d completed! +%d coins, +%d rep", 
            self.current_folio_index, reward.coins, reward.reputation))
        
        table.insert(self.completed_folii, self.current_folio)
        self.current_folio_index = self.current_folio_index + 1
        
        -- Victory check
        if self.current_folio_index > self.total_folii then
            self.victory = true
            log("[Run] VICTORY! Folio set completed!")
            return true, "victory"
        end
        
        -- Nuovo folio
        self.current_folio = Folio.new(self.fascicolo, self.seed + self.current_folio_index, self.rule_setup)
        return true, "next"
        
    elseif self.current_folio.busted then
        -- Folio perso
        local rep_loss = 3
        self.reputation = self.reputation - rep_loss
        log(string.format("[Run] Folio BUST! -%d reputation (now: %d)", rep_loss, self.reputation))
        
        -- Check game over
        if self.reputation <= 0 then
            self.game_over = true
            log("[Run] GAME OVER! Reputation depleted!")
            return false, "game_over"
        end
        
        -- Nuovo folio (stessa posizione, si riprova)
        self.current_folio = Folio.new(self.fascicolo, self.seed + self.current_folio_index + 1000, self.rule_setup)
        return true, "retry"
    end
    
    return false, "in_progress"
end

--- Calcola reward per folio completato
function Run:calculateFolioReward()
    local reward = {coins = 30, reputation = 0}  -- Base
    
    local folio = self.current_folio
    for elem, bonus in pairs(Folio.BONUS) do
        if folio.elements[elem].completed then
            reward.coins = reward.coins + (bonus.coins or 0)
            reward.reputation = reward.reputation + (bonus.reputation or 0)
        end
    end
    
    -- Pardon: bonus se pochi stain e nessun peccato
    if folio.stain_count < 2 then
        reward.reputation = reward.reputation + 2
        log("[Run] Pardon! +2 reputation")
    end
    
    return reward
end

--- Stato per UI
function Run:getStatus()
    local cards = self.rule_setup and self.rule_setup.cards or {}
    return {
        fascicolo = self.fascicolo,
        folio = string.format("%d/%d", self.current_folio_index, self.total_folii),
        reputation = self.reputation,
        coins = self.coins,
        seed = self.seed,
        game_over = self.game_over,
        victory = self.victory,
        cards = {
            commission = cards.commission and cards.commission.name or nil,
            parchment = cards.parchment and cards.parchment.name or nil,
            tool = cards.tool and cards.tool.name or nil,
        },
    }
end

-- Wrapper modulo runtime (entrypoint UI/controller per una run)
local run_module = {}
local Run = Run
local current_run = nil
local run_title_font = nil
local run_body_font = nil
local run_title_size = 0
local run_body_size = 0
local run_ui = {}


function run_module.enter(params)
    if params and params.run then
        current_run = params.run
    else
        current_run = Run.new("BIFOLIO", os.time())
    end
end

function run_module.exit()
    current_run = nil
end

function run_module.update(dt)
    -- Placeholder: nessuna logica temporale
end

function run_module.draw()
    local high_contrast = RuntimeUI.high_contrast()
    local bg = high_contrast and {0.08, 0.08, 0.10} or {0.15, 0.12, 0.18}
    local title_size = RuntimeUI.sized(24)
    local body_size = RuntimeUI.sized(16)
    if not run_title_font or run_title_size ~= title_size then
        local ok, f = pcall(function() return love.graphics.newFont(title_size) end)
        run_title_font = (ok and f) or love.graphics.getFont()
        run_title_size = title_size
    end
    if not run_body_font or run_body_size ~= body_size then
        local ok, f = pcall(function() return love.graphics.newFont(body_size) end)
        run_body_font = (ok and f) or love.graphics.getFont()
        run_body_size = body_size
    end
    love.graphics.setBackgroundColor(bg[1], bg[2], bg[3])
    love.graphics.setColor(high_contrast and 1.0 or 0.95, high_contrast and 1.0 or 0.95, high_contrast and 1.0 or 0.95)
    love.graphics.setFont(run_title_font)
    love.graphics.print("GAME RUN - Placeholder", 60, 100)
    if current_run then
        local status = current_run:getStatus()
        love.graphics.setFont(run_body_font)
        love.graphics.print("Folio Set: " .. status.fascicolo, 60, 140)
        love.graphics.print("Folio: " .. status.folio, 60, 160)
        love.graphics.print("Reputation: " .. status.reputation, 60, 180)
        love.graphics.print("Coins: " .. status.coins, 60, 200)
        love.graphics.print("Seed: " .. status.seed, 60, 220)
        if status.game_over then
            love.graphics.print("GAME OVER!", 60, 260)
        elseif status.victory then
            love.graphics.print("VICTORY!", 60, 260)
        end
    end
    local btn_w = 220
    local btn_h = 42
    local btn_gap = 14
    local btn_x = 60
    local btn_y = 300
    local menu_rect = {x = btn_x, y = btn_y, w = btn_w, h = btn_h}
    local next_rect = {x = btn_x + btn_w + btn_gap, y = btn_y, w = btn_w, h = btn_h}
    run_ui.menu = menu_rect
    run_ui.next = next_rect

    love.graphics.setColor(0.22, 0.16, 0.24, 0.94)
    love.graphics.rectangle("fill", menu_rect.x, menu_rect.y, menu_rect.w, menu_rect.h, 6, 6)
    love.graphics.rectangle("fill", next_rect.x, next_rect.y, next_rect.w, next_rect.h, 6, 6)
    love.graphics.setColor(0.86, 0.76, 0.42, 0.9)
    love.graphics.rectangle("line", menu_rect.x, menu_rect.y, menu_rect.w, menu_rect.h, 6, 6)
    love.graphics.rectangle("line", next_rect.x, next_rect.y, next_rect.w, next_rect.h, 6, 6)

    love.graphics.setFont(run_body_font)
    love.graphics.setColor(0.96, 0.92, 0.84, 1)
    love.graphics.printf("Menu", menu_rect.x, menu_rect.y + 11, menu_rect.w, "center")
    love.graphics.printf("Next Folio (test)", next_rect.x, next_rect.y + 11, next_rect.w, "center")
    love.graphics.print("Mouse-only controls", 60, 356)
    love.graphics.setColor(1, 1, 1)
end


function run_module.keypressed(_key, _scancode, _isrepeat)
    -- Mouse-only module: keyboard input intentionally disabled.
end

function run_module.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    if run_ui.menu and x >= run_ui.menu.x and x <= run_ui.menu.x + run_ui.menu.w and y >= run_ui.menu.y and y <= run_ui.menu.y + run_ui.menu.h then
        if _G.set_module then
            _G.set_module("main_menu")
        elseif run_module.onExit then
            run_module.onExit()
        end
        return
    end

    if run_ui.next and x >= run_ui.next.x and x <= run_ui.next.x + run_ui.next.w and y >= run_ui.next.y and y <= run_ui.next.y + run_ui.next.h then
        -- Simula completamento folio per test
        if current_run then
            local completed, status = current_run:nextFolio()
            if completed and status == "next" and _G.set_module then
                -- Passa al modulo reward
                _G.set_module("reward", {run = current_run})
            end
        end
    end
end

return {
    Run = Run,
    module = run_module,
}
