dbg={}

require"core"     -- base utilities + vectors/rotations
require"render"   -- rendering + LÖVE extensions
require"physics"  -- simulation (box, star, materials)
require"geometry"
require"view"
require"light"

-- Board configuration (consolidated from resources/config.lua)
config = {
  boardlight = light.metal
}
function config.boardimage(x,y)
  return "resources/textures/felt.png"
end

-- Create four D6 dice by default for playtesting
dice = {}
local dice_size = 0.7
for i = 1, 4 do
  local sx = (i - 2.5) * 0.6
  dice[i] = {
    star = newD6star(dice_size):set({sx, 0, 10}, { (i%2==0) and 4 or -4, (i%2==0) and -2 or 2, 0 }, {1,1,2}),
    die = clone(d6, { material = light.plastic, color = {200, 0, 20, 150}, text = {255,255,255}, shadow = {20,0,0,150} })
  }

  -- Physics tuning: don't override mass (let newD6star calculate it based on size)
  -- Only override per-die behavior parameters
  dice[i].star.restitution = 0.25
  dice[i].star.friction = 0.75
  dice[i].star.linear_damping = 0.18  -- higher damping for smaller dice
  dice[i].star.angular_damping = 0.22 -- higher damping for smaller dice
  -- apply a default material preset to the star for convenience (now rubber)
  if materials and materials.get then
    local mat = materials.get("rubber")
    if mat then 
      -- Apply material but scale mass to dice size
      local size_factor = dice_size * dice_size * dice_size  -- volume scales with size^3
      dice[i].star.restitution = mat.restitution or 0.15
      dice[i].star.friction = mat.friction or 1.0
      dice[i].star.linear_damping = mat.linear_damping or 0.12
      dice[i].star.angular_damping = mat.angular_damping or 0.12
      -- Keep mass calculated by newD6star (proportional to size)
    end
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

-- Drag/grab feature removed: input-based grabbing is disabled to allow programmatic rolls only.
-- If needed, programmatic roll helper is provided below: rollAllDice().

-- Convert screen coords to world coords (same maths as used in draw)
function convert(sx, sy)
  local cx = love.graphics.getWidth()/2
  local cy = love.graphics.getHeight()/2
  local scale = cx/4
  return (sx - cx) / scale, (sy - cy) / scale
end

function love.load()
  -- box: x,y,z, gravity, bounce(restitution), friction, dt
  -- wood-like physical parameters (rectangular tray: smaller)
  box:set(8,5,10,25,0.25,0.75,0.01)
  -- slightly stronger global damping to dissipate energy and avoid ball-like rebounds
  box.linear_damping = 0.12
  box.angular_damping = 0.12
  -- border height for rim rejection physics (must match render.tray_border height)
  box.border_height = 1.5

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
end

-- Input-based grabbing has been intentionally disabled.
function love.mousepressed(x,y,b)
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
function love.mousemoved(x,y,dx,dy,istouch)
  -- no-op: grab removed
end
function love.mousereleased(x,y,b)
  -- no-op: grab removed
end

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
    -- grab feature removed: no input-driven follow logic
  end
  
  box:update(dt)
end

