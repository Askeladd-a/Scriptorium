
local ResolutionManager = {}

local state = {
    virtual_w = 1920,
    virtual_h = 1080,
    real_w = 1920,
    real_h = 1080,
    viewport_x = 0,
    viewport_y = 0,
    viewport_w = 1920,
    viewport_h = 1080,
    scale = 1,
}

local function clamp_positive(n, fallback)
    local v = tonumber(n) or fallback
    if v == nil or v <= 0 then
        return fallback
    end
    return v
end

local function recalc()
    local sx = state.real_w / state.virtual_w
    local sy = state.real_h / state.virtual_h
    state.scale = math.min(sx, sy)
    if state.scale <= 0 then
        state.scale = 1
    end

    state.viewport_w = state.virtual_w * state.scale
    state.viewport_h = state.virtual_h * state.scale
    state.viewport_x = (state.real_w - state.viewport_w) * 0.5
    state.viewport_y = (state.real_h - state.viewport_h) * 0.5
end

function ResolutionManager.init(virtual_w, virtual_h)
    state.virtual_w = clamp_positive(virtual_w, 1920)
    state.virtual_h = clamp_positive(virtual_h, 1080)
    ResolutionManager.refresh()
end

function ResolutionManager.set_virtual_size(virtual_w, virtual_h)
    state.virtual_w = clamp_positive(virtual_w, state.virtual_w)
    state.virtual_h = clamp_positive(virtual_h, state.virtual_h)
    recalc()
end

function ResolutionManager.refresh(real_w, real_h)
    if real_w == nil or real_h == nil then
        if love and love.graphics and love.graphics.getDimensions then
            real_w, real_h = love.graphics.getDimensions()
        end
    end
    state.real_w = clamp_positive(real_w, state.real_w)
    state.real_h = clamp_positive(real_h, state.real_h)
    recalc()
end

function ResolutionManager.get_virtual_size()
    return state.virtual_w, state.virtual_h
end

function ResolutionManager.get_real_size()
    return state.real_w, state.real_h
end

function ResolutionManager.get_scale()
    return state.scale
end

function ResolutionManager.get_viewport()
    return {
        x = state.viewport_x,
        y = state.viewport_y,
        w = state.viewport_w,
        h = state.viewport_h,
    }
end

function ResolutionManager.to_virtual(x, y)
    local s = state.scale
    if s <= 0 then
        return x, y
    end
    return (x - state.viewport_x) / s, (y - state.viewport_y) / s
end

function ResolutionManager.to_screen(x, y)
    return state.viewport_x + x * state.scale, state.viewport_y + y * state.scale
end

function ResolutionManager.begin_ui()
    love.graphics.push()
    love.graphics.translate(state.viewport_x, state.viewport_y)
    love.graphics.scale(state.scale, state.scale)
end

function ResolutionManager.end_ui()
    love.graphics.pop()
end

function ResolutionManager.draw_letterbox(r, g, b, a)
    local color_r = r or 0
    local color_g = g or 0
    local color_b = b or 0
    local color_a = a or 1

    if state.viewport_x <= 0 and state.viewport_y <= 0 then
        return
    end

    love.graphics.setColor(color_r, color_g, color_b, color_a)

    if state.viewport_x > 0 then
        love.graphics.rectangle("fill", 0, 0, state.viewport_x, state.real_h)
        love.graphics.rectangle(
            "fill",
            state.viewport_x + state.viewport_w,
            0,
            state.real_w - (state.viewport_x + state.viewport_w),
            state.real_h
        )
    end

    if state.viewport_y > 0 then
        love.graphics.rectangle("fill", 0, 0, state.real_w, state.viewport_y)
        love.graphics.rectangle(
            "fill",
            0,
            state.viewport_y + state.viewport_h,
            state.real_w,
            state.real_h - (state.viewport_y + state.viewport_h)
        )
    end
end

return ResolutionManager
