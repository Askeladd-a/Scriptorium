-- src/core/register_reward_scene.lua
-- Registra la scena reward nel SceneManager

local SceneManager = require("src.core.scene_manager")
local reward_scene = require("src.scenes.reward")

SceneManager.register("reward", reward_scene)

return true
