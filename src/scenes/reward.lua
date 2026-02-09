-- src/scenes/reward.lua
-- Schermata di selezione ricompensa (tool) dopo completamento folio

local RewardUI = require("src.ui.reward")
local Run = require("src.game.run")

local RewardScene = {}

-- Lista strumenti disponibili (ispirata a RewardScreen.tsx)
local AVAILABLE_TOOLS = {
    { id = "reroll", name = "Raschietto", description = "Rilancia tutti i dadi una volta durante il turno", uses = 2, icon = "↻" },
    { id = "flip", name = "Specchio", description = "Inverti il valore di un dado (1↔6, 2↔5, 3↔4)", uses = 3, icon = "⧉" },
    { id = "clean", name = "Pietra Pomice", description = "Rimuovi una macchia permanente", uses = 1, icon = "□" },
    { id = "convert", name = "Alchimia", description = "Cambia il colore di un dado in quello che preferisci", uses = 2, icon = "⚗" },
    { id = "safe_push", name = "Benedizione", description = "Il prossimo PUSH non può causare bust", uses = 1, icon = "✨" },
    { id = "double", name = "Duplicato", description = "Copia un dado già lanciato", uses = 2, icon = "⎘" }
}

local selected = 1
local shuffled = {}
local run = nil

function RewardScene:enter(params)
    run = params and params.run or nil
    -- Shuffle e scegli 3 tool
    shuffled = {}
    for i, t in ipairs(AVAILABLE_TOOLS) do shuffled[i] = t end
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    shuffled = {shuffled[1], shuffled[2], shuffled[3]}
    selected = 1
end

function RewardScene:update(dt)
    -- Niente
end

function RewardScene:draw()
    RewardUI.draw(shuffled, selected)
end

function RewardScene:keypressed(key)
    if key == "left" or key == "a" then
        selected = math.max(1, selected - 1)
    elseif key == "right" or key == "d" then
        selected = math.min(3, selected + 1)
    elseif key == "return" or key == "space" then
        if run and shuffled[selected] then
            run:addTool(shuffled[selected])
            local scene_manager = require("src.core.scene_manager")
            if scene_manager and scene_manager.change then
                scene_manager.change("run", {run = run})
            end
        end
    end
end

return RewardScene
