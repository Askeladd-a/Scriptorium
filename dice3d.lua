-- dice3d.lua
-- Gestione dadi 3D e vassoio con rendering g3d e collisioni/fisica da g3d_fps

local g3d = require("g3d")

local dice3d = {}

-- Parametri vassoio
local tray = {
    x = 0, y = 0, z = 0,
    width = 8, depth = 8, height = 0.5,
    wallHeight = 1,
    wallThickness = 0.2
}

-- Lista dadi
local dice = {}

-- Definizione facce (normali in spazio modello -> valore del dado)
-- Nota: se l'orientamento delle texture non coincide, basta scambiare i valori.
local faceNormals = {
    {value = 1, normal = {0, 1, 0}},   -- +Y
    {value = 6, normal = {0, -1, 0}},  -- -Y
    {value = 2, normal = {1, 0, 0}},   -- +X
    {value = 5, normal = {-1, 0, 0}},  -- -X
    {value = 3, normal = {0, 0, 1}},   -- +Z
    {value = 4, normal = {0, 0, -1}},  -- -Z
}

local function rotateVectorByEuler(v, rot)
    local ca, cb, cc = math.cos(rot[3]), math.cos(rot[2]), math.cos(rot[1])
    local sa, sb, sc = math.sin(rot[3]), math.sin(rot[2]), math.sin(rot[1])
    local m11, m12, m13 = ca*cb, ca*sb*sc - sa*cc, ca*sb*cc + sa*sc
    local m21, m22, m23 = sa*cb, sa*sb*sc + ca*cc, sa*sb*cc - ca*sc
    local m31, m32, m33 = -sb, cb*sc, cb*cc
    return {
        m11 * v[1] + m12 * v[2] + m13 * v[3],
        m21 * v[1] + m22 * v[2] + m23 * v[3],
        m31 * v[1] + m32 * v[2] + m33 * v[3],
    }
end

local function getTopFaceFromRotation(rot)
    local up = {0, 1, 0}
    local bestValue = nil
    local bestDot = -math.huge
    for _, face in ipairs(faceNormals) do
        local worldNormal = rotateVectorByEuler(face.normal, rot)
        local dot = worldNormal[1] * up[1] + worldNormal[2] * up[2] + worldNormal[3] * up[3]
        if dot > bestDot then
            bestDot = dot
            bestValue = face.value
        end
    end
    return bestValue, bestDot
end

-- Funzione AABB 3D (in stile LeadHaul)
local function aabb_collides(a, b)
    return math.abs(a.pos[1] - b.pos[1]) < a.size/2 + b.size/2 and
           math.abs(a.pos[2] - b.pos[2]) < a.size/2 + b.size/2 and
           math.abs(a.pos[3] - b.pos[3]) < a.size/2 + b.size/2
end

-- Separazione AABB (sposta a fuori da b)
local function aabb_separate(a, b)
    local dx = a.pos[1] - b.pos[1]
    local dy = a.pos[2] - b.pos[2]
    local dz = a.pos[3] - b.pos[3]
    local px = (a.size/2 + b.size/2) - math.abs(dx)
    local py = (a.size/2 + b.size/2) - math.abs(dy)
    local pz = (a.size/2 + b.size/2) - math.abs(dz)
    if px < py and px < pz then
        a.pos[1] = a.pos[1] + (dx > 0 and px or -px)
        a.vel[1] = -a.vel[1]*0.5
    elseif py < px and py < pz then
        a.pos[2] = a.pos[2] + (dy > 0 and py or -py)
        a.vel[2] = -a.vel[2]*0.5
    else
        a.pos[3] = a.pos[3] + (dz > 0 and pz or -pz)
        a.vel[3] = -a.vel[3]*0.5
    end
end

-- Mesh vassoio e bordi
local trayMesh
local trayWalls = {}

-- Camera 3D
local camera

-- Camera orbitale controllabile
local cameraAngle = math.pi/4
local cameraRadius = 12
local cameraHeight = 8
local cameraTarget = {0, 0, 0}
local trailLength = 12
local trailInterval = 0.04
local trailTimer = 0

