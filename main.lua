-- (definizione rimossa: handler unificato più sotto)

-- (definizione rimossa: handler unificato più sotto)

-- (definizione rimossa: handler unificato più sotto)

dbg={}

local dice3d = require("dice3d")

require"base"
require"loveplus"
require"vector"

require"render"
require"stars"
require"geometry"
require"view"
require"light"
materials = require"materials"

require "default/config"

-- Create four D6 dice by default for playtesting
dice = {}
for i = 1, 4 do
  local sx = (i - 2.5) * 0.8
  dice[i] = {
    star = newD6star():set({sx, 0, 10}, { (i%2==0) and 4 or -4, (i%2==0) and -2 or 2, 0 }, {1,1,2}),
    die = clone(d6, { material = light.plastic, color = {200, 0, 20, 150}, text = {255,255,255}, shadow = {20,0,0,150} })
  }

  -- Apply a wood-like physics preset to the star (visual clone stays unchanged)
  -- Tweak these numbers later to taste; this does not modify the `die = clone(...)` line
  dice[i].star.mass = 1.2
  dice[i].star.invMass = 1 / 1.2
  -- per-die tuning to match wood-like behaviour
  dice[i].star.restitution = 0.25
  dice[i].star.friction = 0.75
  dice[i].star.linear_damping = 0.06
  dice[i].star.angular_damping = 0.08
  -- apply a default material preset to the star for convenience (now rubber)
  if materials and materials.get then
    local mat = materials.get("rubber")
    if mat then materials.apply(dice[i].star, mat) end
  end
end

-- Simple UI button (screen coordinates)
local roll_button = { x = 20, y = 620, w = 160, h = 48, text = "Lancia Dadi" }
-- Material UI state (populated in love.load)
local material_names = {}
local material_buttons = {}

-- helper: build material name list from module
local function build_material_list()
  material_names = {}
  if materials and materials.presets then
    for name,_ in pairs(materials.presets) do table.insert(material_names, name) end
    table.sort(material_names)
  end
end

-- Helper: get the material preset name for a star (by identity)
local function get_material_name(star)
  if not star or not star.material then return nil end
  if materials and materials.presets then
    for name,p in pairs(materials.presets) do if p == star.material then return name end end
  end
  -- fallback: if the material itself has a name field, use it
  return star.material.name
end

-- Tooltip mode: when true, show tooltips for all dice always
tooltip_always_on = true

-- Drag/grab feature removed: input-based grabbing is disabled to allow programmatic rolls only.
-- If needed, programmatic roll helper is provided below: rollAllDice().

-- Convert screen coords to world coords (same maths as used in draw)
function convert(sx, sy)
  local cx = love.graphics.getWidth()/2
  local cy = love.graphics.getHeight()/2
  local scale = cx/4
  return (sx - cx) / scale, (sy - cy) / scale
end

-- Pick the topmost die under screen coords (returns die or nil)
local function pick_focused_at_screen(sx, sy)
  if not view then return nil end
  local d = {}
  for i=1,#dice do
    local px,py,pz,p = view.project(unpack(dice[i].star.position))
    table.insert(d,{dice[i], px, py, pz, p})
  end
  table.sort(d, function(a,b) return a[4] > b[4] end)
  local wx,wy = convert(sx, sy)
  for i=1,#d do
    local dx,dy = wx - d[i][2], wy - d[i][3]
    local size = d[i][5]
    if math.abs(dx) < size and math.abs(dy) < size then
      return d[i][1]
    end
  end
  return nil
end

