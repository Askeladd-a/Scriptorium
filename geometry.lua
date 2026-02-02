require "core"
require "physics"

function newD6star(size)
  if not size then size=1 end
  size=size/1.6
  local new={ {size,size,size}, {size,-size,size}, {-size,-size,size}, {-size,size,size},
              {size,size,-size}, {size,-size,-size}, {-size,-size,-size}, {-size,size,-size} }
  return clone(star,new):set(nil,nil,nil,size*size*size*2,size*size*size*2)
end
d6= {
  faces={{1,2,3,4}, {5,6,7,8}, {1,2,6,5},{2,3,7,6},{3,4,8,7},{4,1,5,8}}
}
function d6.image(n,a,b,c,d,e,f,g,h)
  if n>6 then return end
  local img=love.graphics.getImage("resources/"..n..".png")
  love.graphics.push()
  love.graphics.transform(a,b,c,d,g,h)
  love.graphics.draw(img,0,0,0,1/img:getWidth(),1/img:getHeight())
  love.graphics.pop()
end