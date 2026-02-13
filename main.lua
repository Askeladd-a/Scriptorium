
require("core")
require("src.engine3d.render")
require("src.engine3d.physics")
require("src.engine3d.geometry")
require("src.engine3d.view")
require("src.engine3d.light")

local Scriptorium = require("src.features.scriptorium.module")
local SettingsState = require("src.core.settings_state")
local AudioManager = require("src.core.audio_manager")
local RuntimeUI = require("src.core.runtime_ui")
local ResolutionManager = require("src.core.resolution_manager")

local main_menu_module = nil
local run_module = nil
local active_module = nil
local scriptorium = nil
local settings_module = nil

local set_module
local rollAllDice
local checkDiceSettled
local onDiceSettled
local readDiceValues
local readDieFace

config = {
    boardlight = light.metal
}
---@diagnostic disable-next-line: duplicate-set-field
function config.boardimage(x, y)
    return "resources/textures/wood.png"
end

dice = {}
local DICE_SIZE_BASE = 0.92
local DICE_SIZE_MIN = 0.74

local DICE_POOL = {
    { kind = "d6", count = 6, sides = 6, template = d6, body_factory = newD6Body },
    { kind = "d8", count = 3, sides = 8, template = d8, body_factory = newD8Body },
}

local function get_total_dice_count()
    local total = 0
    for _, spec in ipairs(DICE_POOL) do
        total = total + math.max(0, math.floor(spec.count or 0))
    end
    return total
end

local D6_BLACK_FACE_COLOR = {20, 20, 20, 255}
local D8_PROTO_COLOR = {250, 235, 20, 255}
local D8_PROTO_TEXT = {0, 0, 0}
local D8_FACE_COLORS = {
    {220, 45, 45, 255},   -- red
    {35, 95, 210, 255},   -- blue
    {45, 170, 70, 255},   -- green
    {235, 210, 40, 255},  -- yellow
    {20, 20, 20, 255},    -- black
    {120, 72, 36, 255},   -- brown
    {245, 245, 245, 255}, -- white
    {150, 70, 180, 255},  -- purple
}

local function build_face_colors(spec, face_count)
    if not spec then
        return nil
    end
    if spec.kind == "d8" then
        local colors = {}
        local n = #D8_FACE_COLORS
        for face_idx = 1, face_count do
            local src = D8_FACE_COLORS[((face_idx - 1) % n) + 1]
            colors[face_idx] = {src[1], src[2], src[3], src[4]}
        end
        return colors
    end
    if spec.kind ~= "d6" then
        return nil
    end
    local colors = {}
    for face_idx = 1, face_count do
        local src = D6_BLACK_FACE_COLOR
        colors[face_idx] = {src[1], src[2], src[3], src[4]}
    end
    return colors
end

local diceSettled = false
local diceSettledTimer = 0
local SETTLE_DELAY = 0.3
local last_roll_indices = nil

local fps_font = nil
local fps_font_size = 0
local last_frame_present = nil

local MAIN_TRAY_LAYOUT = {
    width_ratio = 0.60,
    height_ratio = 0.29,
    max_width = 1240,
    max_height = 400,
    min_width = 680,
    min_height = 230,
    overlay_scale_mult = 2.20,
    overlay_center_y = 0.50,
    floor_top_ratio = 0.20,
    floor_bottom_ratio = 0.90,
    floor_top_width_ratio = 0.68,
    floor_bottom_width_ratio = 0.93,
}

local MINI_TRAY_LAYOUT = {
    width_ratio = 0.22,
    height_ratio = 0.27,
    max_width = 520,
    max_height = 320,
    min_width = 300,
    min_height = 190,
    gap = 0,
    overlay_scale_mult = 2.18,
    overlay_center_y = 0.52,
    floor_top_ratio = 0.22,
    floor_bottom_ratio = 0.90,
    floor_top_width_ratio = 0.62,
    floor_bottom_width_ratio = 0.88,
}

local TRAY_LAYOUT_SHARED = {
    bottom_margin = 8,
}

