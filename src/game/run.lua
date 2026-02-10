-- src/game/run.lua
-- Gestisce una run completa (fascicolo di N folii)

local Folio = require("src.game.folio")

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
    
    -- Stato run
    self.current_folio_index = 1
    self.current_folio = Folio.new(self.fascicolo, self.seed + 1)
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
        
        log(string.format("[Run] Folio %d completato! +%d coins, +%d rep", 
            self.current_folio_index, reward.coins, reward.reputation))
        
        table.insert(self.completed_folii, self.current_folio)
        self.current_folio_index = self.current_folio_index + 1
        
        -- Check vittoria
        if self.current_folio_index > self.total_folii then
            self.victory = true
            log("[Run] VITTORIA! Fascicolo completato!")
            return true, "victory"
        end
        
        -- Nuovo folio
        self.current_folio = Folio.new(self.fascicolo, self.seed + self.current_folio_index)
        return true, "next"
        
    elseif self.current_folio.busted then
        -- Folio perso
        local rep_loss = 3
        self.reputation = self.reputation - rep_loss
        log(string.format("[Run] Folio BUST! -%d reputation (now: %d)", rep_loss, self.reputation))
        
        -- Check game over
        if self.reputation <= 0 then
            self.game_over = true
            log("[Run] GAME OVER! Reputazione esaurita!")
            return false, "game_over"
        end
        
        -- Nuovo folio (stessa posizione, si riprova)
        self.current_folio = Folio.new(self.fascicolo, self.seed + self.current_folio_index + 1000)
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
    return {
        fascicolo = self.fascicolo,
        folio = string.format("%d/%d", self.current_folio_index, self.total_folii),
        reputation = self.reputation,
        coins = self.coins,
        seed = self.seed,
        game_over = self.game_over,
        victory = self.victory,
    }
end

-- Wrapper scena per SceneManager
local run_scene = {}
local Run = Run
local current_run = nil


function run_scene.enter(params)
    if params and params.run then
        current_run = params.run
    else
        current_run = Run.new("BIFOLIO", os.time())
    end
end

function run_scene.exit()
    current_run = nil
end

function run_scene.update(dt)
    -- Placeholder: nessuna logica temporale
end

function run_scene.draw()
    love.graphics.setBackgroundColor(0.15, 0.12, 0.18)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.print("GAME RUN - Placeholder", 60, 100)
    if current_run then
        local status = current_run:getStatus()
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.print("Fascicolo: " .. status.fascicolo, 60, 140)
        love.graphics.print("Folio: " .. status.folio, 60, 160)
        love.graphics.print("Reputation: " .. status.reputation, 60, 180)
        love.graphics.print("Coins: " .. status.coins, 60, 200)
        love.graphics.print("Seed: " .. status.seed, 60, 220)
        if status.game_over then
            love.graphics.print("GAME OVER!", 60, 260)
        elseif status.victory then
            love.graphics.print("VITTORIA!", 60, 260)
        end
    end
    love.graphics.print("Premi ESC per tornare al menu", 60, 300)
    love.graphics.setColor(1, 1, 1)
end


function run_scene.keypressed(key, scancode, isrepeat)
    if key == "escape" then
        if _G.set_module then
            _G.set_module("main_menu")
        elseif run_scene.onExit then
            run_scene.onExit()
        end
    elseif key == "n" then
        -- Simula completamento folio per test
        if current_run then
            local completed, status = current_run:nextFolio()
            if completed and status == "next" then
                -- Passa al modulo reward
                if _G.set_module then
                    _G.set_module("reward", {run = current_run})
                end
            end
        end
    end
end

        return {
            Run = Run,
            scene = run_scene
        }
