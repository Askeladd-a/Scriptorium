
local RuntimeUI = require("src.core.runtime_ui")

local RewardUI = {}

local COLORS = {
    panel = {0.12, 0.10, 0.08, 0.95},
    border = {0.9, 0.75, 0.3},
    text = {0.95, 0.90, 0.80},
    selected = {0.2, 0.7, 0.3},
    icon = {0.95, 0.85, 0.3},
}

local font_cache = {}

local function get_font(px)
    local size = RuntimeUI.sized(px)
    if not font_cache[size] then
        local ok, font = pcall(function()
            return love.graphics.newFont(size)
        end)
        font_cache[size] = ok and font or love.graphics.getFont()
    end
    return font_cache[size]
end

local function build_layout(tool_count)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local panel_w = math.min(w - RuntimeUI.sized(36), RuntimeUI.sized(820))
    local panel_h = math.min(h - RuntimeUI.sized(36), RuntimeUI.sized(420))
    local x = math.floor((w - panel_w) * 0.5)
    local y = math.floor((h - panel_h) * 0.5)
    local padding = RuntimeUI.sized(24)
    local title_h = RuntimeUI.sized(46)
    local gap = RuntimeUI.sized(14)
    local count = math.max(1, tool_count)
    local row_x = x + padding
    local row_y = y + title_h + RuntimeUI.sized(18)
    local row_w = panel_w - padding * 2
    local row_h = panel_h - title_h - RuntimeUI.sized(36)
    local card_w = math.max(RuntimeUI.sized(130), math.floor((row_w - gap * (count - 1)) / count))
    local card_h = row_h
    local cards = {}
    for i = 1, count do
        cards[i] = {
            x = row_x + (i - 1) * (card_w + gap),
            y = row_y,
            w = card_w,
            h = card_h,
        }
    end
    return {
        panel = {x = x, y = y, w = panel_w, h = panel_h},
        cards = cards,
    }
end

function RewardUI.getLayout(tools)
    return build_layout(tools and #tools or 0)
end

---@param tools table list of 3 tools
---@param selected integer selected index (1-3)
function RewardUI.draw(tools, selected)
    local high_contrast = RuntimeUI.high_contrast()
    local reduced_motion = RuntimeUI.reduced_animations()
    local layout = RewardUI.getLayout(tools)
    local panel = layout.panel
    local radius = RuntimeUI.sized(12)

    love.graphics.setColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], high_contrast and 0.98 or COLORS.panel[4])
    love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, radius, radius)
    love.graphics.setColor(high_contrast and 1.0 or COLORS.border[1], high_contrast and 0.85 or COLORS.border[2], high_contrast and 0.32 or COLORS.border[3], 1)
    love.graphics.setLineWidth(RuntimeUI.sized(3))
    love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, radius, radius)
    love.graphics.setLineWidth(1)

    local previous_font = love.graphics.getFont()
    local title_font = get_font(36)
    local name_font = get_font(24)
    local body_font = get_font(16)
    local uses_font = get_font(15)
    local icon_font = get_font(34)

    love.graphics.setFont(title_font)
    love.graphics.setColor(high_contrast and 1.0 or COLORS.text[1], high_contrast and 0.96 or COLORS.text[2], high_contrast and 0.86 or COLORS.text[3], 1)
    love.graphics.printf("Choose a reward", panel.x, panel.y + RuntimeUI.sized(12), panel.w, "center")

    for i, tool in ipairs(tools) do
        local card = layout.cards[i]
        local cx = card.x
        local cy = card.y
        local card_w = card.w
        local card_h = card.h
        local active = (i == selected)

        if active and not reduced_motion and love.timer and love.timer.getTime then
            local t = love.timer.getTime()
            local pulse = 0.20 + 0.08 * math.sin(t * 5.8)
            love.graphics.setColor(COLORS.selected[1], COLORS.selected[2], COLORS.selected[3], pulse)
            love.graphics.rectangle("fill", cx - 4, cy - 4, card_w + 8, card_h + 8, radius, radius)
        end

        if active then
            love.graphics.setColor(COLORS.selected[1], COLORS.selected[2], COLORS.selected[3], high_contrast and 0.34 or 0.26)
        else
            love.graphics.setColor(0.18, 0.14, 0.10, high_contrast and 0.92 or 0.84)
        end
        love.graphics.rectangle("fill", cx, cy, card_w, card_h, radius, radius)
        love.graphics.setColor(high_contrast and 1.0 or COLORS.border[1], high_contrast and 0.86 or COLORS.border[2], high_contrast and 0.36 or COLORS.border[3], active and 1 or 0.85)
        love.graphics.rectangle("line", cx, cy, card_w, card_h, radius, radius)

        love.graphics.setFont(icon_font)
        love.graphics.setColor(COLORS.icon)
        love.graphics.printf(tool.icon or "?", cx, cy + RuntimeUI.sized(12), card_w, "center")

        love.graphics.setFont(name_font)
        love.graphics.setColor(high_contrast and 1.0 or COLORS.text[1], high_contrast and 0.96 or COLORS.text[2], high_contrast and 0.88 or COLORS.text[3], 1)
        love.graphics.printf(tool.name or "Tool", cx + RuntimeUI.sized(8), cy + RuntimeUI.sized(62), card_w - RuntimeUI.sized(16), "center")

        love.graphics.setFont(body_font)
        love.graphics.setColor(high_contrast and 1.0 or COLORS.text[1], high_contrast and 0.95 or COLORS.text[2], high_contrast and 0.87 or COLORS.text[3], high_contrast and 1 or 0.95)
        love.graphics.printf(tool.description or "", cx + RuntimeUI.sized(10), cy + RuntimeUI.sized(102), card_w - RuntimeUI.sized(20), "left")

        love.graphics.setFont(uses_font)
        love.graphics.setColor(COLORS.icon)
        love.graphics.printf("Uses: " .. tostring(tool.uses or 0), cx, cy + card_h - RuntimeUI.sized(28), card_w, "center")
    end

    love.graphics.setFont(previous_font)
    return layout
end

return RewardUI