local DICE_OVERLAY_SCALE_MULT = 2.20
local DICE_OVERLAY_CENTER_Y = 0.50
local DICE_OVERLAY_SHADOWS = false
local DICE_TRAY_FLAT_FLOOR = true
local DICE_TRAY_USE_3D_BORDER = true

local TRAY_CAMERA_LOCKED = true
local TRAY_CAMERA = {
    yaw = 0.00,
    pitch = 0.62,
    distance = 14.1,
}

local DICE_BOX_HALF_X = 7.2
local DICE_BOX_HALF_Y = 3.4

local DICE_REGIONS = {
    main = {
        x_center = -1.8,
        y_back = -3.05,
        y_front = 3.05,
        half_back = 3.9,
        half_front = 5.2,
        bounce = 0.34,
        slide_damping = 0.90,
    },
    mini = {
        x_center = 5.30,
        y_back = -2.35,
        y_front = 2.35,
        half_back = 1.15,
        half_front = 1.70,
        bounce = 0.30,
        slide_damping = 0.88,
    },
}

local DICE_GLOW_SHADER_PATH = "lib/dice_glow.glsl"
local DICE_GLOW_COLOR = {1.0, 0.93, 0.62}
local DICE_GLOW_INTENSITY = 0.58
local dice_glow_shader = nil

local function clamp(v, min_v, max_v)
    if v < min_v then return min_v end
    if v > max_v then return max_v end
    return v
end

local last_mouse_x = nil
local last_mouse_y = nil

local function get_mouse_delta()
    local delta_fn = (love and love.mouse) and rawget(love.mouse, "delta") or nil
    if type(delta_fn) == "function" then
        return delta_fn()
    end
    if not (love and love.mouse and love.mouse.getPosition) then
        return 0, 0
    end
    local mx, my = love.mouse.getPosition()
    if last_mouse_x == nil or last_mouse_y == nil then
        last_mouse_x, last_mouse_y = mx, my
        return 0, 0
    end
    local dx, dy = mx - last_mouse_x, my - last_mouse_y
    last_mouse_x, last_mouse_y = mx, my
    return dx, dy
end

local function apply_tray_camera_lock()
    view.yaw = TRAY_CAMERA.yaw
    view.pitch = TRAY_CAMERA.pitch
    view.distance = TRAY_CAMERA.distance
    view.cos_pitch, view.sin_pitch = math.cos(view.pitch), math.sin(view.pitch)
    view.cos_yaw, view.sin_yaw = math.cos(view.yaw), math.sin(view.yaw)
end

local function get_tray_rects(window_w, window_h)
    local mini_w = clamp(window_w * MINI_TRAY_LAYOUT.width_ratio, MINI_TRAY_LAYOUT.min_width, MINI_TRAY_LAYOUT.max_width)
    local mini_h = clamp(window_h * MINI_TRAY_LAYOUT.height_ratio, MINI_TRAY_LAYOUT.min_height, MINI_TRAY_LAYOUT.max_height)
    local gap = MINI_TRAY_LAYOUT.gap

    local main_w = clamp(window_w * MAIN_TRAY_LAYOUT.width_ratio, MAIN_TRAY_LAYOUT.min_width, MAIN_TRAY_LAYOUT.max_width)
    local max_main_w = window_w - mini_w - gap - 24
    if max_main_w < MAIN_TRAY_LAYOUT.min_width then
        max_main_w = MAIN_TRAY_LAYOUT.min_width
    end
    main_w = clamp(main_w, MAIN_TRAY_LAYOUT.min_width, max_main_w)
    local main_h = clamp(window_h * MAIN_TRAY_LAYOUT.height_ratio, MAIN_TRAY_LAYOUT.min_height, MAIN_TRAY_LAYOUT.max_height)

    local pair_h = math.max(main_h, mini_h)
    local base_y = window_h - pair_h - TRAY_LAYOUT_SHARED.bottom_margin
    local total_w = main_w + gap + mini_w
    local base_x = (window_w - total_w) * 0.5

    local main_tray = {
        x = base_x,
        y = base_y + (pair_h - main_h),
        w = main_w,
        h = main_h,
    }

    local mini_tray = {
        x = main_tray.x + main_tray.w + gap,
        y = base_y + (pair_h - mini_h),
        w = mini_w,
        h = mini_h,
    }

    return main_tray, mini_tray
