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
local Scriptorium = require("src.scenes.scriptorium")
local Content = require("src.content")
local DiceFaces = Content.DiceFaces
local SettingsState = require("src.core.settings_state")
local AudioManager = require("src.core.audio_manager")
local RuntimeUI = require("src.core.runtime_ui")

-- Module references (popolate in love.load)
local main_menu_module = nil
local run_module = nil
local active_module = nil

-- Configurazione board (dal main.lua originale)
config = {
    boardlight = light.metal
}
function config.boardimage(x, y)
    return "resources/textures/felt.png"
end

-- Dadi 3D
dice = {}
local dice_size = 0.92

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
local roll_button = {w = 140, h = 40, text = "Reroll", x = 0, y = 0}
local fps_font = nil
local fps_font_size = 0
local last_frame_present = nil

-- Stato overlay feedback
local overlayMessage = nil
local overlayTimer = 0
local OVERLAY_DURATION = 1.2

-- Prototype tray layout (screen-relative, no dependency on static background image).
local DICE_TRAY_LAYOUT = {
    width_ratio = 0.66,
    height_ratio = 0.34,
    max_width = 1180,
    max_height = 440,
    min_width = 720,
    min_height = 260,
    bottom_margin = 6,
    floor_top_ratio = 0.16,
    floor_bottom_ratio = 0.88,
    floor_top_width_ratio = 0.74,
    floor_bottom_width_ratio = 0.92,
}

-- Visual calibration for the prototype tray overlay.
local DICE_OVERLAY_SCALE_MULT = 1.04
local DICE_OVERLAY_CENTER_Y = 0.53

-- Physics box for dice motion inside the tray (world units).
local DICE_BOX_HALF_X = 7.2
local DICE_BOX_HALF_Y = 3.4

-- Trapezoid constraints in world space for the "invisible tray".
-- Narrower on the back side, wider on the front side to match perspective.
local DICE_TRAPEZOID = {
    y_back = -3.05,
    y_front = 3.05,
    half_back = 3.9,
    half_front = 6.5,
    bounce = 0.34,
    slide_damping = 0.90,
}

local function clamp(v, min_v, max_v)
    if v < min_v then return min_v end
    if v > max_v then return max_v end
    return v
end

local function get_tray_rect(window_w, window_h)
    local tray_w = clamp(window_w * DICE_TRAY_LAYOUT.width_ratio, DICE_TRAY_LAYOUT.min_width, DICE_TRAY_LAYOUT.max_width)
    local tray_h = clamp(window_h * DICE_TRAY_LAYOUT.height_ratio, DICE_TRAY_LAYOUT.min_height, DICE_TRAY_LAYOUT.max_height)
    return {
        x = (window_w - tray_w) * 0.5,
        y = window_h - tray_h - DICE_TRAY_LAYOUT.bottom_margin,
        w = tray_w,
        h = tray_h,
    }
end

local function get_tray_floor_polygon(tray)
    local cx = tray.x + tray.w * 0.5
    local top_y = tray.y + tray.h * DICE_TRAY_LAYOUT.floor_top_ratio
    local bottom_y = tray.y + tray.h * DICE_TRAY_LAYOUT.floor_bottom_ratio
    local top_half = (tray.w * DICE_TRAY_LAYOUT.floor_top_width_ratio) * 0.5
    local bottom_half = (tray.w * DICE_TRAY_LAYOUT.floor_bottom_width_ratio) * 0.5
    return {
        cx - top_half, top_y,
        cx + top_half, top_y,
        cx + bottom_half, bottom_y,
        cx - bottom_half, bottom_y,
    }
end

local function trapezoid_half_width_at_y(y)
    local t = (y - DICE_TRAPEZOID.y_back) / (DICE_TRAPEZOID.y_front - DICE_TRAPEZOID.y_back)
    t = clamp(t, 0, 1)
    return DICE_TRAPEZOID.half_back + (DICE_TRAPEZOID.half_front - DICE_TRAPEZOID.half_back) * t
end

