
local Run = require("src.gameplay.run.model").Run
local RuntimeUI = require("src.core.runtime_ui")
local ResolutionManager = require("src.core.resolution_manager")
local Helpers = require("src.features.scriptorium.helpers")
local ScriptoriumActions = require("src.features.scriptorium.actions")
local ScriptoriumLayout = require("src.features.scriptorium.layout")
local ScriptoriumHud = require("src.features.scriptorium.hud")
local ScriptoriumOverlays = require("src.features.scriptorium.overlays")

local Scriptorium = {
    run = nil,
    dice_results = {},
    turn_palette = nil,
    palette_picker = nil,
    state = "waiting",
    message = nil,
    message_timer = 0,
    selected_cell = nil,
    selected_die = nil,
    ui_hit = {},
    lock_badges = {},
    mouse_x = 0,
    mouse_y = 0,
    hovered_lock = nil,
    view_mode = "overview",
    zoom_element = nil,
    show_run_setup = false,
    value_to_color = nil,
    current_focus = nil,
}

local BG_PATH = "resources/ui/game.png"
local PROTOTYPE_NO_BACKGROUND = true
local TILE_DIR = "resources/tiles"
local UPPERCASE_FONT_CANDIDATES = {
    "resources/font/ManuskriptGothischUNZ1A.ttf",
    "resources/font/UnifrakturMaguntia-Regular.ttf",
}
local LOWERCASE_FONT_CANDIDATES = {
    "resources/font/EagleLake-Regular.ttf",
    "resources/font/UnifrakturMaguntia-Regular.ttf",
}

local REF_W = 1536
local REF_H = 1024

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
    VIOLA = {0.56, 0.34, 0.70},
    BIANCO = {0.93, 0.93, 0.93},
}

Scriptorium.value_to_color = VALUE_TO_COLOR

local clamp = Helpers.clamp
local point_in_rect = Helpers.point_in_rect
local point_in_ring = Helpers.point_in_ring
local project_rect = Helpers.project_rect
local get_panels_bounds = Helpers.get_panels_bounds
local get_section_progress = Helpers.get_section_progress
local find_panel_by_element = Helpers.find_panel_by_element
local get_unlock_tooltip = Helpers.get_unlock_tooltip
local draw_text_center = Helpers.draw_text_center
local get_remaining_dice_count = Helpers.get_remaining_dice_count
local get_unusable_dice_count = Helpers.get_unusable_dice_count

local layout_methods
local hud_methods
local overlay_methods

local bg_img = nil
local font_cache = {}
local tile_images = {}
local tiles_loaded = false

local function ui_dimensions()
    return ResolutionManager.get_virtual_size()
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
    local candidates = decorative and UPPERCASE_FONT_CANDIDATES or LOWERCASE_FONT_CANDIDATES
    for _, path in ipairs(candidates) do
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

    if not selected then
        local ok, font = pcall(function()
            return love.graphics.newFont(size)
        end)
        selected = (ok and font) or love.graphics.getFont()
    end

    font_cache[key] = selected
    return selected
end

layout_methods = ScriptoriumLayout.new({
    RuntimeUI = RuntimeUI,
    ResolutionManager = ResolutionManager,
    ui_dimensions = ui_dimensions,
    clamp = clamp,
})

hud_methods = ScriptoriumHud.new({
    RuntimeUI = RuntimeUI,
    PROTOTYPE_NO_BACKGROUND = PROTOTYPE_NO_BACKGROUND,
    project_rect = project_rect,
    clamp = clamp,
    point_in_rect = point_in_rect,
    draw_text_center = draw_text_center,
    get_font = get_font,
    get_remaining_dice_count = get_remaining_dice_count,
    get_unusable_dice_count = get_unusable_dice_count,
    ui_dimensions = ui_dimensions,
})

overlay_methods = ScriptoriumOverlays.new({
    RuntimeUI = RuntimeUI,
    ui_dimensions = ui_dimensions,
    get_font = get_font,
    draw_text_center = draw_text_center,
    point_in_rect = point_in_rect,
    clamp = clamp,
})

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