-- Programmatic roll helper: apply random impulses to every die
function rollAllDice()
  local rnd = (love and love.math and love.math.random) or math.random
  -- pick a single random point on the square board border and launch all dice together
  local half = box.x * 0.9
  local side = math.floor(rnd()*4) + 1
  local sx, sy
  -- pick a point near the border but MORE inset to prevent immediate wall collisions
  local inset = box.x * (0.15 + rnd() * 0.10) -- 15%..25% inward (was 3%..15%)
  local span = half - inset
  if side == 1 then sx = -half + inset; sy = (rnd()*2 - 1) * span
  elseif side == 2 then sx = half - inset; sy = (rnd()*2 - 1) * span
  elseif side == 3 then sy = -half + inset; sx = (rnd()*2 - 1) * span
  else sy = half - inset; sx = (rnd()*2 - 1) * span end

  -- spawn height: higher to give more flight time for diagonal movement
  local rz = box.z * 0.5 + 1.0 + rnd() * 1.5  -- was 0.4 + 0.5 + 0..1
  
  -- compute direction toward center
  local to_center = vector{-sx, -sy, 0}
  local len = math.sqrt(to_center[1]^2 + to_center[2]^2)
  if len < 1e-4 then
    -- If spawn near center, generate random direction (avoid zero-vector normalization)
    local angle = rnd() * 2 * math.pi
    to_center = vector{math.cos(angle), math.sin(angle), 0}
  else
    to_center[1] = to_center[1] / len
    to_center[2] = to_center[2] / len
  end

  -- Target: diagonal throw with ~45 degree angle toward the board center
  -- Use VELOCITY directly instead of impulse to avoid clamping issues
  local vertical_speed = -(20 + rnd()*10)  -- downward speed: -20 to -30 (stronger throw)
  -- Lateral speed: ensure diagonal trajectory (0.8 to 1.1 of vertical magnitude)
  local lateral_speed = math.abs(vertical_speed) * (0.8 + rnd()*0.3)
  
  local base_velocity = vector{
    to_center[1] * lateral_speed,
    to_center[2] * lateral_speed,
    vertical_speed
  }

  for i=1,#dice do
    -- tiny per-die offset to avoid exact overlap on spawn (keeps them 'together')
    local jitter = 0.05 * (i - (#dice+1)/2)  -- slightly larger jitter
    dice[i].star.position = vector{sx + jitter, sy - jitter, rz}
    
    -- CRITICAL: Wake up the die so physics actually processes it!
    dice[i].star.asleep = false
    dice[i].star.sleep_timer = 0
    dice[i].star.wall_hits = 0  -- reset wall hit counter
    
    -- Angular velocity for visible spin
    dice[i].star.angular = vector{(rnd()-0.5)*12, (rnd()-0.5)*12, (rnd()-0.5)*12}
    
    -- Apply velocity DIRECTLY (bypassing :push() clamping) with tiny per-die variation
    local noise = 1.2
    dice[i].star.velocity = vector{
      base_velocity[1] + (rnd()-0.5)*noise,
      base_velocity[2] + (rnd()-0.5)*noise,
      base_velocity[3] + (rnd()-0.5)*0.5  -- less noise on vertical
    }
  end
end

function love.draw()
  --use a coordinate system with 0,0 at the center
  --and an approximate width and height of 10
  local cx,cy=love.graphics.getWidth()/2,love.graphics.getHeight()/2
  local scale=cx/4
  
  -- Offset to position tray lower on screen (where the yellow X was)
  local tray_offset_y = love.graphics.getHeight() * 0.22
  
  love.graphics.push()
  love.graphics.translate(cx, cy + tray_offset_y)
  love.graphics.scale(scale)
  -- convert already defined globally; reuse it here
  
  --board: rectangular using box.x (width) and box.y (depth)
  local bx = math.max(0.001, box.x)
  local by = math.max(0.001, box.y)
  render.board(config.boardimage, config.boardlight, -bx, bx, -by, by)
  
  --shadows
  for i=1,#dice do render.shadow(function(z,f) f() end, dice[i].die, dice[i].star) end
  render.edgeboard()  -- covers area outside tray with black
  
  -- Draw everything in a SINGLE z-buffer pass for correct depth sorting
  render.clear()
  
  -- Add tray border to z-buffer
  render.tray_border(render.zbuffer, 0.8, 1.5)  -- border_width=0.8, border_height=1.5
  
  -- Add light bulb and dice to SAME z-buffer
  render.bulb(render.zbuffer)
  for i=1,#dice do render.die(render.zbuffer, dice[i].die, dice[i].star) end
  
  -- Paint everything together - z-buffer handles occlusion
  render.paint()

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

end

function love.keypressed(key, scancode, isrepeat)
  if key == 'r' or key == 'R' then
    if rollAllDice then rollAllDice() end
  end
end