-- Adjust the grabbed star's world x,y so that its projection matches target_px/py at given lift z
-- Compute a world position (x,y) for star such that view.project(x,y,lift) ~= target_px/py.
-- Returns nx,ny (world coords). Does not mutate velocities; caller decides smoothing.
local function snap_star_to_projection(star, target_px, target_py, lift, dt)
  local max_iters = 4
  local eps = 0.001
  local alpha = 1.0
  local nx, ny = star.position[1], star.position[2]
  for iter=1,max_iters do
    local x,y,z = nx, ny, lift
    local px,py = view.project(x,y,z)
    local ex,ey = target_px - px, target_py - py
    if math.sqrt(ex*ex + ey*ey) < 1e-4 then break end

    -- finite difference jacobian
    local px_dx,py_dx = view.project(x+eps,y,z)
    local px_dy,py_dy = view.project(x,y+eps,z)
    local j11 = (px_dx - px)/eps
    local j12 = (px_dy - px)/eps
    local j21 = (py_dx - py)/eps
    local j22 = (py_dy - py)/eps

    local det = j11*j22 - j12*j21
    if math.abs(det) < 1e-8 then break end
    local dx = (  ( j22*ex - j12*ey) / det) * alpha
    local dy = (  ( -j21*ex + j11*ey) / det) * alpha

    -- clamp step to avoid overshoot
    local maxstep = 0.5 * (dt*60 + 0.1)
    if dx > maxstep then dx = maxstep end
    if dx < -maxstep then dx = -maxstep end
    if dy > maxstep then dy = maxstep end
    if dy < -maxstep then dy = -maxstep end

    nx = nx + dx
    ny = ny + dy
  end
  return nx, ny
end