-- Inizializza dadi, vassoio, camera
function dice3d.load()
    -- Crea mesh vassoio (piano)
    trayMesh = g3d.newModel("models/plane.obj", "textures/marble2.png", {tray.x, tray.y, tray.z}, {0,0,0}, {tray.width, 1, tray.depth})
    -- trayMesh:setColor(0.7, 0.6, 0.4, 1) -- rimosso: lasciamo solo la texture

    -- Crea bordi vassoio (4 muri)
    trayWalls = {}
    local wx, wy, wz = tray.width, tray.wallHeight, tray.depth
    local t = tray.wallThickness
    -- Bordo nord
    local wallColor = {0.3, 0.2, 0.1, 1} -- marrone scuro
    local function makeWall(pos, scale)
        local wall = g3d.newModel("models/cube.obj", nil, pos, {0,0,0}, scale)
        wall:setColor(unpack(wallColor))
        return wall
    end
    table.insert(trayWalls, makeWall({tray.x, tray.y+wy/2, tray.z-wz/2+t/2}, {wx, wy, t}))
    -- Bordo sud
    table.insert(trayWalls, makeWall({tray.x, tray.y+wy/2, tray.z+wz/2-t/2}, {wx, wy, t}))
    -- Bordo ovest
    table.insert(trayWalls, makeWall({tray.x-wx/2+t/2, tray.y+wy/2, tray.z}, {t, wy, wz}))
    -- Bordo est
    table.insert(trayWalls, makeWall({tray.x+wx/2-t/2, tray.y+wy/2, tray.z}, {t, wy, wz}))

    -- Crea alcuni dadi di esempio
    dice = {}
    for i=1,3 do
        local d = {
            model = g3d.newModel("models/cube.obj", "textures/"..i..".png", {math.random(-2,2), 2, math.random(-2,2)}, {0,0,0}, {0.5,0.5,0.5}),
            pos = {math.random(-2,2), 2, math.random(-2,2)},
            vel = {math.random()-0.5, 0, math.random()-0.5},
            rot = {math.random()*math.pi*2, math.random()*math.pi*2, math.random()*math.pi*2},
            angVel = {math.random()-0.5, math.random()-0.5, math.random()-0.5},
            size = 0.5,
            color = {1, 1, 1, 1}, -- dadi lucidi (bianco)
            flash = 0,
            trail = {},
            topFace = 1,
        }
        table.insert(dice, d)
    end

    -- Camera 3D
    camera = g3d.camera
    camera.lookAt(0, 8, 12, 0, 0, 0)
end

