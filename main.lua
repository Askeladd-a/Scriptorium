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

-- Carica moduli gioco (consolidati)
local SceneManager = require("src.core.scene_manager")
local Scriptorium = require("src.game.scriptorium")
local Content = require("src.content")
local DiceFaces = Content.DiceFaces

-- Scene references (popolate in love.load)
local splash_scene = nil
local main_menu_scene = nil
local run_scene = nil

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

-- Wet Buffer e penalità (MVP)
local WetBuffer = {}  -- { {element, row, col, die, pigment} }
local sbavature = 0
local macchie = 0
local lastBust = false

-- Posizioni "kept" (fuori dal tray, sopra)
local KEPT_POSITIONS = {
    {x = -2.5, y = -5.5, z = 1},
    {x = -0.8, y = -5.5, z = 1},
    {x =  0.8, y = -5.5, z = 1},
    {x =  2.5, y = -5.5, z = 1},
}

-- UI
local roll_button = {w = 140, h = 40, text = "Rilancia", x = 0, y = 0}

-- Stato overlay feedback
local overlayMessage = nil
local overlayTimer = 0
local OVERLAY_DURATION = 1.2

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
        
        -- Colori per faccia basati su DiceFaces (pigmenti fallback)
        -- Usa d6.pipMap per convertire indice geometrico → valore pip
        local faceColors = {}
        for geoFace = 1, 6 do
            local pip = d6.pipMap[geoFace]  -- faccia geometrica → valore pip
            local faceData = DiceFaces.DiceFaces[pip]
            local rgb = DiceFaces.getDieColor(faceData.fallback)
            faceColors[geoFace] = {rgb[1], rgb[2], rgb[3], 255}
        end
        
        dice[i] = {
            star = newD6star(dice_size):set({sx, sy, 8}, {(i % 2 == 0) and 3 or -3, (i % 2 == 0) and -2 or 2, 0}, {1, 1, 2}),
            die = clone(d6, {
                material = light.plastic,
                faceColors = faceColors,       -- Colori per faccia
                color = {200, 180, 160, 255},  -- Fallback neutro
                text = {255, 255, 255},
                shadow = {20, 0, 0, 150}
            }),
            kept = false,  -- Se il dado è stato tenuto (Farkle)
            value = nil,   -- Valore corrente dopo roll
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
    -- Register UI scenes after LÖVE subsystems ready (safe)
    splash_scene = require("src.scenes.splash")
    SceneManager.register("Splash", splash_scene)
    main_menu_scene = require("src.scenes.main_menu")
    SceneManager.register("MainMenu", main_menu_scene)
    local run_mod = require("src.game.run")
    local Run = run_mod.Run
    run_scene = run_mod.scene
    run_scene.onExit = function()
        SceneManager.switch("MainMenu")
    end
    SceneManager.register("run", run_scene)
    
    -- Setup callback roll
    Scriptorium.onRollRequest = function()
        rollAllDice()
    end
    
    -- Avvio scena: mostra prima la splash e poi il menu
    print("[love.load] switching to Splash")
    -- Avvio dalla splash
    SceneManager.switch("Splash")
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
    
    -- Stato overlay feedback
    if overlayTimer and overlayTimer > 0 then
        overlayTimer = overlayTimer - dt
        if overlayTimer <= 0 then
            overlayTimer = 0
            overlayMessage = nil
        end
    end
end

function love.draw()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    -- If we're showing Splash or MainMenu, let SceneManager draw and skip the game draw
    if SceneManager.current and (SceneManager.current == splash_scene or SceneManager.current == main_menu_scene) then
        SceneManager.draw()
        return
    end
    
    -- ========================
    -- LAYOUT: 3/4 pergamena, 1/4 tray + bottoni
    -- ========================
    
    local UI = require("src.ui")
    local folio = Scriptorium.run and Scriptorium.run.current_folio or nil
    
    -- Calcolo layout
    local btn_area_h = 50   -- Altezza area bottoni
    local tray_h = (h - btn_area_h) * 0.25  -- 1/4 dello spazio rimanente
    local parch_h = (h - btn_area_h) * 0.75  -- 3/4 dello spazio rimanente
    local tray_y = parch_h
    local btn_y = h - btn_area_h
    
    -- ========================
    -- TRAY 3D PRIMA (con scissor per non sovrascrivere)
    -- ========================
    love.graphics.setScissor(0, tray_y, w, tray_h)
    -- Sfondo marrone tray (riempie anche "dietro" il 3D)
    love.graphics.setColor(0.36, 0.25, 0.20)
    love.graphics.rectangle("fill", 0, tray_y, w, tray_h)

    -- Tray 3D ruotato verso il player, "in piano", abbassato
    local tray_cx = w / 2
        local tray_cy = tray_y + tray_h * 0.62  -- centrato meglio nella fascia
    local scale = math.min(w, tray_h) / 7.5

    -- Camera: quasi dall’alto, lato lungo verso il player
    local old_dist = view.distance
    local old_pitch = view.pitch
    local old_yaw = view.yaw
    view.distance = 8
        view.pitch = 0.85  -- inclinata verso il centro del tray
    view.yaw = 0  -- lato lungo orizzontale verso il player

    love.graphics.push()
    love.graphics.translate(tray_cx, tray_cy)
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
    love.graphics.setScissor()  -- Reset scissor
    view.distance = old_dist  -- restore
    view.pitch = old_pitch
    view.yaw = old_yaw
    
    -- ========================
    -- SFONDO MARRONCINO (resto dello schermo)
    -- ========================
    -- Area sopra tray (pergamena)
    love.graphics.setColor(0.36, 0.25, 0.20)
    love.graphics.rectangle("fill", 0, 0, w, tray_y)
    -- Area sotto tray (bottoni)
    love.graphics.rectangle("fill", 0, tray_y + tray_h, w, btn_area_h)
    
    -- ========================
    -- PERGAMENA (3/4 superiore)
    -- ========================
    local parch_margin = 20
    local parch_w = math.min(400, w - parch_margin * 2)
    local parch_x = w / 2 - parch_w / 2
    local parch_y_pos = parch_margin / 2
    local parch_inner_h = parch_h - parch_margin
    
    -- Background pergamena
    love.graphics.setColor(0.95, 0.90, 0.78)
    love.graphics.rectangle("fill", parch_x, parch_y_pos, parch_w, parch_inner_h, 6, 6)
    love.graphics.setColor(0.65, 0.55, 0.40)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", parch_x, parch_y_pos, parch_w, parch_inner_h, 6, 6)
    love.graphics.setLineWidth(1)
    
    -- Contenuto pergamena
    if folio then
        drawParchmentContent(parch_x, parch_y_pos, parch_w, parch_inner_h, folio)
    end
    
    -- ========================
    -- BOTTONI E ISTRUZIONI (sotto tray)
    -- ========================
    roll_button.x = w / 2 - roll_button.w / 2
    roll_button.y = btn_y + 5
    
    -- Conta dadi non kept
    local unkept_count = 0
    for i = 1, #dice do
        if not dice[i].kept then unkept_count = unkept_count + 1 end
    end
    
    -- Testo bottone dinamico
    if unkept_count == 0 then
        roll_button.text = "Nessun dado"
    elseif unkept_count == #dice then
        roll_button.text = "Lancia tutti"
    else
        roll_button.text = "Rilancia " .. unkept_count
    end
    
    love.graphics.setColor(0.22, 0.17, 0.12, 0.95)
    love.graphics.rectangle("fill", roll_button.x, roll_button.y, roll_button.w, roll_button.h, 5, 5)
    love.graphics.setColor(0.75, 0.65, 0.50)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", roll_button.x, roll_button.y, roll_button.w, roll_button.h, 5, 5)
    love.graphics.setLineWidth(1)
    
    love.graphics.setColor(0.95, 0.90, 0.80)
    local font = love.graphics.getFont()
    local fh = font and font:getHeight() or 14
    love.graphics.printf(roll_button.text, roll_button.x, roll_button.y + (roll_button.h - fh) / 2, roll_button.w, "center")
    
    -- Istruzioni (accanto al bottone)
    love.graphics.setColor(0.75, 0.70, 0.60)
    love.graphics.printf("[Click dado = tieni/rilascia]  [SPACE = rilancia]", 0, btn_y + 15, w, "center")
    
    -- FPS (corner)
    love.graphics.setColor(0.5, 0.45, 0.40)
    love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 8, h - 20)

    -- Wet Buffer overlay (placeholder: bordo blu)
    if #WetBuffer > 0 then
        love.graphics.setColor(0.2, 0.4, 0.9, 0.18)
        love.graphics.rectangle("fill", parch_x, parch_y_pos, parch_w, parch_inner_h, 6, 6)
        love.graphics.setColor(0.2, 0.4, 0.9, 0.5)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", parch_x, parch_y_pos, parch_w, parch_inner_h, 6, 6)
        love.graphics.setLineWidth(1)
    end

    -- Bust overlay (placeholder: bordo rosso)
    if lastBust then
        love.graphics.setColor(0.9, 0.1, 0.1, 0.18)
        love.graphics.rectangle("fill", parch_x, parch_y_pos, parch_w, parch_inner_h, 6, 6)
        love.graphics.setColor(0.9, 0.1, 0.1, 0.5)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", parch_x, parch_y_pos, parch_w, parch_inner_h, 6, 6)
        love.graphics.setLineWidth(1)
    end

    -- Dadi KEPT indicator (sopra tray, piccolo)
    drawKeptDiceIndicator(w, tray_y)
    -- Sbavature/macchie (debug)
    love.graphics.setColor(0.5, 0.45, 0.40)
    love.graphics.print(string.format("Sbavature: %d   Macchie: %d", sbavature, macchie), w-180, h-20)
