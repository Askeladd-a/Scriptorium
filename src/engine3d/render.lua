
if rawget(math, "atan2") == nil then
  rawset(math, "atan2", function(y, x)
    if x == nil then
      return math.atan(y)
    end
    if x > 0 then
      return math.atan(y / x)
    end
    if x < 0 then
      if y >= 0 then
        return math.atan(y / x) + math.pi
      end
      return math.atan(y / x) - math.pi
    end
    if y > 0 then
      return math.pi / 2
    end
    if y < 0 then
      return -math.pi / 2
    end
    return 0
  end)
end


local function graphics_transform(ox, oy, xx, xy, yx, yy)
  
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
rawset(love.graphics, "transform", graphics_transform)

local imageCache = {}
local function graphics_get_image(filename)
  if not imageCache[filename] then
    local img = love.graphics.newImage(filename)
    img:setFilter("linear", "linear")
    img:setWrap("clamp", "clamp")
    imageCache[filename] = img
  end
  return imageCache[filename]
end
rawset(love.graphics, "getImage", graphics_get_image)


local lovepolygon=love.graphics.polygon
local function graphics_polygon(mode,p,...)
  if type(p)=="number" then return lovepolygon(mode,p,...) end
  local pts={}
  for i=1,#p do table.insert(pts,p[i][1]) table.insert(pts,p[i][2]) end
  return lovepolygon(mode,unpack(pts))
end
rawset(love.graphics, "polygon", graphics_polygon)


local function graphics_dbg()
  local dbg_data = rawget(_G, "dbg")
  if not dbg_data then return end
  love.graphics.setColor(255,255,255)
  local x,y=5,15
  local rows = (pretty and pretty.table and pretty.table(dbg_data, 4)) or {}
  if type(rows) == "string" then
    rows = {rows}
  elseif type(rows) ~= "table" then
    rows = {}
  end
  for _,s in ipairs(rows) do
    love.graphics.print(tostring(s),x,y)
    y=y+15
    if y>love.graphics.getHeight()-15 then x,y=x+200,15 end
  end
end
rawset(love.graphics, "dbg", graphics_dbg)

local lastx,lasty
local function mouse_delta()
  local x,y=love.mouse.getPosition()
  lastx,lasty, x,y = x,y, x-(lastx or x),y-(lasty or y)
  return x,y
end
rawset(love.mouse, "delta", mouse_delta)

do
  local _setColor = love.graphics.setColor
  local function graphics_set_color(r,g,b,a)
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
  rawset(love.graphics, "setColor", graphics_set_color)
end

render={}
local tray_wood_texture = nil
local board_mesh_cache = {key = nil, mesh = nil, corners = nil}
local tray_border_cache = {key = nil, draw_calls = nil}

local function fmt4(n)
  return string.format("%.4f", tonumber(n) or 0)
end

local function cycle(value, n)
  while value > n do value = value - n end
  while value < 1 do value = value + n end
  return value
end

local function current_view_signature()
  if not view then
    return "view:nil"
  end
  return table.concat({
    "view",
    fmt4(view.yaw),
    fmt4(view.pitch),
    fmt4(view.distance),
  }, "|")
end

local function current_light_signature()
  if type(light) == "table" then
    return table.concat({
      "light",
      fmt4(light[1]),
      fmt4(light[2]),
      fmt4(light[3]),
    }, "|")
  end
  return "light:nil"
end

local function safe_release_mesh(mesh)
  if mesh and mesh.release then
    pcall(function()
      mesh:release()
    end)
  end
end

local function release_tray_draw_calls(draw_calls)
  if not draw_calls then
    return
  end
  for i = 1, #draw_calls do
    safe_release_mesh(draw_calls[i].mesh)
  end
end

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

