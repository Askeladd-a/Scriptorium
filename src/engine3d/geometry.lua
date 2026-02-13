require "core"
require "src.engine3d.physics"

local graphics_get_image = rawget(love.graphics, "getImage") or love.graphics.newImage
local graphics_transform = rawget(love.graphics, "transform")

---@diagnostic disable-next-line: lowercase-global
function newD6Body(size)
  if not size then size=1 end
  size=size/1.6
  local new={ {size,size,size}, {size,-size,size}, {-size,-size,size}, {-size,size,size},
              {size,size,-size}, {size,-size,-size}, {-size,-size,-size}, {-size,size,-size} }
  local b = clone(body,new):set(nil,nil,nil,size*size*size*2,size*size*size*2)
  b.flat_face_vertices = 4
  b.flat_z_tolerance = 0.03
  b.settle_linear = 0.20
  b.settle_angular = 0.15
  return b
end
---@diagnostic disable-next-line: lowercase-global
d6= {
  faces={{1,2,3,4}, {5,6,7,8}, {1,2,6,5},{2,3,7,6},{3,4,8,7},{4,1,5,8}},
  faceValueMap = {1, 6, 3, 5, 4, 2}
}
d6.pipMap = d6.faceValueMap

function d6.image(n,a,b,c,d,e,f,g,h)
  if n>6 then return end
  if not (a and b and c and d and g and h) then return end
  local pip = d6.faceValueMap[n] or n
  local img=graphics_get_image("resources/dice/"..pip..".png")
  love.graphics.push()
  if graphics_transform then
    local ok = graphics_transform(a,b,c,d,g,h)
    if not ok then
      love.graphics.pop()
      return
    end
  end
  love.graphics.draw(img,0,0,0,1/img:getWidth(),1/img:getHeight())
  love.graphics.pop()
end

---@diagnostic disable-next-line: lowercase-global
function newD8Body(size)
  if not size then size=1 end
  local new={
    { size, 0, 0},
    {0, -size, 0},
    {-size, 0, 0},
    {0, size, 0},
    {0, 0, -size},
    {0, 0, size},
  }
  local b = clone(body,new):set(nil,nil,nil,size*size*size/2,size*size*size/2)
  b.flat_face_vertices = 3
  b.flat_z_tolerance = 0.045
  b.settle_linear = 0.24
  b.settle_angular = 0.24
  return b
end

---@diagnostic disable-next-line: lowercase-global
d8 = {
  faces = {
    {5,2,1}, {6,1,2}, {5,3,2}, {6,2,3},
    {5,4,3}, {6,3,4}, {5,1,4}, {6,4,1},
  },
  faceValueMap = {1, 2, 3, 4, 5, 6, 7, 8},
  -- Requested order: red, blue, green, yellow, black, brown, white, purple.
  -- File mapping in resources/dice:
  -- R=rosso, A=azzurro(blu), V=verde, G=giallo, N=nero, M=marrone, B=bianco, P=viola.
  faceImageMap = {"R", "A", "V", "G", "N", "M", "B", "P"},
}

local d8_mesh_cache = {}

local function d8_get_mesh(image_key, image)
  local entry = d8_mesh_cache[image_key]
  if not entry then
    local mesh = love.graphics.newMesh({
      {0, 0, 0.5, 0.0},
      {0, 0, 1.0, 1.0},
      {0, 0, 0.0, 1.0},
    }, "triangles", "stream")
    mesh:setTexture(image)
    entry = {mesh = mesh}
    d8_mesh_cache[image_key] = entry
  else
    entry.mesh:setTexture(image)
  end
  return entry.mesh
end

function d8.image(n,a,b,c,d,e,f)
  if n>8 then return end
  if not (a and b and c and d and e and f) then return end

  local key = d8.faceImageMap[n]
  if not key then return end

  local img = graphics_get_image("resources/dice/" .. key .. ".png")
  local mesh = d8_get_mesh(key, img)
  mesh:setVertices({
    {a, b, 0.5, 0.0},
    {c, d, 1.0, 1.0},
    {e, f, 0.0, 1.0},
  })

  local pr, pg, pb, pa = love.graphics.getColor()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(mesh)
  if love.graphics.flushBatch then
    love.graphics.flushBatch()
  end
  love.graphics.setColor(pr, pg, pb, pa)
end
