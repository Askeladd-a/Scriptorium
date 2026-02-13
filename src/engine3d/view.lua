
view={
  yaw=1.2,
  pitch=1.2,
  distance=12,
  focus=5
}
view.cos_pitch, view.sin_pitch=math.cos(view.pitch), math.sin(view.pitch)
view.cos_yaw, view.sin_yaw=math.cos(view.yaw), math.sin(view.yaw)

local function clamp(value, min_v, max_v)
  if value < min_v then return min_v end
  if value > max_v then return max_v end
  return value
end

function view.raise(delta)
  view.pitch=clamp(view.pitch-delta,0.1,1.5)
  view.cos_pitch,view.sin_pitch=math.cos(view.pitch), math.sin(view.pitch)
end
function view.turn(delta)
  view.yaw=view.yaw-delta
  view.cos_yaw,view.sin_yaw=math.cos(view.yaw), math.sin(view.yaw)
end
function view.move(delta)
  view.distance=clamp(view.distance*delta,20,100)
end

function view.project(x,y,z)
  local v=view
  x,y= v.cos_yaw*x-v.sin_yaw*y, v.sin_yaw*x+v.cos_yaw*y
  y,z = v.cos_pitch*y-v.sin_pitch*z, v.sin_pitch*y+v.cos_pitch*z
  z = view.distance-z
  local p=view.focus/z
  if p<0 then p=1000 end
  return x*p, y*p, -z, p
end

function view.get()
  local v,x,y,z=view,0,0,view.distance
  y,z = v.cos_pitch*y+v.sin_pitch*z, -v.sin_pitch*y+v.cos_pitch*z
  x,y= v.cos_yaw*x+v.sin_yaw*y, -v.sin_yaw*x+v.cos_yaw*y
  return x,y,z
end
