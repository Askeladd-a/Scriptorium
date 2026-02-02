-- render.lua
-- Consolidated from: render.lua + loveplus.lua
-- All rendering, z-buffer, LÖVE extensions

--------------------------------------------------------------------------------
-- LÖVE EXTENSIONS (from loveplus.lua)
--------------------------------------------------------------------------------
-- Compatibility: provide math.atan2 if missing (Lua 5.1/5.2 have math.atan(y, x))
if rawget(math, "atan2") == nil then
  rawset(math, "atan2", function(y, x)
    return math.atan(y, x)
  end)
end

--applies a transformation that maps 
--  0,0 => ox, oy
--  1,0 => xx, xy
--  0,1 => yx, yy
-- via love.graphics.translate, .rotate and .scale

function love.graphics.transform(ox, oy, xx, xy, yx, yy)
  
  local ex, ey, fx,fy = xx-ox, xy-oy, yx-ox, yy-oy
  if ex*fy<ey*fx then ex,ey,fx,fy=fx,fy,ex,ey end
  local e,f = math.sqrt(ex*ex+ey*ey), math.sqrt(fx*fx+fy*fy)
  
  ex,ey = ex/e, ey/e
  fx,fy = fx/f, fy/f
  
  local desiredOrientation=math.atan2(ey+fy,ex+fx)
  local desiredAngle=math.acos(ex*fx+ey*fy)/2
  local z=math.tan(desiredAngle)
  local distortion=math.sqrt((1+z*z)/2)
  
  love.graphics.translate(ox, oy)
  love.graphics.rotate(desiredOrientation)
  love.graphics.scale(1, z)
  love.graphics.rotate(-math.pi/4)
  love.graphics.scale(e/distortion,f/distortion)

end

--cached load for images
local imageCache = {}
function love.graphics.getImage(filename)
  if not imageCache[filename] then
    imageCache[filename]=love.graphics.newImage(filename)
  end
  return imageCache[filename]
end


--a polygon function that unpacks a list of points for a polygon
local lovepolygon=love.graphics.polygon
function love.graphics.polygon(mode,p,...)
  if type(p)=="number" then return lovepolygon(mode,p,...) end
  local pts={}
  for i=1,#p do table.insert(pts,p[i][1]) table.insert(pts,p[i][2]) end
  return lovepolygon(mode,unpack(pts))
end


function love.graphics.dbg()
  if not dbg then return end
  love.graphics.setColor(255,255,255)
  local x,y=5,15
  for _,s in ipairs(pretty.table(dbg,4)) do
    love.graphics.print(s,x,y)
    y=y+15
    if y>love.graphics.getHeight()-15 then x,y=x+200,15 end
  end
end

local lastx,lasty
function love.mouse.delta()
  local x,y=love.mouse.getPosition()
  lastx,lasty, x,y = x,y, x-(lastx or x),y-(lasty or y)
  return x,y
end

-- Compatibility wrapper for setColor: accept 0..255 or 0..1 inputs.
do
  local _setColor = love.graphics.setColor
  function love.graphics.setColor(r,g,b,a)
    if type(r)=="table" then
      local t=r
      r,g,b,a = t[1],t[2],t[3],t[4]
    end
    if r and (r>1 or (g or 0)>1 or (b or 0)>1 or (a or 0)>1) then
      return _setColor((r or 0)/255,(g or 0)/255,(b or 0)/255,(a==nil and 1) or a/255)
    else
      return _setColor(r,g,b,a)
    end
  end
end

--------------------------------------------------------------------------------
-- RENDER MODULE
--------------------------------------------------------------------------------
render={}
local tray_wood_texture = nil

--z ordered rendering of elements
function render.zbuffer(z,action)
  table.insert(render,{z,action})
end
function render.paint()
  table.sort(render,function(a,b) return a[1]<b[1] end)
  for i=1,#render do render[i][2]() end
end
function render.clear()
  table.clear(render)
end

