-- src/modules/init.lua
-- Loader moduli runtime (menu, gameplay, impostazioni, reward, splash)

return {
    Scriptorium = require("src.modules.scriptorium"),
    MainMenu = require("src.modules.main_menu"),
    Settings = require("src.modules.settings"),
    Reward = require("src.modules.reward"),
    StartupSplash = require("src.modules.startup_splash"),
}
