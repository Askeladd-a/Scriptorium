-- src/scenes/splash.lua
-- Splash screen CrackScript Studio

local Splash = {}

local timer = 0
local state = "fadein" -- fadein, hold, fadeout, done
local alpha = 0
local FADE_TIME = 0.7
local HOLD_TIME = 1.6
local logo = nil

function Splash:enter()
    timer = 0
    state = "fadein"
    alpha = 0
    if not logo then
        -- Safe-load logo: only if file exists and loading succeeds
        local ok = false
        if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo("resources/ui/crackscript_logo.png") then
            ok = pcall(function()
                logo = love.graphics.newImage("resources/ui/crackscript_logo.png")
            end)
        end
        if not ok then
            logo = nil -- fallback: no logo, still continue
        end
    end
    print("[Splash] enter. logo=" .. (logo and "loaded" or "nil"))
    -- Preload main menu music (warm decoder) following Balatro pattern
    if not _G.__audio_preloaded then
        local path = "resources/sounds/maintitle.ogg"
        if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(path) then
            local ok, src = pcall(function()
                local s = love.audio.newSource(path, "stream")
                s:setVolume(0)
                love.audio.play(s)
                s:stop()
                return true
            end)
            print(string.format("[Splash] preload maintitle.ogg ok=%s", tostring(ok)))
        else
            print("[Splash] preload: maintitle.ogg not found")
        end
        _G.__audio_preloaded = true
    end
end

function Splash:update(dt)
    timer = timer + dt
    if state == "fadein" then
        alpha = math.min(timer / FADE_TIME, 1)
        if timer >= FADE_TIME then
            timer = 0
            state = "hold"
        end
    elseif state == "hold" then
        alpha = 1
        if timer >= HOLD_TIME then
            timer = 0
            state = "fadeout"
        end
    elseif state == "fadeout" then
        alpha = 1 - math.min(timer / FADE_TIME, 1)
        if timer >= FADE_TIME then
            state = "done"
            print("[Splash] fadeout complete -> switching to MainMenu")
            require("src.core.scene_manager").switch("MainMenu")
        end
    end
end

function Splash:draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0.10, 0.08, 0.06, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)
    if logo then
        local scale = math.min(w / logo:getWidth(), h / logo:getHeight()) * 0.6
        local lw, lh = logo:getWidth() * scale, logo:getHeight() * scale
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(logo, w/2 - lw/2, h/2 - lh/2, 0, scale, scale)
    end
end

function Splash:keypressed(key)
    if state ~= "done" then
        state = "fadeout"
        timer = 0
    end
end

function Splash:mousepressed(x, y, button)
    if state ~= "done" then
        state = "fadeout"
        timer = 0
    end
end

return Splash
