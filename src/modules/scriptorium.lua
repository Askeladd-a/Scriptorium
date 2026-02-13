-- src/modules/scriptorium.lua
-- Main gameplay module with tile-grid layout anchored to game.png.

local Folio = require("src.game.folio")
local RuntimeUI = require("src.core.runtime_ui")
local AudioManager = require("src.core.audio_manager")
local DiceFaces = require("src.core.dice_faces")
local ResolutionManager = require("src.core.resolution_manager")

local Scriptorium = {
    run = nil,
    dice_results = {},
    state = "waiting", -- waiting, rolling, placing, resolved
    message = nil,
    message_timer = 0,
    selected_cell = nil,
    selected_die = nil,
    ui_hit = {},
    lock_badges = {},
    mouse_x = 0,
    mouse_y = 0,
    hovered_lock = nil,
    view_mode = "overview", -- overview, zoom
    zoom_element = nil,
    show_run_setup = false,
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
    { element = "DROPCAPS", title = "Dropcaps/Corners", x = 462, y = 170, w = 316, h = 246 },
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

local function ui_dimensions()
    return ResolutionManager.get_virtual_size()
end

local function point_in_rect(x, y, rect)
    if not rect then
        return false
    end
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function point_in_ring(x, y, outer, inner)
    if not point_in_rect(x, y, outer) then
        return false
    end
    if inner and point_in_rect(x, y, inner) then
        return false
    end
    return true
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
    local bottom_reserved = RuntimeUI.sized(300)
    local h_gap = RuntimeUI.sized(24)
    local v_gap = RuntimeUI.sized(22)

    local usable_w = math.max(RuntimeUI.sized(760), screen_w - side * 2)
    local usable_h = math.max(RuntimeUI.sized(560), screen_h - top - bottom_reserved)

    local panel_w = clamp(math.floor((usable_w - h_gap) * 0.5), RuntimeUI.sized(410), RuntimeUI.sized(620))
    local panel_h = clamp(math.floor((usable_h - v_gap) * 0.5), RuntimeUI.sized(248), RuntimeUI.sized(430))

    local total_w = panel_w * 2 + h_gap
    local total_h = panel_h * 2 + v_gap
    local start_x = math.floor((screen_w - total_w) * 0.5)
    local start_y = math.floor(top + math.max(0, (usable_h - total_h) * 0.24))

    return {
        { element = "DROPCAPS", title = "Dropcaps/Corners", x = start_x, y = start_y, w = panel_w, h = panel_h, screen_space = true },
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

local function get_section_progress(elem)
    local committed = elem.cells_filled or 0
    local wet = 0
    if elem.wet then
        for _, placed in pairs(elem.wet) do
            if placed then
                wet = wet + 1
            end
        end
    end
    local total = elem.cells_total or 1
    local filled = committed + wet
    if filled > total then
        filled = total
    end
    return filled, total
end

local function find_panel_by_element(panels, element)
    if not panels then
        return nil
    end
    for _, panel in ipairs(panels) do
        if panel.element == element then
            return panel
        end
    end
    return nil
end

local function get_element_display_name(element)
    if element == "TEXT" then return "Text" end
    if element == "DROPCAPS" then return "Dropcaps/Corners" end
    if element == "BORDERS" then return "Borders" end
    if element == "MINIATURE" then return "Miniature" end
    return tostring(element)
end

local function get_unlock_tooltip(folio, element)
    local idx = nil
    for i, e in ipairs(folio.ELEMENTS) do
        if e == element then
            idx = i
            break
        end
    end
    if not idx or idx <= 1 then
        return "Locked section"
    end
    local prev = folio.ELEMENTS[idx - 1]
    return "Locked: complete " .. get_element_display_name(prev)
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

    -- Bottom bridge: visually links the manuscript board with the dice tray.
    local bridge_w = outer.w * 0.34
    local bridge_h = RuntimeUI.sized(30)
    local bridge_x = outer.x + (outer.w - bridge_w) * 0.5
    local bridge_y = outer.y + outer.h - RuntimeUI.sized(2)
    love.graphics.setColor(0.26, 0.17, 0.10, 0.94)
    love.graphics.rectangle("fill", bridge_x, bridge_y, bridge_w, bridge_h, 6, 6)
    love.graphics.setColor(0.62, 0.45, 0.28, 0.66)
    love.graphics.rectangle("line", bridge_x, bridge_y, bridge_w, bridge_h, 6, 6)

    local support_w = RuntimeUI.sized(24)
    local support_h = RuntimeUI.sized(68)
    local support_x = seam_x - support_w * 0.5
    local support_y = bridge_y + bridge_h - RuntimeUI.sized(1)
    love.graphics.setColor(0.22, 0.14, 0.08, 0.90)
    love.graphics.rectangle("fill", support_x, support_y, support_w, support_h, 4, 4)
    love.graphics.setColor(0.52, 0.36, 0.22, 0.58)
    love.graphics.rectangle("line", support_x, support_y, support_w, support_h, 4, 4)

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

local function get_remaining_dice_count(results)
    if not results then
        return 0
    end
    local count = 0
    for _, d in ipairs(results) do
        if d and not d.used then
            count = count + 1
        end
    end
    return count
end

local function get_unusable_dice_count(results)
    if not results then
        return 0
    end
    local count = 0
    for _, d in ipairs(results) do
        if d and d.unusable and not d.burned then
            count = count + 1
        end
    end
    return count
end

function Scriptorium:enter(fascicolo_type, seed)
    self.run = Folio.Run.new(fascicolo_type or "BIFOLIO", seed)
    self.dice_results = {}
    self.state = "waiting"
    self.message = nil
    self.message_timer = 0
    self.selected_cell = nil
    self.selected_die = nil
    self.ui_hit = {}
    self.lock_badges = {}
    self.hovered_lock = nil
    self.view_mode = "overview"
    self.zoom_element = nil
    self.show_run_setup = true

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
    self.ui_hit = {}
    self.lock_badges = {}
    self.hovered_lock = nil
    self.view_mode = "overview"
    self.zoom_element = nil
    self.show_run_setup = false
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
        local w, h = ui_dimensions()

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
        love.graphics.rectangle("fill", 0, 0, w, h)
        return
    end

    if bg_img then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bg_img, bg.x, bg.y, 0, bg.scale, bg.scale)
    else
        love.graphics.setColor(0.10, 0.08, 0.06, 1)
        local w, h = ui_dimensions()
        love.graphics.rectangle("fill", 0, 0, w, h)
    end

    love.graphics.setColor(0.11, 0.08, 0.05, high_contrast and 0.12 or 0.24)
    love.graphics.rectangle("fill", bg.x, bg.y, bg.w, bg.h)
end

function Scriptorium:drawStatusBar(bg, high_contrast, anchor_page)
    if not self.run or not self.run.current_folio then
        return
    end

    local stats_rect
    if PROTOTYPE_NO_BACKGROUND then
        local screen_w = select(1, ui_dimensions())
        local margin = RuntimeUI.sized(18)
        local base_w = anchor_page and anchor_page.w or (screen_w * 0.56)
        local stats_w = clamp(math.floor(base_w * 0.64), RuntimeUI.sized(520), RuntimeUI.sized(820))
        local stats_h = RuntimeUI.sized(62)
        local x
        local y
        if anchor_page then
            x = math.floor(anchor_page.x + (anchor_page.w - stats_w) * 0.5)
            y = math.max(margin, math.floor(anchor_page.y - stats_h - RuntimeUI.sized(14)))
        else
            x = math.floor((screen_w - stats_w) * 0.5)
            y = margin
        end
        stats_rect = {
            x = x,
            y = y,
            w = stats_w,
            h = stats_h,
        }
    else
        stats_rect = project_rect(bg, 30, 20, 470, 58)
    end
    love.graphics.setColor(0.33, 0.23, 0.15, high_contrast and 0.94 or 0.82)
    love.graphics.rectangle("fill", stats_rect.x, stats_rect.y, stats_rect.w, stats_rect.h, 7, 7)
    love.graphics.setColor(0.80, 0.64, 0.45, 0.66)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", stats_rect.x, stats_rect.y, stats_rect.w, stats_rect.h, 7, 7)
    love.graphics.setLineWidth(1)

    local folio = self.run.current_folio
    local values = {
        {"Folio", tostring(self.run.current_folio_index)},
        {"Reputation", tostring(self.run.reputation)},
        {"Stains", tostring(folio.stain_count)},
        {"Quality", tostring(folio.quality or 0)},
    }

    local col_w = stats_rect.w / #values
    local label_font = get_font(12, false)
    local value_font = get_font(21, true)

    for i, pair in ipairs(values) do
        local cx = stats_rect.x + (i - 1) * col_w
        if i > 1 then
            love.graphics.setColor(0.80, 0.64, 0.45, 0.28)
            love.graphics.line(cx, stats_rect.y + RuntimeUI.sized(7), cx, stats_rect.y + stats_rect.h - RuntimeUI.sized(7))
        end
        local label_rect = {x = cx, y = stats_rect.y + RuntimeUI.sized(4), w = col_w, h = RuntimeUI.sized(16)}
        draw_text_center(pair[1], label_rect, label_font, {0.95, 0.86, 0.72, 1})

        local color = {0.94, 0.88, 0.74, 1}
        if i == 2 then color = {0.40, 0.95, 0.58, 1} end
        if i == 3 then color = {0.95, 0.40, 0.40, 1} end
        if i == 4 then color = {0.95, 0.82, 0.50, 1} end
        local value_rect = {x = cx, y = stats_rect.y + RuntimeUI.sized(22), w = col_w, h = RuntimeUI.sized(30)}
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
    love.graphics.setColor(0.34, 0.29, 0.20, 0.80)
    love.graphics.rectangle("fill", x, y, size, size, 2, 2)
    love.graphics.setColor(0.62, 0.43, 0.23, 0.28)
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
        local fill_alpha = placed.wet and 0.58 or 0.82
        love.graphics.setColor(die_color[1], die_color[2], die_color[3], fill_alpha)
        love.graphics.rectangle("fill", x + 2, y + 2, size - 4, size - 4, 2, 2)
        love.graphics.setColor(0.97, 0.86, 0.56, placed.wet and 0.45 or 0.28)
        love.graphics.rectangle("line", x + 2, y + 2, size - 4, size - 4, 2, 2)

        love.graphics.setFont(get_font(math.max(11, math.floor(size * 0.42)), true))
        love.graphics.setColor(0.12, 0.08, 0.05, 1)
        love.graphics.printf(tostring(placed.value), x, y + (size * 0.24), size, "center")

        if placed.wet then
            love.graphics.setFont(get_font(math.max(7, math.floor(size * 0.17)), false))
            love.graphics.setColor(0.98, 0.95, 0.84, 0.9)
            love.graphics.printf("WET", x, y + size - RuntimeUI.sized(10), size, "center")
        end
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

local function resolve_panel_rect(bg, def)
    if def.screen_space then
        return {x = def.x, y = def.y, w = def.w, h = def.h}
    end
    return project_rect(bg, def.x, def.y, def.w, def.h)
end

function Scriptorium:getUnifiedPagePanel(screen_w, screen_h)
    local side = clamp(screen_w * 0.03, RuntimeUI.sized(24), RuntimeUI.sized(48))
    local top = RuntimeUI.sized(86)
    local tray = self:_getTrayRect()
    local dock_h = RuntimeUI.sized(108)
    local gap_page_dock = RuntimeUI.sized(10)
    local gap_dock_tray = RuntimeUI.sized(10)
    local bottom_limit = tray.y - dock_h - gap_page_dock - gap_dock_tray
    local page_h = clamp(bottom_limit - top, RuntimeUI.sized(500), RuntimeUI.sized(860))
    local page_w = clamp(screen_w - side * 2, RuntimeUI.sized(980), screen_w - RuntimeUI.sized(36))

    return {
        x = math.floor((screen_w - page_w) * 0.5),
        y = top,
        w = page_w,
        h = page_h,
    }
end

function Scriptorium:getUnifiedZones(page)
    local x = page.x
    local y = page.y
    local w = page.w
    local h = page.h

    local text = {
        element = "TEXT",
        title = "Text",
        rect = {
            x = x + w * 0.24,
            y = y + h * 0.14,
            w = w * 0.42,
            h = h * 0.60,
        }
    }
    local dropcaps = {
        element = "DROPCAPS",
        title = "Dropcaps/Corners",
        rect = {
            x = x + w * 0.08,
            y = y + h * 0.16,
            w = w * 0.18,
            h = h * 0.26,
        }
    }
    local miniature = {
        element = "MINIATURE",
        title = "Miniature",
        rect = {
            x = x + w * 0.70,
            y = y + h * 0.19,
            w = w * 0.22,
            h = h * 0.44,
        }
    }
    local borders = {
        element = "BORDERS",
        title = "Borders",
        rect = {
            x = x + w * 0.24,
            y = y + h * 0.76,
            w = w * 0.48,
            h = h * 0.17,
        }
    }
    return {
        text = text,
        dropcaps = dropcaps,
        miniature = miniature,
        borders = borders,
    }
end

function Scriptorium:drawZoneGrid(bg, zone, high_contrast)
    if not self.run or not self.run.current_folio then
        return
    end
    local folio = self.run.current_folio
    local elem = folio.elements[zone.element]
    if not elem then
        return
    end

    local rect = zone.rect
    local hover = point_in_rect(self.mouse_x, self.mouse_y, rect)

    love.graphics.setColor(0.20, 0.14, 0.09, hover and 0.24 or 0.16)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
    love.graphics.setColor(0.64, 0.47, 0.30, hover and 0.62 or 0.44)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 6, 6)

    local title_rect = {
        x = rect.x,
        y = rect.y - RuntimeUI.sized(22),
        w = rect.w,
        h = RuntimeUI.sized(18),
    }
    draw_text_center(zone.title, title_rect, get_font(15, true), {0.70, 0.51, 0.30, 1})

    local rows = elem.pattern.rows or 4
    local cols = elem.pattern.cols or 5
    local gap = math.max(3, math.floor(rect.w * 0.010))
    local side_pad = math.floor(rect.w * 0.04)
    local top_pad = math.floor(rect.h * 0.08)
    local bottom_pad = math.floor(rect.h * 0.18)
    local usable_w = rect.w - side_pad * 2
    local usable_h = rect.h - top_pad - bottom_pad
    local cell = math.floor(math.min((usable_w - gap * (cols - 1)) / cols, (usable_h - gap * (rows - 1)) / rows))
    if cell < RuntimeUI.sized(20) then
        cell = RuntimeUI.sized(20)
    end
    local grid_w = cell * cols + gap * (cols - 1)
    local grid_h = cell * rows + gap * (rows - 1)
    local gx = rect.x + (rect.w - grid_w) * 0.5
    local gy = rect.y + top_pad + math.max(0, (usable_h - grid_h) * 0.5)

    for row = 1, rows do
        for col = 1, cols do
            local index = (row - 1) * cols + col
            local cx = gx + (col - 1) * (cell + gap)
            local cy = gy + (row - 1) * (cell + gap)
            local constraint = elem.pattern.grid[index]
            local tile_key = elem.pattern.tile_keys and elem.pattern.tile_keys[index] or get_tile_key_for_constraint(constraint)
            local marker = elem.pattern.tile_markers and elem.pattern.tile_markers[index] or nil
            local placed = (elem.wet and elem.wet[index]) or elem.placed[index]
            self:drawTileCell(cx, cy, cell, constraint, marker, placed, tile_key, high_contrast)
        end
    end

    local filled, total = get_section_progress(elem)
    draw_text_center(string.format("%d/%d", filled, total), {
        x = rect.x,
        y = rect.y + rect.h - RuntimeUI.sized(24),
        w = rect.w,
        h = RuntimeUI.sized(18),
    }, get_font(13, false), {0.70, 0.51, 0.30, 1})

    if not elem.unlocked then
        love.graphics.setColor(0.08, 0.08, 0.08, 0.20)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
        local badge_size = RuntimeUI.sized(20)
        local bx = rect.x + rect.w - badge_size - RuntimeUI.sized(6)
        local by = rect.y + RuntimeUI.sized(6)
        love.graphics.setColor(0.28, 0.20, 0.12, 0.94)
        love.graphics.rectangle("fill", bx, by, badge_size, badge_size, 4, 4)
        love.graphics.setColor(0.75, 0.58, 0.36, 0.86)
        love.graphics.rectangle("line", bx, by, badge_size, badge_size, 4, 4)
        local cx = bx + badge_size * 0.5
        local cy = by + badge_size * 0.5
        local r = badge_size * 0.24
        love.graphics.setColor(0.93, 0.88, 0.76, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", cx, cy - RuntimeUI.sized(2), r, math.pi, math.pi * 2)
        love.graphics.rectangle("line", cx - r, cy - RuntimeUI.sized(1), r * 2, r * 1.25, 2, 2)
        love.graphics.setLineWidth(1)
        self.lock_badges[#self.lock_badges + 1] = {
            rect = {x = bx, y = by, w = badge_size, h = badge_size},
            text = get_unlock_tooltip(folio, zone.element),
        }
    end
end

function Scriptorium:drawUnifiedFolioOverview(page, high_contrast)
    if not self.run or not self.run.current_folio then
        return
    end
    local folio = self.run.current_folio
    local zones = self:getUnifiedZones(page)

    love.graphics.setColor(0.88, 0.80, 0.66, high_contrast and 0.66 or 0.54)
    love.graphics.rectangle("fill", page.x, page.y, page.w, page.h, 10, 10)
    love.graphics.setColor(0.62, 0.45, 0.28, 0.58)
    love.graphics.rectangle("line", page.x, page.y, page.w, page.h, 10, 10)

    local inner = {
        x = page.x + RuntimeUI.sized(16),
        y = page.y + RuntimeUI.sized(16),
        w = page.w - RuntimeUI.sized(32),
        h = page.h - RuntimeUI.sized(32),
    }
    local border_band = RuntimeUI.sized(20)
    local border_inner = {
        x = inner.x + border_band,
        y = inner.y + border_band,
        w = inner.w - border_band * 2,
        h = inner.h - border_band * 2,
    }

    local border_hover = point_in_ring(self.mouse_x, self.mouse_y, inner, border_inner)

    local borders_elem = folio.elements.BORDERS
    local bfilled, btotal = get_section_progress(borders_elem)
    love.graphics.setColor(0.58, 0.42, 0.26, border_hover and 0.68 or 0.50)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", inner.x, inner.y, inner.w, inner.h, 9, 9)
    love.graphics.setLineWidth(1)
    draw_text_center(string.format("Borders %d/%d", bfilled, btotal), {
        x = inner.x,
        y = inner.y + RuntimeUI.sized(4),
        w = inner.w,
        h = RuntimeUI.sized(18),
    }, get_font(12, false), {0.62, 0.44, 0.26, 1})

    if not borders_elem.unlocked then
        love.graphics.setColor(0.08, 0.08, 0.08, 0.14)
        love.graphics.rectangle("fill", inner.x, inner.y, inner.w, inner.h, 9, 9)
        local badge_size = RuntimeUI.sized(22)
        local bx = inner.x + inner.w - badge_size - RuntimeUI.sized(6)
        local by = inner.y + RuntimeUI.sized(6)
        love.graphics.setColor(0.28, 0.20, 0.12, 0.94)
        love.graphics.rectangle("fill", bx, by, badge_size, badge_size, 4, 4)
        love.graphics.setColor(0.75, 0.58, 0.36, 0.86)
        love.graphics.rectangle("line", bx, by, badge_size, badge_size, 4, 4)
        local cx = bx + badge_size * 0.5
        local cy = by + badge_size * 0.5
        local r = badge_size * 0.24
        love.graphics.setColor(0.93, 0.88, 0.76, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", cx, cy - RuntimeUI.sized(2), r, math.pi, math.pi * 2)
        love.graphics.rectangle("line", cx - r, cy - RuntimeUI.sized(1), r * 2, r * 1.25, 2, 2)
        love.graphics.setLineWidth(1)
        self.lock_badges[#self.lock_badges + 1] = {
            rect = {x = bx, y = by, w = badge_size, h = badge_size},
            text = get_unlock_tooltip(folio, "BORDERS"),
        }
    end

    self:drawZoneGrid(nil, zones.borders, high_contrast)
    self:drawZoneGrid(nil, zones.text, high_contrast)
    self:drawZoneGrid(nil, zones.dropcaps, high_contrast)
    self:drawZoneGrid(nil, zones.miniature, high_contrast)

    -- Four corner slots (taken from DROPCAPS logical grid) to reinforce page metaphor.
    local corners_elem = folio.elements.DROPCAPS
    if corners_elem then
        local slot = math.floor(math.min(page.w, page.h) * 0.075)
        local pad = RuntimeUI.sized(16)
        local corner_positions = {
            {x = inner.x + pad, y = inner.y + pad},
            {x = inner.x + inner.w - slot - pad, y = inner.y + pad},
            {x = inner.x + pad, y = inner.y + inner.h - slot - pad},
            {x = inner.x + inner.w - slot - pad, y = inner.y + inner.h - slot - pad},
        }
        local corner_indexes = {1, 2, 3, 4}
        for i, pos in ipairs(corner_positions) do
            local index = corner_indexes[i]
            local constraint = corners_elem.pattern.grid[index]
            local tile_key = corners_elem.pattern.tile_keys and corners_elem.pattern.tile_keys[index] or get_tile_key_for_constraint(constraint)
            local marker = corners_elem.pattern.tile_markers and corners_elem.pattern.tile_markers[index] or nil
            local placed = (corners_elem.wet and corners_elem.wet[index]) or corners_elem.placed[index]
            self:drawTileCell(pos.x, pos.y, slot, constraint, marker, placed, tile_key, high_contrast)
        end
    end
end

function Scriptorium:drawMarginNotes(page, high_contrast)
    if not self.run or not self.run.current_folio or not page then
        return
    end
    local folio = self.run.current_folio

    local note = {
        x = page.x + page.w - page.w * 0.22,
        y = page.y + page.h * 0.58,
        w = page.w * 0.18,
        h = page.h * 0.35,
    }
    love.graphics.setColor(0.92, 0.85, 0.72, high_contrast and 0.88 or 0.74)
    love.graphics.rectangle("fill", note.x, note.y, note.w, note.h, 7, 7)
    love.graphics.setColor(0.66, 0.49, 0.31, 0.62)
    love.graphics.rectangle("line", note.x, note.y, note.w, note.h, 7, 7)

    local y = note.y + RuntimeUI.sized(8)
    draw_text_center("Capitolato", {
        x = note.x,
        y = y,
        w = note.w,
        h = RuntimeUI.sized(20),
    }, get_font(16, true), {0.95, 0.86, 0.68, 1})

    y = y + RuntimeUI.sized(24)
    local status = self.run.getStatus and self.run:getStatus() or {}
    local cards = status.cards or {}
    local lines = {
        "Complete Text + Miniature",
        string.format("Stains room: %d", math.max(0, folio.stain_threshold - folio.stain_count)),
        string.format("Folio %d", self.run.current_folio_index or 1),
        "Bordi: " .. tostring((folio.border_parity == "EVEN") and "pari" or "dispari"),
        "Com: " .. tostring(cards.commission or "-"),
        "Perg: " .. tostring(cards.parchment or "-"),
        "Tool: " .. tostring(cards.tool or "-"),
    }
    local body_font = get_font(12, false)
    love.graphics.setFont(body_font)
    for _, line in ipairs(lines) do
        love.graphics.setColor(0.34, 0.25, 0.17, 1)
        love.graphics.print("• " .. line, note.x + RuntimeUI.sized(10), y)
        y = y + RuntimeUI.sized(18)
    end

    y = y + RuntimeUI.sized(6)
    love.graphics.setColor(0.64, 0.47, 0.30, 0.36)
    love.graphics.line(note.x + RuntimeUI.sized(10), y, note.x + note.w - RuntimeUI.sized(10), y)
    y = y + RuntimeUI.sized(8)

    local icons = {
        { label = "Shield", value = tostring(folio.shield or 0), color = {0.82, 0.68, 0.40, 1}},
        { label = "Risk", value = tostring(folio:getTurnRisk()), color = {0.85, 0.36, 0.32, 1}},
        { label = "Prep", value = tostring(folio.getPreparationGuard and folio:getPreparationGuard() or 0), color = {0.50, 0.74, 0.88, 1}},
        { label = "Tool", value = tostring(folio.getToolUsesLeft and folio:getToolUsesLeft() or 0), color = {0.64, 0.88, 0.62, 1}},
    }
    local icon_r = RuntimeUI.sized(10)
    local icon_gap = RuntimeUI.sized(54)
    local start_x = note.x + RuntimeUI.sized(18)
    for i, icon in ipairs(icons) do
        local ix = start_x + (i - 1) * icon_gap
        love.graphics.setColor(icon.color[1], icon.color[2], icon.color[3], 0.95)
        love.graphics.circle("fill", ix, y + icon_r, icon_r)
        love.graphics.setColor(0.23, 0.16, 0.10, 1)
        love.graphics.circle("line", ix, y + icon_r, icon_r)
        love.graphics.setColor(0.34, 0.25, 0.17, 1)
        love.graphics.setFont(get_font(10, false))
        love.graphics.print(icon.label .. ": " .. icon.value, ix + RuntimeUI.sized(14), y + RuntimeUI.sized(2))
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

    local panel = resolve_panel_rect(bg, def)
    -- One light section frame only (reduced visual weight).
    love.graphics.setColor(0.74, 0.55, 0.35, high_contrast and 0.46 or 0.30)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 4, 4)

    local title_font = get_font(13, true)
    local tab_w = clamp(
        title_font:getWidth(def.title) + RuntimeUI.sized(22),
        RuntimeUI.sized(110),
        panel.w * 0.56
    )
    local tab_h = RuntimeUI.sized(24)
    love.graphics.setColor(0.38, 0.27, 0.17, 0.95)
    love.graphics.rectangle("fill", panel.x + RuntimeUI.sized(6), panel.y - RuntimeUI.sized(10), tab_w, tab_h, 4, 4)
    draw_text_center(def.title, {
        x = panel.x + RuntimeUI.sized(6),
        y = panel.y - RuntimeUI.sized(8),
        w = tab_w,
        h = tab_h,
    }, title_font, {0.95, 0.86, 0.68, 1})

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

    for row = 1, rows do
        for col = 1, cols do
            local index = (row - 1) * cols + col
            local cx = gx + (col - 1) * (cell + gap)
            local cy = gy + (row - 1) * (cell + gap)
            local constraint = elem.pattern.grid[index]
            local tile_key = elem.pattern.tile_keys and elem.pattern.tile_keys[index] or get_tile_key_for_constraint(constraint)
            local marker = elem.pattern.tile_markers and elem.pattern.tile_markers[index] or nil
            local placed = (elem.wet and elem.wet[index]) or elem.placed[index]
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
        love.graphics.setColor(0.08, 0.08, 0.08, PROTOTYPE_NO_BACKGROUND and 0.14 or 0.32)
        if PROTOTYPE_NO_BACKGROUND then
            love.graphics.rectangle("fill", gx, gy, grid_w, grid_h, 3, 3)
        else
            love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 3, 3)
        end

        -- Small lock icon (top-right) + tooltip data
        local badge_size = RuntimeUI.sized(22)
        local bx = gx + grid_w - badge_size - RuntimeUI.sized(2)
        local by = gy + RuntimeUI.sized(2)
        love.graphics.setColor(0.28, 0.20, 0.12, 0.94)
        love.graphics.rectangle("fill", bx, by, badge_size, badge_size, 4, 4)
        love.graphics.setColor(0.75, 0.58, 0.36, 0.86)
        love.graphics.rectangle("line", bx, by, badge_size, badge_size, 4, 4)
        local cx = bx + badge_size * 0.5
        local cy = by + badge_size * 0.5
        local r = badge_size * 0.24
        love.graphics.setColor(0.93, 0.88, 0.76, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", cx, cy - RuntimeUI.sized(2), r, math.pi, math.pi * 2)
        love.graphics.rectangle("line", cx - r, cy - RuntimeUI.sized(1), r * 2, r * 1.25, 2, 2)
        love.graphics.setLineWidth(1)

        self.lock_badges[#self.lock_badges + 1] = {
            rect = {x = bx, y = by, w = badge_size, h = badge_size},
            text = get_unlock_tooltip(folio, def.element),
        }
    end
end

function Scriptorium:drawOverviewCard(bg, def, high_contrast)
    if not self.run or not self.run.current_folio then
        return
    end

    local folio = self.run.current_folio
    local elem = folio.elements[def.element]
    if not elem then
        return
    end

    local panel = resolve_panel_rect(bg, def)
    self.ui_hit.overview_cards[#self.ui_hit.overview_cards + 1] = {
        element = def.element,
        rect = panel,
    }

    local hover = point_in_rect(self.mouse_x, self.mouse_y, panel)
    love.graphics.setColor(0.16, 0.11, 0.07, hover and 0.34 or 0.26)
    love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 8, 8)
    love.graphics.setColor(0.74, 0.55, 0.35, hover and 0.62 or 0.40)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 8, 8)

    local title_font = get_font(14, true)
    local tab_w = clamp(
        title_font:getWidth(def.title) + RuntimeUI.sized(24),
        RuntimeUI.sized(120),
        panel.w * 0.62
    )
    local tab_h = RuntimeUI.sized(26)
    love.graphics.setColor(0.38, 0.27, 0.17, 0.95)
    love.graphics.rectangle("fill", panel.x + RuntimeUI.sized(8), panel.y - RuntimeUI.sized(12), tab_w, tab_h, 5, 5)
    draw_text_center(def.title, {
        x = panel.x + RuntimeUI.sized(8),
        y = panel.y - RuntimeUI.sized(10),
        w = tab_w,
        h = tab_h,
    }, title_font, {0.95, 0.86, 0.68, 1})

    local rows = elem.pattern.rows or 0
    local cols = elem.pattern.cols or 0
    draw_text_center(string.format("%dx%d grid", rows, cols), {
        x = panel.x,
        y = panel.y + RuntimeUI.sized(52),
        w = panel.w,
        h = RuntimeUI.sized(22),
    }, get_font(16, true), {0.93, 0.88, 0.78, 1})

    local filled, total = get_section_progress(elem)
    local ratio = total > 0 and (filled / total) or 0
    local bar_x = panel.x + RuntimeUI.sized(22)
    local bar_w = panel.w - RuntimeUI.sized(44)
    local bar_h = RuntimeUI.sized(14)
    local bar_y = panel.y + panel.h - RuntimeUI.sized(52)
    love.graphics.setColor(0.19, 0.14, 0.10, 0.84)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 5, 5)
    love.graphics.setColor(0.68, 0.52, 0.33, 0.92)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w * ratio, bar_h, 5, 5)
    love.graphics.setColor(0.82, 0.66, 0.46, 0.52)
    love.graphics.rectangle("line", bar_x, bar_y, bar_w, bar_h, 5, 5)
    draw_text_center(string.format("%d/%d", filled, total), {
        x = panel.x,
        y = bar_y - RuntimeUI.sized(20),
        w = panel.w,
        h = RuntimeUI.sized(16),
    }, get_font(14, false), {0.96, 0.90, 0.80, 1})

    local subtitle = elem.completed and "Completed" or "Click to zoom"
    local subtitle_color = elem.completed and {0.48, 0.92, 0.62, 1} or {0.94, 0.84, 0.62, 1}
    draw_text_center(subtitle, {
        x = panel.x,
        y = panel.y + panel.h - RuntimeUI.sized(30),
        w = panel.w,
        h = RuntimeUI.sized(18),
    }, get_font(12, false), subtitle_color)

    if not elem.unlocked then
        love.graphics.setColor(0.08, 0.08, 0.08, 0.28)
        love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 8, 8)

        local badge_size = RuntimeUI.sized(22)
        local bx = panel.x + panel.w - badge_size - RuntimeUI.sized(8)
        local by = panel.y + RuntimeUI.sized(8)
        love.graphics.setColor(0.28, 0.20, 0.12, 0.94)
        love.graphics.rectangle("fill", bx, by, badge_size, badge_size, 4, 4)
        love.graphics.setColor(0.75, 0.58, 0.36, 0.86)
        love.graphics.rectangle("line", bx, by, badge_size, badge_size, 4, 4)
        local cx = bx + badge_size * 0.5
        local cy = by + badge_size * 0.5
        local r = badge_size * 0.24
        love.graphics.setColor(0.93, 0.88, 0.76, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", cx, cy - RuntimeUI.sized(2), r, math.pi, math.pi * 2)
        love.graphics.rectangle("line", cx - r, cy - RuntimeUI.sized(1), r * 2, r * 1.25, 2, 2)
        love.graphics.setLineWidth(1)

        self.lock_badges[#self.lock_badges + 1] = {
            rect = {x = bx, y = by, w = badge_size, h = badge_size},
            text = get_unlock_tooltip(folio, def.element),
        }
    end
end

function Scriptorium:getZoomPanelLayout(screen_w, screen_h, panels)
    local base = find_panel_by_element(panels, self.zoom_element) or panels[1]
    if not base then
        return nil
    end

    local top = RuntimeUI.sized(112)
    local side = RuntimeUI.sized(128)
    local bottom_reserved = RuntimeUI.sized(300)
    local panel_w = clamp(screen_w - side * 2, RuntimeUI.sized(760), screen_w - RuntimeUI.sized(42))
    local panel_h = clamp(screen_h - top - bottom_reserved, RuntimeUI.sized(420), screen_h - top - RuntimeUI.sized(112))

    return {
        element = base.element,
        title = base.title,
        x = math.floor((screen_w - panel_w) * 0.5),
        y = top,
        w = panel_w,
        h = panel_h,
        screen_space = true,
    }
end

function Scriptorium:drawZoomHeader(zoom_panel, high_contrast)
    local back_rect = {
        x = zoom_panel.x,
        y = zoom_panel.y - RuntimeUI.sized(44),
        w = RuntimeUI.sized(220),
        h = RuntimeUI.sized(30),
    }
    self.ui_hit.zoom_back = back_rect
    local hover_back = point_in_rect(self.mouse_x, self.mouse_y, back_rect)
    love.graphics.setColor(0.30, 0.21, 0.13, hover_back and 0.94 or 0.84)
    love.graphics.rectangle("fill", back_rect.x, back_rect.y, back_rect.w, back_rect.h, 5, 5)
    love.graphics.setColor(0.72, 0.55, 0.35, 0.66)
    love.graphics.rectangle("line", back_rect.x, back_rect.y, back_rect.w, back_rect.h, 5, 5)
    draw_text_center("Back to overview", back_rect, get_font(14, true), {0.96, 0.90, 0.80, 1})

    local folio = self.run and self.run.current_folio
    local elem = folio and folio.elements[zoom_panel.element] or nil
    if elem then
        local filled, total = get_section_progress(elem)
        local info_rect = {
            x = zoom_panel.x + zoom_panel.w - RuntimeUI.sized(240),
            y = back_rect.y,
            w = RuntimeUI.sized(240),
            h = back_rect.h,
        }
        love.graphics.setColor(0.30, 0.21, 0.13, high_contrast and 0.92 or 0.82)
        love.graphics.rectangle("fill", info_rect.x, info_rect.y, info_rect.w, info_rect.h, 5, 5)
        love.graphics.setColor(0.72, 0.55, 0.35, 0.58)
        love.graphics.rectangle("line", info_rect.x, info_rect.y, info_rect.w, info_rect.h, 5, 5)
        draw_text_center(string.format("Progress: %d/%d", filled, total), info_rect, get_font(13, false), {0.95, 0.86, 0.70, 1})
    end
end

function Scriptorium:drawMessageOverlay()
    if not self.message then
        return
    end

    local w, h = ui_dimensions()
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

function Scriptorium:drawRunSetupOverlay()
    if not self.show_run_setup then
        self.ui_hit.setup_start = nil
        return
    end

    local w, h = ui_dimensions()
    local folio = self.run and self.run.current_folio or nil
    local cards = (folio and folio.getRuleCards and folio:getRuleCards()) or {}
    local parity = (folio and folio.border_parity) or "EVEN"
    local parity_text = (parity == "EVEN") and "pari" or "dispari"

    love.graphics.setColor(0, 0, 0, 0.70)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local box_w = math.min(RuntimeUI.sized(980), w * 0.88)
    local box_h = math.min(RuntimeUI.sized(560), h * 0.84)
    local box_x = (w - box_w) * 0.5
    local box_y = (h - box_h) * 0.5

    love.graphics.setColor(0.20, 0.14, 0.10, 0.96)
    love.graphics.rectangle("fill", box_x, box_y, box_w, box_h, 10, 10)
    love.graphics.setColor(0.82, 0.65, 0.42, 0.86)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", box_x, box_y, box_w, box_h, 10, 10)
    love.graphics.setLineWidth(1)

    draw_text_center("Preparazione della Run", {
        x = box_x,
        y = box_y + RuntimeUI.sized(18),
        w = box_w,
        h = RuntimeUI.sized(36),
    }, get_font(34, true), {0.96, 0.86, 0.60, 1})

    draw_text_center("Queste regole restano attive per tutti i folii della run.", {
        x = box_x + RuntimeUI.sized(20),
        y = box_y + RuntimeUI.sized(60),
        w = box_w - RuntimeUI.sized(40),
        h = RuntimeUI.sized(24),
    }, get_font(14, false), {0.93, 0.90, 0.84, 1})

    local cards_area_y = box_y + RuntimeUI.sized(96)
    local cards_area_h = box_h - RuntimeUI.sized(184)
    local gap = RuntimeUI.sized(12)
    local card_w = (box_w - RuntimeUI.sized(40) - gap * 2) / 3
    local card_h = cards_area_h
    local start_x = box_x + RuntimeUI.sized(20)

    local entries = {
        { title = "Commissione", card = cards.commission },
        { title = "Pergamena", card = cards.parchment },
        { title = "Strumento", card = cards.tool },
    }

    for i, entry in ipairs(entries) do
        local cx = start_x + (i - 1) * (card_w + gap)
        local cy = cards_area_y
        love.graphics.setColor(0.30, 0.21, 0.13, 0.90)
        love.graphics.rectangle("fill", cx, cy, card_w, card_h, 8, 8)
        love.graphics.setColor(0.72, 0.55, 0.35, 0.60)
        love.graphics.rectangle("line", cx, cy, card_w, card_h, 8, 8)

        draw_text_center(entry.title, {
            x = cx,
            y = cy + RuntimeUI.sized(8),
            w = card_w,
            h = RuntimeUI.sized(22),
        }, get_font(16, true), {0.95, 0.84, 0.58, 1})

        local card_name = (entry.card and entry.card.name) or "-"
        draw_text_center(card_name, {
            x = cx + RuntimeUI.sized(8),
            y = cy + RuntimeUI.sized(34),
            w = card_w - RuntimeUI.sized(16),
            h = RuntimeUI.sized(42),
        }, get_font(18, true), {0.96, 0.92, 0.84, 1})

        love.graphics.setColor(0.62, 0.46, 0.30, 0.42)
        love.graphics.line(cx + RuntimeUI.sized(10), cy + RuntimeUI.sized(82), cx + card_w - RuntimeUI.sized(10), cy + RuntimeUI.sized(82))

        local rule_text = (entry.card and entry.card.text) or "Nessuna regola."
        love.graphics.setFont(get_font(13, false))
        love.graphics.setColor(0.94, 0.90, 0.82, 1)
        love.graphics.printf(rule_text, cx + RuntimeUI.sized(10), cy + RuntimeUI.sized(92), card_w - RuntimeUI.sized(20), "left")
    end

    draw_text_center("Bordi per questa run: solo valori " .. parity_text, {
        x = box_x + RuntimeUI.sized(20),
        y = box_y + box_h - RuntimeUI.sized(84),
        w = box_w - RuntimeUI.sized(40),
        h = RuntimeUI.sized(22),
    }, get_font(14, false), {0.95, 0.86, 0.70, 1})

    local button_w = RuntimeUI.sized(260)
    local button_h = RuntimeUI.sized(42)
    local button_rect = {
        x = box_x + (box_w - button_w) * 0.5,
        y = box_y + box_h - RuntimeUI.sized(54),
        w = button_w,
        h = button_h,
    }
    self.ui_hit.setup_start = button_rect
    local hover = point_in_rect(self.mouse_x, self.mouse_y, button_rect)
    local alpha = hover and 0.96 or 0.88

    love.graphics.setColor(0.22, 0.45, 0.24, alpha)
    love.graphics.rectangle("fill", button_rect.x, button_rect.y, button_rect.w, button_rect.h, 6, 6)
    love.graphics.setColor(0.70, 0.88, 0.64, alpha)
    love.graphics.rectangle("line", button_rect.x, button_rect.y, button_rect.w, button_rect.h, 6, 6)
    draw_text_center("INIZIA RUN", {
        x = button_rect.x,
        y = button_rect.y + RuntimeUI.sized(10),
        w = button_rect.w,
        h = RuntimeUI.sized(22),
    }, get_font(18, true), {0.98, 0.94, 0.86, 1})
end

function Scriptorium:_getTrayRect()
    if type(_G.get_dice_tray_rect) == "function" then
        local ok, rect = pcall(_G.get_dice_tray_rect)
        if ok and rect and rect.w and rect.h then
            local x1, y1 = ResolutionManager.to_virtual(rect.x, rect.y)
            local x2, y2 = ResolutionManager.to_virtual(rect.x + rect.w, rect.y + rect.h)
            return {
                x = x1,
                y = y1,
                w = x2 - x1,
                h = y2 - y1,
            }
        end
    end
    local w, h = ui_dimensions()
    local tray_w = math.max(RuntimeUI.sized(680), w * 0.70)
    local tray_h = math.max(RuntimeUI.sized(250), h * 0.32)
    return {
        x = (w - tray_w) * 0.5,
        y = h - tray_h + RuntimeUI.sized(16),
        w = tray_w,
        h = tray_h,
    }
end

function Scriptorium:drawStopPushControls(high_contrast)
    local folio = self.run and self.run.current_folio
    if not folio then
        return
    end

    local page = self.page_rect
    local tray = self:_getTrayRect()

    local dock_h = RuntimeUI.sized(108)
    local dock_x
    local dock_w
    local dock_y
    if page then
        dock_x = page.x
        dock_w = page.w
        dock_y = page.y + page.h + RuntimeUI.sized(10)
    else
        dock_w = math.min(tray.w, RuntimeUI.sized(980))
        dock_x = tray.x + (tray.w - dock_w) * 0.5
        dock_y = tray.y - dock_h - RuntimeUI.sized(10)
    end
    local max_y = tray.y - dock_h - RuntimeUI.sized(8)
    if dock_y > max_y then
        dock_y = max_y
    end

    love.graphics.setColor(0.24, 0.16, 0.10, high_contrast and 0.96 or 0.90)
    love.graphics.rectangle("fill", dock_x, dock_y, dock_w, dock_h, 8, 8)
    love.graphics.setColor(0.70, 0.52, 0.33, 0.56)
    love.graphics.rectangle("line", dock_x, dock_y, dock_w, dock_h, 8, 8)

    local pad = RuntimeUI.sized(12)
    local gap = RuntimeUI.sized(10)
    local left_w = dock_w * 0.22
    local mid_w = dock_w * 0.30
    local right_w = dock_w - left_w - mid_w - gap * 2 - pad * 2
    local left = {x = dock_x + pad, y = dock_y + pad, w = left_w, h = dock_h - pad * 2}
    local mid = {x = left.x + left.w + gap, y = dock_y + pad, w = mid_w, h = dock_h - pad * 2}
    local right = {x = mid.x + mid.w + gap, y = dock_y + pad, w = right_w, h = dock_h - pad * 2}

    love.graphics.setColor(0.31, 0.22, 0.14, 0.88)
    love.graphics.rectangle("fill", left.x, left.y, left.w, left.h, 6, 6)
    love.graphics.rectangle("fill", mid.x, mid.y, mid.w, mid.h, 6, 6)
    love.graphics.setColor(0.70, 0.52, 0.33, 0.42)
    love.graphics.rectangle("line", left.x, left.y, left.w, left.h, 6, 6)
    love.graphics.rectangle("line", mid.x, mid.y, mid.w, mid.h, 6, 6)

    local remaining = get_remaining_dice_count(self.dice_results)
    draw_text_center("Dadi rimasti", {
        x = left.x,
        y = left.y + RuntimeUI.sized(6),
        w = left.w,
        h = RuntimeUI.sized(18),
    }, get_font(13, false), {0.95, 0.90, 0.82, 1})
    draw_text_center(tostring(remaining), {
        x = left.x,
        y = left.y + RuntimeUI.sized(30),
        w = left.w,
        h = RuntimeUI.sized(30),
    }, get_font(28, true), {0.95, 0.82, 0.50, 1})

    local wet_text = string.format("Wet buffer: %d", folio:getWetCount())
    local risk_text = string.format("Rischio macchia: %d", folio:getTurnRisk())
    local state_text = "Stato: " .. tostring(self.state or "waiting")
    draw_text_center(wet_text, {
        x = mid.x,
        y = mid.y + RuntimeUI.sized(8),
        w = mid.w,
        h = RuntimeUI.sized(20),
    }, get_font(14, true), {0.95, 0.90, 0.82, 1})
    draw_text_center(risk_text, {
        x = mid.x,
        y = mid.y + RuntimeUI.sized(34),
        w = mid.w,
        h = RuntimeUI.sized(18),
    }, get_font(14, true), {0.95, 0.68, 0.52, 1})
    draw_text_center(state_text, {
        x = mid.x,
        y = mid.y + RuntimeUI.sized(58),
        w = mid.w,
        h = RuntimeUI.sized(16),
    }, get_font(12, false), {0.88, 0.78, 0.64, 1})

    local menu_rect = {
        x = dock_x + dock_w - RuntimeUI.sized(122),
        y = dock_y + RuntimeUI.sized(7),
        w = RuntimeUI.sized(112),
        h = RuntimeUI.sized(24),
    }
    self.ui_hit.menu = menu_rect
    local menu_hover = point_in_rect(self.mouse_x, self.mouse_y, menu_rect)
    local menu_alpha = menu_hover and 0.94 or 0.82
    love.graphics.setColor(0.28, 0.19, 0.12, menu_alpha)
    love.graphics.rectangle("fill", menu_rect.x, menu_rect.y, menu_rect.w, menu_rect.h, 5, 5)
    love.graphics.setColor(0.78, 0.60, 0.38, menu_alpha)
    love.graphics.rectangle("line", menu_rect.x, menu_rect.y, menu_rect.w, menu_rect.h, 5, 5)
    draw_text_center("MENU", {
        x = menu_rect.x,
        y = menu_rect.y + RuntimeUI.sized(3),
        w = menu_rect.w,
        h = RuntimeUI.sized(16),
    }, get_font(13, true), {0.97, 0.92, 0.84, 1})

    local button_gap = RuntimeUI.sized(8)
    local placing_mode = (self.state == "placing")

    if placing_mode then
        local top_h = math.floor(right.h * 0.64)
        local prep_h = right.h - top_h - button_gap
        local third_w = (right.w - button_gap * 2) / 3
        local stop_rect = {x = right.x, y = right.y, w = third_w, h = top_h}
        local push_all_rect = {x = right.x + third_w + button_gap, y = right.y, w = third_w, h = top_h}
        local push_one_rect = {x = right.x + (third_w + button_gap) * 2, y = right.y, w = third_w, h = top_h}
        local prep_w = (right.w - button_gap) * 0.5
        local prep_risk_rect = {x = right.x, y = right.y + top_h + button_gap, w = prep_w, h = prep_h}
        local prep_guard_rect = {x = right.x + prep_w + button_gap, y = right.y + top_h + button_gap, w = prep_w, h = prep_h}

        local can_prepare = get_unusable_dice_count(self.dice_results) > 0 and folio.canUsePreparation and folio:canUsePreparation()

        self.ui_hit.stop = stop_rect
        self.ui_hit.push_all = push_all_rect
        self.ui_hit.push_one = push_one_rect
        self.ui_hit.push = push_all_rect
        self.ui_hit.prepare_risk = can_prepare and prep_risk_rect or nil
        self.ui_hit.prepare_guard = can_prepare and prep_guard_rect or nil
        self.ui_hit.restart = nil
        self.ui_hit.roll = nil

        local function draw_action(rect, title, subtitle, base_color, line_color, enabled)
            local hover = point_in_rect(self.mouse_x, self.mouse_y, rect)
            local alpha = enabled and (hover and 0.96 or 0.88) or 0.40
            love.graphics.setColor(base_color[1], base_color[2], base_color[3], alpha)
            love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
            love.graphics.setColor(line_color[1], line_color[2], line_color[3], alpha)
            love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 6, 6)
            draw_text_center(title, {
                x = rect.x,
                y = rect.y + RuntimeUI.sized(8),
                w = rect.w,
                h = RuntimeUI.sized(20),
            }, get_font(15, true), {0.98, 0.93, 0.84, enabled and 1 or 0.55})
            draw_text_center(subtitle, {
                x = rect.x,
                y = rect.y + RuntimeUI.sized(30),
                w = rect.w,
                h = RuntimeUI.sized(16),
            }, get_font(10, false), {0.98, 0.93, 0.84, enabled and 0.95 or 0.45})
        end

        draw_action(stop_rect, "STOP", "asciuga", {0.56, 0.23, 0.16}, {0.86, 0.62, 0.46}, true)
        draw_action(push_all_rect, "PUSH ALL", "rilancia tutti", {0.22, 0.45, 0.24}, {0.70, 0.88, 0.64}, true)
        draw_action(push_one_rect, "PUSH 1", "rilancia un dado", {0.20, 0.36, 0.46}, {0.62, 0.84, 0.92}, true)
        draw_action(prep_risk_rect, "PREP", "-1 rischio", {0.30, 0.25, 0.15}, {0.86, 0.72, 0.44}, can_prepare)
        draw_action(prep_guard_rect, "PREP", "+1 guardia", {0.18, 0.29, 0.38}, {0.56, 0.78, 0.94}, can_prepare)
    else
        local button_w = (right.w - button_gap) * 0.5
        local button_h = right.h
        local primary_rect = {x = right.x, y = right.y, w = button_w, h = button_h}
        local secondary_rect = {x = right.x + button_w + button_gap, y = right.y, w = button_w, h = button_h}
        local primary_hover = point_in_rect(self.mouse_x, self.mouse_y, primary_rect)
        local secondary_hover = point_in_rect(self.mouse_x, self.mouse_y, secondary_rect)

        local can_restart = (self.state ~= "rolling")
        local can_roll = (self.state == "waiting")
        self.ui_hit.stop = nil
        self.ui_hit.push = nil
        self.ui_hit.push_all = nil
        self.ui_hit.push_one = nil
        self.ui_hit.prepare_risk = nil
        self.ui_hit.prepare_guard = nil
        self.ui_hit.restart = can_restart and primary_rect or nil
        self.ui_hit.roll = can_roll and secondary_rect or nil

        local primary_alpha = can_restart and (primary_hover and 0.96 or 0.88) or 0.42
        local secondary_alpha = can_roll and (secondary_hover and 0.96 or 0.88) or 0.42

        love.graphics.setColor(0.36, 0.24, 0.14, primary_alpha)
        love.graphics.rectangle("fill", primary_rect.x, primary_rect.y, primary_rect.w, primary_rect.h, 6, 6)
        love.graphics.setColor(0.84, 0.66, 0.46, primary_alpha)
        love.graphics.rectangle("line", primary_rect.x, primary_rect.y, primary_rect.w, primary_rect.h, 6, 6)
        draw_text_center("NUOVO", {
            x = primary_rect.x,
            y = primary_rect.y + RuntimeUI.sized(10),
            w = primary_rect.w,
            h = RuntimeUI.sized(22),
        }, get_font(20, true), {0.98, 0.93, 0.84, can_restart and 1 or 0.55})
        draw_text_center("(reset folio)", {
            x = primary_rect.x,
            y = primary_rect.y + RuntimeUI.sized(38),
            w = primary_rect.w,
            h = RuntimeUI.sized(16),
        }, get_font(11, false), {0.98, 0.93, 0.84, can_restart and 0.95 or 0.45})

        love.graphics.setColor(0.22, 0.45, 0.24, secondary_alpha)
        love.graphics.rectangle("fill", secondary_rect.x, secondary_rect.y, secondary_rect.w, secondary_rect.h, 6, 6)
        love.graphics.setColor(0.70, 0.88, 0.64, secondary_alpha)
        love.graphics.rectangle("line", secondary_rect.x, secondary_rect.y, secondary_rect.w, secondary_rect.h, 6, 6)
        draw_text_center(can_roll and "ROLL" or "ROLLING", {
            x = secondary_rect.x,
            y = secondary_rect.y + RuntimeUI.sized(10),
            w = secondary_rect.w,
            h = RuntimeUI.sized(22),
        }, get_font(20, true), {0.98, 0.93, 0.84, can_roll and 1 or 0.55})
        draw_text_center(can_roll and "(lancia dadi)" or "(attendi)", {
            x = secondary_rect.x,
            y = secondary_rect.y + RuntimeUI.sized(38),
            w = secondary_rect.w,
            h = RuntimeUI.sized(16),
        }, get_font(11, false), {0.98, 0.93, 0.84, can_roll and 0.95 or 0.45})
    end