-- Update fisica e collisioni
function dice3d.update(dt)
    -- Gestione animazione shake
    if isShaking then
        shakeTimer = shakeTimer + dt
        local shakeStrength = 0.25 + 0.25*math.sin(shakeTimer*20)
        for _,d in ipairs(dice) do
            d.rot[1] = d.rot[1] + math.sin(shakeTimer*8 + d.pos[1])*shakeStrength*dt
            d.rot[2] = d.rot[2] + math.cos(shakeTimer*7 + d.pos[3])*shakeStrength*dt
            d.rot[3] = d.rot[3] + math.sin(shakeTimer*6 + d.pos[2])*shakeStrength*dt
            d.pos[2] = 4 + math.sin(shakeTimer*10 + d.pos[1])*0.2
        end
        if shakeTimer >= shakeDuration then
            isShaking = false
            do_real_roll()
        end
        -- Durante shake, non aggiorna fisica vera
        for _,d in ipairs(dice) do
            d.model:setTranslation(d.pos[1], d.pos[2], d.pos[3])
            d.model:setRotation(d.rot[1], d.rot[2], d.rot[3])
        end
        return
    end
    -- ...existing code...
    for _,d in ipairs(dice) do
        -- Aggiorna posizione
        d.pos[1] = d.pos[1] + d.vel[1]*dt
        d.pos[2] = d.pos[2] + d.vel[2]*dt
        d.pos[3] = d.pos[3] + d.vel[3]*dt
        -- Aggiorna rotazione
        d.rot[1] = d.rot[1] + d.angVel[1]*dt
        d.rot[2] = d.rot[2] + d.angVel[2]*dt
        d.rot[3] = d.rot[3] + d.angVel[3]*dt
        -- Gravità
        d.vel[2] = d.vel[2] - 9.81*dt
        -- Attrito dinamico: più forte se il dado è a contatto col piano
        local minY = tray.y + tray.height/2 + d.size/2
        local onGround = d.pos[2] <= minY + 0.001
        local speed = math.sqrt(d.vel[1]^2 + d.vel[3]^2)
        local friction = onGround and (0.88 + 0.06 * math.exp(-speed * 2)) or 0.99
        d.vel[1] = d.vel[1]*friction
        d.vel[3] = d.vel[3]*friction
        -- Rallentamento angolare più forte se a terra
        local angFriction = onGround and (0.86 + 0.08 * math.exp(-speed * 2)) or 0.98
        d.angVel[1] = d.angVel[1]*angFriction
        d.angVel[2] = d.angVel[2]*angFriction
        d.angVel[3] = d.angVel[3]*angFriction
        -- Torque semplificato dal contatto (rotazione realistica)
        if onGround then
            d.angVel[1] = d.angVel[1] + d.vel[3] * 0.6 * dt
            d.angVel[3] = d.angVel[3] - d.vel[1] * 0.6 * dt
        end
        -- Se la velocità è molto bassa, azzera per fermare il dado
        if math.abs(d.vel[1]) < 0.01 then d.vel[1] = 0 end
        if math.abs(d.vel[2]) < 0.01 then d.vel[2] = 0 end
        if math.abs(d.vel[3]) < 0.01 then d.vel[3] = 0 end
        if math.abs(d.angVel[1]) < 0.01 then d.angVel[1] = 0 end
        if math.abs(d.angVel[2]) < 0.01 then d.angVel[2] = 0 end
        if math.abs(d.angVel[3]) < 0.01 then d.angVel[3] = 0 end
    end
    -- Collisione con piano vassoio e bordi (AABB)
    for _,d in ipairs(dice) do
        -- Piano inferiore
        local minY = tray.y + tray.height/2 + d.size/2
        if d.pos[2] < minY then
            d.pos[2] = minY
            d.vel[2] = -d.vel[2]*0.4
            d.vel[1] = d.vel[1]*0.95
            d.vel[3] = d.vel[3]*0.95
            d.flash = math.min(1, d.flash + 0.35)
            -- Impulso rotazionale quando tocca il piano
            d.angVel[1] = d.angVel[1] + (math.random()-0.5)*0.2
            d.angVel[2] = d.angVel[2] + (math.random()-0.5)*0.2
            d.angVel[3] = d.angVel[3] + (math.random()-0.5)*0.2
        end
        -- Bordi vassoio (AABB)
        local halfW, halfD = tray.width/2-d.size/2, tray.depth/2-d.size/2
        if d.pos[1] < tray.x - halfW then d.pos[1]=tray.x-halfW; d.vel[1]=-d.vel[1]*0.5; d.angVel[2]=d.angVel[2]+(math.random()-0.5)*0.3; d.flash = math.min(1, d.flash + 0.2) end
        if d.pos[1] > tray.x + halfW then d.pos[1]=tray.x+halfW; d.vel[1]=-d.vel[1]*0.5; d.angVel[2]=d.angVel[2]+(math.random()-0.5)*0.3; d.flash = math.min(1, d.flash + 0.2) end
        if d.pos[3] < tray.z - halfD then d.pos[3]=tray.z-halfD; d.vel[3]=-d.vel[3]*0.5; d.angVel[1]=d.angVel[1]+(math.random()-0.5)*0.3; d.flash = math.min(1, d.flash + 0.2) end
        if d.pos[3] > tray.z + halfD then d.pos[3]=tray.z+halfD; d.vel[3]=-d.vel[3]*0.5; d.angVel[1]=d.angVel[1]+(math.random()-0.5)*0.3; d.flash = math.min(1, d.flash + 0.2) end
    end
    -- Collisioni tra dadi (AABB)
    for i=1,#dice-1 do
        for j=i+1,#dice do
            local a, b = dice[i], dice[j]
            if aabb_collides(a, b) then
                aabb_separate(a, b)
                -- Impulso rotazionale casuale su collisione
                a.angVel[1] = a.angVel[1] + (math.random()-0.5)*0.2
                a.angVel[2] = a.angVel[2] + (math.random()-0.5)*0.2
                a.angVel[3] = a.angVel[3] + (math.random()-0.5)*0.2
                b.angVel[1] = b.angVel[1] + (math.random()-0.5)*0.2
                b.angVel[2] = b.angVel[2] + (math.random()-0.5)*0.2
                b.angVel[3] = b.angVel[3] + (math.random()-0.5)*0.2
                a.flash = math.min(1, a.flash + 0.2)
                b.flash = math.min(1, b.flash + 0.2)
            end
        end
    end
    -- Aggiorna trail e flash
    trailTimer = trailTimer + dt
    for _,d in ipairs(dice) do
        d.flash = math.max(0, d.flash - dt * 1.8)
        if trailTimer >= trailInterval then
            table.insert(d.trail, 1, {pos = {d.pos[1], d.pos[2], d.pos[3]}, rot = {d.rot[1], d.rot[2], d.rot[3]}, alpha = 0.25})
            if #d.trail > trailLength then
                table.remove(d.trail)
            end
        end
        local topFace = getTopFaceFromRotation(d.rot)
        d.topFace = topFace
    end
    if trailTimer >= trailInterval then
        trailTimer = 0
    end
    -- Aggiorna modelli dadi
    for _,d in ipairs(dice) do
        d.model:setTranslation(d.pos[1], d.pos[2], d.pos[3])
        d.model:setRotation(d.rot[1], d.rot[2], d.rot[3])
    end
