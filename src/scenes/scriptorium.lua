-- src/scenes/scriptorium.lua
-- Main gameplay scene with tile-grid layout anchored to game.png.

local Folio = require("src.game.folio")
local RuntimeUI = require("src.core.runtime_ui")
local AudioManager = require("src.core.audio_manager")
local DiceFaces = require("src.core.dice_faces")

local Scriptorium = {
    run = nil,
    dice_results = {},
    state = "waiting", -- waiting, rolling, placing, resolved
    message = nil,
    message_timer = 0,
    selected_cell = nil,
    selected_die = nil,
}

local BG_PATH = "resources/ui/game.png"
local PROTOTYPE_NO_BACKGROUND = true
local TILE_DIR = "resources/tiles"
local MENU_FONT_CANDIDATES = {
    "resources/font/ManuskriptGothischUNZ1A.ttf",
    "resources/font/UnifrakturMaguntia-Regular.ttf",
    "resources/font/EagleLake-Regular.ttf",
}

local REF_W = 1536
local REF_H = 1024

local GRID_PANELS = {
    { element = "DROPCAPS", title = "Dropcaps", x = 462, y = 170, w = 316, h = 246 },
    { element = "TEXT", title = "Text", x = 804, y = 170, w = 316, h = 246 },
    { element = "MINIATURE", title = "Miniature", x = 462, y = 432, w = 316, h = 246 },
    { element = "BORDERS", title = "Borders", x = 804, y = 432, w = 316, h = 246 },
}

local CONSTRAINT_LINES = {
    "Specific value",
    "Specific color",
    "Different adjacent colors",
    "Different adjacent values",
    "Same value on diagonals",
    "Color + value pair",
    "Odd values only",
    "Even values only",
    "No gold in marked cells",
    "All values differ in row",
    "Permanent stain (BUST)",
}

local VALUE_TO_COLOR = {
    [1] = "MARRONE",
    [2] = "VERDE",
    [3] = "NERO",
    [4] = "ROSSO",
    [5] = "BLU",
    [6] = "GIALLO",
}

local COLOR_TO_VALUE = {
    MARRONE = 1,
    VERDE = 2,
    NERO = 3,
    ROSSO = 4,
    BLU = 5,
    GIALLO = 6,
}

local COLOR_SWATCH = {
    MARRONE = {0.55, 0.35, 0.20},
    VERDE = {0.25, 0.55, 0.30},
    NERO = {0.14, 0.14, 0.14},
    ROSSO = {0.72, 0.20, 0.15},
    BLU = {0.24, 0.37, 0.70},
    GIALLO = {0.85, 0.70, 0.25},
}

local bg_img = nil
local font_cache = {}
local tile_images = {}
local tiles_loaded = false

local function clamp(v, min_v, max_v)
    if v < min_v then return min_v end
    if v > max_v then return max_v end
    return v
end

local function ensure_bg()
    if PROTOTYPE_NO_BACKGROUND then
        bg_img = nil
        return
    end
    if bg_img then
        return
    end
    if love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(BG_PATH) then
        local ok, img = pcall(function()
            return love.graphics.newImage(BG_PATH)
        end)
        if ok and img then
            bg_img = img
        end
    end
end

local function ensure_tiles()
    if tiles_loaded then
        return
    end
    tiles_loaded = true

    if not (love and love.filesystem and love.filesystem.getDirectoryItems) then
        return
    end

    local ok, files = pcall(function()
        return love.filesystem.getDirectoryItems(TILE_DIR)
    end)
    if not ok or type(files) ~= "table" then
        return
    end

    for _, name in ipairs(files) do
        if type(name) == "string" and name:sub(-4):lower() == ".png" then
            local key = name:gsub("%.png$", "")
            local path = TILE_DIR .. "/" .. name
            local iok, image = pcall(function()
                return love.graphics.newImage(path)
            end)
            if iok and image then
                tile_images[key] = image
            end
        end
    end
end

