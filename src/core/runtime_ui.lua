
local RuntimeUI = {}

local function accessibility()
    local state = _G.game_settings
    if state and state.accessibility then
        return state.accessibility
    end
    return {
        big_text = false,
        high_contrast = false,
        reduced_animations = false,
    }
end

function RuntimeUI.scale()
    return (_G.ui_scale or 1)
end

function RuntimeUI.big_text()
    return accessibility().big_text and true or false
end

function RuntimeUI.high_contrast()
    return accessibility().high_contrast and true or false
end

function RuntimeUI.reduced_animations()
    return accessibility().reduced_animations and true or false
end

function RuntimeUI.sized(px)
    local scaled = math.floor((px * RuntimeUI.scale()) + 0.5)
    return math.max(8, scaled)
end

return RuntimeUI
