-- src/scenes/main_menu.lua
-- Scena menu principale stile "libri impilati"

local MainMenu = {}
local music = nil
local menu_font = nil
local music_play_attempted = false

local menu_items = {
    {label = "Continue", enabled = false},
    {label = "Start Game", enabled = true},
    {label = "Settings", enabled = true},
    {label = "Wishlist Now!", enabled = true},
    {label = "Quit", enabled = true},
}

local selected = 2 -- Default: Start Game
local hovered = nil -- Indice del pulsante sotto il mouse

function MainMenu:enter()
    -- Reset selezione
    selected = 2
    print("[MainMenu] enter() called")
    -- Log audio subsystem state
    if love.audio and love.audio.getActiveSourceCount then
        local ok, cnt = pcall(function() return love.audio.getActiveSourceCount() end)
        print(string.format("[MainMenu] love.audio active source count: %s", tostring(cnt)))
    else
        print("[MainMenu] love.audio API not available or missing getActiveSourceCount")
    end
    -- Load menu font once (safe)
    if not menu_font then
        if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo("resources/font/EagleLake-Regular.ttf") then
            local ok, f = pcall(function()
                return love.graphics.newFont("resources/font/EagleLake-Regular.ttf", 32)
            end)
            if ok and f then
                menu_font = f
                print("[MainMenu] menu font loaded")
            else
                menu_font = nil
                print("[MainMenu] failed to load menu font, will fallback")
            end
        end
    end
    -- Simplified: force load the converted .ogg file
    if not music then
        local ogg = "resources/sounds/maintitle.ogg"
        if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(ogg) then
            local ok, src = pcall(function()
                return love.audio.newSource(ogg, "stream")
            end)
            print(string.format("[MainMenu] try load .ogg ok=%s src=%s", tostring(ok), tostring(src)))
            if ok and src then
                music = src
                music:setLooping(true)
                music:setVolume(0.7)
                if love.audio and love.audio.setVolume then pcall(function() love.audio.setVolume(1) end) end
                local played_ok = pcall(function() music:play() end)
                print(string.format("[MainMenu] play called .ogg success=%s isPlaying=%s", tostring(played_ok), tostring(music:isPlaying())))
            else
                print("[MainMenu] failed to load maintitle.ogg")
            end
        else
            print("[MainMenu] maintitle.ogg not found")
        end
    elseif not music:isPlaying() then
        pcall(function() music:play() end)
    end
    -- Extra diagnostics and fallback attempts
    if music then
        local ok, dur = pcall(function() return music:getDuration() end)
        print(string.format("[MainMenu] music exists. duration_ok=%s duration=%s", tostring(ok), tostring(dur)))
        local ok2, vol = pcall(function() return music:getVolume() end)
        print(string.format("[MainMenu] music:getVolume ok=%s vol=%s", tostring(ok2), tostring(vol)))
        local ok3, isplay = pcall(function() return music:isPlaying() end)
        print(string.format("[MainMenu] music:isPlaying ok=%s isPlaying=%s", tostring(ok3), tostring(isplay)))
        -- Try love.audio.play as alternative
        local okp, errp = pcall(function() love.audio.play(music) end)
        print(string.format("[MainMenu] love.audio.play called ok=%s err=%s", tostring(okp), tostring(errp)))
        -- If still not playing, try static SoundData fallback
        local still_playing = false
        pcall(function() still_playing = music:isPlaying() end)
        if not still_playing and love.sound and love.sound.newSoundData then
            local ogg = "resources/sounds/maintitle.ogg"
            local oksd, sd = pcall(function() return love.sound.newSoundData(ogg) end)
            print(string.format("[MainMenu] newSoundData ok=%s sd=%s", tostring(oksd), tostring(sd)))
            if oksd and sd then
                local oksrc, ssrc = pcall(function() return love.audio.newSource(sd) end)
                print(string.format("[MainMenu] newSource from SoundData ok=%s src=%s", tostring(oksrc), tostring(ssrc)))
                if oksrc and ssrc then
                    ssrc:setLooping(true)
                    ssrc:setVolume(0.7)
                    pcall(function() love.audio.play(ssrc) end)
                    print(string.format("[MainMenu] played SoundData source isPlaying=%s", tostring(ssrc:isPlaying())))
                    music = ssrc
                end
            end
        end
    else
        print("[MainMenu] music is nil after load attempts")
    end
