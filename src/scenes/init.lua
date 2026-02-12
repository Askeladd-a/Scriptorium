-- src/scenes/init.lua
-- Scenes module loader

return {
    Scriptorium = require("src.scenes.scriptorium"),
    DeskPrototype = require("src.scenes.scriptorium"), -- legacy alias
    MainMenu = require("src.scenes.main_menu"),
    Settings = require("src.scenes.settings"),
}
