local Splash = {}
local AudioManager = require("src.core.audio_manager")
local RuntimeUI = require("src.core.runtime_ui")
local logo = nil

local timer = 0
local inkProgress = 0

local T_INK_START = 0.8
local T_INK_DURATION = 2.5
local T_COMPLETE = 5.5

local titleFont = nil
local titleFontSize = 0

local function switchToMainMenu()
    if _G.set_module then
        _G.set_module("main_menu")
        return true
    end
    return false
end

function Splash:enter()
    timer = 0
    inkProgress = 0
    pcall(function() logo = love.graphics.newImage("resources/ui/splash.png") end)
    local desiredSize = RuntimeUI.sized(96)
    if not titleFont or titleFontSize ~= desiredSize then
        local candidates = {
            "resources/font/ManuskriptGothischUNZ1A.ttf"
        }
        local loaded = false
        for _, fname in ipairs(candidates) do
            local ok, f = pcall(function() return love.graphics.newFont(fname, desiredSize) end)
            if ok and f then
                titleFont = f
                titleFontSize = desiredSize
                loaded = true
                break
            end
        end
        if not loaded then
            local ok2, f2 = pcall(function() return love.graphics.newFont(desiredSize) end)
            titleFont = (ok2 and f2) or love.graphics.getFont()
            titleFontSize = desiredSize
        end
    end
end

function Splash:update(dt)
    local reduced = RuntimeUI.reduced_animations()
    local speed = reduced and 2.8 or 1.0
    local ink_start = reduced and (T_INK_START * 0.20) or T_INK_START
    local ink_duration = reduced and (T_INK_DURATION * 0.35) or T_INK_DURATION
    local complete_time = reduced and (T_COMPLETE * 0.42) or T_COMPLETE

    timer = timer + dt * speed
    if timer >= ink_start then
        local t = math.min((timer - ink_start) / ink_duration, 1)
        inkProgress = t
    end
    if timer >= complete_time then
        switchToMainMenu()
    end
end

local function drawCenteredBackground(w, h)
    if logo then
        local lw, lh = logo:getWidth(), logo:getHeight()
        local scale = math.max((w) / lw, (h) / lh)
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(logo, w/2 - (lw*scale)/2, h/2 - (lh*scale)/2, 0, scale, scale)
    else
        love.graphics.setColor(0.06, 0.04, 0.03)
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
end

function Splash:draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local high_contrast = RuntimeUI.high_contrast()
    if love.graphics.clear then love.graphics.clear(0, 0, 0, 1) end

    drawCenteredBackground(w, h)


    local tf = titleFont or love.graphics.getFont()
    love.graphics.setFont(tf)
    local title = "Scriptorium"
    love.graphics.setColor(0.09,0.05,0.03,high_contrast and 0.22 or 0.12)
    love.graphics.printf(title, 0, h/2 - 80, w, "center")

    love.graphics.setColor(high_contrast and 0.10 or 0.17, high_contrast and 0.05 or 0.09, high_contrast and 0.02 or 0.05)
    local textWidth = tf:getWidth(title)
    local tx = (w - textWidth) / 2
    local ty = h/2 - 80
    local revealW = textWidth * inkProgress
    if revealW > 0 then
        love.graphics.setScissor(tx, ty, revealW, tf:getHeight())
        love.graphics.printf(title, 0, ty, w, "center")
        love.graphics.setScissor()
    end

end

function Splash:keypressed(_key)
end

function Splash:mousepressed(x,y,button)
    if button == 1 then
        AudioManager.play_ui("confirm")
        switchToMainMenu()
    end
end

return Splash
