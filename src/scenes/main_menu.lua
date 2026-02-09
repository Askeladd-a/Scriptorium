-- src/scenes/main_menu.lua
-- Scena menu principale stile "libri impilati" (UI ridisegnata: pulsanti orizzontali)

local MainMenu = {}
local music = nil
local menu_font = nil
local music_play_attempted = false
local menu_bg = nil

local menu_items = {
    {label = "Continue", enabled = false},
    {label = "New Game", enabled = true},
    {label = "Settings", enabled = true},
    {label = "Wishlist Now!", enabled = true},
    {label = "Quit", enabled = true},
}

-- Absolute positions for menu items (from design). Each entry: x,y,w,h
-- Coordinate precise per centrare ogni pulsante sulla costina corrispondente (tarate su screenshot)
local menu_positions = {
    {x=260, y=110, w=210, h=70, angle=-0.06},   -- Continue: primo libro in alto
    {x=260, y=185, w=210, h=70, angle=-0.06},   -- New Game: secondo libro
    {x=260, y=265, w=210, h=70, angle=-0.06},   -- Settings: terzo libro
    {x=260, y=345, w=210, h=70, angle=-0.06},   -- Wishlist: quarto libro
    {x=320, y=440, w=210, h=70, angle=-0.06},   -- Quit: rotolo in basso
}



-- Save detection and wishlist URL
local save_file_candidate = nil
local WISHLIST_URL = "https://store.steampowered.com/"

-- Simple in-menu modal for stubs (settings, messages)
local modal_message = nil
local modal_timer = 0

local selected = 2 -- Default: Start Game
local hovered = nil -- Indice del pulsante sotto il mouse

function MainMenu:enter()
    -- Reset selezione
    selected = 2
    log("[MainMenu] enter() called")
    -- Log audio subsystem state
    if love.audio and love.audio.getActiveSourceCount then
        local ok, cnt = pcall(function() return love.audio.getActiveSourceCount() end)
        log(string.format("[MainMenu] love.audio active source count: %s", tostring(cnt)))
    else
        log("[MainMenu] love.audio API not available or missing getActiveSourceCount")
    end

    -- Load menu font once (safe)
    if not menu_font then
        local candidates = {
            "resources/font/Manuskript Gothisch UNZ1A.ttf",
            "resources/font/Manuskript.ttf",
            "resources/font/UnifrakturMaguntia.ttf",
            "resources/font/EagleLake-Regular.ttf",
        }
        for _, fname in ipairs(candidates) do
            if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(fname) then
                local ok, f = pcall(function() return love.graphics.newFont(fname, 28) end)
                if ok and f then
                    menu_font = f
                    log("[MainMenu] menu font loaded: " .. fname)
                    break
                end
            end
        end
        if not menu_font then
            -- fallback to system font
            local ok, f = pcall(function() return love.graphics.newFont(28) end)
            menu_font = (ok and f) or love.graphics.getFont()
            log("[MainMenu] menu font fallback in use")
        end
    end

    -- load menu background image (optional)
    if not menu_bg then
        if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo("resources/ui/menu.png") then
            pcall(function()
                menu_bg = love.graphics.newImage("resources/ui/menu.png")
            end)
        end
    end

    -- Simplified: force load the converted .ogg file
    if not music then
        local ogg = "resources/sounds/maintitle.ogg"
        if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(ogg) then
            local ok, src = pcall(function()
                return love.audio.newSource(ogg, "stream")
            end)
            if ok and src then
                music = src
                music:setLooping(true)
                -- Lower default menu music volume to be less intrusive
                music:setVolume(0.2)
                if love.audio and love.audio.setVolume then pcall(function() love.audio.setVolume(1) end) end
                local played_ok = pcall(function() music:play() end)
                log(string.format("[MainMenu] play called .ogg success=%s isPlaying=%s", tostring(played_ok), tostring(music:isPlaying())))
            else
                -- silent failure loading menu music
            end
        else
            -- maintitle.ogg not found
        end
    elseif not music:isPlaying() then
        pcall(function() music:play() end)
    end

    -- Optional silent diagnostics and fallbacks (no console logs)
    if music then
        -- attempt to ensure it's playing; keep diagnostics silent
        pcall(function() music:getDuration() end)
        pcall(function() music:getVolume() end)
        pcall(function() music:isPlaying() end)
        pcall(function() love.audio.play(music) end)

        -- If still not playing, try static SoundData fallback (silent)
        local still_playing = false
        pcall(function() still_playing = music:isPlaying() end)
        if not still_playing and love.sound and love.sound.newSoundData then
            local ogg = "resources/sounds/maintitle.ogg"
            local oksd, sd = pcall(function() return love.sound.newSoundData(ogg) end)
            if oksd and sd then
                local oksrc, ssrc = pcall(function() return love.audio.newSource(sd) end)
                if oksrc and ssrc then
                    ssrc:setLooping(true)
                    ssrc:setVolume(0.2)
                    pcall(function() love.audio.play(ssrc) end)
                    music = ssrc
                end
            end
        end
    else
        -- music not available (silent)
    end

    -- Detect save file presence (enable Continue if found)
    local save_candidates = {
        "scriptorium_save.dat",
        "scriptorium_save.lua",
        "save.dat",
        "save.lua",
        "scriptorium_save.bin",
    }
    save_file_candidate = nil
    if love.filesystem and love.filesystem.getInfo then
        for _, fname in ipairs(save_candidates) do
            local info = pcall(function() return love.filesystem.getInfo(fname) end)
            if info then
                -- prefer the first existing file
                save_file_candidate = fname
                break
            end
        end
    end
    if save_file_candidate then
        menu_items[1].enabled = true
        log(string.format("[MainMenu] save file detected: %s -> Continue enabled", tostring(save_file_candidate)))
    else
        menu_items[1].enabled = false
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
        pcall(function() music:play() end)
    end

    -- Modal timer
    if modal_timer and modal_timer > 0 then
        modal_timer = modal_timer - dt
        if modal_timer <= 0 then modal_message = nil; modal_timer = 0 end
    end
