
function love.conf(t)
    t.console = false           -- Attach a console (boolean, Windows only)
    -- Window settings (LÖVE 0.9.0+)
    t.window = t.window or {}
    t.window.title = "dice3d"         -- Window title
    t.window.fullscreen = false        -- Enable fullscreen
    t.window.vsync = 1                 -- 0 = disabled, 1 = enabled (LÖVE 11.x)
    t.window.msaa = 4                  -- Multisample anti-aliasing (replaces fsaa)
    t.window.height = 600              -- Window height
    t.window.width = 800               -- Window width
    t.window.resizable = true          -- Allow the window to be resized by the user
    t.window.minwidth = 400            -- Minimum window width when resizing
    t.window.minheight = 300           -- Minimum window height when resizing

    -- Identify the save directory and target LÖVE version
    t.identity = "dice3d"             -- Save directory name
    t.version = "11.5"                -- LÖVE version this game targets (string)
end
