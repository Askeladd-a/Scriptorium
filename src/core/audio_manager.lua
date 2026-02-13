
local SettingsState = require("src.core.settings_state")

local AudioManager = {}

local sources = {}
local music_sources = {}
local runtime_audio_override = nil

local function clamp(v, min_v, max_v)
    if v < min_v then return min_v end
    if v > max_v then return max_v end
    return v
end

local function get_persisted_audio_settings()
    local state = SettingsState.get()
    return state and state.audio or nil
end

local function get_audio_settings()
    if type(runtime_audio_override) == "table" then
        return runtime_audio_override
    end
    return get_persisted_audio_settings()
end

local function get_sfx_gain()
    local audio = get_audio_settings()
    if not audio then return 1 end
    if audio.mute_sfx then return 0 end
    return clamp(tonumber(audio.sfx_volume) or 1, 0, 1)
end

local function get_master_gain(audio)
    if type(audio) ~= "table" then
        return 1
    end
    return clamp(tonumber(audio.master_volume) or 1, 0, 1)
end

local function get_music_gain(audio)
    if type(audio) ~= "table" then
        return 0.6
    end
    if audio.mute_music then
        return 0
    end
    return clamp(tonumber(audio.music_volume) or 0.6, 0, 1)
end

local function is_valid_source(src)
    return src and type(src.setVolume) == "function"
end

local function make_tone(freq, duration, amp)
    if not (love and love.sound and love.sound.newSoundData and love.audio and love.audio.newSource) then
        return nil
    end

    local sample_rate = 44100
    local samples = math.max(1, math.floor(sample_rate * duration))
    local data = love.sound.newSoundData(samples, sample_rate, 16, 1)
    local two_pi = math.pi * 2
    amp = amp or 0.3

    for i = 0, samples - 1 do
        local t = i / sample_rate
        local envelope = 1 - (i / samples)
        local sample = math.sin(two_pi * freq * t) * amp * envelope
        data:setSample(i, sample)
    end

    return love.audio.newSource(data, "static")
end

local function ensure_sources()
    if sources.ui_move then return end
    sources.ui_move = make_tone(760, 0.03, 0.20)
    sources.ui_hover = make_tone(920, 0.02, 0.14)
    sources.ui_toggle = make_tone(640, 0.04, 0.22)
    sources.ui_confirm = make_tone(1180, 0.05, 0.26)
    sources.ui_back = make_tone(520, 0.05, 0.24)
end

function AudioManager.play(name, opts)
    ensure_sources()
    local base = sources[name]
    if not base then return false end

    local gain = get_sfx_gain()
    if gain <= 0 then return false end

    local src = base:clone()
    local volume_mul = opts and opts.volume_mul or 1
    local pitch = opts and opts.pitch or 1
    src:setVolume(clamp(gain * volume_mul, 0, 1))
    src:setPitch(pitch)
    src:play()
    return true
end

function AudioManager.play_ui(event_name)
    if event_name == "move" then
        return AudioManager.play("ui_move", {volume_mul = 0.85})
    elseif event_name == "hover" then
        return AudioManager.play("ui_hover", {volume_mul = 0.65})
    elseif event_name == "toggle" then
        return AudioManager.play("ui_toggle", {volume_mul = 0.85})
    elseif event_name == "confirm" then
        return AudioManager.play("ui_confirm", {volume_mul = 1.0})
    elseif event_name == "back" then
        return AudioManager.play("ui_back", {volume_mul = 0.9})
    end
    return false
end

function AudioManager.register_music_source(id, source, opts)
    if not source then return nil end
    local key = id or tostring(source)
    music_sources[key] = {
        source = source,
        volume_mul = clamp(tonumber(opts and opts.volume_mul) or 1, 0, 2),
    }
    AudioManager.apply_audio_settings()
    return key
end

function AudioManager.unregister_music_source(id)
    if id == nil then return end
    music_sources[id] = nil
end

function AudioManager.apply_audio_settings(audio_override)
    if type(audio_override) == "table" then
        runtime_audio_override = audio_override
    else
        runtime_audio_override = nil
    end
    local audio = get_audio_settings()

    local master = get_master_gain(audio)
    local music = get_music_gain(audio)

    if love and love.audio and love.audio.setVolume then
        pcall(function()
            love.audio.setVolume(master)
        end)
    end

    for key, entry in pairs(music_sources) do
        local src = entry and entry.source or nil
        if is_valid_source(src) then
            local mul = clamp(tonumber(entry.volume_mul) or 1, 0, 2)
            pcall(function()
                src:setVolume(clamp(music * mul, 0, 1))
            end)
        else
            music_sources[key] = nil
        end
    end

    local menu_src = rawget(_G, "menu_music_source")
    if menu_src and menu_src.setVolume then
        pcall(function()
            menu_src:setVolume(music)
        end)
    end
end

function AudioManager.refresh_music(audio_override)
    AudioManager.apply_audio_settings(audio_override)
end

return AudioManager
