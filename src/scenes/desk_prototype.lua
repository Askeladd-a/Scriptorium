-- src/scenes/desk_prototype.lua
-- Prototipo visuale: layout desk ispirato a Figma/React

local DeskPrototype = {}

-- Asset path (modifica se hai immagini reali)
local BG_PATH = "resources/ui/game.png"
local bg_img = nil

local FONT_PATH = "resources/font/EagleLake-Regular.ttf"
local font_title = nil
local font_label = nil

local hovered_cell = nil
local selected_cell = nil
local titles = {"Text", "Border", "Miniature", "Initial"}
local anim_time = 0

function DeskPrototype:draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    -- Layout params
    local page_margin_x, page_margin_y = 220, 60
    local page_gap = 60
    local page_w = (w - 2*page_margin_x - page_gap) / 2
    local page_h = h - 2*page_margin_y - 80
    local left_x = page_margin_x
    local right_x = page_margin_x + page_w + page_gap
    local page_y = page_margin_y + 40

    -- comfortable grid size (slightly reduced)
    local grid_w = page_w * 0.38
    local grid_h = ((page_h - page_gap) / 2) * 0.69
    local grid_gap_y = 60

    local cell_rows, cell_cols = 4, 5
    local cell_pad = 10
    local box_pad = 12

    -- Background: lazy-load image if present and draw scaled to cover
    if not bg_img then
        if love.filesystem.getInfo(BG_PATH) then
            local ok, img = pcall(love.graphics.newImage, BG_PATH)
            if ok and img then bg_img = img end
        end
    end
    if bg_img then
        love.graphics.setColor(1,1,1)
        local img_w, img_h = bg_img:getWidth(), bg_img:getHeight()
        -- Do NOT enlarge the image: draw at native size or scale down to fit screen
        local fitScale = math.min(w/img_w, h/img_h)
        local scale = math.min(1, fitScale)
        local draw_w, draw_h = img_w * scale, img_h * scale
        local dx, dy = (w - draw_w) / 2, (h - draw_h) / 2
        love.graphics.draw(bg_img, dx, dy, 0, scale, scale)
    end

    -- Draw two pages (left/right) with two grids each (i=0,1)
    for side=1,2 do
        local base_x = (side==1) and left_x or right_x
        for i=0,1 do
            local gx = base_x
            local gy = page_y + i*(grid_h+grid_gap_y)

            -- compute cell size and box
            local max_cell_w = (grid_w - cell_pad*(cell_cols+1)) / cell_cols
            local max_cell_h = (grid_h - cell_pad*(cell_rows+1)) / cell_rows
            local cell_size = math.floor(math.min(max_cell_w, max_cell_h))
            local grid_total_w = cell_cols*cell_size + (cell_cols+1)*cell_pad
            local grid_total_h = cell_rows*cell_size + (cell_rows+1)*cell_pad
            local box_w = grid_total_w + box_pad*2
            local box_h = grid_total_h + box_pad*2
            local box_x = gx + (page_w - box_w)/2
            local box_y = gy + (grid_h - box_h)/2

            -- Box background
            love.graphics.setColor(0.13,0.11,0.09,0.92)
            love.graphics.rectangle("fill", box_x, box_y, box_w, box_h, 10, 10)
            -- Title above box (lazy-load font_label)
            if not font_label then
                if love.filesystem.getInfo(FONT_PATH) then
                    local ok, f = pcall(love.graphics.newFont, FONT_PATH, 16)
                    if ok and f then font_label = f end
                end
            end
            local idx = (side-1)*2 + (i+1)
            if font_label then
                love.graphics.setFont(font_label)
            end
            love.graphics.setColor(0,0,0,0.7)
            love.graphics.printf(titles[idx], box_x+1, box_y-26, box_w, "center")
            love.graphics.setColor(1,0.97,0.7)
            love.graphics.printf(titles[idx], box_x, box_y-28, box_w, "center")

            -- Cells
            local offset_x = box_x + box_pad
            local offset_y = box_y + box_pad
            for r=0,cell_rows-1 do
                for c=0,cell_cols-1 do
                    local cx = offset_x + cell_pad + c*(cell_size+cell_pad)
                    local cy = offset_y + cell_pad + r*(cell_size+cell_pad)
                    local cell = {side=(side==1) and "left" or "right", grid=i+1, row=r+1, col=c+1}
                    local is_hovered = hovered_cell and hovered_cell.side==cell.side and hovered_cell.grid==cell.grid and hovered_cell.row==cell.row and hovered_cell.col==cell.col
                    local is_selected = selected_cell and selected_cell.side==cell.side and selected_cell.grid==cell.grid and selected_cell.row==cell.row and selected_cell.col==cell.col

                    -- Animated highlights: pulse on hover, stronger pulse on select
                    if is_selected then
                        local pulse = 0.45 + 0.12 * math.sin(anim_time*4)
                        love.graphics.setColor(0.25,0.45,1,pulse)
                        -- slightly larger glow
                        love.graphics.rectangle("fill", cx-4, cy-4, cell_size+8, cell_size+8, 8, 8)
                        love.graphics.setColor(0.15,0.25,0.6,0.35)
                        love.graphics.rectangle("fill", cx, cy, cell_size, cell_size, 6, 6)
                    elseif is_hovered then
                        local pulse = 0.22 + 0.10 * math.sin(anim_time*6)
                        love.graphics.setColor(0.95,0.95,0.4,pulse)
                        love.graphics.rectangle("fill", cx-3, cy-3, cell_size+6, cell_size+6, 7, 7)
                        love.graphics.setColor(0.18,0.15,0.12,0.92)
                        love.graphics.rectangle("fill", cx, cy, cell_size, cell_size, 6, 6)
                    else
                        love.graphics.setColor(0.18,0.15,0.12,0.92)
                        love.graphics.rectangle("fill", cx, cy, cell_size, cell_size, 6, 6)
                    end

                    love.graphics.setColor(1,0.85,0.5,0.8)
                    love.graphics.setLineWidth(is_selected and 4 or is_hovered and 3 or 2)
                    love.graphics.rectangle("line", cx, cy, cell_size, cell_size, 6, 6)
                end
            end
        end
    end

    -- Bottom tray/button
    love.graphics.setColor(0.18,0.13,0.08,0.92)
    love.graphics.rectangle("fill", w/2-160, h-100, 320, 56, 12, 12)
    love.graphics.setColor(0.2,1,0.2)
    if font_title then love.graphics.setFont(font_title) end
    love.graphics.printf("LANCIA DADI", w/2-120, h-86, 240, "center")
