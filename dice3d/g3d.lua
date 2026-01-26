-- Minimal g3d compatibility shim for this project.
-- This provides just enough of the g3d API used by render_g3d.lua
-- so the game can run without requiring the external g3d.lua file.
-- If you want full g3d features, replace this file with the real library.

local g3d = {}

local function load_texture(path)
  if love and love.filesystem and love.filesystem.getInfo then
    if love.filesystem.getInfo(path) then
      local ok, image = pcall(love.graphics.newImage, path)
      if ok then return image end
    end
  end
  return nil
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
  local x, y, z = self.position[1], self.position[2], self.position[3]
  local px, py, _pz, p = x, y, z, 1
  if view and view.project then
    px, py, _pz, p = view.project(x, y, z)
  end

  local cx = love.graphics.getWidth() / 2
  local cy = love.graphics.getHeight() / 2
  local scale = cx / 4

  local screen_x = cx + px * scale
  local screen_y = cy + py * scale
  local size = (self.scale[1] or 1) * (p or 1) * 24

  if self.texture then
    local img_w, img_h = self.texture:getWidth(), self.texture:getHeight()
    local sx = size / img_w
    local sy = size / img_h
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.texture, screen_x, screen_y, 0, sx, sy, img_w / 2, img_h / 2)
  else
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.circle("fill", screen_x, screen_y, size)
  end
end

function g3d.newModel(obj_path, texture_path, position, rotation, scale)
  local model = setmetatable({}, Model)
  model.obj = obj_path
  model.texture = load_texture(texture_path)
  model.position = position or { 0, 0, 0 }
  model.rotation = rotation or { 0, 0, 0 }
  model.scale = scale or { 1, 1, 1 }
  return model
end

return g3d
