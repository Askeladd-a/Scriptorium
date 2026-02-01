-- materials.lua
-- Define named material presets (physics) and helper to apply to stars

local M = {}

M.presets = {
  wood = {
    mass = 1.2,
    restitution = 0.25,
    friction = 0.75,
    linear_damping = 0.06,
    angular_damping = 0.08,
    color = {0.55, 0.35, 0.18}, -- darker brown
  },
  metal = {
    mass = 1.5,
    restitution = 0.12,
    friction = 0.35,
    linear_damping = 0.02,
    angular_damping = 0.03,
    color = {0.66, 0.68, 0.70}, -- cool metal gray
  },
  rubber = {
    mass = 1.5,
    restitution = 0.15,
    friction = 1.0,
    linear_damping = 0.12,
    angular_damping = 0.12,
    color = {0.08, 0.08, 0.10}, -- near-black (rubber)
  }
  ,
  bone = {
    mass = 1.3,
    restitution = 0.22,
    friction = 0.72,
    linear_damping = 0.05,
    angular_damping = 0.06,
    color = {0.97, 0.94, 0.86}, -- warm bone
  }
}

-- Apply preset properties to a star-like object (mutates star)
function M.apply(star, preset)
  if not star or not preset then return end
  if preset.mass       then star.mass = preset.mass; star.invMass = (preset.mass ~= 0) and (1 / preset.mass) or 0 end
  if preset.restitution then star.restitution = preset.restitution end
  if preset.friction    then star.friction = preset.friction end
  if preset.linear_damping then star.linear_damping = preset.linear_damping end
  if preset.angular_damping then star.angular_damping = preset.angular_damping end
  -- tag
  star.material = preset
  return star
end

function M.get(name)
  return M.presets[name]
end

return M