function Scriptorium:buildPlacementFocus()
    if self.state ~= "placing" or not self.run or not self.run.current_folio then
        return nil
    end
    local die = self.getSelectedDie and self:getSelectedDie() or nil
    if not die or die.used then
        return nil
    end

    local folio = self.run.current_folio
    local palette = (self.getTurnPalette and self:getTurnPalette()) or {}
    local focus = {
        active = true,
        die_index = self.selected_die,
        die_value = die.value,
        die_color = nil,
        palette = palette,
        legal_by_element = {},
        best_element = nil,
        best_entry = nil,
        total_legal = 0,
    }

    local best_element_count = -1
    local best_element_score = -math.huge
    for _, element in ipairs(folio.ELEMENTS) do
        local zone_info = {
            count = 0,
            by_key = {},
        }

        local element_best_score = -math.huge
        for _, color in ipairs(palette) do
            local placements = folio:getValidPlacements(element, die.value, color)
            for _, placement in ipairs(placements) do
                local preview = folio.getPlacementDecisionPreview
                        and folio:getPlacementDecisionPreview(element, placement.row, placement.col, die.value, color)
                    or {quality_gain = 0, risk_gain = 0, score = 0}
                local key = tostring(placement.row) .. ":" .. tostring(placement.col)
                local entry = zone_info.by_key[key]
                if not entry then
                    entry = {
                        element = element,
                        row = placement.row,
                        col = placement.col,
                        quality_gain = preview.quality_gain or 0,
                        risk_gain = preview.risk_gain or 0,
                        score = preview.score or 0,
                        palette_colors = {color},
                    }
                    zone_info.by_key[key] = entry
                    zone_info.count = zone_info.count + 1
                else
                    if not entry.palette_colors then
                        entry.palette_colors = {}
                    end
                    local has_color = false
                    for _, existing in ipairs(entry.palette_colors) do
                        if existing == color then
                            has_color = true
                            break
                        end
                    end
                    if not has_color then
                        entry.palette_colors[#entry.palette_colors + 1] = color
                    end
                    if (preview.score or 0) > (entry.score or -math.huge) then
                        entry.quality_gain = preview.quality_gain or 0
                        entry.risk_gain = preview.risk_gain or 0
                        entry.score = preview.score or 0
                    end
                end
                if (entry.score or -math.huge) > element_best_score then
                    element_best_score = entry.score or 0
                end
                if not focus.best_entry or (entry.score or -math.huge) > (focus.best_entry.score or -math.huge) then
                    focus.best_entry = entry
                end
            end
        end

        if zone_info.count > 0 then
            focus.total_legal = focus.total_legal + zone_info.count
            focus.legal_by_element[element] = zone_info
            if zone_info.count > best_element_count or (zone_info.count == best_element_count and element_best_score > best_element_score) then
                best_element_count = zone_info.count
                best_element_score = element_best_score
                focus.best_element = element
            end
        end
    end

    if focus.total_legal <= 0 then
        return nil
    end
    return focus
end

function Scriptorium:enter(folio_set_type, seed)
    self.run = Run.new(folio_set_type or "BIFOLIO", seed)
    self.value_to_color = VALUE_TO_COLOR
    self.dice_results = {}
    self.turn_palette = nil
    self.palette_picker = nil
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
    self.current_focus = nil

    if _G.log then
        _G.log("[Scriptorium] New run started: " .. tostring(self.run.folio_set))
    end
end

function Scriptorium:exit()
    self.run = nil
    self.dice_results = {}
    self.turn_palette = nil
    self.palette_picker = nil
    self.state = "waiting"
    self.message = nil
    self.message_timer = 0
    self.ui_hit = {}
    self.lock_badges = {}
    self.hovered_lock = nil
    self.view_mode = "overview"
    self.zoom_element = nil
    self.show_run_setup = false
    self.current_focus = nil
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
                self.turn_palette = nil
                self.palette_picker = nil
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

function Scriptorium:drawLegendPanel(bg, high_contrast)
    local panel = project_rect(bg, 18, 156, 148, 436)
    love.graphics.setColor(0.38, 0.26, 0.18, high_contrast and 0.95 or 0.90)
    love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 10, 10)
    love.graphics.setColor(0.76, 0.58, 0.40, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 10, 10)
    love.graphics.setLineWidth(1)

    local title_font = get_font(16, false)
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

