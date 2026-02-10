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
    local margin = 48
    local sidebar_w = math.min(360, w * 0.28)
    local content_x = margin + sidebar_w + 24
    local content_w = w - content_x - margin
    local header_y = margin
    local section_gap = 28
    -- Sfondo chiaro stile Potion Craft
    love.graphics.setColor(0.98, 0.95, 0.85, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)
    -- Header
    love.graphics.setColor(0.5, 0.35, 0.15, 1)
    love.graphics.printf("Impostazioni", margin, header_y, w - margin * 2, "left")

    -- Sidebar panel
    love.graphics.setColor(0.92, 0.86, 0.68, 1)
    love.graphics.rectangle("fill", margin, header_y + 48, sidebar_w, h - header_y - margin - 48, 12, 12)
    love.graphics.setColor(0.6, 0.45, 0.2, 1)
    love.graphics.rectangle("line", margin, header_y + 48, sidebar_w, h - header_y - margin - 48, 12, 12)
    love.graphics.setColor(0.5, 0.35, 0.15, 1)
    love.graphics.printf("Sezioni", margin, header_y + 72, sidebar_w, "center")
    -- Tab navigation (sidebar)
    for i, tab in ipairs(tabs) do
        local tab_y = header_y + 112 + (i - 1) * 34
        local is_selected = i == selected_tab
        love.graphics.setColor(is_selected and 0.8 or 0.7, is_selected and 0.68 or 0.6, 0.3, 1)
        love.graphics.rectangle("fill", margin + 16, tab_y - 4, sidebar_w - 32, 28, 8, 8)
        love.graphics.setColor(0.5, 0.35, 0.15, 1)
        love.graphics.printf(tab.label, margin + 24, tab_y, sidebar_w - 48, "left")
    end

    -- Content panel
    love.graphics.setColor(0.96, 0.92, 0.78, 1)
    love.graphics.rectangle("fill", content_x, header_y + 48, content_w, h - header_y - margin - 48, 12, 12)
    love.graphics.setColor(0.6, 0.45, 0.2, 1)
    love.graphics.rectangle("line", content_x, header_y + 48, content_w, h - header_y - margin - 48, 12, 12)

    love.graphics.setColor(0.5, 0.35, 0.15, 1)
    love.graphics.printf(tabs[selected_tab].label, content_x + 24, header_y + 72, content_w - 48, "left")

    -- Sliders
    local slider_start_y = header_y + 120
    for i, slider in ipairs(sliders) do
        local y = slider_start_y + (i - 1) * 48
        love.graphics.setColor(0.5, 0.35, 0.15, 1)
        love.graphics.printf(slider.label, content_x + 24, y, content_w * 0.45, "left")
        love.graphics.setColor(0.7, 0.6, 0.3, 1)
        local bar_x = content_x + content_w * 0.55
        local bar_w = content_w * 0.35
        love.graphics.rectangle("fill", bar_x, y + 10, bar_w * slider.value, 12, 6, 6)
        love.graphics.setColor(0.5, 0.35, 0.15, 1)
        love.graphics.rectangle("line", bar_x, y + 10, bar_w, 12, 6, 6)
    end
    -- Toggles
    local toggle_start_y = slider_start_y + (#sliders * 48) + section_gap
    for i, toggle in ipairs(toggles) do
        local y = toggle_start_y + (i - 1) * 40
        love.graphics.setColor(0.5, 0.35, 0.15, 1)
        love.graphics.printf(toggle.label, content_x + 24, y, content_w * 0.45, "left")
        love.graphics.setColor(toggle.value and 0.7 or 0.8, toggle.value and 0.6 or 0.8, 0.3, 1)
        love.graphics.rectangle("fill", content_x + content_w * 0.55, y - 4, 68, 28, 8, 8)
        love.graphics.setColor(0.45, 0.3, 0.12, 1)
        love.graphics.printf(toggle.value and "Sì" or "No", content_x + content_w * 0.55, y, 68, "center")
    end
    -- Pulsanti
    local button_start_y = toggle_start_y + (#toggles * 40) + section_gap
    local button_w = 160
    local button_gap = 16
    local total_buttons_w = (#buttons * button_w) + ((#buttons - 1) * button_gap)
    local buttons_x = content_x + (content_w - total_buttons_w) / 2
    for i, btn in ipairs(buttons) do
        local x = buttons_x + (i - 1) * (button_w + button_gap)
        love.graphics.setColor(i == 2 and 0.76 or 0.7, i == 2 and 0.62 or 0.58, 0.3, 1)
        love.graphics.rectangle("fill", x, button_start_y, button_w, 36, 10, 10)
        love.graphics.setColor(0.45, 0.3, 0.12, 1)
        love.graphics.rectangle("line", x, button_start_y, button_w, 36, 10, 10)
        love.graphics.printf(btn.label, x, button_start_y + 8, button_w, "center")
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
        if _G.set_module then
            _G.set_module("main_menu")
        end
    end
end

return Settings