end

function MainMenu:draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    -- Ensure full-screen scissor reset
    if love.graphics.setScissor then love.graphics.setScissor() end
    -- draw menu background if available, otherwise fallback to solid black
    if menu_bg then
        local bw, bh = menu_bg:getWidth(), menu_bg:getHeight()
        -- Non ritagliare e non ingrandire: adattiamo l'immagine senza upscaling
        local scale = math.min(1, math.min(w / bw, h / bh))
        local dw, dh = bw * scale, bh * scale
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(menu_bg, w/2 - dw/2, h/2 - dh/2, 0, scale, scale)
    else
        if love.graphics.clear then
            love.graphics.clear(0, 0, 0, 1)
        else
            love.graphics.setColor(0.0, 0.0, 0.0, 1)
            love.graphics.rectangle("fill", 0, 0, w, h)
        end
    end

    -- Tavolo (base) removed for full-black background in menu
    -- (was: love.graphics.setColor(0.25,0.18,0.10) + rectangle at bottom)

    -- Text-only menu items: place at absolute positions (static menu_positions)
    local font = menu_font or love.graphics.getFont()
    love.graphics.setFont(font)
    for i, item in ipairs(menu_items) do
        local text = item.label or ""
        local pos = menu_positions[i]
        if pos then
            local tx = pos.x
            local ty = pos.y
            local tw = pos.w
            local th = pos.h
            local isHovered = (i == hovered)

            -- Glow behind text when hovered (use rect from design)
            if isHovered then
                love.graphics.push()
                love.graphics.setBlendMode("add")
                local glowPad = 14
                love.graphics.setColor(0.98, 0.86, 0.34, 0.14)
                love.graphics.rectangle("fill", tx - glowPad/2, ty - glowPad/2, tw + glowPad, th + glowPad, 12, 12)
                love.graphics.setBlendMode("alpha")
                love.graphics.pop()
            end

            -- Shadow for legibility (offset)
            love.graphics.setColor(0,0,0,0.6)
            -- center text inside the provided box
            local tfont = font
            local twidth = tfont:getWidth(text)
            local theight = tfont:getHeight()
            local text_x = tx + (tw - twidth) / 2
            local text_y = ty + (th - theight) / 2
            love.graphics.print(text, text_x + 2, text_y + 2)

            -- Main text color
            if not item.enabled then
                love.graphics.setColor(0.5,0.45,0.4,0.85)
            elseif i == selected then
                love.graphics.setColor(0.98,0.86,0.34,1)
            elseif isHovered then
                love.graphics.setColor(0.97,0.88,0.6,1)
            else
                love.graphics.setColor(0.95,0.90,0.80,1)
            end
            love.graphics.print(text, text_x, text_y)
        else
            -- Fallback to stacked text if positions missing
            local left_x, stack_y = math.max(24, w * 0.04), h * 0.15
            local spacing = 18
            local tw = font:getWidth(text)
            local th = font:getHeight()
            local y = stack_y + (i-1) * (th + spacing)
            local isHovered = (i == hovered)
            if isHovered then
                love.graphics.push(); love.graphics.setBlendMode("add")
                love.graphics.setColor(0.98, 0.86, 0.34, 0.14)
                love.graphics.rectangle("fill", left_x - 12/2, y - 12/2, tw + 12, th + 12, 8, 8)
                love.graphics.setBlendMode("alpha"); love.graphics.pop()
            end
            love.graphics.setColor(0,0,0,0.6); love.graphics.print(text, left_x + 2, y + 2)
            if not item.enabled then
                love.graphics.setColor(0.5,0.45,0.4,0.85)
            elseif i == selected then
                love.graphics.setColor(0.98,0.86,0.34,1)
            elseif isHovered then
                love.graphics.setColor(0.97,0.88,0.6,1)
            else
                love.graphics.setColor(0.95,0.90,0.80,1)
            end
            love.graphics.print(text, left_x, y)
        end
    end

    -- Decorative overlay removed (cards/coins/dice) per UI cleanup

    -- Draw modal if present
    if modal_message then
        local font = menu_font or love.graphics.getFont()
        love.graphics.setFont(font)
        local bw, bh = 520, 140
        local mx, my = (w - bw) / 2, (h - bh) / 2
        love.graphics.setColor(0,0,0,0.7)
        love.graphics.rectangle("fill", mx, my, bw, bh, 8, 8)
        love.graphics.setColor(0.95,0.9,0.8,1)
        love.graphics.printf(modal_message, mx + 16, my + 18, bw - 32, "center")
    end
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
        if item.label == "New Game" or item.label == "Start Game" then
            -- Start a fresh run with a new seed
            local seed = os.time()
            pcall(function() if love.math and love.math.setRandomSeed then love.math.setRandomSeed(seed) end end)
            if _G.set_module then
                _G.set_module("desk_prototype")
            end
        elseif item.label == "Quit" then
            love.event.quit()
        elseif item.label == "Settings" then
            if _G.set_module then
                _G.set_module("settings")
            end
        else
            -- Delegate to activate for other items (Continue/Wishlist)
            MainMenu:activate(selected)
        end
    end
