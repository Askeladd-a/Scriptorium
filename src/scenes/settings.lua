-- src/scenes/settings.lua
-- Scene impostazioni stile Potion Craft

local Settings = {}

local tabs = {
    {label = "Impostazioni del gioco"},
    {label = "Comandi"},
    {label = "Impostazioni di accessibilità"},
    {label = "Impostazioni video"},
    {label = "Impostazioni audio"},
}

local selected_tab = 1
local sliders = {
    {label = "Volume generale", value = 0.8},
    {label = "Volume effetti sonori", value = 0.7},
    {label = "Volume musica", value = 0.6},
}
local toggles = {
    {label = "Disattiva effetti sonori", value = false},
    {label = "Disattiva musica", value = false},
}

local buttons = {
    {label = "Resetta", action = "reset"},
    {label = "Conferma", action = "confirm"},
    {label = "Indietro", action = "back"},
}

function Settings:enter()
    -- Stub: reset state if needed
end

function Settings:update(dt)
    -- Stub: animazioni future
end

function Settings:draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local font = love.graphics.getFont()
    love.graphics.setFont(font)
    -- Sfondo chiaro stile Potion Craft
    love.graphics.setColor(0.98, 0.95, 0.85, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(0.5, 0.35, 0.15, 1)
    love.graphics.printf("Impostazioni", 0, 60, w, "center")
    love.graphics.setColor(0.7, 0.6, 0.3, 1)
    love.graphics.printf(tabs[selected_tab].label, 0, 120, w, "center")
    -- Tab navigation
    for i, tab in ipairs(tabs) do
        local tab_y = 160 + (i-1)*32
        love.graphics.setColor(i == selected_tab and 0.7 or 0.5, 0.5, 0.2, 1)
        love.graphics.printf(tab.label, 0, tab_y, w, "center")
    end
    -- Sliders
    for i, slider in ipairs(sliders) do
        local y = 340 + (i-1)*40
        love.graphics.setColor(0.5, 0.35, 0.15, 1)
        love.graphics.printf(slider.label .. "  ", w/2-180, y, 200, "right")
        love.graphics.setColor(0.7, 0.6, 0.3, 1)
        love.graphics.rectangle("fill", w/2-60, y+8, 120*slider.value, 12, 6, 6)
        love.graphics.setColor(0.5, 0.35, 0.15, 1)
        love.graphics.rectangle("line", w/2-60, y+8, 120, 12, 6, 6)
    end
    -- Toggles
    for i, toggle in ipairs(toggles) do
        local y = 480 + (i-1)*32
        love.graphics.setColor(0.5, 0.35, 0.15, 1)
        love.graphics.printf(toggle.label, w/2-180, y, 200, "right")
        love.graphics.setColor(toggle.value and 0.7 or 0.8, toggle.value and 0.6 or 0.8, 0.3, 1)
        love.graphics.printf(toggle.value and "Sì" or "No", w/2+60, y, 60, "left")
    end
    -- Pulsanti
    for i, btn in ipairs(buttons) do
        local y = 600 + (i-1)*40
        love.graphics.setColor(i==2 and 0.7 or 0.5, i==2 and 0.6 or 0.5, 0.3, 1)
        love.graphics.printf(btn.label, 0, y, w, "center")
    end
end

function Settings:keypressed(key)
    if key == "up" then
        selected_tab = selected_tab - 1
        if selected_tab < 1 then selected_tab = #tabs end
    elseif key == "down" then
        selected_tab = selected_tab + 1
        if selected_tab > #tabs then selected_tab = 1 end
    elseif key == "escape" or key == "backspace" then
        require("src.core.scene_manager").switch("MainMenu")
    end
end

return Settings