-- Piazzamento temporaneo (Wet Buffer)
function addToWetBuffer(element, row, col, die, pigment)
    table.insert(WetBuffer, {element=element, row=row, col=col, die=die, pigment=pigment})
end

-- Commit Wet Buffer (piazzamenti diventano permanenti)
function commitWetBuffer(folio)
    for _, p in ipairs(WetBuffer) do
        folio:placeDie(p.element, p.row, p.col, p.die.value, p.die.color, p.pigment)
    end
    WetBuffer = {}
    lastBust = false
    overlayMessage = {msg = "COMPLETATO!", sub = nil}
    overlayTimer = OVERLAY_DURATION
end

-- Bust: perdi tutto il Wet Buffer, aggiungi sbavatura
function bustWetBuffer()
    WetBuffer = {}
    sbavature = (sbavature or 0) + 1
    if sbavature >= 3 then
        sbavature = 0
        macchie = (macchie or 0) + 1
    end
    lastBust = true
    overlayMessage = {msg = "BUST!", sub = "Hai perso tutto il Wet Buffer"}
    overlayTimer = OVERLAY_DURATION
end

-- Utility: controlla se almeno un dado è piazzabile (vincoli Sagrada)
function hasPlacableDice(dice, folio)
    for i, die in ipairs(dice) do
        for _, elem in ipairs(folio.ELEMENTS) do
            local valid = folio:getValidPlacements(elem, die.value, die.color)
            if #valid > 0 then return true end
        end
    end
    return false