local function constrain_dice_to_trapezoid()
    if active_module ~= Scriptorium then
        return
    end
    if not dice or #dice == 0 then
        return
    end

    local y_min = DICE_TRAPEZOID.y_back
    local y_max = DICE_TRAPEZOID.y_front
    local bounce = DICE_TRAPEZOID.bounce
    local slide_damping = DICE_TRAPEZOID.slide_damping

    for i = 1, #dice do
        local body = dice[i] and dice[i].star or nil
        if body and body.position and body.velocity then
            local radius = math.max(0.15, (body.radius or 0.4) * 0.50)

            local px = body.position[1]
            local py = body.position[2]
            local vx = body.velocity[1]
            local vy = body.velocity[2]
            local corrected = false

            local min_y = y_min + radius
            local max_y = y_max - radius

            if py < min_y then
                py = min_y
                if vy < 0 then
                    vy = -vy * bounce
                end
                vx = vx * slide_damping
                corrected = true
            elseif py > max_y then
                py = max_y
                if vy > 0 then
                    vy = -vy * bounce
                end
                vx = vx * slide_damping
                corrected = true
            end

            local half_w = trapezoid_half_width_at_y(py) - radius
            if half_w < 0.2 then
                half_w = 0.2
            end

            if px > half_w then
                px = half_w
                if vx > 0 then
                    vx = -vx * bounce
                end
                vy = vy * slide_damping
                corrected = true
            elseif px < -half_w then
                px = -half_w
                if vx < 0 then
                    vx = -vx * bounce
                end
                vy = vy * slide_damping
                corrected = true
            end

            if corrected then
                body.position[1] = px
                body.position[2] = py
                body.velocity[1] = vx
                body.velocity[2] = vy
                body.asleep = false
                body.sleep_timer = 0
            end
        end
    end
end

local function draw_dice_tray_overlay()
    if active_module ~= Scriptorium then
        return
    end
    if not dice or #dice == 0 then
        return
    end

    local w, h = love.graphics.getDimensions()
    local tray = get_tray_rect(w, h)
    local tray_floor_poly = get_tray_floor_polygon(tray)

    love.graphics.setScissor(
        math.floor(tray.x),
        math.floor(tray.y),
        math.ceil(tray.w),
        math.ceil(tray.h)
    )
    if love.graphics.stencil and love.graphics.setStencilTest then
        love.graphics.stencil(function()
            love.graphics.polygon("fill", unpack(tray_floor_poly))
        end, "replace", 1)
        love.graphics.setStencilTest("greater", 0)
    end

    love.graphics.push()
    local cx = tray.x + tray.w * 0.5
    local cy = tray.y + tray.h * DICE_OVERLAY_CENTER_Y
    local scale = math.max(1, (math.min(tray.w * 0.5, tray.h * 0.5) / 4) * DICE_OVERLAY_SCALE_MULT)
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale)

    -- Keep tray geometry aligned with physics bounds even when board mesh is hidden.
    render.board_extents = {-box.x, box.x, -box.y, box.y}

    -- Draw tray floor + 3D wooden frame for prototype mode.
    render.board(config.boardimage, config.boardlight, -box.x, box.x, -box.y, box.y)

    for i = 1, #dice do
        render.shadow(function(_, action)
            action()
        end, dice[i].die, dice[i].star)
    end

    render.clear()
    render.tray_border(render.zbuffer, 0.85, box.border_height or 1.1, {105, 68, 40})
    for i = 1, #dice do
        render.die(render.zbuffer, dice[i].die, dice[i].star)
    end
    render.paint()

    love.graphics.pop()
    if love.graphics.setStencilTest then
        love.graphics.setStencilTest()
    end
    love.graphics.setScissor()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- LÖVE CALLBACKS
-- ============================================================================

function love.load()
    -- Setup fisica (dal main.lua originale)
    box:set(DICE_BOX_HALF_X, DICE_BOX_HALF_Y, 10, 25, 0.25, 0.75, 0.01)
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

    -- Carica e applica impostazioni utente persistenti
    SettingsState.load()
    SettingsState.apply()
    if love.graphics then
        local desired_fps_size = RuntimeUI.sized(14)
        local ok, font = pcall(function()
            return love.graphics.newFont(desired_fps_size)
        end)
        fps_font = ok and font or love.graphics.getFont()
        fps_font_size = desired_fps_size
    end
    if love.timer then
        last_frame_present = love.timer.getTime()
    end

    -- Prototype camera: keeps top face + two lateral faces readable.
    view.yaw = 0.78
    view.pitch = 0.96
    view.distance = 13
    view.cos_pitch, view.sin_pitch = math.cos(view.pitch), math.sin(view.pitch)
    view.cos_yaw, view.sin_yaw = math.cos(view.yaw), math.sin(view.yaw)
    
    -- ...existing code...
    -- Carica moduli UI/gioco
    main_menu_module = require("src.scenes.main_menu")
    run_module = require("src.game.run").scene
    scriptorium = Scriptorium
    settings_scene = require("src.scenes.settings")
    local reward_module = require("src.scenes.reward")
    local startup_splash_module = require("src.scenes.startup_splash")
    local modules = {
        startup_splash = startup_splash_module,
        main_menu = main_menu_module,
        scriptorium = scriptorium,
        settings = settings_scene,
        run = run_module,
        reward = reward_module,
    }
    -- Funzione per cambiare modulo attivo
    function set_module(name, params)
        local next_module = modules[name]
        if next_module and next_module.enter then next_module:enter(params) end
        active_module = next_module
    end
    -- Rendi globale per accesso dai moduli
    _G.set_module = set_module
    -- Imposta il modulo iniziale
    set_module("startup_splash")
    -- Setup callback roll
    Scriptorium.onRollRequest = function()
        rollAllDice()
    end
