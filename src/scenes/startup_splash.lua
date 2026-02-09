local Splash = {}
local logo = nil

-- Animation state
local timer = 0
local inkProgress = 0 -- 0..1

-- Timings (match the attached design timings)
local T_INK_START = 0.8
local T_INK_DURATION = 2.5
local T_COMPLETE = 5.5

local titleFont = nil
local fadeIn = false
local fadeOut = false

local function switchToMainMenu()
    if _G.set_module then
        _G.set_module("main_menu")
        return true
    end
    return false
end

function Splash:enter()
    timer = 0
    fadeIn = false
    fadeOut = false
    inkProgress = 0
    -- load background if present
    pcall(function() logo = love.graphics.newImage("resources/ui/splash.png") end)
    -- load fonts (fall back to default if missing)
    if not titleFont then
        -- Try several Manuskript font filenames (exact provided file, then common fallback)
        local candidates = {
            "resources/font/ManuskriptGothischUNZ1A.ttf"
        }
        local loaded = false
        for _, fname in ipairs(candidates) do
            local ok, f = pcall(function() return love.graphics.newFont(fname, 96) end)
            if ok and f then
                titleFont = f
                loaded = true
                break
            end
        end
        if not loaded then
            local ok2, f2 = pcall(function() return love.graphics.newFont(96) end)
            titleFont = (ok2 and f2) or love.graphics.getFont()
        end
    end
    -- subtitle removed (design uses only the main title)
end

function Splash:update(dt)
    timer = timer + dt
    -- ink animation
    if timer >= T_INK_START then
        local t = math.min((timer - T_INK_START) / T_INK_DURATION, 1)
        inkProgress = t
    end
    -- complete
    if timer >= T_COMPLETE then
        switchToMainMenu()
    end
end

local function drawCenteredBackground(w, h)
    if logo then
        local lw, lh = logo:getWidth(), logo:getHeight()
        local scale = math.max((w) / lw, (h) / lh)
        -- cover the screen
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(logo, w/2 - (lw*scale)/2, h/2 - (lh*scale)/2, 0, scale, scale)
    else
        love.graphics.setColor(0.06, 0.04, 0.03)
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
end

function Splash:draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    if love.graphics.clear then love.graphics.clear(0, 0, 0, 1) end

    -- Background
    drawCenteredBackground(w, h)

    -- No fade overlay: draw directly

    -- Decorative flourishes
    local tf = titleFont or love.graphics.getFont()
    love.graphics.setFont(tf)
    local title = "Scriptorium"
    -- Outline/background faint text
    love.graphics.setColor(0.09,0.05,0.03,0.12)
    love.graphics.printf(title, 0, h/2 - 80, w, "center")

    -- Ink reveal: draw masked filled text by using scissor
    love.graphics.setColor(0.17,0.09,0.05)
    local textWidth = tf:getWidth(title)
    local tx = (w - textWidth) / 2
    local ty = h/2 - 80
    local revealW = textWidth * inkProgress
    if revealW > 0 then
        love.graphics.setScissor(tx, ty, revealW, tf:getHeight())
        love.graphics.printf(title, 0, ty, w, "center")
        love.graphics.setScissor()
    end

    -- subtitle intentionally omitted to match design
end

function Splash:keypressed(key)
    switchToMainMenu()
end

function Splash:mousepressed(x,y,button)
    if button == 1 then switchToMainMenu() end
end

return Splash
