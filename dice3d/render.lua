
render={}
render.shader=nil
render.mesh=nil
render.vertexFormat=nil

local function ensure_shader()
  if render.shader then return end
  render.shader = love.graphics.newShader [[
    uniform mat4 projectionMatrix;
    uniform mat4 modelMatrix;
    uniform mat4 viewMatrix;

    varying vec4 vertexColor;

    #ifdef VERTEX
        vec4 position(mat4 transform_projection, vec4 vertex_position)
        {
            vertexColor = VertexColor;
            return projectionMatrix * viewMatrix * modelMatrix * vertex_position;
        }
    #endif

    #ifdef PIXEL
        vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 pixcoord)
        {
            vec4 texcolor = Texel(tex, vec2(texcoord.x, 1-texcoord.y));
            if (texcolor.a == 0.0) { discard; }
            return vec4(texcolor)*color*vertexColor;
        }
    #endif
  ]]
  render.vertexFormat = {
    {"VertexPosition", "float", 3},
    {"VertexTexCoord", "float", 2},
    {"VertexColor", "byte", 4},
  }
  render.mesh = love.graphics.newMesh(render.vertexFormat, 6, "triangles", "dynamic")
  love.graphics.setDepthMode("lequal", true)
end

function render.begin3d()
  ensure_shader()
  local proj, viewm = view.get_matrices()
  render.shader:send("projectionMatrix", proj)
  render.shader:send("viewMatrix", viewm)
  render.shader:send("modelMatrix", {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1})
  love.graphics.setShader(render.shader)
end

function render.end3d()
  love.graphics.setShader()
end

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
draw={}


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

  render.begin3d()
  for x=x1,x2-1 do
    for y=y1,y2-1 do
      local l=light(vector{x,y}, vector{0,0,1})
      local color = {255*l,255*l,255*l,255}
      local tex = love.graphics.getImage(image(x,y))
      local v1 = {x, y, 0}
      local v2 = {x+1, y, 0}
      local v3 = {x+1, y+1, 0}
      local v4 = {x, y+1, 0}
      render.mesh:setTexture(tex)
      render.mesh:setVertices({
        {v1[1], v1[2], v1[3], 0, 0, unpack(color)},
        {v2[1], v2[2], v2[3], 1, 0, unpack(color)},
        {v3[1], v3[2], v3[3], 1, 1, unpack(color)},
        {v1[1], v1[2], v1[3], 0, 0, unpack(color)},
        {v3[1], v3[2], v3[3], 1, 1, unpack(color)},
        {v4[1], v4[2], v4[3], 0, 1, unpack(color)},
      })
      love.graphics.draw(render.mesh)
    end
  end
  render.end3d()
  return {points[x1][y1], points[x2][y1], points[x2][y2], points[x1][y2]}
end


--draws the lightbulb
function render.bulb(action)
  local x,y,z,s=view.project(unpack(light-{0,0,2}))
  action(z,function()
    love.graphics.setBlendMode("add")
    love.graphics.setColor(255,255,255)
    love.graphics.draw(love.graphics.getImage("default/bulb.png"),x,y,0,s/96,s/96)
    --[[    love.graphics.circle("fill",x,y,s/5,40)
    love.graphics.circle("line",x,y,s/5,40)
    ]]
    love.graphics.setBlendMode("alpha")
  end)
end

--draws a die complete with lighting and projection
function render.die(action, die, star)
  local cam={view.get()}
  local faces = {}
  for i=1,#die.faces do
    local face=die.faces[i]
    local c=vector()
    for j=1,#face do
      c=c+star[face[j]]
    end
    c=c/#face
    local strength=die.material(c+star.position, c:norm())
    local color={ die.color[1]*strength, die.color[2]*strength, die.color[3]*strength, die.color[4] or 255 }
    local front=c..(1*c+star.position-cam)<=0
    if front or (color[4] and color[4]<255) then
      local tex = love.graphics.getImage("textures/"..i..".png")
      local verts = nil
      if #face == 3 then
        local v1 = star[face[1]] + star.position
        local v2 = star[face[2]] + star.position
        local v3 = star[face[3]] + star.position
        verts = {
          {v1[1], v1[2], v1[3], 0, 0, unpack(color)},
          {v2[1], v2[2], v2[3], 1, 0, unpack(color)},
          {v3[1], v3[2], v3[3], 0.5, 1, unpack(color)},
          {v1[1], v1[2], v1[3], 0, 0, unpack(color)},
          {v2[1], v2[2], v2[3], 1, 0, unpack(color)},
          {v3[1], v3[2], v3[3], 0.5, 1, unpack(color)},
        }
      else
        local v1 = star[face[1]] + star.position
        local v2 = star[face[2]] + star.position
        local v3 = star[face[3]] + star.position
        local v4 = star[face[4]] + star.position
        verts = {
          {v1[1], v1[2], v1[3], 0, 0, unpack(color)},
          {v2[1], v2[2], v2[3], 1, 0, unpack(color)},
          {v3[1], v3[2], v3[3], 1, 1, unpack(color)},
          {v1[1], v1[2], v1[3], 0, 0, unpack(color)},
          {v3[1], v3[2], v3[3], 1, 1, unpack(color)},
          {v4[1], v4[2], v4[3], 0, 1, unpack(color)},
        }
      end
      table.insert(faces, {texture = tex, vertices = verts})
    end
  end
  action(0, function()
    if #faces == 0 then return end
    render.begin3d()
    for _,face in ipairs(faces) do
      render.mesh:setTexture(face.texture)
      render.mesh:setVertices(face.vertices)
      love.graphics.draw(render.mesh)
    end
    render.end3d()
  end)
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
  
  local w = love.graphics.getWidth()
  local h = love.graphics.getHeight()
  local left = -w
  local right = w * 2
  local top = -h
  local bottom = h * 2

  local m=1 --m is the leftmost corner
  for i=2,4 do if corners[i][1]<corners[m][1] then m=i end end
  
  --n(ext), p(rev), o(ther),m(in) are the four corners
  local n,p,o= corners[math.cycle(m+1,4)], corners[math.cycle(m-1,4)], corners[math.cycle(m+2,4)]
  m=corners[m]
  
  --we ecpect n(ext) to be the clockwise next from m(in)
  if n[2]>p[2] then n,p=p,n end
  
  love.graphics.polygon("fill", left,m[2], m[1],m[2], n[1],n[2], n[1],top, left,top)
  love.graphics.polygon("fill", n[1],top, n[1],n[2], o[1],o[2], right,o[2], right, top)
  love.graphics.polygon("fill", right,o[2], o[1],o[2], p[1],p[2], p[1],bottom, right,bottom)
  love.graphics.polygon("fill", p[1],bottom, p[1],p[2], m[1],m[2], left,m[2], left,bottom)
  
end