local function get_font(px, decorative)
    local size = RuntimeUI.sized(px)
    local key = (decorative and "dec-" or "std-") .. tostring(size)
    if font_cache[key] then
        return font_cache[key]
    end

    local selected = nil
    if decorative then
        for _, path in ipairs(MENU_FONT_CANDIDATES) do
            if love.filesystem.getInfo(path) then
                local ok, font = pcall(function()
                    return love.graphics.newFont(path, size)
                end)
                if ok and font then
                    selected = font
                    break
                end
            end
        end
    end

    if not selected then
        local ok, font = pcall(function()
            return love.graphics.newFont(size)
        end)
        selected = (ok and font) or love.graphics.getFont()
    end

    font_cache[key] = selected
    return selected
end

local function get_bg_rect(window_w, window_h)
    if not bg_img then
        return {
            x = 0,
            y = 0,
            w = window_w,
            h = window_h,
            sx = window_w / REF_W,
            sy = window_h / REF_H,
        }
    end

    local bw, bh = bg_img:getWidth(), bg_img:getHeight()
    local scale = math.min(window_w / bw, window_h / bh)
    local draw_w = bw * scale
    local draw_h = bh * scale
    local draw_x = (window_w - draw_w) * 0.5
    local draw_y = (window_h - draw_h) * 0.5

    return {
        x = draw_x,
        y = draw_y,
        w = draw_w,
        h = draw_h,
        sx = draw_w / REF_W,
        sy = draw_h / REF_H,
        scale = scale,
    }
end

local function project_rect(bg, rx, ry, rw, rh)
    return {
        x = bg.x + rx * bg.sx,
        y = bg.y + ry * bg.sy,
        w = rw * bg.sx,
        h = rh * bg.sy,
    }
end

local function get_grid_panels_layout(screen_w, screen_h)
    if not PROTOTYPE_NO_BACKGROUND then
        return GRID_PANELS
    end

    local top = RuntimeUI.sized(128)
    local side = RuntimeUI.sized(82)
    local bottom_reserved = RuntimeUI.sized(226)
    local h_gap = RuntimeUI.sized(30)
    local v_gap = RuntimeUI.sized(26)

    local usable_w = math.max(RuntimeUI.sized(760), screen_w - side * 2)
    local usable_h = math.max(RuntimeUI.sized(560), screen_h - top - bottom_reserved)

    local panel_w = clamp(math.floor((usable_w - h_gap) * 0.5), RuntimeUI.sized(430), RuntimeUI.sized(620))
    local panel_h = clamp(math.floor((usable_h - v_gap) * 0.5), RuntimeUI.sized(300), RuntimeUI.sized(470))

    local total_w = panel_w * 2 + h_gap
    local total_h = panel_h * 2 + v_gap
    local start_x = math.floor((screen_w - total_w) * 0.5)
    local start_y = math.floor(top + math.max(0, (usable_h - total_h) * 0.42))

    return {
        { element = "DROPCAPS", title = "Dropcaps", x = start_x, y = start_y, w = panel_w, h = panel_h, screen_space = true },
        { element = "TEXT", title = "Text", x = start_x + panel_w + h_gap, y = start_y, w = panel_w, h = panel_h, screen_space = true },
        { element = "MINIATURE", title = "Miniature", x = start_x, y = start_y + panel_h + v_gap, w = panel_w, h = panel_h, screen_space = true },
        { element = "BORDERS", title = "Borders", x = start_x + panel_w + h_gap, y = start_y + panel_h + v_gap, w = panel_w, h = panel_h, screen_space = true },
    }
end

local function get_panels_bounds(panels)
    if not panels or #panels == 0 then
        return nil
    end
    local min_x = math.huge
    local min_y = math.huge
    local max_x = -math.huge
    local max_y = -math.huge
    for _, panel in ipairs(panels) do
        local x = panel.x
        local y = panel.y
        local w = panel.w
        local h = panel.h
        if x < min_x then min_x = x end
        if y < min_y then min_y = y end
        if x + w > max_x then max_x = x + w end
        if y + h > max_y then max_y = y + h end
    end
    if min_x == math.huge then
        return nil
    end
    return {
        x = min_x,
        y = min_y,
        w = max_x - min_x,
        h = max_y - min_y,
    }
end