function Scriptorium:drawTileCell(x, y, size, constraint, marker, placed, tile_key, high_contrast, visual)
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
            local dot = math.max(3, math.floor(size * 0.10))
            love.graphics.setColor(0.96, 0.90, 0.70, 0.92)
            love.graphics.circle("fill", x + size - dot - 3, y + size - dot - 3, dot)
            love.graphics.setColor(0.32, 0.22, 0.12, 0.82)
            love.graphics.circle("line", x + size - dot - 3, y + size - dot - 3, dot)
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

    if visual and visual.dim then
        love.graphics.setColor(0.07, 0.05, 0.04, 0.42)
        love.graphics.rectangle("fill", x + 1, y + 1, size - 2, size - 2, 2, 2)
    end

    if visual and visual.highlight then
        local pulse = (love.timer and love.timer.getTime and (0.5 + 0.5 * math.sin(love.timer.getTime() * 5.0))) or 0.5
        love.graphics.setColor(0.98, 0.84, 0.52, 0.60 + pulse * 0.24)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 1, y + 1, size - 2, size - 2, 3, 3)
        love.graphics.setLineWidth(1)
    end

    if visual and visual.preview and not placed then
        local quality = visual.preview.quality_gain or 0
        local risk = visual.preview.risk_gain or 0
        local txt = string.format("+Q%d / +R%d", quality, risk)
        love.graphics.setColor(0.10, 0.08, 0.06, 0.78)
        love.graphics.rectangle("fill", x + 2, y + size - RuntimeUI.sized(13), size - 4, RuntimeUI.sized(11), 2, 2)
        love.graphics.setFont(get_font(math.max(7, math.floor(size * 0.14)), false))
        love.graphics.setColor(0.96, 0.90, 0.78, 0.96)
        love.graphics.printf(txt, x + 2, y + size - RuntimeUI.sized(12), size - 4, "center")
    end

    if visual and visual.stained and not placed then
        love.graphics.setColor(0.14, 0.08, 0.06, 0.54)
        love.graphics.rectangle("fill", x + 1, y + 1, size - 2, size - 2, 2, 2)
        love.graphics.setColor(0.70, 0.28, 0.22, 0.86)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + RuntimeUI.sized(4), y + RuntimeUI.sized(4), x + size - RuntimeUI.sized(4), y + size - RuntimeUI.sized(4))
        love.graphics.line(x + size - RuntimeUI.sized(4), y + RuntimeUI.sized(4), x + RuntimeUI.sized(4), y + size - RuntimeUI.sized(4))
        love.graphics.setLineWidth(1)
    end
end

