require "core"
require "src.engine3d.physics"

function newD6star(size)
  if not size then size=1 end
  size=size/1.6
  local new={ {size,size,size}, {size,-size,size}, {-size,-size,size}, {-size,size,size},
              {size,size,-size}, {size,-size,-size}, {-size,-size,-size}, {-size,size,-size} }
  return clone(star,new):set(nil,nil,nil,size*size*size*2,size*size*size*2)
end
---@diagnostic disable-next-line: lowercase-global
d6= {
  faces={{1,2,3,4}, {5,6,7,8}, {1,2,6,5},{2,3,7,6},{3,4,8,7},{4,1,5,8}},
  -- Mapping faccia geometrica -> valore pip per dado standard (right-handed)
  -- Facce opposte sommano a 7: 1↔6, 2↔5, 3↔4
  pipMap = {1, 6, 3, 5, 4, 2}  -- face 1=1pip, face 2=6pip, face 3=3pip, etc.
}
function d6.image(n,a,b,c,d,e,f,g,h)
  if n>6 then return end
  -- Usa il mapping per caricare la texture corretta
  local pip = d6.pipMap[n] or n
  local img=love.graphics.getImage("resources/dice/"..pip..".png")
  love.graphics.push()
  love.graphics.transform(a,b,c,d,g,h)
  love.graphics.draw(img,0,0,0,1/img:getWidth(),1/img:getHeight())
  love.graphics.pop()
end