-- draws a board of 20x20 tiles, on the coordinates -10,-10 to 10 10
-- takes the function for the tile images and the lighting mode
-- returns with the four projected corners of the board 
function render.board(image, light, x1, x2, y1, y2)
  -- optional extents: defaults keep previous behaviour (-10..10)
  x1 = x1 or -10; x2 = x2 or 10; y1 = y1 or -10; y2 = y2 or 10

  -- store extents for edgeboard and other helpers
  render.board_extents = {x1,x2,y1,y2}

  -- projects the corners of the tiles
  local points={}
  for x=x1,x2 do    
    local row={}
    for y=y1,y2 do  
      row[y]={view.project(x,y,0)}
    end
    points[x]=row
  end

  for x=x1,x2-1 do
    for y=y1,y2-1 do
      local a,b=points[x][y][1],points[x][y][2]
      local c,d=points[x+1][y][1],points[x+1][y][2]
      local e,f=points[x][y+1][1],points[x][y+1][2]
      local l=light(vector{x,y}, vector{0,0,1})
      love.graphics.setColor(255*l,255*l,255*l)
      love.graphics.push()
      love.graphics.transform(a,b,c,d,e,f)
      local image =love.graphics.getImage(image(x,y))
      love.graphics.draw(image,0,0,0,1/32,1/32)
      love.graphics.pop()
    end
  end
  return {points[x1][y1], points[x2][y1], points[x2][y2], points[x1][y2]}
end


--draws the lightbulb
function render.bulb(action)
  local x,y,z,s=view.project(unpack(light-{0,0,2}))
  action(z,function()
    love.graphics.setBlendMode("add")
    love.graphics.setColor(255,255,255)
    love.graphics.draw(love.graphics.getImage("resources/bulb.png"),x,y,0,s/64,s/64)
    --[[    love.graphics.circle("fill",x,y,s/5,40)
    love.graphics.circle("line",x,y,s/5,40)
    ]]
    love.graphics.setBlendMode("alpha")
  end)
end

--draws a die complete with lighting and projection
function render.die(action, die, star)
  local cam={view.get()}
  local projected={}
  for i=1,#star do
    table.insert(projected, {view.project(unpack(star[i]+star.position))})
  end

  for i=1,#die.faces do
    --prepare face data
    local face=die.faces[i]
    local xy,z,c={},0,vector()
    for i=1,#face do
      c=c+star[face[i]]
      local p = projected[face[i]]
      table.insert(xy,p[1])
      table.insert(xy,p[2])
      z=z+p[3]
    end
    z=z/#face
    c=c/#face
    
    --light it up
    local strength=die.material(c+star.position, c:norm())
    local strength=die.material(c+star.position, c:norm())
    local color={ die.color[1]*strength, die.color[2]*strength, die.color[3]*strength, die.color[4] }
    local text={die.text[1]*strength,die.text[2]*strength,die.text[3]*strength}
    local front=c..(1*c+star.position-cam)<=0
    --if it is visible then render
    action(z, function()
      if front then 
        love.graphics.setColor(unpack(color))
        love.graphics.polygon("fill",unpack(xy))
        love.graphics.setColor(unpack(text))
        die.image(i,unpack(xy))
        -- outline removed (can cause rendering artifacts); material indicator will be drawn as a dot
      elseif color[4] and color[4]<255 then
        love.graphics.setColor(unpack(text))
        die.image(i,unpack(xy))
        love.graphics.setColor(unpack(color))
        love.graphics.polygon("fill",unpack(xy))
      end
    end) 
  end

  
end