end

-- Esempio loop di turno (MVP, da integrare con input/UI reali)
function turnLoop(folio, dice)
    -- 1. Roll
    -- (già fatto fuori da questa funzione)
    while true do
        -- 2. Calcola piazzamenti validi
        if not hasPlacableDice(dice, folio) then
            bustWetBuffer()
            break
        end
        -- 3. (Qui: input player per scegliere piazzamenti e pigmenti)
        -- Per MVP: simuliamo che il player piazza sempre il primo dado valido
        local placed = false
        for i, die in ipairs(dice) do
            for _, elem in ipairs(folio.ELEMENTS) do
                local valid = folio:getValidPlacements(elem, die.value, die.color)
                if #valid > 0 then
                    local cell = valid[1]
                    addToWetBuffer(elem, cell.row, cell.col, die, "DEFAULT")
                    table.remove(dice, i)
                    placed = true
                    break
                end
            end
            if placed then break end
        end
        if not placed then break end
        -- 4. (Qui: input player PUSH/STOP)
        -- Per MVP: simuliamo che il player fa STOP se restano <=2 dadi
        if #dice <= 2 then
            commitWetBuffer(folio)
            break
        else
            -- PUSH: rolla i dadi rimasti
            -- (qui dovresti chiamare la tua funzione di roll)
            -- Per MVP: esci dal loop
            break
        end
    end
