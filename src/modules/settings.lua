-- src/modules/settings.lua
-- Modulo impostazioni in stile pergamena (ispirata a Potion Craft)

local Settings = {}
local SettingsState = require("src.core.settings_state")
local AudioManager = require("src.core.audio_manager")
local RuntimeUI = require("src.core.runtime_ui")

local tabs = {
    {
        label = "Game Settings",
        controls = {
            {type = "choice", label = "Language", options = {"English"}, value_index = 1, default_index = 1, setting = "game.language"},
        },
    },
    {
        label = "Controls",
        controls = {
            {type = "slider", label = "Mouse sensitivity", value = 0.55, default = 0.55, step = 0.05, setting = "controls.mouse_sensitivity"},
            {type = "toggle", label = "Invert Y axis", value = false, default = false, setting = "controls.invert_y"},
            {type = "choice", label = "Input prompt", options = {"Controller", "Keyboard"}, value_index = 2, default_index = 2, setting = "controls.prompt_input"},
        },
    },
    {
        label = "Accessibility",
        controls = {
            {type = "toggle", label = "Large text", value = false, default = false, setting = "accessibility.big_text"},
            {type = "toggle", label = "High contrast", value = false, default = false, setting = "accessibility.high_contrast"},
            {type = "toggle", label = "Reduced animations", value = false, default = false, setting = "accessibility.reduced_animations"},
        },
    },
    {
        label = "Video Settings",
        controls = {
            {type = "choice", label = "Window mode", options = {"Windowed", "Borderless", "Fullscreen"}, value_index = 2, default_index = 2, setting = "video.window_mode"},
            {type = "choice", label = "FPS limit", options = {"30", "60", "120", "144", "240"}, value_index = 5, default_index = 5, value_map = {30, 60, 120, 144, 240}, setting = "video.fps_limit"},
            {type = "toggle", label = "Show FPS", value = false, default = false, setting = "video.show_fps"},
        },
    },
    {
        label = "Audio Settings",
        controls = {
            {type = "slider", label = "Master volume", value = 0.8, default = 0.8, step = 0.05, setting = "audio.master_volume"},
            {type = "slider", label = "SFX volume", value = 0.7, default = 0.7, step = 0.05, setting = "audio.sfx_volume"},
            {type = "slider", label = "Music volume", value = 0.6, default = 0.6, step = 0.05, setting = "audio.music_volume"},
            {type = "toggle", label = "Mute SFX", value = false, default = false, setting = "audio.mute_sfx"},
            {type = "toggle", label = "Mute music", value = false, default = false, setting = "audio.mute_music"},
        },
    },
}

local content_actions = {
    {label = "Reset", action = "reset"},
    {label = "Confirm", action = "confirm"},
    {label = "Back", action = "back"},
}

local bg_image = nil
local title_font = nil
local subtitle_font = nil
local section_font = nil
local content_font = nil
local action_font = nil

local view_mode = "sections"        -- "sections" | "content"
local selected_tab = 1
local selected_section_entry = 1    -- 1..#tabs, #tabs+1=Indietro
local selected_content_index = 1    -- controls first, then actions
local hovered_id = nil
local layout_cache = nil
local cached_scale = nil

local function clamp(v, min_v, max_v)
    if v < min_v then return min_v end
    if v > max_v then return max_v end
    return v
end

local function point_in_rect(px, py, rect)
    return px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
end

local function leave_to_main_menu()
    AudioManager.apply_audio_settings()
    if _G.set_module then
        _G.set_module("main_menu")
    end
end

local function load_font(candidates, size)
    if love.filesystem and love.filesystem.getInfo then
        for _, path in ipairs(candidates) do
            if love.filesystem.getInfo(path) then
                local ok, font = pcall(function()
                    return love.graphics.newFont(path, size)
                end)
                if ok and font then
                    return font
                end
            end
        end
    end

    local ok, fallback = pcall(function()
        return love.graphics.newFont(size)
    end)
    if ok and fallback then
        return fallback
    end
    return love.graphics.getFont()
end