end

function MainMenu:mousepressed(x, y, button)
    if button ~= 1 then return end
    -- Usa solo menu_positions statico
    for i, item in ipairs(menu_items) do
        local pos = menu_positions[i]
        if pos then
            if x >= pos.x and x <= pos.x + pos.w and y >= pos.y and y <= pos.y + pos.h then
                if item.enabled then selected = i; hovered = i; MainMenu:activate(i) end
                return
            end
        else
            -- Fallback to text bounding box
            local w, h = love.graphics.getWidth(), love.graphics.getHeight()
            local left_x, stack_y = math.max(24, w * 0.04), h * 0.15
            local font = menu_font or love.graphics.getFont()
            local spacing = 18
            local text = item.label or ""
            local tw = font:getWidth(text)
            local th = font:getHeight()
            local yb = stack_y + (i-1) * (th + spacing)
            if x >= left_x and x <= left_x + tw and y >= yb and y <= yb + th then
                if item.enabled then selected = i; hovered = i; MainMenu:activate(i) end
                return
            end
        end
    end
end

function MainMenu:mousemoved(x, y, dx, dy)
    hovered = nil
    for i, item in ipairs(menu_items) do
        local pos = menu_positions[i]
        if pos then
            if x >= pos.x and x <= pos.x + pos.w and y >= pos.y and y <= pos.y + pos.h then
                if item.enabled then hovered = i end
                break
            end
        else
            local w, h = love.graphics.getWidth(), love.graphics.getHeight()
            local left_x, stack_y = math.max(24, w * 0.04), h * 0.15
            local spacing = 18
            local font = menu_font or love.graphics.getFont()
            local text = item.label or ""
            local tw = font:getWidth(text)
            local th = font:getHeight()
            local yb = stack_y + (i-1) * (th + spacing)
            if x >= left_x and x <= left_x + tw and y >= yb and y <= yb + th then
                if item.enabled then hovered = i end
                break
            end
        end
    end
end

function MainMenu:activate(idx)
    local item = menu_items[idx]
    if not item or not item.enabled then return end
    if item.label == "New Game" or item.label == "Start Game" then
        local seed = os.time()
        pcall(function() if love.math and love.math.setRandomSeed then love.math.setRandomSeed(seed) end end)
        if _G.set_module then
            _G.set_module("desk_prototype")
        end
    elseif item.label == "Continue" then
        -- Try to use a save manager if present
        local ok, SaveManager = pcall(function() return require("src.engine.save_manager") end)
        if ok and SaveManager and SaveManager.load then
            local succ, data = pcall(function() return SaveManager.load() end)
            if succ and data then
                log("[MainMenu] Loaded save via SaveManager")
                if _G.set_module then
                    _G.set_module("desk_prototype")
                end
                return
            end
        end
        if save_file_candidate then
            log(string.format("[MainMenu] Continue pressed but no SaveManager; switching to desk prototype (save=%s)", tostring(save_file_candidate)))
            if _G.set_module then
                _G.set_module("desk_prototype")
            end
            return
        end
        modal_message = "No saved game found. Start a New Game instead."
        modal_timer = 3
    elseif item.label == "Settings" then
        if _G.set_module then
            _G.set_module("settings")
        end
    elseif item.label == "Wishlist Now!" then
        if love.system and love.system.openURL then
            pcall(function() love.system.openURL(WISHLIST_URL) end)
        else
            modal_message = "Open the store to wishlist the game: " .. WISHLIST_URL
            modal_timer = 5
        end
    elseif item.label == "Quit" then
        love.event.quit()
    else
        log("[MainMenu] Selected (unhandled): " .. tostring(item.label))
    end
end

return MainMenu
