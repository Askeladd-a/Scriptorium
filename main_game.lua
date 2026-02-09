-- main_game.lua
-- Entry point per il gioco Scriptorium Alchimico
-- Integra il sistema dadi 3D esistente con la logica di gioco

-- Carica moduli esistenti
require("core")
require("render")
require("physics")
require("geometry")
require("view")
require("light")

-- Carica moduli gioco
local SceneManager = require("src.core.scene_manager")
local Scriptorium = require("src.scenes.scriptorium")

-- Configurazione board (dal main.lua originale)
config = {
    boardlight = light.metal
}
function config.boardimage(x, y)
    return "resources/textures/felt.png"
end

-- Dadi 3D
dice = {}
local dice_size = 0.7

-- Mapping faccia dado -> valore pip (standard D6)
local faceToPip = {1, 6, 2, 3, 5, 4}

-- Stato dadi
local diceSettled = false
local diceSettledTimer = 0
local SETTLE_DELAY = 0.3  -- Secondi di stabilità prima di leggere

-- UI
local roll_button = {w = 160, h = 48, text = "Lancia Dadi", x = 0, y = 0}

-- ============================================================================
-- LÖVE CALLBACKS
-- ============================================================================

function love.load()
    -- Setup fisica (dal main.lua originale)
    box:set(5.5, 3.5, 10, 25, 0.25, 0.75, 0.01)
    box.linear_damping = 0.12
    box.angular_damping = 0.12
    box.border_height = 0.9
    
    -- Crea 4 dadi D6
    for i = 1, 4 do
        local col = ((i - 1) % 2) - 0.5
        local row = math.floor((i - 1) / 2) - 0.5
        local sx = col * 1.2
        local sy = row * 1.0
        
        dice[i] = {
            star = newD6star(dice_size):set({sx, sy, 8}, {(i % 2 == 0) and 3 or -3, (i % 2 == 0) and -2 or 2, 0}, {1, 1, 2}),
            die = clone(d6, {
                material = light.plastic,
                color = {200, 0, 20, 150},     -- Rosso originale
                text = {255, 255, 255},
                shadow = {20, 0, 0, 150}
            })
        }
        
        -- Applica preset BONE per fisica realistica
        materials.apply(dice[i].star, materials.get("bone"))
        
        box[i] = dice[i].star
    end
    
    -- Seed RNG
    local seed = os.time()
    math.randomseed(seed)
    if love.math then
        love.math.setRandomSeed(seed)
    end
    
    -- Registra scene
    SceneManager.register("scriptorium", Scriptorium)
    
    -- Setup callback roll
    Scriptorium.onRollRequest = function()
        rollAllDice()
    end
    
    -- Avvia scena
    SceneManager.switch("scriptorium", "BIFOLIO", seed)
    
    -- Roll iniziale
    rollAllDice()
end

function love.update(dt)
    -- Update physics
    box:update(dt)
    
    -- Check se i dadi si sono fermati
    checkDiceSettled(dt)
    
    -- Update scena
    SceneManager.update(dt)
    
    -- Camera/view (dal main.lua originale)
    local dx, dy = love.mouse.delta()
    if love.mouse.isDown(2) then
        view.raise(dy / 100)
        view.turn(dx / 100)
    end
end

