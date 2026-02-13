-- src/core/module_manager.lua
-- Gestisce i moduli runtime (menu, scriptorium, biblioteca, ecc.)

local ModuleManager = {
    current = nil,      -- Modulo attivo
    modules = {},       -- Registry moduli
    transition = nil,   -- Transizione in corso (future)
}

--- Registra un modulo
---@param name string Nome univoco del modulo
---@param module table Oggetto modulo con metodi: enter, exit, update, draw, keypressed, mousepressed
function ModuleManager.register(name, module)
    assert(module, "Module cannot be nil: " .. name)
    ModuleManager.modules[name] = module
end

--- Cambia modulo
---@param name string Nome del modulo target
---@param ... any Parametri da passare a module:enter()
function ModuleManager.switch(name, ...)
    local next_module = ModuleManager.modules[name]
    assert(next_module, "Module not found: " .. name)
    
    -- Exit dal modulo corrente
    if ModuleManager.current and ModuleManager.current.exit then
        ModuleManager.current:exit()
    end
    
    -- Enter nel nuovo modulo
    ModuleManager.current = next_module
    if ModuleManager.current.enter then
        ModuleManager.current:enter(...)
    end
    
    log("[ModuleManager] Switched to: " .. name)
end

--- Update del modulo corrente
function ModuleManager.update(dt)
    if ModuleManager.current and ModuleManager.current.update then
        ModuleManager.current:update(dt)
    end
end

--- Draw del modulo corrente
function ModuleManager.draw()
    if ModuleManager.current and ModuleManager.current.draw then
        ModuleManager.current:draw()
    end
end

--- Forward degli input
function ModuleManager.keypressed(key, scancode, isrepeat)
    if ModuleManager.current and ModuleManager.current.keypressed then
        ModuleManager.current:keypressed(key, scancode, isrepeat)
    end
end

function ModuleManager.mousepressed(x, y, button)
    if ModuleManager.current and ModuleManager.current.mousepressed then
        ModuleManager.current:mousepressed(x, y, button)
    end
end

function ModuleManager.mousereleased(x, y, button)
    if ModuleManager.current and ModuleManager.current.mousereleased then
        ModuleManager.current:mousereleased(x, y, button)
    end
end

function ModuleManager.wheelmoved(x, y)
    if ModuleManager.current and ModuleManager.current.wheelmoved then
        ModuleManager.current:wheelmoved(x, y)
    end
end



return ModuleManager
