## Using plugins
Just add it to ccgame/plugins, example on making your own here:

```lua
local plugin = {}

function plugin.setup(screen)
  local last = 0
  screen.events:on("post_update", function(scr, dt)
    -- code
  end)

  -- example on a function
  function screen:oh_wow_a_function()
    -- code
  end
end

return plugin
```