end

function Scriptorium:drawHoveredLockTooltip()
    if not self.hovered_lock then
        return
    end
    local text = self.hovered_lock.text
    if not text or text == "" then
        return
    end

    local font = get_font(13, false)
    love.graphics.setFont(font)
    local padding = RuntimeUI.sized(8)
    local tw = font:getWidth(text)
    local th = font:getHeight()
    local w, h = ui_dimensions()
    local x = clamp(self.mouse_x + RuntimeUI.sized(14), RuntimeUI.sized(8), w - tw - padding * 2 - RuntimeUI.sized(8))
    local y = clamp(self.mouse_y + RuntimeUI.sized(10), RuntimeUI.sized(8), h - th - padding * 2 - RuntimeUI.sized(8))

    love.graphics.setColor(0.14, 0.10, 0.07, 0.94)
    love.graphics.rectangle("fill", x, y, tw + padding * 2, th + padding * 2, 5, 5)
    love.graphics.setColor(0.78, 0.60, 0.40, 0.72)
    love.graphics.rectangle("line", x, y, tw + padding * 2, th + padding * 2, 5, 5)
    love.graphics.setColor(0.96, 0.90, 0.82, 1)
    love.graphics.print(text, x + padding, y + padding)
end

function Scriptorium:draw()
    local w, h = ui_dimensions()
    local high_contrast = RuntimeUI.high_contrast()
    ensure_bg()
    ensure_tiles()
    self.ui_hit = {}
    self.lock_badges = {}
    local mouse_sx, mouse_sy = love.mouse.getPosition()
    self.mouse_x, self.mouse_y = ResolutionManager.to_virtual(mouse_sx, mouse_sy)
    self.hovered_lock = nil

    local bg = get_bg_rect(w, h)
    local unified_page = self:getUnifiedPagePanel(w, h)
    local draw_panels = {
        {x = unified_page.x, y = unified_page.y, w = unified_page.w, h = unified_page.h, screen_space = true}
    }
    self.page_rect = unified_page

    ResolutionManager.begin_ui()
    self:drawBackground(bg, high_contrast)
    self:drawDiegeticWorkspace(draw_panels, high_contrast)
    self:drawStatusBar(bg, high_contrast, unified_page)
    self:drawUnifiedFolioOverview(unified_page, high_contrast)
    self:drawMarginNotes(unified_page, high_contrast)

    for _, badge in ipairs(self.lock_badges) do
        if point_in_rect(self.mouse_x, self.mouse_y, badge.rect) then
            self.hovered_lock = badge
            break
        end
    end

    self:drawStopPushControls(high_contrast)

    local instruction = self:getInstructions()
    if instruction and instruction ~= "" then
        local hint_rect = {
            x = 0,
            y = h - RuntimeUI.sized(38),
            w = w,
            h = RuntimeUI.sized(30),
        }
        love.graphics.setColor(0.08, 0.06, 0.04, 0.70)
        love.graphics.rectangle("fill", hint_rect.x, hint_rect.y, hint_rect.w, hint_rect.h)
        draw_text_center(instruction, {
            x = hint_rect.x,
            y = hint_rect.y + RuntimeUI.sized(6),
            w = hint_rect.w,
            h = RuntimeUI.sized(20),
        }, get_font(15, false), {0.94, 0.90, 0.82, 1})
    end

    self:drawHoveredLockTooltip()
    self:drawMessageOverlay()
    self:drawRunSetupOverlay()
    ResolutionManager.end_ui()