function Scriptorium:drawDiegeticWorkspace(panels, high_contrast)
    if not PROTOTYPE_NO_BACKGROUND then
        return
    end
    local bounds = get_panels_bounds(panels)
    if not bounds then
        return
    end

    local frame_pad_x = RuntimeUI.sized(40)
    local frame_pad_y = RuntimeUI.sized(28)
    local outer = {
        x = bounds.x - frame_pad_x,
        y = bounds.y - frame_pad_y,
        w = bounds.w + frame_pad_x * 2,
        h = bounds.h + frame_pad_y * 2,
    }

    love.graphics.setColor(0.03, 0.02, 0.01, high_contrast and 0.42 or 0.30)
    love.graphics.rectangle(
        "fill",
        outer.x - RuntimeUI.sized(6),
        outer.y - RuntimeUI.sized(7),
        outer.w + RuntimeUI.sized(12),
        outer.h + RuntimeUI.sized(16),
        10, 10
    )

    love.graphics.setColor(0.27, 0.18, 0.10, high_contrast and 0.98 or 0.94)
    love.graphics.rectangle("fill", outer.x, outer.y, outer.w, outer.h, 8, 8)
    love.graphics.setColor(0.52, 0.37, 0.22, 0.64)
    love.graphics.rectangle("line", outer.x, outer.y, outer.w, outer.h, 8, 8)

    local inner_pad = RuntimeUI.sized(13)
    local inner = {
        x = outer.x + inner_pad,
        y = outer.y + inner_pad,
        w = outer.w - inner_pad * 2,
        h = outer.h - inner_pad * 2,
    }
    local left_page_w = math.floor(inner.w * 0.5)
    local right_page_w = inner.w - left_page_w

    love.graphics.setColor(0.86, 0.78, 0.64, high_contrast and 0.60 or 0.46)
    love.graphics.rectangle("fill", inner.x, inner.y, left_page_w, inner.h, 6, 6)
    love.graphics.setColor(0.82, 0.74, 0.60, high_contrast and 0.58 or 0.42)
    love.graphics.rectangle("fill", inner.x + left_page_w, inner.y, right_page_w, inner.h, 6, 6)

    local seam_x = inner.x + left_page_w
    love.graphics.setColor(0.30, 0.21, 0.14, 0.38)
    love.graphics.setLineWidth(2)
    love.graphics.line(seam_x, inner.y + RuntimeUI.sized(10), seam_x, inner.y + inner.h - RuntimeUI.sized(10))
    love.graphics.setLineWidth(1)

    local binder_w = RuntimeUI.sized(16)
    love.graphics.setColor(0.29, 0.18, 0.10, 0.78)
    love.graphics.rectangle("fill", seam_x - binder_w * 0.5, inner.y + RuntimeUI.sized(6), binder_w, inner.h - RuntimeUI.sized(12), 4, 4)

    local clip_w = RuntimeUI.sized(64)
    local clip_h = RuntimeUI.sized(14)
    love.graphics.setColor(0.63, 0.47, 0.30, 0.88)
    love.graphics.rectangle("fill", seam_x - clip_w * 0.5, outer.y - clip_h * 0.5, clip_w, clip_h, 4, 4)

    love.graphics.setColor(0.71, 0.55, 0.38, 0.78)
    love.graphics.rectangle("line", outer.x, outer.y, outer.w, outer.h, 8, 8)
    love.graphics.setColor(0.40, 0.30, 0.20, 0.55)
    love.graphics.rectangle("line", inner.x, inner.y, inner.w, inner.h, 6, 6)
end

local function draw_text_center(text, rect, font, color)
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.printf(text, rect.x + 1, rect.y + 1, rect.w, "center")
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.printf(text, rect.x, rect.y, rect.w, "center")
end

local function get_tile_color_for_constraint(constraint)
    if type(constraint) == "string" then
        return COLOR_SWATCH[constraint]
    end
    return nil
end

local function get_tile_key_for_constraint(constraint)
    if type(constraint) == "number" then
        local n = math.floor(constraint)
        if n >= 1 and n <= 6 then
            return tostring(n)
        end
    elseif type(constraint) == "string" then
        local mapped = COLOR_TO_VALUE[constraint]
        if mapped then
            return tostring(mapped)
        end
    end
    return nil
end

local function get_die_color_key(value)
    return VALUE_TO_COLOR[value] or "MARRONE"
end

local function get_completed_elements(folio)
    local completed = 0
    for _, element in ipairs(folio.ELEMENTS) do
        if folio.elements[element].completed then
            completed = completed + 1
        end
    end
    return completed
end