local function resolve_panel_rect(bg, def)
    if def.screen_space then
        return {x = def.x, y = def.y, w = def.w, h = def.h}
    end
    return project_rect(bg, def.x, def.y, def.w, def.h)
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
    local focus = self.current_focus
    local spotlight = focus and focus.active
    local zone_focus = spotlight and focus.legal_by_element and focus.legal_by_element[zone.element] or nil
    local zone_has_legal = zone_focus and zone_focus.count and zone_focus.count > 0
    local zone_is_best = spotlight and focus.best_element == zone.element
    local zone_dim = spotlight and (not zone_has_legal)

    local fill_alpha = hover and 0.24 or 0.16
    local line_alpha = hover and 0.62 or 0.44
    if zone_dim then
        fill_alpha = 0.08
        line_alpha = 0.24
    elseif zone_has_legal then
        fill_alpha = math.max(fill_alpha, 0.28)
        line_alpha = math.max(line_alpha, 0.58)
    end

    love.graphics.setColor(0.20, 0.14, 0.09, fill_alpha)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
    love.graphics.setColor(0.64, 0.47, 0.30, line_alpha)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 6, 6)
    if zone_is_best then
        love.graphics.setColor(0.96, 0.84, 0.54, 0.80)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rect.x - RuntimeUI.sized(2), rect.y - RuntimeUI.sized(2), rect.w + RuntimeUI.sized(4), rect.h + RuntimeUI.sized(4), 7, 7)
        love.graphics.setLineWidth(1)
    end

    local title_rect = {
        x = rect.x,
        y = rect.y - RuntimeUI.sized(24),
        w = rect.w,
        h = RuntimeUI.sized(18),
    }
    local title_color = zone_dim and {0.50, 0.38, 0.24, 0.70} or {0.70, 0.51, 0.30, 1}
    draw_text_center(zone.title, title_rect, get_font(15, false), title_color)

    local rows = elem.pattern.rows or 4
    local cols = elem.pattern.cols or 5
    local gap = math.max(3, math.floor(rect.w * 0.010))
    local side_pad = math.floor(rect.w * 0.04)
    local top_pad = math.floor(rect.h * 0.07)
    local bottom_ratio = (rows <= 2) and 0.10 or 0.14
    local bottom_pad = math.floor(rect.h * bottom_ratio)
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
    local selected_die = self.getSelectedDie and self:getSelectedDie() or nil

    for row = 1, rows do
        for col = 1, cols do
            local index = (row - 1) * cols + col
            local cx = gx + (col - 1) * (cell + gap)
            local cy = gy + (row - 1) * (cell + gap)
            local constraint = elem.pattern.grid[index]
            local tile_key = elem.pattern.tile_keys and elem.pattern.tile_keys[index] or get_tile_key_for_constraint(constraint)
            local marker = elem.pattern.tile_markers and elem.pattern.tile_markers[index] or nil
            local placed = (elem.wet and elem.wet[index]) or elem.placed[index]
            local stained = elem.stained and elem.stained[index] or false
            local key = tostring(row) .. ":" .. tostring(col)
            local preview = zone_focus and zone_focus.by_key and zone_focus.by_key[key] or nil
            local visual = nil
            if spotlight then
                if preview and elem.unlocked and (not elem.completed) then
                    visual = {highlight = true, preview = preview}
                    if selected_die and (not selected_die.used) then
                        local options = {}
                        if preview and preview.palette_colors then
                            for _, color in ipairs(preview.palette_colors) do
                                options[#options + 1] = color
                            end
                        end
                        self.ui_hit.placement_cells[#self.ui_hit.placement_cells + 1] = {
                            element = zone.element,
                            row = row,
                            col = col,
                            rect = {x = cx, y = cy, w = cell, h = cell},
                            palette_options = options,
                        }
                    end
                else
                    visual = {dim = true}
                end
            end
            if stained and not placed then
                visual = visual or {}
                visual.stained = true
            end
            self:drawTileCell(cx, cy, cell, constraint, marker, placed, tile_key, high_contrast, visual)
        end
    end

    local filled, total = get_section_progress(elem)
    draw_text_center(string.format("%d/%d", filled, total), {
        x = rect.x,
        y = rect.y + rect.h - RuntimeUI.sized(24),
        w = rect.w,
        h = RuntimeUI.sized(18),
    }, get_font(13, false), zone_dim and {0.50, 0.38, 0.24, 0.70} or {0.70, 0.51, 0.30, 1})

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
    local zone = (zones and zones.main) or (zones and zones.ordered and zones.ordered[1]) or nil
    if not zone then
        return
    end

    love.graphics.setColor(0.88, 0.80, 0.66, high_contrast and 0.66 or 0.54)
    love.graphics.rectangle("fill", page.x, page.y, page.w, page.h, 10, 10)
    love.graphics.setColor(0.62, 0.45, 0.28, 0.58)
    love.graphics.rectangle("line", page.x, page.y, page.w, page.h, 10, 10)

    local focus = self.current_focus
    if focus and focus.active then
        love.graphics.setColor(0.10, 0.08, 0.06, 0.18)
        love.graphics.rectangle("fill", page.x, page.y, page.w, page.h, 10, 10)
    end

    local pattern_name = (folio.getPatternName and folio:getPatternName()) or "Window"
    local token = (folio.getPatternToken and folio:getPatternToken()) or 0
    draw_text_center(string.format("%s  (token %d)", tostring(pattern_name), tonumber(token) or 0), {
        x = page.x,
        y = page.y + RuntimeUI.sized(8),
        w = page.w,
        h = RuntimeUI.sized(24),
    }, get_font(16, false), {0.66, 0.46, 0.26, 1})

    local filled, target = 0, 15
    if folio.getObjectiveProgress then
        filled, target = folio:getObjectiveProgress()
    end
    draw_text_center(string.format("Objective: fill %d/%d cells", tonumber(filled) or 0, tonumber(target) or 15), {
        x = page.x,
        y = page.y + page.h - RuntimeUI.sized(28),
        w = page.w,
        h = RuntimeUI.sized(20),
    }, get_font(13, false), {0.70, 0.51, 0.30, 1})

    self:drawZoneGrid(nil, zone, high_contrast)
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
    love.graphics.setColor(0.74, 0.55, 0.35, high_contrast and 0.46 or 0.30)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 4, 4)

    local title_font = get_font(13, false)
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

    local title_font = get_font(14, false)
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
    }, get_font(16, false), {0.93, 0.88, 0.78, 1})

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
    draw_text_center("Back to overview", back_rect, get_font(14, false), {0.96, 0.90, 0.80, 1})

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

