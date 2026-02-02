
config = {
  boardimage=nil,
  boardlight=light.metal
}

function config.boardimage(x,y)
  if (x+y)%2==1 then return "resources/marble2.png"
  else return "resources/marble.png" end
end