function love.draw()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    
    -- Calcola posizione bottone
    roll_button.x = w / 2 - roll_button.w / 2
    roll_button.y = h - roll_button.h - 20
    
    -- ========================
    -- AREA DADI 3D (metà sinistra)
    -- ========================
    love.graphics.push()
    
    local dice_area_w = w * 0.5
    local cx = dice_area_w / 2
    local cy = h / 2
    local scale = math.min(cx, cy) / 4
    
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale)
    
    -- Board
    local bx = math.max(0.001, box.x)
    local by = math.max(0.001, box.y)
    render.board(config.boardimage, config.boardlight, -bx, bx, -by, by)
    
    -- Shadows
    for i = 1, #dice do
        render.shadow(function(z, f) f() end, dice[i].die, dice[i].star)
    end
    -- render.edgeboard() -- removed: covers outside tray with black (caused unwanted black background)
    
    -- Z-buffer pass
    render.clear()
    render.tray_border(render.zbuffer, 0.8, 0.9)
    render.bulb(render.zbuffer)
    for i = 1, #dice do
        render.die(render.zbuffer, dice[i].die, dice[i].star)
    end
    render.paint()
    
    love.graphics.pop()
    
    -- ========================
    -- AREA GIOCO (metà destra)
    -- ========================
    love.graphics.push()
    love.graphics.translate(dice_area_w, 0)
    
    -- Clip area gioco
    love.graphics.setScissor(dice_area_w, 0, w - dice_area_w, h)
    
    -- Disegna scena (spostata a sinistra per adattarsi)
    local scene = SceneManager.current
    if scene and scene.draw then
        -- Override temporanea dimensioni per la scena
        local old_getWidth = love.graphics.getWidth
        love.graphics.getWidth = function() return w - dice_area_w end
        scene:draw()
        love.graphics.getWidth = old_getWidth
    end
    
    love.graphics.setScissor()
    love.graphics.pop()
    
    -- ========================
    -- UI GLOBALE
    -- ========================
    
    -- Bottone roll (centrato sotto l'area dadi)
    roll_button.x = dice_area_w / 2 - roll_button.w / 2
    roll_button.y = h - roll_button.h - 20
    
    love.graphics.setColor(0.2, 0.2, 0.25, 0.95)
    love.graphics.rectangle("fill", roll_button.x, roll_button.y, roll_button.w, roll_button.h, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", roll_button.x, roll_button.y, roll_button.w, roll_button.h, 6, 6)
    
    local font = love.graphics.getFont()
    local fh = font and font:getHeight() or 14
    love.graphics.printf(roll_button.text, roll_button.x, roll_button.y + (roll_button.h - fh) / 2, roll_button.w, "center")
    
    -- FPS
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 8, 8)
    
    -- Separatore verticale
    love.graphics.setColor(0.3, 0.25, 0.2)
    love.graphics.setLineWidth(2)
    love.graphics.line(dice_area_w, 0, dice_area_w, h)
    love.graphics.setLineWidth(1)
end

function love.keypressed(key, scancode, isrepeat)
    if key == 'space' then
        rollAllDice()
    end
    SceneManager.keypressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button)
    if button == 1 then
        -- Check roll button
        if x >= roll_button.x and x <= roll_button.x + roll_button.w and
           y >= roll_button.y and y <= roll_button.y + roll_button.h then
            rollAllDice()
            return
        end
    end
    SceneManager.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    SceneManager.mousereleased(x, y, button)
end

function love.wheelmoved(dx, dy)
    if dy > 0 then view.move(1.1) end
    if dy < 0 then view.move(0.91) end
    SceneManager.wheelmoved(dx, dy)
end

-- ============================================================================
-- DICE FUNCTIONS
-- ============================================================================