--draws a shadow of a die
function render.shadow(action,die, star)
  
  local cast={}
  for i=1,#star do
    local x,y=light.cast(star[i]+star.position)
    if not x then return end --no shadow
    table.insert(cast,vector{x,y})
  end
    
  --convex hull, gift wrapping algorithm
  --find the leftmost point
  --thats in the hull for sure
  local hull={cast[1]}
  for i=1,#cast do if cast[i][1]<hull[1][1] then hull[1]=cast[i] end end
  
  --now wrap around the points to find the outermost
  --this algorithm has the additional niceity that it gives us the points clockwise
  --which is important for love.polygon
  repeat
    local point=hull[#hull]
    local endpoint=cast[1]
    if point==endpoint then endpoint=cast[2] end
    
    --see if cast[i] is to the left of our best guess so far
    for i=1,#cast do
      local left = endpoint-point
      left[1],left[2]=left[2],-left[1]
      local diff=cast[i]-endpoint
      if diff..left>0 then
        endpoint=cast[i]
      end
    end
    hull[#hull+1]=endpoint
    if #hull>#cast+1 then return end --we've done something wrong here
  until hull[1]==hull[#hull]
  if #hull<3 then return end --also something wrong or degenerate case
  
  action(0,function()
    love.graphics.setColor(unpack(die.shadow))
    love.graphics.polygon("fill",hull)
  end)
end  

-- Stencil function: draws the entire tray interior volume for masking
-- Includes floor + all 4 inner walls to properly mask dice at any camera angle
function render.stencil_board_area(border_height)
  border_height = border_height or 1.5
  local x1,x2,y1,y2 = -10,10,-10,10
  if render.board_extents then x1,x2,y1,y2 = unpack(render.board_extents) end
  
  -- Project floor corners
  local floor = {
    {view.project(x1,y1,0)},
    {view.project(x2,y1,0)},
    {view.project(x2,y2,0)},
    {view.project(x1,y2,0)}
  }
  
  -- Project inner top corners (top edge of inner walls)
  local inner_top = {
    {view.project(x1, y1, border_height)},
    {view.project(x2, y1, border_height)},
    {view.project(x2, y2, border_height)},
    {view.project(x1, y2, border_height)}
  }
  
  -- Draw floor
  love.graphics.polygon("fill", 
    floor[1][1], floor[1][2],
    floor[2][1], floor[2][2],
    floor[3][1], floor[3][2],
    floor[4][1], floor[4][2])
  
  -- Draw all 4 inner walls (these extend the stencil area upward)
  -- Front inner wall (y1 side)
  love.graphics.polygon("fill",
    floor[1][1], floor[1][2],
    floor[2][1], floor[2][2],
    inner_top[2][1], inner_top[2][2],
    inner_top[1][1], inner_top[1][2])
  -- Right inner wall (x2 side)
  love.graphics.polygon("fill",
    floor[2][1], floor[2][2],
    floor[3][1], floor[3][2],
    inner_top[3][1], inner_top[3][2],
    inner_top[2][1], inner_top[2][2])
  -- Back inner wall (y2 side)
  love.graphics.polygon("fill",
    floor[3][1], floor[3][2],
    floor[4][1], floor[4][2],
    inner_top[4][1], inner_top[4][2],
    inner_top[3][1], inner_top[3][2])
  -- Left inner wall (x1 side)
  love.graphics.polygon("fill",
    floor[4][1], floor[4][2],
    floor[1][1], floor[1][2],
    inner_top[1][1], inner_top[1][2],
    inner_top[4][1], inner_top[4][2])
end

  --draws around a board
  --draw the void with black to remove shadows extending from the board
function render.edgeboard()
  local x1,x2,y1,y2 = -10,10,-10,10
  if render.board_extents then x1,x2,y1,y2 = unpack(render.board_extents) end
  local corners={
    {view.project(x1,y1,0)},
    {view.project(x1,y2,0)},
    {view.project(x2,y2,0)},
    {view.project(x2,y1,0)}
  }
  love.graphics.setColor(0,0,0)
  
  local m=1 --m is the leftmost corner
  for i=2,4 do if corners[i][1]<corners[m][1] then m=i end end
  
  --n(ext), p(rev), o(ther),m(in) are the four corners
  local n,p,o= corners[math.cycle(m+1,4)], corners[math.cycle(m-1,4)], corners[math.cycle(m+2,4)]
  m=corners[m]
  
  --we ecpect n(ext) to be the clockwise next from m(in)
  if n[2]>p[2] then n,p=p,n end
  
  love.graphics.polygon("fill", -100,m[2], m[1],m[2], n[1],n[2], n[1],-100, -100,-100)
  love.graphics.polygon("fill", n[1],-100, n[1],n[2], o[1],o[2], 100,o[2], 100, -100)
  love.graphics.polygon("fill", 100,o[2], o[1],o[2], p[1],p[2], p[1],100, 100,100)
  love.graphics.polygon("fill", p[1],100, p[1],p[2], m[1],m[2], -100,m[2], -100,100)
  
end

-- Draws a 3D raised border around the board to simulate a dice tray
-- Now integrates with z-buffering for proper depth sorting with dice
function render.tray_border(action, border_width, border_height, border_color)
  -- If called without action (backward compat), draw immediately
  if type(action) ~= "function" then
    -- Shift args: action was actually border_width
    border_color = border_height
    border_height = border_width
    border_width = action
    action = function(z, fn) fn() end  -- immediate draw
  end
  
  border_width = border_width or 0.8   -- width of the border rim
  border_height = border_height or 1.2 -- height of the border walls
  -- Colors in 0-255 format (dark wood brown)
  border_color = border_color or {90, 56, 31}  -- RGB: dark wood brown
  
  local x1, x2, y1, y2 = -10, 10, -10, 10
  if render.board_extents then x1, x2, y1, y2 = unpack(render.board_extents) end
  
  -- Outer edge coordinates (board + border width)
  local ox1, ox2, oy1, oy2 = x1 - border_width, x2 + border_width, y1 - border_width, y2 + border_width
  
  -- Helper: draw a solid color quad (no texture)
  -- Use z_min (closest to camera) for proper occlusion
  local function draw_quad(c1, c2, c3, c4, color, shade)
    local z_min = math.min(c1[3], c2[3], c3[3], c4[3])
    action(z_min, function()
      local r, g, b = color[1] * shade, color[2] * shade, color[3] * shade
      love.graphics.setColor(r, g, b, 255)
      love.graphics.polygon("fill", c1[1], c1[2], c2[1], c2[2], c3[1], c3[2], c4[1], c4[2])
    end)
  end
  
  -- Helper: draw a textured quad using Mesh for correct UV mapping
  -- Use z_min (closest to camera) for proper occlusion
  local function draw_textured_quad(c1, c2, c3, c4, color, shade, texture)
    local z_min = math.min(c1[3], c2[3], c3[3], c4[3])
    action(z_min, function()
      local r, g, b = color[1] * shade / 255, color[2] * shade / 255, color[3] * shade / 255
      -- Create mesh with 4 vertices: {x, y, u, v, r, g, b, a}
      -- UV coords: c1=top-left(0,0), c2=top-right(1,0), c3=bottom-right(1,1), c4=bottom-left(0,1)
      local vertices = {
        {c1[1], c1[2], 0, 0, r, g, b, 1},  -- top-left
        {c2[1], c2[2], 1, 0, r, g, b, 1},  -- top-right
        {c3[1], c3[2], 1, 1, r, g, b, 1},  -- bottom-right
        {c4[1], c4[2], 0, 1, r, g, b, 1},  -- bottom-left
      }
      local mesh = love.graphics.newMesh(vertices, "fan", "stream")
      mesh:setTexture(texture)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(mesh)
    end)
  end
  
  -- Lazy load texture at the start
  if not tray_wood_texture then
    local ok, img = pcall(love.graphics.newImage, "resources/wood.png")
    if ok then tray_wood_texture = img end
  end
  
  -- Project all 16 key points (inner/outer at z=0 and z=border_height)
  local inner_bottom = {
    {view.project(x1, y1, 0)},
    {view.project(x2, y1, 0)},
    {view.project(x2, y2, 0)},
    {view.project(x1, y2, 0)}
  }
  local outer_bottom = {
    {view.project(ox1, oy1, 0)},
    {view.project(ox2, oy1, 0)},
    {view.project(ox2, oy2, 0)},
    {view.project(ox1, oy2, 0)}
  }
  local inner_top = {
    {view.project(x1, y1, border_height)},
    {view.project(x2, y1, border_height)},
    {view.project(x2, y2, border_height)},
    {view.project(x1, y2, border_height)}
  }
  local outer_top = {
    {view.project(ox1, oy1, border_height)},
    {view.project(ox2, oy1, border_height)},
    {view.project(ox2, oy2, border_height)},
    {view.project(ox1, oy2, border_height)}
  }
  
  -- Draw the 4 outer walls (vertical faces on outside) with texture
  if tray_wood_texture then
    draw_textured_quad(outer_bottom[1], outer_bottom[2], outer_top[2], outer_top[1], border_color, 180, tray_wood_texture)
    draw_textured_quad(outer_bottom[2], outer_bottom[3], outer_top[3], outer_top[2], border_color, 220, tray_wood_texture)
    draw_textured_quad(outer_bottom[3], outer_bottom[4], outer_top[4], outer_top[3], border_color, 255, tray_wood_texture)
    draw_textured_quad(outer_bottom[4], outer_bottom[1], outer_top[1], outer_top[4], border_color, 190, tray_wood_texture)
  else
    draw_quad(outer_bottom[1], outer_bottom[2], outer_top[2], outer_top[1], border_color, 0.7)
    draw_quad(outer_bottom[2], outer_bottom[3], outer_top[3], outer_top[2], border_color, 0.85)
    draw_quad(outer_bottom[3], outer_bottom[4], outer_top[4], outer_top[3], border_color, 1.0)
    draw_quad(outer_bottom[4], outer_bottom[1], outer_top[1], outer_top[4], border_color, 0.75)
  end
  
  -- Draw the 4 inner walls (vertical faces on inside, facing the dice) with texture
  if tray_wood_texture then
    draw_textured_quad(inner_bottom[2], inner_bottom[1], inner_top[1], inner_top[2], border_color, 130, tray_wood_texture)
    draw_textured_quad(inner_bottom[3], inner_bottom[2], inner_top[2], inner_top[3], border_color, 140, tray_wood_texture)
    draw_textured_quad(inner_bottom[4], inner_bottom[3], inner_top[3], inner_top[4], border_color, 150, tray_wood_texture)
    draw_textured_quad(inner_bottom[1], inner_bottom[4], inner_top[4], inner_top[1], border_color, 130, tray_wood_texture)
  else
    draw_quad(inner_bottom[2], inner_bottom[1], inner_top[1], inner_top[2], border_color, 0.5)
    draw_quad(inner_bottom[3], inner_bottom[2], inner_top[2], inner_top[3], border_color, 0.55)
    draw_quad(inner_bottom[4], inner_bottom[3], inner_top[3], inner_top[4], border_color, 0.6)
    draw_quad(inner_bottom[1], inner_bottom[4], inner_top[4], inner_top[1], border_color, 0.5)
  end
  
  -- Draw the top surface (horizontal rim) with wood texture
  if tray_wood_texture then
    draw_textured_quad(outer_top[1], outer_top[2], inner_top[2], inner_top[1], border_color, 230, tray_wood_texture)
    draw_textured_quad(outer_top[2], outer_top[3], inner_top[3], inner_top[2], border_color, 240, tray_wood_texture)
    draw_textured_quad(outer_top[3], outer_top[4], inner_top[4], inner_top[3], border_color, 255, tray_wood_texture)
    draw_textured_quad(outer_top[4], outer_top[1], inner_top[1], inner_top[4], border_color, 225, tray_wood_texture)
  else
    draw_quad(outer_top[1], outer_top[2], inner_top[2], inner_top[1], border_color, 0.9)
    draw_quad(outer_top[2], outer_top[3], inner_top[3], inner_top[2], border_color, 0.95)
    draw_quad(outer_top[3], outer_top[4], inner_top[4], inner_top[3], border_color, 1.0)
    draw_quad(outer_top[4], outer_top[1], inner_top[1], inner_top[4], border_color, 0.88)
  end
end