function Scriptorium:enter(fascicolo_type, seed)
    self.run = Folio.Run.new(fascicolo_type or "BIFOLIO", seed)
    self.dice_results = {}
    self.state = "waiting"
    self.message = nil
    self.message_timer = 0
    self.selected_cell = nil
    self.selected_die = nil

    if _G.log then
        _G.log("[Scriptorium] New run started: " .. tostring(self.run.fascicolo))
    end
end

function Scriptorium:exit()
    self.run = nil
    self.dice_results = {}
    self.state = "waiting"
    self.message = nil
    self.message_timer = 0
end

function Scriptorium:update(dt)
    if self.message_timer > 0 then
        self.message_timer = self.message_timer - dt
        if self.message_timer <= 0 then
            self.message_timer = 0
            self.message = nil

            if self.run and self.run.current_folio and (self.run.current_folio.busted or self.run.current_folio.completed) then
                local _, result = self.run:nextFolio()
                self.dice_results = {}
                self.state = "waiting"
                if result == "victory" then
                    self:showMessage("VICTORY!", nil, 5)
                elseif result == "game_over" then
                    self:showMessage("GAME OVER", nil, 5)
                end
            end
        end
    end
end

function Scriptorium:drawBackground(bg, high_contrast)
    if PROTOTYPE_NO_BACKGROUND then
        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()

        love.graphics.setColor(0.10, 0.07, 0.05, 1)
        love.graphics.rectangle("fill", 0, 0, w, h)

        love.graphics.setColor(0.20, 0.14, 0.09, high_contrast and 0.34 or 0.25)
        love.graphics.rectangle("fill", w * 0.04, h * 0.05, w * 0.92, h * 0.90)

        love.graphics.setColor(0.38, 0.27, 0.18, high_contrast and 0.18 or 0.12)
        love.graphics.rectangle("fill", w * 0.18, h * 0.08, w * 0.64, h * 0.84, 10, 10)

        love.graphics.setColor(0.04, 0.03, 0.02, 0.46)
        love.graphics.rectangle("fill", 0, 0, w, RuntimeUI.sized(96))
        love.graphics.rectangle("fill", 0, h - RuntimeUI.sized(120), w, RuntimeUI.sized(120))
        love.graphics.rectangle("fill", 0, 0, RuntimeUI.sized(58), h)
        love.graphics.rectangle("fill", w - RuntimeUI.sized(58), 0, RuntimeUI.sized(58), h)

        love.graphics.setColor(0.20, 0.14, 0.10, high_contrast and 0.10 or 0.18)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        return
    end

    if bg_img then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bg_img, bg.x, bg.y, 0, bg.scale, bg.scale)
    else
        love.graphics.setColor(0.10, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end

    love.graphics.setColor(0.11, 0.08, 0.05, high_contrast and 0.12 or 0.24)
    love.graphics.rectangle("fill", bg.x, bg.y, bg.w, bg.h)
end

function Scriptorium:drawStatusBar(bg, high_contrast, panels)
    if not self.run or not self.run.current_folio then
        return
    end

    local stats_rect
    if PROTOTYPE_NO_BACKGROUND then
        local screen_w = love.graphics.getWidth()
        local margin = RuntimeUI.sized(18)
        local stats_w = clamp(math.floor(screen_w * 0.34), RuntimeUI.sized(390), RuntimeUI.sized(520))
        local stats_h = RuntimeUI.sized(86)
        local x = math.floor((screen_w - stats_w) * 0.5)
        local y = margin
        local bounds = get_panels_bounds(panels)
        if bounds then
            x = math.floor(bounds.x + (bounds.w - stats_w) * 0.5)
            y = math.floor(bounds.y - stats_h - RuntimeUI.sized(18))
            x = clamp(x, margin, screen_w - stats_w - margin)
            y = math.max(margin, y)
        end
        stats_rect = {
            x = x,
            y = y,
            w = stats_w,
            h = stats_h,
        }
    else
        stats_rect = project_rect(bg, 606, 56, 320, 84)
    end
    love.graphics.setColor(0.40, 0.29, 0.20, 0.95)
    love.graphics.rectangle("fill", stats_rect.x, stats_rect.y, stats_rect.w, stats_rect.h, 8, 8)
    love.graphics.setColor(0.73, 0.58, 0.42, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", stats_rect.x, stats_rect.y, stats_rect.w, stats_rect.h, 8, 8)
    love.graphics.setLineWidth(1)

    local folio = self.run.current_folio
    local completed = get_completed_elements(folio)
    local values = {
        {"Folio", tostring(self.run.current_folio_index)},
        {"Reputation", tostring(self.run.reputation)},
        {"Stains", tostring(folio.stain_count)},
        {"Completed", tostring(completed)},
    }

    local col_w = stats_rect.w / #values
    local label_font = get_font(13, false)
    local value_font = get_font(25, true)

    for i, pair in ipairs(values) do
        local cx = stats_rect.x + (i - 1) * col_w
        local label_rect = {x = cx, y = stats_rect.y + RuntimeUI.sized(8), w = col_w, h = RuntimeUI.sized(16)}
        draw_text_center(pair[1], label_rect, label_font, {0.90, 0.80, 0.66, 1})

        local color = {0.94, 0.88, 0.74, 1}
        if i == 2 then color = {0.40, 0.95, 0.58, 1} end
        if i == 3 then color = {0.95, 0.40, 0.40, 1} end
        local value_rect = {x = cx, y = stats_rect.y + RuntimeUI.sized(30), w = col_w, h = RuntimeUI.sized(36)}
        draw_text_center(pair[2], value_rect, value_font, color)
    end
end

function Scriptorium:drawLegendPanel(bg, high_contrast)
    local panel = project_rect(bg, 18, 156, 148, 436)
    love.graphics.setColor(0.38, 0.26, 0.18, high_contrast and 0.95 or 0.90)
    love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 10, 10)
    love.graphics.setColor(0.76, 0.58, 0.40, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 10, 10)
    love.graphics.setLineWidth(1)

    local title_font = get_font(16, true)
    local body_font = get_font(RuntimeUI.big_text() and 13 or 12, false)
    draw_text_center("Constraints", {x = panel.x, y = panel.y + RuntimeUI.sized(10), w = panel.w, h = RuntimeUI.sized(20)}, title_font, {0.95, 0.82, 0.52, 1})

    local line_y = panel.y + RuntimeUI.sized(46)
    local line_step = RuntimeUI.sized(RuntimeUI.big_text() and 30 or 28)
    for i, text in ipairs(CONSTRAINT_LINES) do
        local bullet_color = (i == #CONSTRAINT_LINES) and {0.95, 0.82, 0.52, 1} or {0.96, 0.61, 0.24, 1}
        love.graphics.setColor(bullet_color[1], bullet_color[2], bullet_color[3], 1)
        love.graphics.circle("fill", panel.x + RuntimeUI.sized(12), line_y + RuntimeUI.sized(7), RuntimeUI.sized(3))
        love.graphics.setColor(0.96, 0.90, 0.82, 1)
        love.graphics.setFont(body_font)
        love.graphics.print(text, panel.x + RuntimeUI.sized(22), line_y)
        line_y = line_y + line_step
    end
end

function Scriptorium:drawTileCell(x, y, size, constraint, marker, placed, tile_key, high_contrast)
    love.graphics.setColor(0.32, 0.27, 0.19, 0.90)
    love.graphics.rectangle("fill", x, y, size, size, 2, 2)
    love.graphics.setColor(0.81, 0.42, 0.12, 0.95)
    love.graphics.rectangle("line", x, y, size, size, 2, 2)

    if not placed then
        local background_key = tile_key or get_tile_key_for_constraint(constraint)
        local tile = background_key and tile_images[background_key] or nil
        if tile then
            local tw, th = tile:getWidth(), tile:getHeight()
            if tw > 0 and th > 0 then
                local sx = (size - 2) / tw
                local sy = (size - 2) / th
                love.graphics.setColor(1, 1, 1, background_key == "w" and 0.98 or 0.92)
                love.graphics.draw(tile, x + 1, y + 1, 0, sx, sy)
            end
        end
    end

    if placed then
        local die_color = COLOR_SWATCH[placed.color] or {0.75, 0.75, 0.75}
        love.graphics.setColor(die_color[1], die_color[2], die_color[3], 0.82)
        love.graphics.rectangle("fill", x + 2, y + 2, size - 4, size - 4, 2, 2)
        love.graphics.setColor(0.97, 0.86, 0.56, 0.84)
        love.graphics.rectangle("line", x + 2, y + 2, size - 4, size - 4, 2, 2)

        love.graphics.setFont(get_font(math.max(11, math.floor(size * 0.42)), true))
        love.graphics.setColor(0.12, 0.08, 0.05, 1)
        love.graphics.printf(tostring(placed.value), x, y + (size * 0.24), size, "center")
    end

    if constraint and not placed then
        local badge_key = tile_key or get_tile_key_for_constraint(constraint)
        local badge = badge_key and tile_images[badge_key] or nil
        if badge then
            local badge_size = math.max(8, math.floor(size * 0.34))
            local bx = x + size - badge_size - 2
            local by = y + 2
            local bw, bh = badge:getWidth(), badge:getHeight()
            if bw > 0 and bh > 0 then
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.draw(badge, bx, by, 0, badge_size / bw, badge_size / bh)
            end
        else
            if type(constraint) == "number" then
                local r = math.max(5, math.floor(size * 0.16))
                love.graphics.setColor(0.49, 0.34, 0.22, 0.95)
                love.graphics.circle("fill", x + size - r - 2, y + r + 2, r)
                love.graphics.setColor(0.98, 0.90, 0.76, 1)
                love.graphics.setFont(get_font(math.max(8, math.floor(size * 0.28)), true))
                love.graphics.printf(tostring(constraint), x + size - r * 2 - 2, y + r - (r * 0.55), r * 2, "center")
            else
                local c = get_tile_color_for_constraint(constraint) or {0.82, 0.82, 0.82}
                local dot = math.max(4, math.floor(size * 0.16))
                love.graphics.setColor(c[1], c[2], c[3], 0.96)
                love.graphics.circle("fill", x + size - dot - 3, y + dot + 3, dot)
                love.graphics.setColor(0.08, 0.08, 0.08, 0.9)
                love.graphics.circle("line", x + size - dot - 3, y + dot + 3, dot)
            end
        end
    end

    if marker then
        local marker_key = tostring(marker)
        local marker_img = tile_images[marker_key]
        if marker_img then
            local marker_size = math.max(8, math.floor(size * 0.28))
            local mx = x + 2
            local my = y + 2
            local mw, mh = marker_img:getWidth(), marker_img:getHeight()
            if mw > 0 and mh > 0 then
                love.graphics.setColor(1, 1, 1, 0.92)
                love.graphics.draw(marker_img, mx, my, 0, marker_size / mw, marker_size / mh)
            end
        else
            local m = marker_key
            love.graphics.setColor(0.58, 0.34, 0.16, 0.92)
            love.graphics.circle("fill", x + RuntimeUI.sized(6), y + RuntimeUI.sized(6), RuntimeUI.sized(5))
            love.graphics.setColor(high_contrast and 0.98 or 0.94, high_contrast and 0.92 or 0.86, high_contrast and 0.70 or 0.62, 1)
            love.graphics.setFont(get_font(9, false))
            love.graphics.printf(m, x + RuntimeUI.sized(1), y + RuntimeUI.sized(1), RuntimeUI.sized(10), "center")
        end
    end
end

function Scriptorium:drawGridPanel(bg, def, high_contrast)
    if not self.run or not self.run.current_folio then
        return
    end

    local folio = self.run.current_folio
    local elem = folio.elements[def.element]
    if not elem then
        return
    end

    local panel
    if def.screen_space then
        panel = {x = def.x, y = def.y, w = def.w, h = def.h}
    else
        panel = project_rect(bg, def.x, def.y, def.w, def.h)
    end
    if not PROTOTYPE_NO_BACKGROUND then
        love.graphics.setColor(0.21, 0.24, 0.30, high_contrast and 0.96 or 0.90)
        love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 3, 3)
        love.graphics.setColor(0.46, 0.53, 0.62, 0.8)
        love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 3, 3)
    end

    local tab_w = math.min(panel.w * 0.28, RuntimeUI.sized(120))
    local tab_h = RuntimeUI.sized(24)
    love.graphics.setColor(0.38, 0.27, 0.17, 0.95)
    love.graphics.rectangle("fill", panel.x + RuntimeUI.sized(6), panel.y - RuntimeUI.sized(10), tab_w, tab_h, 4, 4)
    draw_text_center(def.title, {
        x = panel.x + RuntimeUI.sized(6),
        y = panel.y - RuntimeUI.sized(8),
        w = tab_w,
        h = tab_h,
    }, get_font(13, true), {0.95, 0.86, 0.68, 1})

    local rows = elem.pattern.rows or 4
    local cols = elem.pattern.cols or 5
    local gap = math.max(4, math.floor(panel.w * 0.010))
    local side_pad = math.floor(panel.w * 0.030)
    local top_pad = math.floor(panel.h * 0.10)
    local bottom_pad = math.floor(panel.h * 0.05)
    local usable_w = panel.w - side_pad * 2
    local usable_h = panel.h - top_pad - bottom_pad
    local cell = math.floor(math.min((usable_w - gap * (cols - 1)) / cols, (usable_h - gap * (rows - 1)) / rows))
    if cell < 8 then
        cell = 8
    end
    local grid_w = cell * cols + gap * (cols - 1)
    local grid_h = cell * rows + gap * (rows - 1)
    local gx = panel.x + (panel.w - grid_w) * 0.5
    local gy = panel.y + top_pad + (usable_h - grid_h) * 0.5

    if PROTOTYPE_NO_BACKGROUND then
        love.graphics.setColor(0.06, 0.04, 0.02, 0.18)
        love.graphics.rectangle("fill", gx - RuntimeUI.sized(8), gy - RuntimeUI.sized(8), grid_w + RuntimeUI.sized(16), grid_h + RuntimeUI.sized(16), 6, 6)
        love.graphics.setColor(0.62, 0.45, 0.24, 0.24)
        love.graphics.rectangle("line", gx - RuntimeUI.sized(8), gy - RuntimeUI.sized(8), grid_w + RuntimeUI.sized(16), grid_h + RuntimeUI.sized(16), 6, 6)
    end

    for row = 1, rows do
        for col = 1, cols do
            local index = (row - 1) * cols + col
            local cx = gx + (col - 1) * (cell + gap)
            local cy = gy + (row - 1) * (cell + gap)
            local constraint = elem.pattern.grid[index]
            local tile_key = elem.pattern.tile_keys and elem.pattern.tile_keys[index] or get_tile_key_for_constraint(constraint)
            local marker = elem.pattern.tile_markers and elem.pattern.tile_markers[index] or nil
            local placed = elem.placed[index]
            self:drawTileCell(cx, cy, cell, constraint, marker, placed, tile_key, high_contrast)
        end
    end

    if elem.completed then
        draw_text_center("Completed", {
            x = panel.x,
            y = panel.y + panel.h - RuntimeUI.sized(26),
            w = panel.w,
            h = RuntimeUI.sized(20),
        }, get_font(12, false), {0.48, 0.92, 0.62, 1})
    elseif not elem.unlocked then
        love.graphics.setColor(0.08, 0.08, 0.08, PROTOTYPE_NO_BACKGROUND and 0.34 or 0.48)
        if PROTOTYPE_NO_BACKGROUND then
            love.graphics.rectangle("fill", gx, gy, grid_w, grid_h, 3, 3)
        else
            love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 3, 3)
        end
        draw_text_center("LOCKED", {
            x = panel.x,
            y = panel.y + panel.h * 0.44,
            w = panel.w,
            h = RuntimeUI.sized(20),
        }, get_font(14, true), {0.92, 0.86, 0.74, 1})
    end
