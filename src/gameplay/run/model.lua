
local FolioModule = require("src.gameplay.folio.model")
local Folio = FolioModule.Folio or FolioModule
local RuntimeUI = require("src.core.runtime_ui")

local Run = {}
Run.__index = Run

local function build_default_run_setup()
    return {
        cards = {},
        effects = {},
    }
end

Run.FOLIO_SET_SIZES = {
    BIFOLIO = 1,
    DUERNO = 1,
    TERNIONE = 1,
    QUATERNIONE = 1,
    QUINTERNO = 1,
    SESTERNO = 1,
}

---@param folio_set_type string Folio set type
---@param seed number Seed for reproducible RNG (optional)
function Run.new(folio_set_type, seed)
    local self = setmetatable({}, Run)
    
    self.folio_set = folio_set_type or "BIFOLIO"
    self.total_folios = 1
    
    self.seed = seed or os.time()
    math.randomseed(self.seed)
    if love and love.math then
        love.math.setRandomSeed(self.seed)
    end
    log("[Run] Seed: " .. self.seed)
    self.rule_setup = build_default_run_setup()
    
    self.current_folio_index = 1
    self.current_folio = Folio.new(self.folio_set, self.seed + 1, self.rule_setup)
    self.completed_folios = {}
    
    self.reputation = 20
    self.coins = 0
    
    self.inventory = {
        pigments = {},
        binders = {},
    }
    
    self.game_over = false
    self.victory = false
    
    return self
end

function Run:nextFolio()
    if self.current_folio.completed then
        local reward = self:calculateFolioReward()
        self.coins = self.coins + reward.coins
        self.reputation = self.reputation + reward.reputation
        
        log(string.format("[Run] Folio %d completed! +%d coins, +%d rep", 
            self.current_folio_index, reward.coins, reward.reputation))
        
        table.insert(self.completed_folios, self.current_folio)
        self.victory = true
        log("[Run] VICTORY! Folio completed!")
        return true, "victory"
        
    elseif self.current_folio.busted then
        local rep_loss = 3
        self.reputation = self.reputation - rep_loss
        log(string.format("[Run] Folio BUST! -%d reputation (now: %d)", rep_loss, self.reputation))
        
        self.game_over = true
        log("[Run] GAME OVER! Folio busted!")
        return false, "game_over"
    end
    
    return false, "in_progress"
end

function Run:calculateFolioReward()
    local reward = {coins = 30, reputation = 0}
    local folio = self.current_folio
    if folio and folio.elements and folio.elements.TEXT and folio.elements.TEXT.completed then
        local bonus = Folio.BONUS.TEXT or {}
        reward.coins = reward.coins + (bonus.coins or 0)
        reward.reputation = reward.reputation + (bonus.reputation or 0)
    end
    if folio and folio.stain_count <= 1 then
        reward.reputation = reward.reputation + 1
    end
    return reward
end

function Run:getStatus()
    return {
        folio_set = self.folio_set,
        folio = string.format("%d/%d", self.current_folio_index, self.total_folios),
        reputation = self.reputation,
        coins = self.coins,
        seed = self.seed,
        game_over = self.game_over,
        victory = self.victory,
    }
end

local run_module = {}
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
        love.graphics.print("Folio Set: " .. status.folio_set, 60, 140)
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
        if current_run then
            local completed, status = current_run:nextFolio()
            if completed and status == "next" and _G.set_module then
                _G.set_module("reward", {run = current_run})
            end
        end
    end
end

return {
    Run = Run,
    module = run_module,
}
