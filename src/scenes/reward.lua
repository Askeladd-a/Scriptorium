-- src/scenes/reward.lua
-- Schermata di selezione ricompensa (tool) dopo completamento folio

local RewardUI = require("src.ui.reward")
local AudioManager = require("src.core.audio_manager")

local RewardScene = {}

-- Available tools (inspired by RewardScreen.tsx)
local AVAILABLE_TOOLS = {
    { id = "reroll", name = "Scraper", description = "Reroll all dice once during the turn", uses = 2, icon = "↻" },
    { id = "flip", name = "Mirror", description = "Flip one die value (1↔6, 2↔5, 3↔4)", uses = 3, icon = "⧉" },
    { id = "clean", name = "Pumice Stone", description = "Remove one permanent stain", uses = 1, icon = "□" },
    { id = "convert", name = "Alchemy", description = "Change one die color to the one you need", uses = 2, icon = "⚗" },
    { id = "safe_push", name = "Blessing", description = "Your next PUSH cannot cause a bust", uses = 1, icon = "✨" },
    { id = "double", name = "Duplicate", description = "Copy one die that was already rolled", uses = 2, icon = "⎘" }
}

local selected = 1
local shuffled = {}
local run = nil

function RewardScene:enter(params)
    run = params and params.run or nil
    -- Shuffle and pick 3 tools
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
    -- Reserved
end

function RewardScene:draw()
    RewardUI.draw(shuffled, selected)
end

function RewardScene:keypressed(key)
    if key == "left" or key == "a" then
        selected = math.max(1, selected - 1)
        AudioManager.play_ui("move")
    elseif key == "right" or key == "d" then
        selected = math.min(3, selected + 1)
        AudioManager.play_ui("move")
    elseif key == "return" or key == "space" then
        AudioManager.play_ui("confirm")
        if run and shuffled[selected] then
            if run.addTool then
                run:addTool(shuffled[selected])
            end
            if _G.set_module then
                _G.set_module("run", {run = run})
            end
        end
    elseif key == "escape" or key == "backspace" then
        AudioManager.play_ui("back")
        if _G.set_module then
            _G.set_module("run", {run = run})
        end
    end
end

return RewardScene