function Scriptorium:draw()
    local w, h = ui_dimensions()
    local high_contrast = RuntimeUI.high_contrast()
    ensure_bg()
    ensure_tiles()
    self.ui_hit = {}
    self.ui_hit.placement_cells = {}
    self.lock_badges = {}
    local mouse_sx, mouse_sy = love.mouse.getPosition()
    self.mouse_x, self.mouse_y = ResolutionManager.to_virtual(mouse_sx, mouse_sy)
    self.hovered_lock = nil
    self.current_focus = self:buildPlacementFocus()

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

Scriptorium.getControlsDockHeight = layout_methods.getControlsDockHeight
Scriptorium._getTrayRect = layout_methods._getTrayRect
Scriptorium.getUnifiedPagePanel = layout_methods.getUnifiedPagePanel
Scriptorium.getUnifiedZones = layout_methods.getUnifiedZones

Scriptorium.drawStatusBar = hud_methods.drawStatusBar
Scriptorium.drawMarginNotes = hud_methods.drawMarginNotes
Scriptorium.drawStopPushControls = hud_methods.drawStopPushControls

Scriptorium.drawMessageOverlay = overlay_methods.drawMessageOverlay
Scriptorium.drawRunSetupOverlay = overlay_methods.drawRunSetupOverlay
Scriptorium.drawHoveredLockTooltip = overlay_methods.drawHoveredLockTooltip

Scriptorium.requestRoll = ScriptoriumActions.requestRoll
Scriptorium.performPushAll = ScriptoriumActions.performPushAll
Scriptorium.performPushOne = ScriptoriumActions.performPushOne
Scriptorium.performStop = ScriptoriumActions.performStop
Scriptorium.performRestart = ScriptoriumActions.performRestart
Scriptorium.clearTurnPalette = ScriptoriumActions.clearTurnPalette
Scriptorium.getTurnPalette = ScriptoriumActions.getTurnPalette
Scriptorium.ensureTurnPalette = ScriptoriumActions.ensureTurnPalette
Scriptorium.getLegalPaletteColorsForPlacement = ScriptoriumActions.getLegalPaletteColorsForPlacement
Scriptorium.getRerollIndices = ScriptoriumActions.getRerollIndices
Scriptorium.getSelectedDie = ScriptoriumActions.getSelectedDie
Scriptorium.setSelectedDie = ScriptoriumActions.setSelectedDie
Scriptorium.refreshDiceLegality = ScriptoriumActions.refreshDiceLegality
Scriptorium.autoSelectPlayableDie = ScriptoriumActions.autoSelectPlayableDie
Scriptorium._consumeUnusableDie = ScriptoriumActions.consumeUnusableDie
Scriptorium.performPreparation = ScriptoriumActions.performPreparation
Scriptorium.performSealReroll = ScriptoriumActions.performSealReroll
Scriptorium.performSealAdjust = ScriptoriumActions.performSealAdjust
Scriptorium.placeSelectedDieAt = ScriptoriumActions.placeSelectedDieAt
Scriptorium.autoPlaceDie = ScriptoriumActions.autoPlaceDie
Scriptorium.onDiceSettled = ScriptoriumActions.onDiceSettled
Scriptorium.showMessage = ScriptoriumActions.showMessage
Scriptorium.getInstructions = ScriptoriumActions.getInstructions
Scriptorium.keypressed = ScriptoriumActions.keypressed
Scriptorium.mousepressed = ScriptoriumActions.mousepressed
Scriptorium.mousemoved = ScriptoriumActions.mousemoved
Scriptorium.wheelmoved = ScriptoriumActions.wheelmoved

return Scriptorium