--- Lancia tutti i dadi
function rollAllDice()
    local rnd = (love and love.math and love.math.random) or math.random
    
    diceSettled = false
    diceSettledTimer = 0
    
    -- Notifica scena
    if Scriptorium then
        Scriptorium.state = "rolling"
        Scriptorium.dice_results = {}
    end
    
    -- Spawn point (dal main.lua originale)
    local half = math.min(box.x, box.y) * 0.85
    local side = math.floor(rnd() * 4) + 1
    local sx, sy
    local inset = half * (0.15 + rnd() * 0.10)
    local span = half - inset
    
    if side == 1 then sx = -half + inset; sy = (rnd() * 2 - 1) * span
    elseif side == 2 then sx = half - inset; sy = (rnd() * 2 - 1) * span
    elseif side == 3 then sy = -half + inset; sx = (rnd() * 2 - 1) * span
    else sy = half - inset; sx = (rnd() * 2 - 1) * span end
    
    local rz = box.z * 0.5 + 1.0 + rnd() * 1.5
    
    -- Direzione verso centro
    local to_center = vector{-sx, -sy, 0}
    local len = math.sqrt(to_center[1]^2 + to_center[2]^2)
    if len < 1e-4 then
        local angle = rnd() * 2 * math.pi
        to_center = vector{math.cos(angle), math.sin(angle), 0}
    else
        to_center[1] = to_center[1] / len
        to_center[2] = to_center[2] / len
    end
    
    local vertical_speed = -(20 + rnd() * 10)
    local lateral_speed = math.abs(vertical_speed) * (0.8 + rnd() * 0.3)
    
    local base_velocity = vector{
        to_center[1] * lateral_speed,
        to_center[2] * lateral_speed,
        vertical_speed
    }
    
    for i = 1, #dice do
        local jitter = 0.05 * (i - (#dice + 1) / 2)
        dice[i].star.position = vector{sx + jitter, sy - jitter, rz}
        dice[i].star.asleep = false
        dice[i].star.sleep_timer = 0
        dice[i].star.wall_hits = 0
        dice[i].star.angular = vector{(rnd() - 0.5) * 12, (rnd() - 0.5) * 12, (rnd() - 0.5) * 12}
        
        local noise = 1.2
        dice[i].star.velocity = vector{
            base_velocity[1] + (rnd() - 0.5) * noise,
            base_velocity[2] + (rnd() - 0.5) * noise,
            base_velocity[3] + (rnd() - 0.5) * noise * 0.5
        }
    end
end

--- Controlla se i dadi si sono fermati
function checkDiceSettled(dt)
    if diceSettled then return end
    
    local all_stable = true
    for i = 1, #dice do
        local s = dice[i].star
        if not s.asleep then
            all_stable = false
            break
        end
    end
    
    if all_stable then
        diceSettledTimer = diceSettledTimer + dt
        if diceSettledTimer >= SETTLE_DELAY then
            diceSettled = true
            onDiceSettled()
        end
    else
        diceSettledTimer = 0
    end
end

--- Callback quando i dadi si fermano
function onDiceSettled()
    local values = readDiceValues()
    log("[Dice] Settled: " .. table.concat(values, ", "))
    
    -- Notifica scena
    if Scriptorium.onDiceSettled then
        Scriptorium:onDiceSettled(values)
    end
end

--- Legge i valori delle facce superiori dei dadi
function readDiceValues()
    local values = {}
    
    for i = 1, #dice do
        local value = readDieFace(dice[i].star)
        table.insert(values, value)
    end
    
    return values
end

-- Mapping faccia geometrica -> valore pip per dado standard (right-handed)
-- Le facce opposte sommano a 7: 1↔6, 2↔5, 3↔4
-- Face geometry: 1=z+, 2=z-, 3=x+, 4=y-, 5=x-, 6=y+
-- Standard die: top=1, bottom=6, front=2, back=5, right=3, left=4
local FACE_TO_PIP = {
    [1] = 1,  -- z+ (top) = 1 pip
    [2] = 6,  -- z- (bottom) = 6 pip (opposite of 1)
    [3] = 3,  -- x+ (right) = 3 pip
    [4] = 5,  -- y- (back) = 5 pip
    [5] = 4,  -- x- (left) = 4 pip (opposite of 3)
    [6] = 2,  -- y+ (front) = 2 pip (opposite of 5)
}

--- Legge la faccia superiore di un dado
function readDieFace(star)
    -- Le facce del D6 (da geometry.lua)
    -- faces={{1,2,3,4}, {5,6,7,8}, {1,2,6,5},{2,3,7,6},{3,4,8,7},{4,1,5,8}}
    -- Le texture 1.png-6.png corrispondono agli indici delle facce
    local faces = d6.faces
    
    local best_face = 1
    local best_z = -math.huge
    
    -- Per ogni faccia, calcola il centro e trova quella con Z più alto
    for face_idx, face in ipairs(faces) do
        local center_z = 0
        
        -- Calcola Z medio dei vertici della faccia (già ruotati)
        for _, vert_idx in ipairs(face) do
            local vertex = star[vert_idx]
            center_z = center_z + vertex[3]
        end
        center_z = center_z / #face
        
        if center_z > best_z then
            best_z = center_z
            best_face = face_idx
        end
    end
    
    -- Converti indice faccia geometrica a valore pip (dado standard)
    return FACE_TO_PIP[best_face] or best_face
end
