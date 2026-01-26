require "base"

-- simplest_3d.lua
-- Core projection helpers adapted from groverburger/simplest_3d (Feb 2021).
-- Exposes a compatible view module for the existing 3D-Studio renderer.

----------------------------------------------------------------------------------------------------
-- simple vector library (same primitives as simplest_3d)
----------------------------------------------------------------------------------------------------

local function NormalizeVector(vector)
  local dist = math.sqrt(vector[1]^2 + vector[2]^2 + vector[3]^2)
  return {
    vector[1]/dist,
    vector[2]/dist,
    vector[3]/dist,
  }
end

local function DotProduct(a,b)
  return a[1]*b[1] + a[2]*b[2] + a[3]*b[3]
end

local function CrossProduct(a,b)
  return {
    a[2]*b[3] - a[3]*b[2],
    a[3]*b[1] - a[1]*b[3],
    a[1]*b[2] - a[2]*b[1],
  }
end

----------------------------------------------------------------------------------------------------
-- matrix helper functions
----------------------------------------------------------------------------------------------------

local function IdentityMatrix()
  return {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
end

local function GetMatrixXY(matrix, x,y)
  return matrix[x + (y-1)*4]
end

local function MatrixMult(a,b)
  local ret = {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0}

  local i = 1
  for y=1, 4 do
    for x=1, 4 do
      ret[i] = ret[i] + GetMatrixXY(a,1,y)*GetMatrixXY(b,x,1)
      ret[i] = ret[i] + GetMatrixXY(a,2,y)*GetMatrixXY(b,x,2)
      ret[i] = ret[i] + GetMatrixXY(a,3,y)*GetMatrixXY(b,x,3)
      ret[i] = ret[i] + GetMatrixXY(a,4,y)*GetMatrixXY(b,x,4)
      i = i + 1
    end
  end

  return ret
end

local function ApplyMatrix(matrix, v)
  return {
    GetMatrixXY(matrix,1,1)*v[1] + GetMatrixXY(matrix,2,1)*v[2] + GetMatrixXY(matrix,3,1)*v[3] + GetMatrixXY(matrix,4,1)*v[4],
    GetMatrixXY(matrix,1,2)*v[1] + GetMatrixXY(matrix,2,2)*v[2] + GetMatrixXY(matrix,3,2)*v[3] + GetMatrixXY(matrix,4,2)*v[4],
    GetMatrixXY(matrix,1,3)*v[1] + GetMatrixXY(matrix,2,3)*v[2] + GetMatrixXY(matrix,3,3)*v[3] + GetMatrixXY(matrix,4,3)*v[4],
    GetMatrixXY(matrix,1,4)*v[1] + GetMatrixXY(matrix,2,4)*v[2] + GetMatrixXY(matrix,3,4)*v[3] + GetMatrixXY(matrix,4,4)*v[4],
  }
end

----------------------------------------------------------------------------------------------------
-- three core matrix functions (from simplest_3d)
----------------------------------------------------------------------------------------------------

local function GetTransformationMatrix(translation, rotation, scale)
  local ret = IdentityMatrix()

  ret[4] = translation[1]
  ret[8] = translation[2]
  ret[12] = translation[3]

  local rx = IdentityMatrix()
  rx[6] = math.cos(rotation[1])
  rx[7] = -1*math.sin(rotation[1])
  rx[10] = math.sin(rotation[1])
  rx[11] = math.cos(rotation[1])
  ret = MatrixMult(ret, rx)

  local ry = IdentityMatrix()
  ry[1] = math.cos(rotation[2])
  ry[3] = math.sin(rotation[2])
  ry[9] = -math.sin(rotation[2])
  ry[11] = math.cos(rotation[2])
  ret = MatrixMult(ret, ry)

  local rz = IdentityMatrix()
  rz[1] = math.cos(rotation[3])
  rz[2] = -math.sin(rotation[3])
  rz[5] = math.sin(rotation[3])
  rz[6] = math.cos(rotation[3])
  ret = MatrixMult(ret, rz)

  local s = IdentityMatrix()
  s[1] = scale[1]
  s[6] = scale[2]
  s[11] = scale[3]
  ret = MatrixMult(ret, s)

  return ret
end

local function GetProjectionMatrix(fov, near, far, aspectRatio)
  local top = near * math.tan(fov/2)
  local bottom = -1*top
  local right = top * aspectRatio
  local left = -1*right
  return {
    2*near/(right-left), 0, (right+left)/(right-left), 0,
    0, 2*near/(top-bottom), (top+bottom)/(top-bottom), 0,
    0, 0, -1*(far+near)/(far-near), -2*far*near/(far-near),
    0, 0, -1, 0
  }
end

local function GetViewMatrix(eye, target, down)
  local z = NormalizeVector({eye[1] - target[1], eye[2] - target[2], eye[3] - target[3]})
  local x = NormalizeVector(CrossProduct(down, z))
  local y = CrossProduct(z, x)

  return {
    x[1], x[2], x[3], -1*DotProduct(x, eye),
    y[1], y[2], y[3], -1*DotProduct(y, eye),
    z[1], z[2], z[3], -1*DotProduct(z, eye),
    0, 0, 0, 1,
  }
end

----------------------------------------------------------------------------------------------------
-- view wrapper used by the existing renderer
----------------------------------------------------------------------------------------------------

local view = {
  yaw = 1.2,
  pitch = 1.2,
  distance = 20,
  focus = 5,
  fov = math.pi/2,
  near = 0.01,
  far = 1000,
}

local function recalc()
  view.cos_pitch, view.sin_pitch = math.cos(view.pitch), math.sin(view.pitch)
  view.cos_yaw, view.sin_yaw = math.cos(view.yaw), math.sin(view.yaw)
end

recalc()

local function update_matrices()
  local aspect = 1
  if love and love.graphics and love.graphics.getWidth then
    aspect = love.graphics.getWidth() / math.max(1, love.graphics.getHeight())
  end
  view.projectionMatrix = GetProjectionMatrix(view.fov, view.near, view.far, aspect)
  view.viewMatrix = GetViewMatrix({view.get()}, {0,0,0}, {0,0,1})
end

function view.raise(delta)
  view.pitch = math.bound(view.pitch - delta, 0.1, 1.5)
  recalc()
end

function view.turn(delta)
  view.yaw = view.yaw - delta
  recalc()
end

function view.move(delta)
  view.distance = math.bound(view.distance * delta, 20, 100)
end

function view.get()
  local x, y, z = 0, 0, view.distance
  y, z = view.cos_pitch * y + view.sin_pitch * z, -view.sin_pitch * y + view.cos_pitch * z
  x, y = view.cos_yaw * x + view.sin_yaw * y, -view.sin_yaw * x + view.cos_yaw * y
  return x, y, z
end

function view.project(x, y, z)
  update_matrices()
  local camera = ApplyMatrix(view.viewMatrix, {x, y, z, 1})
  local clip = ApplyMatrix(view.projectionMatrix, camera)
  local w = clip[4]
  if w == 0 then w = 0.000001 end
  local ndc_x = clip[1] / w
  local ndc_y = clip[2] / w
  local depth = -camera[3]
  if depth == 0 then depth = 0.000001 end
  local width = 1
  if love and love.graphics and love.graphics.getWidth then
    width = love.graphics.getWidth()
  end
  local p = (view.focus / depth) * (width / 2)
  if p < 0 then p = 1000 end
  local height = width
  if love and love.graphics and love.graphics.getHeight then
    height = love.graphics.getHeight()
  end
  local screen_x = (ndc_x + 1) * 0.5 * width
  local screen_y = (1 - ndc_y) * 0.5 * height
  return screen_x, screen_y, depth, p
end

function view.get_matrices()
  update_matrices()
  return view.projectionMatrix, view.viewMatrix
end

return view
