
local MainMenu = {}
local AudioManager = require("src.core.audio_manager")
local RuntimeUI = require("src.core.runtime_ui")
local music = nil
local menu_font = nil
local menu_font_size = 0
local music_play_attempted = false
local menu_bg = nil

local MENU_REF_W = 1536
local MENU_REF_H = 1024

local menu_items = {
    {label = "Continue", enabled = false},
    {label = "New Game", enabled = true},
    {label = "Settings", enabled = true},
    {label = "Wishlist Now!", enabled = true},
    {label = "Quit", enabled = true},
}

local menu_positions_ref = {
    {x = 172, y = 125, w = 220, h = 52},
    {x = 177, y = 232, w = 226, h = 54},
    {x = 182, y = 340, w = 232, h = 55},
    {x = 186, y = 458, w = 244, h = 58},
    {x = 196, y = 593, w = 220, h = 54},
}

local menu_positions_screen = nil

local function get_menu_background_rect(window_w, window_h)
    if not menu_bg then
        return nil
    end

    local bw, bh = menu_bg:getWidth(), menu_bg:getHeight()
    local scale = math.min(1, math.min(window_w / bw, window_h / bh))
    local draw_w = bw * scale
    local draw_h = bh * scale
    local draw_x = window_w * 0.5 - draw_w * 0.5
    local draw_y = window_h * 0.5 - draw_h * 0.5
    return draw_x, draw_y, draw_w, draw_h, scale
end

local function build_menu_positions_screen(window_w, window_h)
    local bg_x, bg_y, bg_w, bg_h = get_menu_background_rect(window_w, window_h)
    if not bg_x then
        return nil
    end

    local scale_x = bg_w / MENU_REF_W
    local scale_y = bg_h / MENU_REF_H
    local projected = {}
    for i, ref in ipairs(menu_positions_ref) do
        projected[i] = {
            x = bg_x + ref.x * scale_x,
            y = bg_y + ref.y * scale_y,
            w = ref.w * scale_x,
            h = ref.h * scale_y,
        }
    end
    return projected
end



local save_file_candidate = nil
local WISHLIST_URL = "https://store.steampowered.com/"

local modal_message = nil
local modal_timer = 0

local selected = nil
local hovered = nil
local mouse_has_moved = false

local function get_audio_settings()
    local ok, SettingsState = pcall(function() return require("src.core.settings_state") end)
    if ok and SettingsState and SettingsState.get then
        local state = SettingsState.get()
        if state and state.audio then
            return state.audio
        end
    end
    return nil
end

local function get_menu_music_volume()
    local audio = get_audio_settings()
    if not audio then return 0.2 end
    if audio.mute_music then return 0 end
    local v = tonumber(audio.music_volume) or 0.6
    if v < 0 then v = 0 end
    if v > 1 then v = 1 end
    return v
end