end

_G.get_dice_tray_rect = function()
    local w, h = love.graphics.getDimensions()
    local main_tray = get_tray_rects(w, h)
    return main_tray
end

local function get_tray_floor_polygon(tray, tray_layout)
    tray_layout = tray_layout or MAIN_TRAY_LAYOUT
    local cx = tray.x + tray.w * 0.5
    local top_y = tray.y + tray.h * tray_layout.floor_top_ratio
    local bottom_y = tray.y + tray.h * tray_layout.floor_bottom_ratio
    local top_half = (tray.w * tray_layout.floor_top_width_ratio) * 0.5
    local bottom_half = (tray.w * tray_layout.floor_bottom_width_ratio) * 0.5
    return {
        cx - top_half, top_y,
        cx + top_half, top_y,
        cx + bottom_half, bottom_y,
        cx - bottom_half, bottom_y,
    }
end

local function region_half_width_at_y(region, y)
    local t = (y - region.y_back) / (region.y_front - region.y_back)
    t = clamp(t, 0, 1)
    return region.half_back + (region.half_front - region.half_back) * t
end

local function get_region_for_die(die_entry)
    if die_entry and die_entry.kind == "d8" then
        return DICE_REGIONS.mini
    end
    return DICE_REGIONS.main
end

local function get_world_extents_for_region(region)
    return {
        -region.half_front,
        region.half_front,
        region.y_back,
        region.y_front,
    }
end

local function constrain_dice_to_regions()
    if active_module ~= Scriptorium then
        return
    end
    if not dice or #dice == 0 then
        return
    end

    for i = 1, #dice do
        local die_entry = dice[i]
        local body = die_entry and die_entry.body or nil
        if body and body.position and body.velocity then
            local region = get_region_for_die(die_entry)
            local y_min = region.y_back
            local y_max = region.y_front
            local bounce = region.bounce
            local slide_damping = region.slide_damping
            local radius = math.max(0.15, (body.radius or 0.4) * 0.50)

            local px = body.position[1]
            local py = body.position[2]
            local vx = body.velocity[1]
            local vy = body.velocity[2]
            local corrected = false

            local min_y = y_min + radius
            local max_y = y_max - radius

            if py < min_y then
                py = min_y
                if vy < 0 then
                    vy = -vy * bounce
                end
                vx = vx * slide_damping
                corrected = true
            elseif py > max_y then
                py = max_y
                if vy > 0 then
                    vy = -vy * bounce
                end
                vx = vx * slide_damping
                corrected = true
            end

            local half_w = region_half_width_at_y(region, py) - radius
            if half_w < 0.2 then
                half_w = 0.2
            end

            local min_x = region.x_center - half_w
            local max_x = region.x_center + half_w

            if px > max_x then
                px = max_x
                if vx > 0 then
                    vx = -vx * bounce
                end
                vy = vy * slide_damping
                corrected = true
            elseif px < min_x then
                px = min_x
                if vx < 0 then
                    vx = -vx * bounce
                end
                vy = vy * slide_damping
                corrected = true
            end

            if corrected then
                body.position[1] = px
                body.position[2] = py
                body.velocity[1] = vx
                body.velocity[2] = vy
                body.asleep = false
                body.sleep_timer = 0
            end
        end
    end
end

local function get_usable_dice_map()
    local usable = {}
    if active_module ~= Scriptorium or not Scriptorium then
        return usable
    end
    if type(Scriptorium.dice_results) ~= "table" then
        return usable
    end
    for _, die_state in ipairs(Scriptorium.dice_results) do
        local idx = tonumber(die_state and die_state.index)
        if idx then
            idx = math.floor(idx)
            if idx >= 1 and idx <= #dice and (not die_state.used) and (not die_state.unusable) then
                usable[idx] = true
            end
        end
    end
    return usable