local function ensure_assets()
    local scale = RuntimeUI.scale()
    if cached_scale ~= scale then
        title_font = nil
        subtitle_font = nil
        section_font = nil
        content_font = nil
        action_font = nil
        cached_scale = scale
    end

    if not bg_image and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo("resources/ui/menu.png") then
        pcall(function()
            bg_image = love.graphics.newImage("resources/ui/menu.png")
        end)
    end

    if not title_font then
        title_font = load_font({
            "resources/font/ManuskriptGothischUNZ1A.ttf",
            "resources/font/UnifrakturMaguntia-Regular.ttf",
            "resources/font/EagleLake-Regular.ttf",
        }, RuntimeUI.sized(94))
    end

    if not subtitle_font then
        subtitle_font = load_font({
            "resources/font/EagleLake-Regular.ttf",
            "resources/font/UnifrakturMaguntia-Regular.ttf",
        }, RuntimeUI.sized(50))
    end

    if not section_font then
        section_font = load_font({
            "resources/font/EagleLake-Regular.ttf",
            "resources/font/UnifrakturMaguntia-Regular.ttf",
        }, RuntimeUI.sized(40))
    end

    if not content_font then
        content_font = load_font({
            "resources/font/EagleLake-Regular.ttf",
            "resources/font/UnifrakturMaguntia-Regular.ttf",
        }, RuntimeUI.sized(32))
    end

    if not action_font then
        action_font = load_font({
            "resources/font/UnifrakturMaguntia-Regular.ttf",
            "resources/font/EagleLake-Regular.ttf",
        }, RuntimeUI.sized(38))
    end
end

local function get_active_tab()
    return tabs[selected_tab]
end

