
config = {
  boardimage=nil,
  boardlight=light.metal,
  render_backend="g3d"
}

function config.boardimage(x,y)
  if (x+y)%2==1 then return "default/marble2.png"
  else return "default/marble.png" end
end