function render.board(image, light_fn, x1, x2, y1, y2)
  x1 = x1 or -10; x2 = x2 or 10; y1 = y1 or -10; y2 = y2 or 10

  render.board_extents = {x1,x2,y1,y2}

  local subdiv = 8
  
  local tex_path = image(0, 0)
  local tex = graphics_get_image(tex_path)

  local l = light_fn(vector{(x1+x2)/2, (y1+y2)/2}, vector{0,0,1})
  local r, g, b = l, l, l
  local view_sig = current_view_signature()
  local light_sig = current_light_signature()
  local key = table.concat({
    "board",
    tex_path,
    tostring(subdiv),
    fmt4(x1), fmt4(x2), fmt4(y1), fmt4(y2),
    fmt4(r), fmt4(g), fmt4(b),
    view_sig,
    light_sig,
  }, "|")

  if board_mesh_cache.key ~= key then
    safe_release_mesh(board_mesh_cache.mesh)

    local vertices = {}
    local stepX = (x2 - x1) / subdiv
    local stepY = (y2 - y1) / subdiv
    local stepU = 1 / subdiv
    local stepV = 1 / subdiv

    for j = 0, subdiv - 1 do
      for i = 0, subdiv - 1 do
        local wx1 = x1 + i * stepX
        local wx2 = x1 + (i + 1) * stepX
        local wy1 = y1 + j * stepY
        local wy2 = y1 + (j + 1) * stepY

        local cu1 = i * stepU
        local cu2 = (i + 1) * stepU
        local cv1 = j * stepV
        local cv2 = (j + 1) * stepV

        local p1 = {view.project(wx1, wy1, 0)}
        local p2 = {view.project(wx2, wy1, 0)}
        local p3 = {view.project(wx2, wy2, 0)}
        local p4 = {view.project(wx1, wy2, 0)}

        table.insert(vertices, {p1[1], p1[2], cu1, cv1, r, g, b, 1})
        table.insert(vertices, {p2[1], p2[2], cu2, cv1, r, g, b, 1})
        table.insert(vertices, {p3[1], p3[2], cu2, cv2, r, g, b, 1})
        table.insert(vertices, {p1[1], p1[2], cu1, cv1, r, g, b, 1})
        table.insert(vertices, {p3[1], p3[2], cu2, cv2, r, g, b, 1})
        table.insert(vertices, {p4[1], p4[2], cu1, cv2, r, g, b, 1})
      end
    end

    local mesh = love.graphics.newMesh(vertices, "triangles", "stream")
    mesh:setTexture(tex)

    local c1 = {view.project(x1, y1, 0)}
    local c2 = {view.project(x2, y1, 0)}
    local c3 = {view.project(x2, y2, 0)}
    local c4 = {view.project(x1, y2, 0)}

    board_mesh_cache.key = key
    board_mesh_cache.mesh = mesh
    board_mesh_cache.corners = {
      {c1[1], c1[2]},
      {c2[1], c2[2]},
      {c3[1], c3[2]},
      {c4[1], c4[2]},
    }
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(board_mesh_cache.mesh)
  return board_mesh_cache.corners
end


function render.bulb(action)
  local x,y,z,s=view.project(unpack(light-{0,0,2}))
  action(z,function()
    love.graphics.setBlendMode("add")
    love.graphics.setColor(255,255,255)
    love.graphics.draw(graphics_get_image("resources/ui/bulb.png"),x,y,0,s/64,s/64)
    love.graphics.circle("line",x,y,s/5,40)
    love.graphics.setBlendMode("alpha")
  end)
end

function render.die(action, die, body)
  local cam={view.get()}
  local projected={}
  for i=1,#body do
    table.insert(projected, {view.project(unpack(body[i]+body.position))})
  end

  for i=1,#die.faces do
    local face=die.faces[i]
    local xy,z,c={},0,vector()
    for j=1,#face do
      c=c+body[face[j]]
      local p = projected[face[j]]
      table.insert(xy,p[1])
      table.insert(xy,p[2])
      z=z+p[3]
    end
    z=z/#face
    c=c/#face
    
    local strength=die.material(c+body.position, c:norm())
    local baseColor = (die.faceColors and die.faceColors[i]) or die.color
    local color={ baseColor[1]*strength, baseColor[2]*strength, baseColor[3]*strength, baseColor[4] or 255 }
    local text={die.text[1]*strength,die.text[2]*strength,die.text[3]*strength}
    local front=c..(1*c+body.position-cam)<=0
    action(z, function()
      if front then 
        love.graphics.setColor(unpack(color))
        love.graphics.polygon("fill",unpack(xy))
        love.graphics.setColor(unpack(text))
        die.image(i,unpack(xy))
      elseif color[4] and color[4]<255 then
        love.graphics.setColor(unpack(text))
        die.image(i,unpack(xy))
        love.graphics.setColor(unpack(color))
        love.graphics.polygon("fill",unpack(xy))
      end
    end) 
  end

  