end
end

--- Disegna contenuto pergamena (pattern di tutti gli elementi)
function drawParchmentContent(x, y, w, h, folio)
    local UI = require("src.ui")
    
    -- Titolo
    love.graphics.setColor(0.2, 0.15, 0.1)
    love.graphics.setFont(love.graphics.newFont(22))
    love.graphics.printf("Folio " .. (Scriptorium.run and Scriptorium.run.current_folio_index or 1), x, y + 8, w, "center")
    love.graphics.setFont(love.graphics.newFont(14))
    -- Layout
    local cell_size = 32
    local spacing = 6
    local margin = 24
    local curr_y = y + 44
    for idx, elem_name in ipairs(folio.ELEMENTS) do
        local elem = folio.elements[elem_name]
        local pattern = elem.pattern
        local grid_w = pattern.cols * (cell_size + spacing) - spacing
        local grid_h = pattern.rows * (cell_size + spacing) - spacing
        local grid_x = x + w/2 - grid_w/2
        -- Box sezione
        love.graphics.setColor(0.97, 0.93, 0.82, 0.92)
        love.graphics.rectangle("fill", x + 8, curr_y - 10, w - 16, grid_h + 54, 8, 8)
        -- Titolo elemento centrato oro
        love.graphics.setColor(0.9, 0.75, 0.3)
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.printf(elem_name:upper(), x, curr_y, w, "center")
        love.graphics.setFont(love.graphics.newFont(14))
        -- Label a sinistra
        love.graphics.setColor(elem.unlocked and {0.2, 0.15, 0.1} or {0.5, 0.45, 0.4})
        local lock = elem.unlocked and "" or "🔒 "
        local done = elem.completed and " ✓" or ""
        love.graphics.print(lock .. elem_name .. done, x + margin, curr_y + 22)
        -- Griglia
        UI.drawPatternGrid(folio, elem_name, grid_x, curr_y + 18, cell_size, nil)
        -- Progress bar sotto la griglia
        love.graphics.setColor(0.7, 0.65, 0.5)
        love.graphics.rectangle("fill", grid_x, curr_y + 24 + grid_h, grid_w, 8, 3, 3)
        love.graphics.setColor(0.2, 0.7, 0.3)
        local fill = (elem.cells_filled/elem.cells_total) * grid_w
        love.graphics.rectangle("fill", grid_x, curr_y + 24 + grid_h, fill, 8, 3, 3)
        love.graphics.setColor(0.2, 0.15, 0.1)
        love.graphics.printf(string.format("%d/%d", elem.cells_filled, elem.cells_total), grid_x, curr_y + 24 + grid_h - 2, grid_w, "center")
        -- Separatore tra sezioni
        curr_y = curr_y + grid_h + 54 + 18
        if idx < #folio.ELEMENTS then
            love.graphics.setColor(0.8, 0.75, 0.6, 0.5)
            love.graphics.rectangle("fill", x + 16, curr_y - 9, w - 32, 3, 2, 2)
        end
    end
end

--- Disegna indicatore dadi kept (sopra il tray, compatto)
function drawKeptDiceIndicator(screen_w, tray_y)
    local kept_count = 0
    for i = 1, #dice do
        if dice[i].kept then kept_count = kept_count + 1 end
    end
    
    if kept_count == 0 then return end
    
    -- Label
    love.graphics.setColor(0.7, 0.65, 0.55)
    love.graphics.printf("Dadi tenuti:", 0, tray_y - 85, screen_w, "center")
    
    -- Dadi kept come quadrati 2D
    local die_size = 45
    local spacing = 10
    local total_w = kept_count * (die_size + spacing) - spacing
    local start_x = screen_w / 2 - total_w / 2
    local y = tray_y - 70
    
    local idx = 0
    for i = 1, #dice do
        if dice[i].kept then
            local dx = start_x + idx * (die_size + spacing)
            local value = dice[i].value or readDieFace(dice[i].star)
            
            -- Background dado
            love.graphics.setColor(0.9, 0.85, 0.75)
            love.graphics.rectangle("fill", dx, y, die_size, die_size, 4, 4)
            
            -- Bordo oro (kept)
            love.graphics.setColor(0.9, 0.75, 0.3)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", dx, y, die_size, die_size, 4, 4)
            love.graphics.setLineWidth(1)
            
            -- Valore
            love.graphics.setColor(0.15, 0.12, 0.1)
            love.graphics.printf(tostring(value), dx, y + die_size/2 - 10, die_size, "center")
            
            idx = idx + 1
        end
    end
