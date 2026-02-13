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
  return clone(body,new):set(nil,nil,nil,size*size*size*2,size*size*size*2)
end
---@diagnostic disable-next-line: lowercase-global
d6= {
  faces={{1,2,3,4}, {5,6,7,8}, {1,2,6,5},{2,3,7,6},{3,4,8,7},{4,1,5,8}},
  pipMap = {1, 6, 3, 5, 4, 2}
}
function d6.image(n,a,b,c,d,e,f,g,h)
  if n>6 then return end
  local pip = d6.pipMap[n] or n
  local img=graphics_get_image("resources/dice/"..pip..".png")
  love.graphics.push()
  if graphics_transform then
    graphics_transform(a,b,c,d,g,h)
  end
  love.graphics.draw(img,0,0,0,1/img:getWidth(),1/img:getHeight())
  love.graphics.pop()
end