end

function Scriptorium:requestRoll(max_dice)
    if self.state == "rolling" then
        return
    end

    self.state = "rolling"

    if self.onRollRequest then
        self.onRollRequest(max_dice)
    else
        self.state = "waiting"
    end
end

function Scriptorium:performPushAll()
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return
    end
    self.run.current_folio:registerPush("all")
    AudioManager.play_ui("confirm")
    self:requestRoll(nil)
end

function Scriptorium:performPushOne()
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return
    end
    self.run.current_folio:registerPush("one")
    AudioManager.play_ui("confirm")
    self:requestRoll(1)
end

function Scriptorium:performStop()
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return
    end
    AudioManager.play_ui("confirm")
    local result = self.run.current_folio:commitWetBuffer()
    if self.run.current_folio.completed then
        self:showMessage("COMPLETED!", "Folio completed successfully.")
    elseif result and result.still_wet and result.still_wet > 0 then
        self:showMessage("Pergamena umida", tostring(result.still_wet) .. " dado resta wet", 2.0)
    elseif result and result.stains_added and result.stains_added > 0 then
        self:showMessage("Ink still wet", "+" .. tostring(result.stains_added) .. " stain(s) from risk", 2.0)
    end
    self.state = "waiting"
end

function Scriptorium:performRestart()
    AudioManager.play_ui("toggle")
    self:enter(self.run and self.run.fascicolo or "BIFOLIO")
