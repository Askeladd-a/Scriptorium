-- src/core/scene_manager.lua
-- Gestisce le scene del gioco (menu, scriptorium, biblioteca, ecc.)

local SceneManager = {
    current = nil,      -- Scena attiva
    scenes = {},        -- Registry delle scene
    transition = nil,   -- Transizione in corso (future)
}

--- Registra una scena
---@param name string Nome univoco della scena
---@param scene table Oggetto scena con metodi: enter, exit, update, draw, keypressed, mousepressed
function SceneManager.register(name, scene)
    assert(scene, "Scene cannot be nil: " .. name)
    SceneManager.scenes[name] = scene
end

--- Cambia scena
---@param name string Nome della scena target
---@param ... any Parametri da passare a scene:enter()
function SceneManager.switch(name, ...)
    local next_scene = SceneManager.scenes[name]
    assert(next_scene, "Scene not found: " .. name)
    
    -- Exit dalla scena corrente
    if SceneManager.current and SceneManager.current.exit then
        SceneManager.current:exit()
    end
    
    -- Enter nella nuova scena
    SceneManager.current = next_scene
    if SceneManager.current.enter then
        SceneManager.current:enter(...)
    end
    
    print("[SceneManager] Switched to: " .. name)
end

--- Update della scena corrente
function SceneManager.update(dt)
    if SceneManager.current and SceneManager.current.update then
        SceneManager.current:update(dt)
    end
end

--- Draw della scena corrente
function SceneManager.draw()
    if SceneManager.current and SceneManager.current.draw then
        SceneManager.current:draw()
    end
end

--- Forward degli input
function SceneManager.keypressed(key, scancode, isrepeat)
    if SceneManager.current and SceneManager.current.keypressed then
        SceneManager.current:keypressed(key, scancode, isrepeat)
    end
end

function SceneManager.mousepressed(x, y, button)
    if SceneManager.current and SceneManager.current.mousepressed then
        SceneManager.current:mousepressed(x, y, button)
    end
end

function SceneManager.mousereleased(x, y, button)
    if SceneManager.current and SceneManager.current.mousereleased then
        SceneManager.current:mousereleased(x, y, button)
    end
end

function SceneManager.wheelmoved(x, y)
    if SceneManager.current and SceneManager.current.wheelmoved then
        SceneManager.current:wheelmoved(x, y)
    end
end



return SceneManager