end

local function build_die_action_with_optional_glow(index, usable_map)
    if not usable_map or not usable_map[index] or not dice_glow_shader then
        return render.zbuffer
    end
    return function(z, draw_call)
        render.zbuffer(z, function()
            local now = (love.timer and love.timer.getTime and love.timer.getTime()) or 0
            pcall(function()
                dice_glow_shader:send("time", now)
                dice_glow_shader:send("intensity", DICE_GLOW_INTENSITY)
                dice_glow_shader:send("glowColor", DICE_GLOW_COLOR)
            end)
            love.graphics.setShader(dice_glow_shader)
            draw_call()
            love.graphics.setShader()
        end)
    end
end

local function draw_single_tray(tray, tray_layout, region, die_predicate, usable_map, glow_enabled)
    if not tray or not region then
        return
    end

    local tray_floor_poly = get_tray_floor_polygon(tray, tray_layout)
    local world_extents = get_world_extents_for_region(region)
    local draw_offset_x = region.x_center or 0

    local function with_draw_offset(body, fn)
        if (not body) or draw_offset_x == 0 then
            fn()
            return
        end
        local old_x = body.position and body.position[1] or 0
        body.position[1] = old_x - draw_offset_x
        fn()
        body.position[1] = old_x
    end

    love.graphics.setScissor(
        math.floor(tray.x),
        math.floor(tray.y),
        math.ceil(tray.w),
        math.ceil(tray.h)
    )
    if love.graphics.stencil and love.graphics.setStencilTest then
        if love.graphics.setColorMask then
            love.graphics.setColorMask(false, false, false, false)
        end
        love.graphics.stencil(function()
            love.graphics.polygon("fill", unpack(tray_floor_poly))
        end, "replace", 1)
        if love.graphics.setColorMask then
            love.graphics.setColorMask(true, true, true, true)
        end
        love.graphics.setStencilTest("greater", 0)
    end

    love.graphics.push()
    local cx = tray.x + tray.w * 0.5
    local cy = tray.y + tray.h * (tray_layout.overlay_center_y or DICE_OVERLAY_CENTER_Y)
    local scale_mult = tray_layout.overlay_scale_mult or DICE_OVERLAY_SCALE_MULT
    local scale = math.max(1, (math.min(tray.w * 0.5, tray.h * 0.5) / 4) * scale_mult)
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale)

    render.board_extents = world_extents

    local x1, x2, y1, y2 = world_extents[1], world_extents[2], world_extents[3], world_extents[4]
    if DICE_TRAY_FLAT_FLOOR then
        local c1 = {view.project(x1, y1, 0)}
        local c2 = {view.project(x2, y1, 0)}
        local c3 = {view.project(x2, y2, 0)}
        local c4 = {view.project(x1, y2, 0)}
        love.graphics.setColor(0.38, 0.32, 0.26, 1.0)
        love.graphics.polygon("fill", c1[1], c1[2], c2[1], c2[2], c3[1], c3[2])
        love.graphics.polygon("fill", c1[1], c1[2], c3[1], c3[2], c4[1], c4[2])
        love.graphics.setColor(0.16, 0.12, 0.09, 0.62)
        love.graphics.polygon("line",
            c1[1], c1[2],
            c2[1], c2[2],
            c3[1], c3[2],
            c4[1], c4[2]
        )
    else
        render.board(config.boardimage, config.boardlight, x1, x2, y1, y2)
    end

    if DICE_OVERLAY_SHADOWS then
        for i = 1, #dice do
            local die_entry = dice[i]
            if die_predicate(die_entry) then
                with_draw_offset(die_entry.body, function()
                    render.shadow(function(_, action)
                        action()
                    end, die_entry.die, die_entry.body)
                end)
            end
        end
    end

    render.clear()
    render.tray_border(render.zbuffer, 0.85, box.border_height or 1.1, {105, 68, 40})
    for i = 1, #dice do
        local die_entry = dice[i]
        if die_predicate(die_entry) then
            with_draw_offset(die_entry.body, function()
                local action = render.zbuffer
                if glow_enabled then
                    action = build_die_action_with_optional_glow(i, usable_map)
                end
                render.die(action, die_entry.die, die_entry.body)
            end)
        end
    end
    render.paint()
    love.graphics.pop()

    if love.graphics.setStencilTest then
        love.graphics.setStencilTest()
    end
    love.graphics.setScissor()