end

local function find_cell_at(x, y)
    -- compute same layout as draw to detect hover/click targets
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local page_margin_x, page_margin_y = 220, 60
    local page_gap = 60
    local page_w = (w - 2*page_margin_x - page_gap) / 2
    local page_h = h - 2*page_margin_y - 80
    local left_x = page_margin_x
    local right_x = page_margin_x + page_w + page_gap
    local page_y = page_margin_y + 40

    local grid_w = page_w * 0.38
    local grid_h = ((page_h - page_gap) / 2) * 0.69
    local grid_gap_y = 60

    local cell_rows, cell_cols = 4, 5
    local cell_pad = 10
    local box_pad = 12

    for side=1,2 do
        local base_x = (side==1) and left_x or right_x
        for i=0,1 do
            local gx = base_x
            local gy = page_y + i*(grid_h+grid_gap_y)
            local max_cell_w = (grid_w - cell_pad*(cell_cols+1)) / cell_cols
            local max_cell_h = (grid_h - cell_pad*(cell_rows+1)) / cell_rows
            local cell_size = math.floor(math.min(max_cell_w, max_cell_h))
            local grid_total_w = cell_cols*cell_size + (cell_cols+1)*cell_pad
            local grid_total_h = cell_rows*cell_size + (cell_rows+1)*cell_pad
            local box_w = grid_total_w + box_pad*2
            local box_h = grid_total_h + box_pad*2
            local box_x = gx + (page_w - box_w)/2
            local box_y = gy + (grid_h - box_h)/2
            local offset_x = box_x + box_pad
            local offset_y = box_y + box_pad

            for r=0,cell_rows-1 do
                for c=0,cell_cols-1 do
                    local cx = offset_x + cell_pad + c*(cell_size+cell_pad)
                    local cy = offset_y + cell_pad + r*(cell_size+cell_pad)
                    if x >= cx and x <= cx+cell_size and y >= cy and y <= cy+cell_size then
                        return {side=(side==1) and "left" or "right", grid=i+1, row=r+1, col=c+1}
                    end
                end
            end
        end
    end

    return nil
end

function DeskPrototype:mousemoved(x, y, dx, dy, istouch)
    hovered_cell = find_cell_at(x, y)
end

function DeskPrototype:mousepressed(x, y, button, istouch, presses)
    if button ~= 1 then return end

    local clicked_cell = find_cell_at(x, y)
    hovered_cell = clicked_cell

    if clicked_cell then
        if selected_cell and selected_cell.side == clicked_cell.side and selected_cell.grid == clicked_cell.grid
           and selected_cell.row == clicked_cell.row and selected_cell.col == clicked_cell.col then
            selected_cell = nil
        else
            selected_cell = {side=clicked_cell.side, grid=clicked_cell.grid, row=clicked_cell.row, col=clicked_cell.col}
        end
    end
end

function DeskPrototype:update(dt)
    anim_time = anim_time + (dt or 0)
end

return DeskPrototype
