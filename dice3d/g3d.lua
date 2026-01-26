-- Minimal g3d compatibility shim for this project.
-- This provides enough of the g3d API used by render_g3d.lua to draw
-- the dice and tray using the existing projection helpers in view.lua.
-- Replace this file with the real g3d.lua for full 3D rendering.

require "vector"
local vector = _G.vector

local g3d = {}

local model_cache = {}

local function read_file(path)
  if love and love.filesystem and love.filesystem.read then
    return love.filesystem.read(path)
  end
  local file = io.open(path, "r")
  if not file then return nil end
  local data = file:read("*a")
  file:close()
  return data
end

local function parse_obj(path)
  if model_cache[path] then return model_cache[path] end
  local data = read_file(path)
  if not data then
    model_cache[path] = { vertices = {}, faces = {} }
    return model_cache[path]
  end

  local vertices = {}
  local faces = {}

  for line in data:gmatch("[^\r\n]+") do
    local head, rest = line:match("^(%S+)%s+(.+)$")
    if head == "v" then
      local x, y, z = rest:match("([^%s]+)%s+([^%s]+)%s+([^%s]+)")
      vertices[#vertices + 1] = { tonumber(x), tonumber(y), tonumber(z) }
    elseif head == "f" then
      local face = {}
      for v in rest:gmatch("%S+") do
        local idx = v:match("^(%d+)")
        if idx then face[#face + 1] = tonumber(idx) end
      end
      if #face >= 3 then faces[#faces + 1] = face end
    end
  end

  model_cache[path] = { vertices = vertices, faces = faces }
  return model_cache[path]
end

local function rotate_vertex(v, rx, ry, rz)
  local x, y, z = v[1], v[2], v[3]
  local cx, sx = math.cos(rx), math.sin(rx)
  local cy, sy = math.cos(ry), math.sin(ry)
  local cz, sz = math.cos(rz), math.sin(rz)

  local y1 = y * cx - z * sx
  local z1 = y * sx + z * cx
  y, z = y1, z1

  local x2 = x * cy + z * sy
  local z2 = -x * sy + z * cy
  x, z = x2, z2

  local x3 = x * cz - y * sz
  local y3 = x * sz + y * cz
  return { x3, y3, z }
end

local function vec_sub(a, b)
  return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function vec_cross(a, b)
  return {
    a[2] * b[3] - a[3] * b[2],
    a[3] * b[1] - a[1] * b[3],
    a[1] * b[2] - a[2] * b[1]
  }
end

local function vec_norm(v)
  local len = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
  if len == 0 then return vector { 0, 0, 1 } end
  return vector { v[1] / len, v[2] / len, v[3] / len }
end

local function get_default_color(texture_path)
  if texture_path and texture_path:find("marble") then
    return { 0.65, 0.65, 0.68, 1 }
  end
  return { 0.92, 0.92, 0.95, 1 }
end

function g3d.newCamera(x, y, z, lookx, looky, lookz)
  return {
    position = { x or 0, y or 0, z or 0 },
    lookAt = { lookx or 0, looky or 0, lookz or 0 }
  }
end

local Model = {}
Model.__index = Model

function Model:setTranslation(x, y, z)
  self.position = { x, y, z }
end

function Model:setRotation(rx, ry, rz)
  self.rotation = { rx, ry, rz }
end

function Model:draw(_camera)
  if not love or not love.graphics then return end
  local view = _G.view
  if not view or not view.project then return end

  local mesh = self.mesh
  if not mesh or #mesh.vertices == 0 then return end

  local rx, ry, rz = self.rotation[1], self.rotation[2], self.rotation[3]
  local sx, sy, sz = self.scale[1], self.scale[2], self.scale[3]
  local px, py, pz = self.position[1], self.position[2], self.position[3]

  local transformed = {}
  for i, v in ipairs(mesh.vertices) do
    local scaled = { v[1] * sx, v[2] * sy, v[3] * sz }
    local rotated = rotate_vertex(scaled, rx, ry, rz)
    transformed[i] = { rotated[1] + px, rotated[2] + py, rotated[3] + pz }
  end

  local faces = {}
  for _, face in ipairs(mesh.faces) do
    local zsum = 0
    local pts = {}
    for _, idx in ipairs(face) do
      local world = transformed[idx]
      local fx, fy, fz, _ = view.project(world[1], world[2], world[3])
      pts[#pts + 1] = { fx, fy, fz, world }
      zsum = zsum + fz
    end
    faces[#faces + 1] = { z = zsum / #face, points = pts }
  end

  table.sort(faces, function(a, b) return a.z < b.z end)

  for _, face in ipairs(faces) do
    local poly = {}
    for _, p in ipairs(face.points) do
      poly[#poly + 1] = p[1]
      poly[#poly + 1] = p[2]
    end

    local v1 = vector(face.points[1][4])
    local v2 = vector(face.points[2][4])
    local v3 = vector(face.points[3][4])
    local normal = vec_norm(vec_cross(vec_sub(v2, v1), vec_sub(v3, v1)))

    local light_strength = 1
    if _G.light and _G.light.generic then
      light_strength = _G.light.generic(0.9, 0.0, true, v1, normal)
    end

    local color = {
      self.color[1] * light_strength,
      self.color[2] * light_strength,
      self.color[3] * light_strength,
      self.color[4]
    }
    love.graphics.setColor(color)
    love.graphics.polygon("fill", table.unpack(poly))
  end
end

function g3d.newModel(obj_path, texture_path, position, rotation, scale)
  local model = setmetatable({}, Model)
  model.obj = obj_path
  model.texture_path = texture_path
  model.mesh = parse_obj(obj_path)
  model.position = position or { 0, 0, 0 }
  model.rotation = rotation or { 0, 0, 0 }
  model.scale = scale or { 1, 1, 1 }
  model.color = get_default_color(texture_path)
  return model
end

return g3d