-- Compute velocity (vx,vy) from samples using linear regression over time
-- Weighted linear regression velocity estimator (gives more weight to recent samples)
local function compute_velocity_from_samples(samples)
  local n = #samples
  if n < 2 then return nil end
  -- choose time constant (seconds) for exponential weighting
  local tau = 0.08
  local last_t = samples[#samples].t
  local wsum = 0
  local t_mean = 0
  local x_mean = 0
  local y_mean = 0
  local ws = {}
  for i=1,n do
    local w = math.exp((samples[i].t - last_t)/tau)
    ws[i] = w
    wsum = wsum + w
    t_mean = t_mean + w * samples[i].t
    x_mean = x_mean + w * samples[i].pos[1]
    y_mean = y_mean + w * samples[i].pos[2]
  end
  if wsum == 0 then return nil end
  t_mean = t_mean / wsum; x_mean = x_mean / wsum; y_mean = y_mean / wsum

  local num_x, num_y, denom = 0,0,0
  for i=1,n do
    local dt = samples[i].t - t_mean
    num_x = num_x + ws[i] * dt * (samples[i].pos[1] - x_mean)
    num_y = num_y + ws[i] * dt * (samples[i].pos[2] - y_mean)
    denom = denom + ws[i] * dt * dt
  end
  if math.abs(denom) < 1e-6 then return nil end
  local vx = num_x / denom
  local vy = num_y / denom
  return vector{vx, vy, 0}
end

function love.load()
  --feed the simulation
  -- box: x,y,z, gravity, bounce(restitution), friction, dt
  -- increase gravity to make dice fall faster; slightly bump restitution for liveliness
  -- wood-like physical parameters (tuned to avoid overly bouncy behavior)
  -- gravity=25, restitution(bounce)=0.25, friction=0.75, dt=0.01
  box:set(10,10,10,25,0.25,0.75,0.01)
  -- slightly stronger global damping to dissipate energy and avoid ball-like rebounds
  box.linear_damping = 0.12
  box.angular_damping = 0.12
  ---round(0.2,dice[2].die,dice[2].star)

  for i=1,#dice do box[i]=dice[i].star end
  -- seed randomness and perform an initial programmatic roll
  math.randomseed(os.time())
  -- seed both standard and LÖVE RNGs when available
  if love and love.math and love.math.setRandomSeed then love.math.setRandomSeed(os.time()) end
  math.randomseed(os.time())
  if rollAllDice then rollAllDice() end

  -- build materials list and material UI button rectangles
  build_material_list()
  -- prepare rectangles (screen coords) for each die's material button; will be laid out in love.draw if needed
  material_buttons = {}

  -- Inizializza 3D (dadi, vassoio, camera)
  if dice3d and dice3d.load then dice3d.load() end
end

-- Track previous inside/outside state per die for automatic investigation
local prev_inside = {}


-- Input-based grabbing has been intentionally disabled.
function love.mousepressed(x, y, b)
  if dice3d and dice3d.mousepressed then dice3d.mousepressed(x, y, b) end
  if b ~= 1 then return end
  -- button hit test
  if x >= roll_button.x and x <= roll_button.x + roll_button.w and y >= roll_button.y and y <= roll_button.y + roll_button.h then
    if rollAllDice then rollAllDice() end
    return
  end
  -- material button hit tests (cycle material for the clicked die)
  for i,rect in ipairs(material_buttons) do
    if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
      -- cycle the material for die i
      local cur = dice[i].star.material and dice[i].star.material or nil
      local cur_name = nil
      if cur then
        -- find name by identity in presets
        for name,p in pairs(materials.presets) do if p == cur then cur_name = name; break end end
      end
      local idx = 1
      for j=1,#material_names do if material_names[j] == cur_name then idx = j; break end end
      local next_idx = (idx % #material_names) + 1
      local next_name = material_names[next_idx]
      local preset = materials.get(next_name)
      if preset then materials.apply(dice[i].star, preset) end
      return
    end
  end
end
-- (definizione rimossa: handler unificato in alto)
-- (definizione rimossa: handler unificato in alto)

-- Mouse wheel scroll (LÖVE 0.9+)
function love.wheelmoved(dx,dy)
  if dy>0 then view.move(1.1) end
  if dy<0 then view.move(0.91) end
end

function love.update(dt)
  dbg.fps=(dbg.fps or 100)*99/100 +0.01/dt
  local dx,dy=love.mouse.delta()
  if love.mouse.isDown(2) then 
    view.raise(dy/100)
    view.turn(dx/100)
  end
  
  if convert then 
    
    --get the dice
    local d={}
    for i=1,#dice do table.insert(d,{dice[i], view.project(unpack(dice[i].star.position))}) end
    table.sort(d,function(a,b) return a[4]>b[4] end)
    
    --get the one under focus
    local x,y=convert(love.mouse.getPosition())
    focused=false
    for i=1,#d do
      local dx,dy=x-d[i][2],y-d[i][3]
      local size=d[i][5]
      if math.abs(dx)<size and math.abs(dy)<size then
        focused=d[i][1]
        break
      end
    end
    light.follow(focused and focused.star,dt)
    -- automatic investigation: detect IN/OUT transitions and log details
    for i=1,#dice do
      local s = dice[i].star
      local inside_x = s.position[1] >= -box.x and s.position[1] <= box.x
      local inside_y = s.position[2] >= -box.y and s.position[2] <= box.y
      local inside_z = s.position[3] >= 0 and s.position[3] <= box.z
      local inside = inside_x and inside_y and inside_z
      if prev_inside[i] == nil then prev_inside[i] = inside end
      if prev_inside[i] ~= inside then
        local t = love.timer.getTime()
        local reason = {}
        if not inside_x then table.insert(reason, string.format("x=%.2f", s.position[1])) end
        if not inside_y then table.insert(reason, string.format("y=%.2f", s.position[2])) end
        if not inside_z then table.insert(reason, string.format("z=%.2f", s.position[3])) end
        local vel = s.velocity
        local logline = string.format("[physics] time=%.3f die=%d %s->%s reason=%s pos=(%.3f,%.3f,%.3f) vel=(%.3f,%.3f,%.3f)",
          t, i, tostring(prev_inside[i]), tostring(inside), table.concat(reason,","), s.position[1],s.position[2],s.position[3], vel[1],vel[2],vel[3])
        -- append to log file so we can collect diagnostics even when LÖVE runs detached
        local fh, ferr = io.open("physics_log.txt", "a")
        if fh then
          fh:write(logline .. "\n")
          fh:close()
        else
          -- fallback to console if file cannot be opened
          print("[physics:log-error]", ferr, logline)
        end
        prev_inside[i] = inside
      end
    end
    -- grab feature removed: no input-driven follow logic
  end
  
  box:update(dt)
  -- Aggiorna la pipeline 3D dadi/vassoio
  dice3d.update(dt)
end

-- Programmatic roll helper: apply random impulses to every die
function rollAllDice()
  local rnd = (love and love.math and love.math.random) or math.random
  -- pick a single random point on the square board border and launch all dice together
  local half = box.x * 0.9
  local side = math.floor(rnd()*4) + 1
  local sx, sy
  -- pick a point near the border but slightly inset so dice don't spawn exactly on the edge
  local inset = box.x * (0.03 + rnd() * 0.12) -- 3%..15% inward
  local span = half - inset
  if side == 1 then sx = -half + inset; sy = (rnd()*2 - 1) * span
  elseif side == 2 then sx = half - inset; sy = (rnd()*2 - 1) * span
  elseif side == 3 then sy = -half + inset; sx = (rnd()*2 - 1) * span
  else sy = half - inset; sx = (rnd()*2 - 1) * span end

  -- spawn height and common impulse directed roughly toward center
  -- we want the impulse to be downward (negative z) with a maximum angle of 45 degrees
  local rz = box.z * 0.4 + 0.5 + rnd() * 1.0
  local to_center = vector{-sx, -sy, 0}
  -- normalize lateral direction
  local len = math.sqrt(to_center[1]^2 + to_center[2]^2)
  if len < 1e-4 then len = 1 end
  to_center[1] = to_center[1] / len
  to_center[2] = to_center[2] / len

  -- choose a downward (negative) vertical impulse magnitude
  local vertical_strength = -(18 + rnd()*8) -- negative = toward the board
  -- lateral magnitude must satisfy lateral/|vertical| <= tan(45)=1 to keep angle <=45deg
  local max_lateral = math.abs(vertical_strength)
  local lateral_strength = max_lateral * (0.5 + rnd()*0.45) -- between 50% and 95% of vertical
  local base_impulse = vector{to_center[1] * lateral_strength, to_center[2] * lateral_strength, vertical_strength}

  for i=1,#dice do
    -- tiny per-die offset to avoid exact overlap on spawn (keeps them 'together')
    local jitter = 0.02 * (i - (#dice+1)/2)
    dice[i].star.position = vector{sx + jitter, sy - jitter, rz}
    dice[i].star.velocity = vector{0,0,0}
    -- small random angular variance but same translational impulse (increased spin)
    dice[i].star.angular = vector{(rnd()-0.5)*10, (rnd()-0.5)*10, (rnd()-0.5)*10}
    -- apply the same base impulse to all dice (optionally add tiny random noise)
    local noise = 1.5
    local impulse = vector{ base_impulse[1] + (rnd()-0.5)*noise, base_impulse[2] + (rnd()-0.5)*noise, base_impulse[3] }
    dice[i].star:push(impulse, vector{(rnd()-0.5)*1, (rnd()-0.5)*1, 1})
  end
end


function love.draw()

  --use a coordinate system with 0,0 at the center
  --and an approximate width and height of 10
  local cx,cy=love.graphics.getWidth()/2,love.graphics.getHeight()/2
  local scale=cx/4
  
  love.graphics.push()
  love.graphics.translate(cx,cy)
  love.graphics.scale(scale)

  -- Disegna vassoio e dadi 3D (solo g3d)
  dice3d.draw()

  -- (debug overlay removed)

  love.graphics.pop()

  -- Physics debug overlay: show inside/outside state and velocities
  -- disabled by default to hide debug information in the corner
  local show_physics_debug = false
  if show_physics_debug then
    love.graphics.setColor(255,255,255)
    local sx,sy = 5,15
    for i=1,#dice do
      local s = dice[i].star
      local inside_x = s.position[1] >= -box.x and s.position[1] <= box.x
      local inside_y = s.position[2] >= -box.y and s.position[2] <= box.y
      local inside_z = s.position[3] >= 0 and s.position[3] <= box.z
      local inside = inside_x and inside_y and inside_z and "IN" or "OUT"
      local v = s.velocity
      local msg = string.format("die %d: %s pos=(%.2f,%.2f,%.2f) vel=(%.2f,%.2f,%.2f)", i, inside, s.position[1],s.position[2],s.position[3], v[1],v[2],v[3])
      love.graphics.print(msg, sx, sy + (i-1)*15)
    end
  end
  -- Draw simple UI button (screen coords)
  love.graphics.setColor(0.2, 0.2, 0.25, 0.95)
  love.graphics.rectangle("fill", roll_button.x, roll_button.y, roll_button.w, roll_button.h, 6, 6)
  love.graphics.setColor(1,1,1)
  love.graphics.rectangle("line", roll_button.x, roll_button.y, roll_button.w, roll_button.h, 6, 6)
  local font = love.graphics.getFont()
  local fh = font and font:getHeight() or 14
  love.graphics.printf(roll_button.text, roll_button.x, roll_button.y + (roll_button.h - fh)/2, roll_button.w, "center")

  -- FPS counter (screen coords)
  love.graphics.setColor(1,1,1)
  local fps = love.timer.getFPS()
  love.graphics.print(string.format("FPS: %d", fps), 8, 8)

  -- Materials runtime UI (per-die) placed above the roll button
  if #dice > 0 and #material_names > 0 then
    local bw, bh = 120, 22
    local start_x = roll_button.x
    local start_y = roll_button.y - (#dice * (bh + 6)) - 12
    material_buttons = {}
    for i=1,#dice do
      local y = start_y + (i-1)*(bh+6)
      -- background
      love.graphics.setColor(0.15,0.15,0.18,0.9)
      love.graphics.rectangle("fill", start_x, y, bw, bh, 4, 4)
      love.graphics.setColor(1,1,1)
      local matname = (dice[i].star.material and (function()
        for n,p in pairs(materials.presets) do if p == dice[i].star.material then return n end end
        return "?"
      end)()) or "none"
      -- material color swatch
      local sw = 14
      local swx = start_x + 6
      local swy = y + (bh - sw)/2
      local matcolor = nil
      if dice[i].star.material and dice[i].star.material.color then matcolor = dice[i].star.material.color end
      if matcolor then love.graphics.setColor(matcolor) else love.graphics.setColor(0.5,0.5,0.5) end
      love.graphics.rectangle("fill", swx, swy, sw, sw, 3, 3)
      love.graphics.setColor(1,1,1)
      love.graphics.print(string.format("Die %d: %s", i, matname), swx + sw + 6, y+3)
      -- button area to the right of the label
      local bx, by, bwb, bbh = start_x + bw + 8, y, 64, bh
      love.graphics.setColor(0.22,0.22,0.25,0.95)
      love.graphics.rectangle("fill", bx, by, bwb, bbh, 4,4)
      love.graphics.setColor(1,1,1)
      love.graphics.printf("Cambia", bx, by + (bh - fh)/2, bwb, "center")
      table.insert(material_buttons, { x = bx, y = by, w = bwb, h = bbh })
    end
  end
  -- Tooltip: either always-on for all dice, or hover-based
  local font = love.graphics.getFont()
  local pad = 6
  local fh = font and font:getHeight() or 14
  if tooltip_always_on then
    local cx, cy = love.graphics.getWidth()/2, love.graphics.getHeight()/2
    local scale = cx/4
    for i=1,#dice do
      local s = dice[i].star
      local px,py = view.project(unpack(s.position))
      local tx, ty = cx + px*scale + 8, cy + py*scale + 8
      local matname = get_material_name(s) or "none"
      local lines = {
        string.format("Die %d: %s", i, matname),
        string.format("mass=%.2f  rest=%.2f  fric=%.2f", (s.mass or 0), (s.restitution or 0), (s.friction or 0)),
      }
      local w = 0
      for _,ln in ipairs(lines) do w = math.max(w, font:getWidth(ln)) end
      local h = #lines * fh + (#lines-1)*2
      love.graphics.setColor(0,0,0,0.75)
      love.graphics.rectangle("fill", tx, ty, w + pad*2, h + pad*2, 6, 6)
      love.graphics.setColor(1,1,1)
      for j,ln in ipairs(lines) do love.graphics.print(ln, tx + pad, ty + pad + (j-1)*(fh+2)) end
    end
  else
    local mx, my = love.mouse.getPosition()
    local hovered = pick_focused_at_screen(mx, my)
    if hovered then
      local s = hovered.star
      local matname = get_material_name(s) or "none"
      local lines = {}
      table.insert(lines, string.format("Material: %s", matname))
      table.insert(lines, string.format("mass=%.2f  rest=%.2f  fric=%.2f", (s.mass or 0), (s.restitution or 0), (s.friction or 0)))
      table.insert(lines, string.format("lin_damp=%.2f  ang_damp=%.2f", (s.linear_damping or 0), (s.angular_damping or 0)))
      local w = 0
      for i,ln in ipairs(lines) do w = math.max(w, font:getWidth(ln)) end
      local h = #lines * fh + (#lines-1)*2
      local tx, ty = mx + 12, my + 12
      love.graphics.setColor(0,0,0,0.75)
      love.graphics.rectangle("fill", tx, ty, w + pad*2, h + pad*2, 6, 6)
      love.graphics.setColor(1,1,1)
      for i,ln in ipairs(lines) do love.graphics.print(ln, tx + pad, ty + pad + (i-1)*(fh+2)) end
    end
  end

end

function love.keypressed(key, scancode, isrepeat)
  if key == 'r' or key == 'R' then
    if rollAllDice then rollAllDice() end
    -- Lancia un dado 3D di test
    dice3d.spawn(0, 2, 0)
  end
end