end


function render.shadow(action,die, body)
  
  local cast={}
  for i=1,#body do
    local x,y=light.cast(body[i]+body.position)
    if not x then return end
    table.insert(cast,vector{x,y})
  end
    
  local hull={cast[1]}
  for i=1,#cast do if cast[i][1]<hull[1][1] then hull[1]=cast[i] end end
  
  repeat
    local point=hull[#hull]
    local endpoint=cast[1]
    if point==endpoint then endpoint=cast[2] end
    
    for i=1,#cast do
      local left = endpoint-point
      left[1],left[2]=left[2],-left[1]
      local diff=cast[i]-endpoint
      if diff..left>0 then
        endpoint=cast[i]
      end
    end
    hull[#hull+1]=endpoint
    if #hull>#cast+1 then return end
  until hull[1]==hull[#hull]
  if #hull<3 then return end
  
  action(0,function()
    love.graphics.setColor(unpack(die.shadow))
    love.graphics.polygon("fill",hull)
  end)
end  

function render.stencil_board_area(border_height)
  border_height = border_height or 1.5
  local x1,x2,y1,y2 = -10,10,-10,10
  if render.board_extents then x1,x2,y1,y2 = unpack(render.board_extents) end
  
  local floor = {
    {view.project(x1,y1,0)},
    {view.project(x2,y1,0)},
    {view.project(x2,y2,0)},
    {view.project(x1,y2,0)}
  }
  
  local inner_top = {
    {view.project(x1, y1, border_height)},
    {view.project(x2, y1, border_height)},
    {view.project(x2, y2, border_height)},
    {view.project(x1, y2, border_height)}
  }
  
  love.graphics.polygon("fill", 
    floor[1][1], floor[1][2],
    floor[2][1], floor[2][2],
    floor[3][1], floor[3][2],
    floor[4][1], floor[4][2])
  
  love.graphics.polygon("fill",
    floor[1][1], floor[1][2],
    floor[2][1], floor[2][2],
    inner_top[2][1], inner_top[2][2],
    inner_top[1][1], inner_top[1][2])
  love.graphics.polygon("fill",
    floor[2][1], floor[2][2],
    floor[3][1], floor[3][2],
    inner_top[3][1], inner_top[3][2],
    inner_top[2][1], inner_top[2][2])
  love.graphics.polygon("fill",
    floor[3][1], floor[3][2],
    floor[4][1], floor[4][2],
    inner_top[4][1], inner_top[4][2],
    inner_top[3][1], inner_top[3][2])
  love.graphics.polygon("fill",
    floor[4][1], floor[4][2],
    floor[1][1], floor[1][2],
    inner_top[1][1], inner_top[1][2],
    inner_top[4][1], inner_top[4][2])
end

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
  
  local left_idx=1
  for i=2,4 do if corners[i][1]<corners[left_idx][1] then left_idx=i end end
  
  local n,p,o= corners[cycle(left_idx+1,4)], corners[cycle(left_idx-1,4)], corners[cycle(left_idx+2,4)]
  local m = corners[left_idx]
  
  if n[2]>p[2] then n,p=p,n end
  
  love.graphics.polygon("fill", -100,m[2], m[1],m[2], n[1],n[2], n[1],-100, -100,-100)
  love.graphics.polygon("fill", n[1],-100, n[1],n[2], o[1],o[2], 100,o[2], 100, -100)
  love.graphics.polygon("fill", 100,o[2], o[1],o[2], p[1],p[2], p[1],100, 100,100)
  love.graphics.polygon("fill", p[1],100, p[1],p[2], m[1],m[2], -100,m[2], -100,100)
  
end

function render.tray_border(action, border_width, border_height, border_color)
  if type(action) ~= "function" then
    border_color = border_height
    border_height = border_width
    border_width = action
    action = function(z, fn) fn() end
  end
  
  border_width = border_width or 0.8
  border_height = border_height or 1.2
  border_color = border_color or {90, 56, 31}
  
  local x1, x2, y1, y2 = -10, 10, -10, 10
  if render.board_extents then x1, x2, y1, y2 = unpack(render.board_extents) end
  
  local ox1, ox2, oy1, oy2 = x1 - border_width, x2 + border_width, y1 - border_width, y2 + border_width
  
  local segments = 8
  
  local view_sig = current_view_signature()
  
  local function lerp(a, b, t) return a + (b - a) * t end
  
  if not tray_wood_texture then
    local ok, img = pcall(love.graphics.newImage, "resources/textures/wood.png")
    if ok then tray_wood_texture = img end
  end
  
  local tex = tray_wood_texture
  local key = table.concat({
    "tray-border",
    fmt4(x1), fmt4(x2), fmt4(y1), fmt4(y2),
    fmt4(border_width), fmt4(border_height),
    fmt4(border_color[1]), fmt4(border_color[2]), fmt4(border_color[3]),
    tostring(segments),
    tex and "tex:1" or "tex:0",
    view_sig,
  }, "|")

  if tray_border_cache.key ~= key then
    release_tray_draw_calls(tray_border_cache.draw_calls)
    local draw_calls = {}

    local function draw_quad(c1, c2, c3, c4, color, shade)
      local z_min = math.min(c1[3], c2[3], c3[3], c4[3])
      table.insert(draw_calls, {
        z = z_min,
        points = {c1[1], c1[2], c2[1], c2[2], c3[1], c3[2], c4[1], c4[2]},
        color = {color[1] * shade, color[2] * shade, color[3] * shade, 255},
      })
    end

    local function draw_textured_quad(c1, c2, c3, c4, color, shade, texture, u1, v1, u2, v2)
      u1 = u1 or 0; v1 = v1 or 0; u2 = u2 or 1; v2 = v2 or 1
      local z_min = math.min(c1[3], c2[3], c3[3], c4[3])
      local r, g, b = color[1] * shade / 255, color[2] * shade / 255, color[3] * shade / 255
      local vertices = {
        {c1[1], c1[2], u1, v1, r, g, b, 1},
        {c2[1], c2[2], u2, v1, r, g, b, 1},
        {c3[1], c3[2], u2, v2, r, g, b, 1},
        {c4[1], c4[2], u1, v2, r, g, b, 1},
      }
      local mesh = love.graphics.newMesh(vertices, "fan", "stream")
      mesh:setTexture(texture)
      table.insert(draw_calls, {
        z = z_min,
        mesh = mesh,
      })
    end

    local function draw_wall_tessellated(ax_in, ay_in, bx_in, by_in, ax_out, ay_out, bx_out, by_out, z_bot, z_top, color, shade, texture)
      for i = 0, segments - 1 do
        local t1 = i / segments
        local t2 = (i + 1) / segments

        local ox1_seg, oy1_seg = lerp(ax_out, bx_out, t1), lerp(ay_out, by_out, t1)
        local ox2_seg, oy2_seg = lerp(ax_out, bx_out, t2), lerp(ay_out, by_out, t2)

        local tu1, tu2 = t1, t2

        if texture then
          local p1 = {view.project(ox1_seg, oy1_seg, z_bot)}
          local p2 = {view.project(ox2_seg, oy2_seg, z_bot)}
          local p3 = {view.project(ox2_seg, oy2_seg, z_top)}
          local p4 = {view.project(ox1_seg, oy1_seg, z_top)}
          draw_textured_quad(p1, p2, p3, p4, color, shade, texture, tu1, 1, tu2, 0)
        else
          local p1 = {view.project(ox1_seg, oy1_seg, z_bot)}
          local p2 = {view.project(ox2_seg, oy2_seg, z_bot)}
          local p3 = {view.project(ox2_seg, oy2_seg, z_top)}
          local p4 = {view.project(ox1_seg, oy1_seg, z_top)}
          draw_quad(p1, p2, p3, p4, color, shade)
        end
      end
    end

    local function draw_inner_wall_tessellated(ax, ay, bx, by, z_bot, z_top, color, shade, texture)
      for i = 0, segments - 1 do
        local t1 = i / segments
        local t2 = (i + 1) / segments

        local px1, py1 = lerp(ax, bx, t1), lerp(ay, by, t1)
        local px2, py2 = lerp(ax, bx, t2), lerp(ay, by, t2)

        local u1, u2 = t1, t2

        local p1 = {view.project(px2, py2, z_bot)}
        local p2 = {view.project(px1, py1, z_bot)}
        local p3 = {view.project(px1, py1, z_top)}
        local p4 = {view.project(px2, py2, z_top)}

        if texture then
          draw_textured_quad(p1, p2, p3, p4, color, shade, texture, u2, 1, u1, 0)
        else
          draw_quad(p1, p2, p3, p4, color, shade)
        end
      end
    end

    local function draw_rim_tessellated(ax_in, ay_in, bx_in, by_in, ax_out, ay_out, bx_out, by_out, z, color, shade, texture)
      for i = 0, segments - 1 do
        local t1 = i / segments
        local t2 = (i + 1) / segments

        local ix1, iy1 = lerp(ax_in, bx_in, t1), lerp(ay_in, by_in, t1)
        local ix2, iy2 = lerp(ax_in, bx_in, t2), lerp(ay_in, by_in, t2)
        local ox1_seg, oy1_seg = lerp(ax_out, bx_out, t1), lerp(ay_out, by_out, t1)
        local ox2_seg, oy2_seg = lerp(ax_out, bx_out, t2), lerp(ay_out, by_out, t2)

        local p1 = {view.project(ox1_seg, oy1_seg, z)}
        local p2 = {view.project(ox2_seg, oy2_seg, z)}
        local p3 = {view.project(ix2, iy2, z)}
        local p4 = {view.project(ix1, iy1, z)}

        if texture then
          draw_textured_quad(p1, p2, p3, p4, color, shade, texture, t1, 0, t2, 1)
        else
          draw_quad(p1, p2, p3, p4, color, shade)
        end
      end
    end

    draw_wall_tessellated(x1, y1, x2, y1, ox1, oy1, ox2, oy1, 0, border_height, border_color, tex and 180 or 0.7, tex)
    draw_wall_tessellated(x2, y1, x2, y2, ox2, oy1, ox2, oy2, 0, border_height, border_color, tex and 220 or 0.85, tex)
    draw_wall_tessellated(x2, y2, x1, y2, ox2, oy2, ox1, oy2, 0, border_height, border_color, tex and 255 or 1.0, tex)
    draw_wall_tessellated(x1, y2, x1, y1, ox1, oy2, ox1, oy1, 0, border_height, border_color, tex and 190 or 0.75, tex)

    draw_inner_wall_tessellated(x1, y1, x2, y1, 0, border_height, border_color, tex and 130 or 0.5, tex)
    draw_inner_wall_tessellated(x2, y1, x2, y2, 0, border_height, border_color, tex and 140 or 0.55, tex)
    draw_inner_wall_tessellated(x2, y2, x1, y2, 0, border_height, border_color, tex and 150 or 0.6, tex)
    draw_inner_wall_tessellated(x1, y2, x1, y1, 0, border_height, border_color, tex and 130 or 0.5, tex)

    draw_rim_tessellated(x1, y1, x2, y1, ox1, oy1, ox2, oy1, border_height, border_color, tex and 230 or 0.9, tex)
    draw_rim_tessellated(x2, y1, x2, y2, ox2, oy1, ox2, oy2, border_height, border_color, tex and 240 or 0.95, tex)
    draw_rim_tessellated(x2, y2, x1, y2, ox2, oy2, ox1, oy2, border_height, border_color, tex and 255 or 1.0, tex)
    draw_rim_tessellated(x1, y2, x1, y1, ox1, oy2, ox1, oy1, border_height, border_color, tex and 225 or 0.88, tex)

    tray_border_cache.key = key
    tray_border_cache.draw_calls = draw_calls
  end

  local draw_calls = tray_border_cache.draw_calls or {}
  for i = 1, #draw_calls do
    local call = draw_calls[i]
    action(call.z, function()
      if call.mesh then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(call.mesh)
      else
        love.graphics.setColor(call.color)
        love.graphics.polygon("fill", unpack(call.points))
      end
    end)
  end
end