local function split_path(path)
    local parts = {}
    for part in string.gmatch(path or "", "[^%.]+") do
        parts[#parts + 1] = part
    end
    return parts
end

local function get_path_value(tbl, path)
    local curr = tbl
    for _, part in ipairs(split_path(path)) do
        if type(curr) ~= "table" then
            return nil
        end
        curr = curr[part]
    end
    return curr
end

local function set_path_value(tbl, path, value)
    local parts = split_path(path)
    if #parts == 0 then return end
    local curr = tbl
    for i = 1, #parts - 1 do
        local part = parts[i]
        if type(curr[part]) ~= "table" then
            curr[part] = {}
        end
        curr = curr[part]
    end
    curr[parts[#parts]] = value
end

local function sync_controls_from_settings(state)
    for _, tab in ipairs(tabs) do
        for _, control in ipairs(tab.controls) do
            if control.setting then
                local raw = get_path_value(state, control.setting)
                if control.type == "slider" then
                    if type(raw) == "number" then
                        control.value = clamp(raw, 0, 1)
                    end
                elseif control.type == "toggle" then
                    if type(raw) == "boolean" then
                        control.value = raw
                    end
                elseif control.type == "choice" then
                    local idx = nil
                    if control.value_map then
                        for i, mapped in ipairs(control.value_map) do
                            if mapped == raw then
                                idx = i
                                break
                            end
                        end
                    else
                        local target = tostring(raw)
                        for i, option in ipairs(control.options) do
                            if option == target then
                                idx = i
                                break
                            end
                        end
                    end
                    if idx then
                        control.value_index = idx
                    end
                end
            end
        end
    end
end

local function build_settings_from_controls()
    local state = SettingsState.get()
    for _, tab in ipairs(tabs) do
        for _, control in ipairs(tab.controls) do
            if control.setting then
                local out_value = nil
                if control.type == "slider" then
                    out_value = clamp(control.value, 0, 1)
                elseif control.type == "toggle" then
                    out_value = control.value and true or false
                elseif control.type == "choice" then
                    if control.value_map then
                        out_value = control.value_map[control.value_index]
                    else
                        out_value = control.options[control.value_index]
                    end
                end
                if out_value ~= nil then
                    set_path_value(state, control.setting, out_value)
                end
            end
        end
    end
    return state
end

local function control_display_value(control)
    if control.type == "toggle" then
        return control.value and "Yes" or "No"
    end
    if control.type == "choice" then
        return tostring(control.options[control.value_index])
    end
    if control.type == "slider" then
        return ""
    end
    return ""
end

local function adjust_control(control, dir)
    if control.type == "slider" then
        local step = control.step or 0.05
        control.value = clamp(control.value + (step * dir), 0, 1)
    elseif control.type == "toggle" then
        if dir == 0 then
            control.value = not control.value
        elseif dir > 0 then
            control.value = true
        else
            control.value = false
        end
    elseif control.type == "choice" then
        local count = #control.options
        if count > 0 then
            control.value_index = control.value_index + dir
            if control.value_index < 1 then control.value_index = count end
            if control.value_index > count then control.value_index = 1 end
        end
    end
end

local function is_audio_control(control)
    return control
        and type(control.setting) == "string"
        and control.setting:sub(1, 6) == "audio."
end

local function apply_live_audio_preview()
    if not AudioManager.apply_audio_settings then
        return
    end
    local preview_state = build_settings_from_controls()
    if preview_state and preview_state.audio then
        AudioManager.apply_audio_settings(preview_state.audio)
    end
end

local function reset_tab(tab)
    for _, control in ipairs(tab.controls) do
        if control.type == "slider" then
            control.value = control.default or 0
        elseif control.type == "toggle" then
            control.value = control.default and true or false
        elseif control.type == "choice" then
            control.value_index = control.default_index or 1
        end
    end
end

local function run_action(action)
    if action == "reset" then
        local active_tab = get_active_tab()
        reset_tab(active_tab)
        for _, control in ipairs(active_tab.controls) do
            if is_audio_control(control) then
                apply_live_audio_preview()
                break
            end
        end
        AudioManager.play_ui("toggle")
    elseif action == "confirm" then
        local next_state = build_settings_from_controls()
        local applied_state = SettingsState.set(next_state)
        SettingsState.save()
        SettingsState.apply()
        if applied_state and applied_state.audio then
            AudioManager.apply_audio_settings(applied_state.audio)
        end
        sync_controls_from_settings(applied_state)
        AudioManager.play_ui("confirm")
    elseif action == "back" then
        view_mode = "sections"
        selected_section_entry = selected_tab
        AudioManager.play_ui("back")
    end
end

local function set_slider_from_x(control, slider_rect, mouse_x)
    if not slider_rect or slider_rect.w <= 0 then return end
    local ratio = clamp((mouse_x - slider_rect.x) / slider_rect.w, 0, 1)
    local step = control.step or 0.05
    local steps = math.max(1, math.floor(1 / step + 0.5))
    local snapped = math.floor(ratio * steps + 0.5) / steps
    control.value = clamp(snapped, 0, 1)
end

local function build_layout()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local center_x = w * 0.5
    local max_main_w = math.min(980, w * 0.78)
    local base_row_h = math.max(52, math.floor(h * 0.053))
    local base_row_gap = math.max(8, math.floor(base_row_h * 0.22))

    local layout = {
        w = w,
        h = h,
        center_x = center_x,
        max_main_w = max_main_w,
        row_h = base_row_h,
        row_gap = base_row_gap,
        title_y = math.floor(h * 0.08),
        subtitle_y = math.floor(h * 0.31),
        section_items = {},
        controls = {},
        actions = {},
    }

    if view_mode == "sections" then
        local entries = #tabs + 1
        local section_font_h = (section_font and section_font:getHeight()) or base_row_h
        local section_row_h = math.max(section_font_h + 8, math.floor(h * 0.060))
        local section_gap = math.max(14, math.floor(section_row_h * 0.30))
        local subtitle_h = (subtitle_font and subtitle_font:getHeight()) or math.floor(h * 0.05)
        local top_anchor = layout.subtitle_y + subtitle_h + 34
        local bottom_limit = h - math.floor(h * 0.16)
        local available = math.max(section_row_h, bottom_limit - top_anchor)
        local total_h = entries * section_row_h + (entries - 1) * section_gap
        if total_h > available and entries > 1 then
            local fitted_gap = math.floor((available - entries * section_row_h) / (entries - 1))
            section_gap = math.max(8, fitted_gap)
            total_h = entries * section_row_h + (entries - 1) * section_gap
            if total_h > available then
                section_row_h = math.max(section_font_h, math.floor((available - (entries - 1) * section_gap) / entries))
                total_h = entries * section_row_h + (entries - 1) * section_gap
            end
        end

        local start_y = top_anchor
        if total_h < available then
            start_y = top_anchor + math.floor((available - total_h) * 0.14)
        end

        local section_w = max_main_w * 0.92
        for i = 1, #tabs do
            local y = start_y + (i - 1) * (section_row_h + section_gap)
            layout.section_items[i] = {
                id = "section:" .. i,
                type = "tab",
                tab_index = i,
                label = tabs[i].label,
                x = center_x - section_w * 0.5,
                y = y,
                w = section_w,
                h = section_row_h,
            }
        end
        local back_y = start_y + (#tabs) * (section_row_h + section_gap)
        layout.section_items[#tabs + 1] = {
            id = "section:back",
            type = "back",
            label = "Back",
            x = center_x - section_w * 0.5,
            y = back_y,
            w = section_w,
            h = section_row_h,
        }
    else
        local tab = get_active_tab()
        local subtitle_h = (subtitle_font and subtitle_font:getHeight()) or math.floor(h * 0.05)
        local content_font_h = (content_font and content_font:getHeight()) or base_row_h
        local action_font_h = (action_font and action_font:getHeight()) or base_row_h
        local top_anchor = layout.subtitle_y + subtitle_h + 20
        local bottom_limit = h - math.floor(h * 0.08)
        local available_h = math.max(120, bottom_limit - top_anchor)
        local controls_count = #tab.controls
        local actions_count = #content_actions

        local row_h = math.max(base_row_h, content_font_h + 4)
        local row_gap = math.max(6, math.floor(content_font_h * 0.16))
        local action_h = math.max(action_font_h + 4, math.floor(row_h * 1.02))
        local action_gap = math.max(4, math.floor(action_h * 0.10))
        local block_gap = math.max(12, math.floor(row_h * 0.24))

        local function total_height()
            local controls_h = controls_count > 0 and (controls_count * row_h + (controls_count - 1) * row_gap) or 0
            local actions_h = actions_count > 0 and (actions_count * action_h + (actions_count - 1) * action_gap) or 0
            local middle_h = (controls_h > 0 and actions_h > 0) and block_gap or 0
            return controls_h + middle_h + actions_h, controls_h, actions_h, middle_h
        end

        local total_h, controls_h, actions_h, middle_h = total_height()
        while total_h > available_h and (row_gap > 4 or action_gap > 2 or block_gap > 8) do
            if row_gap >= action_gap and row_gap > 4 then
                row_gap = row_gap - 1
            elseif action_gap > 2 then
                action_gap = action_gap - 1
            elseif block_gap > 8 then
                block_gap = block_gap - 1
            end
            total_h, controls_h, actions_h, middle_h = total_height()
        end

        local min_row_h = math.max(content_font_h + 2, math.floor(base_row_h * 0.74))
        while total_h > available_h and row_h > min_row_h do
            row_h = row_h - 1
            total_h, controls_h, actions_h, middle_h = total_height()
        end

        local controls_top = top_anchor
        if total_h < available_h then
            controls_top = top_anchor + math.floor((available_h - total_h) * 0.14)
        end

        local row_w = max_main_w * 0.92
        local control_label_w = row_w * 0.62
        local control_value_w = row_w * 0.34

        for i, control in ipairs(tab.controls) do
            local y = controls_top + (i - 1) * (row_h + row_gap)
            local x = center_x - row_w * 0.5
            layout.controls[i] = {
                id = "control:" .. i,
                index = i,
                control = control,
                x = x,
                y = y,
                w = row_w,
                h = row_h,
                label_rect = {x = x + 12, y = y, w = control_label_w, h = row_h},
                value_rect = {x = x + row_w - control_value_w - 10, y = y, w = control_value_w, h = row_h},
            }

            if control.type == "slider" then
                layout.controls[i].slider_rect = {
                    x = x + row_w - control_value_w - 8,
                    y = y + math.floor(row_h * 0.24),
                    w = control_value_w - 8,
                    h = math.floor(row_h * 0.52),
                }
            end
        end

        local actions_top = controls_top + controls_h + middle_h
        local action_w = max_main_w * 0.56
        for i, action in ipairs(content_actions) do
            local y = actions_top + (i - 1) * (action_h + action_gap)
            layout.actions[i] = {
                id = "action:" .. i,
                index = i,
                action = action,
                x = center_x - action_w * 0.5,
                y = y,
                w = action_w,
                h = action_h,
            }
        end
    end

    return layout
end

local function draw_background(layout)
    local w, h = layout.w, layout.h
    local high_contrast = RuntimeUI.high_contrast()

    if bg_image then
        local bw, bh = bg_image:getWidth(), bg_image:getHeight()
        local scale = math.max(w / bw, h / bh)
        local dw, dh = bw * scale, bh * scale
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bg_image, (w - dw) * 0.5, (h - dh) * 0.5, 0, scale, scale)
    else
        love.graphics.setColor(0.96, 0.92, 0.80, 1)
        love.graphics.rectangle("fill", 0, 0, w, h)
    end

    love.graphics.setColor(0.98, 0.95, 0.85, high_contrast and 0.78 or 0.92)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local border_pad = 12
    love.graphics.setLineWidth(5)
    love.graphics.setColor(0.30, 0.17, 0.08, high_contrast and 0.96 or 0.88)
    love.graphics.rectangle("line", border_pad, border_pad, w - border_pad * 2, h - border_pad * 2, 8, 8)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.72, 0.53, 0.24, high_contrast and 0.98 or 0.85)
    love.graphics.rectangle("line", border_pad + 8, border_pad + 8, w - (border_pad + 8) * 2, h - (border_pad + 8) * 2, 8, 8)
    love.graphics.setLineWidth(1)
end

local function draw_title(layout)
    local center_x = layout.center_x
    local high_contrast = RuntimeUI.high_contrast()
    local title_face = title_font or love.graphics.getFont()
    local subtitle_face = subtitle_font or love.graphics.getFont()

    love.graphics.setFont(title_face)
    love.graphics.setColor(0.06, 0.04, 0.02, high_contrast and 0.38 or 0.24)
    love.graphics.printf("Scriptorium", center_x - 500 + 3, layout.title_y + 3, 1000, "center")
    love.graphics.setColor(high_contrast and 0.20 or 0.33, high_contrast and 0.11 or 0.21, high_contrast and 0.05 or 0.10, 1)
    love.graphics.printf("Scriptorium", center_x - 500, layout.title_y, 1000, "center")

    love.graphics.setFont(subtitle_face)
    local subtitle = (view_mode == "sections") and "Settings" or get_active_tab().label
    love.graphics.setColor(high_contrast and 0.68 or 0.76, high_contrast and 0.50 or 0.62, high_contrast and 0.20 or 0.30, 1)
    love.graphics.printf(subtitle, center_x - 450, layout.subtitle_y, 900, "center")

    local y = layout.subtitle_y + subtitle_face:getHeight() + 8
    love.graphics.setColor(high_contrast and 0.78 or 0.84, high_contrast and 0.60 or 0.70, high_contrast and 0.22 or 0.36, 0.88)
    love.graphics.rectangle("fill", center_x - 210, y, 180, 2)
    love.graphics.rectangle("fill", center_x + 30, y, 180, 2)
    love.graphics.polygon("fill", center_x, y + 6, center_x + 6, y, center_x, y - 6, center_x - 6, y)
end

local function draw_slider_gems(rect, value, selected)
    local count = 10
    local filled = math.floor(value * count + 0.5)
    local gap = math.max(3, math.floor(rect.w * 0.020))
    local gem_w = math.max(8, math.floor((rect.w - (count - 1) * gap) / count))
    local gem_h = math.max(8, math.floor(rect.h * 0.74))
    local total_w = count * gem_w + (count - 1) * gap
    local start_x = rect.x + math.max(0, (rect.w - total_w) * 0.5)
    local mid_y = rect.y + rect.h * 0.5

    for i = 1, count do
        local x = start_x + (i - 1) * (gem_w + gap)
        local lit = i <= filled
        if lit then
            love.graphics.setColor(0.35, 0.20, 0.09, 1)
        else
            love.graphics.setColor(0.84, 0.72, 0.42, selected and 0.9 or 0.75)
        end
        love.graphics.polygon("fill",
            x + gem_w * 0.5, mid_y - gem_h * 0.5,
            x + gem_w, mid_y,
            x + gem_w * 0.5, mid_y + gem_h * 0.5,
            x, mid_y
        )
    end
end

local function draw_sections(layout)
    local section_face = section_font or love.graphics.getFont()
    love.graphics.setFont(section_face)
    local font_h = section_face:getHeight()

    for i, item in ipairs(layout.section_items) do
        local is_selected = (selected_section_entry == i)
        local is_hovered = (hovered_id == item.id)
        local active = is_selected or is_hovered

        if active then
            love.graphics.setColor(0.82, 0.68, 0.35, 0.16)
            love.graphics.rectangle("fill", item.x, item.y + 2, item.w, item.h - 4, 8, 8)
        end

        local color
        if active then
            color = {0.20, 0.12, 0.05, 1}
        else
            color = {0.33, 0.20, 0.09, 1}
        end

        local text_w = section_face:getWidth(item.label)
        local tx = item.x + (item.w - text_w) * 0.5
        local ty = item.y + math.floor((item.h - font_h) * 0.5)

        love.graphics.setColor(0.08, 0.05, 0.02, 0.24)
        love.graphics.print(item.label, tx + 1, ty + 1)
        love.graphics.setColor(color)
        love.graphics.print(item.label, tx, ty)
    end
end

local function draw_content(layout)
    local content_face = content_font or love.graphics.getFont()
    love.graphics.setFont(content_face)
    local font_h = content_face:getHeight()

    local controls_count = #layout.controls
    for i, row in ipairs(layout.controls) do
        local is_selected = (selected_content_index == i)
        local is_hovered = (hovered_id == row.id)
        local active = is_selected or is_hovered
        local control = row.control

        if active then
            love.graphics.setColor(0.82, 0.68, 0.35, 0.16)
            love.graphics.rectangle("fill", row.x, row.y + 2, row.w, row.h - 4, 7, 7)
        end

        local label_y = row.label_rect.y + math.floor((row.label_rect.h - font_h) * 0.5)
        love.graphics.setColor(0.08, 0.05, 0.02, 0.22)
        love.graphics.print(control.label, row.label_rect.x + 1, label_y + 1)
        if active then
            love.graphics.setColor(0.20, 0.12, 0.05, 1)
        else
            love.graphics.setColor(0.33, 0.20, 0.09, 1)
        end
        love.graphics.print(control.label, row.label_rect.x, label_y)

        if control.type == "slider" then
            draw_slider_gems(row.slider_rect, control.value, active)
        else
            local value_text = control_display_value(control)
            local text_w = content_face:getWidth(value_text)
            local vx = row.value_rect.x + (row.value_rect.w - text_w) * 0.5
            local vy = row.value_rect.y + math.floor((row.value_rect.h - font_h) * 0.5)
            love.graphics.setColor(0.08, 0.05, 0.02, 0.22)
            love.graphics.print(value_text, vx + 1, vy + 1)
            if active then
                love.graphics.setColor(0.20, 0.12, 0.05, 1)
            else
                love.graphics.setColor(0.35, 0.22, 0.10, 0.95)
            end
            love.graphics.print(value_text, vx, vy)
        end
    end

    local action_face = action_font or love.graphics.getFont()
    love.graphics.setFont(action_face)
    local action_font_h = action_face:getHeight()
    for i, row in ipairs(layout.actions) do
        local global_index = controls_count + i
        local is_selected = selected_content_index == global_index
        local is_hovered = hovered_id == row.id
        local active = is_selected or is_hovered
        local label = row.action.label
        local label_w = action_face:getWidth(label)
        local tx = row.x + (row.w - label_w) * 0.5
        local ty = row.y + math.floor((row.h - action_font_h) * 0.5)

        if active then
            love.graphics.setColor(0.84, 0.72, 0.38, 0.12)
            love.graphics.rectangle("fill", row.x, row.y + 4, row.w, row.h - 8, 8, 8)
        end

        love.graphics.setColor(0.08, 0.05, 0.02, 0.24)
        love.graphics.print(label, tx + 1, ty + 1)
        if active then
            love.graphics.setColor(0.82, 0.66, 0.30, 1)
        else
            love.graphics.setColor(0.30, 0.18, 0.08, 1)
        end
        love.graphics.print(label, tx, ty)
    end
end

function Settings:enter()
    ensure_assets()
    local loaded = SettingsState.get()
    sync_controls_from_settings(loaded)
    if loaded and loaded.audio then
        AudioManager.apply_audio_settings(loaded.audio)
    end
    view_mode = "sections"
    selected_section_entry = selected_tab
    selected_content_index = 1
    hovered_id = nil
    layout_cache = nil
end

function Settings:update(dt)
    -- Reserved for future transitions/animations
end

function Settings:draw()
    ensure_assets()
    layout_cache = build_layout()
    local layout = layout_cache

    draw_background(layout)
    draw_title(layout)

    if view_mode == "sections" then
        draw_sections(layout)
    else
        draw_content(layout)
    end
end

function Settings:keypressed(_key)
    -- Mouse-only module: keyboard input intentionally disabled.
end

function Settings:mousepressed(x, y, button)
    if button ~= 1 then return end

    local layout = build_layout()
    layout_cache = layout

    if view_mode == "sections" then
        for i, item in ipairs(layout.section_items) do
            if point_in_rect(x, y, item) then
                selected_section_entry = i
                if item.type == "tab" then
                    selected_tab = item.tab_index
                    view_mode = "content"
                    selected_content_index = 1
                    AudioManager.play_ui("confirm")
                else
                    AudioManager.play_ui("back")
                    leave_to_main_menu()
                end
                return
            end
        end
        return
    end

    local tab = get_active_tab()

    for i, row in ipairs(layout.controls) do
        if point_in_rect(x, y, row) then
            selected_content_index = i
            local control = tab.controls[i]
            if control.type == "toggle" then
                adjust_control(control, 0)
                if is_audio_control(control) then
                    apply_live_audio_preview()
                end
                AudioManager.play_ui("toggle")
            elseif control.type == "choice" then
                adjust_control(control, 1)
                if is_audio_control(control) then
                    apply_live_audio_preview()
                end
                AudioManager.play_ui("toggle")
            elseif control.type == "slider" then
                set_slider_from_x(control, row.slider_rect, x)
                if is_audio_control(control) then
                    apply_live_audio_preview()
                end
                AudioManager.play_ui("toggle")
            end
            return
        end
    end

    for i, row in ipairs(layout.actions) do
        if point_in_rect(x, y, row) then
            selected_content_index = #tab.controls + i
            run_action(row.action.action)
            return
        end
    end
end

function Settings:mousemoved(x, y, dx, dy, istouch)
    local layout = layout_cache or build_layout()
    local previous_hover = hovered_id
    hovered_id = nil

    if view_mode == "sections" then
        for _, item in ipairs(layout.section_items) do
            if point_in_rect(x, y, item) then
                hovered_id = item.id
                break
            end
        end
        if hovered_id and previous_hover ~= hovered_id and not RuntimeUI.reduced_animations() then
            AudioManager.play_ui("hover")
        end
        return
    end

    local tab = get_active_tab()

    for _, row in ipairs(layout.controls) do
        if point_in_rect(x, y, row) then
            hovered_id = row.id
            break
        end
    end

    if not hovered_id then
        for _, row in ipairs(layout.actions) do
            if point_in_rect(x, y, row) then
                hovered_id = row.id
                break
            end
        end
    end

    if hovered_id and previous_hover ~= hovered_id and not RuntimeUI.reduced_animations() then
        AudioManager.play_ui("hover")
    end

    if love.mouse and love.mouse.isDown and love.mouse.isDown(1) and selected_content_index <= #tab.controls then
        local control = tab.controls[selected_content_index]
        local row = layout.controls[selected_content_index]
        if control and control.type == "slider" and row and row.slider_rect then
            if y >= row.slider_rect.y - 12 and y <= row.slider_rect.y + row.slider_rect.h + 12 then
                set_slider_from_x(control, row.slider_rect, x)
                if is_audio_control(control) then
                    apply_live_audio_preview()
                end
            end
        end
    end
end

return Settings