end

function Scriptorium:_consumeUnusableDie()
    if not self.dice_results then
        return nil
    end
    for _, die in ipairs(self.dice_results) do
        if die and die.unusable and not die.burned then
            die.burned = true
            die.used = true
            return die
        end
    end
    return nil
end

function Scriptorium:performPreparation(mode)
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return
    end
    local folio = self.run.current_folio
    if not (folio.canUsePreparation and folio:canUsePreparation()) then
        return
    end
    if not self:_consumeUnusableDie() then
        return
    end
    local ok = folio:applyPreparation(mode)
    if ok then
        AudioManager.play_ui("move")
    end
end

function Scriptorium:autoPlaceDie(value)
    if not self.run or not self.run.current_folio then
        return false
    end

    local folio = self.run.current_folio
    local function try_place(v)
        local color_key = get_die_color_key(v)
        for _, element in ipairs(folio.ELEMENTS) do
            local valid = folio:getValidPlacements(element, v, color_key)
            if #valid > 0 then
                local cell = valid[1]
                local fallback = (DiceFaces.DiceFaces[v] and DiceFaces.DiceFaces[v].fallback) or "OCRA_GIALLA"
                local ok = folio:addWetDie(element, cell.row, cell.col, v, color_key, fallback)
                if ok then
                    return true
                end
            end
        end
        return false
    end

    if try_place(value) then
        return true
    end

    if value > 1 and folio.canUseTool and folio:canUseTool("coltellino") then
        local corrected = value - 1
        if try_place(corrected) then
            folio:consumeToolUse("coltellino")
            return true
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
    local dice_with_color = {}
    for _, value in ipairs(values) do
        dice_with_color[#dice_with_color + 1] = {
            value = value,
            color = get_die_color_key(value),
        }
    end

    -- Bust di turno: nessun dado legalmente piazzabile.
    if not folio:hasAnyLegalPlacement(dice_with_color) then
        local lost = folio:discardWetBuffer()
        folio:addStain(1)
        if self.run then
            self.run.reputation = math.max(0, (self.run.reputation or 0) - 1)
        end
        self:showMessage("BUST!", string.format("No legal placement. Wet lost: %d", lost), 2.4)
        self.state = "waiting"
        return
    end

    for _, value in ipairs(values) do
        local color_key = get_die_color_key(value)
        local placed = self:autoPlaceDie(value)
        self.dice_results[#self.dice_results + 1] = {
            value = value,
            color_key = color_key,
            used = placed,
            unusable = not placed,
        }
    end

    if folio.busted then
        self:showMessage("BUST!", "The folio is ruined. Reputation lost.")
    elseif folio.completed then
        self:showMessage("COMPLETED!", "Folio completed successfully.")
    elseif folio:getWetCount() > 0 then
        self.state = "placing"
        return
    end

    self.state = "waiting"
