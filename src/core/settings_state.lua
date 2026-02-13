-- src/core/settings_state.lua
-- Gestione stato impostazioni: default, load/save, apply runtime.

local SettingsState = {}

local FILE_PATH = "settings_data.lua"

local DEFAULTS = {
    game = {
        language = "English",
    },
    controls = {
        mouse_sensitivity = 0.55,
        invert_y = false,
        prompt_input = "Keyboard",
    },
    accessibility = {
        big_text = false,
        high_contrast = false,
        reduced_animations = false,
    },
    video = {
        window_mode = "Borderless",
        fps_limit = 240,
        show_fps = false,
    },
    audio = {
        master_volume = 0.8,
        sfx_volume = 0.7,
        music_volume = 0.6,
        mute_sfx = false,
        mute_music = false,
    },
}

local VALID_LANGUAGES = {
    English = true,
}

local VALID_PROMPT_INPUT = {
    Controller = true,
    Keyboard = true,
}

local VALID_WINDOW_MODE = {
    ["Windowed"] = true,
    ["Borderless"] = true,
    ["Fullscreen"] = true,
}

local VALID_FPS_LIMIT = {
    [30] = true,
    [60] = true,
    [120] = true,
    [144] = true,
    [240] = true,
}

local current = nil
local last_windowed_w = nil
local last_windowed_h = nil

local function clamp(v, min_v, max_v)
    if v < min_v then return min_v end
    if v > max_v then return max_v end
    return v
end

local function deep_copy(value)
    if type(value) ~= "table" then
        return value
    end

    local out = {}
    for k, v in pairs(value) do
        out[k] = deep_copy(v)
    end
    return out
end

local function copy_table(tbl)
    local out = {}
    if type(tbl) ~= "table" then
        return out
    end
    for k, v in pairs(tbl) do
        out[k] = v
    end
    return out
end

local function merge_with_defaults(default_value, loaded_value)
    if type(default_value) ~= "table" then
        if type(loaded_value) == type(default_value) then
            return loaded_value
        end
        return default_value
    end

    local out = {}
    for k, dv in pairs(default_value) do
        local lv = nil
        if type(loaded_value) == "table" then
            lv = loaded_value[k]
        end
        out[k] = merge_with_defaults(dv, lv)
    end
    return out
end

local function normalize(data)
    local out = merge_with_defaults(DEFAULTS, data)

    if not VALID_LANGUAGES[out.game.language] then
        out.game.language = DEFAULTS.game.language
    end

    if not VALID_PROMPT_INPUT[out.controls.prompt_input] then
        out.controls.prompt_input = DEFAULTS.controls.prompt_input
    end
    out.controls.mouse_sensitivity = clamp(tonumber(out.controls.mouse_sensitivity) or DEFAULTS.controls.mouse_sensitivity, 0, 1)
    out.controls.invert_y = out.controls.invert_y and true or false

    out.accessibility.big_text = out.accessibility.big_text and true or false
    out.accessibility.high_contrast = out.accessibility.high_contrast and true or false
    out.accessibility.reduced_animations = out.accessibility.reduced_animations and true or false

    if not VALID_WINDOW_MODE[out.video.window_mode] then
        out.video.window_mode = DEFAULTS.video.window_mode
    end
    out.video.fps_limit = tonumber(out.video.fps_limit) or DEFAULTS.video.fps_limit
    if not VALID_FPS_LIMIT[out.video.fps_limit] then
        out.video.fps_limit = DEFAULTS.video.fps_limit
    end
    out.video.show_fps = out.video.show_fps and true or false

    out.audio.master_volume = clamp(tonumber(out.audio.master_volume) or DEFAULTS.audio.master_volume, 0, 1)
    out.audio.sfx_volume = clamp(tonumber(out.audio.sfx_volume) or DEFAULTS.audio.sfx_volume, 0, 1)
    out.audio.music_volume = clamp(tonumber(out.audio.music_volume) or DEFAULTS.audio.music_volume, 0, 1)
    out.audio.mute_sfx = out.audio.mute_sfx and true or false
    out.audio.mute_music = out.audio.mute_music and true or false

    return out
end

local function is_identifier(str)
    return type(str) == "string" and str:match("^[%a_][%w_]*$") ~= nil
end

local function sorted_keys(tbl)
    local keys = {}
    for k in pairs(tbl) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then
            return tostring(a) < tostring(b)
        end
        return type(a) < type(b)
    end)
    return keys
end