end

-- Rendering dadi e vassoio
function dice3d.draw()
    -- Tray
    trayMesh:draw()
    -- Bordi
    for _,wall in ipairs(trayWalls) do wall:draw() end
    -- Ombre semplici sotto i dadi
    for _,d in ipairs(dice) do
        love.graphics.setColor(0,0,0,0.18)
        local shadowY = tray.y + tray.height/2 + 0.01
        love.graphics.ellipse("fill", d.pos[1], shadowY, d.size*0.6, d.size*0.18)
    end
    -- Dadi
    for _,d in ipairs(dice) do
        local flashBoost = d.flash * 0.6
        d.model:setColor(
            math.min(1, d.color[1] + flashBoost),
            math.min(1, d.color[2] + flashBoost),
            math.min(1, d.color[3] + flashBoost),
            d.color[4]
        )
        local originalPos = {d.pos[1], d.pos[2], d.pos[3]}
        local originalRot = {d.rot[1], d.rot[2], d.rot[3]}
        for _,trail in ipairs(d.trail) do
            d.model:setTranslation(trail.pos[1], trail.pos[2], trail.pos[3])
            d.model:setRotation(trail.rot[1], trail.rot[2], trail.rot[3])
            d.model:setColor(d.color[1], d.color[2], d.color[3], trail.alpha)
            d.model:draw()
        end
        d.model:setTranslation(originalPos[1], originalPos[2], originalPos[3])
        d.model:setRotation(originalRot[1], originalRot[2], originalRot[3])
        d.model:setColor(unpack(d.color))
        d.model:draw()
    end
    love.graphics.setColor(1,1,1,1)
end

-- Avvia animazione di lancio (shake)
function dice3d.roll()
    if isShaking then return end -- evita roll multipli
    isShaking = true
    shakeTimer = 0
    -- Prepara i dadi in posizione "in aria" e randomizza rotazione
    for _,d in ipairs(dice) do
        d.pos = {math.random(-2,2), 4, math.random(-2,2)}
        d.vel = {0, 0, 0}
        d.rot = {math.random()*math.pi*2, math.random()*math.pi*2, math.random()*math.pi*2}
        d.angVel = {math.random()-0.5, math.random()-0.5, math.random()-0.5}
        d.flash = 0.4
    end
end

-- Funzione interna: lancia i dadi dopo shake
local function do_real_roll()
    for _,d in ipairs(dice) do
        d.pos = {math.random(-2,2), 2, math.random(-2,2)}
        d.vel = {math.random()-0.5, 5+math.random(), math.random()-0.5}
        d.rot = {math.random()*math.pi*2, math.random()*math.pi*2, math.random()*math.pi*2}
        d.angVel = {math.random()-0.5, math.random()-0.5, math.random()-0.5}
    end
end

-- Variabili per animazione lancio
local isShaking = false
local shakeTimer = 0
local shakeDuration = 0.7

-- Aggiorna la posizione della camera orbitale
local function updateCamera()
    local x = cameraTarget[1] + math.cos(cameraAngle) * cameraRadius
    local y = cameraHeight
    local z = cameraTarget[3] + math.sin(cameraAngle) * cameraRadius
    if camera.lookAt then
        camera.lookAt(x, y, z, cameraTarget[1], cameraTarget[2], cameraTarget[3])
    else
        camera:setPosition(x, y, z)
        camera:setLookAt(cameraTarget[1], cameraTarget[2], cameraTarget[3])
    end
end

-- Input per controllare la camera (da chiamare in love.keypressed e love.wheelmoved)
function dice3d.cameraKeypressed(key)
    if key == "left" then cameraAngle = cameraAngle - 0.1 end
    if key == "right" then cameraAngle = cameraAngle + 0.1 end
    if key == "up" then cameraHeight = cameraHeight + 0.5 end
    if key == "down" then cameraHeight = cameraHeight - 0.5 end
    updateCamera()
end

function dice3d.cameraWheelmoved(dx, dy)
    cameraRadius = math.max(4, cameraRadius - dy)
    updateCamera()
end

function dice3d.getTopFace(index)
    local die = dice[index]
    if not die then return nil end
    return die.topFace
end

-- Variabili per drag mouse camera
local dragging = false
local lastMouseX = 0

function dice3d.mousepressed(x, y, button)
    if button == 2 then -- tasto destro
        dragging = true
        lastMouseX = x
    end
end

function dice3d.mousereleased(x, y, button)
    if button == 2 then
        dragging = false
    end
end

function dice3d.mousemoved(x, y, dx, dy)
    if dragging then
        cameraAngle = cameraAngle - dx * 0.01
        updateCamera()
    end
end

return dice3d