end

local function draw_dice_tray_overlay()
    if active_module ~= Scriptorium then
        return
    end
    if not dice or #dice == 0 then
        return
    end

    love.graphics.origin()
    love.graphics.setBlendMode("alpha")
    if love.graphics.setShader then
        love.graphics.setShader()
    end
    if love.graphics.setCanvas then
        love.graphics.setCanvas()
    end
    if love.graphics.setColorMask then
        love.graphics.setColorMask(true, true, true, true)
    end

    local w, h = love.graphics.getDimensions()
    local main_tray, mini_tray = get_tray_rects(w, h)
    local usable_map = get_usable_dice_map()

    draw_single_tray(
        main_tray,
        MAIN_TRAY_LAYOUT,
        DICE_REGIONS.main,
        function(die_entry) return die_entry and die_entry.kind ~= "d8" end,
        usable_map,
        true
    )

    draw_single_tray(
        mini_tray,
        MINI_TRAY_LAYOUT,
        DICE_REGIONS.mini,
        function(die_entry) return die_entry and die_entry.kind == "d8" end,
        nil,
        false
    )

    love.graphics.setScissor()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")
end

local function load_dice_glow_shader()
    if not (love and love.graphics and love.graphics.newShader and love.filesystem and love.filesystem.getInfo) then
        return
    end
    if not love.filesystem.getInfo(DICE_GLOW_SHADER_PATH) then
        return
    end
    local ok_src, shader_src = pcall(function()
        return love.filesystem.read(DICE_GLOW_SHADER_PATH)
    end)
    if not ok_src or type(shader_src) ~= "string" or shader_src == "" then
        return
    end
    local ok_shader, shader = pcall(function()
        return love.graphics.newShader(shader_src)
    end)
    if ok_shader and shader then
        dice_glow_shader = shader
    else
        dice_glow_shader = nil
    end
end

