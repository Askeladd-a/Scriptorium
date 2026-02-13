std = "luajit+love"

globals = {
    "config",
    "dice",
    "light",
    "view",
    "render",
    "materials",
    "box",
    "body",
    "vector",
    "rotation",
    "pretty",
    "d6",
    "set_module",
    "clone",
    "newD6Body",
    "rollAllDice",
    "checkDiceSettled",
    "convert",
    "focused",
    "dbg",
    "log",
}

unused_args = false
max_line_length = false

ignore = {
    "611", -- trailing whitespace
    "612", -- only whitespace on line
}

exclude_files = {
    "main_backup.lua",
    "**/main_backup.lua",
    "main_game.lua",
    "**/main_game.lua",
    "docs/**",
    "resources/**",
    "third_party/**",
}