end

function love.keypressed(key, scancode, isrepeat)
    -- Disabilitato: gameplay solo via UI/click
    -- if key == 'space' then
    --     rollAllDice()
    -- elseif key == 'r' then
    --     releaseAllDice()
    --     rollAllDice()
    -- end
    SceneManager.keypressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button)
    if button == 1 then
        -- BOTTONI PUSH/STOP
        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()
        local btn_area_h = 50
        local btn_y = h - btn_area_h
        local btn_cx = w / 2
        local btn_spacing = 24
        local UI = require("src.ui")
        local folio = Scriptorium.run and Scriptorium.run.current_folio or nil
        -- Push
        local push_btn = UI.PUSHSTOP_BUTTONS.push
        if x >= push_btn.x and x <= push_btn.x + push_btn.w and y >= push_btn.y and y <= push_btn.y + push_btn.h then
            -- Azione PUSH: committa Wet Buffer
            if #WetBuffer > 0 then
                commitWetBuffer(folio)
            end
            return
        end
        -- Stop
        local stop_btn = UI.PUSHSTOP_BUTTONS.stop
        if x >= stop_btn.x and x <= stop_btn.x + stop_btn.w and y >= stop_btn.y and y <= stop_btn.y + stop_btn.h then
            -- Azione STOP: termina turno, committa Wet Buffer e passa
            if #WetBuffer > 0 then
                commitWetBuffer(folio)
            end
            -- TODO: transizione stato/fine turno
            return
        end
        -- CLICK SU CELLA PATTERN (pergamena)
        if folio then
            -- Calcola layout pergamena
            local parch_margin = 20
            local parch_w = math.min(400, w - parch_margin * 2)
            local parch_x = w / 2 - parch_w / 2
            local parch_y_pos = parch_margin / 2
            local parch_inner_h = (h - btn_area_h) * 0.75 - parch_margin
            -- Cerca cella cliccata
            local cell_size = 26
            local spacing = 3
            local curr_y = parch_y_pos + 32
            for _, elem_name in ipairs(folio.ELEMENTS) do
                local elem = folio.elements[elem_name]
                local pattern = elem.pattern
                local grid_w = pattern.cols * (cell_size + spacing) - spacing
                local grid_x = parch_x + (parch_w - grid_w) / 2
                local grid_y = curr_y + 6
                for row = 1, pattern.rows do
                    for col = 1, pattern.cols do
                        local cx = grid_x + (col - 1) * (cell_size + spacing)
                        local cy = grid_y + (row - 1) * (cell_size + spacing)
                        if x >= cx and x <= cx + cell_size and y >= cy and y <= cy + cell_size then
                            -- Prova a piazzare il dado attivo (TODO: selezione dado attivo)
                            -- Esempio: prendi primo dado non kept
                            local die = nil
                            for i = 1, #dice do
                                if not dice[i].kept then die = dice[i] break end
                            end
                            if die then
                                -- Scegli pigmento (MVP: primo pigmento valido)
                                local pigment = die.color
                                -- Verifica se la cella è valida
                                local valid = folio:getValidPlacements(elem_name, die.value, pigment)
                                local is_valid = false
                                for _, v in ipairs(valid) do
                                    if v.row == row and v.col == col then is_valid = true break end
                                end
                                if is_valid then
                                    addToWetBuffer(elem_name, row, col, die, pigment)
                                    die.kept = true -- blocca il dado
                                end
                            end
                            return
                        end
                    end
                end
                local grid_h = pattern.rows * (cell_size + spacing) - spacing
                curr_y = curr_y + grid_h + 28
            end
        end
        -- Check roll button
        if x >= roll_button.x and x <= roll_button.x + roll_button.w and
           y >= roll_button.y and y <= roll_button.y + roll_button.h then
            rollAllDice()
            return
        end
        
        -- Check click su dado nel tray (solo quando dadi fermi)
        if diceSettled then
            local die_idx = findDieAtPosition(x, y)
            if die_idx then
                toggleDieKept(die_idx)
                return
            end
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