---@diagnostic disable: duplicate-set-field
function love.load()
    box:set(DICE_BOX_HALF_X, DICE_BOX_HALF_Y, 10, 25, 0.25, 0.75, 0.01)
    box.linear_damping = 0.12
    box.angular_damping = 0.12
    box.border_height = 0.74
    
    local total_dice = get_total_dice_count()
    local spawn_dice_size = DICE_SIZE_BASE
    if total_dice > 6 then
        local scale = math.sqrt(6 / total_dice)
        spawn_dice_size = math.max(DICE_SIZE_MIN, math.min(DICE_SIZE_BASE, DICE_SIZE_BASE * scale))
    end
    local die_index = 0
    local main_slot_index = 0
    local mini_slot_index = 0

    local function initial_position_for_slot(slot, slot_index)
        local region = (slot == "mini") and DICE_REGIONS.mini or DICE_REGIONS.main
        if slot == "mini" then
            local col = ((slot_index - 1) % 2) - 0.5
            local row = math.floor((slot_index - 1) / 2) - 0.5
            local sx = region.x_center + col * 0.85
            local sy = row * 0.95
            return sx, sy
        end
        local col = ((slot_index - 1) % 3) - 1
        local row = math.floor((slot_index - 1) / 3) - 0.5
        local sx = region.x_center + col * 1.35
        local sy = row * 1.20
        return sx, sy
    end

    for _, spec in ipairs(DICE_POOL) do
        local die_template = spec.template or d6
        local body_factory = spec.body_factory or newD6Body
        local faces = die_template.faces or {}
        local count = math.max(0, math.floor(spec.count or 0))

        for _ = 1, count do
            die_index = die_index + 1
            local tray_slot = (spec.kind == "d8") and "mini" or "main"
            if tray_slot == "mini" then
                mini_slot_index = mini_slot_index + 1
            else
                main_slot_index = main_slot_index + 1
            end
            local slot_idx = (tray_slot == "mini") and mini_slot_index or main_slot_index
            local sx, sy = initial_position_for_slot(tray_slot, slot_idx)

            local faceColors = build_face_colors(spec, #faces)
            local is_d8 = (spec.kind == "d8")
            local die_material = light.plastic
            local die_color = is_d8 and D8_PROTO_COLOR or {200, 180, 160, 255}
            local die_text = is_d8 and D8_PROTO_TEXT or {255, 255, 255}

            dice[die_index] = {
                body = body_factory(spawn_dice_size):set(
                    {sx, sy, 8},
                    {(die_index % 2 == 0) and 3 or -3, (die_index % 2 == 0) and -2 or 2, 0},
                    {1, 1, 2}
                ),
                die = clone(die_template, {
                    material = die_material,
                    faceColors = faceColors,
                    color = die_color,
                    text = die_text,
                    shadow = {20, 0, 0, 150}
                }),
                kind = spec.kind or "d6",
                sides = math.max(2, math.floor(spec.sides or 6)),
                tray_slot = tray_slot,
                kept = false,
                value = nil,
            }

            materials.apply(dice[die_index].body, materials.get("bone"))
            box[die_index] = dice[die_index].body
        end
    end
    
    local seed = os.time()
    math.randomseed(seed)
    if love.math then
        love.math.setRandomSeed(seed)
    end

    SettingsState.load()
    SettingsState.apply()
    ResolutionManager.init(1920, 1080)
    _G.get_ui_viewport = function()
        return ResolutionManager.get_viewport()
    end
    _G.to_virtual_ui = function(x, y)
        return ResolutionManager.to_virtual(x, y)
    end
    _G.to_screen_ui = function(x, y)
        return ResolutionManager.to_screen(x, y)
    end
    if love.graphics then
        local desired_fps_size = RuntimeUI.sized(14)
        local ok, font = pcall(function()
            return love.graphics.newFont(desired_fps_size)
        end)
        fps_font = ok and font or love.graphics.getFont()
        fps_font_size = desired_fps_size
    end
    if love.timer then
        last_frame_present = love.timer.getTime()
    end
    load_dice_glow_shader()

    apply_tray_camera_lock()
    
    main_menu_module = require("src.features.main_menu.module")
    run_module = require("src.gameplay.run.model").module
    scriptorium = Scriptorium
    settings_module = require("src.features.settings.module")
    local reward_module = require("src.features.reward.module")
    local startup_splash_module = require("src.features.startup_splash.module")
    local modules = {
        startup_splash = startup_splash_module,
        main_menu = main_menu_module,
        scriptorium = scriptorium,
        settings = settings_module,
        run = run_module,
        reward = reward_module,
    }
    function set_module(name, params)
        local next_module = modules[name]
        if next_module and next_module.enter then next_module:enter(params) end
        active_module = next_module
    end
    _G.set_module = set_module
    set_module("startup_splash")
    Scriptorium.onRollRequest = function(max_dice, roll_indices)
        rollAllDice(max_dice, roll_indices)
    end
end

function love.resize(w, h)
    ResolutionManager.refresh(w, h)
end

function love.update(dt)
    ResolutionManager.refresh()
    box:update(dt)
    constrain_dice_to_regions()
    checkDiceSettled(dt)
    if active_module and active_module.update then
        active_module:update(dt)
    end
    if TRAY_CAMERA_LOCKED then
        apply_tray_camera_lock()
    else
        local dx, dy = get_mouse_delta()
        if love.mouse.isDown(2) then
            view.raise(dy / 100)
            view.turn(dx / 100)
        end
    end
end

function love.draw()
    if active_module and active_module.draw then
        active_module:draw()
    end

    draw_dice_tray_overlay()

    if _G.show_fps then
        local desired_fps_size = RuntimeUI.sized(14)
        if love.graphics and desired_fps_size ~= fps_font_size then
            local ok, f = pcall(function()
                return love.graphics.newFont(desired_fps_size)
            end)
            fps_font = ok and f or love.graphics.getFont()
            fps_font_size = desired_fps_size
        end
        local high_contrast = RuntimeUI.high_contrast()
        local prev_font = love.graphics.getFont()
        if fps_font then
            love.graphics.setFont(fps_font)
        end
        love.graphics.setColor(0, 0, 0, high_contrast and 0.75 or 0.55)
        love.graphics.rectangle("fill", 8, 8, 92, 24, 4, 4)
        love.graphics.setColor(high_contrast and 1.0 or 0.95, high_contrast and 0.97 or 0.92, high_contrast and 0.90 or 0.82, 1)
        love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 14, 12)
        if prev_font then
            love.graphics.setFont(prev_font)
        end
    end

    local target_fps = tonumber(_G.target_fps)
    if target_fps and target_fps > 0 and love.timer then
        local target_dt = 1 / target_fps
        local now = love.timer.getTime()
        if last_frame_present then
            local elapsed = now - last_frame_present
            if elapsed < target_dt then
                love.timer.sleep(target_dt - elapsed)
                now = love.timer.getTime()
            end
        end
        last_frame_present = now
    end