end

function MainMenu:exit()
    -- Stub
end

function MainMenu:update(dt)
    -- Stub (animazioni future)
    -- Reset hover (verrà aggiornato in love.mousemoved)
    hovered = nil
    -- If we have a loaded music Source but it's not playing, try once to play it
    if music and not music:isPlaying() and not music_play_attempted then
        music_play_attempted = true
        local ok, err = pcall(function() music:play() end)
        print(string.format("[MainMenu] retry play attempted ok=%s err=%s isPlaying=%s", tostring(ok), tostring(err), tostring(music:isPlaying())))
    end
end

function MainMenu:draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setBackgroundColor(0.12, 0.10, 0.08, 1)

    -- Tavolo (base)
    love.graphics.setColor(0.25, 0.18, 0.10, 1)
    love.graphics.rectangle("fill", 0, h*0.7, w, h*0.3)

    -- Stack libri
    local book_w, book_h = 340, 60
    local stack_x, stack_y = w*0.25, h*0.25
    for i, item in ipairs(menu_items) do
        local y = stack_y + (i-1)*(book_h+8)
        -- Ombra
        love.graphics.setColor(0.08, 0.06, 0.04, 0.7)
        love.graphics.rectangle("fill", stack_x+8, y+8, book_w, book_h)
        -- Libro
        if i == selected or i == hovered then
            love.graphics.setColor(0.9, 0.75, 0.3, 1) -- Highlight oro
        else
            love.graphics.setColor(0.35, 0.25, 0.12, 1)
        end
        love.graphics.rectangle("fill", stack_x, y, book_w, book_h, 16, 16)
        -- Bordo dorato per Settings
        if item.label == "Settings" then
            love.graphics.setColor(0.9, 0.75, 0.3, 1)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", stack_x+4, y+4, book_w-8, book_h-8, 12, 12)
        end
        -- Testo
        love.graphics.setColor((i == selected or i == hovered) and {0.15, 0.10, 0.05, 1} or {0.95, 0.90, 0.80, 1})
        local font = menu_font or love.graphics.getFont()
        love.graphics.setFont(font)
        love.graphics.printf(item.label, stack_x+12, y+book_h/2-18, book_w-24, "left")
        -- Disabilitato
        if not item.enabled then
            love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
            love.graphics.rectangle("fill", stack_x, y, book_w, book_h, 16, 16)
        end
    end

    -- Decorative overlay removed (cards/coins/dice) per UI cleanup
end

function MainMenu:keypressed(key)
    if key == "up" then
        repeat
            selected = selected - 1
            if selected < 1 then selected = #menu_items end
        until menu_items[selected].enabled
    elseif key == "down" then
        repeat
            selected = selected + 1
            if selected > #menu_items then selected = 1 end
        until menu_items[selected].enabled
    elseif key == "return" or key == "space" then
        local item = menu_items[selected]
        if item.label == "Start Game" then
            require("src.core.scene_manager").switch("Scriptorium")
        elseif item.label == "Quit" then
            love.event.quit()
        else
            print("[MainMenu] Selected: " .. item.label)
        end
    end
end

function MainMenu:mousepressed(x, y, button)
    if button ~= 1 then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local book_w, book_h = 340, 60
    local stack_x, stack_y = w*0.25, h*0.25
    for i, item in ipairs(menu_items) do
        local yb = stack_y + (i-1)*(book_h+8)
        if x >= stack_x and x <= stack_x+book_w and y >= yb and y <= yb+book_h then
            if item.enabled then
                selected = i
                hovered = i
                MainMenu:activate(i)
            end
            return
        end
    end
end

function MainMenu:mousemoved(x, y, dx, dy)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local book_w, book_h = 340, 60
    local stack_x, stack_y = w*0.25, h*0.25
    hovered = nil
    for i, item in ipairs(menu_items) do
        local yb = stack_y + (i-1)*(book_h+8)
        if x >= stack_x and x <= stack_x+book_w and y >= yb and y <= yb+book_h then
            if item.enabled then
                hovered = i
            end
            break
        end
    end
end

function MainMenu:activate(idx)
    local item = menu_items[idx]
    if item.label == "Start Game" then
        require("src.core.scene_manager").switch("scriptorium")
    elseif item.label == "Quit" then
        love.event.quit()
    else
        print("[MainMenu] Selected: " .. item.label)
    end
end

return MainMenu