local function serialize(value, indent)
    indent = indent or 0
    local pad = string.rep(" ", indent)
    local t = type(value)

    if t == "number" then
        return tostring(value)
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "string" then
        return string.format("%q", value)
    elseif t == "table" then
        local parts = {"{\n"}
        local keys = sorted_keys(value)
        for _, key in ipairs(keys) do
            local key_repr
            if is_identifier(key) then
                key_repr = key
            else
                key_repr = "[" .. serialize(key, indent + 2) .. "]"
            end
            local val_repr = serialize(value[key], indent + 2)
            parts[#parts + 1] = string.rep(" ", indent + 2) .. key_repr .. " = " .. val_repr .. ",\n"
        end
        parts[#parts + 1] = pad .. "}"
        return table.concat(parts)
    end

    return "nil"
end

local function ensure_current()
    if not current then
        current = deep_copy(DEFAULTS)
    end
end

local function sanitize_dimension(v, fallback)
    local n = math.floor(tonumber(v) or fallback or 0)
    if n < 1 then
        return math.floor(fallback or 1)
    end
    return n
end

local function get_desktop_dimensions(flags, fallback_w, fallback_h)
    local out_w = sanitize_dimension(fallback_w, 1280)
    local out_h = sanitize_dimension(fallback_h, 720)

    if not (love and love.window and love.window.getDesktopDimensions) then
        return out_w, out_h
    end

    local display_index = 1
    if type(flags) == "table" and type(flags.display) == "number" then
        display_index = flags.display
    end

    local ok, dw, dh = pcall(love.window.getDesktopDimensions, display_index)
    if ok and type(dw) == "number" and type(dh) == "number" and dw > 0 and dh > 0 then
        return math.floor(dw), math.floor(dh)
    end

    return out_w, out_h
end

local function default_windowed_size(desktop_w, desktop_h)
    local min_w = math.min(960, desktop_w)
    local min_h = math.min(540, desktop_h)
    local w = clamp(math.floor(desktop_w * 0.84), min_w, desktop_w)
    local h = clamp(math.floor(desktop_h * 0.84), min_h, desktop_h)
    return w, h
end

function SettingsState.get_defaults()
    return deep_copy(DEFAULTS)
end

function SettingsState.get()
    ensure_current()
    return deep_copy(current)
end

function SettingsState.set(next_settings)
    current = normalize(next_settings)
    return deep_copy(current)
end

function SettingsState.reset()
    current = deep_copy(DEFAULTS)
    return deep_copy(current)
end

function SettingsState.load()
    local loaded = nil

    if love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(FILE_PATH) then
        local chunk, load_err = love.filesystem.load(FILE_PATH)
        if chunk then
            local ok, data = pcall(chunk)
            if ok and type(data) == "table" then
                loaded = data
            end
        else
            if _G.log and load_err then
                _G.log("[SettingsState] load error: " .. tostring(load_err))
            end
        end
    end

    current = normalize(loaded)
    return deep_copy(current)
end

function SettingsState.save()
    ensure_current()
    if not (love and love.filesystem and love.filesystem.write) then
        return false, "love.filesystem.write not available"
    end

    local text = "return " .. serialize(current, 0) .. "\n"
    local ok, err = love.filesystem.write(FILE_PATH, text)
    return ok, err
end

function SettingsState.apply()
    ensure_current()

    if love and love.audio and love.audio.setVolume then
        pcall(function()
            love.audio.setVolume(current.audio.master_volume)
        end)
    end

    if love and love.window and love.window.getMode and love.window.setMode then
        local mode = current.video.window_mode
        local curr_w, curr_h, curr_flags = love.window.getMode()
        curr_w = sanitize_dimension(curr_w, 1280)
        curr_h = sanitize_dimension(curr_h, 720)
        curr_flags = curr_flags or {}

        local desktop_w, desktop_h = get_desktop_dimensions(curr_flags, curr_w, curr_h)
        local target_w = curr_w
        local target_h = curr_h
        local flags = copy_table(curr_flags)

        if not curr_flags.fullscreen and not curr_flags.borderless then
            if curr_w < desktop_w or curr_h < desktop_h then
                last_windowed_w = curr_w
                last_windowed_h = curr_h
            end
        end

        flags.resizable = true
        if flags.vsync == nil then
            flags.vsync = 1
        end

        if mode == "Fullscreen" then
            flags.fullscreen = true
            flags.fullscreentype = "desktop"
            flags.borderless = false
            target_w = desktop_w
            target_h = desktop_h
            flags.x = nil
            flags.y = nil
        elseif mode == "Borderless" then
            flags.fullscreen = false
            flags.fullscreentype = "desktop"
            flags.borderless = true
            target_w = desktop_w
            target_h = desktop_h
            flags.x = 0
            flags.y = 0
        else
            flags.fullscreen = false
            flags.fullscreentype = "desktop"
            flags.borderless = false
            local default_w, default_h = default_windowed_size(desktop_w, desktop_h)
            local min_w = math.min(960, desktop_w)
            local min_h = math.min(540, desktop_h)
            local can_use_saved = (type(last_windowed_w) == "number" and type(last_windowed_h) == "number")
            if can_use_saved and last_windowed_w >= desktop_w and last_windowed_h >= desktop_h then
                can_use_saved = false
            end

            local source_w = can_use_saved and last_windowed_w or default_w
            local source_h = can_use_saved and last_windowed_h or default_h
            target_w = clamp(sanitize_dimension(source_w, default_w), min_w, desktop_w)
            target_h = clamp(sanitize_dimension(source_h, default_h), min_h, desktop_h)
            flags.x = nil
            flags.y = nil
        end

        local ok, success = pcall(love.window.setMode, target_w, target_h, flags)
        if (not ok) or (success == false) then
            local fallback_flags = {
                resizable = true,
                vsync = flags.vsync or 1,
                fullscreen = false,
                fullscreentype = "desktop",
                borderless = false,
            }
            pcall(love.window.setMode, target_w, target_h, fallback_flags)
            if _G.log then
                _G.log("[SettingsState] window mode apply failed, fallback to windowed.")
            end
        elseif mode == "Windowed" then
            last_windowed_w = target_w
            last_windowed_h = target_h
        end
    end

    -- Runtime globals usati da moduli/UI
    _G.game_settings = deep_copy(current)
    _G.show_fps = current.video.show_fps
    _G.target_fps = current.video.fps_limit
    _G.ui_scale = current.accessibility.big_text and 1.18 or 1.0
    _G.ui_high_contrast = current.accessibility.high_contrast and true or false
    _G.ui_reduced_animations = current.accessibility.reduced_animations and true or false
end

SettingsState.FILE_PATH = FILE_PATH

return SettingsState