end

function love.keypressed(_key, _scancode, _isrepeat)
end

function love.mousepressed(x, y, button)
    if active_module and active_module.mousepressed then
        active_module:mousepressed(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if active_module and active_module.mousemoved then
        active_module:mousemoved(x, y, dx, dy, istouch)
    end
end
---@diagnostic enable: duplicate-set-field

local function pick_spawn_for_region(region, rnd)
    local inset_y = 0.26
    local min_y = region.y_back + inset_y
    local max_y = region.y_front - inset_y
    local side = math.floor(rnd() * 4) + 1
    local sx, sy

    if side == 1 or side == 2 then
        sy = min_y + rnd() * (max_y - min_y)
        local half_w = math.max(0.35, region_half_width_at_y(region, sy) - 0.22)
        if side == 1 then
            sx = region.x_center - half_w
        else
            sx = region.x_center + half_w
        end
    elseif side == 3 then
        sy = min_y
        local half_w = math.max(0.35, region_half_width_at_y(region, sy) - 0.26)
        sx = region.x_center + (rnd() * 2 - 1) * half_w
    else
        sy = max_y
        local half_w = math.max(0.35, region_half_width_at_y(region, sy) - 0.26)
        sx = region.x_center + (rnd() * 2 - 1) * half_w
    end

    return sx, sy
end

function rollAllDice(max_dice, roll_indices)
    local rnd = (love and love.math and love.math.random) or math.random
    
    local to_roll = {}
    if type(roll_indices) == "table" and #roll_indices > 0 then
        local seen = {}
        for _, idx in ipairs(roll_indices) do
            local i = tonumber(idx)
            if i then
                i = math.floor(i)
                if i >= 1 and i <= #dice and not seen[i] then
                    to_roll[#to_roll + 1] = i
                    seen[i] = true
                end
            end
        end
    else
        for i = 1, #dice do
            if not dice[i].kept then
                table.insert(to_roll, i)
            end
        end
    end
    
    if #to_roll == 0 then
        log("[Dice] No dice available to roll.")
        return
    end

    if max_dice and max_dice > 0 and #to_roll > max_dice then
        local target = math.max(1, math.floor(max_dice))
        local selected = {}
        while #selected < target and #to_roll > 0 do
            local at = math.floor(rnd() * #to_roll) + 1
            selected[#selected + 1] = to_roll[at]
            table.remove(to_roll, at)
        end
        to_roll = selected
    end

    table.sort(to_roll)
    last_roll_indices = {}
    for i = 1, #to_roll do
        last_roll_indices[i] = to_roll[i]
    end
    
    diceSettled = false
    diceSettledTimer = 0
    
    if Scriptorium then
        Scriptorium.state = "rolling"
    end
    
    for _, i in ipairs(to_roll) do
        local die_entry = dice[i]
        local region = get_region_for_die(die_entry)
        local sx, sy = pick_spawn_for_region(region, rnd)
        local rz = box.z * 0.5 + 1.0 + rnd() * 1.5

        local center_y = (region.y_back + region.y_front) * 0.5
        local to_center = vector{region.x_center - sx, center_y - sy, 0}
        local len = math.sqrt(to_center[1]^2 + to_center[2]^2)
        if len < 1e-4 then
            local angle = rnd() * 2 * math.pi
            to_center = vector{math.cos(angle), math.sin(angle), 0}
        else
            to_center[1] = to_center[1] / len
            to_center[2] = to_center[2] / len
        end

        local vertical_speed = -(18 + rnd() * 8)
        local lateral_speed = math.abs(vertical_speed) * (0.80 + rnd() * 0.25)
        local base_velocity = vector{
            to_center[1] * lateral_speed,
            to_center[2] * lateral_speed,
            vertical_speed
        }

        local jitter = 0.05 * (i - (#dice + 1) / 2)
        die_entry.body.position = vector{sx + jitter, sy - jitter, rz}
        die_entry.body.asleep = false
        die_entry.body.sleep_timer = 0
        die_entry.body.wall_hits = 0
        die_entry.body.angular = vector{(rnd() - 0.5) * 12, (rnd() - 0.5) * 12, (rnd() - 0.5) * 12}
        die_entry.value = nil
        
        local noise = 1.2
        die_entry.body.velocity = vector{
            base_velocity[1] + (rnd() - 0.5) * noise,
            base_velocity[2] + (rnd() - 0.5) * noise,
            base_velocity[3] + (rnd() - 0.5) * noise * 0.5
        }
    end
    
    AudioManager.play_ui("confirm")
    log("[Dice] Rolled " .. #to_roll .. " dice")
end

function checkDiceSettled(dt)
    if diceSettled then return end
    
    local all_stable = true
    for i = 1, #dice do
        local s = dice[i].body
        if not s.asleep then
            all_stable = false
            break
        end
    end
    
    if all_stable then
        diceSettledTimer = diceSettledTimer + dt
        if diceSettledTimer >= SETTLE_DELAY then
            diceSettled = true
            onDiceSettled()
        end
    else
        diceSettledTimer = 0
    end
end

function onDiceSettled()
    local values = readDiceValues(last_roll_indices)
    local log_values = {}
    for i = 1, #values do
        log_values[i] = tostring(values[i].value)
    end
    log("[Dice] Settled: " .. table.concat(log_values, ", "))
    AudioManager.play_ui("move")
    
    if Scriptorium.onDiceSettled then
        Scriptorium:onDiceSettled(values)
    end
end

function readDiceValues(indices)
    local values = {}
    
    local source = indices
    if type(source) ~= "table" or #source == 0 then
        source = {}
        for i = 1, #dice do
            source[#source + 1] = i
        end
    end

    for _, i in ipairs(source) do
        local die_entry = dice[i]
        if die_entry and die_entry.body and die_entry.die then
            local value = readDieFace(die_entry.die, die_entry.body)
            table.insert(values, {
                value = value,
                sides = die_entry.sides or 6,
                kind = die_entry.kind or "d6",
                index = i,
            })
        end
    end
    
    return values
end

function readDieFace(die, body)
    local faces = (die and die.faces) or d6.faces
    local face_map = (die and (die.faceValueMap or die.pipMap)) or d6.faceValueMap or d6.pipMap
    
    local best_face = 1
    local best_z = -math.huge
    
    for face_idx, face in ipairs(faces) do
        local center_z = 0
        
        for _, vert_idx in ipairs(face) do
            local vertex = body[vert_idx]
            center_z = center_z + vertex[3]
        end
        center_z = center_z / #face
        
        if center_z > best_z then
            best_z = center_z
            best_face = face_idx
        end
    end
    
    return (face_map and face_map[best_face]) or best_face
end
