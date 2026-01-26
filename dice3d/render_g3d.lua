local g3d = require "g3d"

local M = {}

local function set_model_transform(model, position)
  if model.setTranslation then
    model:setTranslation(position[1], position[2], position[3])
  else
    model.position = { position[1], position[2], position[3] }
  end
end

local function quat_to_euler(q)
  if not q then return 0, 0, 0 end
  local w, x, y, z = q[1], q[2], q[3], q[4]
  local sinr_cosp = 2 * (w * x + y * z)
  local cosr_cosp = 1 - 2 * (x * x + y * y)
  local roll = math.atan2(sinr_cosp, cosr_cosp)

  local sinp = 2 * (w * y - z * x)
  local pitch
  if math.abs(sinp) >= 1 then
    pitch = (sinp >= 0 and 1 or -1) * (math.pi / 2)
  else
    pitch = math.asin(sinp)
  end

  local siny_cosp = 2 * (w * z + x * y)
  local cosy_cosp = 1 - 2 * (y * y + z * z)
  local yaw = math.atan2(siny_cosp, cosy_cosp)
  return roll, pitch, yaw
end

local function set_model_rotation(model, orientation)
  local rx, ry, rz = quat_to_euler(orientation)
  if model.setRotation then
    model:setRotation(rx, ry, rz)
  else
    model.rotation = { rx, ry, rz }
  end
end

function M.init(state)
  M.camera = g3d.newCamera(0, 8, 22, 0, 0, 0)
  M.tray = g3d.newModel(
    "assets/models/tray.obj",
    "default/marble.png",
    { 0, 0, 0 },
    { 0, 0, 0 },
    { 1, 1, 1 }
  )

  M.dice = {}
  for i = 1, #state.dice do
    M.dice[i] = g3d.newModel(
      "assets/models/die.obj",
      "textures/1.png",
      { 0, 0, 0 },
      { 0, 0, 0 },
      { 1, 1, 1 }
    )
  end
end

function M.sync(state)
  for i = 1, #state.dice do
    local star = state.dice[i].star
    local model = M.dice[i]
    if model then
      set_model_transform(model, star.position)
      set_model_rotation(model, star.orientation)
    end
  end
end

function M.draw(state)
  M.sync(state)
  if M.tray then
    M.tray:draw(M.camera)
  end
  for i = 1, #M.dice do
    M.dice[i]:draw(M.camera)
  end
end

return M