end

function Scriptorium:drawMessageOverlay()
    if not self.message then
        return
    end

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local box_w = math.min(RuntimeUI.sized(560), w * 0.82)
    local box_h = RuntimeUI.sized(170)
    local box_x = (w - box_w) * 0.5
    local box_y = (h - box_h) * 0.5

    love.graphics.setColor(0.20, 0.14, 0.10, 0.95)
    love.graphics.rectangle("fill", box_x, box_y, box_w, box_h, 10, 10)
    love.graphics.setColor(0.82, 0.65, 0.42, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", box_x, box_y, box_w, box_h, 10, 10)
    love.graphics.setLineWidth(1)

    draw_text_center(self.message.text or "", {
        x = box_x,
        y = box_y + RuntimeUI.sized(28),
        w = box_w,
        h = RuntimeUI.sized(52),
    }, get_font(36, true), {0.95, 0.84, 0.54, 1})

    if self.message.subtext then
        draw_text_center(self.message.subtext, {
            x = box_x + RuntimeUI.sized(20),
            y = box_y + RuntimeUI.sized(96),
            w = box_w - RuntimeUI.sized(40),
            h = RuntimeUI.sized(40),
        }, get_font(18, false), {0.95, 0.90, 0.82, 1})
    end
end

function Scriptorium:draw()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local high_contrast = RuntimeUI.high_contrast()
    ensure_bg()
    ensure_tiles()

    local panels = get_grid_panels_layout(w, h)
    local bg = get_bg_rect(w, h)
    self:drawBackground(bg, high_contrast)
    self:drawDiegeticWorkspace(panels, high_contrast)
    self:drawStatusBar(bg, high_contrast, panels)

    for _, panel in ipairs(panels) do
        self:drawGridPanel(bg, panel, high_contrast)
    end

    local instruction = self:getInstructions()
    if instruction and instruction ~= "" then
        draw_text_center(instruction, {
            x = 0,
            y = h - RuntimeUI.sized(32),
            w = w,
            h = RuntimeUI.sized(24),
        }, get_font(14, false), {0.92, 0.88, 0.78, 1})
    end

    self:drawMessageOverlay()
end

function Scriptorium:requestRoll()
    if self.state == "rolling" then
        return
    end

    self.state = "rolling"

    if self.onRollRequest then
        self.onRollRequest()
    else
        self.state = "waiting"
    end
end

function Scriptorium:autoPlaceDie(value)
    if not self.run or not self.run.current_folio then
        return false
    end

    local folio = self.run.current_folio
    local color_key = get_die_color_key(value)

    for _, element in ipairs(folio.ELEMENTS) do
        local valid = folio:getValidPlacements(element, value, color_key)
        if #valid > 0 then
            local cell = valid[1]
            local ok = folio:placeDie(element, cell.row, cell.col, value, color_key, DiceFaces.DiceFaces[value].fallback)
            if ok then
                return true
            end
        end
    end

    return false
end

function Scriptorium:onDiceSettled(values)
    if not self.run or not values or #values == 0 then
        self.state = "waiting"
        return
    end

    self.dice_results = {}
    local folio = self.run.current_folio

    for _, value in ipairs(values) do
        local color_key = get_die_color_key(value)
        local placed = self:autoPlaceDie(value)
        self.dice_results[#self.dice_results + 1] = {
            value = value,
            color_key = color_key,
            used = placed,
        }
        if not placed then
            folio:addStain(1)
        end
    end

    if folio.busted then
        self:showMessage("BUST!", "The folio is ruined. Reputation lost.")
    elseif folio.completed then
        self:showMessage("COMPLETED!", "Folio completed successfully.")
    end

    self.state = "placing"
end

function Scriptorium:showMessage(text, subtext, duration)
    self.message = {
        text = text,
        subtext = subtext,
    }
    self.message_timer = duration or 2.2
end

function Scriptorium:getInstructions()
    if self.message then
        return "Click or press any key to dismiss"
    end
    if self.state == "waiting" then
        return "[SPACE] Roll dice  |  [R] Restart  |  [ESC] Menu"
    end
    if self.state == "rolling" then
        return "Dice are rolling..."
    end
    if self.state == "placing" then
        return "[SPACE] Roll again  |  [ESC] Menu"
    end
    return "[SPACE] Continue"
end

function Scriptorium:keypressed(key)
    if self.message then
        self.message = nil
        self.message_timer = 0
        return
    end

    if key == "space" then
        AudioManager.play_ui("confirm")
        self:requestRoll()
    elseif key == "escape" then
        AudioManager.play_ui("back")
        if _G.set_module then
            _G.set_module("main_menu")
        end
    elseif key == "r" then
        AudioManager.play_ui("toggle")
        self:enter(self.run and self.run.fascicolo or "BIFOLIO")
    end
end

function Scriptorium:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    if self.message then
        self.message = nil
        self.message_timer = 0
        return
    end
end

function Scriptorium:mousemoved(x, y, dx, dy)
    -- Dice tray interaction is handled by the 3D runtime outside this scene.
end

function Scriptorium:wheelmoved(x, y)
    -- Managed by 3D camera system in main.lua.
end

return Scriptorium