end

function love.update(dt)
    -- Update physics
    box:update(dt)
    constrain_dice_to_trapezoid()
    -- Check se i dadi si sono fermati
    checkDiceSettled(dt)
    -- Update scena attiva
    if active_module and active_module.update then
        active_module:update(dt)
    end
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
    if active_module and active_module.draw then
        active_module:draw()
    end

    draw_dice_tray_overlay()

    if _G.show_fps then
        local desired_fps_size = RuntimeUI.sized(14)
        if love.graphics and desired_fps_size ~= fps_font_size then
            local ok, f = pcall(function()
                return love.graphics.newFont(desired_fps_size)
            end)
            fps_font = ok and f or love.graphics.getFont()
            fps_font_size = desired_fps_size
        end
        local high_contrast = RuntimeUI.high_contrast()
        local prev_font = love.graphics.getFont()
        if fps_font then
            love.graphics.setFont(fps_font)
        end
        love.graphics.setColor(0, 0, 0, high_contrast and 0.75 or 0.55)
        love.graphics.rectangle("fill", 8, 8, 92, 24, 4, 4)
        love.graphics.setColor(high_contrast and 1.0 or 0.95, high_contrast and 0.97 or 0.92, high_contrast and 0.90 or 0.82, 1)
        love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 14, 12)
        if prev_font then
            love.graphics.setFont(prev_font)
        end
    end

    local target_fps = tonumber(_G.target_fps)
    if target_fps and target_fps > 0 and love.timer then
        local target_dt = 1 / target_fps
        local now = love.timer.getTime()
        if last_frame_present then
            local elapsed = now - last_frame_present
            if elapsed < target_dt then
                love.timer.sleep(target_dt - elapsed)
                now = love.timer.getTime()
            end
        end
        last_frame_present = now
    end
end

function love.keypressed(key, scancode, isrepeat)
    if active_module and active_module.keypressed then
        active_module:keypressed(key, scancode, isrepeat)
    end
end

function love.mousepressed(x, y, button)
    if active_module and active_module.mousepressed then
        active_module:mousepressed(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if active_module and active_module.mousemoved then
        active_module:mousemoved(x, y, dx, dy, istouch)
    end
end

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
    overlayMessage = {msg = "COMPLETED!", sub = nil}
    overlayTimer = OVERLAY_DURATION
    AudioManager.play_ui("confirm")
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
    overlayMessage = {msg = "BUST!", sub = "You lost all Wet Buffer placements"}
    overlayTimer = OVERLAY_DURATION
    AudioManager.play_ui("back")
end

-- Utility: controlla se almeno un dado è piazzabile (vincoli pattern griglia)
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
    love.graphics.printf("Kept dice:", 0, tray_y - 85, screen_w, "center")
    
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
        log("[Dice] No dice available to roll.")
        return
    end
    
    diceSettled = false
    diceSettledTimer = 0
    
    -- Notifica scena
    if Scriptorium then
        Scriptorium.state = "rolling"
    end
    
    -- Spawn point
    local half_x = box.x * 0.84
    local half_y = box.y * 0.84
    local side = math.floor(rnd() * 4) + 1
    local sx, sy
    local inset_x = half_x * (0.12 + rnd() * 0.12)
    local inset_y = half_y * (0.12 + rnd() * 0.12)
    local span_x = half_x - inset_x
    local span_y = half_y - inset_y

    if side == 1 then
        sx = -half_x + inset_x
        sy = (rnd() * 2 - 1) * span_y
    elseif side == 2 then
        sx = half_x - inset_x
        sy = (rnd() * 2 - 1) * span_y
    elseif side == 3 then
        sy = -half_y + inset_y
        sx = (rnd() * 2 - 1) * span_x
    else
        sy = half_y - inset_y
        sx = (rnd() * 2 - 1) * span_x
    end
    
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

    local vertical_speed = -(18 + rnd() * 8)
    local lateral_speed = math.abs(vertical_speed) * (0.80 + rnd() * 0.25)

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
    
    AudioManager.play_ui("confirm")
    log("[Dice] Rolled " .. #to_roll .. " dice")
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
        log("[Dice] Die " .. die_index .. " kept (value " .. dice[die_index].value .. ")")
    else
        log("[Dice] Die " .. die_index .. " released")
    end
    AudioManager.play_ui("toggle")
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
    log("[Dice] Settled: " .. table.concat(values, ", "))
    AudioManager.play_ui("move")
    
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