end

function Scriptorium:showMessage(text, subtext, duration)
    self.message = {
        text = text,
        subtext = subtext,
    }
    self.message_timer = duration or 2.2
end

function Scriptorium:getInstructions()
    if self.show_run_setup then
        return "Mouse: leggi le carte e clicca INIZIA RUN"
    end
    if self.message then
        return "Clicca per chiudere il messaggio"
    end
    if self.state == "waiting" then
        return "Mouse: clicca ROLL per lanciare i dadi"
    end
    if self.state == "rolling" then
        return "Dadi in movimento..."
    end
    if self.state == "placing" then
        local folio = self.run and self.run.current_folio
        if folio then
            return string.format("Mouse: STOP, PUSH ALL, PUSH 1, PREP | Wet:%d  Risk:%d",
                folio:getWetCount(), folio:getTurnRisk())
        end
        return "Mouse: STOP, PUSH ALL, PUSH 1, PREP"
    end
    return "Mouse-only mode"
end

function Scriptorium:keypressed(_key)
    -- Mouse-only module: keyboard input intentionally disabled.
end

function Scriptorium:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    local vx, vy = ResolutionManager.to_virtual(x, y)

    if self.message then
        self.message = nil
        self.message_timer = 0
        return
    end

    if self.show_run_setup then
        if point_in_rect(vx, vy, self.ui_hit.setup_start) then
            self.show_run_setup = false
            AudioManager.play_ui("confirm")
        end
        return
    end

    if point_in_rect(vx, vy, self.ui_hit.menu) then
        AudioManager.play_ui("back")
        if _G.set_module then
            _G.set_module("main_menu")
        end
        return
    end

    if self.state == "placing" then
        if point_in_rect(vx, vy, self.ui_hit.stop) then
            self:performStop()
            return
        end
        if point_in_rect(vx, vy, self.ui_hit.push_all) or point_in_rect(vx, vy, self.ui_hit.push) then
            self:performPushAll()
            return
        end
        if point_in_rect(vx, vy, self.ui_hit.push_one) then
            self:performPushOne()
            return
        end
        if point_in_rect(vx, vy, self.ui_hit.prepare_risk) then
            self:performPreparation("risk")
            return
        end
        if point_in_rect(vx, vy, self.ui_hit.prepare_guard) then
            self:performPreparation("guard")
            return
        end
    else
        if point_in_rect(vx, vy, self.ui_hit.restart) then
            self:performRestart()
            return
        end
        if point_in_rect(vx, vy, self.ui_hit.roll) then
            AudioManager.play_ui("confirm")
            self:requestRoll()
            return
        end
    end
end

function Scriptorium:mousemoved(x, y, dx, dy)
    local vx, vy = ResolutionManager.to_virtual(x, y)
    self.mouse_x = vx
    self.mouse_y = vy
    self.hovered_lock = nil
    if self.lock_badges then
        for _, badge in ipairs(self.lock_badges) do
            if point_in_rect(vx, vy, badge.rect) then
                self.hovered_lock = badge
                break
            end
        end
    end
end

function Scriptorium:wheelmoved(x, y)
    -- Managed by 3D camera system in main.lua.
end

return Scriptorium