function MainMenu:enter()
    selected = nil
    hovered = nil
    mouse_has_moved = false
    log("[MainMenu] enter() called")
    if love.audio and love.audio.getActiveSourceCount then
        local _, cnt = pcall(function() return love.audio.getActiveSourceCount() end)
        log(string.format("[MainMenu] love.audio active source count: %s", tostring(cnt)))
    else
        log("[MainMenu] love.audio API not available or missing getActiveSourceCount")
    end

    local desired_font_size = RuntimeUI.sized(19)
    if not menu_font or menu_font_size ~= desired_font_size then
        local candidates = {
            "resources/font/Manuskript Gothisch UNZ1A.ttf",
            "resources/font/Manuskript.ttf",
            "resources/font/UnifrakturMaguntia.ttf",
            "resources/font/EagleLake-Regular.ttf",
        }
        for _, fname in ipairs(candidates) do
            if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(fname) then
                local ok, f = pcall(function() return love.graphics.newFont(fname, desired_font_size) end)
                if ok and f then
                    menu_font = f
                    menu_font_size = desired_font_size
                    log("[MainMenu] menu font loaded: " .. fname)
                    break
                end
            end
        end
        if not menu_font then
            local ok, f = pcall(function() return love.graphics.newFont(desired_font_size) end)
            menu_font = (ok and f) or love.graphics.getFont()
            menu_font_size = desired_font_size
            log("[MainMenu] menu font fallback in use")
        end
    end

    if not menu_bg then
        if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo("resources/ui/menu.png") then
            pcall(function()
                menu_bg = love.graphics.newImage("resources/ui/menu.png")
            end)
        end
    end

    if not music then
        local ogg = "resources/sounds/maintitle.ogg"
        if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(ogg) then
            local ok, src = pcall(function()
                return love.audio.newSource(ogg, "stream")
            end)
            if ok and src then
                music = src
                music:setLooping(true)
                music:setVolume(get_menu_music_volume())
                if love.audio and love.audio.setVolume then pcall(function() love.audio.setVolume(1) end) end
                local played_ok = pcall(function() music:play() end)
                log(string.format("[MainMenu] play called .ogg success=%s isPlaying=%s", tostring(played_ok), tostring(music:isPlaying())))
                _G.menu_music_source = music
                AudioManager.register_music_source("main_menu", music)
            end
        end
    elseif not music:isPlaying() then
        pcall(function() music:setVolume(get_menu_music_volume()) end)
        pcall(function() music:play() end)
    end

    if music then
        pcall(function() music:getDuration() end)
        pcall(function() music:getVolume() end)
        pcall(function() music:isPlaying() end)
        pcall(function() love.audio.play(music) end)

        local still_playing = false
        pcall(function() still_playing = music:isPlaying() end)
        if not still_playing and love.sound and love.sound.newSoundData then
            local ogg = "resources/sounds/maintitle.ogg"
            local oksd, sd = pcall(function() return love.sound.newSoundData(ogg) end)
            if oksd and sd then
                local oksrc, ssrc = pcall(function() return love.audio.newSource(sd) end)
                if oksrc and ssrc then
                    ssrc:setLooping(true)
                    ssrc:setVolume(get_menu_music_volume())
                    pcall(function() love.audio.play(ssrc) end)
                    music = ssrc
                    _G.menu_music_source = music
                    AudioManager.register_music_source("main_menu", music)
                end
            end
        end
    end

    if music then
        _G.menu_music_source = music
        AudioManager.register_music_source("main_menu", music)
    end

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
end

function MainMenu:update(dt)
    if music and not music:isPlaying() and not music_play_attempted then
        music_play_attempted = true
        pcall(function() music:play() end)
    end
    AudioManager.refresh_music()

    if modal_timer and modal_timer > 0 then
        modal_timer = modal_timer - dt
        if modal_timer <= 0 then modal_message = nil; modal_timer = 0 end
    end
end

