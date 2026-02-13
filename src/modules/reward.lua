-- src/modules/reward.lua
-- Schermata di selezione ricompensa (tool) dopo completamento folio

local RewardUI = require("src.ui.reward")
local AudioManager = require("src.core.audio_manager")

local RewardModule = {}

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
local layout_cache = nil

local function choose_selected_tool()
    AudioManager.play_ui("confirm")
    if run and shuffled[selected] and run.addTool then
        run:addTool(shuffled[selected])
    end
    if _G.set_module then
        _G.set_module("run", {run = run})
    end
end

function RewardModule:enter(params)
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
    layout_cache = nil
end

function RewardModule:update(dt)
    -- Reserved
end

function RewardModule:draw()
    layout_cache = RewardUI.draw(shuffled, selected)
end

function RewardModule:keypressed(_key)
    -- Mouse-only module: keyboard input intentionally disabled.
end

function RewardModule:mousemoved(x, y, _dx, _dy)
    local layout = layout_cache or RewardUI.getLayout(shuffled)
    local previous = selected
    for i, rect in ipairs(layout.cards or {}) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            selected = i
            break
        end
    end
    if selected ~= previous then
        AudioManager.play_ui("hover")
    end
end

function RewardModule:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end
    local layout = layout_cache or RewardUI.getLayout(shuffled)
    for i, rect in ipairs(layout.cards or {}) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            selected = i
            choose_selected_tool()
            return
        end
    end
end

return RewardModule