--- Lancia solo i dadi NON kept (meccanica Farkle)
function rollAllDice()
    local rnd = (love and love.math and love.math.random) or math.random
    
    -- Conta dadi da lanciare
    local to_roll = {}
    for i = 1, #dice do
        if not dice[i].kept then
            table.insert(to_roll, i)
        end
    end
    
    if #to_roll == 0 then
        print("[Dice] Nessun dado da lanciare!")
        return
    end
    
    diceSettled = false
    diceSettledTimer = 0
    
    -- Notifica scena
    if Scriptorium then
        Scriptorium.state = "rolling"
    end
    
    -- Spawn point
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
    
    -- Lancia SOLO i dadi non-kept
    for _, i in ipairs(to_roll) do
        local jitter = 0.05 * (i - (#dice + 1) / 2)
        dice[i].star.position = vector{sx + jitter, sy - jitter, rz}
        dice[i].star.asleep = false
        dice[i].star.sleep_timer = 0
        dice[i].star.wall_hits = 0
        dice[i].star.angular = vector{(rnd() - 0.5) * 12, (rnd() - 0.5) * 12, (rnd() - 0.5) * 12}
        dice[i].value = nil  -- Reset valore
        
        local noise = 1.2
        dice[i].star.velocity = vector{
            base_velocity[1] + (rnd() - 0.5) * noise,
            base_velocity[2] + (rnd() - 0.5) * noise,
            base_velocity[3] + (rnd() - 0.5) * noise * 0.5
        }
    end
    
    print("[Dice] Lanciati " .. #to_roll .. " dadi")
end

--- Rilascia tutti i dadi (reset kept per nuovo turno)
function releaseAllDice()
    for i = 1, #dice do
        dice[i].kept = false
        dice[i].value = nil
    end
end

--- Toggle stato kept di un dado
---@param die_index number Indice del dado
function toggleDieKept(die_index)
    if die_index < 1 or die_index > #dice then return end
    dice[die_index].kept = not dice[die_index].kept
    
    -- Salva valore se kept
    if dice[die_index].kept then
        dice[die_index].value = readDieFace(dice[die_index].star)
        print("[Dice] Dado " .. die_index .. " tenuto (valore " .. dice[die_index].value .. ")")
    else
        print("[Dice] Dado " .. die_index .. " rilasciato")
    end
end

--- Trova il dado sotto le coordinate mouse (nel tray 3D)
---@param mx number Mouse X
---@param my number Mouse Y
---@return number|nil Indice dado o nil
function findDieAtPosition(mx, my)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    
    -- Parametri tray (devono matchare love.draw)
    local tray_h = h * 0.38
    local tray_y = h - tray_h
    local tray_cx = w / 2
    local tray_cy = tray_y + tray_h / 2
    local scale = math.min(w, tray_h) / 12
    
    -- Converti coordinate mouse a coordinate mondo
    local world_x = (mx - tray_cx) / scale
    local world_y = (my - tray_cy) / scale
    
    -- Trova dado più vicino (distanza 2D proiettata)
    local best_die = nil
    local best_dist = 1.5  -- Raggio di click
    
    for i = 1, #dice do
        if not dice[i].kept then  -- Solo dadi nel tray
            local pos = dice[i].star.position
            local dx = pos[1] - world_x
            local dy = pos[2] - world_y
            local dist = math.sqrt(dx*dx + dy*dy)
            
            if dist < best_dist then
                best_dist = dist
                best_die = i
            end
        end
    end
    
    return best_die
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
    print("[Dice] Settled: " .. table.concat(values, ", "))
    
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