function MainMenu:draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local high_contrast = RuntimeUI.high_contrast()
    if love.graphics.setScissor then love.graphics.setScissor() end
    if menu_bg then
        local bg_x, bg_y, _, _, scale = get_menu_background_rect(w, h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(menu_bg, bg_x, bg_y, 0, scale, scale)
        menu_positions_screen = build_menu_positions_screen(w, h)
    else
        menu_positions_screen = nil
        if love.graphics.clear then
            love.graphics.clear(0, 0, 0, 1)
        else
            love.graphics.setColor(0.0, 0.0, 0.0, 1)
            love.graphics.rectangle("fill", 0, 0, w, h)
        end
    end


    local font = menu_font or love.graphics.getFont()
    love.graphics.setFont(font)
    for i, item in ipairs(menu_items) do
        local text = item.label or ""
        local pos = menu_positions_screen and menu_positions_screen[i] or nil
        if pos then
            local tx = pos.x
            local ty = pos.y
            local tw = pos.w
            local th = pos.h
            local isHovered = mouse_has_moved and (i == hovered)

            love.graphics.setColor(0,0,0,high_contrast and 0.76 or 0.6)
            local tfont = font
            local twidth = tfont:getWidth(text)
            local theight = tfont:getHeight()
            local text_x = tx + (tw - twidth) / 2
            local text_y = ty + (th - theight) / 2
            love.graphics.print(text, text_x + 2, text_y + 2)

            if not item.enabled then
                love.graphics.setColor(0.45,0.40,0.36,0.9)
            elseif i == selected then
                love.graphics.setColor(high_contrast and 1.0 or 0.98, high_contrast and 0.90 or 0.86, high_contrast and 0.40 or 0.34, 1)
            elseif isHovered then
                love.graphics.setColor(high_contrast and 1.0 or 0.97, high_contrast and 0.94 or 0.88, high_contrast and 0.72 or 0.6, 1)
            else
                love.graphics.setColor(high_contrast and 1.0 or 0.95, high_contrast and 0.96 or 0.90, high_contrast and 0.88 or 0.80, 1)
            end
            love.graphics.print(text, text_x, text_y)
        else
            local left_x, stack_y = math.max(24, w * 0.04), h * 0.15
            local spacing = 18
            local th = font:getHeight()
            local y = stack_y + (i-1) * (th + spacing)
            local isHovered = mouse_has_moved and (i == hovered)
            love.graphics.setColor(0,0,0,high_contrast and 0.76 or 0.6); love.graphics.print(text, left_x + 2, y + 2)
            if not item.enabled then
                love.graphics.setColor(0.45,0.40,0.36,0.9)
            elseif i == selected then
                love.graphics.setColor(high_contrast and 1.0 or 0.98, high_contrast and 0.90 or 0.86, high_contrast and 0.40 or 0.34, 1)
            elseif isHovered then
                love.graphics.setColor(high_contrast and 1.0 or 0.97, high_contrast and 0.94 or 0.88, high_contrast and 0.72 or 0.6, 1)
            else
                love.graphics.setColor(high_contrast and 1.0 or 0.95, high_contrast and 0.96 or 0.90, high_contrast and 0.88 or 0.80, 1)
            end
            love.graphics.print(text, left_x, y)
        end
    end


    if modal_message then
        local modal_font = menu_font or love.graphics.getFont()
        love.graphics.setFont(modal_font)
        local bw, bh = 520, 140
        local mx, my = (w - bw) / 2, (h - bh) / 2
        love.graphics.setColor(0,0,0,high_contrast and 0.84 or 0.7)
        love.graphics.rectangle("fill", mx, my, bw, bh, 8, 8)
        love.graphics.setColor(high_contrast and 1.0 or 0.95, high_contrast and 0.96 or 0.9, high_contrast and 0.88 or 0.8, 1)
        love.graphics.printf(modal_message, mx + 16, my + 18, bw - 32, "center")
    end
end

function MainMenu:keypressed(_key)
end

function MainMenu:mousepressed(x, y, button)
    if button ~= 1 then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local projected_positions = build_menu_positions_screen(w, h)
    for i, item in ipairs(menu_items) do
        local pos = projected_positions and projected_positions[i] or nil
        if pos then
            if x >= pos.x and x <= pos.x + pos.w and y >= pos.y and y <= pos.y + pos.h then
                if item.enabled then
                    selected = i
                    hovered = i
                    AudioManager.play_ui("confirm")
                    MainMenu:activate(i)
                end
                return
            end
        else
            local left_x, stack_y = math.max(24, w * 0.04), h * 0.15
            local font = menu_font or love.graphics.getFont()
            local spacing = 18
            local text = item.label or ""
            local tw = font:getWidth(text)
            local th = font:getHeight()
            local yb = stack_y + (i-1) * (th + spacing)
            if x >= left_x and x <= left_x + tw and y >= yb and y <= yb + th then
                if item.enabled then
                    selected = i
                    hovered = i
                    AudioManager.play_ui("confirm")
                    MainMenu:activate(i)
                end
                return
            end
        end
    end
end

function MainMenu:mousemoved(x, y, dx, dy)
    mouse_has_moved = true
    local prev_hovered = hovered
    hovered = nil
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local projected_positions = build_menu_positions_screen(w, h)
    for i, item in ipairs(menu_items) do
        local pos = projected_positions and projected_positions[i] or nil
        if pos then
            if x >= pos.x and x <= pos.x + pos.w and y >= pos.y and y <= pos.y + pos.h then
                if item.enabled then hovered = i end
                break
            end
        else
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
    if hovered and hovered ~= prev_hovered and not RuntimeUI.reduced_animations() then
        AudioManager.play_ui("hover")
    end
end

function MainMenu:activate(idx)
    local item = menu_items[idx]
    if not item or not item.enabled then return end
    if item.label == "New Game" or item.label == "Start Game" then
        local seed = os.time()
        pcall(function() if love.math and love.math.setRandomSeed then love.math.setRandomSeed(seed) end end)
        if _G.set_module then
            _G.set_module("scriptorium")
        end
    elseif item.label == "Continue" then
        local ok, SaveManager = pcall(function() return require("src.engine.save_manager") end)
        if ok and SaveManager and SaveManager.load then
            local succ, data = pcall(function() return SaveManager.load() end)
            if succ and data then
                log("[MainMenu] Loaded save via SaveManager")
                if _G.set_module then
                    _G.set_module("scriptorium")
                end
                return
            end
        end
        if save_file_candidate then
            log(string.format("[MainMenu] Continue pressed but no SaveManager; switching to scriptorium (save=%s)", tostring(save_file_candidate)))
            if _G.set_module then
                _G.set_module("scriptorium")
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
